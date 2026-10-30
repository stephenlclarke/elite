import Foundation
import Testing

@testable import L337Core

enum StationBoardChange: CaseIterable, Sendable {
  case pause, launch, manualCancel, actorEpoch, owner, system, hour, overflow, legal, lifecycle,
    durability
}

enum MainDestinationChange: CaseIterable, Sendable {
  case replacementActor, owner, destroyed, rawDockFlags, actorEpoch
}

struct NativeStationServiceTests {
  @Test(arguments: NativeStationGeometry.Kind.allCases)
  func actualEntryProvidesOnlySourceBoundBoardFacts(kind: NativeStationGeometry.Kind) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try stationServiceApproach(kind)
    try await verifyStationBoardFacts(&game, kind: kind, storage: storage)
  }

  @Test(arguments: StationBoardChange.allCases)
  func capturedBoardContextCannotSurviveChangedAuthority(change: StationBoardChange) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try stationServiceApproach(.headquarters)
    try await verifyChangedStationBoard(&game, change: change, storage: storage)
  }

  @Test(arguments: NativeStationGeometry.Kind.allCases)
  func validatedLoadKeepsReceiptAndPropertyButReplacesBoardEpoch(kind: NativeStationGeometry.Kind)
    async throws
  {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try stationServiceApproach(kind)
    try await verifyStationBoardLoad(&game, storage: storage)
  }

  @Test func rawDockLedgerCannotProvideLiveBoardFactsOrAServiceContext() throws {
    var game = try NativeStationTestFixture.launched()
    try verifyRawStationBoardRefusal(&game)
  }

  @Test(arguments: NativeStationGeometry.Kind.allCases)
  func boardOnlyStationsRefusePaidShopsTradingAndRefuellingWithoutPropertyLoss(
    kind: NativeStationGeometry.Kind
  ) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try stationServiceApproach(kind)
    try await verifyStationShopRefusals(&game, storage: storage)
  }

  @Test(arguments: NativeStationGeometry.Kind.allCases)
  func boardOnlyDockStillAllowsValidOwnedEquipmentStorageAndRefitting(
    kind: NativeStationGeometry.Kind
  ) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try stationServiceApproach(kind)
    try await verifyStationOwnedFitting(&game, storage: storage)
  }

  @Test(arguments: [false, true])
  func originalMainAndDiscoveredPlughKeepPaidFuelCabinsEquipmentAndMarkets(plugh: Bool) throws {
    var game = Game(executive: false)
    try verifyOriginalStationServices(&game, plugh: plugh)
  }

  @Test func originalMainArrivalNeedsItsActualDoorwayAndCurrentTypedDestination() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    try FileManager.default.createDirectory(
      at: storage.directory, withIntermediateDirectories: true)
    var game = try NativeStationTestFixture.launched()
    try await verifyMainServiceArrival(&game, storage: storage)
  }

  @Test(arguments: MainDestinationChange.allCases)
  func mainDestinationRejectsReplacementOwnershipAndUnprovedArrival(
    change: MainDestinationChange
  ) throws {
    var game = try NativeStationTestFixture.launched()
    try verifyChangedMainDestination(&game, change: change)
  }
}

private func stationServiceApproach(_ kind: NativeStationGeometry.Kind) throws -> Game {
  var game = try NativeStationTestFixture.approach(kind: kind)
  game.commander.credits = 1_000_000
  game.commander.fuel = 10
  game.commander.cargo[0] = 1
  // G04-S149 Food retains its authenticated quotes; only live stock is mutable.
  try #require(game.market[0].price == 215 && game.market[0].bidPrice == 197)
  game.market[0].quantity = 10
  try #require(game.commander.originalMarkets.valid)
  try #require(game.commander.valid && game.commander.fuel < game.commander.fuelCapacity)
  try #require(game.commander.cargoTonnes < game.commander.tradeCargoCapacity)
  return game
}

private func stationServiceFiles(_ directory: URL) throws -> [String: Data] {
  let files = try #require(FileManager.default.enumerator(atPath: directory.path))
  var result: [String: Data] = [:]
  for case let relative as String in files {
    let file = directory.appendingPathComponent(relative)
    guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
      continue
    }
    try #require(!relative.isEmpty && result[relative] == nil)
    result[relative] = try Data(contentsOf: file)
  }
  return result
}

