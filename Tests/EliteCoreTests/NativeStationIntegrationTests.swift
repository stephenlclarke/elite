import Foundation
import Testing

@testable import EliteCore

struct NativeStationIntegrationTests {
  @Test func compiledStationBindingsMatchTheRetainedSourcePopulationAndSeparateHeadquarters() throws
  {
    let expected = [47, 47, 48, 32, 48, 47, 49, 46]
    #expect(NativeStationSource.bindings.count == 372)
    for galaxy in 0..<8 {
      let bindings = NativeStationSource.bindings.filter { $0.system.galaxy == galaxy }
      #expect(bindings.filter { $0.kind == .waystation }.count == expected[galaxy])
      let hq = try #require(bindings.first { $0.kind == .headquarters })
      #expect(hq.system.system == [237, 98, 5, 149, 35, 213, 66, 7][galaxy])
      let waystation = try #require(
        bindings.first { $0.system == hq.system && $0.kind == .waystation })
      #expect(waystation.key != hq.key)
      #expect(waystation.descriptor.boardOrigin == .source)
      #expect(hq.descriptor.boardOrigin == .projectExtension)
      #expect(waystation.rotationRate == 0.02 && hq.rotationRate == 0)
      #expect(waystation.technology == 7 && hq.technology == 0)
      #expect(!bindings.contains { $0.system.system == Plugh.systemID })
    }
  }

  @Test func nativeStationWorldRetainsChosenPosesWithoutMintingDockingAuthority() throws {
    let owner = UUID()
    let world = try NativeStationWorld(owner: owner)
    #expect(world.valid && world.ledger.world == owner && world.ledger.records.count == 372)
    #expect(world.ledger.currentDock == nil && world.ledger.nextDockSequence == 1)
    #expect(world.ledger.records.allSatisfy { $0.binding == nil && $0.tombstone == nil })
    let bytes = try JSONEncoder().encode(world)
    let loaded = try JSONDecoder().decode(NativeStationWorld.self, from: bytes)
    #expect(loaded == world)
    let hq = try #require(world.poses.first { $0.station.definition == "rrs_headquarters" })
    #expect(hq.orientation == loaded.pose(for: hq.station)?.orientation)
    #expect(hq.orientation(at: 0) == hq.orientation(at: 12_345))
    let waystation = try #require(world.poses.first { $0.station.definition == "rescue_station" })
    #expect(waystation.orientation == Basis3())
    #expect(waystation.orientation(at: 0) != waystation.orientation(at: 1))
    #expect(waystation.orientation(at: .nan) == nil)
  }

  @Test func savedDescriptorsAndAlteredPosesCannotReplaceTheCompiledSourceBinding() throws {
    let owner = UUID()
    let world = try NativeStationWorld(owner: owner)
    let record = try #require(world.ledger.records.first)
    #expect(NativeStationSource.authentic(record, owner: owner))
    #expect(!NativeStationSource.authentic(record, owner: UUID()))
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(world)) as? [String: Any])
    var poses = try #require(object["poses"] as? [[String: Any]])
    var position = try #require(poses[0]["position"] as? [String: Any])
    position["x"] = 0
    poses[0]["position"] = position
    object["poses"] = poses
    let forged = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: NativeStationRuntimeError.self) {
      _ = try JSONDecoder().decode(NativeStationWorld.self, from: forged)
    }
    object["poses"] = Array(repeating: poses[0], count: 373)
    let oversized = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: NativeStationRuntimeError.self) {
      _ = try JSONDecoder().decode(NativeStationWorld.self, from: oversized)
    }
  }

  @Test func stationBoardHourUsesOnlyTheExplicitNativePersistentCalendar() {
    #expect(NativeStationSource.boardHour(calendarSeconds: 0) == 0)
    #expect(NativeStationSource.boardHour(calendarSeconds: 3599.9) == 0)
    #expect(NativeStationSource.boardHour(calendarSeconds: 3600) == 1)
    #expect(NativeStationSource.boardHour(calendarSeconds: 7201) == 2)
    #expect(NativeStationSource.boardHour(calendarSeconds: -1) == nil)
    #expect(NativeStationSource.boardHour(calendarSeconds: .infinity) == nil)
    #expect(NativeStationSource.boardHour(calendarSeconds: .nan) == nil)
    #expect(NativeStationSource.boardHour(calendarSeconds: .greatestFiniteMagnitude) == nil)
  }

  @Test func actualPopulationKeepsOriginalMainAndSeparateWaystationAndHeadquarters() throws {
    var game = try NativeStationTestFixture.launched()
    try verifyNativePopulation(&game)
  }

  @Test func populationCapacityRefusalDoesNotAllocateOrPublishPartialStations() throws {
    var game = Game(executive: false)
    try verifyNativePopulationCapacity(&game)
  }

  @Test(arguments: NativeStationGeometry.Kind.allCases)
  func actualNativeEntryCommitsSelectedStationAndLaunchesFromItsOwnExit(
    kind: NativeStationGeometry.Kind
  ) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativeStationTestFixture.approach(kind: kind)
    try await verifyNativeEntryAndExit(&game, kind: kind, storage: storage)
  }

  @Test(arguments: ["speed", "facing", "aperture", "nonfinite"])
  func unsafeActualApproachCannotIssueADockingReceipt(reason: String) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativeStationTestFixture.approach(kind: .headquarters)
    try await verifyUnsafeNativeApproach(&game, reason: reason, storage: storage)
  }

  @Test func booleanDockAndPureLedgerReceiptCannotMintNativeServiceEvidence() throws {
    var game = try NativeStationTestFixture.launched()
    try verifyUnprovedDocking(&game)
  }

  @Test func originalMainArrivalRequiresItsActualNativeDoorwayCrossing() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativeStationTestFixture.launched()
    try await verifyOriginalMainArrival(&game, storage: storage)
  }
}

