import Foundation
import Testing

@testable import EliteCore

private func campaignPatrolLawDiagnostic(_ game: Game) -> String {
  let ordinary = game.bodies.filter {
    $0.energy > 0 && $0.hull.isTargetShip && $0.missionInstanceID == nil
  }
  let ships = ordinary.sorted { $0.id < $1.id }.prefix(12).map { body in
    "id=\(body.id),actor=\(String(describing: body.physical?.identity))"
      + ",role=\(String(describing: body.physical?.npc?.role)),legal=\(body.physical?.npc?.legal.value ?? 0)"
      + ",intention=\(String(describing: body.physical?.npc?.intention))"
      + ",hostile=\(body.hostile),HP=\(body.energy),position=\(body.position)"
  }.joined(separator: "; ")
  let assignments = game.commander.stationSecurity.assignments.prefix(8).map {
    "actor=\($0.actor),target=\(String(describing: $0.target)),phase=\($0.phase)"
  }.joined(separator: "; ")
  let station = game.bodies.first { $0.id == 0 && $0.hull == .station }
  return
    "legal=\(game.commander.legal),player=\(String(describing: game.commander.flightSimulation.player))"
    + ",stationViewPosition=\(String(describing: station?.position))"
    + ",stationDistance=\(String(describing: station?.position.length))"
    + ",stationSystemPosition=\(String(describing: game.commander.flightSimulation.anchors?.station.position))"
    + ",securityPhase=\(game.commander.stationSecurity.phase),assignments=[\(assignments)]"
    + ",ordinaryCount=\(ordinary.count),policeCount=\(ordinary.filter { $0.physical?.npc?.role == .police }.count)"
    + ",ordinaryShips=[\(ships)]"
}

// Scalar evidence only: keep the actual encounter, flight and refusal state unchanged.
func campaignPatrolDiagnostic(_ game: Game, child: UUID) -> String {
  let encounter = game.commander.scriptState.instances[child]?.ownedEncounters["raiders"]
  let actors = (encounter?.actors.keys.sorted() ?? []).prefix(4).map { alias in
    guard let actor = encounter?.actors[alias] else { return alias + "=missing" }
    guard let body = game.bodies.first(where: { $0.missionActorID == actor.identity }) else {
      return "\(alias):presence=\(actor.presence),live=absent,retainedHP=\(actor.body.energy)"
    }
    return "\(alias):presence=\(actor.presence),id=\(body.id),HP=\(body.energy)"
      + ",position=\(body.position),forward=\(body.orientation.z)"
      + ",native=\(body.physical != nil),profiled=\(body.scriptNPC != nil)"
  }.joined(separator: "; ")
  return [
    "paused=\(game.paused),screen=\(game.screen),valid=\(game.commander.valid)",
    "energy=\(game.energy),shields=\(game.frontShield)/\(game.rearShield),speed=\(game.speed)",
    "time=\(game.time),physicalTime=\(game.commander.flightSimulation.physicalTime)",
    "playerPosition=\(game.commander.flightSimulation.pose.position)",
    "playerForward=\(game.commander.flightSimulation.pose.orientation.z)",
    "heat=\(game.laserHeat),flash=\(game.laserFlash)",
    "discharge=\(game.dischargeAudio.events.last?.id ?? 0),laser=\(game.commander.laser(on: .front))",
    "docked=\(game.docked)/\(game.dockedAtMainStation),dockingHardware=\(game.commander.hasAutomaticDocking)",
    "targetingFit=\(game.commander.fittedEquipment(at: .targetingCore)?.node.key ?? "none")",
    "target=\(String(describing: game.autoPilot.targetID)),weapons=\(String(describing: game.weaponsTargetID))",
    "autopilot=\(game.autoPilot.status),dockingComputer=\(game.dockingComputer)",
    "message=\(game.message),actors=[\(actors)]",
    campaignPatrolLawDiagnostic(game),
  ].joined(separator: ",")
}

private func fitCampaignPatrolTargeting(_ game: inout Game) throws {
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
}

private func campaignPatrolTargetIsOwned(_ game: Game, child: UUID) -> Bool {
  guard let body = game.autoTargetBody, body.energy > 0, body.missionInstanceID == child,
    let identity = body.missionActorID,
    let encounter = game.commander.scriptState.instances[child]?.ownedEncounters["raiders"]
  else { return false }
  return encounter.actors.values.contains {
    $0.identity == identity && $0.presence != .destroyed
  }
}

func campaignPatrolOutsideStationZone(_ game: Game) throws -> Bool {
  let station = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
  return station.position.length > 1200
}

private func selectCampaignPatrolTarget(_ game: inout Game, child: UUID) throws {
  // Keep tracking the live owned actor; cycle actual player targets only when it changes.
  for _ in 0...game.bodies.count {
    if campaignPatrolTargetIsOwned(game, child: child) { return }
    game.key("r")
  }
  try #require(
    campaignPatrolTargetIsOwned(game, child: child),
    Comment(
      rawValue: "Owned patrol target unavailable: " + campaignPatrolDiagnostic(game, child: child)))
}

