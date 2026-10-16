import AppKit
import Testing

@testable import EliteCore
@testable import EliteMac

extension GameRuntime {
  fileprivate func installNativeWorkScene(_ prepared: Game) throws {
    guard prepared.commander.valid, prepared.workGuidance == nil,
      prepared.workBraking == nil, prepared.approvedWorkMotion == nil,
      prepared.autoPilot.targetID == nil
    else { throw SaveError.invalidCommander }
    game = prepared
    setControls(.init())
  }
}

private func nativeWorkScene(mining: Bool = true) throws -> Game {
  var game = Game(executive: false)
  game.commander.shipID = "SH023"
  try game.commander.prepareEquipment(legacy: false)
  for (name, slot) in [
    ("Targeting: Military", ComponentFittingSlot.targetingCore),
    ("Targeting: Salvage Module", .targetingSalvage),
    ("Fuel Scoops", .utility(.fuelScoops)),
  ] {
    try game.commander.grantEquipment(name, at: slot, provenance: .grant("native work fixture"))
  }
  if mining {
    try game.commander.grantEquipment(
      "Targeting: Mining Module", at: .targetingMining, provenance: .grant("native work fixture"))
  }
  try game.commander.validateEquipmentState()
  game.launch()
  game.speed = 0
  game.bodies = []
  game.celestials = []
  game.salvageSites = []
  game.commander.npcPersistence = .init()
  return game
}

private func nativeMiningScene(mining: Bool = true) throws -> (Game, ActorIdentity) {
  var game = try nativeWorkScene(mining: mining)
  let rock = try #require(game.miningFields.flatMap(\.rocks).first)
  // Move only the observer. The rock retains its generated world position and identity.
  game.commander.flightSimulation.pose = .init(position: rock.position - .init(0, 0, 900))
  game.activateNearbyMiningFields()
  let body = try #require(game.bodies.first { $0.physical?.rock == rock.identity })
  let actor = try #require(body.physical?.identity)
  game.bodies = [body]
  #expect(game.gameplayMesh(for: body).vertices.count > 0)
  #expect(body.energy == game.commander.miningLedger.remainingEnergy(for: rock))
  return (game, actor)
}

private func nativeSalvageScene() throws -> (Game, ActorIdentity, SalvageLotIdentity) {
  var game = try nativeWorkScene()
  game.miningFields = []
  try game.commander.grantEquipment(
    "Salvage Cutter", at: .utility(.salvageCutter), provenance: .grant("native lot fixture"))
  try game.commander.validateEquipmentState()
  game.speed = 1
  game.commander.flightSimulation.pose = .init(position: .init(100_000, 0, 0))
  let profile = try #require(
    SalvageCatalogue.all.first { $0.sections.contains { $0.kind == .computer } })
  let section = try #require(profile.sections.first { $0.kind == .computer })
  let wreck = WreckIdentity(system: game.systemIdentity, site: 51, lineage: 9001)
  let conditions = SalvageWorkConditions(
    toolInstalled: true, inRange: true, aligned: true, lineOfSight: true,
    resourcesAvailable: true, ownershipAuthorized: true)
  var operation: UInt64 = 0
  for _ in 0..<(Int(ceil(section.workSeconds)) + 1) {
    operation += 1
    let result = game.commander.salvageLedger.advance(
      wreck: wreck, section: section,
      pose: .init(position: game.commander.flightSimulation.pose.position + .init(0, 0, 2000)),
      velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), tool: .cutter,
      elapsed: 1, operation: operation, conditions: conditions)
    if case .released = result { break }
  }
  let lot = try #require(
    game.commander.salvageLedger.pendingLots.first {
      $0.halfExtents.x <= 16 && $0.halfExtents.y <= 16 && $0.halfExtents.z <= 16
    })
  game.commander.salvageLedger.updateLot(
    lot.identity, position: game.commander.flightSimulation.pose.position + .init(0, -45, 1800),
    velocity: .init(0, 0, 0))
  let context = try #require(game.gameplayContext())
  let offered = game.commander.salvageLedger.spawnRequests(context: context)
  let request = try #require(offered.first { $0.payload == .salvage(lot.identity) })
  let receipts = game.admitEncounterPlan(
    .init(
      system: context.system, visit: context.visit, revision: context.revision,
      batches: [.init(requests: [request], atomic: false)], intents: []))
  game.commander.salvageLedger.acknowledge(receipts: receipts)
  let actor = try #require(receipts.first?.actor)
  let body = try #require(game.bodies.first { $0.physical?.identity == actor })
  #expect(body.physical?.salvage == request.salvage)
  #expect(game.commander.salvageLedger.boundActor(for: lot.identity) == actor)
  return (game, actor, lot.identity)
}

