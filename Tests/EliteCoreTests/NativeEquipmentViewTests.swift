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
  let originalFiles: [String: Data]
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
    var openedDelegate: AppDelegate?
    do {
      // Match the initial docked scene formerly supplied by legacy load, retaining all current property.
      try #require(commander.valid && commander.savedEquipmentVersion == 3)
      var bootstrap = Game(executive: false)
      bootstrap.commander = commander
      bootstrap.screen = .status
      bootstrap.systems = Universe.systemsIncludingPlugh(number: commander.galaxy)
      bootstrap.selectedSystem = commander.system
      bootstrap.market = MarketItem.at(bootstrap.currentSystem, fluctuation: 0)
      bootstrap.docked = true
      bootstrap.dockedAtMainStation = true
      bootstrap.energy = commander.performance.energy
      bootstrap.frontShield = commander.shieldCapacity
      bootstrap.rearShield = commander.rearShieldCapacity
      var expected = commander
      try expected.prepareEquipment()
      expected.mirrorFittedEquipment()
      expected.miningLedger = commander.miningLedger
      if expected.scriptState.calendarLedger == nil {
        expected.scriptState.calendarLedger = .init(origin: .newCommander)
      }
      let writer = GameRuntime(game: bootstrap)
      try await writer.save(to: save)
      let published = await writer.snapshot()
      #expect(published.commander == expected)
      #expect(published.commander.equipmentOwnerID == commander.equipmentOwnerID)
      #expect(published.commander.hullInstanceID == commander.hullInstanceID)
      #expect(published.commander.equipmentInventory == commander.equipmentInventory)
      #expect(published.commander.equipmentPurchaseHistory == commander.equipmentPurchaseHistory)
      #expect(published.commander.salvageLedger == commander.salvageLedger)
      #expect(
        published.commander.credits == commander.credits
          && published.commander.cargo == commander.cargo)
      #expect(
        published.commander.name == commander.name && published.commander.shipID == commander.shipID
      )
      #expect(
        published.commander.fuel == commander.fuel
          && published.commander.missiles == commander.missiles)
      #expect(published.commander.contracts == commander.contracts)
      #expect(published.commander.accommodation == commander.accommodation)
      #expect(published.commander.missionProgress == commander.missionProgress)
      #expect(
        published.commander.missionStage == commander.missionStage
          && published.commander.blackjack == commander.blackjack)
      #expect(published.commander.scriptState == expected.scriptState)
      let originalSave = try Data(contentsOf: save)
      let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: originalSave)
      try #require(pointer.schemaVersion == 26 && pointer.scope == "commander")
      let (stored, world) = try ScriptSaveStore.read(originalSave, from: save)
      #expect(stored == expected && world.valid && world.consistent(with: stored))
      let originalFiles = try recoveredSaveFiles(directory)
      let saves = CommanderSaveSession(preferences: preferences, defaultURL: save)
      let delegate = AppDelegate(
        restoreOnLaunch: false, saves: saves,
        windowSize: NSSize(width: Double(width), height: Double(height)))
      openedDelegate = delegate
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
      #expect(view.game.commander == expected)
      #expect(view.game.docked && view.game.dockedAtMainStation && view.game.bodies.isEmpty)
      #expect(view.game.selectedSystem == commander.system && view.game.market == bootstrap.market)
      #expect(view.game.energy == bootstrap.energy)
      #expect(
        view.game.frontShield == bootstrap.frontShield
          && view.game.rearShield == bootstrap.rearShield)
      let loadedFiles = try recoveredSaveFiles(directory)
      #expect(loadedFiles == originalFiles)
      view.pending.removeAll()
      let fixture = Self(
        delegate: delegate, view: view, window: window, preferences: preferences,
        identifier: identifier, directory: directory, save: save, originalSave: originalSave,
        originalFiles: originalFiles, originalMenu: originalMenu)
      try await fixture.press(20, text: "3", expected: "3")
      #expect(view.game.screen == .equipment && view.isFlipped)
      #expect(view.bounds.width == Double(width) && view.bounds.height == Double(height))
      let paintedFiles = try recoveredSaveFiles(directory)
      #expect(paintedFiles == originalFiles)
      return fixture
    } catch {
      openedDelegate?.windowWillClose(Notification(name: NSWindow.willCloseNotification))
      openedDelegate?.window?.orderOut(nil)
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
    let equipmentReturn = code == 36 && view.game.screen == .equipment
    let protectedKey =
      ScriptPagePresentation.controlKeys.contains(expected)
      || ScriptPagePresentation.galleryContextKeys.contains(expected)
      || ScriptPagePresentation.contractContextKeys.contains(expected)
    if equipmentReturn || protectedKey { _ = try capture("before-" + expected, scale: 1) }
    let painted = view.paintedMissionMenuPresentation
    view.keyDown(with: try event(.keyDown))
    if equipmentReturn {
      #expect(view.pending.last == "equipment-purchase")
      #expect(view.pendingEquipmentPurchases.count == 1)
    } else if protectedKey {
      try verifyPageKey(expected, painted: #require(painted))
    } else {
      #expect(view.pending.last == expected)
    }
    view.keyUp(with: try event(.keyUp))
    await delegate.processPendingCommands(in: view)
    #expect(view.pending.isEmpty && view.held.isEmpty)
    #expect(!view.controls.fire && view.controls.pitch == 0 && view.controls.roll == 0)
    #expect(view.controls.yaw == 0 && view.controls.throttle == 0)
  }

  func verifyPageKey(_ key: String, painted: ScriptPagePresentation) throws {
    let packet = try #require(view.pending.last)
    try #require(packet.hasPrefix("script-page-key:"))
    let parts = packet.dropFirst("script-page-key:".count).split(separator: ":", maxSplits: 1)
    try #require(parts.count == 2)
    let bytes = try #require(Data(base64Encoded: String(parts[0])))
    let proof = try JSONDecoder().decode(ScriptPagePresentation.self, from: bytes)
    #expect(proof == painted && String(parts[1]) == key)
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
    let liveBytes = try nativeEquipmentBytes(view.game.commander)
    let savedBytes = try Data(contentsOf: save)
    let savedFiles = try recoveredSaveFiles(directory)
    #expect(liveBytes == commander)
    #expect(savedBytes == originalSave && savedFiles == originalFiles)
    #expect(delegate.saves.activeURL == save)
  }

  func capture(_ name: String, scale: Int) throws -> CGImage {
    let actualStarted = ProcessInfo.processInfo.systemUptime
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
    let actualSeconds = ProcessInfo.processInfo.systemUptime - actualStarted
    #expect(image.width == width * scale && image.height == height * scale)
    let oracleStarted = ProcessInfo.processInfo.systemUptime
    let exported = try #require(imageForGame(view.game, width: width, height: height, scale: scale))
    let oracleSeconds = ProcessInfo.processInfo.systemUptime - oracleStarted
    let drawnBytes = try #require(image.dataProvider?.data)
    let exportedBytes = try #require(exported.dataProvider?.data)
    // Same drawing path and pixel format: this catches a blank or stale native view.
    let identical = CFEqual(drawnBytes, exportedBytes)
    #expect(identical)
    try #require(actualSeconds > 0 && oracleSeconds > 0)
    let ratio = actualSeconds / oracleSeconds
    if let evidence = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"] {
      let output = URL(fileURLWithPath: evidence, isDirectory: true)
      try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
      let data = try #require(
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
      try data.write(to: output.appendingPathComponent("equipment-\(name)-\(width)-\(scale)x.png"))
      let timings: [String: Any] = [
        "source": ProcessInfo.processInfo.environment["ELITE_VALIDATION_SOURCE_SHA"] ?? "local",
        "fixture": name, "width": width, "height": height, "scale": scale,
        "actualDrawSeconds": actualSeconds, "oracleSeconds": oracleSeconds,
        "actualToOracleRatio": ratio, "byteParity": identical,
      ]
      try JSONSerialization.data(withJSONObject: timings, options: [.prettyPrinted, .sortedKeys])
        .write(
          to: output.appendingPathComponent("equipment-\(name)-\(width)-\(scale)x-timing.json"))
    }
    #expect(ratio < 10)
    return image
  }
}

