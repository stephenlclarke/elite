import Foundation
import Testing

@testable import EliteCore

@Test func courierXorshiftUsesWrappingOrderAndZeroNormalization() {
  var state: UInt32 = 1
  #expect(ScriptCourierGeneration.next(&state) == 270369)
  #expect(ScriptCourierGeneration.next(&state) == 67_634_689)
  #expect(ScriptCourierGeneration.next(&state) == 2_647_435_461)
  var zero: UInt32 = 0
  var normalized: UInt32 = 0x6D2B_79F5
  #expect(ScriptCourierGeneration.next(&zero) == ScriptCourierGeneration.next(&normalized))
  #expect(zero != 0)
}

@Test func courierGenerationProofRejectsDrawRouteAndNativeReachSubstitution() throws {
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let (key, _) = try fixture.offer(&game)
  let original = try #require(game.commander.contracts.boards[key]?.courierGeneration)
  #expect(original.valid)
  var object = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
  object["draws"] = [UInt32](repeating: 1, count: 6)
  let substituted = try JSONDecoder().decode(
    ScriptCourierGeneration.self, from: JSONSerialization.data(withJSONObject: object))
  #expect(!substituted.valid)
  game.commander.fuel = 0
  #expect(throws: MissionPackError.self) {
    try ScriptCourierGeneration(origin: game.contractStation, commander: game.commander, seed: 0)
  }
  #expect(game.commander.contracts.boards[key]?.courierGeneration == original)
}
