import Foundation
import Testing

@testable import EliteCore

struct RRSCourierTests {
  @Test func sourceGatesKeepTheStrictHalfBoundary() {
    #expect(RRSCourierContent.eligible(reputation: -10, legal: 50, draw: 0))
    #expect(RRSCourierContent.eligible(reputation: -10, legal: 50, draw: 0.5.nextDown))
    #expect(!RRSCourierContent.eligible(reputation: -11, legal: 50, draw: 0))
    #expect(!RRSCourierContent.eligible(reputation: -10, legal: 51, draw: 0))
    #expect(!RRSCourierContent.eligible(reputation: 0, legal: 0, draw: 0.5))
    #expect(!RRSCourierContent.eligible(reputation: 0, legal: 0, draw: 1))
    #expect(!RRSCourierContent.eligible(reputation: 0, legal: 0, draw: .nan))
    #expect(!RRSCourierContent.eligible(reputation: 0, legal: 0, draw: -.infinity))
  }

  @Test(arguments: NativeStationGeometry.Kind.allCases)
  func actualStationBoardCachesAndDeclinesWithoutPacketOrResourceEffects(
    kind: NativeStationGeometry.Kind
  ) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try rrsApproach(kind)
    try await verifyRRSBoard(&game, storage: storage)
  }

  @Test(arguments: NativeStationGeometry.Kind.allCases)
  func actualConfirmAndReloadPreserveFrozenIdentitiesAndZeroFootprintPacket(
    kind: NativeStationGeometry.Kind
  ) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try rrsApproach(kind)
    try await verifyRRSAcceptanceAndRestore(&game, storage: storage)
  }

  @Test(arguments: ["hour", "legal", "epoch", "main-unproved"])
  func staleActualReviewsCannotAccept(reason: String) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try rrsApproach(.waystation)
    try await verifyRRSStaleReview(&game, reason: reason, storage: storage)
  }

  @Test(arguments: ["accept", "decline", "abandon", "debrief"])
  func failedActualWriterConservesWholeCommanderSceneAndPreviousFiles(action: String)
    async throws
  {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try rrsApproach(.headquarters)
    try await verifyRRSWriterFailure(&game, action: action, storage: storage)
  }

  @Test func genuineOriginalMainDoorwayAndDebriefConfirmPayExactlyOnce() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try rrsApproach(.waystation)
    try await verifyRRSDebrief(&game, storage: storage)
  }

  @Test func booleanMainDockCannotMintDeliveryAuthority() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try rrsApproach(.waystation)
    try await verifyRRSBooleanDockRefusal(&game, storage: storage)
  }

  @Test func temporarilyUnprovedMainSuspendsWithoutLosingPacketOrFailing() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try rrsApproach(.waystation)
    try await verifyRRSUnprovedMain(&game, storage: storage)
  }

  @Test(arguments: [false, true])
  func actualSystemOrGalaxyDepartureFailsExactlyOnce(galaxy: Bool) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try rrsApproach(.waystation)
    try await verifyRRSDeparture(&game, galaxy: galaxy, storage: storage)
  }

  @Test func failedAutonomousDepartureWriterKeepsPacketAndRetriesExactlyOnce() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try rrsApproach(.waystation)
    try await verifyRRSDepartureWriterFailure(&game, storage: storage)
  }

  @Test(arguments: [
    "owner", "packet", "origin", "destination", "receipt", "seed", "profile",
    "legal", "reputation", "source", "duplicate", "early-terminal",
  ])
  func decodedLedgerForgeriesCannotValidateAsCommanderState(reason: String) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try rrsApproach(.waystation)
    try await verifyRRSLedgerForgery(&game, reason: reason, storage: storage)
  }

  @Test func actualOriginalMainMissileDestructionFailsWithoutReplacementDelivery() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try rrsApproach(.waystation)
    try await verifyRRSMainDestruction(&game, storage: storage)
  }
}

