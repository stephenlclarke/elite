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

  @MainActor @Test func planetCurveUsesNativeAntialiasing() throws {
    var game = Game(executive: false)
    game.screen = .front
    game.bodies = []
    let image = try #require(
      imageFor(Display.render(game, rasterizeGraphics: false), pixelSize: 768))
    let data = try #require(image.dataProvider?.data)
    let bytes = try #require(CFDataGetBytePtr(data))
    var shades = 0
    for y in (18 * 3)..<(92 * 3) {
      for x in (155 * 3)..<(230 * 3) {
        let value = bytes[y * image.bytesPerRow + x * 4]
        if value > 0 && value < 255 { shades += 1 }
      }
    }
    #expect(shades > 100)
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
