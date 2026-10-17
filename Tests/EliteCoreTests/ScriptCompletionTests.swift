import Foundation
import Testing

@testable import EliteCore

private func boundedActualLedgerFacts<T: Encodable>(_ value: T, collection: String) -> String {
  guard let bytes = try? JSONEncoder().encode(value),
    let object = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
    let records = object[collection] as? [Any],
    let selected = try? JSONSerialization.data(
      withJSONObject: Array(records.suffix(8)), options: .sortedKeys),
    let text = String(data: selected, encoding: .utf8)
  else { return "unavailable" }
  return String(text.prefix(12000))
}

// Read-only, bounded facts from the actual station and controller; no scene repair or extra input.
func actualStationGuidanceDiagnostic(_ game: Game) -> String {
  let control = game.autoPilot
  let context = game.gameplayContext()
  let station = game.bodies.first { $0.id == 0 && $0.hull == .station }
  let capabilities = game.workTargetCapabilities
  var facts = [
    "context=\(String(describing: context?.system))/\(String(describing: context?.visit))",
    "anchor=\(String(describing: context?.anchors.station.identity))",
    "filter=\(game.workTargetFilter.label),core=\(String(describing: capabilities.core))",
    "target=\(String(describing: control.targetID)),targetActor=\(String(describing: control.targetActor))",
    "status=\(control.status),ready=\(control.ready),final=\(control.finalApproach),manual=\(control.manualEngagement)",
    "velocity=\(control.velocity),rollRate=\(control.rollRate),speed=\(game.speed)",
    "errors=position:\(control.positionError),facing:\(control.facingError),phase:\(control.phaseError),rate:\(control.rateError)",
    "rates=\(game.pitch)/\(game.yaw)/\(game.roll),time=\(game.time),physicalTime=\(game.commander.flightSimulation.physicalTime)",
    "paused=\(game.paused),screen=\(game.screen),docked=\(game.docked)/\(game.dockedAtMainStation),energy=\(game.energy)",
    "legal=\(game.commander.legal),shields=\(game.frontShield)/\(game.rearShield),security=\(game.commander.stationSecurity.phase)",
    "docking=\(game.dockingComputer),hardware=\(game.commander.hasAutomaticDocking),targeting=\(game.targetingEnabled)",
    "work=\(game.workGuidance != nil)/\(game.workBraking != nil),manualResidual=\(game.manualResidualFlight)",
    "limits=\(game.workLimits),message=\(game.message)",
  ]
  let police = game.bodies.filter { $0.energy > 0 && $0.physical?.npc?.role == .police }
  facts += [
    "policeCount=\(police.count),police=["
      + police.prefix(8).map {
        "id=\($0.id),actor=\(String(describing: $0.physical?.identity)),HP=\($0.energy),hostile=\($0.hostile),firstAggressor=\(String(describing: $0.physical?.npc?.firstAggressor)),intention=\(String(describing: $0.physical?.npc?.intention))"
      }.joined(separator: " | ") + "]"
  ]
  facts += [
    "actualAttacks=" + boundedActualLedgerFacts(game.commander.crimeLedger, collection: "attacks"),
    "actualThreats="
      + boundedActualLedgerFacts(game.commander.stationSecurity, collection: "threats"),
    "liveOrdnance=["
      + game.bodies.filter {
        $0.energy > 0 && ($0.scriptShot != nil || $0.physical?.ordnance != nil)
      }.prefix(8).map {
        "id=\($0.id),shot=\(String(describing: $0.scriptShot?.identity)),shotOwner=\(String(describing: $0.scriptShot?.owner)),nativeOwner=\(String(describing: $0.physical?.attackOrigin?.owner)),position=\($0.position)"
      }.joined(separator: " | ") + "]",
  ]
  guard let station else { return (facts + ["station=missing"]).joined(separator: "; ") }
  let model = game.modelPose(of: station)
  let speed = max(game.speed * 18, control.velocity.length)
  let door = station.entrancePosition
  let toPlayer = door * -1
  let normal = station.entranceNormal
  let up = station.entranceUp
  let side = station.modelVector(.init(1, 0, 0))
  facts += [
    "stationActor=\(String(describing: station.physical?.identity)),HP=\(station.energy)",
    "position=\(station.position),distance=\(station.position.length),rotation=\(station.rotation),spin=\(station.rotationRate)",
    "bodyBasisValid=\(station.orientation.validRotation),modelBasisValid=\(model.orientation.validRotation),modelPosition=\(model.position)",
    "door=\(door),normal=\(normal),up=\(up),stagingGoal=\(door + normal * 1000)",
    "doorErrors=x:\(toPlayer.dot(side)),y:\(toPlayer.dot(up)),depth:\(toPlayer.dot(normal)),entrySpeed=\(speed)",
    "containsPlayer=\(station.containsPlayer),canEnter=\(station.canEnter(roll: game.roll, speed: speed))",
    "samePhysicalIDs=\(game.bodies.filter { $0.physical?.identity == station.physical?.identity }.prefix(16).map(\.id))",
  ]
  if let context {
    let layout = CockpitLayout(game: game, width: game.viewportWidth, height: game.viewportHeight)
    let visible = Display.visibleInFront(station, game: game, layout: layout)
    if let candidate = game.workTargetCandidate(
      for: station, context: context, frontVisible: visible)
    {
      let decision = WorkTargetSelection.evaluate(
        candidate, system: context.system, visit: context.visit, capabilities: capabilities)
      let filtered = WorkTargetSelection.ordered(
        [candidate], filter: game.workTargetFilter, system: context.system, visit: context.visit,
        capabilities: capabilities)
      facts += [
        "stationVisible=\(visible),candidate=\(candidate),decision=\(decision),filterIncludes=\(!filtered.isEmpty)"
      ]
    } else {
      facts += ["stationVisible=\(visible),candidate=missing"]
    }
  }
  return facts.joined(separator: "; ")
}

