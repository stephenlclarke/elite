import Foundation

struct NativeInductionWorkshopEndFacts: Codable, Sendable, Equatable {
  enum Kind: String, Codable, Sendable {
    case cancelledBeforePickup, returned, cancelledHeld, carrierExit, sourceLost
  }
  let booking: UUID
  let kind: Kind
  let sequence: UInt64
  let stockRevision: UInt64
  let window: NativeInductionCapacityReturn
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let context: ScriptEventContext
  let contact: WayfarerColdChainContact?
  let loss: WayfarerColdChainPhysicalLoss?
  let sourceLoss: ScriptStationResource?
  let creditsBefore: Int?
  let creditsAfter: Int?
}

struct NativeInductionWorkshopEnd: Codable, Sendable, Equatable {
  let operation: UUID
  let facts: NativeInductionWorkshopEndFacts
  static func identity(_ facts: NativeInductionWorkshopEndFacts) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-original-workshop-terminal-v1:\(try NativeFlightReception.hash(facts))")
  }
  func valid(contract: NativeInductionWorkshopContract, parent: NativeWayfarerInductionState)
    -> Bool
  {
    let booking = contract.booking
    let f = facts
    let previousSequence =
      contract.cancellation?.contact.sequence ?? contract.service?.contact.sequence ?? contract
      .pickup?.contact.sequence ?? booking.sequence
    let previousTime =
      contract.cancellation?.physicalTime ?? contract.service?.physicalTime ?? contract.pickup?
      .physicalTime ?? booking.physicalTime
    let previousClock =
      contract.cancellation?.contact.context.flightSeconds ?? contract.service?.contact.context
      .flightSeconds ?? contract.pickup?.contact.context.flightSeconds ?? booking.flightSeconds
    guard operation == (try? Self.identity(f)), f.booking == booking.operation,
      f.sequence > previousSequence, f.sequence < UInt64(Int64.max),
      f.physicalTime.isFinite, (previousTime...1e12).contains(f.physicalTime),
      f.context.valid, f.context.flightSeconds >= previousClock,
      f.context.calendarSeconds >= booking.dock.calendarSeconds,
      f.carrier == booking.carrier,
      f.inventoryRevision
        >= (contract.service?.inventoryRevision ?? contract.pickup?.inventoryRevision
          ?? booking.inventoryRevision),
      f.inventoryRevision < UInt64(Int64.max), f.stockRevision > booking.stockRevision,
      let source = parent.charterWorkshopSource, let capacity = parent.charterCapacity,
      let stock = try? source.snapshot(at: f.stockRevision),
      stock.units.contains(where: {
        $0.id == booking.unit && $0.serial == booking.serial && $0.instance == booking.instance
          && $0.status == .held
      }),
      let before = try? capacity.snapshot(at: f.window.revision),
      f.window
        == (try? before.returnQuote(
          reservation: booking.window.operation,
          reason: f.kind == .returned ? .completed : .cancelled))
    else { return false }
    let previousDock =
      contract.cancellation?.contact.dock ?? contract.service?.contact.dock ?? contract.pickup?
      .contact.dock ?? booking.dock
    let previousRevision =
      contract.cancellation?.contact.context.revision ?? contract.service?.contact.context.revision
      ?? contract.pickup?.contact.context.revision ?? 0
    guard f.context.calendarSeconds >= previousDock.calendarSeconds,
      f.context.revision >= previousRevision
    else { return false }
    if let contact = f.contact {
      guard contact.valid, contact.sequence == f.sequence, contact.context == f.context,
        contact.dock.commanderOwner == booking.commanderOwner,
        contact.dock.sequence >= previousDock.sequence,
        contact.dock.actor.visit >= previousDock.actor.visit
      else { return false }
    }
    if f.kind != .returned && (f.creditsBefore != nil || f.creditsAfter != nil) { return false }
    switch f.kind {
    case .cancelledBeforePickup:
      return contract.pickup == nil && f.contact != nil && f.loss == nil && f.sourceLoss == nil
    case .returned:
      guard contract.pickup != nil, let service = contract.service, contract.cancellation == nil,
        let contact = f.contact, contact.dock.station == booking.dock.station,
        contact.dock.sequence > service.contact.dock.sequence,
        contact.dock.actor.visit > service.contact.dock.actor.visit,
        f.loss == nil, f.sourceLoss == nil, let before = f.creditsBefore,
        let after = f.creditsAfter,
        (0...4_294_967_295).contains(before), before <= 4_294_967_295 - booking.rewardNative,
        after == before + booking.rewardNative
      else { return false }
      return true
    case .cancelledHeld:
      return contract.pickup != nil && contract.cancellation != nil
        && f.contact?.dock.station == booking.dock.station && f.loss == nil && f.sourceLoss == nil
    case .carrierExit:
      guard let loss = f.loss, loss.valid, loss.sequence == f.sequence, loss.context == f.context,
        loss.visit >= booking.dock.actor.visit, f.contact == nil, f.sourceLoss == nil
      else { return false }
      return true
    case .sourceLost:
      guard contract.pickup == nil, f.contact == nil, f.loss == nil,
        let sourceLoss = f.sourceLoss, sourceLoss.valid, sourceLoss.destroyed,
        sourceLoss.energy == 0,
        sourceLoss.identity == source.issue.dock.station.resource,
        sourceLoss.key == source.issue.profile.source.resourceKey
      else { return false }
      return true
    }
  }
}

final class NativeInductionWorkshopContract: Codable, Sendable, Equatable {
  static let payload = "induction-original-workshop-unit"
  let booking: NativeInductionWorkshopBooking
  let pickup: NativeInductionWorkshopPickup?
  let service: NativeInductionWorkshopService?
  let cancellation: NativeInductionWorkshopCancellation?
  let end: NativeInductionWorkshopEnd?
  init(
    booking: NativeInductionWorkshopBooking, pickup: NativeInductionWorkshopPickup? = nil,
    service: NativeInductionWorkshopService? = nil,
    cancellation: NativeInductionWorkshopCancellation? = nil,
    end: NativeInductionWorkshopEnd? = nil
  ) {
    self.booking = booking
    self.pickup = pickup
    self.service = service
    self.cancellation = cancellation
    self.end = end
  }
  var reservedCargoTonnes: Int { pickup == nil && end == nil ? 2 : 0 }
  var payloads: [String: Int] { pickup != nil && end == nil ? [Self.payload: 2] : [:] }
  var condition: NativeRepairLoopCondition { service?.after ?? .failed(sourceUnit: booking.unit) }
  var outcome: ScriptOutcome {
    guard let end else { return .active }
    switch end.facts.kind {
    case .returned: return .complete
    case .cancelledBeforePickup, .cancelledHeld: return .abandoned
    case .carrierExit, .sourceLost: return .failed
    }
  }
  func valid(parent: NativeWayfarerInductionState) -> Bool {
    guard booking.valid(parent: parent) else { return false }
    if let pickup { guard pickup.valid(booking: booking) else { return false } }
    if let service {
      guard let pickup, service.valid(booking: booking, pickup: pickup) else { return false }
    }
    if let cancellation {
      guard let pickup, cancellation.valid(pickup: pickup, service: service) else { return false }
    }
    return end?.valid(contract: self, parent: parent) ?? true
  }
  static func == (a: NativeInductionWorkshopContract, b: NativeInductionWorkshopContract) -> Bool {
    a === b
      || (a.booking == b.booking && a.pickup == b.pickup && a.service == b.service
        && a.cancellation == b.cancellation && a.end == b.end)
  }
}