/// Choose a deterministic simulation-hour fixture before entry; authority still comes only
/// from the existing real swept docking path and its bound save writer.
private func rrsApproach(_ kind: NativeStationGeometry.Kind) throws -> Game {
  var game = try NativeStationTestFixture.approach(kind: kind)
  let station = try #require(
    game.bodies.first {
      $0.nativeStationIdentity?.definition == kind.sourceDefinition
    }?.nativeStationIdentity)
  let hour = try #require(
    (1...128).first {
      let key = RRSCourierContent.boardKey(station, hour: Int64($0))
      return RRSCourierContent.draw(RRSCourierContent.seed(key)) < 0.5
    })
  game.commander.scriptState.calendarSeconds = Double(hour) * 3600
  #expect(game.commander.valid)
  return game
}

private func enterRRS(_ game: inout Game, storage: NativeStationTestStorage) async throws {
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  game = await runtime.advance(delta: 0.1)
  #expect(game.docked && !game.dockedAtMainStation)
  let context = try #require(game.nativeStationBoardContext)
  #expect(game.acceptsNativeStationBoardContext(context))
  await runtime.key("contracts-open")
  game = await runtime.snapshot()
  #expect(game.screen == .contracts && MissionUIAction.contracts.isEnabled(in: game))
  #expect(game.contractBoard.rows.count == 1 && game.contractBoard.rows[0].rrs != nil)
}

private func acceptRRS(_ game: inout Game, storage: NativeStationTestStorage) async throws {
  try await enterRRS(&game, storage: storage)
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  game = await runtime.snapshot()
  let row = try #require(game.contractBoard.selected?.rrs)
  let quote = game.rrsCourierQuote(for: row)
  #expect(quote.allowed)
  try await runtime.confirmRRSCourier(quote)
  game = await runtime.snapshot()
  #expect(game.commander.contracts.rrs?.active?.carriesPacket == true)
}

private func verifyRRSBoard(_ game: inout Game, storage: NativeStationTestStorage) async throws {
  try await enterRRS(&game, storage: storage)
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  let original = game.commander
  let board = try #require(game.commander.contracts.rrs?.boards.values.first)
  let context = try #require(game.nativeStationBoardContext)
  #expect(board.station == context.station && board.hour == context.hour)
  #expect(game.commander.contracts.rrs?.jobs.isEmpty == true)
  await runtime.key("return")
  game = await runtime.snapshot()
  #expect(game.contractBoard.detail && game.contractBoard.action == .back)
  #expect(Display.contractDetailRows(game, width: 800).joined().contains("0 tonnes"))
  await runtime.key("escape")
  await runtime.key("contract-refresh")
  game = await runtime.snapshot()
  let wholeCommanderUnchanged = game.commander == original
  #expect(wholeCommanderUnchanged)
  let row = try #require(game.contractBoard.selected?.rrs)
  try await runtime.declineRRSCourier(game.rrsCourierQuote(for: row))
  game = await runtime.snapshot()
  var expected = original
  expected.contracts.rrs?.boards[board.station.key]?.declined = true
  let onlyDeclineChanged = game.commander == expected
  #expect(onlyDeclineChanged)
  await runtime.key("contract-refresh")
  game = await runtime.snapshot()
  #expect(game.contractBoard.rows.isEmpty && game.commander.contracts.rrs?.active == nil)
}

