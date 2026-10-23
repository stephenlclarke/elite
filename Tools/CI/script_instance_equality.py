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


def instance_payload(body: str) -> str:
    """Inventory actual heap fields rather than the facade's one reference."""
    marker = "  private final class Storage: @unchecked Sendable {"
    if body.count(marker) != 1:
        raise ValueError("Missing or ambiguous private instance payload")
    payload = body.split(marker, 1)[1].split("\n  }", 1)[0]
    return "\n".join(line[2:] if line.startswith("  ") else line for line in payload.splitlines())


def stored_fields(body: str, type_name: str) -> list[str]:
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
    return fields


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
    inventory_body = body
    arguments = "lhs, rhs"
    if type_name == "ScriptInstanceValue":
        inventory_body = instance_payload(body)
        if stored_fields(body, type_name) != ["payload"]:
            raise ValueError("Facade must store only its private payload")
        arguments = "lhs.payload, rhs.payload"
    fields = stored_fields(inventory_body, type_name)
    helpers = re.findall(
        r"private static func (equal\w+)\([^)]*\)\s*->\s*Bool\s*\{\s*"
        r"lhs\.(\w+)(!\.value)? == rhs\.(\w+)(!\.value)?\s*\}",
        body,
    )
    if any(left != right or left_path != right_path for _, left, left_path, right, right_path in helpers):
        raise ValueError("Equality must compare the same member on both operands")
    mapping = {name: left for name, left, _, _, _ in helpers}
    wrapped = set(re.findall(r"^  var (\w+): Field<[^\n]+>\?", inventory_body, re.M))
    if any(bool(path) != (field in wrapped) for _, field, path, _, _ in helpers):
        raise ValueError("Equality must compare logical field values, not storage handles")
    if len(mapping) != len(helpers):
        raise ValueError("Duplicate equality helpers")
    calls = re.findall(rf"guard (equal\w+)\({re.escape(arguments)}\) else \{{ return false \}}", body)
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
        f"guard {name}({arguments}) else {{ return false }}" for name in calls
    ) + "return true"
    if entry is None or re.sub(r"\s+", "", entry[1]) != re.sub(r"\s+", "", expected):
        raise ValueError("Equality must short circuit through every checked comparison")
    return fields


