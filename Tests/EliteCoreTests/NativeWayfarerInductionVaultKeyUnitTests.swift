import Foundation
import Testing

@testable import EliteCore

struct InductionVaultKeyFixture {
  let helpers: InductionCassetteServiceFixture
  let serviced: NativeWayfarerInductionState
  init() throws {
    let helpers = try InductionCassetteServiceFixture()
    self.helpers = helpers
    serviced = try helpers.carried.servicingCassette(helpers.receipt())
  }
  func key(
    system: Int = 162, owner: UUID? = nil, unit: UUID? = nil,
    receiver: SystemIdentity? = nil, target: String? = nil,
    loan: Bool = true, status: EquipmentIssueStatus = .issued, returnRemaining: Bool = true
  ) throws -> NativeInductionVaultKeyLoan {
    let service = try #require(serviced.cassetteService)
    let dock = helpers.helpers.helpers.dock(
      owner: owner ?? serviced.permission.owner, system: system, visit: 6, sequence: 6)
    let consent = try NativeWayfarerInduction.continuationOperation(
      target: NativeWayfarerInduction.seedConsentTarget, previous: service.returnOperation,
      dock: dock, carrier: service.carrier, revision: 1, flightSeconds: 400)
    let unit = unit ?? NativeWayfarerInduction.vaultKeyUnit(owner: serviced.permission.owner)
    return .init(
      operation: NativeWayfarerInduction.vaultKeyLoanOperation(consent: consent, unit: unit),
      consentOperation: consent, serviceReturnOperation: service.returnOperation, unit: unit,
      source: .init(
        mission: serviced.permission.mission, resource: NativeWayfarerInduction.keyItem,
        packDigest: NativeWayfarerInduction.digest),
      status: status, loan: loan, returnRemaining: returnRemaining,
      receiver: receiver ?? NativeWayfarerInduction.seedReceiver,
      receivingTarget: target ?? NativeWayfarerInduction.seedReceivingTarget,
      dock: dock, carrier: service.carrier, inventoryRevision: 1,
      physicalTime: 350, flightSeconds: 400)
  }
}

