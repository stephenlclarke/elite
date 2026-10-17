import Foundation
import Testing

@testable import EliteCore

private func modularDriveShop() throws -> Game {
  var game = Game(executive: false)
  game.screen = .equipment
  game.commander.credits = 1_000_000
  game.commander.system = try #require(game.systems.first { $0.technology >= 12 }?.id)
  try game.commander.prepareEquipment(legacy: false)
  return game
}
private func purchaseDrive(_ tier: HyperspaceDriveTier, game: inout Game) throws {
  game.selection = try #require(Equipment.all.firstIndex { $0.name == tier.label })
  game.purchase()
  try #require(
    game.commander.fittedEquipment(at: .drive)?.node == HyperspaceDriveDefinition.node(for: tier))
}

struct HyperspaceDriveRuntimeTests {
  @Test func standardDriveIsOneRealIntrinsicDeviceAndPreparingItAgainDoesNotMintAnything() throws {
    var commander = Commander()
    let native = commander.nativePerformance
    try commander.prepareEquipment(legacy: false)
    let item = try #require(commander.fittedEquipment(at: .drive))
    #expect(
      item.node == HyperspaceDriveDefinition.node(for: .basic) && item.provenance == .standard)
    #expect(EquipmentIssueTransactions.isIntrinsicFoundation(item))
    #expect(Commander.commonEquipmentUnitCost(for: item) == 0)
    #expect(commander.performance.spool == 10 && commander.nativePerformance == native)
    let before = commander
    try commander.prepareEquipment()
    #expect(commander == before && commander.savedEquipmentVersion == 3)
  }

  @Test func existingVersionTwoMigrationRetainsEveryOwnedItemAndPaidHistoryExactly() throws {
    var commander = Commander()
    try commander.prepareEquipment(legacy: false)
    let current = try #require(commander.equipmentInventory)
    let context = EquipmentRuntimeCatalog.context(
      owner: current.owner, hull: current.activeHull,
      performance: commander.nativePerformance)
    commander.savedEquipmentInventory = try current.applyingBatch(
      items: current.items.filter { $0.location?.slot != .drive },
      expectedRevision: current.revision, context: context)
    commander.savedEquipmentVersion = 2
    commander.mirrorFittedEquipment()
    try commander.validateEquipmentState()
    let old = commander
    let oldItems = try #require(old.equipmentInventory?.items)
    try commander.prepareEquipment()
    let migrated = try #require(commander.equipmentInventory)
    #expect(migrated.items.filter { oldItems.map(\.id).contains($0.id) } == oldItems)
    #expect(migrated.items.count == oldItems.count + 1)
    #expect(commander.equipmentPurchaseHistory == old.equipmentPurchaseHistory)
    #expect(
      commander.cargo == old.cargo && commander.credits == old.credits && commander.fuel == old.fuel
    )
    #expect(
      commander.equipmentOwnerID == old.equipmentOwnerID
        && commander.hullInstanceID == old.hullInstanceID)
    let once = commander
    try commander.prepareEquipment()
    #expect(commander == once)
  }

  @Test func actualShopDebitsBothSequentialDrivesAndCannotSkipThePaidPredecessor() throws {
    var game = try modularDriveShop()
    let advanced = try #require(
      Equipment.all.first { $0.name == HyperspaceDriveTier.advanced.label })
    #expect(throws: (any Error).self) { _ = try game.quoteEquipmentPurchase(advanced) }
    let before = game.commander.credits
    try purchaseDrive(.intermediate, game: &game)
    #expect(game.commander.credits == before - 50000)
    #expect(game.commander.performance.spool == 5)
    try purchaseDrive(.advanced, game: &game)
    #expect(game.commander.credits == before - 200000)
    #expect(game.commander.performance.spool == 1)
    let paid = game.commander.equipmentPurchaseHistory?.paid ?? []
    #expect(paid.filter { $0.node.family == HyperspaceDriveDefinition.purchaseFamily }.count == 2)
    #expect(
      game.commander.equipmentInventory?.items.filter {
        $0.node.family == HyperspaceDriveDefinition.purchaseFamily
      }.count == 3)
    #expect(game.commander.valid)
  }

  @Test func actualAdvancedJumpUsesOneSecondAndFiniteFuelWhileClassicMassLockStaysIntact() throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    game.speed = 0
    game.bodies = [.init(id: 42, hull: .cobra, position: .init(0, 0, 500))]
    game.celestials = []
    game.ensurePhysicalActors()
    let destination = try #require(
      game.knownSystems.filter {
        $0.id != game.commander.system && $0.id != Plugh.systemID
          && game.currentSystem.distance(to: $0) > 0
          && game.currentSystem.distance(to: $0) <= game.commander.maximumJumpDistance
      }.min { game.currentSystem.distance(to: $0) < game.currentSystem.distance(to: $1) })
    game.selectedSystem = destination.id
    let fuel = game.commander.fuel
    let debit = game.commander.jumpFuelCost(distance: game.currentSystem.distance(to: destination))
    game.beginHyperspace()
    #expect(game.jumpCountdown == nil && game.commander.fuel == fuel)
    try game.commander.grantEquipment(
      HyperspaceDriveTier.advanced.label, at: .drive,
      provenance: .grant("Modular travel boundary"))
    #expect(game.massLocked && !game.hyperspaceMassLocked)
    game.beginHyperspace()
    try #require(game.jumpCountdown == 1)
    for _ in 0..<12 where game.jumpCountdown != nil { game.tick(delta: 0.1) }
    #expect(game.commander.system == destination.id && game.jumpCountdown == nil)
    #expect(game.commander.fuel == fuel - debit && debit > 0 && !game.commander.unlimitedFuel)
    #expect(game.commander.flightSimulation.system == game.systemIdentity)
  }

  @Test func celestialHyperspaceScaleDoesNotChangeTheInSystemJumpCollisionBoundary() throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    game.bodies = []
    game.celestials = [.init(kind: .planet, position: .init(0, 0, 3500), radius: 1000)]
    try game.commander.grantEquipment(
      HyperspaceDriveTier.advanced.label, at: .drive,
      provenance: .grant("Modular mass lock boundary"))
    #expect(game.massLocked && !game.hyperspaceMassLocked)
    let pose = game.commander.flightSimulation.pose
    game.inSystemJump()
    #expect(game.commander.flightSimulation.pose == pose)
  }

  @Test func actualStockDriveSaveUsesVersionedHeaderAndLegacyDowngradeRefusesIt() async throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    let before = await runtime.snapshot()
    try await runtime.save(to: file)
    let bytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == 25)
    let (saved, _) = try ScriptSaveStore.read(bytes, from: file)
    #expect(saved.equipmentInventory == before.commander.equipmentInventory)
    #expect(saved.performance.spool == 10)
    var object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    object["schemaVersion"] = 24
    let bad = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: SaveError.self) { _ = try ScriptSaveStore.read(bad, from: file) }
  }
}

