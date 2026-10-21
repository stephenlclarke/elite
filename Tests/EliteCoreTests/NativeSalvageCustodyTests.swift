import Foundation
import Testing

@testable import EliteCore

struct NativeSalvageCustodyTests {
  @Test(arguments: ["wreck", "reserved", "companion", "legacy-current"])
  func completeSnapshotCensusRejectsAParentSharingAnotherCurrentCustodyActor(kind: String) throws {
    let actor = ActorIdentity(system: .init(galaxy: 0, system: 7), visit: 1, entity: 200)
    let distinct = ActorIdentity(system: actor.system, visit: actor.visit, entity: actor.entity + 1)
    let needsCurrentPlan = kind == "reserved" || kind == "companion"
    var fixture = try AlienLegacyFixture.make(
      definition: kind == "reserved" ? AlienModuleKind.energyCapacity.definitionID : nil,
      roles: kind == "reserved" ? [.thargoid, .militaryCapital] : [.militaryCapital],
      manifest: kind == "reserved" ? nil : [.init(commodity: .food, quantity: 2)],
      elapsed: needsCurrentPlan ? 0.5 : 1)
    if needsCurrentPlan {
      #expect(fixture.ledger.progress(fixture.plan.section) == 0.5)
      // Complete the original producer budget with an actual positive operation.
      let section = SalvageSectionProfile(
        index: 1, kind: .computer, localPosition: .init(10, 0, 0), normal: .init(0, 0, 1),
        radius: 10, workSeconds: 1, structural: true, technologyDefinitionIDs: [],
        sourceFaceIndex: 0)
      let result = fixture.ledger.advance(
        wreck: fixture.plan.section.wreck, section: section, pose: .init(),
        velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), tool: .cutter,
        elapsed: 0.5, operation: 1, conditions: NativePagedSalvageFixture.permitted,
        source: fixture.plan.source)
      guard case .released(let lots) = result, !lots.isEmpty else {
        throw SaveError.invalidCommander
      }
    }
    let exported = try fixture.ledger.exportNativeSection(fixture.plan.section)
    if needsCurrentPlan {
      #expect(exported.lastOperation == 1 && exported.partialWork == nil)
    }
    let owner = AlienLegacyFixture.owner
    var world: [AlienStorageWorldRecord]
    if kind == "legacy-current" {
      let imported = try NativeSalvageImport(
        ledger: fixture.ledger, section: fixture.plan.section, owner: owner, at: 1, previous: nil)
      var assigned = false
      world = imported.snapshot.world.map { record in
        guard !assigned, case .legacyCurrent(let current) = record,
          case .pending(let lot, let at, _, _) = current.state
        else { return record }
        assigned = true
        return .legacyCurrent(
          .init(
            id: current.id, owner: current.owner, claim: current.claim,
            state: .pending(lot: lot, at: at, offer: nil, binding: actor)))
      }
      #expect(assigned)
    } else {
      let planID = UUID()
      world = [
        .plan(
          .init(
            id: planID, owner: owner, seed: exported.seed, plan: exported.plan,
            inspectedAt: 0, requiredWorkSeconds: 1, workSeconds: 1,
            damagedTechnology: exported.damagedTechnology, depleted: exported.depleted,
            destroyed: false, lastOperation: exported.lastOperation, progress: exported.progress))
      ]
      let emissions = try SalvageSectionEmissionView(
        seed: exported.seed, plan: exported.plan, progress: exported.progress
      ).emissions()
      var assigned = false
      for (origin, item) in emissions.sorted(by: { $0.value.identity.lot < $1.value.identity.lot })
      {
        let lot = try #require(exported.evidence.pending.first { $0.identity == item.identity })
        let reserved: Bool
        if case .technology(let id, _, _) = lot.content {
          reserved = AlienModuleDefinition.isAttachmentDefinition(id)
        } else {
          reserved = false
        }
        let bind = !assigned && (kind == "reserved" ? reserved : !reserved)
        if bind { assigned = true }
        if reserved {
          guard case .planned(let index, 0) = origin else { throw SaveError.invalidCommander }
          world.append(
            .lot(
              .init(
                id: UUID(), owner: owner, plan: planID,
                itemIndex: index, issuedAt: 1,
                state: .pending(lot: lot, physicalTime: 1, offer: nil, binding: bind ? actor : nil))
            ))
        } else {
          world.append(
            .companion(
              .init(
                id: UUID(), owner: owner, plan: planID, origin: origin,
                issuedAt: 1,
                state: .pending(lot: lot, physicalTime: 1, offer: nil, binding: bind ? actor : nil))
            ))
        }
      }
      #expect(assigned)
    }
    if kind == "wreck" {
      // The other current actor is a second independent storage record. These typed
      // fixtures never confer the Commander's deterministic native source permission.
      world = []
      let second = WreckIdentity(system: actor.system, site: 600, lineage: 123)
      world.append(.nativeWreck(try wreck(second, owner: owner, actor: actor)))
    }
    let parent = try wreck(fixture.plan.section.wreck, owner: owner, actor: distinct)
    func snapshot(_ binding: ActorIdentity) -> AlienStorageSnapshot {
      let current = NativeSalvageWreck(
        id: parent.id, owner: parent.owner, identity: parent.identity,
        catalogueShipID: parent.catalogueShipID, seed: parent.seed, source: parent.source,
        bornAt: parent.bornAt, observedAt: parent.observedAt, binding: binding,
        motion: parent.motion, destroyedAt: nil)
      return .init(
        owner: owner, revision: 0, worldRevision: 1,
        world: world + [.nativeWreck(current)], sources: [], attachments: [], upgrades: [],
        receipts: [], commands: [])
    }
    try snapshot(distinct).validate()
    #expect(throws: AlienStorageError.duplicateKey) { try snapshot(actor).validate() }
    try snapshot(distinct).validate()
  }

  private func wreck(_ identity: WreckIdentity, owner: UUID, actor: ActorIdentity) throws
    -> NativeSalvageWreck
  {
    let profile = try #require(SalvageCatalogue.profile(catalogueShipID: "SH043"))
    let site = SalvageSite(
      identity: identity, catalogueShipID: profile.catalogueShipID,
      kind: .deepSpace, position: .init(0, 0, 300), orientation: .init(),
      velocity: .init(1, 2, 3), angularVelocity: .init(0, 0.01, 0), ownership: .abandoned)
    return .init(
      id: UUID(), owner: owner, identity: identity, catalogueShipID: site.catalogueShipID,
      seed: 0, source: .generated(site), bornAt: 0, observedAt: 1, binding: actor,
      motion: .init(
        pose: .init(position: site.position, orientation: site.orientation),
        velocity: site.velocity, angularVelocity: site.angularVelocity, energy: 100),
      destroyedAt: nil)
  }
}