func selectCampaignPatrolTarget(_ runtime: GameRuntime, child: UUID) async throws {
  var selected = await runtime.snapshot()
  for _ in 0...selected.bodies.count {
    if campaignPatrolTargetIsOwned(selected, child: child) { return }
    await runtime.key("r")
    selected = await runtime.snapshot()
  }
  try #require(
    campaignPatrolTargetIsOwned(selected, child: child),
    Comment(
      rawValue: "Owned patrol target unavailable: "
        + campaignPatrolDiagnostic(selected, child: child)))
}

private struct CampaignFixture {
  let root: URL
  let child: ScriptPack
  let parents: [ScriptPack]
  var save: URL { root.appendingPathComponent("save/commander.json") }
  init(
    policy: String = "suspend", parentOnly: Bool = false,
    childFault: Bool = false, parentTail: String = "", parentEdits: [(String, String)] = []
  ) throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "native-campaign-" + UUID().uuidString)
    let original = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let cleanup = root
    var retained = false
    defer { if !retained { try? FileManager.default.removeItem(at: cleanup) } }
    let childFolder = root.appendingPathComponent("child")
    try FileManager.default.copyItem(
      at: original.appendingPathComponent("scripted-patrol"), to: childFolder)
    let childManifest = childFolder.appendingPathComponent("manifest.toml")
    var childText = try String(contentsOf: childManifest, encoding: .utf8)
    if parentOnly {
      childText = childText.replacingOccurrences(
        of: "\"classic-encounters-v2\"]",
        with: "\"classic-encounters-v2\", \"scoped-campaigns-basic-v2\"]"
      )
      .replacingOccurrences(of: "[mission]", with: "[mission]\nparentOnly=true")
    }
    try childText.write(to: childManifest, atomically: true, encoding: .utf8)
    if childFault {
      let file = childFolder.appendingPathComponent("scripts/main.lua")
      let source = try String(contentsOf: file, encoding: .utf8)
      try source.replacingOccurrences(
        of: "function M.accepted(e,w,d)",
        with: "function M.accepted(e,w,d)\n  error('Original child initialization failed')"
      )
      .write(to: file, atomically: true, encoding: .utf8)
    }
    child = try ScriptPackLibrary.read(childFolder)
    var loaded: [ScriptPack] = []
    for index in 0..<2 {
      let folder = root.appendingPathComponent("parent\(index)")
      try FileManager.default.copyItem(
        at: original.appendingPathComponent("scoped-patrol"), to: folder)
      let manifest = folder.appendingPathComponent("manifest.toml")
      var text = try String(contentsOf: manifest, encoding: .utf8)
      text = text.replacingOccurrences(of: "example.scoped-patrol", with: "test.campaign-\(index)")
        .replacingOccurrences(
          of: "f7c2123ea24e13e6d8e613a72270a052ae6b5a010e4edb678ab10a239f185906", with: child.digest
        )
        .replacingOccurrences(
          of: "terminalPolicy = \"suspend\"", with: "terminalPolicy = \"\(policy)\"")
      for (old, new) in parentEdits { text = text.replacingOccurrences(of: old, with: new) }
      try text.write(to: manifest, atomically: true, encoding: .utf8)
      if !parentTail.isEmpty {
        let file = folder.appendingPathComponent("scripts/main.lua")
        let source = try String(contentsOf: file, encoding: .utf8)
        try source.replacingOccurrences(
          of: "commands={{op='child.ensure',id='patrol'}}}",
          with: "commands={{op='child.ensure',id='patrol'},\(parentTail)}}"
        )
        .write(to: file, atomically: true, encoding: .utf8)
      }
      loaded.append(try ScriptPackLibrary.read(folder))
    }
    parents = loaded
    retained = true
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
  func commanderChangedPaths(_ before: Commander, _ after: Commander) throws -> [String] {
    let encoder = JSONEncoder()
    let left = try JSONSerialization.jsonObject(with: encoder.encode(before))
    let right = try JSONSerialization.jsonObject(with: encoder.encode(after))
    let sameEquipment = before.equipment == after.equipment
    var paths: [String] = []
    func compare(_ left: Any?, _ right: Any?, path: String, depth: Int) {
      guard paths.count < 12 else { return }
      switch (left, right) {
      case (nil, nil): return
      case (let left?, let right?):
        if let left = left as? [String: Any], let right = right as? [String: Any], depth < 20 {
          for key in Set(left.keys).union(right.keys).sorted() {
            if depth == 0 && key == "equipment" && sameEquipment { continue }
            compare(left[key], right[key], path: path + "." + key, depth: depth + 1)
          }
        } else if let left = left as? [Any], let right = right as? [Any], depth < 20 {
          if left.count != right.count { paths.append(path + ".count") }
          for index in 0..<min(left.count, right.count) {
            compare(left[index], right[index], path: path + "[\(index)]", depth: depth + 1)
          }
        } else if String(describing: left) != String(describing: right) {
          paths.append(path)
        }
      default: paths.append(path)
      }
    }
    compare(left, right, path: "Commander", depth: 0)
    return paths
  }
  func game() -> Game {
    var game = Game(executive: false)
    game.screen = .status
    do { try fitCampaignPatrolTargeting(&game) } catch { Issue.record(error) }
    game.scriptPacks = [child] + parents
    return game
  }
  func start(_ game: inout Game, index: Int = 0) throws -> (UUID, UUID) {
    let parent = try game.acceptScriptMission(parents[index])
    let child = try #require(
      game.commander.scriptState.instances[parent]?.campaignChildren["patrol"]?.child)
    for _ in 0..<3 { game.drainScriptEvents() }
    return (parent, child)
  }
  func report(_ game: inout Game, child: UUID) throws {
    let legalBefore = game.commander.legal
    try #require(legalBefore == 0)
    let beforeFire = campaignPatrolDiagnostic(game, child: child)
    var observedFlash = false
    var firing = Controls()
    for _ in 0..<200 {
      // Actual launch motion clears the station zone within the original combat budget.
      firing = Controls()
      if try campaignPatrolOutsideStationZone(game) {
        try selectCampaignPatrolTarget(&game, child: child)
        firing.fire = game.autoPilot.status == "TRACKING TARGET"
      }
      game.tick(delta: 0.1, controls: firing)
      observedFlash = observedFlash || game.laserFlash > 0
      if game.commander.scriptState.instances[child]?.ownedEncounters["raiders"]?.destroyed == true
      {
        break
      }
    }
    #expect(
      game.commander.scriptState.instances[child]?.ownedEncounters["raiders"]?.destroyed == true,
      Comment(
        rawValue: "beforeFire: \(beforeFire); observedFlash=\(observedFlash); afterFire: "
          + campaignPatrolDiagnostic(game, child: child)))
    #expect(
      game.commander.legal == legalBefore,
      Comment(rawValue: campaignPatrolDiagnostic(game, child: child)))
    firing = Controls()
    for _ in 0..<8 {
      game.key("r")
      if game.autoPilot.targetID == 0 { break }
    }
    let beforeDock = campaignPatrolDiagnostic(game, child: child)
    for _ in 0..<5000 where !game.docked { game.tick(delta: 0.02, controls: firing) }
    #expect(
      game.docked && game.dockedAtMainStation,
      Comment(
        rawValue: "afterStationSelection: \(beforeDock); afterDockFlight: "
          + campaignPatrolDiagnostic(game, child: child)))
    #expect(game.commander.legal == legalBefore)
    game.emitScriptEvent("contact.requested", only: child)
    let shown = game.showScriptDialogue(only: child)
    #expect(shown)
    game.confirmScriptDialogue()
    for _ in 0..<3 { game.drainScriptEvents() }
    #expect(game.commander.scriptState.instances[child]?.outcome == .complete)
  }
}