private func verifyRRSAcceptanceAndRestore(
  _ game: inout Game, storage: NativeStationTestStorage
) async throws {
  try await enterRRS(&game, storage: storage)
  let before = game.commander
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  game = await runtime.snapshot()
  let row = try #require(game.contractBoard.selected?.rrs)
  let quote = game.rrsCourierQuote(for: row)
  await runtime.key("return")
  game = await runtime.snapshot()
  #expect(game.contractBoard.detail && game.contractBoard.rrsQuote?.allowed == true)
  if quote.board?.station.definition == "rrs_headquarters" {
    let button = try #require(
      ContractBoardLayout(width: game.viewportWidth, height: game.viewportHeight)
        .actions.first { $0.0 == .accept }?.1)
    await runtime.scriptPageClick(
      x: button.x + 4, y: button.y + 4,
      expected: game.scriptPagePresentation)
  } else {
    await runtime.key("right")
    await runtime.key("return")
  }
  game = await runtime.snapshot()
  let job = try #require(game.commander.contracts.rrs?.active)
  #expect(job.origin == quote.board?.service.receipt)
  #expect(job.destination == quote.destination?.identity)
  #expect(job.packet == RRSCourierContent.packetID(job.id) && job.carriesPacket)
  #expect(job.origin.station.definition != "main-orbital")
  var expected = before
  expected.contracts.rrs = game.commander.contracts.rrs
  let noResourceOrFlightEffects = game.commander == expected
  #expect(noResourceOrFlightEffects)
  #expect(game.docked && !game.dockedAtMainStation)
  try await expectRRSRefusal(runtime, quote: quote)
  try await runtime.save(to: storage.url)
  game = await runtime.snapshot()
  let accepted = game.commander
  let files = try rrsSaveFiles(storage.directory)
  let restored = GameRuntime(game: Game(executive: false))
  try await restored.load(from: storage.url, persistMigrations: false)
  game = await restored.snapshot()
  let wholeCommanderRestored = game.commander == accepted
  #expect(wholeCommanderRestored)
  #expect(game.commander.contracts.rrs?.active == job)
  #expect(!game.acceptsNativeStationBoardContext(try #require(quote.board)))
  try await expectRRSRefusal(restored, quote: quote)
  #expect(try rrsSaveFiles(storage.directory) == files)
  await restored.key("contracts-open")
  game = await restored.snapshot()
  #expect(game.contractBoard.rows.count == 2)
  #expect(game.contractBoard.rows.allSatisfy { $0.rrs?.canDecline == false })
}

private func verifyRRSStaleReview(
  _ game: inout Game, reason: String, storage: NativeStationTestStorage
) async throws {
  try await enterRRS(&game, storage: storage)
  let row = try #require(game.contractBoard.selected?.rrs)
  let quote = game.rrsCourierQuote(for: row)
  switch reason {
  case "hour": game.commander.scriptState.calendarSeconds += 3600
  case "legal": game.commander.legal = 51
  case "epoch": game.invalidateNativeStationAuthority()
  default: game.commander.nativeStations?.mainObservations = []
  }
  let before = game.commander
  let bodies = game.bodies
  do {
    try game.confirmRRSCourier(quote)
    Issue.record("Stale real RRS review was accepted: \(reason)")
  } catch {}
  let wholeCommanderUnchanged = game.commander == before
  #expect(wholeCommanderUnchanged && game.bodies == bodies)
  #expect(game.commander.contracts.rrs?.active == nil)
}

private func approachRRSMain(_ game: inout Game) throws {
  game.screen = .status
  game.launch()
  #expect(!game.docked)
  let station = try #require(game.bodies.first { $0.id == 0 })
  let old = game.commander.flightSimulation.pose
  var pose = ShipPose()
  pose.position = old.systemPoint(station.entrancePosition + station.entranceNormal * 2)
  pose.orientation.y = old.orientation.apply(station.entranceUp)
  pose.orientation.z = old.orientation.apply(station.entranceNormal) * -1
  pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
  NativeStationTestFixture.reframe(&game, to: pose)
  game.speed = 3
}

private func arriveRRSMain(_ game: inout Game, storage: NativeStationTestStorage) async throws {
  try approachRRSMain(&game)
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  for _ in 0..<100 where !game.docked { game = await runtime.advance(delta: 0.1) }
  #expect(game.docked && game.dockedAtMainStation)
  let active = try #require(game.commander.contracts.rrs?.active)
  #expect(game.nativeMainStationArrivalContext(for: active.destination) != nil)
}

private func verifyRRSDebrief(_ game: inout Game, storage: NativeStationTestStorage) async throws {
  try await acceptRRS(&game, storage: storage)
  let active = try #require(game.commander.contracts.rrs?.active)
  try await arriveRRSMain(&game, storage: storage)
  let before = game.commander
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  game = await runtime.snapshot()
  let quote = game.rrsCourierQuote(for: .debrief(active.id))
  #expect(quote.allowed)
  await runtime.key("contracts-open")
  game = await runtime.snapshot()
  #expect(game.contractBoard.rows.contains { $0.rrs == .debrief(active.id) })
  try await runtime.confirmRRSCourier(quote)
  game = await runtime.snapshot()
  let ledger = try #require(game.commander.contracts.rrs)
  #expect(ledger.active == nil && ledger.completed == 1 && ledger.failed == 0)
  #expect(ledger.reputation == 2 && ledger.jobs[0].terminal?.outcome == .delivered)
  #expect(ledger.jobs[0].terminal?.arrival == quote.arrival?.receipt)
  #expect(!ledger.jobs[0].carriesPacket)
  var expected = before
  expected.contracts.rrs = ledger
  expected.credits += 300
  let onlyDeliveryEffects = game.commander == expected
  #expect(onlyDeliveryEffects)
  let delivered = game.commander
  try await expectRRSRefusal(runtime, quote: quote)
  game = await runtime.advance(delta: 0.1)
  #expect(game.commander.credits == delivered.credits)
  #expect(game.commander.contracts.rrs == delivered.contracts.rrs)
}

