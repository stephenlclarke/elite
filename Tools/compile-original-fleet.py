#!/usr/bin/env python3
"""Stage approved original fleet TOMLs without legacy balance or runtime activation.

Requires Python 3.11+ (stdlib tomllib). Only a single hull is resident at once.
"""

import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import re
import sys

try:
    import tomllib
except ModuleNotFoundError:
    raise SystemExit("Python 3.11+ is required for standard-library tomllib")


MAX_INPUT_BYTES = 64 * 1024 * 1024
MAX_OUTPUT_BYTES = 500 * 1024 * 1024
ID_PATTERN = re.compile(r"SH[0-9]{3}")
LEGACY_SPEC_FIELDS = {"profiles", "nativeDesign", "nativeCombat", "nativeHull"}
LOADER_ROOT_FIELDS = {
    "id", "name", "shipClass", "appearances", "evidence", "refit", "model",
    "modelSource", "dimensions", "geometryContext", "profiles", "game", "catalogue", "design",
}
REQUIRED_LOADER_FIELDS = {
    "id", "name", "shipClass", "appearances", "evidence", "refit", "geometryContext",
    "profiles", "catalogue", "design",
}
LOADER_DESIGN_FIELDS = {
    "vertices", "faces", "license", "source", "details", "materials", "faceMaterials",
    "paletteName", "appearanceSource", "appearanceLicense", "appearanceBasis",
    "sourceFaceColours", "sourceTextures", "sourceFaceTextures", "resolvedTextures",
}
FLOAT_GAME_FIELDS = (
    "speed", "acceleration", "energy", "recharge", "roll", "pitch", "yaw", "shield",
    "shieldRecharge", "jump", "spool",
)
INTEGER_GAME_RANGES = {
    "cargo": (0, 100000), "fuel": (1, 10000), "missiles": (1, 32),
    "facings": (1, 15), "cargoExpansion": (0, 100000), "price": (1, 100000000),
}
GAME_FIELDS = set(FLOAT_GAME_FIELDS) | set(INTEGER_GAME_RANGES) | {"workTools"}
PURCHASE_POLICIES = {"blueprintFabrication", "pendingFabrication", "xyzzyOnly", "never"}
UNIT_DEPENDENCY = (
    "Preserve all authored game values verbatim. Specs provide no separate unit/scale declaration; "
    "central integration must confirm each native field's unit and balance scale. Do not apply "
    "historical source-refit ratios or catalogue_balance."
)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def output_root(path: Path) -> Path:
    """Reject an explicitly redirected output root before losing its symlink identity."""
    if path.is_symlink():
        raise ValueError(f"Symlink output root is not supported: {path}")
    return path.resolve()


def safe_path(root: Path, relative: str) -> Path:
    """Constrain file names and reject symlink redirection in source/output trees."""
    part = Path(relative)
    if part.is_absolute() or not part.parts or ".." in part.parts:
        raise ValueError(f"Unsafe relative path: {relative}")
    path = root / part
    if not path.resolve().is_relative_to(root):
        raise ValueError(f"Path escapes root: {relative}")
    for candidate in (path, *path.parents):
        if candidate == root:
            break
        if candidate.is_symlink():
            raise ValueError(f"Symlink path is not supported: {relative}")
    return path


def read_toml(path: Path) -> tuple[dict, bytes]:
    with path.open("rb") as stream:
        raw = stream.read(MAX_INPUT_BYTES + 1)
    if len(raw) > MAX_INPUT_BYTES:
        raise ValueError(f"Input exceeds 64 MiB: {path.name}")
    data = tomllib.loads(raw.decode("utf-8"))
    return data, raw


def finite_number(value: object) -> bool:
    return type(value) in (int, float) and math.isfinite(value)


def text(value: object, label: str) -> None:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Expected nonempty {label}")


def toml_string(value: str) -> str:
    # JSON escapes C0 controls; TOML additionally forbids a literal U+007F DEL.
    return json.dumps(value, ensure_ascii=False).replace("\x7f", "\\u007f")


def toml_value(value: object) -> str:
    """Encode original values directly; never invoke the legacy authoring writer."""
    if isinstance(value, str):
        return toml_string(value)
    if type(value) in (bool, int):
        return json.dumps(value)
    if isinstance(value, float) and math.isfinite(value):
        return json.dumps(value, allow_nan=False)
    if isinstance(value, list):
        return "[" + ", ".join(toml_value(item) for item in value) + "]"
    if isinstance(value, dict):
        return "{ " + ", ".join(
            toml_string(key) + " = " + toml_value(item)
            for key, item in value.items()
        ) + " }"
    raise ValueError(f"Unsupported/nonfinite TOML value: {type(value).__name__}")


