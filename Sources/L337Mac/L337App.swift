import AppKit
import ImageIO
import L337Core
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
        || game.inventoryContextEpoch != oldValue.inventoryContextEpoch
        || game.acceptsTextInput != oldValue.acceptsTextInput
      {
        held.removeAll()
        pressedKeys.removeAll()
        trackpad.reset()
      }
      if !acceptsTrackpadFlight {
        trackpad.reset()
      } else if game.spin.mode != oldValue.spin.mode {
        trackpad.setSpinMode(game.spin.mode)
      }
      modelInventoryInputGeneration = processedInventoryInputGeneration
    }
  }
  private var displayedScriptPage: ScriptPagePresentation?
  private var displayedScriptPageSize: NSSize?
  var paintedMissionMenuPresentation: ScriptPagePresentation? {
    guard displayedScriptPageSize == bounds.size else { return nil }
    return displayedScriptPage
  }
  let shipPanelRenderer = ShipPanelRenderer()
  var frameProfile: PlanetFrameProfiler?
  var profileSubmittedFrame: UInt64?
  let audio = AudioPresenter()
  var held: Set<String> = []
  var pressedKeys: [UInt16: String] = [:]
  var pending: [String] = []
  var pendingInventoryCommands: [InventoryCommand] = []
  var pendingEquipmentPurchases: [EquipmentPurchaseContext] = []
  var pendingPassengerBerthFittings: [PassengerBerthFittingIntent] = []
  var pendingCommanderFiles: [NativeCommanderFileIntent] = []
  var pendingMissionUI: [MissionUIIntent] = []
  private(set) var inventoryInputGeneration: UInt64 = 0
  var processedInventoryInputGeneration: UInt64 = 0
  private var modelInventoryInputGeneration: UInt64 = 0
  private var paintedInventoryInputGeneration: UInt64 = 0
  private(set) var paintedInventoryInteraction: InventoryInteraction?
  private var paintedInventoryState: InventoryPaintState?
  private var paintedPurchaseContext: EquipmentPurchaseContext?
  private var paintedPurchaseBounds: NSRect?
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
  override var isOpaque: Bool { true }
  override func draw(_ _: NSRect) {
    NSColor.black.setFill()
    bounds.fill()
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    let snapshot = game
    let presentationStart = frameProfile == nil ? nil : ContinuousClock.now
    let frame = Display.presentation(snapshot, width: bounds.width, height: bounds.height)
    let drawStart = frameProfile == nil ? nil : ContinuousClock.now
    let startup = snapshot.screen == .title || snapshot.screen == .demo
    let panels = drawFrame(
      frame, context: context, rect: bounds, panelRenderer: startup ? shipPanelRenderer : nil)
    if let presentationStart, let drawStart {
      let now = ContinuousClock.now
      frameProfile?.drew(
        in: self, id: profileSubmittedFrame, frame: frame,
        presentation: PlanetFrameProfiler.elapsed(presentationStart, drawStart),
        drawing: PlanetFrameProfiler.elapsed(drawStart, now), at: now,
        panelBackend: startup ? panels.backendDescription : nil)
    }
    paintedInventoryInteraction = frame.inventoryInteraction
    paintedInventoryState = frame.inventoryInteraction.map { _ in
      InventoryPaintState(game: snapshot, bounds: bounds)
    }
    paintedInventoryInputGeneration = modelInventoryInputGeneration
    paintedPurchaseContext = snapshot.equipmentPurchaseContext
    paintedPurchaseBounds = paintedPurchaseContext == nil ? nil : bounds
    var painted = snapshot
    if [.gallery, .contracts].contains(painted.screen) {
      painted.viewportWidth = Double(bounds.width)
      painted.viewportHeight = Double(bounds.height)
    }
    displayedScriptPage = painted.scriptPagePresentation
    displayedScriptPageSize = bounds.size
  }
  private struct InventoryPaintState: Equatable {
    let context: InventoryContextEpoch
    let bounds: NSRect
    let screen: Screen
    let scroll: Int
    let selection: Int
    let upgrade: Int
    let mount: LaserMount
    let tool: Bool
    let ship: String
    let owner: UUID?
    let hull: UUID?
    let ownedRevision: UInt64?
    let sourceRevision: UInt64
    init(game: Game, bounds: NSRect) {
      context = game.inventoryContextEpoch
      self.bounds = bounds
      screen = game.screen
      scroll = game.informationScroll
      selection = game.inventoryActionSelection
      upgrade = game.inventoryUpgradeChoice
      mount = game.equipmentMount
      tool = game.equipmentWorkTool
      ship = game.commander.shipID
      owner = game.commander.equipmentOwnerID
      hull = game.commander.hullInstanceID
      ownedRevision = game.commander.equipmentInventory?.revision
      sourceRevision = game.commander.salvageLedger.revision
    }
  }
  private func queuePaintedInventoryCommand(at point: SIMD2<Double>? = nil) {
    guard pendingInventoryCommands.count < 64,
      inventoryInputGeneration == paintedInventoryInputGeneration,
      paintedInventoryState == InventoryPaintState(game: game, bounds: bounds),
      let presentation = paintedInventoryInteraction
    else {
      needsDisplay = true
      return
    }
    let command: InventoryCommand?
    if let point {
      command = presentation.command(at: point)
    } else {
      command = presentation.primary
    }
    guard let command else { return }
    pendingInventoryCommands.append(command)
    pending.append("inventory-command")
  }
  private func queuePaintedEquipmentPurchase() {
    guard pendingEquipmentPurchases.count < 64,
      inventoryInputGeneration == paintedInventoryInputGeneration,
      paintedPurchaseBounds == bounds, let context = paintedPurchaseContext,
      context == game.equipmentPurchaseContext
    else {
      needsDisplay = true
      return
    }
    pendingEquipmentPurchases.append(context)
    pending.append("equipment-purchase")
  }
  private func queuePaintedPassengerBerthFitting(fitted: Bool) {
    guard pendingPassengerBerthFittings.count < 64,
      inventoryInputGeneration == paintedInventoryInputGeneration,
      paintedPurchaseBounds == bounds, let context = paintedPurchaseContext,
      context == game.equipmentPurchaseContext,
      let intent = context.passengerBerthFitting(fitted: fitted)
    else {
      needsDisplay = true
      return
    }
    pendingPassengerBerthFittings.append(intent)
    pending.append("passenger-berth-fitting")
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
  private func scriptPageToken() -> String? {
    guard let proof = paintedMissionMenuPresentation,
      let bytes = try? JSONEncoder().encode(proof), bytes.count <= 1024
    else {
      needsDisplay = true
      return nil
    }
    return bytes.base64EncodedString()
  }
  private func enqueueKey(_ key: String) {
    if ScriptPagePresentation.controlKeys.contains(key)
      || ScriptPagePresentation.galleryContextKeys.contains(key)
      || ScriptPagePresentation.contractContextKeys.contains(key)
      || (game.screen == .gallery && ["gallery-trial", "mission-resume"].contains(key))
    {
      guard let token = scriptPageToken() else { return }
      pending.append("script-page-key:" + token + ":" + key)
    } else {
      pending.append(key)
    }
  }
  func enqueueGalleryCommand(_ key: String) {
    guard game.screen == .gallery, ["gallery-trial", "mission-resume"].contains(key) else { return }
    enqueueKey(key)
  }
  func enqueueContractCommand(_ key: String) {
    guard ScriptPagePresentation.contractContextKeys.contains(key) else { return }
    enqueueKey(key)
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
    if game.screen == .inventory, key == "return" {
      if !event.isARepeat { queuePaintedInventoryCommand() }
      return
    }
    if game.screen == .equipment, key == "return" {
      if !event.isARepeat { queuePaintedEquipmentPurchase() }
      return
    }
    if game.passengerBerthSelected, ["s", "r"].contains(key) {
      if !event.isARepeat { queuePaintedPassengerBerthFitting(fitted: key == "r") }
      return
    }
    if key == "tab" && !event.isARepeat && game.screen.isFlight {
      clearSteeringInput()
    }
    if game.screen.isFlight && !game.paused {
      // A menu/context transition can clear held input; an old Return repeat is not a new press.
      if key == FlightControlInput.token(for: .fire), event.isARepeat, !held.contains(key) {
        return
      }
      held.insert(key)
      pressedKeys[event.keyCode] = key
    }
    let repeatNavigation =
      !game.screen.isFlight && ["up", "down", "left", "right", "pageup", "pagedown"].contains(key)
    let repeatText = game.acceptsTextInput && (key.count == 1 || key == "backspace")
    if !event.isARepeat || repeatNavigation || repeatText {
      if game.screen == .inventory || game.screen == .equipment { inventoryInputGeneration &+= 1 }
      enqueueKey(key)
    }
  }
  override func keyUp(with event: NSEvent) {
    held.remove(pressedKeys.removeValue(forKey: event.keyCode) ?? Self.key(event))
  }
  override func mouseDown(with event: NSEvent) {
    if game.screen == .inventory {
      let point = convert(event.locationInWindow, from: nil)
      queuePaintedInventoryCommand(at: .init(point.x, point.y))
      return
    }
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
    if game.screen == .rumour {
      let point = convert(event.locationInWindow, from: nil)
      pending.append("wanted-click:\(point.x):\(point.y)")
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
    if [.handoff, .gallery, .contracts].contains(game.screen) {
      let point = convert(event.locationInWindow, from: nil)
      guard let token = scriptPageToken() else { return }
      pending.append("script-page-click:" + token + ":\(point.x):\(point.y)")
      return
    }
    if game.screen == .equipment {
      let point = convert(event.locationInWindow, from: nil)
      inventoryInputGeneration &+= 1
      pending.append("equipment-click:\(point.x):\(point.y)")
      return
    }
    if game.screen == .library {
      let point = convert(event.locationInWindow, from: nil)
      pending.append("library-click:\(point.x):\(point.y)")
      return
    }
    guard [.chart, .shortChart, .navigation].contains(game.screen) else { return }
    let point = convert(event.locationInWindow, from: nil)
    pending.append("map-click:\(point.x):\(point.y)")
  }
  override func scrollWheel(with event: NSEvent) {
    if game.screen == .contracts {
      enqueueKey(event.scrollingDeltaY > 0 ? "up" : "down")
      return
    }
    if game.screen == .handoff || game.screen == .library {
      enqueueKey(event.scrollingDeltaY > 0 ? "pageup" : "pagedown")
      return
    }
    if [.secret, .system, .status, .inventory, .market, .buy, .sell].contains(game.screen) {
      if game.screen == .inventory { inventoryInputGeneration &+= 1 }
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
      inventoryInputGeneration &+= 1
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
      guard let token = scriptPageToken() else { return }
      pending.append(
        "script-page-gallery-scroll:" + token + ":\(event.scrollingDeltaY > 0 ? -1 : 1)")
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
    controls.fire = FlightControlInput.fireIsHeld(held)
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
    case 36, 76: return FlightControlInput.token(for: .fire)
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
  let runtime: GameRuntime
  let frameProfile: PlanetFrameProfiler?
  var loop: Task<Void, Never>?
  var missionMenu: NativeMissionMenu?
  let saves: CommanderSaveSession
  let windowSize: NSSize
  let restoreOnLaunch: Bool
  private var processingPendingCommands = false
  let commanderFileFailure: @MainActor (any Error) -> Void
  var saveURL: URL { saves.activeURL }
  init(
    restoreOnLaunch: Bool = true, saves: CommanderSaveSession? = nil,
    windowSize: NSSize = .init(width: 768, height: 768),
    runtime: GameRuntime = GameRuntime(), frameProfile: PlanetFrameProfiler? = nil,
    commanderFileFailure: @escaping @MainActor (any Error) -> Void = {
      NSAlert(error: $0).runModal()
    }
  ) {
    self.runtime = runtime
    self.frameProfile = frameProfile
    self.windowSize = windowSize
    self.restoreOnLaunch = restoreOnLaunch
    self.commanderFileFailure = commanderFileFailure
    self.saves = saves ?? CommanderSaveSession()
    super.init()
  }
  func applicationDidFinishLaunching(_ _: Notification) {
    // Warm immutable texture pixels before any normal frame can encounter a textured craft.
    ShipTextureAssets.preload()
    let view = GameView(frame: NSRect(origin: .zero, size: windowSize))
    view.frameProfile = frameProfile
    view.wantsLayer = true
    let window = NSWindow(
      contentRect: view.frame, styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered, defer: false)
    // ARC retains this window through AppDelegate; AppKit must not release it again on close.
    window.isReleasedWhenClosed = false
    window.title = NewCommanderDefaults.title
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
    // Controlled launches retain their configured script library.
    let shouldLoadDefaultScriptPacks = restoreOnLaunch
    loop = Task { [weak view, weak self] in
      guard !Task.isCancelled else { return }
      if let profile = self?.frameProfile {
        await runtime.loadMissionPacks(
          directory: profile.directory.appendingPathComponent("mission-packs"))
      } else {
        await runtime.loadMissionPacks()
      }
      guard !Task.isCancelled else { return }
      var packErrors = await runtime.snapshot().missionPacks.errors
      guard !Task.isCancelled else { return }
      if shouldLoadDefaultScriptPacks {
        packErrors += await runtime.loadDefaultScriptPacks()
      }
      guard !Task.isCancelled else { return }
      if !packErrors.isEmpty {
        let alert = NSAlert()
        alert.messageText = "Some mission packs could not be enabled"
        alert.informativeText = packErrors.joined(separator: "\n")
        alert.runModal()
      }
      var failedRestore = false
      if let self, self.restoreOnLaunch, let url = self.saves.startupURL {
        do {
          try await runtime.restoreStartup(from: url)
          guard !Task.isCancelled else { return }
          view?.game = await runtime.snapshot()
        } catch {
          guard !Task.isCancelled else { return }
          failedRestore = true
          await self.recoverStartup(error, url: url)
        }
      }
      if let self, self.restoreOnLaunch {
        await self.prepareNewCommanderSaveIfNeeded(afterFailedRestore: failedRestore)
      }
      if let profile = self?.frameProfile, profile.startupRequest == nil {
        _ = await PlanetRenderer.prepareGPU()
      }
      var previousTick = ContinuousClock.now
      var cadence = FrameCadence(start: previousTick, maximumFPS: 60)
      while !Task.isCancelled {
        guard let view else { return }
        let frameStart = ContinuousClock.now
        let maximumFPS = view.window?.screen?.maximumFramesPerSecond ?? 60
        let deadline = cadence.nextDeadline(after: frameStart, maximumFPS: maximumFPS)
        if let self {
          self.frameProfile?.beginFrame(in: view)
          guard !Task.isCancelled else { return }
          await self.processFrame(in: view) {
            let now = ContinuousClock.now
            let elapsed = previousTick.duration(to: now).components
            previousTick = now
            return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
          }
        } else {
          return
        }
        self?.frameProfile?.endFrame(in: view, started: frameStart, deadline: deadline)
        guard !Task.isCancelled else { return }
        // Keep the cadence phase after late wakes and sleep past slots missed by actual work.
        let wakeDeadline = cadence.nextDeadline(after: ContinuousClock.now, maximumFPS: maximumFPS)
        do {
          try await Task.sleep(
            until: wakeDeadline, tolerance: FrameCadence.sleepTolerance, clock: .continuous)
        } catch { return }
      }
    }
  }
  func prepareNewCommanderSaveIfNeeded(afterFailedRestore: Bool) async {
    do {
      try await bindNewCommanderSaveIfNeeded(afterFailedRestore: afterFailedRestore)
    } catch {
      // Keep the ordered consumer alive so Open or Save As can recover a writable destination.
      commanderFileFailure(error)
    }
  }
  func bindNewCommanderSaveIfNeeded(afterFailedRestore: Bool) async throws {
    guard !(await runtime.hasCommanderSaveDestination()) else { return }
    try await runtime.startNewCommander()
    let proposed = saves.newCommanderDestination(afterFailedRestore: afterFailedRestore)
    let accepted: URL
    do {
      accepted = try await runtime.registerNewCommanderDestination(at: proposed)
    } catch {
      // A racing first-run file is never adopted or overwritten by this fresh commander.
      let fresh = saves.newCommanderDestination(afterFailedRestore: true)
      accepted = try await runtime.registerNewCommanderDestination(at: fresh)
    }
    saves.activeURL = accepted
  }
  func acknowledgeNewCommanderSave() async {
    if let receipt = await runtime.takeNewCommanderSaveReceipt() {
      saves.didSave(to: receipt.url)
    }
  }
  func processFrame(in view: GameView, delta: () -> Double) async {
    let commandStart = frameProfile == nil ? nil : ContinuousClock.now
    await processPendingCommands(in: view)
    frameProfile?.willAdvance(in: view)
    await runtime.setViewport(width: view.bounds.width, height: view.bounds.height)
    await runtime.setControls(view.controls)
    let advanceStart = frameProfile == nil ? nil : ContinuousClock.now
    let snapshot = await runtime.advance(delta: delta())
    let advanceEnd = frameProfile == nil ? nil : ContinuousClock.now
    view.profileSubmittedFrame = frameProfile?.currentID
    view.game = snapshot
    await acknowledgeNewCommanderSave()
    view.audio.update(view.game)
    view.needsDisplay = true
    if let commandStart, let advanceStart, let advanceEnd {
      frameProfile?.submitted(
        in: view, commands: PlanetFrameProfiler.elapsed(commandStart, advanceStart),
        advance: PlanetFrameProfiler.elapsed(advanceStart, advanceEnd),
        submission: PlanetFrameProfiler.elapsed(advanceEnd, ContinuousClock.now))
    }
  }
  // The frame loop and native integration checks share one ordered command batch.
  // Awaiting this method acknowledges actual processing instead of elapsed time.
  private func scriptPageProof(_ token: Substring) -> ScriptPagePresentation? {
    guard token.utf8.count <= 1400, let bytes = Data(base64Encoded: String(token)),
      bytes.count <= 1024
    else { return nil }
    return try? JSONDecoder().decode(ScriptPagePresentation.self, from: bytes)
  }
  func processPendingCommands(in view: GameView) async {
    guard !processingPendingCommands else { return }
    processingPendingCommands = true
    defer { processingPendingCommands = false }
    let events = view.pending
    view.pending.removeAll()
    let inventoryCommands = view.pendingInventoryCommands
    view.pendingInventoryCommands.removeAll(keepingCapacity: true)
    let purchases = view.pendingEquipmentPurchases
    view.pendingEquipmentPurchases.removeAll(keepingCapacity: true)
    let cabinFittings = view.pendingPassengerBerthFittings
    view.pendingPassengerBerthFittings.removeAll(keepingCapacity: true)
    let files = view.pendingCommanderFiles
    view.pendingCommanderFiles.removeAll(keepingCapacity: true)
    let missionIntents = view.pendingMissionUI
    view.pendingMissionUI.removeAll(keepingCapacity: true)
    let inventoryGeneration = view.inventoryInputGeneration
    var inventoryCommandIndex = 0
    var purchaseIndex = 0
    var cabinFittingIndex = 0
    var fileIndex = 0
    var missionUIIndex = 0
    for event in events {
      if event == "mission-ui" {
        guard missionIntents.indices.contains(missionUIIndex) else { continue }
        let intent = missionIntents[missionUIIndex]
        missionUIIndex += 1
        await runtime.missionUICommand(intent)
      } else if event == "equipment-purchase" {
        if purchases.indices.contains(purchaseIndex) {
          _ = await runtime.equipmentTransaction(.purchase(purchases[purchaseIndex]))
          purchaseIndex += 1
        }
      } else if event == "passenger-berth-fitting" {
        if cabinFittings.indices.contains(cabinFittingIndex) {
          _ = await runtime.equipmentTransaction(.passengerBerth(cabinFittings[cabinFittingIndex]))
          cabinFittingIndex += 1
        }
      } else if event == "inventory-command" {
        if inventoryCommands.indices.contains(inventoryCommandIndex) {
          _ = await runtime.inventoryCommand(inventoryCommands[inventoryCommandIndex])
          inventoryCommandIndex += 1
        }
      } else if event == "commander-file" {
        guard files.indices.contains(fileIndex) else { continue }
        let intent = files[fileIndex]
        let operation = intent.operation(activeURL: saves.activeURL)
        fileIndex += 1
        do {
          let receipt = try await runtime.commanderFileOperationForInterface(
            operation,
            activePath: intent.usesActivePath)
          switch operation {
          case .save:
            if !receipt.isTrial { saves.didSave(to: receipt.url) }
          case .load:
            if !receipt.isTrial { saves.activeURL = receipt.url }
            view.held.removeAll()
            view.pressedKeys.removeAll()
            view.trackpad.reset()
            view.game = await runtime.snapshot()
          }
        } catch { commanderFileFailure(error) }
      } else if event.hasPrefix("market-click:") {
        let values = event.dropFirst(13).split(separator: ":").compactMap { Double($0) }
        if values.count == 2 { await runtime.marketClick(x: values[0], y: values[1]) }
      } else if event.hasPrefix("secret-click:") {
        let values = event.dropFirst(13).split(separator: ":").compactMap { Double($0) }
        if values.count == 2 { await runtime.secretClick(x: values[0], y: values[1]) }
      } else if event.hasPrefix("wanted-click:") {
        let values = event.dropFirst("wanted-click:".count).split(separator: ":").compactMap {
          Double($0)
        }
        if values.count == 2 { await runtime.wantedBoardClick(x: values[0], y: values[1]) }
      } else if event.hasPrefix("showroom-click:") {
        let values = event.dropFirst(15).split(separator: ":").compactMap { Double($0) }
        if values.count == 2 { await runtime.showroomClick(x: values[0], y: values[1]) }
      } else if event.hasPrefix("script-page-key:") {
        let parts = event.dropFirst("script-page-key:".count).split(separator: ":", maxSplits: 1)
        if parts.count == 2, let proof = scriptPageProof(parts[0]) {
          await runtime.scriptPageKey(String(parts[1]), expected: proof)
        }
      } else if event.hasPrefix("script-page-gallery-scroll:") {
        let parts = event.dropFirst("script-page-gallery-scroll:".count).split(separator: ":")
        if parts.count == 2, let proof = scriptPageProof(parts[0]), let amount = Int(parts[1]) {
          await runtime.scriptPageGalleryScroll(amount, expected: proof)
        }
      } else if event.hasPrefix("script-page-click:") {
        let parts = event.dropFirst("script-page-click:".count).split(separator: ":")
        if parts.count == 3, let proof = scriptPageProof(parts[0]),
          let x = Double(parts[1]), let y = Double(parts[2])
        {
          await runtime.scriptPageClick(x: x, y: y, expected: proof)
        }
      } else if event.hasPrefix("handoff-click:") {
        // Coordinates alone cannot authorize a different contact after repaint or load.
        continue
      } else if event.hasPrefix("equipment-click:") {
        let values = event.dropFirst(16).split(separator: ":").compactMap { Double($0) }
        if values.count == 2 { await runtime.equipmentClick(y: values[1], x: values[0]) }
      } else if event.hasPrefix("map-click:") {
        let parts = event.split(separator: ":")
        if parts.count == 3, let x = Double(parts[1]), let y = Double(parts[2]) {
          await runtime.mapClick(x: x, y: y)
        }
      } else if event.hasPrefix("gallery-click:") || event.hasPrefix("contract-click:")
        || event.hasPrefix("contract-scroll:") || event.hasPrefix("gallery-scroll:")
      {
        // Old unproved packets cannot select a new campaign or payment target.
        continue
      } else if event.hasPrefix("library-click:") {
        let parts = event.split(separator: ":")
        if parts.count == 3, let x = Double(parts[1]), let y = Double(parts[2]) {
          await runtime.libraryClick(x: x, y: y)
        }
      } else if event.hasPrefix("chart:") {
        let parts = event.split(separator: ":")
        if parts.count == 3, let x = Double(parts[1]), let y = Double(parts[2]),
          x.isFinite, y.isFinite
        {
          await runtime.selectSystem(x: x, y: y)
        }
      } else {
        await runtime.key(event)
      }
    }
    await acknowledgeNewCommanderSave()
    view.processedInventoryInputGeneration = inventoryGeneration
    if !events.isEmpty { view.game = await runtime.snapshot() }
  }
  func applicationShouldTerminateAfterLastWindowClosed(_ _: NSApplication) -> Bool {
    frameProfile == nil
  }
  func applicationWillTerminate(_ notification: Notification) {
    windowWillClose(notification)
  }
  func windowWillClose(_ _: Notification) {
    (window?.contentView as? GameView)?.audio.shutdown()
    frameProfile?.cancelled()
    loop?.cancel()
    loop = nil
  }
  func windowDidEnterFullScreen(_ notification: Notification) {
    if let window = notification.object as? NSWindow {
      frameProfile?.enteredFullscreen(window: window)
    }
  }
  func windowDidFailToEnterFullScreen(_ _: NSWindow) {
    frameProfile?.fail("AppKit refused the native fullscreen transition.")
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
      withTitle: "Quit L337", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
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
      (
        FlightControlAuthority.ActionID.nextTarget.binding.label,
        FlightControlInput.token(for: .nextTarget)
      ),
      (
        FlightControlAuthority.ActionID.targetFilter.binding.label,
        FlightControlInput.token(for: .targetFilter)
      ),
      (
        FlightControlAuthority.ActionID.changeWeapon.binding.label,
        FlightControlInput.token(for: .changeWeapon)
      ),
      (
        FlightControlAuthority.ActionID.releaseHold.binding.label,
        FlightControlInput.token(for: .releaseHold)
      ),
      ("Hyperspace to Selected System", "h"), ("In-system Jump", "j"),
      ("Galactic Hyperdrive", "g"),
      (FlightControlAuthority.ActionID.ecm.binding.label, FlightControlInput.token(for: .ecm)),
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
    let pause = game.submenu?.addItem(
      withTitle: "Pause / Resume", action: #selector(togglePause), keyEquivalent: "p")
    pause?.target = self
    let spin = game.submenu?.addItem(
      withTitle: "Toggle Spin Hold", action: #selector(toggleSpin), keyEquivalent: "")
    spin?.target = self
    let stop = game.submenu?.addItem(
      withTitle: "Stop Spin", action: #selector(stopSpin), keyEquivalent: "")
    stop?.target = self
    let missionMenu = NativeMissionMenu(
      snapshot: { [weak self] in (self?.window?.contentView as? GameView)?.game },
      paintedPresentation: { [weak self] in
        (self?.window?.contentView as? GameView)?.paintedMissionMenuPresentation
      },
      enqueue: { [weak self] intent in
        guard let view = self?.window?.contentView as? GameView,
          view.pendingMissionUI.count < 64
        else { return }
        view.pendingMissionUI.append(intent)
        view.pending.append("mission-ui")
      })
    self.missionMenu = missionMenu
    if let submenu = game.submenu { missionMenu.install(in: submenu) }
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
    queueCommanderFile(.saveActive)
  }
  func queueCommanderFile(_ intent: NativeCommanderFileIntent) {
    guard let view = window?.contentView as? GameView else { return }
    view.pendingCommanderFiles.append(intent)
    view.pending.append("commander-file")
  }
  @objc private func installMissionPack() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.folder, UTType(filenameExtension: "toml") ?? .plainText]
    panel.message = "Choose a mission file or the complete mission folder."
    guard panel.runModal() == .OK, let url = panel.url else { return }
    Task { [weak self] in
      guard let self else { return }
      do { try await runtime.installMissionPackInput(from: url) } catch { show(error) }
    }
  }
  @objc private func loadCommander() {
    queueCommanderFile(.reloadActive)
  }
  @objc private func chooseCommander() {
    openChosenCommander()
  }
  private func openChosenCommander() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.json]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    queueCommanderFile(.open(url))
  }
  @objc private func saveCommanderAs() {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.json]
    panel.nameFieldStringValue = "commander.json"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    queueCommanderFile(.saveAs(url))
  }
  private func recoverStartup(_ error: Error, url: URL) async {
    let alert = NSAlert()
    alert.messageText = "Your last commander could not be restored"
    alert.informativeText =
      "The saved file at \(url.path) is missing, inaccessible or invalid. It has not been changed. Choose another save or start a new Commander \(NewCommanderDefaults.name). \(error.localizedDescription)"
    alert.addButton(withTitle: "Choose Save")
    alert.addButton(withTitle: "Start New")
    if alert.runModal() == .alertFirstButtonReturn { openChosenCommander() }
  }
  private func show(_ error: Error) { NSAlert(error: error).runModal() }
}

@main
struct L337App {
  @MainActor static func main() async throws {
    if let index = CommandLine.arguments.firstIndex(of: "--validate-commander-save") {
      do {
        guard CommandLine.arguments.indices.contains(index + 1) else {
          throw SaveError.invalidCommander
        }
        let runtime = GameRuntime()
        try await runtime.load(
          from: URL(fileURLWithPath: CommandLine.arguments[index + 1]), persistMigrations: false)
      } catch {
        FileHandle.standardError.write(Data("Invalid commander save\n".utf8))
        exit(EXIT_FAILURE)
      }
      return
    }
    if let index = CommandLine.arguments.firstIndex(of: "--validate-mission-pack") {
      do {
        guard CommandLine.arguments.indices.contains(index + 1) else {
          throw MissionPackErrorCLI.missingPath
        }
        let input = try MissionPackInput(at: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
        let lines = try input.validationLines()
        for line in lines { print(line) }
      } catch MissionPackErrorCLI.missingPath {
        FileHandle.standardError.write(
          Data("Missing mission pack path. Use --validate-mission-pack <file-or-folder>.\n".utf8))
        exit(EXIT_FAILURE)
      } catch {
        FileHandle.standardError.write(
          Data("Invalid mission pack: \(error.localizedDescription)\n".utf8))
        exit(EXIT_FAILURE)
      }
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
    if let request = try PlanetFrameProfiler.startupRequest(arguments: CommandLine.arguments) {
      let game = request.game()
      let profile = try PlanetFrameProfiler(
        directory: request.directory, sourceSHA: request.sourceSHA, system: game.currentSystem,
        mode: .compact, startupRequest: request)
      let saves = CommanderSaveSession(
        preferences: nil, defaultURL: request.directory.appendingPathComponent("commander.json"))
      let delegate = AppDelegate(
        restoreOnLaunch: false, saves: saves, windowSize: .init(width: 768, height: 768),
        runtime: GameRuntime(game: game), frameProfile: profile,
        commanderFileFailure: { profile.fail($0.localizedDescription) })
      app.setActivationPolicy(.regular)
      app.delegate = delegate
      withExtendedLifetime(delegate) { app.run() }
      delegate.loop?.cancel()
      delegate.window?.orderOut(nil)
      guard profile.completedSuccessfully else { throw CocoaError(.coderInvalidValue) }
      return
    }
    if let index = CommandLine.arguments.firstIndex(of: "--profile-planet-frames") {
      guard CommandLine.arguments.indices.contains(index + 3),
        CommandLine.arguments[index + 1].hasPrefix("/"),
        let mode = PlanetFrameProfiler.WindowMode(rawValue: CommandLine.arguments[index + 3])
      else { throw CocoaError(.fileWriteInvalidFileName) }
      let directory = URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
      guard
        let system = Universe.galaxy(number: 0).filter({ $0.economy == 0 && $0.government == 7 })
          .sorted(by: {
            $0.technology == $1.technology ? $0.id < $1.id : $0.technology > $1.technology
          })
          .first
      else { throw CocoaError(.coderInvalidValue) }
      let profile = try PlanetFrameProfiler(
        directory: directory, sourceSHA: CommandLine.arguments[index + 2], system: system,
        mode: mode, diagnosticCaptures: CommandLine.arguments.contains("--profile-station-geometry")
      )
      var game = Game(executive: false)
      game.commander.system = system.id
      game.commander.shipDisplayStyle = .shadedPanels
      game.screen = .status
      let runtime = GameRuntime(game: game)
      let saves = CommanderSaveSession(
        preferences: nil, defaultURL: directory.appendingPathComponent("commander.json"))
      let delegate = AppDelegate(
        restoreOnLaunch: false, saves: saves, windowSize: .init(width: 512, height: 540),
        runtime: runtime, frameProfile: profile,
        commanderFileFailure: { profile.fail($0.localizedDescription) })
      app.setActivationPolicy(.regular)
      app.delegate = delegate
      withExtendedLifetime(delegate) { app.run() }
      delegate.loop?.cancel()
      delegate.window?.orderOut(nil)
      guard profile.completedSuccessfully else { throw CocoaError(.coderInvalidValue) }
      return
    }
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
    try exportRouteReadmeMedia()
    try FileManager.default.createDirectory(atPath: "docs", withIntermediateDirectories: true)
    var game = Game()
    game.launch()
    game.bodies[1].position = .init(-35, 10, 320)
    game.prepareFlightWeaponDisplay()
    guard let image = imageForGame(game, width: 1024, height: 768),
      let png = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: "docs/l337.png") as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw SaveError.invalidCommander }
    CGImageDestinationAddImage(png, image, nil)
    guard CGImageDestinationFinalize(png) else { throw SaveError.invalidCommander }
    guard
      let gif = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: "docs/start-sequence.gif") as CFURL, UTType.gif.identifier as CFString,
        80, nil)
    else { throw SaveError.invalidCommander }
    CGImageDestinationSetProperties(
      gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    game = Game()
    for index in 0..<80 {
      if index >= 48 {
        let shipID = index < 64 ? "SH002" : "SH035"
        let frame = try Display.originalDesignPresentation(
          game, shipID: shipID, time: Double((index - 48) % 16) / 6,
          width: 1024, height: 768)
        guard let image = imageForFrame(frame, width: 1024, height: 768) else {
          throw SaveError.invalidCommander
        }
        CGImageDestinationAddImage(
          gif, image,
          [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.16]] as CFDictionary)
        continue
      }
      game.time = Double(index) / 6
      if index >= 16 { game.screen = .title }
      if index >= 24 { game.screen = .status }
      if index >= 30 {
        game.launch()
        game.bodies[1].position = .init(-35, 10, 320)
        game.time = Double(index) / 6
      }
      game.prepareFlightWeaponDisplay()
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
    try await GameRuntime().diagnoseScriptHost()
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