@Test func loadingAnotherActualCommanderStartsANewStationTargetCycleEvenWithTheSameVisitTuple()
  throws
{
  var first = Commander()
  try first.prepareEquipment(legacy: false)
  try first.grantEquipment(
    TargetingTier.docking.equipmentName, at: .targetingCore,
    provenance: .grant("first cycle commander"))
  var game = Game(executive: false)
  let loadedFirst = game.load(first)
  try #require(loadedFirst)
  game.launch()
  for _ in 0...game.bodies.count {
    game.key("r")
    if game.autoTargetBody?.id == 0 { break }
  }
  try #require(game.autoTargetBody?.id == 0 && game.dockingComputer)
  let firstOrigin = try #require(game.gameplayContext()?.player.identity)
  var second = Commander()
  try second.prepareEquipment(legacy: false)
  try second.grantEquipment(
    TargetingTier.docking.equipmentName, at: .targetingCore,
    provenance: .grant("second cycle commander"))
  try #require(first.equipmentOwnerID != second.equipmentOwnerID)
  let loadedSecond = game.load(second)
  try #require(loadedSecond)
  #expect(game.autoPilot.targetID == nil && game.autoPilot.status == "OFF")
  game.launch()
  try #require(game.gameplayContext()?.player.identity == firstOrigin)
  var selected: [Int] = []
  for _ in 0...game.bodies.count {
    game.key("r")
    if let target = game.autoPilot.targetID, selected.count < 16 { selected.append(target) }
    if game.autoTargetBody?.id == 0 { break }
  }
  #expect(
    game.autoTargetBody?.id == 0 && game.dockingComputer,
    Comment(
      rawValue: "actual new Commander cycle=\(selected); " + actualStationGuidanceDiagnostic(game)))
}

private func fitCompletionPatrolTargeting(_ game: inout Game) throws {
  let before = game.commander
  try game.commander.grantEquipment(
    TargetingTier.docking.equipmentName, at: .targetingCore, provenance: .legacyUnknown)
  try #require(game.commander.hasAutomaticDocking)
  #expect(
    game.commander.fittedEquipment(at: .targetingCore)?.node.key
      == TargetingTier.docking.equipmentName)
  #expect(game.commander.credits == before.credits && game.commander.cargo == before.cargo)
  #expect(game.commander.scriptState == before.scriptState)
  #expect(
    game.commander.contracts == before.contracts
      && game.commander.accommodation == before.accommodation)
  #expect(game.commander.laser(on: .front) == before.laser(on: .front))
  #expect(
    game.commander.laserDamage(against: .sidewinder, mount: .front)
      == before.laserDamage(against: .sidewinder, mount: .front))
}

private func completionPatrolTargetIsOwned(_ game: Game, child: UUID) -> Bool {
  guard let body = game.autoTargetBody, body.energy > 0, body.missionInstanceID == child,
    let identity = body.missionActorID,
    let encounter = game.commander.scriptState.instances[child]?.ownedEncounters["raiders"]
  else { return false }
  return encounter.actors.values.contains {
    $0.identity == identity && $0.presence != .destroyed
  }
}

