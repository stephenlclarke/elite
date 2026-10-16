import Foundation

struct PreparedSalvageAdmissionHull: Sendable {
  let mesh: Mesh
  let hull: PreparedHull
}

extension Game {
  /// The broad sphere stays authoritative for unrelated actors. Only a ledger-offered
  /// fragment may replace its own live parent's sphere with an actual-mesh proof.
  mutating func releasedFragmentClearsParent(
    _ request: SpawnRequest, parent: ActorSnapshot, context: EncounterContext
  ) -> Bool {
    guard request.identity.producer == .salvage,
      request.identity.system == context.system, request.identity.visit == context.visit,
      let lot = commander.salvageLedger.offeredLot(for: request.identity),
      lot.identity.section.wreck.system == context.system,
      commander.salvageLedger.boundActor(for: lot.identity) == nil,
      !context.protection.protectedPayloads.contains(.salvage(lot.identity)),
      parent.identity.system == context.system, parent.identity.visit == context.visit,
      !context.protection.protectedActors.contains(parent.identity),
      let metadata = parent.salvage,
      [.wreck, .section].contains(metadata.category),
      metadata.ownership == .abandoned, metadata.claimant == nil,
      metadata.wreck == lot.identity.section.wreck,
      metadata.section == nil || metadata.section == lot.identity.section,
      let body = bodies.first(where: { $0.physical?.identity == parent.identity && $0.energy > 0 }),
      let physical = body.physical, physical.npc == nil,
      physical.salvage == metadata, physical.catalogueShipID == parent.catalogueShipID,
      commander.flightSimulation.pose.systemPoint(body.position) == parent.position,
      physical.velocity == parent.velocity,
      let catalogue = physical.catalogueShipID,
      let profile = SalvageCatalogue.profile(catalogueShipID: catalogue),
      profile.sections.contains(where: { $0.index == lot.identity.section.section }),
      SalvageCatalogue.eligibility(
        catalogueShipID: catalogue, ownership: metadata.ownership,
        activeStation: body.id == 0 && body.hull == .station) == .allowed
    else { return false }
    let fragmentMetadata = SalvageTargetMetadata(
      category: lot.category, ownership: lot.loot?.legality.ownership ?? .abandoned,
      claimant: nil, wreck: lot.identity.section.wreck, section: lot.identity.section,
      lot: lot.identity, bounds: .init(center: .init(0, 0, 0), radius: lot.halfExtents.length),
      workSurfaces: [])
    let expected = SpawnRequest(
      identity: request.identity, population: .cargo, hull: .cargo,
      position: lot.position, orientation: .init(), velocity: lot.velocity, npc: nil,
      rock: nil, payload: .salvage(lot.identity), priority: .ordinary,
      salvage: fragmentMetadata)
    guard request == expected else { return false }
    let mesh = gameplayMesh(for: body)
    let prepared: PreparedHull
    if let cached = salvageAdmissionGeometry[catalogue],
      cached.mesh.vertices == mesh.vertices, cached.mesh.faces == mesh.faces
    {
      prepared = cached.hull
    } else {
      guard let hull = try? PreparedHull(mesh: mesh) else { return false }
      salvageAdmissionGeometry[catalogue] = .init(mesh: mesh, hull: hull)
      prepared = hull
    }
    return HullSweepSafety.validatePlacement(
      center: lot.position, radius: lot.halfExtents.length,
      hull: prepared, pose: modelPose(of: body), requiredClearance: 8
    ).safe
  }
}