@Test func twoCampaignsOwnDifferentPhysicalPatrolsAndOnlyTheirActualReportQualifies() async throws {
  let fixture = try CampaignFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let first = try fixture.start(&game)
  let second = try fixture.start(&game, index: 1)
  #expect(first.1 != second.1 && game.commander.scriptState.instances.count == 4)
  let firstBinding = try #require(
    game.commander.scriptState.instances[first.0]?.campaignChildren["patrol"])
  #expect(game.commander.scriptState.instances[first.1]?.campaignParent == firstBinding)
  #expect(game.commander.scriptState.instances[first.0]?.data["starts"] == .integer(1))
  let rng = game.commander.scriptState.instances[first.1]?.randomState
  game.emitScriptEvent("contact.requested", only: first.0)
  #expect(game.commander.scriptState.instances[first.0]?.campaignChildren["patrol"] == firstBinding)
  #expect(game.commander.scriptState.instances[first.1]?.randomState == rng)
  game.launch()
  game.emitScriptEvent("station.undocked")
  let admitted = try #require(
    [first, second].first {
      game.commander.scriptState.instances[$0.1]?.ownedEncounters["raiders"]?.admitted == true
    })
  let waiting = admitted.0 == first.0 ? second : first
  try fixture.report(&game, child: admitted.1)
  let owner = try #require(game.commander.scriptState.instances[admitted.0])
  let other = try #require(game.commander.scriptState.instances[waiting.0])
  let rule = try #require(fixture.parents[0].manifest.receiptRequirements?.first)
  #expect(game.matchingScriptReceipts(rule, parent: owner) == [admitted.1])
  #expect(game.matchingScriptReceipts(rule, parent: other).isEmpty)
  #expect(owner.data["notifications"] == .integer(1) && other.data["notifications"] == .integer(0))
  #expect(throws: MissionPackError.self) {
    try game.scriptReceiptJoins(
      fixture.parents[1], stage: .completion, existing: [:], parent: other)
  }
  game.emitScriptEvent("contact.requested", only: admitted.0)
  let firstShown = game.showScriptDialogue(only: admitted.0)
  #expect(firstShown)
  game.confirmScriptDialogue()
  #expect(
    game.commander.scriptState.instances[admitted.0]?.receiptJoins?["owned-report"] == [admitted.1])
  #expect(game.commander.scriptState.instances[waiting.0]?.outcome == .active)
  // The second cohort is still a genuine separate job, admitted on the next actual launch.
  game.launch()
  game.emitScriptEvent("station.undocked")
  try fixture.report(&game, child: waiting.1)
  game.emitScriptEvent("contact.requested", only: waiting.0)
  let secondShown = game.showScriptDialogue(only: waiting.0)
  #expect(secondShown)
  game.confirmScriptDialogue()
  #expect(
    game.commander.scriptState.instances[waiting.0]?.receiptJoins?["owned-report"] == [waiting.1])
  #expect(
    game.commander.scriptState.instances[admitted.0]?.campaignChildren["patrol"] == firstBinding
      || admitted.0 != first.0)
  #expect(game.commander.valid)
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: fixture.save)
  let loaded = GameRuntime(game: fixture.game())
  try await loaded.load(from: fixture.save, persistMigrations: false)
  #expect(await loaded.snapshot().commander == game.commander)
}