private func selectCompletionPatrolTarget(_ game: inout Game, child: UUID) throws {
  for _ in 0...game.bodies.count {
    if completionPatrolTargetIsOwned(game, child: child) { return }
    game.key("r")
  }
  try #require(
    completionPatrolTargetIsOwned(game, child: child),
    Comment(rawValue: campaignPatrolDiagnostic(game, child: child)))
}

private struct CompletionFixture {
  let root: URL
  let child: ScriptPack
  let parent: ScriptPack
  init(
    stage: String = "completion", digest: String? = nil, outcome: String = "complete",
    allowedOutcomes: [String]? = nil, childID: String? = nil, failedChild: Bool = false
  ) throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "native-completion-" + UUID().uuidString)
    let examples = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
        "docs/mission-packs")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    var childFolder = examples.appendingPathComponent("scripted-patrol")
    if childID != nil || failedChild {
      let local = root.appendingPathComponent("child")
      try FileManager.default.copyItem(at: childFolder, to: local)
      if let childID {
        let file = local.appendingPathComponent("manifest.toml")
        let text = try String(contentsOf: file, encoding: .utf8)
        try text.replacingOccurrences(of: "example.scripted-patrol", with: childID)
          .write(to: file, atomically: true, encoding: .utf8)
      }
      if failedChild {
        let file = local.appendingPathComponent("scripts/main.lua")
        let text = try String(contentsOf: file, encoding: .utf8)
        try text.replacingOccurrences(of: "outcome='complete'", with: "outcome='failed'")
          .replacingOccurrences(of: "amount=1000", with: "amount=0")
          .replacingOccurrences(
            of: "Paid 100 credits.", with: "Recorded failed report without payment."
          )
          .write(to: file, atomically: true, encoding: .utf8)
      }
      childFolder = local
    }
    child = try ScriptPackLibrary.read(childFolder)
    let outcomeRule =
      allowedOutcomes.map {
        "outcomes=[" + $0.map { "\"" + $0 + "\"" }.joined(separator: ",") + "]"
      } ?? "outcome=\"\(outcome)\""
    let folder = root.appendingPathComponent("parent")
    try FileManager.default.copyItem(
      at: examples.appendingPathComponent("scripted-courier"), to: folder)
    try """
    schemaVersion=2
    missionAPI=2
    id="test.receipt-parent"
    version="1.0.0"
    minimumEngine="2.0.0"
    capabilities=["script-lua-v1","story-v2","economy-v2","completion-receipts-v2"\(allowedOutcomes == nil ? "" : ",\"compound-receipts-v2\"")]
    priority=700
    source="Original linked mission test."
    license="MIT"
    environments=["space","orbital-station"]
    module="scripts/main.lua"
    [mission]
    id="report"
    title="Linked patrol report"
    briefing="Report after the actual patrol is complete."
    destination="Lave orbital station"
    reward="10 credits"
    milestones=["Report"]
    [[receiptRequirements]]
    id="patrol"
    stage="\(stage)"
    definition="\(child.manifest.stateID)"
    version="\(child.manifest.version)"
    digest="\(digest ?? child.digest)"
    \(outcomeRule)
    minimumCount=1
    [[handlers]]
    event="mission.accepted"
    function="accepted"
    [[handlers]]
    event="contact.requested"
    function="contact"
    [[handlers]]
    event="mission.receipted"
    function="receipted"
    """.write(to: folder.appendingPathComponent("manifest.toml"), atomically: true, encoding: .utf8)
    try """
    return {
      accepted=function(e,w,d) return {data={notifications=0},commands={}} end,
      contact=function(e,w,d)
        d.attempted=true
        return {data=d,commands={{op='credits',id='pay',amount=100},
          {op='milestone.ensure',index=0},{op='mission.finish',outcome='complete'}}}
      end,
      receipted=function(e,w,d)
        d.notifications=d.notifications+1
        d.child=e.receipt_instance_id
        d.proof=w.receipt_requirements.patrol.satisfied
        return {data=d,commands={}}
      end
    }
    """.write(
      to: folder.appendingPathComponent("scripts/main.lua"), atomically: true, encoding: .utf8)
    parent = try ScriptPackLibrary.read(folder)
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
  func game() -> Game {
    var game = Game(executive: false)
    game.screen = .status
    do { try fitCompletionPatrolTargeting(&game) } catch { Issue.record(error) }
    game.scriptPacks = [child, parent]
    return game
  }
  func completePatrol(_ game: inout Game, report: Bool = true, expected: ScriptOutcome = .complete)
    throws -> UUID
  {
    try fitCompletionPatrolTargeting(&game)
    let id = try game.acceptScriptMission(child)
    game.launch()
    game.emitScriptEvent("station.undocked")
    let legalBefore = game.commander.legal
    try #require(legalBefore == 0)
    let beforeFire = campaignPatrolDiagnostic(game, child: id)
    var firing = Controls()
    for _ in 0..<200 {
      // Fly the original launch path and fire only at an actual owned hull outside the station zone.
      firing = Controls()
      if try campaignPatrolOutsideStationZone(game) {
        try selectCompletionPatrolTarget(&game, child: id)
        firing.fire = try campaignPatrolHasActualLaserContact(game, child: id)
      }
      game.tick(delta: 0.1, controls: firing)
      if game.commander.scriptState.instances[id]?.ownedEncounters["raiders"]?.destroyed == true {
        break
      }
    }
    #expect(
      game.commander.scriptState.instances[id]?.ownedEncounters["raiders"]?.destroyed == true,
      Comment(
        rawValue: "beforeFire: \(beforeFire); afterFire: "
          + campaignPatrolDiagnostic(game, child: id)))
    #expect(game.commander.legal == legalBefore)
    firing = Controls()
    let beforeStationSelection = actualStationGuidanceDiagnostic(game)
    var stationCycle: [String] = []
    // Sequential sorties retain more targets; cycle the actual scene rather than assuming eight.
    for attempt in 0...game.bodies.count {
      game.key("r")
      if stationCycle.count < 16 {
        stationCycle.append(
          "\(attempt):target=\(String(describing: game.autoPilot.targetID)),actor=\(String(describing: game.autoPilot.targetActor)),docking=\(game.dockingComputer)"
        )
      }
      if game.autoPilot.targetID == 0 { break }
    }
    try #require(
      game.autoTargetBody?.id == 0 && game.autoTargetBody?.hull == .station && game.dockingComputer,
      Comment(
        rawValue: "Original main station was not selected: "
          + campaignPatrolDiagnostic(game, child: id)
          + "; beforeSelection=" + beforeStationSelection
          + "; cycle=[" + stationCycle.joined(separator: " | ") + "]"
          + "; afterSelection=" + actualStationGuidanceDiagnostic(game)))
    let beforeDock =
      campaignPatrolDiagnostic(game, child: id) + "; " + actualStationGuidanceDiagnostic(game)
    for _ in 0..<5000 where !game.docked { game.tick(delta: 0.02, controls: firing) }
    #expect(
      game.docked && game.dockedAtMainStation,
      Comment(
        rawValue: "afterStationSelection: \(beforeDock); afterDockFlight: "
          + campaignPatrolDiagnostic(game, child: id)
          + "; guidance=" + actualStationGuidanceDiagnostic(game)))
    #expect(game.commander.legal == legalBefore)
    if !report { return id }
    game.emitScriptEvent("contact.requested", only: id)
    let offered = game.showScriptDialogue()
    #expect(offered && game.scriptOffer == id)
    game.confirmScriptDialogue()
    #expect(game.commander.scriptState.instances[id]?.outcome == expected)
    return id
  }
}

