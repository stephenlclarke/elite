#!/usr/bin/env python3
"""Revise only project geometry/liveries, retaining gameplay and source profiles."""

import argparse
import copy
import importlib.util
import json
from pathlib import Path


def module(name):
    spec = importlib.util.spec_from_file_location(
        name, Path(__file__).with_name(name + ".py")
    )
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


ship_files = module("ship-files")

# Coordinated adaptations, not historical texture/paint claims. Semantic roles
# stay fixed while a family/variant chooses its own six-material livery.
PALETTES = {
    "alliance-olive": [
        0x87977AFF,
        0x485C50FF,
        0xD1B46FFF,
        0x182622FF,
        0x579DA8FF,
        0x72D4ECFF,
    ],
    "federal-slate": [
        0x8794A6FF,
        0x47566AFF,
        0xC95C4DFF,
        0x161D2AFF,
        0x4AA1BBFF,
        0xF2AD54FF,
    ],
    "imperial-pearl": [
        0xEBE7DCFF,
        0xAABCCAFF,
        0xC9A257FF,
        0x253747FF,
        0x4698B4FF,
        0x75CFEAFF,
    ],
    "industrial-ochre": [
        0xC1A370FF,
        0x635F59FF,
        0xE4C795FF,
        0x23282DFF,
        0x668FA2FF,
        0xE0AB5AFF,
    ],
    "explorer-copper": [
        0xB77C55FF,
        0x4C626AFF,
        0xD1C4AAFF,
        0x202A30FF,
        0x58A7ADFF,
        0x78D4DAFF,
    ],
    "naval-blue": [
        0x6F8FB9FF,
        0x334A68FF,
        0xC1D3DFFF,
        0x16202EFF,
        0x63B1C9FF,
        0x63D0FFFF,
    ],
    "crimson-ceramic": [
        0xB7655DFF,
        0x6A4245FF,
        0xD5C6ABFF,
        0x261F2CFF,
        0x5CA4B3FF,
        0xF3B77DFF,
    ],
    "rescue-ivory": [
        0xDBD8C7FF,
        0x7B8A88FF,
        0xDE8A4AFF,
        0x242D35FF,
        0x5EA6BCFF,
        0x6ED6F0FF,
    ],
    "alien-jade": [
        0x5D9572FF,
        0x356A5CFF,
        0xB7B574FF,
        0x183A36FF,
        0x8FD1AEFF,
        0xB8D983FF,
    ],
    "alien-amber": [
        0xA99963FF,
        0x5F7958FF,
        0xD1BC7EFF,
        0x233D31FF,
        0xC2C99BFF,
        0xDEB868FF,
    ],
}


def palette(name):
    return [
        {"name": role, "colour": colour, "emissive": role == "engine"}
        for role, colour in zip(
            ["hull", "secondary", "trim", "dark", "cockpit", "engine"], PALETTES[name]
        )
    ]


def default_livery(ship):
    """Preserve imported geometry while making its chosen native paint explicit."""
    name = ship["name"]
    kind = (
        "organic"
        if "Thargoid" in name or "Thargon" in name
        else "viper"
        if "Viper" in name
        else "imperial"
        if "Imperial" in name
        else "freighter"
        if any(w in name for w in ["Transport", "Freighter", "Carrier", "Factory"])
        else "wedge"
    )
    selected = palette_name(ship, kind)
    d = ship["design"]
    d.update(
        paletteName=selected,
        materials=palette(selected),
        appearanceSource="Right-On Commander authored default livery",
        appearanceLicense="MIT",
        appearanceBasis="Native palette adaptation; raw source colours/UVs are retained separately. No historical texture pixels are bundled.",
    )
    vertices = d["vertices"]
    low, high = min(v[2] for v in vertices), max(v[2] for v in vertices)
    center = (low + high) / 2
    assignments = []
    for face in d["faces"]:
        a, b, c = [vertices[i] for i in face[:3]]
        ab, ac = [b[i] - a[i] for i in range(3)], [c[i] - a[i] for i in range(3)]
        normal = [
            ab[1] * ac[2] - ab[2] * ac[1],
            ab[2] * ac[0] - ab[0] * ac[2],
            ab[0] * ac[1] - ab[1] * ac[0],
        ]
        length = sum(x * x for x in normal) ** 0.5
        z = sum(vertices[i][2] for i in face) / len(face)
        assignments.append(
            2
            if kind != "organic" and abs(z - center) < (high - low) * 0.045
            else 1
            if length and abs(normal[0]) / length > 0.75
            else 0
        )
    d["faceMaterials"] = assignments
    return ship


