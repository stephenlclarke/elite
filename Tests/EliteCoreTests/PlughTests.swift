import Foundation
import Testing

@testable import EliteCore

private func plughGame(galaxy: Int = 0) -> Game {
  var game = Game(executive: false)
  game.commander.galaxy = galaxy
  game.systems = Universe.systemsIncludingPlugh(number: galaxy)
  game.commander.system = 7
  game.selectedSystem = 7
  game.screen = .status
  game.key("u")
  game.key("return")
  game.docked = false
  game.selectedSystem = Plugh.systemID
  game.arrive()
  game.dock()
  return game
}

// Buy real predecessors so the desired PLUGH transaction tests its own single discount.
private func buyPlughPrerequisites(_ node: EquipmentNodeID, game: inout Game) throws {
  let definition = try #require(EquipmentRuntimeCatalog.graph.nodes.first { $0.id == node })
  for parent in definition.prerequisites {
    let predecessor = try #require(EquipmentRuntimeCatalog.graph.nodes.first { $0.id == parent })
    if predecessor.policy == .standardFoundation { continue }
    try buyPlughPrerequisites(parent, game: &game)
    try buyPlughPredecessor(parent, game: &game)
  }
}

// Keep purchase and assertion read buffers outside the recursive graph traversal frames.
private func buyPlughPredecessor(_ parent: EquipmentNodeID, game: inout Game) throws {
  if game.commander.equipmentPurchaseHistory?.paid.contains(where: { $0.node == parent }) == true {
    return
  }
  game.selection = try #require(Equipment.all.firstIndex { $0.name == parent.key })
  let cash = game.commander.credits
  let price = game.shopPrice(Equipment.all[game.selection])
  game.purchase()
  #expect(game.commander.credits == cash - price)
  let receipt = try #require(game.commander.equipmentPurchaseHistory?.paid.last)
  #expect(receipt.node == parent && receipt.price == price)
}

@Test func plughAddsOneDistinctStableSystemPerGalaxyWithoutChangingOriginals() {
  var identities = Set<String>()
  for galaxy in 0..<8 {
    let original = Universe.galaxy(number: galaxy)
    let all = Universe.systemsIncludingPlugh(number: galaxy)
    let secret = Plugh.system(galaxy: galaxy)
    #expect(original.count == 256 && all.count == 257 && Array(all.prefix(256)) == original)
    #expect(all[256] == secret && secret.name == "PLUGH")
    #expect(!original.contains { $0.x == secret.x && $0.y == secret.y })
    #expect(original[7].distance(to: secret) <= 3)
    #expect(secret.economyName == "Rich Industrial" && secret.governmentName == "Corporate State")
    identities.insert("\(galaxy):\(secret.id)")
  }
  #expect(identities.count == 8)
}

@Test func plughDiscoveryIsHiddenFromSearchRoutesAndOtherGalaxiesUntilRumour() {
  var game = Game(executive: false)
  game.commander.installNavigationComputer(.military)
  game.screen = .chart
  for galaxy in 0..<8 {
    game.viewGalaxy(galaxy)
    game.mapSearch.query = "plugh"
    #expect(game.searchResults.isEmpty && game.mapSystems.count == 256)
  }
  #expect(!game.canPlan(to: game.systems[256]))
  #expect(NavigationGraph(game: game).edges.allSatisfy { !$0.contains(256) })
  game.screen = .status
  game.commander.system = 129
  game.key("u")
  #expect(game.screen == .rumour && !game.commander.hasDiscoveredPlugh(in: 0))
  #expect(game.stationRumour.contains("LAVE"))
  game.key("k")
  game.key("k")
  game.key("escape")
  game.commander.system = 7
  game.key("u")
  #expect(game.commander.hasDiscoveredPlugh(in: 0) && game.stationRumour.contains("PLUGH"))
  game.key("return")
  game.key("4")
  game.viewGalaxy(0)
  game.mapSearch.query = "plugh"
  #expect(game.searchResults.map(\.id) == [256])
  game.viewGalaxy(1)
  game.mapSearch.query = "plugh"
  #expect(game.searchResults.isEmpty)
  game.docked = false
  game.screen = .front
  let discovery = game.commander.plughDiscoveryMask
  game.key("u")
  #expect(game.commander.plughDiscoveryMask == discovery && game.screen == .front)
}