@Test func childAcceptanceWaitsForItsParentProposalAndNeverReissuesAfterAChildFault() async throws {
  let fixture = try CampaignFixture(childFault: true)
  defer { fixture.clean() }
  var game = fixture.game()
  let parent = try game.acceptScriptMission(fixture.parents[0])
  let binding = try #require(
    game.commander.scriptState.instances[parent]?.campaignChildren["patrol"])
  #expect(game.commander.scriptState.instances[binding.child]?.revision == 0)
  #expect(game.commander.scriptState.instances[binding.child]?.suspension == nil)
  #expect(
    game.commander.scriptState.pendingEvents.contains {
      $0.instance == binding.child && $0.kind == "mission.accepted"
    })
  game.drainScriptEvents()
  let fault = try #require(game.commander.scriptState.instances[binding.child])
  #expect(fault.suspension?.contains("Original child initialization failed") == true)
  let pending = game.commander.scriptState.pendingEvents.first { $0.instance == binding.child }
  game.emitScriptEvent("contact.requested", only: parent)
  #expect(game.commander.scriptState.instances[parent]?.campaignChildren["patrol"] == binding)
  #expect(game.commander.scriptState.instances[binding.child] == fault)
  #expect(game.commander.scriptState.pendingEvents.contains { $0 == pending })
  #expect(game.commander.valid && game.commander.scriptState.instances.count == 2)
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: fixture.save)
  let loaded = GameRuntime(game: fixture.game())
  try await loaded.load(from: fixture.save, persistMigrations: false)
  await #expect(throws: (any Error).self) { try await loaded.resumeScriptMission(binding.child) }
  #expect(
    await loaded.snapshot().commander.scriptState.instances[parent]?.campaignChildren["patrol"]
      == binding)
}

@Test func aLateParentCommandFailureCannotKeepItsStagedChildOrAcceptedFact() throws {
  let fixture = try CampaignFixture(parentTail: "{op='unsupported'}")
  defer { fixture.clean() }
  var game = fixture.game()
  let before = game.commander
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(fixture.parents[0]) }
  #expect(game.commander == before && game.commander.scriptState.instances.isEmpty)
}

@Test func failedNativeCampaignAcceptanceLeavesNoChildAndRetryKeepsOneOriginalPair() async throws {
  let fixture = try CampaignFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
  await runtime.key("contacts-open")
  let before = await runtime.snapshot()
  try Data("blocked directory".utf8).write(to: fixture.save.deletingLastPathComponent())
  await runtime.key("return")
  #expect(await runtime.snapshot().commander == before.commander)
  #expect(await runtime.snapshot().scriptAvailablePackDigest == before.scriptAvailablePackDigest)
  try FileManager.default.removeItem(at: fixture.save.deletingLastPathComponent())
  await runtime.key("return")
  let accepted = await runtime.snapshot()
  #expect(accepted.commander.scriptState.instances.count == 2 && accepted.commander.valid)
  let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.save), from: fixture.save)
  #expect(saved == accepted.commander)
}