private func verifyStationBoardFacts(
  _ game: inout Game, kind: NativeStationGeometry.Kind, storage: NativeStationTestStorage
) async throws {
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  game = await runtime.advance(delta: 0.1)
  try #require(game.docked && !game.dockedAtMainStation)
  let before = game.commander
  let files = try stationServiceFiles(storage.directory)
  let context = try #require(await runtime.nativeStationBoardContext())
  let receipt = try #require(before.nativeStations?.ledger.currentDock)
  #expect(context.service.receipt == receipt)
  #expect(context.service.capability == .rrsContractBoard)
  #expect(context.station.world == before.equipmentOwnerID)
  #expect(context.station.system == game.systemIdentity)
  #expect(context.station.definition == kind.sourceDefinition)
  #expect(context.hour == Int64(floor(before.scriptState.calendarSeconds / 3600)))
  #expect(context.legal == before.legal)
  #expect(context.profileRevision == NativeStationSource.boardRevision)
  #expect(context.adapterRevision == NativeStationSource.adapterRevision)
  #expect(context.geometryRevision == NativeStationGeometry.adapterRevision)
  #expect(await runtime.acceptsNativeStationBoardContext(context))
  let facts = game.nativeStationFacts
  #expect(facts["board_origin"]?.string == (kind == .waystation ? "source" : "project_extension"))
  #expect(facts["station_id"]?.string == receipt.station.key)
  #expect(facts["docking_sequence"]?.integer == Int64(receipt.sequence))
  #expect(facts["lifecycle_revision"]?.integer == Int64(receipt.lifecycleRevision))
  #expect(facts["market_available"] == .bool(false))
  #expect(facts["equipment_available"] == .bool(false))
  #expect(facts["runtime_epoch"] == nil && facts["service_token"] == nil)
  #expect(game.nativeStationEventFacts?.value["board_origin"] == facts["board_origin"])
  #expect(!game.stationAllowsMarketServices && !game.stationAllowsEquipmentServices)
  #expect(await runtime.snapshot().commander == before)
  #expect(try stationServiceFiles(storage.directory) == files)
}

private func replaceServiceOwner(_ game: inout Game) throws {
  let inventory = try #require(game.commander.equipmentInventory)
  game.commander.savedEquipmentInventory = try OwnedEquipmentInventory(
    owner: UUID(), activeHull: inventory.activeHull, revision: inventory.revision,
    items: inventory.items)
}

private func verifyChangedStationBoard(
  _ game: inout Game, change: StationBoardChange, storage: NativeStationTestStorage
) async throws {
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  game = await runtime.advance(delta: 0.1)
  let original = try #require(game.nativeStationBoardContext)
  switch change {
  case .pause:
    await runtime.key("pause")
    game = await runtime.snapshot()
    try #require(game.paused)
  case .launch, .manualCancel:
    await runtime.key("0")
    if change == .manualCancel { await runtime.key("q") }
    game = await runtime.snapshot()
    try #require(!game.docked)
  case .actorEpoch:
    let replacement = GameRuntime(game: game, saveURL: storage.url)
    game = await replacement.snapshot()
    let fresh = try #require(game.nativeStationBoardContext)
    #expect(fresh.service.receipt == original.service.receipt)
    #expect(fresh.service.runtimeEpoch != original.service.runtimeEpoch)
    #expect(game.acceptsNativeStationBoardContext(fresh))
  case .owner: try replaceServiceOwner(&game)
  case .system: game.commander.system = (game.commander.system + 1) % 256
  case .hour: game.commander.scriptState.calendarSeconds += 3600
  case .overflow: game.commander.scriptState.calendarSeconds = .greatestFiniteMagnitude
  case .legal: game.commander.legal += 1
  case .durability: game.scriptDurabilityAvailable = false
  case .lifecycle:
    try game.commander.nativeStations?.ledger.destroy(
      original.station, binding: original.service.receipt.dockingBinding)
  }
  let beforeQuery = game.commander
  #expect(!game.acceptsNativeStationBoardContext(original))
  if change == .hour || change == .legal {
    let current = try #require(game.nativeStationBoardContext)
    #expect(current != original && game.acceptsNativeStationBoardContext(current))
  } else if change != .actorEpoch {
    #expect(game.nativeStationBoardContext == nil)
  }
  #expect(game.commander == beforeQuery)
}

