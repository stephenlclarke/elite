import AppKit
import Testing

@testable import EliteCore
@testable import EliteMac

@MainActor
private final class NativeCommanderFileFixture {
  let identifier = UUID().uuidString
  let directory: URL
  let preferences: UserDefaults
  let delegate: AppDelegate
  let view = GameView(frame: NSRect(x: 0, y: 0, width: 768, height: 768))
  let window: NSWindow
  var errors: [any Error] = []

  init() throws {
    _ = NSApplication.shared
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(identifier)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    preferences = try #require(UserDefaults(suiteName: identifier))
    let saves = CommanderSaveSession(
      preferences: preferences, defaultURL: directory.appendingPathComponent("A.json"))
    var failureSink: (@MainActor (any Error) -> Void)?
    delegate = AppDelegate(
      restoreOnLaunch: false, saves: saves, commanderFileFailure: { failureSink?($0) })
    window = NSWindow(contentRect: view.frame, styleMask: [], backing: .buffered, defer: false)
    window.contentView = view
    delegate.window = window
    failureSink = { [weak self] error in self?.errors.append(error) }
  }

  func write(_ name: String, credits: Int) throws -> URL {
    var commander = Commander()
    commander.name = name
    commander.credits = credits
    let url = directory.appendingPathComponent(name + ".json")
    try JSONEncoder().encode(commander).write(to: url)
    return url
  }

  func loadInitial(_ url: URL) async throws -> Game {
    try await delegate.runtime.load(from: url, persistMigrations: false)
    delegate.saves.didSave(to: url)
    let ready = await delegate.runtime.snapshot()
    view.game = ready
    return ready
  }

  func close() {
    window.orderOut(nil)
    window.contentView = nil
    delegate.window = nil
    preferences.removePersistentDomain(forName: identifier)
    try? FileManager.default.removeItem(at: directory)
  }
}

extension NativeViewTests {
  @MainActor @Test func nativeMissionIntentsKeepTheirFIFOPositionAndRefuseAfterAnEarlierLoad()
    async throws
  {
    let fixture = try NativeCommanderFileFixture()
    defer { fixture.close() }
    let a = try fixture.write("A", credits: 1234)
    let b = try fixture.write("B", credits: 5678)
    let before = try await fixture.loadInitial(a)
    let bytesA = try Data(contentsOf: a)
    let bytesB = try Data(contentsOf: b)
    let old = MissionUIIntent(
      action: .library, game: before, presentation: before.scriptPagePresentation)
    fixture.delegate.queueCommanderFile(.open(b))
    fixture.view.pendingMissionUI.append(old)
    fixture.view.pending.append("mission-ui")
    await fixture.delegate.processPendingCommands(in: fixture.view)
    let loaded = await fixture.delegate.runtime.snapshot()
    #expect(loaded.commander.name == "B" && loaded.screen == .status)
    #expect(loaded.inventoryContextEpoch != before.inventoryContextEpoch)
    #expect(fixture.view.pendingMissionUI.isEmpty && fixture.view.pending.isEmpty)

    let fresh = MissionUIIntent(
      action: .library, game: loaded, presentation: loaded.scriptPagePresentation)
    fixture.view.pendingMissionUI.append(fresh)
    fixture.view.pending.append(contentsOf: ["mission-ui", "escape"])
    await fixture.delegate.processPendingCommands(in: fixture.view)
    let closed = await fixture.delegate.runtime.snapshot()
    #expect(closed.screen == .status && closed.commander == loaded.commander)
    #expect(fixture.view.pendingMissionUI.isEmpty && fixture.view.pending.isEmpty)
    #expect(try Data(contentsOf: a) == bytesA)
    #expect(try Data(contentsOf: b) == bytesB)
    #expect(fixture.errors.isEmpty)
  }

