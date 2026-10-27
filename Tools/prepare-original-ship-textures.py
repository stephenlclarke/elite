#!/usr/bin/env python3
"""Authenticate and stage current-original pixels without archive or geometry conversion."""
import argparse
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import struct
import sys
import tomllib
import zlib

ASSET_IDS = {"l337-patrol-diffuse", "l337-strike-diffuse", "l337-service-details"}
AUXILIARY = ("albedo", "normal", "height", "roughness")
MAX_FILE = 16 * 1024 * 1024


def sha(data):
    return hashlib.sha256(data).hexdigest()


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON member: " + key)
        result[key] = value
    return result


def safe(root, relative):
    path = PurePosixPath(relative)
    if path.is_absolute() or ".." in path.parts or "\\" in relative or not path.parts:
        raise ValueError("Unsafe asset path")
    result = root / Path(*path.parts)
    if not result.resolve().is_relative_to(root.resolve()):
        raise ValueError("Asset path escapes root")
    for part in (result, *result.parents):
        if part == root:
            break
        if part.is_symlink():
            raise ValueError("Symlink asset path")
    return result


def bounded(path, maximum=MAX_FILE):
    with path.open("rb") as stream:
        data = stream.read(maximum + 1)
    if len(data) > maximum:
        raise ValueError("Oversized file: " + path.name)
    return data


