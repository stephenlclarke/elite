import Foundation

struct NativeInductionCapacityReservation: Codable, Sendable, Equatable {
  let operation: UUID
  let allocation: UUID
  let epoch: UUID
  let policy: NativeInductionCharterPolicy
  let revision: UInt64
  let unit: UUID
  let owner: UUID
  let consignment: UUID
  let before: String
}

struct NativeInductionCapacityReturn: Codable, Sendable, Equatable {
  enum Reason: String, Codable, Sendable { case completed, cancelled }
  let operation: UUID
  let allocation: UUID
  let revision: UInt64
  let reservation: UUID
  let unit: UUID
  let owner: UUID
  let reason: Reason
  let before: String
}

struct NativeInductionCapacityRelease: Codable, Sendable, Equatable {
  let operation: UUID
  let allocation: UUID
  let epoch: UUID
  let policy: NativeInductionCharterPolicy
  let revision: UInt64
  let unit: UUID
  let owner: UUID
  let operatorID: NativeInductionCapacityOperator
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let flightSeconds: Double
  let sequence: UInt64
  let before: String

  static func identity(
    allocation: UUID, unit: UUID, owner: UUID,
    revision: UInt64, before: String, dock: NativeMainStationDockReceipt,
    carrier: UUID, fit: UInt64, time: Double, flightSeconds: Double, sequence: UInt64
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-charter-exact-owner-release-v1:\(allocation):\(unit):\(owner):\(revision):\(before):\(try NativeFlightReception.hash(dock)):\(carrier):\(fit):\(time.bitPattern):\(flightSeconds.bitPattern):\(sequence)"
    )
  }
}

enum NativeInductionCapacityEvent: Codable, Sendable, Equatable {
  case released(NativeInductionCapacityRelease)
  case reserved(NativeInductionCapacityReservation)
  case returned(NativeInductionCapacityReturn)
  var operation: UUID {
    switch self {
    case .released(let value): value.operation
    case .reserved(let value): value.operation
    case .returned(let value): value.operation
    }
  }
}

struct NativeInductionCapacitySlot: Sendable {
  let unit: NativeInductionCapacityUnit
  var release: UUID?
  var reservation: NativeInductionCapacityReservation?
}

/// Campaign-local finite ledger. Live signature/booking callers must separately supply actual authority.
struct NativeInductionCapacityState: Codable, Sendable, Equatable {
  static let maximumEvents = 512
  let allocation: NativeInductionCapacityAllocation
  var events: [NativeInductionCapacityEvent] = []
  var revision: UInt64 { UInt64(events.count) }
  var units: [NativeInductionCapacityUnit] {
    NativeInductionCapacityUnit.original(epoch: allocation.epoch)
  }
  var fingerprint: String { get throws { try NativeFlightReception.hash(self) } }

  func valid(choice: NativeInductionCharterChoice) -> Bool {
    allocation.valid(choice: choice) && (try? projection()) != nil
  }
  func eligible(_ slot: NativeInductionCapacitySlot) -> Bool {
    !slot.unit.protected && slot.reservation == nil
      && (allocation.policy == .pooledWindows || slot.release != nil)
  }
  func projection() throws -> [NativeInductionCapacitySlot] {
    guard events.count <= Self.maximumEvents, Set(events.map(\.operation)).count == events.count
    else {
      throw SaveError.invalidCommander
    }
    var prefix = Self(allocation: allocation)
    var slots = units.map { NativeInductionCapacitySlot(unit: $0) }
    var used: Set<UUID> = []
    for event in events {
      try prefix.apply(event, slots: &slots, used: &used)
      prefix.events.append(event)
    }
    return slots
  }
  func reserving(_ quote: NativeInductionCapacityReservation) throws -> Self {
    try appending(.reserved(quote))
  }
  func returning(_ receipt: NativeInductionCapacityReturn) throws -> Self {
    try appending(.returned(receipt))
  }
  func releasing(_ receipt: NativeInductionCapacityRelease) throws -> Self {
    try appending(.released(receipt))
  }
  private func appending(_ event: NativeInductionCapacityEvent) throws -> Self {
    guard events.count < Self.maximumEvents else { throw SaveError.invalidCommander }
    var next = self
    next.events.append(event)
    _ = try next.projection()
    return next
  }