def validate_spec(spec: dict, identifier: str) -> None:
    if spec.get("id") != identifier or not ID_PATTERN.fullmatch(identifier) or identifier == "SH000":
        raise ValueError(f"Spec filename/ID mismatch: {identifier}")
    for key in ("name", "family", "role", "license", "purchasePolicy"):
        text(spec.get(key), f"{identifier}.{key}")
    if type(spec.get("playerFlyable")) is not bool:
        raise ValueError(f"Missing playerFlyable policy: {identifier}")
    if LEGACY_SPEC_FIELDS & spec.keys() or "design" in spec:
        raise ValueError(f"Legacy/geometry fields are not approved spec inputs: {identifier}")
    # Detect unsupported/non-finite values even in fields not understood by the loader.
    for value in spec.values():
        toml_value(value)
    game = spec.get("game")
    if game is not None and not isinstance(game, dict):
        raise ValueError(f"Invalid game table: {identifier}")
    if spec["playerFlyable"] and game is None:
        raise ValueError(f"Flyable authored spec lacks game values: {identifier}")


def game_issues(game: dict | None) -> list[str]:
    if game is None:
        return []
    issues = []
    for key in FLOAT_GAME_FIELDS:
        value = game.get(key)
        if not finite_number(value) or not 0 < value <= 100000:
            issues.append(f"game.{key}: current ShipPerformance requires finite (0, 100000]")
    for key, (minimum, maximum) in INTEGER_GAME_RANGES.items():
        value = game.get(key)
        if type(value) is not int or not minimum <= value <= maximum:
            issues.append(f"game.{key}: current ShipPerformance requires integer [{minimum}, {maximum}]")
    tools = game.get("workTools", [])
    if not isinstance(tools, list) or any(t not in ("miningLaser", "salvageCutter") for t in tools):
        issues.append("game.workTools: unsupported current utility fitting")
    issues += [f"game.{key}: not decoded by current ShipPerformance" for key in sorted(game.keys() - GAME_FIELDS)]
    return issues


