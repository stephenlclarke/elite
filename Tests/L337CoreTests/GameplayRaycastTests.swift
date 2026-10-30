import Foundation
import Testing

@testable import L337Core

private func raycastBox(_ half: Vector3 = .init(10, 10, 10)) -> Mesh {
  Mesh(
    vertices: [
      .init(-half.x, -half.y, -half.z), .init(half.x, -half.y, -half.z),
      .init(half.x, half.y, -half.z), .init(-half.x, half.y, -half.z),
      .init(-half.x, -half.y, half.z), .init(half.x, -half.y, half.z),
      .init(half.x, half.y, half.z), .init(-half.x, half.y, half.z),
    ],
    faces: [
      [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7],
    ],
    preserveWinding: true)
}

@Test func gameplayRaycastChoosesNearestHullIndependentOfArrayOrderAndIgnoresEmitter() throws {
  let near = SpaceBody(id: 7, hull: .cobra, position: .init(0, 0, 100))
  let far = SpaceBody(id: 2, hull: .viper, position: .init(0, 0, 200))
  let overrides = [7: raycastBox(), 2: raycastBox()]
  for bodies in [[near, far], [far, near]] {
    let hit = try #require(
      GameplayRaycast.nearest(
        origin: .init(0, 0, 0), direction: .init(0, 0, 7),
        maxDistance: 500, bodies: bodies, meshOverrides: overrides))
    #expect(hit.target == .body(7) && hit.distance == 90 && hit.point == Vector3(0, 0, 90))
    let ignored = GameplayRaycast.nearest(
      origin: .init(0, 0, 0), direction: .init(0, 0, 1),
      maxDistance: 500, bodies: bodies, ignoring: [7], meshOverrides: overrides)
    #expect(ignored?.target == .body(2) && ignored?.distance == 190)
  }
  var coincident = near
  coincident.id = 1
  let tied = GameplayRaycast.nearest(
    origin: .init(0, 0, 0), direction: .init(0, 0, 1),
    maxDistance: 500, bodies: [near, coincident], meshOverrides: [7: raycastBox(), 1: raycastBox()])
  #expect(tied?.target == .body(1))
}

@Test func gameplayRaycastUsesTheActualNativeStationAsAnOccluder() throws {
  let station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 400))
  let behind = SpaceBody(id: 3, hull: .cobra, position: .init(0, 0, 1000))
  for bodies in [[behind, station], [station, behind]] {
    let hit = try #require(
      GameplayRaycast.nearest(
        origin: .init(0, 0, 0), direction: .init(0, 0, 1),
        maxDistance: 2000, bodies: bodies, meshOverrides: [3: raycastBox()]))
    #expect(hit.target == .body(0) && hit.distance < 500)
  }
  let unblocked = GameplayRaycast.nearest(
    origin: .init(0, 0, 0), direction: .init(0, 0, 1),
    maxDistance: 2000, bodies: [station, behind], ignoring: [0], meshOverrides: [3: raycastBox()])
  #expect(unblocked?.target == .body(3))
}

@Test func gameplayRaycastRejectsConeNearMissesAndConcavePolygonNotches() throws {
  let missed = SpaceBody(id: 1, hull: .cobra, position: .init(40, 0, 1000))
  #expect(
    GameplayRaycast.nearest(
      origin: .init(0, 0, 0), direction: .init(0, 0, 1),
      maxDistance: 2000, bodies: [missed], meshOverrides: [1: raycastBox(.init(5, 5, 5))]) == nil)
  let concave = Mesh(
    vertices: [
      .init(40, 0, 0), .init(40, 10, 0), .init(10, 10, 0),
      .init(10, 40, 0), .init(0, 40, 0), .init(0, 0, 0),
    ], faces: [[0, 1, 2, 3, 4, 5]], preserveWinding: true)
  let plate = SpaceBody(id: 4, hull: .cargo, position: .init(0, 0, 100))
  let farther = SpaceBody(id: 5, hull: .cobra, position: .init(20, 20, 200))
  let throughNotch = GameplayRaycast.nearest(
    origin: .init(20, 20, 0), direction: .init(0, 0, 1),
    maxDistance: 500, bodies: [plate, farther], meshOverrides: [4: concave, 5: raycastBox()])
  #expect(throughNotch?.target == .body(5) && throughNotch?.distance == 190)
  let solid = try #require(
    GameplayRaycast.nearest(
      origin: .init(5, 25, 0), direction: .init(0, 0, 1),
      maxDistance: 500, bodies: [plate], meshOverrides: [4: concave]))
  #expect(solid.target == .body(4) && solid.distance == 100)
}

