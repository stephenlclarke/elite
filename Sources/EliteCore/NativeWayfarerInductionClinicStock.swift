import Foundation

struct NativeInductionClinicStockMutation: Codable, Sendable, Equatable {
  enum Kind: String, Codable, Sendable {
    case reserved, cancelled, failedBeforePickup, received, returnedToOwner, spoiled, carrierLost
  }
  let kind: Kind
  let operation: UUID
  let instance: UUID
  let unit: UUID
  let window: UUID
  let revision: UInt64
  let sequence: UInt64
  let physicalTime: Double
  let flightSeconds: Double
}

extension NativeInductionClinicSource {
  func projectedUnits() throws -> [WayfarerColdChainStockUnit] {
    let history = self.history ?? []
    guard history.count <= 512, self.history == nil || !history.isEmpty,
      Set(history.map(\.operation)).count == history.count
    else { throw SaveError.invalidCommander }
    var result = (0..<issue.profile.stockUnits).map {
      WayfarerColdChainStockUnit(
        id: WayfarerColdChainStockSource.unitIdentity(source: identity, index: $0))
    }
    var instances: Set<UUID> = []
    var sequence = issue.sequence
    var time = issue.physicalTime
    var clock = issue.flightSeconds
    for (index, event) in history.enumerated() {
      guard event.revision == UInt64(index), event.sequence > sequence,
        event.sequence < UInt64(Int64.max),
        event.physicalTime.isFinite, (time...1e12).contains(event.physicalTime),
        event.flightSeconds.isFinite, (clock...1e12).contains(event.flightSeconds),
        let slot = result.firstIndex(where: { $0.id == event.unit })
      else { throw SaveError.invalidCommander }
      switch event.kind {
      case .reserved:
        guard result[slot].status == .available, result[slot].instance == nil,
          event.instance
            == NativeInductionClinicBooking.instance(
              source: identity, unit: event.unit, revision: event.revision),
          instances.insert(event.instance).inserted
        else { throw SaveError.invalidCommander }
        result[slot].status = .held
        result[slot].instance = event.instance
      case .received, .returnedToOwner, .spoiled, .carrierLost:
        guard result[slot].status == .held, result[slot].instance == event.instance else {
          throw SaveError.invalidCommander
        }
        result[slot].status =
          [.received, .returnedToOwner].contains(event.kind) ? .received : .failed
      case .cancelled, .failedBeforePickup:
        guard result[slot].status == .held, result[slot].instance == event.instance else {
          throw SaveError.invalidCommander
        }
        result[slot].status = event.kind == .cancelled ? .available : .failed
        if event.kind == .cancelled { result[slot].instance = nil }
      }
      sequence = event.sequence
      time = event.physicalTime
      clock = event.flightSeconds
    }
    return result
  }
  func snapshot(at revision: UInt64) throws -> Self {
    guard revision <= self.revision else { throw SaveError.invalidCommander }
    var next = self
    next.history = revision == 0 ? nil : Array((history ?? []).prefix(Int(revision)))
    next.units = try next.projectedUnits()
    return next
  }
  func applying(_ event: NativeInductionClinicStockMutation) throws -> Self {
    guard revision < 512, event.revision == revision else { throw SaveError.invalidCommander }
    var next = self
    next.history = (history ?? []) + [event]
    next.units = try next.projectedUnits()
    return next
  }
  func ownsWindowEvent(_ event: NativeInductionCapacityEvent) -> Bool {
    switch event {
    case .released: return false
    case .reserved(let reservation):
      return reservation.owner == issue.operatorOwner && reservation.epoch == issue.epoch
        && reservation.policy == issue.policy
        && (history ?? []).contains {
          $0.kind == .reserved && $0.window == reservation.operation
            && $0.instance == reservation.consignment
        }
    case .returned(let receipt):
      guard receipt.owner == issue.operatorOwner,
        let closing = (history ?? []).first(where: {
          $0.kind != .reserved && $0.window == receipt.operation
        })
      else { return false }
      guard receipt.reason == (closing.kind == .received ? .completed : .cancelled) else {
        return false
      }
      return (history ?? []).contains {
        $0.kind == .reserved && $0.instance == closing.instance && $0.unit == closing.unit
          && $0.window == receipt.reservation
      }
    }
  }
  func windowEventClock(_ event: NativeInductionCapacityEvent) -> (UInt64, Double, Double)? {
    let operation: UUID
    switch event {
    case .released(let value): return (value.sequence, value.physicalTime, value.flightSeconds)
    case .reserved(let value): operation = value.operation
    case .returned(let value): operation = value.operation
    }
    guard let event = (history ?? []).first(where: { $0.window == operation }) else { return nil }
    return (event.sequence, event.physicalTime, event.flightSeconds)
  }
}

extension NativeWayfarerInductionState {
  func updatingClinic(_ source: NativeInductionClinicSource, capacity: NativeInductionCapacityState)
    throws -> Self
  {
    guard valid, let previous = charterClinicSource,
      previous.identity == source.identity, previous.issue == source.issue,
      source.revision == previous.revision + 1,
      capacity.allocation == charterCapacity?.allocation,
      capacity.revision == (charterCapacity?.revision ?? UInt64.max) + 1
    else { throw SaveError.invalidCommander }
    let next = Self(
      permission: permission, crate: crate, loss: loss, reception: reception,
      cassette: cassette, cassetteLoss: cassetteLoss, cassetteService: cassetteService,
      seedKey: seedKey, seedKeyLoss: seedKeyLoss, ark: ark, seedReception: seedReception,
      crewLog: crewLog, crewLogLoss: crewLogLoss, crewLogHullCustody: crewLogHullCustody,
      rescueReception: rescueReception, utilityReception: utilityReception,
      charterChoice: charterChoice, charterCapacity: capacity,
      charterSignatures: charterSignatures, charterClinicSource: source,
      charterWorkshopSource: charterWorkshopSource, charterSeedSource: charterSeedSource)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }
}