private func verifyStationBoardLoad(
  _ game: inout Game, storage: NativeStationTestStorage
) async throws {
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  game = await runtime.advance(delta: 0.1)
  let prior = try #require(game.nativeStationBoardContext)
  let priorFacts = game.nativeStationFacts
  try await runtime.save(to: storage.url)
  game = await runtime.snapshot()
  let before = game.commander
  let files = try stationServiceFiles(storage.directory)
  let reloaded = GameRuntime()
  try await reloaded.load(from: storage.url, persistMigrations: false)
  game = await reloaded.snapshot()
  let fresh = try #require(await reloaded.nativeStationBoardContext())
  #expect(fresh.service.receipt == prior.service.receipt)
  #expect(fresh.service.runtimeEpoch != prior.service.runtimeEpoch)
  #expect(fresh.hour == prior.hour && fresh.legal == prior.legal)
  #expect(!game.acceptsNativeStationBoardContext(prior))
  #expect(await reloaded.acceptsNativeStationBoardContext(fresh))
  // The same Lua-visible facts survive; they do not carry the fresh native authority.
  #expect(game.nativeStationFacts == priorFacts)
  #expect(game.commander == before)
  #expect(
    game.commander.nativeStations?.ledger.nextDockSequence == prior.service.receipt.sequence + 1)
  #expect(try stationServiceFiles(storage.directory) == files)
}

private func verifyRawStationBoardRefusal(_ game: inout Game) throws {
  let station = try #require(game.bodies.first { $0.nativeStationIdentity != nil })
  let identity = try #require(station.nativeStationIdentity)
  let actor = try #require(station.physical?.identity)
  game.dock(atMainStation: false)
  let commanderOwner = game.commander.equipmentOwnerID
  try game.commander.nativeStations?.ledger.recordDock(
    at: identity, binding: .init(actor: actor, bodyID: station.id),
    commanderOwner: commanderOwner)
  game.scriptDurabilityAvailable = true
  try #require(game.commander.nativeStationStateValid)
  let before = game.commander
  #expect(game.nativeStationBoardContext == nil)
  #expect(game.nativeStationFacts == .null && game.nativeStationEventFacts == nil)
  #expect(!game.nativeStationDockEvidenceIsCurrent && game.commander == before)
}

private func verifyStationShopRefusals(
  _ game: inout Game, storage: NativeStationTestStorage
) async throws {
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  game = await runtime.advance(delta: 0.1)
  try #require(game.nativeStationBoardContext != nil)
  let before = game.commander
  let market = game.market
  let files = try stationServiceFiles(storage.directory)
  try #require(before.fuel < before.fuelCapacity && before.credits > PassengerCabin.price)
  try #require(before.cargo[0] > 0 && market[0].quantity > 0)
  try #require(before.cargoTonnes < before.tradeCargoCapacity)
  for name in ["Fuel", FuelStorage.equipmentName, PassengerCabin.equipmentName] {
    game.screen = .equipment
    game.selection = try #require(Equipment.all.firstIndex { $0.name == name })
    try #require(before.availableCredits > game.shopPrice(Equipment.all[game.selection]))
    let context = try #require(game.equipmentPurchaseContext)
    let transaction = game.performEquipmentMutation(.purchase(context))
    #expect(transaction == .refused(.staleContext))
    game.purchase()
    #expect(game.commander == before)
  }
  let device = try #require(Equipment.all.first { $0.name == FuelStorage.equipmentName })
  #expect(throws: EquipmentRuntimeError.unavailable) { _ = try game.quoteEquipmentPurchase(device) }
  let cabin = game.passengerBerthQuote
  #expect(!cabin.allowed && cabin.issues == ["Cabin fitting requires a main orbital station."])
  #expect(throws: (any Error).self) { _ = try game.confirmPassengerBerth(cabin) }
  game.selection = 0
  game.trade(buy: true)
  game.trade(buy: false)
  game.autoTrade()
  #expect(game.commander == before && game.market == market)
  // Exercise the actor's typed and native-key paths against the same real dock custody.
  await runtime.key("screen:3")
  game = await runtime.snapshot()
  try #require(Equipment.all[game.selection].name == "Fuel")
  let context = try #require(game.equipmentPurchaseContext)
  #expect(await runtime.equipmentTransaction(.purchase(context)) == .refused(.staleContext))
  await runtime.key("return")
  let cabinQuote = await runtime.passengerBerthQuote()
  await #expect(throws: (any Error).self) { try await runtime.confirmPassengerBerth(cabinQuote) }
  game = await runtime.snapshot()
  #expect(game.commander == before && game.market == market)
  #expect(try stationServiceFiles(storage.directory) == files)
}

