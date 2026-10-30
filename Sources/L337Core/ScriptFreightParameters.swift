import Foundation

/// The existing Codable parameter shape, without recursively decoding a typed plan during validation.
enum ScriptFreightParameters {
  @inline(never)
  static func project(_ plan: borrowing ScriptFreightPlan) -> ScriptValue? {
    guard withinLegacyLimits(plan), let reach = projectReach(plan.reach),
      let calendar = number(plan.calendarLowerBoundSeconds)
    else { return nil }
    var fields: [String: ScriptValue] = [
      "profile": .string(plan.profile),
      "generator_revision": .integer(Int64(plan.generatorRevision)),
      "variant": .string(plan.variant),
      "content": .object([
        "provider": .string(plan.content.provider), "version": .string(plan.content.version),
        "digest": .string(plan.content.digest), "state_id": .string(plan.content.stateID),
        "board_id": .string(plan.content.boardID),
      ]),
      "owner": .string(plan.owner.uuidString), "board_revision": .integer(plan.boardRevision),
      "seed_hex": .string(plan.seedHex),
      "origin": .object([
        "galaxy": .integer(Int64(plan.origin.galaxy)),
        "system": .integer(Int64(plan.origin.system)),
        "stationClass": .string(plan.origin.stationClass),
      ]),
      "reach": reach, "row": .integer(Int64(plan.row)),
      "initial_state": .integer(Int64(plan.initialState)),
      "draws": .array(plan.draws.map { .integer(Int64($0)) }),
      "final_state": .integer(Int64(plan.finalState)),
      "route_index": .integer(Int64(plan.routeIndex)),
      "commodity_index": .integer(Int64(plan.commodityIndex)),
      "path": .array(plan.path.map { .integer(Int64($0)) }),
      "calendar_lower_bound_seconds": calendar,
      "template": .object(["id": .string(plan.template.id), "title": .string(plan.template.title)]),
      "delivery_contact": .string(plan.deliveryContact),
      "abandon_contact": .string(plan.abandonContact),
      "capabilities": .array(plan.capabilities.map { .string($0) }),
    ]
    if let tiers = plan.bondedHazardTiers {
      fields["bondedHazardTiers"] = .array(tiers.map { .integer(Int64($0)) })
    }
    if let quote = plan.bondedQuote {
      fields["bondedQuote"] = .object([
        "routeLegs": .integer(Int64(quote.routeLegs)),
        "hazardTier": .integer(Int64(quote.hazardTier)),
      ])
    }
    if let supply = plan.supply {
      fields["supply"] = .object([
        "batch": .string(supply.batch), "stockUnits": .integer(Int64(supply.stockUnits)),
        "commodity": .integer(Int64(supply.commodity)),
        "issuerContact": .string(supply.issuerContact), "galaxy": .integer(Int64(supply.galaxy)),
        "system": .integer(Int64(supply.system)),
        "receiverSystem": .integer(Int64(supply.receiverSystem)),
      ])
    }
    return .object(["freight": .object(fields)])
  }

  // The old plain ScriptValue decoder applies individual limits without an aggregate budget.
  @inline(never)
  private static func withinLegacyLimits(_ plan: borrowing ScriptFreightPlan) -> Bool {
    guard plan.draws.count <= 16384, plan.path.count <= 16384,
      plan.capabilities.count <= 16384, (plan.bondedHazardTiers?.count ?? 0) <= 16384
    else { return false }
    var strings = [
      plan.profile, plan.variant, plan.content.provider, plan.content.version, plan.content.digest,
      plan.content.stateID, plan.content.boardID, plan.owner.uuidString, plan.seedHex,
      plan.origin.stationClass, plan.reach.revision, plan.reach.hull,
      plan.template.id, plan.template.title, plan.deliveryContact, plan.abandonContact,
    ]
    if let supply = plan.supply { strings += [supply.batch, supply.issuerContact] }
    guard strings.allSatisfy({ $0.utf8.count <= 262144 }) else { return false }
    return plan.capabilities.allSatisfy { $0.utf8.count <= 262144 }
  }

  @inline(never)
  private static func projectReach(_ reach: borrowing ScriptCourierReach) -> ScriptValue? {
    guard let jumpCap = number(reach.jumpCap), let firstReach = number(reach.firstReach) else {
      return nil
    }
    var fields: [String: ScriptValue] = [
      "revision": .string(reach.revision), "hull": .string(reach.hull),
      "storage": .integer(Int64(reach.storage)), "fuel": .integer(Int64(reach.fuel)),
      "jumpCap": jumpCap, "capacity": .integer(Int64(reach.capacity)), "firstReach": firstReach,
    ]
    if let navigation = reach.navigation {
      fields["navigation"] = .integer(Int64(navigation.rawValue))
    }
    if let multiplier = reach.jumpFuelMultiplier {
      guard let value = number(multiplier) else { return nil }
      fields["jumpFuelMultiplier"] = value
    }
    if let fullTank = reach.fullTankReach {
      guard let value = number(fullTank) else { return nil }
      fields["fullTankReach"] = value
    }
    return .object(fields)
  }

  // Preserve Foundation's decimal-to-Int64 normalisation, including boundary rounding.
  // Only a scalar is decoded here; the recursive ScriptValue decoder is not involved.
  @inline(never)
  private static func number(_ value: Double) -> ScriptValue? {
    guard value.isFinite, let bytes = try? JSONEncoder().encode(value) else { return nil }
    if let integer = try? JSONDecoder().decode(Int64.self, from: bytes) { return .integer(integer) }
    return .number(value)
  }
}
