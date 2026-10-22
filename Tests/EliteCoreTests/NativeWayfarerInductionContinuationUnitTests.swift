import Foundation
import Testing

@testable import EliteCore

struct InductionContinuationFixture {
  let helpers = NativeWayfarerInductionUnitTests()
  let held: NativeWayfarerInductionState
  init() throws {
    let h = NativeWayfarerInductionUnitTests()
    let (state, _) = try h.fixture()
    held = try state.collecting(h.crate(state), freeTonnes: 1)
  }
  func reception(
    system: Int = 164, owner: UUID? = nil, clock: Double = 100,
    unit: UUID? = nil, cooling: UUID? = nil, remaining: Double? = nil
  ) throws -> NativeInductionClinicReception {
    let crate = try #require(held.crate)
    let dock = helpers.dock(
      owner: owner ?? held.permission.owner, system: system, visit: 3, sequence: 3)
    return .init(
      operation: try NativeWayfarerInduction.continuationOperation(
        target: NativeWayfarerInduction.receivingTarget, previous: crate.operation,
        dock: dock, carrier: crate.carrier, revision: 1, flightSeconds: clock),
      crateOperation: crate.operation, unit: unit ?? crate.unit,
      coolingUnit: cooling ?? crate.coolingUnit, dock: dock, carrier: crate.carrier,
      inventoryRevision: 1, physicalTime: 80, flightSeconds: clock,
      remaining: remaining ?? max(0, crate.deadline - clock))
  }
  func cassette(
    _ received: NativeWayfarerInductionState, system: Int = 0, owner: UUID? = nil,
    unit: UUID? = nil, condition: String = "failed-workshop-original"
  ) throws -> NativeInductionWorkshopCassette {
    let reception = try #require(received.reception)
    let dock = helpers.dock(
      owner: owner ?? received.permission.owner, system: system, visit: 4, sequence: 4)
    return .init(
      operation: try NativeWayfarerInduction.continuationOperation(
        target: NativeWayfarerInduction.cassetteTarget, previous: reception.operation,
        dock: dock, carrier: reception.carrier, revision: 1, flightSeconds: 200),
      receptionOperation: reception.operation,
      unit: unit ?? NativeWayfarerInduction.cassetteUnit(owner: received.permission.owner),
      dock: dock, carrier: reception.carrier, inventoryRevision: 1,
      physicalTime: 160, flightSeconds: 200, condition: condition)
  }
}

struct NativeWayfarerInductionContinuationUnitTests {
  @Test func clinicReceptionNeedsTheExactOriginalCoolingUnitActualNavidorAndPositiveQuality()
    throws
  {
    let f = try InductionContinuationFixture()
    let lastUsable = try f.reception(clock: 1859.5)
    let received = try f.held.receiving(lastUsable)
    #expect(received.valid && received.payloads.isEmpty && received.milestones == [0, 1, 2])
    #expect(received.crate == f.held.crate && received.reception?.remaining == 0.5)
    #expect(received.crate?.deadline == 1860 && f.held.payloads.count == 1)
    #expect(throws: (any Error).self) { try received.receiving(lastUsable) }
    for invalid in [
      try f.reception(clock: 1860), try f.reception(clock: 1861),
      try f.reception(clock: 59), try f.reception(system: 185),
      try f.reception(owner: UUID()), try f.reception(unit: UUID()),
      try f.reception(cooling: UUID()), try f.reception(remaining: 1800),
    ] {
      #expect(throws: (any Error).self) { try f.held.receiving(invalid) }
    }
    let commissioned = NativeWayfarerInductionState(permission: f.held.permission)
    #expect(throws: (any Error).self) { try commissioned.receiving(lastUsable) }
  }

  @Test func receptionConsumesOneReservationWithoutDeletingCargoOrResettingThePickupClock()
    throws
  {
    let f = try InductionContinuationFixture()
    let before = try JSONEncoder().encode(f.held)
    let loaded = try JSONDecoder().decode(NativeWayfarerInductionState.self, from: before)
    #expect(loaded == f.held && loaded.crate?.issuedFlightSeconds == 60)
    let received = try loaded.receiving(f.reception(clock: 100))
    #expect(received.permission == loaded.permission && received.crate == loaded.crate)
    #expect(received.reception?.remaining == 1760 && received.payloads.isEmpty)
    let later = try JSONDecoder().decode(
      NativeWayfarerInductionState.self, from: JSONEncoder().encode(received))
    #expect(later == received && later.valid && later.reception?.remaining == 1760)
    #expect(throws: (any Error).self) {
      try later.collecting(try #require(loaded.crate), freeTonnes: 100)
    }
    // Reception has consumed the crate; a later carrier loss cannot destroy it again.
    #expect(throws: (any Error).self) { try later.losing(f.helpers.loss(loaded)) }
  }