private func verifyStationOwnedFitting(
  _ game: inout Game, storage: NativeStationTestStorage
) async throws {
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  game = await runtime.advance(delta: 0.1)
  let receipt = try #require(game.commander.nativeStations?.ledger.currentDock)
  let before = game.commander
  await runtime.key("screen:9")
  game = await runtime.snapshot()
  let pulse = try #require(game.commander.fittedEquipment(at: .laser(.front)))
  let store = try #require(game.inventoryActionPreview(for: .equipment(pulse)).command)
  #expect(await runtime.inventoryCommand(store))
  game = await runtime.snapshot()
  let stored = try #require(game.commander.equipmentInventory?.items.first { $0.id == pulse.id })
  #expect(stored.location == nil && stored.moved(to: nil) == pulse.moved(to: nil))
  let fit = try #require(game.inventoryActionPreview(for: .equipment(stored)).command)
  #expect(await runtime.inventoryCommand(fit))
  game = await runtime.snapshot()
  #expect(game.commander.equipmentInventory?.items.first { $0.id == pulse.id } == pulse)
  #expect(game.commander.credits == before.credits && game.commander.cargo == before.cargo)
  #expect(game.commander.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
  #expect(game.commander.accommodation == before.accommodation)
  let inventory = try #require(before.equipmentInventory)
  var expected = before
  expected.savedEquipmentInventory = try OwnedEquipmentInventory(
    owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision + 2,
    items: inventory.items)
  #expect(game.commander == expected)
  #expect(game.commander.nativeStations?.ledger.currentDock == receipt)
  #expect(game.nativeStationBoardContext != nil && !game.stationAllowsEquipmentServices)
  let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: storage.url), from: storage.url)
  #expect(saved == game.commander)
  let cabin = game.commander.accommodation.addCabin(.stateroomSingle, fitted: false)
  let unchanged = game.commander
  #expect(throws: (any Error).self) { try game.setPassengerBerthFitted(cabin, fitted: true) }
  #expect(game.commander == unchanged)
}

private func verifyOriginalStationServices(_ game: inout Game, plugh: Bool) throws {
  if plugh {
    game.commander.discoverPlugh(in: game.commander.galaxy)
    game.commander.system = Plugh.systemID
  }
  game.commander.credits = 1_000_000
  game.commander.fuel = 10
  game.commander.cargo[0] = 1
  try game.commander.prepareEquipment(legacy: false)
  game.commander.mirrorFittedEquipment()
  game.screen = .equipment
  try #require(game.commander.valid && game.docked && game.dockedAtMainStation)
  #expect(game.stationAllowsMarketServices && game.stationAllowsEquipmentServices)
  #expect(game.atPlugh == plugh && game.nativeStationBoardContext == nil)
  game.selection = try #require(Equipment.all.firstIndex { $0.name == "Fuel" })
  let fuelPrice = game.refillCost
  let cash = game.commander.credits
  let fuel = try #require(game.equipmentPurchaseContext)
  let fuelResult = game.performEquipmentMutation(.purchase(fuel))
  #expect(fuelResult.applied)
  #expect(game.commander.fuel == game.commander.fuelCapacity)
  #expect(game.commander.credits == cash - fuelPrice)
  let device = try #require(Equipment.all.first { $0.name == FuelStorage.equipmentName })
  let quote = try game.quoteEquipmentPurchase(device)
  _ = try game.applyEquipmentPurchase(quote)
  #expect(game.commander.fuelStorageUnits == 1)
  #expect(game.commander.equipmentPurchaseHistory?.paid.count == 1)
  let cabinQuote = game.passengerBerthQuote
  try #require(cabinQuote.allowed)
  let berth = try game.confirmPassengerBerth(cabinQuote)
  #expect(game.commander.accommodation.fitted.contains(berth))
  game.selection = 0
  // G01-S007 Food is 226/208; PLUGH discounts each authenticated quote once.
  let ask = plugh ? 170 : 226
  let bid = plugh ? 156 : 208
  try #require(game.market[0].price == ask && game.market[0].bidPrice == bid)
  game.market[0].quantity = 10
  try #require(game.commander.originalMarkets.valid && game.commander.valid)
  let beforeBuy = game.commander.credits
  let cargo = game.commander.cargo[0]
  game.trade(buy: true)
  #expect(game.commander.cargo[0] == cargo + 1 && game.commander.credits == beforeBuy - ask)
  #expect(game.market[0].quantity == 9)
  game.trade(buy: false)
  #expect(game.commander.cargo[0] == cargo && game.commander.credits == beforeBuy - ask + bid)
  #expect(game.market[0].quantity == 10)
  #expect(game.commander.valid)
}

