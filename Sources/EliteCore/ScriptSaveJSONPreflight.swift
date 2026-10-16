import Foundation

/// Structural bounds precede Foundation's allocation of large saved arrays and dictionaries.
/// Foundation remains responsible for the complete JSON grammar, numbers and UTF-8 validation.
enum ScriptSaveJSONPreflight {
  static func validate(_ data: Data) throws {
    struct Container {
      let closing: UInt8
      var commas = 0
    }
    var stack: [Container] = []
    var quoted = false
    var escaped = false
    var stringBytes = 0
    for byte in data {
      if quoted {
        stringBytes += 1
        guard stringBytes <= 6 * 262144 else { throw SaveError.invalidCommander }
        if escaped {
          escaped = false
        } else if byte == 92 {
          escaped = true
        } else if byte == 34 {
          quoted = false
        }
        continue
      }
      switch byte {
      case 34:
        quoted = true
        escaped = false
        stringBytes = 0
      case 91, 123:
        guard stack.count < 96 else { throw SaveError.invalidCommander }
        stack.append(.init(closing: byte == 91 ? 93 : 125))
      case 93, 125:
        guard stack.last?.closing == byte else { throw SaveError.invalidCommander }
        stack.removeLast()
      case 44:
        guard !stack.isEmpty else { throw SaveError.invalidCommander }
        stack[stack.count - 1].commas += 1
        guard stack[stack.count - 1].commas < 16384 else { throw SaveError.invalidCommander }
      default: break
      }
    }
    guard !quoted, !escaped, stack.isEmpty else { throw SaveError.invalidCommander }
  }
}

extension ScriptSaveJSONPreflight {
  enum CourierLocation { case rawCommander, missions, contracts }
  /// Inspect native schema paths only. Authored ScriptValue data/payload keys are not schema.
  static func rejectCourierFields(_ data: Data, location: CourierLocation) throws {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw SaveError.invalidCommander
    }
    func offer(_ value: Any?) -> Bool {
      (value as? [String: Any])?.keys.contains("courier") == true
    }
    func job(_ value: Any?) -> Bool {
      guard let value = value as? [String: Any] else { return false }
      return value.keys.contains("deadlinePolicy") || value["clock"] as? String == "missionCalendar"
        || offer(value["offer"])
    }
    func dictionaryValues(_ value: Any?) -> [Any] {
      if let dictionary = value as? [String: Any] { return Array(dictionary.values) }
      if let pairs = value as? [Any], pairs.count % 2 == 0 {
        return stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
      }
      return []
    }
    func missions(_ value: [String: Any]) -> Bool {
      if value.keys.contains("missionCalendar") { return true }
      let instances = dictionaryValues(value["instances"])
      return instances.contains { raw in
        guard let instance = raw as? [String: Any] else { return false }
        if instance.keys.contains("courier") || job(instance["contract"]) { return true }
        let timers = instance["timers"] as? [String: Any] ?? [:]
        return timers.values.contains {
          ($0 as? [String: Any])?["domain"] as? String == "missionCalendar"
        }
      }
    }
    func contracts(_ value: [String: Any]) -> Bool {
      let boards = value["boards"] as? [String: Any] ?? [:]
      return boards.values.contains { raw in
        guard let board = raw as? [String: Any] else { return false }
        return board.keys.contains("courierGeneration")
          || board["clock"] as? String == "missionCalendar"
          || (board["offers"] as? [Any] ?? []).contains { offer($0) }
      }
    }
    let containsNativeFields: Bool
    switch location {
    case .missions: containsNativeFields = missions(root)
    case .contracts: containsNativeFields = contracts(root)
    case .rawCommander:
      containsNativeFields =
        missions(root["savedScriptState"] as? [String: Any] ?? [:])
        || contracts(root["savedContracts"] as? [String: Any] ?? [:])
    }
    guard !containsNativeFields else { throw SaveError.invalidCommander }
  }
}
