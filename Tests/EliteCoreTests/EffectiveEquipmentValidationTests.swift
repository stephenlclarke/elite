import Foundation
import Testing

@testable import EliteCore

private func commanderWithRatio(
  slot: ComponentFittingSlot, axis: ComponentAxis, value: Double, held: Bool = false,
  shipID: String = "SH023"
) throws -> Commander {
  var commander = Commander()
  commander.shipID = shipID
  try commander.prepareEquipment(legacy: false)
  let inventory = try #require(commander.equipmentInventory)
  let original = try #require(commander.fittedEquipment(at: slot))
  let component = try #require(original.component)
  var statistics = component.statistics
  statistics[axis] = value
  let id = held ? UUID() : component.id
  let changed = ComponentInstance(
    id: id, origin: component.origin, statistics: statistics,
    grade: component.grade, features: component.features, receipts: component.receipts)
  let item = OwnedEquipmentItem(
    id: id, node: original.node, provenance: held ? .grant("held fixture") : original.provenance,
    component: changed, location: held ? nil : original.location, boundHull: original.boundHull)
  commander.savedEquipmentInventory = try .init(
    owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
    items: held ? inventory.items + [item] : inventory.items.map { $0.id == item.id ? item : $0 })
  commander.mirrorFittedEquipment()
  // Establish that the former generic component/inventory boundary accepts these finite operands.
  try commander.equipmentInventory?.validate(
    context: EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull, performance: commander.performance))
  return commander
}

private struct EffectiveDestinationSnapshot: Equatable {
  let paths: Set<String>
  let files: [String: Data]
}

private func effectiveDestinationSnapshot(_ directory: URL) throws -> EffectiveDestinationSnapshot {
  .init(
    paths: Set(try FileManager.default.subpathsOfDirectory(atPath: directory.path)),
    files: try ScriptFinanceTestFixture.files(directory))
}

private func effectiveWorldObject(_ world: ScriptWorldSave) throws -> NSDictionary {
  let bytes = try ScriptValueStorage.encoder().encode(world)
  return try #require(JSONSerialization.jsonObject(with: bytes) as? NSDictionary)
}

private func expectEffectiveGamePreserved(_ actual: borrowing Game, _ before: borrowing Game) throws
{
  #expect(actual.commander == before.commander)
  let world = try effectiveWorldObject(actual.scriptWorldSave)
  #expect(world.isEqual(try effectiveWorldObject(before.scriptWorldSave)))
  #expect(actual.inventoryContextEpoch == before.inventoryContextEpoch)
  #expect(actual.nativeStationRuntimeEpoch == before.nativeStationRuntimeEpoch)
  #expect(actual.paused == before.paused && actual.selectedFlightTool == before.selectedFlightTool)
  #expect(actual.manualResidualFlight == before.manualResidualFlight)
  #expect(actual.autoPilot.targetID == before.autoPilot.targetID)
  #expect(actual.autoPilot.velocity == before.autoPilot.velocity)
  #expect(actual.dockingComputer == before.dockingComputer)
  #expect(actual.dischargeAudio.epoch == before.dischargeAudio.epoch)
  #expect(actual.dischargeAudio.events == before.dischargeAudio.events)
  #expect(actual.message == before.message && actual.messageTime == before.messageTime)
  #expect(actual.selection == before.selection && actual.equipmentMount == before.equipmentMount)
  #expect(actual.equipmentWorkTool == before.equipmentWorkTool)
  #expect(actual.inventoryActionSelection == before.inventoryActionSelection)
  #expect(actual.inventoryUpgradeChoice == before.inventoryUpgradeChoice)
  #expect(actual.scriptDurabilityAvailable == before.scriptDurabilityAvailable)
  #expect(actual.pendingNewSaveDestination == before.pendingNewSaveDestination)
}