def decode_png(png):
    """Bounded CRC-checked noninterlaced 8/16-bit gray/RGB(A) PNG decoding."""
    if len(png) > MAX_FILE or png[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Invalid PNG signature/size")
    offset, header, chunks, ended, idat_ended = 8, None, [], False, False
    while offset < len(png):
        if offset + 12 > len(png):
            raise ValueError("Truncated PNG chunk")
        size, kind = struct.unpack(">I4s", png[offset:offset + 8])
        end = offset + 12 + size
        if end > len(png):
            raise ValueError("Truncated PNG payload")
        payload = png[offset + 8:end - 4]
        if zlib.crc32(kind + payload) & 0xFFFFFFFF != struct.unpack(">I", png[end - 4:end])[0]:
            raise ValueError("PNG CRC mismatch")
        if kind == b"IHDR":
            if header is not None or offset != 8 or size != 13:
                raise ValueError("Invalid PNG header order")
            header = struct.unpack(">IIBBBBB", payload)
        elif header is None:
            raise ValueError("PNG missing initial IHDR")
        elif kind == b"IDAT":
            if idat_ended:
                raise ValueError("Noncontiguous PNG IDAT")
            chunks.append(payload)
        elif kind == b"IEND":
            if size or end != len(png) or not chunks:
                raise ValueError("Invalid PNG end")
            ended = True
            break
        else:
            if chunks:
                idat_ended = True
            if kind[0] & 32 == 0:
                raise ValueError("Unsupported critical PNG chunk")
        offset = end
    if header is None or not ended:
        raise ValueError("Incomplete PNG")
    width, height, bits, colour, compression, filtering, interlace = header
    if not 0 < width <= 2048 or not 0 < height <= 2048 or bits not in (8, 16) or colour not in (0, 2, 4, 6) or (compression, filtering, interlace) != (0, 0, 0):
        raise ValueError("Unsupported/bounded PNG format")
    channels = {0: 1, 2: 3, 4: 2, 6: 4}[colour]
    pixel_bytes = channels * (bits // 8)
    stride = width * pixel_bytes
    expected = height * (stride + 1)
    decoder = zlib.decompressobj()
    raw = decoder.decompress(b"".join(chunks), expected + 1)
    if len(raw) != expected or not decoder.eof or decoder.unused_data or decoder.unconsumed_tail:
        raise ValueError("PNG deflate size/termination mismatch")
    pixels, previous = bytearray(), bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        mode = raw[start]
        row = bytearray(raw[start + 1:start + 1 + stride])
        if mode not in range(5):
            raise ValueError("Invalid PNG row filter")
        if mode:
            for x in range(stride):
                left = row[x - pixel_bytes] if x >= pixel_bytes else 0
                above = previous[x]
                corner = previous[x - pixel_bytes] if x >= pixel_bytes else 0
                if mode == 1:
                    prediction = left
                elif mode == 2:
                    prediction = above
                elif mode == 3:
                    prediction = (left + above) // 2
                else:
                    p = left + above - corner
                    distances = (abs(p - left), abs(p - above), abs(p - corner))
                    prediction = (left, above, corner)[distances.index(min(distances))]
                row[x] = (row[x] + prediction) & 255
        pixels.extend(row)
        previous = row
    return width, height, bits, colour, bytes(pixels)


def diffuse_pixels(png):
    width, height, bits, colour, pixels = decode_png(png)
    if bits != 8 or colour not in (2, 6):
        raise ValueError("Diffuse PNG must be RGB8/RGBA8")
    if colour == 2:
        pixels = b"".join(pixels[i:i + 3] + b"\xff" for i in range(0, len(pixels), 3))
    return width, height, pixels


def source_path(root, declared):
    # The transferred folder is the contents of this exact manifest namespace.
    parts = PurePosixPath(declared).parts
    if len(parts) != 2 or parts[0] != "original-textures":
        raise ValueError("Unexpected source namespace")
    return safe(root, declared.removeprefix("original-textures/"))


def prepare(source, output):
    if output.is_symlink():
        raise ValueError("Symlink output root")
    source, output = source.resolve(), output.resolve()
    if source.is_relative_to(output) or output.is_relative_to(source):
        raise ValueError("Input/output overlap")
    if output.exists() and any(output.iterdir()):
        raise ValueError("Output must be fresh/empty")
    source_manifest = bounded(safe(source, "manifest.json"), 131072)
    original = json.loads(source_manifest, object_pairs_hook=unique)
    assets = original["assets"]
    if len(assets) != 3 or {a["id"] for a in assets} != ASSET_IDS:
        raise ValueError("Missing/conflicting original asset IDs")
    prepared, filenames = [], set()
    output.mkdir(parents=True, exist_ok=True)
    for asset in sorted(assets, key=lambda a: a["id"]):
        if asset["license"] != "MIT" or not asset["authorship"]:
            raise ValueError("Missing original licence/authorship")
        png = bounded(source_path(source, asset["file"]))
        rgba = bounded(source_path(source, asset["cacheFile"]))
        width, height, decoded = diffuse_pixels(png)
        if (type(asset["width"]), type(asset["height"])) != (int, int) or (width, height) != (asset["width"], asset["height"]) or len(rgba) != width * height * 4:
            raise ValueError("Diffuse dimensions/cache length mismatch")
        if sha(png) != asset["sha256"] or sha(rgba) != asset["cacheSHA256"] or rgba != decoded:
            raise ValueError("Diffuse source/hash/pixel agreement failure")
        if any(rgba[i] != 255 for i in range(3, len(rgba), 4)):
            raise ValueError("Current original hull renderer requires opaque diffuse pixels")
        entry = {"id": asset["id"], "width": width, "height": height,
                 "license": asset["license"], "authorship": asset["authorship"],
                 "pngFile": asset["id"] + ".png", "rgbaFile": asset["id"] + ".rgba",
                 "pngSHA256": sha(png), "rgbaSHA256": sha(rgba), "auxiliary": []}
        for name, data in ((entry["pngFile"], png), (entry["rgbaFile"], rgba)):
            if name in filenames:
                raise ValueError("Conflicting output asset name")
            filenames.add(name)
            safe(output, name).write_bytes(data)
        for kind in AUXILIARY:
            data = bounded(source_path(source, asset[kind + "File"]))
            aux_width, aux_height, _, _, _ = decode_png(data)
            if (aux_width, aux_height) != (width, height) or sha(data) != asset["auxiliarySHA256"][kind]:
                raise ValueError("Auxiliary dimensions/hash mismatch")
            name = asset["id"] + "-" + kind + ".png"
            safe(output, name).write_bytes(data)
            entry["auxiliary"].append({"role": kind, "file": name, "sha256": sha(data),
                                       "rendererUsage": "preserved; not consumed by current renderer"})
        prepared.append(entry)
    manifest = {"version": 1, "kind": "current-original-ship-textures",
                "sourceManifestSHA256": sha(source_manifest), "assets": prepared,
                "rendering": "Exact authored diffuse RGBA; no premultiplication/resize. Auxiliary maps are not applied; do not double-light baked relief.",
                "authoredIntegrationNotes": original.get("integration", []),
                "sourceBindingAuthority": "Advisory source bindings are preserved in SOURCE-manifest.json; use hull-bindings.json from actual hull arrays."}
    safe(output, "SOURCE-manifest.json").write_bytes(source_manifest)
    safe(output, "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=True) + "\n")
    return manifest


def hull_inventory(folder, declared_manifest, expected=94):
    paths = sorted(folder.glob("SH???-design.toml"))
    if len(paths) != expected:
        raise ValueError("Unexpected approved hull count")
    records, actual_bindings = [], {}
    for path in paths:
        if path.is_symlink():
            raise ValueError("Symlink hull input")
        with path.open("rb") as stream:
            raw = stream.read(64 * 1024 * 1024 + 1)
        if len(raw) > 64 * 1024 * 1024:
            raise ValueError("Oversized hull")
        hull = tomllib.loads(raw.decode())
        identifier = hull["proposal"]["id"]
        if path.name != identifier + "-design.toml" or identifier in actual_bindings:
            raise ValueError("Hull ID mismatch/duplicate")
        record = {"id": identifier, "sourceSHA256": sha(raw), "designs": {}}
        for name in ("design", "nativeDesign"):
            design = hull.get(name)
            if design is None:
                continue
            references, mappings = design.get("textures", []), design.get("faceTextures", [])
            ids = [r["asset"] for r in references]
            if len(ids) != len(set(ids)) or any(a not in ASSET_IDS for a in ids):
                raise ValueError("Unknown/duplicate original hull texture")
            for ref in references:
                if ref.get("license") != "MIT" or ref.get("repeat") is not True:
                    raise ValueError("Unsupported original licence/repeat policy")
            if (references or mappings) and len(mappings) != len(design["faces"]):
                raise ValueError("Hull mapping count mismatch")
            placeholders, used_indices = 0, set()
            for face, mapping in zip(design["faces"], mappings):
                index, uv = mapping["texture"], mapping["uv"]
                if type(index) is not int or index < -1 or index >= len(ids) or not isinstance(uv, list):
                    raise ValueError("Invalid original texture index")
                if index == -1 and uv == []:
                    continue
                if len(uv) != len(face) or any(not isinstance(p, list) or len(p) != 2 or not all(type(x) in (int, float) and math.isfinite(x) for x in p) for p in uv):
                    raise ValueError("Invalid original UV corners")
                placeholders += index == -1 and bool(uv)
                if index >= 0:
                    used_indices.add(index)
            used_assets = [asset for i, asset in enumerate(ids) if i in used_indices]
            record["designs"][name] = {"textures": references, "faceCount": len(design["faces"]),
                                        "usedAssets": used_assets,
                                        "mappedFaceCount": len(mappings), "untexturedCornerUVs": placeholders,
                                        "mappingSHA256": sha(json.dumps(mappings, separators=(",", ":"), allow_nan=False).encode())}
            if name == "design":
                actual_bindings[identifier] = used_assets
        records.append(record)
        del hull, raw, design, mappings, references
    declared = declared_manifest.get("bindings", {})
    differences = [{"id": identifier, "declared": declared.get(identifier), "actual": actual_bindings.get(identifier)}
                   for identifier in sorted(set(declared) | set(actual_bindings))
                   if declared.get(identifier) != actual_bindings.get(identifier)]
    return {"kind": "actual-original-hull-texture-references", "geometryOrUVRemapped": False,
            "sourceTargetShips": declared_manifest.get("targetShips", []), "hulls": records,
            "manifestBindingDifferences": differences}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--hulls", type=Path)
    parser.add_argument("--inventory", type=Path)
    args = parser.parse_args()
    try:
        manifest = prepare(args.source, args.output)
        if args.hulls:
            if args.inventory is None or args.inventory.is_symlink() or args.inventory.exists():
                raise ValueError("Inventory must be a new nonsymlink output path")
            inventory = hull_inventory(args.hulls, json.loads((args.source / "manifest.json").read_text()))
            args.inventory.parent.mkdir(parents=True, exist_ok=True)
            args.inventory.write_text(json.dumps(inventory, indent=2) + "\n")
        print("PASS: " + str(len(manifest["assets"])) + " exact original pixelsets staged")
    except (OSError, ValueError, KeyError, TypeError, zlib.error) as error:
        parser.exit(2, str(error) + "\n")


if __name__ == "__main__":
    main()
