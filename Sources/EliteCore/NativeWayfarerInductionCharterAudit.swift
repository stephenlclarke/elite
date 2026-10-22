import Foundation

/// A real available consignment quoted under its owner's narrow Avenor delegation.
enum NativeInductionCharterAuditCandidate: Codable, Sendable, Equatable {
  case clinic(NativeInductionClinicQuote)
  case workshop(NativeInductionWorkshopQuote)
  case seed(NativeInductionSeedQuote)

  var operatorID: NativeInductionCapacityOperator {
    switch self { case .clinic: .clinic; case .workshop: .workshop; case .seed: .seed }
  }
  var dock: NativeMainStationDockReceipt {
    switch self { case .clinic(let q): q.dock; case .workshop(let q): q.dock; case .seed(let q): q.dock }
  }
  var carrier: UUID {
    switch self { case .clinic(let q): q.carrier; case .workshop(let q): q.carrier; case .seed(let q): q.carrier }
  }
  var inventoryRevision: UInt64 {
    switch self { case .clinic(let q): q.inventoryRevision; case .workshop(let q): q.inventoryRevision; case .seed(let q): q.inventoryRevision }
  }
  var capacityRevision: UInt64 {
    switch self { case .clinic(let q): q.capacityRevision; case .workshop(let q): q.capacityRevision; case .seed(let q): q.capacityRevision }
  }
  var stockRevision: UInt64 {
    switch self { case .clinic(let q): q.stockRevision; case .workshop(let q): q.stockRevision; case .seed(let q): q.stockRevision }
  }
  var instance: UUID? {
    switch self {
    case .clinic(let q):
      guard let source = UUID(uuidString: q.offer.sourceID) else { return nil }
      return NativeInductionClinicBooking.instance(source: source, unit: q.offer.stockUnit, revision: q.stockRevision)
    case .workshop(let q):
      guard let source = UUID(uuidString: q.offer.sourceID) else { return nil }
      return NativeInductionWorkshopSource.instance(source: source, unit: q.offer.stockUnit, revision: q.stockRevision)
    case .seed(let q):
      guard let source = UUID(uuidString: q.offer.sourceID) else { return nil }
      return NativeInductionSeedBooking.instance(source: source, unit: q.offer.stockUnit, revision: q.stockRevision)
    }
  }

