import Foundation

/// Descriptive binding only. MBA-05 must admit actual owner, custody and receiver facts.
struct WayfarerColdChainBinding: Codable, Sendable, Equatable {
  let owner: UUID
  let instance: UUID
  let consignment: UUID
  let receiver: UUID
  let timerID: String
}

/// A projection of existing native state, never a second clock or an action capability.
struct WayfarerColdChainSnapshot: Sendable {
  let binding: WayfarerColdChainBinding
  let timer: ScriptTimer
  let context: ScriptEventContext
}

enum WayfarerColdChainError: Error {
  case invalidBinding, invalidTimer, invalidClock, alreadyTerminal, invalidReceipt
}

/// W01 integrity only; has no authority to move cargo, settle cash or complete a mission.
struct WayfarerColdChain: Codable, Sendable, Equatable {
  /// Closed projection of the admitted native event; numeric types survive ordinary Codable.
  struct TimerReceipt: Codable, Sendable, Equatable {
    let sequence: UInt64
    let instance: UUID
    let timerID: String
    let due: Double
    let firedAt: Double
    let context: ScriptEventContext
  }

  enum Terminal: Codable, Sendable, Equatable {
    case spoiled(TimerReceipt)
    case received(ScriptCourierTerminalReceipt)
  }

  private struct Record: Codable, Sendable, Equatable {
    let schema: Int
    let binding: WayfarerColdChainBinding
    let timer: ScriptTimer
    let allowance: Double
    let issuedFlightSeconds: Double
    let issueSequence: UInt64
    var lastContext: ScriptEventContext
    var terminal: Terminal?
  }

  private var record: Record
  var binding: WayfarerColdChainBinding { record.binding }
  var terminal: Terminal? { record.terminal }
  var remaining: Double { max(0, record.timer.due - record.lastContext.flightSeconds) }

  init(snapshot: WayfarerColdChainSnapshot, allowance: Double, issueSequence: UInt64) throws {
    record = Record(
      schema: 1, binding: snapshot.binding, timer: snapshot.timer, allowance: allowance,
      issuedFlightSeconds: snapshot.context.flightSeconds, issueSequence: issueSequence,
      lastContext: snapshot.context)
    guard valid else { throw WayfarerColdChainError.invalidTimer }
  }

  init(from decoder: any Decoder) throws {
    record = try Record(from: decoder)
    guard valid else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Invalid W01 cold-chain state."))
    }
  }

  func encode(to encoder: any Encoder) throws {
    try record.encode(to: encoder)
  }

  /// Absolute snapshots preserve pause/load behavior; identical snapshots change nothing.
  func observing(_ snapshot: WayfarerColdChainSnapshot) throws -> Self {
    guard terminal == nil else { throw WayfarerColdChainError.alreadyTerminal }
    guard snapshot.binding == binding else { throw WayfarerColdChainError.invalidBinding }
    guard snapshot.timer == record.timer else { throw WayfarerColdChainError.invalidTimer }
    try checkContext(snapshot.context)
    var next = self
    next.record.lastContext = snapshot.context
    return next
  }

  /// The existing one-shot timer is removed by the director before this event arrives.
  func spoiling(binding: WayfarerColdChainBinding, event: ScriptEvent) throws -> Self {
    guard terminal == nil else { throw WayfarerColdChainError.alreadyTerminal }
    guard binding == self.binding else { throw WayfarerColdChainError.invalidBinding }
    guard validExpiry(event), let context = event.context else {
      throw WayfarerColdChainError.invalidReceipt
    }
    try checkContext(context)
    var next = self
    next.record.lastContext = context
    next.record.terminal = .spoiled(
      .init(
        sequence: event.sequence, instance: event.instance, timerID: binding.timerID,
        due: record.timer.due, firedAt: context.flightSeconds, context: context))
    return next
  }

  /// MBA-05 must join this receipt to live reception/custody and this exact receiver resource.
  /// Courier proof.clock is mission-calendar time; it must not be used as flight time.
  func receiving(
    _ snapshot: WayfarerColdChainSnapshot, receipt: ScriptCourierTerminalReceipt
  ) throws -> Self {
    var next = try observing(snapshot)
    guard next.remaining > 0, validReception(receipt) else {
      throw WayfarerColdChainError.invalidReceipt
    }
    next.record.terminal = .received(receipt)
    return next
  }

  func matchesNativeState(
    timer: ScriptTimer, allowance: Double, issueSequence: UInt64,
    issuedFlightSeconds: Double, lastContext: ScriptEventContext
  ) -> Bool {
    valid && record.timer == timer && record.allowance == allowance
      && record.issueSequence == issueSequence && record.issuedFlightSeconds == issuedFlightSeconds
      && record.lastContext == lastContext
  }

  private func checkContext(_ context: ScriptEventContext) throws {
    guard context.valid,
      context.flightSeconds >= record.lastContext.flightSeconds,
      context.revision >= record.lastContext.revision
    else { throw WayfarerColdChainError.invalidClock }
  }

  private func validExpiry(_ event: ScriptEvent) -> Bool {
    guard let context = event.context, context.valid else { return false }
    return event.kind == "timer.fired" && event.instance == binding.instance
      && event.sequence > record.issueSequence && event.sequence < UInt64(Int64.max)
      && event.values["timer_id"] == .string(binding.timerID)
      && event.values["pulse"] == .integer(1)
      && event.values["due"]?.double == record.timer.due
      && event.values["fired_at"]?.double == context.flightSeconds
      && event.values["has_been_run"] == .bool(true)
      && context.flightSeconds >= record.timer.due
  }

  private func validReception(_ receipt: ScriptCourierTerminalReceipt) -> Bool {
    receipt.id == ScriptCourierCustody.terminalIdentity(binding.consignment)
      && receipt.item == binding.consignment && receipt.cause == .delivered
      && receipt.proof.valid && receipt.proof.sequence > record.issueSequence
      && receipt.amount >= 0
  }

  private var valid: Bool {
    guard record.schema == 1, record.timer.valid,
      record.timer.domain == .flight, record.timer.policy == .once,
      record.timer.pulses == 0, record.timer.lastDue == nil,
      record.timer.lastFiredAt == nil, record.timer.clockExhausted != true,
      record.timer.id == binding.timerID,
      record.allowance.isFinite, record.allowance > 0,
      record.issuedFlightSeconds.isFinite, record.issuedFlightSeconds >= 0,
      record.timer.due == record.issuedFlightSeconds + record.allowance,
      record.timer.due > record.issuedFlightSeconds,
      record.issueSequence > 0, record.issueSequence < UInt64(Int64.max),
      record.lastContext.valid,
      record.lastContext.flightSeconds >= record.issuedFlightSeconds
    else { return false }
    switch terminal {
    case nil: return true
    case .some(.spoiled(let receipt)):
      return receipt.sequence > record.issueSequence && receipt.sequence < UInt64(Int64.max)
        && receipt.instance == binding.instance && receipt.timerID == binding.timerID
        && receipt.due == record.timer.due && receipt.firedAt >= receipt.due
        && receipt.context == record.lastContext
        && receipt.firedAt == receipt.context.flightSeconds
    case .some(.received(let receipt)):
      return validReception(receipt) && remaining > 0
    }
  }
}
