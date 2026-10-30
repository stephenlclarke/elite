import Foundation

/// Closed current envelopes. Descriptive source IDs never authorize executable content.
enum ScriptClueVersionedSave {
  static let version = 31
  static let alienVersion = 32

  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }

  static func validateClaims(_ commander: Commander, trust: ScriptClueTrustCatalog) -> Bool {
    guard let journal = commander.scriptState.savedClueJournal else { return true }
    return journal.owner == commander.equipmentOwnerID
      && journal.valid(engine: commander.scriptState)
      && journal.awards.values.allSatisfy { award in
        trust.pin(for: award.completion)?.sourceID == award.sourceID
          && (award.sourceID != ScriptNavigationTradeContent.sourceID
            || commander.scriptState.instances[award.completion.instance]?.savedNavigationTrade?
              .stage == .received)
      }
  }

  /// The field belongs only at the missions chunk root of exact 31/32, never null.
  /// Authored Lua data remains opaque; inspect native schema containers only.
  static func validateFields(
    _ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?
  ) throws {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw SaveError.invalidCommander
    }
    let field = "savedClueJournal"
    func reject(_ object: [String: Any]) throws {
      guard !object.keys.contains(field) else { throw SaveError.invalidCommander }
    }
    func values(_ raw: Any?) -> [[String: Any]] {
      if let object = raw as? [String: Any] {
        return object.values.compactMap { $0 as? [String: Any] }
      }
      if let pairs = raw as? [Any], pairs.count % 2 == 0 {
        return stride(from: 1, to: pairs.count, by: 2).compactMap { pairs[$0] as? [String: Any] }
      }
      return []
    }
    func missions(_ object: [String: Any], allow: Bool) throws {
      if allow {
        guard let journal = object[field] as? [String: Any],
          Set(journal.keys) == ["owner", "awards"],
          let owner = journal["owner"] as? String, UUID(uuidString: owner) != nil,
          let awards = journal["awards"] as? [String: Any], (1...64).contains(awards.count)
        else { throw SaveError.invalidCommander }
        for raw in awards.values {
          guard let award = raw as? [String: Any],
            Set(award.keys) == ["sourceID", "clueID", "receiptID", "completion"],
            award["completion"] is [String: Any]
          else { throw SaveError.invalidCommander }
        }
      } else {
        try reject(object)
      }
      for instance in values(object["instances"]) {
        try reject(instance)
        if let contract = instance["contract"] as? [String: Any] {
          try reject(contract)
          if let offer = contract["offer"] as? [String: Any] { try reject(offer) }
        }
      }
    }
    func contracts(_ object: [String: Any]) throws {
      try reject(object)
      for board in values(object["boards"]) {
        try reject(board)
        for offer in board["offers"] as? [[String: Any]] ?? [] { try reject(offer) }
      }
    }
    switch part {
    case .missions:
      try missions(
        root,
        allow: contains(schema)
          || (ScriptNavigationTradeSave.contains(schema) && root.keys.contains(field)))
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
