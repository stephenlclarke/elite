import Foundation
import Testing

@testable import EliteCore

/// Finite ledger and source-policy fixtures; policy bookings/releases do not claim native authority.
final class InductionCapacityFixture {
  let f: InductionCharterFixture
  let choice: NativeInductionCharterChoice
  let chosen: NativeWayfarerInductionState
  let initial: NativeInductionCapacityState
  init(_ policy: NativeInductionCharterPolicy = .pooledWindows) throws {
    f = try .init()
    choice = try f.choice(policy)
    chosen = try f.parent.choosingCharter(choice)
    let source = try NativeInductionCapacityAllocation(
      choice: choice, dock: choice.dock,
      carrier: choice.carrier, revision: choice.inventoryRevision, time: choice.physicalTime,
      flightSeconds: choice.flightSeconds, sequence: choice.sequence)
    initial = .init(allocation: source)
  }
  func release(
    _ state: NativeInductionCapacityState, unit: NativeInductionCapacityUnit,
    owner: UUID? = nil, station: SystemIdentity? = nil
  ) throws -> NativeInductionCapacityRelease {
    let owner = owner ?? unit.owner
    let location = station ?? unit.operatorID.station
    let dock = NativeWayfarerInductionUnitTests().dock(
      owner: choice.owner, system: location.system,
      visit: choice.dock.actor.visit + 1, sequence: 104)
    let before = try state.fingerprint
    let sequence = 126 + state.revision
    let operation = try NativeInductionCapacityRelease.identity(
      allocation: state.allocation.operation,
      unit: unit.identity, owner: owner, revision: state.revision, before: before, dock: dock,
      carrier: choice.carrier, fit: 1, time: 1_000_130, flightSeconds: 900_130, sequence: sequence)
    return .init(
      operation: operation, allocation: state.allocation.operation, epoch: choice.terms.epoch,
      policy: choice.policy, revision: state.revision, unit: unit.identity, owner: owner,
      operatorID: unit.operatorID, dock: dock, carrier: choice.carrier, inventoryRevision: 1,
      physicalTime: 1_000_130, flightSeconds: 900_130, sequence: sequence, before: before)
  }
}

struct NativeWayfarerInductionCapacityUnitTests {
  @Test func originalCapacityHasEighteenDistinctOwnerEpochUnitsAndSixProtectedWithoutChangingStage()
    throws
  {
    for policy in NativeInductionCharterPolicy.allCases {
      let f = try InductionCapacityFixture(policy)
      #expect(f.initial.valid(choice: f.choice))
      let units = f.initial.units
      #expect(units.count == 18 && Set(units.map(\.identity)).count == 18)
      #expect(Set(units.map(\.owner)).count == 3 && units.filter(\.protected).count == 6)
      for operatorID in NativeInductionCapacityOperator.allCases {
        #expect(units.filter { $0.operatorID == operatorID }.count == 6)
        #expect(units.filter { $0.operatorID == operatorID && $0.protected }.count == 2)
      }
      let next = try f.chosen.allocatingCharterCapacity(f.initial)
      #expect(next.milestones == f.chosen.milestones && next.milestones.max() == 10)
      #expect(next.payloads == f.chosen.payloads && next.charterChoice == f.choice)
      #expect(throws: (any Error).self) { try next.allocatingCharterCapacity(f.initial) }
      let restored = try JSONDecoder().decode(
        NativeWayfarerInductionState.self,
        from: JSONEncoder().encode(next))
      #expect(restored == next && restored.charterCapacity?.units == units)
    }
  }

