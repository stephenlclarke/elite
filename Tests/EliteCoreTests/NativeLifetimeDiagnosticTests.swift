import AppKit
import Foundation
import Testing

@testable import EliteCore
@testable import EliteMac

// Diagnostic only: run this filtered test on an explicitly leased native runner.
// Weak liveness is evidence, not a release assertion or a diagnosis of the hosted crash.
@MainActor
private final class NativeLifetimeWitness {
  weak var delegate: AppDelegate?
  weak var window: NSWindow?
  weak var view: GameView?
  weak var audio: AudioPresenter?
  var loopJoined = false
  let identities: [String: String]

  init(delegate: AppDelegate, window: NSWindow, view: GameView) {
    self.delegate = delegate
    self.window = window
    self.view = view
    audio = view.audio
    identities = [
      "delegate": String(describing: ObjectIdentifier(delegate)),
      "window": String(describing: ObjectIdentifier(window)),
      "view": String(describing: ObjectIdentifier(view)),
      "audioPresenter": String(describing: ObjectIdentifier(view.audio)),
    ]
  }

  func write(_ phase: String, iteration: Int, directory: URL) throws {
    let value: [String: Any] = [
      "phase": phase, "iteration": iteration, "identities": identities,
      "mainThread": Thread.isMainThread, "uptime": ProcessInfo.processInfo.systemUptime,
      "delegateAlive": delegate != nil, "windowAlive": window != nil,
      "viewAlive": view != nil, "audioPresenterAlive": audio != nil,
      "loopJoined": loopJoined,
      "loopHandlePresent": delegate?.loop != nil,
      "loopCancelled": delegate?.loop?.isCancelled ?? false,
      "windowDelegatePresent": window?.delegate != nil,
      "contentViewPresent": window?.contentView != nil,
      "firstResponderPresent": window?.firstResponder != nil,
      "windowVisible": window?.isVisible ?? false,
    ]
    try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
      .write(to: directory.appendingPathComponent("cycle-\(iteration)-\(phase).json"))
  }
}

extension GameRuntime {
  fileprivate func installLifetimeDiagnosticScene(_ prepared: Game) throws {
    guard prepared.commander.valid, prepared.workGuidance == nil,
      prepared.workBraking == nil, prepared.approvedWorkMotion == nil,
      prepared.autoPilot.targetID == nil
    else { throw SaveError.invalidCommander }
    game = prepared
    setControls(.init())
  }
}

@MainActor
private func captureLifetimeFrame(_ view: GameView, destination: URL) throws {
  let width = Int(view.bounds.width)
  let height = Int(view.bounds.height)
  let context = try #require(
    CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8,
      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
  context.translateBy(x: 0, y: Double(height))
  context.scaleBy(x: 1, y: -1)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
  view.draw(view.bounds)
  NSGraphicsContext.restoreGraphicsState()
  let actual = try #require(context.makeImage())
  let expected = try #require(imageForGame(view.game, width: width, height: height, scale: 1))
  let actualBytes = try #require(actual.dataProvider?.data)
  let expectedBytes = try #require(expected.dataProvider?.data)
  #expect(CFEqual(actualBytes, expectedBytes))
  let png = try #require(
    NSBitmapImageRep(cgImage: actual).representation(using: .png, properties: [:]))
  try png.write(to: destination)
}

