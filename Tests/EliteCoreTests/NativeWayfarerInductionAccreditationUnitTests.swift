import Foundation
import Testing

@testable import EliteCore

/// Native transaction records and continuing service policy, not a UI journey.
private final class InductionAccreditationFixture {
  let f: InductionNetworkFixture
  let terminal: NativeInductionAccreditation
  let previous: ScriptInstance
  let commander: Commander
  init(carriedSeed: Bool = false) throws {
    f = try .init()
    var commander = try f.commander()
    var mission = try #require(commander.scriptState.instances[f.audited.permission.mission])
    if carriedSeed {
      commander.scriptState.instances[f.f.booking.instance] = f.f.child(custody: f.f.custody)
      mission.revision += 1
      mission.acknowledge(f.f.custody.pickup.contact.sequence)
    }
    previous = mission
    let state = try #require(mission.savedWayfarerInduction)
    let policy = try #require(state.charterChoice?.policy)
    let certificate = try #require(state.networkCertification)
    let entitlement = NativeInductionAccreditation.entitlement(
      parent: mission.id, owner: state.permission.owner, certification: certificate.operation)
    let before = commander.credits
    terminal = .init(
      operation: try NativeInductionAccreditation.identity(
        sequence: 311, revision: mission.revision + 1, certification: certificate.operation,
        policy: policy, entitlement: entitlement, dock: f.dock, carrier: f.f.issue.carrier, fit: 1,
        time: 2_000_020, clock: 900_520, before: before, after: before + 76000), sequence: 311,
      publicationRevision: mission.revision + 1, certification: certificate.operation,
      policy: policy, entitlement: entitlement, dock: f.dock, carrier: f.f.issue.carrier,
      inventoryRevision: 1, physicalTime: 2_000_020, flightSeconds: 900_520, creditsBefore: before,
      creditsAfter: before + 76000)
    let next = try state.accrediting(terminal)
    mission.savedWayfarerInduction = next
    mission.milestones = next.milestones
    mission.outcome = .complete
    mission.revision += 1
    mission.acknowledge(311)
    commander.flightSimulation.physicalTime = 2_000_020
    commander.scriptState.flightSeconds = 900_520
    commander.scriptState.nextEvent = 311
    commander.credits = terminal.creditsAfter
    commander.system = 7
    commander.nativeStations?.currentMainDock = f.dock
    let cause = Self.context(commander, dock: f.dock, revision: previous.revision)
    let committed = Self.context(commander, dock: f.dock, revision: mission.revision)
    mission.completionReceipt = .init(
      instance: mission.id, definition: mission.definition, version: mission.version,
      digest: mission.digest, outcome: .complete, sequence: 311, causeKind: "mission.receipted",
      cause: cause, committed: committed, revision: mission.revision,
      milestones: mission.milestones.sorted(), destroyedEncounters: [], deliveredParties: [],
      returnedEquipment: [], settlementAmount: nil, choices: nil)
    commander.scriptState.instances[mission.id] = mission
    var game = Game()
    game.commander = commander
    try game.awardScriptClue(previous: previous, next: mission, trust: .production)
    self.commander = game.commander
  }
  static func context(
    _ commander: borrowing Commander, dock: NativeMainStationDockReceipt, revision: UInt64
  ) -> ScriptEventContext {
    .init(
      galaxy: 0, system: dock.station.system.system, docked: true, mainStation: true,
      revision: revision, frameSeconds: 0, localSeconds: commander.scriptState.localSeconds,
      flightSeconds: commander.scriptState.flightSeconds,
      calendarSeconds: commander.scriptState.calendarSeconds,
      transitSeconds: commander.scriptState.transitSeconds, playerPosition: nil,
      nativeMainDock: dock)
  }
}