@Test func actualPatrolCompletionJoinsParentOnceAcrossNativeSaveAndReload() async throws {
  let fixture = try CompletionFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let parent = try game.acceptScriptMission(fixture.parent)
  let child = try fixture.completePatrol(&game)
  game.drainScriptEvents()
  let proof = try #require(game.commander.scriptState.instances[child]?.completionReceipt)
  #expect(proof.destroyedEncounters == ["raiders"] && proof.causeKind == "dialogue.confirmed")
  #expect(proof.committed.mainStation && proof.committed.system == 7)
  #expect(proof.outcome == .complete && proof.milestones == [0, 1, 2])
  #expect(game.commander.scriptState.instances[parent]?.data["notifications"] == .integer(1))
  #expect(game.commander.scriptState.instances[parent]?.data["proof"] == .bool(true))
  let balance = game.commander.credits
  let runtime = GameRuntime(game: game)
  let save = fixture.root.appendingPathComponent("save/commander.json")
  try await runtime.save(to: save)
  let loaded = GameRuntime(game: fixture.game())
  try await loaded.load(from: save)
  await loaded.key("contacts-open")
  let finished = await loaded.snapshot()
  #expect(finished.commander.scriptState.instances[parent]?.outcome == .complete)
  #expect(finished.commander.scriptState.instances[parent]?.receiptJoins?["patrol"] == [child])
  #expect(finished.commander.credits == balance + 100)
  #expect(finished.commander.scriptState.instances[child]?.completionReceipt == proof)
  let (disk, _) = try ScriptSaveStore.read(Data(contentsOf: save), from: save)
  #expect(disk == finished.commander)
  await loaded.key("contacts-open")
  #expect(await loaded.snapshot().commander.credits == balance + 100)
}

