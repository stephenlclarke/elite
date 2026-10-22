import Foundation
import Testing

@testable import EliteCore

struct InductionCassetteServiceFixture {
  let helpers: InductionContinuationFixture
  let carried: NativeWayfarerInductionState
  init() throws {
    let helpers = try InductionContinuationFixture()
    self.helpers = helpers
    let received = try helpers.held.receiving(helpers.reception())
    carried = try received.collectingCassette(helpers.cassette(received), freeTonnes: 1)
  }
  func receipt(
    system: Int = 185, owner: UUID? = nil, unit: UUID? = nil,
    before: NativeRepairLoopCondition? = nil, after: NativeRepairLoopCondition? = nil,
    returnOperation: UUID? = nil, ownerStation: NativeMainStationIdentity? = nil
  ) throws -> NativeInductionCassetteService {
    let cassette = try #require(carried.cassette)
    let dock = helpers.helpers.dock(
      owner: owner ?? carried.permission.owner, system: system, visit: 5, sequence: 5)
    let operation = try NativeWayfarerInduction.continuationOperation(
      target: NativeWayfarerInduction.repairTarget, previous: cassette.operation,
      dock: dock, carrier: cassette.carrier, revision: 1, flightSeconds: 300)
    return .init(
      operation: operation,
      returnOperation: returnOperation
        ?? NativeWayfarerInduction.cassetteReturnOperation(
          service: operation, unit: cassette.unit, ownerStation: cassette.dock.station),
      cassetteOperation: cassette.operation, unit: unit ?? cassette.unit,
      ownerStation: ownerStation ?? cassette.dock.station, dock: dock,
      carrier: cassette.carrier, inventoryRevision: 1, physicalTime: 250, flightSeconds: 300,
      before: before ?? .failed(sourceUnit: cassette.unit),
      after: after ?? .operational(sourceUnit: cassette.unit, operation: operation))
  }
}

