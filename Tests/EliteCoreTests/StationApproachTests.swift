import Foundation
import Testing

@testable import EliteCore

private func approachGame(
  position: Vector3, pitch: Double = 0, roll: Double = 0, yaw: Double = 0,
  spin: Double = 0.3, speed: Double = 0
) -> Game {
  var game = Game(executive: false)
  game.commander.installTargetingComputer(.docking)
  game.launch()
  #expect(game.commander.equipmentInventory != nil && game.commander.targetingTier == .docking)
  game.commander.autoTarget = true
  game.speed = speed
  var station = SpaceBody(id: 0, hull: .station, position: position)
  station.orientation.rotate(pitch: pitch, roll: roll, yaw: yaw)
  station.rotation = 1.4
  station.rotationRate = spin
  game.bodies = [station]
  game.key("tab")
  return game
}

@Test func rearAvoidanceWaypointDoesNotOrbitWithTheStationDoorwayPhase() {
  var station = SpaceBody(id: 0, hull: .station, position: .init(300, 100, 2400))
  station.orientation.rotate(pitch: 0.1, roll: 0.4, yaw: .pi)
  var first = AutoTargetControl()
  let baseline = first.steer(target: station, delta: 0.02)
  for phase in [0.7, 1.4, 2.8, 4.2] {
    station.rotation = phase
    var control = AutoTargetControl()
    let steering = control.steer(target: station, delta: 0.02)
    #expect(abs(steering.pitch - baseline.pitch) < 1e-12)
    #expect(abs(steering.yaw - baseline.yaw) < 1e-12)
    #expect(control.velocity == first.velocity)
  }
}

@Test func stationTransitFacesItsSafeWaypointThenStopsBeforeFacingTheDoor() {
  var game = approachGame(position: .init(0, 0, 2400), yaw: .pi)
  var forwardTransitFrames = 0
  var stoppedAlignmentFrames = 0
  for _ in 0..<9000 where !game.autoPilot.finalApproach && !game.docked {
    game.tick(delta: 0.02)
    game.bodies.removeAll { $0.hull != .station }
    let control = game.autoPilot
    if control.status == "APPROACHING" && control.facingError < 0.08 && control.velocity.length > 20
    {
      forwardTransitFrames += 1
      #expect(control.velocity.z > control.velocity.length * 0.96)
    }
    if control.status == "ALIGNING" && control.velocity.length < 1 {
      stoppedAlignmentFrames += 1
      #expect(control.positionError < 40)
    }
  }
  #expect(forwardTransitFrames > 100)
  #expect(stoppedAlignmentFrames > 20)
  #expect(game.autoPilot.finalApproach)
  #expect(game.autoPilot.facingError < 0.02)
}

@Test func stationApproachCompletesForwardAndCollisionFreeForBehindTiltedAndFastStarts() {
  let starts: [(Vector3, Double, Double, Double, Double, Double)] = [
    (.init(0, 0, 2400), 0, 0, 0, 0.3, 0),
    (.init(0, 0, -2400), 0, 0, 0, -0.3, 0),
    (.init(0, 0, 2400), 0, 0, .pi, -0.3, 24),
    (.init(600, 400, 2400), 0.21, 0, 0.7, 0.3, 32),
    (.init(1200, 700, 1600), 0.6, 0.4, 0.8, -0.3, 0),
    (.init(0, 0, 1090), 0, 0, 0, 0.3, 0),
  ]
  for (position, pitch, roll, yaw, spin, speed) in starts {
    var game = approachGame(
      position: position, pitch: pitch, roll: roll, yaw: yaw, spin: spin, speed: speed)
    var collided = false
    var finalFrames = 0
    var shortestDoorDistance = Double.infinity
    var stoppedTransitFrames = 0
    var longestStoppedTransit = 0
    for _ in 0..<9000 where !game.docked {
      let before = game.bodies.first { $0.hull == .station }!
      shortestDoorDistance = min(shortestDoorDistance, before.entrancePosition.length)
      game.tick(delta: 0.02)
      game.bodies.removeAll { $0.hull != .station }
      collided = collided || game.message == "DOCKING COLLISION"
      let control = game.autoPilot
      if control.status == "APPROACHING" && control.velocity.length < 1 {
        stoppedTransitFrames += 1
        longestStoppedTransit = max(longestStoppedTransit, stoppedTransitFrames)
      } else {
        stoppedTransitFrames = 0
      }
      if let after = game.bodies.first(where: { $0.hull == .station }) {
        // Rotation preserves range. Every positional change must come from actual
        // bounded flight translation, including travel around the station's rear.
        #expect(
          abs(after.position.length - before.position.length) <= control.velocity.length * 0.02
            + 0.001)
        if !control.finalApproach { #expect(after.position.length >= 399.9) }
        if control.status == "FINAL APPROACH" {
          finalFrames += 1
          #expect(control.velocity.z > 0)
          #expect(after.entrancePosition.length < before.entrancePosition.length)
        }
      }
    }
    #expect(game.docked && game.screen == .status, "Start: \(position), yaw: \(yaw)")
    #expect(!collided)
    #expect(finalFrames > 100)
    #expect(shortestDoorDistance < 2)
    #expect(longestStoppedTransit < 750)
  }
}

