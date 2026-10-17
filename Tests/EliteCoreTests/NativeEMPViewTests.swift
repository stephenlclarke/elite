import AppKit
import Foundation
import Testing

@testable import EliteCore
@testable import EliteMac

extension NativeViewTests {
  @MainActor @Test func nativeEMPKeysDisableEjectAndPublishTheSameSourceAndPeople() async throws {
    _ = NSApplication.shared
    let previousMenu = NSApp.mainMenu
    let identifier = "elite-native-emp-" + UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: identifier))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(identifier)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("commander.json")
    var baseline = try empFixture(hostile: true)
    baseline.selectFlightTool(.combatLaser)
    let profile = try #require(SalvageCatalogue.empProfile(catalogueShipID: "SH023"))
    let cargoSection = try #require(profile.sections.first { $0.kind == .cargo })
    let forward = cargoSection.normal.unit * -1
    let cardinal = abs(forward.y) < 0.8 ? Vector3(0, 1, 0) : .init(1, 0, 0)
    var basis = Basis3()
    basis.z = forward
    basis.x = cardinal.cross(forward).unit
    basis.y = forward.cross(basis.x).unit
    baseline.bodies[0].orientation = basis.transposed
    baseline.bodies[0].position = .init(0, 0, 1000)
    baseline.bodies[0].physical?.velocity = .init(0, 0, 0)
    baseline.bodies[0].physical?.angularVelocity = .init(0, 0, 0)
    let original = baseline.bodies[0]
    let writer = GameRuntime(game: baseline)
    try await writer.save(to: file)
    let delegate = AppDelegate(
      restoreOnLaunch: false,
      saves: CommanderSaveSession(preferences: preferences, defaultURL: file))
    delegate.applicationDidFinishLaunching(
      Notification(name: NSApplication.didFinishLaunchingNotification))
    let window = try #require(delegate.window)
    defer {
      delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification))
      window.orderOut(nil)
      window.delegate = nil
      NSApp.mainMenu = previousMenu
      preferences.removePersistentDomain(forName: identifier)
      try? FileManager.default.removeItem(at: directory)
    }
    let view = try #require(window.contentView as? GameView)
    let loop = try #require(delegate.loop)
    loop.cancel()
    await loop.value
    try await delegate.runtime.load(from: file, persistMigrations: false)
    view.game = await delegate.runtime.snapshot()
    view.pending.removeAll()
    func event(_ code: UInt16, _ text: String, down: Bool) throws -> NSEvent {
      try #require(
        NSEvent.keyEvent(
          with: down ? .keyDown : .keyUp, location: .zero, modifierFlags: [],
          timestamp: 0, windowNumber: window.windowNumber, context: nil,
          characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code))
    }
    for _ in 0..<3 {
      view.keyDown(with: try event(13, "w", down: true))
      view.keyUp(with: try event(13, "w", down: false))
      await delegate.processPendingCommands(in: view)
    }
    try #require(view.game.selectedFlightTool == .empPirateBlaster)
    view.keyDown(with: try event(36, "\r", down: true))
    await delegate.processFrame(in: view, delta: { 0.1 })
    view.keyUp(with: try event(36, "\r", down: false))
    let source = try #require(view.game.commander.savedEMPState?.records.keys.first)
    let disabled = try #require(view.game.bodies.first { $0.physical?.empSource == source })
    #expect(disabled.id == original.id && disabled.energy == original.energy)
    #expect(view.game.targetColourCue(for: disabled) == .hostile)
    #expect(view.game.empTargetStatus(disabled)?.contains("CREW ABOARD") == true)
    for _ in 0..<40 { await delegate.processFrame(in: view, delta: { 0.1 }) }
    let record = try #require(view.game.commander.savedEMPState?.records[source])
    try #require(record.crewAboard == 0 && record.pods.count == record.crewTotal)
    let salvage = try #require(view.game.bodies.first { $0.physical?.empSource == source })
    #expect(salvage.id == original.id && view.game.targetColourCue(for: salvage) == .recoverable)
    let metadata = try #require(salvage.physical?.salvage)
    let context = try #require(view.game.gameplayContext())
    #expect(view.game.salvageCuttingIsAllowed(salvage, metadata: metadata, context: context))
    let people = Set(view.game.bodies.compactMap { $0.physical?.empCrewPod })
    #expect(people.count == record.crewTotal)
    // Use the player's real filter/target commands and controller to reach a cutter hold.
    for (code, text) in [(UInt16(3), "f"), (3, "f"), (15, "r")] {
      view.keyDown(with: try event(code, text, down: true))
      view.keyUp(with: try event(code, text, down: false))
      await delegate.processPendingCommands(in: view)
    }
    for _ in 0..<2400 where view.game.workGuidance?.holding != true {
      await delegate.processFrame(in: view, delta: { 0.1 })
    }
    try #require(view.game.workGuidance?.holding == true)
    try #require(view.game.selectedFlightTool == .salvageCutter)
    view.keyDown(with: try event(36, "\r", down: true))
    let section = WreckSectionIdentity(wreck: record.wreck, section: cargoSection.index)
    for _ in 0..<1200 where !view.game.commander.salvageLedger.isDepleted(section) {
      await delegate.processFrame(in: view, delta: { 0.1 })
    }
    view.keyUp(with: try event(36, "\r", down: false))
    try #require(view.game.commander.salvageLedger.isDepleted(section))
    let food = view.game.commander.salvageLedger.pendingLots.reduce(0) { total, lot in
      guard lot.identity.section.wreck == record.wreck,
        case .commodity(let amount)? = lot.loot?.content, amount.commodity == .food
      else { return total }
      return total + amount.quantity
    }
    #expect(
      food + view.game.commander.cargo[CommodityIdentity.food.rawValue]
        - baseline.commander.cargo[CommodityIdentity.food.rawValue] == 2)
    #expect(view.game.commander.savedEMPState?.records[source]?.pods.count == people.count)
    delegate.queueCommanderFile(.saveActive)
    await delegate.processPendingCommands(in: view)
    let bytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    let (saved, _) = try ScriptSaveStore.read(bytes, from: file)
    #expect(pointer.schemaVersion == 22)
    #expect(saved.savedEMPState?.records[source]?.pods.count == people.count)
    #expect(saved.savedEMPState?.records[source]?.hull.body.id == original.id)
  }
}
