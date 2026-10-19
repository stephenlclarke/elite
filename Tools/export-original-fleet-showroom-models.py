#!/usr/bin/env python3
"""Export exact effective native designs for read-only showroom access, never activation."""
import argparse
import importlib.util
import json
from pathlib import Path
import sys

spec = importlib.util.spec_from_file_location("fleet_compiler", Path(__file__).with_name("compile-original-fleet.py"))
fleet = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fleet)
MAX_ASSET = 8 * 1024 * 1024
MAX_TOTAL = 128 * 1024 * 1024
MAX_MANIFEST = 262144
KIND = "original-fleet-showroom-models"


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, allow_nan=False, sort_keys=True, separators=(",", ":")) + "\n").encode()


def bounded_json(path, limit):
    with path.open("rb") as stream:
        raw = stream.read(limit + 1)
    if len(raw) > limit:
        raise ValueError("Oversized showroom input")
    return json.loads(raw), raw


def export(input_root, index_path, staging, output, expected=171):
    """Bind one nativeDesign at a time to both the effective index and staged raw hull."""
    input_root, staging = input_root.resolve(), staging.resolve()
    if output.is_symlink() or output.exists():
        raise ValueError("Showroom output must be fresh and not a symlink")
    output = output.resolve()
    if any(output.is_relative_to(root) or root.is_relative_to(output) for root in (input_root, staging)):
        raise ValueError("Showroom input/output overlap")
    entries, index_sha = fleet.indexed_sources(input_root, Path(index_path), expected, expected)
    ready, _ = bounded_json(fleet.safe_path(staging, "readiness.json"), 8 * 1024 * 1024)
    rows = ready.get("ships", [])
    ids = [row.get("id") for row in rows]
    if len(ids) != expected or len(set(ids)) != expected or set(ids) != set(entries):
        raise ValueError("Missing/duplicate showroom staging IDs")
    if ready.get("deliveryIndex") != {"path": index_path, "sha256": index_sha}:
        raise ValueError("Showroom staging/index authority mismatch")
    staged = {row["id"]: row for row in rows}
    models, total = [], 0
    output.mkdir(parents=True)
    for identifier, entry in sorted(entries.items()):
        row = staged[identifier]
        hull_file = f"original-hulls/{identifier}-design.toml"
        if row.get("hull") != hull_file:
            raise ValueError("Showroom hull path mismatch")
        hull, raw = fleet.read_toml(fleet.safe_path(staging, hull_file))
        if fleet.digest(raw) != entry["geometrySHA256"]:
            raise ValueError("Showroom native hull hash mismatch")
        # Require exact staged source provenance, including effective 01/02 LOD selection.
        source = {"path": entry["geometryFile"], "sha256": entry["geometrySHA256"]}
        if source not in row.get("sources", []):
            raise ValueError("Showroom native source mismatch")
        proposal = hull.get("proposal", {})
        if proposal.get("id") != identifier or "nativeDesign" not in hull:
            raise ValueError("Missing/mismatched native showroom design")
        native = hull["nativeDesign"]
        fleet.validate_design(native, identifier + ".nativeDesign")
        units = proposal.get("coordinateUnits")
        if units is not None and (not isinstance(units, str) or not units.strip()):
            raise ValueError("Invalid explicit native coordinate units")
        document = {"id": identifier, "sourcePath": source["path"],
                    "sourceSHA256": source["sha256"], "nativeDesign": native}
        if units is not None:
            document["coordinateUnits"] = units
        raw_model = encoded(document)
        total += len(raw_model)
        if len(raw_model) > MAX_ASSET or total > MAX_TOTAL:
            raise ValueError("Showroom native resource budget exceeded")
        # JSON transport must preserve every native field, value and array order.
        if json.loads(raw_model)["nativeDesign"] != native:
            raise ValueError("Showroom native transport changed authored data")
        (output / (identifier + ".json")).write_bytes(raw_model)
        models.append({"id": identifier, "file": identifier + ".json", "bytes": len(raw_model),
                       "sha256": fleet.digest(raw_model), "sourcePath": source["path"],
                       "sourceSHA256": source["sha256"]})
    manifest = encoded({"schemaVersion": 1, "kind": KIND,
                        "deliveryIndexSHA256": index_sha, "models": models})
    if len(manifest) > MAX_MANIFEST:
        raise ValueError("Showroom manifest budget exceeded")
    (output / "manifest.json").write_bytes(manifest)
    return {"models": len(models), "payloadBytes": total, "manifestSHA256": fleet.digest(manifest),
            "deliveryIndexSHA256": index_sha, "runtimeActivation": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-root", required=True, type=Path)
    parser.add_argument("--fleet-index", required=True)
    parser.add_argument("--staging-root", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(export(args.input_root, args.fleet_index, args.staging_root, args.output_root), sort_keys=True))
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
