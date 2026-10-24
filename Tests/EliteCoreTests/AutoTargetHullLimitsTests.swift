import Foundation
import Testing

@testable import EliteCore

struct AutoTargetHullLimitsTests {
  @Test func runtimeTargetFacingAndDockingRespectHeavyHullAngularRates() throws {
    for hull in [Hull.cobra, .station] {
      var game = Game(executive: false)
      game.commander.shipID = "SH043"
      game.commander.fuel = game.commander.fuelCapacity
      game.energy = game.commander.performance.energy
      game.frontShield = game.commander.shieldCapacity
      game.rearShield = game.commander.rearShieldCapacity
      game.commander.installTargetingComputer(.docking)
      game.commander.autoTarget = true
      try game.commander.prepareEquipment()
      #expect(game.commander.valid)
      game.launch()
      game.speed = 0
      game.celestials = []
      game.bodies = [
        .init(
          id: hull == .station ? 0 : 5, hull: hull,
          position: .init(1800, 1400, 1800))
      ]
      game.key("tab")
      #expect(game.autoPilot.targetID != nil)
      game.tick(delta: 0.1)
      let craft = game.commander.performance
      #expect(abs(game.pitch) <= craft.pitch && abs(game.yaw) <= craft.yaw)
      #expect(abs(game.roll) <= craft.roll)
      #expect(abs(game.pitch) > 0 && abs(game.yaw) > 0)
    }
  }

  @Test func stationAvoidanceUsesOneHullThrustBudgetWithoutOutwardVelocitySnap() throws {
    let limits = try heavyLimits()
    var control = AutoTargetControl()
    control.setApproachVelocity(.init(0, 0, 120))
    let before = control.velocity
    let station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 350))
    _ = control.steer(target: station, delta: 0.1, limits: limits)
    #expect(control.status == "BRAKING FOR CLEARANCE")
    #expect((control.velocity - before).length <= limits.acceleration * 0.1 + 1e-9)
    #expect(control.velocity.z > 0 && control.velocity.z < before.z)
  }

  @Test func externallyInheritedOverspeedBrakesWithinHullThrustInsteadOfClamping() throws {
    let limits = try heavyLimits()
    var control = AutoTargetControl()
    control.setApproachVelocity(.init(0, 0, 600))
    let before = control.velocity
    let station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, -2400))
    _ = control.steer(target: station, delta: 0.1, limits: limits)
    #expect((control.velocity - before).length <= limits.acceleration * 0.1 + 1e-9)
    #expect(control.velocity.length > limits.speed && control.velocity.length < before.length)
  }

  @Test func stationSpinBeyondHullRollAuthorityHoldsWithoutClaimingFinalApproach() throws {
    let limits = try heavyLimits()
    var control = AutoTargetControl()
    var station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 1090))
    station.rotationRate = 0.3
    #expect(station.rotationRate > limits.rollRate)
    for _ in 0..<100 {
      let rates = control.steer(target: station, delta: 0.02, limits: limits)
      #expect(abs(rates.roll ?? 0) <= limits.rollRate)
      #expect(!control.ready && !control.finalApproach)
      #expect(control.velocity == .init(0, 0, 0))
    }
    #expect(control.status == "STATION SPIN EXCEEDS HULL LIMIT")
  }

  @Test(arguments: ["unknown", "mixed", "infeasible", "approach"])
  func returningSpinAcquisitionCannotBypassCurrentFactsOrActualHullAuthority(condition: String)
    throws
  {
    let limits = try heavyLimits()
    var station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 1090))
    station.rotationRate = 0
    var control = AutoTargetControl()
    _ = control.steer(target: station, delta: 0.1, limits: limits)
    try #require(control.finalApproach)
    control.setApproachVelocity(.init(0, 0, 40))
    var facts = StationAutoGuidance(
      aim: .init(600, 0, 0), lateralVelocity: .init(80, 0, 0),
      hazard: .active, interruptionAllowed: true, clearanceRadius: 400, handoverAllowed: true)
    _ = control.steer(target: station, delta: 0.1, limits: limits, defence: facts)
    try #require(control.stationDefencePhase == .defending)
    facts.hazard = .closing
    _ = control.steer(target: station, delta: 0.1, limits: limits, defence: facts)
    try #require(control.stationDefencePhase == .returning)
    station.position.z = 1600
    station.rotation = 0.7
    switch condition {
    case "unknown":
      facts.hazard = .unknown
      facts.handoverAllowed = false
    case "mixed": facts.handoverAllowed = false
    case "infeasible": station.rotationRate = 0.3
    case "approach":
      control = AutoTargetControl()
      facts.hazard = .clear
    default: break
    }
    if condition == "infeasible" { try #require(station.rotationRate > limits.rollRate) }
    control.setApproachVelocity(.init(0, 0, 100))
    let before = control.velocity
    let rates = control.steer(target: station, delta: 0.1, limits: limits, defence: facts)
    #expect(rates.roll == 0 && control.rollRate == 0)
    #expect(!control.ready && !control.finalApproach)
    #expect((control.velocity - before).length <= limits.acceleration * 0.1 + 1e-8)
  }

  private func heavyLimits() throws -> RelativeWorkLimits {
    let performance = try #require(ShipCatalogue.ship("SH043")?.game)
    return .init(
      acceleration: performance.acceleration * 18, speed: performance.speed * 18,
      pitchRate: performance.pitch, yawRate: performance.yaw, rollRate: performance.roll)
  }
}
