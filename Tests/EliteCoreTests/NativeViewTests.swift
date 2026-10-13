import AppKit
import EliteCore
import Testing

@testable import EliteMac

// AppKit has one application and event loop; keep native integration work sequential.
@Suite(.serialized)
struct NativeViewTests {
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
      (119, "", "copy"), (123, "", "left"), (124, "", "right"), (125, "", "down"), (126, "", "up"),
      (0, "a", "a"),
    ]
    for (code, text, expected) in keys {
      let event = try #require(
        NSEvent.keyEvent(
          with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
          windowNumber: 0, context: nil, characters: text, charactersIgnoringModifiers: text,
          isARepeat: false, keyCode: code))
      view.keyDown(with: event)
      #expect(view.pending.last == expected && view.held.contains(expected))
      view.keyUp(with: event)
      #expect(!view.held.contains(expected))
    }
    view.game.launch()
    view.held = ["x", ",", " ", "a"]
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

  @MainActor @Test func nativeWindowLoopProcessesNumberKeysAndClearsFocus() async throws {
    _ = NSApplication.shared
    let delegate = AppDelegate()
    let notification = Notification(name: NSApplication.didFinishLaunchingNotification)
    delegate.applicationDidFinishLaunching(notification)
    let window = try #require(delegate.window)
    let view = try #require(window.contentView as? GameView)
    view.pending = ["return", "0", "chart:20:30"]
    view.held = ["x"]
    view.pressedKeys = [7: "x"]
    // Sanitizers can delay the actor's first frame while other tests run.
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while view.game.time == 0 && ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(view.pending.isEmpty)
    #expect(view.game.time > 0)
    let gameMenu = try #require(NSApp.mainMenu?.item(withTitle: "Game")?.submenu)
    let pauseItem = try #require(gameMenu.item(withTitle: "Pause / Resume"))
    #expect(pauseItem.keyEquivalent == "p" && pauseItem.keyEquivalentModifierMask == .command)
    gameMenu.performActionForItem(at: 0)
    let pauseDeadline = ContinuousClock.now.advanced(by: .seconds(5))
    while !view.game.paused && ContinuousClock.now < pauseDeadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(view.game.paused)
    gameMenu.performActionForItem(at: 0)
    let resumeDeadline = ContinuousClock.now.advanced(by: .seconds(5))
    while view.game.paused && ContinuousClock.now < resumeDeadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(!view.game.paused)
    let guideMenu = try #require(NSApp.mainMenu?.item(withTitle: "Help")?.submenu)
    guideMenu.performActionForItem(at: 0)
    let helpDeadline = ContinuousClock.now.advanced(by: .seconds(5))
    while view.game.screen != .help && ContinuousClock.now < helpDeadline {
      try await Task.sleep(for: .milliseconds(10))
    }
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
        bytes[$0 + 1] > 20 && bytes[$0 + 2] > 20 && bytes[$0] < bytes[$0 + 1] / 2
      }.count
    }
    let lines = try colouredPixels(wire)
    let panels = try colouredPixels(shaded)
    #expect(lines > 100 && panels > lines * 3)
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
    game.key("r")
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
    view.mouseDown(with: click)
    #expect(view.pending.first?.hasPrefix("handoff-click:") == true)
    view.game.key("k")
    #expect(PlayerHelp.pages(for: view.game).first?.title == "BLACKJACK STATION HANDOFF")
  }
}

extension NativeViewTests {
  @MainActor @Test func rClearsHeldSteeringAndStationGuidanceOwnsTheTrackpad() throws {
    let view = GameView()
    view.game.launch()
    view.game.commander.installTargetingComputer(.military)
    view.game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 1500))]
    view.held = ["x", "left", ",", " "]
    view.updateTrackpad(positions: [.zero, .zero, .zero])
    let event = try #require(
      NSEvent.keyEvent(
        with: .keyDown, location: .zero,
        modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "r",
        charactersIgnoringModifiers: "r", isARepeat: false, keyCode: 15))
    view.keyDown(with: event)
    #expect(view.controls.pitch == 0 && view.controls.roll == 0 && view.controls.yaw == 0)
    view.game.key("r")
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
}
