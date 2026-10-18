import Foundation
import Testing

@testable import EliteCore

private func surfaceContractGame(hull: Hull = .cargo) throws -> Game {
  var game = Game(executive: false)
  try game.commander.prepareEquipment(legacy: false)
  try game.commander.grantEquipment(
    "Fuel Scoops", at: .utility(.fuelScoops), provenance: .grant("surface contract fixture"))
  game.launch()
  game.speed = 0
  game.celestials = []
  game.miningFields = []
  game.salvageSites = []
  game.commander.npcPersistence = .init()
  let allocated = game.commander.flightSimulation.allocateActor()
  let actor = try #require(allocated)
  var body = SpaceBody(id: 71, hull: hull, position: .init(0, 0, 1000))
  body.rotationRate = 0
  body.physical = .init(
    identity: actor, population: hull == .asteroid ? .asteroid : .cargo,
    canonicalSpin: true)
  game.bodies = [body]
  game.nextBodyID = max(game.nextBodyID, 72)
  return game
}

/// An explicit unit-test patch on the unchanged native octahedron's front triangular face.
private func narrowUnitSurface(_ game: borrowing Game, named: Bool = true) -> FlightWorkSurface {
  let section = WreckSectionIdentity(
    wreck: .init(system: game.systemIdentity, site: 90, lineage: 1), section: 0)
  return .init(
    point: .init(-15, 16, -15), normal: .init(0, 0, -1), radius: named ? 1 : nil,
    section: named ? section : nil)
}

/// Independent arbitrary-origin ray in this aligned fixture's original camera frame.
private func narrowUnitRay(
  _ game: borrowing Game, surface: FlightWorkSurface, offset: Double
) -> GameplayHit? {
  let radius = game.commander.playerMesh.vertices.map(\.length).max() ?? 0
  let distance = max(120, 2 * radius) + radius + 1
  let origin = game.bodies[0].position + surface.point + Vector3(0, offset, -distance)
  return GameplayRaycast.nearest(
    origin: origin, direction: .init(0, 0, 1), maxDistance: 6000,
    bodies: game.bodies, celestials: game.celestials, meshOverrides: game.gameplayMeshOverrides)
}

struct WorkSurfaceRayContractTests {
  @Test func sameBodyHitOutsideNamedPatchCannotAuthorizeItsWorkHold() throws {
    let game = try surfaceContractGame()
    let body = game.bodies[0]
    let surface = narrowUnitSurface(game)
    let hit = try #require(narrowUnitRay(game, surface: surface, offset: 2))
    // This is exactly the old acceptance condition, independently observed by a real mesh ray.
    try #require(hit.target == .body(body.id))
    let point = game.modelPose(of: body).systemPoint(surface.point)
    let impact = game.commander.flightSimulation.pose.systemPoint(hit.point)
    let radius = try #require(surface.radius)
    try #require((point - impact).length > max(1, radius))
    #expect(!game.workRayReachesSurface(body: body, surface: surface, lateralOffset: 2))
    #expect(game.workRayReachesSurface(body: body, surface: surface, lateralOffset: 0))
    let missing = FlightWorkSurface(
      point: surface.point, normal: surface.normal, radius: nil, section: surface.section)
    #expect(!game.workRayReachesSurface(body: body, surface: missing, lateralOffset: 0))
    for invalid in [Double.nan, .infinity, 0, -1] {
      let malformed = FlightWorkSurface(
        point: surface.point, normal: surface.normal, radius: invalid, section: surface.section)
      #expect(!game.workRayReachesSurface(body: body, surface: malformed, lateralOffset: 0))
    }
  }

