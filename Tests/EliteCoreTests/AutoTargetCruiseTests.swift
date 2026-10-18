import Foundation
import Testing

@testable import EliteCore

struct AutoTargetCruiseTests {
  @Test(arguments: ["SH023", "SH009"])
  func actualFittedHullFarApproachUsesItsAvailableSpeedAndThrustWithoutExceedingOneBudget(
    shipID: String
  ) async throws {
    var game = Game(executive: false)
    game.commander.shipID = shipID
    let startingRounds = min(3, game.commander.nativePerformance.missiles)
    game.commander.missiles = startingRounds
    game.commander.installTargetingComputer(.docking)
    try game.commander.prepareEquipment()
    let destination = try #require(
      game.knownSystems.first {
        $0.id != game.commander.system && $0.id != Plugh.systemID && $0.government == 7
          && game.currentSystem.distance(to: $0) > 0
          && game.currentSystem.distance(to: $0) <= game.commander.maximumJumpDistance
      })
    game.launch()
    game.selectedSystem = destination.id
    // The real arrival producer supplies station, ordinary traffic, celestials and bindings.
    game.arrive()
    try #require(game.commander.system == destination.id && !game.docked)
    try #require(game.currentSystem.government == 7)
    try #require(game.commander.shipID == shipID && game.bodies.count > 1)
    try #require(Set(game.celestials.map(\.kind)) == [.sun, .planet])
    let station = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
    let actor = try #require(station.physical?.identity)
    let craft = game.commander.performance
    if shipID == "SH023" { try #require(craft.speed == 32 && craft.acceleration == 12) }
    if shipID == "SH009" {
      try #require(craft.acceleration * 18 > AutoTargetControl.policyLimits.acceleration)
    }
    let speedLimit = craft.speed * 18
    let acceleration = craft.acceleration * 18
    let runtime = GameRuntime(game: game)
    for _ in 0..<32 {
      await runtime.key("tab")
      game = await runtime.snapshot()
      if game.autoPilot.targetActor == actor { break }
    }
    try #require(game.autoPilot.targetActor == actor && game.dockingComputer)
    let delta = 0.05
    var peakSpeed = 0.0
    var peakImpulse = 0.0
    for _ in 0..<80 {
      let beforeVelocity = game.flightWorldVelocity
      let beforePosition = game.commander.flightSimulation.pose.position
      game = await runtime.advance(delta: delta)
      let speed = game.flightWorldVelocity.length
      peakSpeed = max(peakSpeed, speed)
      peakImpulse = max(peakImpulse, (game.flightWorldVelocity - beforeVelocity).length)
      #expect(speed <= speedLimit + 1e-8)
      #expect((game.flightWorldVelocity - beforeVelocity).length <= acceleration * delta + 1e-8)
      #expect(
        (game.commander.flightSimulation.pose.position - beforePosition).length
          <= speedLimit * delta + 1e-8)
      #expect(game.autoPilot.targetActor == actor && !game.docked)
      #expect(game.autoPilot.status == "APPROACHING" && !game.autoPilot.finalApproach)
    }
    #expect(peakSpeed > 144 && game.flightWorldVelocity.length > 144)
    #expect(peakImpulse >= acceleration * delta - 1e-8)
    #expect(game.autoTargetBody?.position.length ?? 0 > 10000)
  }

  @Test func fastLowAccelerationCruiseReservesBrakingDistanceAndOneCompleteStep() {
    for distance in [0.01, 1, 40, 180, 720, 5000, 16000] {
      for acceleration in [0.1, 8.1, 216, 270, 337.5] {
        for delta in [0.02, 0.05, 0.1] {
          let speed = AutoTargetControl.approachCruiseSpeed(
            distance: distance, acceleration: acceleration, delta: delta, maximumSpeed: 1800)
          #expect(speed.isFinite && speed >= 0 && speed <= 1800)
          // Independent physical inequality: one frame of travel plus a complete stop fits.
          #expect(speed * delta + speed * speed / (2 * acceleration) <= distance + 1e-8)
          #expect(speed <= distance * 0.8 + 1e-8)
        }
      }
    }
    let slow = AutoTargetControl.approachCruiseSpeed(
      distance: 5000, acceleration: 0.1, delta: 0.1, maximumSpeed: 1800)
    #expect(slow < 144)
    for distance in [1e-300, 1e300, Double.greatestFiniteMagnitude] {
      let speed = AutoTargetControl.approachCruiseSpeed(
        distance: distance, acceleration: 240, delta: 0.05,
        maximumSpeed: Double.greatestFiniteMagnitude)
      #expect(speed.isFinite && speed >= 0)
    }
    let hugeStep = AutoTargetControl.approachCruiseSpeed(
      distance: 1e300, acceleration: 240, delta: Double.greatestFiniteMagnitude,
      maximumSpeed: 1800)
    #expect(hugeStep == 0)
  }

  @Test func referenceAlignmentDoorAndObstructionPoliciesRemainConservative() throws {
    let craft = try #require(ShipCatalogue.ship("SH023")?.game)
    let limits = RelativeWorkLimits(
      acceleration: craft.acceleration * 18, speed: craft.speed * 18,
      pitchRate: craft.pitch, yawRate: craft.yaw, rollRate: craft.roll)
    let delta = 0.05
    var reference = AutoTargetControl()
    let far = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 16000))
    for _ in 0..<50 {
      _ = reference.steer(target: far, delta: delta)
      #expect(reference.velocity.length <= 144 + 1e-8)
    }
    #expect(reference.velocity.length == 144)
    var door = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 1090))
    door.rotationRate = 0
    var final = AutoTargetControl()
    for _ in 0..<20 {
      let before = final.velocity
      _ = final.steer(target: door, delta: delta, limits: limits)
      #expect((final.velocity - before).length <= limits.acceleration * delta + 1e-8)
      #expect(final.velocity.length <= 96 + 1e-8)
    }
    #expect(final.finalApproach && final.status == "FINAL APPROACH")
    door.position.z = 280
    for _ in 0..<20 {
      let before = final.velocity
      _ = final.steer(target: door, delta: delta, limits: limits)
      #expect((final.velocity - before).length <= limits.acceleration * delta + 1e-8)
      #expect(final.velocity.length <= max(48, before.length) + 1e-8)
    }
    #expect(final.velocity.length <= 48 + 1e-8)
    var alignment = AutoTargetControl()
    door.position.z = 1090
    door.rotation = 0.6
    _ = alignment.steer(target: door, delta: delta, limits: limits)
    #expect(!alignment.finalApproach && alignment.velocity == .init(0, 0, 0))
    #expect(alignment.status == "MATCHING SPIN")
    var obstructed = AutoTargetControl()
    var closed = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 1600))
    closed.orientation.rotate(pitch: 0, roll: 0, yaw: .pi)
    let rates = obstructed.steer(target: closed, delta: delta, limits: limits)
    #expect(abs(rates.yaw) > 0 && abs(rates.yaw) <= limits.yawRate)
    #expect(obstructed.velocity == .init(0, 0, 0) && !obstructed.finalApproach)
  }
}