@Test func installedChildFlagsAndCounterfeitDeathEventsCannotMintCompletionProof() throws {
  let fixture = try CompletionFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let parent = try game.acceptScriptMission(fixture.parent)
  let child = try game.acceptScriptMission(fixture.child)
  game.commander.scriptState.instances[child]?.data = .object(["complete": .bool(true)])
  game.emitScriptEvent("actor.destroyed", values: ["encounter_id": .string("raiders")], only: child)
  let balance = game.commander.credits
  game.emitScriptEvent("contact.requested", only: parent)
  let state = try #require(game.commander.scriptState.instances[parent])
  #expect(state.outcome == .active && state.suspension != nil && state.completionReceipt == nil)
  #expect(state.data["attempted"] == nil && state.milestones.isEmpty && state.receipts.isEmpty)
  #expect(game.commander.credits == balance && game.commander.valid)
}

@Test func exactContentAndOutcomeReceiptGatesBlockAcceptanceEvenWhenInstalled() throws {
  let fixture = try CompletionFixture(stage: "acceptance")
  let otherDigest = try CompletionFixture(
    stage: "acceptance", digest: String(repeating: "a", count: 64))
  let wrongOutcome = try CompletionFixture(stage: "acceptance", outcome: "failed")
  defer {
    fixture.clean()
    otherDigest.clean()
    wrongOutcome.clean()
  }
  var game = fixture.game()
  let before = game.commander
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(fixture.parent) }
  #expect(game.commander == before)
  let child = try fixture.completePatrol(&game)
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(otherDigest.parent) }
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(wrongOutcome.parent) }
  let parent = try game.acceptScriptMission(fixture.parent)
  #expect(game.commander.scriptState.instances[parent]?.receiptJoins?["patrol"] == [child])
  game.emitScriptEvent("contact.requested", only: parent)
  #expect(game.commander.scriptState.instances[parent]?.outcome == .complete)
  #expect(game.commander.scriptState.instances[parent]?.receiptJoins?["patrol"] == [child])
  #expect(game.commander.valid)
}

@Test func terminalLegacyFlagsAreNeverMigratedIntoNativeReceipts() throws {
  let fixture = try CompletionFixture(stage: "acceptance")
  defer { fixture.clean() }
  var game = fixture.game()
  let child = try game.acceptScriptMission(fixture.child)
  game.commander.scriptState.instances[child]?.outcome = .complete
  game.commander.scriptState.instances[child]?.milestones = [0, 1, 2]
  let data = try ScriptValueStorage.encoder().encode(game.commander.scriptState)
  game.commander.scriptState = try ScriptValueStorage.decoder(typed: true).decode(
    ScriptEngineState.self, from: data)
  #expect(game.commander.scriptState.instances[child]?.completionReceipt == nil)
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(fixture.parent) }
}

@Test func failedNativeReportPublicationCreatesNeitherPaymentNorChildReceipt() async throws {
  let fixture = try CompletionFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let child = try fixture.completePatrol(&game, report: false)
  let container = fixture.root.appendingPathComponent("save")
  let save = container.appendingPathComponent("commander.json")
  let backup = fixture.root.appendingPathComponent("backup")
  let runtime = GameRuntime(game: game, saveURL: save)
  await runtime.key("contacts-open")
  let before = await runtime.snapshot()
  let pointer = try Data(contentsOf: save)
  try FileManager.default.moveItem(at: container, to: backup)
  try Data("blocked".utf8).write(to: container)
  await runtime.key("return")
  let denied = await runtime.snapshot()
  #expect(denied.commander == before.commander && denied.scriptOffer == child)
  #expect(denied.commander.scriptState.instances[child]?.completionReceipt == nil)
  try FileManager.default.removeItem(at: container)
  try FileManager.default.moveItem(at: backup, to: container)
  #expect(try Data(contentsOf: save) == pointer)
  await runtime.key("return")
  let completed = await runtime.snapshot()
  #expect(completed.commander.scriptState.instances[child]?.completionReceipt != nil)
  #expect(completed.commander.credits == before.commander.credits + 1000)
  let (disk, _) = try ScriptSaveStore.read(Data(contentsOf: save), from: save)
  #expect(disk == completed.commander)
}

