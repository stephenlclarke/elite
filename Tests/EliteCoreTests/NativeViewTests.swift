import AppKit
import EliteCore
import Testing

@testable import EliteMac

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
  let frame = Display.render(game, rasterizeShips: false)
  let smooth = try #require(imageFor(frame, scale: 3))
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
  try await Task.sleep(for: .milliseconds(150))
  #expect(view.pending.isEmpty)
  #expect(view.game.time > 0)
  delegate.windowDidResignKey(notification)
  #expect(view.held.isEmpty && view.pressedKeys.isEmpty)
  delegate.windowWillClose(notification)
  #expect(delegate.loop == nil)
  window.orderOut(nil)
}
