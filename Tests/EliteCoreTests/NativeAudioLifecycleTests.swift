import AppKit
import Testing

@testable import EliteCore
@testable import EliteMac

// Use the existing serialized AppKit cohort and genuine generated-effect playback.
extension NativeViewTests {
  @MainActor @Test func nativeAudioShutdownStopsOwnedPlaybackAndRejectsLaterUpdates() throws {
    let audio = AudioPresenter()
    defer { audio.shutdown() }
    var flying = Game()
    flying.commander.speech = false
    flying.docked = false
    audio.update(flying)
    let playing = try #require(audio.players.first)
    try #require(playing.isPlaying)
    audio.shutdown()
    #expect(audio.isShutdown && audio.players.isEmpty && !playing.isPlaying)
    audio.shutdown()
    var docked = flying
    docked.docked = true
    audio.update(docked)
    audio.update(flying)
    #expect(audio.isShutdown && audio.players.isEmpty && !playing.isPlaying)
    let active = AudioPresenter()
    defer { active.shutdown() }
    active.update(flying)
    #expect(!active.isShutdown && active.players.contains { $0.isPlaying })
  }

  @MainActor @Test func nativeWindowCloseDuringFramePreventsAudioRestart() async throws {
    _ = NSApplication.shared
    var flying = Game()
    flying.commander.speech = false
    flying.docked = false
    let delegate = AppDelegate(restoreOnLaunch: false, runtime: GameRuntime(game: flying))
    let view = GameView(frame: NSRect(x: 0, y: 0, width: 768, height: 768))
    let window = NSWindow(contentRect: view.frame, styleMask: [], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = view
    window.delegate = delegate
    delegate.window = window
    defer {
      view.audio.shutdown()
      window.delegate = nil
      window.orderOut(nil)
    }
    view.audio.update(flying)
    let playing = try #require(view.audio.players.first)
    try #require(playing.isPlaying)
    var docked = flying
    docked.docked = true
    var closingPlayer = playing
    try #require(!(await delegate.runtime.snapshot()).docked)
    var closedDuringFrame = false
    await delegate.processFrame(
      in: view,
      delta: {
        // This runs immediately before the actor advance. The frame resumes after close.
        view.audio.update(docked)
        // Leave audio docked: the genuine flying runtime frame must attempt a launch sound.
        closingPlayer = view.audio.players.last ?? playing
        #expect(closingPlayer.isPlaying)
        window.close()
        closedDuringFrame = true
        return 0.1
      })
    #expect(closedDuringFrame && !view.game.docked)
    #expect(view.audio.isShutdown && !closingPlayer.isPlaying)
    #expect(view.audio.players.isEmpty && !playing.isPlaying)
    await delegate.processFrame(in: view, delta: { 0.1 })
    #expect(view.audio.players.isEmpty && !playing.isPlaying)
  }

  @MainActor @Test func nativeApplicationTerminationStopsAudioAndIsIdempotent() throws {
    _ = NSApplication.shared
    let delegate = AppDelegate(restoreOnLaunch: false)
    let view = GameView(frame: NSRect(x: 0, y: 0, width: 768, height: 768))
    let window = NSWindow(contentRect: view.frame, styleMask: [], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = view
    delegate.window = window
    defer {
      view.audio.shutdown()
      window.delegate = nil
      window.orderOut(nil)
    }
    var flying = Game()
    flying.commander.speech = false
    flying.docked = false
    view.audio.update(flying)
    let playing = try #require(view.audio.players.first)
    try #require(playing.isPlaying)
    let notification = Notification(name: NSApplication.willTerminateNotification, object: NSApp)
    delegate.applicationWillTerminate(notification)
    delegate.applicationWillTerminate(notification)
    #expect(view.audio.isShutdown && view.audio.players.isEmpty && !playing.isPlaying)
    view.audio.update(Game())
    #expect(view.audio.players.isEmpty && !playing.isPlaying)
  }
}
