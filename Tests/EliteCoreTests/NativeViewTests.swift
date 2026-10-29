import AppKit
import Testing

@testable import EliteCore
@testable import EliteMac

@MainActor
func verifyNativePaintedKey(
  _ view: GameView, key: String, painted: ScriptPagePresentation
) throws {
  let packet = try #require(view.pending.last)
  try #require(packet.hasPrefix("script-page-key:"))
  let parts = packet.dropFirst("script-page-key:".count).split(separator: ":", maxSplits: 1)
  try #require(parts.count == 2)
  let bytes = try #require(Data(base64Encoded: String(parts[0])))
  let proof = try JSONDecoder().decode(ScriptPagePresentation.self, from: bytes)
  #expect(proof == painted && String(parts[1]) == key)
}

// AppKit has one application and event loop; keep native integration work sequential.
@Suite(.serialized)
struct NativeViewTests {
  @MainActor @Test func nativeMenusRetireDuplicateNavigationAcceleratorsAndKeepPrimaryScreens()
    async throws
  {
    _ = NSApplication.shared
    let delegate = AppDelegate(restoreOnLaunch: false)
    let notification = Notification(name: NSApplication.didFinishLaunchingNotification)
    delegate.applicationDidFinishLaunching(notification)
    let window = try #require(delegate.window)
    defer {
      delegate.windowWillClose(notification)
      window.orderOut(nil)
    }
    let view = try #require(window.contentView as? GameView)
    let loop = try #require(delegate.loop)
    loop.cancel()
    await loop.value
    view.game.screen = .status
    let commander = try #require(NSApp.mainMenu?.item(withTitle: "Commander")?.submenu)
    #expect(commander.item(withTitle: "Ship Showroom") == nil)
    let screens = try #require(NSApp.mainMenu?.item(withTitle: "Screens")?.submenu)
    delegate.menuNeedsUpdate(screens)
    #expect(screens.items.allSatisfy { $0.keyEquivalent.isEmpty })
    for number in [1, 2] {
      let item = try #require(screens.items.first { $0.tag == number })
      #expect(item.isHidden && !delegate.validateMenuItem(item))
    }
    for number in [6, 7] {
      let item = try #require(screens.items.first { $0.tag == number })
      #expect(!item.isHidden && delegate.validateMenuItem(item))
      screens.performActionForItem(at: screens.index(of: item))
      #expect(view.pending.last == "screen:\(number)")
    }
    view.pending.removeAll()
    let retired = try #require(
      NSEvent.keyEvent(
        with: .keyDown, location: .zero,
        modifierFlags: [.command, .shift], timestamp: 0, windowNumber: window.windowNumber,
        context: nil, characters: "W", charactersIgnoringModifiers: "w", isARepeat: false,
        keyCode: 13))
    view.keyDown(with: retired)
    #expect(view.pending.isEmpty && view.game.screen == .status)
    let save = try #require(commander.item(withTitle: "Save Commander"))
    let open = try #require(commander.item(withTitle: "Open Commander..."))
    #expect(save.keyEquivalent == "s" && save.keyEquivalentModifierMask == .command)
    #expect(open.keyEquivalent == "o" && open.keyEquivalentModifierMask == [.command, .shift])
    view.game.launch()
    delegate.menuNeedsUpdate(screens)
    for number in [1, 2] {
      let item = try #require(screens.items.first { $0.tag == number })
      #expect(!item.isHidden && delegate.validateMenuItem(item))
    }
  }

  @MainActor @Test func nativeSaveIncludesEarlierQueuedCobraRestore() async throws {
    let id = UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: id))
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(id + ".json")
    defer {
      preferences.removePersistentDomain(forName: id)
      try? FileManager.default.removeItem(at: url)
    }
    var commander = Commander()
    commander.shipID = "SH013"
    commander.fuel = commander.fuelCapacity
    commander.missiles = min(3, commander.missileCapacity)
    commander.xyzzyActive = true
    commander.autoTrade = false
    commander.credits = 12345
    try JSONEncoder().encode(commander).write(to: url)
    let saves = CommanderSaveSession(preferences: preferences, defaultURL: url)
    // Await fixture validation before testing input order; sanitizer startup may be slow.
    let delegate = AppDelegate(restoreOnLaunch: false, saves: saves)
    try await delegate.runtime.load(from: url, persistMigrations: false)
    #expect(await delegate.runtime.snapshot().commander.shipID == "SH013")
    let notification = Notification(name: NSApplication.didFinishLaunchingNotification)
    delegate.applicationDidFinishLaunching(notification)
    let window = try #require(delegate.window)
    defer {
      delegate.windowWillClose(notification)
      window.orderOut(nil)
    }
    let view = try #require(window.contentView as? GameView)
    // Stop and await the automatic consumer before draining the real menu batch
    // deterministically. Heavy sanitizer workloads can starve a wall-clock poll.
    let loop = try #require(delegate.loop)
    loop.cancel()
    await loop.value
    view.pending = ["x", "y", "z", "z", "y"]
    let menu = try #require(NSApp.mainMenu?.item(withTitle: "Commander")?.submenu)
    menu.performActionForItem(at: 0)
    #expect(view.pending.last == "commander-file")
    #expect(view.pendingCommanderFiles.last == .saveActive)
    await delegate.processPendingCommands(in: view)
    #expect(view.pending.isEmpty)
    let persisted = try NativeSaveTestFixture.readVersionedCommander(from: url)
    #expect(persisted.shipID == "SH023" && persisted.credits == 12345)
    #expect(persisted.name == "CLARKE" && saves.startupURL == url)
  }

  @MainActor @Test func cancellingNativeStartupBeforeExecutionDoesNotRestoreOrProcessInput()
    async throws
  {
    let id = UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: id))
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(id + ".json")
    defer {
      preferences.removePersistentDomain(forName: id)
      try? FileManager.default.removeItem(at: url)
    }
    var commander = Commander()
    commander.name = "CANCELLED"
    commander.credits = 98765
    try JSONEncoder().encode(commander).write(to: url)
    let saves = CommanderSaveSession(preferences: preferences, defaultURL: url)
    let delegate = AppDelegate(saves: saves)
    let before = await delegate.runtime.snapshot().commander
    let beforePacks = await delegate.runtime.snapshot().scriptPacks.map(\.digest)
    let notification = Notification(name: NSApplication.didFinishLaunchingNotification)
    delegate.applicationDidFinishLaunching(notification)
    let window = try #require(delegate.window)
    defer { window.orderOut(nil) }
    let view = try #require(window.contentView as? GameView)
    view.pending = ["x", "y", "z", "z", "y"]
    let loop = try #require(delegate.loop)
    delegate.windowWillClose(notification)
    await loop.value
    #expect(delegate.loop == nil)
    #expect(await delegate.runtime.snapshot().commander == before)
    let afterPacks = await delegate.runtime.snapshot().scriptPacks.map(\.digest)
    #expect(afterPacks == beforePacks)
    #expect(view.pending == ["x", "y", "z", "z", "y"])
  }

  @MainActor @Test func nativeSpinInputRecognizesCirclesRebasesAimAndKeepsForwardThrottleSeparate()
  {
    let view = GameView()
    view.game.launch()
    view.game.key("v")
    for index in 0...40 {
      let angle = -Double(index) * .pi / 20
      view.updateTrackpad(positions: [.init(0.5 + cos(angle) * 0.3, 0.5 + sin(angle) * 0.3)])
    }
    #expect(view.pending == ["spin:cw"])
    #expect(view.controls.pitch == 0 && view.controls.yaw == 0 && view.controls.throttle == 0)
    view.updateTrackpad(positions: [.zero, .zero, .zero])
    #expect(view.controls.spinContacts == 3 && view.controls.throttle == 0)
    view.updateTrackpad(positions: [.init(0.1, 0.1), .init(0.3, 0.1)])
    #expect(view.controls.pitch == 0 && view.controls.yaw == 0)
    view.updateTrackpad(positions: [.init(0.2, 0.2), .init(0.4, 0.2)])
    #expect(view.controls.pitch > 0 && view.controls.yaw > 0 && view.controls.roll == 0)
    view.held = ["-", "right"]
    #expect(view.controls.spinSlower && !view.controls.spinFaster && view.controls.yaw == 1)
    view.held = ["+"]
    #expect(view.controls.spinFaster && !view.controls.spinSlower)
    view.game.key("b")
    #expect(view.trackpad.fingerCount == 0)
  }

  @MainActor @Test func nativeTrackpadHoldsControlsAndClearsOnPauseHelpDockingOrFocusLoss() throws {
    let view = GameView()
    #expect(view.allowedTouchTypes == .indirect && view.wantsRestingTouches)
    view.updateTrackpad(positions: [.init(0.5, 1), .init(0.5, 1)])
    #expect(view.trackpad.fingerCount == 0)
    view.game.launch()
    view.updateTrackpad(positions: [.init(0.5, 1), .init(0.5, 1)])
    #expect(view.controls.pitch == 1 && view.controls.throttle == 0)
    view.held = ["x"]
    #expect(view.controls.pitch == 1)
    view.held = ["s"]
    #expect(view.controls.pitch == 0)
    view.held = []
    view.updateTrackpad(positions: [.init(0.5, 0.5)])
    #expect(view.controls.throttle == -1 && view.controls.pitch == 0)
    view.updateTrackpad(positions: [.zero, .zero, .zero])
    #expect(view.controls.throttle == 1 && view.controls.roll == 0)
    view.game.paused = true
    #expect(view.trackpad.fingerCount == 0 && view.controls.throttle == 0)
    view.game.paused = false
    view.updateTrackpad(positions: [.init(1, 0.5), .init(1, 0.5)])
    #expect(view.controls.roll == -1)
    view.game.key("k")
    #expect(view.trackpad.fingerCount == 0)
    view.game.key("k")
    #expect(view.controls.roll == 0)
    view.game.dockingComputer = true
    view.updateTrackpad(positions: [.zero, .zero, .zero])
    #expect(view.trackpad.fingerCount == 0)
    view.game.dockingComputer = false
    view.updateTrackpad(positions: [.zero, .zero, .zero])
    let cancel = try #require(
      NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
        windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
        isARepeat: false, keyCode: 0))
    view.touchesCancelled(with: cancel)
    #expect(view.trackpad.fingerCount == 0)
    view.updateTrackpad(positions: [.zero, .zero, .zero])
    view.game.dock()
    #expect(view.trackpad.fingerCount == 0)
  }

  @MainActor @Test func nativeFrameConversionAndInput() throws {
    let image = try #require(imageFor(Display.render(Game())))
    #expect(image.width == 256 && image.height == 256)
    let view = GameView(frame: NSRect(x: 0, y: 0, width: 768, height: 768))
    #expect(view.acceptsFirstResponder && view.isFlipped)
    let keys: [(UInt16, String, String)] = [
      (36, "\r", "return"), (48, "\t", "tab"), (53, "", "escape"),
      (117, "", "delete"), (119, "", "copy"), (123, "", "left"), (124, "", "right"),
      (125, "", "down"), (126, "", "up"),
      (0, "a", "a"),
    ]
    for (code, text, expected) in keys {
      let event = try #require(
        NSEvent.keyEvent(
          with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
          windowNumber: 0, context: nil, characters: text, charactersIgnoringModifiers: text,
          isARepeat: false, keyCode: code))
      let protectedKey =
        ScriptPagePresentation.controlKeys.contains(expected)
        || ScriptPagePresentation.galleryContextKeys.contains(expected)
      if protectedKey { try paintCampaignGalleryView(view) }
      let painted = view.paintedMissionMenuPresentation
      view.keyDown(with: event)
      if protectedKey {
        try verifyNativePaintedKey(view, key: expected, painted: #require(painted))
      } else {
        #expect(view.pending.last == expected)
      }
      #expect(view.held.isEmpty)
      view.keyUp(with: event)
      #expect(!view.held.contains(expected))
    }
    view.game.launch()
    view.held = ["x", ",", " ", FlightControlInput.token(for: .fire)]
    #expect(
      view.controls.pitch == 1 && view.controls.roll == 1 && view.controls.throttle == 1
        && view.controls.fire)
    view.held = ["s", ".", "/"]
    #expect(view.controls.pitch == -1 && view.controls.roll == -1 && view.controls.throttle == -1)
    view.held = ["<", ">", "?"]
    #expect(view.controls.roll == 0 && view.controls.throttle == -1)
    view.held = []
    #expect(!view.controls.fire)
    weak var released: GameView?
    do {
      let transient = GameView()
      released = transient
      #expect(released != nil)
    }
    #expect(released == nil)
  }

  @MainActor @Test func smoothWireframesPreservePixelTextAndShiftedKeyRelease() throws {
    var game = Game(executive: false)
    game.time = 1.3
    game.screen = .front
    game.bodies = [.init(id: 1, hull: .cobra, position: .init(0, 0, 280))]
    let frame = Display.render(game, rasterizeGraphics: false)
    let smooth = try #require(imageFor(frame, pixelSize: 768))
    #expect(smooth.width == 768 && smooth.height == 768)
    let data = try #require(smooth.dataProvider?.data)
    let bytes = CFDataGetBytePtr(data)!
    let count = CFDataGetLength(data)
    let intermediate = stride(from: 0, to: count, by: 4).filter { bytes[$0] > 0 && bytes[$0] < 255 }
      .count
    #expect(intermediate > 100)
    let view = GameView()
    view.game.launch()
    let down = try #require(
      NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: .shift, timestamp: 0,
        windowNumber: 0, context: nil, characters: "<", charactersIgnoringModifiers: ",",
        isARepeat: false, keyCode: 43))
    let up = try #require(
      NSEvent.keyEvent(
        with: .keyUp, location: .zero, modifierFlags: [], timestamp: 0,
        windowNumber: 0, context: nil, characters: ",", charactersIgnoringModifiers: ",",
        isARepeat: false, keyCode: 43))
    view.keyDown(with: down)
    #expect(view.controls.roll == 1)
    view.keyUp(with: up)
    #expect(view.controls.roll == 0 && view.held.isEmpty)
  }

  @MainActor @Test func nativeFrameProcessesNumberKeysMenusAndClearsFocus() async throws {
    _ = NSApplication.shared
    let delegate = AppDelegate(restoreOnLaunch: false)
    let notification = Notification(name: NSApplication.didFinishLaunchingNotification)
    delegate.applicationDidFinishLaunching(notification)
    let window = try #require(delegate.window)
    defer {
      delegate.windowWillClose(notification)
      window.orderOut(nil)
    }
    let view = try #require(window.contentView as? GameView)
    let loop = try #require(delegate.loop)
    loop.cancel()
    await loop.value
    view.pending = ["return", "0", "chart:20:30"]
    view.held = ["x"]
    view.pressedKeys = [7: "x"]
    await delegate.processFrame(in: view) { 0.02 }
    #expect(view.pending.isEmpty)
    #expect(view.game.time > 0)
    let gameMenu = try #require(NSApp.mainMenu?.item(withTitle: "Game")?.submenu)
    let pauseItem = try #require(gameMenu.item(withTitle: "Pause / Resume"))
    #expect(pauseItem.keyEquivalent == "p" && pauseItem.keyEquivalentModifierMask == .command)
    gameMenu.performActionForItem(at: gameMenu.index(of: pauseItem))
    await delegate.processFrame(in: view) { 0.02 }
    #expect(view.game.paused)
    gameMenu.performActionForItem(at: gameMenu.index(of: pauseItem))
    await delegate.processFrame(in: view) { 0.02 }
    #expect(!view.game.paused)
    let guideMenu = try #require(NSApp.mainMenu?.item(withTitle: "Help")?.submenu)
    guideMenu.performActionForItem(at: 0)
    await delegate.processFrame(in: view) { 0.02 }
    #expect(view.game.screen == .help)
    view.game.launch()
    // Headless runners may not grant key-window status; inject the held touch for this reset check.
    view.trackpad.update(positions: [.zero, .zero, .zero])
    #expect(view.trackpad.fingerCount == 3)
    delegate.windowDidResignKey(notification)
    #expect(view.held.isEmpty && view.pressedKeys.isEmpty && view.trackpad.fingerCount == 0)
    delegate.windowWillClose(notification)
    #expect(delegate.loop == nil)
    window.orderOut(nil)
  }

  @MainActor @Test func nativePresentationDrawsColouredLinesAndShadedFaces() throws {
    var game = Game(executive: false)
    game.time = 2.3
    game.screen = .front
    game.bodies = [.init(id: 1, hull: .cobra, position: .init(0, 0, 280))]
    game.commander.shipDisplayStyle = .colourWireframe
    let wire = try #require(
      imageFor(Display.render(game, rasterizeGraphics: false), pixelSize: 512))
    game.commander.shipDisplayStyle = .shadedPanels
    let shaded = try #require(
      imageFor(Display.render(game, rasterizeGraphics: false), pixelSize: 512))
    func colouredPixels(_ image: CGImage) throws -> Int {
      let data = try #require(image.dataProvider?.data)
      let bytes = try #require(CFDataGetBytePtr(data))
      return stride(from: 0, to: CFDataGetLength(data), by: 4).filter {
        let channels = [Int(bytes[$0]), Int(bytes[$0 + 1]), Int(bytes[$0 + 2])]
        return channels.max()! > 20 && channels.max()! - channels.min()! > 20
      }.count
    }
    let lines = try colouredPixels(wire)
    let panels = try colouredPixels(shaded)
    #expect(lines > 100)
    // Filled material colour covers more area than lines, regardless of livery hue.
    #expect(panels > lines)
    #expect(shaded.width == 512 && shaded.height == 512)
  }

  @MainActor @Test func flightHasNoDecorativePlanetAndUsesNativeWindowSize() throws {
    var game = Game(executive: false)
    game.launch()
    game.bodies = []
    let frame = Display.cockpit(game, width: 1379, height: 800)
    #expect(
      !frame.worldGraphics.contains {
        if case .ellipse = $0 { return true }
        return false
      })
    let image = try #require(imageForGame(game, width: 1379, height: 800, scale: 2))
    #expect(image.width == 2758 && image.height == 1600)
    #expect(imageForGame(game, width: 0, height: 800) == nil)
    #expect(imageForGame(game, width: 5000, height: 800) == nil)
  }

  @MainActor @Test func changingThrottleCannotTeleportStarsOrAddTails() throws {
    var game = Game(executive: false)
    game.screen = .front
    game.bodies = []
    game.time = 100
    game.speed = 20
    let before = try #require(
      imageFor(Display.render(game, rasterizeGraphics: false), pixelSize: 768))
    game.speed = 32
    let after = try #require(
      imageFor(Display.render(game, rasterizeGraphics: false), pixelSize: 768))
    let first = try #require(before.dataProvider?.data)
    let second = try #require(after.dataProvider?.data)
    // The cockpit speed gauge changes, but space must not move until the next tick.
    let space = (12 * 3 * before.bytesPerRow)..<(176 * 3 * before.bytesPerRow)
    let firstSpace = Data(bytes: CFDataGetBytePtr(first)! + space.lowerBound, count: space.count)
    let secondSpace = Data(bytes: CFDataGetBytePtr(second)! + space.lowerBound, count: space.count)
    #expect(firstSpace == secondSpace)
  }

  @MainActor @Test func nativeGraphicsRenderAtExactOutputSizeAndKeepOriginalGlyphs() throws {
    var game = Game(executive: false)
    game.key("k")
    let frame = Display.render(game, rasterizeGraphics: false)
    let image = try #require(imageFor(frame, pixelSize: 768))
    let data = try #require(image.dataProvider?.data)
    let bytes = try #require(CFDataGetBytePtr(data))
    for y in 8..<15 {
      for x in 0..<256 {
        let expected = UInt8((frame.pixels[y * 256 + x] >> 24) & 255)
        for dy in 0..<3 {
          for dx in 0..<3 {
            #expect(bytes[(y * 3 + dy) * image.bytesPerRow + (x * 3 + dx) * 4] == expected)
          }
        }
      }
    }
    let resized = try #require(imageFor(frame, pixelSize: 1379))
    #expect(resized.width == 1379 && resized.height == 1379)
    let retina = try #require(imageFor(frame, pixelSize: 3072))
    #expect(retina.width == 3072 && retina.height == 3072)
    #expect(imageFor(frame, pixelSize: 0) == nil)
    #expect(imageFor(frame, pixelSize: 8193) == nil)
  }
}