/// Shared fixture setup preserves every body's system position and model orientation.
/// Tests still cross the actual doorway through GameRuntime.advance; setup mints no receipt.
enum NativeStationTestFixture {
  static func launched() throws -> Game {
    var game = Game(executive: false)
    game.commander.system = 237
    game.screen = .status
    game.launch()
    guard !game.docked, game.commander.nativeStationStateValid,
      game.bodies.filter({ $0.nativeStationIdentity != nil }).count == 2
    else { throw NativeStationRuntimeError.invalidState }
    return game
  }

  static func approach(kind: NativeStationGeometry.Kind) throws -> Game {
    var game = try launched()
    guard let world = game.commander.nativeStations,
      let body = game.bodies.first(where: {
        $0.nativeStationIdentity?.definition == kind.sourceDefinition
      }), let identity = body.nativeStationIdentity,
      let saved = world.pose(for: identity),
      let orientation = saved.orientation(at: game.commander.flightSimulation.physicalTime)
    else { throw NativeStationRuntimeError.invalidState }
    let geometry = kind == .waystation ? NativeStationGeometry.waystation : .headquarters
    let port = geometry.docking
    var pose = ShipPose()
    pose.position = saved.position + orientation.apply(port.center + port.outward)
    pose.orientation.y = orientation.apply(port.up)
    pose.orientation.z = orientation.apply(port.outward) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    reframe(&game, to: pose)
    game.speed = 2
    return game
  }

  static func reframe(_ game: inout Game, to pose: ShipPose) {
    let previous = game.commander.flightSimulation.pose
    for index in game.bodies.indices {
      let point = previous.systemPoint(game.bodies[index].position)
      let orientation = game.bodies[index].orientation.transformed(by: previous.orientation)
      game.bodies[index].position = pose.shipPoint(point)
      game.bodies[index].orientation = orientation.relative(to: pose.orientation)
    }
    for index in game.celestials.indices {
      game.celestials[index].position = pose.shipPoint(
        previous.systemPoint(game.celestials[index].position))
    }
    game.commander.flightSimulation.pose = pose
  }
}