@Test func delayedNativeReportRetainsCauseTimeSeparatelyFromCompletionCommitTime() throws {
  let fixture = try CompletionFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let child = try fixture.completePatrol(&game, report: false)
  game.emitScriptEvent("contact.requested", only: child)
  let offered = game.showScriptDialogue()
  #expect(offered)
  game.scriptEventsDeferred = true
  game.confirmScriptDialogue()
  let event = try #require(
    game.commander.scriptState.pendingEvents.first {
      $0.instance == child && $0.kind == "dialogue.confirmed"
    })
  let cause = try #require(event.context)
  for _ in 0..<100 {
    let advanced = game.advanceScriptClockValues(
      delta: 0.1, flight: false, local: true, calendar: true)
    #expect(advanced)
  }
  game.scriptEventsDeferred = false
  game.drainScriptEvents()
  let receipt = try #require(game.commander.scriptState.instances[child]?.completionReceipt)
  #expect(receipt.cause == cause && receipt.sequence == event.sequence)
  #expect(abs(receipt.committed.localSeconds - cause.localSeconds - 10) < 1e-8)
  #expect(abs(receipt.committed.calendarSeconds - cause.calendarSeconds - 10) < 1e-8)
  #expect(game.commander.valid)
}

@Test func inconsistentCompletionProofAndSelfJoinsCannotReplaceThePriorSave() async throws {
  let fixture = try CompletionFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let child = try fixture.completePatrol(&game)
  let save = fixture.root.appendingPathComponent("save/commander.json")
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: save)
  let pointer = try Data(contentsOf: save)
  let receipt = try #require(game.commander.scriptState.instances[child]?.completionReceipt)
  let original = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(receipt)) as? [String: Any])
  for (key, value) in [
    ("digest", String(repeating: "a", count: 64) as Any),
    ("outcome", "failed" as Any), ("sequence", 0 as Any), ("revision", 0 as Any),
    ("causeKind", "invented.death" as Any), ("destroyedEncounters", ["invented"] as Any),
  ] {
    var fields = original
    fields[key] = value
    let invalid = try JSONDecoder().decode(
      ScriptCompletionReceipt.self, from: JSONSerialization.data(withJSONObject: fields))
    var candidate = game
    candidate.commander.scriptState.instances[child]?.completionReceipt = invalid
    #expect(!candidate.commander.valid)
    #expect(throws: SaveError.self) {
      try ScriptSaveStore.write(
        commander: candidate.commander, world: candidate.scriptWorldSave, to: save)
    }
    #expect(try Data(contentsOf: save) == pointer)
  }
  game.commander.scriptState.instances[child]?.receiptJoins = ["self": [child]]
  #expect(!game.commander.valid)
}

@Test func optionalLinkedPatrolExampleUsesActualReceiptsInAnIsolatedGalleryTrial() async throws {
  let fixture = try CompletionFixture()
  defer { fixture.clean() }
  let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
      "docs/mission-packs/linked-patrol")
  let parent = try ScriptPackLibrary.read(example)
  #expect(parent.missingCapabilities.isEmpty)
  #expect(parent.manifest.receiptRequirements?.first?.digest == fixture.child.digest)
  var live = fixture.game()
  live.scriptPacks = [fixture.child, parent]
  let owner = GameRuntime(game: live)
  let original = await owner.snapshot()
  let trial = try await owner.scriptGalleryTrial(packDigest: parent.digest)
  let directory = try #require(await trial.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: directory) }
  let initial = await trial.snapshot()
  let parentID = try #require(initial.commander.scriptState.instances.keys.first)
  #expect(initial.commander.scriptState.instances[parentID]?.completionReceipt == nil)
  // Test hardware setup; every objective still goes through actual player controls and physics.
  await trial.nativeCommand { game in
    do { try fitCompletionPatrolTargeting(&game) } catch { Issue.record(error) }
  }
  await trial.key("contacts-open")
  await trial.key("return")
  let child = try #require(
    await trial.snapshot().commander.scriptState.instances.values.first {
      $0.definition == fixture.child.manifest.stateID
    }?.id)
  await trial.key("0")
  let legalBefore = await trial.snapshot().commander.legal
  try #require(legalBefore == 0)
  var firing = Controls()
  for _ in 0..<200 {
    firing = Controls()
    if try campaignPatrolOutsideStationZone(await trial.snapshot()) {
      try await selectCampaignPatrolTarget(trial, child: child)
      firing.fire = try campaignPatrolHasActualLaserContact(await trial.snapshot(), child: child)
    }
    await trial.setControls(firing)
    let battle = await trial.advance(delta: 0.1)
    if battle.commander.scriptState.instances[child]?.ownedEncounters["raiders"]?.destroyed == true
    {
      break
    }
  }
  #expect(
    await trial.snapshot().commander.scriptState.instances[child]?.ownedEncounters["raiders"]?
      .destroyed == true)
  #expect(await trial.snapshot().commander.legal == legalBefore)
  await trial.setControls(Controls())
  for _ in 0..<8 {
    await trial.key("r")
    if await trial.snapshot().autoPilot.targetID == 0 { break }
  }
  var actual = await trial.snapshot()
  for _ in 0..<5000 where !actual.docked { actual = await trial.advance(delta: 0.02) }
  #expect(actual.docked && actual.dockedAtMainStation)
  #expect(actual.commander.legal == legalBefore)
  await trial.key("contacts-open")
  #expect(await trial.snapshot().scriptOffer == child)
  await trial.key("return")
  #expect(await trial.snapshot().commander.scriptState.instances[child]?.completionReceipt != nil)
  await trial.key("contacts-open")
  #expect(await trial.snapshot().scriptOffer == parentID)
  let balance = await trial.snapshot().commander.credits
  await trial.key("return")
  actual = await trial.snapshot()
  #expect(
    actual.commander.scriptState.instances[parentID]?.receiptJoins?["patrol-report"] == [child])
  #expect(actual.commander.scriptState.instances[parentID]?.outcome == .complete)
  #expect(actual.commander.credits == balance && actual.isMissionTrial)
  let saved = directory.appendingPathComponent("commander.json")
  let (disk, _) = try ScriptSaveStore.read(Data(contentsOf: saved), from: saved)
  #expect(disk == actual.commander)
  #expect(await owner.snapshot().commander == original.commander)
  #expect(await owner.snapshot().bodies == original.bodies && actual.commander.valid)
}