extension NativeViewTests {
  @MainActor @Test func nativeTargetCameraAndEquipmentRenderResponsiveFrames() throws {
    var game = Game(executive: false)
    game.launch()
    game.speed = 0
    for key in "xyzzy" { game.key(String(key)) }
    game.key("return")
    game.bodies = [.init(id: 1, hull: .constrictor, position: .init(0, 0, 1000))]
    game.key("tab")
    game.targetPanelExpanded = true
    for width in [512, 1512] {
      for style in ShipDisplayStyle.allCases {
        game.commander.shipDisplayStyle = style
        let image = try #require(imageForGame(game, width: width, height: 768))
        #expect(image.width == width && image.height == 768)
      }
      game.screen = .equipment
      game.selection = Equipment.all.count - 1
      let image = try #require(imageForGame(game, width: width, height: 768))
      #expect(image.width == width)
      game.screen = .front
    }
  }
}

extension NativeViewTests {
  @MainActor @Test func nativeMapsAndSearchRenderWithNoFlightInputLeakage() throws {
    let view = GameView()
    view.game.launch()
    view.game.key("4")
    view.game.key("/")
    view.held = ["a", "x", " "]
    #expect(!view.controls.fire && view.controls.pitch == 0 && view.controls.throttle == 0)
    for width in [512, 1512] {
      for mode in MapColourMode.allCases {
        view.game.mapColour = mode
        let image = try #require(imageForGame(view.game, width: width, height: 768))
        #expect(image.width == width)
      }
      view.game.key("escape")
      view.game.key("5")
      let image = try #require(imageForGame(view.game, width: width, height: 768))
      #expect(image.width == width)
      view.game.key("4")
      view.game.key("/")
    }
  }
  @MainActor @Test func responsiveStationScreensRenderMarketColoursMountsAndScrollableInformation()
    throws
  {
    var game = Game(executive: false)
    game.commander.installLaser(.military, on: .rear)
    for screen in [Screen.market, .buy, .sell, .status, .inventory, .equipment] {
      game.screen = screen
      for width in [512, 1024, 2560] {
        let image = try #require(imageForGame(game, width: width, height: 518))
        #expect(image.width == width && image.height == 518)
        #expect(image.dataProvider?.data != nil)
      }
    }
  }

}

