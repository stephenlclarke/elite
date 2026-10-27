import Foundation
import Testing

@testable import EliteCore

struct WayfarerColdChainTests {
  private let owner = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
  private let instance = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
  private let receiver = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

  private var binding: WayfarerColdChainBinding {
    WayfarerColdChainBinding(
      owner: owner, instance: instance, consignment: ScriptCourierCustody.itemIdentity(instance),
      receiver: receiver, timerID: "sample-integrity")
  }

  // Fixture allowance only; production requires an authored finite allowance.
  private var timer: ScriptTimer {
    ScriptTimer(id: binding.timerID, domain: .flight, due: 130, interval: 0, policy: .once)
  }

  private func context(_ flight: Double, revision: UInt64 = 1) -> ScriptEventContext {
    ScriptEventContext(
      galaxy: 0, system: 7, docked: true, mainStation: true, revision: revision,
      frameSeconds: 999, localSeconds: 99, flightSeconds: flight, calendarSeconds: 5000,
      transitSeconds: 0, playerPosition: nil)
  }

  private func snapshot(
    _ flight: Double, revision: UInt64 = 1, timer supplied: ScriptTimer? = nil,
    binding suppliedBinding: WayfarerColdChainBinding? = nil
  ) -> WayfarerColdChainSnapshot {
    WayfarerColdChainSnapshot(
      binding: suppliedBinding ?? binding, timer: supplied ?? timer,
      context: context(flight, revision: revision))
  }

  private func issued() throws -> WayfarerColdChain {
    try WayfarerColdChain(snapshot: snapshot(100), allowance: 30, issueSequence: 5)
  }

  private func expiry(_ flight: Double = 130, sequence: UInt64 = 6) -> ScriptEvent {
    ScriptEvent(
      sequence: sequence, kind: "timer.fired", instance: instance,
      values: [
        "timer_id": .string(binding.timerID), "pulse": .integer(1), "due": .number(130),
        "fired_at": .number(flight), "has_been_run": .bool(true),
        "clock_exhausted": .bool(false), "counters": .object([:]), "reset_counters": .array([]),
      ], context: context(flight))
  }

  private func reception(sequence: UInt64 = 6) -> ScriptCourierTerminalReceipt {
    ScriptCourierTerminalReceipt(
      id: ScriptCourierCustody.terminalIdentity(binding.consignment),
      item: binding.consignment, cause: .delivered,
      proof: ScriptCourierActionProof(
        sequence: sequence, token: "reception", revision: 1, epoch: receiver,
        clock: 5000,
        station: ContractStationIdentity(
          galaxy: 0, system: 7, stationClass: "main-orbital")),
      amount: 0)
  }

  @Test func absoluteFlightBudgetAndRepeatedPauseSnapshot() throws {
    let start = try issued()
    #expect(start.remaining == 30)
    let halfway = try start.observing(snapshot(112))
    #expect(halfway.remaining == 18)
    #expect(try halfway.observing(snapshot(112)) == halfway)
    let resumed = try halfway.observing(snapshot(125, revision: 2))
    #expect(resumed.remaining == 5)
    #expect(start.remaining == 30)
  }

  @Test func reloadPreservesDueAndRemainder() throws {
    let saved = try issued().observing(snapshot(112))
    let reloaded = try JSONDecoder().decode(
      WayfarerColdChain.self, from: JSONEncoder().encode(saved))
    #expect(reloaded == saved)
    #expect(try reloaded.observing(snapshot(120)).remaining == 10)
  }

