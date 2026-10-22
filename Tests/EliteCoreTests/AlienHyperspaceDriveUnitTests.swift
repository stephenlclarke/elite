import Foundation
import Testing

@testable import EliteCore

private let recoveredAlienDrive = AlienModuleKind.hyperspaceDrive

private func driveDestination(_ game: borrowing Game) -> StarSystem? {
  let current = game.currentSystem
  let reach = game.commander.maximumJumpDistance
  return game.knownSystems.filter {
    $0.id != current.id && $0.id != Plugh.systemID
      && current.distance(to: $0) > 0 && current.distance(to: $0) <= reach
  }.min { current.distance(to: $0) < current.distance(to: $1) }
}

private func fitRecoveredAlienDrive(_ file: URL) async throws -> (GameRuntime, UUID) {
  let (runtime, id) = try await recoveredModuleAtActualPlughDock(file, kind: recoveredAlienDrive)
  let before = await runtime.snapshot()
  #expect(before.commander.fittedAlienHyperspaceDrivePolicy == nil)
  let command = try #require(before.inventoryActionPreview(for: .alienAttachment(id)).command)
  let result = await runtime.equipmentTransaction(.inventory(command))
  try #require(result.applied)
  return (runtime, id)
}

struct AlienHyperspaceDriveUnitTests {
  @Test func alienOnlyLootProducesTypedDriveWithoutScalarUpgradeOrOrdinaryFit() throws {
    let (_, plan, lot) = try AlienStorageTestFixture.plan(
      site: 41, definition: recoveredAlienDrive.definitionID)
    #expect(plan.profile == .thargoid && plan.items.count == 1)
    #expect(try AlienModuleDefinition.kind(for: lot) == recoveredAlienDrive)
    #expect(lot.loot?.effect == .alienHyperspaceDrive && lot.loot?.bonusBasisPoints == 0)
    #expect(!recoveredAlienDrive.supportsUpgrade && recoveredAlienDrive.axes.isEmpty)
    #expect(SalvageDefinitions.definition(id: recoveredAlienDrive.upgradeDefinitionID) == nil)
    #expect(!AlienModuleDefinition.isAttachmentDefinition(recoveredAlienDrive.upgradeDefinitionID))
    #expect(throws: AlienAttachmentError.invalidSource) {
      try AlienModuleDefinition.upgradeBonus(for: lot, kind: recoveredAlienDrive)
    }
    let definition = try #require(
      SalvageDefinitions.definition(id: recoveredAlienDrive.definitionID))
    let context = SalvageFitContext(
      stockFacingMask: 1, installedFacingMask: 1, retrofitFacingMask: 0,
      stockPylons: 1, installedPylons: 1, structuralPylonLimit: 8, storedEmptyPods: 0,
      fittedLasers: [:], loadedMissiles: 0)
    #expect(definition.category == .driveTechnology && definition.provenance == .alien)
    for axis: SalvageUpgradeAxis? in [nil, .spoolDuration] {
      #expect(
        SalvageDefinitions.compatibility(
          definition: definition, action: .fit(axis: axis, mount: nil), context: context)
          == .refused(.incompatibleHardware))
    }
    let boundary = try recoveredAlienBoundaryGame(
      definitionID: recoveredAlienDrive.definitionID, roles: [.thargoid])
    let held = try #require(boundary.commander.salvageLedger.inventory.first)
    let before = boundary.commander
    #expect(boundary.inventoryActionPreview(for: .recovered(held)).command == nil)
    #expect(throws: SalvageComponentEffectError.unsupportedEffect) {
      try boundary.commander.quoteRecoveredUpgrade(
        lot: held.identity, axis: .spoolDuration, slot: .drive)
    }
    #expect(
      boundary.commander == before && boundary.commander.fittedAlienHyperspaceDrivePolicy == nil)
    for role in SalvageSourceRole.allCases where role != .thargoid {
      let source = SalvageLootSource(
        roles: [role], legalValue: 0, economy: 3, technology: 12, ownership: .abandoned)
      for seed in UInt64(0)..<100 {
        let human = SalvageLootProfiles.plan(section: plan.section, seed: seed, source: source)
        #expect(!human.items.contains { $0.effect == .alienHyperspaceDrive })
      }
    }
  }

  @Test func forgedDriveEvidenceAndReplayCannotCreateOwnedCapability() throws {
    let (_, plan, lot) = try AlienStorageTestFixture.plan(
      site: 42, definition: recoveredAlienDrive.definitionID)
    let wrongSeed = try #require(
      (UInt64(0)..<2000).first {
        SalvageLootProfiles.plan(section: plan.section, seed: $0, source: plan.source) != plan
      })
    #expect(throws: AlienStorageError.invalidJoin) {
      try SalvageSectionEmissionView(
        seed: wrongSeed, plan: plan,
        progress: .init(
          issued: [0], discarded: [false], structuralUnits: 0, issuedStructural: 0,
          materialKind: .alloys, nextLot: 0)
      ).validate()
    }
    let original = try #require(lot.loot)
    for variant in 0..<3 {
      let invalid = SalvageLootItem(
        identity: original.identity, content: original.content,
        effect: variant == 1 ? .scalar(axes: [.spoolDuration]) : original.effect,
        bonusBasisPoints: variant == 2 ? 1000 : 0,
        massKg: original.massKg, halfExtents: original.halfExtents,
        provenance: variant == 0 ? .human : .alien,
        saleValueTenths: original.saleValueTenths, legality: original.legality,
        requiresChunking: original.requiresChunking)
      #expect(throws: AlienAttachmentError.invalidSource) {
        try AlienModuleDefinition.validatePlanned(invalid)
      }
    }
    var fixture = AlienStorageTestFixture()
    let id = try fixture.acquire(kind: recoveredAlienDrive)
    let snapshot = fixture.snapshot
    let duplicate = AlienStorageSnapshot(
      owner: snapshot.owner, revision: snapshot.revision, worldRevision: snapshot.worldRevision,
      world: snapshot.world, sources: snapshot.sources,
      attachments: snapshot.attachments + fixture.attachments,
      upgrades: snapshot.upgrades, receipts: snapshot.receipts, commands: snapshot.commands)
    #expect(throws: (any Error).self) { try duplicate.validate() }
    let old = try #require(fixture.attachments.first)
    fixture.attachments = [
      .init(
        id: id, owner: old.owner, kind: old.kind, source: old.source,
        disposition: .fitted(hull: AlienStorageTestFixture.hull), contributionBasisPoints: 0)
    ]
    // A plausible fitted record without its relocation command is not a validated witness.
    #expect(throws: (any Error).self) { try fixture.snapshot.validate() }
  }

  @Test func pagedDriveCustodyRoundTripKeepsIdentityAndOtherHullIsolation() throws {
    let directory = try nativeSalvageTestDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    var fixture = AlienStorageTestFixture()
    let id = try fixture.acquire(kind: recoveredAlienDrive)
    try fixture.fit(id)
    let before = fixture.snapshot
    let reference = try AlienStoragePageStore.write(snapshot: before, previous: nil, to: directory)
    let restored = try AlienStoragePageStore.read(
      reference: reference, expectedOwner: before.owner, from: directory)
    #expect(restored == before)
    let witness = try AlienStorageValidatedState(validating: restored)
    #expect(witness.summaries(for: AlienStorageTestFixture.hull)[recoveredAlienDrive]?.count == 1)
    #expect(witness.summaries(for: UUID())[recoveredAlienDrive]?.count == 0)
    #expect(
      witness.summaries(for: AlienStorageTestFixture.hull)[recoveredAlienDrive]?.bonusBasisPoints
        == 0)
    let base = AlienAttachmentBase(
      energyCapacity: 200, energyRecharge: 20, frontShieldCapacity: 100,
      rearShieldCapacity: 100, frontShieldRecharge: 10, rearShieldRecharge: 10)
    let effects = try AlienAttachmentEffects.resolve(
      validated: witness, owner: before.owner, activeHull: AlienStorageTestFixture.hull,
      normalBase: base)
    #expect(effects.effective == base && effects.energyModuleCount == 0)
    #expect(throws: (any Error).self) {
      try AlienStoragePageStore.read(reference: reference, expectedOwner: UUID(), from: directory)
    }
    try fixture.retire(id)
    let retired = try AlienStorageValidatedState(validating: fixture.snapshot)
    #expect(retired.summaries(for: AlienStorageTestFixture.hull)[recoveredAlienDrive]?.count == 0)
    #expect(fixture.snapshot.sources == before.sources)
  }

  @Test func actualRecoveryAndPlughFittingSurviveColdSaveAndJumpImmediatelyThroughMassLock()
    async throws
  {
    let folder = try nativeSalvageTestDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let (runtime, id) = try await fitRecoveredAlienDrive(file)
    let fitted = await runtime.snapshot()
    try await runtime.load(from: file, persistMigrations: false)
    let loaded = await runtime.snapshot()
    #expect(loaded.commander.alienStorageState == fitted.commander.alienStorageState)
    #expect(loaded.commander.fittedAlienHyperspaceDrivePolicy?.activation == .immediate)
    #expect(loaded.commander.fittedAlienHyperspaceDrivePolicy?.massLockScale == 0)
    #expect(
      loaded.commander.alienStorageState?.current.snapshot.attachments.first { $0.id == id }?.kind
        == recoveredAlienDrive)
    await runtime.nativeCommand { $0.launch() }
    let launched = await runtime.snapshot()
    try #require(!launched.docked && launched.massLocked && !launched.hyperspaceMassLocked)
    let destination = try #require(driveDestination(launched))
    let fuel = launched.commander.fuel
    let debit = launched.commander.jumpFuelCost(
      distance: launched.currentSystem.distance(to: destination))
    await runtime.nativeCommand {
      $0.selectedSystem = destination.id
      $0.beginHyperspace()
    }
    let arrived = await runtime.snapshot()
    #expect(arrived.commander.system == destination.id && arrived.jumpCountdown == nil)
    #expect(arrived.commander.fuel == fuel - debit && debit > 0)
    #expect(arrived.commander.valid && !arrived.commander.unlimitedFuel)
    #expect(
      arrived.commander.alienStorageState?.current.snapshot.sources
        == fitted.commander.alienStorageState?.current.snapshot.sources)
    #expect(
      arrived.commander.alienStorageState?.current.snapshot.attachments
        == fitted.commander.alienStorageState?.current.snapshot.attachments)
  }

  @Test func storingDriveRevokesCapabilityAndStaleOrUndockedRefitDoesNothing() async throws {
    let folder = try nativeSalvageTestDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let (runtime, id) = try await fitRecoveredAlienDrive(file)
    let fitted = await runtime.snapshot()
    let store = try #require(fitted.inventoryActionPreview(for: .alienAttachment(id)).command)
    let result = await runtime.equipmentTransaction(.inventory(store))
    try #require(result.applied)
    let stored = await runtime.snapshot()
    #expect(stored.commander.fittedAlienHyperspaceDrivePolicy == nil)
    #expect(stored.commander.hyperspaceDrivePolicy?.activation == .timed(seconds: 10))
    #expect(stored.commander.credits == fitted.commander.credits)
    #expect(stored.commander.equipmentInventory == fitted.commander.equipmentInventory)
    #expect(
      stored.commander.alienStorageState?.current.snapshot.sources
        == fitted.commander.alienStorageState?.current.snapshot.sources)
    let stale = await runtime.equipmentTransaction(.inventory(store))
    #expect(!stale.applied)
    var undocked = stored
    let fit = try #require(undocked.inventoryActionPreview(for: .alienAttachment(id)).command)
    undocked.invalidateNativeStationAuthority()
    let before = undocked.commander
    #expect(!undocked.performInventoryCommand(fit) && undocked.commander == before)
    undocked.launch()
    #expect(undocked.commander.fittedAlienHyperspaceDrivePolicy == nil)
    #expect(!undocked.nativeAlienFittingAvailable)
  }

  @Test func fittedAlienDriveRetainsFuelElectricalAndOrdinaryDriveGates() async throws {
    let folder = try nativeSalvageTestDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let (runtime, _) = try await fitRecoveredAlienDrive(file)
    var game = await runtime.snapshot()
    let docked = game.commander
    game.beginHyperspace()
    #expect(game.commander == docked && game.jumpCountdown == nil)
    game.launch()
    try #require(!game.docked && game.massLocked && !game.hyperspaceMassLocked)
    let destination = try #require(driveDestination(game))
    game.selectedSystem = destination.id
    game.commander.fuel = 0
    let empty = game.commander
    game.beginHyperspace()
    #expect(game.commander == empty && game.jumpCountdown == nil)
    game.commander.fuel = game.commander.fuelCapacity
    var reserve = try #require(
      ElectricalReserve(
        capacity: game.commander.performance.energy,
        recharge: game.commander.performance.recharge * game.commander.energyRechargeMultiplier,
        at: game.commander.flightSimulation.physicalTime))
    let disabled = reserve.drain(reserve.capacity, at: reserve.physicalTime)
    try #require(disabled)
    game.commander.savedPlayerElectrical = reserve
    try #require(game.playerEMPDisabled)
    let before = game.commander
    game.beginHyperspace()
    #expect(game.commander == before && game.jumpCountdown == nil)
    game.commander.savedPlayerElectrical = nil
    let inventory = try #require(game.commander.equipmentInventory)
    game.commander.savedEquipmentInventory = try inventory.applyingBatch(
      items: inventory.items.map {
        guard $0.location?.slot == .drive else { return $0 }
        return .init(
          id: $0.id, node: $0.node, provenance: $0.provenance, component: $0.component,
          location: nil)
      }, expectedRevision: inventory.revision,
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: inventory.activeHull,
        performance: game.commander.nativePerformance))
    game.commander.mirrorFittedEquipment()
    let missing = game.commander
    game.beginHyperspace()
    #expect(game.commander == missing && game.jumpCountdown == nil)
  }
}
