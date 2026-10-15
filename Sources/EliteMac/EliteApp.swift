import AppKit
import EliteCore
import ImageIO
import UniformTypeIdentifiers

@MainActor
final class GameView: NSView {
  var game = Game() {
    didSet {
      if game.autoPilot.targetID != oldValue.autoPilot.targetID, game.autoPilot.targetID != nil {
        clearSteeringInput()
        if game.dockingComputer {
          held.removeAll()
          pressedKeys.removeAll()
        }
      }
      if game.screen != oldValue.screen || game.paused != oldValue.paused
        || game.acceptsTextInput != oldValue.acceptsTextInput
      {
        held.removeAll()
        pressedKeys.removeAll()
        trackpad.reset()
      }
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
  override var wantsUpdateLayer: Bool { true }
  override func updateLayer() {
    let scale = (window?.backingScaleFactor ?? 1) >= 2 ? 2 : 1
    guard
      let image = imageForGame(
        game, width: Int(bounds.width), height: Int(bounds.height), scale: scale)
    else { return }
    layer?.contentsScale = CGFloat(scale)
    layer?.contents = image
  }
  override func draw(_ _: NSRect) {
    NSColor.black.setFill()
    bounds.fill()
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    drawGame(game, context: context, rect: bounds)
  }
  private func clearSteeringInput() {
    held.subtract(["x", "s", ",", "<", ".", ">", "left", "right", "up", "down"])
    trackpad.reset()
  }
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if event.modifierFlags.contains(.command), event.keyCode == 51,
      [.chart, .showroom].contains(game.screen)
    {
      pending.append("search-clear")
      return true
    }
    return super.performKeyEquivalent(with: event)
  }
  override func keyDown(with event: NSEvent) {
    let key = Self.key(event)
    if event.modifierFlags.contains(.command), event.keyCode == 51,
      [.chart, .showroom].contains(game.screen)
    {
      pending.append("search-clear")
      return
    }
    if !event.modifierFlags.intersection([.command, .control]).isEmpty { return }
    if ["r", "tab"].contains(key) && !event.isARepeat && game.screen.isFlight {
      clearSteeringInput()
    }
    if game.screen.isFlight && !game.paused {
      held.insert(key)
      pressedKeys[event.keyCode] = key
    }
    let repeatNavigation =
      !game.screen.isFlight && ["up", "down", "left", "right", "pageup", "pagedown"].contains(key)
    let repeatText = game.acceptsTextInput && (key.count == 1 || key == "backspace")
    if !event.isARepeat || repeatNavigation || repeatText { pending.append(key) }
  }
  override func keyUp(with event: NSEvent) {
    held.remove(pressedKeys.removeValue(forKey: event.keyCode) ?? Self.key(event))
  }
  override func mouseDown(with event: NSEvent) {
    if [.market, .buy, .sell].contains(game.screen) {
      let point = convert(event.locationInWindow, from: nil)
      pending.append("market-click:\(point.x):\(point.y)")
      return
    }
    if game.screen == .secret {
      let point = convert(event.locationInWindow, from: nil)
      pending.append("secret-click:\(point.x):\(point.y)")
      return
    }
    if game.screen == .showroom {
      let point = convert(event.locationInWindow, from: nil)
      pending.append("showroom-click:\(point.x):\(point.y)")
      let layout = ShowroomLayout(
        width: bounds.width, height: bounds.height, detail: game.showroom.detail)
      if !game.showroom.trading && layout.list.contains(.init(point.x, point.y))
        && event.clickCount >= 2
      {
        pending.append("return")
      }
      return
    }
    if game.screen == .handoff {
      let point = convert(event.locationInWindow, from: nil)
      pending.append("handoff-click:\(point.x):\(point.y)")
      return
    }
    if game.screen == .equipment {
      let point = convert(event.locationInWindow, from: nil)
      pending.append("equipment-click:\(point.x):\(point.y)")
      return
    }
    if game.screen == .gallery {
      let point = convert(event.locationInWindow, from: nil)
      pending.append("gallery-click:\(point.x):\(point.y)")
      return
    }
    guard game.screen == .chart || game.screen == .shortChart else { return }
    let point = convert(event.locationInWindow, from: nil)
    pending.append("map-click:\(point.x):\(point.y)")
  }
  override func scrollWheel(with event: NSEvent) {
    if game.screen == .handoff {
      pending.append(event.scrollingDeltaY > 0 ? "pageup" : "pagedown")
      return
    }
    if [.secret, .system, .status, .inventory, .market, .buy, .sell].contains(game.screen) {
      pending.append(event.scrollingDeltaY > 0 ? "up" : "down")
    }
    if game.screen == .showroom && game.showroom.trading {
      pending.append(event.scrollingDeltaY > 0 ? "up" : "down")
      return
    }
    if game.screen == .showroom {
      let point = convert(event.locationInWindow, from: nil)
      let layout = ShowroomLayout(
        width: bounds.width, height: bounds.height, detail: game.showroom.detail)
      let region =
        layout.listVisible && layout.list.contains(.init(point.x, point.y)) ? "list" : "scroll"
      pending.append("showroom-\(region):\(event.scrollingDeltaY > 0 ? -1 : 1)")
    }
    if game.screen == .equipment {
      pending.append("equipment-scroll:\(event.scrollingDeltaY > 0 ? -1 : 1)")
    }
    if game.screen == .navigation {
      pending.append("route-scroll:\(event.scrollingDeltaY > 0 ? -1 : 1)")
    }
    if game.docked && [.chart, .shortChart].contains(game.screen) && !game.mapSearch.active {
      pending.append(event.scrollingDeltaY > 0 ? "up" : "down")
    }
    if game.mapSearch.active { pending.append("map-scroll:\(event.scrollingDeltaY > 0 ? -1 : 1)") }
    if game.screen == .gallery {
      pending.append("gallery-scroll:\(event.scrollingDeltaY > 0 ? -1 : 1)")
    }
  }
  var controls: Controls {
    var controls = Controls()
    if !game.screen.isFlight || game.paused {
      return controls
    }
    controls.pitch =
      (held.contains("up") || held.contains("x") ? 1 : 0)
      - (held.contains("down") || held.contains("s") ? 1 : 0)
    controls.roll =
      (held.contains(",") || held.contains("<") || (!game.spin.mode && held.contains("left"))
        ? 1 : 0)
      - (held.contains(".") || held.contains(">") || (!game.spin.mode && held.contains("right"))
        ? 1 : 0)
    controls.throttle =
      (held.contains(" ") ? 1 : 0)
      - (held.contains("backspace") || held.contains("/") || held.contains("?") ? 1 : 0)
    controls.fire = held.contains("return") || held.contains("a")
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
    if event.modifierFlags.contains(.option) {
      if event.keyCode == 126 { return "pageup" }
      if event.keyCode == 125 { return "pagedown" }
    }
    switch event.keyCode {
    case 51: return "backspace"
    case 36: return "return"
    case 48: return "tab"
    case 53: return "escape"
    case 117: return "delete"
    case 119: return "copy"
    case 116: return "pageup"
    case 121: return "pagedown"
    case 123: return "left"
    case 124: return "right"
    case 125: return "down"
    case 126: return "up"
    default: return event.characters?.lowercased() ?? ""
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate,
  NSMenuItemValidation
{
  var window: NSWindow?
  let runtime = GameRuntime()
  var loop: Task<Void, Never>?
  let saves: CommanderSaveSession
  let windowSize: NSSize
  let restoreOnLaunch: Bool
  var saveURL: URL { saves.activeURL }
  init(
    restoreOnLaunch: Bool = true, saves: CommanderSaveSession? = nil,
    windowSize: NSSize = .init(width: 768, height: 768)
  ) {
    self.windowSize = windowSize
    self.restoreOnLaunch = restoreOnLaunch
    self.saves = saves ?? CommanderSaveSession()
    super.init()
  }
  func applicationDidFinishLaunching(_ _: Notification) {
    let view = GameView(frame: NSRect(origin: .zero, size: windowSize))
    view.wantsLayer = true
    let window = NSWindow(
      contentRect: view.frame, styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered, defer: false)
    window.title = "XYZZY Elite - Right-On Commander"
    window.contentView = view
    window.minSize = NSSize(width: 512, height: 540)
    window.delegate = self
    window.center()
    window.makeKeyAndOrderFront(nil)
    window.makeFirstResponder(view)
    self.window = window
    installMenu()
    NSApp.activate(ignoringOtherApps: true)
    let runtime = self.runtime
    loop = Task { [weak view, weak self] in
      guard !Task.isCancelled else { return }
      await runtime.loadMissionPacks()
      let packErrors = await runtime.snapshot().missionPacks.errors
      guard !Task.isCancelled else { return }
      if !packErrors.isEmpty {
        let alert = NSAlert()
        alert.messageText = "Some mission packs could not be enabled"
        alert.informativeText = packErrors.joined(separator: "\n")
        alert.runModal()
      }
      if let self, self.restoreOnLaunch, let url = self.saves.startupURL {
        do {
          try await runtime.restoreStartup(from: url)
          guard !Task.isCancelled else { return }
          view?.game = await runtime.snapshot()
        } catch {
          guard !Task.isCancelled else { return }
          await self.recoverStartup(error, url: url)
        }
      }
      var previousTick = ContinuousClock.now
      while !Task.isCancelled {
        guard let view else { return }
        if let self {
          await self.processFrame(in: view) {
            let now = ContinuousClock.now
            let elapsed = previousTick.duration(to: now).components
            previousTick = now
            return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
          }
        } else {
          return
        }
        do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
      }
    }
  }
  func processFrame(in view: GameView, delta: () -> Double) async {
    await processPendingCommands(in: view)
    await runtime.setViewport(width: view.bounds.width, height: view.bounds.height)
    await runtime.setControls(view.controls)
    view.game = await runtime.advance(delta: delta())
    view.audio.update(view.game)
    view.needsDisplay = true
  }
  // The frame loop and native integration checks share one ordered command batch.
  // Awaiting this method acknowledges actual processing instead of elapsed time.
  func processPendingCommands(in view: GameView) async {
    let events = view.pending
    view.pending.removeAll()
    for event in events {
      if event.hasPrefix("commander-save:") {
        let url = URL(fileURLWithPath: String(event.dropFirst("commander-save:".count)))
        do {
          try await runtime.save(to: url)
          self.saves.didSave(to: url)
        } catch { self.show(error) }
      } else if event.hasPrefix("market-click:") {
        let values = event.dropFirst(13).split(separator: ":").compactMap { Double($0) }
        if values.count == 2 { await runtime.marketClick(x: values[0], y: values[1]) }
      } else if event.hasPrefix("secret-click:") {
        let values = event.dropFirst(13).split(separator: ":").compactMap { Double($0) }
        if values.count == 2 { await runtime.secretClick(x: values[0], y: values[1]) }
      } else if event.hasPrefix("showroom-click:") {
        let values = event.dropFirst(15).split(separator: ":").compactMap { Double($0) }
        if values.count == 2 { await runtime.showroomClick(x: values[0], y: values[1]) }
      } else if event.hasPrefix("handoff-click:") {
        let values = event.dropFirst(14).split(separator: ":").compactMap { Double($0) }
        if values.count == 2 { await runtime.blackjackHandoffClick(x: values[0], y: values[1]) }
      } else if event.hasPrefix("equipment-click:") {
        let values = event.dropFirst(16).split(separator: ":").compactMap { Double($0) }
        if values.count == 2 { await runtime.equipmentClick(y: values[1], x: values[0]) }
      } else if event.hasPrefix("map-click:") {
        let parts = event.split(separator: ":")
        if parts.count == 3, let x = Double(parts[1]), let y = Double(parts[2]) {
          await runtime.mapClick(x: x, y: y)
        }
      } else if event.hasPrefix("gallery-click:") {
        let parts = event.split(separator: ":")
        if parts.count == 3, let x = Double(parts[1]), let y = Double(parts[2]) {
          await runtime.galleryClick(x: x, y: y)
        }
      } else if event.hasPrefix("chart:") {
        let parts = event.split(separator: ":")
        if let x = Int(parts[1]), let y = Int(parts[2]) {
          await runtime.selectSystem(x: x, y: y)
        }
      } else {
        await runtime.key(event)
      }
    }
    if !events.isEmpty { view.game = await runtime.snapshot() }
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
    let open = commander.submenu?.addItem(
      withTitle: "Open Commander...", action: #selector(chooseCommander), keyEquivalent: "o")
    open?.keyEquivalentModifierMask = [.command, .shift]
    open?.target = self
    let saveAs = commander.submenu?.addItem(
      withTitle: "Save Commander As...", action: #selector(saveCommanderAs), keyEquivalent: "s")
    saveAs?.keyEquivalentModifierMask = [.command, .shift]
    saveAs?.target = self
    let installPack = commander.submenu?.addItem(
      withTitle: "Install Mission Pack...", action: #selector(installMissionPack), keyEquivalent: ""
    )
    installPack?.target = self
    let screens = NSMenuItem()
    screens.title = "Screens"
    menu.addItem(screens)
    screens.submenu = NSMenu(title: "Screens")
    screens.submenu?.delegate = self
    for number in 0...9 {
      let item = screens.submenu?.addItem(
        withTitle: Game.screenTitle(number, docked: true),
        action: #selector(gameAction(_:)), keyEquivalent: "")
      item?.representedObject = "screen:\(number)"
      item?.tag = number
      item?.target = self
    }
    let flight = NSMenuItem()
    flight.title = "Flight"
    menu.addItem(flight)
    flight.submenu = NSMenu(title: "Flight")
    let flightActions = [
      ("Next Target", "tab"), ("Cancel Automatic Guidance", "q"),
      ("Hyperspace to Selected System", "h"), ("In-system Jump", "j"),
      ("Galactic Hyperdrive", "g"), ("Activate ECM", "e"),
      ("Arm Missile", "t"), ("Disarm Missile", "u"), ("Fire Missile", "m"),
      ("Detonate Energy Bomb", "energy-bomb"), ("Launch Escape Pod", "escape-pod"),
    ]
    for (title, command) in flightActions {
      let item = flight.submenu?.addItem(
        withTitle: title, action: #selector(gameAction(_:)),
        keyEquivalent: command == "escape-pod" ? "e" : "")
      if command == "escape-pod" { item?.keyEquivalentModifierMask = [.command, .shift] }
      item?.representedObject = command
      item?.target = self
    }
    let game = NSMenuItem()
    game.title = "Game"
    menu.addItem(game)
    game.submenu = NSMenu(title: "Game")
    for (title, command) in [
      ("Mission Gallery", "gallery-open"), ("Mission Contacts", "contacts-open"),
      ("Station Rumours", "rumours-open"),
    ] {
      let item = game.submenu?.addItem(
        withTitle: title, action: #selector(gameAction(_:)), keyEquivalent: "")
      item?.representedObject = command
      item?.target = self
    }
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
  func menuNeedsUpdate(_ menu: NSMenu) {
    guard menu.title == "Screens", let view = window?.contentView as? GameView else { return }
    for item in menu.items {
      item.isHidden = Game.numberedScreen(item.tag, docked: view.game.docked) == nil
      item.title = "\(item.tag): " + Game.screenTitle(item.tag, docked: view.game.docked)
    }
  }
  func validateMenuItem(_ item: NSMenuItem) -> Bool {
    guard let game = (window?.contentView as? GameView)?.game else { return false }
    if let command = item.representedObject as? String {
      if command.hasPrefix("screen:"), let number = Int(command.dropFirst(7)) {
        return Game.numberedScreen(number, docked: game.docked) != nil && !game.paused
          && !game.showroom.trading
          && ![Screen.help, .secret, .mission, .handoff, .demo, .title, .gameOver].contains(
            game.screen)
      }
      if item.menu?.title == "Flight" {
        return !game.docked && game.screen.isFlight && !game.paused
          && flightActionAvailable(command, game: game)
      }
      if command == "contacts-open" || command == "rumours-open" || command == "gallery-open" {
        return !game.paused && !game.acceptsTextInput
          && ![
            Screen.demo, .title, .gameOver, .secret, .help, .mission, .handoff, .showroom, .gallery,
          ].contains(game.screen)
          && (command == "gallery-open" || game.docked)
      }
    }
    if item.action == #selector(togglePause) {
      return ![
        Screen.demo, .title, .gameOver, .help, .gallery, .showroom, .mission, .handoff, .navigation,
        .rumour,
      ].contains(game.screen)
    }
    if item.action == #selector(toggleSpin) || item.action == #selector(stopSpin) {
      return !game.docked && game.screen.isFlight && !game.paused
    }
    return true
  }
  private func flightActionAvailable(_ command: String, game: Game) -> Bool {
    switch command {
    case "e": return game.commander.equipment.contains("E.C.M. System")
    case "g": return game.commander.equipment.contains("Galactic Hyperdrive")
    case "energy-bomb": return game.commander.equipment.contains("Energy Bomb")
    case "escape-pod": return game.commander.equipment.contains("Escape Pod")
    case "t", "m": return game.commander.missiles > 0 || game.commander.unlimitedMissiles
    case "j": return !game.massLocked
    default: return true
    }
  }
  @objc private func gameAction(_ sender: NSMenuItem) {
    guard let command = sender.representedObject as? String else { return }
    (window?.contentView as? GameView)?.pending.append(command)
  }
  @objc private func showHelp() {
    (window?.contentView as? GameView)?.pending.append("help-open")
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
    queueCommanderSave(to: saveURL)
  }
  private func queueCommanderSave(to url: URL) {
    // Preserve input order: a fast Save must include the preceding confirmation/refit.
    (window?.contentView as? GameView)?.pending.append("commander-save:" + url.path)
  }
  @objc private func installMissionPack() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [UTType(filenameExtension: "toml") ?? .plainText]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    Task { [weak self] in
      guard let self else { return }
      do { try await runtime.installMissionPack(from: url) } catch { show(error) }
    }
  }
  @objc private func loadCommander() {
    Task { [weak self] in
      guard let self else { return }
      do { try await runtime.load(from: saveURL) } catch { show(error) }
    }
  }
  @objc private func chooseCommander() {
    Task { [weak self] in await self?.openChosenCommander() }
  }
  private func openChosenCommander() async {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.json]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      try await runtime.load(from: url, persistMigrations: false)
      saves.activeURL = url
    } catch { show(error) }
  }
  @objc private func saveCommanderAs() {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.json]
    panel.nameFieldStringValue = "commander.json"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    queueCommanderSave(to: url)
  }
  private func recoverStartup(_ error: Error, url: URL) async {
    let alert = NSAlert()
    alert.messageText = "Your last commander could not be restored"
    alert.informativeText =
      "The saved file at \(url.path) is missing, inaccessible or invalid. It has not been changed. Choose another save or start a new Commander Jameson. \(error.localizedDescription)"
    alert.addButton(withTitle: "Choose Save")
    alert.addButton(withTitle: "Start New")
    if alert.runModal() == .alertFirstButtonReturn { await openChosenCommander() }
  }
  private func show(_ error: Error) { NSAlert(error: error).runModal() }
}

@main
struct EliteApp {
  @MainActor static func main() async throws {
    if let index = CommandLine.arguments.firstIndex(of: "--validate-mission-pack") {
      guard CommandLine.arguments.indices.contains(index + 1) else {
        throw MissionPackErrorCLI.missingPath
      }
      let entry = try MissionPackLibrary.read(
        URL(fileURLWithPath: CommandLine.arguments[index + 1]))
      _ = try MissionPackLibrary.checked(MissionPackLibrary.bundled.entries + [entry])
      print("Valid mission pack: \(entry.pack.stateID) @ \(entry.pack.version)")
      return
    }
    if let index = CommandLine.arguments.firstIndex(of: "--ship-media") {
      let ids = Array(CommandLine.arguments.dropFirst(index + 1))
      try exportShipMedia(ids: ids, directory: URL(fileURLWithPath: "docs/ships"))
      try exportShipOverview(directory: URL(fileURLWithPath: "docs/ships"))
      return
    }
    if CommandLine.arguments.contains("--readme-media") {
      try media()
      return
    }
    if CommandLine.arguments.contains("--diagnostics") {
      try await diagnostics()
      return
    }
    let app = NSApplication.shared
    let sizeArgument = CommandLine.arguments.first { $0.hasPrefix("--window-size=") }
    let dimensions =
      sizeArgument?.dropFirst(14).split(separator: "x").compactMap { Double($0) } ?? []
    let size =
      dimensions.count == 2
      ? NSSize(
        width: max(512, min(3600, dimensions[0])), height: max(518, min(2160, dimensions[1])))
      : NSSize(width: 768, height: 768)
    let delegate = AppDelegate(windowSize: size)
    app.setActivationPolicy(.regular)
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
  }
  @MainActor private static func media() throws {
    try exportAppIcon()
    try FileManager.default.createDirectory(atPath: "docs", withIntermediateDirectories: true)
    var game = Game()
    game.launch()
    game.bodies[1].position = .init(-35, 10, 320)
    guard let image = imageForGame(game, width: 1024, height: 768),
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
      guard let image = imageForGame(game, width: 1024, height: 768)
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
        _ = await imageForGame(state, width: cycle % 2 == 0 ? 1280 : 512, height: 720)
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
        _ = await imageForGame(state, width: 1024, height: 720)
      }
    }
    for cycle in 0..<10 {
      var game = Game(executive: false)
      game.commander.galaxy = 1
      game.systems = Universe.galaxy(number: 1)
      game.commander.system = 241
      game.dock()
      let runtime = GameRuntime(game: game)
      for key in ["k", "k", "return", "l", "down", "down", "return", "l"] {
        await runtime.key(key)
        let state = await runtime.advance(delta: 0.02)
        _ = await imageForGame(state, width: cycle % 2 == 0 ? 1280 : 512, height: 720)
      }
      game.key("return")
      game.selectedSystem = 88
      game.docked = false
      game.arrive()
      let encounter = GameRuntime(game: game)
      for _ in 0..<120 {
        let state = await encounter.advance(delta: 0.02)
        _ = await imageForGame(state, width: 1024, height: 720)
      }
    }
    for cycle in 0..<8 {
      var game = Game(executive: false)
      game.screen = .status
      let runtime = GameRuntime(game: game)
      for key in [
        "showroom-open", "down", "b", "down", "return", "v", ".", "pagedown", " ", "k", "k",
        "escape",
        "4", "]", "/", "l", "a", "return", "6", "4", "o", "8", "u", "return",
      ] {
        await runtime.key(key)
        let state = await runtime.advance(delta: 0.02)
        _ = await imageForGame(state, width: cycle % 2 == 0 ? 1280 : 512, height: 720)
      }
    }
    print("Actor simulation and frame lifecycle probe passed")
  }
}

enum MissionPackErrorCLI: Error { case missingPath }
