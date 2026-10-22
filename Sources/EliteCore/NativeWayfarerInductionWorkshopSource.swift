import Foundation

struct NativeInductionWorkshopIssue: Codable, Sendable, Equatable {
  let operation: UUID
  let sequence: UInt64
  let parent: UUID
  let commanderOwner: UUID
  let operatorOwner: UUID
  let epoch: UUID
  let policy: NativeInductionCharterPolicy
  let consent: UUID
  let allocation: UUID
  let capacityRevision: UInt64
  let capacityFingerprint: String
  let familyDigest: String
  let profile: NativeInductionWorkshopProfile
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let flightSeconds: Double
  static func identity(
    consent: UUID, allocation: UUID, revision: UInt64, fingerprint: String,
    dock: NativeMainStationDockReceipt, carrier: UUID, fit: UInt64, time: Double,
    flightSeconds: Double, sequence: UInt64
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-original-workshop-issue-v1:\(consent):\(allocation):\(revision):\(fingerprint):\(NativeInductionWorkshopPack.digest):\(try NativeFlightReception.hash(dock)):\(carrier):\(fit):\(time.bitPattern):\(flightSeconds.bitPattern):\(sequence)"
    )
  }
  func valid(parent: NativeWayfarerInductionState) -> Bool {
    guard let choice = parent.charterChoice, let capacity = parent.charterCapacity,
      let signature = parent.charterSignatures?.first(where: { $0.operatorID == .workshop }),
      self.parent == choice.parent, commanderOwner == choice.owner,
      operatorOwner == NativeInductionCapacityOperator.workshop.owner(epoch: choice.terms.epoch),
      epoch == choice.terms.epoch, policy == choice.policy, consent == signature.operation,
      allocation == capacity.allocation.operation, capacityRevision >= signature.capacityRevision,
      let before = try? capacity.snapshot(at: capacityRevision),
      capacityFingerprint == (try? before.fingerprint),
      before.events.allSatisfy({ event in
        guard let clock = parent.charterCapacityEventClock(event) else { return false }
        return clock.0 < sequence && clock.1 <= physicalTime && clock.2 <= flightSeconds
      }),
      familyDigest == NativeInductionWorkshopPack.digest, profile.valid,
      sequence > signature.sequence, sequence < UInt64(Int64.max),
      dock.valid, dock.commanderOwner == commanderOwner,
      dock.station == signature.dock.station, profile.source.matches(dock.station),
      dock.sequence >= signature.dock.sequence, dock.actor.visit >= signature.dock.actor.visit,
      dock.calendarSeconds >= signature.dock.calendarSeconds,
      inventoryRevision < UInt64(Int64.max), physicalTime.isFinite,
      (signature.physicalTime...1e12).contains(physicalTime), flightSeconds.isFinite,
      (signature.flightSeconds...1e12).contains(flightSeconds)
    else { return false }
    return operation
      == (try? Self.identity(
        consent: consent, allocation: allocation,
        revision: capacityRevision, fingerprint: capacityFingerprint, dock: dock, carrier: carrier,
        fit: inventoryRevision, time: physicalTime, flightSeconds: flightSeconds, sequence: sequence
      ))
  }
}

struct NativeInductionWorkshopDelegation: Codable, Sendable, Equatable {
  let operation: UUID
  let issue: UUID
  let source: UUID
  let epoch: UUID
  let operatorOwner: UUID
  let auditor: NativeMainStationIdentity
  let units: [UUID]
  let scope: String
  static let readOnlyScope = "original-available-workshop-unit-quote-capacity-refusal-only"
  static func identity(issue: UUID, source: UUID, units: [UUID], auditor: NativeMainStationIdentity)
    throws -> UUID
  {
    ScriptIdentity.uuid(
      "induction-workshop-avenor-read-only-delegation-v1:\(issue):\(source):\(try NativeFlightReception.hash(units)):\(try NativeFlightReception.hash(auditor)):\(readOnlyScope)"
    )
  }
}

struct NativeInductionWorkshopUnit: Codable, Sendable, Equatable {
  let id: UUID
  let serial: UUID
  var status: WayfarerRepairLoopUnitStatus = .available
  var instance: UUID?
  var returnedCondition: NativeRepairLoopCondition?
  var originalCondition: NativeRepairLoopCondition { .failed(sourceUnit: id) }
}

