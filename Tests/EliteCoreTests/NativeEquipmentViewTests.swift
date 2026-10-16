import AppKit
import Testing

@testable import EliteCore
@testable import EliteMac

private func nativeEquipmentCommander(heldGrants: Int = 0) throws -> Commander {
  var game = Game(executive: false)
  game.screen = .equipment
  game.commander.shipID = "SH023"
  game.commander.credits = 1_000_000
  game.commander.system = try #require(game.systems.first { $0.technology >= 10 }?.id)
  try game.commander.prepareEquipment(legacy: false)
  let basic = try #require(Equipment.all.first { $0.name == TargetingTier.basic.equipmentName })
  let quote = try game.quoteEquipmentPurchase(basic)
  let fitted = try game.applyEquipmentPurchase(quote)
  #expect(fitted && game.commander.equipmentPurchaseHistory?.paid.count == 1)
  var inventory = try #require(game.commander.equipmentInventory)
  let node = try #require(EquipmentRuntimeCatalog.node(for: "Fuel Scoops"))
  let context = EquipmentRuntimeCatalog.context(
    owner: inventory.owner, hull: inventory.activeHull, performance: game.commander.performance)
  for index in 0..<heldGrants {
    let item = OwnedEquipmentItem(
      id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1000))!,
      node: node, provenance: .grant("native display fixture"))
    try inventory.admit(item, expectedRevision: inventory.revision, context: context)
  }
  game.commander.savedEquipmentInventory = inventory
  try game.commander.validateEquipmentState()
  #expect(game.commander.valid)
  return game.commander
}

private func nativeEquipmentBytes(_ commander: Commander) throws -> Data {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys]
  return try encoder.encode(commander)
}

@MainActor
private struct NativeEquipmentFixture {
  let delegate: AppDelegate
  let view: GameView
  let window: NSWindow
  let preferences: UserDefaults
  let identifier: String
  let directory: URL
  let save: URL
  let originalSave: Data
  let originalMenu: NSMenu?

  static func open(commander: Commander, width: Int, height: Int) async throws -> Self {
    _ = NSApplication.shared
    let originalMenu = NSApp.mainMenu
    let identifier = "elite-native-equipment-" + UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: identifier))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      identifier, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let save = directory.appendingPathComponent("commander.json")
    let originalSave = try nativeEquipmentBytes(commander)
    try originalSave.write(to: save, options: .atomic)
    let saves = CommanderSaveSession(preferences: preferences, defaultURL: save)
    let delegate = AppDelegate(
      restoreOnLaunch: false, saves: saves,
      windowSize: NSSize(width: Double(width), height: Double(height)))
    do {
      delegate.applicationDidFinishLaunching(
        Notification(name: NSApplication.didFinishLaunchingNotification))
      let window = try #require(delegate.window)
      let view = try #require(window.contentView as? GameView)
      let loop = try #require(delegate.loop)
      loop.cancel()
      await loop.value
      // Load only after the automatic consumer has stopped; input below uses its real batch route.
      try await delegate.runtime.load(from: save, persistMigrations: false)
      window.setContentSize(NSSize(width: Double(width), height: Double(height)))
      await delegate.runtime.setViewport(width: view.bounds.width, height: view.bounds.height)
      view.game = await delegate.runtime.snapshot()
      view.pending.removeAll()
      let fixture = Self(
        delegate: delegate, view: view, window: window, preferences: preferences,
        identifier: identifier, directory: directory, save: save, originalSave: originalSave,
        originalMenu: originalMenu)
      try await fixture.press(20, text: "3", expected: "3")
      #expect(view.game.screen == .equipment && view.isFlipped)
      #expect(view.bounds.width == Double(width) && view.bounds.height == Double(height))
      return fixture
    } catch {
      delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification))
      delegate.window?.orderOut(nil)
      NSApp.mainMenu = originalMenu
      preferences.removePersistentDomain(forName: identifier)
      try? FileManager.default.removeItem(at: directory)
      throw error
    }
  }

  func close() {
    delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification))
    window.orderOut(nil)
    window.delegate = nil
    NSApp.mainMenu = originalMenu
    preferences.removePersistentDomain(forName: identifier)
    try? FileManager.default.removeItem(at: directory)
  }

  func press(
    _ code: UInt16, text: String = "", flags: NSEvent.ModifierFlags = [], expected: String
  ) async throws {
    func event(_ type: NSEvent.EventType) throws -> NSEvent {
      try #require(
        NSEvent.keyEvent(
          with: type, location: .zero, modifierFlags: flags, timestamp: 0,
          windowNumber: window.windowNumber, context: nil, characters: text,
          charactersIgnoringModifiers: text, isARepeat: false, keyCode: code))
    }
    view.keyDown(with: try event(.keyDown))
    #expect(view.pending.last == expected)
    view.keyUp(with: try event(.keyUp))
    await delegate.processPendingCommands(in: view)
    #expect(view.pending.isEmpty && view.held.isEmpty)
    #expect(!view.controls.fire && view.controls.pitch == 0 && view.controls.roll == 0)
    #expect(view.controls.yaw == 0 && view.controls.throttle == 0)
  }

  func click(_ bounds: CanvasRect) async throws {
    let local = NSPoint(x: bounds.x + bounds.width / 2, y: bounds.y + bounds.height / 2)
    let event = try #require(
      NSEvent.mouseEvent(
        with: .leftMouseDown, location: view.convert(local, to: nil), modifierFlags: [],
        timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 1,
        clickCount: 1, pressure: 1))
    view.mouseDown(with: event)
    #expect(view.pending.last?.hasPrefix("equipment-click:") == true)
    #expect(!view.pending.contains("return"))
    await delegate.processPendingCommands(in: view)
    #expect(view.pending.isEmpty && !view.controls.fire)
  }

  func selectItem(named name: String) async throws {
    let target = try #require(Equipment.all.firstIndex { $0.name == name })
    let order = EquipmentGroups.itemIndices
    let targetPosition = try #require(order.firstIndex(of: target))
    for _ in 0..<order.count {
      if view.game.selection == target { return }
      let current = try #require(order.firstIndex(of: view.game.selection))
      let down = current < targetPosition
      try await press(down ? 125 : 126, expected: down ? "down" : "up")
    }
    #expect(view.game.selection == target)
  }

  func verifyUnchanged(_ commander: Data) throws {
    #expect(try nativeEquipmentBytes(view.game.commander) == commander)
    #expect(try Data(contentsOf: save) == originalSave)
    #expect(delegate.saves.activeURL == save)
  }

  func capture(_ name: String, scale: Int) throws -> CGImage {
    let width = Int(view.bounds.width)
    let height = Int(view.bounds.height)
    let context = try #require(
      CGContext(
        data: nil, width: width * scale, height: height * scale, bitsPerComponent: 8,
        bytesPerRow: width * scale * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.translateBy(x: 0, y: Double(height * scale))
    context.scaleBy(x: Double(scale), y: Double(-scale))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    view.draw(view.bounds)
    NSGraphicsContext.restoreGraphicsState()
    let image = try #require(context.makeImage())
    #expect(image.width == width * scale && image.height == height * scale)
    let exported = try #require(imageForGame(view.game, width: width, height: height, scale: scale))
    let drawnBytes = try #require(image.dataProvider?.data)
    let exportedBytes = try #require(exported.dataProvider?.data)
    // Same drawing path and pixel format: this catches a blank or stale native view.
    #expect(CFEqual(drawnBytes, exportedBytes))
    if let evidence = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"] {
      let output = URL(fileURLWithPath: evidence, isDirectory: true)
      try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
      let data = try #require(
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
      try data.write(to: output.appendingPathComponent("equipment-\(name)-\(width)-\(scale)x.png"))
    }
    return image
  }
}

