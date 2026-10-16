import Foundation
import Testing

@testable import EliteCore

private struct ActorAdmissionFixture {
  let directory: URL
  let pack: ScriptPack

  init(worldJob: Bool = false, failingPulse: Bool = false, laterOutside: Bool = false) throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "actor-admission-source-" + UUID().uuidString)
    let original = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/profiled-skirmish")
    try FileManager.default.copyItem(at: original, to: directory)
    let manifest = directory.appendingPathComponent("manifest.toml")
    var text = try String(contentsOf: manifest, encoding: .utf8)
    text += """

      [[encounters]]
      id='z-later'
      galaxy=0
      system=7
      profile='profiled-local-freeze-v1'
      actors=[{id='later',npc='training-craft',x=\(laterOutside ? "100000.0" : "10000.0"),y=0.0,z=10000.0,hostile=true}]
      """
    if worldJob {
      text = text.replacingOccurrences(
        of: "capabilities = [",
        with: "capabilities = [\"world-resource-jobs-v2\", \"pulse-counters-v2\", ")
      text += """

        [[worldJobs]]
        id='deploy'
        title='Controlled actor deployment'
        handler='deploy'
        owner='station'
        galaxy=0
        system=7
        firstDue=0
        interval=0
        policy='once'
        controlledEncounters=['z-later']
        """
    }
    try text.write(to: manifest, atomically: true, encoding: .utf8)
    let second =
      worldJob
      ? "{op='world.job.ensure',id='deploy'}" : "{op='encounter.ensure',id='z-later'}"
    let deploy =
      failingPulse
      ? "error('retain actual pending deployment pulse')"
      : "return {data=d,commands={{op='encounter.ensure',id='z-later'}}}"
    let source = """
      local M={}
      function M.accepted(e,w,d) return {data=d,commands={}} end
      function M.undocked(e,w,d)
        return {data=d,commands={{op='encounter.ensure',id='opponents'},\(second)}}
      end
      function M.deploy(e,w,d) \(deploy) end
      function M.admitted(e,w,d) return {data=d,commands={}} end
      M.destroyed=M.admitted; M.contact=M.admitted; M.confirm=M.admitted
      return M
      """
    try source.write(
      to: directory.appendingPathComponent("scripts/main.lua"), atomically: true, encoding: .utf8)
    pack = try ScriptPackLibrary.read(directory)
  }

  func game() throws -> (Game, UUID) {
    var game = Game(executive: false)
    game.screen = .status
    try game.commander.prepareEquipment(legacy: false)
    game.scriptPacks = [pack]
    let instance = try game.acceptScriptMission(pack)
    game.launch()
    game.emitScriptEvent("station.undocked")
    game.drainScriptEvents()
    return (game, instance)
  }

  func clean() { try? FileManager.default.removeItem(at: directory) }
}

