#!/usr/bin/env python3
"""Reject omitted, duplicated or reordered stored-field equality comparisons."""

from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Sources/EliteCore/ScriptMissionState.swift"
COMMANDER_SOURCE = ROOT / "Sources/EliteCore/Game.swift"


ORIGINAL_INFERRED_DECLARATIONS = {
    "ScriptEngineState": {
        "flightSeconds": "= 0.0",
        "localSeconds": "= 0.0",
        "calendarSeconds": "= 0.0",
        "transitSeconds": "= 0.0"
    },
    "Commander": {
        "originalMarkets": "= OriginalLiveMarkets()",
        "name": "= NewCommanderDefaults.name",
        "credits": "= NewCommanderDefaults.credits",
        "fuel": "= NewCommanderDefaults.fuel",
        "galaxy": "= NewCommanderDefaults.galaxy",
        "system": "= NewCommanderDefaults.system",
        "cargo": "= Array(repeating: 0, count: 17)",
        "missiles": "= 3",
        "kills": "= 0",
        "legal": "= 0",
        "unlimitedMissiles": "= false",
        "unlimitedCargo": "= false",
        "unlimitedCash": "= false",
        "unlimitedFuel": "= false",
        "unlimitedJumps": "= false",
        "autoTrade": "= false",
        "speech": "= false",
        "executive": "= false"
    }
}


def inspect_equality(source: str, type_name: str = "ScriptInstanceValue") -> list[str]:
    """Check the private value's explicit equality against its stored declarations."""
    if type_name == "ScriptInstanceValue":
        body = source.split("private struct ScriptInstanceValue:", 1)[1].split(
            "/// One copy-on-write value;", 1
        )[0]
    elif type_name == "ScriptEngineState":
        body = source.split("public struct ScriptEngineState:", 1)[1].split("\n}\n", 1)[0]
    elif type_name == "Commander":
        body = source.split("public struct Commander:", 1)[1].split("\n}\n", 1)[0]
    else:
        raise ValueError("Unsupported equality type")
    fields = []
    lines = body.splitlines()
    for index, line in enumerate(lines):
        match = re.fullmatch(r"  (?![ \t])(.*?)\b(?:let|var)\s+(\w+)(.*)", line)
        if not match or match[1].lstrip().startswith("//"):
            continue
        if re.search(r"\b(?:static|class)\b", match[1]):
            continue
        tail = match[3].strip()
        declaration = tail
        if "{" in tail and "}" not in tail:
            for continuation in lines[index + 1 :]:
                declaration += "\n" + continuation
                if continuation.startswith("  }"):
                    break
        if re.search(r"\b(?:willSet|didSet)\b", declaration):
            raise ValueError("Observed stored declarations need explicit inventory support")
        flattened = re.sub(r'"(?:\\.|[^"\\])*"', "", tail)
        previous = None
        while previous != flattened:
            previous = flattened
            flattened = re.sub(
                r"\([^()]*\)|\[[^\[\]]*\]|<[^<>]*>|\{[^{}]*\}", "", flattened
            )
        if "," in flattened:
            raise ValueError("Multiple bindings need explicit inventory support")
        if not tail.startswith(":"):
            original_inferred = (
                ORIGINAL_INFERRED_DECLARATIONS.get(type_name, {}).get(match[2]) == tail
            )
            if not original_inferred:
                raise ValueError("Stored declarations need an explicit type for inventory checks")
        if "{" in tail.split("=", 1)[0]:
            continue  # Computed properties do not participate in synthesized equality.
        fields.append(match[2])
    if not fields or len(fields) != len(set(fields)):
        raise ValueError("Missing or duplicated stored-field declarations")
    helpers = re.findall(
        r"private static func (equal\w+)\([^)]*\)\s*->\s*Bool\s*\{\s*"
        r"lhs\.(\w+) == rhs\.(\w+)\s*\}",
        body,
    )
    if any(left != right for _, left, right in helpers):
        raise ValueError("Equality must compare the same member on both operands")
    mapping = {name: left for name, left, _ in helpers}
    if len(mapping) != len(helpers):
        raise ValueError("Duplicate equality helpers")
    calls = re.findall(r"guard (equal\w+)\(lhs, rhs\) else \{ return false \}", body)
    try:
        compared = [mapping[name] for name in calls]
    except KeyError as error:
        raise ValueError("Equality calls an unchecked helper") from error
    if compared != fields or len(helpers) != len(fields):
        raise ValueError("Equality must compare every stored field once in declaration order")
    entry = re.search(
        r"static func == \([^)]*\)\s*->\s*Bool\s*\{(.*?)\n  \}", body, re.S
    )
    expected = "".join(
        f"guard {name}(lhs, rhs) else {{ return false }}" for name in calls
    ) + "return true"
    if entry is None or re.sub(r"\s+", "", entry[1]) != re.sub(r"\s+", "", expected):
        raise ValueError("Equality must short circuit through every checked comparison")
    return fields


if __name__ == "__main__":
    for name in ("ScriptInstanceValue", "ScriptEngineState", "Commander"):
        path = COMMANDER_SOURCE if name == "Commander" else SOURCE
        inventory = inspect_equality(path.read_text(), name)
        print(f"{name} equality inventory: {len(inventory)} stored fields checked")
