import Foundation
import Testing

@testable import L337Core

/// Contact/receipt/ledger policy only; no fixture executes native operator visits or unit release.
final class InductionConsentFixture {
  let f: InductionCapacityFixture
  let initial: NativeWayfarerInductionState
  init(_ policy: NativeInductionCharterPolicy = .protectedReservations) throws {
    f = try .init(policy)
    initial = try f.chosen.allocatingCharterCapacity(f.initial)
  }
  func signature(
    _ operatorID: NativeInductionCapacityOperator,
    capacity: NativeInductionCapacityState? = nil, station: Int? = nil,
    sequence: UInt64? = nil, time: Double? = nil, flightSeconds: Double? = nil
  ) throws -> NativeInductionCharterSignature {
    let capacity = capacity ?? f.initial
    let index = try #require(NativeInductionCapacityOperator.allCases.firstIndex(of: operatorID))
    let dock = NativeWayfarerInductionUnitTests().dock(
      owner: f.choice.owner,
      system: station ?? operatorID.station.system,
      visit: f.choice.dock.actor.visit + 1 + UInt64(index), sequence: 104 + UInt64(index))
    let sequence = sequence ?? (126 + UInt64(index))
    let time = time ?? (1_000_130 + Double(index))
    let clock = flightSeconds ?? (900_130 + Double(index))
    let fingerprint = try capacity.fingerprint
    let operation = try NativeInductionCharterSignature.identity(
      choice: f.choice.operation,
      allocation: capacity.allocation.operation, operatorID: operatorID,
      revision: capacity.revision,
      fingerprint: fingerprint, dock: dock, carrier: f.choice.carrier, fit: 1,
      time: time, flightSeconds: clock, sequence: sequence)
    return .init(
      operation: operation, sequence: sequence, choice: f.choice.operation,
      allocation: capacity.allocation.operation, epoch: f.choice.terms.epoch,
      policy: f.choice.policy,
      parent: f.choice.parent, commanderOwner: f.choice.owner, operatorID: operatorID,
      operatorOwner: operatorID.owner(epoch: f.choice.terms.epoch),
      target: NativeInductionCharterSignature.target(operatorID, policy: f.choice.policy),
      units: try NativeFlightReception.hash(capacity.units.filter { $0.operatorID == operatorID }),
      capacityRevision: capacity.revision, capacityFingerprint: fingerprint, protectedMinimum: 2,
      dock: dock, carrier: f.choice.carrier, inventoryRevision: 1, physicalTime: time,
      flightSeconds: clock)
  }
  func release(
    _ consent: NativeInductionCharterSignature,
    capacity: NativeInductionCapacityState? = nil, unit: NativeInductionCapacityUnit? = nil,
    dock: NativeMainStationDockReceipt? = nil,
    sequence: UInt64? = nil, time: Double? = nil, flightSeconds: Double? = nil
  ) throws -> NativeInductionCapacityRelease {
    let capacity = capacity ?? f.initial
    let dock = dock ?? consent.dock
    let selected = try #require(
      unit ?? capacity.units.first { $0.operatorID == consent.operatorID && !$0.protected })
    let sequence = sequence ?? (140 + capacity.revision)
    let time = time ?? 1_000_150
    let flightSeconds = flightSeconds ?? 900_150
    let before = try capacity.fingerprint
    let operation = try NativeInductionCapacityRelease.identity(
      allocation: capacity.allocation.operation,
      unit: selected.identity, owner: selected.owner, revision: capacity.revision, before: before,
      dock: dock, carrier: consent.carrier, fit: 1, time: time,
      flightSeconds: flightSeconds, sequence: sequence, consent: consent.operation)
    return .init(
      operation: operation, allocation: capacity.allocation.operation,
      epoch: capacity.allocation.epoch, policy: capacity.allocation.policy,
      revision: capacity.revision,
      unit: selected.identity, owner: selected.owner, operatorID: selected.operatorID,
      dock: dock,
      carrier: consent.carrier, inventoryRevision: 1, physicalTime: time,
      flightSeconds: flightSeconds, sequence: sequence, before: before, consent: consent.operation)
  }
}

