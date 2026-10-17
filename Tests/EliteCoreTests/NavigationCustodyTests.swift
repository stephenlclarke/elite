import Foundation
import Testing

@testable import EliteCore

private func markedFirearmRoute() throws -> Game {
  var game = Game(executive: false)
  game.commander.galaxy = 1
  game.commander.system = 233
  game.systems = Universe.systemsIncludingPlugh(number: 1)
  game.commander.blackjack.stage = .deliverFirearm
  game.commander.blackjack.transfers = [
    .contact, .goldAward, .goldDelivery, .report, .firearmPickup,
  ]
  game.commander.cargo[10] = 1
  try game.commander.grantEquipment(
    NavigationTier.military.equipmentName, at: .navigation, provenance: .grant("route-custody-test")
  )
  #expect(game.commander.valid)
  return game
}

struct NavigationCustodyTests {
  @Test func markedOnlyFirearmsProduceNoSaleValueOrCargoDetour() throws {
    let game = try markedFirearmRoute()
    let graph = NavigationGraph(game: game)
    #expect(game.commander.sellableCargo(10) == 0)
    #expect(game.knownSystems.allSatisfy { graph.cargoSale($0.id) == 0 })
    let routes = graph.alternatives(destination: 127, tier: .military)
    #expect(!routes.isEmpty)
    #expect(routes.allSatisfy { $0.cargoSale == 0 && !$0.labels.contains("Best Cargo Sale") })
  }

  @Test func mixedPersonalAndMarkedCargoValuesOnlyTheItemsThatCanActuallyBeSold() throws {
    var game = try markedFirearmRoute()
    game.commander.cargo[10] = 4
    game.commander.cargo[13] = 2
    let destination = game.systems[127]
    let prices = MarketItem.minimumPrices(at: destination)
    #expect(
      NavigationGraph(game: game).cargoSale(destination.id)
        == Double(3 * prices[10] + 2 * prices[13]))
    game.selection = 10
    for _ in 0..<3 { game.trade(buy: false) }
    game.trade(buy: false)
    #expect(game.commander.cargo[10] == 1 && game.commander.sellableCargo(10) == 0)
    game.selection = 13
    for _ in 0..<2 { game.trade(buy: false) }
    #expect(NavigationGraph(game: game).cargoSale(destination.id) == 0)
    #expect(game.commander.blackjack.stage == .deliverFirearm && game.commander.valid)
  }

  @Test func acceptedMaximumSaleQuantityIsFiniteWithoutIntegerMultiplication() {
    var game = Game(executive: false)
    game.commander.unlimitedCargo = true
    game.commander.cargo[0] = Int.max / 17
    #expect(game.commander.valid)
    let value = NavigationGraph(game: game).cargoSale(55)
    #expect(value.isFinite && value > Double(Int.max))
  }
}

/// Isolate one real commodity margin so the score exposes loadable units directly.
private func navigationTradeMargin(_ game: inout Game, commodity: Int) throws -> Int {
  let destination = 55
  let prices = MarketItem.minimumPrices(at: game.systems[destination])
  try #require(prices[commodity] > 0)
  game.market = prices.map { .init(price: $0, quantity: 0) }
  game.market[commodity] = .init(price: prices[commodity] - 1, quantity: 63)
  return destination
}