@MainActor
private struct NativeWorkFixture {
  let delegate: AppDelegate
  let view: GameView
  let window: NSWindow
  let preferences: UserDefaults
  let identifier: String
  let directory: URL
  let save: URL
  let bytes: Data
  let menu: NSMenu?

  static func open(_ game: Game, width: Int = 768, height: Int = 768) async throws -> Self {
    _ = NSApplication.shared
    let menu = NSApp.mainMenu
    let identifier = "elite-native-work-" + UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: identifier))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(identifier)
    let save = directory.appendingPathComponent("commander.json")
    let bytes = try JSONEncoder().encode(game.commander)
    let delegate = AppDelegate(
      restoreOnLaunch: false,
      saves: CommanderSaveSession(preferences: preferences, defaultURL: save),
      windowSize: .init(width: Double(width), height: Double(height)))
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try bytes.write(to: save)
      delegate.applicationDidFinishLaunching(
        Notification(name: NSApplication.didFinishLaunchingNotification))
      let window = try #require(delegate.window)
      let view = try #require(window.contentView as? GameView)
      let loop = try #require(delegate.loop)
      loop.cancel()
      await loop.value
      try await delegate.runtime.load(from: save, persistMigrations: false)
      try await delegate.runtime.installNativeWorkScene(game)
      window.setContentSize(NSSize(width: Double(width), height: Double(height)))
      #expect(view.bounds.width == Double(width) && view.bounds.height == Double(height))
      await delegate.runtime.setViewport(width: view.bounds.width, height: view.bounds.height)
      view.game = await delegate.runtime.snapshot()
      view.pending.removeAll()
      return .init(
        delegate: delegate, view: view, window: window, preferences: preferences,
        identifier: identifier, directory: directory, save: save, bytes: bytes, menu: menu)
    } catch {
      if let loop = delegate.loop {
        loop.cancel()
        await loop.value
      }
      delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification))
      delegate.window?.orderOut(nil)
      delegate.window?.delegate = nil
      NSApp.mainMenu = menu
      preferences.removePersistentDomain(forName: identifier)
      try? FileManager.default.removeItem(at: directory)
      throw error
    }
  }
  func close() {
    delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification))
    window.orderOut(nil)
    window.delegate = nil
    NSApp.mainMenu = menu
    preferences.removePersistentDomain(forName: identifier)
    try? FileManager.default.removeItem(at: directory)
  }
  func event(_ code: UInt16, _ text: String, down: Bool) throws -> NSEvent {
    try #require(
      NSEvent.keyEvent(
        with: down ? .keyDown : .keyUp, location: .zero,
        modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil,
        characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code))
  }
  func press(_ code: UInt16, _ text: String) async throws {
    view.keyDown(with: try event(code, text, down: true))
    view.keyUp(with: try event(code, text, down: false))
    await delegate.processPendingCommands(in: view)
    #expect(view.pending.isEmpty && !view.controls.fire)
  }
  func frame(_ delta: Double = 1.0 / 60) async {
    await delegate.processFrame(in: view, delta: { delta })
  }
  func verifyPrivatePersistenceUnchanged() throws {
    #expect(try Data(contentsOf: save) == bytes)
    #expect(delegate.saves.activeURL == save)
    #expect(preferences.persistentDomain(forName: identifier) == nil)
  }
  func capture(name: String, scale: Int) throws {
    let width = Int(view.bounds.width)
    let height = Int(view.bounds.height)
    let context = try #require(
      CGContext(
        data: nil, width: width * scale, height: height * scale,
        bitsPerComponent: 8, bytesPerRow: width * scale * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.translateBy(x: 0, y: Double(height * scale))
    context.scaleBy(x: Double(scale), y: Double(-scale))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    view.draw(view.bounds)
    NSGraphicsContext.restoreGraphicsState()
    let actual = try #require(context.makeImage())
    let expected = try #require(imageForGame(view.game, width: width, height: height, scale: scale))
    #expect(
      CFEqual(try #require(actual.dataProvider?.data), try #require(expected.dataProvider?.data)))
    if let path = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"] {
      let output = URL(fileURLWithPath: path, isDirectory: true)
      try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
      let png = try #require(
        NSBitmapImageRep(cgImage: actual).representation(using: .png, properties: [:]))
      try png.write(
        to: output.appendingPathComponent("work-salvage-\(name)-\(width)-\(scale)x.png"))
    }
    try verifyPrivatePersistenceUnchanged()
  }
}

