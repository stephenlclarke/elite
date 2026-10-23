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

  @Test func actualWeaponRayIntersectsTheSourceStructureOutsideTheOriginalStationMesh() throws {
    var game = try NativeStationTestFixture.launched()
    try verifyNativeStationWeaponMesh(&game)
  }

  @Test func originalMainStationRetainsItsNativeLaserImmunity() throws {
    var game = try NativeStationTestFixture.launched()
    try verifyOriginalMainImmunity(&game)
  }

  @Test func actualXYZZYMissileVolleyDestroysHeadquartersAndRetainsItsTombstoneAcrossLoad()
    async throws
  {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativeStationTestFixture.headquartersAttack()
    try await verifyNativeHeadquartersDestruction(&game, storage: storage)
  }

  @Test(arguments: [false, true])
  func actualWeaponDamageRechargesDuringBothManualAndGuidedPhysicalMovement(guided: Bool)
    throws
  {
    var game = try NativeStationTestFixture.headquartersAttack()
    try verifyNativeStationRecharge(&game, guided: guided)
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

  @Test(arguments: ["speed", "facing", "aperture", "nonfinite", "stationPose"])
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

  @Test(arguments: [0.1, 0.01, 0.001])
  func originalMainArrivalRequiresItsActualNativeDoorwayCrossing(delta: Double) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativeStationTestFixture.launched()
    try await verifyOriginalMainArrival(&game, storage: storage, delta: delta)
  }
}

/// Shared fixture setup preserves every body's system position and model orientation.
/// Tests still cross the actual doorway through GameRuntime.advance; setup mints no receipt.
enum NativeStationTestFixture {
  static func launched() throws -> Game {
    var game = Game(executive: false)
    // Current G04-S149 declares both station kinds; G01-S237 declares only headquarters.
    game.commander.galaxy = 3
    game.commander.system = 149
    game.systems = Universe.systemsIncludingPlugh(number: game.commander.galaxy)
    let sources = NativeStationSource.bindings.filter { $0.system == game.systemIdentity }
    guard sources.count == 2,
      NativeStationGeometry.Kind.allCases.allSatisfy({ kind in
        sources.filter { $0.kind == kind }.count == 1
      })
    else { throw NativeStationRuntimeError.invalidSource }
    game.screen = .status
    game.launch()
    guard !game.docked, game.commander.nativeStationStateValid,
      let owner = game.commander.equipmentOwnerID
    else { throw NativeStationRuntimeError.invalidState }
    let expected = Set(sources.map { $0.identity(world: owner) })
    let actual = game.bodies.compactMap(\.nativeStationIdentity)
    guard actual.count == expected.count, Set(actual) == expected else {
      throw NativeStationRuntimeError.invalidState
    }
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

  static func headquartersAttack() throws -> Game {
    var game = try launched()
    game.enableXYZzy()
    // Actual player preferences: keep the selected offensive lock and avoid friendly ECM.
    game.secretKey("b")
    game.secretKey("e")
    guard game.commander.xyzzyActive, game.commander.unlimitedMissiles,
      let body = game.bodies.first(where: {
        $0.nativeStationIdentity?.definition
          == NativeStationGeometry.Kind.headquarters.sourceDefinition
      }), let identity = body.nativeStationIdentity,
      let saved = game.commander.nativeStations?.pose(for: identity),
      let orientation = saved.orientation(at: game.commander.flightSimulation.physicalTime)
    else { throw NativeStationRuntimeError.invalidState }
    let geometry = NativeStationGeometry.headquarters
    let face = geometry.mesh.faces[0].map { geometry.mesh.vertices[$0] }
    let center = face.reduce(Vector3(0, 0, 0), +) * (1 / Double(face.count))
    let outward = (face[1] - face[0]).cross(face[2] - face[0]).unit
    let radius = game.commander.playerMesh.vertices.map(\.length).max() ?? .infinity
    let separation = geometry.bounds.support(outward) - center.dot(outward) + radius + 1000
    var pose = ShipPose()
    pose.position = saved.position + orientation.apply(center + outward * separation)
    pose.orientation.z = orientation.apply(outward) * -1
    let up = abs(pose.orientation.z.y) < 0.9 ? Vector3(0, 1, 0) : .init(1, 0, 0)
    pose.orientation.y = (up - pose.orientation.z * up.dot(pose.orientation.z)).unit
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    guard pose.orientation.validRotation, pose.position.finite else {
      throw NativeStationRuntimeError.invalidState
    }
    reframe(&game, to: pose)
    game.speed = 0
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
    let saved = try #require(world.pose(for: identity))
    #expect(
      (game.commander.flightSimulation.pose.systemPoint(station.position)
        - saved.position).length < 1e-8)
  }
  let commander = game.commander
  let bodies = game.bodies
  let nextBodyID = game.nextBodyID
  try game.populateNativeStations()
  #expect(game.commander == commander && game.bodies == bodies && game.nextBodyID == nextBodyID)
  #expect(world.ledger.currentDock == nil && world.currentMainDock == nil)
  #expect(world.ledger.records.count == 382 && world.mainStations.count == 1)
}

