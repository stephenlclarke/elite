import Foundation
import MissionScript

public struct ScriptLimits: Sendable {
  public var instructions: UInt64 = 50_000
  public var heapBytes = 8_388_608
  public var allocationBytes = 33_554_432
  public var outputBytes = 524_288
  public init() {}
}
public struct ScriptEvaluation: Sendable {
  public let data: ScriptValue
  public let commands: [ScriptValue]
  public let instructions: UInt64
  public let peakHeapBytes: Int
}

/// Contains no retained interpreter handles and never calls Swift from a Lua frame.
enum ScriptEvaluator {
  static func evaluate(
    source: Data, handler: String, event: ScriptValue, snapshot: ScriptValue,
    state: ScriptValue, limits: ScriptLimits = ScriptLimits()
  ) throws -> ScriptEvaluation {
    guard handler.range(of: "^[A-Za-z_][A-Za-z0-9_]{0,79}$", options: .regularExpression) != nil,
      limits.heapBytes >= 65536,
      limits.allocationBytes >= limits.heapBytes, limits.outputBytes > 0
    else {
      throw MissionPackError("Invalid Lua handler or execution limits.")
    }
    let (output, instructions, peakHeapBytes) = try invoke(
      source: source, handler: handler, input: ScriptWire.encode([event, snapshot, state]),
      limits: limits)
    guard let fields = output.object, Set(fields.keys) == ["data", "commands"],
      let data = fields["data"], data.object != nil,
      let commands = fields["commands"]?.array, commands.count <= 256
    else {
      throw MissionPackError(
        "Handler must return {data = a map, commands = an array of at most 256 commands}.")
    }
    _ = try ScriptWire.encode([data], limit: 262144)
    return ScriptEvaluation(
      data: data, commands: commands, instructions: instructions, peakHeapBytes: peakHeapBytes)
  }
  static func validate(source: Data, handlers: [String] = []) throws {
    _ = try invoke(
      source: source, handler: "",
      input: ScriptWire.encode([.array(handlers.map(ScriptValue.string))]), limits: ScriptLimits())
  }
  private static func invoke(source: Data, handler: String, input: Data, limits: ScriptLimits)
    throws -> (ScriptValue, UInt64, Int)
  {
    var result = source.withUnsafeBytes { sourceBytes in
      input.withUnsafeBytes { inputBytes in
        handler.withCString { name in
          ems_evaluate(
            sourceBytes.bindMemory(to: UInt8.self).baseAddress, source.count, name,
            inputBytes.bindMemory(to: UInt8.self).baseAddress, input.count,
            EMSLimits(
              instructions: limits.instructions, heap_bytes: limits.heapBytes,
              allocation_bytes: limits.allocationBytes, output_bytes: limits.outputBytes))
        }
      }
    }
    defer { ems_release(&result) }
    guard result.status == 0, let bytes = result.bytes else {
      let error = withUnsafePointer(to: &result.error) { pointer in
        pointer.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) }
      }
      throw MissionPackError(error)
    }
    return (
      try ScriptWire.decode(Data(bytes: bytes, count: result.count)), result.instructions,
      result.peak_heap_bytes
    )
  }
}
