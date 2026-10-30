import Foundation
import Testing

@testable import L337Core

struct OriginalSealedDispatchFixture {
  let files: ScriptFreightFixture
  let pack: ScriptPack
  var save: URL { files.save }
  init() throws {
    files = try ScriptFreightFixture()
    pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledSealedDispatchDirectory)
  }
  func runtime(escapeReady: Bool = false, defaults: Bool = false) async throws -> GameRuntime {
    var game = try ScriptProcurementFixture.freshG03FlightGame(escapeReady: escapeReady)
    try game.prepareG03FlightEquipment()
    if escapeReady {
      let pod = try #require(Equipment.all.first { $0.name == "Escape Pod" })
      try #require(try game.applyEquipmentPurchase(game.quoteEquipmentPurchase(pod)))
    }
    game.scriptPacks = defaults ? [] : [pack]
    let runtime = GameRuntime(game: game, saveURL: save)
    try await runtime.save(to: save)
    if defaults {
      let errors = await runtime.loadDefaultScriptPacks(
        directory: files.root.appendingPathComponent("installed"))
      try #require(errors.isEmpty)
    }
    await runtime.key("0")
    try await dock(runtime)
    return runtime
  }
  // Near-door framing supplies no station/journey receipt. Real swept entry mints the dock proof.
  func dock(_ runtime: GameRuntime) async throws {
    // End the preceding work approach through its real release and braking controls.
    // Near-door framing must not leave a different controller driving the attained sweep.
    let arriving = await runtime.snapshot()
    if arriving.workGuidance != nil || arriving.workBraking != nil {
      await runtime.key("q")
    }
    var braking = Controls()
    braking.throttle = -1
    await runtime.setControls(braking)
    for _ in 0..<100 {
      if await runtime.snapshot().flightWorldVelocity == Vector3(0, 0, 0) { break }
      _ = await runtime.advance(delta: 0.05)
    }
    await runtime.setControls(Controls())
    let stopped = await runtime.snapshot()
    try #require(stopped.workGuidance == nil && stopped.workBraking == nil)
    try #require(stopped.flightWorldVelocity == Vector3(0, 0, 0))
    await runtime.nativeCommand { game in
      guard let station = game.bodies.first(where: { $0.id == 0 && $0.hull == .station }) else {
        return
      }
      let old = game.commander.flightSimulation.pose
      var pose = ShipPose()
      pose.position = old.systemPoint(station.entrancePosition + station.entranceNormal * 2)
      pose.orientation.y = old.orientation.apply(station.entranceUp)
      pose.orientation.z = old.orientation.apply(station.entranceNormal) * -1
      pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
      NativeStationTestFixture.reframe(&game, to: pose)
      game.speed = 3
      for _ in 0..<100 where !game.docked { game.tick(delta: 0.1) }
    }
    let game = await runtime.snapshot()
    try #require(game.docked && game.nativeMainStationDockEvidenceIsCurrent)
  }
  func offer(_ runtime: GameRuntime, index: Int = 0) async throws -> (String, ScriptContractOffer) {
    let key = try await runtime.generateContractBoard(packDigest: pack.digest)
    return (
      key, try #require(await runtime.snapshot().commander.contracts.boards[key]?.offers[index])
    )
  }
  func accept(_ runtime: GameRuntime, index: Int = 0) async throws -> UUID {
    let (key, offer) = try await offer(runtime, index: index)
    let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
    try #require(quote.allowed, "\(quote.issues)")
    return try await runtime.confirmContract(quote)
  }
  func travel(_ runtime: GameRuntime, path: [Int]) async throws {
    for destination in path.dropFirst() {
      await runtime.key("escape")
      await runtime.key("0")
      await runtime.nativeCommand { game in
        // Clear the departure geometry only; native H/countdown owns system, fuel and calendar.
        var pose = game.commander.flightSimulation.pose
        pose.position = pose.position + pose.orientation.x * 20_000
        NativeStationTestFixture.reframe(&game, to: pose)
      }
      let game = await runtime.snapshot()
      await runtime.selectSystem(
        x: Double(game.systems[destination].x), y: Double(game.systems[destination].y))
      await runtime.key("h")
      try #require(await runtime.snapshot().jumpCountdown != nil)
      for _ in 0..<200 {
        if await runtime.snapshot().jumpCountdown == nil { break }
        _ = await runtime.advance(delta: 0.1)
      }
      try #require(await runtime.snapshot().commander.system == destination)
      try await dock(runtime)
      if destination != path.last { await runtime.procurementRefuel() }
    }
  }
  func contact(_ runtime: GameRuntime, action: String) async throws {
    await runtime.key("contacts-open")
    try #require(await runtime.snapshot().courierContactActionLabel == action)
  }
  func confirm(_ runtime: GameRuntime) async {
    if await runtime.snapshot().scriptConfirmSelected == false { await runtime.key("left") }
    await runtime.key("return")
  }
}

