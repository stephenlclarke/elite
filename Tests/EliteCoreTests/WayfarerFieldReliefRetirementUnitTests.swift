import Foundation
import Testing

@testable import EliteCore

/// Structural custody and receipt inputs; no native action authority or gameplay fixture.
private struct FieldReliefRetirementFixture {
  let utility: NativeUtilityState
  let state: ScriptInstance
  let engine: ScriptEngineState
  init() {
    var utility = NativeUtilityState(owner: UUID())
    let dock = NativeMainStationDockReceipt(
      station: utility.source,
      actor: .init(system: utility.source.system, visit: 1, entity: 1),
      commanderOwner: utility.owner, sequence: 1, calendarSeconds: 0)
    let job = NativeUtilityConsignment(
      id: utility.consignmentID(0), originalUnits: utility.units(0), hull: UUID(),
      source: .init(dock), route: [7, 237], firstLegReach: 1000, fullTankReach: 1000,
      rewardTenths: 7200)
    utility.consignments = [job]
    utility.revision = 2
    self.utility = utility
    func context(_ revision: UInt64) -> ScriptEventContext {
      .init(
        galaxy: 0, system: 7, docked: true, mainStation: true, revision: revision,
        frameSeconds: 0, localSeconds: 0, flightSeconds: 0, calendarSeconds: 0,
        transitSeconds: 0, playerPosition: nil, nativeMainDock: dock)
    }
    var state = ScriptInstance(
      id: WayfarerFieldRelief.instance(job.id), definition: WayfarerFieldRelief.stateID,
      version: "1.0.0", digest: WayfarerFieldRelief.digest)
    state.savedFieldRelief = .init(
      owner: utility.owner, job: job, acceptanceSequence: 1, accepted: context(0),
      terminalReason: "targetDestroyed")
    let offer = ScriptContractOffer(
      id: WayfarerFieldRelief.offer(job.id), key: WayfarerFieldRelief.offerKey(job.id),
      title: "Field relief", briefing: "Original four-tonne batch.", destinationGalaxy: 0,
      destinationSystem: 237, reward: job.rewardTenths, deposit: 0, failureReward: 0,
      refundOnFailure: false, duration: 0, parameters: .object([:]))
    state.contract = .init(
      boardKey: WayfarerFieldRelief.boardKey, provider: "l337.wayfarer-service",
      version: "1.0.0", digest: WayfarerFieldRelief.digest, station: WayfarerFieldRelief.source,
      boardRevision: 0, group: WayfarerFieldRelief.stateID, offer: offer, clock: .local,
      acceptedAt: 0, deadline: nil, settled: true, settlementOutcome: .failed,
      settlementAmount: 0, settledAt: 0)
    state.outcome = .failed
    state.revision = 2
    state.milestones = [0]
    state.acknowledge(2)
    state.completionReceipt = .init(
      instance: state.id, definition: state.definition, version: state.version,
      digest: state.digest, outcome: .failed, sequence: 2, causeKind: "mission.receipted",
      cause: context(1), committed: context(2), revision: 2, milestones: [0],
      destroyedEncounters: [], deliveredParties: [], returnedEquipment: [],
      settlementAmount: 0, choices: nil)
    self.state = state
    var engine = ScriptEngineState()
    engine.nextEvent = 2
    engine.instances[state.id] = state
    self.engine = engine
  }
  func lost(
    _ cause: NativeUtilityLossCause = .escape, visit: UInt64 = 3, time: Double = 10,
    energy: Double? = nil
  ) -> NativeUtilityConsignment {
    var job = utility.consignments[0]
    job.phase = .lost
    job.loss = .init(
      cause: cause, visit: visit, physicalTime: time,
      energy: energy ?? (cause == .escape ? 10 : 0))
    return job
  }
  func joined(_ job: NativeUtilityConsignment, targetVisit: UInt64? = 2) -> Bool {
    WayfarerFieldReliefRetirement.joins(
      state.savedFieldRelief!, native: job, targetVisit: targetVisit,
      currentVisit: 3, physicalTime: 10)
  }
}