extension HyperspaceDriveRuntimeTests {
  @Test func fullLegacyInventoryGainsOnlyItsReservedStockDriveWithoutLosingAnyOwnedItem() throws {
    var commander = Commander()
    try commander.prepareEquipment(legacy: false)
    let current = try #require(commander.equipmentInventory)
    let context = EquipmentRuntimeCatalog.context(
      owner: current.owner, hull: current.activeHull, performance: commander.nativePerformance)
    var oldItems = current.items.filter { $0.location?.slot != .drive }
    while oldItems.count < OwnedEquipmentInventory.maximumCount {
      oldItems.append(
        .init(
          id: UUID(), node: EquipmentRuntimeCatalog.standardMissile, provenance: .standard))
    }
    commander.savedEquipmentInventory = try current.applyingBatch(
      items: oldItems, expectedRevision: current.revision, context: context)
    commander.savedEquipmentVersion = 2
    commander.mirrorFittedEquipment()
    try commander.validateEquipmentState()
    let old = commander
    try commander.prepareEquipment()
    let migrated = try #require(commander.equipmentInventory)
    #expect(migrated.items.count == 257 && migrated.ordinaryItemCount == 256)
    #expect(migrated.items.filter { oldItems.map(\.id).contains($0.id) } == oldItems)
    #expect(commander.equipmentPurchaseHistory == old.equipmentPurchaseHistory)
    #expect(commander.credits == old.credits && commander.fuel == old.fuel)
    let stored = try JSONDecoder().decode(Commander.self, from: JSONEncoder().encode(commander))
    #expect(stored == commander && stored.valid)
    let extra = OwnedEquipmentItem(
      id: UUID(), node: EquipmentRuntimeCatalog.standardMissile, provenance: .standard)
    var candidate = migrated
    #expect(throws: OwnedEquipmentError.capacity) {
      try candidate.admit(extra, expectedRevision: migrated.revision, context: context)
    }
    #expect(candidate == migrated)
  }

  @Test func stockDriveReserveFollowsValidatedBirthIdentityThroughPromotionStorageAndReload()
    throws
  {
    var commander = Commander()
    try commander.prepareEquipment(legacy: false)
    let stock = try #require(commander.fittedEquipment(at: .drive))
    var component = try #require(stock.component)
    for index in 0..<4 {
      let upgrade = ComponentUpgrade(
        identity: .service(UUID()), boundComponent: stock.id,
        origin: component.origin.identity, basisPoints: [.jumpSpool: 1500])
      let revision = UInt64(index)
      let quote = try ComponentProgression.quote(
        component: component, item: upgrade,
        definition: HyperspaceDriveDefinition.componentDefinition, inventoryRevision: revision)
      component = try ComponentProgression.apply(
        quote, component: component, item: upgrade,
        definition: HyperspaceDriveDefinition.componentDefinition, inventoryRevision: revision
      ).component
    }
    try #require(component.grade == HyperspaceDriveDefinition.template(for: .intermediate).identity)
    let promoted = OwnedEquipmentItem(
      id: stock.id, node: stock.node, provenance: stock.provenance,
      component: component, location: nil)
    let restored = try JSONDecoder().decode(
      OwnedEquipmentItem.self, from: JSONEncoder().encode(promoted))
    #expect(restored == promoted && restored.isReservedStockDrive)
    let purchased = OwnedEquipmentItem(
      id: stock.id, node: stock.node,
      provenance: .paid(owner: UUID(), transaction: UUID()), component: component)
    #expect(!purchased.isReservedStockDrive)
    let duplicateID = UUID()
    let duplicate = OwnedEquipmentItem(
      id: duplicateID, node: stock.node, provenance: .standard,
      component: EquipmentRuntimeCatalog.stockComponent(for: stock.node, id: duplicateID))
    #expect(throws: OwnedEquipmentError.capacity) {
      _ = try OwnedEquipmentInventory(
        owner: UUID(), activeHull: UUID(), items: [restored, duplicate])
    }
  }
}
