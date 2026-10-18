import AppKit
import Foundation
import Testing

@testable import EliteCore
@testable import EliteMac

struct FlightControlInputTests {
  @Test func changingWeaponStopsHeldFireUntilANewPressAndSkipsUnfittedTools() throws {
    var game = try empFixture()
    game.bodies = []
    game.selectFlightTool(.combatLaser)
    var held = Controls()
    held.fire = true
    game.tick(delta: 0.1, controls: held)
    let audio = game.dischargeAudio.events
    try #require(audio.last?.tool == .combatLaser)
    game.key("w")
    #expect(game.selectedFlightTool == .salvageCutter)
    #expect(!game.fittedFlightTools.contains(.miningLaser))
    game.key("w")
    #expect(game.selectedFlightTool == .empPirateBlaster)
    game.key("w")
    #expect(game.selectedFlightTool == .combatLaser)
    for _ in 0..<20 { game.tick(delta: 0.1, controls: held) }
    #expect(game.dischargeAudio.events == audio && game.workFireSuspended)
    game.key("return")
    game.tick(delta: 0.1, controls: held)
    #expect(game.dischargeAudio.events.count == audio.count + 1)
    #expect(!game.workFireSuspended)
  }

  @Test(arguments: ["w", "tab", "f", "q", "1", "k"])
  func actualInterruptionCancelsChargingAndHoldingCannotRestartIt(key: String) throws {
    var game = try empFixture()
    var held = Controls()
    held.fire = true
    game.tick(delta: 0.1, controls: held)
    try #require(game.commander.savedEMPCharge?.phase == .charging)
    let audio = game.dischargeAudio.events
    game.key(key)
    for _ in 0..<110 { game.tick(delta: 0.1, controls: held) }
    #expect(game.dischargeAudio.events == audio)
    #expect(game.commander.savedEMPState == nil)
    #expect(game.workFireSuspended)
  }

  @Test func releaseReturnCancelsActualChargeWithoutReleasingGuidance() throws {
    var game = try empFixture()
    game.key("tab")
    let target = game.autoPilot.targetActor
    var held = Controls()
    held.fire = true
    game.tick(delta: 0.1, controls: held)
    try #require(game.commander.savedEMPCharge?.phase == .charging)
    game.tick(delta: 0.1, controls: .init())
    #expect(game.commander.savedEMPCharge?.phase == .cancelled)
    #expect(game.autoPilot.targetActor == target)
    for _ in 0..<110 { game.tick(delta: 0.1) }
    #expect(game.commander.savedEMPState == nil && game.dischargeAudio.events.isEmpty)
  }

  @Test func selectedWeaponDisplayDoesNotBorrowAutonomousDischargesOrGlobalFlash() throws {
    var game = try empFixture()
    game.selectFlightTool(.combatLaser)
    game.observeFlightFire(held: false)
    game.laserFlash = 1
    game.dischargeAudio.record(.combatLaser)
    #expect(game.deriveFlightWeaponDisplay().status == "READY")
    game.energy = 1
    #expect(game.deriveFlightWeaponDisplay().status == "NO ENERGY")
    game.energy = 100
    game.laserHeat = 240
    #expect(game.deriveFlightWeaponDisplay().status == "OVERHEATED")
    game.laserHeat = 0
    game.fireCooldown = 0.7
    #expect(game.deriveFlightWeaponDisplay().status == "COOLDOWN 0.7S")
    game.fireCooldown = 0
    game.screen = .rear
    #expect(game.deriveFlightWeaponDisplay().status == "NOT FITTED IN VIEW")
    game.screen = .front
    game.selectFlightTool(.miningLaser)
    #expect(game.deriveFlightWeaponDisplay().weapon == "MINING LASER")
    #expect(game.deriveFlightWeaponDisplay().status == "NOT FITTED")
  }

  @Test func actualEMPChargeProgressIsDisplayedWithoutASelectedTrackingTarget() throws {
    var game = try empFixture()
    var held = Controls()
    held.fire = true
    game.tick(delta: 0.1, controls: held)
    try #require(game.autoPilot.targetActor == nil)
    #expect(game.deriveFlightWeaponDisplay().status == "CHARGING 0.0/10S")
    game.tick(delta: 0.1, controls: held)
    #expect(game.deriveFlightWeaponDisplay().status == "CHARGING 0.1/10S")
  }