struct WayfarerFieldReliefRetirementUnitTests {
  @Test(arguments: [NativeUtilityLossCause.escape, .shipDestroyed])
  func laterRealLossRetiresHeldOriginalsWithoutChangingTheFailedMission(
    cause: NativeUtilityLossCause
  ) throws {
    let f = FieldReliefRetirementFixture()
    let job = f.lost(cause)
    try #require(f.utility.valid && f.state.contract?.valid == true)
    #expect(f.joined(job))
    #expect(
      WayfarerFieldReliefRetirement.permits(
        f.state, native: job, action: nil, targetVisit: 2, currentVisit: 3, physicalTime: 10))
    #expect(
      WayfarerFieldReliefSave.stateValid(
        f.state, job: job, targetDead: true, engine: f.engine, requireRecordedLoss: true))
    var utility = f.utility
    utility.consignments[0] = job
    utility.revision += 1
    #expect(utility.valid && utility.heldTonnes == 0 && utility.availableMaterials.count == 4)
    #expect(f.state.savedFieldRelief?.job.phase == .held)
    #expect(f.state.contract?.settlementAmount == 0 && f.engine.savedClueJournal == nil)
  }

  @Test func lostCargoRequiresActualCauseEnergyAndBoundedNativeTimeAndVisit() {
    let f = FieldReliefRetirementFixture()
    for job in [
      f.lost(visit: 1), f.lost(visit: 4), f.lost(time: -1), f.lost(time: .infinity),
      f.lost(time: 11), f.lost(energy: 0), f.lost(.shipDestroyed, energy: 1),
    ] { #expect(!f.joined(job)) }
    #expect(!f.joined(f.lost(), targetVisit: nil))
    #expect(!f.joined(f.lost(), targetVisit: 0))
    #expect(!f.joined(f.lost(), targetVisit: 4))
    #expect(
      !WayfarerFieldReliefRetirement.permits(
        f.state, native: f.lost(), action: .install, targetVisit: 2, currentVisit: 3,
        physicalTime: 10))
  }

  @Test func custodyJoinRejectsReplacementBatchesAndPreviouslyInstalledMaterials() throws {
    let f = FieldReliefRetirementFixture()
    let original = f.lost()
    for field in ["units", "hull", "route", "reach", "reward", "id"] {
      var changed = NativeUtilityConsignment(
        id: field == "id" ? UUID() : original.id,
        originalUnits: field == "units"
          ? [UUID(), UUID(), UUID(), UUID()] : original.originalUnits,
        hull: field == "hull" ? UUID() : original.hull, source: original.source,
        route: field == "route" ? [7, 8, 237] : original.route,
        firstLegReach: field == "reach" ? 999 : original.firstLegReach,
        fullTankReach: original.fullTankReach,
        rewardTenths: field == "reward" ? 6100 : original.rewardTenths)
      changed.phase = .lost
      changed.loss = original.loss
      #expect(!f.joined(changed))
    }
    var installed = f.utility.consignments[0]
    let contact = NativeStationDockReceipt(
      station: f.utility.target, lifecycleRevision: 1,
      dockingBinding: .init(
        actor: .init(system: f.utility.target.system, visit: 2, entity: 2), bodyID: 1),
      sequence: 1, commanderOwner: f.utility.owner)
    installed.phase = .installed
    installed.installation = .init(
      operation: f.utility.operation(installed.id, stage: "install", revision: 3),
      component: f.utility.component(0), engineer: f.utility.engineer, socket: 0,
      contact: .init(contact), revision: 3)
    let leaf = try #require(f.state.savedFieldRelief)
    #expect(
      !WayfarerFieldReliefRetirement.joins(
        leaf.replacing(installed, reason: "targetDestroyed"), native: original,
        targetVisit: 2, currentVisit: 3, physicalTime: 10))
    var state = f.state
    state.outcome = .complete
    #expect(
      !WayfarerFieldReliefRetirement.permits(
        state, native: original, action: nil, targetVisit: 2, currentVisit: 3, physicalTime: 10))
  }

  @Test func laterUnpaidReturnAndLossRoundTripKeepTheOriginalReceiptAndClosedSchema() throws {
    let f = FieldReliefRetirementFixture()
    var returned = f.utility.consignments[0]
    returned.phase = .returned
    let dock = NativeMainStationDockReceipt(
      station: f.utility.source,
      actor: .init(system: f.utility.source.system, visit: 3, entity: 1),
      commanderOwner: f.utility.owner, sequence: 2, calendarSeconds: 10)
    returned.returned = .init(dock)
    #expect(f.joined(returned))
    #expect(
      WayfarerFieldReliefRetirement.permits(
        f.state, native: returned, action: .returnMaterials, targetVisit: 2,
        currentVisit: 3, physicalTime: 10))
    let bytes = try JSONEncoder().encode(f.state)
    let restored = try JSONDecoder().decode(ScriptInstance.self, from: bytes)
    #expect(restored == f.state && restored.completionReceipt == f.state.completionReceipt)
    #expect(restored.savedFieldRelief == f.state.savedFieldRelief)
    for job in [returned, f.lost(), f.lost(.shipDestroyed)] {
      let native = try JSONDecoder().decode(
        NativeUtilityConsignment.self, from: JSONEncoder().encode(job))
      #expect(f.joined(native))
      #expect(
        WayfarerFieldReliefSave.stateValid(
          restored, job: native, targetDead: true, engine: f.engine, requireRecordedLoss: true))
      #expect(
        !WayfarerFieldReliefSave.stateValid(
          restored, job: native, targetDead: false, engine: f.engine, requireRecordedLoss: true))
    }
    var forged = restored
    forged.savedFieldRelief = restored.savedFieldRelief?.replacing(
      f.lost(), reason: "targetDestroyed")
    #expect(
      !WayfarerFieldReliefSave.stateValid(
        forged, job: f.lost(), targetDead: true, engine: f.engine, requireRecordedLoss: true))
    var invalid = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    var leaf = try #require(invalid["savedFieldRelief"] as? [String: Any])
    leaf["extraPayment"] = 7200
    invalid["savedFieldRelief"] = leaf
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(
        ScriptInstance.self, from: JSONSerialization.data(withJSONObject: invalid))
    }
  }
}
