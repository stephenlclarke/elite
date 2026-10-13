import AppKit
import EliteCore
import ImageIO
import UniformTypeIdentifiers

@MainActor
final class GameView: NSView {
  var game = Game() {
    didSet {
      if !acceptsTrackpadFlight || game.spin.mode != oldValue.spin.mode { trackpad.reset() }
    }
  }
  let audio = AudioPresenter()
  var held: Set<String> = []
  var pressedKeys: [UInt16: String] = [:]
  var pending: [String] = []
  var trackpad = TrackpadInput()
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    allowedTouchTypes = .indirect
    wantsRestingTouches = true
  }
  required init?(coder _: NSCoder) { nil }
  private var acceptsTrackpadFlight: Bool {
    !game.docked && game.screen.isFlight && !game.paused && !game.dockingComputer
      && (window?.isKeyWindow ?? true)
  }
  func updateTrackpad(positions: [SIMD2<Double>]) {
    guard acceptsTrackpadFlight else {
      trackpad.reset()
      return
    }
    if let direction = trackpad.update(positions: positions, spinMode: game.spin.mode) {
      pending.append(direction == .clockwise ? "spin:cw" : "spin:ccw")
    }
  }
  private func updateTrackpad(with event: NSEvent) {
    let positions = event.touches(matching: .touching, in: self).filter { $0.type == .indirect }
      .map { SIMD2<Double>($0.normalizedPosition.x, $0.normalizedPosition.y) }
    updateTrackpad(positions: positions)
  }
  override func touchesBegan(with event: NSEvent) { updateTrackpad(with: event) }
  override func touchesMoved(with event: NSEvent) { updateTrackpad(with: event) }
  override func touchesEnded(with event: NSEvent) { updateTrackpad(with: event) }
  override func touchesCancelled(with _: NSEvent) {
    trackpad.reset()
    pending.append("spin-cancel")
  }
  override var acceptsFirstResponder: Bool { true }
  override var isFlipped: Bool { true }
  override func draw(_ _: NSRect) {
    NSColor.black.setFill()
    bounds.fill()
    let side = min(bounds.width, bounds.height)
    let rect = NSRect(
      x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    // Draw into the window's Retina context instead of enlarging an offscreen image.
    drawFrame(Display.render(game, rasterizeGraphics: false), context: context, rect: rect)
  }
  override func keyDown(with event: NSEvent) {
    let key = Self.key(event)
    held.insert(key)
    pressedKeys[event.keyCode] = key
    if !event.isARepeat { pending.append(key) }
  }
  override func keyUp(with event: NSEvent) {
    held.remove(pressedKeys.removeValue(forKey: event.keyCode) ?? Self.key(event))
  }
  override func mouseDown(with event: NSEvent) {
    guard game.screen == .chart else { return }
    let point = convert(event.locationInWindow, from: nil)
    let side = min(bounds.width, bounds.height)
    let x = Int((point.x - (bounds.width - side) / 2) / side * 256)
    let y = Int(((point.y - (bounds.height - side) / 2) / side * 256 - 30) * 2)
    pending.append("chart:\(x):\(y)")
  }
  var controls: Controls {
    var controls = Controls()
    controls.pitch = (held.contains("x") ? 1 : 0) - (held.contains("s") ? 1 : 0)
    controls.roll =
      (held.contains(",") || held.contains("<") ? 1 : 0)
      - (held.contains(".") || held.contains(">") ? 1 : 0)
    controls.throttle =
      (held.contains(" ") ? 1 : 0) - (held.contains("/") || held.contains("?") ? 1 : 0)
    controls.fire = held.contains("a")
    if acceptsTrackpadFlight {
      let touch = game.spin.mode ? trackpad.spinControls : trackpad.controls
      controls.pitch = max(-1, min(1, controls.pitch + touch.pitch))
      controls.roll = max(-1, min(1, controls.roll + touch.roll))
      controls.throttle = max(-1, min(1, controls.throttle + touch.throttle))
      controls.yaw = touch.yaw
      controls.spinContacts = touch.spinContacts
      controls.spinRecognition = touch.spinRecognition
    }
    if game.spin.mode {
      controls.yaw = max(
        -1,
        min(
          1,
          controls.yaw + (held.contains("right") ? 1 : 0)
            - (held.contains("left") ? 1 : 0)))
      controls.spinSlower = held.contains("-")
      controls.spinFaster = held.contains("=") || held.contains("+")
    }
    return controls
  }
  private static func key(_ event: NSEvent) -> String {
    switch event.keyCode {
    case 36: return "return"
    case 48: return "tab"
    case 53: return "escape"
    case 119: return "copy"
    case 123: return "left"
    case 124: return "right"
    case 125: return "down"
    case 126: return "up"
    default: return event.characters?.lowercased() ?? ""
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  var window: NSWindow?
  let runtime = GameRuntime()
  var loop: Task<Void, Never>?
  let saveURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
    ".xyzzy/elite/commander.json")
  func applicationDidFinishLaunching(_ _: Notification) {
    let view = GameView(frame: NSRect(x: 0, y: 0, width: 768, height: 768))
    let window = NSWindow(
      contentRect: view.frame, styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered, defer: false)
    window.title = "XYZZY Elite - Right-On Commander"
    window.contentView = view
    window.contentAspectRatio = NSSize(width: 1, height: 1)
    window.minSize = NSSize(width: 512, height: 540)
    window.delegate = self
    window.center()
    window.makeKeyAndOrderFront(nil)
    window.makeFirstResponder(view)
    self.window = window
    installMenu()
    NSApp.activate(ignoringOtherApps: true)
    let runtime = self.runtime
    loop = Task { [weak view] in
      var previousTick = ContinuousClock.now
      while !Task.isCancelled {
        guard let view else { return }
        let events = view.pending
        view.pending.removeAll()
        for event in events {
          if event.hasPrefix("chart:") {
            let parts = event.split(separator: ":")
            if let x = Int(parts[1]), let y = Int(parts[2]) {
              await runtime.selectSystem(x: x, y: y)
            }
          } else {
            await runtime.key(event)
          }
        }
        if !events.isEmpty { view.game = await runtime.snapshot() }
        await runtime.setControls(view.controls)
        let now = ContinuousClock.now
        let elapsed = previousTick.duration(to: now).components
        previousTick = now
        view.game = await runtime.advance(
          delta: Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18)
        view.audio.update(view.game)
        view.needsDisplay = true
        do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
      }
    }
  }
  func applicationShouldTerminateAfterLastWindowClosed(_ _: NSApplication) -> Bool { true }
  func applicationWillTerminate(_ notification: Notification) {
    windowWillClose(notification)
  }
  func windowWillClose(_ _: Notification) {
    loop?.cancel()
    loop = nil
  }
  func windowDidResignKey(_ _: Notification) {
    (window?.contentView as? GameView)?.held.removeAll()
    (window?.contentView as? GameView)?.pressedKeys.removeAll()
    (window?.contentView as? GameView)?.trackpad.reset()
    (window?.contentView as? GameView)?.pending.append("spin-cancel")
  }
  private func installMenu() {
    let menu = NSMenu()
    let app = NSMenuItem()
    menu.addItem(app)
    app.submenu = NSMenu()
    app.submenu?.addItem(
      withTitle: "Quit Elite", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    let commander = NSMenuItem()
    commander.title = "Commander"
    menu.addItem(commander)
    commander.submenu = NSMenu(title: "Commander")
    let save = commander.submenu?.addItem(
      withTitle: "Save Commander", action: #selector(saveCommander), keyEquivalent: "s")
    save?.target = self
    let load = commander.submenu?.addItem(
      withTitle: "Load Commander", action: #selector(loadCommander), keyEquivalent: "o")
    load?.target = self
    let game = NSMenuItem()
    game.title = "Game"
    menu.addItem(game)
    game.submenu = NSMenu(title: "Game")
    let pause = game.submenu?.addItem(
      withTitle: "Pause / Resume", action: #selector(togglePause), keyEquivalent: "p")
    pause?.target = self
    let spin = game.submenu?.addItem(
      withTitle: "Toggle Spin Hold", action: #selector(toggleSpin), keyEquivalent: "")
    spin?.target = self
    let stop = game.submenu?.addItem(
      withTitle: "Stop Spin", action: #selector(stopSpin), keyEquivalent: "")
    stop?.target = self
    let help = NSMenuItem()
    help.title = "Help"
    menu.addItem(help)
    help.submenu = NSMenu(title: "Help")
    let guide = help.submenu?.addItem(
      withTitle: "Player Key Guide", action: #selector(showHelp), keyEquivalent: "k")
    guide?.target = self
    NSApp.mainMenu = menu
  }
  @objc private func showHelp() {
    (window?.contentView as? GameView)?.pending.append("k")
  }
  @objc private func togglePause() {
    (window?.contentView as? GameView)?.pending.append("pause")
  }
  @objc private func toggleSpin() {
    (window?.contentView as? GameView)?.pending.append("v")
  }
  @objc private func stopSpin() {
    (window?.contentView as? GameView)?.pending.append("b")
  }
  @objc private func saveCommander() {
    Task { [weak self] in
      guard let self else { return }
      do { try await runtime.save(to: saveURL) } catch { show(error) }
    }
  }
  @objc private func loadCommander() {
    Task { [weak self] in
      guard let self else { return }
      do { try await runtime.load(from: saveURL) } catch { show(error) }
    }
  }
  private func show(_ error: Error) { NSAlert(error: error).runModal() }
}

@main
struct EliteApp {
  @MainActor static func main() async throws {
    if CommandLine.arguments.contains("--readme-media") {
      try media()
      return
    }
    if CommandLine.arguments.contains("--diagnostics") {
      try await diagnostics()
      return
    }
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.setActivationPolicy(.regular)
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
  }
  @MainActor private static func media() throws {
    try FileManager.default.createDirectory(atPath: "docs", withIntermediateDirectories: true)
    var game = Game()
    game.launch()
    game.bodies[1].position = .init(-35, 10, 320)
    guard let image = imageFor(Display.render(game, rasterizeGraphics: false), pixelSize: 768),
      let png = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: "docs/elite.png") as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw SaveError.invalidCommander }
    CGImageDestinationAddImage(png, image, nil)
    guard CGImageDestinationFinalize(png) else { throw SaveError.invalidCommander }
    guard
      let gif = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: "docs/start-sequence.gif") as CFURL, UTType.gif.identifier as CFString,
        48, nil)
    else { throw SaveError.invalidCommander }
    CGImageDestinationSetProperties(
      gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    game = Game()
    for index in 0..<48 {
      game.time = Double(index) / 6
      if index >= 16 { game.screen = .title }
      if index >= 24 { game.screen = .status }
      if index >= 30 {
        game.launch()
        game.bodies[1].position = .init(-35, 10, 320)
        game.time = Double(index) / 6
      }
      guard let image = imageFor(Display.render(game, rasterizeGraphics: false), pixelSize: 768)
      else {
        throw SaveError.invalidCommander
      }
      CGImageDestinationAddImage(
        gif, image,
        [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.16]] as CFDictionary)
    }
    guard CGImageDestinationFinalize(gif) else { throw SaveError.invalidCommander }
  }
  private static func diagnostics() async throws {
    for cycle in 0..<10 {
      let runtime = GameRuntime()
      await runtime.key("x")
      await runtime.key("y")
      await runtime.key("z")
      await runtime.key("z")
      await runtime.key("y")
      for _ in 0..<(cycle % 3) { await runtime.key("0") }
      await runtime.key("return")
      for _ in 0..<121 { _ = await runtime.advance(delta: 0.1) }
      await runtime.key(" ")
      await runtime.key("0")
      let spinMode = cycle % 2 == 0
      if spinMode {
        await runtime.key("v")
        await runtime.key("]")
        _ = await runtime.advance(delta: 0.01)
      }
      var trackpad = TrackpadInput()
      for frame in 0..<100 {
        if frame == 40 || frame == 50 { await runtime.key("k") }
        switch frame {
        case 0..<30: trackpad.update(positions: [.zero, .zero, .zero], spinMode: spinMode)
        case 30..<60:
          trackpad.update(positions: [.init(0.6, 0.7), .init(0.8, 0.9)], spinMode: spinMode)
        case 60..<80: trackpad.update(positions: [.init(0.5, 0.5)], spinMode: spinMode)
        default: trackpad.update(positions: [], spinMode: spinMode)
        }
        await runtime.setControls(spinMode ? trackpad.spinControls : trackpad.controls)
        let state = await runtime.advance(delta: 0.02)
        _ = await imageFor(Display.render(state, rasterizeGraphics: false), pixelSize: 512)
      }
    }
    for stage in NavalMissionStage.allCases {
      var game = Game()
      game.commander.missionStage = stage
      game.commander.galaxy = stage.rawValue >= 6 ? 2 : 0
      game.commander.kills = 1280
      game.dock()
      if game.screen != .mission {
        game.launch()
        game.bodies = [
          SpaceBody(id: 1, hull: .constrictor, position: .init(0, 0, 1200), hostile: true),
          SpaceBody(id: 2, hull: .thargoid, position: .init(100, 0, 1500), hostile: true),
          SpaceBody(id: 3, hull: .thargon, position: .init(-100, 0, 1000), hostile: true),
        ]
      }
      let runtime = GameRuntime(game: game)
      for frame in 0..<120 {
        if frame == 115 { await runtime.key("return") }
        let state = await runtime.advance(delta: 0.02)
        _ = await imageFor(Display.render(state, rasterizeGraphics: false), pixelSize: 512)
      }
    }
    print("Actor simulation and frame lifecycle probe passed")
  }
}
