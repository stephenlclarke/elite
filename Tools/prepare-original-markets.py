#!/usr/bin/env python3
"""Compile exact authenticated original initial quotes; never rebalance or activate markets."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import tomllib

VERSION = "l337-world-1"
ROW_FIELDS = {"system", "index", "name", "unit", "askTenthsCR", "bidTenthsCR", "stock", "targetStock", "epoch", "worldVersion"}
QUANTITIES = ("askTenthsCR", "bidTenthsCR", "stock", "targetStock", "epoch")
MAX_FILE = 16 * 1024 * 1024


def sha(data):
    return hashlib.sha256(data).hexdigest()


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON key")
        result[key] = value
    return result


def safe(root, relative):
    p = Path(relative)
    if p.is_absolute() or ".." in p.parts:
        raise ValueError("Unsafe market path")
    result = root / p
    if not result.resolve().is_relative_to(root):
        raise ValueError("Market path escapes root")
    for candidate in (result, *result.parents):
        if candidate == root:
            break
        if candidate.is_symlink():
            raise ValueError("Symlink market path")
    return result


def read(path, maximum=MAX_FILE):
    with path.open("rb") as stream:
        raw = stream.read(maximum + 1)
    if len(raw) > maximum:
        raise ValueError("Oversized market input")
    return raw


def integer(value, minimum, maximum):
    return type(value) is int and minimum <= value <= maximum


def prepare(manifest_path, output, galaxies=8, systems=256, commodity_count=17):
    if manifest_path.is_symlink() or output.is_symlink():
        raise ValueError("Symlink manifest/output root")
    manifest_path = manifest_path.resolve()
    root = manifest_path.parent
    source = root / "inputs/original-world-economy"
    output = output.resolve()
    if output.is_relative_to(source) or source.is_relative_to(output):
        raise ValueError("Market input/output overlap")
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        raise ValueError("Output must be fresh/empty")
    manifest_raw = read(manifest_path, 131072)
    manifest = json.loads(manifest_raw, object_pairs_hook=unique)
    wanted = {"authoring.toml", "catalogue.json"} | {f"markets-{g+1:02}.toml" for g in range(galaxies)}
    documents, fingerprints = {}, []
    for entry in manifest["inputs"]:
        path = entry["path"]
        name = Path(path).name
        if path != "inputs/original-world-economy/" + name or name not in wanted or name in documents:
            raise ValueError("Duplicate/foreign market manifest input")
        raw = read(safe(root, path))
        if type(entry["bytes"]) is not int or len(raw) != entry["bytes"] or sha(raw) != entry["sha256"]:
            raise ValueError("Accepted market input fingerprint mismatch: " + name)
        documents[name] = raw
        fingerprints.append(dict(entry))
    if set(documents) != wanted:
        raise ValueError("Missing market manifest inputs")
    authoring = tomllib.loads(documents["authoring.toml"].decode())
    catalogue = json.loads(documents["catalogue.json"], object_pairs_hook=unique)
    if authoring["version"] != VERSION or catalogue["version"] != VERSION or authoring["systemsPerGalaxy"] != systems or len(authoring["galaxies"]) != galaxies:
        raise ValueError("Wrong original world version/dimensions")
    if set(catalogue) != {"version", "systems"}:
        raise ValueError("Unknown catalogue root keys")
    commodities = {}
    for item in authoring["commodities"]:
        index = item["index"]
        if not integer(index, 0, commodity_count - 1) or index in commodities or not isinstance(item["name"], str) or not item["name"] or item["unit"] not in ("t", "kg", "g"):
            raise ValueError("Invalid commodity authoring")
        commodities[index] = item
    if set(commodities) != set(range(commodity_count)):
        raise ValueError("Missing commodity authoring")
    worlds = {}
    for world in catalogue["systems"]:
        galaxy, system = world["galaxy"], world["system"]
        if not integer(galaxy, 0, galaxies - 1) or not integer(system, 0, systems - 1):
            raise ValueError("Foreign original world")
        identity = (galaxy, system)
        if identity in worlds or world["key"] != f"G{galaxy+1:02}-S{system:03}" or world["worldVersion"] != VERSION:
            raise ValueError("Duplicate/mismatched original world identity")
        worlds[identity] = world["key"]
    if set(worlds) != {(g, s) for g in range(galaxies) for s in range(systems)}:
        raise ValueError("Incomplete original world join")
    quotes, statuses = {}, {}
    for galaxy in range(galaxies):
        name = f"markets-{galaxy+1:02}.toml"
        market = tomllib.loads(documents[name].decode())
        if set(market) != {"version", "status", "markets"} or market["version"] != VERSION or not isinstance(market["status"], str):
            raise ValueError("Unknown market document schema/version")
        statuses[name] = market["status"]
        for row in market["markets"]:
            if not isinstance(row, dict) or set(row) != ROW_FIELDS:
                raise ValueError("Unknown/missing initial quote fields")
            system, index = row["system"], row["index"]
            if not integer(system, 0, systems - 1) or not integer(index, 0, commodity_count - 1) or (galaxy, system) not in worlds:
                raise ValueError("Foreign market world/commodity")
            key = (galaxy, system, index)
            if key in quotes:
                raise ValueError("Duplicate initial quote")
            if row["worldVersion"] != VERSION or row["name"] != commodities[index]["name"] or row["unit"] != commodities[index]["unit"]:
                raise ValueError("Initial quote commodity/version mismatch")
            if any(not integer(row[k], 0, 2**63 - 1) for k in QUANTITIES) or row["bidTenthsCR"] > row["askTenthsCR"]:
                raise ValueError("Invalid integral money/stock/epoch or crossed quote")
            quotes[key] = row
    expected = {(g, s, i) for g in range(galaxies) for s in range(systems) for i in range(commodity_count)}
    if set(quotes) != expected:
        raise ValueError("Missing initial quotes")
    states = [{"key": worlds[(g, s)], "galaxy": g, "system": s,
               "quotes": [quotes[(g, s, i)] for i in range(commodity_count)]}
              for g in range(galaxies) for s in range(systems)]
    raw = (json.dumps({"version": VERSION, "markets": states}, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode()
    if len(raw) > MAX_FILE:
        raise ValueError("Generated markets exceed bounded native payload size")
    provenance = {"version": 1, "kind": "original-market-initial-seeds", "worldVersion": VERSION,
                  "file": "markets.json", "bytes": len(raw), "sha256": sha(raw),
                  "worldCount": len(states), "quoteCount": len(quotes),
                  "acceptedInputManifestSHA256": sha(manifest_raw), "sourceCommit": manifest["sourceCommit"],
                  "sourceFiles": sorted(fingerprints, key=lambda e: e["path"]),
                  "sourceDescriptiveStatuses": statuses,
                  "scope": "Exact authored initial seeds only, not traded/current stock or market activation"}
    output.mkdir(parents=True, exist_ok=True)
    safe(output, "markets.json").write_bytes(raw)
    safe(output, "manifest.json").write_text(json.dumps(provenance, sort_keys=True, indent=2) + "\n")
    return provenance


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        manifest = prepare(args.input_manifest, args.output)
        print(f"PASS: {manifest['worldCount']} worlds / {manifest['quoteCount']} exact initial quotes")
    except (OSError, ValueError, TypeError, KeyError) as error:
        parser.exit(2, str(error) + "\n")


if __name__ == "__main__":
    main()