@Test func nativeReceiptCountsDoNotTreatOneCompletedInstanceAsTwoChildren() throws {
  let fixture = try CompletionFixture(stage: "acceptance")
  defer { fixture.clean() }
  var game = fixture.game()
  let child = try fixture.completePatrol(&game)
  let manifest = fixture.root.appendingPathComponent("parent/manifest.toml")
  let original = try String(contentsOf: manifest, encoding: .utf8)
  try original.replacingOccurrences(of: "minimumCount=1", with: "minimumCount=2")
    .write(to: manifest, atomically: true, encoding: .utf8)
  let parent = try ScriptPackLibrary.read(manifest.deletingLastPathComponent())
  game.scriptPacks = [fixture.child, parent]
  game.emitScriptEvent("contact.requested", only: child)
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(parent) }
  #expect(game.commander.scriptState.instances.count == 1 && game.commander.valid)
}

@Test func declaredFailureCreatesItsOwnNativeReceiptWithoutClaimingChildSuccess() throws {
  let fixture = try CompletionFixture()
  defer { fixture.clean() }
  let folder = fixture.root.appendingPathComponent("parent")
  let file = folder.appendingPathComponent("scripts/main.lua")
  let source = try String(contentsOf: file, encoding: .utf8)
  try source.replacingOccurrences(of: "outcome='complete'", with: "outcome='failed'")
    .write(to: file, atomically: true, encoding: .utf8)
  let pack = try ScriptPackLibrary.read(folder)
  var game = fixture.game()
  game.scriptPacks = [fixture.child, pack]
  let id = try game.acceptScriptMission(pack)
  game.emitScriptEvent("contact.requested", only: id)
  let state = try #require(game.commander.scriptState.instances[id])
  #expect(state.outcome == .failed && state.completionReceipt?.outcome == .failed)
  #expect(state.receiptJoins?.isEmpty == true && game.commander.valid)
  #expect(
    game.matchingScriptReceipts(try #require(pack.manifest.receiptRequirements?.first)).isEmpty)
}

@Test func malformedReceiptRequirementsFailPackValidationBeforeInstallation() throws {
  let fixture = try CompletionFixture()
  defer { fixture.clean() }
  let folder = fixture.root.appendingPathComponent("parent")
  let manifest = folder.appendingPathComponent("manifest.toml")
  let original = try String(contentsOf: manifest, encoding: .utf8)
  for (before, after) in [
    ("minimumCount=1", "minimumCount=0"),
    ("minimumCount=1", "minimumCount=129"),
    ("stage=\"completion\"", "stage=\"installed\""),
    ("outcome=\"complete\"", "outcome=\"active\""),
    (fixture.child.digest, "not-a-digest"),
    (fixture.child.manifest.stateID, "test.receipt-parent/report"),
    ("minimumCount=1", "minimumCount=1\ninvented=1"),
    (",\"completion-receipts-v2\"", ""),
  ] {
    try original.replacingOccurrences(of: before, with: after)
      .write(to: manifest, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ScriptPackLibrary.read(folder) }
  }
}

@Test func fourActualPatrolReportsJoinWithOnlyTheExplicitlyAllowedFailedOutcome() async throws {
  let fixtures = try (0..<4).map { index in
    try CompletionFixture(
      allowedOutcomes: ["complete", "failed"], childID: "test.strand-\(index)",
      failedChild: index == 3)
  }
  defer { for fixture in fixtures { fixture.clean() } }
  let manifest = fixtures[0].root.appendingPathComponent("parent/manifest.toml")
  var text = try String(contentsOf: manifest, encoding: .utf8)
  text = text.replacingOccurrences(
    of: "outcomes=[\"complete\",\"failed\"]", with: "outcome=\"complete\"")
  for index in 1..<4 {
    let child = fixtures[index].child
    text += """

      [[receiptRequirements]]
      id="patrol\(index)"
      stage="completion"
      definition="\(child.manifest.stateID)"
      version="\(child.manifest.version)"
      digest="\(child.digest)"
      \(index == 3 ? "outcomes=[\"complete\",\"failed\"]" : "outcome=\"complete\"")
      minimumCount=1
      """
  }
  try text.write(to: manifest, atomically: true, encoding: .utf8)
  let parent = try ScriptPackLibrary.read(manifest.deletingLastPathComponent())
  var game = fixtures[0].game()
  game.scriptPacks = fixtures.map(\.child) + [parent]
  let parentID = try game.acceptScriptMission(parent)
  var children: [UUID] = []
  for index in 0..<4 {
    children.append(
      try fixtures[index].completePatrol(&game, expected: index == 3 ? .failed : .complete))
    #expect(game.commander.scriptState.instances[parentID]?.outcome == .active)
  }
  game.drainScriptEvents()
  #expect(game.commander.kills == 8)
  let balance = game.commander.credits
  game.emitScriptEvent("contact.requested", only: parentID)
  let state = try #require(game.commander.scriptState.instances[parentID])
  #expect(state.outcome == .complete && state.receiptJoins?.count == 4)
  #expect(state.data["notifications"] == .integer(4))
  #expect(Set(state.receiptJoins?.values.flatMap { $0 } ?? []) == Set(children))
  #expect(game.commander.scriptState.instances[children[3]]?.completionReceipt?.outcome == .failed)
  #expect(game.commander.credits == balance + 100 && game.commander.valid)
  let save = fixtures[0].root.appendingPathComponent("save/commander.json")
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: save)
  let loaded = GameRuntime(game: fixtures[0].game())
  try await loaded.load(from: save)
  #expect(
    await loaded.snapshot().commander.scriptState.instances[parentID]?.receiptJoins
      == state.receiptJoins)
  #expect(
    await loaded.snapshot().commander.scriptState.instances[children[3]]?.completionReceipt?.outcome
      == .failed)
}

