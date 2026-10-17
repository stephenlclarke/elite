import Foundation
import Testing

@testable import EliteCore

@Test func fuelStorageUnitsAreCountedPricedAndNeverSupplyFreeFuel() throws {
  var game = Game(executive: false)
  game.commander.credits = 100_000
  game.commander.fuel = 35
  game.selection = try #require(Equipment.all.firstIndex { $0.name == FuelStorage.equipmentName })
  for count in 1...4 {
    game.purchase()
    #expect(
      game.commander.fuelStorageUnits == count && game.commander.fuelCapacity == (count + 1) * 70)
    #expect(game.commander.fuel == 35 && game.commander.credits == 100_000 - count * 20_000)
    #expect(!game.commander.equipment.contains(FuelStorage.equipmentName) && game.commander.valid)
  }
  game.purchase()
  #expect(game.commander.fuelStorageUnits == 4 && game.message == "FUEL STORAGE FULL")
  game.selection = 0
  game.purchase()
  #expect(game.commander.fuel == 350 && game.commander.credits == 20_000 - 315 * 2)
  // Capacity belongs to fitted physical tanks; a legacy counter assignment cannot remove one.
  let full = game.commander
  let tank = try #require(game.commander.fittedEquipment(at: .fuelStorage(3)))
  let revision = try #require(game.commander.equipmentInventory?.revision)
  #expect(throws: EquipmentRuntimeError.incompatibleFit) {
    try game.storeEquipment(tank, expectedRevision: revision)
  }
  #expect(game.commander == full && game.commander.fuelStorageUnits == 4)

  var poor = Game(executive: false)
  poor.commander.fuel = 35
  poor.commander.credits = 19_999
  poor.selection = try #require(Equipment.all.firstIndex { $0.name == FuelStorage.equipmentName })
  let before = poor.commander
  poor.purchase()
  #expect(poor.commander.fuelStorageUnits == 0 && poor.message == "NOT ENOUGH CASH")
  #expect(poor.commander == before)
}

@Test func invalidLegacyFuelAndStorageCountsStillRefuseDecodingIntoAnActualRuntime() async throws {
  let runtime = GameRuntime(game: Game(executive: false))
  let ready = await runtime.snapshot()
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  for (units, fuel) in [(0, 350), (5, 70)] {
    var legacy = Commander()
    legacy.fuelStorageUnits = units
    legacy.fuel = fuel
    #expect(legacy.equipmentInventory == nil && !legacy.valid)
    let data = try JSONEncoder().encode(legacy)
    let decoded = try JSONDecoder().decode(Commander.self, from: data)
    #expect(decoded.equipmentInventory == nil && !decoded.valid)
    try data.write(to: url)
    await #expect(throws: SaveError.self) {
      try await runtime.load(from: url, persistMigrations: false)
    }
    let after = await runtime.snapshot()
    #expect(
      after.commander == ready.commander
        && after.inventoryContextEpoch == ready.inventoryContextEpoch)
  }
}

@Test func fuelStorageSaveCompatibilityAndFullAutoTradeRefuellingUseInstalledCapacity() async throws
{
  let original = try JSONEncoder().encode(Commander())
  var object = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
  object.removeValue(forKey: "storageUnitCount")
  let legacy = try JSONDecoder().decode(
    Commander.self, from: JSONSerialization.data(withJSONObject: object))
  #expect(legacy.fuelStorageUnits == 0 && legacy.fuelCapacity == 70 && legacy.valid)
  var game = Game(executive: false)
  game.commander.fuelStorageUnits = 4
  game.commander.fuel = 100
  game.commander.credits = 500
  game.selectedSystem = game.commander.system
  for i in game.market.indices { game.market[i].quantity = 0 }
  game.autoTrade()
  #expect(game.commander.fuel == 350 && game.commander.credits == 0)
  let runtime = GameRuntime(game: game)
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  try await runtime.save(to: url)
  try await runtime.load(from: url)
  #expect(await runtime.snapshot().commander.fuelCapacity == 350)
}

@Test func eachComputerStorageAndFuelCombinationControlsRingsSearchAndActualJump() throws {
  for tier in NavigationTier.allCases {
    for units in 0...4 {
      for fuel in [0, 30, 70, (units + 1) * 70] {
        var game = Game(executive: false)
        game.commander.installNavigationComputer(tier)
        game.commander.fuelStorageUnits = units
        game.commander.fuel = fuel
        let capacity = Double((units + 1) * 7)
        #expect(game.jumpReach.maximum == min(capacity, tier.jumpCap))
        #expect(game.jumpReach.actual == min(Double(fuel) / 10, tier.jumpCap))
        #expect(
          game.navigationPlanningRadius
            == (tier == .military ? nil : capacity + Double(tier.rawValue * 7)))
        for system in game.knownSystems {
          game.selectedSystem = system.id
          #expect(
            game.targetReachable
              == (game.currentSystem.distance(to: system) <= game.jumpReach.actual))
        }
        game.screen = .shortChart
        for zoom in MapZoom.allCases {
          game.mapZoom = zoom
          let frame = Display.map(game, width: 512, height: 518)
          let styles = (frame.worldGraphics + frame.graphics).compactMap {
            graphic -> StrokePattern? in
            if case .ring(_, _, _, _, let style) = graphic { return style }
            return nil
          }
          #expect(styles.contains(.dotted) && styles.contains(.dashed))
          #expect(styles.contains(.solid) == (game.jumpReach.actual != game.jumpReach.maximum))
          for label in frame.labels {
            #expect(label.bounds.x >= 0 && label.bounds.maxX <= 512 && label.bounds.maxY <= 518)
          }
        }
      }
    }
  }
  var game = Game(executive: false)
  game.screen = .shortChart
  #expect(game.jumpReach.maximum == 7 && game.jumpReach.search == nil)
  for zoom in MapZoom.allCases {
    #expect(game.mapZoom == zoom)
    game.key("z")
  }
  #expect(game.mapZoom == .jump)
}

@Test func routeFirstHopUsesCurrentFuelLaterHopsUseCapacityAndNavigationCap() throws {
  var game = Game(executive: false)
  game.commander.installNavigationComputer(.military)
  game.commander.fuelStorageUnits = 4
  game.commander.fuel = 70
  let graph = NavigationGraph(game: game)
  let dest = try #require(
    game.systems.first {
      game.currentSystem.distance(to: $0) > 21
        && graph.path(from: game.commander.system, to: $0.id, fuel: 70, scoring: 0) != nil
    })
  let path = try #require(
    graph.path(from: game.commander.system, to: dest.id, fuel: 70, scoring: 0))
  #expect(game.systems[path[0]].distance(to: game.systems[path[1]]) <= 7)
  #expect(
    zip(path, path.dropFirst()).allSatisfy { game.systems[$0].distance(to: game.systems[$1]) <= 21 }
  )
  #expect(
    graph.edges[game.commander.system].contains {
      game.currentSystem.distance(to: game.systems[$0]) > 14
    })
  #expect(
    !graph.edges[game.commander.system].contains {
      game.currentSystem.distance(to: game.systems[$0]) > 21
    })
}
