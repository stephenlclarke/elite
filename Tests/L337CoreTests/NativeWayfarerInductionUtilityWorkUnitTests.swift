import Foundation
import Testing

@testable import L337Core

/// Typed receipt/policy fixtures only; they do not execute or qualify a native maintenance journey.
final class InductionUtilityWorkFixture {
  let f: InductionUtilityFixture
  init() throws { f = try .init() }
  func arm(_ role: NativeInductionUtilityRole, attempt: Int = 0) throws -> NativeInductionUtilityArm
  {
    let index = try #require(NativeInductionUtilityRole.allCases.firstIndex(of: role))
    let actor = ActorIdentity(
      system: NativeInductionUtilitySource.location,
      visit: f.authorization.dock.actor.visit + 1, entity: UInt64(10 + index))
    let player = ActorIdentity(system: actor.system, visit: actor.visit, entity: 0)
    let sequence = UInt64(110 + index * 2 + attempt * 10)
    let time = 1_000_010 + Double(index * 30 + attempt * 10)
    let clock = 900_010 + Double(index * 30 + attempt * 10)
    let epoch = ScriptIdentity.uuid("utility-unit-runtime")
    let operation = try NativeInductionUtilityArm.identity(
      authorization: f.authorization.operation, role: role, actor: actor, player: player,
      carrier: f.authorization.carrier, revision: 1, epoch: epoch,
      time: time, flightSeconds: clock, sequence: sequence)
    return .init(
      operation: operation, sequence: sequence, authorization: f.authorization.operation,
      owner: f.source.owner, job: f.authorization.job, role: role,
      module: f.source.module(role), kit: f.source.kit(role), actor: actor, player: player,
      carrier: f.authorization.carrier, inventoryRevision: 1, epoch: epoch,
      physicalTime: time, flightSeconds: clock)
  }
  func work(_ role: NativeInductionUtilityRole, seconds: Double = 20, repaired: Bool = true) throws
    -> NativeInductionUtilityWork
  {
    let arm = try arm(role)
    let segment = NativeInductionUtilityWorkSegment(
      arm: arm, seconds: seconds, intervals: UInt64(ceil(seconds * 10)),
      first: arm.physicalTime, last: arm.physicalTime + seconds,
      lastRange: 100, lastSpeed: 0.5, lastAim: 0.01)
    var work = NativeInductionUtilityWork(segments: [segment])
    if repaired {
      let history = try NativeFlightReception.hash(work.segments)
      let sequence = arm.sequence + 1
      let time = arm.physicalTime + seconds
      let operation = try NativeInductionUtilityRepair.identity(
        authorization: arm.authorization, module: arm.module, kit: arm.kit,
        history: history, actor: arm.actor, time: time, sequence: sequence)
      work.repair = .init(
        operation: operation, sequence: sequence,
        authorization: arm.authorization, owner: arm.owner, job: arm.job, role: role,
        module: arm.module, kit: arm.kit, actor: arm.actor, history: history,
        physicalTime: time, flightSeconds: arm.flightSeconds + seconds)
    }
    return work
  }
  func state(repaired: Bool = true) throws -> NativeInductionUtilityState {
    var state = f.state()
    state.admission = [:]
    for (index, role) in NativeInductionUtilityRole.allCases.enumerated() {
      let arm = try arm(role)
      state.admission?[role.rawValue] = .init(actor: arm.actor, physicalTime: 1_000_002)
      state.modules[index].work = try work(role, seconds: repaired ? 20 : 4.5, repaired: repaired)
      if repaired {
        state.modules[index].fault = role.workingFault
        state.modules[index].availableKits = 0
      }
    }
    return state
  }
  func receipt(_ state: NativeInductionUtilityState, repairs: [UUID]? = nil) throws
    -> NativeInductionUtilityReception
  {
    let repairs = repairs ?? state.modules.compactMap { $0.work?.repair?.operation }
    let dock = NativeWayfarerInductionUnitTests().dock(
      owner: f.source.owner, system: 190,
      visit: f.authorization.dock.actor.visit + 1, sequence: 102)
    let operation = try NativeInductionUtilityReception.identity(
      authorization: f.authorization.operation, repairs: repairs, dock: dock,
      carrier: f.authorization.carrier, revision: 1, time: 1_000_110,
      flightSeconds: 900_110, sequence: 120)
    return .init(
      operation: operation, sequence: 120, owner: f.source.owner,
      parent: f.source.parent, job: f.authorization.job, issue: f.source.issue,
      authorization: f.authorization.operation, rescue: f.source.reception,
      operatorID: f.source.operatorID, targets: NativeInductionUtilityRole.allCases.map(\.target),
      modules: state.modules.map(\.module), kits: state.modules.map(\.kit), repairs: repairs,
      dock: dock, carrier: f.authorization.carrier, inventoryRevision: 1,
      physicalTime: 1_000_110, flightSeconds: 900_110)
  }
}