private func verifyRRSWriterFailure(
  _ game: inout Game, action: String, storage: NativeStationTestStorage
) async throws {
  if action == "accept" || action == "decline" {
    try await enterRRS(&game, storage: storage)
  } else {
    try await acceptRRS(&game, storage: storage)
    if action == "debrief" { try await arriveRRSMain(&game, storage: storage) }
  }
  let row: RRSCourierRow
  if action == "accept" || action == "decline" {
    row = try #require(game.contractBoard.selected?.rrs)
  } else {
    let id = try #require(game.commander.contracts.rrs?.active?.id)
    row = action == "debrief" ? .debrief(id) : .abandon(id)
  }
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  try await runtime.save(to: storage.url)
  game = await runtime.snapshot()
  let quote = game.rrsCourierQuote(for: row)
  #expect(quote.allowed)
  let before = game.commander
  let bodies = game.bodies
  let cursor = game.nextBodyID
  let files = try rrsSaveFiles(storage.directory)
  try storage.blockWriter()
  var refused = false
  do {
    if action == "decline" {
      try await runtime.declineRRSCourier(quote)
    } else {
      try await runtime.confirmRRSCourier(quote)
    }
  } catch { refused = true }
  #expect(refused)
  game = await runtime.snapshot()
  let wholeCommanderConserved = game.commander == before
  #expect(wholeCommanderConserved && game.bodies == bodies && game.nextBodyID == cursor)
  #expect(try rrsSaveFiles(storage.backup) == files)
  #expect(try Data(contentsOf: storage.directory) == Data("blocked save directory".utf8))
  try storage.restoreWriter()
  if action == "decline" {
    try await runtime.declineRRSCourier(quote)
  } else {
    try await runtime.confirmRRSCourier(quote)
  }
  game = await runtime.snapshot()
  #expect(game.commander != before)
  if action == "abandon" {
    let ledger = try #require(game.commander.contracts.rrs)
    #expect(ledger.active == nil && ledger.failed == 1 && ledger.completed == 0)
    #expect(ledger.reputation == -10 && ledger.jobs[0].terminal?.outcome == .abandoned)
    #expect(game.commander.credits == before.credits)
    try await expectRRSRefusal(runtime, quote: quote)
    game = await runtime.snapshot()
    #expect(game.commander.contracts.rrs == ledger)
  }
}

private func verifyRRSBooleanDockRefusal(
  _ game: inout Game, storage: NativeStationTestStorage
) async throws {
  try await acceptRRS(&game, storage: storage)
  let active = try #require(game.commander.contracts.rrs?.active)
  game.dock(atMainStation: true)
  #expect(game.nativeMainStationArrivalContext(for: active.destination) == nil)
  let before = game.commander
  let quote = game.rrsCourierQuote(for: .debrief(active.id))
  #expect(!quote.allowed)
  do {
    try game.confirmRRSCourier(quote)
    Issue.record("Boolean dock delivered packet")
  } catch {}
  let conserved = game.commander == before
  #expect(conserved && game.commander.contracts.rrs?.active == active)
}

