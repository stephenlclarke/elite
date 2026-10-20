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
  /// W02 and W03 validate their closed claims against the actual envelope before lower gates run.
  static func validateRepairLoopFields(
    _ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int? = nil
  ) throws {
    try NativeOriginalSurveySave.validateFields(data, part: part, schema: schema)
    let predecessorSchema = NativeOriginalSurveySave.lowerSchema(schema)
    try NativePeopleVersionedSave.validateStationPassengerFields(
      data, part: part, schema: predecessorSchema)
    let supplierSchema = NativeStationPassengerJourneySave.lowerSchema(
      NativeOrbitalOutlookJourneySave.lowerSchema(
        NativeOriginalRescueJourneySave.lowerSchema(
          NativeOriginalEvacuationSave.lowerSchema(predecessorSchema))))
    try OriginalConsentedFreightSupplySave.validateFields(data, part: part, schema: supplierSchema)
    let serviceSchema = OriginalConsentedFreightSupplySave.legacyServiceSchema(supplierSchema)
    try WayfarerRepairLoopSave.validateFields(data, part: part, schema: serviceSchema)
    try WayfarerColdChainSave.validateFields(data, part: part, schema: serviceSchema)
    guard part == .commander,
      let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let embedded = root["savedScriptState"] as? [String: Any]
    else { return }
    // Current headers cannot hide a second mission ledger that decode later replaces.
    let embeddedBytes = try JSONSerialization.data(withJSONObject: embedded)
    try WayfarerRepairLoopSave.validateFields(embeddedBytes, part: .contracts, schema: nil)
    try WayfarerColdChainSave.validateFields(embeddedBytes, part: .contracts, schema: nil)
  }

  /// Freight custody belongs only in its native chunks. Version 28 remains reserved;
  /// provider claims may coexist only inside a validated freight envelope.
  static func validateFreightFields(
    _ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int? = nil
  ) throws {
    if schema == nil { try validateRepairLoopFields(data, part: part) }
    try ScriptClueVersionedSave.validateFields(data, part: part, schema: schema)
    try ScriptNavigationTradeSave.validateFields(data, part: part, schema: schema)
    let freight =
      ScriptClueVersionedSave.contains(schema) || ScriptNavigationTradeSave.contains(schema)
      || schema == ScriptFreightVersionedSave.version
      || schema == ScriptFreightVersionedSave.alienVersion
    if freight, part != .commander {
      try ScriptFreightVersionedSave.validateFields(data, part: part)
      if part == .missions { try validateFreightProviderFields(data) }
    } else {
      try ScriptFreightVersionedSave.rejectFields(data, part: part)
    }
    if !freight || part == .commander {
      switch part {
      case .commander: try ScriptProviderVersionedSave.rejectFields(data, part: .commander)
      case .missions: try ScriptProviderVersionedSave.rejectFields(data, part: .missions)
      case .contracts: break
      }
    }
  }

  /// Optional native custody must not disappear through decodeIfPresent(null).
  /// Freight inspection has already bounded and authenticated the instance keys.
  private static func validateFreightProviderFields(_ data: Data) throws {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw SaveError.invalidCommander
    }
    let instances: [Any]
    if let dictionary = root["instances"] as? [String: Any] {
      instances = Array(dictionary.values)
    } else if let pairs = root["instances"] as? [Any] {
      instances = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
    } else {
      instances = []
    }
    for raw in instances {
      guard let instance = raw as? [String: Any],
        let provider = instance["savedProviderContract"]
      else { continue }
      guard let object = provider as? [String: Any] else { throw SaveError.invalidCommander }
      _ = try JSONDecoder().decode(
        ScriptProviderContractState.self,
        from: JSONSerialization.data(withJSONObject: object))
    }
  }

  enum CourierLocation { case rawCommander, currentCommanderHeader, missions, contracts }
  /// Inspect native schema paths only. Authored data/payload keys are not schema.
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
        let newGearFields: Set<String> = [
          "savedGearVersion", "source", "node", "displacements", "legacyMissingItems",
        ]
        if dictionaryValues(instance["savedGearIssues"]).contains(where: { raw in
          guard let record = raw as? [String: Any] else { return false }
          return !newGearFields.isDisjoint(with: record.keys)
        }) {
          return true
        }
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
    case .currentCommanderHeader:
      // Versioned station state lives in this header; its retained world is checked later.
      // Mission/contract custody still belongs exclusively in the separate native chunks.
      let rrs = (root["savedContracts"] as? [String: Any])?["rrs"]
      containsNativeFields =
        (rrs != nil && !(rrs is NSNull))
        || missions(root["savedScriptState"] as? [String: Any] ?? [:])
        || contracts(root["savedContracts"] as? [String: Any] ?? [:])
    case .rawCommander:
      // Station custody requires the versioned world and its native save barrier.
      // A legacy Commander has no retained scene that can authenticate a dock receipt.
      let stations = root["nativeStations"]
      let rrs = (root["savedContracts"] as? [String: Any])?["rrs"]
      containsNativeFields =
        (stations != nil && !(stations is NSNull)) || (rrs != nil && !(rrs is NSNull))
        || missions(root["savedScriptState"] as? [String: Any] ?? [:])
        || contracts(root["savedContracts"] as? [String: Any] ?? [:])
    }
    guard !containsNativeFields else { throw SaveError.invalidCommander }
  }
}
