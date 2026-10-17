import AppKit
import Foundation
import Testing

@testable import EliteCore
@testable import EliteMac

private func registrationDirectory() -> URL {
  FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
}

@Suite(.serialized)
struct StartupSaveRegistrationTests {
  @MainActor @Test func freshNativeLaunchPublishesAndAcknowledgesItsDefaultDestination()
    async throws
  {
    _ = NSApplication.shared
    let identifier = UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: identifier))
    let directory = registrationDirectory()
    defer {
      preferences.removePersistentDomain(forName: identifier)
      try? FileManager.default.removeItem(at: directory)
    }
    let url = directory.appendingPathComponent("commander.json")
    let saves = CommanderSaveSession(preferences: preferences, defaultURL: url)
    let delegate = AppDelegate(restoreOnLaunch: false, saves: saves)
    let before = await delegate.runtime.snapshot()
    try await delegate.bindNewCommanderSaveIfNeeded(afterFailedRestore: false)
    let registered = await delegate.runtime.snapshot()
    #expect(registered.commander == before.commander && registered.scriptDurabilityAvailable)
    #expect(saves.activeURL == url && saves.startupURL == nil)
    #expect(!FileManager.default.fileExists(atPath: directory.path))
    #expect(preferences.persistentDomain(forName: identifier) == nil)
    // Let the actual introductory sequence reach the title before using the native command batch.
    for _ in 0..<121 { _ = await delegate.runtime.advance(delta: 0.1) }
    let title = await delegate.runtime.snapshot()
    try #require(title.screen == .title)
    let view = GameView(frame: NSRect(x: 0, y: 0, width: 768, height: 768))
    view.pending = [" ", "0"]
    await delegate.processPendingCommands(in: view)
    let flying = await delegate.runtime.snapshot()
    #expect(!flying.docked && flying.commander.nativeStations != nil)
    #expect(flying.requiresScriptDurability && flying.scriptDurabilityAvailable)
    #expect(flying.commander.scriptState.calendarSeconds == 600)
    let bytes = try Data(contentsOf: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == 21 && pointer.scope == "commander")
    let (saved, _) = try ScriptSaveStore.read(bytes, from: url)
    #expect(saved.valid && saved.nativeStations == flying.commander.nativeStations)
    #expect(saved.scriptState == flying.commander.scriptState)
    #expect(saved.equipmentInventory == flying.commander.equipmentInventory)
    #expect(CommanderSaveSession(preferences: preferences, defaultURL: url).startupURL == url)
    #expect(preferences.string(forKey: "lastCommanderSavePath") == url.path)
    #expect(await delegate.runtime.takeNewCommanderSaveReceipt() == nil)
  }

  @MainActor @Test(arguments: [false, true])
  func failedOrMissingSelectedSaveUsesANewDestinationWithoutOverwriting(missing: Bool) async throws
  {
    let identifier = UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: identifier))
    let directory = registrationDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
      preferences.removePersistentDomain(forName: identifier)
      try? FileManager.default.removeItem(at: directory)
    }
    let selected = directory.appendingPathComponent("previous.json")
    let original = Data("invalid previous commander".utf8)
    if !missing { try original.write(to: selected) }
    let defaultURL = directory.appendingPathComponent("commander.json")
    let saves = CommanderSaveSession(preferences: preferences, defaultURL: defaultURL)
    saves.didSave(to: selected)
    let delegate = AppDelegate(restoreOnLaunch: false, saves: saves)
    let initial = await delegate.runtime.snapshot()
    await #expect(throws: (any Error).self) {
      try await delegate.runtime.restoreStartup(from: selected)
    }
    // This is also the safe fallback after Choose Save is cancelled or its load fails.
    try await delegate.bindNewCommanderSaveIfNeeded(afterFailedRestore: true)
    let registered = await delegate.runtime.snapshot()
    #expect(registered.commander == initial.commander)
    #expect(saves.activeURL != selected && saves.activeURL != defaultURL)
    #expect(preferences.string(forKey: "lastCommanderSavePath") == selected.path)
    #expect(!FileManager.default.fileExists(atPath: saves.activeURL.path))
    try await delegate.runtime.save(to: saves.activeURL)
    await delegate.acknowledgeNewCommanderSave()
    #expect(preferences.string(forKey: "lastCommanderSavePath") == saves.activeURL.path)
    #expect(
      CommanderSaveSession(preferences: preferences, defaultURL: defaultURL).startupURL
        == saves.activeURL)
    if missing {
      #expect(!FileManager.default.fileExists(atPath: selected.path))
    } else {
      #expect(try Data(contentsOf: selected) == original)
    }
  }

  @Test func registeredNativeFlightSupportsTheActualRecoveredEquipmentWriter() async throws {
    let directory = registrationDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: try recoveredEquipmentGame("energy-technology"))
    _ = try await runtime.registerNewCommanderDestination(at: url)
    await runtime.key("0")
    await runtime.key("9")
    let before = await runtime.snapshot()
    try #require(!before.docked && before.scriptDurabilityAvailable && before.screen == .inventory)
    let lot = try #require(before.commander.salvageLedger.inventory.first)
    let command = try #require(before.inventoryActionPreview(for: .recovered(lot)).command)
    let result = await runtime.equipmentTransaction(.inventory(command))
    #expect(result.applied)
    let committed = await runtime.snapshot()
    #expect(committed.commander.salvageLedger.inventory.isEmpty)
    #expect(
      committed.commander.fittedComponent(at: .energy)?.receipts.first?.item
        == .salvage(lot.identity))
    #expect(committed.commander.credits == before.commander.credits)
    #expect(
      committed.commander.equipmentPurchaseHistory == before.commander.equipmentPurchaseHistory)
    let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: url), from: url)
    #expect(saved.valid && saved.salvageLedger == committed.commander.salvageLedger)
    #expect(saved.equipmentInventory == committed.commander.equipmentInventory)
  }

  @Test func collisionAtFirstPublicationPreservesTheExistingPointerAndGeneration() async throws {
    let directory = registrationDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("commander.json")
    var game = Game(executive: false)
    game.screen = .status
    let runtime = GameRuntime(game: game)
    _ = try await runtime.registerNewCommanderDestination(at: url)
    // Another valid native save arrives after registration, before this commander's first write.
    var other = Game(executive: false)
    other.screen = .status
    other.commander.name = "EXISTING"
    let otherRuntime = GameRuntime(game: other, saveURL: url)
    await otherRuntime.key("0")
    let bytes = try Data(contentsOf: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: url)
    let chunks = try pointer.hashes.keys.reduce(into: [String: Data]()) {
      $0[$1] = try Data(contentsOf: generation.appendingPathComponent($1))
    }
    let before = await runtime.snapshot()
    await runtime.key("0")
    let refused = await runtime.snapshot()
    #expect(refused.commander == before.commander && refused.docked == before.docked)
    #expect(refused.pendingNewSaveDestination == url)
    #expect(await runtime.takeNewCommanderSaveReceipt() == nil)
    #expect(try Data(contentsOf: url) == bytes)
    for (name, data) in chunks {
      #expect(try Data(contentsOf: generation.appendingPathComponent(name)) == data)
    }
    let entries = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil)
    #expect(!entries.contains { $0.lastPathComponent.hasSuffix(".pending") })
    let alternative = directory.appendingPathComponent("safe-new.json")
    try await runtime.save(to: alternative)
    #expect(try Data(contentsOf: url) == bytes)
    #expect(await runtime.takeNewCommanderSaveReceipt() == nil)
  }

  @Test func failedFirstWriteHasNoReceiptAndPreservesTheRegisteredCommander() async throws {
    let directory = registrationDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let blocker = directory.appendingPathComponent("parent")
    let url = blocker.appendingPathComponent("commander.json")
    var game = Game(executive: false)
    game.screen = .status
    let runtime = GameRuntime(game: game)
    _ = try await runtime.registerNewCommanderDestination(at: url)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let original = Data("blocks the writer".utf8)
    try original.write(to: blocker)
    let before = await runtime.snapshot()
    await runtime.key("0")
    let refused = await runtime.snapshot()
    #expect(refused.commander == before.commander && refused.docked)
    #expect(refused.pendingNewSaveDestination == url)
    #expect(await runtime.takeNewCommanderSaveReceipt() == nil)
    #expect(try Data(contentsOf: blocker) == original)
  }

  @Test(arguments: [false, true])
  func successfulOpenOrSaveAsCannotAcknowledgeAnOlderDestination(open: Bool) async throws {
    let directory = registrationDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let a = directory.appendingPathComponent("A.json")
    let b = directory.appendingPathComponent("B.json")
    let runtime = GameRuntime(game: Game(executive: false))
    _ = try await runtime.registerNewCommanderDestination(at: a)
    try await runtime.save(to: a)
    let original = try Data(contentsOf: a)
    if open {
      try JSONEncoder().encode(Commander()).write(to: b)
      try await runtime.load(from: b, persistMigrations: false)
    } else {
      try await runtime.save(to: b)
    }
    #expect(await runtime.takeNewCommanderSaveReceipt() == nil)
    #expect(try Data(contentsOf: a) == original)
    #expect(await runtime.hasCommanderSaveDestination())
  }

  @Test func registrationRejectsExistingFilesDanglingLinksAndTrialWriters() async throws {
    let directory = registrationDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("existing.json")
    let link = directory.appendingPathComponent("dangling.json")
    let bytes = Data("existing".utf8)
    try bytes.write(to: file)
    try FileManager.default.createSymbolicLink(
      at: link, withDestinationURL: directory.appendingPathComponent("missing.json"))
    let runtime = GameRuntime(game: Game(executive: false))
    for url in [file, link] {
      await #expect(throws: (any Error).self) {
        _ = try await runtime.registerNewCommanderDestination(at: url)
      }
    }
    #expect(!(await runtime.hasCommanderSaveDestination()))
    #expect(try Data(contentsOf: file) == bytes)
    var trial = Game(executive: false)
    trial.isMissionTrial = true
    let trialRuntime = GameRuntime(game: trial)
    await #expect(throws: (any Error).self) {
      _ = try await trialRuntime.registerNewCommanderDestination(
        at: directory.appendingPathComponent("trial.json"))
    }
    #expect(await trialRuntime.takeNewCommanderSaveReceipt() == nil)
  }
}