private func verifyRRSUnprovedMain(
  _ game: inout Game, storage: NativeStationTestStorage
) async throws {
  try await acceptRRS(&game, storage: storage)
  game.screen = .status
  game.launch()
  let main = try #require(game.bodies.first { $0.id == 0 })
  game.bodies.removeAll { $0.id == 0 }
  let before = game.commander
  game.resolveRRSCourierTerminals()
  let unprovedSuspends = game.commander == before
  #expect(unprovedSuspends && game.commander.contracts.rrs?.failed == 0)
  game.bodies.insert(main, at: 0)
  game.resolveRRSCourierTerminals()
  #expect(game.commander.contracts.rrs?.active?.carriesPacket == true)
  #expect(game.commander.contracts.rrs?.failed == 0)
}

private func verifyRRSDeparture(
  _ game: inout Game, galaxy: Bool, storage: NativeStationTestStorage
) async throws {
  try await acceptRRS(&game, storage: storage)
  game.screen = .status
  if galaxy {
    try game.commander.grantEquipment(
      "Galactic Hyperdrive", at: .utility(.galacticHyperdrive), provenance: .xyzzy)
  }
  game.launch()
  let origin = game.systemIdentity
  let credits = game.commander.credits
  if galaxy {
    game.galacticJump()
    #expect(game.systemIdentity.galaxy != origin.galaxy)
  } else {
    game.bodies = []
    game.celestials = []
    let destination = try #require(
      game.knownSystems.first {
        $0.id != game.commander.system && game.currentSystem.distance(to: $0) <= 7
      })
    game.selectedSystem = destination.id
    game.beginHyperspace()
    #expect(game.jumpCountdown != nil)
    game.arrive()
    #expect(game.systemIdentity != origin && game.systemIdentity.galaxy == origin.galaxy)
  }
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  game = await runtime.advance(delta: 0.1)
  let ledger = try #require(game.commander.contracts.rrs)
  #expect(ledger.active == nil && ledger.failed == 1 && ledger.completed == 0)
  #expect(ledger.reputation == -10 && game.commander.credits == credits)
  #expect(ledger.jobs[0].terminal?.outcome == (galaxy ? .newGalaxy : .departedSystem))
  game = await runtime.advance(delta: 0.1)
  #expect(game.commander.contracts.rrs == ledger && game.commander.credits == credits)
}

private func verifyRRSDepartureWriterFailure(
  _ game: inout Game, storage: NativeStationTestStorage
) async throws {
  try await acceptRRS(&game, storage: storage)
  let files = try rrsSaveFiles(storage.directory)
  game.screen = .status
  try game.commander.grantEquipment(
    "Galactic Hyperdrive", at: .utility(.galacticHyperdrive), provenance: .xyzzy)
  game.launch()
  let origin = game.systemIdentity
  game.galacticJump()
  #expect(game.systemIdentity.galaxy != origin.galaxy)
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  game = await runtime.snapshot()
  let before = game.commander
  let bodies = game.bodies
  try storage.blockWriter()
  await runtime.key("rrs-test-no-op")
  game = await runtime.snapshot()
  let failedWriterConserved = game.commander == before
  #expect(failedWriterConserved && game.bodies == bodies)
  #expect(game.commander.contracts.rrs?.active?.carriesPacket == true)
  #expect(try rrsSaveFiles(storage.backup) == files)
  try storage.restoreWriter()
  await runtime.key("rrs-test-no-op")
  game = await runtime.snapshot()
  let ledger = try #require(game.commander.contracts.rrs)
  #expect(ledger.active == nil && ledger.failed == 1 && ledger.reputation == -10)
  #expect(ledger.jobs[0].terminal?.outcome == .newGalaxy)
  #expect(game.commander.credits == before.credits)
  await runtime.key("rrs-test-no-op")
  game = await runtime.snapshot()
  #expect(game.commander.contracts.rrs == ledger)
}

