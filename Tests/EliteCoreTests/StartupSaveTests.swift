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
    commander.scriptState.calendarLedger = .init(origin: .inactiveLegacyMigration)
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

  @Test func restoredStartupWaitsAtTitleAndContinuesTheSameCommander() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    var commander = Commander()
    commander.name = "RESTORED"
    commander.credits = 12345
    commander.system = 7
    let original = try JSONEncoder().encode(commander)
    try original.write(to: url)
    commander.scriptState.calendarLedger = .init(origin: .inactiveLegacyMigration)
    let runtime = GameRuntime()
    try await runtime.restoreStartup(from: url)
    let restored = await runtime.snapshot()
    #expect(restored.screen == .title && restored.time == 0)
    #expect(restored.commander == commander && restored.docked)
    #expect(try Data(contentsOf: url) == original)
    await runtime.key(" ")
    let continued = await runtime.snapshot()
    #expect(continued.screen == .status && continued.commander == commander)
    try await runtime.load(from: url)
    #expect(await runtime.snapshot().screen == .status)
  }

  @Test func buildIdentityKeepsTheExactRevisionAndRejectsMissingOrMalformedMetadata() {
    let sha = "0123456789abcdef0123456789abcdef01234567"
    let identity = BuildIdentity(info: [
      "CFBundleShortVersionString": "1.2.3", "EliteSourceRevision": sha,
    ])
    #expect(identity.versionLine == "VERSION 1.2.3")
    #expect(identity.revisionLine == sha)
    #expect(identity.legacyRevisionLines.joined() == sha)
    #expect(BuildIdentity(info: [:]).revisionLine == "COMMIT UNAVAILABLE")
    #expect(BuildIdentity(info: ["EliteSourceRevision": "short"]).revision == nil)
    #expect(
      BuildIdentity(info: ["EliteSourceRevision": String(repeating: "z", count: 40)]).revision
        == nil)
  }

  @Test func titleAndScrollingCreditsIncludeBuildIdentityWithinTheStartupDuration() {
    var game = Game()
    game.screen = .title
    let frame = Display.startupScreen(game, width: 512, height: 512)
    let title = frame.labels.map(\.text)
    #expect(title.contains(BuildIdentity.repository))
    #expect(title.contains(BuildIdentity.current.versionLine))
    #expect(title.contains(BuildIdentity.current.revisionLine))
    var seen = Set<String>()
    game.screen = .demo
    for tick in 0..<120 {
      game.time = Double(tick) / 10
      let credits = Display.startupScreen(game, width: 512, height: 512)
      seen.formUnion(credits.labels.map(\.text))
    }
    #expect(seen.contains(BuildIdentity.repository))
    #expect(seen.contains(BuildIdentity.current.versionLine))
    #expect(seen.contains(BuildIdentity.current.revisionLine))
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
