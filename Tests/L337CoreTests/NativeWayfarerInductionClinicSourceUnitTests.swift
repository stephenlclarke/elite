import Foundation
import Testing

@testable import L337Core

/// Source/quote/receipt fixtures only; no actual owner visit, issue, pickup or audit is executed.
final class InductionClinicFixture {
  let f: InductionConsentFixture
  let signature: NativeInductionCharterSignature
  let signed: NativeWayfarerInductionState
  let issue: NativeInductionClinicIssue
  let source: NativeInductionClinicSource
  let issued: NativeWayfarerInductionState
  init() throws {
    f = try .init()
    signature = try f.signature(.clinic)
    signed = try f.initial.recordingCharterConsent(signature)
    let capacity = try #require(signed.charterCapacity)
    let choice = f.f.choice
    let fingerprint = try capacity.fingerprint
    let operation = try NativeInductionClinicIssue.identity(
      consent: signature.operation,
      allocation: capacity.allocation.operation, revision: capacity.revision,
      fingerprint: fingerprint,
      dock: signature.dock, carrier: choice.carrier, fit: 1, time: 1_000_150,
      flightSeconds: 900_150, sequence: 150)
    issue = .init(
      operation: operation, sequence: 150, parent: choice.parent,
      commanderOwner: choice.owner, operatorOwner: signature.operatorOwner,
      epoch: choice.terms.epoch,
      policy: choice.policy, consent: signature.operation,
      allocation: capacity.allocation.operation,
      capacityRevision: capacity.revision, capacityFingerprint: fingerprint,
      family: NativeInductionClinicPack.stateID, familyVersion: NativeInductionClinicPack.version,
      familyDigest: NativeInductionClinicPack.digest, profile: .original, dock: signature.dock,
      carrier: choice.carrier, inventoryRevision: 1, physicalTime: 1_000_150, flightSeconds: 900_150
    )
    source = try .init(issue: issue, parent: signed)
    issued = try signed.issuingClinicBatch(source)
  }
  func quote(
    parent: NativeWayfarerInductionState? = nil,
    scope: NativeInductionClinicQuoteScope = .ownerStation,
    dock: NativeMainStationDockReceipt? = nil, revision: UInt64 = 1, epoch: UUID? = nil,
    unit: UUID? = nil
  ) throws -> NativeInductionClinicQuote {
    try .prepare(
      source: source, parent: parent ?? issued, unit: unit ?? source.units[0].id,
      scope: scope, dock: dock ?? issue.dock, carrier: issue.carrier, revision: revision,
      runtimeEpoch: epoch ?? ScriptIdentity.uuid("clinic-source-quote-runtime"), firstReachLY: 7,
      fullReachLY: 7)
  }
  var auditorDock: NativeMainStationDockReceipt {
    NativeWayfarerInductionUnitTests().dock(
      owner: issue.commanderOwner, system: 7,
      visit: issue.dock.actor.visit + 1, sequence: 105)
  }
}

struct NativeWayfarerInductionClinicSourceUnitTests {
  @Test func originalClinicBatchUsesSixNewOperatorStockSerialsSeparateFromWindowsAndInductionCargo()
    throws
  {
    let f = try InductionClinicFixture()
    #expect(f.source.valid(parent: f.issued) && f.source.units.count == 6)
    #expect(Set(f.source.units.map(\.id)).count == 6)
    #expect(f.source.issue.operatorOwner != f.source.issue.commanderOwner)
    let original = NativeWayfarerInduction.clinicUnit(owner: f.issue.commanderOwner)
    #expect(!f.source.units.contains { $0.id == original })
    let capacity = try #require(f.issued.charterCapacity)
    #expect(Set(f.source.units.map(\.id)).isDisjoint(with: capacity.units.map(\.identity)))
    #expect(f.source.units.allSatisfy { $0.status == .available && $0.instance == nil })
    #expect(f.issued.payloads == f.signed.payloads && f.issued.milestones == f.signed.milestones)
    #expect(f.issued.charterCapacity == f.signed.charterCapacity && f.issued.milestones.max() == 10)
    #expect(throws: (any Error).self) { try f.issued.issuingClinicBatch(f.source) }
    #expect(throws: (any Error).self) { try f.f.initial.issuingClinicBatch(f.source) }
  }