private func verifyNativePopulationCapacity(_ game: inout Game) throws {
  game.commander.system = 237
  try game.activateNativeStationWorld()
  game.commander.flightSimulation.enter(game.systemIdentity, arriving: false)
  game.docked = false
  game.bodies = (0..<128).map {
    SpaceBody(id: $0 + 100, hull: .asteroid, position: .init(Double($0) * 1000, 100000, 100000))
  }
  game.nextBodyID = 228
  game.ensurePhysicalActors()
  #expect(game.bodies.allSatisfy { $0.physical != nil })
  let commander = game.commander
  let bodies = game.bodies
  let cursor = game.nextBodyID
  #expect(throws: NativeStationRuntimeError.capacity) { try game.populateNativeStations() }
  #expect(game.commander == commander && game.bodies == bodies && game.nextBodyID == cursor)
  #expect(game.commander.nativeStations?.ledger.records.allSatisfy { $0.binding == nil } == true)
}

private func verifyNativeStationWeaponMesh(_ game: inout Game) throws {
  let body = try #require(
    game.bodies.first {
      $0.nativeStationIdentity?.definition == NativeStationGeometry.Kind.waystation.sourceDefinition
    })
  let mesh = NativeStationGeometry.waystation.mesh
  let face = mesh.faces[0]
  let points = face.map { mesh.vertices[$0] }
  let center = points.reduce(Vector3(0, 0, 0), +) * (1 / Double(points.count))
  let outward = (points[1] - points[0]).cross(points[2] - points[0]).unit
  // This actual source triangle lies at x > 90, outside the original orbital mesh.
  #expect(center.x > 90 && outward.length > 0)
  let origin = body.position + body.modelVector(center + outward * 1000)
  let direction = body.modelVector(outward * -1)
  let contact = try #require(
    try game.nearestMissionCollision(
      from: origin, direction: direction, range: 2000, radius: 0, includePlayer: false))
  #expect(contact.hit.target == .body(body.id))
  #expect(game.gameplayMeshOverrides[body.id]?.vertices == mesh.vertices)
}

private func verifyOriginalMainImmunity(_ game: inout Game) throws {
  game.enableXYZzy()
  var pose = ShipPose()
  pose.position = .init(0, 0, -1000)
  NativeStationTestFixture.reframe(&game, to: pose)
  game.speed = 0
  let main = try #require(game.bodies.first { $0.id == 0 })
  let contact = try #require(
    try game.nearestMissionCollision(
      from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000, radius: 0,
      includePlayer: false))
  #expect(contact.hit.target == .body(main.id))
  game.fireLaser()
  #expect(game.laserFlash > 0 && game.bodies.first { $0.id == 0 }?.energy == main.energy)
  for _ in 0..<16 where game.weaponsTargetID != main.id { game.key("tab") }
  #expect(game.weaponsTargetID == main.id)
  game.key("q")
  game.key("t")
  let flight = game.commander.flightSimulation
  let fired = game.fireMissile()
  #expect(!fired)
  #expect(game.commander.flightSimulation == flight)
}

private func verifyNativeStationRecharge(_ game: inout Game, guided: Bool) throws {
  let hq = try #require(
    game.bodies.first {
      $0.nativeStationIdentity?.definition
        == NativeStationGeometry.Kind.headquarters.sourceDefinition
    })
  game.fireLaser()
  #expect(game.bodies.first { $0.id == hq.id }?.energy == hq.energy - LaserKind.naval.damage)
  if guided {
    let rock = try #require(game.miningFields.first?.rocks.first)
    var pose = ShipPose()
    pose.position = rock.position - Vector3(0, 0, 500)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.activateNearbyMiningFields()
    game.key("f")
    #expect(game.workTargetFilter == .mining)
    for _ in 0..<64 where game.workGuidance == nil { game.key("tab") }
    #expect(game.workGuidance != nil)
  }
  let clock = game.commander.flightSimulation.physicalTime
  game.tick(delta: 0.1)
  #expect(game.commander.flightSimulation.physicalTime == clock + 0.1)
  #expect(game.bodies.first { $0.id == hq.id }?.energy == hq.energy - LaserKind.naval.damage + 10)
  #expect(!game.docked && !game.paused)
}