struct NativeWayfarerInductionAccreditationUnitTests {
  @Test func owningTerminalRecordsExactly7600OnceChosenCharterAccreditationAndOneUniqueClue() throws
  {
    let f = try InductionAccreditationFixture()
    var game = Game()
    game.commander = f.commander
    let mission = try #require(game.wayfarerInductionMission)
    let state = try #require(mission.savedWayfarerInduction)
    #expect(state.valid && state.accreditation == f.terminal && mission.outcome == .complete)
    #expect(mission.milestones == Set(0...13) && state.payloads.isEmpty)
    #expect(f.commander.credits == f.terminal.creditsBefore + 76000)
    #expect(f.terminal.policy == state.charterChoice?.policy)
    #expect(
      NativeWayfarerInductionSave.validateClaims(game.commander)
        && NativeInductionCrewLogSave.validateClaims(game.commander))
    #expect(game.hasWayfarerAccreditation)
    #expect(
      game.commander.scriptState.savedClueJournal?.awards["l337.wayfarer-exchange"]?.clueID
        == "exchange-unbooked-window")
    #expect(game.commander.scriptState.savedClueJournal?.awards.count == 1)
    let receipt = try #require(mission.completionReceipt)
    try game.awardScriptClue(previous: f.previous, next: mission, trust: .production)
    #expect(
      game.commander.scriptState.savedClueJournal?.awards.count == 1
        && mission.completionReceipt == receipt)
    #expect(throws: (any Error).self) { try state.accrediting(f.terminal) }
  }

  @Test func repeatedSennConfirmationCannotPayOrGrantAnotherClueOrDiscardExistingBookings() throws {
    let f = try InductionAccreditationFixture()
    var game = Game()
    game.commander = f.commander
    let credits = game.commander.credits
    let journal = game.commander.scriptState.savedClueJournal
    let mission = try #require(game.wayfarerInductionMission)
    #expect(
      try mission.savedWayfarerInduction?.charterCapacity?.projection().filter {
        $0.reservation != nil
      }.count == 3)
    #expect(throws: (any Error).self) {
      try game.confirmInductionAccreditation(
        dock: f.f.dock, carrier: f.terminal.carrier, revision: 1)
    }
    #expect(
      game.commander.credits == credits && game.commander.scriptState.savedClueJournal == journal)
    #expect(game.wayfarerInductionMission == mission)
    let certified = try #require(f.previous.savedWayfarerInduction)
    var raw = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(f.terminal)) as? [String: Any])
    raw["creditsBefore"] = 4_294_967_295
    raw["creditsAfter"] = 4_294_967_295
    let overflow = try JSONDecoder().decode(
      NativeInductionAccreditation.self, from: JSONSerialization.data(withJSONObject: raw))
    #expect(!overflow.valid(parent: certified))
  }

  @Test
  func actualUncollectedCancellationAfterAccreditationReturnsSameStockWindowAndKeepsFinalReceipt()
    throws
  {
    let f = try InductionAccreditationFixture()
    var game = Game()
    game.commander = f.commander
    let before = try #require(game.wayfarerInductionMission)
    let receipt = try #require(before.completionReceipt)
    try game.closeInductionSeedBooking(instance: f.f.f.booking.instance)
    let after = try #require(game.wayfarerInductionMission)
    #expect(after.outcome == .complete && after.revision == before.revision + 1)
    #expect(
      after.completionReceipt == receipt
        && receipt.valid(for: after, engine: game.commander.scriptState))
    #expect(game.commander.credits == f.commander.credits && game.hasWayfarerAccreditation)
    #expect(after.savedWayfarerInduction?.charterSeedSource?.units[0].status == .available)
    #expect(
      try after.savedWayfarerInduction?.charterCapacity?.projection().filter {
        $0.reservation != nil
      }.count == 2)
    #expect(game.commander.scriptState.savedClueJournal?.awards.count == 1)
  }

  @Test func realHeldSeedReceivingAfterSennPaysOnlyItsFrozenQuoteAndRetainsTheOwningEntitlement()
    throws
  {
    let f = try InductionAccreditationFixture(carriedSeed: true)
    let seed = f.f.f
    var commander = f.commander
    let dock = seed.dock(91, sequence: 112, visit: f.f.dock.actor.visit + 1)
    commander.flightSimulation.enter(dock.station.system, arriving: true)
    commander.flightSimulation.physicalTime = 2_000_100
    commander.scriptState.flightSeconds = 900_600
    commander.nativeStations?.nextMainDockSequence = 113
    commander.nativeStations?.currentMainDock = dock
    commander.system = 91
    var child = try #require(commander.scriptState.instances[seed.booking.instance])
    let parent = try #require(
      commander.scriptState.instances[seed.booking.parent]?.savedWayfarerInduction)
    let capacity = try #require(parent.charterCapacity)
    let window = try capacity.returnQuote(
      reservation: seed.booking.window.operation, reason: .completed)
    let context = InductionAccreditationFixture.context(
      commander, dock: dock, revision: child.revision)
    let contact = WayfarerColdChainContact(sequence: 312, dock: dock, context: context)
    let payment = ScriptCourierTerminalReceipt(
      id: ScriptCourierCustody.terminalIdentity(seed.booking.unit), item: seed.booking.unit,
      cause: .delivered,
      proof: .init(
        sequence: 312, token: "induction-original-seed-reception", revision: child.revision,
        epoch: UUID(), clock: context.calendarSeconds,
        station: .init(galaxy: 0, system: 91, stationClass: "main-orbital")),
      amount: seed.booking.terms.rewardNative)
    let before = commander.credits
    let after = before + seed.booking.terms.rewardNative
    let integrity = try seed.custody.integrity.receiving(
      .init(binding: seed.custody.integrity.binding, timer: seed.custody.timer, context: context),
      receipt: payment)
    let end = NativeInductionSeedCustodyEnd(
      operation: try NativeInductionSeedCustodyEnd.identity(
        booking: seed.booking.operation, pickup: seed.custody.pickup.operation, kind: .received,
        sequence: 312, stockRevision: 1, window: window, time: 2_000_100, context: context,
        closedFlightSeconds: 900_600, contact: contact, loss: nil, expiry: nil, payment: payment,
        before: before, after: after), booking: seed.booking.operation,
      pickup: seed.custody.pickup.operation, kind: .received, sequence: 312, stockRevision: 1,
      window: window, physicalTime: 2_000_100, context: context, closedFlightSeconds: 900_600,
      contact: contact, loss: nil, expiry: nil, payment: payment, creditsBefore: before,
      creditsAfter: after)
    let custody = NativeInductionSeedCustody(
      pickup: seed.custody.pickup, timer: seed.custody.timer, integrity: integrity, end: end)
    let committed = InductionAccreditationFixture.context(
      commander, dock: dock, revision: child.revision + 1)
    try NativeInductionSeedSave.commitEnd(
      end, custody: custody, child: &child, commander: &commander, committedContext: committed)
    let terminal = try #require(commander.scriptState.instances[seed.booking.parent])
    let receipt = try #require(terminal.completionReceipt)
    #expect(
      commander.credits == after && after == f.commander.credits + seed.booking.terms.rewardNative)
    #expect(receipt == f.commander.scriptState.instances[seed.booking.parent]?.completionReceipt)
    #expect(receipt.valid(for: terminal, engine: commander.scriptState))
    #expect(
      NativeWayfarerInductionSave.validateClaims(commander)
        && NativeInductionCrewLogSave.validateClaims(commander))
    #expect(commander.scriptState.savedClueJournal?.awards.count == 1)
  }

  @Test(arguments: [false, true])
  func completedEntitlementAndLaterCancellationSurviveActiveLessonHighestEnvelope(alien: Bool)
    throws
  {
    let f = try InductionAccreditationFixture()
    var game = Game()
    game.commander = f.commander
    let parentID = f.previous.id
    let originalTerminal = try #require(game.wayfarerInductionMission?.completionReceipt)
    // Use the actual continuing-service command after accreditation, not a forged revision.
    try game.closeInductionSeedBooking(instance: f.f.f.booking.instance)
    let continued = try #require(game.wayfarerInductionMission)
    #expect(continued.revision > f.previous.revision + 1)
    #expect(continued.completionReceipt == originalTerminal)
    let credits = game.commander.credits
    let journal = game.commander.scriptState.savedClueJournal
    game.scriptPacks = [
      try ScriptPackLibrary.read(ScriptPackLibrary.bundledSafeGunneryDirectory)
    ]
    game.scriptDurabilityAvailable = true
    game.docked = true
    game.dockedAtMainStation = true
    try game.rebindNativeStationsAfterLoad()
    try #require(game.nativeMainStationDockEvidenceIsCurrent)
    let review = game.safeGunneryReview(.accept)
    try #require(review.allowed)
    try game.confirmSafeGunnery(review)
    let active = try #require(game.activeSafeGunnery)
    // Provider allocation is a component fixture; no flight journey or weapon input is run.
    var flight = game.commander.flightSimulation
    flight.enter(NativeSafeGunnery.location, arriving: false)
    flight.pose.position = .init(20000, 0, 0)
    flight.physicalTime += 1
    let scope = active.state.permission
    let provider = try NativePracticeState.prepare(
      permission: .init(
        mission: active.instance.id, owner: scope.owner, carrier: scope.carrier,
        lesson: .gunnery, digest: NativeSafeGunnery.digest, consent: scope.consent,
        player: try #require(flight.player), frame: flight.pose, begunAt: flight.physicalTime),
      flight: &flight)
    var lesson = active.state
    try lesson.begin(provider)
    var instance = active.instance
    instance.savedSafeGunnery = lesson
    instance.savedNativePractice = provider
    instance.milestones = [0, 1]
    game.commander.flightSimulation = flight
    game.commander.scriptState.instances[instance.id] = instance
    #expect(NativeSafeGunnerySave.validateClaims(game.commander))
    #expect(NativePracticeSave.validateClaims(game.commander))
    #expect(NativeWayfarerInductionSave.validateClaims(game.commander))
    #expect(NativeInductionCrewLogSave.validateClaims(game.commander))

    let schema = alien ? 128 : 127
    #expect(
      NativeSafeGunnerySave.publicationVersion(
        lesson: true, practice: true, crewLog: true, alien: alien) == schema)
    let expectedState = game.commander.scriptState
    let expectedContracts = game.commander.contracts
    let missions = try JSONEncoder().encode(expectedState)
    let contracts = try JSONEncoder().encode(expectedContracts)
    try NativeSafeGunnerySave.validateArchiveFields(
      missions, part: .missions, schema: schema, alien: alien)
    try NativeSafeGunnerySave.validateArchiveFields(
      contracts, part: .contracts, schema: schema, alien: alien)
    // Decode back into the existing Game's COW Commander storage. The round-trip only
    // replaces these two chunks; it does not need a whole Commander snapshot or second Game.
    game.commander.scriptState = try JSONDecoder().decode(ScriptEngineState.self, from: missions)
    game.commander.contracts = try JSONDecoder().decode(ScriptContractState.self, from: contracts)
    #expect(game.commander.scriptState == expectedState)
    #expect(game.commander.contracts == expectedContracts)
    #expect(game.commander.scriptState.instances[parentID] == continued)
    #expect(game.commander.scriptState.instances[instance.id] == instance)
    #expect(
      game.commander.scriptState.savedClueJournal == journal && game.commander.credits == credits)
    #expect(NativeSafeGunnerySave.validateClaims(game.commander))
    #expect(NativePracticeSave.validateClaims(game.commander))
    #expect(NativeWayfarerInductionSave.validateClaims(game.commander))
    #expect(NativeInductionCrewLogSave.validateClaims(game.commander))
    #expect(game.hasWayfarerAccreditation)
    #expect(game.activeSafeGunnery?.state == lesson)
    #expect(
      originalTerminal.valid(
        for: try #require(game.commander.scriptState.instances[parentID]),
        engine: game.commander.scriptState))
    // The higher envelope must still close every present lower-family native leaf.
    var parent = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(continued)) as? [String: Any])
    var induction = try #require(parent["savedWayfarerInduction"] as? [String: Any])
    var terminal = try #require(induction["accreditation"] as? [String: Any])
    terminal["extraPayment"] = 76000
    induction["accreditation"] = terminal
    parent["savedWayfarerInduction"] = induction
    let corrupt = try JSONSerialization.data(withJSONObject: [
      "instances": [parentID.uuidString: parent]
    ])
    #expect(throws: (any Error).self) {
      try NativeSafeGunnerySave.validateArchiveFields(
        corrupt, part: .missions, schema: schema, alien: alien)
    }
  }

  @Test func revisionOnlyForgeryMissingChildAcknowledgementOrClueCannotPreserveAccreditation()
    throws
  {
    let f = try InductionAccreditationFixture()
    var commander = f.commander
    let id = f.previous.id
    var mission = try #require(commander.scriptState.instances[id])
    let receipt = try #require(mission.completionReceipt)
    mission.revision += 1
    #expect(!receipt.valid(for: mission, engine: commander.scriptState))
    commander.scriptState.instances[id] = mission
    #expect(!NativeWayfarerInductionSave.validateClaims(commander))
    commander = f.commander
    commander.scriptState.instances[f.f.f.booking.instance] = nil
    mission = try #require(commander.scriptState.instances[id])
    #expect(!receipt.valid(for: mission, engine: commander.scriptState))
    commander = f.commander
    commander.scriptState.savedClueJournal = nil
    #expect(!NativeWayfarerInductionSave.validateClaims(commander))
    commander = f.commander
    commander.scriptState.instances[id]?.acknowledgedThrough = 310
    #expect(!NativeWayfarerInductionSave.validateClaims(commander))
    var ordinary = ScriptInstance(
      id: UUID(), definition: "l337.other/ordinary",
      version: "1.0.0", digest: String(repeating: "a", count: 64))
    ordinary.outcome = .complete
    ordinary.revision = 1
    ordinary.acknowledge(1)
    let cause = InductionAccreditationFixture.context(f.commander, dock: f.f.dock, revision: 0)
    let committed = InductionAccreditationFixture.context(f.commander, dock: f.f.dock, revision: 1)
    let generic = ScriptCompletionReceipt(
      instance: ordinary.id, definition: ordinary.definition,
      version: ordinary.version, digest: ordinary.digest, outcome: .complete, sequence: 1,
      causeKind: "mission.receipted", cause: cause, committed: committed, revision: 1,
      milestones: [], destroyedEncounters: [], deliveredParties: [], returnedEquipment: [],
      settlementAmount: nil, choices: nil)
    #expect(generic.valid(for: ordinary, engine: f.commander.scriptState))
    ordinary.revision = 2
    #expect(!generic.valid(for: ordinary, engine: f.commander.scriptState))

  }

  @Test func wrongOwningSourceOperationRewardAndOriginalProofCannotBecomeACompletionClue() throws {
    let f = try InductionAccreditationFixture()
    let mission = try #require(f.commander.scriptState.instances[f.previous.id])
    let original = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(mission.completionReceipt))
        as? [String: Any])
    for (key, value): (String, Any) in [
      ("definition", "l337.other/other"), ("digest", String(repeating: "0", count: 64)),
      ("revision", mission.revision + 1), ("sequence", 310),
    ] {
      var raw = original
      raw[key] = value
      let receipt = try JSONDecoder().decode(
        ScriptCompletionReceipt.self, from: JSONSerialization.data(withJSONObject: raw))
      #expect(!receipt.valid(for: mission, engine: f.commander.scriptState))
    }
    var raw = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(f.terminal)) as? [String: Any])
    raw["creditsAfter"] = f.terminal.creditsBefore + 7600
    let wrongAmount = try JSONDecoder().decode(
      NativeInductionAccreditation.self, from: JSONSerialization.data(withJSONObject: raw))
    #expect(!wrongAmount.valid(parent: try #require(f.previous.savedWayfarerInduction)))
    raw = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(f.terminal)) as? [String: Any])
    raw["certification"] = f.f.f.booking.operation.uuidString
    let wrongProof = try JSONDecoder().decode(
      NativeInductionAccreditation.self, from: JSONSerialization.data(withJSONObject: raw))
    #expect(!wrongProof.valid(parent: try #require(f.previous.savedWayfarerInduction)))
  }

  @Test func terminalFormatsCloseTheNativeProofAndKeepEarlierSchemasAndUnknownRefusalsDistinct()
    throws
  {
    let f = try InductionAccreditationFixture()
    let mission = try #require(f.commander.scriptState.instances[f.previous.id])
    let raw = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(mission)) as? [String: Any])
    let bytes = try JSONSerialization.data(withJSONObject: [
      "instances": [mission.id.uuidString: raw]
    ])
    for schema in [125, 126] {
      try NativeInductionCrewLogSave.validateFields(bytes, part: .missions, schema: schema)
      try NativeWayfarerInductionSave.validateFields(
        bytes, part: .missions, schema: NativeInductionArkSave.lowerSchema(schema))
    }
    for schema in [119, 120, 121, 122, 123, 124] {
      #expect(throws: (any Error).self) {
        try NativeInductionCrewLogSave.validateFields(bytes, part: .missions, schema: schema)
      }
    }
    var changed = raw
    var parent = try #require(raw["savedWayfarerInduction"] as? [String: Any])
    var terminal = try #require(parent["accreditation"] as? [String: Any])
    terminal["extraPayment"] = 76000
    parent["accreditation"] = terminal
    changed["savedWayfarerInduction"] = parent
    let unknown = try JSONSerialization.data(withJSONObject: [
      "instances": [mission.id.uuidString: changed]
    ])
    #expect(throws: (any Error).self) {
      try NativeWayfarerInductionSave.validateFields(
        unknown, part: .missions, schema: NativeInductionArkSave.lowerSchema(125))
    }
    let embedded = try JSONSerialization.data(withJSONObject: [
      "savedScriptState": ["instances": [mission.id.uuidString: raw]]
    ])
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(embedded, part: .commander, schema: 125)
    }
    #expect(NativeInductionArkSave.isAlien(124) && NativeInductionArkSave.isAlien(126))
  }

  @Test func finalHelpAndOrdinaryServicePathsKeepTheirExistingLimitsAndNoPrematureEntitlement()
    throws
  {
    let f = try InductionNetworkFixture()
    var game = Game()
    game.commander = try f.commander()
    game.screen = .contracts
    #expect(!game.hasWayfarerAccreditation)
    game.contractBoard.rows = [
      .init(
        board: NativeWayfarerInductionAction.accredit.key, offer: nil,
        title: NativeWayfarerInductionAction.accredit.title, reason: nil,
        wayfarerInduction: .accredit)
    ]
    let page = try #require(PlayerHelp.pages(for: game).first)
    #expect(
      page.title == "SENN FINAL ACCREDITATION" && page.rows.contains { $0.contains("GLOBAL3") })
    let incomplete = try #require(game.wayfarerInductionMission)
    #expect(
      incomplete.outcome == .active && incomplete.savedWayfarerInduction?.accreditation == nil)
    #expect(game.inductionAccreditationRows.count == 1)
  }
}
