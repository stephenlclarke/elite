import Foundation
import Testing

@testable import EliteCore

/// Actual binding-producer policy over typed native/retained records; no native journey is run.
private final class UtilityBindingFixture {
  let f: InductionUtilityWorkFixture
  var game: Game
  init() throws {
    f = try .init()
    game = Game()
    game.commander = try f.f.commander()
    game.commander.system = 190
    game.docked = false
    game.screen = .front
    let inlet = try f.arm(.inlet)
    while game.commander.flightSimulation.visit < inlet.actor.visit {
      game.commander.flightSimulation.enter(NativeInductionUtilitySource.location, arriving: true)
    }
    while game.commander.flightSimulation.nextActor <= 20 {
      _ = game.commander.flightSimulation.allocateActor()
    }
    game.commander.flightSimulation.physicalTime = 1_000_100
    game.commander.scriptState.flightSeconds = 900_100
    game.commander.scriptState.nextEvent = 121
    var child = f.f.child()
    child.savedNativeInductionUtility = try f.state(repaired: false)
    child.revision = 1000
    child.acknowledge(121)
    game.commander.scriptState.instances[f.f.source.parent]?.acknowledge(121)
    var actors: [String: ScriptOwnedActor] = [:]
    for (index, role) in NativeInductionUtilityRole.allCases.enumerated() {
      var actor = try f.f.prepared(role)
      let resources = try NativeInductionUtilityPack.initialResources(
        state: f.f.child(), actor: actor)
      actor.presence = .present
      actor.body.id = 40 + index
      actor.body.physical = .init(
        identity: try f.arm(role).actor, population: .mission,
        npc: resources)
      actors[role.rawValue] = actor
      var live = actor.body
      if role == .inlet {
        // Ordinary retained restoration changes native entity in the same visit, not the logical actor.
        let condition = try #require(live.physical)
        live.physical = .init(
          identity: .init(system: inlet.actor.system, visit: inlet.actor.visit, entity: 20),
          population: condition.population, npc: condition.npc)
      }
      game.bodies.append(live)
    }
    var group = ScriptOwnedEncounter(
      id: NativeInductionUtilityPack.encounter,
      galaxy: 0, system: 190, actors: actors)
    group.admitted = true
    child.ownedEncounters[group.id] = group
    game.commander.scriptState.instances[child.id] = child
  }
  func newArm(_ binding: NativeInductionUtilityBinding?) throws -> NativeInductionUtilityArm {
    let body = try #require(game.bodies.first { game.inductionUtilityRole($0) == .inlet })
    let actor = try #require(body.physical?.identity)
    let player = try #require(game.commander.flightSimulation.player)
    let epoch = game.nativeStationRuntimeEpoch
    let operation = try NativeInductionUtilityArm.identity(
      authorization: f.f.authorization.operation, role: .inlet, actor: actor, player: player,
      carrier: f.f.authorization.carrier, revision: 1, epoch: epoch, time: 1_000_100,
      flightSeconds: 900_100, sequence: 121, binding: binding)
    return .init(
      operation: operation, sequence: 121, authorization: f.f.authorization.operation,
      owner: f.f.source.owner, job: f.f.authorization.job, role: .inlet,
      module: f.f.source.module(.inlet), kit: f.f.source.kit(.inlet), actor: actor, player: player,
      carrier: f.f.authorization.carrier, inventoryRevision: 1, epoch: epoch,
      physicalTime: 1_000_100, flightSeconds: 900_100, binding: binding)
  }
}

