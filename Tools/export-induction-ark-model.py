#!/usr/bin/env python3
"""Export only the authenticated original Haflinger design into the native ark service pack."""
import argparse
import hashlib
import json
from pathlib import Path
import re


def export(check=False):
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
    entry = next(row for row in entries if row["id"] == "SH061")
    raw = (models / "SH061.json").read_bytes()
    if len(raw) != entry["bytes"] or hashlib.sha256(raw).hexdigest() != entry["sha256"]:
        raise ValueError("Original Haflinger model content changed")
    source = json.loads(raw)
    if source["id"] != "SH061" or source["sourceSHA256"] != entry["sourceSHA256"]:
        raise ValueError("Original Haflinger source binding changed")
    output = (json.dumps(source["nativeDesign"], ensure_ascii=False, allow_nan=False,
                         sort_keys=True, separators=(",", ":")) + "\n").encode()
    pack = resources / "ScriptPacks/l337-wayfarer-seed-ark"
    manifest = pack / "manifest.toml"
    old = manifest.read_text()
    updated, count = re.subn(r'(?m)^sha256 = "[a-f0-9]{64}"$',
                            'sha256 = "' + hashlib.sha256(output).hexdigest() + '"', old)
    if count != 1:
        raise ValueError("Expected exactly one native ark model declaration")
    target = pack / "models/haflinger.json"
    if check:
        if target.read_bytes() != output or old != updated:
            raise ValueError("Regenerate the native ark model")
    else:
        target.write_bytes(output)
        manifest.write_text(updated)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    export(parser.parse_args().check)