  @Test func pooledBookingsExhaustOnlyTwelveFreeSurplusUnitsAndNeverBorrowProtectedMinimum() throws
  {
    let f = try InductionCapacityFixture()
    var ledger = f.initial
    let protected = try #require(ledger.units.first { $0.protected })
    let before = ledger
    #expect(throws: (any Error).self) {
      try ledger.quote(consignment: UUID(), unit: protected.identity)
    }
    #expect(ledger == before)
    for _ in 0..<12 {
      let quote = try ledger.quote(consignment: UUID())
      ledger = try ledger.reserving(quote)
    }
    #expect(try ledger.projection().filter { ledger.eligible($0) }.isEmpty)
    #expect(try ledger.projection().filter { $0.reservation != nil }.count == 12)
    #expect(
      try ledger.projection().filter { $0.unit.protected && $0.reservation == nil }.count == 6)
    #expect(throws: (any Error).self) { try ledger.quote(consignment: UUID()) }
    let decoded = try JSONDecoder().decode(
      NativeInductionCapacityState.self, from: JSONEncoder().encode(ledger))
    #expect(decoded == ledger && decoded.units == f.initial.units)
    #expect(throws: (any Error).self) { try decoded.quote(consignment: UUID()) }
  }

  @Test func protectedCapacityNeedsExactOwnerReleaseAtItsOwnStationAndCannotDoubleRelease() throws {
    let f = try InductionCapacityFixture(.protectedReservations)
    let unit = try #require(f.initial.units.first { !$0.protected })
    #expect(throws: (any Error).self) { try f.initial.quote(consignment: UUID()) }
    let foreignOwner = try f.release(f.initial, unit: unit, owner: UUID())
    #expect(throws: (any Error).self) { try f.initial.releasing(foreignOwner) }
    let wrongStation = try f.release(f.initial, unit: unit, station: NativeWayfarerInduction.source)
    #expect(throws: (any Error).self) { try f.initial.releasing(wrongStation) }
    let protected = try #require(f.initial.units.first { $0.protected })
    let minimumRelease = try f.release(f.initial, unit: protected)
    #expect(throws: (any Error).self) { try f.initial.releasing(minimumRelease) }
    let release = try f.release(f.initial, unit: unit)
    let released = try f.initial.releasing(release)
    #expect(
      try released.projection().filter { released.eligible($0) }.map(\.unit.identity) == [
        unit.identity
      ])
    let duplicate = try f.release(released, unit: unit)
    #expect(throws: (any Error).self) { try released.releasing(duplicate) }
    #expect(f.initial.events.isEmpty && f.initial.revision == 0)
    #expect(NativeInductionCapacityOperator.clinic.station.system == 185)
    #expect(NativeInductionCapacityOperator.workshop.station.system == 0)
    #expect(NativeInductionCapacityOperator.seed.station.system == 162)
  }

  @Test
  func completionOrCancellationReturnsSameUnitToOriginalOwnerAndPolicyWithoutReusingConsignment()
    throws
  {
    for policy in NativeInductionCharterPolicy.allCases {
      for reason in [NativeInductionCapacityReturn.Reason.completed, .cancelled] {
        let f = try InductionCapacityFixture(policy)
        let unit = try #require(f.initial.units.first { !$0.protected })
        var ledger = f.initial
        if policy == .protectedReservations {
          ledger = try ledger.releasing(f.release(ledger, unit: unit))
        }
        let quote = try ledger.quote(consignment: UUID(), unit: unit.identity)
        let booked = try ledger.reserving(quote)
        #expect(throws: (any Error).self) { try booked.reserving(quote) }
        let returned = try booked.returning(
          booked.returnQuote(reservation: quote.operation, reason: reason))
        let slots = try returned.projection()
        let slot = try #require(slots.first { $0.unit.identity == unit.identity })
        #expect(slot.unit.owner == unit.owner && slot.reservation == nil && slot.release == nil)
        #expect(returned.allocation == f.initial.allocation && returned.units == f.initial.units)
        #expect(throws: (any Error).self) { try returned.quote(consignment: quote.consignment) }
        #expect(throws: (any Error).self) {
          try returned.returnQuote(reservation: quote.operation, reason: reason)
        }
        if policy == .protectedReservations {
          #expect(throws: (any Error).self) {
            try returned.quote(consignment: UUID(), unit: unit.identity)
          }
        } else {
          let next = try returned.quote(consignment: UUID(), unit: unit.identity)
          #expect(next.unit == quote.unit && next.owner == quote.owner)
        }
      }
    }
  }

  @Test func staleForeignQuotesAndReorderedOrDuplicatePolicyEventsCannotConsumeCapacity() throws {
    let f = try InductionCapacityFixture()
    let first = try f.initial.quote(consignment: UUID())
    let stale = try f.initial.quote(consignment: UUID())
    let booked = try f.initial.reserving(first)
    #expect(throws: (any Error).self) { try booked.reserving(stale) }
    let foreign = try InductionCapacityFixture()
    let quote = try foreign.initial.quote(consignment: UUID())
    #expect(throws: (any Error).self) { try f.initial.reserving(quote) }
    var duplicate = booked
    duplicate.events.append(.reserved(first))
    #expect(!duplicate.valid(choice: f.choice))
    var cap = f.initial
    cap.events = Array(
      repeating: .reserved(first), count: NativeInductionCapacityState.maximumEvents + 1)
    #expect(!cap.valid(choice: f.choice))
    #expect(f.initial.events.isEmpty && booked.revision == 1)
  }

  @Test
  func nativeSourceClaimsNeedActualOwningAcknowledgedAllocationAndCannotSavePolicyOnlyBookings()
    throws
  {
    let f = try InductionCapacityFixture()
    var commander = try f.f.work.f.commander()
    while commander.flightSimulation.visit < f.choice.dock.actor.visit {
      commander.flightSimulation.enter(NativeWayfarerInduction.source, arriving: true)
    }
    commander.flightSimulation.physicalTime = 1_000_140
    commander.scriptState.flightSeconds = 900_140
    commander.scriptState.nextEvent = 125
    commander.nativeStations?.mainStations.append(f.choice.dock.station)
    commander.nativeStations?.nextMainDockSequence = 104
    var parent = try #require(commander.scriptState.instances[f.choice.parent])
    parent.acknowledge(125)
    #expect(
      NativeInductionCapacitySave.claimsValid(f.initial, mission: parent, commander: commander))
    parent.acknowledgedThrough = 124
    #expect(
      !NativeInductionCapacitySave.claimsValid(f.initial, mission: parent, commander: commander))
    parent.acknowledge(125)
    let booked = try f.initial.reserving(f.initial.quote(consignment: UUID()))
    #expect(!NativeInductionCapacitySave.claimsValid(booked, mission: parent, commander: commander))
    #expect(f.chosen.charterCapacity == nil)
    #expect(throws: (any Error).self) { try f.f.parent.allocatingCharterCapacity(f.initial) }
  }

  @Test
  func closedCapacitySchemaKeepsEarlierChoicesAndRejectsEarlyEmbeddedUnknownAndRefilledClaims()
    throws
  {
    let f = try InductionCapacityFixture()
    let allocated = try f.chosen.allocatingCharterCapacity(f.initial)
    var leaf = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(allocated)) as? [String: Any])
    func data() throws -> Data {
      try JSONSerialization.data(withJSONObject: [
        "instances": [
          f.choice.parent.uuidString: [
            "definition": NativeWayfarerInduction.stateID, "digest": NativeWayfarerInduction.digest,
            "savedWayfarerInduction": leaf,
          ]
        ]
      ])
    }
    for schema in [105, 106] {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(data(), part: .missions, schema: schema)
    }
    for schema in [99, 100, 101, 102, 103, 104] {
      #expect(throws: (any Error).self) {
        try ScriptSaveJSONPreflight.validateRepairLoopFields(
          data(), part: .missions, schema: schema)
      }
    }
    let embedded = try JSONSerialization.data(withJSONObject: [
      "savedScriptState": try JSONSerialization.jsonObject(with: data())
    ])
    #expect(throws: (any Error).self) {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(embedded, part: .commander, schema: 105)
    }
    var raw = try #require(leaf["charterCapacity"] as? [String: Any])
    raw["refilled"] = true
    leaf["charterCapacity"] = raw
    #expect(throws: (any Error).self) {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(data(), part: .missions, schema: 105)
    }
    #expect(NativeInductionArkSave.isAlien(104) && NativeInductionArkSave.isAlien(106))
  }
}