@Test func plughCanBeReachedByOrdinaryFuelLimitedHyperspaceAndDocked() {
  for galaxy in 0..<8 {
    var game = Game(executive: false)
    game.commander.galaxy = galaxy
    game.systems = Universe.systemsIncludingPlugh(number: galaxy)
    game.screen = .status
    game.key("u")
    game.key("return")
    game.launch()
    game.bodies = []
    game.selectedSystem = 256
    let fuel = game.commander.fuel
    let cost = Int(game.currentSystem.distance(to: game.targetSystem) * 10)
    game.beginHyperspace()
    #expect(game.jumpCountdown != nil)
    for _ in 0..<160 { game.tick(delta: 0.1) }
    #expect(game.commander.system == 256 && game.commander.fuel == fuel - cost)
    game.dock()
    #expect(
      game.docked && game.atPlugh && game.commander.valid
        && game.market.allSatisfy { $0.quantity == 63 })
  }
}

@Test func plughDiscoverySaveValidationAndGalacticDeparturePreserveIdentityAndEquipment()
  async throws
{
  var game = plughGame(galaxy: 2)
  try NativeSaveTestFixture.prepareCurrentPolicy(&game)
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  let runtime = GameRuntime(game: game)
  let bootstrapped = await runtime.snapshot()
  try await runtime.save(to: url)
  let bytes = try Data(contentsOf: url)
  try await runtime.load(from: url)
  let saved = await runtime.snapshot()
  var expected = bootstrapped.commander
  expected.npcPersistence.resetPhysicalBindings(system: bootstrapped.systemIdentity)
  expected.resetWantedCareerBindings(system: bootstrapped.systemIdentity)
  #expect(saved.commander == expected && saved.currentSystem.name == "PLUGH")
  #expect(try Data(contentsOf: url) == bytes)
  var invalid = saved.commander
  invalid.plughDiscoveryMask = 0
  #expect(!invalid.valid)
  invalid = Commander()
  #expect(invalid.valid && invalid.plughDiscoveryMask == 0)
  invalid.plughDiscoveryMask = 256
  #expect(!invalid.valid)
  var departure = saved
  try departure.commander.grantEquipment(
    "Galactic Hyperdrive", at: .utility(.galacticHyperdrive), provenance: .grant("plugh-test"))
  let drive = try #require(departure.commander.fittedEquipment(at: .utility(.galacticHyperdrive)))
  let owner = departure.commander.equipmentOwnerID
  let hull = departure.commander.hullInstanceID
  departure.launch()
  departure.galacticJump()
  #expect(departure.commander.galaxy == 3 && departure.commander.system == 7)
  #expect(
    !departure.commander.hasDiscoveredPlugh(in: 3) && departure.commander.hasDiscoveredPlugh(in: 2))
  #expect(!departure.commander.equipment.contains("Galactic Hyperdrive"))
  #expect(departure.commander.equipmentInventory?.items.contains { $0.id == drive.id } == false)
  #expect(
    departure.commander.equipmentOwnerID == owner && departure.commander.hullInstanceID == hull)
  #expect(departure.commander.valid)
}