  @Test func everyActualHelpPageIncludesScopedGeneratedControls() {
    for screen in Screen.allCases {
      for docked in [false, true] {
        for paused in [false, true] {
          var game = Game(executive: false)
          if !docked { game.launch() }
          game.screen = screen
          game.paused = paused
          for page in PlayerHelp.pages(for: game) {
            #expect(page.rows.count <= 16 && page.rows.allSatisfy { $0.count <= 40 })
            #expect(page.rows.contains("FLIGHT ONLY; MENUS KEEP THEIR KEYS"))
            for action in FlightControlAuthority.ActionID.allCases {
              let binding = action.binding
              let row =
                binding.key.uppercased() + " - " + binding.label.uppercased()
                + (action == .fire ? " (HOLD)" : "")
              #expect(page.rows.contains(row))
            }
          }
        }
      }
    }
  }

  @Test func weaponRowIsReservedAboveScannerAcrossViewsStylesAndSizes() throws {
    var game = Game(executive: false)
    game.launch()
    game.bodies = []
    for style in ShipDisplayStyle.allCases {
      game.commander.shipDisplayStyle = style
      for screen in [Screen.front, .rear, .left, .right] {
        game.screen = screen
        game.prepareFlightWeaponDisplay()
        for width in [320.0, 512, 768, 1512, 2560] {
          let frame = Display.cockpit(game, width: width, height: 768)
          let layout = CockpitLayout(game: game, width: width, height: 768)
          let scanner = try #require(frame.labels.first { $0.text == "Scanner" })
          for text in layout.weaponLines {
            let row = try #require(frame.labels.first { $0.text == text })
            #expect(row.bounds.x >= 0 && row.bounds.maxX <= width)
            #expect(row.bounds.y >= layout.weaponTop && row.bounds.maxY <= scanner.bounds.y)
          }
          #expect(layout.weaponLines.joined(separator: " ").contains("WEAPON:"))
        }
      }
    }
  }

  @Test @MainActor func nativeReturnAndKeypadEnterHoldFireAndContextRepeatsCannotRestartIt()
    async throws
  {
    _ = NSApplication.shared
    let view = GameView(frame: .init(x: 0, y: 0, width: 768, height: 768))
    var game = Game(executive: false)
    game.launch()
    let runtime = GameRuntime(game: game)
    let delegate = AppDelegate(
      restoreOnLaunch: false,
      saves: CommanderSaveSession(preferences: nil), runtime: runtime)
    view.game = await runtime.snapshot()
    func event(_ code: UInt16, down: Bool, repeatKey: Bool = false) throws -> NSEvent {
      try #require(
        NSEvent.keyEvent(
          with: down ? .keyDown : .keyUp, location: .zero, modifierFlags: [], timestamp: 0,
          windowNumber: 0, context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
          isARepeat: repeatKey, keyCode: code))
    }
    // Return retains the existing proof requirement; an unpainted key cannot queue a command.
    view.keyDown(with: try event(36, down: true))
    #expect(view.controls.fire && view.pending.isEmpty)
    view.keyUp(with: try event(36, down: false))
    for code: UInt16 in [36, 76] {
      try paintCampaignGalleryView(view)
      let painted = try #require(view.paintedMissionMenuPresentation)
      try #require(painted.page == nil)
      view.keyDown(with: try event(code, down: true))
      #expect(view.controls.fire && view.pending.count == 1)
      try verifyNativePaintedKey(view, key: "return", painted: painted)
      await delegate.processPendingCommands(in: view)
      let pressed = await runtime.snapshot()
      #expect(pressed.flightTrigger.held && pressed.flightTrigger.pressPending)
      #expect(view.pending.isEmpty)
      view.keyUp(with: try event(code, down: false))
      #expect(!view.controls.fire)
      await runtime.setControls(view.controls)
    }
    try paintCampaignGalleryView(view)
    let beforeHelpPaint = try #require(view.paintedMissionMenuPresentation)
    view.keyDown(with: try event(36, down: true))
    try verifyNativePaintedKey(view, key: "return", painted: beforeHelpPaint)
    await delegate.processPendingCommands(in: view)
    try #require(view.controls.fire)
    // Exercise real context transitions while Return remains physically held.
    await runtime.key("k")
    view.game = await runtime.snapshot()
    try #require(view.game.screen == .help)
    #expect(!view.controls.fire)
    await runtime.key("escape")
    view.game = await runtime.snapshot()
    try #require(view.game.screen == .front)
    view.keyDown(with: try event(36, down: true, repeatKey: true))
    #expect(!view.controls.fire && view.pending.isEmpty)
    try paintCampaignGalleryView(view)
    let painted = try #require(view.paintedMissionMenuPresentation)
    view.keyDown(with: try event(36, down: true))
    #expect(view.controls.fire && view.pending.count == 1)
    try verifyNativePaintedKey(view, key: "return", painted: painted)
    await delegate.processPendingCommands(in: view)
    let fresh = await runtime.snapshot()
    #expect(fresh.flightTrigger.pressPending && view.pending.isEmpty)
    await runtime.key("w")
    view.game = await runtime.snapshot()
    let interrupted = await runtime.snapshot()
    #expect(interrupted.workFireSuspended && !interrupted.flightTrigger.pressPending)
    view.keyDown(with: try event(36, down: true, repeatKey: true))
    #expect(view.controls.fire && view.pending.isEmpty)
    view.keyUp(with: try event(36, down: false))
    // Release/repress between simulation frames still supplies a genuine new queued press.
    try paintCampaignGalleryView(view)
    let changedPaint = try #require(view.paintedMissionMenuPresentation)
    view.keyDown(with: try event(36, down: true))
    #expect(view.controls.fire && view.pending.count == 1)
    try verifyNativePaintedKey(view, key: "return", painted: changedPaint)
    await delegate.processPendingCommands(in: view)
    let repressed = await runtime.snapshot()
    #expect(repressed.flightTrigger.pressPending && view.pending.isEmpty)
    view.keyUp(with: try event(36, down: false))
    await runtime.setControls(view.controls)
  }
}

