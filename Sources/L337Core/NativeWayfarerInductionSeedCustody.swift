import Foundation

struct NativeInductionSeedPickup: Codable, Sendable, Equatable {
  let operation: UUID
  let booking: UUID
  let contact: WayfarerColdChainContact
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  static func identity(
    booking: UUID, contact: WayfarerColdChainContact, carrier: UUID, fit: UInt64,
    time: Double
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-seed-original-pickup-v1:\(booking):\(try NativeFlightReception.hash(contact)):\(carrier):\(fit):\(time.bitPattern)"
    )
  }
  func valid(booking: NativeInductionSeedBooking) -> Bool {
    self.booking == booking.operation && contact.valid && contact.sequence > booking.sequence
      && contact.dock.station == booking.dock.station
      && contact.dock.commanderOwner == booking.commanderOwner
      && contact.dock.sequence >= booking.dock.sequence
      && contact.dock.actor.visit >= booking.dock.actor.visit
      && contact.context.flightSeconds >= booking.flightSeconds
      && contact.context.calendarSeconds >= booking.dock.calendarSeconds
      && carrier == booking.carrier && inventoryRevision >= booking.inventoryRevision
      && inventoryRevision < UInt64(Int64.max) && physicalTime.isFinite
      && (booking.physicalTime...1e12).contains(physicalTime)
      && operation
        == (try? Self.identity(
          booking: self.booking, contact: contact, carrier: carrier,
          fit: inventoryRevision, time: physicalTime))
  }
}

struct NativeInductionSeedHeldCancellation: Codable, Sendable, Equatable {
  let operation: UUID
  let pickup: UUID
  let contact: WayfarerColdChainContact
  let physicalTime: Double
  static func identity(pickup: UUID, contact: WayfarerColdChainContact, time: Double) throws -> UUID
  {
    ScriptIdentity.uuid(
      "induction-seed-held-cancel-v1:\(pickup):\(try NativeFlightReception.hash(contact)):\(time.bitPattern)"
    )
  }
  func valid(pickup: NativeInductionSeedPickup) -> Bool {
    self.pickup == pickup.operation && contact.valid && contact.sequence > pickup.contact.sequence
      && contact.dock.commanderOwner == pickup.contact.dock.commanderOwner
      && contact.dock.sequence >= pickup.contact.dock.sequence
      && contact.dock.actor.visit >= pickup.contact.dock.actor.visit
      && contact.context.flightSeconds >= pickup.contact.context.flightSeconds
      && physicalTime.isFinite && (pickup.physicalTime...1e12).contains(physicalTime)
      && operation
        == (try? Self.identity(pickup: self.pickup, contact: contact, time: physicalTime))
  }
}