  /// Recreate the captured quote against exact retained source/capacity history, never today's route.
  func valid(parent: NativeWayfarerInductionState, sequence: UInt64, time: Double, clock: Double) -> Bool {
    guard let capacity = parent.charterCapacity,
      let before = try? capacity.snapshot(at: capacityRevision),
      capacity.events.enumerated().allSatisfy({ index, event in
        guard let c = parent.charterCapacityEventClock(event) else { return false }
        return index < Int(capacityRevision)
          ? c.0 < sequence && c.1 <= time && c.2 <= clock
          : c.0 > sequence && c.1 >= time && c.2 >= clock
      })
    else { return false }
    do {
      var clinic = parent.charterClinicSource
      var workshop = parent.charterWorkshopSource
      var seed = parent.charterSeedSource
      switch self {
      case .clinic: clinic = try clinic?.snapshot(at: stockRevision)
      case .workshop: workshop = try workshop?.snapshot(at: stockRevision)
      case .seed: seed = try seed?.snapshot(at: stockRevision)
      }
      let snapshot = parent.auditCopy(capacity: before, clinic: clinic, workshop: workshop, seed: seed)
      switch self {
      case .clinic(let q):
        guard let source = clinic, q.scope == .avenorReadOnlyAudit,
          source.issue.sequence < sequence,
          source.issue.physicalTime <= time, source.issue.flightSeconds <= clock,
          Self.historyValid(parent.charterClinicSource?.history?.map { ($0.sequence, $0.physicalTime, $0.flightSeconds) } ?? [], revision: stockRevision, sequence: sequence, time: time, clock: clock)
        else { return false }
        return q == (try NativeInductionClinicQuote.prepare(source: source, parent: snapshot, unit: q.offer.stockUnit, scope: .avenorReadOnlyAudit, dock: q.dock, carrier: q.carrier, revision: q.inventoryRevision, runtimeEpoch: q.runtimeEpoch, firstReachLY: q.route.firstReachLY, fullReachLY: q.route.fullReachLY, retainedRoute: q.route))
      case .workshop(let q):
        guard let source = workshop, q.scope == .avenorReadOnlyAudit,
          source.issue.sequence < sequence,
          source.issue.physicalTime <= time, source.issue.flightSeconds <= clock,
          Self.historyValid(parent.charterWorkshopSource?.history?.map { ($0.sequence, $0.physicalTime, $0.flightSeconds) } ?? [], revision: stockRevision, sequence: sequence, time: time, clock: clock)
        else { return false }
        return q == (try NativeInductionWorkshopQuote.prepare(source: source, parent: snapshot, unit: q.offer.stockUnit, scope: .avenorReadOnlyAudit, dock: q.dock, carrier: q.carrier, fit: q.inventoryRevision, runtimeEpoch: q.runtimeEpoch, firstReachLY: q.route.firstReachLY, fullReachLY: q.route.fullReachLY, retainedRoute: q.route))
      case .seed(let q):
        guard let source = seed, q.scope == .avenorReadOnlyAudit,
          source.issue.sequence < sequence,
          source.issue.physicalTime <= time, source.issue.flightSeconds <= clock,
          Self.historyValid(parent.charterSeedSource?.history?.map { ($0.sequence, $0.physicalTime, $0.flightSeconds) } ?? [], revision: stockRevision, sequence: sequence, time: time, clock: clock)
        else { return false }
        return q == (try NativeInductionSeedQuote.prepare(source: source, parent: snapshot, unit: q.offer.stockUnit, scope: .avenorReadOnlyAudit, dock: q.dock, carrier: q.carrier, revision: q.inventoryRevision, runtimeEpoch: q.runtimeEpoch, firstReachLY: q.route.firstReachLY, fullReachLY: q.route.fullReachLY, retainedRoute: q.route))
      }
    } catch { return false }
  }
  private static func historyValid(_ events: [(UInt64, Double, Double)], revision: UInt64, sequence: UInt64, time: Double, clock: Double) -> Bool {
    events.enumerated().allSatisfy { index, event in
      index < Int(revision)
        ? event.0 < sequence && event.1 <= time && event.2 <= clock
        : event.0 > sequence && event.1 >= time && event.2 >= clock
    }
  }
}

/// A refused request does not enter the finite ledger, move stock or create a contract.
struct NativeInductionCharterAudit: Codable, Sendable, Equatable {
  let operation: UUID
  let sequence: UInt64
  let choice: UUID
  let signatures: [UUID]
  let candidate: NativeInductionCharterAuditCandidate
  let attempt: NativeInductionCapacityReservation
  let unchanged: String
  let physicalTime: Double
  let flightSeconds: Double

  static func identity(sequence: UInt64, choice: UUID, signatures: [UUID], candidate: NativeInductionCharterAuditCandidate, attempt: NativeInductionCapacityReservation, unchanged: String, time: Double, clock: Double) throws -> UUID {
    ScriptIdentity.uuid("induction-actual-charter-audit-v1:\(sequence):\(choice):\(try NativeFlightReception.hash(signatures)):\(try NativeFlightReception.hash(candidate)):\(try NativeFlightReception.hash(attempt)):\(unchanged):\(time.bitPattern):\(clock.bitPattern)")
  }
  func valid(parent: NativeWayfarerInductionState) -> Bool {
    guard let choice = parent.charterChoice, choice.operation == self.choice,
      let signatures = parent.charterSignatures, signatures.count == 3,
      Set(signatures.map(\.operatorID)) == Set(NativeInductionCapacityOperator.allCases),
      self.signatures == signatures.map(\.operation),
      sequence < UInt64(Int64.max), physicalTime.isFinite, flightSeconds.isFinite,
      physicalTime <= 1e12, flightSeconds <= 1e12,
      signatures.allSatisfy({ $0.sequence < sequence && $0.physicalTime <= physicalTime && $0.flightSeconds <= flightSeconds && $0.dock.sequence < candidate.dock.sequence && $0.dock.actor.visit < candidate.dock.actor.visit && $0.dock.calendarSeconds <= candidate.dock.calendarSeconds }),
      let instance = candidate.instance,
      candidate.dock.station == choice.dock.station,
      candidate.valid(parent: parent, sequence: sequence, time: physicalTime, clock: flightSeconds),
      let capacity = try? parent.charterCapacity?.snapshot(at: candidate.capacityRevision),
      let slot = try? capacity.projection().first(where: { $0.unit.identity == attempt.unit }),
      slot.unit.operatorID == candidate.operatorID, slot.reservation == nil,
      choice.policy == .pooledWindows ? slot.unit.protected : (!slot.unit.protected && slot.release == nil),
      !capacity.eligible(slot), attempt.allocation == capacity.allocation.operation,
      attempt.epoch == capacity.allocation.epoch, attempt.policy == choice.policy,
      attempt.revision == capacity.revision, attempt.owner == slot.unit.owner,
      attempt.consignment == instance, attempt.before == (try? capacity.fingerprint),
      unchanged == attempt.before,
      attempt.operation == NativeInductionCapacityState.reservationIdentity(allocation: attempt.allocation, revision: attempt.revision, unit: attempt.unit, owner: attempt.owner, consignment: attempt.consignment, before: attempt.before),
      (try? capacity.quote(consignment: instance, unit: attempt.unit)) == nil,
      (try? capacity.reserving(attempt)) == nil,
      unchanged == (try? capacity.fingerprint)
    else { return false }
    return operation == (try? Self.identity(sequence: sequence, choice: self.choice, signatures: self.signatures, candidate: candidate, attempt: attempt, unchanged: unchanged, time: physicalTime, clock: flightSeconds))
  }
}