// Inherit the existing suite's serialization; AppKit still has one application/event loop.
extension NativeViewTests {
  @MainActor @Test func nativePaintedShopRejectsStaleActionsAndCommitsDuplicateReturnOnce()
    async throws
  {
    let commander = try nativeEquipmentCommander()
    let fixture = try await NativeEquipmentFixture.open(
      commander: commander, width: 768, height: 768)
    defer { fixture.close() }
    fixture.window.orderOut(nil)
    try await fixture.selectItem(named: "Fuel Scoops")
    let beforeCommander = fixture.view.game.commander
    var before = try nativeEquipmentBytes(beforeCommander)
    let paid = try #require(fixture.view.game.commander.equipmentPurchaseHistory?.paid.count)
    func enqueue(_ code: UInt16, _ text: String) throws {
      func event(_ type: NSEvent.EventType) throws -> NSEvent {
        try #require(
          NSEvent.keyEvent(
            with: type, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: fixture.window.windowNumber, context: nil,
            characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code))
      }
      fixture.view.keyDown(with: try event(.keyDown))
      fixture.view.keyUp(with: try event(.keyUp))
    }
    // Selection changed since the last paint: Return has no trusted displayed context.
    try enqueue(36, "\r")
    #expect(fixture.view.pendingEquipmentPurchases.isEmpty)
    await fixture.delegate.processPendingCommands(in: fixture.view)
    try fixture.verifyUnchanged(before)

    _ = try fixture.capture("shop-navigation-guard", scale: 1)
    try enqueue(125, "")
    try enqueue(36, "\r")
    #expect(fixture.view.pendingEquipmentPurchases.isEmpty)
    await fixture.delegate.processPendingCommands(in: fixture.view)
    try fixture.verifyUnchanged(before)
    try await fixture.selectItem(named: "Fuel Scoops")

    _ = try fixture.capture("shop-bounds-guard", scale: 1)
    let bounds = fixture.view.bounds
    fixture.view.setBoundsSize(NSSize(width: bounds.width - 1, height: bounds.height))
    try enqueue(36, "\r")
    #expect(fixture.view.pendingEquipmentPurchases.isEmpty)
    fixture.view.setBoundsSize(bounds.size)
    await fixture.delegate.processPendingCommands(in: fixture.view)
    try fixture.verifyUnchanged(before)