@Test func aFailedNativeChildDoesNotMatchASuccessOnlyCompoundRequirement() throws {
  let fixture = try CompletionFixture(allowedOutcomes: ["complete"], failedChild: true)
  defer { fixture.clean() }
  var game = fixture.game()
  let parent = try game.acceptScriptMission(fixture.parent)
  _ = try fixture.completePatrol(&game, expected: .failed)
  game.drainScriptEvents()
  let balance = game.commander.credits
  game.emitScriptEvent("contact.requested", only: parent)
  #expect(game.commander.scriptState.instances[parent]?.outcome == .active)
  #expect(game.commander.scriptState.instances[parent]?.completionReceipt == nil)
  #expect(game.commander.credits == balance && game.commander.valid)
}

@Test func ambiguousActiveDuplicateAndUnsupportedCompoundOutcomesCannotInstall() throws {
  let fixture = try CompletionFixture(allowedOutcomes: ["complete", "failed"])
  defer { fixture.clean() }
  let folder = fixture.root.appendingPathComponent("parent")
  let file = folder.appendingPathComponent("manifest.toml")
  let original = try String(contentsOf: file, encoding: .utf8)
  for replacement in [
    "outcomes=[]", "outcomes=[\"active\"]", "outcomes=[\"complete\",\"complete\"]",
    "outcomes=[\"complete\",\"unknown\"]", "outcome=\"complete\"\noutcomes=[\"failed\"]",
  ] {
    try original.replacingOccurrences(of: "outcomes=[\"complete\",\"failed\"]", with: replacement)
      .write(to: file, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ScriptPackLibrary.read(folder) }
  }
  try original.replacingOccurrences(of: ",\"compound-receipts-v2\"", with: "")
    .write(to: file, atomically: true, encoding: .utf8)
  #expect(throws: (any Error).self) { try ScriptPackLibrary.read(folder) }
}
