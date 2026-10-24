#!/usr/bin/env python3
"""Generate pure Swift controls and help copy from a validated JSON authority."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys


BINDINGS = (
    ("change_weapon", "changeWeapon", "W", "Change weapon"),
    ("fire", "fire", "Return", "Fire"),
    ("ecm", "ecm", "E", "ECM"),
    ("release_hold", "releaseHold", "Q", "Release hold"),
    ("next_target", "nextTarget", "Tab", "Next target"),
    ("target_filter", "targetFilter", "F", "Target filter"),
)
TOPICS = (
    "flight", "combat", "targeting", "mining", "salvage", "emp", "ecm",
    "navigation", "equipment", "shipyard", "inventory", "market", "missions",
    "status", "settings",
)
WEAPONS = ("Main Laser", "Mining Laser", "Salvage Cutter", "EMP Blaster")
WEAPON_CASES = ("mainLaser", "miningLaser", "salvageCutter", "empBlaster")
INDICATOR_TEXT = (
    "label", "placement", "content", "stateAuthority", "updates", "presentation",
    "exampleNotice", "help",
)
TEXT_FIELDS = ("scope", "footer", "automaticSelection", "asteroidDestruction")
LIST_FIELDS = ("helpPolicy", "selectionRules", "holdRules")
SWIFT_PATH = Path("Sources/EliteCore/FlightControlAuthority.swift")
MARKDOWN_PATH = Path("docs/FLIGHT-CONTROLS.generated.md")
MAX_AUTHORITY_BYTES = 1024 * 1024


def unique_object(pairs: list) -> dict:
    """JSON must not silently replace a repeated object member."""
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate JSON key: {key}")
        result[key] = value
    return result


def reject_constant(value: str) -> None:
    raise ValueError(f"Non-finite JSON value: {value}")


def fields(value: object, expected: set, label: str) -> None:
    if not isinstance(value, dict) or set(value) != expected:
        raise ValueError(f"{label}: missing or unexpected fields")


def text(value: object, label: str) -> None:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{label}: expected non-empty text")
    if any(0xD800 <= ord(char) <= 0xDFFF for char in value):
        raise ValueError(f"{label}: isolated Unicode surrogate")


def text_list(value: object, label: str) -> None:
    if not isinstance(value, list) or not value:
        raise ValueError(f"{label}: expected non-empty text list")
    for item in value:
        text(item, label)


def records(value: object, expected_ids: tuple, keys: set, label: str) -> dict:
    if not isinstance(value, list):
        raise ValueError(f"{label}: expected list")
    indexed = {}
    for item in value:
        fields(item, keys, label)
        for key in keys:
            text(item[key], f"{label}.{key}")
        identifier = item["id"]
        if identifier in indexed:
            raise ValueError(f"{label}: duplicate ID {identifier}")
        indexed[identifier] = item
    if set(indexed) != set(expected_ids):
        raise ValueError(f"{label}: missing or extra IDs")
    return indexed


def validate(data: dict) -> None:
    required = {
        "schema", "bindings", "weaponNames", "helpTopics", "provenance",
        "weaponIndicator", *TEXT_FIELDS, *LIST_FIELDS,
    }
    fields(data, required, "authority")
    if data["schema"] != "l337.flight-controls/1":
        raise ValueError("Unsupported authority schema")
    for key in TEXT_FIELDS:
        text(data[key], key)
    for key in LIST_FIELDS:
        text_list(data[key], key)
    bindings = records(
        data["bindings"], tuple(item[0] for item in BINDINGS),
        {"id", "key", "action", "detail"}, "bindings",
    )
    seen_keys = set()
    for identifier, _, key, action in BINDINGS:
        binding = bindings[identifier]
        if binding["key"].casefold() in seen_keys:
            raise ValueError("Duplicate binding key")
        seen_keys.add(binding["key"].casefold())
        if (binding["key"], binding["action"]) != (key, action):
            raise ValueError(f"Inconsistent key or action label: {identifier}")
    footer = " | ".join(f"{key.upper()}: {action.upper()}" for _, _, key, action in BINDINGS)
    if data["footer"] != footer:
        raise ValueError("Footer conflicts with binding labels")
    if data["weaponNames"] != list(WEAPONS):
        raise ValueError("Missing, extra or stale weapon label")
    topics = records(data["helpTopics"], TOPICS, {"id", "title", "detail"}, "helpTopics")
    for topic in topics.values():
        if re.search(r"\bchange tool\b", topic["title"] + " " + topic["detail"], re.IGNORECASE):
            raise ValueError("Stale help label: use Change weapon")
    indicator = data["weaponIndicator"]
    fields(indicator, {*INDICATOR_TEXT, "states", "examples"}, "weaponIndicator")
    for key in INDICATOR_TEXT:
        text(indicator[key], f"weaponIndicator.{key}")
    for key in ("states", "examples"):
        text_list(indicator[key], f"weaponIndicator.{key}")
    if indicator["label"] != "WEAPON" or not indicator["help"].startswith(footer + "."):
        raise ValueError("Weapon indicator conflicts with shared labels")
    provenance = data["provenance"]
    fields(provenance, {"controlsSHA256", "sources"}, "provenance")
    if not isinstance(provenance["sources"], list) or not provenance["sources"]:
        raise ValueError("Missing source provenance")
    paths = set()
    for source in provenance["sources"]:
        fields(source, {"path", "sha256"}, "source")
        text(source["path"], "source.path")
        path = Path(source["path"])
        if path.is_absolute() or ".." in path.parts or source["path"] in paths:
            raise ValueError("Source provenance must use unique relative paths")
        paths.add(source["path"])
        if not isinstance(source["sha256"], str) or not re.fullmatch(r"[a-f0-9]{64}", source["sha256"]):
            raise ValueError("Invalid source SHA-256")
    control_sources = [s for s in provenance["sources"] if s["path"] == "inputs/controls.json"]
    if len(control_sources) != 1 or control_sources[0]["sha256"] != provenance["controlsSHA256"]:
        raise ValueError("Controls fingerprint conflicts with provenance")


def load_authority(path: Path) -> tuple:
    with path.open("rb") as stream:
        raw = stream.read(MAX_AUTHORITY_BYTES + 1)
    if len(raw) > MAX_AUTHORITY_BYTES:
        raise ValueError("Authority exceeds 1 MiB")
    data = json.loads(raw, object_pairs_hook=unique_object, parse_constant=reject_constant)
    validate(data)
    return data, hashlib.sha256(raw).hexdigest()


def swift_string(value: str) -> str:
    """Escape Swift interpolation, quotes, controls and Unicode without evaluation."""
    escaped = []
    for char in value:
        if char == "\\":
            escaped.append("\\\\")
        elif char == '"':
            escaped.append('\\"')
        elif ord(char) < 32 or ord(char) >= 127:
            escaped.append(f"\\u{{{ord(char):x}}}")
        else:
            escaped.append(char)
    return '"' + "".join(escaped) + '"'


def swift_array(name: str, values: list) -> list:
    return [f"  public static let {name}: [String] = [", *[
        f"    {swift_string(value)}," for value in values
    ], "  ]"]


def swift_constant(name: str, value: str) -> list:
    prefix = f"  public static let {name} ="
    literal = swift_string(value)
    if len(prefix) + 1 + len(literal) <= 100:
        return [f"{prefix} {literal}"]
    return [prefix, f"    {literal}"]


def swift_detail(value: str) -> list:
    literal = swift_string(value)
    prefix = "          detail:"
    if len(prefix) + 1 + len(literal) <= 100:
        return [f"{prefix} {literal}"]
    return [prefix, f"            {literal}"]


def render_swift(data: dict, digest: str) -> str:
    quote = swift_string
    bindings = {item["id"]: item for item in data["bindings"]}
    topics = {item["id"]: item for item in data["helpTopics"]}
    lines = [
        "// Generated by Tools/generate-flight-controls.py; edit config/flight-controls.json.",
        f"// Authority SHA-256: {digest}",
        "// Pure display authority; native input, readiness and hold state are owned by the runtime.",
        "public enum FlightControlAuthority: Sendable {",
        "  public enum ActionID: String, CaseIterable, Sendable {",
    ]
    lines += [f"    case {case} = {quote(identifier)}" for identifier, case, _, _ in BINDINGS]
    lines += ["", "    public var binding: Binding {", "      switch self {"]
    for identifier, case, _, _ in BINDINGS:
        item = bindings[identifier]
        lines += [f"      case .{case}:", "        return Binding(",
                  f"          id: self, key: {quote(item['key'])},",
                  f"          label: {quote(item['action'])},",
                  *swift_detail(item["detail"]), "        )"]
    lines += ["      }", "    }", "  }", "", "  public struct Binding: Sendable {",
              "    public let id: ActionID", "    public let key: String",
              "    public let label: String", "    public let detail: String", "  }", "",
              "  public enum Weapon: String, CaseIterable, Sendable {"]
    lines += [f"    case {case} = {quote(name)}" for case, name in zip(WEAPON_CASES, data["weaponNames"])]
    lines += ["  }", "", "  public enum HelpTopicID: String, CaseIterable, Sendable {"]
    lines += [f"    case {identifier}" for identifier in TOPICS]
    lines += ["", "    public var topic: HelpTopic {", "      switch self {"]
    for identifier in TOPICS:
        topic = topics[identifier]
        lines += [f"      case .{identifier}:", "        return HelpTopic(",
                  f"          id: self, title: {quote(topic['title'])},",
                  *swift_detail(topic["detail"]), "        )"]
    lines += ["      }", "    }", "  }", "", "  public struct HelpTopic: Sendable {",
              "    public let id: HelpTopicID", "    public let title: String",
              "    public let detail: String",
              '    public var flightHeading: String { "Flight controls" }',
              "    public var bindings: [Binding] { FlightControlAuthority.bindings }",
              "    public var footer: String { FlightControlAuthority.footer }",
              "    public var menuContext: String { FlightControlAuthority.scope }", "  }", "",
              "  public static let bindings: [Binding] = ActionID.allCases.map { $0.binding }",
              "  public static let helpTopics: [HelpTopic] = HelpTopicID.allCases.map { $0.topic }",
              "  public static let weaponNames: [String] = Weapon.allCases.map { $0.rawValue }"]
    lines += swift_constant("authoritySHA256", digest)
    lines += swift_constant("originalControlsSHA256", data["provenance"]["controlsSHA256"])
    for key in TEXT_FIELDS:
        lines += swift_constant(key, data[key])
    for key in LIST_FIELDS:
        lines += swift_array(key, data[key])
    for key in INDICATOR_TEXT:
        name = "weaponIndicator" + key[0].upper() + key[1:]
        lines += swift_constant(name, data["weaponIndicator"][key])
    lines += swift_array("weaponIndicatorStates", data["weaponIndicator"]["states"])
    lines += swift_array("weaponIndicatorExamples", data["weaponIndicator"]["examples"])
    lines += ["}", ""]
    return "\n".join(lines)


def markdown_text(value: str) -> str:
    # Encode structural characters so data cannot introduce links/HTML/blocks.
    return "".join(f"&#{ord(char)};" if char in "\\`*_{}[]<>|&#" or ord(char) < 32 or ord(char) >= 127
                   else char for char in value)


def render_markdown(data: dict, digest: str) -> str:
    md = markdown_text
    bindings = {item["id"]: item for item in data["bindings"]}
    topics = {item["id"]: item for item in data["helpTopics"]}
    block = ["| Key | Action | Detail |", "| --- | --- | --- |"]
    for identifier, _, _, _ in BINDINGS:
        item = bindings[identifier]
        block.append(f"| {md(item['key'])} | {md(item['action'])} | {md(item['detail'])} |")
    block += ["", f"`{data['footer']}`", ""]
    lines = ["# Shared flight controls", "",
             "Generated by `Tools/generate-flight-controls.py` from `config/flight-controls.json`.", "",
             f"Authority SHA-256: `{digest}`.", "",
             "This authority requires native integration and runtime verification.", ""]
    for identifier in TOPICS:
        topic = topics[identifier]
        title = md(topic["title"])
        lines += [f"## {title} ({identifier})", "", f"Topic ID: `{identifier}`.", "", md(topic["detail"]), "",
                  f"### Flight controls: {title} ({identifier})", "", *block,
                  f"### Separate menu context: {title} ({identifier})", "", md(data["scope"]), ""]
    lines += ["## Selection and hold semantics", "", md(data["automaticSelection"]), ""]
    for key in ("selectionRules", "holdRules", "helpPolicy"):
        lines += [f"- {md(item)}" for item in data[key]] + [""]
    lines += ["## Weapon labels and actual activity", "", *[f"- {md(item)}" for item in data["weaponNames"]], ""]
    indicator = data["weaponIndicator"]
    lines += [md(indicator[key]) + "\n" for key in INDICATOR_TEXT]
    lines += ["States: " + ", ".join(md(item) for item in indicator["states"]) + ".", ""]
    lines += [f"- {md(item)}" for item in indicator["examples"]]
    lines += ["", "## Asteroid destruction", "", md(data["asteroidDestruction"]), "",
              "## Source provenance", ""]
    lines += [f"- {md(source['path'])}: `{source['sha256']}`." for source in data["provenance"]["sources"]]
    return "\n".join(lines) + "\n"


def output_path(root: Path, relative: Path) -> Path:
    """Only fixed generated paths are writable, including through symlink parents."""
    path = root / relative
    if not path.resolve().is_relative_to(root):
        raise ValueError(f"Output escapes repo root: {relative}")
    for part in (path, *path.parents):
        if part == root:
            break
        if part.is_symlink():
            raise ValueError(f"Symlink output is not supported: {relative}")
    return path


def main(argv: list = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--input", type=Path, help="JSON authority; defaults to repo-root/config/flight-controls.json")
    parser.add_argument("--check", action="store_true", help="Report missing/stale output without writing")
    options = parser.parse_args(argv)
    try:
        root = options.repo_root.resolve()
        data, digest = load_authority(options.input or root / "config/flight-controls.json")
        generated = {SWIFT_PATH: render_swift(data, digest), MARKDOWN_PATH: render_markdown(data, digest)}
        paths = {relative: output_path(root, relative) for relative in generated}
        stale = []
        for relative, content in generated.items():
            path = paths[relative]
            expected = content.encode("utf-8")
            if options.check:
                if not path.is_file() or path.read_bytes() != expected:
                    stale.append(str(relative))
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(expected)
        if stale:
            print("Stale or missing output: " + ", ".join(stale), file=sys.stderr)
            return 1
        print("Flight controls check passed" if options.check else "Generated Swift authority and 15 help topics")
        return 0
    except (OSError, ValueError) as error:
        print(f"Flight controls error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
