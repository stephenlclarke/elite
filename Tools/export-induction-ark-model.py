#!/usr/bin/env python3
"""Export authenticated original geometry into the two closed native induction service packs."""
import argparse
import hashlib
import json
from pathlib import Path
import re


def export(check=False, crew_log=False):
    """Preserve exact design values and refresh the one declared internal model hash."""
    repo = Path(__file__).resolve().parents[1]
    resources = repo / "Sources/EliteCore/Resources"
    models = resources / "OriginalFleetShowroomModels"
    manifest_bytes = (models / "manifest.json").read_bytes()
    authority = (repo / "Sources/EliteCore/OriginalFleetShowroomModels.swift").read_text()
    pin = re.search(r'manifestSHA256 = "([a-f0-9]{64})"', authority)
    if pin is None or hashlib.sha256(manifest_bytes).hexdigest() != pin[1]:
        raise ValueError("Original model manifest does not match the native loader authority")
    entries = json.loads(manifest_bytes)["models"]
    hull = "SH029" if crew_log else "SH061"
    entry = next(row for row in entries if row["id"] == hull)
    raw = (models / (hull + ".json")).read_bytes()
    if len(raw) != entry["bytes"] or hashlib.sha256(raw).hexdigest() != entry["sha256"]:
        raise ValueError("Original induction hull model content changed")
    source = json.loads(raw)
    if source["id"] != hull or source["sourceSHA256"] != entry["sourceSHA256"]:
        raise ValueError("Original induction hull source binding changed")
    output = (json.dumps(source["nativeDesign"], ensure_ascii=False, allow_nan=False,
                         sort_keys=True, separators=(",", ":")) + "\n").encode()
    pack = resources / ("ScriptPacks/l337-induction-crew-log" if crew_log
                        else "ScriptPacks/l337-wayfarer-seed-ark")
    manifest = pack / "manifest.toml"
    old = manifest.read_text()
    updated, count = re.subn(r'(?m)^sha256 = "[a-f0-9]{64}"$',
                            'sha256 = "' + hashlib.sha256(output).hexdigest() + '"', old)
    if count != 1:
        raise ValueError("Expected exactly one native induction hull model declaration")
    target = pack / ("models/burro.json" if crew_log else "models/haflinger.json")
    if check:
        if target.read_bytes() != output or old != updated:
            raise ValueError("Regenerate the native induction hull model")
    else:
        target.write_bytes(output)
        manifest.write_text(updated)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--crew-log", action="store_true",
                        help="Export the approved original Burro for the Cevilis source")
    args = parser.parse_args()
    export(args.check, args.crew_log)
