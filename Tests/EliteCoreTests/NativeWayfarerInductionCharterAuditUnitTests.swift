import Foundation
import Testing

@testable import EliteCore

/// Receipt and finite-policy units; these fixtures do not execute actual operator visits.
private final class InductionCharterAuditFixture {
  let f: InductionConsentFixture
  let parent: NativeWayfarerInductionState
  let candidate: NativeInductionCharterAuditCandidate
  init(_ policy: NativeInductionCharterPolicy) throws {
    f = try .init(policy)
    var signed = f.initial
    for operatorID in NativeInductionCapacityOperator.allCases {
      signed = try signed.recordingCharterConsent(f.signature(operatorID))
    }
    let choice = f.f.choice
    let capacity = try #require(signed.charterCapacity)
    let signature = try #require(signed.charterSignatures?.first { $0.operatorID == .clinic })
    let fingerprint = try capacity.fingerprint
    let issue = NativeInductionClinicIssue(
      operation: try NativeInductionClinicIssue.identity(
        consent: signature.operation, allocation: capacity.allocation.operation,
        revision: capacity.revision, fingerprint: fingerprint, dock: signature.dock,
        carrier: choice.carrier, fit: 1, time: 1_000_150, flightSeconds: 900_150, sequence: 150),
      sequence: 150, parent: choice.parent, commanderOwner: choice.owner,
      operatorOwner: signature.operatorOwner, epoch: choice.terms.epoch, policy: policy,
      consent: signature.operation, allocation: capacity.allocation.operation,
      capacityRevision: capacity.revision, capacityFingerprint: fingerprint,
      family: NativeInductionClinicPack.stateID, familyVersion: NativeInductionClinicPack.version,
      familyDigest: NativeInductionClinicPack.digest, profile: .original, dock: signature.dock,
      carrier: choice.carrier, inventoryRevision: 1, physicalTime: 1_000_150, flightSeconds: 900_150
    )
    let source = try NativeInductionClinicSource(issue: issue, parent: signed)
    parent = try signed.issuingClinicBatch(source)
    let dock = NativeWayfarerInductionUnitTests().dock(
      owner: choice.owner, system: 7, visit: signature.dock.actor.visit + 4, sequence: 110)
    candidate = .clinic(
      try .prepare(
        source: source, parent: parent, unit: source.units[0].id,
        scope: .avenorReadOnlyAudit, dock: dock, carrier: choice.carrier, revision: 1,
        runtimeEpoch: ScriptIdentity.uuid("charter-audit-unit-runtime"), firstReachLY: 7,
        fullReachLY: 7))
  }
  func receipt() throws -> NativeInductionCharterAudit {
    try .prepare(
      parent: parent, candidate: candidate, sequence: 160, time: 1_000_160, clock: 900_160)
  }
}