  @Test func currentReachableOriginalRoutesSetExactLegPriceAndIntegrityWithoutForcedJumpOrFuel()
    throws
  {
    let f = try InductionClinicFixture()
    let quote = try f.quote()
    #expect(
      quote.family == NativeInductionClinicPack.stateID
        && quote.familyDigest == NativeInductionClinicPack.digest)
    #expect(
      quote.route.valid && quote.route.worldKeys.first == "G01-S185"
        && quote.route.worldKeys.last == "G01-S164")
    #expect(
      quote.offer.tonnes == 1 && quote.offer.flightAllowance == 1800 && quote.offer.hazardTier == 0)
    #expect(quote.offer.rewardNative == 3200 + 850 * quote.route.distancesLY.count)
    #expect(quote.terms.valid && !quote.terms.isSeedTransfer && quote.terms.maximumActive == 3)
    for (first, full) in [(0.0, 7.0), (-1, 7), (.nan, 7), (7, Double.infinity), (8, 7)] {
      #expect(throws: (any Error).self) {
        try NativeInductionClinicRoute(firstReachLY: first, fullReachLY: full)
      }
    }
    #expect(f.source.units.allSatisfy { $0.status == .available } && f.source.revision == 0)
  }

  @Test func readOnlyAvenorDelegationCannotBecomeRemotePickupOrQuoteForeignUnits() throws {
    let f = try InductionClinicFixture()
    let local = try f.quote()
    let remote = try f.quote(scope: .avenorReadOnlyAudit, dock: f.auditorDock)
    #expect(remote.scope == .avenorReadOnlyAudit && remote.offer.stockUnit == local.offer.stockUnit)
    #expect(remote.offer.id != local.offer.id && remote.dock != local.dock)
    #expect(f.source.delegation.units == f.source.units.map(\.id))
    #expect(f.source.delegation.operatorOwner == f.signature.operatorOwner)
    #expect(throws: (any Error).self) { try f.quote(scope: .ownerStation, dock: f.auditorDock) }
    #expect(throws: (any Error).self) {
      try f.quote(scope: .avenorReadOnlyAudit, dock: f.issue.dock)
    }
    #expect(throws: (any Error).self) { try f.quote(unit: UUID()) }
    #expect(throws: (any Error).self) {
      try f.quote(scope: .avenorReadOnlyAudit, dock: f.f.f.choice.dock)
    }
    #expect(f.issued.charterClinicSource == f.source && f.issued.payloads == f.signed.payloads)
  }

  @Test
  func
    laterOwnerConsentAndExactUnitReleaseKeepTheSameOriginalClinicStockAndRefreshOnlyQuoteIdentity()
    throws
  {
    let f = try InductionClinicFixture()
    let before = try f.quote()
    let workshop = try f.f.signature(
      .workshop, sequence: 151, time: 1_000_151, flightSeconds: 900_151)
    let withConsent = try f.issued.recordingCharterConsent(workshop)
    #expect(withConsent.charterClinicSource == f.source)
    let release = try f.f.release(
      f.signature, sequence: 152, time: 1_000_152, flightSeconds: 900_152)
    let released = try withConsent.releasingCharterUnit(release)
    #expect(released.charterClinicSource == f.source && released.charterCapacity?.revision == 1)
    let after = try f.quote(parent: released)
    #expect(
      after.offer.id != before.offer.id && after.capacityRevision == 1 && after.stockRevision == 0)
    #expect(
      after.offer.stockUnit == before.offer.stockUnit
        && after.offer.rewardNative == before.offer.rewardNative)
    let refitted = try f.quote(revision: 2)
    #expect(refitted.offer.id != before.offer.id)
    #expect(try f.quote(epoch: UUID()).offer.id != before.offer.id)
  }

  @Test func originalSourceDecodeRejectsMissingRefilledHeldOrForeignStockAndDoesNotRecreateUnits()
    throws
  {
    let f = try InductionClinicFixture()
    let data = try JSONEncoder().encode(f.issued)
    let restored = try JSONDecoder().decode(NativeWayfarerInductionState.self, from: data)
    #expect(restored == f.issued && restored.charterClinicSource?.units == f.source.units)
    var source = f.source
    source.units.removeLast()
    #expect(!source.valid(parent: f.issued) && source.units.count == 5)
    source = f.source
    source.units.append(source.units[0])
    #expect(!source.valid(parent: f.issued))
    source = f.source
    source.units[0].status = .held
    source.units[0].instance = UUID()
    #expect(!source.valid(parent: f.issued))
    #expect(NativeInductionClinicProfile.original.stockUnits == 6)
    #expect(NativeInductionClinicProfile.original.flightAllowance == 1800)
  }

  @Test
  func
    owningSourceClaimsRequireActualAcknowledgedIssueStationAndClockAndRefusePrematureConsignments()
    throws
  {
    let f = try InductionClinicFixture()
    var commander = try f.f.f.f.work.f.commander()
    while commander.flightSimulation.visit < f.issue.dock.actor.visit {
      commander.flightSimulation.enter(
        NativeInductionCapacityOperator.clinic.station, arriving: true)
    }
    commander.flightSimulation.physicalTime = 1_000_200
    commander.scriptState.flightSeconds = 900_200
    commander.scriptState.nextEvent = 150
    commander.nativeStations?.mainStations += [f.issue.dock.station, f.source.delegation.auditor]
    commander.nativeStations?.nextMainDockSequence = 106
    let parentID = f.issue.parent
    commander.scriptState.instances[parentID]?.savedWayfarerInduction = f.issued
    commander.scriptState.instances[parentID]?.acknowledge(150)
    #expect(NativeInductionClinicSave.validateClaims(commander))
    commander.scriptState.instances[parentID]?.acknowledgedThrough = 149
    #expect(!NativeInductionClinicSave.validateClaims(commander))
    commander.scriptState.instances[parentID]?.acknowledge(150)
    commander.scriptState.flightSeconds = 900_149
    #expect(!NativeInductionClinicSave.validateClaims(commander))
    commander.scriptState.flightSeconds = 900_200
    let premature = ScriptInstance(
      id: UUID(), definition: NativeInductionClinicPack.stateID,
      version: NativeInductionClinicPack.version, digest: NativeInductionClinicPack.digest)
    commander.scriptState.instances[premature.id] = premature
    #expect(!NativeInductionClinicSave.validateClaims(commander))
  }

  @Test
  func
    exactInternalFamilyPinsSourceAndRemainsOutsideGenericAcceptanceGalleryAndStockInitialization()
    throws
  {
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledInductionClinicDirectory)
    #expect(NativeInductionClinicPack.matches(pack))
    #expect(
      pack.manifest.coldChain == nil && pack.manifest.board == nil && pack.manifest.trial == nil)
    #expect(pack.manifest.handlers.count == 1 && pack.manifest.handlers[0].event == "timer.fired")
    var game = Game()
    game.scriptPacks = [pack]
    #expect(game.scriptUnavailable(pack) != nil)
    #expect(game.scriptGallery.isEmpty)
    let f = try InductionClinicFixture()
    game.scriptPacks.append(
      try ScriptPackLibrary.read(ScriptPackLibrary.bundledWayfarerInductionDirectory))
    game.commander = try f.f.f.f.work.f.commander()
    game.commander.system = 185
    game.commander.scriptState.instances[f.issue.parent]?.savedWayfarerInduction = f.signed
    #expect(game.wayfarerInductionRows.contains { $0.wayfarerInduction == .issueClinicStock })
    game.commander.scriptState.instances[f.issue.parent]?.savedWayfarerInduction = f.issued
    let before = game.commander
    #expect(game.wayfarerInductionRows.contains { $0.wayfarerInduction == .viewClinicStock })
    #expect(
      game.commander == before && game.commander.scriptState.savedWayfarerColdChainStock == nil)
  }

  @Test func sourceDetailUsesTheCapturedReadOnlyQuoteWithoutReplanningFromTheRenderPath() throws {
    let f = try InductionClinicFixture()
    let captured = try f.quote()
    var game = Game()
    game.commander = try f.f.f.f.work.f.commander()
    game.commander.scriptState.instances[f.issue.parent]?.savedWayfarerInduction = f.issued
    game.screen = .contracts
    game.contractBoard.rows = [
      .init(
        board: NativeWayfarerInductionAction.viewClinicStock.key,
        offer: nil, title: "Read-only original clinic source", reason: "Read-only",
        wayfarerInduction: .viewClinicStock)
    ]
    game.contractBoard.wayfarerInductionQuote = .init(
      action: .viewClinicStock, dock: f.issue.dock,
      carrier: f.issue.carrier, inventoryRevision: 1, trade: nil, epoch: captured.runtimeEpoch,
      missionRevision: 1, arkRevision: nil, rescueRevision: nil, utilityRevision: nil,
      capacityRevision: 0, capacityUnit: nil, clinicQuote: captured, issues: ["Read-only"])
    // This typed fixture has no actual live source contact; rendering must use the captured value.
    #expect(throws: (any Error).self) { try game.inductionClinicReadOnlyQuote() }
    let before = game.commander
    let detail = game.wayfarerInductionDetail()
    #expect(detail.contains { $0.hasPrefix("READ-ONLY SOURCE QUOTE AT REVIEW:") })
    #expect(detail.contains { $0.contains(captured.offer.stockUnit.uuidString) })
    #expect(game.commander == before && game.contractBoard.wayfarerInductionQuote?.allowed == false)
    #expect(PlayerHelp.pages(for: game).first?.title == "ORIGINAL CLINIC SOURCE")
  }

  @Test func closedClinicSourceSchemaRejectsEarlyEmbeddedUnknownDelegationAndGenericInstanceClaims()
    throws
  {
    let f = try InductionClinicFixture()
    var leaf = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(f.issued)) as? [String: Any])
    func data() throws -> Data {
      try JSONSerialization.data(withJSONObject: [
        "instances": [
          f.issue.parent.uuidString: [
            "definition": NativeWayfarerInduction.stateID, "digest": NativeWayfarerInduction.digest,
            "savedWayfarerInduction": leaf,
          ]
        ]
      ])
    }
    for schema in [109, 110] {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(data(), part: .missions, schema: schema)
    }
    for schema in [103, 104, 105, 106, 107, 108] {
      #expect(throws: (any Error).self) {
        try ScriptSaveJSONPreflight.validateRepairLoopFields(
          data(), part: .missions, schema: schema)
      }
    }
    let embedded = try JSONSerialization.data(withJSONObject: [
      "savedScriptState": try JSONSerialization.jsonObject(with: data())
    ])
    #expect(throws: (any Error).self) {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(embedded, part: .commander, schema: 109)
    }
    var raw = try #require(leaf["charterClinicSource"] as? [String: Any])
    raw["unlimitedStock"] = true
    leaf["charterClinicSource"] = raw
    #expect(throws: (any Error).self) {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(data(), part: .missions, schema: 109)
    }
    let alias = try JSONSerialization.data(withJSONObject: ["charterClinicSource": raw])
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(alias, part: .missions, schema: 109)
    }
    let misplaced = try JSONSerialization.data(withJSONObject: [
      "instances": [
        UUID().uuidString: [
          "charterClinicSource": raw
        ]
      ]
    ])
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(misplaced, part: .missions, schema: 109)
    }
    let generic = try JSONSerialization.data(withJSONObject: [
      "instances": [
        UUID().uuidString: [
          "definition": NativeInductionClinicPack.stateID,
          "digest": NativeInductionClinicPack.digest,
        ]
      ]
    ])
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(generic, part: .missions, schema: 109)
    }
    #expect(NativeInductionArkSave.isAlien(108) && NativeInductionArkSave.isAlien(110))
  }
}
