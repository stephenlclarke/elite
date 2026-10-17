import Foundation
import Testing

@testable import EliteCore

enum NativePeopleTestFixture {
  static func disabled(large: Bool = false, seed: UInt64 = 0) throws -> Game {
    let id: String
    if large {
      id = try #require(
        ShipCatalogue.all.sorted(by: { $0.id < $1.id }).first {
          $0.game != nil && EMPState.hasSupportedCrew($0)
            && ((try? ShipAccommodationProfile(ship: $0).operatingCrew) ?? 0) > 30
        }?.id)
    } else {
      id = "SH023"
    }
    var game = try empFixture(catalogue: id)
    game.bodies[0].physical?.velocity = .init(0, 0, 0)
    game.bodies[0].physical?.angularVelocity = .init(0, 0, 0)
    game.bodies[0].rotationRate = 0
    game.seedScriptTrial(seed)
    try #require(game.fireEMPPirateBlaster())
    return game
  }
  static func source(_ game: Game) throws -> ActorIdentity {
    try #require(game.commander.savedEMPState?.records.keys.first)
  }
  static func withinWindow() throws -> Game {
    let game = try disabled(large: true)
    let record = try #require(game.commander.savedEMPState?.records[try source(game)])
    try #require(record.crewAboard > 0)
    try #require(game.commander.flightSimulation.physicalTime < record.crewDeadline!)
    return game
  }
  static func aimCutter(_ game: inout Game) throws {
    let source = try source(game)
    let index = try #require(game.bodies.firstIndex { $0.physical?.empSource == source })
    let catalogue = try #require(game.bodies[index].physical?.catalogueShipID)
    let profile = try #require(SalvageCatalogue.empProfile(catalogueShipID: catalogue))
    let section = try #require(profile.sections.first { $0.kind == .cargo })
    let forward = section.normal.unit * -1
    let cardinal = abs(forward.y) < 0.8 ? Vector3(0, 1, 0) : .init(1, 0, 0)
    var frame = Basis3()
    frame.z = forward
    frame.x = cardinal.cross(forward).unit
    frame.y = forward.cross(frame.x).unit
    let orientation = frame.transposed
    game.bodies[index].orientation = orientation
    game.bodies[index].position = Vector3(0, 0, 200) - orientation.apply(section.localPosition)
    game.bodies[index].rotation = 0
    game.bodies[index].rotationRate = 0
    game.bodies[index].physical?.velocity = .init(0, 0, 0)
    game.bodies[index].physical?.angularVelocity = .init(0, 0, 0)
    game.selectedFlightTool = .salvageCutter
    game.speed = 0
    game.screen = .front
    try #require(game.persistEMPState())
    let hit = try #require(
      GameplayRaycast.nearest(
        origin: .init(0, 0, 0), direction: .init(0, 0, 1),
        maxDistance: 300, bodies: game.bodies, meshOverrides: game.gameplayMeshOverrides))
    try #require(hit.target == .body(game.bodies[index].id))
  }
  static func podApproach() throws -> Game {
    var game = try disabled()
    for _ in 0..<15 { game.tick(delta: 0.1) }
    let index = try #require(game.bodies.firstIndex { $0.physical?.empCrewPod != nil })
    game.bodies[index].position = .init(0, -45, 500)
    game.bodies[index].physical?.velocity = .init(0, 0, 0)
    game.bodies[index].physical?.angularVelocity = .init(0, 0, 0)
    game.bodies[index].physical?.canonicalSpin = true
    game.bodies[index].rotationRate = 0
    game.speed = 0
    game.workTargetFilter = .salvage
    try #require(game.persistEMPState())
    return game
  }
  static func capture(_ runtime: GameRuntime) async -> Game {
    var controls = Controls()
    controls.fire = true
    await runtime.setControls(controls)
    let game = await runtime.advance(delta: 0.05)
    await runtime.setControls(Controls())
    return game
  }
  static func station(_ game: inout Game) throws {
    guard !game.docked else { return }
    // An unproved dock grants no service. Native launch loads the original station;
    // the following genuine doorway crossing must supply the only transfer authority.
    game.dock()
    try #require(game.commander.nativeStations?.currentMainDock == nil)
    game.launch()
    try #require(!game.docked)
    try ScriptFinanceTestFixture.approachMain(&game)
  }
  static func review(_ runtime: GameRuntime, row: NativePeopleStationRow) async throws
    -> ScriptPagePresentation
  {
    await runtime.key("contracts-open")
    let game = await runtime.snapshot()
    let index = try #require(game.contractBoard.rows.firstIndex { $0.people == row })
    for _ in 0..<abs(index - game.contractBoard.selection) {
      await runtime.key(index < game.contractBoard.selection ? "up" : "down")
    }
    let page = await runtime.snapshot().scriptPagePresentation
    await runtime.scriptPageKey("return", expected: page)
    try #require(await runtime.snapshot().contractBoard.peopleQuote?.row == row)
    return await runtime.snapshot().scriptPagePresentation
  }

  static func capturedRuntime(storage: NativeStationTestStorage, count: Int = 2) async throws
    -> GameRuntime
  {
    var game = try withinWindow()
    game.commander.cargo[0] = game.commander.standardCargoCapacity - count
    try aimCutter(&game)
    let collector = GameRuntime(game: game, saveURL: storage.url)
    game = await capture(collector)
    try #require(game.commander.nativeCaptiveCount == count)
    try station(&game)
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    try await ScriptFinanceTestFixture.enterMain(runtime)
    return runtime
  }

  static func confirm(_ runtime: GameRuntime, row: NativePeopleStationRow) async throws {
    let page = try await review(runtime, row: row)
    await runtime.scriptPageKey("right", expected: page)
    await runtime.scriptPageKey("return", expected: page)
  }
}