    _ = try fixture.capture("shop-load-guard", scale: 1)
    try enqueue(36, "\r")
    #expect(fixture.view.pendingEquipmentPurchases.count == 1)
    try await fixture.delegate.runtime.load(from: fixture.save, persistMigrations: false)
    let loaded = await fixture.delegate.runtime.snapshot()
    #expect(loaded.commander == beforeCommander)
    #expect(loaded.commander.equipmentInventory == beforeCommander.equipmentInventory)
    #expect(loaded.commander.equipmentPurchaseHistory == beforeCommander.equipmentPurchaseHistory)
    // Codable Sets can change array order across decoding. Actions must preserve the loaded bytes.
    before = try nativeEquipmentBytes(loaded.commander)
    await fixture.delegate.processPendingCommands(in: fixture.view)
    #expect(fixture.view.game.commander.equipmentPurchaseHistory?.paid.count == paid)
    try fixture.verifyUnchanged(before)
    try await fixture.press(20, text: "3", expected: "3")
    try await fixture.selectItem(named: "Fuel Scoops")

    _ = try fixture.capture("shop-pause-guard", scale: 1)
    func togglePauseThroughMenu() async throws {
      let event = try #require(
        NSEvent.keyEvent(
          with: .keyDown, location: .zero,
          modifierFlags: .command, timestamp: 0, windowNumber: fixture.window.windowNumber,
          context: nil, characters: "p", charactersIgnoringModifiers: "p", isARepeat: false,
          keyCode: 35))
      let handled = try #require(NSApp.mainMenu).performKeyEquivalent(with: event)
      #expect(handled && fixture.view.pending.last == "pause")
      await fixture.delegate.processPendingCommands(in: fixture.view)
    }
    try await togglePauseThroughMenu()
    try enqueue(36, "\r")
    #expect(fixture.view.pendingEquipmentPurchases.isEmpty)
    await fixture.delegate.processPendingCommands(in: fixture.view)
    #expect(fixture.view.game.paused)
    try fixture.verifyUnchanged(before)
    try await togglePauseThroughMenu()

    let layout = EquipmentLayout(game: fixture.view.game, width: 768, height: 768)
    try await fixture.click(try #require(layout.mounts.first).bounds)
    try fixture.verifyUnchanged(before)
    try await fixture.selectItem(named: "Fuel Scoops")
    let rows = EquipmentLayout(game: fixture.view.game, width: 768, height: 768)
    let visual = try #require(
      EquipmentGroups.rows.firstIndex(of: .item(fixture.view.game.selection)))
    let row = visual - rows.start
    try await fixture.click(
      .init(
        x: rows.left + 32,
        y: rows.listTop + Double(row) * rows.row, width: rows.contentWidth - 32, height: rows.row))
    try fixture.verifyUnchanged(before)
    _ = try fixture.capture("shop-duplicate-return", scale: 1)
    let beforePurchase = fixture.view.game
    let item = try #require(Equipment.all.first { $0.name == "Fuel Scoops" })
    let price = beforePurchase.shopPrice(item)
    try enqueue(36, "\r")
    try enqueue(36, "\r")
    #expect(fixture.view.pendingEquipmentPurchases.count == 2)
    let originalContext = try #require(fixture.view.pendingEquipmentPurchases.first)
    #expect(fixture.view.pendingEquipmentPurchases == [originalContext, originalContext])
    await fixture.delegate.processPendingCommands(in: fixture.view)
    let after = fixture.view.game.commander
    #expect(after.equipmentPurchaseHistory?.paid.count == paid + 1)
    #expect(after.equipmentInventory?.items.filter { $0.node.key == "Fuel Scoops" }.count == 1)
    #expect(after.credits < commander.credits)
    let history = try #require(after.equipmentPurchaseHistory)
    let oldHistory = try #require(beforePurchase.commander.equipmentPurchaseHistory)
    #expect(Array(history.paid.prefix(paid)) == oldHistory.paid)
    let receipt = try #require(history.paid.last)
    // Only these allocated identities come from the result; every semantic fact comes from before.
    let expected = try independentNativePurchaseExpectation(
      before: beforePurchase, item: item, price: price,
      transaction: receipt.transaction, newItem: receipt.binding.request.newItem)
    #expect(receipt == expected.commander.equipmentPurchaseHistory?.paid.last)
    #expect(after.credits == beforePurchase.commander.credits - price)
    let checkpoint = try await verifyNativeEquipmentPublication(
      fixture: fixture, expected: expected)
    try await verifyNativeEquipmentPostcommitRefusal(
      fixture: fixture, intent: .purchase(originalContext), expected: expected,
      checkpoint: checkpoint)
    #expect(fixture.delegate.saves.activeURL == fixture.save)
  }

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
      #expect(rows.filter { $0 == "Held - Granted" }.count == 24)
      #expect(rows.contains("Fitted targeting core - Purchased"))
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
        seen.contains("Held - Granted") && seen.contains("Fitted targeting core - Purchased"))
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