struct NativeStationTestStorage {
  let root: URL
  var directory: URL { root.appendingPathComponent("save", isDirectory: true) }
  var url: URL { directory.appendingPathComponent("commander.json") }
  var backup: URL { root.appendingPathComponent("backup", isDirectory: true) }
  init() throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "native-station-" + UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }
  func blockWriter() throws {
    try FileManager.default.moveItem(at: directory, to: backup)
    try Data("blocked save directory".utf8).write(to: directory)
  }
  func restoreWriter() throws {
    try FileManager.default.removeItem(at: directory)
    try FileManager.default.moveItem(at: backup, to: directory)
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
}

private func verifyNativePopulation(_ game: inout Game) throws {
  let world = try #require(game.commander.nativeStations)
  let main = try #require(game.bodies.first { $0.id == 0 })
  #expect(main.nativeStationIdentity == nil && main.hull == .station)
  #expect(main.physical?.identity == game.commander.flightSimulation.anchors?.station.identity)
  #expect(main.physical?.identity.entity == 1)
  let stations = game.bodies.filter { $0.nativeStationIdentity != nil }
  #expect(stations.count == 2)
  #expect(Set(stations.compactMap { $0.physical?.identity }).count == 2)
  for station in stations {
    let identity = try #require(station.nativeStationIdentity)
    let source = try #require(NativeStationSource.binding(for: identity))
    #expect(identity.world == game.commander.equipmentOwnerID)
    #expect(game.nativeStationBodyIsCurrent(station))
    #expect(station.energy == source.maximumEnergy && station.rotationRate == source.rotationRate)
    #expect(game.gameplayMesh(for: station).vertices == source.geometry.mesh.vertices)
    #expect(
      game.commander.flightSimulation.pose.systemPoint(station.position)
        == world.pose(for: identity)?.position)
  }
  let commander = game.commander
  let bodies = game.bodies
  let nextBodyID = game.nextBodyID
  try game.populateNativeStations()
  #expect(game.commander == commander && game.bodies == bodies && game.nextBodyID == nextBodyID)
  #expect(world.ledger.currentDock == nil && world.currentMainDock == nil)
  #expect(world.ledger.records.count == 372 && world.mainStations.count == 1)
}

private func verifyNativePopulationCapacity(_ game: inout Game) throws {
  game.commander.system = 237
  try game.activateNativeStationWorld()
  game.commander.flightSimulation.enter(game.systemIdentity, arriving: false)
  game.docked = false
  game.bodies = (0..<128).map {
    SpaceBody(id: $0 + 100, hull: .asteroid, position: .init(Double($0) * 1000, 100000, 100000))
  }
  let commander = game.commander
  let bodies = game.bodies
  let cursor = game.nextBodyID
  #expect(throws: NativeStationRuntimeError.capacity) { try game.populateNativeStations() }
  #expect(game.commander == commander && game.bodies == bodies && game.nextBodyID == cursor)
  #expect(game.commander.nativeStations?.ledger.records.allSatisfy { $0.binding == nil } == true)
}

private func verifyNativeEntryAndExit(
  _ game: inout Game, kind: NativeStationGeometry.Kind, storage: NativeStationTestStorage
) async throws {
  let station = try #require(
    game.bodies.first {
      $0.nativeStationIdentity?.definition == kind.sourceDefinition
    })
  let identity = try #require(station.nativeStationIdentity)
  let actor = try #require(station.physical?.identity)
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  game = await runtime.advance(delta: 0.1)
  #expect(game.docked && !game.dockedAtMainStation && !game.paused)
  let receipt = try #require(game.commander.nativeStations?.ledger.currentDock)
  #expect(receipt.station == identity)
  #expect(receipt.dockingBinding == .init(actor: actor, bodyID: station.id))
  #expect(receipt.sequence == 1 && receipt.commanderOwner == identity.world)
  #expect(game.nativeStationDockEvidenceIsCurrent && game.nativeStationBoardContext != nil)
  let (disk, _) = try ScriptSaveStore.read(Data(contentsOf: storage.url), from: storage.url)
  #expect(disk.nativeStations?.ledger.currentDock == receipt)
  let calendar = game.commander.scriptState.calendarSeconds
  await runtime.key(" ")
  game = await runtime.snapshot()
  #expect(!game.docked && !game.paused)
  #expect(game.commander.nativeStations?.ledger.currentDock == nil)
  #expect(game.commander.nativeStations?.ledger.nextDockSequence == 2)
  #expect(game.commander.scriptState.calendarSeconds == calendar + 600)
  let source = try #require(NativeStationSource.binding(for: identity))
  let saved = try #require(game.commander.nativeStations?.pose(for: identity))
  let orientation = try #require(
    saved.orientation(at: game.commander.flightSimulation.physicalTime))
  let exit = try #require(source.geometry.exit(for: game.commander.playerMesh))
  #expect(
    (game.commander.flightSimulation.pose.position
      - (saved.position + orientation.apply(exit.center))).length < 1e-8)
  #expect(game.nativeStationBoardContext == nil)
  #expect(game.bodies.first { $0.id == 0 }?.nativeStationIdentity == nil)
}