struct NativeWayfarerInductionCharterConsentUnitTests {
  @Test
  func threeDistinctActualOwnerConsentReceiptsBindEachSelectedBranchWithoutReleaseOrStageTwelve()
    throws
  {
    for policy in NativeInductionCharterPolicy.allCases {
      let f = try InductionConsentFixture(policy)
      var state = f.initial
      for operatorID in NativeInductionCapacityOperator.allCases {
        let signature = try f.signature(operatorID)
        state = try state.recordingCharterConsent(signature)
        #expect(signature.operatorOwner != signature.commanderOwner)
        #expect(
          signature.target == operatorID.rawValue
            + (policy == .pooledWindows ? "-pooled-signature" : "-reserved-signature"))
      }
      #expect(state.valid && state.charterSignatures?.count == 3)
      #expect(
        state.charterCapacity == f.initial.charterCapacity
          && state.charterCapacity?.events.isEmpty == true)
      #expect(state.milestones == f.initial.milestones && state.milestones.max() == 10)
      #expect(
        state.payloads == f.initial.payloads && state.utilityReception == f.initial.utilityReception
      )
      let restored = try JSONDecoder().decode(
        NativeWayfarerInductionState.self, from: JSONEncoder().encode(state))
      #expect(restored == state)
    }
  }

  @Test
  func ownerConsentRefusesWrongStationChangedEpochMinimaUnitsRevisionAndDuplicateOrOtherBranch()
    throws
  {
    let f = try InductionConsentFixture()
    let good = try f.signature(.clinic)
    let wrong = try f.signature(.clinic, station: 7)
    #expect(throws: (any Error).self) { try f.initial.recordingCharterConsent(wrong) }
    let signed = try f.initial.recordingCharterConsent(good)
    #expect(throws: (any Error).self) { try signed.recordingCharterConsent(good) }
    let pooled = try InductionConsentFixture(.pooledWindows)
    #expect(throws: (any Error).self) { try pooled.initial.recordingCharterConsent(good) }
    let original = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(good)) as? [String: Any])
    for (key, value): (String, Any) in [
      ("epoch", UUID().uuidString), ("protectedMinimum", 0),
      ("units", String(repeating: "a", count: 64)),
      ("capacityRevision", 1), ("operatorOwner", f.f.choice.owner.uuidString),
    ] {
      var altered = original
      altered[key] = value
      let decoded = try JSONDecoder().decode(
        NativeInductionCharterSignature.self,
        from: JSONSerialization.data(withJSONObject: altered))
      #expect(!decoded.valid(choice: f.f.choice, capacity: f.f.initial))
    }
  }

  @Test func separatelySignedNamedFreeUnitReleasePreservesHistoricalConsentAndAllProtectedCapacity()
    throws
  {
    let f = try InductionConsentFixture()
    let consent = try f.signature(.clinic)
    let signed = try f.initial.recordingCharterConsent(consent)
    let release = try f.release(consent)
    let released = try signed.releasingCharterUnit(release)
    let capacity = try #require(released.charterCapacity)
    let eligible = try capacity.projection().filter { capacity.eligible($0) }
    #expect(eligible.map(\.unit.identity) == [release.unit])
    #expect(eligible.first?.unit.owner == consent.operatorOwner)
    #expect(released.charterSignatures == signed.charterSignatures)
    #expect(consent.valid(choice: f.f.choice, capacity: capacity))
    #expect(released.milestones == signed.milestones && released.payloads == signed.payloads)
    #expect(throws: (any Error).self) { try f.initial.releasingCharterUnit(release) }
    #expect(throws: (any Error).self) { try released.releasingCharterUnit(release) }
    let minimum = try #require(capacity.units.first { $0.operatorID == .clinic && $0.protected })
    let protectedRelease = try f.release(consent, capacity: capacity, unit: minimum)
    #expect(throws: (any Error).self) { try released.releasingCharterUnit(protectedRelease) }
  }

  @Test func nativeReleaseSaveNeedsSameActualSignatureAcknowledgementStationHistoryAndClock() throws
  {
    let f = try InductionConsentFixture()
    let consent = try f.signature(.clinic)
    let signed = try f.initial.recordingCharterConsent(consent)
    let release = try f.release(consent)
    let released = try signed.releasingCharterUnit(release)
    let capacity = try #require(released.charterCapacity)
    var commander = try f.f.f.work.f.commander()
    while commander.flightSimulation.visit < consent.dock.actor.visit {
      commander.flightSimulation.enter(
        NativeInductionCapacityOperator.clinic.station, arriving: true)
    }
    commander.flightSimulation.physicalTime = 1_000_200
    commander.scriptState.flightSeconds = 900_200
    commander.scriptState.nextEvent = 140
    commander.nativeStations?.mainStations += [f.f.choice.dock.station, consent.dock.station]
    commander.nativeStations?.nextMainDockSequence = 105
    var mission = try #require(commander.scriptState.instances[f.f.choice.parent])
    mission.savedWayfarerInduction = released
    mission.acknowledge(140)
    #expect(
      NativeInductionCharterConsentSave.signaturesValid(
        [consent], mission: mission, commander: commander))
    #expect(
      NativeInductionCapacitySave.claimsValid(capacity, mission: mission, commander: commander))
    mission.acknowledgedThrough = 139
    #expect(
      !NativeInductionCapacitySave.claimsValid(capacity, mission: mission, commander: commander))
    mission.acknowledge(140)
    commander.scriptState.flightSeconds = 900_140
    #expect(
      !NativeInductionCapacitySave.claimsValid(capacity, mission: mission, commander: commander))
    commander.scriptState.flightSeconds = 900_200
    let unit = try #require(f.f.initial.units.first { $0.operatorID == .clinic && !$0.protected })
    let model = try f.f.initial.releasing(f.f.release(f.f.initial, unit: unit))
    #expect(!NativeInductionCapacitySave.claimsValid(model, mission: mission, commander: commander))
  }

  @Test func protectedBoardShowsDistinctExactUnitKeysAndReadOnlyReviewsCannotReleaseOrCreateStock()
    throws
  {
    let f = try InductionConsentFixture()
    let signed = try f.initial.recordingCharterConsent(f.signature(.clinic))
    var game = Game()
    game.commander = try f.f.f.work.f.commander()
    game.commander.system = 185
    game.screen = .contracts
    game.docked = true
    game.scriptPacks = [
      try ScriptPackLibrary.read(ScriptPackLibrary.bundledWayfarerInductionDirectory)
    ]
    game.commander.scriptState.instances[f.f.choice.parent]?.savedWayfarerInduction = signed
    let rows = game.inductionCharterOperatorRows
    #expect(rows.count == 5 && rows[0].wayfarerInduction == .clinicConsent)
    #expect(Set(rows.map(\.key)).count == 5)
    #expect(
      rows.dropFirst().allSatisfy {
        $0.wayfarerInduction == .releaseClinicCapacity && $0.inductionCapacityUnit != nil
      })
    let before = game.commander
    game.contractBoard.rows = rows
    for index in 1..<rows.count {
      game.contractBoard.selection = index
      let quote = game.wayfarerInductionReview(.releaseClinicCapacity)
      game.contractBoard.wayfarerInductionQuote = quote
      #expect(
        quote.capacityUnit == rows[index].inductionCapacityUnit && quote.capacityRevision == 0)
      #expect(!quote.allowed)
      #expect(
        game.wayfarerInductionDetail().contains {
          $0.contains(rows[index].inductionCapacityUnit!.uuidString)
        })
      #expect(PlayerHelp.pages(for: game).first?.title == "ORIGINAL OWNER CHARTER")
      #expect(throws: (any Error).self) { try game.confirmWayfarerInduction(quote) }
    }
    #expect(game.commander == before && signed.charterCapacity?.events.isEmpty == true)
  }

  @Test func closedConsentSchemaRejectsEarlierEmbeddedAndUnknownSignatureOrUnsignedReleaseClaims()
    throws
  {
    let f = try InductionConsentFixture()
    let consent = try f.signature(.clinic)
    let signed = try f.initial.recordingCharterConsent(consent)
    let released = try signed.releasingCharterUnit(f.release(consent))
    var leaf = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(released)) as? [String: Any])
    func data() throws -> Data {
      try JSONSerialization.data(withJSONObject: [
        "instances": [
          f.f.choice.parent.uuidString: [
            "definition": NativeWayfarerInduction.stateID, "digest": NativeWayfarerInduction.digest,
            "savedWayfarerInduction": leaf,
          ]
        ]
      ])
    }
    for schema in [107, 108] {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(data(), part: .missions, schema: schema)
    }
    for schema in [101, 102, 103, 104, 105, 106] {
      #expect(throws: (any Error).self) {
        try ScriptSaveJSONPreflight.validateRepairLoopFields(
          data(), part: .missions, schema: schema)
      }
    }
    let embedded = try JSONSerialization.data(withJSONObject: [
      "savedScriptState": try JSONSerialization.jsonObject(with: data())
    ])
    #expect(throws: (any Error).self) {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(embedded, part: .commander, schema: 107)
    }
    var signatures = try #require(leaf["charterSignatures"] as? [[String: Any]])
    signatures[0]["allOwnersSigned"] = true
    leaf["charterSignatures"] = signatures
    #expect(throws: (any Error).self) {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(data(), part: .missions, schema: 107)
    }
    #expect(NativeInductionArkSave.isAlien(106) && NativeInductionArkSave.isAlien(108))
  }
}

extension InductionConsentFixture {
  fileprivate var choiceOwner: UUID { f.choice.owner }
}
