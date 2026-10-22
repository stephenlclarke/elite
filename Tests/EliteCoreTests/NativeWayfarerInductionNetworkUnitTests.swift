import Foundation
import Testing

@testable import EliteCore

/// Native receipt graph only; no fixture claims an executed gameplay journey.
private final class InductionNetworkFixture {
  let f: InductionSeedFixture
  let audited: NativeWayfarerInductionState
  let certification: NativeInductionNetworkCertification
  let dock: NativeMainStationDockReceipt
  init() throws {
    f = try .init()
    dock = f.dock(7, sequence: 110, visit: f.returned.actor.visit + 1)
    let source = try #require(f.held.charterSeedSource)
    let quote = try NativeInductionSeedQuote.prepare(
      source: source, parent: f.held, unit: source.units[1].id, scope: .avenorReadOnlyAudit,
      dock: dock, carrier: f.issue.carrier, revision: 1, runtimeEpoch: UUID(), firstReachLY: 7,
      fullReachLY: 7)
    let audit = try NativeInductionCharterAudit.prepare(
      parent: f.held, candidate: .seed(quote), sequence: 300, time: 2_000_000, clock: 900_500)
    audited = try f.held.auditingCharter(audit)
    let proofs = try NativeInductionNetworkProofs(parent: audited)
    certification = .init(
      operation: try NativeInductionNetworkCertification.identity(
        sequence: 310, proofs: proofs, dock: dock, carrier: f.issue.carrier, fit: 1,
        time: 2_000_010, clock: 900_510), sequence: 310, proofs: proofs, dock: dock,
      carrier: f.issue.carrier, inventoryRevision: 1, physicalTime: 2_000_010,
      flightSeconds: 900_510)
  }
  func commander() throws -> Commander {
    var commander = try f.commander(clock: 900_510)
    while commander.flightSimulation.visit < dock.actor.visit {
      commander.flightSimulation.enter(dock.station.system, arriving: true)
    }
    commander.flightSimulation.physicalTime = 2_000_010
    commander.scriptState.nextEvent = 310
    var mission = try #require(commander.scriptState.instances[audited.permission.mission])
    let state = try audited.certifyingNetwork(certification)
    mission.savedWayfarerInduction = state
    mission.milestones = state.milestones
    mission.revision += 2
    mission.acknowledge(300)
    mission.acknowledge(310)
    commander.scriptState.instances[mission.id] = mission
    try f.restoreOriginalParentSaveClaims(&commander)
    try f.restoreOriginalNetworkChildren(&commander)
    return commander
  }
}

