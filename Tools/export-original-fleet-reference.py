#!/usr/bin/env python3
"""Export original authored specifications and actual staging gaps, never geometry or gameplay."""
import argparse
import csv
import hashlib
import io
import json
from pathlib import Path
import re
import sys
import tomllib

FIELDS = (
    "cargo", "speed", "acceleration", "energy", "recharge", "roll", "pitch", "yaw",
    "shield", "shieldRecharge", "fuel", "jump", "spool", "missiles", "facings",
    "cargoExpansion", "price",
)
# Only units directly supported by the supplied ShipPerformance/accommodation/SHIP-FILES contract.
UNITS = {"cargo": "t", "cargoExpansion": "t", "fuel": "0.1 LY (raw tenths)",
         "jump": "LY", "spool": "seconds", "missiles": "count", "facings": "facing bit mask",
         "price": "credits"}


def fingerprint(data):
    return hashlib.sha256(data).hexdigest()


def bounded(path, limit):
    with path.open("rb") as stream:
        raw = stream.read(limit + 1)
    if len(raw) > limit:
        raise ValueError("Oversized reference input")
    return raw


def safe(root, relative):
    path = Path(relative)
    if path.is_absolute() or ".." in path.parts:
        raise ValueError("Unsafe reference path")
    result = root / path
    if not result.resolve().is_relative_to(root):
        raise ValueError("Reference path escapes root")
    for candidate in (result, *result.parents):
        if candidate == root:
            break
        if candidate.is_symlink():
            raise ValueError("Symlink reference path")
    return result


def md(value):
    value = str(value)
    return "".join(f"&#{ord(char)};" if char in "&<>|\\`*_[]#" or ord(char) < 32 or ord(char) == 127 else char for char in value)


def scalar(value):
    return json.dumps(value, ensure_ascii=True, allow_nan=False, separators=(",", ":"))


def spreadsheet_text(value):
    value = str(value)
    return "'" + value if value.lstrip().startswith(("=", "+", "-", "@")) else value


