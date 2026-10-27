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
    game.commander.fuel = game.commander.fuelCapacity
    // Authenticated G01-S000 has a government-seven neighbour within the stock seven-LY reach.
    game.commander.system = 0
    game.selectedSystem = 0
    game.market = MarketItem.at(game.currentSystem)
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
    let peak = verifyMovingFinalApproach(&final, station: &door, limits: limits, delta: delta)
    #expect(peak > 144)
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

private func verifyMovingFinalApproach(
  _ control: inout AutoTargetControl, station: inout SpaceBody, limits: RelativeWorkLimits,
  delta: Double
) -> Double {
  var peak = 0.0
  var fullImpulse = 0.0
  var crossed = false
  let terminal = min(48, limits.speed)
  for _ in 0..<2000 {
    let before = control.velocity
    let distance = -station.entrancePosition.dot(station.entranceNormal)
    let steering = control.steer(target: station, delta: delta, limits: limits)
    let speed = control.velocity.length
    peak = max(peak, speed)
    fullImpulse = max(fullImpulse, (control.velocity - before).length)
    #expect((control.velocity - before).length <= limits.acceleration * delta + 1e-8)
    #expect(speed <= limits.speed + 1e-8)
    if speed > terminal + 1e-8 {
      // Independent physical check after this frame's impulse, before its actual translation.
      let travelAndBrake =
        speed * delta + (speed * speed - terminal * terminal) / (2 * limits.acceleration)
      #expect(travelAndBrake <= distance - 200 + 1e-7)
    }
    if distance <= 200 { #expect(speed <= terminal + 1e-8) }
    station.position = station.position - control.velocity * delta
    let afterDistance = -station.entrancePosition.dot(station.entranceNormal)
    if distance >= 0 && afterDistance < 0 {
      crossed = true
      #expect(speed < 144 && speed <= terminal + 1e-8)
      #expect(station.containsPlayer && station.canEnter(roll: steering.roll ?? 0, speed: speed))
      #expect(
        control.facingError < 0.03 && abs(control.phaseError) < 0.08 && control.rateError < 0.06)
      break
    }
  }
  #expect(crossed)
  #expect(fullImpulse >= limits.acceleration * delta - 1e-8)
  return peak
}

extension AutoTargetCruiseTests {
  @Test(arguments: ["SH009", "SH043"])
  func nativeHighAndLowThrustFinalApproachesReserveBrakingToRealEntryGate(shipID: String) throws {
    let craft = try #require(ShipCatalogue.ship(shipID)?.game)
    let limits = RelativeWorkLimits(
      acceleration: craft.acceleration * 18, speed: craft.speed * 18,
      pitchRate: craft.pitch, yawRate: craft.yaw, rollRate: craft.roll)
    var station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 1090))
    station.rotationRate = 0
    var control = AutoTargetControl()
    let peak = verifyMovingFinalApproach(&control, station: &station, limits: limits, delta: 0.05)
    if shipID == "SH009" { #expect(peak > 144) }
  }

  @Test(arguments: ["SH023", "SH009", "SH043"])
  func inheritedFinalOverspeedBrakesFullVectorBeforeLateralCorrectionAndCannotClaimEntry(
    shipID: String
  ) throws {
    let craft = try #require(ShipCatalogue.ship(shipID)?.game)
    let limits = RelativeWorkLimits(
      acceleration: craft.acceleration * 18, speed: craft.speed * 18,
      pitchRate: craft.pitch, yawRate: craft.yaw, rollRate: craft.roll)
    var control = AutoTargetControl()
    var station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 1090))
    station.rotationRate = 0
    _ = control.steer(target: station, delta: 0.05, limits: limits)
    try #require(control.finalApproach)
    station.position = .init(30, 0, 280)
    let before = Vector3(90, -60, max(limits.speed * 2, 144 * 2))
    control.setApproachVelocity(before)
    _ = control.steer(target: station, delta: 0.05, limits: limits)
    let impulse = limits.acceleration * 0.05
    let physicallyBraked = before.unit * (before.length - impulse)
    #expect((control.velocity - physicallyBraked).length < 1e-8)
    #expect(abs((control.velocity - before).length - impulse) < 1e-8)
    #expect(control.velocity.length > limits.speed && !control.ready)
    #expect(control.status == "HOLDING FOR ALIGNMENT")
    station.position = .init(0, 0, 90)
    #expect(!station.canEnter(roll: 0, speed: control.velocity.length))
  }

  @Test(arguments: ["facing", "phase", "lateral"])
  func unalignedFinalApproachNeverAddsForwardAcceleration(condition: String) {
    var station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 1090))
    station.rotationRate = 0
    var control = AutoTargetControl()
    _ = control.steer(target: station, delta: 0.1)
    control.setApproachVelocity(.init(10, -5, 120))
    switch condition {
    case "facing": station.orientation.rotate(pitch: 0, roll: 0, yaw: 0.2)
    case "phase": station.rotation = 0.2
    case "lateral": station.position.x = 30
    default: break
    }
    let before = control.velocity
    let inward = station.entranceNormal * -1
    _ = control.steer(target: station, delta: 0.1)
    #expect(control.status == "HOLDING FOR ALIGNMENT" && !control.ready)
    #expect(control.velocity.dot(inward) <= before.dot(inward))
    #expect((control.velocity - before).length <= 24 + 1e-8)
  }

  @Test func finalCruiseEnvelopeUsesFinitePhysicalBrakingAndTerminalBoundary() {
    for acceleration in [8.1, 216, 337.5] {
      for delta in [0.02, 0.05, 0.1] {
        for distance in [-25.0, -0.1, 0.0, 199, 200, 200.01, 201, 400, 1000, 1e300] {
          let speed = AutoTargetControl.finalCruiseSpeed(
            distance: distance, delta: delta, acceleration: acceleration, maximumSpeed: 576)
          #expect(speed.isFinite && speed >= 0 && speed <= 576)
          if distance < 0 { #expect(speed == 0) }
          if distance >= 0 && distance <= 200 { #expect(speed == 48) }
          if speed > 48 + 1e-8 {
            #expect(
              speed * delta + (speed * speed - 48 * 48) / (2 * acceleration)
                <= distance - 200 + 1e-7)
          }
        }
      }
    }
    for distance in [1e-300, 1e300, Double.greatestFiniteMagnitude] {
      let speed = AutoTargetControl.finalCruiseSpeed(
        distance: distance, delta: 0.1, acceleration: 216,
        maximumSpeed: Double.greatestFiniteMagnitude)
      #expect(speed.isFinite && speed >= 0)
    }
    let extreme = AutoTargetControl.finalCruiseSpeed(
      distance: Double.greatestFiniteMagnitude, delta: 0.1,
      acceleration: Double.greatestFiniteMagnitude, maximumSpeed: 1800)
    #expect(extreme.isFinite && extreme >= 0 && extreme <= 1800)
  }
}