@Test func plughShopSellsEverySupportedItemAtOneDiscountAndKeepsRewardsRestrictedElsewhere() throws
{
  for (index, item) in Equipment.all.enumerated() {
    var game = plughGame()
    game.commander.credits = 10_000_000
    game.commander.fuel = 0
    try game.commander.prepareEquipment(legacy: false)
    game.equipmentMount = .left
    if let node = EquipmentRuntimeCatalog.node(for: item.name) {
      try buyPlughPrerequisites(node, game: &game)
    }
    game.selection = index
    let cost = game.shopPrice(item)
    let undiscounted =
      item.name == "Fuel"
      ? (game.commander.fuelCapacity - game.commander.fuel) * item.price
      : Plugh.rewardPrices[item.name] ?? item.price
    #expect(cost == Plugh.discount(undiscounted) && cost > 0 && game.equipmentAvailable(item))
    let cash = game.commander.credits
    let fuel = game.commander.fuel
    let history = game.commander.equipmentPurchaseHistory?.paid.count ?? 0
    game.purchase()
    if item.name == NavigationTier.basic.equipmentName {
      #expect(game.commander.credits == cash && game.commander.navigationTier == .basic)
      #expect(game.message == "STANDARD OR ACQUISITION HARDWARE - NOT FOR SALE")
      #expect(game.commander.equipmentPurchaseHistory?.paid.count == history)
    } else {
      #expect(game.commander.credits == cash - cost, "\(item.name): \(game.message)")
      if let node = EquipmentRuntimeCatalog.node(for: item.name) {
        let receipt = try #require(game.commander.equipmentPurchaseHistory?.paid.last)
        #expect(receipt.node == node && receipt.price == cost)
        #expect(game.commander.equipmentPurchaseHistory?.paid.count == history + 1)
      }
    }
    if item.name != "Fuel" { #expect(game.commander.fuel == fuel) }
    if let laser = LaserKind.from(item.name) { #expect(game.commander.laser(on: .left) == laser) }
    #expect(game.commander.valid)
    if Equipment.isReward(item.name) {
      var normal = Game(executive: false)
      normal.commander.credits = 10_000_000
      normal.selection = index
      normal.purchase()
      #expect(normal.commander.credits == 10_000_000 && normal.message.hasSuffix("NOT FOR SALE"))
    }
  }
  var game = plughGame()
  game.commander.credits = 1_000_000
  let naval = try #require(EquipmentRuntimeCatalog.node(for: Equipment.navalEnergyUnit))
  try buyPlughPrerequisites(naval, game: &game)
  game.selection = try #require(Equipment.all.firstIndex { $0.name == Equipment.navalEnergyUnit })
  let cash = game.commander.credits
  let cost = game.shopPrice(Equipment.all[game.selection])
  game.purchase()
  #expect(game.commander.credits == cash - cost)
  #expect(
    game.commander.equipment.contains(Equipment.navalEnergyUnit)
      && !game.commander.equipment.contains("Extra Energy Unit"))
}

@Test func plughShopRespectsCashStorageMissileMountAndTierLimitsWithoutRefillsOrCashReset() throws {
  var game = plughGame()
  game.commander.credits = 10_000_000
  game.commander.xyzzyActive = true
  game.commander.xyzzyCashGranted = true
  game.selection = try #require(Equipment.all.firstIndex { $0.name == FuelStorage.equipmentName })
  for _ in 0..<4 { game.purchase() }
  let cash = game.commander.credits
  let fuel = game.commander.fuel
  game.purchase()
  #expect(
    game.commander.fuelStorageUnits == 4 && game.commander.credits == cash
      && game.commander.fuel == fuel)
  game.selection = try #require(Equipment.all.firstIndex { $0.name == Equipment.navalLaser })
  game.commander.credits = game.shopPrice(Equipment.all[game.selection]) - 1
  let poor = game.commander
  game.purchase()
  #expect(game.commander == poor)
  game.commander.credits = 1_000_000
  game.purchase()
  let fitted = game.commander
  game.purchase()
  #expect(game.commander == fitted)
  game.selection = try #require(Equipment.all.firstIndex { $0.name == "Missile" })
  try game.commander.grantEquipment(
    "Missile", at: .missilePylon(3), provenance: .grant("plugh full rack fixture"))
  #expect(
    game.commander.fittedEquipment(at: .missilePylon(3))?.node
      == EquipmentRuntimeCatalog.standardMissile)
  #expect(game.commander.missiles == 4)
  game.commander.missiles = 4
  let full = game.commander
  game.purchase()
  #expect(game.commander == full)
  try game.commander.grantEquipment(
    NavigationTier.military.equipmentName, at: .navigation,
    provenance: .grant("plugh tier refusal fixture"))
  #expect(game.commander.navigationTier == .military)
  #expect(
    game.commander.fittedEquipment(at: .navigation)?.node.key
      == NavigationTier.military.equipmentName)
  game.selection = try #require(
    Equipment.all.firstIndex { $0.name == NavigationTier.basic.equipmentName })
  let maxed = game.commander
  game.purchase()
  #expect(game.commander == maxed)
}

@Test func plughFuelAndAllCommodityPricesMatchDisplaysAndCannotCreateInstantTradeProfit() throws {
  var game = plughGame()
  game.commander.credits = 1_000_000
  let ordinary = MarketItem.at(Universe.galaxy(number: game.commander.galaxy)[Plugh.rumourStation])
  #expect(
    game.market.indices.allSatisfy {
      game.market[$0].price == Plugh.discount(ordinary[$0].price)
        && game.market[$0].bidPrice == Plugh.discount(ordinary[$0].bidPrice)
    })
  for index in Commodity.all.indices {
    game.selection = index
    let cash = game.commander.credits
    game.trade(buy: true)
    #expect(game.commander.credits == cash - game.market[index].price)
    game.trade(buy: false)
    #expect(
      game.commander.credits == cash - game.market[index].price + game.market[index].bidPrice
        && game.market[index].quantity == 63)
  }
  game.commander.fuel = 0
  game.selection = 0
  let refill = game.refillCost
  let cash = game.commander.credits
  let frame = Display.equipmentScreen(game, width: 768, height: 768)
  #expect(
    frame.labels.contains { $0.text == String(format: "Refill %.1f CR", Double(refill) / 10) })
  game.purchase()
  #expect(
    game.commander.credits == cash - refill && game.commander.fuel == game.commander.fuelCapacity)
  #expect(refill == Plugh.discount(70 * Equipment.base[0].price))
}