@Test(arguments: ["suspend", "preserve"])
func terminalParentUsesDeclaredPolicyAndNeverDeletesActualChildProperty(policy: String) async throws
{
  let fixture = try CampaignFixture(policy: policy)
  defer { fixture.clean() }
  var game = fixture.game()
  let (parent, child) = try fixture.start(&game)
  game.launch()
  game.emitScriptEvent("station.undocked")
  let owned = try #require(game.commander.scriptState.instances[child]?.ownedEncounters["raiders"])
  let bodies = game.bodies
  game.emitScriptEvent("mission.abandoned", only: parent)
  let state = try #require(game.commander.scriptState.instances[child])
  #expect(game.commander.scriptState.instances[parent]?.outcome == .abandoned)
  #expect(
    state.ownedEncounters["raiders"] == owned && game.bodies == bodies && state.outcome == .active)
  #expect((state.suspension != nil) == (policy == "suspend"))
  let revision = state.revision
  game.emitScriptEvent("system.entered", only: child)
  game.drainScriptEvents()
  if policy == "suspend" {
    #expect(game.commander.scriptState.instances[child]?.revision == revision)
  }
  let unprepared = game.commander
  try game.commander.prepareEquipment()
  game.commander.mirrorFittedEquipment()
  try #require(game.commander.savedEquipmentVersion == 2)
  #expect(game.commander.credits == unprepared.credits && game.commander.cargo == unprepared.cargo)
  #expect(game.commander.shipID == unprepared.shipID && game.commander.name == unprepared.name)
  #expect(game.commander.fuel == unprepared.fuel && game.commander.missiles == unprepared.missiles)
  #expect(game.commander.scriptState == unprepared.scriptState)
  #expect(game.commander.contracts == unprepared.contracts)
  #expect(game.commander.accommodation == unprepared.accommodation)
  let beforePhysicalSync = game.commander
  let liveBodies = game.bodies
  game.persistScriptActors()
  var conserved = game.commander
  for alias in ["lead", "wing"] {
    let originalActor = try #require(
      beforePhysicalSync.scriptState.instances[child]?.ownedEncounters["raiders"]?.actors[alias])
    let synchronizedActor = try #require(
      game.commander.scriptState.instances[child]?.ownedEncounters["raiders"]?.actors[alias])
    let actualBody = try #require(liveBodies.first { $0.missionActorID == originalActor.identity })
    #expect(
      synchronizedActor.identity == originalActor.identity
        && synchronizedActor.presence == originalActor.presence)
    #expect(synchronizedActor.body.physical == actualBody.physical)
    conserved.scriptState.instances[child]?.ownedEncounters["raiders"]?.actors[alias]?.body
      .physical = originalActor.body.physical
  }
  #expect(conserved == beforePhysicalSync && game.bodies == liveBodies)
  #expect(game.commander.scriptState.instances[child]?.outcome == state.outcome)
  #expect(game.commander.scriptState.instances[child]?.suspension == state.suspension)
  let expected = try GameRuntime.prepareNativeSaveState(game)
  #expect(expected.game.commander == game.commander && expected.game.bodies == liveBodies)
  #expect(expected.commander.npcPersistence.count == expected.game.commander.npcPersistence.count)
  #expect(
    expected.commander.npcPersistence.livingCount
      == expected.game.commander.npcPersistence.livingCount)
  #expect(
    expected.commander.npcPersistence.unboundSnapshots.count
      == expected.commander.npcPersistence.livingCount)
  #expect(expected.commander.scriptState == expected.game.commander.scriptState)
  for (logical, snapshot) in expected.commander.npcPersistence.unboundSnapshots {
    #expect(snapshot == expected.game.commander.npcPersistence.snapshot(for: logical))
  }
  var checkedNPCBindings = 0
  for body in liveBodies {
    if let physical = body.physical,
      let logical = expected.game.commander.npcPersistence.logicalIdentity(for: physical.identity)
    {
      checkedNPCBindings += 1
      #expect(
        expected.commander.npcPersistence.snapshot(for: logical)
          == expected.game.commander.npcPersistence.snapshot(for: logical))
      #expect(expected.commander.npcPersistence.binding(for: logical) == nil)
      #expect(expected.game.commander.npcPersistence.binding(for: logical) == physical.identity)
    }
  }
  try #require(checkedNPCBindings > 0)
  let runtime = GameRuntime(game: game)
  #expect(await runtime.snapshot().commander == game.commander)
  try await runtime.save(to: fixture.save)
  let saved = await runtime.snapshot().commander
  let savePreservedCommander = saved == game.commander
  let saveChanges = try fixture.commanderChangedPaths(game.commander, saved)
  #expect(
    savePreservedCommander,
    Comment(rawValue: "Save changed: " + saveChanges.joined(separator: "; ")))
  let (written, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.save), from: fixture.save)
  #expect(written == expected.commander)
  let loaded = GameRuntime(game: fixture.game())
  try await loaded.load(from: fixture.save, persistMigrations: false)
  let reloaded = await loaded.snapshot().commander
  let loadPreservedCommander = reloaded == expected.commander
  let loadChanges = try fixture.commanderChangedPaths(expected.commander, reloaded)
  #expect(
    loadPreservedCommander,
    Comment(rawValue: "Reload changed: " + loadChanges.joined(separator: "; ")))
  if policy == "suspend" {
    await #expect(throws: MissionPackError.self) { try await loaded.resumeScriptMission(child) }
    #expect(
      await loaded.snapshot().commander.scriptState.instances[child]?.suspension == state.suspension
    )
  }
}

@Test func parentOnlyChildCannotBeOfferedOrTriedAndMissingOwningContentSuspendsIntact() async throws
{
  let fixture = try CampaignFixture(parentOnly: true)
  defer { fixture.clean() }
  var game = fixture.game()
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(fixture.child) }
  #expect(throws: MissionPackError.self) {
    try game.makeScriptTrial(packDigest: fixture.child.digest, seed: 42)
  }
  game.scriptPacks = [fixture.child]
  let offered = game.offerAvailableScriptMission()
  #expect(!offered)
  game = fixture.game()
  let (parent, child) = try fixture.start(&game)
  let binding = game.commander.scriptState.instances[child]?.campaignParent
  game.scriptPacks = [fixture.child]
  game.suspendUnavailableScriptContent()
  #expect(game.commander.scriptState.instances[parent]?.suspension != nil)
  #expect(game.commander.scriptState.instances[child]?.suspension != nil)
  #expect(game.commander.scriptState.instances[child]?.campaignParent == binding)
  game.scriptPacks = [fixture.child] + fixture.parents
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  try await runtime.resumeScriptMission(parent)
  try await runtime.resumeScriptMission(child)
  #expect(
    await runtime.snapshot().commander.scriptState.instances[child]?.campaignParent == binding)
  #expect(await runtime.snapshot().commander.scriptState.instances[child]?.suspension == nil)
}