// Inherit the existing suite's serialization; AppKit still has one application/event loop.
extension NativeViewTests {
  @MainActor @Test func nativeEquipmentKeysAndWindowPointersSelectWithoutPurchasing() async throws {
    let commander = try nativeEquipmentCommander()
    for (width, height) in [(512, 518), (1512, 982)] {
      let fixture = try await NativeEquipmentFixture.open(
        commander: commander, width: width, height: height)
      defer { fixture.close() }
      let before = try nativeEquipmentBytes(fixture.view.game.commander)
      let layout = EquipmentLayout(
        game: fixture.view.game, width: Double(width), height: Double(height))
      for cell in layout.mounts {
        try await fixture.click(cell.bounds)
        #expect(
          fixture.view.game.equipmentMount == cell.mount && !fixture.view.game.equipmentWorkTool)
        try fixture.verifyUnchanged(before)
      }
      let tool = try #require(layout.workToolBounds)
      try await fixture.click(tool)
      #expect(fixture.view.game.equipmentWorkTool)
      try await fixture.press(124, expected: "right")
      #expect(!fixture.view.game.equipmentWorkTool && fixture.view.game.equipmentMount == .front)
      for mount in [LaserMount.left, .right, .rear] {
        try await fixture.press(124, expected: "right")
        #expect(!fixture.view.game.equipmentWorkTool && fixture.view.game.equipmentMount == mount)
      }
      try await fixture.press(124, expected: "right")
      #expect(fixture.view.game.equipmentWorkTool)
      for mount in [LaserMount.rear, .right, .left, .front] {
        try await fixture.press(123, expected: "left")
        #expect(!fixture.view.game.equipmentWorkTool && fixture.view.game.equipmentMount == mount)
      }
      try await fixture.press(123, expected: "left")
      #expect(fixture.view.game.equipmentWorkTool)
      try fixture.verifyUnchanged(before)
    }
  }

  @MainActor @Test func nativeEquipmentReturnRefusesAndInventoryPagesPreserveAcquisitionFacts()
    async throws
  {
    let commander = try nativeEquipmentCommander(heldGrants: 24)
    for (width, height) in [(512, 518), (1512, 982)] {
      let fixture = try await NativeEquipmentFixture.open(
        commander: commander, width: width, height: height)
      defer { fixture.close() }
      let before = try nativeEquipmentBytes(fixture.view.game.commander)
      let layout = EquipmentLayout(
        game: fixture.view.game, width: Double(width), height: Double(height))
      try await fixture.click(try #require(layout.workToolBounds))
      try await fixture.selectItem(named: LaserKind.beam.equipmentName)
      var frame = Display.equipmentScreen(
        fixture.view.game, width: Double(width), height: Double(height))
      var text = frame.labels.map(\.text).joined(separator: " ")
      #expect(text.contains("Cannot fit selected destination") && !text.contains("Return: buy"))
      try await fixture.press(36, text: "\r", expected: "return")
      #expect(fixture.view.game.message == "NO COMPATIBLE FREE FITTING")
      try fixture.verifyUnchanged(before)
      try await fixture.click(try #require(layout.mounts.first).bounds)
      try await fixture.selectItem(named: TargetingTier.basic.equipmentName)
      frame = Display.equipmentScreen(
        fixture.view.game, width: Double(width), height: Double(height))
      text = frame.labels.map(\.text).joined(separator: " ")
      #expect(text.contains("Already owned") && !text.contains("Return: buy"))
      #expect(frame.labels.contains { $0.text == "FITTED" })
      try await fixture.press(36, text: "\r", expected: "return")
      #expect(fixture.view.game.message == "ALREADY OWNED")
      try fixture.verifyUnchanged(before)
      try await fixture.press(25, text: "9", expected: "9")
      #expect(fixture.view.game.screen == .inventory)
      let rows = fixture.view.game.informationRows.map { $0.0 }
      #expect(rows.contains("Recorded purchases: 1"))
      #expect(rows.filter { $0 == "  Held - Granted" }.count == 24)
      #expect(rows.contains("  Fitted targeting core - Purchased"))
      #expect(!rows.contains("  Held - Purchased"))
      var seen = Set<String>()
      let window = fixture.view.game.informationWindow
      #expect(window.last > 0)
      for _ in 0...rows.count {
        let visible = Display.information(
          fixture.view.game, width: Double(width), height: Double(height))
        seen.formUnion(visible.labels.map(\.text))
        if fixture.view.game.informationWindow.offset == fixture.view.game.informationWindow.last {
          break
        }
        try await fixture.press(125, flags: .option, expected: "pagedown")
      }
      #expect(
        fixture.view.game.informationWindow.offset == fixture.view.game.informationWindow.last)
      #expect(
        seen.contains("  Held - Granted") && seen.contains("  Fitted targeting core - Purchased"))
      #expect(seen.contains("Basic Shield") && seen.contains("Recorded purchases: 1"))
      try await fixture.press(126, flags: .option, expected: "pageup")
      #expect(fixture.view.game.informationWindow.offset < fixture.view.game.informationWindow.last)
      try fixture.verifyUnchanged(before)
    }
  }

  @MainActor @Test func nativeEquipmentDrawsCompactAndDoubleScaleFramesWithFixedTypography()
    async throws
  {
    let commander = try nativeEquipmentCommander(heldGrants: 1)
    for (width, height, scale) in [(512, 518, 1), (1512, 982, 2)] {
      let fixture = try await NativeEquipmentFixture.open(
        commander: commander, width: width, height: height)
      defer { fixture.close() }
      let before = try nativeEquipmentBytes(fixture.view.game.commander)
      for name in [
        LaserKind.beam.equipmentName, TargetingTier.basic.equipmentName, Equipment.all.last!.name,
      ] {
        try await fixture.selectItem(named: name)
        let game = fixture.view.game
        let frame = Display.equipmentScreen(game, width: Double(width), height: Double(height))
        let layout = EquipmentLayout(game: game, width: Double(width), height: Double(height))
        #expect(frame.labels.allSatisfy { $0.scale == GameTypography.scale })
        let selected = try #require(frame.labels.first { $0.text == ">" })
        #expect(selected.y >= layout.listTop)
        #expect(
          selected.bounds.maxY <= CockpitLayout(
            game: game, width: Double(width), height: Double(height)
          ).dashboardTop - 82)
        for price in frame.labels.filter({ $0.text.hasSuffix(" CR") }) {
          #expect(abs(price.bounds.maxX - layout.left - layout.contentWidth) < 0.0001)
        }
        #expect(
          frame.labels.allSatisfy {
            $0.bounds.x >= 0 && $0.bounds.maxX <= Double(width) && $0.bounds.maxY <= Double(height)
          })
        let image = try fixture.capture("row-\(game.selection)", scale: scale)
        #expect(image.dataProvider?.data != nil)
      }
      let layout = EquipmentLayout(
        game: fixture.view.game, width: Double(width), height: Double(height))
      try await fixture.click(try #require(layout.workToolBounds))
      try await fixture.selectItem(named: LaserKind.beam.equipmentName)
      _ = try fixture.capture("work-refusal", scale: scale)
      try await fixture.press(25, text: "9", expected: "9")
      _ = try fixture.capture("inventory", scale: scale)
      try fixture.verifyUnchanged(before)
    }
  }
}
