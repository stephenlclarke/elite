import Foundation
import Testing

@testable import EliteCore

/// Existing original source/custody fixtures, not an executed native pickup or flight journey.
private final class CrewLogRecorderBoundaryFixture {
  let source: CrewLogPickupFixture
  var game = Game(executive: false)
  let parentID: UUID
  let childID: UUID
  let expected: ScriptOwnedActor
  init() throws {
    source = try CrewLogPickupFixture()
    parentID = source.f.parent.permission.mission
    childID = source.f.authorization.job
    expected = source.capture.marker
    game.commander = try source.commander()
    // The typed custody fixture does not render; metadata also needs its exact retained geometry.
    for design in source.f.source.models.values {
      let hash = ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(design))
      game.commander.scriptState.geometry[hash] = design
    }
    game.commander.galaxy = NativeInductionCrewLogSource.location.galaxy
    game.commander.system = NativeInductionCrewLogSource.location.system
    game.commander.scriptState.instances[parentID]?.savedWayfarerInduction = source.f.parent
    game.commander.scriptState.instances[childID]?.savedNativeCrewLog?.capture = nil
    game.commander.scriptState.instances[childID]?
      .ownedEncounters[NativeInductionCrewLogPack.encounter]?.actors["recorder"] = expected
  }
}

struct NativeCrewLogRecorderBoundaryUnitTests {
  @Test(arguments: [
    "ordinary", "missing-job", "missing-actor", "wrong-actor", "missing-child",
    "missing-authorization", "wrong-definition", "wrong-digest", "wrong-authorization",
  ])
  func unmarkedTargetsRejectWithoutChangingRetainedCustody(condition: String) throws {
    let f = try CrewLogRecorderBoundaryFixture()
    var body = f.expected.body
    switch condition {
    case "ordinary":
      body.missionInstanceID = nil
      body.missionActorID = nil
    case "missing-job": body.missionInstanceID = nil
    case "missing-actor": body.missionActorID = nil
    case "missing-child": f.game.commander.scriptState.instances.removeValue(forKey: f.childID)
    case "missing-authorization":
      f.game.commander.scriptState.instances[f.childID]?.savedNativeCrewLog = nil
    case "wrong-definition", "wrong-digest":
      let original = try #require(f.game.commander.scriptState.instances[f.childID])
      var child = ScriptInstance(
        id: original.id,
        definition: condition == "wrong-definition" ? "other-mission" : original.definition,
        version: original.version,
        digest: condition == "wrong-digest" ? "other-digest" : original.digest)
      child.savedNativeCrewLog = original.savedNativeCrewLog
      child.ownedEncounters = original.ownedEncounters
      f.game.commander.scriptState.instances[f.childID] = child
    case "wrong-authorization":
      let job = UUID()
      body.missionInstanceID = job
      body.missionActorID = NativeInductionCrewLogPack.actor(job: job, role: .recorder)
      f.game.commander.scriptState.instances[job] =
        f.game.commander.scriptState.instances[f.childID]
    default: body.missionActorID = UUID()
    }
    let before = f.game.commander
    #expect(f.game.inductionCrewLogRecorder(body) == nil)
    #expect(f.game.inductionCrewLogFacts(body) == nil)
    #expect(f.game.inductionCrewLogMetadata(body) == nil)
    #expect(f.game.commander == before)
  }

  @Test(arguments: [
    "valid", "full-hold", "inactive", "missing-admission", "captured", "lost", "unadmitted",
    "absent",
    "wrong-body", "hostile", "dead", "missing-physical", "wrong-visit", "wrong-population",
    "wrong-profile", "wrong-models",
  ])
  func markedRecorderRetainsEveryPresentAuthorityAndExactReturnedBody(condition: String) throws {
    let f = try CrewLogRecorderBoundaryFixture()
    var body = f.expected.body
    // A current pose is returned in the original owning alias rather than its retained old pose.
    body.position = .init(12, -34, 56)
    switch condition {
    case "full-hold":
      let free = f.game.commander.tradeCargoCapacity - f.game.commander.cargoTonnes
      try #require(free >= 0)
      f.game.commander.cargo[0] += free
    case "inactive": f.game.commander.scriptState.instances[f.childID]?.outcome = .complete
    case "missing-admission":
      f.game.commander.scriptState.instances[f.childID]?.savedNativeCrewLog?.admission = nil
    case "captured":
      f.game.commander.scriptState.instances[f.childID]?.savedNativeCrewLog?.capture =
        f.source.capture
    case "lost":
      f.game.commander.scriptState.instances[f.childID]?.savedNativeCrewLog?.losses = [
        .init(role: "recorder", actor: f.source.f.admission.recorder, physicalTime: 20_002)
      ]
    case "unadmitted":
      f.game.commander.scriptState.instances[f.childID]?
        .ownedEncounters[NativeInductionCrewLogPack.encounter]?.admitted = false
    case "absent":
      f.game.commander.scriptState.instances[f.childID]?
        .ownedEncounters[NativeInductionCrewLogPack.encounter]?.actors["recorder"]?.presence =
        .outside
    case "wrong-body": body.id += 1
    case "hostile": body.hostile = true
    case "dead": body.energy = 0
    case "missing-physical": body.physical = nil
    case "wrong-visit":
      let physical = try #require(body.physical)
      body.physical = .init(
        identity: .init(system: NativeInductionCrewLogSource.location, visit: 29, entity: 4),
        population: physical.population, npc: physical.npc)
    case "wrong-population": body.physical?.population = .civilian
    case "wrong-profile": body.scriptNPC = try f.source.f.prepared(.tender).body.scriptNPC
    case "wrong-models":
      let npc = try #require(body.scriptNPC)
      body.scriptNPC = .init(
        fit: .init(definition: npc.fit.definition, models: [:]), fuel: npc.fuel,
        guns: npc.guns, components: npc.components)
    default: break
    }
    let before = f.game.commander
    let actual = f.game.inductionCrewLogRecorder(body)
    if condition == "valid" || condition == "full-hold" {
      var expected = f.expected
      expected.body = body
      #expect(actual == expected)
      let actualFacts = f.game.inductionCrewLogFacts(body)
      let facts = try #require(actualFacts)
      #expect(facts.original == f.source.f.source.manifest.recorder)
      #expect(facts.fits == (before.tradeCargoCapacity - before.cargoTonnes >= 1))
      #expect(facts.fits == (condition != "full-hold"))
      let actualMetadata = f.game.inductionCrewLogMetadata(body)
      let metadata = try #require(actualMetadata)
      let expectedMetadata = SalvageTargetMetadata(
        category: .cargo, ownership: .missionProtected, claimant: nil,
        wreck: nil, section: nil, lot: nil,
        bounds: .init(
          center: .init(0, 0, 0), radius: try NativeInductionCrewLogSource.recorderRadius.get()),
        workSurfaces: [])
      #expect(metadata == expectedMetadata)
    } else {
      #expect(actual == nil)
      #expect(f.game.inductionCrewLogFacts(body) == nil)
      #expect(f.game.inductionCrewLogMetadata(body) == nil)
    }
    #expect(f.game.commander == before)
  }
}