struct OriginalSealedDispatchNativeTests {
  @Test func closedDispatchPlanKeepsSixDrawsThreeOddRowsAndAuthoredUntimedTerms() async throws {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    #expect(
      fixture.pack.digest == "93289d5daf873d0cf878b37fa55178e4ab91cf6fa1947f379a54c3bc04267ae7")
    #expect(OriginalSealedDispatch.validManifest(fixture.pack.manifest))
    let runtime = try await fixture.runtime()
    let (key, _) = try await fixture.offer(runtime)
    let game = await runtime.snapshot()
    let board = try #require(game.commander.contracts.boards[key])
    let generation = try #require(board.courierGeneration)
    #expect(
      board.valid && generation.valid && generation.draws.count == 6
        && generation.indices.count == 6)
    #expect(board.offers.compactMap { $0.courier?.row } == [1, 3, 5])
    for offer in board.offers {
      let terms = try #require(offer.courier)
      #expect(terms.variant == .package && terms.duration == 0)
      #expect(terms.reward == (320 + 90 * (terms.path.count - 1)) * 10)
      #expect(terms.generation == generation && terms.valid && terms.matches(offer))
      #expect(ScriptCourierPreview(terms: terms).summary.contains("H0 | Untimed"))
    }
    let before = game.commander
    #expect(try await runtime.generateContractBoard(packDigest: fixture.pack.digest) == key)
    #expect(await runtime.snapshot().commander == before)
    for (index, pair) in [
      ("original-sealed-dispatch", "other-profile"),
      (#"exclusiveGroup = "sealed-dispatch""#, #"exclusiveGroup = "g02-courier""#),
      (#"id = "sealed-dispatch""#, #"id = "foreign-dispatch""#),
    ].enumerated() {
      let folder = fixture.files.root.appendingPathComponent("invalid-\(index)")
      try FileManager.default.copyItem(
        at: ScriptPackLibrary.bundledSealedDispatchDirectory, to: folder)
      let url = folder.appendingPathComponent("manifest.toml")
      try String(contentsOf: url, encoding: .utf8).replacingOccurrences(of: pair.0, with: pair.1)
        .write(to: url, atomically: true, encoding: .utf8)
      #expect(throws: (any Error).self) { try ScriptPackLibrary.read(folder) }
    }
  }

  @Test(arguments: [0, 1, 2])
  func dispatchNativeIssuanceActualTravelReceptionAndReplayPayOnlyOriginal(index: Int) async throws
  {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let id = try await fixture.accept(runtime, index: index)
    let accepted = await runtime.snapshot()
    let original = try #require(accepted.commander.scriptState.instances[id])
    let terms = try #require(original.contract?.offer.courier)
    #expect(original.contract?.deadline == nil && original.contract?.offer.duration == 0)
    #expect(original.courier?.item == ScriptCourierCustody.itemIdentity(id))
    #expect(
      accepted.commander.cargoTonnes == 1 && accepted.commander.scriptState.savedClueJournal == nil)
    try await fixture.travel(runtime, path: terms.path)
    let arrived = await runtime.snapshot()
    #expect(
      arrived.commander.scriptState.clock(.missionCalendar) > original.contract!.acceptedAt
        + terms.calendarLowerBoundSeconds)
    try await fixture.contact(runtime, action: "Deliver")
    let before = await runtime.snapshot()
    await runtime.key("return")  // Back is the initial selection.
    #expect(await runtime.snapshot().commander == before.commander)
    try await fixture.contact(runtime, action: "Deliver")
    await fixture.confirm(runtime)
    let done = await runtime.snapshot()
    let state = try #require(done.commander.scriptState.instances[id])
    #expect(state.outcome == .complete && state.courier?.terminal?.item == original.courier?.item)
    #expect(
      state.courier?.terminal?.amount == terms.reward
        && done.commander.credits == before.commander.credits + terms.reward)
    #expect(done.commander.cargoTonnes == 0 && done.commander.valid)
    #expect(
      done.commander.scriptState.savedClueJournal?.awards[OriginalSealedDispatch.stateID]?.clueID
        == "sealed-dispatch-family-trace")
    var replay = done
    replay.emitScriptEvent("dialogue.confirmed", only: id)
    #expect(replay.commander.credits == done.commander.credits)
    #expect(
      replay.commander.scriptState.savedClueJournal == done.commander.scriptState.savedClueJournal)
    try await runtime.save(to: fixture.save)
    try await runtime.load(from: fixture.save, persistMigrations: false)
    #expect(await runtime.snapshot().commander == done.commander)
  }

  @Test func dispatchNilDeadlineSurvivesLateCalendarAndRejectsForeignRowsItemsAndExpiry()
    async throws
  {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    let id = try await fixture.accept(runtime)
    let terms = try #require(
      await runtime.snapshot().commander.scriptState.instances[id]?.contract?.offer.courier)
    try await fixture.travel(runtime, path: terms.path)
    // Controlled boundary semantics on a genuinely travelled snapshot, not elapsed-flight evidence.
    await runtime.nativeCommand { game in
      let late = game.commander.scriptState.clock(.missionCalendar) + 259201
      game.commander.scriptState.calendarSeconds = late
      game.commander.scriptState.missionCalendar?.seconds = late
      game.resolveCourierTerminals()
    }
    let late = await runtime.snapshot()
    let state = try #require(late.commander.scriptState.instances[id])
    #expect(state.outcome == .active && state.courier?.terminal == nil && late.commander.valid)
    let custody = try #require(state.courier)
    for field in ["row", "profile", "item", "deadline"] {
      var object = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
      var job = try #require(object["contract"] as? [String: Any])
      var offer = try #require(job["offer"] as? [String: Any])
      var courier = try #require(offer["courier"] as? [String: Any])
      if field == "row" { courier["row"] = 0 }
      if field == "profile" {
        var declaration = try #require(courier["declaration"] as? [String: Any])
        declaration["profile"] = "PROJECT-SPACE-G02-1"
        courier["declaration"] = declaration
      }
      if field == "deadline" { job["deadline"] = 999999999999.0 }
      if field == "item" {
        var held = try #require(object["courier"] as? [String: Any])
        held["item"] = UUID().uuidString
        object["courier"] = held
      }
      offer["courier"] = courier
      job["offer"] = offer
      object["contract"] = job
      let forged = try JSONDecoder().decode(
        ScriptInstance.self, from: JSONSerialization.data(withJSONObject: object))
      #expect(
        !forged.contract!.valid
          || !forged.courier!.valid(state: forged, engine: late.commander.scriptState))
    }
    var expired = state
    var job = try #require(expired.contract)
    job.settled = true
    job.settlementOutcome = .failed
    job.settlementAmount = 0
    job.settledAt = late.commander.scriptState.clock(.missionCalendar)
    expired.contract = job
    expired.outcome = .failed
    expired.courier = .init(
      item: custody.item, issue: custody.issue,
      terminal: .init(
        id: ScriptCourierCustody.terminalIdentity(custody.item), item: custody.item,
        cause: .expired,
        proof: late.courierProof(token: "native:expired", revision: state.revision), amount: 0))
    #expect(!expired.courier!.valid(state: expired, engine: late.commander.scriptState))
    try await fixture.contact(runtime, action: "Deliver")
    await fixture.confirm(runtime)
    #expect(await runtime.snapshot().commander.scriptState.instances[id]?.outcome == .complete)
  }

  @Test(arguments: ["abandon", "escape", "fatal"])
  func dispatchNativeLossConsumesOriginalWithoutPaymentOrClue(mode: String) async throws {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime(escapeReady: mode == "escape")
    let id = try await fixture.accept(runtime)
    let before = await runtime.snapshot()
    let item = before.commander.scriptState.instances[id]?.courier?.item
    if mode == "abandon" {
      try await fixture.contact(runtime, action: "Abandon")
      await fixture.confirm(runtime)
    } else {
      await runtime.key("0")
      if mode == "escape" {
        await runtime.key("escape-pod")
      } else {
        await runtime.nativeCommand { game in
          game.speed = 0
          game.bodies = []
          game.celestials = []
          game.cabinTemperature = 0.99
          game.celestials = [.init(kind: .sun, position: .init(0, 0, 1500), radius: 1100)]
        }
        _ = await runtime.advance(delta: 0.1)
      }
    }
    let lost = await runtime.snapshot()
    let state = try #require(lost.commander.scriptState.instances[id])
    #expect(state.courier?.terminal?.item == item && state.courier?.terminal?.amount == 0)
    #expect(
      state.courier?.terminal?.cause
        == (mode == "abandon" ? .abandoned : mode == "escape" ? .escapePod : .shipDestroyed))
    #expect(lost.commander.cargoTonnes == 0 && lost.commander.credits == before.commander.credits)
    #expect(lost.commander.scriptState.savedClueJournal == nil && lost.commander.valid)
    var retry = lost
    retry.resolveCourierTerminals()
    #expect(retry.commander == lost.commander)
    if mode == "abandon" {
      let newID = try await fixture.accept(runtime, index: 1)
      let next = await runtime.snapshot()
      #expect(newID != id && next.commander.scriptState.instances[newID]?.courier?.item != item)
    }
  }
  @Test(arguments: [172800.0, 259200.0], [false, true])
  func currentNativeLegacyCourierKeepsInclusiveDeadlineAndStrictExpiry(duration: Double, late: Bool)
    async throws
  {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledCourierDirectory)
    let declaration = try #require(pack.manifest.courier)
    var initial = try ScriptProcurementFixture.freshG03FlightGame()
    try initial.prepareG03FlightEquipment()
    initial.scriptPacks = [pack]
    // Pick an initial scene with an admissible genuine quote, never rewrite a generated plan.
    // The real runtime below is initialized and physically docked before its board freezes.
    var selected: (origin: Int, row: Int)?
    for origin in 0..<256 {
      var commander = initial.commander
      commander.system = origin
      let station = ContractStationIdentity(galaxy: 0, system: origin, stationClass: "main-orbital")
      let key = pack.digest + "/" + pack.manifest.board!.id + "/" + station.key
      let seed = try #require(Game.pledgeBoardSeed(key, revision: 0))
      guard
        let generation = try? ScriptCourierGeneration(
          origin: station, commander: commander, seed: seed)
      else { continue }
      if let row = (0..<6).first(where: {
        let terms = generation.terms(declaration, row: $0)
        return terms.duration == duration && terms.calendarLowerBoundSeconds + 1200 < duration
      }) {
        selected = (origin, row)
        break
      }
    }
    let source = try #require(selected)
    initial.commander.system = source.origin
    initial.selectedSystem = source.origin
    initial.market = MarketItem.at(initial.currentSystem)
    let runtime = GameRuntime(game: initial, saveURL: fixture.save)
    try await runtime.save(to: fixture.save)
    await runtime.key("0")
    try await fixture.dock(runtime)
    let key = try await runtime.generateContractBoard(packDigest: pack.digest)
    let frozen = try #require(await runtime.snapshot().commander.contracts.boards[key])
    let offer = frozen.offers[source.row]
    let terms = try #require(offer.courier)
    #expect(frozen.valid && frozen.offers.count == 6 && frozen.courierGeneration?.draws.count == 6)
    #expect(frozen.offers.compactMap { $0.courier?.row } == Array(0..<6))
    #expect(terms.duration == duration && !OriginalSealedDispatch.matches(terms.declaration))
    let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
    try #require(quote.allowed, "\(quote.issues)")
    let id = try await runtime.confirmContract(quote)
    let accepted = try #require(await runtime.snapshot().commander.scriptState.instances[id])
    let due = try #require(accepted.contract?.deadline)
    #expect(due == accepted.contract!.acceptedAt + duration && accepted.courier != nil)
    try await fixture.travel(runtime, path: terms.path)
    let arrived = await runtime.snapshot()
    try #require(arrived.commander.scriptState.clock(.missionCalendar) < due)
    let ledger = try #require(arrived.commander.scriptState.calendarLedger)
    try #require(ledger.pendingJourney == nil)
    let operation = try #require(arrived.commander.scriptState.missionCalendar?.lastNativeOperation)
    #expect(operation == ledger.operation)
    // Controlled deadline-policy clock on a genuinely travelled and docked snapshot.
    // Preserve calendar offset and native operation ledger; this is not elapsed-flight evidence.
    await runtime.nativeCommand { game in
      let target = due + (late ? 0.1 : 0)
      let delta = target - game.commander.scriptState.clock(.missionCalendar)
      game.commander.scriptState.calendarSeconds += delta
      game.commander.scriptState.missionCalendar?.seconds = target
      game.resolveCourierTerminals()
    }
    let boundary = await runtime.snapshot()
    #expect(boundary.commander.scriptState.calendarLedger == ledger)
    #expect(boundary.commander.scriptState.missionCalendar?.lastNativeOperation == operation)
    #expect(boundary.commander.valid)
    if late {
      let expired = try #require(boundary.commander.scriptState.instances[id])
      #expect(expired.outcome == .failed && expired.courier?.terminal?.cause == .expired)
      #expect(expired.contract?.settlementAmount == 0 && expired.courier?.terminal?.amount == 0)
      #expect(boundary.commander.credits == arrived.commander.credits)
    } else {
      #expect(boundary.commander.scriptState.instances[id]?.outcome == .active)
      try await fixture.contact(runtime, action: "Deliver")
      await fixture.confirm(runtime)
      let delivered = await runtime.snapshot()
      let state = try #require(delivered.commander.scriptState.instances[id])
      #expect(state.outcome == .complete && state.courier?.terminal?.proof.clock == due)
      #expect(delivered.commander.credits == arrived.commander.credits + terms.reward)
      #expect(delivered.commander.valid)
    }
  }
}