struct NativeInductionSeedCustodyEnd: Codable, Sendable, Equatable {
  enum Kind: String, Codable, Sendable { case received, returned, spoiled, carrierExit }
  let operation: UUID
  let booking: UUID
  let pickup: UUID
  let kind: Kind
  let sequence: UInt64
  let stockRevision: UInt64
  let window: NativeInductionCapacityReturn
  let physicalTime: Double
  let context: ScriptEventContext
  let closedFlightSeconds: Double
  let contact: WayfarerColdChainContact?
  let loss: WayfarerColdChainPhysicalLoss?
  let expiry: ScriptEvent?
  let payment: ScriptCourierTerminalReceipt?
  let creditsBefore: Int?
  let creditsAfter: Int?
  static func identity(
    booking: UUID, pickup: UUID, kind: Kind, sequence: UInt64,
    stockRevision: UInt64, window: NativeInductionCapacityReturn, time: Double,
    context: ScriptEventContext, closedFlightSeconds: Double, contact: WayfarerColdChainContact?,
    loss: WayfarerColdChainPhysicalLoss?,
    expiry: ScriptEvent?, payment: ScriptCourierTerminalReceipt?, before: Int?, after: Int?
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-seed-custody-end-v1:\(booking):\(pickup):\(kind.rawValue):\(sequence):\(stockRevision):\(try NativeFlightReception.hash(window)):\(time.bitPattern):\(try NativeFlightReception.hash(context)):\(closedFlightSeconds.bitPattern):\(try NativeFlightReception.hash(contact)):\(try NativeFlightReception.hash(loss)):\(try NativeFlightReception.hash(expiry)):\(try NativeFlightReception.hash(payment)):\(String(describing: before)):\(String(describing: after))"
    )
  }
  func valid(
    booking: NativeInductionSeedBooking, custody: NativeInductionSeedCustody,
    parent: NativeWayfarerInductionState
  ) -> Bool {
    guard self.booking == booking.operation, pickup == custody.pickup.operation,
      sequence > custody.pickup.contact.sequence, sequence < UInt64(Int64.max),
      stockRevision > booking.stockRevision,
      let source = parent.charterSeedSource, let capacity = parent.charterCapacity,
      let stock = try? source.snapshot(at: stockRevision),
      stock.units.contains(where: {
        $0.id == booking.unit && $0.instance == booking.instance && $0.status == .held
      }),
      let before = try? capacity.snapshot(at: window.revision),
      window
        == (try? before.returnQuote(
          reservation: booking.window.operation,
          reason: kind == .received ? .completed : .cancelled)),
      context.valid, context.flightSeconds >= custody.pickup.contact.context.flightSeconds,
      closedFlightSeconds.isFinite, (context.flightSeconds...1e12).contains(closedFlightSeconds),
      kind == .spoiled || closedFlightSeconds == context.flightSeconds,
      context.calendarSeconds >= custody.pickup.contact.context.calendarSeconds,
      context.revision >= custody.pickup.contact.context.revision,
      physicalTime.isFinite, (custody.pickup.physicalTime...1e12).contains(physicalTime),
      operation
        == (try? Self.identity(
          booking: self.booking, pickup: pickup, kind: kind,
          sequence: sequence, stockRevision: stockRevision, window: window, time: physicalTime,
          context: context, closedFlightSeconds: closedFlightSeconds, contact: contact, loss: loss,
          expiry: expiry, payment: payment,
          before: creditsBefore, after: creditsAfter))
    else { return false }
    if let contact {
      guard contact.dock.sequence >= custody.pickup.contact.dock.sequence,
        contact.dock.actor.visit >= custody.pickup.contact.dock.actor.visit
      else { return false }
    }
    if let cancellation = custody.cancellation {
      guard sequence > cancellation.contact.sequence,
        context.flightSeconds >= cancellation.contact.context.flightSeconds,
        physicalTime >= cancellation.physicalTime
      else { return false }
    }
    switch kind {
    case .received:
      guard custody.cancellation == nil, let contact, contact.valid,
        contact.sequence == sequence, contact.context == context,
        booking.terms.receiver.matches(contact.dock.station),
        contact.dock.commanderOwner == booking.commanderOwner,
        let payment, payment.amount == booking.terms.rewardNative,
        payment.proof.sequence == sequence, payment.proof.clock == context.calendarSeconds,
        payment.proof.token == "induction-original-seed-reception",
        payment.proof.revision == context.revision,
        payment.proof.station
          == ContractStationIdentity(
            galaxy: context.galaxy, system: context.system, stationClass: "main-orbital"),
        let creditsBefore, let creditsAfter, (0...4_294_967_295).contains(creditsBefore),
        creditsBefore <= 4_294_967_295 - payment.amount,
        creditsAfter == creditsBefore + payment.amount,
        loss == nil, expiry == nil,
        custody.integrity.terminal == .received(payment)
      else { return false }
    case .returned:
      guard context.flightSeconds < custody.timer.due, custody.cancellation != nil, let contact,
        contact.valid,
        contact.sequence == sequence, contact.context == context,
        contact.dock.station == booking.dock.station,
        contact.dock.commanderOwner == booking.commanderOwner,
        loss == nil, expiry == nil, payment == nil, creditsBefore == nil, creditsAfter == nil,
        custody.integrity.terminal == nil
      else { return false }
    case .spoiled:
      guard let expiry, expiry.instance == booking.instance, expiry.sequence <= sequence,
        expiry.sequence > custody.pickup.contact.sequence,
        expiry.kind == "timer.fired", expiry.context == context,
        Set(expiry.values.keys) == [
          "timer_id", "pulse", "due", "fired_at", "has_been_run", "clock_exhausted", "counters",
          "reset_counters",
        ],
        expiry.values["timer_id"] == .string(custody.timer.id),
        expiry.values["pulse"] == .integer(1), expiry.values["due"]?.double == custody.timer.due,
        expiry.values["fired_at"]?.double == context.flightSeconds,
        expiry.values["has_been_run"] == .bool(true),
        expiry.values["clock_exhausted"] == .bool(false),
        expiry.values["counters"] == .object([:]), expiry.values["reset_counters"] == .array([]),
        contact == nil, loss == nil, payment == nil,
        creditsBefore == nil, creditsAfter == nil,
        case .some(.spoiled(let receipt)) = custody.integrity.terminal,
        receipt.sequence == expiry.sequence, receipt.context == context
      else { return false }
    case .carrierExit:
      guard let loss, loss.valid, loss.sequence == sequence, loss.context == context,
        loss.visit >= custody.pickup.contact.dock.actor.visit,
        contact == nil, expiry == nil, payment == nil, creditsBefore == nil, creditsAfter == nil,
        custody.integrity.terminal == nil
      else { return false }
    }
    return true
  }
}

struct NativeInductionSeedCustody: Codable, Sendable, Equatable {
  static let payload = "induction-original-seed-lot"
  static let timerID = "induction-original-seed-integrity"
  let pickup: NativeInductionSeedPickup
  let timer: ScriptTimer
  let integrity: WayfarerColdChain
  var cancellation: NativeInductionSeedHeldCancellation?
  var end: NativeInductionSeedCustodyEnd?
  var outcome: ScriptOutcome {
    guard let end else { return .active }
    switch end.kind {
    case .received: return .complete
    case .returned: return .abandoned
    case .spoiled, .carrierExit: return .failed
    }
  }
  func valid(booking: NativeInductionSeedBooking, parent: NativeWayfarerInductionState) -> Bool {
    guard pickup.valid(booking: booking), timer.valid,
      timer.id == Self.timerID, timer.domain == .flight, timer.policy == .once,
      timer.interval == 0, timer.pulses == 0,
      timer.due == pickup.contact.context.flightSeconds + booking.terms.flightAllowance,
      integrity.binding
        == WayfarerColdChainBinding(
          owner: booking.commanderOwner,
          instance: booking.instance, consignment: booking.unit,
          receiver: Game.worldResourceIdentity(
            "main-station-v1:" + booking.terms.receiver.resourceKey), timerID: timer.id),
      cancellation?.valid(pickup: pickup) ?? true,
      cancellation.map({ $0.contact.context.flightSeconds < timer.due }) ?? true,
      integrity.matchesNativeState(
        timer: timer, allowance: booking.terms.flightAllowance,
        issueSequence: pickup.contact.sequence,
        issuedFlightSeconds: pickup.contact.context.flightSeconds,
        lastContext: end?.context ?? cancellation?.contact.context ?? pickup.contact.context)
    else { return false }
    if let end { return end.valid(booking: booking, custody: self, parent: parent) }
    return integrity.terminal == nil
  }
}