@Test(arguments: ["inverse", "root", "depth", "sequence", "scope", "foreign-join"])
func malformedCampaignRelationshipsRefuseLoadEvenWithUpdatedChunkHash(field: String) async throws {
  let fixture = try CampaignFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let (parent, child) = try fixture.start(&game)
  _ = try fixture.start(&game, index: 1)
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: fixture.save)
  let before = await runtime.snapshot()
  let pointer = try JSONDecoder().decode(
    ScriptSavePointer.self, from: Data(contentsOf: fixture.save))
  let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.save)
  let file = directory.appendingPathComponent("missions.json")
  var engine = try ScriptValueStorage.decoder(typed: true).decode(
    ScriptEngineState.self, from: Data(contentsOf: file))
  let binding = try #require(engine.instances[child]?.campaignParent)
  if field == "inverse" {
    engine.instances[child]?.campaignParent = nil
  } else if field == "scope" {
    engine.instances[parent]?.savedCampaignReceiptScopes = ["invalid alias!": "patrol"]
  } else if field == "foreign-join" {
    engine.instances[parent]?.receiptJoins = ["owned-report": [UUID()]]
  } else {
    let bad = ScriptChildBinding(
      parent: binding.parent, root: field == "root" ? UUID() : binding.root,
      child: binding.child, depth: field == "depth" ? Int.max : binding.depth,
      definition: binding.definition, sequence: field == "sequence" ? 0 : binding.sequence,
      revision: binding.revision, causeKind: binding.causeKind, cause: binding.cause,
      committed: binding.committed)
    engine.instances[child]?.campaignParent = bad
    engine.instances[parent]?.campaignChildren["patrol"] = bad
  }
  let changed = try ScriptValueStorage.encoder().encode(engine)
  try changed.write(to: file)
  var hashes = pointer.hashes
  hashes["missions.json"] = ScriptPackLibrary.hash(changed)
  let replacement = ScriptSavePointer(
    format: pointer.format, schemaVersion: pointer.schemaVersion,
    generation: pointer.generation, hashes: hashes, scope: pointer.scope,
    valueCodec: pointer.valueCodec)
  try JSONEncoder().encode(replacement).write(to: fixture.save)
  await #expect(throws: (any Error).self) { try await runtime.load(from: fixture.save) }
  #expect(await runtime.snapshot().commander == before.commander)
}

@Test func campaignChildrenHaveStableIndependentSeedsWithoutConsumingSimulationRandomness() throws {
  let fixture = try CampaignFixture()
  defer { fixture.clean() }
  let parentID = UUID()
  var first = fixture.game()
  var second = fixture.game()
  var untouched = fixture.game()
  _ = try first.acceptScriptMission(fixture.parents[0], instanceID: parentID)
  _ = second.randomByte()
  _ = try second.acceptScriptMission(fixture.parents[0], instanceID: parentID)
  let binding = try #require(
    first.commander.scriptState.instances[parentID]?.campaignChildren["patrol"])
  #expect(second.commander.scriptState.instances[parentID]?.campaignChildren["patrol"] == binding)
  #expect(
    first.commander.scriptState.instances[binding.child]?.randomState
      == second.commander.scriptState.instances[binding.child]?.randomState)
  let firstRandom = first.randomByte()
  let untouchedRandom = untouched.randomByte()
  #expect(firstRandom == untouchedRandom)
}

@Test(arguments: ["policy", "alias", "pin", "acceptance", "count", "capability", "unknown"])
func malformedCampaignDeclarationsFailInstallation(field: String) throws {
  let edits: [(String, String)]
  switch field {
  case "policy": edits = [("terminalPolicy = \"suspend\"", "terminalPolicy = \"erase\"")]
  case "alias": edits = [("child = \"patrol\"", "child = \"foreign\"")]
  case "pin": edits = [("child = \"patrol\"", "child = \"patrol\"\nchoice=\"only\"")]
  case "acceptance": edits = [("stage = \"completion\"", "stage = \"acceptance\"")]
  case "count": edits = [("minimumCount = 1", "minimumCount = 2")]
  case "capability": edits = [("\"scoped-campaigns-basic-v2\", ", "")]
  default: edits = [("terminalPolicy = \"suspend\"", "terminalPolicy = \"suspend\"\nteleport=true")]
  }
  #expect(throws: (any Error).self) { try CampaignFixture(parentEdits: edits) }
}

private func nestedCampaigns(_ fixture: CampaignFixture, count: Int) throws -> [ScriptPack] {
  var child = fixture.child
  var result: [ScriptPack] = []
  let original = fixture.root.appendingPathComponent("parent0")
  for index in 0..<count {
    let folder = fixture.root.appendingPathComponent("nested\(index)")
    try FileManager.default.copyItem(at: original, to: folder)
    let file = folder.appendingPathComponent("manifest.toml")
    let text = try String(contentsOf: file, encoding: .utf8)
    try text.replacingOccurrences(of: fixture.parents[0].manifest.id, with: "test.nested-\(index)")
      .replacingOccurrences(of: fixture.child.manifest.stateID, with: child.manifest.stateID)
      .replacingOccurrences(of: fixture.child.digest, with: child.digest)
      .replacingOccurrences(
        of: "terminalPolicy = \"suspend\"",
        with: "terminalPolicy = \"\(index == count - 1 ? "suspend" : "preserve")\""
      )
      .write(to: file, atomically: true, encoding: .utf8)
    child = try ScriptPackLibrary.read(folder)
    result.append(child)
  }
  return result
}

