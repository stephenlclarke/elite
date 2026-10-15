import Foundation
import Testing

@testable import EliteCore
@testable import EliteMac

@Suite struct FlightPerformanceScenarioTests {
  @Test func boundedTraceIsSafeDeterministicAndUsesNormalResources() async {
    for variant in FlightPerformanceScenario.Variant.allCases {
      let scenario = FlightPerformanceScenario(variant: variant)
      let initial = scenario.makeGame()
      let runtime = GameRuntime(game: initial)
      let replay = GameRuntime(game: scenario.makeGame())
      #expect(initial.commander.shipDisplayStyle == .shadedPanels)
      #expect(!initial.commander.unlimitedFuel && !initial.commander.unlimitedCash)
      let peaceful = initial.bodies.allSatisfy { !$0.hostile }
      #expect(initial.bodies.count == 4 && peaceful)
      for tick in 0..<FlightPerformanceScenario.tickCount {
        let controls = scenario.controls(forTick: tick)
        await runtime.setControls(controls)
        await replay.setControls(controls)
        let game = await runtime.advance(delta: FlightPerformanceScenario.delta)
        let same = await replay.advance(delta: FlightPerformanceScenario.delta)
        #expect(game.screen != .gameOver && !game.docked)
        #expect(game.bodies == same.bodies && game.celestials == same.celestials)
        #expect(game.commander.legal == initial.commander.legal)
        #expect(game.commander.cargo == initial.commander.cargo)
        #expect(game.energy > 0 && game.energy <= game.commander.performance.energy)
        #expect(game.frontShield <= game.commander.shieldCapacity)
        #expect(game.rearShield <= game.commander.shieldCapacity)
        #expect(game.cabinTemperature == 0)
        for body in game.bodies {
          #expect(body.position.x.isFinite && body.position.y.isFinite && body.position.z.isFinite)
        }
        for body in game.celestials {
          #expect(body.position.length.isFinite)
          #expect(body.position.length - body.radius > 2000)
          if body.kind == .sun { #expect(body.position.length > body.radius * 4) }
        }
      }
    }
  }

  @Test @MainActor func nativeDiagnosticHookUsesActorTraceAndStopsBeforeWorldCanDrift() async {
    let scenario = FlightPerformanceScenario(variant: .combined)
    let delegate = AppDelegate(restoreOnLaunch: true, performanceScenario: scenario)
    let view = GameView()
    var usedWallClockDelta = false
    #expect(!delegate.restoreOnLaunch)
    for _ in 0..<FlightPerformanceScenario.tickCount {
      await delegate.processFrame(in: view) {
        usedWallClockDelta = true
        return 99
      }
    }
    #expect(!usedWallClockDelta && view.game.screen != .gameOver)
    let stopped = await delegate.runtime.snapshot()
    await delegate.processFrame(in: view) { 99 }
    let after = await delegate.runtime.snapshot()
    #expect(after.time == stopped.time && after.bodies == stopped.bodies)
    #expect(after.celestials == stopped.celestials && after.energy == stopped.energy)
  }

  @Test func nativePitchTraceIncludesReleaseAndImmediateReversal() {
    let scenario = FlightPerformanceScenario(variant: .combined)
    for (tick, expected) in [
      (119, 0.0), (120, -1), (179, -1), (180, 0),
      (239, 0), (240, 1), (299, 1), (300, -1), (359, -1), (360, 0), (479, 0),
    ] {
      let controls = scenario.controls(forTick: tick)
      #expect(controls.pitch == expected)
      #expect(controls.yaw == 0 && controls.roll == 0 && controls.throttle == 0 && !controls.fire)
    }
  }
}
