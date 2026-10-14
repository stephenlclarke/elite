import Foundation

/// The only values allowed across the interpreter boundary or in persisted script data.
public indirect enum ScriptValue: Sendable, Equatable, Codable {
  case null
  case bool(Bool)
  case integer(Int64)
  case number(Double)
  case string(String)
  case array([ScriptValue])
  case object([String: ScriptValue])

  public init(from decoder: any Decoder) throws {
    guard decoder.codingPath.count < 64 else {
      throw MissionPackError("Saved script value nesting exceeded.")
    }
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Int64.self) {
      self = .integer(value)
    } else if let value = try? container.decode(Double.self), value.isFinite {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([ScriptValue].self) {
      self = .array(value)
    } else {
      self = .object(try container.decode([String: ScriptValue].self))
    }
  }
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null: try container.encodeNil()
    case .bool(let value): try container.encode(value)
    case .integer(let value): try container.encode(value)
    case .number(let value): try container.encode(value)
    case .string(let value): try container.encode(value)
    case .array(let value): try container.encode(value)
    case .object(let value): try container.encode(value)
    }
  }
  var object: [String: ScriptValue]? { if case .object(let value) = self { value } else { nil } }
  var string: String? { if case .string(let value) = self { value } else { nil } }
  var integer: Int64? { if case .integer(let value) = self { value } else { nil } }
  var double: Double? {
    switch self {
    case .integer(let v): Double(v)
    case .number(let v): v
    default: nil
    }
  }
  var array: [ScriptValue]? {
    if case .array(let value) = self { return value }
    if case .object(let value) = self, value.isEmpty { return [] }
    return nil
  }
  subscript(_ key: String) -> ScriptValue? { object?[key] }
}

/// Private bounded binary exchange; map keys are sorted so encoding is reproducible.
enum ScriptWire {
  static let maximumBytes = 1_048_576
  static func encode(_ values: [ScriptValue], limit: Int = maximumBytes) throws -> Data {
    var data = Data()
    var items = 0
    func bytes<T>(_ value: T) {
      var copy = value
      withUnsafeBytes(of: &copy) { data.append(contentsOf: $0) }
    }
    func string(_ value: String) throws {
      let encoded = Data(value.utf8)
      guard encoded.count <= limit else { throw MissionPackError("Script string is too large.") }
      bytes(UInt32(encoded.count).littleEndian)
      data.append(encoded)
    }
    func put(_ value: ScriptValue, depth: Int) throws {
      items += 1
      guard depth < 32, items <= 16384 else {
        throw MissionPackError("Script data is too deeply nested or large.")
      }
      switch value {
      case .null: data.append(0)
      case .bool(let v): data.append(v ? 2 : 1)
      case .integer(let v):
        data.append(3)
        bytes(v.littleEndian)
      case .number(let v):
        guard v.isFinite else { throw MissionPackError("Script numbers must be finite.") }
        data.append(4)
        bytes(v.bitPattern.littleEndian)
      case .string(let v):
        data.append(5)
        try string(v)
      case .array(let v):
        guard v.count <= 16384 else { throw MissionPackError("Script collection is too large.") }
        data.append(6)
        bytes(UInt32(v.count).littleEndian)
        for child in v { try put(child, depth: depth + 1) }
      case .object(let v):
        guard v.count <= 16384 else { throw MissionPackError("Script collection is too large.") }
        data.append(7)
        bytes(UInt32(v.count).littleEndian)
        for key in v.keys.sorted() {
          try string(key)
          try put(v[key]!, depth: depth + 1)
        }
      }
      guard data.count <= limit else {
        throw MissionPackError("Script data exceeds its byte budget.")
      }
    }
    for value in values { try put(value, depth: 0) }
    return data
  }
  static func decode(_ data: Data) throws -> ScriptValue {
    guard data.count <= maximumBytes else { throw MissionPackError("Script output is too large.") }
    var cursor = 0
    var items = 0
    func read(_ count: Int) throws -> Data {
      guard count >= 0, count <= data.count - cursor else {
        throw MissionPackError("Truncated script result.")
      }
      defer { cursor += count }
      return data.subdata(in: cursor..<(cursor + count))
    }
    func length() throws -> Int {
      Int(try read(4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).littleEndian })
    }
    func string() throws -> String {
      guard let value = String(data: try read(length()), encoding: .utf8) else {
        throw MissionPackError("Script strings must be UTF-8.")
      }
      return value
    }
    func get(_ depth: Int) throws -> ScriptValue {
      items += 1
      guard depth < 32, items <= 16384 else {
        throw MissionPackError("Script result nesting/items exceeded.")
      }
      switch try read(1).first! {
      case 0: return .null
      case 1: return .bool(false)
      case 2: return .bool(true)
      case 3:
        return .integer(
          try read(8).withUnsafeBytes { $0.loadUnaligned(as: Int64.self).littleEndian })
      case 4:
        let value = Double(
          bitPattern: try read(8).withUnsafeBytes { $0.loadUnaligned(as: UInt64.self).littleEndian }
        )
        guard value.isFinite else { throw MissionPackError("Nonfinite script result.") }
        return .number(value)
      case 5: return .string(try string())
      case let tag where tag == 6 || tag == 7:
        let count = try length()
        guard count <= 16384 else { throw MissionPackError("Script result collection exceeded.") }
        if tag == 6 { return .array(try (0..<count).map { _ in try get(depth + 1) }) }
        var map: [String: ScriptValue] = [:]
        for _ in 0..<count {
          let key = try string()
          guard map[key] == nil else { throw MissionPackError("Duplicate script result key.") }
          map[key] = try get(depth + 1)
        }
        return .object(map)
      default: throw MissionPackError("Invalid script result tag.")
      }
    }
    let result = try get(0)
    guard cursor == data.count else { throw MissionPackError("Trailing script result bytes.") }
    return result
  }
}
