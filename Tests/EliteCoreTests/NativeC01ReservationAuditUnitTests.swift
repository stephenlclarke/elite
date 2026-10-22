import Foundation
import Testing

@testable import EliteCore

/// A real born berth and writable destination; earlier discovery/visit facts are controlled inputs,
/// not a claim that this fixture flew those routes or executed the twelve-second scans.
private final class C01ReservationAuditFixture {
  let root: URL
  let save: URL
  var game: Game

  init() async throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "c01-audit-" + UUID().uuidString)
    save = root.appendingPathComponent("commander.json")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let runtime = GameRuntime(game: Game(executive: false))
    try await runtime.startNewCommander()
    _ = try await runtime.registerNewCommanderDestination(at: save)
    game = await runtime.snapshot()
    game.screen = .status
    let owner = try #require(game.commander.equipmentOwnerID)
    for system in [185, 93] {
      let key = "main-orbital:0:\(system)"
      let identity = NativeMainStationIdentity(
        world: owner, system: .init(galaxy: 0, system: system),
        resource: Game.worldResourceIdentity("main-station-v1:" + key))
      game.commander.nativeStations?.mainStations.append(identity)
      game.commander.scriptState.stationResources[key] = .init(
        identity: identity.resource, galaxy: 0, system: system)
    }
    var discovery = NativeFleetDiscovery(owner: owner)
    let ships = ShipCatalogue.all.filter {
      $0.originalDefinition != nil && $0.catalogue.discoveryEligible
        && $0.catalogue.objectKind == .ship
    }.prefix(2)
    for ship in ships {
      let allocated = game.commander.flightSimulation.allocateActor()
      let actor = try #require(allocated)
      let player = try #require(game.commander.flightSimulation.player)
      try discovery.record(
        .init(
          owner: owner, ship: ship.id, kind: .identification, actor: actor, player: player,
          physicalTime: 0, death: nil, mainDock: nil, secondaryDock: nil))
    }
    game.commander.scriptState.savedFleetDiscovery = discovery
    game.scriptPacks = [try ScriptPackLibrary.read(ScriptPackLibrary.bundledGlassMeridianDirectory)]
    try #require(game.nativeMainStationDockEvidenceIsCurrent && game.scriptDurabilityAvailable)
    try #require(game.commander.valid)
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
  func heldAtSorel() async throws -> GameRuntime {
    _ = try accept()
    let accepted = try #require(game.glassMeridianMission)
    let opening = try #require(accepted.savedGlassMeridian)
    let component = try C01SurveyorFixture(commission: opening)
    let held = try component.held()
    let history = try component.commander(held)
    var mission = accepted
    mission.savedGlassMeridian = held
    mission.milestones = [0, 1, 2]
    mission.revision += 2
    mission.ownedEncounters = try #require(history.scriptState.instances[mission.id])
      .ownedEncounters
    for sealed in held.readings {
      let ordinal = sealed.reading.ordinal
      let key = NativeGlassMeridian.encounters[ordinal]
      var group = ScriptOwnedEncounter(
        id: key, galaxy: 0, system: 185,
        actors: [NativeGlassMeridian.targets[ordinal]: sealed.authority.marker])
      group.admitted = true
      mission.ownedEncounters[key] = group
    }
    game.commander.scriptState.instances[mission.id] = mission
    game.commander.scriptState.geometry.merge(history.scriptState.geometry) { existing, _ in
      existing
    }
    let pack = try #require(game.glassMeridianPack)
    for design in pack.models.values {
      let hash = ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(design))
      game.commander.scriptState.geometry[hash] = design
    }
    game.commander.flightSimulation = history.flightSimulation
    game.commander.nativeStations?.currentMainDock = nil
    game.nativeMainStationDockEvidence = nil
    game.commander.system = 0
    game.selectedSystem = 0
    game.market = MarketItem.at(game.currentSystem)
    // Controlled Enmadan scene setup after the historical component proofs; no route claim.
    game.launch()
    try #require(!game.docked && game.commander.valid, Comment(rawValue: game.message))
    let station = try #require(game.bodies.first { $0.id == 0 })
    let old = game.commander.flightSimulation.pose
    var pose = ShipPose()
    pose.position = old.systemPoint(station.entrancePosition + station.entranceNormal * 2)
    pose.orientation.y = old.orientation.apply(station.entranceUp)
    pose.orientation.z = old.orientation.apply(station.entranceNormal) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 3
    let runtime = GameRuntime(game: game, saveURL: save)
    for _ in 0..<100 {
      if await runtime.snapshot().docked { break }
      _ = await runtime.advance(delta: 0.05)
    }
    let arrived = await runtime.snapshot()
    try #require(arrived.docked && arrived.nativeMainStationDockEvidenceIsCurrent)
    let review = arrived.glassMeridianReview(.auditReservations)
    try #require(review.allowed, Comment(rawValue: review.issues.joined(separator: "; ")))
    return runtime
  }

  func accept() throws -> NativeC01ReservationSource {
    let review = game.glassMeridianReview(.accept)
    try #require(review.allowed, Comment(rawValue: review.issues.joined(separator: "; ")))
    try game.confirmGlassMeridian(review)
    return try #require(game.glassMeridianMission?.savedGlassMeridian?.reservationCase?.source)
  }
}