extension NativeEquipmentFixture {
  func queueInventoryKey(_ code: UInt16, text: String = "") throws {
    for type in [NSEvent.EventType.keyDown, .keyUp] {
      let event = try #require(
        NSEvent.keyEvent(
          with: type, location: .zero, modifierFlags: [], timestamp: 0,
          windowNumber: window.windowNumber, context: nil, characters: text,
          charactersIgnoringModifiers: text, isARepeat: false, keyCode: code))
      if type == .keyDown { view.keyDown(with: event) } else { view.keyUp(with: event) }
    }
  }

  func queueInventoryMouse(_ bounds: CanvasRect) throws {
    let local = NSPoint(x: bounds.x + bounds.width / 2, y: bounds.y + bounds.height / 2)
    let event = try #require(
      NSEvent.mouseEvent(
        with: .leftMouseDown, location: view.convert(local, to: nil), modifierFlags: [],
        timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 1,
        clickCount: 1, pressure: 1))
    view.mouseDown(with: event)
  }

  func revealInventoryActions(recovered: Bool = false) async throws {
    try await press(25, text: "9", expected: "9")
    let rows = view.game.inventoryInformationRows(width: view.bounds.width)
    let first = try #require(
      rows.firstIndex { row in
        guard row.preview?.command != nil else { return false }
        if recovered {
          if case .recovered = row.subject { return true }
          return false
        }
        return true
      })
    let target = min(first, view.game.informationWindow.last)
    for _ in 0..<target { try await press(125, expected: "down") }
  }
}

