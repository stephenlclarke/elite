import Foundation
import Testing

@testable import EliteCore

/// Component projection checks; they do not claim an executed mission journey.
struct ScriptCargoProjectionTests {
  @Test(arguments: ["absent", "awaitingBuy", "held", "sold", "received", "cancelled", "lost"])
  func navigationStageQueryPreservesEveryStageAndRetainedValues(scenario: String) async throws {
    let fixture = try ScriptNavigationTradeFixture(alien: false)
    defer { fixture.clean() }
    let runtime = GameRuntime(game: fixture.initial, saveURL: fixture.save)
    try await fixture.dock(runtime)
    let id = try await fixture.acceptAndConfirm(runtime)
    let game = await runtime.snapshot()
    var child = try #require(game.commander.scriptState.instances[id])
    if scenario == "absent" {
      child.savedNavigationTrade = nil
    } else {
      child.savedNavigationTrade?.stage = try #require(
        ScriptNavigationTradeState.Stage(rawValue: scenario))
    }
    #expect(child.hasAwaitingBuyNavigationTrade == (scenario == "awaitingBuy"))
    try assertOwnedProjectionValues(child)
    let retained = child
    child.savedNavigationTrade = nil
    #expect(!child.hasAwaitingBuyNavigationTrade)
    #expect(retained.hasAwaitingBuyNavigationTrade == (scenario == "awaitingBuy"))
  }

  @Test(arguments: ["seed", "workshop", "clinic"])
  func reservationQueriesPreserveNilReservedAndRetainedValues(scenario: String) throws {
    var child: ScriptInstance
    switch scenario {
    case "seed":
      let fixture = try InductionSeedFixture()
      child = fixture.child()
      #expect(child.reservedSeedCargoTonnes == 3)
      #expect(fixture.child(custody: fixture.custody).reservedSeedCargoTonnes == 0)
    case "workshop":
      let fixture = try InductionWorkshopFixture()
      child = fixture.child(.init(booking: fixture.booking))
      #expect(child.reservedWorkshopCargoTonnes == 2)
      #expect(fixture.child(try fixture.picked()).reservedWorkshopCargoTonnes == 0)
    case "clinic":
      child = try InductionClinicAcceptanceFixture().child()
      #expect(child.reservedClinicCargoTonnes == 1)
    default:
      Issue.record(Comment(rawValue: "Unrecognised cargo reservation fixture: " + scenario))
      return
    }
    try assertOwnedProjectionValues(child)
    let retained = child
    child.savedNativeInductionSeed = nil
    child.savedNativeInductionWorkshop = nil
    child.savedNativeInductionClinic = nil
    #expect(child.reservedSeedCargoTonnes == 0)
    #expect(child.reservedWorkshopCargoTonnes == 0)
    #expect(child.reservedClinicCargoTonnes == 0)
    try assertOwnedProjectionValues(retained)
  }

  @Test(arguments: ["empty", "bounds", "invalid", "too-many"])
  func payloadSnapshotPreservesExactValuesAndDetachesLaterMutation(scenario: String) throws {
    var child = ScriptInstance(
      id: UUID(), definition: "projection-component", version: "1", digest: "fixture")
    switch scenario {
    case "empty": child.payloads = [:]
    case "bounds": child.payloads = ["zero": 0, "upper": 1_000_000]
    case "invalid": child.payloads = ["negative": -1, "large": Int.max]
    case "too-many":
      child.payloads = Dictionary(
        uniqueKeysWithValues: (0..<129).map { (String($0), $0) })
    default:
      Issue.record(Comment(rawValue: "Unrecognised payload fixture: " + scenario))
      return
    }
    let expected = child.payloads
    let retained = child
    let payloads = child.retainedCargoPayloads
    #expect(payloads == expected)
    try assertOwnedProjectionValues(child)
    child.payloads["later"] = 1
    #expect(payloads == expected && retained.retainedCargoPayloads == expected)
    #expect(child.retainedCargoPayloads["later"] == 1)
  }

  private func assertOwnedProjectionValues(_ child: ScriptInstance) throws {
    let retained = child
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let bytes = try encoder.encode(child)
    #expect(
      child.hasAwaitingBuyNavigationTrade == (child.savedNavigationTrade?.stage == .awaitingBuy))
    #expect(
      child.reservedSeedCargoTonnes == (child.savedNativeInductionSeed?.reservedCargoTonnes ?? 0))
    #expect(
      child.reservedWorkshopCargoTonnes
        == (child.savedNativeInductionWorkshop?.reservedCargoTonnes ?? 0))
    #expect(
      child.reservedClinicCargoTonnes
        == (child.savedNativeInductionClinic?.reservedCargoTonnes ?? 0))
    #expect(child.retainedCargoPayloads == child.payloads)
    #expect(child == retained)
    #expect(try encoder.encode(child) == bytes)
    let decoded = try JSONDecoder().decode(ScriptInstance.self, from: bytes)
    #expect(decoded == child)
    #expect(decoded.hasAwaitingBuyNavigationTrade == child.hasAwaitingBuyNavigationTrade)
    #expect(decoded.reservedSeedCargoTonnes == child.reservedSeedCargoTonnes)
    #expect(decoded.reservedWorkshopCargoTonnes == child.reservedWorkshopCargoTonnes)
    #expect(decoded.reservedClinicCargoTonnes == child.reservedClinicCargoTonnes)
    #expect(decoded.retainedCargoPayloads == child.retainedCargoPayloads)
  }
}