private func verifyNativeHeadquartersDestruction(
  _ game: inout Game, storage: NativeStationTestStorage
) async throws {
  let hq = try #require(
    game.bodies.first {
      $0.nativeStationIdentity?.definition
        == NativeStationGeometry.Kind.headquarters.sourceDefinition
    })
  let identity = try #require(hq.nativeStationIdentity)
  let actor = try #require(hq.physical?.identity)
  #expect(hq.energy == 25000 && !hq.ecmEnabled)
  #expect(game.commander.credits == Commander.xyzzyStartingCredits && !game.commander.unlimitedCash)
  let contact = try #require(
    try game.nearestMissionCollision(
      from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000, radius: 0,
      includePlayer: false))
  #expect(contact.hit.target == .body(hq.id))
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  for _ in 0..<16 where game.weaponsTargetID != hq.id {
    await runtime.key("tab")
    game = await runtime.snapshot()
  }
  #expect(game.weaponsTargetID == hq.id)
  await runtime.key("q")
  var controls = Controls()
  controls.fire = true
  await runtime.setControls(controls)
  game = await runtime.advance(delta: 0.1)
  #expect(game.bodies.first { $0.id == hq.id }?.energy == hq.energy - LaserKind.naval.damage + 10)
  await runtime.setControls(Controls())
  var launches = 0
  for frame in 0..<5000
  where game.bodies.contains(where: { $0.id == hq.id })
    && game.screen != .gameOver && !game.paused
  {
    if frame % 11 == 0 {
      let cursor = game.commander.flightSimulation.nextSpawn
      await runtime.key("t")
      await runtime.key("m")
      game = await runtime.snapshot()
      if game.commander.flightSimulation.nextSpawn > cursor { launches += 1 }
    }
    game = await runtime.advance(delta: 0.1)
  }
  #expect(launches > 100 && !game.paused && game.screen != .gameOver)
  #expect(!game.bodies.contains { $0.nativeStationIdentity == identity })
  let world = try #require(game.commander.nativeStations)
  let record = try #require(world.ledger.records.first { $0.identity == identity })
  let tombstone = try #require(record.tombstone)
  #expect(tombstone.destroyedBinding == .init(actor: actor, bodyID: hq.id))
  #expect(record.binding == nil && record.revision == 2)
  #expect(world.pose(for: identity)?.energy == 0 && world.ledger.currentDock == nil)
  try await runtime.save(to: storage.url)
  let (disk, _) = try ScriptSaveStore.read(Data(contentsOf: storage.url), from: storage.url)
  #expect(disk.nativeStations?.ledger.records.first { $0.identity == identity } == record)
  try await runtime.load(from: storage.url, persistMigrations: false)
  game = await runtime.advance(delta: 0.01)
  #expect(game.commander.nativeStations?.ledger.records.first { $0.identity == identity } == record)
  #expect(!game.bodies.contains { $0.nativeStationIdentity == identity })
  #expect(game.commander.nativeStations?.poses == disk.nativeStations?.poses)
  #expect(game.commander.nativeStationStateValid)
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
  await runtime.key("0")
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
  case "stationPose":
    let index = try #require(
      game.bodies.firstIndex {
        $0.nativeStationIdentity?.definition
          == NativeStationGeometry.Kind.headquarters.sourceDefinition
      })
    game.bodies[index].position.x += 300
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
  _ game: inout Game, storage: NativeStationTestStorage, delta: Double
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
  for _ in 0..<100 where !game.docked { game = await runtime.advance(delta: delta) }
  #expect(game.docked && game.dockedAtMainStation)
  let receipt = try #require(game.commander.nativeStations?.currentMainDock)
  #expect(receipt.station.system == game.systemIdentity && receipt.actor.entity == 1)
  #expect(
    receipt.station.resource == Game.worldResourceIdentity("main-station-v1:main-orbital:3:149"))
  #expect(game.commander.nativeStations?.ledger.currentDock == nil)
  #expect(game.commander.nativeStations?.ledger.records.count == 372)
  #expect(game.nativeMainStationDockEvidenceIsCurrent)
  let context = try #require(game.nativeMainStationArrivalContext(for: receipt.station))
  #expect(game.acceptsNativeMainStationArrivalContext(context))
  game.invalidateNativeStationAuthority()
  #expect(!game.acceptsNativeMainStationArrivalContext(context))
}
