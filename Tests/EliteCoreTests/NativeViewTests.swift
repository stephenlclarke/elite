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
    (122, "", "f1"), (120, "", "f2"), (99, "", "f3"), (118, "", "f4"), (96, "", "f5"),
    (97, "", "f6"),
    (98, "", "f7"), (100, "", "f8"), (101, "", "f9"), (109, "", "f10"), (0, "a", "a"),
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