/// This bodyless owned scene permits only explicit current mining-presence storage at publication.
private func effectivePublicationExpectation(_ before: borrowing Game) throws -> Commander {
  try #require(before.docked && before.dockedAtMainStation && before.screen == .status)
  try #require(before.bodies.isEmpty && before.commander.npcPersistence.count == 0)
  try #require(before.commander.nativeStations == nil && before.commander.savedEMPState == nil)
  try #require(before.commander.alienStorageState == nil)
  try #require(
    before.commander.scriptState.instances.isEmpty && before.commander.contracts.boards.isEmpty)
  try #require(before.commander.scriptState.calendarLedger != nil)
  var expected = before.commander
  try expected.prepareEquipment()
  expected.mirrorFittedEquipment()
  try #require(expected == before.commander)
  var mining = before.commander.miningLedgerForMigration(legacyMissing: false)
  try #require(mining.requiredPresencePinSystems.isEmpty)
  let system = Universe.systemsIncludingPlugh(number: expected.galaxy)[expected.system]
  try mining.migratePresence(
    current: .init(system: system, galaxy: expected.galaxy), historical: [])
  expected.miningLedger = mining
  return expected
}

struct EffectiveEquipmentValidationTests {
  @Test func finiteOperandsWhoseRuntimeProductsOverflowAreRefusedWithoutPublication() async throws {
    let cases: [(ComponentFittingSlot, ComponentAxis)] = [
      (.energy, .energyCapacity), (.energy, .energyRecharge),
      (.shield, .frontShieldCapacity), (.shield, .rearShieldCapacity),
      (.shield, .frontShieldRecharge), (.shield, .rearShieldRecharge),
      (.navigation, .jumpSpool), (.navigation, .jumpFuelCost),
    ]
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("commander.json")
    let writer = GameRuntime(game: Game(executive: false))
    try await writer.save(to: url)
    let bytes = try Data(contentsOf: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    try #require(pointer.schemaVersion == 26 && pointer.scope == "commander")
    let (valid, world) = try ScriptSaveStore.read(bytes, from: url)
    try #require(valid.valid && world.valid && world.consistent(with: valid))
    let destination = try effectiveDestinationSnapshot(directory)
    for (slot, axis) in cases {
      let context = Comment(rawValue: "actual fitted slot=\(slot), axis=\(axis), scalar=1e308")
      let commander = try commanderWithRatio(
        slot: slot, axis: axis, value: 1e308,
        shipID: [.frontShieldRecharge, .rearShieldRecharge].contains(axis) ? "SH171" : "SH023")
      let item = try #require(commander.fittedEquipment(at: slot))
      try #require(item.component?.statistics[axis] == 1e308)
      #expect(!commander.valid, context)
      #expect(throws: CommanderEquipmentError.invalidRuntimeStatistics, context) {
        try commander.validateEquipmentState()
      }
      var invalid = Game(executive: false)
      invalid.commander = commander
      invalid.screen = .status
      let runtime = GameRuntime(game: invalid, saveURL: url)
      // Capture after legitimate initializer effects, and prove the original bad device survives them.
      let before = await runtime.snapshot()
      try #require(before.commander.fittedEquipment(at: slot) == item)
      try #require(before.commander.fittedEquipment(at: slot)?.component?.statistics[axis] == 1e308)
      try #require(before.commander.equipmentInventory == commander.equipmentInventory)
      try #require(before.commander.equipmentPurchaseHistory == commander.equipmentPurchaseHistory)
      #expect(!before.commander.valid, context)
      await #expect(throws: CommanderEquipmentError.invalidRuntimeStatistics, context) {
        try await runtime.save(to: url)
      }
      let after = await runtime.snapshot()
      try expectEffectiveGamePreserved(after, before)
      #expect(try effectiveDestinationSnapshot(directory) == destination, context)
      var candidate = before
      let original = candidate
      #expect(throws: CommanderEquipmentError.invalidRuntimeStatistics, context) {
        try GameRuntime.writeCommander(&candidate, to: url)
      }
      try expectEffectiveGamePreserved(candidate, original)
      #expect(try effectiveDestinationSnapshot(directory) == destination, context)
    }
  }

  @Test func finiteFuelCostBeyondIntRangeIsRejectedBeforeAnyJumpConversion() throws {
    let commander = try commanderWithRatio(slot: .navigation, axis: .jumpFuelCost, value: 1e16)
    #expect(!commander.valid)
    #expect(throws: CommanderEquipmentError.self) { try commander.validateEquipmentState() }
    let supported = try commanderWithRatio(slot: .navigation, axis: .jumpFuelCost, value: 1e12)
    #expect(supported.valid)
    for galaxy in 0..<8 {
      let systems = Universe.systemsIncludingPlugh(number: galaxy)
      for system in systems {
        #expect(supported.jumpFuelCost(distance: systems[7].distance(to: system)) >= 0)
      }
    }
  }

  @Test func strongerFiniteGrandfatheredStatisticsRetainIdentityAndResourcesThroughSave()
    async throws
  {
    var commander = try commanderWithRatio(slot: .energy, axis: .energyCapacity, value: 1e100)
    commander.scriptState.calendarLedger = .init(origin: .newCommander)
    #expect(commander.valid && commander.performance.energy.isFinite)
    let original = try #require(commander.fittedEquipment(at: .energy))
    var expected = commander
    var policy = MiningLedger.legacyUnworked()
    let system = Universe.systemsIncludingPlugh(number: commander.galaxy)[commander.system]
    try policy.migratePresence(
      current: .init(system: system, galaxy: commander.galaxy), historical: [])
    expected.miningLedger = policy
    let runtime = GameRuntime(game: Game())
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    var historical = Game(executive: false)
    historical.commander = commander
    historical.energy = commander.performance.energy
    historical.frontShield = commander.shieldCapacity
    historical.rearShield = commander.rearShieldCapacity
    try ScriptSaveStore.write(commander: commander, world: historical.scriptWorldSave, to: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: url))
    #expect(pointer.schemaVersion == 25)
    try await runtime.load(from: url, persistMigrations: false)
    let loaded = await runtime.snapshot()
    #expect(loaded.commander == expected && loaded.energy == commander.performance.energy)
    #expect(loaded.commander.fittedEquipment(at: .energy) == original)
    try await runtime.save(to: url)
    try await runtime.load(from: url, persistMigrations: false)
    #expect(await runtime.snapshot().commander == expected)
    #expect(try NativeSaveTestFixture.readVersionedCommander(from: url) == expected)
  }

  @Test func tinyFuelCostsCannotOverflowSearchRadiusOrItsChartInteger() async throws {
    for cost in [0, 1e-308, 1e-18] {
      let commander = try commanderWithRatio(slot: .navigation, axis: .jumpFuelCost, value: cost)
      #expect(!commander.valid)
      #expect(throws: CommanderEquipmentError.self) { try commander.validateEquipmentState() }
    }
    let supported = try commanderWithRatio(slot: .navigation, axis: .jumpFuelCost, value: 1e-12)
    #expect(supported.valid)
    let original = try #require(supported.fittedEquipment(at: .navigation))
    var raw = Game(executive: false)
    let rawBefore = raw
    #expect(!raw.load(supported))
    try expectEffectiveGamePreserved(raw, rawBefore)
    var source = Game(executive: false)
    source.commander = supported
    source.screen = .status
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("commander.json")
    let writer = GameRuntime(game: source, saveURL: url)
    let before = await writer.snapshot()
    try #require(before.commander.fittedEquipment(at: .navigation) == original)
    try #require(before.commander.equipmentInventory == supported.equipmentInventory)
    try #require(before.commander.equipmentPurchaseHistory == supported.equipmentPurchaseHistory)
    let expected = try effectivePublicationExpectation(before)
    let expectedWorld = try effectiveWorldObject(before.scriptWorldSave)
    try await writer.save(to: url)
    let published = await writer.snapshot()
    try #require(published.commander == expected)
    try #require(expectedWorld.isEqual(try effectiveWorldObject(published.scriptWorldSave)))
    let bytes = try Data(contentsOf: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    try #require(pointer.format == "elite-script-save" && pointer.schemaVersion == 26)
    try #require(pointer.scope == "commander" && pointer.valueCodec == ScriptValueStorage.codec)
    let names = Set(["commander.json", "missions.json", "world.json", "contracts.json"])
    try #require(Set(pointer.hashes.keys) == names)
    let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: url)
    for name in names {
      let chunk = try Data(contentsOf: generation.appendingPathComponent(name))
      try #require(ScriptPackLibrary.hash(chunk) == pointer.hashes[name])
    }
    let (stored, storedWorld) = try ScriptSaveStore.read(bytes, from: url)
    try #require(stored == expected && storedWorld.valid && storedWorld.consistent(with: stored))
    try #require(expectedWorld.isEqual(try effectiveWorldObject(storedWorld)))
    let destination = try effectiveDestinationSnapshot(directory)
    let reader = GameRuntime()
    try await reader.load(from: url, persistMigrations: false)
    var game = await reader.snapshot()
    #expect(game.commander == expected)
    #expect(game.commander.fittedEquipment(at: .navigation) == original)
    #expect(
      game.commander.fittedEquipment(at: .navigation)?.component?.statistics[.jumpFuelCost] == 1e-12
    )
    #expect(game.commander.equipmentInventory == supported.equipmentInventory)
    #expect(game.commander.equipmentPurchaseHistory == supported.equipmentPurchaseHistory)
    #expect(expectedWorld.isEqual(try effectiveWorldObject(game.scriptWorldSave)))
    #expect(try effectiveDestinationSnapshot(directory) == destination)
    game.mapZoom = .search
    #expect(game.chartScaleFuel > 0 && game.jumpReach.search?.isFinite == true)
  }

  @Test func actualFittedDriveRequiresItsCombinedNavigationPolicyAtTheExistingBoundary() throws {
    let legacy = Commander()
    try #require(legacy.equipmentInventory == nil && legacy.savedEquipmentVersion == nil)
    #expect(legacy.valid && legacy.hyperspaceDrivePolicy?.activation == .timed(seconds: 10))
    for (ratio, accepted) in [(1e11, true), (1e11 + 1, false), (1e308, false)] {
      let commander = try commanderWithRatio(slot: .navigation, axis: .jumpSpool, value: ratio)
      let drive = try #require(commander.fittedComponent(at: .drive))
      try #require(drive.origin == HyperspaceDriveDefinition.template(for: .basic))
      try #require(drive.statistics[.jumpSpool] == 10)
      try #require(commander.fittedComponent(at: .navigation)?.statistics[.jumpSpool] == ratio)
      if accepted {
        #expect(commander.hyperspaceDrivePolicy?.activation == .timed(seconds: 1e12))
        #expect(commander.valid)
        try commander.validateEquipmentState()
      } else {
        #expect(commander.hyperspaceDrivePolicy == nil)
        #expect(commander.performance.spool == commander.nativePerformance.spool)
        #expect(!commander.valid)
        #expect(throws: CommanderEquipmentError.invalidRuntimeStatistics) {
          try commander.validateEquipmentState()
        }
      }
    }
  }

  @Test func invalidLegacyTankCountsRejectBeforeDerivedCapacityAndPreserveLoadState() async throws {
    let runtime = GameRuntime()
    let before = await runtime.snapshot()
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    for count in [Int.min, -1, 5, Int.max] {
      var commander = Commander()
      commander.fuelStorageUnits = count
      #expect(!commander.valid)
      let original = try JSONEncoder().encode(commander)
      try original.write(to: url)
      await #expect(throws: SaveError.self) { try await runtime.load(from: url) }
      let after = await runtime.snapshot()
      #expect(after.commander == before.commander && after.bodies == before.bodies)
      #expect(after.inventoryContextEpoch == before.inventoryContextEpoch)
      #expect(try Data(contentsOf: url) == original)
    }
  }

  @Test func heldUnsafeDeviceStaysOwnedButCannotReplaceAnOperatingSystem() throws {
    var commander = try commanderWithRatio(
      slot: .energy, axis: .energyCapacity, value: 1e308, held: true)
    #expect(commander.valid)
    let item = try #require(commander.equipmentInventory?.items.first { $0.location == nil })
    let before = commander
    let revision = try #require(commander.equipmentInventory).revision
    #expect(throws: EquipmentRuntimeError.self) {
      try commander.fitEquipment(item, at: .energy, expectedRevision: revision)
    }
    #expect(commander == before)
  }
}