def inspect_instance_storage(source: str) -> list[str]:
    """Fail closed if a logical field loses mutation, clone or wire coverage."""
    body = source.split("private struct ScriptInstanceValue:", 1)[1].split(
        "/// One copy-on-write value;", 1
    )[0]
    payload = instance_payload(body)
    fields = inspect_equality(source)
    declarations = re.findall(r"^  (let|var) (\w+): ([^\n{]+)$", payload, re.M)
    if [name for _, name, _ in declarations] != fields:
        raise ValueError("Payload declarations need explicit storage coverage")
    compact = lambda text: re.sub(r"\s+", "", text)
    uniqueness = re.search(r"private mutating func ensureUniqueStorage\(\) \{(.*?)\n  \}", body, re.S)
    expected_uniqueness = "if !isKnownUniquelyReferenced(&payload) { payload = Storage(copying: payload) }"
    if uniqueness is None or compact(uniqueness[1]) != compact(expected_uniqueness):
        raise ValueError("Mutations must clone shared payload storage")
    mutable = [name for mode, name, _ in declarations if mode == "var"]
    wrapped = {
        name: match[1]
        for _, name, declaration in declarations
        if (match := re.fullmatch(r"Field<(.+)>\?", declaration))
    }
    for mode, name, _ in declarations:
        accessor = re.search(rf"^  var {name}: [^\n]+ \{{(.*?)^  \}}", body, re.M | re.S)
        projection = name + ("!.value" if name in wrapped else "")
        expected = f"_read {{ yield payload.{projection} }}"
        if mode == "var":
            expected += (
                f"set {{ ensureUniqueStorage() payload.{projection} = newValue }}"
                f"_modify {{ ensureUniqueStorage() yield &payload.{projection} }}"
            )
        if accessor is None or compact(accessor[1]) != compact(expected):
            raise ValueError(f"Mutable projections must detach before write/yield: {name}")
    copies = re.findall(
        r"private func (copy\w+)\(from source: Storage\) \{\s*(\w+) = source\.(\w+)\s*\}",
        payload,
    )
    if any(left != right for _, left, right in copies):
        raise ValueError("Clone must copy the same logical member")
    if [left for _, left, _ in copies] != mutable:
        raise ValueError("Clone must cover every mutable field once in order")
    clone = re.search(r"convenience init\(copying source: Storage\) \{(.*?)\n  \}", payload, re.S)
    expected = "self.init(emptyID: source.id, definition: source.definition, version: source.version, digest: source.digest)"
    expected += "".join(f"{helper}(from: source)" for helper, _, _ in copies)
    if clone is None or compact(clone[1]) != compact(expected):
        raise ValueError("Clone must allocate first then call each bounded field helper")
    for helper, _, _ in copies:
        if not re.search(rf"@inline\(never\)\s+private func {helper}\(", payload):
            raise ValueError("Clone helpers must retain separate frames")
    default_init = re.search(r"convenience init\(id: UUID, definition: String, version: String, digest: String\) \{(.*?)\n  \}", payload, re.S)
    expected = "self.init(emptyID: id, definition: definition, version: version, digest: digest)"
    for name, value_type in wrapped.items():
        helper = "initialize" + name[0].upper() + name[1:]
        expected += f"{helper}()"
        match = re.search(rf"@inline\(never\)\s+private func {helper}\(\) \{{(.*?)\n  \}}", payload, re.S)
        if match is None or compact(match[1]) != compact(f"{name} = Field<{value_type}>()"):
            raise ValueError("Default construction must initialize every field handle separately")
    if default_init is None or compact(default_init[1]) != compact(expected):
        raise ValueError("Default construction must cover every field handle once in order")
    empty_init = re.search(r"private init\(emptyID id: UUID, definition: String, version: String, digest: String\) \{(.*?)\n  \}", payload, re.S)
    expected = "self.id = id self.definition = definition self.version = version self.digest = digest"
    if empty_init is None or compact(empty_init[1]) != compact(expected):
        raise ValueError("Clone allocation must not construct default child values")
    field = body.split("  private struct Field<Value: Sendable>: Sendable {", 1)[1].split("\n  }", 1)[0]
    field = re.sub(r"//[^\n]*", "", field)
    expected = """
        private final class InitialNil { var value: Value? }
        private var values: [Value?]
        init() {
          let initial = InitialNil()
          values = withUnsafePointer(to: &initial.value) { source in
            Array(unsafeUninitializedCapacity: 1) { destination, initializedCount in
              destination.baseAddress!.initialize(from: source, count: 1)
              initializedCount = 1
            }
          }
        }
        init(_ value: consuming Value?) { values = [consume value] }
        var value: Value? {
          _read { yield values[0] }
          set { values[0] = newValue }
          _modify { yield &values[0] }
        }
    """
    if compact(field) != compact(expected):
        raise ValueError("Field storage must retain typed Array COW and initialized heap-to-heap nil construction")
    keys = re.search(r"private enum CodingKeys: String, CodingKey \{(.*?)\n  \}", body, re.S)
    if keys is None or re.findall(r"case (\w+)", keys[1]) != fields:
        raise ValueError("Codec must retain every logical key once in order")
    decoder = re.search(r"init\(from decoder: any Decoder\) throws \{(.*?)\n  \}", payload, re.S)
    encoder = re.search(r"func encode\(to encoder: any Encoder\) throws \{(.*?)\n  \}", payload, re.S)
    expected_decoder = "let values = try decoder.container(keyedBy: CodingKeys.self)"
    expected_encoder = "var values = encoder.container(keyedBy: CodingKeys.self)"
    for mode, name, declaration in declarations:
        field_type = wrapped[name] + "?" if name in wrapped else declaration.split(" = ", 1)[0]
        optional = field_type.endswith("?")
        value_type = field_type[:-1] if optional else field_type
        suffix = name[0].upper() + name[1:]
        decode = f"{name} = try values.decode{'IfPresent' if optional else ''}({value_type}.self, forKey: .{name})"
        projection = name + ("!.value" if name in wrapped else "")
        encode = f"try values.encode{'IfPresent' if optional else ''}({projection}, forKey: .{name})"
        if name in wrapped:
            decode = decode.replace(f"{name} = ", f"{name} = Field(") + ")"
        if mode == "let":
            expected_decoder += decode
        else:
            expected_decoder += f"try decode{suffix}(from: values)"
            helper = re.search(rf"private func decode{suffix}\([^{{]+\)\s*throws\s*\{{(.*?)\n  \}}", payload, re.S)
            if helper is None or compact(helper[1]) != compact(decode):
                raise ValueError(f"Codec must preserve required/optional decoding: {name}")
        expected_encoder += f"try encode{suffix}(to: &values)"
        helper = re.search(rf"private func encode{suffix}\([^{{]+\)\s*throws\s*\{{(.*?)\n  \}}", payload, re.S)
        if helper is None or compact(helper[1]) != compact(encode):
            raise ValueError(f"Codec must preserve optional omission and field encoding: {name}")
    if decoder is None or compact(decoder[1]) != compact(expected_decoder):
        raise ValueError("Codec must decode every field once in order")
    if encoder is None or compact(encoder[1]) != compact(expected_encoder):
        raise ValueError("Codec must encode every field once in order")
    return fields


if __name__ == "__main__":
    inspect_instance_storage(SOURCE.read_text())
    for name in ("ScriptInstanceValue", "ScriptEngineState", "Commander"):
        path = COMMANDER_SOURCE if name == "Commander" else SOURCE
        inventory = inspect_equality(path.read_text(), name)
        print(f"{name} equality inventory: {len(inventory)} stored fields checked")