@MainActor
private func lifetimeDiagnosticCycle(_ iteration: Int, directory: URL) async throws
  -> NativeLifetimeWitness
{
  _ = NSApplication.shared
  let oldMenu = NSApp.mainMenu
  let identifier = "elite-native-lifetime-" + UUID().uuidString
  let preferences = try #require(UserDefaults(suiteName: identifier))
  let privateDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(identifier)
  let save = privateDirectory.appendingPathComponent("commander.json")
  try FileManager.default.createDirectory(at: privateDirectory, withIntermediateDirectories: true)
  var scene = Game(executive: false)
  try scene.commander.prepareEquipment(legacy: false)
  scene.launch()
  let bytes = try JSONEncoder().encode(scene.commander)
  try bytes.write(to: save)
  let delegate = AppDelegate(
    restoreOnLaunch: false,
    saves: CommanderSaveSession(preferences: preferences, defaultURL: save),
    windowSize: .init(width: 768, height: 768), windowFactory: nativeViewportTestWindow)
  var teardownFinished = false
  // Match NativeWorkFixture.close exactly; do not introduce a speculative lifetime fix.
  defer {
    if !teardownFinished {
      delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification))
      delegate.window?.orderOut(nil)
      delegate.window?.delegate = nil
      NSApp.mainMenu = oldMenu
    }
    preferences.removePersistentDomain(forName: identifier)
    try? FileManager.default.removeItem(at: privateDirectory)
  }
  delegate.applicationDidFinishLaunching(
    Notification(name: NSApplication.didFinishLaunchingNotification))
  do {
    let window = try #require(delegate.window)
    let view = try #require(window.contentView as? GameView)
    let witness = NativeLifetimeWitness(delegate: delegate, window: window, view: view)
    let loop = try #require(delegate.loop)
    try witness.write("opened", iteration: iteration, directory: directory)
    loop.cancel()
    await loop.value
    witness.loopJoined = true
    #expect(loop.isCancelled)
    try witness.write("joined", iteration: iteration, directory: directory)
    try await delegate.runtime.load(from: save, persistMigrations: false)
    try await delegate.runtime.installLifetimeDiagnosticScene(scene)
    window.setContentSize(.init(width: 768, height: 768))
    #expect(view.bounds.width == 768 && view.bounds.height == 768)
    await delegate.runtime.setViewport(width: view.bounds.width, height: view.bounds.height)
    view.game = await delegate.runtime.snapshot()
    view.pending.removeAll()
    await delegate.processFrame(in: view, delta: { 1.0 / 60 })
    #expect(!view.game.docked && view.pending.isEmpty && !view.controls.fire)
    try captureLifetimeFrame(
      view, destination: directory.appendingPathComponent("cycle-\(iteration)-original-native.png"))
    let savedBytes = try Data(contentsOf: save)
    #expect(savedBytes == bytes)
    #expect(delegate.saves.activeURL == save)
    #expect(preferences.persistentDomain(forName: identifier) == nil)
    try witness.write("framed-audio-updated-drawn", iteration: iteration, directory: directory)
    // Explicit teardown permits a receipt while locals still hold their original strong references.
    delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification))
    window.orderOut(nil)
    window.delegate = nil
    NSApp.mainMenu = oldMenu
    teardownFinished = true
    try witness.write("torn-down-before-local-release", iteration: iteration, directory: directory)
    return witness
  } catch {
    if let loop = delegate.loop {
      loop.cancel()
      await loop.value
    }
    throw error
  }
}

extension NativeViewTests {
  @MainActor @Test func nativeLifetimeDiagnosticOpenJoinFrameDrawTeardown() async throws {
    let environment = ProcessInfo.processInfo.environment
    let parent =
      environment["ELITE_NATIVE_LIFETIME_ARTIFACT_DIRECTORY"].map {
        URL(fileURLWithPath: $0, isDirectory: true)
      } ?? FileManager.default.temporaryDirectory
    let directory = parent.appendingPathComponent("native-lifetime-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let metadata: [String: Any] = [
      "diagnostic": true, "productionBase": "a804f245c4baf3668b22393206a43a048465739a",
      "source": environment["ELITE_VALIDATION_SOURCE_SHA"] ?? "unprovided",
      "pid": ProcessInfo.processInfo.processIdentifier,
      "os": ProcessInfo.processInfo.operatingSystemVersionString,
      "process": ProcessInfo.processInfo.processName,
      "arguments": ProcessInfo.processInfo.arguments,
      "iterations": 3, "artifactDirectory": directory.path,
      "audioObservation": "Presenter lifetime only; private playback internals are not observed.",
      "crashReports": "Runner must collect process-matched .ips reports after process termination.",
      "equivalence": "Local macOS 27 is not hosted macOS 15/Xcode 16.4 reproduction evidence.",
    ]
    try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
      .write(to: directory.appendingPathComponent("process.json"))
    print("ELITE_NATIVE_LIFETIME_ARTIFACT_DIRECTORY=\(directory.path)")
    for iteration in 0..<3 {
      let witness = try await lifetimeDiagnosticCycle(iteration, directory: directory)
      try witness.write("returned-after-local-release", iteration: iteration, directory: directory)
      // Yield to AppKit's main run loop without a synchronous nested run loop or lifetime assertion.
      for turn in 0..<3 {
        try await Task.sleep(for: .milliseconds(20))
        try witness.write("runloop-turn-\(turn)", iteration: iteration, directory: directory)
      }
    }
  }
}