extension NativeViewTests {
  @MainActor @Test func nativeMiningKeysSelectRealRockThroughTabAndR() async throws {
    for (code, text) in [(UInt16(48), "\t"), (UInt16(15), "r")] {
      let (game, actor) = try nativeMiningScene()
      let fixture = try await NativeWorkFixture.open(game)
      defer { fixture.close() }
      try await fixture.press(3, "f")
      try await fixture.press(code, text)
      let snapshot = await fixture.delegate.runtime.snapshot()
      #expect(snapshot.workTargetFilter == .mining)
      #expect(
        snapshot.workGuidance?.parent == actor && snapshot.workGuidance?.mode == .hold(.mining))
      #expect(snapshot.targetInformation?.status == snapshot.workGuidance?.status)
      #expect(snapshot.laserFlash == 0 && !fixture.view.controls.fire)
      #expect(snapshot.commander.cargo == game.commander.cargo)
      #expect(snapshot.commander.equipmentInventory == game.commander.equipmentInventory)
      #expect(snapshot.commander.miningLedger == game.commander.miningLedger)
      try fixture.verifyPrivatePersistenceUnchanged()
    }
  }
  @MainActor @Test func nativeSalvageApproachDrawAndQPreserveFiniteCustody() async throws {
    for (width, height, scale) in [(512, 518, 1), (1512, 982, 2)] {
      for (code, text) in [(UInt16(48), "\t"), (UInt16(15), "r")] {
        let (game, actor, lot) = try nativeSalvageScene()
        let fixture = try await NativeWorkFixture.open(game, width: width, height: height)
        defer { fixture.close() }
        let cargo = game.commander.cargo
        let inventory = game.commander.salvageLedger.inventory
        let pending = try #require(
          game.commander.salvageLedger.pendingLots.first { $0.identity == lot })
        let equipment = game.commander.equipmentInventory
        let history = game.commander.equipmentPurchaseHistory
        try await fixture.press(3, "f")
        try await fixture.press(3, "f")
        try await fixture.press(code, text)
        await fixture.frame()
        let snapshot = await fixture.delegate.runtime.snapshot()
        #expect(snapshot.workTargetFilter == .salvage)
        #expect(
          snapshot.workGuidance?.parent == actor
            && snapshot.workGuidance?.mode == .autoScoop(.salvage))
        #expect(snapshot.targetInformation?.status == snapshot.workGuidance?.status)
        let frame = Display.presentation(snapshot, width: Double(width), height: Double(height))
        let labels = frame.labels.map(\.text).joined(separator: " ").uppercased()
        for line in snapshot.autoHUDLines { #expect(labels.contains(line.uppercased())) }
        try fixture.capture(name: code == 48 ? "tab" : "r", scale: scale)
        let velocity = snapshot.flightWorldVelocity
        #expect(velocity.length > 0)
        try await fixture.press(12, "q")
        let released = await fixture.delegate.runtime.snapshot()
        #expect(released.workGuidance == nil && released.autoPilot.targetID == nil)
        #expect((released.flightWorldVelocity - velocity).length < 1e-8)
        #expect(
          released.commander.cargo == cargo
            && released.commander.salvageLedger.inventory == inventory)
        #expect(released.commander.salvageLedger.boundActor(for: lot) == actor)
        let stillPending = try #require(
          released.commander.salvageLedger.pendingLots.first { $0.identity == lot })
        #expect(
          stillPending.content == pending.content && stillPending.halfExtents == pending.halfExtents
        )
        #expect(stillPending.massKg == pending.massKg && stillPending.loot == pending.loot)
        #expect(released.commander.equipmentInventory == equipment)
        #expect(released.commander.equipmentPurchaseHistory == history)
        #expect(released.laserFlash == 0)
        try fixture.verifyPrivatePersistenceUnchanged()
      }
    }
  }
  @MainActor @Test func nativeMilitaryCoreCannotSubstituteForMiningModule() async throws {
    for (code, text) in [(UInt16(48), "\t"), (UInt16(15), "r")] {
      let (game, _) = try nativeMiningScene(mining: false)
      let fixture = try await NativeWorkFixture.open(game)
      defer { fixture.close() }
      try await fixture.press(3, "f")
      try await fixture.press(code, text)
      let snapshot = await fixture.delegate.runtime.snapshot()
      #expect(snapshot.workGuidance == nil && snapshot.autoPilot.targetID == nil)
      #expect(snapshot.message == "FIT A MINING TARGETING MODULE")
      #expect(snapshot.commander.cargo == game.commander.cargo)
      #expect(snapshot.commander.salvageLedger == game.commander.salvageLedger)
      #expect(snapshot.commander.equipmentInventory == game.commander.equipmentInventory)
      try fixture.verifyPrivatePersistenceUnchanged()
    }
  }
  @MainActor @Test func nativeHeldSteeringInterruptsActualMiningHoldWithoutVelocitySnap()
    async throws
  {
    var (game, _) = try nativeMiningScene()
    game.speed = 1
    let fixture = try await NativeWorkFixture.open(game)
    defer { fixture.close() }
    try await fixture.press(3, "f")
    try await fixture.press(15, "r")
    let before = await fixture.delegate.runtime.snapshot()
    #expect(before.workGuidance?.mode == .hold(.mining))
    #expect(before.flightWorldVelocity.length > 0)
    fixture.view.keyDown(with: try fixture.event(123, "", down: true))
    #expect(fixture.view.held.contains("left") && fixture.view.controls.roll != 0)
    await fixture.frame(0.001)
    let interrupted = await fixture.delegate.runtime.snapshot()
    #expect(interrupted.workGuidance == nil && interrupted.autoPilot.targetID == nil)
    #expect((interrupted.flightWorldVelocity - before.flightWorldVelocity).length < 1e-8)
    #expect(interrupted.laserFlash == 0 && !fixture.view.controls.fire)
    fixture.view.keyUp(with: try fixture.event(123, "", down: false))
    #expect(fixture.view.controls.roll == 0 && !fixture.view.held.contains("left"))
    #expect(interrupted.commander.cargo == before.commander.cargo)
    #expect(interrupted.commander.equipmentInventory == before.commander.equipmentInventory)
    #expect(interrupted.commander.miningLedger == before.commander.miningLedger)
    try fixture.verifyPrivatePersistenceUnchanged()
  }
}
