import Foundation

struct OriginalConsentedFreightSupplyDeclaration: Codable, Sendable, Equatable {
  let batch: String
  let stockUnits: Int
  let commodity: Int
  let issuerContact: String
  let galaxy: Int
  let system: Int
  let receiverSystem: Int
  var valid: Bool {
    batch == "avenor-utility-parts-01" && stockUnits == 16
      && commodity == CommodityIdentity.machinery.rawValue && issuerContact == "arlen"
      && galaxy == 0 && system == 7 && receiverSystem == 185
  }
}

struct OriginalConsentedFreightSupplySource: Codable, Sendable, Equatable {
  let owner: UUID
  let station: ContractStationIdentity
  let declaration: OriginalConsentedFreightSupplyDeclaration
  let content: ScriptFreightContent
  let units: [UUID]
  var allocations: [UUID: [UUID]]
  var key: String { OriginalConsentedFreightSupply.sourceKey(owner: owner) }
  var remaining: [UUID] {
    let assigned = Set(allocations.values.flatMap { $0 })
    return units.filter { !assigned.contains($0) }
  }
}

struct OriginalConsentedFreightSupplyStock: Codable, Sendable, Equatable {
  let owner: UUID
  var sources: [String: OriginalConsentedFreightSupplySource]

  func valid(engine: borrowing ScriptEngineState) -> Bool {
    guard sources.count == 1,
      let source = sources[OriginalConsentedFreightSupply.sourceKey(owner: owner)],
      source.owner == owner, source.station == OriginalConsentedFreightSupply.issuer,
      source.declaration.valid, source.content.valid,
      source.content.stateID == OriginalConsentedFreightSupply.stateID,
      source.units == OriginalConsentedFreightSupply.unitIDs(owner: owner),
      (1...2).contains(source.allocations.count)
    else { return false }
    var used: Set<UUID> = []
    for (id, units) in source.allocations {
      guard units.count == 8, Set(units).count == 8,
        Set(units).isSubset(of: Set(source.units)), used.isDisjoint(with: units),
        let state = engine.instances[id], let plan = state.contract?.offer.freightPlan,
        plan.isConsented, plan.owner == owner, plan.content == source.content,
        plan.supply == source.declaration, let cargo = state.savedOwnedCargo,
        cargo.owner == owner, cargo.instance == id, cargo.issued == units,
        cargo.issuer == source.station, cargo.commodity == source.declaration.commodity
      else { return false }
      used.formUnion(units)
    }
    var issueSequences: [UUID: UInt64] = [:]
    for id in source.allocations.keys {
      issueSequences[id] = engine.instances[id]?.savedOwnedCargo?.issue.sequence
    }
    let ordered = source.allocations.keys.sorted {
      (issueSequences[$0] ?? 0) < (issueSequences[$1] ?? 0)
    }
    var sequences: Set<UInt64> = []
    for (index, id) in ordered.enumerated() {
      guard let sequence = engine.instances[id]?.savedOwnedCargo?.issue.sequence,
        sequences.insert(sequence).inserted,
        source.allocations[id] == Array(source.units.dropFirst(index * 8).prefix(8))
      else { return false }
    }
    return engine.instances.values.allSatisfy { state in
      guard state.contract?.offer.freightPlan?.isConsented == true else { return true }
      return source.allocations[state.id] == state.savedOwnedCargo?.issued
        && state.savedOwnedCargo != nil
    }
  }
}

enum OriginalConsentedFreightSupply {
  static let stateID = "l337.contract/consented-freight"
  // Frozen from the actual production pack before owner qualification.
  static let digest = "37ca73ed1b3f3656c42baedaf8dbaa3ee8aa3798ccf23e376c3c25ceac9bd572"
  static let issuer = ContractStationIdentity(galaxy: 0, system: 7, stationClass: "main-orbital")
  static func sourceKey(owner: UUID) -> String {
    "g02-supply-v1:" + owner.uuidString + ":" + issuer.key + ":avenor-utility-parts-01"
  }
  static func unitIDs(owner: UUID) -> [UUID] {
    (0..<16).map { ScriptIdentity.uuid(sourceKey(owner: owner) + ":" + String($0)) }
  }
  static func allocationMatches(
    _ cargo: borrowing ScriptOwnedCargoState, state: borrowing ScriptInstance,
    engine: borrowing ScriptEngineState
  ) -> Bool {
    guard let plan = state.contract?.offer.freightPlan, plan.isConsented,
      let stock = engine.savedOriginalConsentedFreightSupply,
      stock.owner == plan.owner,
      let source = stock.sources[sourceKey(owner: plan.owner)], source.content == plan.content,
      source.declaration == plan.supply
    else { return false }
    return source.allocations[state.id] == cargo.issued
  }
  static func engineValid(_ engine: borrowing ScriptEngineState) -> Bool {
    if let stock = engine.savedOriginalConsentedFreightSupply { return stock.valid(engine: engine) }
    return !engine.instances.values.contains { $0.contract?.offer.freightPlan?.isConsented == true }
  }
}