struct NativeInductionWorkshopStockMutation: Codable, Sendable, Equatable {
  enum Kind: String, Codable, Sendable {
    case reserved, cancelledBeforePickup, returned, cancelledHeld, lost, sourceLost
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
  let condition: NativeRepairLoopCondition?
}

struct NativeInductionWorkshopSource: Codable, Sendable, Equatable {
  let identity: UUID
  let issue: NativeInductionWorkshopIssue
  let delegation: NativeInductionWorkshopDelegation
  var units: [NativeInductionWorkshopUnit]
  var history: [NativeInductionWorkshopStockMutation]?
  var revision: UInt64 { UInt64(history?.count ?? 0) }
  static func identity(parent: UUID, epoch: UUID, owner: UUID) -> UUID {
    ScriptIdentity.uuid("induction-original-workshop-batch-v1:\(parent):\(epoch):\(owner)")
  }
  static func originals(source: UUID) -> [NativeInductionWorkshopUnit] {
    (0..<6).map { index in
      let unit = WayfarerRepairLoopStockSource.unitIdentity(source: source, index: index)
      return .init(
        id: unit,
        serial: ScriptIdentity.uuid("induction-original-workshop-serial-v1:\(source):\(unit)"))
    }
  }
  init(issue: NativeInductionWorkshopIssue, parent: NativeWayfarerInductionState) throws {
    guard issue.valid(parent: parent), let choice = parent.charterChoice else {
      throw SaveError.invalidCommander
    }
    identity = Self.identity(parent: issue.parent, epoch: issue.epoch, owner: issue.operatorOwner)
    self.issue = issue
    units = Self.originals(source: identity)
    delegation = .init(
      operation: try NativeInductionWorkshopDelegation.identity(
        issue: issue.operation,
        source: identity, units: units.map(\.id), auditor: choice.dock.station),
      issue: issue.operation, source: identity, epoch: issue.epoch,
      operatorOwner: issue.operatorOwner,
      auditor: choice.dock.station, units: units.map(\.id),
      scope: NativeInductionWorkshopDelegation.readOnlyScope)
    guard valid(parent: parent) else { throw SaveError.invalidCommander }
  }
  func valid(parent: NativeWayfarerInductionState) -> Bool {
    guard issue.valid(parent: parent), let choice = parent.charterChoice,
      identity
        == Self.identity(parent: issue.parent, epoch: issue.epoch, owner: issue.operatorOwner),
      units == (try? projectedUnits()), delegation.issue == issue.operation,
      delegation.source == identity, delegation.epoch == issue.epoch,
      delegation.operatorOwner == issue.operatorOwner, delegation.auditor == choice.dock.station,
      delegation.units == units.map(\.id),
      delegation.scope == NativeInductionWorkshopDelegation.readOnlyScope
    else { return false }
    return delegation.operation
      == (try? NativeInductionWorkshopDelegation.identity(
        issue: issue.operation,
        source: identity, units: units.map(\.id), auditor: delegation.auditor))
  }
  func projectedUnits() throws -> [NativeInductionWorkshopUnit] {
    let history = self.history ?? []
    guard history.count <= 512, self.history == nil || !history.isEmpty,
      Set(history.map(\.operation)).count == history.count
    else { throw SaveError.invalidCommander }
    var result = Self.originals(source: identity)
    var instances: Set<UUID> = []
    var clock = (issue.sequence, issue.physicalTime, issue.flightSeconds)
    for (index, event) in history.enumerated() {
      guard event.revision == UInt64(index), event.sequence > clock.0,
        event.sequence < UInt64(Int64.max),
        event.physicalTime.isFinite, (clock.1...1e12).contains(event.physicalTime),
        event.flightSeconds.isFinite, (clock.2...1e12).contains(event.flightSeconds),
        let slot = result.firstIndex(where: { $0.id == event.unit })
      else { throw SaveError.invalidCommander }
      switch event.kind {
      case .reserved:
        guard result[slot].status == .available, result[slot].instance == nil,
          event.condition == nil,
          event.instance
            == Self.instance(source: identity, unit: event.unit, revision: event.revision),
          instances.insert(event.instance).inserted
        else { throw SaveError.invalidCommander }
        result[slot].status = .held
        result[slot].instance = event.instance
      case .cancelledBeforePickup:
        guard result[slot].status == .held, result[slot].instance == event.instance,
          event.condition == nil
        else { throw SaveError.invalidCommander }
        result[slot].status = .available
        result[slot].instance = nil
      case .returned, .cancelledHeld, .lost, .sourceLost:
        guard result[slot].status == .held, result[slot].instance == event.instance,
          let condition = event.condition, condition.sourceUnit == event.unit
        else { throw SaveError.invalidCommander }
        result[slot].status = [.returned, .cancelledHeld].contains(event.kind) ? .returned : .lost
        result[slot].returnedCondition = condition
      }
      clock = (event.sequence, event.physicalTime, event.flightSeconds)
    }
    return result
  }
  static func instance(source: UUID, unit: UUID, revision: UInt64) -> UUID {
    ScriptIdentity.uuid("induction-original-workshop-booking-v1:\(source):\(unit):\(revision)")
  }
  func snapshot(at revision: UInt64) throws -> Self {
    guard revision <= self.revision else { throw SaveError.invalidCommander }
    var next = self
    next.history = revision == 0 ? nil : Array((history ?? []).prefix(Int(revision)))
    next.units = try next.projectedUnits()
    return next
  }
  func applying(_ event: NativeInductionWorkshopStockMutation) throws -> Self {
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
        let close = (history ?? []).first(where: {
          $0.kind != .reserved && $0.window == receipt.operation
        }),
        receipt.reason == (close.kind == .returned ? .completed : .cancelled)
      else { return false }
      return (history ?? []).contains {
        $0.kind == .reserved && $0.instance == close.instance && $0.unit == close.unit
          && $0.window == receipt.reservation
      }
    }
  }
  func windowEventClock(_ event: NativeInductionCapacityEvent) -> (UInt64, Double, Double)? {
    guard let item = (history ?? []).first(where: { $0.window == event.operation }) else {
      return nil
    }
    return (item.sequence, item.physicalTime, item.flightSeconds)
  }
}