struct NativeWayfarerInductionCassetteServiceUnitTests {
  @Test func sharedNativeRepairTransitionRequiresTheSameFailedSerialAndRejectsASecondService()
    throws
  {
    let unit = UUID()
    let operation = UUID()
    let failed = NativeRepairLoopCondition.failed(sourceUnit: unit)
    let working = try failed.serviced(sourceUnit: unit, operation: operation)
    #expect(working == .operational(sourceUnit: unit, operation: operation))
    #expect(working.sourceUnit == failed.sourceUnit)
    #expect(throws: OwnedEquipmentError.incompatibleComponent) {
      try failed.serviced(sourceUnit: UUID(), operation: operation)
    }
    #expect(throws: OwnedEquipmentError.incompatibleComponent) {
      try working.serviced(sourceUnit: unit, operation: UUID())
    }
  }

  @Test func serviceNeedsTheOriginalUnitActualRenasNativeConditionAndItsOwnersReceipt() throws {
    let f = try InductionCassetteServiceFixture()
    let other = try f.receipt().dock.station
    let unit = try #require(f.carried.cassette?.unit)
    for invalid in [
      try f.receipt(system: 0), try f.receipt(owner: UUID()), try f.receipt(unit: UUID()),
      try f.receipt(before: .failed(sourceUnit: UUID())),
      try f.receipt(after: .failed(sourceUnit: unit)),
      try f.receipt(after: .operational(sourceUnit: unit, operation: UUID())),
      try f.receipt(returnOperation: UUID()), try f.receipt(ownerStation: other),
    ] {
      #expect(throws: (any Error).self) { try f.carried.servicingCassette(invalid) }
    }
    let lost = try f.carried.losing(
      .init(
        carrier: f.carried.cassette!.carrier, physicalTime: 200,
        facts: .init(
          cause: .shipDestroyed, sequence: 10,
          context: .init(
            galaxy: 0, system: 0, docked: false, mainStation: false, revision: 4,
            frameSeconds: 0, localSeconds: 200, flightSeconds: 200, calendarSeconds: 200,
            transitSeconds: 0, playerPosition: nil), energy: 0, visit: 4)))
    #expect(throws: (any Error).self) { try lost.servicingCassette(f.receipt()) }
    #expect(throws: (any Error).self) { try f.helpers.held.servicingCassette(f.receipt()) }
  }

  @Test func servicedOriginalReturnsOnceReleasesItsTonneAndKeepsClinicAndWorkshopHistory()
    throws
  {
    let f = try InductionCassetteServiceFixture()
    let receipt = try f.receipt()
    let returned = try f.carried.servicingCassette(receipt)
    #expect(returned.valid && returned.payloads.isEmpty && returned.milestones == [0, 1, 2, 3, 4])
    #expect(returned.cassette == f.carried.cassette && returned.reception == f.carried.reception)
    #expect(returned.crate == f.carried.crate && returned.permission == f.carried.permission)
    #expect(returned.cassetteService == receipt && returned.cassetteLoss == nil)
    #expect(receipt.ownerStation == f.carried.cassette?.dock.station)
    #expect(receipt.after.sourceUnit == f.carried.cassette?.unit)
    #expect(f.carried.payloads == [NativeWayfarerInduction.cassettePayload: 1])
    #expect(f.carried.action(at: NativeWayfarerInduction.clinic) == .service)
    #expect(returned.action(at: NativeWayfarerInduction.clinic) == .progress)
    #expect(NativeWayfarerInduction.repairTarget == "renas-cassette-loop-closed")
    #expect(NativeWayfarerInduction.laterStages.contains("11-14"))
    #expect(throws: (any Error).self) { try returned.servicingCassette(receipt) }
    #expect(throws: (any Error).self) {
      try returned.collectingCassette(try #require(f.carried.cassette), freeTonnes: 100)
    }
    let restored = try JSONDecoder().decode(
      NativeWayfarerInductionState.self, from: JSONEncoder().encode(returned))
    #expect(restored == returned && restored.valid)
  }

  @Test(arguments: [false, true])
  func serviceSchemasKeepEarlierEvidenceButRejectServiceInOlderOrAlteredEnvelopes(alien: Bool)
    throws
  {
    let f = try InductionCassetteServiceFixture()
    let returned = try f.carried.servicingCassette(f.receipt())
    func root(_ state: NativeWayfarerInductionState) throws -> [String: Any] {
      [
        "instances": [
          "induction": [
            "definition": NativeWayfarerInduction.stateID, "digest": NativeWayfarerInduction.digest,
            "savedWayfarerInduction": try JSONSerialization.jsonObject(
              with: JSONEncoder().encode(state)),
          ]
        ]
      ]
    }
    func validate(_ value: [String: Any], schema: Int) throws {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(
        JSONSerialization.data(withJSONObject: value), part: .missions, schema: schema)
    }
    let current = alien ? 72 : 71
    for earlier in [alien ? 68 : 67, alien ? 70 : 69, current] {
      try validate(root(f.helpers.held), schema: earlier)
      #expect(NativeWayfarerInductionSave.isAlien(earlier) == alien)
    }
    try validate(root(f.carried), schema: current)
    try validate(root(returned), schema: current)
    for earlier in [alien ? 68 : 67, alien ? 70 : 69] {
      #expect(throws: (any Error).self) { try validate(root(returned), schema: earlier) }
    }
    var value = try root(returned)
    var missions = try #require(value["instances"] as? [String: Any])
    var mission = try #require(missions["induction"] as? [String: Any])
    var leaf = try #require(mission["savedWayfarerInduction"] as? [String: Any])
    var service = try #require(leaf["cassetteService"] as? [String: Any])
    service["ownerPaid"] = 7600
    leaf["cassetteService"] = service
    mission["savedWayfarerInduction"] = leaf
    missions["induction"] = mission
    value["instances"] = missions
    #expect(throws: (any Error).self) { try validate(value, schema: current) }
    #expect(NativeWayfarerInductionSave.lowerSchema(current) == (alien ? 66 : 65))
  }
}
