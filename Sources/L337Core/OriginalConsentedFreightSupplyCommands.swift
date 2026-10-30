import Foundation

/// Attempt-local output; never serialized or retained as a second custody authority.
struct OriginalConsentedFreightSupplyDelta: Sendable {
  let before: OriginalConsentedFreightSupplyStock?
  let after: OriginalConsentedFreightSupplyStock
  let units: [UUID]
  func install(into engine: inout ScriptEngineState) throws {
    guard engine.savedOriginalConsentedFreightSupply == before else {
      throw MissionPackError("Supplier stock changed; review the actual source again.")
    }
    engine.savedOriginalConsentedFreightSupply = after
  }
}

extension OriginalConsentedFreightSupply {
  static func allocate(
    plan: ScriptFreightPlan, instance: UUID, game: borrowing Game
  ) throws -> OriginalConsentedFreightSupplyDelta {
    guard plan.valid, plan.isConsented, let declaration = plan.supply, declaration.valid,
      plan.origin == issuer, game.contractStation == issuer,
      game.nativeMainStationDockEvidenceIsCurrent, game.commander.equipmentOwnerID == plan.owner,
      engineValid(game.commander.scriptState)
    else { throw MissionPackError("ARLEN requires an actual current source confirmation.") }
    let before = game.commander.scriptState.savedOriginalConsentedFreightSupply
    var stock = before ?? .init(owner: plan.owner, sources: [:])
    let key = sourceKey(owner: plan.owner)
    var source =
      stock.sources[key]
      ?? .init(
        owner: plan.owner, station: issuer, declaration: declaration, content: plan.content,
        units: unitIDs(owner: plan.owner), allocations: [:])
    guard stock.owner == plan.owner, source.content == plan.content,
      source.declaration == declaration, source.allocations[instance] == nil,
      source.remaining.count >= 8
    else { throw MissionPackError("The original supplier batch has no eight unallocated units.") }
    let units = Array(source.remaining.prefix(8))
    source.allocations[instance] = units
    stock.sources[key] = source
    return .init(before: before, after: stock, units: units)
  }
  static func requireAvailable(_ plan: ScriptFreightPlan, game: borrowing Game) throws {
    guard plan.isConsented else { return }
    let before = game.commander.scriptState.savedOriginalConsentedFreightSupply
    guard engineValid(game.commander.scriptState),
      before.map({ $0.owner == plan.owner }) ?? true,
      before?.sources[sourceKey(owner: plan.owner)].map({
        $0.content == plan.content && $0.declaration == plan.supply && $0.remaining.count >= 8
      }) ?? (before == nil)
    else {
      throw MissionPackError("ARLEN's original finite batch cannot supply another eight tonnes.")
    }
  }
  static func receiverMatches(_ plan: ScriptFreightPlan, game: borrowing Game) -> Bool {
    if !plan.isConsented { return true }
    guard plan.supply?.valid == true, plan.deliveryContact == "freight-delivery",
      game.contractStation
        == ContractStationIdentity(galaxy: 0, system: 185, stationClass: "main-orbital"),
      game.nativeMainStationDockEvidenceIsCurrent
    else { return false }
    return true
  }
}
