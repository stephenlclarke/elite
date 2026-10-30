import Foundation
import Testing

@testable import L337Core

private func alienMeshGame(profile: OrdnanceProfile) throws -> Game {
  var game = Game(executive: false)
  game.docked = false
  game.screen = .front
  game.commander.flightSimulation.enter(game.systemIdentity, arriving: true)
  let player = try #require(game.commander.flightSimulation.player)
  let targetAllocation = game.commander.flightSimulation.allocateActor()
  let target = try #require(targetAllocation)
  let projectileAllocation = game.commander.flightSimulation.allocateActor()
  let projectile = try #require(projectileAllocation)
  let attackOrigin = game.makeAttackOrigin(owner: player, ordnance: projectile)
  let origin = try #require(attackOrigin)
  let position = Vector3(0, 0, 500)
  let state = try #require(
    OrdnanceState(
      profile: profile, origin: origin, target: target,
      position: game.commander.flightSimulation.pose.systemPoint(position),
      direction: .init(0, 0, 1)))
  var body = SpaceBody(id: 20, hull: .missile, position: position, hostile: true)
  body.rotationRate = 0
  body.physical = .init(
    identity: projectile, population: .projectile, npc: nil, attackOrigin: origin)
  body.physical?.ordnance = state
  game.bodies = [body]
  game.celestials = []
  return game
}

struct AlienMissileMeshTests {
  @Test func actualAlienProfileSelectsOneClosedMeshForRenderingAndCollision() throws {
    let alien = try alienMeshGame(profile: .alienSeeker)
    let body = alien.bodies[0]
    let mesh = alien.gameplayMesh(for: body)
    let override = try #require(alien.gameplayMeshOverrides[body.id])
    #expect(body.hull == .missile && body.physical?.catalogueShipID == nil)
    #expect(mesh.vertices == override.vertices && mesh.faces == override.faces)
    #expect(mesh.vertices != Mesh.hull(.missile).vertices)
    let verticesAreFinite = mesh.vertices.allSatisfy(\.finite)
    #expect(verticesAreFinite)
    var edges: [String: Int] = [:]
    var directed: Set<String> = []
    var signedVolume = 0.0
    for face in mesh.faces {
      try #require(face.count >= 3 && face.allSatisfy { mesh.vertices.indices.contains($0) })
      let a = mesh.vertices[face[0]]
      for index in 1..<(face.count - 1) {
        let b = mesh.vertices[face[index]]
        let c = mesh.vertices[face[index + 1]]
        #expect((b - a).cross(c - a).length > 0)
        signedVolume += a.dot(b.cross(c)) / 6
      }
      for index in face.indices {
        let a = face[index]
        let b = face[(index + 1) % face.count]
        let key = "\(min(a, b)):\(max(a, b))"
        edges[key, default: 0] += 1
        #expect(directed.insert("\(a):\(b)").inserted)
      }
    }
    #expect(!edges.isEmpty && edges.values.allSatisfy { $0 == 2 })
    #expect(signedVolume > 0)
    for profile in [OrdnanceProfile.standardMissile, .plasma] {
      let ordinary = try alienMeshGame(profile: profile)
      #expect(
        ordinary.gameplayMesh(for: ordinary.bodies[0]).vertices == Mesh.hull(.missile).vertices)
      #expect(ordinary.gameplayMeshOverrides[20] == nil)
    }
  }

  @Test func realRaycastResolvesForkGapsDifferentlyFromStockSilhouette() throws {
    let alien = try alienMeshGame(profile: .alienSeeker)
    let standard = try alienMeshGame(profile: .standardMissile)
    let mesh = alien.gameplayMesh(for: alien.bodies[0])
    let width = try #require(mesh.vertices.map { abs($0.x) }.max())
    let length = try #require(mesh.vertices.map { abs($0.z) }.max())
    let height = try #require(mesh.vertices.map { abs($0.y) }.max())
    var alienOnly = 0
    var standardOnly = 0
    var shared = 0
    for x in -9...9 {
      for z in -9...9 {
        let origin = Vector3(
          Double(x) * width / 10, height + 50, 500 + Double(z) * length / 10)
        func hits(_ game: Game) -> Bool {
          GameplayRaycast.nearest(
            origin: origin, direction: .init(0, -1, 0), maxDistance: 2 * height + 100,
            bodies: game.bodies, meshOverrides: game.gameplayMeshOverrides)?.target == .body(20)
        }
        let a = hits(alien)
        let s = hits(standard)
        if a && s { shared += 1 }
        if a && !s { alienOnly += 1 }
        if !a && s { standardOnly += 1 }
      }
    }
    #expect(shared > 0 && alienOnly > 0 && standardOnly > 0)
  }

  @Test(arguments: ShipDisplayStyle.allCases)
  func everyDrawingStyleUsesDistinctAlienGeometryAndPreservesThreatClassification(
    style: ShipDisplayStyle
  ) throws {
    func frame(profile: OrdnanceProfile) throws -> Frame {
      var game = try alienMeshGame(profile: profile)
      game.commander.shipDisplayStyle = style
      game.bodies[0].orientation = RelativeWorkController.rotated(
        Basis3(), omega: .init(1, 0.3, 0), delta: 0.9)
      #expect(game.targetColourCue(for: game.bodies[0]) == .hostile)
      var result = Frame()
      result.rasterizeGraphics = false
      Display.draw(game.bodies[0], game: game, into: &result)
      return result
    }
    let alien = try frame(profile: .alienSeeker)
    let standard = try frame(profile: .standardMissile)
    #expect(!alien.graphics.isEmpty && !standard.graphics.isEmpty)
    #expect(alien.graphics != standard.graphics)
    if style == .shadedPanels {
      #expect(!alien.shipPanels.isEmpty)
    } else {
      #expect(!alien.shipLines.isEmpty)
      if style == .whiteWireframe { #expect(alien.shipLines.allSatisfy { $0.ink == .white }) }
    }
  }
}