struct NativeWayfarerInductionNetworkUnitTests {
  @Test func veilCertifiesOnlyTheOriginalNetworkOnceWithoutPaymentOrChangingAnyCustody() throws {
    let f = try InductionNetworkFixture()
    let next = try f.audited.certifyingNetwork(f.certification)
    #expect(next.valid && next.networkCertification == f.certification)
    #expect(next.milestones == f.audited.milestones.union([12]))
    #expect(
      next.payloads == f.audited.payloads && next.charterCapacity == f.audited.charterCapacity)
    #expect(
      next.charterClinicSource == f.audited.charterClinicSource
        && next.charterWorkshopSource == f.audited.charterWorkshopSource
        && next.charterSeedSource == f.audited.charterSeedSource)
    #expect(f.certification.proofs.clinic == f.audited.reception?.operation)
    #expect(f.certification.proofs.cassetteReturn == f.audited.cassetteService?.returnOperation)
    #expect(f.certification.proofs.seedReception == f.audited.seedReception?.operation)
    #expect(f.certification.proofs.keyReturn == f.audited.seedKey?.operation)
    #expect(
      f.certification.proofs.rescue == f.audited.rescueReception?.operation
        && f.audited.rescueReception?.crew.count == 2)
    #expect(f.certification.proofs.utility == f.audited.utilityReception?.operation)
    #expect(throws: (any Error).self) { try next.certifyingNetwork(f.certification) }
    #expect(
      try JSONDecoder().decode(NativeWayfarerInductionState.self, from: JSONEncoder().encode(next))
        == next)
  }

  @Test func signaturesAndLaterConsignmentsCannotReplaceTheActualSelectedCharterAudit() throws {
    let f = try InductionNetworkFixture()
    #expect(f.f.held.charterSignatures?.count == 3 && f.f.held.charterSeedSource != nil)
    #expect(throws: (any Error).self) { try NativeInductionNetworkProofs(parent: f.f.held) }
    #expect(throws: (any Error).self) { try f.f.held.certifyingNetwork(f.certification) }
    let earlier = try InductionConsentFixture().initial
    #expect(throws: (any Error).self) { try NativeInductionNetworkProofs(parent: earlier) }
  }

  @Test func rehashedWrongOriginalProofStationClockOrSequenceStillCannotCertify() throws {
    let f = try InductionNetworkFixture()
    let original = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(f.certification)) as? [String: Any])
    var variants: [[String: Any]] = []
    for (key, value): (String, Any) in [
      ("sequence", 300), ("physicalTime", 1_999_999), ("flightSeconds", 900_499),
    ] {
      var changed = original
      changed[key] = value
      variants.append(changed)
    }
    var changed = original
    var proofs = try #require(original["proofs"] as? [String: Any])
    proofs["clinic"] = f.f.booking.operation.uuidString
    changed["proofs"] = proofs
    variants.append(changed)
    changed = original
    changed["dock"] = try JSONSerialization.jsonObject(
      with: JSONEncoder().encode(f.f.dock(162, sequence: 111, visit: f.dock.actor.visit + 1)))
    variants.append(changed)
    for raw in variants {
      let d = try JSONDecoder().decode(
        NativeInductionNetworkCertification.self, from: JSONSerialization.data(withJSONObject: raw))
      let r = NativeInductionNetworkCertification(
        operation: try NativeInductionNetworkCertification.identity(
          sequence: d.sequence, proofs: d.proofs, dock: d.dock, carrier: d.carrier,
          fit: d.inventoryRevision, time: d.physicalTime, clock: d.flightSeconds),
        sequence: d.sequence, proofs: d.proofs, dock: d.dock, carrier: d.carrier,
        inventoryRevision: d.inventoryRevision, physicalTime: d.physicalTime,
        flightSeconds: d.flightSeconds)
      #expect(!r.valid(parent: f.audited))
      #expect(throws: (any Error).self) { try f.audited.certifyingNetwork(r) }
    }
  }

  @Test func certificationRequiresItsOwnActualAcknowledgementClockContactAndEarlierChildJoins()
    throws
  {
    let f = try InductionNetworkFixture()
    var commander = try f.commander()
    let id = f.audited.permission.mission
    var mission = try #require(commander.scriptState.instances[id])
    #expect(
      NativeWayfarerInductionSave.validateClaims(commander)
        && NativeInductionCrewLogSave.validateClaims(commander))
    #expect(
      NativeInductionNetworkCertificationSave.claimsValid(
        f.certification, mission: mission, commander: commander))
    mission.acknowledgedThrough = 309
    #expect(
      !NativeInductionNetworkCertificationSave.claimsValid(
        f.certification, mission: mission, commander: commander))
    mission.acknowledge(310)
    commander.scriptState.flightSeconds = 900_509
    #expect(
      !NativeInductionNetworkCertificationSave.claimsValid(
        f.certification, mission: mission, commander: commander))
    commander.scriptState.flightSeconds = 900_510
    let crewID = try #require(f.audited.crewLog?.job)
    let removedCrew = commander.scriptState.instances.removeValue(forKey: crewID)
    let originalCrew = try #require(removedCrew)
    #expect(!NativeInductionCrewLogSave.validateClaims(commander))
    commander.scriptState.instances[crewID] = originalCrew
    #expect(NativeInductionCrewLogSave.validateClaims(commander))
    let utility = try #require(f.audited.utilityReception)
    commander.scriptState.instances[utility.job] = nil
    #expect(!NativeInductionCrewLogSave.validateClaims(commander))
  }

  @Test func certificationHasClosedNewFormatsAndCannotEnterEarlierEmbeddedOrUnknownArchives() throws
  {
    let f = try InductionNetworkFixture()
    let commander = try f.commander()
    let mission = try #require(commander.scriptState.instances[f.audited.permission.mission])
    let object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(mission)) as? [String: Any])
    let bytes = try JSONSerialization.data(withJSONObject: [
      "instances": [mission.id.uuidString: object]
    ])
    for schema in [123, 124] {
      try NativeInductionCrewLogSave.validateFields(bytes, part: .missions, schema: schema)
      try NativeWayfarerInductionSave.validateFields(
        bytes, part: .missions, schema: NativeInductionArkSave.lowerSchema(schema))
    }
    for schema in [119, 120, 121, 122, 117, 118] {
      #expect(throws: (any Error).self) {
        try NativeInductionCrewLogSave.validateFields(bytes, part: .missions, schema: schema)
      }
    }
    let embedded = try JSONSerialization.data(withJSONObject: [
      "savedScriptState": ["instances": [mission.id.uuidString: object]]
    ])
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(embedded, part: .commander, schema: 123)
    }
    var changed = object
    var parent = try #require(changed["savedWayfarerInduction"] as? [String: Any])
    var certification = try #require(parent["networkCertification"] as? [String: Any])
    certification["payment"] = 76000
    parent["networkCertification"] = certification
    changed["savedWayfarerInduction"] = parent
    let unknown = try JSONSerialization.data(withJSONObject: [
      "instances": [mission.id.uuidString: changed]
    ])
    #expect(throws: (any Error).self) {
      try NativeWayfarerInductionSave.validateFields(
        unknown, part: .missions, schema: NativeInductionArkSave.lowerSchema(123))
    }
    let misplaced = try JSONSerialization.data(withJSONObject: [
      "networkCertification": certification
    ])
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(misplaced, part: .missions, schema: 123)
    }
    #expect(
      NativeInductionArkSave.isAlien(120) && NativeInductionArkSave.isAlien(122)
        && NativeInductionArkSave.isAlien(124))
  }

  @Test func laterOwnerWindowReleasePreservesCertifiedProofsAndContextHelpKeepsSennSeparate() throws
  {
    let f = try InductionNetworkFixture()
    let state = try f.audited.certifyingNetwork(f.certification)
    let capacity = try #require(state.charterCapacity)
    let signature = try #require(state.charterSignatures?.first { $0.operatorID == .seed })
    let unit = try #require(capacity.units.first { $0.operatorID == .seed && $0.slot == 3 })
    let release = try f.f.f.f.f.f.release(
      signature, capacity: capacity, unit: unit, sequence: 320, time: 2_000_020,
      flightSeconds: 900_520)
    let next = try state.releasingCharterUnit(release)
    #expect(
      next.valid && next.networkCertification == f.certification
        && next.charterAudit == state.charterAudit)
    var game = Game()
    game.screen = .contracts
    game.contractBoard.rows = [
      .init(
        board: NativeWayfarerInductionAction.certifyNetwork.key, offer: nil,
        title: NativeWayfarerInductionAction.certifyNetwork.title, reason: nil,
        wayfarerInduction: .certifyNetwork)
    ]
    let page = try #require(PlayerHelp.pages(for: game).first)
    #expect(
      page.title == "VEIL NETWORK CERTIFICATION" && page.rows.contains { $0.contains("SENN") })
    #expect(
      game.inductionNetworkRows.isEmpty && !game.wayfarerInductionReview(.certifyNetwork).allowed)
  }
}