  func quote(consignment: UUID, unit identity: UUID? = nil) throws
    -> NativeInductionCapacityReservation
  {
    let slots = try projection()
    guard
      !events.contains(where: {
        if case .reserved(let previous) = $0 { return previous.consignment == consignment }
        return false
      }),
      let slot = slots.first(where: {
        (identity == nil || $0.unit.identity == identity) && eligible($0)
      })
    else { throw SaveError.invalidCommander }
    let before = try fingerprint
    let operation = Self.reservationIdentity(
      allocation: allocation.operation, revision: revision,
      unit: slot.unit.identity, owner: slot.unit.owner, consignment: consignment, before: before)
    return .init(
      operation: operation, allocation: allocation.operation, epoch: allocation.epoch,
      policy: allocation.policy, revision: revision, unit: slot.unit.identity,
      owner: slot.unit.owner, consignment: consignment, before: before)
  }
  static func reservationIdentity(
    allocation: UUID, revision: UInt64, unit: UUID,
    owner: UUID, consignment: UUID, before: String
  ) -> UUID {
    ScriptIdentity.uuid(
      "induction-charter-reservation-v1:\(allocation):\(revision):\(unit):\(owner):\(consignment):\(before)"
    )
  }
  func returnQuote(reservation: UUID, reason: NativeInductionCapacityReturn.Reason) throws
    -> NativeInductionCapacityReturn
  {
    guard let slot = try projection().first(where: { $0.reservation?.operation == reservation })
    else {
      throw SaveError.invalidCommander
    }
    let before = try fingerprint
    let operation = Self.returnIdentity(
      allocation: allocation.operation, revision: revision,
      reservation: reservation, unit: slot.unit.identity, owner: slot.unit.owner, reason: reason,
      before: before)
    return .init(
      operation: operation, allocation: allocation.operation, revision: revision,
      reservation: reservation, unit: slot.unit.identity, owner: slot.unit.owner, reason: reason,
      before: before)
  }
  static func returnIdentity(
    allocation: UUID, revision: UInt64, reservation: UUID,
    unit: UUID, owner: UUID, reason: NativeInductionCapacityReturn.Reason, before: String
  ) -> UUID {
    ScriptIdentity.uuid(
      "induction-charter-reservation-return-v1:\(allocation):\(revision):\(reservation):\(unit):\(owner):\(reason.rawValue):\(before)"
    )
  }

  private func apply(
    _ event: NativeInductionCapacityEvent, slots: inout [NativeInductionCapacitySlot],
    used: inout Set<UUID>
  ) throws {
    let before = try fingerprint
    switch event {
    case .reserved(let quote):
      guard quote.allocation == allocation.operation, quote.epoch == allocation.epoch,
        quote.policy == allocation.policy, quote.revision == revision, quote.before == before,
        let index = slots.firstIndex(where: { $0.unit.identity == quote.unit }),
        eligible(slots[index]),
        quote.owner == slots[index].unit.owner, !used.contains(quote.consignment),
        quote.operation
          == Self.reservationIdentity(
            allocation: allocation.operation, revision: revision,
            unit: quote.unit, owner: quote.owner, consignment: quote.consignment, before: before)
      else { throw SaveError.invalidCommander }
      slots[index].reservation = quote
      used.insert(quote.consignment)
    case .returned(let receipt):
      guard receipt.allocation == allocation.operation, receipt.revision == revision,
        receipt.before == before,
        let index = slots.firstIndex(where: { $0.unit.identity == receipt.unit }),
        receipt.owner == slots[index].unit.owner,
        slots[index].reservation?.operation == receipt.reservation,
        receipt.operation
          == Self.returnIdentity(
            allocation: allocation.operation, revision: revision,
            reservation: receipt.reservation, unit: receipt.unit, owner: receipt.owner,
            reason: receipt.reason, before: before)
      else { throw SaveError.invalidCommander }
      slots[index].reservation = nil
      slots[index].release = nil
    case .released(let receipt):
      let previous = events.compactMap { event -> NativeInductionCapacityRelease? in
        if case .released(let value) = event { return value }
        return nil
      }.last
      guard allocation.policy == .protectedReservations,
        receipt.allocation == allocation.operation, receipt.epoch == allocation.epoch,
        receipt.policy == allocation.policy, receipt.revision == revision, receipt.before == before,
        let index = slots.firstIndex(where: { $0.unit.identity == receipt.unit }),
        !slots[index].unit.protected, slots[index].reservation == nil, slots[index].release == nil,
        receipt.owner == slots[index].unit.owner,
        receipt.operatorID == slots[index].unit.operatorID,
        receipt.dock.valid, receipt.dock.commanderOwner == allocation.commanderOwner,
        receipt.dock.station.world == allocation.commanderOwner,
        receipt.dock.station.system == receipt.operatorID.station,
        receipt.dock.sequence > allocation.dock.sequence,
        receipt.dock.actor.visit > allocation.dock.actor.visit,
        receipt.dock.calendarSeconds >= allocation.dock.calendarSeconds,
        receipt.inventoryRevision < UInt64(Int64.max), receipt.physicalTime.isFinite,
        (allocation.physicalTime...1e12).contains(receipt.physicalTime),
        receipt.flightSeconds.isFinite,
        (allocation.flightSeconds...1e12).contains(receipt.flightSeconds),
        receipt.sequence > (previous?.sequence ?? allocation.sequence),
        receipt.sequence < UInt64(Int64.max),
        receipt.physicalTime >= (previous?.physicalTime ?? allocation.physicalTime),
        receipt.flightSeconds >= (previous?.flightSeconds ?? allocation.flightSeconds),
        receipt.dock.sequence >= (previous?.dock.sequence ?? allocation.dock.sequence),
        receipt.operation
          == (try? NativeInductionCapacityRelease.identity(
            allocation: allocation.operation,
            unit: receipt.unit, owner: receipt.owner, revision: revision, before: before,
            dock: receipt.dock,
            carrier: receipt.carrier, fit: receipt.inventoryRevision, time: receipt.physicalTime,
            flightSeconds: receipt.flightSeconds, sequence: receipt.sequence))
      else { throw SaveError.invalidCommander }
      slots[index].release = receipt.operation
    }
  }
}
