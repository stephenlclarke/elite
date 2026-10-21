import Foundation
import Testing

@testable import EliteCore

/// A valid external pack requests ordinary cargo, without a bundled legacy binding.
enum PackReservedCargoTestFixture {
  static func removalPack(index: Int, galaxy: Int, system: Int) throws -> LoadedMissionPack {
    let text = """
      schemaVersion = 1
      id = "xyzzy.test.protected-removal"
      version = "1.0.0"
      minimumEngine = "1.0.0"
      capabilities = ["state-machine-v1", "dialog-v1", "economy-v1", "cargo-v1"]
      priority = 500
      source = "Original project ownership regression fixture."
      license = "MIT"
      [mission]
      id = "removal"
      title = "Ordinary cargo transfer"
      initialStage = "available"
      briefing = "Confirm an ordinary commodity transfer."
      destination = "The current main station."
      reward = "50 CR only after transfer."
      prerequisites = []
      milestones = ["Transfer the commodity"]
      [[stages]]
      id = "available"
      objective = "Confirm the transfer."
      completed = 0
      [[stages]]
      id = "complete"
      objective = "Transfer complete."
      completed = 1
      terminal = true
      [[dialogs]]
      id = "transfer"
      text = "Confirm the ordinary cargo transfer for 50 CR?"
      [[transitions]]
      id = "remove"
      from = "available"
      event = "contact"
      to = "complete"
      confirmation = true
      dialog = "transfer"
      conditions = [{ field = "galaxy", op = "eq", value = \(galaxy) }, { field = "system", op = "eq", value = \(system) }, { field = "mainStation", op = "eq", value = 1 }]
      actions = [{ kind = "cargoRemove", key = "\(index)", amount = 1 }, { kind = "credits", amount = 500 }]
      """
    let entry = try MissionPackLibrary.decode(Data(text.utf8))
    #expect(entry.pack.mission.binding == nil)
    return entry
  }

  static func refuseExternalRemoval(_ original: Game, index: Int) throws -> Game {
    var game = original
    if game.screen == .handoff { game.key("escape") }
    try #require(game.docked && game.dockedAtMainStation && game.commander.valid)
    let entry = try removalPack(
      index: index, galaxy: game.commander.galaxy, system: game.commander.system)
    game.missionPacks = try .checked([entry])
    game.key("8")
    game.key("b")
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