extension AutoTargetCruiseTests {
  @Test func actualHighThrustHullUsesAvailableBrakingAndCoastsDownInheritedOverspeed() throws {
    var game = Game(executive: false)
    game.commander.shipID = "SH009"
    let startingRounds = min(3, game.commander.nativePerformance.missiles)
    game.commander.missiles = startingRounds
    try game.commander.prepareEquipment(legacy: false)
    let limits = game.workLimits
    try #require(limits.acceleration > AutoTargetControl.policyLimits.acceleration)
    let distance = 900.0
    let delta = 0.1
    let speed = AutoTargetControl.approachCruiseSpeed(
      distance: distance, acceleration: limits.acceleration, delta: delta,
      maximumSpeed: limits.speed)
    let oldCap = AutoTargetControl.approachCruiseSpeed(
      distance: distance, acceleration: AutoTargetControl.policyLimits.acceleration, delta: delta,
      maximumSpeed: limits.speed)
    #expect(speed > oldCap)
    #expect(speed * delta + speed * speed / (2 * limits.acceleration) <= distance + 1e-8)
    var control = AutoTargetControl()
    let inherited = Vector3(0, 0, limits.speed * 2)
    control.setApproachVelocity(inherited)
    _ = control.steer(
      target: .init(id: 0, hull: .station, position: .init(0, 0, 16000)),
      delta: delta, limits: limits)
    #expect(abs((control.velocity - inherited).length - limits.acceleration * delta) < 1e-8)
    #expect(control.velocity.length > limits.speed && control.velocity.z < inherited.z)
  }
}
