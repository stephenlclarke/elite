import CoreFoundation
import Foundation
import Testing

@testable import EliteCore

// Codable represents enum-keyed maps and Sets as arrays; compare their values independent of order.
private func solarEquipmentComparison(_ encoded: Any?) throws -> [String: Any] {
  func statistics(_ encoded: Any?) throws -> [Any] {
    let values = try #require(encoded as? [Any])
    try #require(values.count.isMultiple(of: 2))
    var pairs: [(axis: String, value: NSNumber)] = []
    var axes: Set<String> = []
    for index in stride(from: 0, to: values.count, by: 2) {
      let axis = try #require(values[index] as? String)
      try #require(ComponentAxis(rawValue: axis) != nil && axes.insert(axis).inserted)
      let number = try #require(values[index + 1] as? NSNumber)
      try #require(CFGetTypeID(number) != CFBooleanGetTypeID() && number.doubleValue.isFinite)
      pairs.append((axis, number))
    }
    return pairs.sorted { $0.axis < $1.axis }.flatMap { [$0.axis, $0.value] as [Any] }
  }
  func members(_ encoded: Any?, axes: Bool = false) throws -> [String] {
    let values = try #require(encoded as? [String])
    try #require(Set(values).count == values.count)
    if axes { try #require(values.allSatisfy { ComponentAxis(rawValue: $0) != nil }) }
    return values.sorted()
  }
  var inventory = try #require(encoded as? [String: Any])
  var items = try #require(inventory["items"] as? [[String: Any]])
  for index in items.indices {
    // Equipment without a component has no component maps or Sets to canonicalize.
    guard let encodedComponent = items[index]["component"] else { continue }
    var component = try #require(encodedComponent as? [String: Any])
    var origin = try #require(component["origin"] as? [String: Any])
    component["statistics"] = try statistics(component["statistics"])
    component["features"] = try members(component["features"])
    origin["statistics"] = try statistics(origin["statistics"])
    origin["requiredAxes"] = try members(origin["requiredAxes"], axes: true)
    origin["compatibleFeatures"] = try members(origin["compatibleFeatures"])
    component["origin"] = origin
    items[index]["component"] = component
  }
  inventory["items"] = items
  return inventory
}

private func solarGame(distance: Double = 2970) throws -> Game {
  var game = Game(executive: false)
  game.launch()
  game.bodies = []
  game.celestials = [.init(kind: .sun, position: .init(0, 0, distance), radius: 1100)]
  try game.commander.grantEquipment(
    "Fuel Scoops", at: .utility(.fuelScoops), provenance: .grant("solar fixture"))
  game.commander.fuel = 0
  game.speed = 8
  return game
}

private func solarWorldAfterRelaunch(
  _ game: inout Game, saved: NativeStationWorld
) throws -> NativeStationWorld {
  var expected = saved
  let flight = game.commander.flightSimulation
  let anchors = try #require(flight.anchors)
  for record in saved.ledger.records
  where record.identity.system == game.systemIdentity && record.tombstone == nil {
    let body = try #require(
      game.bodies.first { $0.nativeStationIdentity == record.identity })
    let actor = try #require(body.physical?.identity)
    #expect(actor.system == game.systemIdentity && actor.visit == flight.visit)
    #expect(record.binding?.actor != actor)
    try expected.ledger.rebind(record.identity, to: .init(actor: actor, bodyID: body.id))
  }
  // A new visit observes the same original station with its new physical actor.
  expected.mainObservations = saved.mainObservations.map { observation in
    guard observation.station.system == game.systemIdentity else { return observation }
    return .init(
      station: observation.station, actor: anchors.station.identity,
      calendarSeconds: game.commander.scriptState.calendarSeconds)
  }
  #expect(expected.valid)
  return expected
}

@Test func solarScoopAccumulatesFractionalFuelAndRespectsTankCapacity() throws {
  var game = try solarGame()
  for _ in 0..<10 { game.advanceSolarFlight(delta: 0.1) }
  #expect(game.commander.fuel == 7)
  #expect(game.solarScoopState == .collecting)
  #expect(game.cabinTemperature > 0 && game.cabinTemperature < 0.75)
  game.commander.fuel = game.commander.fuelCapacity - 1
  for _ in 0..<10 { game.advanceSolarFlight(delta: 0.1) }
  #expect(game.commander.fuel == game.commander.fuelCapacity)
  #expect(game.solarScoopState == .tankFull && game.solarFuelRemainder == 0)
}