struct NativeWayfarerInductionVaultKeyUnitTests {
  @Test func keyLoanNeedsCompletedOriginalServiceActualEnlirinConsentAndFreeHold() throws {
    let f = try InductionVaultKeyFixture()
    let key = try f.key()
    #expect(throws: (any Error).self) { try f.serviced.borrowingVaultKey(key, freeTonnes: 0) }
    #expect(throws: (any Error).self) {
      try f.helpers.carried.borrowingVaultKey(key, freeTonnes: 1)
    }
    for invalid in [
      try f.key(system: 185), try f.key(owner: UUID()), try f.key(unit: UUID()),
      try f.key(receiver: NativeWayfarerInduction.source), try f.key(target: "another-cradle"),
      try f.key(loan: false), try f.key(status: .released), try f.key(status: .returned),
      try f.key(returnRemaining: false),
    ] {
      #expect(throws: (any Error).self) { try f.serviced.borrowingVaultKey(invalid, freeTonnes: 1) }
    }
    #expect(f.serviced.seedKey == nil && f.serviced.payloads.isEmpty)
  }

  @Test func oneOriginalLoanPreservesCustodianOwnershipAndReceivingRestrictionWithoutEscortCredit()
    throws
  {
    let f = try InductionVaultKeyFixture()
    let key = try f.key()
    let carried = try f.serviced.borrowingVaultKey(key, freeTonnes: 1)
    #expect(carried.valid && carried.payloads == [NativeWayfarerInduction.keyPayload: 1])
    #expect(carried.milestones == [0, 1, 2, 3, 4, 5] && !carried.milestones.contains(6))
    #expect(carried.seedKey?.loan == true && carried.seedKey?.status == .issued)
    #expect(carried.seedKey?.returnRemaining == true)
    #expect(carried.seedKey?.receiver == SystemIdentity(galaxy: 0, system: 91))
    #expect(carried.seedKey?.receivingTarget == "lareria-seed-ark-received")
    #expect(carried.seedKey?.source.resource == "seed-vault-key")
    #expect(carried.permission == f.serviced.permission && carried.crate == f.serviced.crate)
    #expect(carried.reception == f.serviced.reception && carried.cassette == f.serviced.cassette)
    #expect(carried.cassetteService == f.serviced.cassetteService)
    #expect(f.serviced.action(at: NativeWayfarerInduction.seedSource) == .keyLoan)
    #expect(carried.action(at: NativeWayfarerInduction.seedSource) == .progress)
    #expect(carried.action(at: NativeWayfarerInduction.seedReceiver) == .progress)
    #expect(throws: (any Error).self) { try carried.borrowingVaultKey(key, freeTonnes: 100) }
    #expect(NativeWayfarerInduction.seedConsentTarget == "enlirin-seed-consent")
    #expect(NativeWayfarerInduction.laterStages.contains("7-14"))
  }

  @Test(arguments: [false, true])
  func keyLossReleasesMassButRetainsTheOutstandingOriginalLoanAndAllEarlierReceiving(escape: Bool)
    throws
  {
    let f = try InductionVaultKeyFixture()
    let carried = try f.serviced.borrowingVaultKey(f.key(), freeTonnes: 1)
    let context = ScriptEventContext(
      galaxy: 0, system: 162, docked: false, mainStation: false, revision: 6,
      frameSeconds: 0, localSeconds: 500, flightSeconds: 500, calendarSeconds: 500,
      transitSeconds: 0, playerPosition: nil)
    let loss = NativeInductionCrateLoss(
      carrier: carried.seedKey!.carrier, physicalTime: 450,
      facts: .init(
        cause: escape ? .escapePod : .shipDestroyed, sequence: 10, context: context,
        energy: escape ? 10 : 0, visit: 6))
    let lost = try carried.losing(loss)
    #expect(lost.valid && lost.payloads.isEmpty && lost.seedKeyLoss == loss)
    #expect(lost.seedKey == carried.seedKey && lost.seedKey?.status == .issued)
    #expect(lost.seedKey?.returnRemaining == true && lost.seedKey?.loan == true)
    #expect(lost.cassetteService == carried.cassetteService && lost.cassetteLoss == nil)
    #expect(lost.reception == carried.reception && lost.loss == nil)
    #expect(throws: (any Error).self) { try lost.losing(loss) }
    #expect(throws: (any Error).self) { try lost.borrowingVaultKey(f.key(), freeTonnes: 100) }
    let restored = try JSONDecoder().decode(
      NativeWayfarerInductionState.self, from: JSONEncoder().encode(lost))
    #expect(restored == lost && restored.valid)
  }

  @Test(arguments: [false, true])
  func keySchemasReadEveryEarlierStageButRefuseEarlyUnknownOrReleasedLoanClaims(alien: Bool)
    throws
  {
    let f = try InductionVaultKeyFixture()
    let carried = try f.serviced.borrowingVaultKey(f.key(), freeTonnes: 1)
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
    let current = alien ? 74 : 73
    for schema in [alien ? 68 : 67, alien ? 70 : 69, alien ? 72 : 71, current] {
      try validate(root(f.helpers.helpers.held), schema: schema)
      #expect(NativeWayfarerInductionSave.isAlien(schema) == alien)
    }
    try validate(root(f.serviced), schema: alien ? 72 : 71)
    try validate(root(f.serviced), schema: current)
    try validate(root(carried), schema: current)
    for schema in [alien ? 68 : 67, alien ? 70 : 69, alien ? 72 : 71] {
      #expect(throws: (any Error).self) { try validate(root(carried), schema: schema) }
    }
    var value = try root(carried)
    var instances = try #require(value["instances"] as? [String: Any])
    var mission = try #require(instances["induction"] as? [String: Any])
    var leaf = try #require(mission["savedWayfarerInduction"] as? [String: Any])
    var key = try #require(leaf["seedKey"] as? [String: Any])
    for alteration in ["loan", "releasedByPlayer"] {
      var changed = key
      changed[alteration] = false
      leaf["seedKey"] = changed
      mission["savedWayfarerInduction"] = leaf
      instances["induction"] = mission
      value["instances"] = instances
      #expect(throws: (any Error).self) { try validate(value, schema: current) }
    }
    key["status"] = "returned"
    leaf["seedKey"] = key
    mission["savedWayfarerInduction"] = leaf
    instances["induction"] = mission
    value["instances"] = instances
    #expect(throws: (any Error).self) { try validate(value, schema: current) }
    #expect(NativeWayfarerInductionSave.lowerSchema(current) == (alien ? 66 : 65))
  }
}