extension NativeViewTests {
  @MainActor @Test func nativeInventoryRequiresPaintAndSafelyRefusesFastFocusBeforeReturn()
    async throws
  {
    let fixture = try await NativeEquipmentFixture.open(
      commander: nativeEquipmentCommander(heldGrants: 2), width: 512, height: 518)
    defer { fixture.close() }
    fixture.window.orderOut(nil)
    try await fixture.revealInventoryActions()
    let before = fixture.view.game.commander
    let current = try #require(
      Display.information(
        fixture.view.game, width: fixture.view.bounds.width, height: fixture.view.bounds.height
      ).inventoryInteraction)
    try #require(current.primary != nil)
    // Navigation may retain an older paint; the current scrolled frame has not been drawn.
    #expect(fixture.view.paintedInventoryInteraction != current)
    try fixture.queueInventoryKey(36, text: "\r")
    #expect(fixture.view.pendingInventoryCommands.isEmpty)
    await fixture.delegate.processPendingCommands(in: fixture.view)
    #expect(fixture.view.game.commander == before)
    _ = try fixture.capture("inventory-before-focus", scale: 1)
    let painted = try #require(fixture.view.paintedInventoryInteraction)
    #expect(painted.controls.count > 1)
    let oldPrimary = try #require(painted.primary)
    let page = try #require(fixture.view.paintedMissionMenuPresentation)
    try fixture.queueInventoryKey(48, text: "\t")
    try fixture.queueInventoryKey(36, text: "\r")
    #expect(fixture.view.pending.count == 1 && fixture.view.pendingInventoryCommands.isEmpty)
    try fixture.verifyPageKey("tab", painted: page)
    await fixture.delegate.processPendingCommands(in: fixture.view)
    #expect(fixture.view.game.commander == before)
    _ = try fixture.capture("inventory-after-focus", scale: 1)
    let chosen = try #require(fixture.view.paintedInventoryInteraction?.primary)
    #expect(chosen != oldPrimary)
    let beforeBytes = try nativeEquipmentBytes(before)
    try fixture.verifyUnchanged(beforeBytes)
    let expected = try independentNativeFitExpectation(before: fixture.view.game, command: chosen)
    try fixture.queueInventoryKey(36, text: "\r")
    try fixture.queueInventoryKey(36, text: "\r")
    #expect(fixture.view.pendingInventoryCommands == [chosen, chosen])
    await fixture.delegate.processPendingCommands(in: fixture.view)
    if case .fit(let item, let slot) = chosen.action {
      #expect(fixture.view.game.commander.fittedEquipment(at: slot)?.id == item.id)
    } else {
      Issue.record("Tab should select the next visible held-device Fit action")
    }
    #expect(fixture.view.game.commander.targetingTier == .basic)
    #expect(
      fixture.view.game.commander.equipmentInventory?.revision == before.equipmentInventory!
        .revision + 1)
    #expect(fixture.view.game.commander.credits == before.credits)
    #expect(fixture.view.game.commander.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
    let checkpoint = try await verifyNativeEquipmentPublication(
      fixture: fixture, expected: expected)
    try await verifyNativeEquipmentPostcommitRefusal(
      fixture: fixture, intent: .inventory(chosen), expected: expected, checkpoint: checkpoint)
  }

  @MainActor @Test func nativeInventoryMouseRejectsUnpaintedResizeAndRestoredContext() async throws
  {
    let fixture = try await NativeEquipmentFixture.open(
      commander: nativeEquipmentCommander(heldGrants: 2), width: 512, height: 518)
    defer { fixture.close() }
    fixture.window.orderOut(nil)
    try await fixture.revealInventoryActions()
    _ = try fixture.capture("inventory-before-load", scale: 1)
    let presentation = try #require(fixture.view.paintedInventoryInteraction)
    let control = try #require(
      presentation.controls.first {
        if case .fit = $0.command.action { return true }
        return false
      })
    let before = fixture.view.game.commander
    try fixture.queueInventoryMouse(.init(x: 0, y: 0, width: 2, height: 2))
    #expect(fixture.view.pendingInventoryCommands.isEmpty)
    fixture.window.setContentSize(.init(width: 600, height: 518))
    try fixture.queueInventoryMouse(control.bounds)
    #expect(fixture.view.pendingInventoryCommands.isEmpty)
    fixture.window.setContentSize(.init(width: 512, height: 518))
    fixture.view.pending.append("inventory-click:0:0")
    await fixture.delegate.processPendingCommands(in: fixture.view)
    #expect(fixture.view.game.commander == before)
    try await fixture.delegate.runtime.load(from: fixture.save, persistMigrations: false)
    fixture.view.game = await fixture.delegate.runtime.snapshot()
    try await fixture.revealInventoryActions()
    #expect(fixture.view.game.commander.equipmentOwnerID == control.command.owner)
    #expect(fixture.view.game.commander.hullInstanceID == control.command.hull)
    #expect(
      fixture.view.game.commander.equipmentInventory?.revision == control.command.ownedRevision)
    try fixture.queueInventoryKey(36, text: "\r")
    #expect(fixture.view.pendingInventoryCommands.isEmpty)
    let loaded = fixture.view.game.commander
    let acceptedOld = await fixture.delegate.runtime.inventoryCommand(control.command)
    #expect(!acceptedOld)
    let refusedSnapshot = await fixture.delegate.runtime.snapshot()
    #expect(refusedSnapshot.commander == loaded)
    let loadedBytes = try nativeEquipmentBytes(loaded)
    try fixture.verifyUnchanged(loadedBytes)
    _ = try fixture.capture("inventory-restored-paint", scale: 1)
    let fresh = try #require(
      fixture.view.paintedInventoryInteraction?.controls.first {
        if case .fit = $0.command.action { return true }
        return false
      })
    let expected = try independentNativeFitExpectation(
      before: fixture.view.game, command: fresh.command)
    try fixture.queueInventoryMouse(fresh.bounds)
    #expect(fixture.view.pendingInventoryCommands == [fresh.command])
    await fixture.delegate.processPendingCommands(in: fixture.view)
    if case .fit(let item, let slot) = fresh.command.action {
      #expect(fixture.view.game.commander.fittedEquipment(at: slot)?.id == item.id)
    }
    let checkpoint = try await verifyNativeEquipmentPublication(
      fixture: fixture, expected: expected)
    try await verifyNativeEquipmentPostcommitRefusal(
      fixture: fixture, intent: .inventory(fresh.command), expected: expected,
      checkpoint: checkpoint)
  }

  @MainActor @Test func nativeRecoveredUpgradeFitsInSpaceFromItsPaintedControlOnlyOnce()
    async throws
  {
    let source = try recoveredEquipmentGame("shield-technology")
    let fixture = try await NativeEquipmentFixture.open(
      commander: source.commander, width: 512, height: 518)
    defer { fixture.close() }
    fixture.window.orderOut(nil)
    try await fixture.press(29, text: "0", expected: "0")
    #expect(!fixture.view.game.docked)
    try await fixture.revealInventoryActions(recovered: true)
    _ = try fixture.capture("inventory-in-space-upgrade", scale: 1)
    let control = try #require(
      fixture.view.paintedInventoryInteraction?.controls.first {
        if case .upgrade = $0.command.action { return true }
        return false
      })
    let before = fixture.view.game.commander
    try fixture.queueInventoryMouse(control.bounds)
    try fixture.queueInventoryMouse(control.bounds)
    await fixture.delegate.processPendingCommands(in: fixture.view)
    let after = fixture.view.game.commander
    #expect(!fixture.view.game.docked && after.salvageLedger.inventory.isEmpty)
    #expect(after.fittedComponent(at: .shield)?.receipts.count == 1)
    #expect(after.shieldCapacity > before.shieldCapacity)
    #expect(
      after.credits == before.credits && after.fuel == before.fuel
        && after.missiles == before.missiles)
    #expect(after.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
    try await verifyRecoveredSaveAndRefusedReplay(fixture, command: control.command)
  }

  @MainActor @Test func nativeRecoveredFeatureFitsInSpaceFromItsPaintedControlOnlyOnce()
    async throws
  {
    for (id, width, height, scale) in [
      ("feature-mining-targeting", 512, 518, 1), ("feature-fuel-scoops", 1512, 982, 2),
    ] {
      var source = try recoveredEquipmentGame(id)
      try source.commander.grantEquipment(
        TargetingTier.basic.equipmentName, at: .targetingCore,
        provenance: .grant("native recovered feature fixture"))
      let lot = try #require(source.commander.salvageLedger.inventory.first)
      let fixture = try await NativeEquipmentFixture.open(
        commander: source.commander, width: width, height: height)
      defer { fixture.close() }
      fixture.window.orderOut(nil)
      try await fixture.press(29, text: "0", expected: "0")
      #expect(!fixture.view.game.docked)
      try await fixture.revealInventoryActions(recovered: true)
      _ = try fixture.capture("recovered-feature-before", scale: scale)
      let control = try #require(
        fixture.view.paintedInventoryInteraction?.controls.first {
          if case .installFeature = $0.command.action { return true }
          return false
        })
      guard case .installFeature(_, let definition) = control.command.action else {
        throw RecoveredEquipmentError.invalidBinding
      }
      let before = fixture.view.game.commander
      try fixture.queueInventoryMouse(control.bounds)
      try fixture.queueInventoryMouse(control.bounds)
      #expect(fixture.view.pendingInventoryCommands == [control.command, control.command])
      await fixture.delegate.processPendingCommands(in: fixture.view)
      let after = fixture.view.game.commander
      let item = try #require(after.fittedEquipment(at: definition.slot))
      #expect(!fixture.view.game.docked && after.salvageLedger.inventory.isEmpty)
      #expect(RecoveredFeatureDevices.source(for: item, ledger: after.salvageLedger) == lot)
      #expect(after.equipmentInventory!.items.count == before.equipmentInventory!.items.count + 1)
      #expect(after.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
      #expect(
        after.credits == before.credits && after.fuel == before.fuel
          && after.missiles == before.missiles)
      #expect(after.equipment.contains(definition.node.key))
      _ = try fixture.capture("recovered-feature-after", scale: scale)
      try await verifyRecoveredSaveAndRefusedReplay(fixture, command: control.command)
      #expect(fixture.preferences.persistentDomain(forName: fixture.identifier) == nil)
    }
  }
}