  @Test func exactBoundaryRequiresNativeTimerEventForTerminal() throws {
    let boundary = try issued().observing(snapshot(130))
    #expect(boundary.remaining == 0)
    #expect(boundary.terminal == nil)
    #expect(throws: WayfarerColdChainError.self) {
      try boundary.receiving(snapshot(130), receipt: reception())
    }
    let expired = try boundary.spoiling(binding: binding, event: expiry())
    #expect(expired.terminal != nil)
    #expect(expired.remaining == 0)
    #expect(throws: WayfarerColdChainError.self) {
      try expired.spoiling(binding: binding, event: expiry())
    }
    #expect(throws: WayfarerColdChainError.self) {
      try expired.receiving(snapshot(130), receipt: reception())
    }
  }

  @Test func delayedTimerDispatchUsesExistingAbsoluteClock() throws {
    for firedAt in [132.0, 132.25] {
      let expired = try issued().spoiling(binding: binding, event: expiry(firedAt))
      #expect(expired.remaining == 0)
      let decoded = try JSONDecoder().decode(
        WayfarerColdChain.self, from: JSONEncoder().encode(expired))
      #expect(decoded == expired)
    }
  }

  @Test func receptionUsesSnapshotFlightTimeNotCourierCalendarTime() throws {
    let received = try issued().receiving(snapshot(129), receipt: reception())
    #expect(received.remaining == 1)
    #expect(received.terminal == .received(reception()))
    #expect(throws: WayfarerColdChainError.self) {
      try received.receiving(snapshot(129), receipt: reception())
    }
    #expect(throws: WayfarerColdChainError.self) {
      try received.spoiling(binding: binding, event: expiry())
    }
  }

  @Test func rejectsAllForeignBindingComponents() throws {
    let original = binding
    let other = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    let foreign = [
      WayfarerColdChainBinding(
        owner: other, instance: original.instance,
        consignment: original.consignment, receiver: receiver, timerID: original.timerID),
      WayfarerColdChainBinding(
        owner: owner, instance: other,
        consignment: original.consignment, receiver: receiver, timerID: original.timerID),
      WayfarerColdChainBinding(
        owner: owner, instance: original.instance,
        consignment: other, receiver: receiver, timerID: original.timerID),
      WayfarerColdChainBinding(
        owner: owner, instance: original.instance,
        consignment: original.consignment, receiver: other, timerID: original.timerID),
      WayfarerColdChainBinding(
        owner: owner, instance: original.instance,
        consignment: original.consignment, receiver: receiver, timerID: "foreign"),
    ]
    for value in foreign {
      #expect(throws: WayfarerColdChainError.self) {
        try issued().observing(snapshot(110, binding: value))
      }
    }
  }

  @Test func rejectsInvalidReversedAndStaleClockSnapshots() throws {
    let state = try issued().observing(snapshot(115, revision: 3))
    for flight in [-1, 114, Double.nan, Double.infinity, 1e12 + 1] {
      #expect(throws: WayfarerColdChainError.self) {
        try state.observing(snapshot(flight, revision: 3))
      }
    }
    #expect(throws: WayfarerColdChainError.self) {
      try state.observing(snapshot(116, revision: 2))
    }
  }

  @Test func rejectsRearmingAndWrongDomainOrRepeatingTimers() throws {
    var timers = [timer, timer, timer, timer]
    timers[0].due = 140
    timers[1].domain = .local
    timers[2].policy = .delay
    timers[2].interval = 1
    timers[3].pulses = 1
    for changed in timers {
      #expect(throws: WayfarerColdChainError.self) {
        try issued().observing(snapshot(110, timer: changed))
      }
    }
    for allowance in [0, -1, Double.nan, Double.infinity, 31] {
      #expect(throws: WayfarerColdChainError.self) {
        try WayfarerColdChain(snapshot: snapshot(100), allowance: allowance, issueSequence: 5)
      }
    }
  }

  @Test func rejectsStaleForeignAndEarlyExpiryEvents() throws {
    var wrongTimer = expiry()
    wrongTimer = ScriptEvent(
      sequence: wrongTimer.sequence, kind: wrongTimer.kind, instance: instance,
      values: ["timer_id": .string("foreign")], context: wrongTimer.context)
    let foreign = ScriptEvent(
      sequence: 6, kind: "timer.fired", instance: receiver,
      values: expiry().values, context: context(130))
    for event in [expiry(sequence: 5), expiry(129), wrongTimer, foreign] {
      #expect(throws: WayfarerColdChainError.self) {
        try issued().spoiling(binding: binding, event: event)
      }
    }
  }

  @Test func rejectsStaleAndForeignCustodyReceipt() throws {
    let foreign = ScriptCourierTerminalReceipt(
      id: reception().id, item: receiver, cause: .delivered, proof: reception().proof, amount: 0)
    for receipt in [reception(sequence: 5), foreign] {
      #expect(throws: WayfarerColdChainError.self) {
        try issued().receiving(snapshot(120), receipt: receipt)
      }
    }
  }

  @Test func rejectsCorruptSavedTimerAndSchema() throws {
    let data = try JSONEncoder().encode(issued())
    let original = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    for key in ["schema", "allowance", "issuedFlightSeconds"] {
      var corrupt = original
      corrupt[key] = -1
      let changed = try JSONSerialization.data(withJSONObject: corrupt)
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(WayfarerColdChain.self, from: changed)
      }
    }
    let expired = try issued().spoiling(binding: binding, event: expiry(132))
    let expiredData = try JSONEncoder().encode(expired)
    let saved = try #require(JSONSerialization.jsonObject(with: expiredData) as? [String: Any])
    let terminal = try #require(saved["terminal"] as? [String: Any])
    let spoiled = try #require(terminal["spoiled"] as? [String: Any])
    let receipt = try #require(spoiled["_0"] as? [String: Any])
    let replacements: [String: Any] = [
      "sequence": 0, "instance": receiver.uuidString, "timerID": "foreign",
      "due": 131, "firedAt": 133,
    ]
    for (field, value) in replacements {
      var changedReceipt = receipt
      changedReceipt[field] = value
      var corrupt = saved
      corrupt["terminal"] = ["spoiled": ["_0": changedReceipt]]
      let bytes = try JSONSerialization.data(withJSONObject: corrupt)
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(WayfarerColdChain.self, from: bytes)
      }
    }
  }
}
