import Testing

@testable import EliteCore

struct FlightWeaponSnapshotTests {
  @Test func actorPublishesCurrentWeaponChargeAndInputChangesBeforeReturningItsSnapshot()
    async throws
  {
    let game = try empFixture()
    let runtime = GameRuntime(game: game)
    let initial = await runtime.snapshot()
    #expect(initial.flightWeaponDisplay == initial.deriveFlightWeaponDisplay())
    #expect(initial.flightWeaponDisplay.status == "BLOCKED: FRESH RETURN")
    var held = Controls()
    held.fire = true
    await runtime.setControls(held)
    let charging = await runtime.advance(delta: 0.1)
    #expect(charging.commander.savedEMPCharge?.phase == .charging)
    #expect(charging.flightWeaponDisplay.status == "CHARGING 0.0/10S")
    #expect(charging.flightWeaponDisplay == charging.deriveFlightWeaponDisplay())
    let progressed = await runtime.advance(delta: 0.1)
    #expect(progressed.flightWeaponDisplay.status == "CHARGING 0.1/10S")
    #expect(charging.flightWeaponDisplay.status == "CHARGING 0.0/10S")
    await runtime.key("w")
    let changed = await runtime.snapshot()
    #expect(changed.selectedFlightTool == .combatLaser)
    #expect(changed.flightWeaponDisplay.weapon == "MAIN LASER")
    #expect(changed.flightWeaponDisplay.status == "BLOCKED: FRESH RETURN")
    #expect(changed.flightWeaponDisplay == changed.deriveFlightWeaponDisplay())
    await runtime.setControls(.init())
    let released = await runtime.advance(delta: 0.1)
    #expect(released.commander.savedEMPCharge?.phase == .cancelled)
    #expect(released.flightWeaponDisplay.status == "READY")
    #expect(released.flightWeaponDisplay == released.deriveFlightWeaponDisplay())
    #expect(released.dischargeAudio.events.isEmpty)
  }

  @Test func inactiveAdvanceAndViewTransitionsAlsoPublishCurrentPresentation() async throws {
    let runtime = GameRuntime(game: try empFixture())
    await runtime.setControls(.init())
    let ready = await runtime.snapshot()
    #expect(ready.flightWeaponDisplay.status == "READY")
    await runtime.key("1")
    let rear = await runtime.advance(delta: 0)
    #expect(rear.screen == .rear)
    #expect(rear.flightWeaponDisplay.status == "BLOCKED: FRONT VIEW")
    #expect(rear.flightWeaponDisplay == rear.deriveFlightWeaponDisplay())
    await runtime.key("k")
    let help = await runtime.advance(delta: 0.1)
    #expect(help.screen == .help)
    #expect(help.flightWeaponDisplay == help.deriveFlightWeaponDisplay())
    #expect(
      help.commander.flightSimulation.physicalTime == rear.commander.flightSimulation.physicalTime)
  }

  @Test func directlyConstructedOffscreenScenesPrepareExplicitlyAndPaintUsesOnlyTheProjection()
    throws
  {
    var game = try empFixture()
    #expect(game.flightWeaponDisplay.status == "SNAPSHOT REQUIRED")
    game.prepareFlightWeaponDisplay()
    let projection = game.flightWeaponDisplay
    #expect(projection == game.deriveFlightWeaponDisplay())
    for width in [512.0, 768, 1512] {
      let frame = Display.cockpit(game, width: width, height: 768)
      let layout = CockpitLayout(game: game, width: width, height: 768)
      #expect(layout.weaponLines.joined(separator: " ") == projection.text)
      #expect(layout.weaponLines.allSatisfy { line in frame.labels.contains { $0.text == line } })
      #expect(game.flightWeaponDisplay == projection)
    }
    game.screen = .rear
    game.prepareFlightWeaponDisplay()
    #expect(game.flightWeaponDisplay.status == "BLOCKED: FRONT VIEW")
  }
}
