import AppKit
import CoreFoundation
import Testing

@testable import L337Mac

@MainActor
func nativeWindowOwnershipRunLoopTurn() async {
  await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
    // A real main-run-loop callback acknowledges deferred native work without a sleep.
    RunLoop.main.perform(inModes: [.default]) { continuation.resume() }
    CFRunLoopWakeUp(CFRunLoopGetMain())
  }
}

extension NativeViewTests {
  @MainActor @Test func nativeWindowCloseKeepsARCOwnershipAndJoinsItsCancelledLoop() async throws {
    _ = NSApplication.shared
    let originalMenu = NSApp.mainMenu
    let identifier = "window-arc-" + UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: identifier))
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(identifier + ".json")
    let saves = CommanderSaveSession(preferences: preferences, defaultURL: url)
    let delegate = AppDelegate(restoreOnLaunch: false, saves: saves)
    let notification = Notification(name: NSApplication.didFinishLaunchingNotification)
    delegate.applicationDidFinishLaunching(notification)
    let window = try #require(delegate.window)
    defer {
      delegate.windowWillClose(notification)
      window.orderOut(nil)
      window.contentView = nil
      delegate.window = nil
      NSApp.mainMenu = originalMenu
      preferences.removePersistentDomain(forName: identifier)
      try? FileManager.default.removeItem(at: url)
    }
    try #require(!window.isReleasedWhenClosed)
    let view = try #require(window.contentView as? GameView)
    let loop = try #require(delegate.loop)
    view.pending = ["x", "y", "z", "z", "y"]
    // Closing the actual window must invoke the production delegate's cancellation path.
    window.close()
    #expect(delegate.loop == nil && loop.isCancelled)
    await loop.value
    await nativeWindowOwnershipRunLoopTurn()
    #expect(delegate.window === window && window.contentView === view)
    #expect(!window.isVisible && !window.isReleasedWhenClosed)
    window.title = "Retained closed Elite window"
    #expect(window.title == "Retained closed Elite window")
    // Close may append the existing focus reset, but must not consume earlier player input.
    #expect(Array(view.pending.prefix(5)) == ["x", "y", "z", "z", "y"])
    #expect(view.pending.dropFirst(5).allSatisfy { $0 == "spin-cancel" })
    #expect(!FileManager.default.fileExists(atPath: url.path))
  }
}