extension NavigationCustodyTests {
  @Test(arguments: [false, true])
  func purchasedCabinReservesRealHoldEvenWithUnlimitedCargo(unlimited: Bool) throws {
    var game = Game(executive: false)
    let hold = game.commander.standardCargoCapacity
    let freeHold = hold - 5
    game.commander.credits = 100000
    game.commander.unlimitedCargo = unlimited
    try game.confirmPassengerBerth(game.passengerBerthQuote)
    try #require(game.commander.accommodation.fittedBerths.count == 1)
    try #require(game.commander.cargoTonnes == 5 && game.commander.tradeCargoCapacity == hold)
    let destination = try navigationTradeMargin(&game, commodity: 0)
    let before = game.commander
    let market = game.market
    #expect(
      NavigationGraph(game: game).trade(game.commander.system, destination) == Double(freeHold))
    #expect(game.commander == before && game.market == market)
    game.selection = 0
    for _ in 0..<freeHold { game.trade(buy: true) }
    let full = game.commander
    game.trade(buy: true)
    #expect(game.commander == full && game.commander.cargo[0] == freeHold)
  }

  @Test func purchasedCabinsFillActualHoldAndLeaveNoTonneTradeOrPurchaseRoom() throws {
    var game = Game(executive: false)
    game.commander.credits = 100000
    let hold = game.commander.standardCargoCapacity
    let cabinTonnes = AccommodationFitting.tonnesPerCommonBerth
    try #require(hold > 0 && hold % cabinTonnes == 0)
    let cabinCount = hold / cabinTonnes
    for _ in 0..<cabinCount { try game.confirmPassengerBerth(game.passengerBerthQuote) }
    try #require(game.commander.accommodation.fittedBerths.count == cabinCount)
    try #require(game.commander.cargoTonnes == hold && game.commander.tradeCargoCapacity == hold)
    let destination = try navigationTradeMargin(&game, commodity: 0)
    let before = game.commander
    let market = game.market
    #expect(NavigationGraph(game: game).trade(game.commander.system, destination) == 0)
    #expect(game.commander == before && game.market == market)
    game.selection = 0
    game.trade(buy: true)
    #expect(game.commander == before && game.market == market)
  }

  @Test func markedFirearmReservesOneTonneAfterOrdinaryCargoIsSold() throws {
    var game = try markedFirearmRoute()
    let hold = game.commander.tradeCargoCapacity
    game.commander.cargo[0] = hold - 1
    let destination = try navigationTradeMargin(&game, commodity: 0)
    try #require(game.commander.cargoTonnes == hold && game.commander.valid)
    let before = game.commander
    #expect(
      NavigationGraph(game: game).trade(game.commander.system, destination) == Double(hold - 1))
    #expect(game.commander == before && game.commander.sellableCargo(10) == 0)
  }

  @Test func acceptedProtectedPayloadKeepsItsTonneOutOfTradeEstimates() throws {
    let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/scripted-courier")
    let pack = try ScriptPackLibrary.read(directory)
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [pack]
    let instance = try game.acceptScriptMission(pack)
    try #require(game.commander.scriptState.instances[instance]?.payloads["supplies"] == 1)
    try #require(game.commander.cargoTonnes == 1 && game.commander.valid)
    let destination = try navigationTradeMargin(&game, commodity: 0)
    let before = game.commander
    #expect(
      NavigationGraph(game: game).trade(game.commander.system, destination)
        == Double(game.commander.tradeCargoCapacity - 1))
    #expect(game.commander == before)
  }

  @Test func fullOrdinaryHoldCanBeSoldBeforeTheNextTonneTrade() throws {
    var game = Game(executive: false)
    let hold = game.commander.tradeCargoCapacity
    game.commander.cargo[0] = hold
    let destination = try navigationTradeMargin(&game, commodity: 0)
    try #require(game.commander.cargoTonnes == game.commander.tradeCargoCapacity)
    let before = game.commander
    #expect(NavigationGraph(game: game).trade(game.commander.system, destination) == Double(hold))
    #expect(game.commander == before)
  }

  @Test func nonTonneTradeStillLoadsWithAnOccupiedHold() throws {
    var game = Game(executive: false)
    game.commander.credits = 100000
    let hold = game.commander.tradeCargoCapacity
    game.commander.cargo[0] = hold
    let destination = try navigationTradeMargin(&game, commodity: 13)
    let before = game.commander
    #expect(NavigationGraph(game: game).trade(game.commander.system, destination) == 63)
    #expect(game.commander == before)
    game.selection = 13
    game.trade(buy: true)
    #expect(game.commander.cargo[13] == 1 && game.commander.cargoTonnes == hold)
  }

  @Test func maximumValidOrdinaryTonnageKeepsTradeScoringFinite() throws {
    var game = Game(executive: false)
    game.commander.unlimitedCargo = true
    game.commander.cargo[0] = Int.max / 17
    try #require(game.commander.valid)
    let destination = try navigationTradeMargin(&game, commodity: 0)
    let before = game.commander
    let estimate = NavigationGraph(game: game).trade(game.commander.system, destination)
    #expect(estimate.isFinite && estimate == 63)
    #expect(game.commander == before)
  }

  @Test func collectedTechnologyKeepsItsReservedTonneOutOfTradeEstimates() throws {
    var game = Game(executive: false)
    var ledger = game.commander.salvageLedger
    let wreck = WreckIdentity(system: .init(galaxy: 0, system: 7), site: 1, lineage: 2)
    let section = SalvageSectionProfile(
      index: 0, kind: .computer, localPosition: .init(10, 0, 0), normal: .init(0, 0, 2),
      radius: 10, workSeconds: 1, structural: false,
      technologyDefinitionIDs: ["computer-core"], sourceFaceIndex: 0)
    let conditions = SalvageWorkConditions(
      toolInstalled: true, inRange: true, aligned: true,
      lineOfSight: true, resourcesAvailable: true, ownershipAuthorized: true)
    _ = ledger.advance(
      wreck: wreck, section: section, pose: .init(position: .init(100, 200, 300)),
      velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: 1,
      operation: 1, conditions: conditions)
    let lot = try #require(ledger.pendingLots.first)
    var cargo = game.commander.cargo
    let receipt = ledger.collect(
      lot: lot.identity, cargo: &cargo,
      freeTonnes: game.commander.tradeCargoCapacity - game.commander.cargoTonnes,
      apertureHalfExtents: .init(100, 100, 100), hasScoops: true, approachAllowed: true,
      protection: .init())
    try #require(receipt == .collected(lot) && ledger.reservedTonnes == 1)
    game.commander.salvageLedger = ledger
    game.commander.cargo = cargo
    try #require(game.commander.cargoTonnes == 1 && game.commander.valid)
    let destination = try navigationTradeMargin(&game, commodity: 0)
    let before = game.commander
    #expect(
      NavigationGraph(game: game).trade(game.commander.system, destination)
        == Double(game.commander.tradeCargoCapacity - 1))
    #expect(game.commander == before)
  }
}