def export(staging, output, expected=171):
    if output.is_symlink():
        raise ValueError("Symlink output root")
    staging, output = staging.resolve(), output.resolve()
    if staging.is_relative_to(output) or output.is_relative_to(staging):
        raise ValueError("Input/output overlap")
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        raise ValueError("Output must be fresh/empty")
    ready_raw = bounded(safe(staging, "readiness.json"), 8 * 1024 * 1024)
    ready = json.loads(ready_raw)
    if ready.get("schema") != "l337.original-fleet-staging/1" or len(ready["ships"]) != expected:
        raise ValueError("Unexpected readiness schema/spec count")
    records, identities, game_fields = [], set(), set(FIELDS)
    for entry in sorted(ready["ships"], key=lambda e: e["id"]):
        identity = entry["id"]
        if not re.fullmatch(r"SH[0-9]{3}", identity) or identity in identities or entry["spec"] != f"specs/{identity}.toml":
            raise ValueError("Duplicate/unsafe spec identity")
        identities.add(identity)
        raw = bounded(safe(staging, entry["spec"]), 131072)
        spec = tomllib.loads(raw.decode())
        if spec.get("id") != identity:
            raise ValueError("Spec ID mismatch")
        sources = [s for s in entry["sources"] if s["path"] == f"fleet-specs/{identity}.toml"]
        if len(sources) != 1 or fingerprint(raw) != sources[0]["sha256"]:
            raise ValueError("Staged spec fingerprint mismatch")
        # Preserve future authored fields too; JSON encoding refuses non-finite numbers.
        scalar(spec)
        game_fields.update(spec.get("game", {}))
        records.append((spec, entry, fingerprint(raw)))
    stats = list(FIELDS) + sorted(game_fields - set(FIELDS))
    headers = ["id", "name", "family", "role", "authored_player_flyable", "authored_access",
               "authored_purchase_policy", "approved_mesh_available", "runtime_ready",
               "current_loader_compatible", "missing_loader_fields", "loader_dependencies",
               "game_validity_issues", "unsupported_spec_fields", "unsupported_design_fields",
               "hull_metadata_differences", "spec_sha256"]
    headers += ["game." + field for field in stats]
    headers += ["unit." + field for field in stats] + ["authored_spec_json"]
    buffer = io.StringIO(newline="")
    writer = csv.writer(buffer, lineterminator="\n")
    writer.writerow(headers)
    lines = ["# Original fleet specification reference", "",
             "Authored capability and purchase policy are design data; they do not establish runtime readiness or a shipped feature.", "",
             "All values remain unconverted. Raw authored units are used unless the supplied native field contract declares a unit. No historical balance or geometry is read.", "",
             "## Index", "", "| ID | Name | Family | Role | Authored flyable | Mesh | Runtime ready | Purchase policy | Cost (credits) |",
             "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
    for spec, entry, sha in records:
        game = spec.get("game", {})
        flyable = scalar(spec.get("playerFlyable")) if "playerFlyable" in spec else "not authored"
        row = [spec["id"], spreadsheet_text(spec["name"]), spreadsheet_text(spec.get("family", "")),
               spreadsheet_text(spec.get("role", "")), flyable, spreadsheet_text(spec.get("access", "")),
               spreadsheet_text(spec.get("purchasePolicy", "")), scalar(entry["geometryAvailable"]),
               scalar(entry["runtimeReady"]), scalar(entry["currentLoaderCompatible"]),
               scalar(entry.get("missingLoaderFields", [])), scalar(entry.get("dependencies", [])),
               scalar(entry.get("gameValidityIssues", [])), scalar(entry.get("unsupportedSpecFields", [])),
               scalar(entry.get("unsupportedDesignFields", [])), scalar(entry.get("hullSpecMetadataDifferences", [])), sha]
        row += [spreadsheet_text(scalar(game[field])) if field in game else "" for field in stats]
        row += [UNITS.get(field, "raw authored units") for field in stats] + [scalar(spec)]
        writer.writerow(row)
        lines.append("| " + " | ".join(md(v) for v in [spec["id"], spec["name"], spec.get("family", "not authored"), spec.get("role", "not authored"), flyable, scalar(entry["geometryAvailable"]), scalar(entry["runtimeReady"]), spec.get("purchasePolicy", "not authored"), scalar(game["price"]) if "price" in game else "not authored"]) + " |")
    lines += ["", "## Integration dependency definitions", ""]
    for code, detail in sorted(ready["dependencyDefinitions"].items()):
        lines += [f"### {md(code)}", "", md(detail), ""]
    for spec, entry, sha in records:
        lines += [f"## {spec['id']}: {md(spec['name'])}", "",
                  f"Family: {md(spec.get('family', 'not authored'))}. Role: {md(spec.get('role', 'not authored'))}.", "",
                  f"Authored playerFlyable: {md(spec.get('playerFlyable', 'not authored'))}. Access: {md(spec.get('access', 'not authored'))}. Purchase policy: {md(spec.get('purchasePolicy', 'not authored'))}.", "",
                  f"Approved mesh available: {md(entry['geometryAvailable'])}. Runtime ready: {md(entry['runtimeReady'])}. Current loader compatible: {md(entry['currentLoaderCompatible'])}.", "",
                  f"Spec SHA-256: `{sha}`.", "", "| Field | Authored value | Unit |", "| --- | --- | --- |"]
        for key, value in spec.get("game", {}).items():
            lines.append(f"| {md(key)} | {md(scalar(value))} | {md(UNITS.get(key, 'raw authored units'))} |")
        if "game" not in spec:
            lines += ["| Performance | Not authored (display object) | Not applicable |"]
        lines += ["", "Missing loader fields: " + md(scalar(entry.get("missingLoaderFields", []))), "",
                  "Dependencies: " + md(scalar(entry.get("dependencies", []))), "",
                  "Current native range/field issues: " + md(scalar(entry.get("gameValidityIssues", []))), "",
                  "Unmapped spec fields: " + md(scalar(entry.get("unsupportedSpecFields", []))), "",
                  "Unsupported design fields: " + md(scalar(entry.get("unsupportedDesignFields", []))), "",
                  "Hull metadata differences: " + md(scalar(entry.get("hullSpecMetadataDifferences", []))), ""]
    output.mkdir(parents=True, exist_ok=True)
    csv_raw = buffer.getvalue().encode("utf-8")
    markdown_raw = ("\n".join(lines).rstrip("\n") + "\n").encode("utf-8")
    safe(output, "fleet-reference.csv").write_bytes(csv_raw)
    safe(output, "fleet-reference.md").write_bytes(markdown_raw)
    manifest = {"version": 1, "records": len(records), "readinessSHA256": fingerprint(ready_raw),
                "geometryRead": False, "numericConversionApplied": False,
                "csvTextSafety": "Spreadsheet-active display text is apostrophe-prefixed; authored_spec_json retains every exact original value.",
                "files": [{"path": "fleet-reference.csv", "bytes": len(csv_raw), "sha256": fingerprint(csv_raw)},
                          {"path": "fleet-reference.md", "bytes": len(markdown_raw), "sha256": fingerprint(markdown_raw)}]}
    safe(output, "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--staging", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--expected-specs", type=int, default=171)
    args = parser.parse_args()
    try:
        manifest = export(args.staging, args.output_root, args.expected_specs)
        print("PASS: " + str(manifest["records"]) + " original specifications exported")
    except (OSError, ValueError, TypeError, KeyError) as error:
        parser.exit(2, str(error) + "\n")


if __name__ == "__main__":
    main()