struct NativeC01ReservationAuditUnitTests {
  @Test func freshNativeCommissionCreatesOneCapacityTwoPaidClaimsBeforeAnyObservation() async throws
  {
    let f = try await C01ReservationAuditFixture()
    defer { f.clean() }
    let before = f.game.commander
    let next = before.scriptState.nextEvent + 1
    let source = try f.accept()
    let mission = try #require(f.game.glassMeridianMission)
    let state = try #require(mission.savedGlassMeridian)
    #expect(source.terms.firstSequence == next && source.events.count == 5)
    #expect(source.terms.epoch == before.flightSimulation.physicalTime)
    #expect(
      source.events.allSatisfy {
        $0.physicalTime == source.terms.epoch && mission.hasAcknowledged($0.sequence)
      })
    #expect(state.readings.isEmpty && state.surveyor == nil && state.losses.isEmpty)
    #expect(
      !f.game.glassMeridianAuditDetail(.auditReservations).contains { $0.hasPrefix("Findings:") })
    #expect(f.game.glassMeridianReview(.auditReservations).auditPin == nil)
    #expect(source.projection.availableUnits == 0 && source.projection.claims.count == 2)
    #expect(source.projection.allocation == source.projection.claims[0].id)
    #expect(source.projection.balances == .init(clinic: 0, freight: 0, contractor: 1000))
    #expect(source.projection.payments.map(\.amount) == [500, 500])
    #expect(Set(source.projection.claims.map(\.certificate)) == [source.certificate])
    #expect(f.game.commander.credits == before.credits && f.game.commander.cargo == before.cargo)
    #expect(f.game.commander.equipmentInventory == before.equipmentInventory)
    #expect(NativeGlassMeridianSave.validateClaims(f.game.commander))
  }

  @Test func originalContentsComputeConcealedOverlapWithoutChangingLedgerOrCreatingASecondUnit()
    throws
  {
    let state = try NativeGlassMeridianUnitTests().fixture()
    let source = try NativeC01ReservationSource(permission: state.permission, firstSequence: 100)
    let before = try JSONEncoder().encode(source)
    let finding = try NativeC01ReservationComparison.compare(
      source: source, clocks: source.clocks, recorder: source.recorder)
    #expect(finding.trueOverlap == 30 && finding.concealedClockOffset == 60)
    #expect(finding.reservationCounterDifference == 1)
    #expect(finding.claims.count == 2 && finding.payments.count == 2)
    #expect(source.clocks[0].localWindow.overlap(source.clocks[1].localWindow) == 0)
    #expect(
      source.recorder.original
        == NativeC01Surveyor.actor(
          mission: state.permission.mission, alias: "original-recorder"))
    #expect(try NativeC01ReservationSource.decodeClosed(before) == source)
    #expect(source.fingerprint == (try NativeC01ReservationSource.decodeClosed(before)).fingerprint)
    #expect(source.projection.availableUnits == 0)
    var projection = source.projection
    let retained = projection
    #expect(throws: (any Error).self) {
      try NativeC01ReservationSource.applying(
        .reserveClinic, terms: source.terms, state: &projection, previous: source.events)
    }
    #expect(projection == retained)
  }

  @Test(arguments: [0.0, 350.07, 370.07, 1_000_000.05, 1e12 - 1000])
  func nativeClockArithmeticKeepsThirtySecondFindingAcrossBinaryExponentBoundaries(epoch: Double)
    throws
  {
    let p = try NativeGlassMeridianUnitTests().fixture().permission
    let permission = NativeGlassMeridianPermission(
      mission: p.mission, operation: p.operation, owner: p.owner, dock: p.dock,
      carrier: p.carrier, inventoryRevision: p.inventoryRevision, fit: p.fit,
      visited: p.visited, identified: p.identified, physicalTime: epoch)
    let source = try NativeC01ReservationSource(permission: permission, firstSequence: 1)
    let finding = try NativeC01ReservationComparison.compare(
      source: source, clocks: source.clocks, recorder: source.recorder)
    #expect(finding.trueOverlap == 30 && finding.concealedClockOffset == 60)
  }

  @Test func foreignClockRecorderAndAlteredOriginalPaymentsCannotSupplyFindings() throws {
    let source = try NativeC01ReservationSource(
      permission: NativeGlassMeridianUnitTests().fixture().permission, firstSequence: 20)
    let other = try NativeC01ReservationSource(
      permission: NativeGlassMeridianUnitTests().fixture().permission, firstSequence: 30)
    #expect(throws: (any Error).self) {
      try NativeC01ReservationComparison.compare(
        source: source, clocks: other.clocks, recorder: source.recorder)
    }
    #expect(throws: (any Error).self) {
      try NativeC01ReservationComparison.compare(
        source: source, clocks: source.clocks, recorder: other.recorder)
    }
    let raw = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(source)) as? [String: Any])
    for change in ["amount", "extra-clock", "offset", "unknown", "counter"] {
      var changed = raw
      if change == "amount" {
        var events = try #require(changed["events"] as? [[String: Any]])
        var payment = try #require(events[2]["payment"] as? [String: Any])
        payment["amount"] = 499
        events[2]["payment"] = payment
        changed["events"] = events
      } else if change == "unknown" {
        changed["auditComplete"] = true
      } else {
        var clocks = try #require(changed["clocks"] as? [[String: Any]])
        if change == "extra-clock" {
          clocks.append(clocks[0])
        } else {
          clocks[1][change == "offset" ? "offset" : "reservationCounter"] = 0
        }
        changed["clocks"] = clocks
      }
      let data = try JSONSerialization.data(withJSONObject: changed)
      #expect(throws: (any Error).self) { try NativeC01ReservationSource.decodeClosed(data) }
    }
  }

  @Test func nativeSorelConfirmationRecordsOnlyStageFourAndRetainsTheSameProtectedRecorder()
    async throws
  {
    let f = try await C01ReservationAuditFixture()
    defer { f.clean() }
    let runtime = try await f.heldAtSorel()
    let before = await runtime.snapshot()
    let review = before.glassMeridianReview(.auditReservations)
    let source = try #require(
      before.glassMeridianMission?.savedGlassMeridian?.reservationCase?.source)
    try await runtime.scriptCommand { game in try game.confirmGlassMeridianReservationAudit(review)
    }
    let after = await runtime.snapshot()
    let mission = try #require(after.glassMeridianMission)
    let state = try #require(mission.savedGlassMeridian)
    let audit = try #require(state.reservationCase?.audit)
    #expect(audit.pin == review.auditPin && audit.consent == review.reviewToken)
    #expect(audit.target == "sorel-ledger-audit" && audit.event == "mission_contact_confirmed")
    #expect(audit.stage == "l337.glass-meridian/audit-reservations")
    #expect(audit.findings.trueOverlap == 30 && audit.findings.concealedClockOffset == 60)
    #expect(audit.findings.reservationCounterDifference == 1)
    #expect(mission.milestones == [0, 1, 2, 3] && mission.completionReceipt == nil)
    #expect(mission.hasAcknowledged(audit.sequence) && mission.receipts.contains(audit.target))
    #expect(state.reservationCase?.source == source && state.surveyor?.held == true)
    #expect(state.surveyor == before.glassMeridianMission?.savedGlassMeridian?.surveyor)
    #expect(
      after.commander.credits == before.commander.credits
        && after.commander.cargo == before.commander.cargo)
    #expect(after.commander.equipmentInventory == before.commander.equipmentInventory)
    #expect(after.commander.checkedCargoTonnes == before.commander.checkedCargoTonnes)
    #expect(
      after.commander.scriptState.savedClueJournal == before.commander.scriptState.savedClueJournal)
    #expect(NativeGlassMeridianSave.validateClaims(after.commander) && after.commander.valid)
    #expect(mission.receipts.allSatisfy(PackValidation.localID))
    let sequence = after.commander.scriptState.nextEvent
    try await runtime.scriptCommand { game in try game.confirmGlassMeridianReservationAudit(review)
    }
    let replay = await runtime.snapshot()
    #expect(replay.glassMeridianMission?.savedGlassMeridian == state)
    #expect(
      replay.commander.scriptState.nextEvent == sequence
        && replay.commander.credits == before.commander.credits)
    let pointer = try Data(contentsOf: f.save)
    let decoded = try ScriptSaveStore.read(pointer, from: f.save)
    #expect(decoded.0.scriptState.instances[mission.id]?.savedGlassMeridian == state)
    #expect(try JSONDecoder().decode(ScriptSavePointer.self, from: pointer).schemaVersion == 137)
  }

  @Test(arguments: [
    "paused", "trial", "writer", "epoch", "dock", "carrier", "fit", "clock", "recorder", "source",
  ])
  func staleOrUnattainedNativeInputsCannotGrantSorelAudit(change: String) async throws {
    let f = try await C01ReservationAuditFixture()
    defer { f.clean() }
    let runtime = try await f.heldAtSorel()
    var game = await runtime.snapshot()
    let review = game.glassMeridianReview(.auditReservations)
    let id = try #require(game.glassMeridianMission?.id)
    switch change {
    case "paused": game.paused = true
    case "trial": game.isMissionTrial = true
    case "writer": game.scriptDurabilityAvailable = false
    case "epoch": game.invalidateNativeStationAuthority()
    case "dock": game.nativeMainStationDockEvidence = nil
    case "carrier":
      let inventory = try #require(game.commander.equipmentInventory)
      game.commander.savedEquipmentInventory = try .init(owner: inventory.owner, activeHull: UUID())
    case "fit":
      let inventory = try #require(game.commander.equipmentInventory)
      game.commander.savedEquipmentInventory = try .init(
        owner: inventory.owner, activeHull: inventory.activeHull,
        revision: inventory.revision + 1, items: inventory.items)
    case "clock":
      game.commander.scriptState.instances[id]?.savedGlassMeridian?.readings.removeLast()
    case "recorder":
      game.commander.scriptState.instances[id]?.savedGlassMeridian?.surveyor?.capture = nil
    default: game.commander.scriptState.instances[id]?.savedGlassMeridian?.reservationCase = nil
    }
    let before = game.commander
    #expect(throws: (any Error).self) { try game.confirmGlassMeridianReservationAudit(review) }
    #expect(game.commander == before)
    #expect(game.glassMeridianMission?.savedGlassMeridian?.reservationCase?.audit == nil)
  }

  @Test func refusedWriterRollsBackAuditAndAcknowledgementThenFreshRetryCommitsOnce() async throws {
    let f = try await C01ReservationAuditFixture()
    defer { f.clean() }
    let runtime = try await f.heldAtSorel()
    let before = await runtime.snapshot()
    let review = before.glassMeridianReview(.auditReservations)
    let pointer = try Data(contentsOf: f.save)
    try FileManager.default.removeItem(at: f.save)
    try FileManager.default.createDirectory(at: f.save, withIntermediateDirectories: false)
    do {
      try await runtime.scriptCommand { game in
        try game.confirmGlassMeridianReservationAudit(review)
      }
      Issue.record("An occupied directory must refuse the actual pointer publication")
    } catch {}
    let refused = await runtime.snapshot()
    #expect(refused.commander == before.commander)
    #expect(refused.glassMeridianMission?.savedGlassMeridian?.reservationCase?.audit == nil)
    try FileManager.default.removeItem(at: f.save)
    try pointer.write(to: f.save, options: .atomic)
    let fresh = refused.glassMeridianReview(.auditReservations)
    try await runtime.scriptCommand { game in try game.confirmGlassMeridianReservationAudit(fresh) }
    let committed = await runtime.snapshot()
    #expect(committed.glassMeridianMission?.savedGlassMeridian?.reservationCase?.audit != nil)
    #expect(committed.commander.credits == before.commander.credits)
  }

  @Test func actualLaterCarrierLossRetainsAuditedHistoryAndPublishesOneOrderedObservation()
    async throws
  {
    let f = try await C01ReservationAuditFixture()
    defer { f.clean() }
    let runtime = try await f.heldAtSorel()
    let review = await runtime.snapshot().glassMeridianReview(.auditReservations)
    try await runtime.scriptCommand { game in try game.confirmGlassMeridianReservationAudit(review)
    }
    let completed = await runtime.snapshot()
    let audit = try #require(
      completed.glassMeridianMission?.savedGlassMeridian?.reservationCase?.audit)
    try await runtime.scriptCommand { game in
      game.launch()
      try #require(!game.docked)
    }
    await runtime.attainC01AuditUnitFatalState()
    let attained = await runtime.snapshot()
    let pointer = try Data(contentsOf: f.save)
    try FileManager.default.removeItem(at: f.save)
    try FileManager.default.createDirectory(at: f.save, withIntermediateDirectories: false)
    await runtime.commitC01AuditUnitLoss()
    let refused = await runtime.snapshot()
    #expect(refused.commander == attained.commander)
    #expect(refused.energy == 0 && refused.screen == .gameOver)
    #expect(refused.glassMeridianMission?.savedGlassMeridian?.reservationCase?.laterLoss == nil)
    #expect(refused.commander.scriptState.nextEvent == attained.commander.scriptState.nextEvent)
    try FileManager.default.removeItem(at: f.save)
    try pointer.write(to: f.save, options: .atomic)
    await runtime.commitC01AuditUnitLoss()
    let lost = await runtime.snapshot()
    let state = try #require(lost.glassMeridianMission?.savedGlassMeridian)
    let observation = try #require(state.reservationCase?.laterLoss)
    #expect(state.reservationCase?.audit == audit && state.surveyor?.held == false)
    #expect(observation.audit == audit.operation && observation.sequence > audit.sequence)
    #expect(observation.loss.physicalTime >= audit.physicalTime)
    #expect(lost.glassMeridianMission?.hasAcknowledged(observation.sequence) == true)
    #expect(lost.glassMeridianMission?.milestones == [0, 1, 2, 3])
    #expect(lost.commander.credits == completed.commander.credits)
    #expect(NativeGlassMeridianSave.validateClaims(lost.commander))
    let sequence = lost.commander.scriptState.nextEvent
    await runtime.commitC01AuditUnitLoss()
    #expect(await runtime.snapshot().commander.scriptState.nextEvent == sequence)
  }

  @Test(arguments: [false, true])
  func newCorpusUsesClosed137And138AndNeverHydratesAnOlderUnboundCommission(alien: Bool)
    async throws
  {
    let f = try await C01ReservationAuditFixture()
    defer { f.clean() }
    _ = try f.accept()
    let mission = try #require(f.game.glassMeridianMission)
    let state = try #require(mission.savedGlassMeridian)
    let leaf = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
    func data(_ leaf: [String: Any]) throws -> Data {
      try JSONSerialization.data(withJSONObject: [
        "instances": [
          mission.id.uuidString: [
            "definition": NativeGlassMeridian.stateID, "digest": NativeGlassMeridian.digest,
            "savedGlassMeridian": leaf,
          ]
        ]
      ])
    }
    let bytes = try data(leaf)
    try ScriptSaveJSONPreflight.validateRepairLoopFields(
      bytes, part: .missions, schema: alien ? 138 : 137)
    for schema in [63, 64, 129, 130, 139] {
      #expect(throws: (any Error).self) {
        try ScriptSaveJSONPreflight.validateRepairLoopFields(bytes, part: .missions, schema: schema)
      }
    }
    var old = f.game
    old.commander.scriptState.instances[mission.id]?.savedGlassMeridian?.reservationCase = nil
    let before = old.commander
    let quote = old.glassMeridianReview(.accept)
    #expect(!quote.allowed)
    #expect(throws: (any Error).self) { try old.confirmGlassMeridian(quote) }
    #expect(old.commander == before)
    #expect(old.glassMeridianMission?.savedGlassMeridian?.reservationCase == nil)
    var unknown = leaf
    unknown["completedAudit"] = true
    let unknownBytes = try data(unknown)
    #expect(throws: (any Error).self) {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(
        unknownBytes, part: .missions, schema: alien ? 138 : 137)
    }
  }

  @Test func unreadReplacementUsesPreassignedLineageButAliasOrForeignScanCannotReadContents() throws
  {
    let helper = NativeGlassMeridianUnitTests()
    var state = try helper.fixture()
    let source = try NativeC01ReservationSource(permission: state.permission, firstSequence: 10)
    state.reservationCase = .init(source: source)
    var old = try helper.sealed(state, ordinal: 0).authority.marker
    old.presence = .destroyed
    old.body.energy = 0
    state.losses = [.init(ordinal: 0, generation: 0, marker: old, physicalTime: 5)]
    let replacement = try helper.sealed(state, ordinal: 0, start: 10)
    state.readings = [replacement]
    let contents = try #require(
      NativeGlassMeridian.reservationContents(for: replacement, in: state))
    #expect(contents == source.clocks[0])
    #expect(contents.lineage != replacement.reading.marker)
    let foreign = try helper.sealed(helper.fixture(), ordinal: 0)
    #expect(NativeGlassMeridian.reservationContents(for: foreign, in: state) == nil)
    state.readings = []
    #expect(NativeGlassMeridian.reservationContents(for: replacement, in: state) == nil)
  }
}

extension GameRuntime {
  /// A controlled attained simulation input, outside the protected loss candidate.
  fileprivate func attainC01AuditUnitFatalState() {
    game.energy = 0
    game.screen = .gameOver
  }
  fileprivate func commitC01AuditUnitLoss() {
    commitC01Surveyor(
      startTime: game.commander.flightSimulation.physicalTime,
      startPlayer: game.commander.flightSimulation.player)
  }
}
