import Foundation
import Testing

@testable import L337Core

private func mainCapacityGame(discoverAllGalaxies: Bool = false) throws -> Game {
  var game = Game(executive: false)
  try game.commander.prepareEquipment(legacy: false)
  game.launch()
  try #require(!game.docked)
  game.dock()
  try #require(game.docked && game.commander.valid)
  try #require(game.commander.system == Plugh.rumourStation)
  let originalGalaxy = game.commander.galaxy
  let galaxies = discoverAllGalaxies ? Array(0..<8) : [originalGalaxy]
  for galaxy in galaxies {
    // Select the private docked fixture's location, then use the real discovery action.
    // No discovery bits or arrival/service receipts are manufactured.
    game.commander.galaxy = galaxy
    game.systems = Universe.systemsIncludingPlugh(number: galaxy)
    try #require(game.docked && game.commander.valid && game.screen == .status)
    game.openStationRumour()
    try #require(game.screen == .rumour && game.commander.hasDiscoveredPlugh(in: galaxy))
    game.key("escape")
    try #require(game.screen == .status && game.commander.valid)
  }
  game.commander.galaxy = originalGalaxy
  game.systems = Universe.systemsIncludingPlugh(number: originalGalaxy)
  try #require(game.commander.valid)
  return game
}

/// Controlled canonical historical snapshots, not simulated flights or invented service receipts.
/// Existing observations/resources and every RRS record, pose and counter are retained exactly.
private func installMainHistory(_ systems: [SystemIdentity], in game: inout Game) throws {
  var world = try #require(game.commander.nativeStations)
  let oldObservations = Dictionary(
    uniqueKeysWithValues: world.mainObservations.map { ($0.station, $0) })
  let oldResources = game.commander.scriptState.stationResources
  var resources: [String: ScriptStationResource] = [:]
  let identities = systems.map { system in
    let key = "main-orbital:\(system.galaxy):\(system.system)"
    return NativeMainStationIdentity(
      world: world.ledger.world, system: system,
      resource: Game.worldResourceIdentity("main-station-v1:\(key)"))
  }
  world.mainStations = identities
  world.mainObservations = identities.map { station in
    oldObservations[station]
      ?? .init(
        station: station, actor: .init(system: station.system, visit: 1, entity: 1),
        calendarSeconds: 0)
  }
  for (index, station) in identities.enumerated() {
    var resource =
      oldResources[station.key]
      ?? ScriptStationResource(
        identity: station.resource, galaxy: station.system.galaxy, system: station.system.system)
    if oldResources[station.key] == nil {
      resource.energy = Double(17 + index % 11)
      if index % 97 == 0 {
        resource.energy = 0
        resource.destroyed = true
      }
    }
    resources[station.key] = resource
  }
  game.commander.nativeStations = world
  game.commander.scriptState.stationResources = resources
}

private func mainCapacitySystems() -> [SystemIdentity] {
  (0..<8).flatMap { galaxy in
    (0...Plugh.systemID).map { .init(galaxy: galaxy, system: $0) }
  }
}

