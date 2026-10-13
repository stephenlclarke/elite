import AppKit
import Foundation
import Testing

@testable import EliteCore
@testable import EliteMac

@Suite(.serialized)
struct StartupSaveTests {
  @MainActor @Test func lastSuccessfulSaveLocationAndFirstLaunchAreDeterministic() throws {
    let suite = "elite-test-" + UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: suite))
    defer { preferences.removePersistentDomain(forName: suite) }
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let standard = folder.appendingPathComponent("commander.json")
    let saves = CommanderSaveSession(preferences: preferences, defaultURL: standard)
    #expect(saves.startupURL == nil)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try JSONEncoder().encode(Commander()).write(to: standard)
    #expect(saves.startupURL == standard)
    let alternate = folder.appendingPathComponent("alternative.json")
    saves.didSave(to: alternate)
    #expect(saves.activeURL == alternate && saves.startupURL == alternate)
    let restarted = CommanderSaveSession(preferences: preferences, defaultURL: standard)
    #expect(restarted.startupURL == alternate)
    restarted.activeURL = standard  // Open does not pretend that an older file is the latest save.
    let again = CommanderSaveSession(preferences: preferences, defaultURL: standard)
    #expect(again.startupURL == alternate)
  }

  @Test func startupRestoreMigratesInMemoryWithoutOverwritingAndFailuresPreserveGame() async throws
  {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    var commander = Commander()
    commander.shipID = "SH013"
    commander.credits = 100000
    commander.legal = 75
    let original = try JSONEncoder().encode(commander)
    try original.write(to: url)
    let runtime = GameRuntime()
    try await runtime.load(from: url, persistMigrations: false)
    let restored = await runtime.snapshot()
    #expect(restored.commander == commander && restored.docked && restored.screen == .status)
    #expect(restored.energy == commander.performance.energy)
    #expect(try Data(contentsOf: url) == original)
    try Data("corrupt".utf8).write(to: url)
    await #expect(throws: (any Error).self) {
      try await runtime.load(from: url, persistMigrations: false)
    }
    #expect(await runtime.snapshot().commander == commander)
    try FileManager.default.removeItem(at: url)
    await #expect(throws: (any Error).self) {
      try await runtime.load(from: url, persistMigrations: false)
    }
    #expect(await runtime.snapshot().commander == commander)
  }

  @Test func xyzzyLegalResetPersistsWithoutChangingMissionOrOtherCommanderState() async throws {
    var game = Game(executive: false)
    game.screen = .secret
    game.commander.legal = 99
    game.commander.xyzzyActive = true
    let old = game.commander
    game.key("l")
    var expected = old
    expected.legal = 0
    expected.xyzzyWantedAmnesty = false
    #expect(game.commander == expected && game.message == "LEGAL STATUS RESET TO CLEAN")
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: url)
    try await runtime.load(from: url, persistMigrations: false)
    #expect(await runtime.snapshot().commander.legal == 0)
    game.commander.legal = 100
    game.viewportHeight = 518
    for _ in 0..<100 { game.key("down") }
    let row = try #require(game.secretRows.firstIndex { $0.0 == "l" })
    let layout = CompactLayout(game: game, width: game.viewportWidth, height: game.viewportHeight)
    game.secretScroll = max(0, row - game.secretWindow.visible + 1)
    game.secretClick(
      x: layout.left + 4, y: 76 + Double(row - game.secretWindow.offset) * layout.row + 4)
    #expect(game.commander.legal == 0)
  }
}