struct NativeWayfarerInductionUtilityWorkUnitTests {
  @Test func maintenanceEnvelopeRequiresEveryFrontSurfaceSpeedAimAndOcclusionBoundary() {
    for range in [50.0, 100, 150] {
      #expect(
        NativeInductionUtilityEnvelope.qualifies(
          range: range, speed: 1,
          aim: 2 * .pi / 180, front: true, unobstructed: true))
    }
    for (range, speed, aim, front, clear) in [
      (49.999, 0.0, 0.0, true, true), (150.001, 0, 0, true, true),
      (100, 1.001, 0, true, true), (100, 0, 0.035, true, true),
      (100, 0, 0, false, true), (100, 0, 0, true, false),
      (Double.nan, 0, 0, true, true), (100, Double.infinity, 0, true, true),
    ] {
      #expect(
        !NativeInductionUtilityEnvelope.qualifies(
          range: range, speed: speed,
          aim: aim, front: front, unobstructed: clear))
    }
  }

  @Test func onlyPositiveBoundedNativeIntervalsCreditAndNeverExceedTwentySeconds() {
    #expect(NativeInductionUtilityEnvelope.credit(before: 0, start: 10, end: 10) == nil)
    #expect(NativeInductionUtilityEnvelope.credit(before: 0, start: 10, end: 9) == nil)
    #expect(NativeInductionUtilityEnvelope.credit(before: 0, start: 10, end: 10.2) == nil)
    #expect(NativeInductionUtilityEnvelope.credit(before: 0, start: .nan, end: 10) == nil)
    let credit = NativeInductionUtilityEnvelope.credit(before: 19.95, start: 10, end: 10.1)
    #expect(abs((credit ?? -1) - 0.05) < 1e-8)
    #expect(NativeInductionUtilityEnvelope.credit(before: 20, start: 10, end: 10.1) == 0)
  }

  @Test func partialWorkRoundTripsWithoutSpendingKitsRepairingControlsOrAdvancingStageTen() throws {
    let fixture = try InductionUtilityWorkFixture()
    let state = try fixture.state(repaired: false)
    #expect(state.shapeValid(parent: fixture.f.parent))
    let restored = try JSONDecoder().decode(
      NativeInductionUtilityState.self,
      from: JSONEncoder().encode(state))
    #expect(restored == state && restored.receiving == nil)
    #expect(
      restored.modules.allSatisfy {
        $0.work?.seconds == 4.5 && $0.work?.repair == nil && $0.availableKits == 1
          && $0.fault == $0.role.initialFault
      })
    #expect(!fixture.f.parent.milestones.contains(9))
  }

  @Test func rearmingPreservesEarlierPartialTimeAndRejectsOverlappingOrDuplicateArmHistory() throws
  {
    let fixture = try InductionUtilityWorkFixture()
    var work = try fixture.work(.inlet, seconds: 4.5, repaired: false)
    let second = try fixture.arm(.inlet, attempt: 1)
    work.segments.append(.init(arm: second))
    #expect(
      work.seconds == 4.5
        && work.valid(
          authorization: fixture.f.authorization,
          source: fixture.f.source, role: .inlet)
    )
    work.segments.append(work.segments[0])
    #expect(
      !work.valid(authorization: fixture.f.authorization, source: fixture.f.source, role: .inlet))
    work.segments.removeLast()
    work.segments[0].last = second.physicalTime + 1
    #expect(
      !work.valid(authorization: fixture.f.authorization, source: fixture.f.source, role: .inlet))
  }

  @Test func originalKitAndWorkingControlMustChangeTogetherWithCompleteBoundRepairHistory() throws {
    let fixture = try InductionUtilityWorkFixture()
    let good = try fixture.state()
    #expect(good.shapeValid(parent: fixture.f.parent))
    var state = good
    state.modules[0].availableKits = 1
    #expect(!state.shapeValid(parent: fixture.f.parent))
    state = good
    state.modules[1].fault = NativeInductionUtilityRole.buffer.initialFault
    #expect(!state.shapeValid(parent: fixture.f.parent))
    state = good
    state.modules[2].work?.segments[0].seconds = 19.9
    #expect(!state.shapeValid(parent: fixture.f.parent))
    state = good
    state.modules[0].work?.segments[0].lastSpeed = 1.01
    #expect(!state.shapeValid(parent: fixture.f.parent))
  }

  @Test func liveReceivingNeedsAllThreeDistinctOriginalRepairsAndOnlyThenUnlocksStageTenOnce()
    throws
  {
    let fixture = try InductionUtilityWorkFixture()
    var state = try fixture.state()
    let receipt = try fixture.receipt(state)
    let next = try fixture.f.parent.receivingUtilityRoute(receipt)
    #expect(next.milestones == fixture.f.parent.milestones.union([9]))
    #expect(next.payloads == fixture.f.parent.payloads)
    #expect(!state.shapeValid(parent: next))
    state.receiving = receipt
    #expect(state.shapeValid(parent: next))
    #expect(throws: (any Error).self) { try next.receivingUtilityRoute(receipt) }
    let wrong = try fixture.receipt(state, repairs: [UUID(), UUID(), UUID()])
    let foreign = try fixture.f.parent.receivingUtilityRoute(wrong)
    #expect(!state.shapeValid(parent: foreign))
    #expect(NativeWayfarerInduction.laterStages.contains("12-14"))
  }

  @Test func workAndReceivingClaimsNeedOwningAcknowledgementsClockAndReverseSourceJoin() throws {
    let fixture = try InductionUtilityWorkFixture()
    var state = try fixture.state()
    let receipt = try fixture.receipt(state)
    let next = try fixture.f.parent.receivingUtilityRoute(receipt)
    state.receiving = receipt
    var commander = try fixture.f.commander()
    while commander.flightSimulation.visit < receipt.dock.actor.visit {
      commander.flightSimulation.enter(NativeInductionUtilitySource.location, arriving: true)
    }
    while commander.flightSimulation.nextActor <= 12 {
      _ = commander.flightSimulation.allocateActor()
    }
    commander.flightSimulation.physicalTime = 1_000_200
    commander.scriptState.flightSeconds = 900_200
    commander.scriptState.nextEvent = 120
    commander.nativeStations?.nextMainDockSequence = 103
    var parent = try #require(commander.scriptState.instances[fixture.f.source.parent])
    parent.savedWayfarerInduction = next
    var child = fixture.f.child()
    child.savedNativeInductionUtility = state
    child.revision = 1000
    child.milestones = [0]
    for sequence: UInt64 in [110, 111, 112, 113, 114, 115, 120] {
      parent.acknowledge(sequence)
      child.acknowledge(sequence)
    }
    var actors: [String: ScriptOwnedActor] = [:]
    for role in NativeInductionUtilityRole.allCases {
      var actor = try fixture.f.prepared(role)
      let resources = try NativeInductionUtilityPack.initialResources(
        state: fixture.f.child(), actor: actor)
      let arm = try fixture.arm(role)
      actor.body.id = Int(arm.actor.entity)
      actor.presence = .unloaded
      actor.body.physical = .init(
        identity: arm.actor, population: .mission,
        npc: resources
      )
      actors[role.rawValue] = actor
    }
    var group = ScriptOwnedEncounter(
      id: NativeInductionUtilityPack.encounter,
      galaxy: 0, system: 190, actors: actors)
    group.admitted = true
    child.ownedEncounters[group.id] = group
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.instances[child.id] = child
    #expect(NativeInductionUtilitySave.validateClaims(commander))
    commander.scriptState.instances[child.id] = nil
    #expect(!NativeInductionUtilitySave.validateClaims(commander))
    commander.scriptState.instances[child.id] = child
    commander.flightSimulation.physicalTime = 1_000_100
    #expect(!NativeInductionUtilitySave.validateClaims(commander))
    commander.flightSimulation.physicalTime = 1_000_200
    commander.scriptState.instances[child.id]?.acknowledgedThrough = 119
    #expect(!NativeInductionUtilitySave.validateClaims(commander))
  }

  @Test func maintenanceReviewBindsPaintedConfirmAndHeldReturnCannotLeakIntoWeaponsAfterStop()
    throws
  {
    let fixture = try InductionUtilityWorkFixture()
    let arm = try fixture.arm(.inlet)
    var game = Game()
    game.docked = false
    game.screen = .front
    game.commander.system = 190
    let initialEnergy = game.energy
    let initialHeat = game.laserHeat
    let initialDischarges = game.dischargeAudio.events
    let before = game.scriptPagePresentation
    let review = NativeInductionUtilityWorkReview(
      nonce: UUID(), job: arm.job,
      revision: 1, role: .inlet, actor: arm.actor, carrier: arm.carrier,
      inventoryRevision: 1, epoch: arm.epoch)
    game.inductionUtilityWorkRuntime.review = review
    let shown = game.scriptPagePresentation
    #expect(before != shown && shown.page == .inductionUtility(review.nonce))
    #expect(game.inductionUtilityUsesReturn)
    #expect(PlayerHelp.pages(for: game).first?.title == "ENRON MAINTENANCE")
    let admitted = game.admitFlightFire(held: true)
    #expect(!admitted && game.flightTrigger.held && game.workFireSuspended)
    game.interruptInductionUtilityWork()
    #expect(game.inductionUtilityWorkRuntime.review == nil)
    let afterStop = game.admitFlightFire(held: true)
    #expect(!afterStop)
    _ = game.admitFlightFire(held: false)
    let afterRelease = game.admitFlightFire(held: true)
    #expect(afterRelease)
    #expect(game.energy == initialEnergy && game.laserHeat == initialHeat)
    #expect(game.dischargeAudio.events == initialDischarges)
  }

  @Test func closedWorkEnvelopeRejectsEarlierSchemaUnknownProgressAndUnpairedReceivingFields()
    throws
  {
    let fixture = try InductionUtilityWorkFixture()
    let state = try fixture.state(repaired: false)
    var leaf = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
    func validate(_ schema: Int) throws {
      try NativeInductionUtilitySave.validateFields(
        [
          "definition": NativeInductionUtilityPack.stateID,
          "digest": NativeInductionUtilityPack.digest,
          "savedNativeInductionUtility": leaf,
        ], schema: schema, embedded: false)
    }
    try validate(99)
    try validate(100)
    for schema in [95, 96, 97, 98] {
      #expect(throws: (any Error).self) { try validate(schema) }
    }
    let repaired = try fixture.state()
    let receipt = try fixture.receipt(repaired)
    let parent = try fixture.f.parent.receivingUtilityRoute(receipt)
    let rawParent = try JSONSerialization.jsonObject(with: JSONEncoder().encode(parent))
    let envelope = try JSONSerialization.data(withJSONObject: [
      "instances": [
        fixture.f.source.parent.uuidString: [
          "definition": NativeWayfarerInduction.stateID, "digest": NativeWayfarerInduction.digest,
          "savedWayfarerInduction": rawParent,
        ]
      ]
    ])
    // The parent's guard must see the original99/100 envelope before older codecs lower it.
    try ScriptSaveJSONPreflight.validateRepairLoopFields(envelope, part: .missions, schema: 99)
    try ScriptSaveJSONPreflight.validateRepairLoopFields(envelope, part: .missions, schema: 100)
    for schema in [95, 96, 97, 98] {
      #expect(throws: (any Error).self) {
        try ScriptSaveJSONPreflight.validateRepairLoopFields(
          envelope, part: .missions, schema: schema)
      }
    }
    leaf["freeRepair"] = true
    #expect(throws: (any Error).self) { try validate(99) }
    leaf.removeValue(forKey: "freeRepair")
    var modules = try #require(leaf["modules"] as? [[String: Any]])
    var work = try #require(modules[0]["work"] as? [String: Any])
    work["seconds"] = 20
    modules[0]["work"] = work
    leaf["modules"] = modules
    #expect(throws: (any Error).self) { try validate(99) }
  }
}