@Test func gameplayRaycastHonoursViewDirectionsAndBodyModelOrientation() throws {
  let positions: [Vector3] = [
    .init(0, 0, 200), .init(0, 0, -200), .init(-200, 0, 0), .init(200, 0, 0),
  ]
  let directions: [Vector3] = [.init(0, 0, 1), .init(0, 0, -1), .init(-1, 0, 0), .init(1, 0, 0)]
  let bodies = positions.enumerated().map {
    SpaceBody(id: $0.offset, hull: .cobra, position: $0.element)
  }
  let overrides = Dictionary(uniqueKeysWithValues: bodies.map { ($0.id, raycastBox()) })
  for (id, direction) in directions.enumerated() {
    let hit = GameplayRaycast.nearest(
      origin: .init(0, 0, 0), direction: direction,
      maxDistance: 500, bodies: bodies, meshOverrides: overrides)
    #expect(hit?.target == .body(id) && hit?.distance == 190)
  }
  for hull in [Hull.cobra, .station] {
    var body = SpaceBody(id: 9, hull: hull, position: .init(50, 20, 150))
    body.orientation.rotate(pitch: 0.3, roll: 0.4, yaw: 0.7)
    body.rotation = 0.8
    let start = body.position + body.modelVector(.init(0, 0, -100))
    let hit = try #require(
      GameplayRaycast.nearest(
        origin: start,
        direction: body.modelVector(.init(0, 0, 1)), maxDistance: 200,
        bodies: [body], meshOverrides: [9: raycastBox(.init(5, 4, 30))]))
    #expect(abs(hit.distance - 70) < 1e-9)
    #expect((hit.point - body.position - body.modelVector(.init(0, 0, -30))).length < 1e-9)
  }
}

@Test func gameplayRaycastClipsProjectilesToTheirTravelledSegmentAndTestsBothFaces() {
  let body = SpaceBody(id: 1, hull: .cobra, position: .init(0, 0, 100))
  let overrides = [1: raycastBox()]
  #expect(
    GameplayRaycast.segment(
      from: .init(0, 0, 0), to: .init(0, 0, 89.9),
      bodies: [body], meshOverrides: overrides) == nil)
  let endpoint = GameplayRaycast.segment(
    from: .init(0, 0, 0), to: .init(0, 0, 90),
    bodies: [body], meshOverrides: overrides)
  #expect(endpoint?.target == .body(1) && endpoint?.distance == 90)
  let reverse = GameplayRaycast.segment(
    from: .init(0, 0, 200), to: .init(0, 0, 0),
    bodies: [body], meshOverrides: overrides)
  #expect(reverse?.target == .body(1) && reverse?.point == Vector3(0, 0, 110))
}

@Test func gameplayRaycastCanHitTheActualPlayerHullAndCelestialSpheres() throws {
  let player = Commander().playerMesh
  // SH025 has an open centre; aim at the retained native face230 material witness.
  try #require(player.faces.indices.contains(230))
  let face = player.faces[230].map { player.vertices[$0] }
  try #require(face.count >= 3)
  let surface = face.reduce(Vector3(0, 0, 0), +) * (1 / Double(face.count))
  let normal = (face[1] - face[0]).cross(face[2] - face[0]).unit
  try #require(normal.length > 0)
  let body = SpaceBody(id: 1, hull: .cobra, position: .init(0, 0, 500))
  let playerHit = try #require(
    GameplayRaycast.nearest(
      origin: surface + normal * 200, direction: normal * -1,
      maxDistance: 1000, bodies: [body], playerMesh: player, meshOverrides: [1: raycastBox()]))
  #expect(playerHit.target == .player && playerHit.distance > 0 && playerHit.distance < 400)
  let unobstructed = GameplayRaycast.nearest(
    origin: .init(0, 0, -200), direction: .init(0, 0, 1),
    maxDistance: 1000, bodies: [body], meshOverrides: [1: raycastBox()])
  #expect(unobstructed?.target == .body(1) && unobstructed?.distance == 690)
  let planet = CelestialBody(kind: .planet, position: .init(0, 0, 300), radius: 50)
  let sun = CelestialBody(kind: .sun, position: .init(0, 0, 100), radius: 20)
  for celestials in [[planet, sun], [sun, planet]] {
    let hit = GameplayRaycast.nearest(
      origin: .init(0, 0, 0), direction: .init(0, 0, 1),
      maxDistance: 1000, bodies: [body], celestials: celestials, meshOverrides: [1: raycastBox()])
    #expect(hit?.target == .celestial(.sun) && hit?.distance == 80)
  }
  let inside = GameplayRaycast.nearest(
    origin: planet.position, direction: .init(0, 0, 1),
    maxDistance: 1000, bodies: [], celestials: [planet])
  #expect(inside?.target == .celestial(.planet) && inside?.distance == 0)
}

