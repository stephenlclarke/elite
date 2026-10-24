import Foundation
import Testing

@testable import EliteCore

/// Raw settlement components only; no fixture claims a valid accepted native contract or journey.
struct ScriptSettlementProjectionTests {
  @Test(arguments: ["absent", "job", "courier-no-terminal", "terminal", "nan-clock"])
  func ownedSettlementReadsPreserveNilValuesClockAndRetainedBytes(scenario: String) throws {
    var state = instance()
    if scenario != "absent" { state.contract = job() }
    if scenario == "courier-no-terminal" {
      state.courier = courier(clock: nil)
    } else if scenario == "terminal" || scenario == "nan-clock" {
      state.courier = courier(clock: scenario == "nan-clock" ? .nan : 41.25)
    }
    let retained = state
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.nonConformingFloatEncodingStrategy = .convertToString(
      positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
    let bytes = try encoder.encode(state)
    let ownedJob = state.retainedSettlementJob
    let definition = state.retainedSettlementDefinition
    let clock = state.retainedSettlementCourierTerminalClock
    #expect(ownedJob == state.contract && definition == state.definition)
    if scenario == "nan-clock" {
      #expect(clock?.isNaN == true && state.courier?.terminal?.proof.clock.isNaN == true)
    } else {
      #expect(clock == state.courier?.terminal?.proof.clock)
      #expect(state == retained)
    }
    #expect(try encoder.encode(state) == bytes)
    let decoder = JSONDecoder()
    decoder.nonConformingFloatDecodingStrategy = .convertFromString(
      positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
    let decoded = try decoder.decode(ScriptInstance.self, from: bytes)
    #expect(decoded.retainedSettlementJob == ownedJob)
    #expect(decoded.retainedSettlementDefinition == definition)
    if scenario == "nan-clock" {
      #expect(decoded.retainedSettlementCourierTerminalClock?.isNaN == true)
    } else {
      #expect(decoded == state && decoded.retainedSettlementCourierTerminalClock == clock)
    }
    state.contract?.settled = true
    state.courier?.terminal = nil
    #expect(retained.retainedSettlementJob == ownedJob)
    #expect(ownedJob?.settled == (scenario == "absent" ? nil : false))
    #expect(try encoder.encode(retained) == bytes)
    state = ScriptInstance(
      id: state.id, definition: "later-component", version: "1.0.0", digest: digest)
    #expect(definition == "component-settlement")
    #expect(retained.retainedSettlementDefinition == definition)
    if scenario == "terminal" { #expect(clock == 41.25) }
  }

  @Test(arguments: [
    "missing", "complete", "failed-refund", "failed-no-refund", "abandoned", "settled",
    "cash-limit", "courier-clock",
  ])
  func settlementKeepsPaymentRefusalWritebackAndClockFallback(scenario: String) throws {
    let game = Game(executive: false)
    var state = instance()
    if scenario != "missing" { state.contract = job(refund: scenario != "failed-no-refund") }
    if scenario == "settled" { state.contract?.settled = true }
    if scenario == "courier-clock" { state.courier = courier(clock: 41.25) }
    var candidate = Commander()
    candidate.credits = scenario == "cash-limit" ? 4_294_967_295 : 1000
    candidate.scriptState.localSeconds = 17.5
    let beforeState = state
    let beforeCommander = candidate
    let outcome: ScriptOutcome =
      scenario.hasPrefix("failed") ? .failed : scenario == "abandoned" ? .abandoned : .complete
    if scenario == "settled" || scenario == "cash-limit" {
      #expect(throws: MissionPackError.self) {
        try game.settleContract(outcome, state: &state, candidate: &candidate)
      }
      #expect(state == beforeState && candidate == beforeCommander)
      return
    }
    try game.settleContract(outcome, state: &state, candidate: &candidate)
    if scenario == "missing" {
      #expect(state == beforeState && candidate == beforeCommander)
      return
    }
    let expectedAmount =
      scenario == "abandoned"
      ? 0
      : scenario == "failed-refund"
        ? 70
        : scenario == "failed-no-refund" ? 20 : 250
    let settled = try #require(state.contract)
    #expect(settled.settled && settled.settlementOutcome == outcome)
    #expect(settled.settlementAmount == expectedAmount)
    #expect(settled.settledAt == (scenario == "courier-clock" ? 41.25 : 17.5))
    #expect(candidate.credits == beforeCommander.credits + expectedAmount)
    var expectedCommander = beforeCommander
    expectedCommander.credits += expectedAmount
    #expect(candidate == expectedCommander)
    var expectedJob = try #require(beforeState.contract)
    expectedJob.settled = true
    expectedJob.settlementOutcome = outcome
    expectedJob.settlementAmount = expectedAmount
    expectedJob.settledAt = scenario == "courier-clock" ? 41.25 : 17.5
    var expectedState = beforeState
    expectedState.contract = expectedJob
    #expect(state == expectedState && beforeState.contract?.settled == false)
  }

  private let digest = String(repeating: "a", count: 64)
  private var station: ContractStationIdentity {
    .init(galaxy: 0, system: 7, stationClass: "main-orbital")
  }
  private func instance() -> ScriptInstance {
    .init(id: UUID(), definition: "component-settlement", version: "1.0.0", digest: digest)
  }
  private func job(refund: Bool = true) -> ScriptContractJob {
    let offer = ScriptContractOffer(
      id: UUID(), key: "component", title: "Component", briefing: "Settlement component",
      destinationGalaxy: 0, destinationSystem: 7, reward: 200, deposit: 50, failureReward: 20,
      refundOnFailure: refund, duration: 20, parameters: .object([:]))
    return .init(
      boardKey: digest + "/board/" + station.key, provider: "component.provider", version: "1.0.0",
      digest: digest, station: station, boardRevision: 0, group: "component.provider/jobs",
      offer: offer, clock: .local, acceptedAt: 1, deadline: 21)
  }
  private func courier(clock: Double?) -> ScriptCourierCustody {
    let item = UUID()
    let issue = ScriptCourierActionProof(
      sequence: 1, token: "component", revision: 0, epoch: UUID(), clock: 1, station: station)
    let terminal = clock.map { clock in
      ScriptCourierTerminalReceipt(
        id: UUID(), item: item, cause: .delivered,
        proof: .init(
          sequence: 2, token: "terminal", revision: 1, epoch: UUID(), clock: clock,
          station: station), amount: 250)
    }
    return .init(item: item, issue: issue, terminal: terminal)
  }
}
