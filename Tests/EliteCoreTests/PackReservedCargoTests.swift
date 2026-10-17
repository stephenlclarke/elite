import Foundation
import Testing

@testable import EliteCore

/// A valid external pack requests ordinary cargo, without a bundled legacy binding.
enum PackReservedCargoTestFixture {
  static func removalPack(index: Int) throws -> LoadedMissionPack {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/courier.toml")
    let original = try String(contentsOf: url, encoding: .utf8)
    let text = original.replacingOccurrences(
      of: "{ kind = \"payloadRemove\", key = \"parcel\", amount = 1 }",
      with: "{ kind = \"cargoRemove\", key = \"\(index)\", amount = 1 }")
    #expect(text != original)
    let entry = try MissionPackLibrary.decode(Data(text.utf8))
    #expect(entry.pack.mission.binding == nil)
    return entry
  }

  static func refuseExternalRemoval(_ original: Game, index: Int) throws -> Game {
    let entry = try removalPack(index: index)
    var game = original
    game.missionPacks = try .checked([entry])
    game.commander.galaxy = 0
    game.systems = Universe.galaxy(number: 0)
    game.selectedSystem = 7
    game.arrive()
    game.dock()
    game.key("b")
    game.key("return")
    try #require(game.commander.missionProgress[entry.pack.stateID]?.stage == "carrying")
    game.selectedSystem = 129
    game.arrive()
    game.dock()
    try #require(game.screen == .handoff && game.offeredPack?.digest == entry.digest)
    try #require(game.commander.valid)
    let before = game.commander
    let market = game.market
    game.key("return")
    #expect(game.message == "MARKED MISSION CARGO REQUIRED.")
    #expect(game.screen == .handoff && game.commander == before && game.market == market)
    return game
  }
}

struct PackReservedCargoTests {
  @Test func externalPackCannotRemoveActuallyCapturedNativePeopleOrPayForThem() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await NativePeopleTestFixture.capturedRuntime(storage: storage)
    let original = await runtime.snapshot()
    try #require(original.commander.valid && original.commander.nativeCaptiveCount == 2)
    let refused = try PackReservedCargoTestFixture.refuseExternalRemoval(original, index: 3)
    #expect(refused.commander.nativePeople == original.commander.nativePeople)
    #expect(refused.commander.nativeCaptiveCount == 2 && refused.commander.cargo[3] == 2)
  }
}
