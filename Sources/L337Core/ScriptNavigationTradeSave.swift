import Foundation

/// Existing native chunk storage, with a closed envelope for retained tutorial evidence.
enum ScriptNavigationTradeSave {
  static let version = 33
  static let alienVersion = 34
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func hasClaims(_ commander: Commander) -> Bool {
    commander.scriptState.instances.values.contains { $0.savedNavigationTrade != nil }
  }
  static func validateClaims(_ commander: Commander, binding: ScriptNavigationTradeBinding?) -> Bool
  {
    let records = commander.scriptState.instances.values.compactMap(\.savedNavigationTrade)
    guard !records.isEmpty else { return true }
    guard commander.navigationTradeStateValid else { return false }
    let completed = records.filter { $0.stage == .received }
    if !completed.isEmpty {
      guard
        let award = commander.scriptState.savedClueJournal?.awards[
          ScriptNavigationTradeContent.sourceID],
        completed.allSatisfy({ record in
          commander.scriptState.instances[record.instance]?.completionReceipt.map {
            award.completion.sequence <= $0.sequence
          } == true
        })
      else { return false }
    }
    return records.allSatisfy { record in
      let scoped = binding.flatMap {
        $0.training == record.training && $0.destination == record.destination ? $0 : nil
      }
      guard let binding = scoped ?? ScriptNavigationTradeBinding.production(for: record),
        binding.valid
      else { return false }
      return record.training == binding.training && record.destination == binding.destination
        && record.definition == ScriptNavigationTradeContent.sourceID
        && record.version == ScriptNavigationTradeContent.version
        && record.digest == ScriptNavigationTradeContent.digest
        && commander.scriptState.instances[record.instance].map {
          record.valid(instance: $0, engine: commander.scriptState)
        } == true
    }
  }

  static func validateFields(
    _ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?
  ) throws {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw SaveError.invalidCommander
    }
    let field = "savedNavigationTrade"
    func reject(_ object: [String: Any]) throws {
      guard !object.keys.contains(field) else { throw SaveError.invalidCommander }
    }
    func values(_ raw: Any?) -> [[String: Any]] {
      if let dictionary = raw as? [String: Any] {
        return dictionary.values.compactMap { $0 as? [String: Any] }
      }
      if let pairs = raw as? [Any], pairs.count % 2 == 0 {
        return stride(from: 1, to: pairs.count, by: 2).compactMap { pairs[$0] as? [String: Any] }
      }
      return []
    }
    func missions(_ object: [String: Any], allow: Bool) throws {
      try reject(object)
      var found = false
      for instance in values(object["instances"]) {
        if let raw = instance[field] {
          found = true
          guard allow, let record = raw as? [String: Any],
            let journeys = record["journeys"] as? [Any], journeys.count <= 64,
            let fuel = record["fuelPurchases"] as? [Any], fuel.count <= 64,
            Set(record.keys).isSubset(of: [
              "owner", "instance", "definition", "version", "digest",
              "training", "destination", "commodity", "acceptance", "acceptedHull",
              "equipmentRevision",
              "confirmedCapacity", "confirmedCargoTonnes", "quotedPrice", "quotedStock",
              "routeDistance",
              "plannedFuelDebit", "stage", "buy", "journeys", "fuelPurchases", "sale", "reception",
              "cancellation", "loss",
            ])
          else { throw SaveError.invalidCommander }
          for key in ["buy", "sale", "reception", "cancellation", "loss"]
          where record.keys.contains(key) {
            guard record[key] is [String: Any] else { throw SaveError.invalidCommander }
          }
        }
        if let contract = instance["contract"] as? [String: Any] {
          try reject(contract)
          if let offer = contract["offer"] as? [String: Any] { try reject(offer) }
        }
      }
      guard !allow || found else { throw SaveError.invalidCommander }
    }
    func contracts(_ object: [String: Any]) throws {
      try reject(object)
      for board in values(object["boards"]) {
        try reject(board)
        for offer in board["offers"] as? [[String: Any]] ?? [] { try reject(offer) }
      }
    }
    switch part {
    case .missions: try missions(root, allow: contains(schema))
    case .commander:
      try reject(root)
      if let state = root["savedScriptState"] as? [String: Any] {
        try missions(state, allow: false)
      }
      if let saved = root["savedContracts"] as? [String: Any] { try contracts(saved) }
    case .contracts: try contracts(root)
    }
  }
}