@MainActor
private func verifyRecoveredSaveAndRefusedReplay(
  _ fixture: NativeEquipmentFixture, command: InventoryCommand
) async throws {
  let committed = await fixture.delegate.runtime.snapshot()
  let bytes = try Data(contentsOf: fixture.save)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
  #expect(pointer.schemaVersion == 26 && pointer.scope == "commander")
  let (saved, _) = try ScriptSaveStore.read(bytes, from: fixture.save)
  #expect(saved.valid)
  #expect(saved.salvageLedger == committed.commander.salvageLedger)
  #expect(saved.equipmentInventory == committed.commander.equipmentInventory)
  #expect(saved.equipmentPurchaseHistory == committed.commander.equipmentPurchaseHistory)
  #expect(saved.credits == committed.commander.credits)
  #expect(saved.fuel == committed.commander.fuel && saved.missiles == committed.commander.missiles)
  #expect(saved.nativeStations == committed.commander.nativeStations)
  #expect(saved.scriptState == committed.commander.scriptState)
  let beforeFiles = try recoveredSaveFiles(fixture.directory)
  let result = await fixture.delegate.runtime.equipmentTransaction(.inventory(command))
  #expect(result == .refused(.staleContext))
  let replayed = await fixture.delegate.runtime.snapshot()
  #expect(replayed.commander == committed.commander)
  let replayedBytes = try Data(contentsOf: fixture.save)
  let replayedFiles = try recoveredSaveFiles(fixture.directory)
  #expect(replayedBytes == bytes)
  #expect(replayedFiles == beforeFiles)
}

private func recoveredSaveFiles(_ directory: URL) throws -> [String: Data] {
  let entries = try #require(
    FileManager.default.enumerator(
      at: directory, includingPropertiesForKeys: [.isRegularFileKey]))
  var files: [String: Data] = [:]
  for case let url as URL in entries {
    guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
      continue
    }
    let path = try nativeEquipmentRelativeSavePath(url, in: directory)
    try #require(files[path] == nil)
    files[path] = try Data(contentsOf: url)
  }
  return files
}