@Test func stationTurnBrakesExistingCruiseWithoutInstantVelocityChangesAndManualInputCancels() {
  var game = approachGame(position: .init(0, 0, -2400), speed: 32)
  let initialSpeed = game.autoPilot.velocity.length
  game.tick(delta: 0.02)
  #expect(game.autoPilot.velocity.length > initialSpeed - 4.81)
  #expect(game.autoPilot.velocity.length < initialSpeed)
  #expect(game.autoPilot.status == "APPROACHING")
  for _ in 0..<60 { game.tick(delta: 0.02) }
  #expect(game.autoPilot.targetID != nil)
  var controls = Controls()
  controls.yaw = 0.4
  let beforeTakeoverVelocity = game.flightWorldVelocity
  let beforeTakeoverPosition = game.commander.flightSimulation.pose.position
  game.tick(delta: 0.02, controls: controls)
  #expect(game.autoPilot.targetID == nil && game.manualResidualFlight && game.speed == 0)
  #expect((game.flightWorldVelocity - beforeTakeoverVelocity).length < 1e-8)
  #expect(
    (game.commander.flightSimulation.pose.position - beforeTakeoverPosition
      - beforeTakeoverVelocity * 0.02).length < 1e-8)
  #expect(!game.dockingComputer)
  let releasedPosition = game.commander.flightSimulation.pose.position
  game.tick(delta: 0.02)
  #expect(
    (game.flightWorldVelocity - beforeTakeoverVelocity).length
      <= game.workLimits.acceleration * 0.02 + 1e-8)
  #expect(
    (game.commander.flightSimulation.pose.position - releasedPosition
      - beforeTakeoverVelocity * 0.02).length < 1e-8)
  game.bodies = [.init(id: 0, hull: .station, position: .init(500, 0, 2400))]
  game.speed = 0
  game.key("tab")
  for _ in 0..<100 { game.tick(delta: 0.02) }
  #expect(game.autoPilot.status == "APPROACHING" && !game.autoPilot.finalApproach)
}

@Test func freshLaunchCobraAndLiberatorDockFromTheActualCloseRearStation() throws {
  for shipID in ["SH023", "SH171"] {
    var game = Game(executive: false)
    game.commander.shipID = shipID
    game.commander.installTargetingComputer(.docking)
    game.launch()
    game.bodies.removeAll { $0.hull != .station }
    #expect(game.speed == 8)
    #expect(try #require(game.bodies.first).position == Vector3(0, 0, -500))
    game.key("tab")
    var collided = false
    var finalFrames = 0
    var minimumTransitRange = Double.infinity
    var elapsed = 0.0
    for _ in 0..<9000 where !game.docked {
      game.tick(delta: 0.02)
      elapsed += 0.02
      game.bodies.removeAll { $0.hull != .station }
      collided = collided || game.message == "DOCKING COLLISION"
      if game.autoPilot.status == "FINAL APPROACH" { finalFrames += 1 }
      if !game.autoPilot.finalApproach, let station = game.bodies.first {
        minimumTransitRange = min(minimumTransitRange, station.position.length)
      }
    }
    #expect(
      game.docked,
      "\(shipID): \(game.autoPilot.status), facing \(game.autoPilot.facingError), goal \(game.autoPilot.positionError), velocity \(game.autoPilot.velocity)"
    )
    #expect(!collided && minimumTransitRange >= 399.9)
    #expect(finalFrames > 100 && elapsed < 90, "\(shipID): \(elapsed) simulated seconds")
  }
}
