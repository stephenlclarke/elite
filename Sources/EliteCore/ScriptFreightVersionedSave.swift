import Foundation

/// G1 alone activates the outer envelopes and their exact Alien cross-product.
enum ScriptFreightVersionedSave {
  static let version = 29
  static let alienVersion = 30
  enum Part: Equatable { case commander, missions, contracts }

  static func rejectFields(_ bytes: Data, part: Part) throws {
    try inspect(bytes, part: part, allow: false)
  }

  static func validateFields(_ bytes: Data, part: Part) throws {
    try inspect(bytes, part: part, allow: part != .commander)
  }

  private static func inspect(_ bytes: Data, part: Part, allow: Bool) throws {
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
      throw SaveError.invalidCommander
    }
    let reserved: Set<String> = ["savedOwnedCargo", "freightPlan", "freightGeneration"]
    func placement(_ object: [String: Any], allowed: Set<String>) throws {
      guard Set(object.keys).intersection(reserved).isSubset(of: allowed) else {
        throw SaveError.invalidCommander
      }
    }
    try placement(root, allowed: [])
    func values(_ raw: Any?, uuidKeys: Bool = false) throws -> [[String: Any]] {
      guard let raw else { return [] }
      let items: [Any]
      if let dictionary = raw as? [String: Any] {
        guard dictionary.count <= 128 else { throw SaveError.invalidCommander }
        if uuidKeys {
          let keys = dictionary.keys.compactMap(UUID.init(uuidString:))
          guard keys.count == dictionary.count, Set(keys).count == keys.count else {
            throw SaveError.invalidCommander
          }
        }
        items = Array(dictionary.values)
      } else if uuidKeys, let pairs = raw as? [Any], pairs.count % 2 == 0, pairs.count <= 256 {
        var seen: Set<UUID> = []
        for index in stride(from: 0, to: pairs.count, by: 2) {
          guard let key = pairs[index] as? String, let id = UUID(uuidString: key),
            seen.insert(id).inserted
          else {
            throw SaveError.invalidCommander
          }
        }
        items = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
      } else {
        throw SaveError.invalidCommander
      }
      guard items.count <= 128 else { throw SaveError.invalidCommander }
      return try items.map {
        guard let value = $0 as? [String: Any] else { throw SaveError.invalidCommander }
        return value
      }
    }
    func plan(_ object: [String: Any]) throws {
      let keys: Set<String> = [
        "profile", "generator_revision", "variant", "content", "owner", "board_revision",
        "seed_hex", "origin", "reach", "row", "initial_state", "draws", "final_state",
        "route_index", "commodity_index", "path", "calendar_lower_bound_seconds", "template",
        "delivery_contact", "abandon_contact", "capabilities",
      ]
      let bonded = object["profile"] as? String == ScriptFreightPlan.bondedProfileID
      let consented = object["profile"] as? String == OriginalConsentedFreightSupply.stateID
      let expected =
        consented
        ? keys.union(["supply"]) : bonded ? keys.union(["bondedHazardTiers", "bondedQuote"]) : keys
      if consented {
        guard let supply = object["supply"] as? [String: Any],
          Set(supply.keys) == [
            "batch", "stockUnits", "commodity", "issuerContact", "galaxy", "system",
            "receiverSystem",
          ]
        else { throw SaveError.invalidCommander }
      }
      guard Set(object.keys) == expected, (object["draws"] as? [Any])?.count == 6,
        let path = object["path"] as? [Any], (2...4).contains(path.count),
        let capabilities = object["capabilities"] as? [Any], capabilities.count <= 10
      else { throw SaveError.invalidCommander }
      if bonded {
        guard let hazards = object["bondedHazardTiers"] as? [Any], hazards.count == 3,
          let quote = object["bondedQuote"] as? [String: Any],
          Set(quote.keys) == ["routeLegs", "hazardTier"],
          !(quote["routeLegs"] is NSNull), !(quote["hazardTier"] is NSNull)
        else { throw SaveError.invalidCommander }
      }
    }
    func cargo(_ object: [String: Any]) throws {
      let required: Set<String> = [
        "schema", "owner", "instance", "issuer", "commodity", "consignment", "issued", "issue",
        "held", "transfers",
      ]
      guard required.isSubset(of: Set(object.keys)),
        Set(object.keys).isSubset(of: required.union(["pendingLoss", "terminal"])),
        let issued = object["issued"] as? [Any], (1...10).contains(issued.count),
        let held = object["held"] as? [Any], held.count <= 10
      else { throw SaveError.invalidCommander }
      let transfers: [Any]
      if let dictionary = object["transfers"] as? [String: Any] {
        guard dictionary.count <= 10 else { throw SaveError.invalidCommander }
        transfers = Array(dictionary.values)
      } else if let pairs = object["transfers"] as? [Any], pairs.count % 2 == 0, pairs.count <= 20 {
        transfers = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
      } else {
        throw SaveError.invalidCommander
      }
      guard transfers.count <= 10 else { throw SaveError.invalidCommander }
      for raw in transfers {
        guard let transfer = raw as? [String: Any], Set(transfer.keys) == ["units", "choice"],
          let units = transfer["units"] as? [Any], (1...10).contains(units.count)
        else { throw SaveError.invalidCommander }
      }
      for (key, unitsKey) in [("pendingLoss", "units"), ("terminal", "removed")] {
        guard let raw = object[key] else { continue }
        guard let value = raw as? [String: Any], let units = value[unitsKey] as? [Any],
          units.count <= 10
        else { throw SaveError.invalidCommander }
      }
    }
    func field(_ key: String, in object: [String: Any]) throws {
      guard object.keys.contains(key) else { return }
      guard allow, let value = object[key] as? [String: Any] else {
        throw SaveError.invalidCommander
      }
      switch key {
      case "savedOwnedCargo": try cargo(value)
      case "freightPlan": try plan(value)
      case "freightGeneration":
        guard Set(value.keys) == ["plans", "holdCapacity"],
          let plans = value["plans"] as? [[String: Any]],
          plans.count
            == (plans.first?["profile"] as? String == OriginalConsentedFreightSupply.stateID
              ? 1 : 3)
        else { throw SaveError.invalidCommander }
        for item in plans { try plan(item) }
      default: throw SaveError.invalidCommander
      }
    }
    func offer(_ object: [String: Any]) throws {
      try placement(object, allowed: ["freightPlan"])
      try field("freightPlan", in: object)
    }
    func missions(_ object: [String: Any]) throws {
      try placement(object, allowed: [])
      for instance in try values(object["instances"], uuidKeys: true) {
        try placement(instance, allowed: ["savedOwnedCargo"])
        try field("savedOwnedCargo", in: instance)
        if let raw = instance["contract"], !(raw is NSNull) {
          guard let contract = raw as? [String: Any], let row = contract["offer"] as? [String: Any]
          else { throw SaveError.invalidCommander }
          try placement(contract, allowed: [])
          try offer(row)
        }
      }
    }
    func contracts(_ object: [String: Any]) throws {
      try placement(object, allowed: [])
      for board in try values(object["boards"]) {
        try placement(board, allowed: ["freightGeneration"])
        try field("freightGeneration", in: board)
        guard let offers = board["offers"] as? [[String: Any]], offers.count <= 16 else {
          throw SaveError.invalidCommander
        }
        for row in offers { try offer(row) }
      }
    }
    switch part {
    case .missions: try missions(root)
    case .contracts: try contracts(root)
    case .commander:
      for (key, inspect) in [("savedScriptState", missions), ("savedContracts", contracts)] {
        guard let raw = root[key] else { continue }
        if raw is NSNull { continue }
        guard let object = raw as? [String: Any] else { throw SaveError.invalidCommander }
        try inspect(object)
      }
    }
  }

  static func validateClaims(_ commander: Commander) -> Bool {
    commander.freightCargoValid && ScriptProviderVersionedSave.validateClaims(commander)
      && commander.contractsValid
  }
}

extension Commander {
  var usesFreightNativeSaveVersion: Bool {
    contracts.boards.values.contains { board in
      board.freightGeneration != nil || board.offers.contains { $0.freightPlan != nil }
    }
      || scriptState.instances.values.contains {
        $0.savedOwnedCargo != nil || $0.contract?.offer.freightPlan != nil
      }
  }
}