// These native UI tests expect lower-domain effects from the original state, independently of the actor.
private func independentNativePurchaseExpectation(
  before: Game, item: Equipment, price: Int, transaction: UUID, newItem: UUID
) throws -> Game {
  let inventory = try #require(before.commander.equipmentInventory)
  let history = try #require(before.commander.equipmentPurchaseHistory)
  try #require(
    before.screen == .equipment && before.stationAllowsEquipmentServices && !before.paused)
  try #require(Equipment.all.indices.contains(before.selection))
  try #require(Equipment.all[before.selection].name == item.name)
  let node = EquipmentNodeID(family: .init("utility-fuelScoops"), key: "Fuel Scoops")
  let policy = try #require(EquipmentRuntimeCatalog.graph.nodes.first { $0.id == node })
  try #require(item.name == node.key && policy.policy == .shop)
  try #require(policy.prerequisites.isEmpty && policy.fittedPrerequisites.isEmpty)
  try #require(history.paid.allSatisfy { $0.node != node })
  try #require(!before.commander.unlimitedCash && price > 0)
  try #require(before.shopPrice(item) == price && before.commander.availableCredits >= price)
  try #require(EquipmentRuntimeCatalog.node(for: item.name) == node)
  let location = ComponentFittingLocation(
    hullInstanceID: inventory.activeHull, slot: .utility(.fuelScoops))
  try #require(inventory.items.allSatisfy { $0.node != node && $0.location != location })
  let originalIDs = Set(inventory.items.map(\.id) + inventory.items.compactMap { $0.component?.id })
    .union([inventory.owner, inventory.activeHull])
    .union(history.paid.flatMap { [$0.transaction, $0.binding.request.newItem] })
  try #require(transaction != newItem && !originalIDs.contains(transaction))
  try #require(!originalIDs.contains(newItem))
  let request = EquipmentPurchaseRequest(
    transaction: transaction, newItem: newItem,
    offer: .init(
      node: node, price: price,
      shop: "galaxy:\(before.commander.galaxy)/system:\(before.commander.system)", revision: 1),
    location: .init(hull: inventory.activeHull, slot: "utility.fuelScoops"))
  let snapshot = try before.commander.purchaseSnapshot()
  let purchase = try EquipmentPurchaseProgression.quote(
    request: request, snapshot: snapshot, history: history, graph: EquipmentRuntimeCatalog.graph)
  let quote = EquipmentRuntimePurchaseQuote(
    source: before.commander, prepared: before.commander, item: item, mount: before.equipmentMount,
    workTool: before.equipmentWorkTool, shop: request.offer.shop, location: location,
    request: request, purchase: purchase)
  var expected = before
  let fitted = try expected.applyEquipmentPurchase(quote)
  try #require(fitted)
  let expectedInventory = try #require(expected.commander.equipmentInventory)
  let expectedHistory = try #require(expected.commander.equipmentPurchaseHistory)
  let expectedItem = OwnedEquipmentItem(
    id: newItem, node: node, provenance: .paid(owner: inventory.owner, transaction: transaction),
    location: location)
  try #require(
    expectedInventory.owner == inventory.owner
      && expectedInventory.activeHull == inventory.activeHull)
  try #require(expectedInventory.items == inventory.items + [expectedItem])
  try #require(expectedInventory.revision == inventory.revision + 1)
  try #require(expectedHistory.owner == history.owner && expectedHistory.legacy == history.legacy)
  try #require(expectedHistory.revision == history.revision + 1)
  try #require(expectedHistory.paid.count == history.paid.count + 1)
  try #require(Array(expectedHistory.paid.dropLast()) == history.paid)
  try #require(expectedHistory.paid.last?.binding.request == request)
  try #require(expectedHistory.paid.last?.binding.snapshot == snapshot)
  try #require(expected.commander.credits == before.commander.credits - price)
  try #require(expected.commander.cargo == before.commander.cargo)
  try #require(expected.commander.salvageLedger == before.commander.salvageLedger)
  try #require(expected.commander.scriptState == before.commander.scriptState)
  try #require(expected.energy == before.energy && expected.frontShield == before.frontShield)
  try #require(expected.rearShield == before.rearShield)
  return expected
}

private func independentNativeFitExpectation(before: Game, command: InventoryCommand) throws -> Game
{
  let inventory = try #require(before.commander.equipmentInventory)
  try #require(before.screen == .inventory && before.docked && !before.paused)
  try #require(command.owner == inventory.owner && command.hull == inventory.activeHull)
  try #require(
    command.shipID == before.commander.shipID && command.context == before.inventoryContextEpoch)
  try #require(command.ownedRevision == inventory.revision && command.sourceRevision == nil)
  guard case .fit(let item, let slot) = command.action else {
    Issue.record("Expected the painted held-device Fit command")
    throw EquipmentRuntimeError.incompatibleFit
  }
  try #require(inventory.items.contains(item) && item.location == nil)
  try #require(
    item.node == EquipmentNodeID(family: .init("utility-fuelScoops"), key: "Fuel Scoops"))
  try #require(item.provenance == .grant("native display fixture") && item.component == nil)
  try #require(slot == .utility(.fuelScoops))
  let obligations = try before.commander.equipmentIssueObligations()
  try #require(obligations.isEmpty)
  let location = ComponentFittingLocation(hullInstanceID: inventory.activeHull, slot: slot)
  let occupied = inventory.items.first { $0.location == location }
  let projected = inventory.items.map { original in
    if original.id == item.id { return original.moved(to: location) }
    if original.id == occupied?.id { return original.moved(to: nil) }
    return original
  }
  var expectedCommander = before.commander
  try expectedCommander.fitEquipment(item, at: slot, expectedRevision: inventory.revision)
  var expected = before
  try expected.fitEquipment(item, at: slot, expectedRevision: inventory.revision)
  try #require(expected.commander == expectedCommander)
  let expectedInventory = try #require(expected.commander.equipmentInventory)
  try #require(
    expectedInventory.owner == inventory.owner
      && expectedInventory.activeHull == inventory.activeHull)
  try #require(
    expectedInventory.items == projected && expectedInventory.revision == inventory.revision + 1)
  try #require(expected.commander.credits == before.commander.credits)
  try #require(
    expected.commander.equipmentPurchaseHistory == before.commander.equipmentPurchaseHistory)
  try #require(expected.commander.salvageLedger == before.commander.salvageLedger)
  try #require(expected.commander.scriptState == before.commander.scriptState)
  try #require(expected.commander.cargo == before.commander.cargo)
  try #require(expected.energy == before.energy && expected.frontShield == before.frontShield)
  try #require(expected.rearShield == before.rearShield)
  return expected
}