struct NativeMainStationCapacityTests {
  @Test(arguments: [SystemIdentity(galaxy: 0, system: Plugh.systemID), .init(galaxy: 1, system: 0)])
  func actualNativeRegistrationAccepts257thMainAcrossPlughAndGalaxies(target: SystemIdentity)
    throws
  {
    var game = try mainCapacityGame()
    try installMainHistory((0..<256).map { .init(galaxy: 0, system: $0) }, in: &game)
    try #require(game.commander.valid)
    let before = try #require(game.commander.nativeStations)
    let resources = game.commander.scriptState.stationResources
    try #require(before.mainStations.count == 256 && before.mainObservations.count == 256)
    // Select the private fixture's initial location; launch loads the actual original body and
    // calls registerOriginalNativeMainStation. This is not a claim of hyperspace travel coverage.
    game.commander.galaxy = target.galaxy
    game.commander.system = target.system
    try #require(
      target.system != Plugh.systemID || game.commander.hasDiscoveredPlugh(in: target.galaxy))
    try #require(game.commander.valid)
    game.systems = Universe.systemsIncludingPlugh(number: target.galaxy)
    game.launch()
    try #require(!game.docked && game.commander.valid)
    let after = try #require(game.commander.nativeStations)
    #expect(after.mainStations.count == 257 && after.mainObservations.count == 257)
    #expect(game.commander.scriptState.stationResources.count == 257)
    #expect(Array(after.mainStations.prefix(256)) == before.mainStations)
    #expect(Array(after.mainObservations.prefix(256)) == before.mainObservations)
    #expect(
      resources.allSatisfy { game.commander.scriptState.stationResources[$0.key] == $0.value })
    let identity = try #require(after.mainStations.first { $0.system == target })
    let observation = try #require(after.mainObservations.first { $0.station == identity })
    let station = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
    #expect(identity.world == before.ledger.world && identity.valid)
    #expect(observation.actor == game.commander.flightSimulation.anchors?.station.identity)
    #expect(observation.actor == station.physical?.identity)
    #expect(game.commander.scriptState.stationResources[identity.key]?.energy == station.energy)
    #expect(after.currentMainDock == nil && after.ledger.currentDock == nil)
    #expect(after.nextMainDockSequence == before.nextMainDockSequence)
    #expect(after.ledger.nextDockSequence == before.ledger.nextDockSequence)
    #expect(after.ledger.world == before.ledger.world)
    #expect(after.ledger.records.map(\.identity) == before.ledger.records.map(\.identity))
    #expect(after.ledger.records.map(\.tombstone) == before.ledger.records.map(\.tombstone))
    let registered = game.commander
    try game.registerOriginalNativeMainStation()
    #expect(game.commander == registered)
  }

  @Test func all2056CanonicalMainHistoriesAndResourcesRoundTripWithoutDroppingOwnerOrHistory()
    async throws
  {
    var game = try mainCapacityGame(discoverAllGalaxies: true)
    #expect((0..<8).allSatisfy { game.commander.hasDiscoveredPlugh(in: $0) })
    let previous = try #require(game.commander.nativeStations)
    let systems = mainCapacitySystems()
    #expect(NativeMainStationIdentity.maximumCount == 2056 && systems.count == 2056)
    try installMainHistory(systems, in: &game)
    try #require(game.commander.valid)
    let world = try #require(game.commander.nativeStations)
    let state = game.commander.scriptState
    #expect(world.valid && state.worldJobsValid)
    // Retained independent station chances joined to authenticated l337-world-1 governments.
    let expectedWaystations = [45, 49, 51, 44, 46, 52, 42, 45]
    #expect(NativeStationLedger.recordLimit == 382 && NativeStationSource.bindings.count == 382)
    #expect(NativeStationLedger.recordLimit <= NativeStationLedger.maximumSourceRecords)
    let waystationCounts = (0..<8).map { galaxy in
      NativeStationSource.bindings.filter { $0.system.galaxy == galaxy && $0.kind == .waystation }
        .count
    }
    #expect(waystationCounts == expectedWaystations)
    let sourceKeys = NativeStationSource.bindings.map(\.key).sorted().joined(separator: "\n")
    #expect(
      ScriptPackLibrary.hash(Data(sourceKeys.utf8))
        == "3d539657453551102a6f0f682bc9db8039fe231c2dde2cd83b4b3901aee1859b")
    #expect(world.mainStations.count == 2056 && world.mainObservations.count == 2056)
    #expect(state.stationResources.count == 2056)
    #expect(Set(world.mainStations.map(\.system)) == Set(systems))
    #expect(world.ledger == previous.ledger && world.poses == previous.poses)
    #expect(world.currentMainDock == previous.currentMainDock)
    #expect(world.nextMainDockSequence == previous.nextMainDockSequence)
    #expect(
      try JSONDecoder().decode(NativeStationWorld.self, from: JSONEncoder().encode(world)) == world)
    #expect(
      try JSONDecoder().decode(ScriptEngineState.self, from: JSONEncoder().encode(state)) == state)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    let writer = GameRuntime(game: game)
    try await writer.save(to: file)
    let bytes = try Data(contentsOf: file)
    let (saved, _) = try ScriptSaveStore.read(bytes, from: file)
    #expect(saved.valid && saved.nativeStations?.ledger.world == world.ledger.world)
    #expect(saved.nativeStations?.mainStations == world.mainStations)
    #expect(saved.nativeStations?.mainObservations == world.mainObservations)
    #expect(saved.scriptState.stationResources == state.stationResources)
    #expect(saved.nativeStations?.nextMainDockSequence == world.nextMainDockSequence)
    let reader = GameRuntime()
    try await reader.load(from: file, persistMigrations: false)
    let loaded = await reader.snapshot()
    #expect(
      loaded.commander.valid && loaded.commander.equipmentOwnerID == game.commander.equipmentOwnerID
    )
    #expect(loaded.commander.nativeStations?.mainStations == world.mainStations)
    #expect(loaded.commander.nativeStations?.mainObservations == world.mainObservations)
    #expect(loaded.commander.scriptState.stationResources == state.stationResources)
  }

  @Test(arguments: ["mainStations", "mainObservations"])
  func oversized2057ArrayRefusesBeforeDecodingAnInvalidChild(field: String) throws {
    let world = try NativeStationWorld(owner: UUID())
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(world)) as? [String: Any])
    object[field] = Array(repeating: "not a station or observation", count: 2057)
    let bytes = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: NativeStationRuntimeError.invalidState) {
      _ = try JSONDecoder().decode(NativeStationWorld.self, from: bytes)
    }
    // At the accepted count the same child reaches the ordinary typed decoder and still fails.
    object[field] = Array(repeating: "not a station or observation", count: 2056)
    let withinBudget = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: DecodingError.self) {
      _ = try JSONDecoder().decode(NativeStationWorld.self, from: withinBudget)
    }
  }

  @Test func duplicatesForeignOwnersAndOutOfUniverseIdentitiesStillRefuse() throws {
    var game = try mainCapacityGame(discoverAllGalaxies: true)
    try installMainHistory(mainCapacitySystems(), in: &game)
    let original = try #require(game.commander.nativeStations)
    for mutation in 0..<4 {
      var bad = original
      let first = bad.mainStations[0]
      if mutation == 0 {
        bad.mainStations[1] = first
      } else if mutation == 1 {
        bad.mainStations[0] = .init(world: UUID(), system: first.system, resource: first.resource)
      } else {
        let invalid = SystemIdentity(galaxy: mutation == 2 ? 8 : 0, system: mutation == 2 ? 0 : 257)
        let key = "main-orbital:\(invalid.galaxy):\(invalid.system)"
        bad.mainStations[0] = .init(
          world: first.world, system: invalid,
          resource: Game.worldResourceIdentity("main-station-v1:\(key)"))
      }
      #expect(!bad.valid)
      let bytes = try JSONEncoder().encode(bad)
      #expect(throws: NativeStationRuntimeError.invalidState) {
        _ = try JSONDecoder().decode(NativeStationWorld.self, from: bytes)
      }
    }
    var repeatedObservation = original
    repeatedObservation.mainObservations[1] = repeatedObservation.mainObservations[0]
    #expect(!repeatedObservation.valid)
    #expect(throws: NativeStationRuntimeError.invalidState) {
      _ = try JSONDecoder().decode(
        NativeStationWorld.self, from: JSONEncoder().encode(repeatedObservation))
    }
    var foreignCommander = game.commander
    foreignCommander.nativeStations?.ledger = try NativeStationWorld(owner: UUID()).ledger
    #expect(!foreignCommander.nativeStationStateValid && !foreignCommander.valid)
    var extra = game.commander.scriptState
    extra.stationResources["noncanonical-extra"] = extra.stationResources.values.first
    #expect(extra.stationResources.count == 2057 && !extra.worldJobsValid)
    var invalid = game.commander.scriptState
    let resource = try #require(invalid.stationResources.values.first)
    invalid.stationResources[resource.key] = .init(
      identity: resource.identity, galaxy: resource.galaxy, system: 257)
    #expect(!invalid.worldJobsValid)
    var duplicate = game.commander.scriptState
    let keys = duplicate.stationResources.keys.sorted()
    let first = try #require(duplicate.stationResources[keys[0]])
    let second = try #require(duplicate.stationResources[keys[1]])
    duplicate.stationResources[keys[1]] = .init(
      identity: first.identity, galaxy: second.galaxy, system: second.system)
    #expect(!duplicate.worldJobsValid)
  }

  @Test func oldSparseMainHistoryAndMissingOptionalArraysRemainReadable() throws {
    var game = try mainCapacityGame()
    try installMainHistory((0..<256).map { .init(galaxy: 0, system: $0) }, in: &game)
    let world = try #require(game.commander.nativeStations)
    #expect(
      try JSONDecoder().decode(NativeStationWorld.self, from: JSONEncoder().encode(world)) == world)
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(world)) as? [String: Any])
    object.removeValue(forKey: "mainStations")
    object.removeValue(forKey: "mainObservations")
    let bytes = try JSONSerialization.data(withJSONObject: object)
    let legacy = try JSONDecoder().decode(NativeStationWorld.self, from: bytes)
    #expect(legacy.valid && legacy.mainStations.isEmpty && legacy.mainObservations.isEmpty)
    #expect(legacy.ledger == world.ledger && legacy.poses == world.poses)
    #expect(legacy.nextMainDockSequence == world.nextMainDockSequence)
  }
}