private func verifyMainServiceArrival(
  _ game: inout Game, storage: NativeStationTestStorage
) async throws {
  guard case .living(let destination) = game.nativeOriginalMainStationDestination else {
    throw NativeStationRuntimeError.invalidState
  }
  #expect(game.acceptsNativeMainStationDestination(destination))
  #expect(game.nativeMainStationArrivalContext(for: destination.identity) == nil)
  let station = try #require(game.bodies.first { $0.id == 0 })
  let old = game.commander.flightSimulation.pose
  var pose = ShipPose()
  pose.position = old.systemPoint(station.entrancePosition + station.entranceNormal * 2)
  pose.orientation.y = old.orientation.apply(station.entranceUp)
  pose.orientation.z = old.orientation.apply(station.entranceNormal) * -1
  pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
  NativeStationTestFixture.reframe(&game, to: pose)
  game.speed = 3
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  game = await runtime.snapshot()
  for _ in 0..<100 where !game.docked { game = await runtime.advance(delta: 0.1) }
  try #require(game.docked && game.dockedAtMainStation)
  let context = try #require(
    await runtime.nativeMainStationArrivalContext(for: destination.identity))
  #expect(game.acceptsNativeMainStationArrivalContext(context))
  #expect(context.receipt.station == destination.identity && context.receipt.actor.entity == 1)
  #expect(context.destination.identity.resource == destination.identity.resource)
  #expect(context.receipt.commanderOwner == game.commander.equipmentOwnerID)
  let other = NativeMainStationIdentity(
    world: UUID(), system: destination.identity.system, resource: destination.identity.resource)
  #expect(game.nativeMainStationArrivalContext(for: other) == nil)
  let before = game.commander
  let files = try stationServiceFiles(storage.directory)
  await runtime.key("pause")
  game = await runtime.snapshot()
  #expect(game.paused && !game.acceptsNativeMainStationArrivalContext(context))
  #expect(game.commander == before)
  #expect(try stationServiceFiles(storage.directory) == files)
}

private func verifyChangedMainDestination(
  _ game: inout Game, change: MainDestinationChange
) throws {
  guard case .living(let original) = game.nativeOriginalMainStationDestination else {
    throw NativeStationRuntimeError.invalidState
  }
  switch change {
  case .replacementActor:
    let index = try #require(game.bodies.firstIndex { $0.id == 0 })
    let allocatedActor = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocatedActor)
    let originalBody = try #require(game.bodies[index].physical)
    game.bodies[index].physical = .init(
      identity: actor, population: originalBody.population, npc: originalBody.npc)
  case .owner: try replaceServiceOwner(&game)
  case .destroyed:
    game.commander.scriptState.stationResources[original.identity.key]?.energy = 0
    game.commander.scriptState.stationResources[original.identity.key]?.destroyed = true
  case .rawDockFlags: game.dock(atMainStation: true)
  case .actorEpoch: game.invalidateNativeStationAuthority()
  }
  let before = game.commander
  #expect(!game.acceptsNativeMainStationDestination(original))
  #expect(game.nativeMainStationArrivalContext(for: original.identity) == nil)
  if change == .destroyed {
    guard case .destroyed(let identity) = game.nativeOriginalMainStationDestination else {
      throw NativeStationRuntimeError.invalidState
    }
    #expect(identity == original.identity)
  }
  #expect(game.commander == before)
}
