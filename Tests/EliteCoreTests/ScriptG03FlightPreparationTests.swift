import Foundation
import Testing

@testable import EliteCore

private func requireUnpublishedG03Preparation(_ game: borrowing Game, before: borrowing Game) {
  let sameCommander = game.commander == before.commander
  let sameBodies = game.bodies == before.bodies
  let sameMarket = game.market == before.market
  let sameSelection = game.selectedSystem == before.selectedSystem
  let sameEnergy = game.energy == before.energy
  let sameFront = game.frontShield == before.frontShield
  let sameRear = game.rearShield == before.rearShield
  let sameSpeed = game.speed == before.speed
  let sameRevision = game.gameplayRevision == before.gameplayRevision
  let sameAllocator = game.nextBodyID == before.nextBodyID
  #expect(sameCommander && sameBodies && sameMarket && sameSelection)
  #expect(sameEnergy && sameFront && sameRear && sameSpeed)
  #expect(sameRevision && sameAllocator)
}

struct ScriptG03FlightPreparationTests {
  @Test(arguments: ["generated-procurement", "generated-supplied-freight"])
  func declaredTrialBuysItsWholeFitAtTheActualOriginalShop(directory: String) throws {
    let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/" + directory)
    let pack = try ScriptPackLibrary.read(source)
    let scene = try #require(pack.manifest.trial)
    let world = try Universe.originalWorlds.world(key: "G01-S007")
    try #require(scene.galaxy == world.galaxy && scene.system == world.system)
    var parent = Game(executive: false)
    parent.scriptPacks = [pack]
    parent.scriptDurabilityAvailable = true
    var game = try parent.constructScriptTrial(packDigest: pack.digest, seed: 42)
    try #require(game.currentSystem.original == world && game.currentSystem.technology == 12)
    let energy = try #require(Equipment.all.first { $0.name == "Extra Energy Unit" })
    try #require(energy.requiredTechnologyLevel == 9 && game.equipmentAvailable(energy))
    // Controlled pre-purchase resource boundary: fitting must preserve spent resources and cargo.
    game.energy = game.commander.performance.energy * 0.5
    game.frontShield = game.commander.shieldCapacity * 0.5
    game.rearShield = game.commander.rearShieldCapacity * 0.25
    game.commander.cargo[CommodityIdentity.food.rawValue] = 1
    game.commander.fuel -= 1
    let before = game
    try game.prepareG03FlightEquipment()
    try ScriptProcurementFixture.requirePaidG03Preparation(game)
    #expect(game.commander.credits == before.commander.credits - 93875)
    #expect(game.commander.equipmentOwnerID == before.commander.equipmentOwnerID)
    #expect(game.commander.hullInstanceID == before.commander.hullInstanceID)
    #expect(
      game.commander.cargo == before.commander.cargo && game.commander.fuel == before.commander.fuel
    )
    #expect(game.commander.missiles == before.commander.missiles)
    #expect(game.energy == before.energy)
    #expect(game.frontShield == game.commander.shieldCapacity * 0.5)
    #expect(game.rearShield == game.commander.rearShieldCapacity * 0.25)
    #expect(game.commander.galaxy == scene.galaxy && game.commander.system == scene.system)
    #expect(game.commander.flightSimulation == before.commander.flightSimulation)
    #expect(game.commander.scriptState == before.commander.scriptState)
    #expect(game.market == before.market && game.bodies == before.bodies)
    #expect(game.docked && game.commander.scriptState.instances.isEmpty)
    #expect(game.commander.contracts == before.commander.contracts)
  }

  @Test func lowerTechnologyShopRefusesWithoutPublishingTheFourEarlierPurchases() throws {
    // Controlled fresh initialization at the original failing shop; no journey is claimed.
    var game = Game(executive: false)
    game.screen = .status
    game.commander.system = 0
    game.selectedSystem = 0
    game.market = MarketItem.at(game.currentSystem)
    game.commander.credits = 100000
    try game.commander.prepareEquipment(legacy: false)
    let world = try Universe.originalWorlds.world(key: "G01-S000")
    try #require(game.currentSystem.original == world && world.technology == 7)
    let energy = try #require(Equipment.all.first { $0.name == "Extra Energy Unit" })
    try #require(!game.equipmentAvailable(energy))
    for name in [
      "Targeting: Basic", "Targeting: Advanced", "Targeting: Docking", "Pulse Shield Booster",
    ] {
      let earlier = try #require(Equipment.all.first { $0.name == name })
      try #require(game.equipmentAvailable(earlier))
    }
    let before = game
    #expect(throws: EquipmentRuntimeError.unavailable) { try game.prepareG03FlightEquipment() }
    requireUnpublishedG03Preparation(game, before: before)
    #expect(game.commander.targetingTier == nil)
    #expect(game.commander.equipmentPurchaseHistory?.paid.isEmpty == true)
  }

  @Test func insufficientBudgetRefusesWithoutPublishingAnyPaidPredecessor() throws {
    var game = try ScriptProcurementFixture.freshG03FlightGame()
    game.commander.credits = 93874
    try game.commander.prepareEquipment(legacy: false)
    let before = game
    #expect(throws: EquipmentPurchaseError.insufficientFunds) {
      try game.prepareG03FlightEquipment()
    }
    requireUnpublishedG03Preparation(game, before: before)
    #expect(game.commander.targetingTier == nil)
    #expect(game.commander.equipmentPurchaseHistory?.paid.isEmpty == true)
  }

  @Test func alteredOrdinaryShopCannotClaimTheInstalledTechnology() throws {
    var game = try ScriptProcurementFixture.freshG03FlightGame()
    var fields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(game.currentSystem)) as? [String: Any]
    )
    fields["technology"] = 15
    game.systems[game.commander.system] = try JSONDecoder().decode(
      StarSystem.self,
      from: JSONSerialization.data(withJSONObject: fields))
    let before = game
    #expect(throws: MissionPackError.self) { try game.prepareG03FlightEquipment() }
    requireUnpublishedG03Preparation(game, before: before)
  }
}