@Test func solarScoopRequiresEquipmentRangeNoseFacingAndForwardCruise() throws {
  var game = try solarGame()
  _ = try game.commander.removeFittedEquipment("Fuel Scoops")
  game.advanceSolarFlight(delta: 1)
  #expect(game.commander.fuel == 0 && game.solarScoopState == .noScoops)
  #expect(game.cabinTemperature > 0)
  try game.commander.grantEquipment(
    "Fuel Scoops", at: .utility(.fuelScoops), provenance: .grant("solar fixture"))
  game.speed = 0
  game.advanceSolarFlight(delta: 1)
  #expect(game.commander.fuel == 0 && game.solarScoopState == .turnTowardSun)
  game.speed = 8
  game.celestials[0].position.z = -2970
  game.advanceSolarFlight(delta: 1)
  #expect(game.commander.fuel == 0 && game.solarScoopState == .turnTowardSun)
  game.celestials[0].position = .init(0, 0, 5000)
  game.advanceSolarFlight(delta: 1)
  #expect(game.commander.fuel == 0 && game.solarScoopState == .inactive)
  game.celestials[0] = .init(kind: .planet, position: .init(0, 0, 2970), radius: 1100)
  game.advanceSolarFlight(delta: 1)
  #expect(game.commander.fuel == 0)
}

@Test func solarCollectionDependsOnNoseInsteadOfSelectedCameraAndScalesWithCruise() throws {
  var game = try solarGame()
  game.screen = .rear
  game.speed = 4
  game.advanceSolarFlight(delta: 1)
  #expect(game.commander.fuel == 3 && abs(game.solarFuelRemainder - 0.5) < 0.000001)
  #expect(game.solarScoopState == .collecting)
}

@Test func thermalExposureCoolsAwayFromSunAndKillsDespiteShieldsOrXYZzyFuel() throws {
  var game = try solarGame(distance: 1500)
  game.commander.unlimitedFuel = true
  game.commander.fuel = game.commander.fuelCapacity
  for _ in 0..<30 where game.screen != .gameOver { game.advanceSolarFlight(delta: 0.1) }
  #expect(game.screen == .gameOver && game.energy == 0)
  #expect(game.message.contains("OVERHEATED"))
  #expect(game.frontShield > 0)
  var cooling = try solarGame(distance: 10000)
  cooling.cabinTemperature = 0.9
  for _ in 0..<50 { cooling.advanceSolarFlight(delta: 0.1) }
  #expect(cooling.cabinTemperature < 0.5 && cooling.screen == .front)
}

@Test func celestialSurfaceImpactsAreFatalAndProximityMassLocksJumps() throws {
  var game = try solarGame(distance: 1000)
  #expect(game.massLocked)
  let before = game.celestials
  game.inSystemJump()
  #expect(game.celestials == before && game.message == "MASS LOCKED")
  game.advanceSolarFlight(delta: 0.1)
  #expect(game.screen == .gameOver && game.message == "DESTROYED IN THE SUN")
  var planet = try solarGame()
  planet.celestials = [.init(kind: .planet, position: .init(0, 0, 900), radius: 1000)]
  planet.advanceSolarFlight(delta: 0.1)
  #expect(planet.screen == .gameOver && planet.message == "PLANET IMPACT")
}

@Test func flightTickMovesCelestialsExactlyWithShipsAndFreezesForHelp() throws {
  var game = try solarGame(distance: 12000)
  game.bodies = [.init(id: 100, hull: .cargo, position: .init(0, 0, 12000))]
  game.tick(delta: 0.1, controls: Controls())
  #expect(game.celestials[0].position == game.bodies[0].position)
  let prior = game.celestials
  let heat = game.cabinTemperature
  game.screen = .help
  game.tick(delta: 0.1)
  #expect(game.celestials == prior && game.cabinTemperature == heat)
  game.screen = .front
  game.inSystemJump()
  #expect(game.celestials[0].position.z == prior[0].position.z - 3000)
}

