import Foundation

extension Game {
  func salvageProfile(for body: SpaceBody) -> SalvageProfile? {
    guard let catalogue = body.physical?.catalogueShipID else { return nil }
    if let existing = SalvageCatalogue.profile(catalogueShipID: catalogue) { return existing }
    guard isEMPDisabled(body), let source = body.physical?.empSource,
      let record = commander.savedEMPState?.records[source], record.crewAboard == 0,
      record.wreck == body.physical?.salvage?.wreck
    else { return nil }
    return SalvageCatalogue.empProfile(catalogueShipID: catalogue)
  }

  func salvageCuttingIsAllowed(
    _ body: SpaceBody, metadata: SalvageTargetMetadata,
    context: EncounterContext
  ) -> Bool {
    guard let physical = body.physical, physical.npc == nil, metadata.claimant == nil,
      metadata.ownership == .abandoned,
      !context.protection.protectedActors.contains(physical.identity),
      body.id != 0 || body.hull != .station
    else { return false }
    if let source = physical.empSource {
      guard let record = commander.savedEMPState?.records[source], isEMPDisabled(body),
        record.crewAboard == 0, record.pods.count + record.capturedCrewCount == record.crewTotal,
        record.wreck == metadata.wreck
      else { return false }
      return salvageProfile(for: body) != nil
    }
    guard let catalogue = physical.catalogueShipID else { return false }
    return SalvageCatalogue.eligibility(
      catalogueShipID: catalogue,
      ownership: metadata.ownership) == .allowed
  }
}