@MainActor
private func verifyNativeEquipmentPublication(
  fixture: NativeEquipmentFixture, expected: Game
) async throws -> [String: Data] {
  // Empty actors/events make native publication preparation a no-op for these three fixture states.
  try #require(expected.bodies.isEmpty && expected.commander.scriptState.instances.isEmpty)
  try #require(expected.commander.scriptState.pendingEvents.isEmpty)
  try #require(
    expected.commander.npcPersistence.count == 0 && expected.commander.contracts.boards.isEmpty)
  try #require(expected.commander.scriptState.calendarLedger != nil)
  try #require(expected.commander.savedEMPState == nil && expected.commander.nativeStations == nil)
  try #require(expected.screen == .equipment || expected.screen == .inventory)
  try #require(expected.commander.miningLedger.usesEconomyWeightedPresence)
  let live = await fixture.delegate.runtime.snapshot()
  try #require(
    live.commander == expected.commander && fixture.view.game.commander == expected.commander)
  try #require(live.energy == expected.energy && live.frontShield == expected.frontShield)
  try #require(live.rearShield == expected.rearShield)
  let bytes = try Data(contentsOf: fixture.save)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
  let original = try JSONDecoder().decode(ScriptSavePointer.self, from: fixture.originalSave)
  try #require(pointer.format == "elite-script-save" && pointer.schemaVersion == 26)
  try #require(pointer.scope == "commander" && pointer.valueCodec == ScriptValueStorage.codec)
  try #require(pointer.generation != original.generation)
  let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.save)
  let names = Set(["commander.json", "missions.json", "world.json", "contracts.json"])
  try #require(Set(pointer.hashes.keys) == names)
  let (stored, world) = try ScriptSaveStore.read(bytes, from: fixture.save)
  try #require(stored == expected.commander && stored.valid)
  try #require(world.valid && world.consistent(with: expected.commander))
  // World has no actor bodies here; compare all JSON values, never re-encoded Commander Set hashes.
  let worldBytes = try ScriptValueStorage.encoder().encode(world)
  let expectedWorldBytes = try ScriptValueStorage.encoder().encode(expected.scriptWorldSave)
  let worldValue = try JSONSerialization.jsonObject(with: worldBytes)
  let expectedWorldValue = try JSONSerialization.jsonObject(with: expectedWorldBytes)
  let worldObject = try #require(worldValue as? NSDictionary)
  let expectedWorldObject = try #require(expectedWorldValue as? NSDictionary)
  try #require(worldObject.isEqual(expectedWorldObject))
  let files = try recoveredSaveFiles(fixture.directory)
  let pointerPath = try nativeEquipmentRelativeSavePath(fixture.save, in: fixture.directory)
  try #require(files[pointerPath] == bytes && bytes != fixture.originalSave)
  for (path, originalBytes) in fixture.originalFiles where path != pointerPath {
    try #require(files[path] == originalBytes)
  }
  let added = Set(files.keys).subtracting(fixture.originalFiles.keys)
  let expectedAdded = Set(
    try names.map {
      try nativeEquipmentRelativeSavePath(
        generation.appendingPathComponent($0), in: fixture.directory)
    })
  try #require(added == expectedAdded)
  try #require(Set(fixture.originalFiles.keys).isSubset(of: Set(files.keys)))
  for name in names {
    let path = try nativeEquipmentRelativeSavePath(
      generation.appendingPathComponent(name), in: fixture.directory)
    let chunk = try #require(files[path])
    try #require(ScriptPackLibrary.hash(chunk) == pointer.hashes[name])
  }
  try #require(fixture.delegate.saves.activeURL == fixture.save)
  return files
}

@MainActor
private func verifyNativeEquipmentPostcommitRefusal(
  fixture: NativeEquipmentFixture, intent: EquipmentMutationIntent, expected: Game,
  checkpoint: [String: Data]
) async throws {
  let result = await fixture.delegate.runtime.equipmentTransaction(intent)
  try #require(result == .refused(.staleContext))
  let live = await fixture.delegate.runtime.snapshot()
  try #require(live.commander == expected.commander)
  try #require(live.energy == expected.energy && live.frontShield == expected.frontShield)
  try #require(live.rearShield == expected.rearShield)
  let files = try recoveredSaveFiles(fixture.directory)
  let pointerBytes = try Data(contentsOf: fixture.save)
  let pointerPath = try nativeEquipmentRelativeSavePath(fixture.save, in: fixture.directory)
  try #require(files == checkpoint)
  try #require(pointerBytes == checkpoint[pointerPath])
  try #require(fixture.delegate.saves.activeURL == fixture.save)
}

// Enumeration and expected URLs must agree across temporary-directory aliases and separators.
private func nativeEquipmentRelativeSavePath(_ url: URL, in directory: URL) throws -> String {
  let root = directory.resolvingSymlinksInPath().standardizedFileURL.pathComponents
  let path = url.resolvingSymlinksInPath().standardizedFileURL.pathComponents
  try #require(path.count > root.count && path.prefix(root.count).elementsEqual(root))
  return path.dropFirst(root.count).joined(separator: "/")
}