def shape(ship):
    ident, name = int(ship["id"][2:]), ship["name"]
    if 112 <= ident <= 123:
        return "organic"
    if name.startswith("Alliance "):
        return "alliance"
    if name.startswith("Krait "):
        return "krait"
    if name == "Mandalay":
        return "mandalay"
    if name.startswith("Viper "):
        return "viper"
    if name.startswith("Type-"):
        return "type" + name.split("-")[1].split()[0]
    if name.startswith("Federal "):
        return "federal"
    if name.startswith("Imperial "):
        return "imperial"
    if name.startswith("Anaconda"):
        return "anaconda"
    if name.startswith("Cobra "):
        return "cobra"
    if name.startswith("Python "):
        return "python"
    if name.startswith("Asp "):
        return "asp"
    if name.startswith("Diamondback "):
        return "diamondback"
    return {
        "capital": "carrier",
        "ring": "ring",
        "outrigger": "utility",
        "petals": "organic",
    }.get(ship["design"]["recipe"]["family"], ship["design"]["recipe"]["family"])


def palette_name(ship, kind):
    if kind == "organic":
        return "alien-jade" if int(ship["id"][2:]) % 2 else "alien-amber"
    if kind == "alliance":
        return "alliance-olive"
    if kind in {"imperial", "liner"}:
        return "imperial-pearl"
    if kind in {"federal", "carrier"}:
        return "federal-slate"
    if kind.startswith("type") or kind in {"freighter", "ring"}:
        return "industrial-ochre"
    if kind in {"mandalay", "diamondback", "asp"}:
        return "explorer-copper"
    if kind == "viper":
        return "naval-blue"
    return ["naval-blue", "rescue-ivory", "crimson-ceramic", "explorer-copper"][
        int(ship["id"][2:]) % 4
    ]


def revise(ship, generator):
    original = copy.deepcopy(ship)
    recipe = copy.deepcopy(ship["design"]["recipe"])
    kind = shape(ship)
    recipe.update(
        revision=2,
        shape=kind,
        name=ship["name"],
        paletteName=palette_name(ship, kind),
        detailStyle="organic"
        if kind == "organic"
        else "clean"
        if kind in {"imperial", "liner"}
        else "armour",
    )
    recipe["palette"] = palette(recipe["paletteName"])
    design = generator.design(recipe)
    design["recipe"] = recipe
    ship["design"] = design
    assert all(ship.get(k) == original.get(k) for k in original if k != "design")
    return ship


def source_appearance(ship, incoming):
    """Mirror verified archival facts, including removal of obsolete mappings."""
    design = ship["design"]
    assert (
        design["vertices"] == incoming["vertices"]
        and design["faces"] == incoming["faces"]
    ), "Source geometry changed: " + ship["id"]
    for key in ["sourceFaceColours", "sourceTextures", "sourceFaceTextures"]:
        if key in incoming:
            design[key] = copy.deepcopy(incoming[key])
        else:
            design.pop(key, None)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument(
        "--source-models",
        type=Path,
        help="Verified staged ShowroomModels.json; imports archival appearance only after exact geometry comparison",
    )
    args = parser.parse_args()
    generator = module("refined-designs")
    evidence = []
    sources = (
        {m["id"]: m for m in json.loads(args.source_models.read_text())}
        if args.source_models
        else {}
    )
    for ship in ship_files.read_ships():
        recipe = ship["design"].get("recipe")
        if not recipe:
            before = copy.deepcopy(ship)
            incoming = sources.get(ship["model"])
            if incoming:
                source_appearance(ship, incoming)
            default_livery(ship)
            if args.check:
                assert before == ship, "Stale source livery: " + ship["id"]
            else:
                ship_files.write_ship(
                    ship_files.SHIP_FOLDER / (ship["id"] + ".toml"), ship
                )
            continue
        if recipe.get("family") == "liberator-dsv2":
            continue
        before = ship["design"]
        result = revise(ship, generator)
        if args.check:
            assert before == result["design"], "Stale authored design: " + ship["id"]
        else:
            ship_files.write_ship(
                ship_files.SHIP_FOLDER / (ship["id"] + ".toml"), result
            )
        evidence.append(
            {
                "id": ship["id"],
                "name": ship["name"],
                "style": result["design"]["recipe"]["detailStyle"],
                "family": result["design"]["recipe"]["shape"],
                "vertices": len(result["design"]["vertices"]),
                "faces": len(result["design"]["faces"]),
                "palette": result["design"]["paletteName"],
            }
        )
    print(
        f"{len(evidence)} project hull recipes "
        + ("verified" if args.check else "revised")
    )
    if not args.check:
        Path("reports/hull-designs").mkdir(parents=True, exist_ok=True)
        Path("reports/hull-designs/coverage.json").write_text(
            json.dumps(evidence, indent=2) + "\n"
        )


if __name__ == "__main__":
    main()