extension NativeViewTests {
  @MainActor @Test func blackjackNativeContactRendersAndMouseInputKeepsFlightNeutral() throws {
    let view = GameView(frame: NSRect(x: 0, y: 0, width: 512, height: 518))
    view.game.commander.galaxy = 1
    view.game.systems = Universe.galaxy(number: 1)
    view.game.commander.system = 241
    view.game.dock()
    view.held = ["a", "x", " "]
    #expect(view.game.screen == .handoff && !view.controls.fire && view.controls.pitch == 0)
    for width in [512, 1024, 2560] {
      let image = try #require(imageForGame(view.game, width: width, height: 518, scale: 2))
      #expect(image.width == width * 2 && image.height == 1036)
      #expect(image.dataProvider?.data != nil)
    }
    let click = try #require(
      NSEvent.mouseEvent(
        with: .leftMouseDown, location: .init(x: 100, y: 48), modifierFlags: [], timestamp: 0,
        windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    try paintCampaignGalleryView(view)
    let painted = try #require(view.paintedMissionMenuPresentation)
    let point = view.convert(click.locationInWindow, from: nil)
    view.mouseDown(with: click)
    let packet = try #require(view.pending.first)
    try #require(packet.hasPrefix("script-page-click:"))
    let parts = packet.dropFirst("script-page-click:".count).split(separator: ":")
    try #require(parts.count == 3)
    let bytes = try #require(Data(base64Encoded: String(parts[0])))
    let proof = try JSONDecoder().decode(ScriptPagePresentation.self, from: bytes)
    #expect(proof == painted)
    #expect(Double(parts[1]) == point.x && Double(parts[2]) == point.y)
    view.game.key("k")
    #expect(PlayerHelp.pages(for: view.game).first?.title == "MISSION DIALOG")
  }
}

extension NativeViewTests {
  @MainActor @Test func tabClearsHeldSteeringAndStationGuidanceOwnsTheTrackpad() throws {
    let view = GameView()
    view.game.commander.installTargetingComputer(.military)
    view.game.launch()
    #expect(
      view.game.commander.equipmentInventory != nil
        && view.game.commander.targetingTier == .military)
    view.game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 1500))]
    view.held = ["x", "left", ",", " "]
    view.updateTrackpad(positions: [.zero, .zero, .zero])
    let retired = try #require(
      NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
        context: nil, characters: "r", charactersIgnoringModifiers: "r", isARepeat: false,
        keyCode: 15))
    view.keyDown(with: retired)
    #expect(view.held.contains("x") && view.held.contains("left"))
    view.game.key("r")
    #expect(view.game.autoPilot.targetID == nil && !view.game.dockingComputer)
    let event = try #require(
      NSEvent.keyEvent(
        with: .keyDown, location: .zero,
        modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "\t",
        charactersIgnoringModifiers: "\t", isARepeat: false, keyCode: 48))
    view.keyDown(with: event)
    #expect(view.controls.pitch == 0 && view.controls.roll == 0 && view.controls.yaw == 0)
    view.game.key("tab")
    #expect(view.game.dockingComputer && view.controls.throttle == 0 && view.held.isEmpty)
    view.updateTrackpad(positions: [.zero, .zero, .zero])
    #expect(view.controls.throttle == 0 && view.trackpad.fingerCount == 0)
  }

  @MainActor @Test func nativeCatalogueMapsAndCompactScreensRenderAtWindowAndRetinaSizes() throws {
    var game = Game(executive: false)
    game.screen = .status
    game.key("showroom-open")
    game.showroom.selection = "SH165"
    game.showroom.detail = true
    let evidence = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"]
    for (width, height, scale) in [(512, 518, 1), (1512, 982, 2)] {
      for screen in [Screen.showroom, .system, .help, .secret, .demo, .title, .equipment, .chart] {
        game.screen = screen
        game.helpReturn = .showroom
        game.time = 5
        let image = try #require(imageForGame(game, width: width, height: height, scale: scale))
        #expect(image.width == width * scale && image.height == height * scale)
        if let evidence {
          let url = URL(fileURLWithPath: evidence, isDirectory: true)
          try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
          let data = try #require(
            NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
          try data.write(to: url.appendingPathComponent("\(screen.rawValue)-\(width).png"))
        }
      }
    }
    game.screen = .chart
    game.key("/")
    game.key("w")
    #expect(game.screen == .chart && game.mapSearch.query == "w")
    game.key("showroom-open")
    #expect(game.screen == .showroom)
    game.key("/")
    game.key("k")
    #expect(game.showroom.searching && game.showroom.query == "k")
    game.key("help-open")
    #expect(game.screen == .help && game.helpReturn == .showroom)
    game.key("help-open")
    #expect(game.screen == .showroom && game.showroom.searching)
    game.key("escape")
    game.showroom.query = ""
    let bounds = ShowroomLayout(width: 768, height: 768, detail: false)
    game.viewportWidth = 768
    game.viewportHeight = 768
    let view = GameView(frame: .init(x: 0, y: 0, width: 768, height: 768))
    view.game = game
    let event = try #require(
      NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: .init(x: bounds.buttons[3].x + 8, y: 768 - bounds.buttons[3].y - 8),
        modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
        eventNumber: 1, clickCount: 1, pressure: 1))
    view.mouseDown(with: event)
    #expect(view.pending.first?.hasPrefix("showroom-click:") == true)
  }
  @MainActor @Test func macBookControlsUseArrowsDeleteReturnAndSafeModifierCommands() throws {
    let view = GameView(frame: .init(x: 0, y: 0, width: 512, height: 518))
    view.game.launch()
    func event(
      _ code: UInt16, _ text: String = "", flags: NSEvent.ModifierFlags = [], repeated: Bool = false
    ) throws -> NSEvent {
      try #require(
        NSEvent.keyEvent(
          with: .keyDown, location: .zero, modifierFlags: flags,
          timestamp: 0, windowNumber: 0, context: nil, characters: text,
          charactersIgnoringModifiers: text, isARepeat: repeated, keyCode: code))
    }
    for (code, text, key) in [
      (UInt16(126), "", "up"), (123, "", "left"), (49, " ", " "), (36, "\r", "return"),
    ] {
      if code != 49 { try paintCampaignGalleryView(view) }
      let painted = view.paintedMissionMenuPresentation
      view.keyDown(with: try event(code, text))
      if code != 49 {
        try verifyNativePaintedKey(view, key: key, painted: #require(painted))
      }
    }
    #expect(view.controls.pitch == 1 && view.controls.roll == 1)
    #expect(view.controls.throttle == 1 && view.controls.fire)
    view.game.key("4")
    #expect(view.held.isEmpty && view.controls.throttle == 0 && !view.controls.fire)
    try paintCampaignGalleryView(view)
    let beforeDown = try #require(view.paintedMissionMenuPresentation)
    view.keyDown(with: try event(125, flags: .option))
    try verifyNativePaintedKey(view, key: "pagedown", painted: beforeDown)
    try paintCampaignGalleryView(view)
    let beforeUp = try #require(view.paintedMissionMenuPresentation)
    view.keyDown(with: try event(126, flags: .option))
    try verifyNativePaintedKey(view, key: "pageup", painted: beforeUp)
    view.game.key("/")
    view.game.key("a")
    #expect(view.performKeyEquivalent(with: try event(51, flags: .command)))
    #expect(view.pending.last == "search-clear")
    view.game.key(view.pending.removeLast())
    #expect(view.game.mapSearch.query.isEmpty)
    view.keyDown(with: try event(0, "a", flags: .command))
    #expect(!view.held.contains("a"))
    view.keyDown(with: try event(8, "c", repeated: true))
    #expect(view.pending.last == "c")
    view.game.key("escape")
    view.game.key("0")
    view.keyDown(with: try event(51))
    #expect(view.controls.throttle == -1)
    view.keyUp(with: try event(51))
    #expect(view.controls.throttle == 0)
    try view.game.commander.grantEquipment(
      TargetingTier.basic.equipmentName, at: .targetingCore,
      provenance: .grant("MacBook targeting fixture"))
    #expect(
      view.game.commander.equipmentInventory != nil && view.game.commander.targetingTier == .basic)
    try view.game.commander.grantEquipment(
      "Energy Bomb", at: .utility(.energyBomb), provenance: .grant("MacBook bomb fixture"))
    let bomb = try #require(view.game.commander.fittedEquipment(at: .utility(.energyBomb)))
    let credits = view.game.commander.credits
    view.game.key("tab")
    #expect(view.game.commander.equipment.contains("Energy Bomb"))
    #expect(view.game.commander.fittedEquipment(at: .utility(.energyBomb)) == bomb)
    #expect(view.game.commander.credits == credits)
    view.game.paused = true
    #expect(view.held.isEmpty && !view.controls.fire)
  }

}