  @MainActor @Test func nativeSaveOpenAndSaveActiveFollowOneOrderedTypedStream() async throws {
    let fixture = try NativeCommanderFileFixture()
    defer { fixture.close() }
    let a = try fixture.write("A", credits: 1234)
    let b = try fixture.write("B", credits: 5678)
    let before = try await fixture.loadInitial(a)
    fixture.delegate.queueCommanderFile(.saveActive)
    fixture.delegate.queueCommanderFile(.open(b))
    fixture.delegate.queueCommanderFile(.saveActive)
    #expect(fixture.view.pending == Array(repeating: "commander-file", count: 3))
    #expect(fixture.delegate.saves.activeURL == a)
    await fixture.delegate.processPendingCommands(in: fixture.view)
    let savedA = try JSONDecoder().decode(Commander.self, from: Data(contentsOf: a))
    let savedB = try JSONDecoder().decode(Commander.self, from: Data(contentsOf: b))
    let after = await fixture.delegate.runtime.snapshot()
    #expect(savedA == before.commander && savedA.name == "A" && savedA.credits == 1234)
    #expect(savedB == after.commander && savedB.name == "B" && savedB.credits == 5678)
    #expect(fixture.delegate.saves.activeURL == b && fixture.delegate.saves.startupURL == b)
    #expect(after.inventoryContextEpoch != before.inventoryContextEpoch)
    #expect(fixture.view.pending.isEmpty && fixture.view.pendingCommanderFiles.isEmpty)
    #expect(fixture.errors.isEmpty)
  }

  @MainActor @Test func nativeSaveAsRetainsItsExplicitURLBeforeOpenAndClearsOldHeldInput()
    async throws
  {
    let fixture = try NativeCommanderFileFixture()
    defer { fixture.close() }
    let a = try fixture.write("A", credits: 1234)
    let b = try fixture.write("B", credits: 5678)
    let c = fixture.directory.appendingPathComponent("saved A: copy.json")
    let originalA = try Data(contentsOf: a)
    let originalB = try Data(contentsOf: b)
    let before = try await fixture.loadInitial(a)
    fixture.view.held = ["space", "up"]
    fixture.delegate.queueCommanderFile(.saveAs(c))
    fixture.delegate.queueCommanderFile(.open(b))
    await fixture.delegate.processPendingCommands(in: fixture.view)
    let saved = try JSONDecoder().decode(Commander.self, from: Data(contentsOf: c))
    #expect(saved == before.commander)
    #expect(try Data(contentsOf: a) == originalA)
    #expect(try Data(contentsOf: b) == originalB)
    #expect(fixture.delegate.saves.activeURL == b && fixture.delegate.saves.startupURL == b)
    #expect(fixture.preferences.string(forKey: "lastCommanderSavePath") == c.path)
    #expect(fixture.view.game.commander.name == "B" && fixture.view.held.isEmpty)
    #expect(fixture.errors.isEmpty)
  }

  @MainActor @Test func nativeFailedFileIntentsPreserveCommanderEpochPathsAndOriginalBytes()
    async throws
  {
    let fixture = try NativeCommanderFileFixture()
    defer { fixture.close() }
    let a = try fixture.write("A", credits: 1234)
    let bad = fixture.directory.appendingPathComponent("corrupt.json")
    let invalid = Data("invalid".utf8)
    try invalid.write(to: bad)
    let before = try await fixture.loadInitial(a)
    let originalA = try Data(contentsOf: a)
    fixture.delegate.queueCommanderFile(.saveAs(fixture.directory))
    fixture.delegate.queueCommanderFile(.open(bad))
    await fixture.delegate.processPendingCommands(in: fixture.view)
    let after = await fixture.delegate.runtime.snapshot()
    #expect(after.commander == before.commander && after.bodies == before.bodies)
    #expect(after.inventoryContextEpoch == before.inventoryContextEpoch)
    #expect(fixture.delegate.saves.activeURL == a && fixture.delegate.saves.startupURL == a)
    #expect(try Data(contentsOf: a) == originalA)
    #expect(try Data(contentsOf: bad) == invalid)
    #expect(fixture.errors.count == 2)
    fixture.delegate.queueCommanderFile(.saveActive)
    await fixture.delegate.processPendingCommands(in: fixture.view)
    #expect(try JSONDecoder().decode(Commander.self, from: Data(contentsOf: a)) == before.commander)
    #expect(fixture.errors.count == 2)
  }
}
