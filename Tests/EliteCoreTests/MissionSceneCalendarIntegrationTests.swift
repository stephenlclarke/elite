import Foundation
import Testing

@testable import EliteCore

struct MissionSceneCalendarIntegrationTests {
  @Test func anOrdinaryNativeLaunchDoesNotCreateMissionCalendarState() {
    var game = Game(executive: false)
    game.screen = .status
    game.launch()
    #expect(!game.docked && game.commander.valid)
    #expect(game.commander.scriptState == ScriptEngineState() && !game.requiresScriptDurability)
  }

  @Test func aCalendarLaunchRefusalPreservesPhysicalAndCommanderState() {
    var game = Game(executive: false)
    game.screen = .status
    game.commander.scriptState.calendarLedger = .init(origin: .newCommander)
    game.commander.scriptState.calendarSeconds = 1e12 - 100
    let before = game
    #expect(game.commander.valid)
    game.launch()
    #expect(game.docked && game.commander == before.commander && game.bodies == before.bodies)
    #expect(
      game.inventoryContextEpoch == before.inventoryContextEpoch && game.speed == before.speed)
  }

  @Test func theAdmittedMissionJourneyUsesActualGradedFuelAndItsFrozenDestination() throws {
    var game = Game(executive: false)
    game.screen = .status
    try game.commander.prepareEquipment(legacy: false)
    let inventory = try #require(game.commander.equipmentInventory)
    let nav = try #require(game.commander.fittedEquipment(at: .navigation))
    let component = try #require(nav.component)
    var statistics = component.statistics
    statistics[.jumpFuelCost] = 0.5
    let enhanced = OwnedEquipmentItem(
      id: nav.id, node: nav.node, provenance: nav.provenance,
      component: .init(
        id: component.id, origin: component.origin, statistics: statistics,
        grade: component.grade, features: component.features, receipts: component.receipts),
      location: nav.location, boundHull: nav.boundHull)
    game.commander.savedEquipmentInventory = try inventory.applyingBatch(
      items: inventory.items.map { $0.id == nav.id ? enhanced : $0 },
      expectedRevision: inventory.revision,
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: inventory.activeHull,
        performance: game.commander.nativePerformance))
    game.commander.scriptState.calendarLedger = .init(origin: .newCommander)
    game.launch()
    #expect(game.commander.scriptState.calendarSeconds == 600)
    game.bodies = []
    game.celestials = []
    game.selectedSystem = try #require(
      game.systems.first {
        $0.id != game.commander.system && game.currentSystem.distance(to: $0) <= 7
          && game.currentSystem.distance(to: $0) >= 1
      }?.id)
    let destination = game.selectedSystem
    let distance = game.currentSystem.distance(to: game.targetSystem)
    let cost = game.commander.jumpFuelCost(distance: distance)
    let fuel = game.commander.fuel
    game.beginHyperspace()
    let journey = try #require(game.commander.scriptState.calendarLedger?.pendingJourney)
    #expect(journey.nativeFuelDebit == cost && journey.destination == destination)
    game.selectedSystem = game.commander.system
    game.arrive()
    #expect(game.commander.system == destination && game.commander.fuel == fuel - cost)
    #expect(game.commander.scriptState.calendarLedger?.pendingJourney == nil)
    #expect(game.commander.scriptState.calendarSeconds == 600 + journey.seconds)
    #expect(game.commander.valid)
  }

  @Test func aReservedPassengerCabinRefusesEscapeWithoutSpendingTheActualPod() throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    try game.commander.grantEquipment("Escape Pod", at: .utility(.escapePod), provenance: .standard)
    let instance = ScriptInstance(
      id: UUID(), definition: "fixture/passenger", version: "1.0.0",
      digest: String(repeating: "a", count: 64))
    game.commander.scriptState.instances[instance.id] = instance
    let berth = PassengerBerth(use: .reserved(mission: instance.id, person: nil))
    game.commander.accommodation.ownedBerths = [berth]
    game.commander.accommodation.fitted = [berth.id]
    game.launch()
    #expect(!game.docked && game.commander.valid)
    let before = game
    game.escapePod()
    #expect(game.commander == before.commander && game.bodies == before.bodies && !game.docked)
    #expect(game.commander.fittedEquipment(at: .utility(.escapePod)) != nil)
  }
}