extension FlightControlInputTests {
  @Test(arguments: ["q", "w", "tab", "f"])
  func actorSafetyStopSurvivesAnActualRefusedHotWorkFlush(key: String) async throws {
    var (game, _) = try NativePagedSalvageFixture.game()
    let body = try #require(game.bodies.first { $0.physical?.salvage?.wreck != nil })
    game.beginWorkGuidance(body: body, mode: .hold(.salvage), velocity: .init(20, -10, 50))
    try #require(game.workGuidance != nil)
    let cut = game.fireSalvageCutter(delta: 0.1)
    try #require(cut && game.nativeSalvageWork != nil)
    // A new actor invalidates the old transient authority epoch. Its real cold flush must refuse.
    let runtime = GameRuntime(game: game)
    var held = Controls()
    held.fire = true
    await runtime.setControls(held)
    let before = await runtime.snapshot()
    let hot = try #require(before.nativeSalvageWork)
    try #require(!before.nativeSalvageHotWorkIsCurrent(hot))
    let momentum = before.flightWorldVelocity
    await runtime.key(key)
    let stopped = await runtime.snapshot()
    #expect(stopped.workFireSuspended && !stopped.flightTrigger.pressPending)
    #expect(stopped.flightWeaponDisplay == stopped.deriveFlightWeaponDisplay())
    #expect(stopped.flightWeaponDisplay.status != "READY")
    let stoppedCommanderPreserved = stopped.commander == before.commander
    let stoppedBodiesPreserved = stopped.bodies == before.bodies
    #expect(stoppedCommanderPreserved && stoppedBodiesPreserved)
    #expect(stopped.nativeSalvageWork?.cycle == hot.cycle)
    #expect(stopped.nativeSalvageWork?.originalCycle == hot.originalCycle)
    // Match existing Q/work-release frame conversion checks across all three components.
    #expect((stopped.flightWorldVelocity - momentum).length < 1e-9)
    #expect(stopped.commander.flightSimulation.pose == before.commander.flightSimulation.pose)
    if key == "q" {
      #expect(stopped.workGuidance == nil && stopped.workBraking == nil)
      #expect(stopped.autoPilot.targetActor == nil)
    } else {
      #expect(stopped.selectedFlightTool == before.selectedFlightTool)
      #expect(stopped.autoPilot.targetActor == before.autoPilot.targetActor)
      #expect(stopped.workTargetFilter == before.workTargetFilter)
      #expect(stopped.workGuidance?.parent == before.workGuidance?.parent)
      #expect(stopped.message == "MISSION SAVE FAILED - ACTION NOT COMMITTED")
    }
    // The native frame resubmits the still-held level; it is not a fresh Return press.
    await runtime.setControls(held)
    let advanced = await runtime.advance(delta: 0.1)
    let advancedCommanderPreserved = advanced.commander == before.commander
    let advancedBodiesPreserved = advanced.bodies == before.bodies
    #expect(advancedCommanderPreserved && advancedBodiesPreserved)
    #expect((advanced.flightWorldVelocity - momentum).length < 1e-9)
    #expect(advanced.commander.flightSimulation.pose == before.commander.flightSimulation.pose)
    #expect(advanced.workFireSuspended && !advanced.flightTrigger.pressPending)
    #expect(advanced.dischargeAudio.events == before.dischargeAudio.events)
    #expect(advanced.nativeSalvageWork?.cycle == hot.cycle)
  }