struct NativeWayfarerInductionUtilityBindingUnitTests {
  @Test func sameVisitFreshNativeBindingRetainsLogicalModuleHistoricalPartialWorkAndSingleKit()
    throws
  {
    let fixture = try UtilityBindingFixture()
    let body = try #require(
      fixture.game.bodies.first { fixture.game.inductionUtilityRole($0) == .inlet })
    let observed = fixture.game.inductionUtilityBinding(for: body, role: .inlet)
    let binding = try #require(observed)
    let first = binding.firstAdmission
    #expect(first.actor.visit == binding.actor.visit && first.actor.entity != binding.actor.entity)
    #expect(
      binding.logicalActor
        == NativeInductionUtilityPack.actor(job: fixture.f.f.authorization.job, role: .inlet))
    let unproved = try fixture.newArm(nil)
    #expect(!NativeInductionUtilitySave.bindingMatches(unproved, admission: first))
    let arm = try fixture.newArm(binding)
    #expect(NativeInductionUtilitySave.bindingMatches(arm, admission: first))
    #expect(
      arm.valid(authorization: fixture.f.f.authorization, source: fixture.f.f.source, role: .inlet))
    var child = try #require(fixture.game.inductionUtilityChild)
    var state = try #require(child.savedNativeInductionUtility)
    let history = try #require(state.modules[0].work)
    state.modules[0].work?.segments.append(.init(arm: arm))
    #expect(state.shapeValid(parent: fixture.f.f.parent))
    #expect(state.modules[0].work?.seconds == history.seconds)
    #expect(state.modules[0].availableKits == 1 && state.modules[0].fault == "valve-closed")
    #expect(state.modules[0].work?.segments.first == history.segments.first)
    child.savedNativeInductionUtility = state
    child.ownedEncounters[NativeInductionUtilityPack.encounter]?.actors["inlet"]?.body = body
    fixture.game.commander.scriptState.instances[child.id] = child
    #expect(NativeInductionUtilitySave.validateClaims(fixture.game.commander))
    let restored = try JSONDecoder().decode(
      NativeInductionUtilityState.self, from: JSONEncoder().encode(state))
    #expect(restored == state && restored.admission?["inlet"] == first)
  }

  @Test func bindingProducerRefusesForeignRoleAddressOrRetainedAliasAndArmCannotChangeItsProof()
    throws
  {
    let fixture = try UtilityBindingFixture()
    let body = try #require(
      fixture.game.bodies.first { fixture.game.inductionUtilityRole($0) == .inlet })
    #expect(fixture.game.inductionUtilityBinding(for: body, role: .buffer) == nil)
    var foreign = body
    let condition = try #require(foreign.physical)
    foreign.physical = .init(
      identity: .init(
        system: NativeInductionUtilitySource.location,
        visit: condition.identity.visit, entity: 19), population: condition.population,
      npc: condition.npc)
    #expect(fixture.game.inductionUtilityBinding(for: foreign, role: .inlet) == nil)
    let observed = fixture.game.inductionUtilityBinding(for: body, role: .inlet)
    let binding = try #require(observed)
    var arm = try fixture.newArm(binding)
    arm.binding = nil
    #expect(
      !arm.valid(authorization: fixture.f.f.authorization, source: fixture.f.f.source, role: .inlet)
    )
    fixture.game.commander.scriptState.instances[fixture.f.f.authorization.job]?.ownedEncounters[
      NativeInductionUtilityPack.encounter]?.actors["inlet"]?.body.missionActorID = UUID()
    #expect(fixture.game.inductionUtilityBinding(for: body, role: .inlet) == nil)
  }

  @Test func closedBindingSchemaRejectsOldEnvelopesAndPreservesUnboundHistoricalArms() throws {
    let fixture = try UtilityBindingFixture()
    let body = try #require(
      fixture.game.bodies.first { fixture.game.inductionUtilityRole($0) == .inlet })
    let observed = fixture.game.inductionUtilityBinding(for: body, role: .inlet)
    let binding = try #require(observed)
    var state = try fixture.f.state(repaired: false)
    state.modules[0].work?.segments.append(.init(arm: try fixture.newArm(binding)))
    let leaf = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
    let raw: [String: Any] = [
      "definition": NativeInductionUtilityPack.stateID,
      "digest": NativeInductionUtilityPack.digest, "savedNativeInductionUtility": leaf,
    ]
    for schema in [103, 104] {
      try NativeInductionUtilitySave.validateFields(raw, schema: schema, embedded: false)
    }
    for schema in [99, 100, 101, 102] {
      #expect(throws: (any Error).self) {
        try NativeInductionUtilitySave.validateFields(raw, schema: schema, embedded: false)
      }
    }
    let old = try fixture.f.work(.inlet, seconds: 4.5, repaired: false)
    #expect(old.segments[0].arm.binding == nil)
    #expect(
      old.valid(authorization: fixture.f.f.authorization, source: fixture.f.f.source, role: .inlet))
    #expect(NativeInductionArkSave.isAlien(102) && NativeInductionArkSave.isAlien(104))
  }

}