@Test func gameplayRaycastGuardsInvalidRaysAndGeometryWithoutInventingProxyHits() {
  let zero = Vector3(0, 0, 0)
  let body = SpaceBody(id: 1, hull: .cobra, position: .init(0, 0, 100))
  for magnitude in [Double.leastNonzeroMagnitude, .greatestFiniteMagnitude] {
    let hit = GameplayRaycast.nearest(
      origin: zero, direction: .init(0, 0, magnitude), maxDistance: 500,
      bodies: [body], meshOverrides: [1: raycastBox()])
    #expect(hit?.target == .body(1) && hit?.distance == 90)
  }
  for (origin, direction, limit) in [
    (Vector3(.nan, 0, 0), Vector3(0, 0, 1), 500.0),
    (zero, Vector3(0, .infinity, 1), 500), (zero, zero, 500), (zero, Vector3(0, 0, 1), 0),
    (zero, Vector3(0, 0, 1), -1), (zero, Vector3(0, 0, 1), .infinity),
    (zero, Vector3(0, 0, 1), .nan),
  ] {
    #expect(
      GameplayRaycast.nearest(
        origin: origin, direction: direction, maxDistance: limit, bodies: [body]) == nil)
  }
  let malformed = Mesh(
    vertices: [.init(0, 0, 0), .init(1, 0, 0), .init(0, 1, 0)],
    faces: [[0, 1, 99]], preserveWinding: true)
  #expect(
    GameplayRaycast.nearest(
      origin: zero, direction: .init(0, 0, 1), maxDistance: 500,
      bodies: [body], meshOverrides: [1: malformed]) == nil)
  var invalidPose = body
  invalidPose.orientation.x = zero
  #expect(
    GameplayRaycast.nearest(
      origin: zero, direction: .init(0, 0, 1), maxDistance: 500,
      bodies: [invalidPose], meshOverrides: [1: raycastBox()]) == nil)
  #expect(GameplayRaycast.segment(from: zero, to: zero, bodies: [body]) == nil)
}

@Test func gameplayRaycastBroadphaseKeepsAllBodiesInOrdinaryAndLargerScenes() {
  let clock = ContinuousClock()
  for count in [128, 1024] {
    let box = raycastBox(.init(2, 2, 2))
    let bodies = (0..<count).map { id in
      SpaceBody(
        id: id, hull: .cobra,
        position: id == count - 1 ? .init(0, 0, 500) : .init(Double(id + 1000), 0, 1000))
    }
    let overrides = Dictionary(uniqueKeysWithValues: bodies.map { ($0.id, box) })
    let started = clock.now
    let hit = GameplayRaycast.nearest(
      origin: .init(0, 0, 0), direction: .init(0, 0, 1),
      maxDistance: 2000, bodies: bodies, meshOverrides: overrides)
    let reverse = GameplayRaycast.nearest(
      origin: .init(0, 0, 0), direction: .init(0, 0, 1),
      maxDistance: 2000, bodies: Array(bodies.reversed()), meshOverrides: overrides)
    #expect(hit?.target == .body(count - 1) && hit?.distance == 498)
    #expect(reverse == hit)
    print(
      "Gameplay raycast \(count)-body forward/reverse fixture: \(started.duration(to: clock.now))")
  }
}
