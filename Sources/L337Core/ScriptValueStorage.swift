import Foundation
import os

/// Per-operation codec configuration; no decoder or mutable budget is shared between turns.
enum ScriptValueStorage {
  static let codec = "tagged-script-values-v1"
  static let modeKey = CodingUserInfoKey(rawValue: "elite.script-value-mode")!
  static let budgetKey = CodingUserInfoKey(rawValue: "elite.script-value-budget")!
  static func encoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.userInfo[modeKey] = true
    return encoder
  }
  static func decoder(typed: Bool) -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.userInfo[modeKey] = typed
    decoder.userInfo[budgetKey] = ScriptValueDecodeBudget()
    return decoder
  }
}

/// Decoder-local semantic limits match the interpreter wire, including every nested value.
final class ScriptValueDecodeBudget: Sendable {
  private struct State: Sendable {
    var depth = 0
    var values = 0
    var bytes = 0
    var totalBytes = 0
  }
  private let state = OSAllocatedUnfairLock(initialState: State())
  func enter() throws {
    try state.withLock { value in
      if value.depth == 0 {
        value.values = 0
        value.bytes = 0
      }
      guard value.depth < 32, value.values < 16384 else {
        throw MissionPackError("Saved script value depth or count limit exceeded.")
      }
      value.depth += 1
      value.values += 1
    }
  }
  func leave() { state.withLock { $0.depth -= 1 } }
  func charge(_ amount: Int) throws {
    try state.withLock { value in
      guard amount >= 0, amount <= 262144 - value.bytes, amount <= 33_554_432 - value.totalBytes
      else {
        throw MissionPackError("Saved script value byte limit exceeded.")
      }
      value.bytes += amount
      value.totalBytes += amount
    }
  }
}

private struct ScriptStorageKey: CodingKey {
  let stringValue: String
  var intValue: Int? { Int(stringValue) }
  init(_ value: String) { stringValue = value }
  init?(stringValue: String) { self.init(stringValue) }
  init?(intValue: Int) { self.init(String(intValue)) }
}

extension ScriptValue {
  static func decodeStored(
    from decoder: any Decoder, typed: Bool,
    budget: ScriptValueDecodeBudget?
  ) throws -> ScriptValue {
    if !typed { return try decodePrimitive(from: decoder, budget: budget) }
    let container = try decoder.container(keyedBy: ScriptStorageKey.self)
    let type = ScriptStorageKey("type")
    let value = ScriptStorageKey("value")
    let kind = try container.decode(String.self, forKey: type)
    let expected: Set<String> = kind == "null" ? ["type"] : ["type", "value"]
    guard Set(container.allKeys.map(\.stringValue)) == expected else {
      throw MissionPackError("Invalid saved script value fields.")
    }
    switch kind {
    case "null":
      try budget?.charge(1)
      return .null
    case "bool":
      try budget?.charge(1)
      return .bool(try container.decode(Bool.self, forKey: value))
    case "integer":
      try budget?.charge(9)
      return .integer(try container.decode(Int64.self, forKey: value))
    case "number":
      let raw = try container.decode(String.self, forKey: value)
      guard raw.utf8.count == 16,
        raw.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
        let bits = UInt64(raw, radix: 16)
      else { throw MissionPackError("Invalid saved floating bits.") }
      let number = Double(bitPattern: bits)
      guard number.isFinite else { throw MissionPackError("Saved script numbers must be finite.") }
      try budget?.charge(9)
      return .number(number)
    case "string":
      let text = try container.decode(String.self, forKey: value)
      try chargeString(text, budget: budget)
      return .string(text)
    case "array":
      let nested = try container.superDecoder(forKey: value)
      try checkArray(nested, budget: budget)
      return .array(try container.decode([ScriptValue].self, forKey: value))
    case "object":
      let nested = try container.superDecoder(forKey: value)
      try checkObject(nested, budget: budget)
      return .object(try container.decode([String: ScriptValue].self, forKey: value))
    default: throw MissionPackError("Unknown saved script value type.")
    }
  }
  private static func decodePrimitive(
    from decoder: any Decoder,
    budget: ScriptValueDecodeBudget?
  ) throws -> ScriptValue {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      try budget?.charge(1)
      return .null
    }
    if let value = try? container.decode(Bool.self) {
      try budget?.charge(1)
      return .bool(value)
    }
    if let value = try? container.decode(Int64.self) {
      try budget?.charge(9)
      return .integer(value)
    }
    if let value = try? container.decode(Double.self), value.isFinite {
      try budget?.charge(9)
      return .number(value)
    }
    if let value = try? container.decode(String.self) {
      try chargeString(value, budget: budget)
      return .string(value)
    }
    if (try? decoder.unkeyedContainer()) != nil {
      try checkArray(decoder, budget: budget)
      return .array(try container.decode([ScriptValue].self))
    }
    try checkObject(decoder, budget: budget)
    return .object(try container.decode([String: ScriptValue].self))
  }
  private static func chargeString(_ text: String, budget: ScriptValueDecodeBudget?) throws {
    guard text.utf8.count <= 262144 else {
      throw MissionPackError("Saved script string limit exceeded.")
    }
    try budget?.charge(5 + text.utf8.count)
  }
  private static func checkArray(_ decoder: any Decoder, budget: ScriptValueDecodeBudget?) throws {
    let container = try decoder.unkeyedContainer()
    guard (container.count ?? 0) <= 16384 else {
      throw MissionPackError("Saved script collection limit exceeded.")
    }
    try budget?.charge(5)
  }
  private static func checkObject(_ decoder: any Decoder, budget: ScriptValueDecodeBudget?) throws {
    let container = try decoder.container(keyedBy: ScriptStorageKey.self)
    guard container.allKeys.count <= 16384 else {
      throw MissionPackError("Saved script collection limit exceeded.")
    }
    try budget?.charge(5)
    for key in container.allKeys { try budget?.charge(4 + key.stringValue.utf8.count) }
  }
  func encodeStored(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: ScriptStorageKey.self)
    let type = ScriptStorageKey("type")
    let value = ScriptStorageKey("value")
    switch self {
    case .null: try container.encode("null", forKey: type)
    case .bool(let item):
      try container.encode("bool", forKey: type)
      try container.encode(item, forKey: value)
    case .integer(let item):
      try container.encode("integer", forKey: type)
      try container.encode(item, forKey: value)
    case .number(let item):
      guard item.isFinite else { throw MissionPackError("Saved script numbers must be finite.") }
      let raw = String(item.bitPattern, radix: 16)
      try container.encode("number", forKey: type)
      try container.encode(String(repeating: "0", count: 16 - raw.count) + raw, forKey: value)
    case .string(let item):
      try container.encode("string", forKey: type)
      try container.encode(item, forKey: value)
    case .array(let item):
      try container.encode("array", forKey: type)
      try container.encode(item, forKey: value)
    case .object(let item):
      try container.encode("object", forKey: type)
      try container.encode(item, forKey: value)
    }
  }
}