@Test func endedRootBlocksAllDescendantsEvenWhenTheirImmediatePolicyPreserves() async throws {
  let fixture = try CampaignFixture()
  defer { fixture.clean() }
  let chain = try nestedCampaigns(fixture, count: 3)
  var game = fixture.game()
  game.scriptPacks += chain
  let root = try game.acceptScriptMission(chain.last!)
  for _ in 0..<10 { game.drainScriptEvents() }
  let descendants = game.commander.scriptState.instances.values.filter { $0.id != root }
  #expect(descendants.count == 3 && descendants.allSatisfy { $0.suspension == nil })
  game.emitScriptEvent("mission.abandoned", only: root)
  #expect(descendants.allSatisfy { game.commander.scriptState.instances[$0.id]?.suspension != nil })
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  for child in descendants {
    await #expect(throws: MissionPackError.self) { try await runtime.resumeScriptMission(child.id) }
  }
  #expect(await runtime.snapshot().commander.valid)
}

@Test func fifthCampaignLinkIsRefusedWithoutAHiddenOrPartiallyCreatedChild() throws {
  let fixture = try CampaignFixture()
  defer { fixture.clean() }
  let chain = try nestedCampaigns(fixture, count: 5)
  var game = fixture.game()
  game.scriptPacks += chain
  _ = try game.acceptScriptMission(chain.last!)
  for _ in 0..<12 { game.drainScriptEvents() }
  #expect(game.commander.scriptState.instances.count == 5)
  let deepest = try #require(
    game.commander.scriptState.instances.values.first { $0.campaignParent?.depth == 4 })
  #expect(deepest.suspension != nil && deepest.campaignChildren.isEmpty && deepest.revision == 0)
  #expect(
    game.commander.scriptState.pendingEvents.contains {
      $0.instance == deepest.id && $0.kind == "mission.accepted"
    })
  #expect(game.commander.valid)
}

@Test func olderSaveFormatsCannotConcealCampaignOwnershipAndFormerStandaloneReportsDoNotQualify()
  async throws
{
  let fixture = try CampaignFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let standalone = try game.acceptScriptMission(fixture.child)
  game.launch()
  game.emitScriptEvent("station.undocked")
  try fixture.report(&game, child: standalone)
  let (parent, ownedChild) = try fixture.start(&game)
  let owner = try #require(game.commander.scriptState.instances[parent])
  let rule = try #require(fixture.parents[0].manifest.receiptRequirements?.first)
  #expect(ownedChild != standalone && game.matchingScriptReceipts(rule, parent: owner).isEmpty)
  #expect(throws: MissionPackError.self) {
    try game.scriptReceiptJoins(
      fixture.parents[0], stage: .completion, existing: ["owned-report": [standalone]],
      parent: owner)
  }
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: fixture.save)
  let before = await runtime.snapshot()
  let pointer = try JSONDecoder().decode(
    ScriptSavePointer.self, from: Data(contentsOf: fixture.save))
  let old = ScriptSavePointer(
    format: pointer.format, schemaVersion: 18, generation: pointer.generation,
    hashes: pointer.hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
  try JSONEncoder().encode(old).write(to: fixture.save)
  await #expect(throws: (any Error).self) { try await runtime.load(from: fixture.save) }
  #expect(await runtime.snapshot().commander == before.commander)
}