private func verifyRRSMainDestruction(
  _ game: inout Game, storage: NativeStationTestStorage
) async throws {
  try await acceptRRS(&game, storage: storage)
  game.screen = .status
  game.enableXYZzy()
  game.secretKey("b")
  game.secretKey("e")
  game.screen = .status
  game.launch()
  let active = try #require(game.commander.contracts.rrs?.active)
  let station = try #require(game.bodies.first { $0.id == 0 })
  let old = game.commander.flightSimulation.pose
  var pose = ShipPose()
  pose.position = old.systemPoint(station.position + station.entranceNormal * 1000)
  pose.orientation.y = old.orientation.apply(station.entranceUp)
  pose.orientation.z = old.orientation.apply(station.entranceNormal) * -1
  pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
  NativeStationTestFixture.reframe(&game, to: pose)
  game.speed = 0
  let credits = game.commander.credits
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  for _ in 0..<32 where game.weaponsTargetID != station.id {
    await runtime.key("r")
    game = await runtime.snapshot()
  }
  #expect(game.weaponsTargetID == station.id)
  for frame in 0..<5000
  where game.commander.contracts.rrs?.active != nil
    && game.screen != .gameOver && !game.paused
  {
    if frame % 11 == 0 {
      await runtime.key("t")
      await runtime.key("m")
    }
    game = await runtime.advance(delta: 0.1)
  }
  let ledger = try #require(game.commander.contracts.rrs)
  #expect(game.commander.scriptState.stationResources[active.destination.key]?.destroyed == true)
  #expect(ledger.jobs[0].terminal?.outcome == .originalMainDestroyed)
  #expect(ledger.failed == 1 && ledger.completed == 0 && ledger.reputation == -10)
  #expect(game.commander.credits == credits && !ledger.jobs[0].carriesPacket)
  game = await runtime.advance(delta: 0.1)
  #expect(game.commander.contracts.rrs == ledger)
  try await expectRRSRefusal(runtime, quote: game.rrsCourierQuote(for: .debrief(active.id)))
}

private func verifyRRSLedgerForgery(
  _ game: inout Game, reason: String, storage: NativeStationTestStorage
) async throws {
  try await acceptRRS(&game, storage: storage)
  let before = game.commander
  let ledger = try #require(before.contracts.rrs)
  var object = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger))
      as? [String: Any])
  var jobs = try #require(object["jobs"] as? [[String: Any]])
  switch reason {
  case "owner": object["owner"] = UUID().uuidString
  case "packet": jobs[0]["packet"] = UUID().uuidString
  case "origin":
    var origin = try #require(jobs[0]["origin"] as? [String: Any])
    origin["commanderOwner"] = UUID().uuidString
    jobs[0]["origin"] = origin
  case "destination":
    var destination = try #require(jobs[0]["destination"] as? [String: Any])
    destination["world"] = UUID().uuidString
    jobs[0]["destination"] = destination
  case "receipt":
    var origin = try #require(jobs[0]["origin"] as? [String: Any])
    origin["sequence"] = 0
    jobs[0]["origin"] = origin
  case "seed", "profile":
    var board = try #require(jobs[0]["board"] as? [String: Any])
    board[reason] = "forged"
    jobs[0]["board"] = board
  case "legal": jobs[0]["acceptedLegal"] = 51
  case "reputation": jobs[0]["acceptedReputation"] = 1
  case "source": jobs[0]["sourceSHA256"] = String(repeating: "0", count: 64)
  case "duplicate": jobs.append(jobs[0])
  default:
    let job = ledger.jobs[0]
    jobs[0]["terminal"] = [
      "outcome": "abandoned", "calendarSeconds": job.acceptedAt - 1,
      "runtimeEpoch": UUID().uuidString,
      "system": ["galaxy": job.destination.system.galaxy, "system": job.destination.system.system],
    ]
  }
  object["jobs"] = jobs
  let forged = try JSONDecoder().decode(
    RRSCourierLedger.self,
    from: JSONSerialization.data(withJSONObject: object))
  var commander = before
  commander.contracts.rrs = forged
  #expect(!commander.valid && !commander.contractsValid)
  let liveUnchanged = game.commander == before
  #expect(liveUnchanged)
}

private func expectRRSRefusal(_ runtime: GameRuntime, quote: RRSCourierQuote) async throws {
  var refused = false
  do { try await runtime.confirmRRSCourier(quote) } catch { refused = true }
  #expect(refused)
}

private func rrsSaveFiles(_ root: URL) throws -> [String: Data] {
  let entries = try #require(FileManager.default.enumerator(atPath: root.path))
  var files: [String: Data] = [:]
  for case let relative as String in entries {
    let url = root.appendingPathComponent(relative)
    if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
      files[relative] = try Data(contentsOf: url)
    }
  }
  return files
}