extension NativeWayfarerInductionState {
  func auditCopy(capacity: NativeInductionCapacityState?, clinic: NativeInductionClinicSource?, workshop: NativeInductionWorkshopSource?, seed: NativeInductionSeedSource?, audit: NativeInductionCharterAudit? = nil) -> NativeWayfarerInductionState {
    .init(permission: permission, crate: crate, loss: loss, reception: reception,
      cassette: cassette, cassetteLoss: cassetteLoss, cassetteService: cassetteService,
      seedKey: seedKey, seedKeyLoss: seedKeyLoss, ark: ark, seedReception: seedReception,
      crewLog: crewLog, crewLogLoss: crewLogLoss, crewLogHullCustody: crewLogHullCustody,
      rescueReception: rescueReception, utilityReception: utilityReception,
      charterChoice: charterChoice, charterCapacity: capacity, charterSignatures: charterSignatures,
      charterClinicSource: clinic, charterWorkshopSource: workshop, charterSeedSource: seed, charterAudit: audit)
  }
  func auditingCharter(_ receipt: NativeInductionCharterAudit) throws -> NativeWayfarerInductionState {
    guard valid, charterAudit == nil, receipt.valid(parent: self) else { throw SaveError.invalidCommander }
    return auditCopy(capacity: charterCapacity, clinic: charterClinicSource, workshop: charterWorkshopSource, seed: charterSeedSource, audit: receipt)
  }
}

extension NativeInductionCharterAudit {
  static func prepare(parent: NativeWayfarerInductionState, candidate: NativeInductionCharterAuditCandidate, sequence: UInt64, time: Double, clock: Double) throws -> Self {
    guard parent.valid, parent.charterAudit == nil, let choice = parent.charterChoice,
      let signatures = parent.charterSignatures, let capacity = parent.charterCapacity,
      candidate.capacityRevision == capacity.revision, let instance = candidate.instance,
      let slot = try capacity.projection().first(where: {
        $0.unit.operatorID == candidate.operatorID && $0.reservation == nil
          && (choice.policy == .pooledWindows ? $0.unit.protected : (!$0.unit.protected && $0.release == nil))
      })
    else { throw SaveError.invalidCommander }
    let before = try capacity.fingerprint
    let request = NativeInductionCapacityReservation(
      operation: NativeInductionCapacityState.reservationIdentity(allocation: capacity.allocation.operation, revision: capacity.revision, unit: slot.unit.identity, owner: slot.unit.owner, consignment: instance, before: before),
      allocation: capacity.allocation.operation, epoch: capacity.allocation.epoch, policy: choice.policy,
      revision: capacity.revision, unit: slot.unit.identity, owner: slot.unit.owner,
      consignment: instance, before: before)
    let ids = signatures.map(\.operation)
    let result = Self(operation: try identity(sequence: sequence, choice: choice.operation, signatures: ids, candidate: candidate, attempt: request, unchanged: before, time: time, clock: clock), sequence: sequence, choice: choice.operation, signatures: ids, candidate: candidate, attempt: request, unchanged: before, physicalTime: time, flightSeconds: clock)
    guard result.valid(parent: parent) else { throw SaveError.invalidCommander }
    return result
  }
}