  @Test func refusedWriterRollsBackTargetAcquisitionButCannotRestoreHeldEMPFire() async throws {
    var (game, _) = try NativePagedSalvageFixture.game()
    let body = try #require(game.bodies.first { $0.physical?.salvage?.wreck != nil })
    // Retain an actual native parent, but exercise the same visible legacy-spin canonicalization
    // that a real Tab acquisition changes. This guarantees a persistent candidate write.
    let index = try #require(game.bodies.firstIndex { $0.id == body.id })
    game.bodies[index].physical?.canonicalSpin = false
    game.bodies[index].rotationRate = 0.1
    game.bodies[index].position.x += 10000
    try game.commander.grantEquipment(
      Equipment.empPirateBlaster,
      at: .utility(.empPirateBlaster), provenance: .grant("refused input charge"))
    let catalogue = try #require(ShipCatalogue.ship("SH023"))
    let craft = try #require(catalogue.game)
    var target = SpaceBody(id: game.nextBodyID, hull: .cobra, position: .init(0, 0, 1000))
    target.rotationRate = 0
    target.energy = min(77, craft.energy * 0.6)
    game.nextBodyID += 1
    game.bodies.append(target)
    game.ensurePhysicalActors()
    let targetIndex = try #require(game.bodies.firstIndex { $0.id == target.id })
    game.bodies[targetIndex].physical?.catalogueShipID = catalogue.id
    game.bodies[targetIndex].physical?.npc?.resources = .stock(craft)
    game.selectFlightTool(.empPirateBlaster)
    let charged = game.fireEMPPirateBlaster()
    try #require(charged && game.commander.savedEMPCharge?.phase == .charging)
    game.workTargetFilter = .salvage
    let folder = try NativePagedSalvageFixture.folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
    let runtime = GameRuntime(game: game, saveURL: file)
    var held = Controls()
    held.fire = true
    await runtime.setControls(held)
    let before = await runtime.snapshot()
    try #require(before.requiresScriptDurability)
    await runtime.key("tab")
    let refused = await runtime.snapshot()
    #expect(refused.message == "MISSION SAVE FAILED - ACTION NOT COMMITTED")
    #expect(refused.commander == before.commander && refused.bodies == before.bodies)
    #expect(refused.autoPilot.targetActor == before.autoPilot.targetActor)
    #expect(refused.selectedFlightTool == before.selectedFlightTool)
    #expect(refused.workFireSuspended && !refused.flightTrigger.pressPending)
    #expect(refused.flightWeaponDisplay == refused.deriveFlightWeaponDisplay())
    #expect(refused.flightWeaponDisplay.status == "BLOCKED: FRESH RETURN")
    #expect(refused.commander.savedEMPCharge == before.commander.savedEMPCharge)
    let advanced = await runtime.advance(delta: 0.1)
    #expect(advanced.dischargeAudio.events == before.dischargeAudio.events)
    #expect(advanced.commander.savedEMPCharge?.phase == .cancelled)
    #expect(advanced.commander.savedEMPState == nil)
    #expect(advanced.nativeSalvageWork == nil)
    #expect(advanced.workGuidance == nil)
  }
}
