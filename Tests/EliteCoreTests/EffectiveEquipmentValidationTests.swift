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

struct EffectiveEquipmentValidationTests {
  @Test func finiteOperandsWhoseRuntimeProductsOverflowAreRefusedWithoutPublication() async throws {
    let cases: [(ComponentFittingSlot, ComponentAxis)] = [
      (.energy, .energyCapacity), (.energy, .energyRecharge),
      (.shield, .frontShieldCapacity), (.shield, .rearShieldCapacity),
      (.shield, .frontShieldRecharge), (.shield, .rearShieldRecharge),
      (.navigation, .jumpSpool), (.navigation, .jumpFuelCost),
    ]
    let runtime = GameRuntime()
    let before = await runtime.snapshot()
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    for (slot, axis) in cases {
      let commander = try commanderWithRatio(
        slot: slot, axis: axis, value: 1e308,
        shipID: [.frontShieldRecharge, .rearShieldRecharge].contains(axis) ? "SH171" : "SH023")
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
    let commander = try commanderWithRatio(slot: .energy, axis: .energyCapacity, value: 1e100)
    #expect(commander.valid && commander.performance.energy.isFinite)
    let original = try #require(commander.fittedEquipment(at: .energy))
    let runtime = GameRuntime(game: Game())
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    try JSONEncoder().encode(commander).write(to: url)
    try await runtime.load(from: url, persistMigrations: false)
    let loaded = await runtime.snapshot()
    #expect(loaded.commander == commander && loaded.energy == commander.performance.energy)
    #expect(loaded.commander.fittedEquipment(at: .energy) == original)
    try await runtime.save(to: url)
    try await runtime.load(from: url, persistMigrations: false)
    #expect(await runtime.snapshot().commander == commander)
    #expect(try JSONDecoder().decode(Commander.self, from: Data(contentsOf: url)) == commander)
  }

  @Test func tinyFuelCostsCannotOverflowSearchRadiusOrItsChartInteger() throws {
    for cost in [0, 1e-308, 1e-18] {
      let commander = try commanderWithRatio(slot: .navigation, axis: .jumpFuelCost, value: cost)
      #expect(!commander.valid)
      #expect(throws: CommanderEquipmentError.self) { try commander.validateEquipmentState() }
    }
    let supported = try commanderWithRatio(slot: .navigation, axis: .jumpFuelCost, value: 1e-12)
    #expect(supported.valid)
    var game = Game(executive: false)
    let loaded = game.load(supported)
    #expect(loaded)
    game.mapZoom = .search
    #expect(game.chartScaleFuel > 0 && game.jumpReach.search?.isFinite == true)
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