extension NativeWayfarerInductionState {
  func charterCapacityEventClock(_ event: NativeInductionCapacityEvent) -> (UInt64, Double, Double)?
  {
    if case .released(let release) = event {
      return (release.sequence, release.physicalTime, release.flightSeconds)
    }
    return charterClinicSource?.windowEventClock(event)
      ?? charterWorkshopSource?.windowEventClock(event)
      ?? charterSeedSource?.windowEventClock(event)
  }
  private func withWorkshopSource(
    _ source: NativeInductionWorkshopSource, capacity: NativeInductionCapacityState
  ) throws -> Self {
    let next = Self(
      permission: permission, crate: crate, loss: loss, reception: reception,
      cassette: cassette, cassetteLoss: cassetteLoss, cassetteService: cassetteService,
      seedKey: seedKey, seedKeyLoss: seedKeyLoss, ark: ark, seedReception: seedReception,
      crewLog: crewLog, crewLogLoss: crewLogLoss, crewLogHullCustody: crewLogHullCustody,
      rescueReception: rescueReception, utilityReception: utilityReception,
      charterChoice: charterChoice, charterCapacity: capacity, charterSignatures: charterSignatures,
      charterClinicSource: charterClinicSource, charterWorkshopSource: source,
      charterSeedSource: charterSeedSource)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }
  func issuingWorkshopBatch(_ source: NativeInductionWorkshopSource) throws -> Self {
    guard valid, charterWorkshopSource == nil, source.valid(parent: self), let charterCapacity
    else { throw SaveError.invalidCommander }
    return try withWorkshopSource(source, capacity: charterCapacity)
  }
  func updatingWorkshop(
    _ source: NativeInductionWorkshopSource, capacity: NativeInductionCapacityState
  ) throws -> Self {
    guard valid, let previous = charterWorkshopSource, let before = charterCapacity,
      previous.identity == source.identity, previous.issue == source.issue,
      source.revision == previous.revision + 1, capacity.allocation == before.allocation,
      capacity.revision == before.revision + 1
    else { throw SaveError.invalidCommander }
    return try withWorkshopSource(source, capacity: capacity)
  }
}