  @Test func workshopCassetteNeedsPriorReceptionActualEnmadanAndFreeHoldAndCannotReissue()
    throws
  {
    let f = try InductionContinuationFixture()
    let received = try f.held.receiving(f.reception())
    let cassette = try f.cassette(received)
    #expect(throws: (any Error).self) {
      try f.held.collectingCassette(cassette, freeTonnes: 1)
    }
    #expect(throws: (any Error).self) { try received.collectingCassette(cassette, freeTonnes: 0) }
    let carried = try received.collectingCassette(cassette, freeTonnes: 1)
    #expect(carried.valid && carried.milestones == [0, 1, 2, 3])
    #expect(carried.payloads == [NativeWayfarerInduction.cassettePayload: 1])
    #expect(carried.cassette?.condition == "failed-workshop-original")
    #expect(carried.reception == received.reception && carried.crate == received.crate)
    #expect(throws: (any Error).self) { try carried.collectingCassette(cassette, freeTonnes: 100) }
    for invalid in [
      try f.cassette(received, system: 185), try f.cassette(received, owner: UUID()),
      try f.cassette(received, unit: UUID()), try f.cassette(received, condition: "repaired"),
    ] {
      #expect(throws: (any Error).self) { try received.collectingCassette(invalid, freeTonnes: 1) }
    }
  }

  @Test(arguments: [false, true])
  func cassetteCarrierLossKeepsClinicHistoryAndNeverCreatesReplacementsOrAReward(escape: Bool)
    throws
  {
    let f = try InductionContinuationFixture()
    let received = try f.held.receiving(f.reception())
    let carried = try received.collectingCassette(f.cassette(received), freeTonnes: 1)
    let context = ScriptEventContext(
      galaxy: 0, system: 0, docked: false, mainStation: false, revision: 4,
      frameSeconds: 0, localSeconds: 300, flightSeconds: 300, calendarSeconds: 300,
      transitSeconds: 0, playerPosition: nil)
    let facts = NativeInductionCrateLoss(
      carrier: carried.cassette!.carrier, physicalTime: 250,
      facts: .init(
        cause: escape ? .escapePod : .shipDestroyed, sequence: 10, context: context,
        energy: escape ? 10 : 0, visit: 4))
    let lost = try carried.losing(facts)
    #expect(lost.valid && lost.payloads.isEmpty && lost.loss == nil)
    #expect(lost.reception == received.reception && lost.crate == f.held.crate)
    #expect(lost.cassette == carried.cassette && lost.milestones == [0, 1, 2, 3])
    #expect(throws: (any Error).self) { try lost.losing(facts) }
    #expect(throws: (any Error).self) {
      try lost.collectingCassette(try f.cassette(received), freeTonnes: 100)
    }
    let restored = try JSONDecoder().decode(
      NativeWayfarerInductionState.self, from: JSONEncoder().encode(lost))
    #expect(restored == lost && restored.valid)
    #expect(restored.cassetteLoss == facts && restored.reception?.remaining == 1760)
  }

  @Test(arguments: [false, true])
  func continuationSchemasPreserveLegacyOpeningButRefuseNewOrUnknownClaimsInOldEnvelopes(
    alien: Bool
  ) throws {
    let f = try InductionContinuationFixture()
    let received = try f.held.receiving(f.reception())
    let carried = try received.collectingCassette(f.cassette(received), freeTonnes: 1)
    func bytes(_ state: NativeWayfarerInductionState) throws -> Data {
      try JSONSerialization.data(withJSONObject: [
        "instances": [
          "induction": [
            "definition": NativeWayfarerInduction.stateID, "digest": NativeWayfarerInduction.digest,
            "savedWayfarerInduction": try JSONSerialization.jsonObject(
              with: JSONEncoder().encode(state)),
          ]
        ]
      ])
    }
    let current = alien ? 70 : 69
    let legacy = alien ? 68 : 67
    for schema in [current, legacy] {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(
        bytes(f.held), part: .missions, schema: schema)
      #expect(NativeWayfarerInductionSave.isAlien(schema) == alien)
      #expect(NativeWayfarerInductionSave.lowerSchema(schema) == (alien ? 66 : 65))
    }
    try ScriptSaveJSONPreflight.validateRepairLoopFields(
      bytes(carried), part: .missions, schema: current)
    #expect(throws: (any Error).self) {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(
        bytes(carried), part: .missions, schema: legacy)
    }
    var root = try #require(JSONSerialization.jsonObject(with: bytes(carried)) as? [String: Any])
    var instances = try #require(root["instances"] as? [String: Any])
    var mission = try #require(instances["induction"] as? [String: Any])
    var leaf = try #require(mission["savedWayfarerInduction"] as? [String: Any])
    var receipt = try #require(leaf["reception"] as? [String: Any])
    receipt["reward"] = 7600
    leaf["reception"] = receipt
    mission["savedWayfarerInduction"] = leaf
    instances["induction"] = mission
    root["instances"] = instances
    #expect(throws: (any Error).self) {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(
        JSONSerialization.data(withJSONObject: root), part: .missions, schema: current)
    }
  }

  @Test func boardRoutingFollowsOriginalStageLocationsAndKeepsAccreditationLocked()
    throws
  {
    let f = try InductionContinuationFixture()
    #expect(f.held.action(at: NativeWayfarerInduction.receiver) == .receive)
    #expect(f.held.action(at: NativeWayfarerInduction.workshop) == .progress)
    let received = try f.held.receiving(f.reception())
    #expect(received.action(at: NativeWayfarerInduction.workshop) == .cassette)
    #expect(received.action(at: NativeWayfarerInduction.receiver) == .progress)
    let carried = try received.collectingCassette(f.cassette(received), freeTonnes: 1)
    #expect(carried.action(at: NativeWayfarerInduction.clinic) == .service)
    #expect(carried.action(at: NativeWayfarerInduction.workshop) == .progress)
    #expect(NativeWayfarerInduction.receivingTarget == "navidor-clinic-quality-receipt")
    #expect(NativeWayfarerInduction.cassetteTarget == "enmadan-return-cassette")
    #expect(NativeWayfarerInduction.cassetteItem == "return-cassette")
    #expect(NativeWayfarerInduction.laterStages.contains("9-14"))
    #expect(NativeWayfarerInduction.currentBriefing.contains("pay nothing"))
    #expect(NativeWayfarerInduction.currentBriefing.contains("1800"))
  }
}
