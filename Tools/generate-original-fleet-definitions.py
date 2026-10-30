#!/usr/bin/env python3
"""Generate staged immutable Swift records from original specs, without reading geometry."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import sys
import tomllib

NATIVE_FIELDS = ("cargo", "speed", "acceleration", "energy", "recharge", "roll", "pitch", "yaw", "shield", "shieldRecharge", "fuel", "jump", "spool", "missiles", "facings", "cargoExpansion", "price")
INT_FIELDS = {"cargo", "fuel", "missiles", "facings", "cargoExpansion", "price"}
MIN_INT, MAX_INT = -(2**63), 2**63 - 1


def bounded(path, limit):
    with path.open("rb") as stream:
        raw = stream.read(limit + 1)
    if len(raw) > limit:
        raise ValueError("Oversized definition input")
    return raw


def safe(root, relative):
    p = Path(relative)
    if p.is_absolute() or ".." in p.parts:
        raise ValueError("Unsafe definition path")
    path = root / p
    if not path.resolve().is_relative_to(root):
        raise ValueError("Definition path escapes root")
    for candidate in (path, *path.parents):
        if candidate == root:
            break
        if candidate.is_symlink():
            raise ValueError("Symlink definition path")
    return path


def quote(value):
    if not isinstance(value, str) or any(0xD800 <= ord(c) <= 0xDFFF for c in value):
        raise ValueError("Invalid Swift Unicode string")
    return '"' + ''.join('\\\\' if c == '\\' else '\\"' if c == '"' else f'\\u{{{ord(c):x}}}' if ord(c) < 32 or ord(c) >= 127 else c for c in value) + '"'


def integer(value):
    return "Int64.min" if value == MIN_INT else str(value)


def value_lines(value, prefix, indent):
    """Explicit enum cases and bounded literals prevent one giant inferred expression."""
    if isinstance(value, dict):
        if not value:
            return [prefix + ".object([:])"]
        result = [prefix + ".object(["]
        for key, item in sorted(value.items()):
            child = value_lines(item, " " * (indent + 2) + quote(key) + ": ", indent + 2)
            result += child[:-1] + [child[-1] + ","]
        return result + [" " * indent + "])"]
    if isinstance(value, list):
        if not value:
            return [prefix + ".array([])"]
        result = [prefix + ".array(["]
        for item in value:
            child = value_lines(item, " " * (indent + 2), indent + 2)
            result += child[:-1] + [child[-1] + ","]
        return result + [" " * indent + "])"]
    if isinstance(value, bool):
        literal = ".boolean(" + str(value).lower() + ")"
    elif isinstance(value, int):
        literal = ".integer(" + integer(value) + ")" if MIN_INT <= value <= MAX_INT else ".largeInteger(" + quote(str(value)) + ")"
    elif isinstance(value, float) and math.isfinite(value):
        literal = ".number(" + repr(value) + ")"
    elif isinstance(value, str):
        literal = ".string(" + quote(value) + ")"
        if len(prefix) + len(literal) > 100:
            return [prefix + ".string(", " " * (indent + 2) + quote(value), " " * indent + ")"]
    else:
        raise ValueError("Unsupported/nonfinite authored value")
    return [prefix + literal]


def native_values(game):
    if game is None:
        return None, []
    issues, values = [], []
    for field in NATIVE_FIELDS:
        value = game.get(field)
        if field in INT_FIELDS:
            if type(value) is not int or not MIN_INT <= value <= MAX_INT:
                issues.append(f"game.{field}: not representable as native Int without conversion")
            else:
                values.append((field, "Int.min" if value == MIN_INT else str(value)))
        else:
            try:
                converted = float(value) if type(value) in (int, float) else float("nan")
            except OverflowError:
                converted = float("nan")
            if not math.isfinite(converted) or type(value) is int and int(converted) != value:
                issues.append(f"game.{field}: not exactly representable as native Double")
            else:
                values.append((field, repr(converted)))
    issues += [f"game.{field}: not represented by ShipPerformance; typed metadata retained"
               for field in sorted(game.keys() - set(NATIVE_FIELDS) - {"workTools"})]
    if game.get("workTools") is not None:
        issues.append("game.workTools: explicit fitting integration required; authored value retained")
    return (None if issues else values), issues


def generate(staging, repo, expected=171):
    if repo.is_symlink():
        raise ValueError("Symlink output root")
    staging, repo = staging.resolve(), repo.resolve()
    if repo.is_relative_to(staging) or staging.is_relative_to(repo):
        raise ValueError("Input/output overlap")
    ready_raw = bounded(safe(staging, "readiness.json"), 8 * 1024 * 1024)
    ready = json.loads(ready_raw)
    wanted = {f"SH{i:03}" for i in range(1, expected + 1)}
    entries = ready["ships"]
    ids = [e["id"] for e in entries]
    if len(ids) != len(set(ids)) or set(ids) != wanted:
        raise ValueError("Duplicate, missing or extra definition IDs")
    if {p.stem for p in (staging / "specs").glob("*.toml")} != wanted:
        raise ValueError("Missing/extra spec files")
    functions, fingerprints, representations = [], [], []
    for entry in sorted(entries, key=lambda e: e["id"]):
        identifier = entry["id"]
        if entry["spec"] != f"specs/{identifier}.toml":
            raise ValueError("Spec path/ID mismatch")
        raw = bounded(safe(staging, entry["spec"]), 131072)
        spec = tomllib.loads(raw.decode())
        if spec["id"] != identifier or type(spec.get("playerFlyable")) is not bool:
            raise ValueError("Invalid definition identity/capability")
        for key in ("name", "family", "role", "purchasePolicy"):
            if not isinstance(spec.get(key), str) or not spec[key]:
                raise ValueError("Missing definition identity/policy")
        source_sha = hashlib.sha256(raw).hexdigest()
        sources = [s for s in entry["sources"] if s["path"] == f"fleet-specs/{identifier}.toml"]
        if len(sources) != 1 or sources[0]["sha256"] != source_sha:
            raise ValueError("Spec fingerprint mismatch")
        native, issues = native_values(spec.get("game"))
        functions += [f"  private static func {identifier.lower()}() -> OriginalFleetDefinition {{", "    let authored: [String: OriginalFleetValue] = ["]
        for key, value in sorted(spec.items()):
            lines = value_lines(value, "      " + quote(key) + ": ", 6)
            functions += lines[:-1] + [lines[-1] + ","]
        functions += ["    ]"]
        if native is None:
            functions += ["    let performance: ShipPerformance? = nil"]
        else:
            functions += ["    let performance: ShipPerformance? = ShipPerformance("]
            functions += [f"      {field}: {literal}," for field, literal in native]
            functions += ["      workTools: nil", "    )"]
        functions += ["    return OriginalFleetDefinition("]
        for key in ("id", "name", "family", "role"):
            functions += [f"      {key}: {quote(spec[key])},"]
        functions += [f"      playerFlyable: {str(spec['playerFlyable']).lower()},",
                      f"      purchasePolicy: {quote(spec['purchasePolicy'])},", "      authored: authored,",
                      f"      sourcePath: {quote(entry['spec'])},", f"      sourceSHA256: {quote(source_sha)},",
                      "      nativePerformance: performance,",
                      f"      approvedMeshAvailable: {str(entry['geometryAvailable']).lower()},",
                      "      integrationBlockers: ["]
        blockers = entry.get("dependencies", []) + entry.get("gameValidityIssues", []) + issues
        functions += ["        " + quote(blocker) + "," for blocker in blockers]
        functions += ["      ]", "    )", "  }", ""]
        fingerprints.append({"id": identifier, "sha256": source_sha})
        if issues:
            representations.append({"id": identifier, "issues": issues})
    lines = ["// Generated by Tools/generate-original-fleet-definitions.py; staged definitions only.",
             "public enum OriginalFleetDefinitionData {", "  public static let staged: [OriginalFleetDefinition] = ["]
    lines += [f"    {i.lower()}()," for i in sorted(wanted)]
    lines += ["  ]", "", *functions, "}", ""]
    data = "\n".join(lines).encode()
    path = safe(repo, "Sources/L337Core/OriginalFleetDefinitions.generated.swift")
    if path.exists():
        raise ValueError("Refusing to overwrite an existing generated handoff")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    manifest = {"records": len(wanted), "sourceSpecs": fingerprints,
                "readinessSHA256": hashlib.sha256(ready_raw).hexdigest(),
                "generatedSHA256": hashlib.sha256(data).hexdigest(), "nativeRepresentationIssues": representations,
                "geometryRead": False, "runtimeActivated": False}
    safe(repo, "original-fleet-definitions.manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--staging", type=Path, required=True)
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--expected-count", type=int, default=171)
    args = parser.parse_args()
    try:
        manifest = generate(args.staging, args.repo_root, args.expected_count)
        print("PASS: " + str(manifest["records"]) + " immutable staged definitions generated")
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(2, str(error) + "\n")


if __name__ == "__main__":
    main()