  @Test func actualCobraCargoRadiusSurvivesSelectionAndRejectsFortyUnitOffset() throws {
    var game = try surfaceContractGame()
    let profile = try #require(SalvageCatalogue.empProfile(catalogueShipID: "SH023"))
    let cargo = try #require(profile.sections.first { $0.kind == .cargo })
    try #require(cargo.sourceFaceIndex == 895 && cargo.radius < 40)
    #expect(abs(cargo.radius - 34.33882434494874) < 1e-9)
    let wreck = WreckIdentity(system: game.systemIdentity, site: 91, lineage: 1)
    let section = WreckSectionIdentity(wreck: wreck, section: cargo.index)
    let metadata = SalvageTargetMetadata(
      category: .section, ownership: .abandoned, claimant: nil, wreck: wreck,
      section: section, lot: nil, bounds: profile.bounds,
      workSurfaces: profile.surfaces(wreck: wreck))
    let forward = cargo.normal.unit * -1
    let cardinal = abs(forward.y) < 0.8 ? Vector3(0, 1, 0) : .init(1, 0, 0)
    var basis = Basis3()
    basis.z = forward
    basis.x = cardinal.cross(forward).unit
    basis.y = forward.cross(basis.x).unit
    game.bodies[0].hull = .cobra
    game.bodies[0].orientation = basis.transposed
    game.bodies[0].physical?.population = .wreck
    game.bodies[0].physical?.catalogueShipID = "SH023"
    game.bodies[0].physical?.salvage = metadata
    let body = game.bodies[0]
    let mesh = game.gameplayMesh(for: body)
    #expect(mesh.vertices == profile.mesh.vertices && mesh.faces == profile.mesh.faces)
    let surface = try #require(game.workSurface(for: body, metadata: metadata))
    #expect(surface.section == section && surface.radius == cargo.radius)
    #expect(surface.point == cargo.localPosition && surface.normal == cargo.normal)
    #expect(game.workRayReachesSurface(body: body, surface: surface, lateralOffset: 0))
    #expect(!game.workRayReachesSurface(body: body, surface: surface, lateralOffset: 40))
    let commander = game.commander
    game.beginWorkGuidance(body: body, mode: .hold(.salvage), velocity: .init(0, 0, 0))
    let hold = try #require(game.workGuidance)
    #expect(hold.collectionOffset == 0 && hold.surface.section == section)
    #expect(hold.surface.radius == cargo.radius)
    let context = try #require(game.gameplayContext())
    #expect(game.workSurfaceStillAuthorized(hold, body: game.bodies[0], context: context))
    let changedSurfaces = metadata.workSurfaces.map {
      SalvageWorkSurface(
        section: $0.section, position: $0.position, normal: $0.normal,
        radius: $0.section == section ? $0.radius * 0.5 : $0.radius)
    }
    game.bodies[0].physical?.salvage = .init(
      category: metadata.category, ownership: metadata.ownership, claimant: metadata.claimant,
      wreck: metadata.wreck, section: metadata.section, lot: metadata.lot,
      bounds: metadata.bounds, workSurfaces: changedSurfaces)
    #expect(!game.workSurfaceStillAuthorized(hold, body: game.bodies[0], context: context))
    game.bodies[0] = body
    #expect(game.workSurfaceStillAuthorized(hold, body: game.bodies[0], context: context))
    #expect(game.bodies[0] == body && game.commander == commander)
  }

  @Test(arguments: [false, true])
  func namedSurfaceCannotBorrowAHitThroughAnotherActorOrCelestial(celestial: Bool) throws {
    var game = try surfaceContractGame()
    let body = game.bodies[0]
    let surface = narrowUnitSurface(game)
    if celestial {
      game.celestials = [.init(kind: .planet, position: .init(-15, 16, 900), radius: 10)]
    } else {
      game.bodies.append(.init(id: 72, hull: .cargo, position: .init(-15, 16, 900)))
    }
    let hit = try #require(narrowUnitRay(game, surface: surface, offset: 0))
    #expect(hit.target == (celestial ? .celestial(.planet) : .body(72)))
    #expect(!game.workRayReachesSurface(body: body, surface: surface, lateralOffset: 0))
  }

  @Test(arguments: [Hull.cargo, .asteroid])
  func sectionlessPickupAndMiningKeepTheirExistingWholeBodyRayContract(hull: Hull) throws {
    let game = try surfaceContractGame(hull: hull)
    let body = game.bodies[0]
    let surface = narrowUnitSurface(game, named: false)
    let hit = try #require(narrowUnitRay(game, surface: surface, offset: 2))
    try #require(hit.target == .body(body.id))
    #expect(game.workRayReachesSurface(body: body, surface: surface, lateralOffset: 2))
    let metadata = SalvageTargetMetadata(
      category: hull == .cargo ? .cargo : .rock, ownership: .abandoned,
      claimant: nil, wreck: nil, section: nil, lot: nil,
      bounds: .init(center: .init(0, 0, 0), radius: 48), workSurfaces: [])
    let fallback = try #require(game.workSurface(for: body, metadata: metadata))
    #expect(fallback.section == nil && fallback.radius == nil)
  }
}