struct NativePeopleCensusTests {
  @Test func actualPartialCaptureThenOutOfOrderEjectionPreservesOriginalOrdinals() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativePeopleTestFixture.disabled(large: true, seed: 31)
    let source = try NativePeopleTestFixture.source(game)
    let initial = try #require(game.commander.savedEMPState?.records[source])
    let schedule = try #require(initial.disableEpisodes.last)
    #expect(schedule.ejections[0].delay > 20 && schedule.ejections[7].delay == 0.5)
    game.commander.cargo[0] = game.commander.standardCargoCapacity - 2
    try NativePeopleTestFixture.aimCutter(&game)
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    let captured = await NativePeopleTestFixture.capture(runtime)
    #expect(
      captured.commander.nativePeople?.heldCaptives.map { $0.person.emp.ordinal }.sorted() == [
        0, 1,
      ])
    for _ in 0..<10 { _ = await runtime.advance(delta: 0.1) }
    let after = await runtime.snapshot()
    let record = try #require(after.commander.savedEMPState?.records[source])
    let podIndex = try #require(record.podIndex(for: 7))
    #expect(podIndex != 7 && record.crewOutcome(ordinal: 7) == .occupiedPod)
    #expect(
      record.crewOutcome(ordinal: 0) == .captured && record.crewOutcome(ordinal: 1) == .captured)
    #expect(record.crewOutcome(ordinal: 2) == .aboard)
    #expect(record.valid && after.commander.valid)
    #expect(
      record.crewAboard + record.pods.count + record.capturedCrewCount + record.lostCrewCount
        == initial.crewTotal)
    let snapshot = record.disableEpisodes
    try await runtime.save(to: storage.url)
    let reader = GameRuntime()
    try await reader.load(from: storage.url, persistMigrations: false)
    let restored = await reader.snapshot()
    #expect(restored.commander.savedEMPState?.records[source]?.disableEpisodes == snapshot)
    #expect(restored.commander.savedEMPState?.records[source]?.podIndex(for: 7) == podIndex)
    #expect(restored.commander.nativePeople == after.commander.nativePeople)
  }

  @Test func explicitHullDeathRecordsOnlyStillAboardOriginalIDsAfterInterleavedDischarges()
    async throws
  {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativePeopleTestFixture.disabled(large: true, seed: 31)
    game.commander.cargo[0] = game.commander.standardCargoCapacity - 1
    try NativePeopleTestFixture.aimCutter(&game)
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    _ = await NativePeopleTestFixture.capture(runtime)
    for _ in 0..<10 { _ = await runtime.advance(delta: 0.1) }
    game = await runtime.snapshot()
    let source = try NativePeopleTestFixture.source(game)
    let original = try #require(game.commander.savedEMPState?.records[source])
    let aboard = original.aboardOrdinals
    let index = try #require(game.bodies.firstIndex { $0.physical?.empSource == source })
    game.bodies[index].energy = 0
    try #require(game.registerEMPHullDeaths())
    let terminal = try #require(game.commander.savedEMPState?.records[source])
    #expect(terminal.deceasedOrdinals == aboard && terminal.lostCrewCount == aboard.count)
    #expect(!terminal.deceasedOrdinals.contains(0) && !terminal.deceasedOrdinals.contains(7))
    #expect(
      terminal.crewOutcome(ordinal: 0) == .captured
        && terminal.crewOutcome(ordinal: 7) == .occupiedPod)
    #expect(terminal.valid)
  }

  @Test func thirtySecondCutoffDoesNotTransferCrewOrExtendOnRepeatEMP() throws {
    var game = try NativePeopleTestFixture.disabled(large: true)
    let source = try NativePeopleTestFixture.source(game)
    let original = try #require(game.commander.savedEMPState?.records[source])
    #expect(original.crewDeadline == original.disableIncident.physicalTime + 30)
    let counts = original.crewTotal
    #expect(!game.fireEMPPirateBlaster())
    #expect(game.commander.savedEMPState?.records[source]?.crewDeadline == original.crewDeadline)
    for _ in 0..<301 { game.tick(delta: 0.1) }
    let after = try #require(game.commander.savedEMPState?.records[source])
    #expect(
      after.crewAboard + after.pods.count + after.capturedCrewCount + after.lostCrewCount == counts)
    #expect(after.crewCaptures.isEmpty && game.commander.nativeCaptiveCount == 0)
    let pods = after.pods.count
    for _ in 0..<20 { game.tick(delta: 0.1) }
    #expect(game.commander.savedEMPState?.records[source]?.pods.count == pods)
    #expect(game.commander.savedEMPState?.records[source]?.crewAboard == after.crewAboard)
  }
  @Test(arguments: [-0.0001, 0.0, 0.0001])
  func eligibilityUsesTheOriginalExactCutoff(offset: Double) throws {
    var game = try NativePeopleTestFixture.disabled(large: true)
    let source = try NativePeopleTestFixture.source(game)
    let deadline = try #require(game.commander.savedEMPState?.records[source]?.crewDeadline)
    game.commander.flightSimulation.advancePhysicalTime(
      deadline + offset - game.commander.flightSimulation.physicalTime)
    let body = try #require(game.bodies.first { $0.physical?.empSource == source })
    let context = try #require(game.gameplayContext())
    #expect(game.nativeCrewCaptureAvailable(body, context: context) == (offset < 0))
    #expect(game.commander.nativePeople == nil && game.commander.cargo[3] == 0)
  }
}