struct ScriptActorAdmissionSourceTests {
  @Test
  func actualInitialHandlersAndRetainedFactoryExposeMeasuredSpentConditionWithoutNativeIdentity()
    throws
  {
    var (game, instance, index) = try actualMissionBridgeGame()
    game.bodies[index].energy = 37
    game.bodies[index].scriptNPC?.components["turret"]?.energy = 17
    game.bodies[index].scriptNPC?.guns["forward"]?.heat = 7
    game.bodies[index].scriptNPC?.shots = 11
    game.ensurePhysicalActors()
    game.persistScriptActors()
    let before = game.commander
    let bodies = game.bodies
    let nextID = game.nextBodyID
    let sources = try game.retainedMissionActorAdmissionSources()
    let source = try #require(sources.first { $0.instanceID == instance })
    try game.validateMissionActorAdmissionSource(source)
    let lead = try #require(source.actors.first { $0.alias == "lead" })
    #expect(source.mode == .retained && source.authority == .retained)
    #expect(source.instanceRevision == before.scriptState.instances[instance]?.revision)
    #expect(
      source.retention == before.scriptState.instances[instance]?.ownedEncounters["opponents"])
    #expect(lead.canonicalBody.id == -1 && lead.canonicalBody.physical == nil)
    #expect(lead.canonicalBody.energy == 37 && lead.maximumHullEnergy == 120)
    #expect(lead.canonicalBody.scriptNPC?.guns["forward"]?.heat == 7)
    #expect(lead.canonicalBody.scriptNPC?.shots == 11 && lead.nativeUnits == 2)
    #expect(lead.minimum == .init(-40, -20, -60) && lead.maximum == .init(40, 28, 60))
    let part = try #require(lead.parts.first { $0.alias == "turret" })
    #expect(part.energy == 17 && part.maximumEnergy == 40 && part.solid)
    #expect(part.componentID == lead.canonicalBody.scriptNPC?.components["turret"]?.identity)
    #expect(part.mesh.vertices.first == Vector3(-6, 22, -9))
    #expect(game.commander == before && game.bodies == bodies && game.nextBodyID == nextID)
  }

  @Test(arguments: ["owner", "digest", "revision", "actor", "component", "geometry", "condition"])
  func sealedRetainedSourceRefusesChangedActualAuthorityOrCondition(field: String) throws {
    var (game, instance, _) = try actualMissionBridgeGame()
    let sources = try game.retainedMissionActorAdmissionSources()
    let source = try #require(sources.first { $0.instanceID == instance })
    var owner = try #require(game.commander.scriptState.instances[instance])
    switch field {
    case "owner": game.commander.scriptState.instances.removeValue(forKey: instance)
    case "digest":
      game.commander.scriptState.instances[instance] = .init(
        id: instance, definition: owner.definition, version: owner.version,
        digest: String(repeating: "0", count: 64))
    case "revision":
      owner.revision += 1
      game.commander.scriptState.instances[instance] = owner
    case "actor":
      let actor = try #require(owner.ownedEncounters["opponents"]?.actors["lead"])
      owner.ownedEncounters["opponents"]?.actors["lead"] = .init(
        identity: UUID(), alias: actor.alias, body: actor.body, presence: actor.presence)
      game.commander.scriptState.instances[instance] = owner
    case "component":
      let component = try #require(
        owner.ownedEncounters["opponents"]?.actors["lead"]?.body.scriptNPC?.components["turret"])
      owner.ownedEncounters["opponents"]?.actors["lead"]?.body.scriptNPC?.components["turret"] =
        .init(
          identity: UUID(), energy: component.energy, guns: component.guns)
      game.commander.scriptState.instances[instance] = owner
    case "geometry":
      let digest = try #require(game.commander.scriptState.geometry.keys.first)
      game.commander.scriptState.geometry.removeValue(forKey: digest)
    default:
      owner.ownedEncounters["opponents"]?.actors["lead"]?.body.energy = 121
      game.commander.scriptState.instances[instance] = owner
    }
    let before = game.commander
    let bodies = game.bodies
    let nextID = game.nextBodyID
    #expect(throws: MissionPackError.self) { try game.validateMissionActorAdmissionSource(source) }
    #expect(game.commander == before && game.bodies == bodies && game.nextBodyID == nextID)
  }

  @Test(arguments: ["owner", "digest", "revision", "actor", "component", "condition", "position"])
  func preparedHandlerRefusesForgedOwnerOrNonAuthoredCandidateBeforePublication(field: String)
    throws
  {
    let fixture = try ActorAdmissionFixture(worldJob: true)
    defer { fixture.clean() }
    var (game, instance) = try fixture.game()
    game.docked = true
    var owner = try #require(game.commander.scriptState.instances[instance])
    _ = try game.ensureScriptEncounter("z-later", pack: fixture.pack, state: &owner)
    try #require(owner.ownedEncounters["z-later"]?.admitted == false)
    switch field {
    case "owner":
      owner = .init(
        id: UUID(), definition: owner.definition, version: owner.version, digest: owner.digest)
    case "digest":
      owner = .init(
        id: owner.id, definition: owner.definition, version: owner.version,
        digest: String(repeating: "0", count: 64))
    case "revision": owner.revision += 1
    case "actor":
      let actor = try #require(owner.ownedEncounters["z-later"]?.actors["later"])
      owner.ownedEncounters["z-later"]?.actors["later"] = .init(
        identity: UUID(), alias: actor.alias, body: actor.body, presence: actor.presence)
    case "component":
      let component = try #require(
        owner.ownedEncounters["z-later"]?.actors["later"]?.body.scriptNPC?.components["turret"])
      owner.ownedEncounters["z-later"]?.actors["later"]?.body.scriptNPC?.components["turret"] =
        .init(
          identity: UUID(), energy: component.energy, guns: component.guns)
    case "condition": owner.ownedEncounters["z-later"]?.actors["later"]?.body.energy = 119
    default: owner.ownedEncounters["z-later"]?.actors["later"]?.body.position = .init(1, 2, 3)
    }
    let beforeOwner = owner
    let before = game.commander
    let bodies = game.bodies
    let nextID = game.nextBodyID
    #expect(throws: MissionPackError.self) {
      try game.ensureScriptEncounter("z-later", pack: fixture.pack, state: &owner)
    }
    #expect(owner == beforeOwner && game.commander == before)
    #expect(game.bodies == bodies && game.nextBodyID == nextID)
  }

  @Test func laterInvalidRetainedCohortRefusesBeforeEarlierActorOrAnchorRestoration() throws {
    let fixture = try ActorAdmissionFixture()
    defer { fixture.clean() }
    var (game, instance) = try fixture.game()
    game.persistScriptActors()
    try #require(game.commander.scriptState.instances[instance]?.ownedEncounters.count == 2)
    for key in ["opponents", "z-later"] {
      let aliases = game.commander.scriptState.instances[instance]?.ownedEncounters[key]?.actors
        .keys
      for alias in aliases.map(Array.init) ?? [] {
        game.commander.scriptState.instances[instance]?.ownedEncounters[key]?.actors[alias]?
          .presence = .unloaded
      }
    }
    game.commander.scriptState.instances[instance]?.ownedEncounters["z-later"]?.actors["later"]?
      .body.energy = 121
    game.bodies.removeAll { $0.missionActorID != nil || $0.id == 0 }
    try #require(game.scriptAnchor != nil)
    let before = game.commander
    let bodies = game.bodies
    let nextID = game.nextBodyID
    #expect(throws: MissionPackError.self) { try game.restoreScriptActors() }
    #expect(game.commander == before && game.bodies == bodies && game.nextBodyID == nextID)
  }

  @Test(arguments: [false, true])
  func laterBrokenActualLiveBindingCannotPublishEarlierEligibleCohort(firstOutside: Bool) throws {
    let fixture = try ActorAdmissionFixture()
    defer { fixture.clean() }
    var (game, instance) = try fixture.game()
    game.persistScriptActors()
    let first = try #require(
      game.commander.scriptState.instances[instance]?.ownedEncounters["opponents"])
    let identities = Set(first.actors.values.map(\.identity))
    for alias in first.actors.keys {
      game.commander.scriptState.instances[instance]?.ownedEncounters["opponents"]?.actors[alias]?
        .presence = .unloaded
      game.commander.scriptState.instances[instance]?.ownedEncounters["opponents"]?.actors[alias]?
        .body.energy = 37
      if firstOutside {
        game.commander.scriptState.instances[instance]?.ownedEncounters["opponents"]?.actors[alias]?
          .body.position = .init(100_000, 0, 100_000)
      }
    }
    game.bodies.removeAll { $0.missionActorID.map(identities.contains) ?? false }
    let later = try #require(
      game.commander.scriptState.instances[instance]?.ownedEncounters["z-later"]?.actors["later"])
    let laterIndex = try #require(game.bodies.firstIndex { $0.missionActorID == later.identity })
    // The retained source stays genuine; only the actual current native owner's join is broken.
    game.bodies[laterIndex].missionInstanceID = UUID()
    let sources = try game.retainedMissionActorAdmissionSources()
    try #require(sources.count == 2)
    let initial = try #require(sources.first { $0.encounterID == "opponents" })
    let preparation = try game.prepareMissionActorAdmission(initial)
    switch preparation {
    case .ready: #expect(!firstOutside)
    case .unchanged: #expect(firstOutside)
    case .pending:
      Issue.record("This fixture must isolate a valid first cohort or an outside no-op.")
    }
    let before = game.commander
    let bodies = game.bodies
    let nextID = game.nextBodyID
    #expect(throws: (any Error).self) { try game.restoreScriptActors() }
    #expect(game.commander == before && game.bodies == bodies && game.nextBodyID == nextID)
    #expect(!game.bodies.contains { $0.missionActorID.map(identities.contains) ?? false })
  }

  @Test(arguments: ["rotation", "angular"])
  func preparedOutsideCohortCannotStagePrivateOwnerBeforeDifferentLiveBindingHardFailure(
    field: String
  )
    throws
  {
    let fixture = try ActorAdmissionFixture(worldJob: true, laterOutside: true)
    defer { fixture.clean() }
    var (game, instance) = try fixture.game()
    var owner = try #require(game.commander.scriptState.instances[instance])
    try #require(owner.ownedEncounters["z-later"] == nil)
    // A real valid-scene control proves the requested cohort is a temporary outside proposal.
    var control = game
    var controlOwner = owner
    let pending = try control.ensureScriptEncounter(
      "z-later", pack: fixture.pack, state: &controlOwner)
    #expect(pending.0 == "encounter.pending")
    #expect(controlOwner.ownedEncounters["z-later"]?.admitted == false)
    #expect(control.bodies == game.bodies && control.nextBodyID == game.nextBodyID)
    let live = try #require(owner.ownedEncounters["opponents"]?.actors["lead"])
    let index = try #require(game.bodies.firstIndex { $0.missionActorID == live.identity })
    try #require(game.bodies[index].physical != nil)
    if field == "rotation" {
      game.bodies[index].rotation = .nan
    } else {
      game.bodies[index].physical?.angularVelocity.x = .nan
    }
    let beforeOwner = owner
    let before = game.commander
    let beforeBodies = game.bodies
    let nextID = game.nextBodyID
    let reference = game.scriptReferenceFrame
    #expect(throws: NativeMissionActorAdmissionError.invalidScene) {
      try game.ensureScriptEncounter("z-later", pack: fixture.pack, state: &owner)
    }
    #expect(owner == beforeOwner && game.commander == before)
    #expect(owner.ownedEncounters["z-later"] == nil)
    #expect(game.nextBodyID == nextID && game.scriptReferenceFrame == reference)
    // NaN is unequal to itself. Check its exact bits and compare every remaining scene field.
    var expected = beforeBodies
    var actual = game.bodies
    if field == "rotation" {
      #expect(actual[index].rotation.bitPattern == expected[index].rotation.bitPattern)
      expected[index].rotation = 0
      actual[index].rotation = 0
    } else {
      #expect(
        actual[index].physical?.angularVelocity.x.bitPattern
          == expected[index].physical?.angularVelocity.x.bitPattern)
      expected[index].physical?.angularVelocity.x = 0
      actual[index].physical?.angularVelocity.x = 0
    }
    #expect(actual == expected)
  }

  @Test func retentionPatchStagesOnlyAddressesAndRefusesStaleOwnerWithoutPublishing() throws {
    var (game, instance, _) = try actualMissionBridgeGame()
    game.persistScriptActors()
    let sources = try game.retainedMissionActorAdmissionSources()
    let source = try #require(sources.first { $0.instanceID == instance })
    let before = game.commander
    let bodies = game.bodies
    let owner = try #require(before.scriptState.instances[instance])
    let actor = try #require(source.actors.first)
    // Address data exercises pure retention staging only; no native admission is claimed.
    let patch = try source.prepareRetentionPatch(sceneBodyIDs: [actor.actorID: 900_001])
    let staged = try patch.preparingInstance(owner)
    #expect(patch.matches(owner))
    var expected = source.retention
    expected.actors[actor.alias]?.body.id = 900_001
    expected.actors[actor.alias]?.presence = .present
    #expect(staged.ownedEncounters[source.encounterID] == expected)
    var stale = owner
    stale.revision += 1
    #expect(!patch.matches(stale))
    #expect(throws: MissionPackError.self) { try patch.preparingInstance(stale) }
    for field in ["definition", "version"] {
      var replaced = ScriptInstance(
        id: owner.id, definition: field == "definition" ? "forged" : owner.definition,
        version: field == "version" ? "forged" : owner.version, digest: owner.digest)
      replaced.ownedEncounters = owner.ownedEncounters
      #expect(!patch.matches(replaced))
      #expect(throws: MissionPackError.self) { try patch.preparingInstance(replaced) }
    }
    let second = try #require(source.actors.last)
    #expect(throws: MissionPackError.self) {
      try source.prepareRetentionPatch(sceneBodyIDs: [actor.actorID: 7, second.actorID: 7])
    }
    #expect(game.commander == before && game.bodies == bodies)
  }

  @Test func actualWorldJobPulseDeploysOnlyItsDeclaredControlledEncounter() throws {
    let fixture = try ActorAdmissionFixture(worldJob: true)
    defer { fixture.clean() }
    var (game, instance) = try fixture.game()
    try #require(game.commander.scriptState.instances[instance]?.ownedEncounters["z-later"] == nil)
    game.advanceScriptWorldJobs(delta: 0.1)
    let job = try #require(
      game.commander.scriptState.worldJobs.values.first { $0.origin == instance })
    #expect(job.timer.pulses == 1 && job.pending == nil && job.suspension == nil)
    #expect(
      game.commander.scriptState.instances[instance]?.ownedEncounters["z-later"]?.admitted == true)
    let sources = try game.retainedMissionActorAdmissionSources()
    #expect(sources.filter { $0.instanceID == instance }.count == 2)
  }

  @Test(arguments: ["identity", "pulse", "missing-pulse", "suspended"])
  func worldJobDeploymentRejectsWrongActualIdentityOrPendingPulseBeforeStaging(field: String) throws
  {
    let fixture = try ActorAdmissionFixture(worldJob: true, failingPulse: true)
    defer { fixture.clean() }
    var (game, instance) = try fixture.game()
    game.advanceScriptWorldJobs(delta: 0.1)
    let job = try #require(
      game.commander.scriptState.worldJobs.values.first { $0.origin == instance })
    let pulse = try #require(job.pending)
    try #require(job.suspension != nil)
    // Model retry eligibility using the real retained pulse; no pulse/owner is synthesized.
    if field != "suspended" { game.commander.scriptState.worldJobs[job.identity]?.suspension = nil }
    var owner = try #require(game.commander.scriptState.instances[instance])
    let beforeOwner = owner
    let before = game.commander
    let bodies = game.bodies
    let nextID = game.nextBodyID
    #expect(throws: MissionPackError.self) {
      try game.ensureScriptEncounter(
        "z-later", pack: fixture.pack, state: &owner,
        worldJobID: field == "identity" ? UUID() : job.identity,
        worldJobPulse: field == "missing-pulse" ? nil : pulse.sequence + (field == "pulse" ? 1 : 0))
    }
    #expect(owner == beforeOwner && game.commander == before)
    #expect(game.bodies == bodies && game.nextBodyID == nextID)
  }
}
