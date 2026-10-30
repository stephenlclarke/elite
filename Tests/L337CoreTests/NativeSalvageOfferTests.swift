import Foundation
import Testing

@testable import L337Core

struct NativeSalvageOfferTests {
  @Test(arguments: ["lot", "companion", "legacyCurrent"])
  func pureRecordOfferPreservesOriginalCustodyWithoutGrantingSceneAuthority(kind: String) throws {
    let original = try AlienLegacyFixture.make()
    let lot = try #require(original.ledger.pendingLots.first)
    let record = record(kind: kind, lot: lot)
    let pending = AlienNativeSalvageIndex.Pending(
      record: record.id, lot: lot, physicalTime: 100, offer: nil, binding: nil)
    let spawn = SpawnIdentity(
      system: lot.identity.section.wreck.system, visit: 1, sequence: 1, member: 0,
      producer: .salvage)
    let staged = try NativeSalvageOffer.stage(
      record, pending: pending, spawn: spawn, owner: AlienLegacyFixture.owner)
    // These constructed records exercise a pure transition only. No allocator,
    // validated world, writer, physical body or scene permission is supplied.
    switch (record, staged) {
    case (.lot(let old), .lot(let item)):
      #expect(item.id == old.id && item.owner == old.owner && item.plan == old.plan)
      #expect(item.itemIndex == old.itemIndex && item.issuedAt == old.issuedAt)
      #expect(item.state == .pending(lot: lot, physicalTime: 100, offer: spawn, binding: nil))
    case (.companion(let old), .companion(let item)):
      #expect(item.id == old.id && item.owner == old.owner && item.plan == old.plan)
      #expect(item.origin == old.origin && item.issuedAt == old.issuedAt)
      #expect(item.state == .pending(lot: lot, physicalTime: 100, offer: spawn, binding: nil))
    case (.legacyCurrent(let old), .legacyCurrent(let item)):
      #expect(item.id == old.id && item.owner == old.owner && item.claim == old.claim)
      #expect(item.state == .pending(lot: lot, at: 100, offer: spawn, binding: nil))
    default: Issue.record("Offer changed the original custody record kind")
    }
  }