@Test func dockingLoadingAndArrivalUseExistingDockedSaveSemantics() async throws {
  var game = try solarGame()
  do {
    // The legacy loader has no saved flight world; use a genuinely pre-launch Commander.
    var legacy = Commander()
    legacy.equipment.insert("Fuel Scoops")
    legacy.fuel = 0
    try #require(legacy.equipmentInventory == nil && !legacy.usesModularDriveSaveVersion)
    try #require(!legacy.usesEconomyMiningSaveVersion && legacy.nativeStations == nil)
    let bytes = try JSONEncoder().encode(legacy)
    let decoded = try JSONDecoder().decode(Commander.self, from: bytes)
    game.cabinTemperature = 0.6
    try #require(!game.docked && !game.celestials.isEmpty)
    let loaded = game.load(decoded)
    #expect(loaded)
    #expect(game.docked && game.celestials.isEmpty && game.cabinTemperature == 0)
    #expect(decoded == legacy && game.commander.valid)
  }
  game = try solarGame()
  game.cabinTemperature = 0.9
  game.dock()
  #expect(game.celestials.isEmpty && game.cabinTemperature == 0)
  game.launch()
  #expect(Set(game.celestials.map(\.kind)) == [.sun, .planet])
  let scene = game.celestials
  game.cabinTemperature = 0.6
  try game.commander.prepareEquipment()
  game.commander.mirrorFittedEquipment()
  // A current world restores its saved flight state, so actually dock before saving it.
  game.dock()
  try #require(game.docked && game.celestials.isEmpty && game.cabinTemperature == 0)
  let parked = game.commander.npcPersistence
  try #require(parked.valid && parked.count > 0 && parked.livingCount > 0)
  try #require(
    !parked.unboundSnapshots.isEmpty && parked.unboundSnapshots.count == parked.livingCount)
  try #require(parked.unboundSnapshots.values.allSatisfy { $0.valid })
  try #require(game.bodies.isEmpty)
  var alreadyParked = parked
  alreadyParked.resetPhysicalBindings(system: game.systemIdentity)
  try #require(alreadyParked == parked)
  try NativeSaveTestFixture.prepareCurrentPolicy(&game)
  let expectedCommander = game.commander
  try #require(expectedCommander.miningLedger.usesEconomyWeightedPresence)
  try #require(expectedCommander.scriptState.calendarLedger != nil)
  var expectedDisk = expectedCommander
  expectedDisk.npcPersistence.resetPhysicalBindings(system: game.systemIdentity)
  expectedDisk.resetWantedCareerBindings(system: game.systemIdentity)
  try #require(expectedDisk == expectedCommander && expectedDisk.npcPersistence == parked)
  let expectedWorld = game.scriptWorldSave
  let worldEncoder = ScriptValueStorage.encoder()
  let expectedWorldBytes = try worldEncoder.encode(expectedWorld)
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  let file = directory.appendingPathComponent("commander.json")
  let runtime = GameRuntime(game: game)
  try #require(await runtime.snapshot().commander == game.commander)
  try await runtime.save(to: file)
  let published = await runtime.snapshot()
  let commander = published.commander
  #expect(commander == expectedCommander)
  #expect(published.commander.npcPersistence == parked)
  #expect(try worldEncoder.encode(published.scriptWorldSave) == expectedWorldBytes)
  let bytes = try Data(contentsOf: file)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
  try #require(pointer.schemaVersion == 26 && pointer.scope == "commander")
  let (stored, world) = try ScriptSaveStore.read(bytes, from: file)
  #expect(
    stored == expectedDisk && world.docked && world.valid && world.consistent(with: stored))
  #expect(stored.npcPersistence == parked)
  #expect(try worldEncoder.encode(world) == expectedWorldBytes)
  let files = try ScriptFinanceTestFixture.files(directory)
  try await runtime.load(from: file, persistMigrations: false)
  game = await runtime.snapshot()
  #expect(game.commander == commander)
  #expect(game.commander == expectedDisk && game.commander.npcPersistence == parked)
  #expect(try worldEncoder.encode(game.scriptWorldSave) == expectedWorldBytes)
  #expect(try ScriptFinanceTestFixture.files(directory) == files)
  #expect(game.docked && game.celestials.isEmpty && game.cabinTemperature == 0)
  game.launch()
  #expect(game.celestials == scene)
  #expect(game.commander.flightSimulation.visit == commander.flightSimulation.visit + 1)
  #expect(game.commander.equipment == commander.equipment)
  #expect(game.commander.equipmentInventory == commander.equipmentInventory)
  #expect(game.commander.equipmentPurchaseHistory == commander.equipmentPurchaseHistory)
  var actual = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(game.commander)) as? [String: Any])
  var expected = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(commander)) as? [String: Any])
  actual["equipment"] = game.commander.equipment.sorted()
  expected["equipment"] = commander.equipment.sorted()
  let savedWorld = try #require(commander.nativeStations)
  let reboundWorld = try solarWorldAfterRelaunch(&game, saved: savedWorld)
  expected["nativeStations"] = try JSONSerialization.jsonObject(
    with: JSONEncoder().encode(reboundWorld))
  // A genuine docked relaunch adds ten minutes while preserving all other script state.
  var expectedState = commander.scriptState
  var ledger = try #require(expectedState.calendarLedger)
  try #require(expectedState.missionCalendar == nil && ledger.pendingJourney == nil)
  try #require(
    ledger.operation < UInt64(Int64.max) - 1 && expectedState.calendarSeconds <= 1e12 - 600)
  let calendarBefore = expectedState.calendarSeconds
  expectedState.calendarSeconds += 600
  ledger.operation += 1
  ledger.lastAdjustment = .init(
    operation: ledger.operation, kind: .launch, seconds: 600,
    before: calendarBefore, after: expectedState.calendarSeconds)
  expectedState.calendarLedger = ledger
  #expect(game.commander.scriptState.calendarSeconds == calendarBefore + 600)
  #expect(game.commander.scriptState.calendarLedger == ledger)
  expected["savedScriptState"] = try JSONSerialization.jsonObject(
    with: JSONEncoder().encode(expectedState))
  // Re-launch can observe newly rebound actual actors. Derive only those allowed
  // changes from the accepted native ledger, never from the wanted writer output.
  var expectedWanted = commander.wantedCareers
  let context = try #require(game.gameplayContext())
  for body in game.bodies where game.wantedCareerIsOrdinary(body) {
    guard let actor = body.physical?.identity,
      let logical = game.commander.npcPersistence.logicalIdentity(for: actor),
      let snapshot = game.commander.npcPersistence.snapshot(for: logical)
    else { continue }
    expectedWanted.observe(
      snapshot, logical: logical,
      visible: body.position.length <= context.perceptionRadius)
  }
  expectedWanted.reconcile(game.commander.npcPersistence, system: game.systemIdentity)
  #expect(game.commander.wantedCareers == expectedWanted)
  for key in [
    "savedFlightSimulation", "savedCrimeLedger", "savedStationSecurity", "savedMiningLedger",
    "encounterDirector", "savedNPCPersistence", "savedWantedCareers",
  ] {
    actual.removeValue(forKey: key)
    expected.removeValue(forKey: key)
  }
  actual["savedEquipmentInventory"] = try solarEquipmentComparison(
    actual["savedEquipmentInventory"])
  expected["savedEquipmentInventory"] = try solarEquipmentComparison(
    expected["savedEquipmentInventory"])
  #expect(NSDictionary(dictionary: actual).isEqual(to: expected))
}

@Test func solarHUDReportsActualScoopAndThermalDanger() throws {
  var game = try solarGame()
  game.advanceSolarFlight(delta: 0.1)
  #expect(game.solarHUDLines.contains { $0.contains("SCOOP ACTIVE") })
  game.cabinTemperature = 0.95
  #expect(game.solarHUDLines.contains { $0.contains("CRITICAL") })
  game.celestials[0].position = .init(-1000, 1000, -3000)
  #expect(game.solarHUDLines[0].contains("ASTERN PORT UP"))
}

@Test func celestialHUDBearingsFollowTheSelectedCockpitView() throws {
  for (screen, position) in [
    (Screen.front, Vector3(0, 0, 1000)),
    (.rear, .init(0, 0, -1000)),
    (.left, .init(-1000, 0, 0)),
    (.right, .init(1000, 0, 0)),
  ] {
    var game = try solarGame()
    game.screen = screen
    game.celestials[0].position = position
    #expect(game.solarHUDLines[0].contains("SUN AHEAD"))
    #expect(!game.solarHUDLines[0].contains("ASTERN"))
  }
}
