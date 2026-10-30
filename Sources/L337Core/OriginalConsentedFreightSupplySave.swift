import Foundation

enum OriginalConsentedFreightSupplySave {
  static let version = 39
  static let alienVersion = 40
  static let field = "savedOriginalConsentedFreightSupply"
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    if commander.scriptState.savedOriginalConsentedFreightSupply != nil { return true }
    for state in commander.scriptState.instances.values {
      if state.contract?.offer.freightPlan?.isConsented == true { return true }
    }
    for board in commander.contracts.boards.values {
      if board.freightGeneration?.plans.contains(where: \.isConsented) == true { return true }
    }
    return false
  }
  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    guard OriginalConsentedFreightSupply.engineValid(commander.scriptState) else { return false }
    guard let stock = commander.scriptState.savedOriginalConsentedFreightSupply else { return true }
    guard stock.owner == commander.equipmentOwnerID else { return false }
    for source in stock.sources.values {
      for id in source.allocations.keys {
        guard let cargo = commander.scriptState.instances[id]?.savedOwnedCargo,
          commander.freightHistoricalContextValid(cargo.issue.context, requiresDock: true),
          cargo.issue.context.nativeMainDock?.station.system == SystemIdentity(galaxy: 0, system: 7)
        else { return false }
      }
    }
    return true
  }
  static func legacyServiceSchema(_ schema: Int?) -> Int? {
    contains(schema) ? (schema == alienVersion ? 38 : 37) : schema
  }
  static func validateFields(
    _ bytes: Data, part: ScriptFreightVersionedSave.Part, schema: Int?
  ) throws {
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
      throw SaveError.invalidCommander
    }
    func reject(_ value: Any) throws {
      if let object = value as? [String: Any] {
        guard object[field] == nil else { throw SaveError.invalidCommander }
        for child in object.values { try reject(child) }
      } else if let array = value as? [Any] {
        for child in array { try reject(child) }
      }
    }
    var rest = root
    if let raw = rest.removeValue(forKey: field) {
      guard part == .missions, contains(schema),
        let object = raw as? [String: Any], Set(object.keys) == ["owner", "sources"],
        let sources = object["sources"] as? [String: Any], sources.count == 1
      else { throw SaveError.invalidCommander }
      func allocations(_ raw: Any?) throws {
        let entries: [Any]
        if let map = raw as? [String: Any] {
          let ids = map.keys.compactMap(UUID.init(uuidString:))
          guard (1...2).contains(map.count), ids.count == map.count, Set(ids).count == ids.count
          else { throw SaveError.invalidCommander }
          entries = Array(map.values)
        } else if let pairs = raw as? [Any], [2, 4].contains(pairs.count) {
          var ids: Set<UUID> = []
          for index in stride(from: 0, to: pairs.count, by: 2) {
            guard let key = pairs[index] as? String, let id = UUID(uuidString: key),
              ids.insert(id).inserted
            else { throw SaveError.invalidCommander }
          }
          entries = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
        } else {
          throw SaveError.invalidCommander
        }
        for entry in entries {
          guard let units = entry as? [String], units.count == 8,
            units.compactMap(UUID.init(uuidString:)).count == 8, Set(units).count == 8
          else { throw SaveError.invalidCommander }
        }
      }
      for rawSource in sources.values {
        guard let source = rawSource as? [String: Any],
          Set(source.keys) == [
            "owner", "station", "declaration", "content", "units", "allocations",
          ],
          let units = source["units"] as? [String], units.count == 16,
          let declaration = source["declaration"] as? [String: Any],
          Set(declaration.keys) == [
            "batch", "stockUnits", "commodity", "issuerContact", "galaxy", "system",
            "receiverSystem",
          ],
          let station = source["station"] as? [String: Any],
          Set(station.keys) == ["galaxy", "system", "stationClass"],
          let content = source["content"] as? [String: Any],
          Set(content.keys) == ["provider", "version", "digest", "state_id", "board_id"]
        else { throw SaveError.invalidCommander }
        try allocations(source["allocations"])
      }
      let encoded = try JSONSerialization.data(withJSONObject: raw)
      let stock = try JSONDecoder().decode(OriginalConsentedFreightSupplyStock.self, from: encoded)
      guard
        stock.sources.values.allSatisfy({
          (1...2).contains($0.allocations.count)
            && $0.allocations.values.allSatisfy { $0.count == 8 }
        })
      else { throw SaveError.invalidCommander }
    }
    try reject(rest)
  }
}