@Test func nativeGalleryCampaignFliesOwnedPatrolAndRestoresItsLiveCommander() async throws {
  let fixture = try CampaignFixture()
  defer { fixture.clean() }
  var live = fixture.game()
  live.commander.name = "CAMPAIGN OWNER"
  let runtime = GameRuntime(game: live, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  let before = await runtime.snapshot()
  let bytes = try Data(contentsOf: fixture.save)
  await runtime.key("gallery-open")
  var selected = await runtime.snapshot()
  let index = try #require(
    selected.missionCatalogue.firstIndex { $0.trialDigest == fixture.parents[0].digest })
  for _ in 0..<index { await runtime.key("down") }
  #expect(await runtime.snapshot().canTrialSelectedMission)
  await runtime.key("gallery-trial")
  let namespace = try #require(await runtime.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: namespace) }
  selected = await runtime.advance(delta: 0.1)
  let owner = try #require(
    selected.commander.scriptState.instances.values.first { $0.campaignParent == nil })
  let child = try #require(owner.campaignChildren["patrol"]?.child)
  // Test hardware setup only; all objectives use actual player controls and native physics.
  let beforeHardware = await runtime.snapshot().commander
  await runtime.nativeCommand { game in
    do {
      try game.commander.grantEquipment(
        TargetingTier.docking.equipmentName, at: .targetingCore, provenance: .legacyUnknown)
    } catch { Issue.record(error) }
  }
  let fitted = await runtime.snapshot().commander
  try #require(fitted.hasAutomaticDocking)
  #expect(
    fitted.fittedEquipment(at: .targetingCore)?.node.key == TargetingTier.docking.equipmentName)
  #expect(fitted.credits == beforeHardware.credits && fitted.cargo == beforeHardware.cargo)
  #expect(fitted.scriptState == beforeHardware.scriptState)
  #expect(
    fitted.contracts == beforeHardware.contracts
      && fitted.accommodation == beforeHardware.accommodation)
  await runtime.key("0")
  let legalBefore = await runtime.snapshot().commander.legal
  try #require(legalBefore == 0)
  let beforeFire = campaignPatrolDiagnostic(await runtime.snapshot(), child: child)
  var observedFlash = false
  var firing = Controls()
  for _ in 0..<200 {
    firing = Controls()
    if try campaignPatrolOutsideStationZone(await runtime.snapshot()) {
      try await selectCampaignPatrolTarget(runtime, child: child)
      firing.fire = await runtime.snapshot().autoPilot.status == "TRACKING TARGET"
    }
    await runtime.setControls(firing)
    selected = await runtime.advance(delta: 0.1)
    observedFlash = observedFlash || selected.laserFlash > 0
    if selected.commander.scriptState.instances[child]?.ownedEncounters["raiders"]?.destroyed
      == true
    {
      break
    }
  }
  #expect(
    selected.commander.scriptState.instances[child]?.ownedEncounters["raiders"]?.destroyed == true,
    Comment(
      rawValue: "beforeFire: \(beforeFire); observedFlash=\(observedFlash); afterFire: "
        + campaignPatrolDiagnostic(selected, child: child)))
  #expect(
    selected.commander.legal == legalBefore,
    Comment(rawValue: campaignPatrolDiagnostic(selected, child: child)))
  await runtime.setControls(Controls())
  for _ in 0..<8 {
    await runtime.key("r")
    if await runtime.snapshot().autoPilot.targetID == 0 { break }
  }
  let beforeDock = campaignPatrolDiagnostic(await runtime.snapshot(), child: child)
  for _ in 0..<5000 {
    selected = await runtime.advance(delta: 0.02)
    if selected.docked { break }
  }
  #expect(
    selected.docked && selected.dockedAtMainStation,
    Comment(
      rawValue: "afterStationSelection: \(beforeDock); afterDockFlight: "
        + campaignPatrolDiagnostic(selected, child: child)))
  #expect(selected.commander.legal == legalBefore)
  await runtime.key("contacts-open")
  #expect(await runtime.snapshot().scriptOffer == child)
  await runtime.key("return")
  _ = await runtime.advance(delta: 0.1)
  await runtime.key("contacts-open")
  #expect(await runtime.snapshot().scriptOffer == owner.id)
  await runtime.key("return")
  let complete = await runtime.snapshot()
  #expect(complete.commander.scriptState.instances[owner.id]?.outcome == .complete)
  #expect(
    complete.commander.scriptState.instances[owner.id]?.receiptJoins?["owned-report"] == [child])
  let saved = try await runtime.saveForInterface()
  #expect(saved.isTrial && saved.url.path.hasPrefix(namespace.path + "/"))
  _ = try await runtime.loadForInterface()
  #expect(await runtime.snapshot().commander == complete.commander)
  #expect(try Data(contentsOf: fixture.save) == bytes)
  await runtime.key("trial-return")
  #expect(await runtime.snapshot().commander == before.commander)
  #expect(try Data(contentsOf: fixture.save) == bytes)
}

@Test func galleryKeepsEveryOwnedChildEntryAndBrowsingNeverStartsAnotherCampaign() throws {
  let fixture = try CampaignFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let first = try fixture.start(&game)
  let second = try fixture.start(&game, index: 1)
  game.openGallery()
  let before = game.commander
  let entries = game.missionCatalogue
  #expect(Set(entries.compactMap(\.savedInstance)) == [first.0, first.1, second.0, second.1])
  for id in [first.1, second.1] {
    let index = try #require(entries.firstIndex { $0.savedInstance == id })
    #expect(
      entries[index].briefing.contains("Owning campaign: Owned patrol campaign demonstration"))
    #expect(entries[index].trialDigest == nil)
    game.gallery.selection = index
    #expect(!game.canTrialSelectedMission)
    for size in [(512.0, 518.0), (1512.0, 982.0)] {
      let frame = Display.gallery(game, width: size.0, height: size.1)
      #expect(frame.labels.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    }
  }
  #expect(
    entries.first { $0.savedInstance == first.0 }?.briefing.contains("Campaign assignments:")
      == true)
  #expect(game.commander == before)
  game.scriptPacks = fixture.parents
  let missing = game.missionCatalogue.filter {
    [first.1, second.1].contains($0.savedInstance ?? UUID())
  }
  #expect(missing.count == 2 && missing.allSatisfy { $0.status == .locked })
  #expect(game.commander == before)
}

@Test func campaignCapacityRefusesTheWholeRootWhenItsChildCannotFit() throws {
  let fixture = try CampaignFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  // Synthetic admitted saved-state boundary; not127 played missions.
  for _ in 0..<127 {
    let id = UUID()
    game.commander.scriptState.instances[id] = ScriptInstance(
      id: id, definition: "test.capacity/job", version: "1.0.0", digest: fixture.child.digest)
  }
  #expect(game.commander.valid)
  let before = game.commander
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(fixture.parents[0]) }
  #expect(game.commander == before && game.commander.scriptState.instances.count == 127)
}