def validate_design(design: dict, label: str) -> dict:
    """Validate authored geometry without normalising coordinates, winding or palettes."""
    if not isinstance(design, dict):
        raise ValueError(f"Missing design table: {label}")
    for key in ("source", "license"):
        text(design.get(key), f"{label}.{key}")
    vertices, faces = design.get("vertices"), design.get("faces")
    if not isinstance(vertices, list) or len(vertices) < 4 or not isinstance(faces, list) or len(faces) < 4:
        raise ValueError(f"Insufficient geometry: {label}")
    if any(not isinstance(v, list) or len(v) != 3 or not all(finite_number(x) for x in v) for v in vertices):
        raise ValueError(f"Invalid/nonfinite vertex: {label}")
    if not any(any(x != 0 for x in v) for v in vertices):
        raise ValueError(f"Zero geometry: {label}")
    nondegenerate = 0
    for face in faces:
        if not isinstance(face, list) or len(face) < 3 or any(type(i) is not int or not 0 <= i < len(vertices) for i in face):
            raise ValueError(f"Invalid face index: {label}")
        p, q, r = (vertices[i] for i in face[:3])
        a, b = [q[i] - p[i] for i in range(3)], [r[i] - p[i] for i in range(3)]
        cross = [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
        nondegenerate += math.hypot(*cross) > 0.000001
    if nondegenerate < 4:
        raise ValueError(f"Fewer than four loader-valid faces: {label}")
    palette, assignments = design.get("materials", []), design.get("faceMaterials", [])
    if not isinstance(palette, list) or not isinstance(assignments, list):
        raise ValueError(f"Invalid material arrays: {label}")
    if palette:
        if len(assignments) != len(faces) or any(type(i) is not int or not 0 <= i < len(palette) for i in assignments):
            raise ValueError(f"Incomplete/out-of-range material assignments: {label}")
        for material in palette:
            colour = material.get("colour")
            if not isinstance(material.get("name"), str) or not material["name"] or type(colour) is not int or not 0 <= colour <= 0xFFFFFFFF or colour & 255 != 255 or type(material.get("emissive")) is not bool:
                raise ValueError(f"Invalid opaque material: {label}")
    elif assignments:
        raise ValueError(f"Material indices without palette: {label}")
    for detail in design.get("details", []):
        for key, count in (("start", len(vertices)), ("end", len(vertices)), ("face", len(faces))):
            if type(detail.get(key)) is not int or not 0 <= detail[key] < count:
                raise ValueError(f"Invalid detail index: {label}")
    textures, mappings = design.get("textures", []), design.get("faceTextures", [])
    if not isinstance(textures, list) or not isinstance(mappings, list):
        raise ValueError(f"Invalid authored texture arrays: {label}")
    for texture in textures:
        text(texture.get("asset"), f"{label}.textures.asset")
        text(texture.get("license"), f"{label}.textures.license")
    untextured_corner_uvs = 0
    if textures or mappings:
        if len(mappings) != len(faces):
            raise ValueError(f"Incomplete authored UV mapping: {label}")
        for face, mapping in zip(faces, mappings):
            index, uv = mapping.get("texture"), mapping.get("uv")
            if type(index) is int and index == -1:
                # Original proposal UV placeholders are not archival sourceFaceTextures.
                if not isinstance(uv, list) or uv and (len(uv) != len(face) or any(not isinstance(p, list) or len(p) != 2 or not all(finite_number(x) for x in p) for p in uv)):
                    raise ValueError(f"Invalid untextured authored UV corners: {label}")
                untextured_corner_uvs += bool(uv)
                continue
            if type(index) is not int or not 0 <= index < len(textures) or not isinstance(uv, list) or len(uv) != len(face) or any(not isinstance(p, list) or len(p) != 2 or not all(finite_number(x) for x in p) for p in uv):
                raise ValueError(f"Invalid authored texture index/corners: {label}")
    return {"vertices": len(vertices), "faces": len(faces), "materials": len(palette),
            "nondegenerateFaces": nondegenerate, "untexturedCornerUVs": untextured_corner_uvs}


class Artifacts:
    """Write/hash a fixed staging tree while enforcing a total output budget."""

    def __init__(self, root: Path):
        self.root = output_root(root)
        self.files = []
        self.total = 0

    def emit(self, relative: str, chunks) -> None:
        path = safe_path(self.root, relative)
        path.parent.mkdir(parents=True, exist_ok=True)
        hasher, size = hashlib.sha256(), 0
        with path.open("xb") as stream:
            for chunk in chunks:
                self.total += len(chunk)
                if self.total > MAX_OUTPUT_BYTES:
                    raise ValueError("Staging payload exceeds 500 MiB")
                stream.write(chunk)
                hasher.update(chunk)
                size += len(chunk)
        self.files.append({"path": relative, "bytes": size, "sha256": hasher.hexdigest()})


def joined_chunks(spec_raw: bytes, design: dict):
    yield b"# Original staging candidate; NOT runtime-ready. See readiness.json.\n"
    yield spec_raw
    yield b"\n[design]\n"
    for key, value in design.items():
        yield (toml_string(key) + " = " + toml_value(value) + "\n").encode("utf-8")


def compile_record(identifier: str, spec: dict, raw: bytes, hull_path: Path | None, sink: Artifacts,
                   hull_source: str | None = None, hull_sha256: str | None = None) -> dict:
    spec_path = f"specs/{identifier}.toml"
    sink.emit(spec_path, [raw])
    entry = {
        "id": identifier, "name": spec["name"], "family": spec["family"], "role": spec["role"],
        "playerFlyableAuthored": spec["playerFlyable"], "purchasePolicyAuthored": spec["purchasePolicy"],
        "spec": spec_path, "sources": [{"path": f"fleet-specs/{identifier}.toml", "sha256": digest(raw)}],
        "runtimeReady": False, "geometryAvailable": hull_path is not None,
        "currentLoaderCompatible": False,
        "unsupportedSpecFields": sorted(spec.keys() - LOADER_ROOT_FIELDS),
        "gameFieldPaths": [f"game.{key}" for key in spec.get("game", {})],
        "gameValidityIssues": game_issues(spec.get("game")),
        "dependencies": ["catalogue-metadata", "unit-scale-authority"],
    }
    if spec.get("game") is not None:
        entry["dependencies"].append("original-cargo-and-accommodation-contract")
    if spec["purchasePolicy"] not in PURCHASE_POLICIES:
        entry["dependencies"].append("unsupported-purchase-policy")
    if identifier == "SH171":
        entry["dependencies"].append("remove-legacy-SH171-exclusivity")
    if hull_path is None:
        entry["missingLoaderFields"] = sorted(REQUIRED_LOADER_FIELDS - spec.keys())
        entry["dependencies"].append("approved-original-mesh-missing")
        return entry
    # Local scope keeps only this hull's parsed high/low-detail geometry in memory.
    hull, hull_raw = read_toml(hull_path)
    if hull_sha256 is not None and digest(hull_raw) != hull_sha256:
        raise ValueError(f"Hull fingerprint mismatch: {identifier}")
    proposal = hull.get("proposal", {})
    if proposal.get("id") != identifier:
        raise ValueError(f"Hull/spec id mismatch: {identifier}")
    metadata_differences = [
        {"field": key, "spec": spec[key], "hullProposal": proposal.get(key)}
        for key in ("name", "family") if proposal.get(key) != spec[key]
    ]
    if "nativeCombat" in hull or "profiles" in hull or "nativeHull" in hull:
        raise ValueError(f"Legacy runtime attachment in original hull: {identifier}")
    geometry = validate_design(hull.get("design"), f"{identifier}.design")
    native_geometry = None
    if "nativeDesign" in hull:
        native_geometry = validate_design(hull["nativeDesign"], f"{identifier}.nativeDesign")
    hull_relative = f"original-hulls/{identifier}-design.toml"
    sink.emit(hull_relative, [hull_raw])
    joined_relative = f"joined/{identifier}.toml"
    sink.emit(joined_relative, joined_chunks(raw, hull["design"]))
    entry.update({
        "hull": hull_relative, "joined": joined_relative, "geometry": geometry,
        "approvedNativeGeometry": native_geometry,
        "hullSpecMetadataDifferences": metadata_differences,
        "missingLoaderFields": sorted(REQUIRED_LOADER_FIELDS - (spec.keys() | {"design"})),
        "unsupportedDesignFields": sorted(hull["design"].keys() - LOADER_DESIGN_FIELDS),
        "preservedHullOnlyFields": sorted(hull.keys() - {"design"}),
        "textureAssetsNotSupplied": sorted({t["asset"] for t in hull["design"].get("textures", [])}),
    })
    entry["sources"].append({"path": hull_source or f"replacement-hulls/{identifier}-design.toml", "sha256": digest(hull_raw)})
    if entry["unsupportedDesignFields"]:
        entry["dependencies"].append("authored-texture-adapter")
    if native_geometry is not None:
        entry["dependencies"].append("approved-original-native-geometry-adapter")
    if metadata_differences:
        entry["dependencies"].append("hull-spec-metadata-difference")
    return entry


DEPENDENCIES = {
    "hull-spec-metadata-difference": "The approved spec and hull proposal share the exact ID but differ in name/family metadata. Joined identity uses the spec authority; original hull metadata is preserved unchanged. Reconcile this explicit authored difference centrally without renaming IDs or inventing geometry.",
    "catalogue-metadata": "Current CatalogueShip requires shipClass, appearances, evidence, refit, geometryContext, profiles and catalogue. Authored root family/role/playerFlyable/purchasePolicy are preserved but do not fill catalogue schemaVersion=2, access, habitat, encounter, collection or purchase gates. Original policy authoring/integration is required; no legacy defaults are copied.",
    "unit-scale-authority": UNIT_DEPENDENCY,
    "original-cargo-and-accommodation-contract": "Current validEffectiveCargo requires exactly one historical project-refit-v1 or liberator-native-v1 profile; ShipAccommodationProfile also depends on those historical fields. An original authority/validator change is required. Do not manufacture historical profiles to bypass these guards.",
    "approved-original-mesh-missing": "No approved replacement hull with this exact ID was supplied. Spec remains staged without any joined mesh or legacy fallback.",
    "unsupported-purchase-policy": "The authored policy is not in the current ShipCataloguePurchasePolicy enum. Implement the real policy gate; do not substitute blueprintFabrication/never/xyzzyOnly.",
    "remove-legacy-SH171-exclusivity": "Current catalogue validation hardcodes SH171 to xyzzyOnly and no normal discovery. This conflicts with the approved Medusa PLUGH-quest fabrication policy and requires coordinated native policy changes.",
    "authored-texture-adapter": "Proposal design.textures/faceTextures are not current ShipDesign fields. Preserve them but implement the original asset/UV adapter and bundle declared original assets before claiming texture rendering; no bitmap assets were supplied here. Authored untextured -1 mappings can contain corner UV placeholders, unlike current archival sourceFaceTextures which require empty UVs for -1. Never blindly relabel them as archival imported sourceTextures/sourceFaceTextures.",
    "approved-original-native-geometry-adapter": "The approved original hull's nativeDesign is retained only in original-hulls, not copied into joined runtime candidates or mapped to old nativeHull enums. Integrate this original geometry deliberately without preserving superseded NPC blueprints.",
}


def indexed_sources(source: Path, relative: Path, expected_specs: int, expected_hulls: int) -> tuple[dict, str]:
    """Join the exact delivered effective hulls; workspace metadata is never a path authority."""
    path = safe_path(source, relative.as_posix())
    with path.open("rb") as stream:
        raw = stream.read(8 * 1024 * 1024 + 1)
    if len(raw) > 8 * 1024 * 1024:
        raise ValueError("Fleet index exceeds 8 MiB")
    index = json.loads(raw)
    if not isinstance(index, dict) or index.get("schema") != "l337.complete-original-fleet-index/1":
        raise ValueError("Unknown fleet index schema")
    entries = index.get("ships")
    if not isinstance(entries, list) or not all(isinstance(entry, dict) for entry in entries):
        raise ValueError("Invalid fleet index entries")
    ids = [entry.get("id") for entry in entries]
    wanted = {f"SH{i:03}" for i in range(1, expected_specs + 1)}
    if not all(isinstance(identifier, str) for identifier in ids) or len(ids) != len(set(ids)) or set(ids) != wanted:
        raise ValueError("Duplicate, missing or extra fleet index IDs")
    if len(entries) != expected_hulls:
        raise ValueError("Fleet index hull count mismatch")
    for entry in entries:
        identifier = entry["id"]
        if entry.get("statsFile") != f"fleet-specs/{identifier}.toml":
            raise ValueError("Fleet index spec path/ID mismatch")
        for field in ("statsSHA256", "geometrySHA256"):
            if not isinstance(entry.get(field), str) or re.fullmatch(r"[0-9a-f]{64}", entry[field]) is None:
                raise ValueError("Invalid fleet index source fingerprint")
        geometry = entry.get("geometryFile")
        if not isinstance(geometry, str) or Path(geometry).name != f"{identifier}-design.toml":
            raise ValueError("Fleet index hull path/ID mismatch")
        safe_path(source, entry["statsFile"])
        safe_path(source, geometry)
    return {entry["id"]: entry for entry in entries}, digest(raw)


def compile_fleet(source: Path, output: Path, expected_specs: int = 171, expected_hulls: int = 94,
                  fleet_index: Path | None = None) -> dict:
    source, output = source.resolve(), output_root(output)
    if output.is_relative_to(source) or source.is_relative_to(output):
        raise ValueError("Input and output trees must not overlap")
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        raise ValueError("Generation requires a fresh/empty staging directory; use --check for existing output")
    indexed, index_sha256 = {}, None
    if fleet_index is None:
        spec_paths = sorted((source / "fleet-specs").glob("*.toml"))
        hull_paths = sorted((source / "replacement-hulls").glob("*.toml"))
    else:
        indexed, index_sha256 = indexed_sources(source, fleet_index, expected_specs, expected_hulls)
        spec_paths = [safe_path(source, indexed[key]["statsFile"]) for key in sorted(indexed)]
        hull_paths = [safe_path(source, indexed[key]["geometryFile"]) for key in sorted(indexed)]
    if len(spec_paths) != expected_specs or len(hull_paths) != expected_hulls:
        raise ValueError(f"Expected {expected_specs} specs/{expected_hulls} hulls; found {len(spec_paths)}/{len(hull_paths)}")
    specs, hulls = {}, {}
    for path in spec_paths:
        safe_path(source, path.relative_to(source).as_posix())
        if not ID_PATTERN.fullmatch(path.stem):
            raise ValueError(f"Unexpected spec filename: {path.name}")
        spec, raw = read_toml(path)
        validate_spec(spec, path.stem)
        if indexed and digest(raw) != indexed[spec["id"]]["statsSHA256"]:
            raise ValueError(f"Spec fingerprint mismatch: {spec['id']}")
        if spec["id"] in specs:
            raise ValueError(f"Duplicate spec ID: {spec['id']}")
        specs[spec["id"]] = (spec, raw)
    for path in hull_paths:
        safe_path(source, path.relative_to(source).as_posix())
        match = re.fullmatch(r"(SH[0-9]{3})-design\.toml", path.name)
        if match is None or match[1] not in specs or match[1] in hulls:
            raise ValueError(f"Unmatched/duplicate hull filename: {path.name}")
        hulls[match[1]] = path
    output.mkdir(parents=True, exist_ok=True)
    sink = Artifacts(output)
    entries = [compile_record(identifier, spec, raw, hulls.get(identifier), sink,
                              indexed[identifier]["geometryFile"] if indexed else None,
                              indexed[identifier]["geometrySHA256"] if indexed else None)
               for identifier, (spec, raw) in sorted(specs.items())]
    manifest = {
        "schema": "l337.original-fleet-staging/1",
        "format": "Build-time staging inventory only; NOT a new runtime schema or activated catalogue.",
        "referenceContract": "ShipCatalogue/ShipPerformance/ShipCatalogueMetadata/ShipAccommodation and docs/SHIP-FILES.md supplied with this task",
        "runtimeReady": False, "legacyBalanceApplied": False, "coordinateTransformsApplied": False,
        "counts": {"specs": len(specs), "hulls": len(hulls), "joined": len(hulls),
                   "missingMeshes": len(specs) - len(hulls),
                   "authoredFlyable": sum(s[0]["playerFlyable"] for s in specs.values()),
                   "gameRangeConflicts": sum(bool(e["gameValidityIssues"]) for e in entries)},
        "dependencyDefinitions": DEPENDENCIES,
        "dependencyCounts": dict(sorted(Counter(code for e in entries for code in e["dependencies"]).items())),
        "ships": entries, "files": list(sink.files), "payloadBytesExcludingManifest": sink.total,
    }
    if indexed:
        manifest["deliveryIndex"] = {"path": fleet_index.as_posix(), "sha256": index_sha256}
    data = (json.dumps(manifest, indent=2, ensure_ascii=True, allow_nan=False) + "\n").encode()
    sink.emit("readiness.json", [data])
    return manifest


def check_staging(output: Path) -> dict:
    """Verify the frozen payload in one streaming hash pass; never reparse/rebalance hulls."""
    output = output_root(output)
    path = safe_path(output, "readiness.json")
    with path.open("rb") as stream:
        raw = stream.read(8 * 1024 * 1024 + 1)
    if len(raw) > 8 * 1024 * 1024:
        raise ValueError("Readiness manifest exceeds 8 MiB")
    manifest = json.loads(raw)
    if manifest.get("schema") != "l337.original-fleet-staging/1":
        raise ValueError("Unknown staging manifest")
    expected, total = {"readiness.json"}, 0
    for item in manifest["files"]:
        relative = item["path"]
        if relative in expected:
            raise ValueError(f"Duplicate staged path: {relative}")
        expected.add(relative)
        path = safe_path(output, relative)
        hasher, size = hashlib.sha256(), 0
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                hasher.update(chunk)
                size += len(chunk)
                if size > item["bytes"]:
                    raise ValueError(f"Oversized staged file: {relative}")
        if size != item["bytes"] or hasher.hexdigest() != item["sha256"]:
            raise ValueError(f"Stale/corrupt staged file: {relative}")
        total += size
    actual = {p.relative_to(output).as_posix() for p in output.rglob("*") if p.is_file() or p.is_symlink()}
    if actual != expected or total != manifest["payloadBytesExcludingManifest"]:
        raise ValueError("Unexpected/missing files or payload size in staging tree")
    if total + len(raw) > MAX_OUTPUT_BYTES:
        raise ValueError("Staging payload exceeds 500 MiB")
    return manifest


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-root", type=Path, help="Contains fleet-specs/ and replacement-hulls/")
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--fleet-index", type=Path, help="Effective delivery index, relative to --input-root; never reads workspace metadata")
    parser.add_argument("--expected-specs", type=int, default=171)
    parser.add_argument("--expected-hulls", type=int, default=94)
    parser.add_argument("--check", action="store_true", help="Read-only staged inventory/hash check; no source reparse")
    options = parser.parse_args(argv)
    try:
        if options.check:
            manifest = check_staging(options.output_root)
        else:
            if options.input_root is None:
                raise ValueError("--input-root is required for generation")
            manifest = compile_fleet(options.input_root, options.output_root, options.expected_specs, options.expected_hulls, options.fleet_index)
        print(json.dumps({"status": "PASS", "mode": "check" if options.check else "generate", **manifest["counts"]}, sort_keys=True))
        return 0
    except (OSError, ValueError, TypeError, KeyError) as error:
        print(f"Original fleet error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
