import AppKit
import EliteCore
import ImageIO
import UniformTypeIdentifiers

@MainActor
final class GameView: NSView {
  var game = Game()
  let audio = AudioPresenter()
  var held: Set<String> = []
  var pressedKeys: [UInt16: String] = [:]
  var pending: [String] = []
  override var acceptsFirstResponder: Bool { true }
  override var isFlipped: Bool { true }
  override func draw(_ _: NSRect) {
    NSColor.black.setFill()
    bounds.fill()
    guard
      let image = imageFor(
        Display.render(game, rasterizeShips: false),
        scale: max(1, Int(min(bounds.width, bounds.height) / 256)))
    else { return }
    let side = min(bounds.width, bounds.height)
    let rect = NSRect(
      x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    context.interpolationQuality = .none
    context.saveGState()
    context.translateBy(x: rect.minX, y: rect.maxY)
    context.scaleBy(x: 1, y: -1)
    context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
    context.restoreGState()
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
func imageFor(_ frame: Frame, scale: Int = 1) -> CGImage? {
  let rgba = frame.pixels.map { $0.bigEndian }
  let data = rgba.withUnsafeBytes { Data($0) }
  guard let provider = CGDataProvider(data: data as CFData) else { return nil }
  guard
    let bitmap = CGImage(
      width: 256, height: 256, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 1024,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
      provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
  else { return nil }
  guard !frame.rasterizeShips else { return bitmap }
  let size = 256 * max(1, min(scale, 8))
  guard
    let context = CGContext(
      data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  else { return nil }
  context.interpolationQuality = .none
  context.draw(bitmap, in: CGRect(x: 0, y: 0, width: size, height: size))
  context.translateBy(x: 0, y: Double(size))
  context.scaleBy(x: Double(size) / 256, y: -Double(size) / 256)
  context.setShouldAntialias(true)
  context.setAllowsAntialiasing(true)
  context.setLineWidth(0.75)
  context.setLineJoin(.round)
  context.setLineCap(.round)
  for panel in frame.shipPanels {
    guard let first = panel.vertices.first else { continue }
    context.setFillColor(shipColour(panel.colour))
    // Overlap adjoining fills slightly so antialiasing cannot leave dark cracks.
    context.setStrokeColor(shipColour(panel.colour))
    context.setLineWidth(0.35)
    context.beginPath()
    context.move(to: CGPoint(x: first.x, y: first.y))
    for point in panel.vertices.dropFirst() { context.addLine(to: CGPoint(x: point.x, y: point.y)) }
    context.closePath()
    context.drawPath(using: .fillStroke)
  }
  context.setLineWidth(0.75)
  for line in frame.shipLines {
    context.setStrokeColor(shipColour(line.ink.rawValue))
    context.beginPath()
    context.move(to: CGPoint(x: line.x0, y: line.y0))
    context.addLine(to: CGPoint(x: line.x1, y: line.y1))
    context.strokePath()
  }
  return context.makeImage()
}

private func shipColour(_ rgba: UInt32) -> CGColor {
  CGColor(
    red: Double((rgba >> 24) & 255) / 255, green: Double((rgba >> 16) & 255) / 255,
    blue: Double((rgba >> 8) & 255) / 255, alpha: 1)
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
    window.title = "Elite - Executive Edition"
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
    guard let image = imageFor(Display.render(game, rasterizeShips: false), scale: 3),
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
      guard let image = imageFor(Display.render(game, rasterizeShips: false), scale: 3) else {
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
      for frame in 0..<100 {
        if frame == 40 || frame == 50 { await runtime.key("k") }
        let state = await runtime.advance(delta: 0.02)
        _ = await imageFor(Display.render(state, rasterizeShips: false), scale: 2)
      }
    }
    print("Actor simulation and frame lifecycle probe passed")
  }
}
