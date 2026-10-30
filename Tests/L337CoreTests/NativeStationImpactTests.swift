import Testing

@testable import L337Core

struct NativeStationImpactTests {
  @Test(arguments: ["cruise", "residual", "work"])
  func actualNativeTickStopsThePlayerAtASolidArmInsteadOfFlyingThrough(_ mode: String) throws {
    var game = try armApproach()
    let velocity = game.commander.flightSimulation.pose.orientation.z * 576
    switch mode {
    case "residual":
      game.speed = 0
      game.manualResidualFlight = true
      game.autoPilot.setApproachVelocity(game.commander.flightSimulation.pose.shipVector(velocity))
    case "work":
      game.speed = 0
      game.workBraking = .init(velocity: velocity, angularVelocity: .init(0, 0, 0))
    default: game.speed = 32
    }
    let stations = game.bodies.filter { $0.nativeStationIdentity != nil }.map {
      (id: $0.id, point: game.commander.flightSimulation.pose.systemPoint($0.position))
    }
    let celestials = game.celestials.map {
      game.commander.flightSimulation.pose.systemPoint($0.position)
    }
    var hit = false
    for _ in 0..<12 {
      let before = game.commander.flightSimulation.pose
      let movingNPCs = game.bodies.compactMap { body -> (Int, Vector3)? in
        guard body.physical?.npc?.role != .mission, body.physical?.npc != nil else { return nil }
        return (body.id, before.systemPoint(body.position))
      }
      game.tick(delta: 0.1, controls: Controls())
      if game.message == "RRS DOCKING COLLISION" {
        hit = true
        #expect(game.commander.flightSimulation.pose == before)
        #expect(game.speed == 0 && game.flightWorldVelocity.length == 0)
        #expect(game.workGuidance == nil && game.workBraking == nil)
        #expect(game.lastAppliedWorkMotion == nil && !game.manualResidualFlight)
        #expect(!game.docked && game.screen.isFlight)
        #expect(game.stationImpactRevision == game.gameplayRevision)
        #expect(
          movingNPCs.contains { entry in
            let (id, point) = entry
            guard let actor = game.bodies.first(where: { $0.id == id }),
              let velocity = actor.physical?.velocity, velocity.length > 0
            else { return false }
            return (before.systemPoint(actor.position) - point).length > 1e-6
          },
          "An independently moving native NPC must retain its actual collision-frame displacement")
        break
      }
    }
    #expect(hit, "The actual effective player hull must meet the retained solid station arm")
    for station in stations {
      let body = try #require(game.bodies.first { $0.id == station.id })
      let point = game.commander.flightSimulation.pose.systemPoint(body.position)
      #expect((point - station.point).length < 1e-8)
    }
    for (index, point) in celestials.enumerated() {
      let current = game.commander.flightSimulation.pose.systemPoint(
        game.celestials[index].position)
      #expect((current - point).length < 1e-8)
    }
    #expect(
      game.nativeStationFlightObservations(from: nil, delta: nil).allSatisfy {
        $0.rigidPoseConsistent
      })
  }

  @Test func stationaryCraftIsCarriedByActualArmRotationAndRemainsClearAtTheEndPose() throws {
    var game = try NativeStationTestFixture.launched()
    let body = try #require(
      game.bodies.first {
        $0.nativeStationIdentity?.definition == "rescue_station"
      })
    let identity = try #require(body.nativeStationIdentity)
    let saved = try #require(game.commander.nativeStations?.pose(for: identity))
    let source = try #require(NativeStationSource.binding(for: identity))
    let player = game.commander.playerMesh
    let start = try #require(saved.orientation(at: 0))
    let end = try #require(saved.orientation(at: 0.1))
    func pose(_ y: Double) -> ShipPose {
      .init(position: saved.position + start.apply(.init(600, y, 0)), orientation: start)
    }
    func clear(_ point: ShipPose, at orientation: Basis3) -> Bool {
      game.nativeStationHullSweepClear(
        player, from: point, to: point, saved: saved,
        fromOrientation: orientation, toOrientation: orientation, margin: 0,
        mesh: source.geometry.mesh)
    }
    // Find the actual arm boundary, rather than substitute an enclosing sphere.
    var low = 50.0
    var high = 250.0
    #expect(!clear(pose(low), at: start) && clear(pose(high), at: start))
    for _ in 0..<20 {
      let middle = (low + high) * 0.5
      if clear(pose(middle), at: start) { high = middle } else { low = middle }
    }
    let before = pose(high + 0.05)
    #expect(clear(before, at: start) && !clear(before, at: end))
    NativeStationTestFixture.reframe(&game, to: before)
    game.speed = 0
    game.tick(delta: 0.1, controls: Controls())
    let after = game.commander.flightSimulation.pose
    let expected = saved.position + end.apply(start.inverse(before.position - saved.position))
    #expect((after.position - expected).length < 1e-7)
    #expect((after.position - before.position).length > 0)
    #expect(
      (after.position - before.position).length <= (before.position - saved.position).length * 0.002
        + 1e-7)
    #expect(clear(after, at: end))
    #expect(game.stationImpactRevision == game.gameplayRevision)
    #expect(!game.paused && !game.docked && game.screen.isFlight && game.speed == 0)
    #expect(game.message == "RRS DOCKING COLLISION")
  }

  @Test func refusedEndpointReprojectsEveryCurrentActorWithoutUndoingTheirWorldMotion() throws {
    var game = try armApproach()
    let before = game.commander.flightSimulation.pose
    var attempted = before
    attempted.position = before.systemPoint(.init(0, 0, 160))
    NativeStationTestFixture.reframe(&game, to: attempted)
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    for index in game.bodies.indices where game.bodies[index].nativeStationIdentity != nil {
      game.bodies[index].rotation += game.bodies[index].rotationRate * 0.1
    }
    let points = game.bodies.map { attempted.systemPoint($0.position) }
    let orientations = game.bodies.map { $0.orientation.transformed(by: attempted.orientation) }
    let identities = game.bodies.map { $0.physical?.identity }
    let time = game.commander.flightSimulation.physicalTime
    let shield = game.frontShield
    game.collideWithNativeStationStructures(from: before, delta: 0.1)
    #expect(game.commander.flightSimulation.pose == before)
    #expect(game.commander.flightSimulation.physicalTime == time)
    #expect(game.frontShield < shield && game.message == "RRS DOCKING COLLISION")
    #expect(game.bodies.map { $0.physical?.identity } == identities)
    for index in game.bodies.indices {
      let point = before.systemPoint(game.bodies[index].position)
      let orientation = game.bodies[index].orientation.transformed(by: before.orientation)
      #expect((point - points[index]).length < 1e-8)
      #expect((orientation.x - orientations[index].x).length < 1e-8)
      #expect((orientation.y - orientations[index].y).length < 1e-8)
      #expect((orientation.z - orientations[index].z).length < 1e-8)
    }
  }

  @Test func wrongSideImpactAtTheOriginalMainStationUsesTheSamePhysicalStop() throws {
    var game = try NativeStationTestFixture.launched()
    var pose = ShipPose(position: .init(300, 0, 0))
    pose.orientation.x = .init(0, 0, 1)
    pose.orientation.y = .init(0, 1, 0)
    pose.orientation.z = .init(-1, 0, 0)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 32
    var hit = false
    for _ in 0..<6 {
      let before = game.commander.flightSimulation.pose
      game.tick(delta: 0.1, controls: Controls())
      if game.message == "DOCKING COLLISION" {
        hit = true
        #expect(game.commander.flightSimulation.pose == before)
        #expect(game.speed == 0 && game.flightWorldVelocity.length == 0 && !game.docked)
        break
      }
    }
    #expect(hit)
  }

  @Test func unprovedContactPausesWithoutTurningConservativeRefusalIntoInstantDeath() throws {
    var game = try NativeStationTestFixture.launched()
    let body = try #require(
      game.bodies.first {
        $0.nativeStationIdentity?.definition == "rescue_station"
      })
    let identity = try #require(body.nativeStationIdentity)
    let saved = try #require(game.commander.nativeStations?.pose(for: identity))
    let orientation = try #require(saved.orientation(at: 0))
    let pose = ShipPose(
      position: saved.position + orientation.apply(.init(600, 50, 0)), orientation: orientation)
    // Deliberately unproved initial placement: no prior clear pose can authorize
    // a kinematic contact transport or justify a fabricated terminal collision.
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 0
    let energy = game.energy
    let shield = game.frontShield
    game.tick(delta: 0.1, controls: Controls())
    #expect(game.paused && game.screen.isFlight && game.energy == energy)
    #expect(game.frontShield < shield && game.stationImpactRevision == game.gameplayRevision)
    #expect(game.message == "STATION CONTACT UNRESOLVED - FLIGHT PAUSED")
  }

  private func armApproach() throws -> Game {
    var game = try NativeStationTestFixture.launched()
    let body = try #require(
      game.bodies.first {
        $0.nativeStationIdentity?.definition == "rescue_station"
      })
    let identity = try #require(body.nativeStationIdentity)
    let saved = try #require(game.commander.nativeStations?.pose(for: identity))
    let orientation = try #require(
      saved.orientation(at: game.commander.flightSimulation.physicalTime))
    var pose = ShipPose()
    pose.position = saved.position + orientation.apply(.init(800, 0, 0))
    pose.orientation.x = orientation.apply(.init(0, 0, 1))
    pose.orientation.y = orientation.apply(.init(0, 1, 0))
    pose.orientation.z = orientation.apply(.init(-1, 0, 0))
    NativeStationTestFixture.reframe(&game, to: pose)
    return game
  }
}