private func verifyUnsafeNativeApproach(
  _ game: inout Game, reason: String, storage: NativeStationTestStorage
) async throws {
  switch reason {
  case "speed": game.speed = 8
  case "facing":
    var pose = game.commander.flightSimulation.pose
    pose.orientation.rotate(pitch: 0, roll: 0, yaw: .pi)
    NativeStationTestFixture.reframe(&game, to: pose)
  case "aperture":
    var pose = game.commander.flightSimulation.pose
    pose.position = pose.position + pose.orientation.x * 125
    NativeStationTestFixture.reframe(&game, to: pose)
  case "nonfinite": game.commander.flightSimulation.pose.position.x = .nan
  default: throw NativeStationRuntimeError.invalidState
  }
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  game = await runtime.advance(delta: 0.1)
  #expect(!game.docked)
  #expect(game.commander.nativeStations?.ledger.currentDock == nil)
  #expect(game.commander.nativeStations?.ledger.nextDockSequence == 1)
  #expect(game.nativeStationBoardContext == nil && !game.nativeStationDockEvidenceIsCurrent)
}

private func verifyUnprovedDocking(_ game: inout Game) throws {
  let station = try #require(game.bodies.first { $0.nativeStationIdentity != nil })
  let identity = try #require(station.nativeStationIdentity)
  let actor = try #require(station.physical?.identity)
  let owner = game.commander.equipmentOwnerID
  game.dock(atMainStation: false)
  #expect(game.commander.nativeStations?.ledger.currentDock == nil)
  try game.commander.nativeStations?.ledger.recordDock(
    at: identity, binding: .init(actor: actor, bodyID: station.id),
    commanderOwner: owner)
  game.scriptDurabilityAvailable = true
  #expect(game.commander.nativeStationStateValid)
  #expect(game.nativeStationBoardContext == nil && game.nativeStationEventFacts == nil)
  game.invalidateNativeStationAuthority()
  #expect(game.nativeStationBoardContext == nil && !game.nativeStationDockEvidenceIsCurrent)
  let commander = game.commander
  game.launch()
  #expect(game.docked && game.commander == commander)
}

private func verifyOriginalMainArrival(
  _ game: inout Game, storage: NativeStationTestStorage
) async throws {
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
  game = await runtime.advance(delta: 0.1)
  #expect(game.docked && game.dockedAtMainStation)
  let receipt = try #require(game.commander.nativeStations?.currentMainDock)
  #expect(receipt.station.system == game.systemIdentity && receipt.actor.entity == 1)
  #expect(
    receipt.station.resource == Game.worldResourceIdentity("main-station-v1:main-orbital:0:237"))
  #expect(game.commander.nativeStations?.ledger.currentDock == nil)
  #expect(game.commander.nativeStations?.ledger.records.count == 372)
  #expect(game.nativeMainStationDockEvidenceIsCurrent)
  let context = try #require(game.nativeMainStationArrivalContext(for: receipt.station))
  #expect(game.acceptsNativeMainStationArrivalContext(context))
  game.invalidateNativeStationAuthority()
  #expect(!game.acceptsNativeMainStationArrivalContext(context))
}