  @Test(arguments: ["owner", "record", "lot", "time", "offered", "bound", "terminal", "kind"])
  func pureOfferRejectsMismatchedOrAlreadyOwnedCustody(mismatch: String) throws {
    let original = try AlienLegacyFixture.make()
    var lot = try #require(original.ledger.pendingLots.first)
    let value: AlienStorageWorldRecord
    if mismatch == "kind" {
      value = .legacySection(try original.section())
    } else {
      value = record(kind: "companion", lot: lot, terminal: mismatch == "terminal")
    }
    let spawn = SpawnIdentity(
      system: lot.identity.section.wreck.system, visit: 1, sequence: 1, member: 0,
      producer: .salvage)
    if mismatch == "lot" { lot.position.x += 0.01 }
    let pending = AlienNativeSalvageIndex.Pending(
      record: mismatch == "record" ? UUID() : value.id, lot: lot,
      physicalTime: mismatch == "time" ? 101 : 100,
      offer: mismatch == "offered" ? spawn : nil,
      binding: mismatch == "bound" ? .init(system: spawn.system, visit: 1, entity: 2) : nil)
    #expect(throws: AlienStorageError.self) {
      try NativeSalvageOffer.stage(
        value, pending: pending, spawn: spawn,
        owner: mismatch == "owner" ? UUID() : AlienLegacyFixture.owner)
    }
  }

  @Test func actualNativeOfferRequiresExactCurrentContextSourceAndWholeRequest() async throws {
    let released = try await NativeSalvageAdmissionTestFixture.released()
    let (original, pending, request) = try NativeSalvageAdmissionTestFixture.offered(released)
    let context = try #require(original.gameplayContext())
    #expect(original.nativeOfferedSalvageLot(for: request, context: context) == pending.lot)
    let savedWorld = try #require(original.commander.alienStorageState?.current.snapshot)
    let originalLedger = original.commander.salvageLedger
    for mismatch in [
      "sequence", "producer", "system", "visit", "member", "position", "velocity", "bounds",
      "payload", "energy", "orientation", "owner", "reference", "context revision",
      "context time", "context visit", "context system", "context player",
    ] {
      var game = original
      var changed = request
      var observed = context
      switch mismatch {
      case "sequence", "producer", "system", "visit", "member":
        changed = NativeSalvageAdmissionTestFixture.changedRequest(
          request,
          identity: .init(
            system: mismatch == "system" ? .init(galaxy: 7, system: 255) : request.identity.system,
            visit: request.identity.visit + (mismatch == "visit" ? 1 : 0),
            sequence: mismatch == "sequence" ? UInt64.max - 1 : request.identity.sequence,
            member: mismatch == "member" ? 1 : 0,
            producer: mismatch == "producer" ? .cargo : .salvage))
      case "position":
        changed = NativeSalvageAdmissionTestFixture.changedRequest(
          request, position: request.position + .init(0.01, 0, 0))
      case "velocity":
        changed = NativeSalvageAdmissionTestFixture.changedRequest(
          request, velocity: request.velocity + .init(0.01, 0, 0))
      case "bounds":
        let metadata = try #require(request.salvage)
        changed = NativeSalvageAdmissionTestFixture.changedRequest(
          request,
          metadata: .init(
            category: metadata.category, ownership: metadata.ownership, claimant: nil,
            wreck: metadata.wreck, section: metadata.section, lot: metadata.lot,
            bounds: .init(center: .init(0, 0, 0), radius: 0.1), workSurfaces: []))
      case "payload":
        changed = NativeSalvageAdmissionTestFixture.changedRequest(
          request, payload: .salvage(.init(section: pending.lot.identity.section, lot: UInt16.max)))
      case "energy": changed.energy = 1
      case "orientation":
        var basis = Basis3()
        basis.rotate(pitch: 0.1, roll: 0, yaw: 0)
        changed = NativeSalvageAdmissionTestFixture.changedRequest(request, orientation: basis)
      case "owner":
        var foreign = Commander()
        try foreign.prepareEquipment(legacy: false)
        game.commander.savedEquipmentInventory = foreign.equipmentInventory
      case "reference": game.commander.savedAlienStorageReference = nil
      default:
        observed = NativeSalvageAdmissionTestFixture.changedContext(context, mismatch: mismatch)
      }
      #expect(game.nativeOfferedSalvageLot(for: changed, context: observed) == nil)
      #expect(game.commander.alienStorageState?.current.snapshot == savedWorld)
      #expect(game.commander.salvageLedger == originalLedger)
      #expect(game.bodies == original.bodies)
    }
  }

  @Test func nativeOfferStagingRejectsStaleSourceAndUnallocatedNamespaceWithoutMutation()
    async throws
  {
    let released = try await NativeSalvageAdmissionTestFixture.released()
    var (original, pending) = try NativeSalvageAdmissionTestFixture.parked(released)
    let context = try #require(original.gameplayContext())
    let allocated = original.commander.salvageLedger.reserveNativeSpawnIdentity(
      system: context.system, visit: context.visit)
    let spawn = try #require(allocated)
    for mismatch in [
      "context revision", "context time", "context visit", "context system", "context player",
      "unallocated", "foreign spawn", "stale spawn", "wrong producer", "wrong member",
      "record", "lot", "time", "owner", "reference", "offered", "bound",
    ] {
      var game = original
      let observed = NativeSalvageAdmissionTestFixture.changedContext(context, mismatch: mismatch)
      let identity = SpawnIdentity(
        system: mismatch == "foreign spawn" ? .init(galaxy: 7, system: 255) : spawn.system,
        visit: spawn.visit + (mismatch == "stale spawn" ? 1 : 0),
        sequence: mismatch == "unallocated" ? UInt64.max - 1 : spawn.sequence,
        member: mismatch == "wrong member" ? 1 : 0,
        producer: mismatch == "wrong producer" ? .cargo : .salvage)
      var lot = pending.lot
      if mismatch == "lot" { lot.position.x += 0.01 }
      let supplied = AlienNativeSalvageIndex.Pending(
        record: mismatch == "record" ? UUID() : pending.record, lot: lot,
        physicalTime: pending.physicalTime + (mismatch == "time" ? 0.01 : 0),
        offer: mismatch == "offered" ? spawn : nil,
        binding: mismatch == "bound" ? context.player.identity : nil)
      if mismatch == "owner" {
        var foreign = Commander()
        try foreign.prepareEquipment(legacy: false)
        game.commander.savedEquipmentInventory = foreign.equipmentInventory
      } else if mismatch == "reference" {
        game.commander.savedAlienStorageReference = nil
      }
      let before = game.commander
      let bodies = game.bodies
      let staged = game.stageNativeSalvageOffer(supplied, spawn: identity, context: observed)
      #expect(!staged)
      #expect(game.commander == before && game.bodies == bodies)
    }
  }

  private func record(kind: String, lot: SalvageLot, terminal: Bool = false)
    -> AlienStorageWorldRecord
  {
    let id = AlienLegacyFixture.uuid(901)
    let plan = AlienLegacyFixture.uuid(902)
    switch kind {
    case "lot":
      return .lot(
        .init(
          id: id, owner: AlienLegacyFixture.owner, plan: plan, itemIndex: 0, issuedAt: 99,
          state: .pending(lot: lot, physicalTime: 100, offer: nil, binding: nil)))
    case "companion":
      return .companion(
        .init(
          id: id, owner: AlienLegacyFixture.owner, plan: plan, origin: .structural, issuedAt: 99,
          state: terminal
            ? .destroyed(at: 100)
            : .pending(lot: lot, physicalTime: 100, offer: nil, binding: nil)))
    default:
      return .legacyCurrent(
        .init(
          id: id, owner: AlienLegacyFixture.owner, claim: plan,
          state: .pending(lot: lot, at: 100, offer: nil, binding: nil)))
    }
  }
}