struct NativeWayfarerInductionCharterAuditUnitTests {
  private func rehashed(_ receipt: NativeInductionCharterAudit) throws
    -> NativeInductionCharterAudit
  {
    .init(
      operation: try NativeInductionCharterAudit.identity(
        sequence: receipt.sequence, choice: receipt.choice, signatures: receipt.signatures,
        candidate: receipt.candidate, attempt: receipt.attempt, unchanged: receipt.unchanged,
        time: receipt.physicalTime, clock: receipt.flightSeconds), sequence: receipt.sequence,
      choice: receipt.choice, signatures: receipt.signatures, candidate: receipt.candidate,
      attempt: receipt.attempt, unchanged: receipt.unchanged, physicalTime: receipt.physicalTime,
      flightSeconds: receipt.flightSeconds)
  }
  @Test func bothSelectedPoliciesRefuseRealOriginalCandidateWithoutChangingAnyStockOrWindow() throws
  {
    for policy in NativeInductionCharterPolicy.allCases {
      let f = try InductionCharterAuditFixture(policy)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      let before = try encoder.encode(f.parent)
      let audit = try f.receipt()
      let capacity = try #require(f.parent.charterCapacity)
      let unit = try #require(capacity.units.first { $0.identity == audit.attempt.unit })
      #expect(unit.protected == (policy == .pooledWindows))
      #expect(audit.attempt.consignment == f.candidate.instance)
      #expect(throws: (any Error).self) { try capacity.reserving(audit.attempt) }
      #expect(throws: (any Error).self) {
        try capacity.quote(consignment: audit.attempt.consignment, unit: audit.attempt.unit)
      }
      #expect(try encoder.encode(f.parent) == before)
      let next = try f.parent.auditingCharter(audit)
      #expect(next.valid && next.milestones == f.parent.milestones.union([11]))
      #expect(
        next.charterCapacity == capacity && next.charterClinicSource == f.parent.charterClinicSource
      )
      #expect(next.charterWorkshopSource == nil && next.charterSeedSource == nil)
      #expect(
        next.payloads == f.parent.payloads && next.charterSignatures == f.parent.charterSignatures)
      #expect(throws: (any Error).self) { try next.auditingCharter(audit) }
      #expect(
        try JSONDecoder().decode(
          NativeWayfarerInductionState.self, from: JSONEncoder().encode(next)) == next)
    }
  }

  @Test func missingRealSourceOrSignaturesAndOwnerStationQuotesCannotAdvanceTheCharter() throws {
    let f = try InductionCharterAuditFixture(.protectedReservations)
    let unsigned = f.f.initial
    #expect(throws: (any Error).self) {
      try NativeInductionCharterAudit.prepare(
        parent: unsigned, candidate: f.candidate, sequence: 160, time: 1_000_160, clock: 900_160)
    }
    let noSource = f.parent.auditCopy(
      capacity: f.parent.charterCapacity, clinic: nil, workshop: nil, seed: nil)
    #expect(throws: (any Error).self) {
      try NativeInductionCharterAudit.prepare(
        parent: noSource, candidate: f.candidate, sequence: 160, time: 1_000_160, clock: 900_160)
    }
    let source = try #require(f.parent.charterClinicSource)
    let ownerQuote = try NativeInductionClinicQuote.prepare(
      source: source, parent: f.parent, unit: source.units[0].id, scope: .ownerStation,
      dock: source.issue.dock, carrier: source.issue.carrier, revision: 1, runtimeEpoch: UUID(),
      firstReachLY: 7, fullReachLY: 7)
    #expect(throws: (any Error).self) {
      try NativeInductionCharterAudit.prepare(
        parent: f.parent, candidate: .clinic(ownerQuote), sequence: 160, time: 1_000_160,
        clock: 900_160)
    }
    #expect(f.parent.milestones.max() == 10)
  }

  @Test func protectedOwnerReleaseInvalidatesStaleConfirmButPreservesEarlierActualAudit() throws {
    let f = try InductionCharterAuditFixture(.protectedReservations)
    let audit = try f.receipt()
    let signature = try #require(f.parent.charterSignatures?.first { $0.operatorID == .clinic })
    let release = try f.f.release(
      signature, capacity: f.parent.charterCapacity, sequence: 170, time: 1_000_170,
      flightSeconds: 900_170)
    let later = try f.parent.releasingCharterUnit(release)
    #expect(throws: (any Error).self) {
      try NativeInductionCharterAudit.prepare(
        parent: later, candidate: f.candidate, sequence: 180, time: 1_000_180, clock: 900_180)
    }
    let audited = try f.parent.auditingCharter(audit)
    let retained = try audited.releasingCharterUnit(release)
    #expect(retained.valid && retained.charterAudit == audit)
    #expect(audit.valid(parent: retained) && retained.charterCapacity?.revision == 1)
  }

  @Test func forgedProtectedBoundaryOwnerPolicyClockOrUnchangedFingerprintCannotBecomeAnAudit()
    throws
  {
    let f = try InductionCharterAuditFixture(.pooledWindows)
    let audit = try f.receipt()
    let object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(audit)) as? [String: Any])
    for (key, value): (String, Any) in [
      ("choice", UUID().uuidString), ("unchanged", String(repeating: "f", count: 64)),
      ("sequence", 130), ("flightSeconds", 900_100), ("physicalTime", 1_000_100),
    ] {
      var changed = object
      changed[key] = value
      let decoded = try rehashed(
        JSONDecoder().decode(
          NativeInductionCharterAudit.self, from: JSONSerialization.data(withJSONObject: changed)))
      #expect(!decoded.valid(parent: f.parent))
      #expect(throws: (any Error).self) { try f.parent.auditingCharter(decoded) }
    }
    let capacity = try #require(f.parent.charterCapacity)
    let free = try #require(capacity.units.first { !$0.protected && $0.operatorID == .clinic })
    let other = try #require(capacity.units.first { $0.protected && $0.operatorID == .seed })
    for (unit, owner, policy, instance) in [
      (
        free.identity, free.owner, NativeInductionCharterPolicy.pooledWindows,
        audit.attempt.consignment
      ),
      (other.identity, other.owner, .pooledWindows, audit.attempt.consignment),
      (audit.attempt.unit, f.parent.permission.owner, .pooledWindows, audit.attempt.consignment),
      (audit.attempt.unit, audit.attempt.owner, .protectedReservations, audit.attempt.consignment),
      (audit.attempt.unit, audit.attempt.owner, .pooledWindows, UUID()),
    ] {
      let request = NativeInductionCapacityReservation(
        operation: NativeInductionCapacityState.reservationIdentity(
          allocation: audit.attempt.allocation, revision: audit.attempt.revision, unit: unit,
          owner: owner, consignment: instance, before: audit.attempt.before),
        allocation: audit.attempt.allocation, epoch: audit.attempt.epoch, policy: policy,
        revision: audit.attempt.revision, unit: unit, owner: owner, consignment: instance,
        before: audit.attempt.before)
      let changed = NativeInductionCharterAudit(
        operation: audit.operation, sequence: audit.sequence, choice: audit.choice,
        signatures: audit.signatures, candidate: audit.candidate, attempt: request,
        unchanged: audit.unchanged, physicalTime: audit.physicalTime,
        flightSeconds: audit.flightSeconds)
      #expect(try !rehashed(changed).valid(parent: f.parent))
    }

  }

  @Test func allThreeRealDelegatedSourcesRemainEligibleWithoutBypassingThreeActiveContracts() throws
  {
    let f = try InductionSeedFixture()
    let parent = f.held
    let dock = f.dock(7, sequence: 110, visit: f.returned.actor.visit + 1)
    let clinic = try #require(parent.charterClinicSource)
    let workshop = try #require(parent.charterWorkshopSource)
    let seed = try #require(parent.charterSeedSource)
    let candidates: [NativeInductionCharterAuditCandidate] = [
      .clinic(
        try .prepare(
          source: clinic, parent: parent, unit: clinic.units[1].id, scope: .avenorReadOnlyAudit,
          dock: dock, carrier: f.issue.carrier, revision: 1, runtimeEpoch: UUID(), firstReachLY: 7,
          fullReachLY: 7)),
      .workshop(
        try .prepare(
          source: workshop, parent: parent, unit: workshop.units[1].id, scope: .avenorReadOnlyAudit,
          dock: dock, carrier: f.issue.carrier, fit: 1, runtimeEpoch: UUID(), firstReachLY: 7,
          fullReachLY: 7)),
      .seed(
        try .prepare(
          source: seed, parent: parent, unit: seed.units[1].id, scope: .avenorReadOnlyAudit,
          dock: dock, carrier: f.issue.carrier, revision: 1, runtimeEpoch: UUID(), firstReachLY: 7,
          fullReachLY: 7)),
    ]
    let capacity = try #require(parent.charterCapacity)
    #expect(try capacity.projection().filter { $0.reservation != nil }.count == 3)
    for candidate in candidates {
      let audit = try NativeInductionCharterAudit.prepare(
        parent: parent, candidate: candidate, sequence: 300, time: 2_000_000, clock: 900_500)
      let next = try parent.auditingCharter(audit)
      #expect(next.valid && next.charterCapacity == capacity)
      #expect(
        next.charterClinicSource == clinic && next.charterWorkshopSource == workshop
          && next.charterSeedSource == seed)
      #expect(try next.charterCapacity?.projection().filter { $0.reservation != nil }.count == 3)
    }
  }

  @Test func actualAuditSaveRequiresItsOwnAcknowledgementNativeClockAndHistoricalAvenorContact()
    throws
  {
    let f = try InductionSeedFixture()
    let parent = f.held
    let source = try #require(parent.charterSeedSource)
    let dock = f.dock(7, sequence: 110, visit: f.returned.actor.visit + 1)
    let quote = try NativeInductionSeedQuote.prepare(
      source: source, parent: parent, unit: source.units[1].id, scope: .avenorReadOnlyAudit,
      dock: dock, carrier: f.issue.carrier, revision: 1, runtimeEpoch: UUID(), firstReachLY: 7,
      fullReachLY: 7)
    let audit = try NativeInductionCharterAudit.prepare(
      parent: parent, candidate: .seed(quote), sequence: 300, time: 2_000_000, clock: 900_500)
    var commander = try f.commander()
    while commander.flightSimulation.visit < dock.actor.visit {
      commander.flightSimulation.enter(dock.station.system, arriving: true)
    }
    let id = parent.permission.mission
    var mission = try #require(commander.scriptState.instances[id])
    mission.savedWayfarerInduction = try parent.auditingCharter(audit)
    mission.milestones = try #require(mission.savedWayfarerInduction).milestones
    mission.revision += 1
    #expect(
      !NativeInductionCharterAuditSave.claimsValid(audit, mission: mission, commander: commander))
    mission.acknowledge(300)
    commander.scriptState.nextEvent = 300
    commander.scriptState.instances[id] = mission
    #expect(
      NativeInductionCharterAuditSave.claimsValid(audit, mission: mission, commander: commander))
    try f.restoreOriginalParentSaveClaims(&commander)
    let sale = try #require(commander.scriptState.firstNativeCommoditySale)
    #expect(parent.permission.trade == .sale(sale.operation))
    #expect(NativeWayfarerInductionSave.validateClaims(commander))
    let originalSale = commander.scriptState.firstNativeCommoditySale
    commander.scriptState.firstNativeCommoditySale = nil
    #expect(!NativeWayfarerInductionSave.validateClaims(commander))
    commander.scriptState.firstNativeCommoditySale = originalSale
    let clinicReceiver = try #require(parent.reception?.dock.station)
    commander.nativeStations?.mainStations.removeAll { $0 == clinicReceiver }
    #expect(!NativeWayfarerInductionSave.validateClaims(commander))
    commander.nativeStations?.mainStations.append(clinicReceiver)
    #expect(NativeWayfarerInductionSave.validateClaims(commander))
    commander.scriptState.flightSeconds = 900_499
    #expect(
      !NativeInductionCharterAuditSave.claimsValid(audit, mission: mission, commander: commander))
    commander.scriptState.flightSeconds = 900_500
    commander.nativeStations?.mainStations.removeAll { $0 == dock.station }
    #expect(
      !NativeInductionCharterAuditSave.claimsValid(audit, mission: mission, commander: commander))
  }

  @Test
  func closedAuditFormatsRejectEarlierEmbeddedUnknownAndMisplacedClaimsWhileRetainingOldSources()
    throws
  {
    let f = try InductionCharterAuditFixture(.protectedReservations)
    let state = try f.parent.auditingCharter(f.receipt())
    var mission = ScriptInstance(
      id: state.permission.mission, definition: NativeWayfarerInduction.stateID,
      version: NativeWayfarerInduction.version, digest: NativeWayfarerInduction.digest)
    mission.savedWayfarerInduction = state
    mission.milestones = state.milestones
    let encoded = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(mission)) as? [String: Any])
    let bytes = try JSONSerialization.data(withJSONObject: [
      "instances": [mission.id.uuidString: encoded]
    ])
    for schema in [119, 120, 121, 122] {
      try NativeInductionCrewLogSave.validateFields(bytes, part: .missions, schema: schema)
      try NativeWayfarerInductionSave.validateFields(
        bytes, part: .missions, schema: NativeInductionArkSave.lowerSchema(schema))
      #expect(
        NativeInductionCrewLogSave.supportsSeed(schema)
          && NativeInductionCrewLogSave.supportsWorkshop(schema))
    }
    for schema in [117, 118, 115, 116] {
      #expect(throws: (any Error).self) {
        try NativeInductionCrewLogSave.validateFields(bytes, part: .missions, schema: schema)
      }
    }
    let embedded = try JSONSerialization.data(withJSONObject: [
      "savedScriptState": ["instances": [mission.id.uuidString: encoded]]
    ])
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(embedded, part: .commander, schema: 119)
    }
    var altered = encoded
    var leaf = try #require(altered["savedWayfarerInduction"] as? [String: Any])
    var raw = try #require(leaf["charterAudit"] as? [String: Any])
    raw["remotePickup"] = true
    leaf["charterAudit"] = raw
    altered["savedWayfarerInduction"] = leaf
    let unknown = try JSONSerialization.data(withJSONObject: [
      "instances": [mission.id.uuidString: altered]
    ])
    #expect(throws: (any Error).self) {
      try NativeWayfarerInductionSave.validateFields(
        unknown, part: .missions, schema: NativeInductionArkSave.lowerSchema(119))
    }
    let misplaced = try JSONSerialization.data(withJSONObject: ["charterAudit": raw])
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(misplaced, part: .missions, schema: 119)
    }
    #expect(
      NativeInductionArkSave.isAlien(118) && NativeInductionArkSave.isAlien(120)
        && NativeInductionArkSave.isAlien(122))
  }

  @Test func auditHelpAndReadOnlyProjectionDoNotCreateRemotePickupOrPrematureCertification() throws
  {
    let f = try InductionCharterAuditFixture(.pooledWindows)
    var game = Game()
    game.screen = .contracts
    game.contractBoard.rows = [
      .init(
        board: NativeWayfarerInductionAction.auditCharter.key, offer: nil,
        title: NativeWayfarerInductionAction.auditCharter.title, reason: nil,
        wayfarerInduction: .auditCharter)
    ]
    let page = try #require(PlayerHelp.pages(for: game).first)
    #expect(page.title == "AVENOR CHARTER AUDIT" && page.rows.contains { $0.contains("NO STOCK") })
    #expect(
      game.inductionCharterAuditRows.isEmpty && !game.wayfarerInductionReview(.auditCharter).allowed
    )
    let audit = try f.receipt()
    let next = try f.parent.auditingCharter(audit)
    #expect(next.milestones.max() == 11 && next.payloads.isEmpty)
    #expect(next.charterClinicSource?.units.allSatisfy { $0.status == .available } == true)
    #expect(next.charterCapacity?.events.isEmpty == true)
  }
}
