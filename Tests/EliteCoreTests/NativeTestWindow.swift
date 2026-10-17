import AppKit
import Testing

@testable import EliteMac

/// Native viewport fixtures need a logical window larger than a headless runner's display.
/// Production windows retain AppKit's normal screen-fitting behavior.
@MainActor
final class NativeViewportTestWindow: NSWindow {
  override func constrainFrameRect(_ frameRect: NSRect, to _: NSScreen?) -> NSRect { frameRect }

  func defaultConstrainedFrame() -> NSRect {
    super.constrainFrameRect(frame, to: screen)
  }
}

@MainActor
func nativeViewportTestWindow(_ rect: NSRect) -> NSWindow {
  NativeViewportTestWindow(
    contentRect: rect, styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered, defer: false)
}

@MainActor
func nativeWindowSizingDetails(window: NSWindow, view: NSView, requested: NSSize) -> Comment {
  let normal =
    (window as? NativeViewportTestWindow)?.defaultConstrainedFrame()
    ?? window.constrainFrameRect(window.frame, to: window.screen)
  return Comment(
    rawValue:
      "requested=\(requested), frame=\(window.frame), contentRect=\(window.contentRect(forFrameRect: window.frame)), bounds=\(view.bounds), screen=\(String(describing: window.screen?.frame)), visibleFrame=\(String(describing: window.screen?.visibleFrame)), defaultConstraint=\(normal)"
  )
}

extension NativeViewTests {
  @MainActor @Test func nativeViewportFixtureRetainsAnOversizedLogicalContentWindow() throws {
    _ = NSApplication.shared
    let height = max(768, (NSScreen.main?.visibleFrame.height ?? 768) + 200)
    let size = NSSize(width: 768, height: height)
    let window = try #require(
      nativeViewportTestWindow(.init(origin: .zero, size: size)) as? NativeViewportTestWindow)
    let view = GameView(frame: .init(origin: .zero, size: size))
    window.contentView = view
    defer {
      window.orderOut(nil)
      window.contentView = nil
    }
    window.setContentSize(size)
    view.layoutSubtreeIfNeeded()
    #expect(
      view.bounds.size == size,
      nativeWindowSizingDetails(window: window, view: view, requested: size))
    if let destination = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"] {
      func components(_ rect: NSRect) -> [Double] {
        [rect.origin.x, rect.origin.y, rect.width, rect.height].map(Double.init)
      }
      let value: [String: Any] = [
        "requested": [Double(size.width), Double(size.height)],
        "frame": components(window.frame),
        "contentRect": components(window.contentRect(forFrameRect: window.frame)),
        "bounds": components(view.bounds),
        "screenFrame": window.screen.map { components($0.frame) } ?? [],
        "visibleFrame": window.screen.map { components($0.visibleFrame) } ?? [],
        "defaultConstraint": components(window.defaultConstrainedFrame()),
      ]
      let directory = URL(fileURLWithPath: destination, isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        .write(to: directory.appendingPathComponent("native-window-viewport-constraint.json"))
    }
  }
}
