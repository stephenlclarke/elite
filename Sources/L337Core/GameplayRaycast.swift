import Foundation

public enum GameplayHitTarget: Sendable, Equatable {
  case body(Int)
  case player
  case celestial(CelestialKind)
}

public struct GameplayHit: Sendable, Equatable {
  public let target: GameplayHitTarget
  public let distance: Double
  public let point: Vector3

  public init(target: GameplayHitTarget, distance: Double, point: Vector3) {
    self.target = target
    self.distance = distance
    self.point = point
  }
}

/// Physical intersections in the same camera-relative frame used by the simulation.
/// No population limit is imposed: broad bounds prune work without omitting bodies.
public enum GameplayRaycast {
  private struct Ray: Sendable {
    let origin: Vector3
    let direction: Vector3
    let limit: Double

    init?(origin: Vector3, direction: Vector3, limit: Double) {
      guard finite(origin), finite(direction),
        limit.isFinite, limit > 0
      else { return nil }
      let scale = max(abs(direction.x), max(abs(direction.y), abs(direction.z)))
      guard scale > 0 else { return nil }
      let scaled = Vector3(direction.x / scale, direction.y / scale, direction.z / scale)
      let length = hypot(hypot(scaled.x, scaled.y), scaled.z)
      self.origin = origin
      self.direction = scaled * (1 / length)
      self.limit = limit
    }
  }

  fileprivate struct Face: Sendable {
    let indices: [Int]
    let projectionAxis: Int
  }

  fileprivate struct PreparedMesh: Sendable {
    let vertices: [Vector3]
    let faces: [Face]
    let lower: Vector3
    let upper: Vector3
    let center: Vector3
    let radius: Double

    init?(_ mesh: Mesh) {
      guard let first = mesh.vertices.first, mesh.vertices.allSatisfy(finite) else { return nil }
      var lower = first
      var upper = first
      for point in mesh.vertices.dropFirst() {
        lower = .init(min(lower.x, point.x), min(lower.y, point.y), min(lower.z, point.z))
        upper = .init(max(upper.x, point.x), max(upper.y, point.y), max(upper.z, point.z))
      }
      let center = lower * 0.5 + upper * 0.5
      let radius = mesh.vertices.map { length($0 - center) }.max() ?? 0
      guard finite(center), radius.isFinite, radius > 0 else { return nil }
      var faces: [Face] = []
      for indices in mesh.faces where indices.count >= 3 {
        guard indices.allSatisfy({ mesh.vertices.indices.contains($0) }) else { continue }
        let first = mesh.vertices[indices[0]]
        let normal = (1..<(indices.count - 1)).lazy.map {
          (mesh.vertices[indices[$0]] - first).cross(mesh.vertices[indices[$0 + 1]] - first)
        }.first { length($0) > 0 }
        guard let normal, finite(normal) else { continue }
        let components = [abs(normal.x), abs(normal.y), abs(normal.z)]
        let axis = components.indices.max { components[$0] < components[$1] }!
        faces.append(Face(indices: indices, projectionAxis: axis))
      }
      guard !faces.isEmpty else { return nil }
      self.vertices = mesh.vertices
      self.faces = faces
      self.lower = lower
      self.upper = upper
      self.center = center
      self.radius = radius
    }
  }

  // Native collision bounds are immutable and share the authoritative rendered hulls.
  private static let nativeMeshes: [Hull: PreparedMesh] = Dictionary(
    uniqueKeysWithValues: Hull.allCases.compactMap { hull in
      PreparedMesh(.hull(hull)).map { (hull, $0) }
    })

  private enum Geometry: Sendable {
    case mesh(PreparedMesh)
    case sphere(center: Vector3, radius: Double)
  }

  private struct Candidate: Sendable {
    let target: GameplayHitTarget
    let ray: Ray
    let entry: Double
    let geometry: Geometry
  }

  public static func nearest(
    origin: Vector3, direction: Vector3, maxDistance: Double,
    bodies: [SpaceBody], ignoring: Set<Int> = [], playerMesh: Mesh? = nil,
    celestials: [CelestialBody] = [], meshOverrides: [Int: Mesh] = [:]
  ) -> GameplayHit? {
    guard let ray = Ray(origin: origin, direction: direction, limit: maxDistance) else {
      return nil
    }
    var candidates: [Candidate] = []
    for body in bodies where !ignoring.contains(body.id) && finite(body.position) {
      let geometry =
        meshOverrides[body.id].flatMap(PreparedMesh.init)
        ?? (meshOverrides[body.id] == nil ? nativeMeshes[body.hull] : nil)
      guard let geometry, let local = localRay(ray, body: body),
        let entry = meshEntry(local, mesh: geometry)
      else { continue }
      candidates.append(
        .init(target: .body(body.id), ray: local, entry: entry, geometry: .mesh(geometry)))
    }
    if let playerMesh, let geometry = PreparedMesh(playerMesh),
      let entry = meshEntry(ray, mesh: geometry)
    {
      candidates.append(.init(target: .player, ray: ray, entry: entry, geometry: .mesh(geometry)))
    }
    for celestial in celestials {
      guard let entry = sphereEntry(ray, center: celestial.position, radius: celestial.radius)
      else { continue }
      candidates.append(
        .init(
          target: .celestial(celestial.kind), ray: ray, entry: entry,
          geometry: .sphere(center: celestial.position, radius: celestial.radius)))
    }
    candidates.sort {
      $0.entry == $1.entry ? precedes($0.target, $1.target) : $0.entry < $1.entry
    }
    var nearest: GameplayHit?
    for candidate in candidates {
      let limit = nearest?.distance ?? ray.limit
      if candidate.entry > limit { break }
      let distance: Double?
      switch candidate.geometry {
      case .mesh(let geometry): distance = meshHit(candidate.ray, mesh: geometry, limit: limit)
      case .sphere: distance = candidate.entry
      }
      guard let distance else { continue }
      if let previous = nearest, distance == previous.distance,
        !precedes(candidate.target, previous.target)
      {
        continue
      }
      let point = ray.origin + ray.direction * distance
      guard finite(point) else { continue }
      nearest = .init(target: candidate.target, distance: distance, point: point)
    }
    return nearest
  }
  struct GlowOccluder {
    let bodyID: Int?
    let nearDepth: Double
    // nil conservatively covers the view when an occluder crosses the near plane.
    let bounds: CanvasRect?
  }
  struct OcclusionScene {
    fileprivate let bodies: [SpaceBody]
    fileprivate let celestials: [CelestialBody]
    fileprivate let meshes: [Int: PreparedMesh]
    let glowOccluders: [GlowOccluder]
  }
  // Immutable catalogue/native geometry is prepared once and reused across frames and halo rays.
  private static let catalogueOccluders: [String: PreparedMesh] = Dictionary(
    uniqueKeysWithValues: ShipCatalogue.all.compactMap { ship in
      PreparedMesh(ship.design.rawMesh).map { (ship.id, $0) }
    })
  static func prepareOcclusionScene(_ game: Game, projection: FlightProjection = .legacy)
    -> OcclusionScene
  {
    var meshes: [Int: PreparedMesh] = [:]
    for body in game.bodies {
      if let id = body.physical?.catalogueShipID, body.nativeStationIdentity == nil,
        body.scriptNPC == nil,
        body.physical?.rock == nil, body.physical?.payload == nil,
        let cached = catalogueOccluders[id]
      {
        meshes[body.id] = cached
      } else {
        meshes[body.id] = PreparedMesh(game.scriptNPCMesh(body) ?? game.gameplayMesh(for: body))
      }
    }
    var envelopes: [GlowOccluder] = []
    func append(_ points: [Vector3], bodyID: Int?) {
      guard !points.isEmpty, points.allSatisfy(\.finite),
        let near = points.map(\.z).min(), let far = points.map(\.z).max(), far > 1
      else { return }
      guard near > 1 else {
        envelopes.append(.init(bodyID: bodyID, nearDepth: near, bounds: nil))
        return
      }
      let projected = points.map(projection.point)
      guard projected.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return }
      let x = projected.map(\.x).min()!
      let y = projected.map(\.y).min()!
      envelopes.append(
        .init(
          bodyID: bodyID, nearDepth: near,
          bounds: .init(
            x: x, y: y, width: projected.map(\.x).max()! - x,
            height: projected.map(\.y).max()! - y)))
    }
    for body in game.bodies {
      guard let mesh = meshes[body.id] else { continue }
      append(
        mesh.vertices.map { game.viewPosition(body.modelVector($0) + body.position) },
        bodyID: body.id)
    }
    for celestial in game.celestials where celestial.radius.isFinite && celestial.radius > 0 {
      let center = game.viewPosition(celestial.position)
      let r = celestial.radius
      // A view-space box encloses every projected sphere point, including its forward limb.
      let corners = [-r, r].flatMap { x in
        [-r, r].flatMap { y in [-r, r].map { z in center + Vector3(x, y, z) } }
      }
      append(corners, bodyID: nil)
    }
    return .init(
      bodies: game.bodies, celestials: game.celestials, meshes: meshes,
      glowOccluders: envelopes)
  }

  static func nearest(
    origin: Vector3, direction: Vector3, maxDistance: Double,
    scene: OcclusionScene, ignoring: Set<Int> = []
  ) -> GameplayHit? {
    guard let ray = Ray(origin: origin, direction: direction, limit: maxDistance) else {
      return nil
    }
    var candidates: [Candidate] = []
    for body in scene.bodies where !ignoring.contains(body.id) && finite(body.position) {
      let geometry = scene.meshes[body.id]
      guard let geometry, let local = localRay(ray, body: body),
        let entry = meshEntry(local, mesh: geometry)
      else { continue }
      candidates.append(
        .init(target: .body(body.id), ray: local, entry: entry, geometry: .mesh(geometry)))
    }
    for celestial in scene.celestials {
      guard let entry = sphereEntry(ray, center: celestial.position, radius: celestial.radius)
      else { continue }
      candidates.append(
        .init(
          target: .celestial(celestial.kind), ray: ray, entry: entry,
          geometry: .sphere(center: celestial.position, radius: celestial.radius)))
    }
    candidates.sort {
      $0.entry == $1.entry ? precedes($0.target, $1.target) : $0.entry < $1.entry
    }
    var nearest: GameplayHit?
    for candidate in candidates {
      let limit = nearest?.distance ?? ray.limit
      if candidate.entry > limit { break }
      let distance: Double?
      switch candidate.geometry {
      case .mesh(let geometry): distance = meshHit(candidate.ray, mesh: geometry, limit: limit)
      case .sphere: distance = candidate.entry
      }
      guard let distance else { continue }
      if let previous = nearest, distance == previous.distance,
        !precedes(candidate.target, previous.target)
      {
        continue
      }
      let point = ray.origin + ray.direction * distance
      guard finite(point) else { continue }
      nearest = .init(target: candidate.target, distance: distance, point: point)
    }
    return nearest
  }

  public static func segment(
    from origin: Vector3, to end: Vector3, bodies: [SpaceBody], ignoring: Set<Int> = [],
    playerMesh: Mesh? = nil, celestials: [CelestialBody] = [], meshOverrides: [Int: Mesh] = [:]
  ) -> GameplayHit? {
    let direction = end - origin
    return nearest(
      origin: origin, direction: direction, maxDistance: length(direction),
      bodies: bodies, ignoring: ignoring, playerMesh: playerMesh,
      celestials: celestials, meshOverrides: meshOverrides)
  }

  private static func localRay(_ ray: Ray, body: SpaceBody) -> Ray? {
    let axes = [
      body.modelVector(.init(1, 0, 0)), body.modelVector(.init(0, 1, 0)),
      body.modelVector(.init(0, 0, 1)),
    ]
    guard axes.allSatisfy(finite), axes.allSatisfy({ abs($0.dot($0) - 1) < 1e-6 }),
      abs(axes[0].dot(axes[1])) < 1e-6, abs(axes[0].dot(axes[2])) < 1e-6,
      abs(axes[1].dot(axes[2])) < 1e-6
    else { return nil }
    let relative = ray.origin - body.position
    return Ray(
      origin: .init(relative.dot(axes[0]), relative.dot(axes[1]), relative.dot(axes[2])),
      direction: .init(
        ray.direction.dot(axes[0]), ray.direction.dot(axes[1]), ray.direction.dot(axes[2])),
      limit: ray.limit)
  }

  private static func meshEntry(_ ray: Ray, mesh: PreparedMesh) -> Double? {
    guard sphereEntry(ray, center: mesh.center, radius: mesh.radius) != nil else { return nil }
    var entry = 0.0
    var exit = ray.limit
    for (origin, direction, lower, upper) in [
      (ray.origin.x, ray.direction.x, mesh.lower.x, mesh.upper.x),
      (ray.origin.y, ray.direction.y, mesh.lower.y, mesh.upper.y),
      (ray.origin.z, ray.direction.z, mesh.lower.z, mesh.upper.z),
    ] {
      if direction == 0 {
        if origin < lower || origin > upper { return nil }
      } else {
        let first = (lower - origin) / direction
        let second = (upper - origin) / direction
        entry = max(entry, min(first, second))
        exit = min(exit, max(first, second))
        if entry > exit { return nil }
      }
    }
    return entry
  }

  private static func sphereEntry(_ ray: Ray, center: Vector3, radius: Double) -> Double? {
    guard finite(center), radius.isFinite, radius > 0 else { return nil }
    let offset = ray.origin - center
    let projection = offset.dot(ray.direction)
    let square = offset.dot(offset) - radius * radius
    guard projection.isFinite, square.isFinite else { return nil }
    if square <= 0 { return 0 }
    let discriminant = projection * projection - square
    guard discriminant.isFinite, discriminant >= 0 else { return nil }
    let entry = -projection - sqrt(discriminant)
    guard entry >= 0, entry <= ray.limit else { return nil }
    return entry
  }

  private static func meshHit(_ ray: Ray, mesh: PreparedMesh, limit: Double) -> Double? {
    var nearest: Double?
    for face in mesh.faces {
      let a = mesh.vertices[face.indices[0]]
      for index in 1..<(face.indices.count - 1) {
        let b = mesh.vertices[face.indices[index]]
        let c = mesh.vertices[face.indices[index + 1]]
        guard let distance = triangleHit(ray, a: a, b: b, c: c, limit: nearest ?? limit) else {
          continue
        }
        // Imported polygon faces may be concave. Fan triangles are tested on both
        // sides, then clipped to the authored polygon instead of filling its notch.
        if face.indices.count > 3
          && !contains(ray.origin + ray.direction * distance, face: face, mesh: mesh)
        {
          continue
        }
        nearest = distance
      }
    }
    return nearest
  }

  private static func triangleHit(_ ray: Ray, a: Vector3, b: Vector3, c: Vector3, limit: Double)
    -> Double?
  {
    let edge = b - a
    let other = c - a
    let cross = ray.direction.cross(other)
    let determinant = edge.dot(cross)
    guard determinant.isFinite, abs(determinant) > length(edge) * length(other) * 1e-12 else {
      return nil
    }
    let reciprocal = 1 / determinant
    let offset = ray.origin - a
    let u = offset.dot(cross) * reciprocal
    guard u >= -1e-10, u <= 1 + 1e-10 else { return nil }
    let perpendicular = offset.cross(edge)
    let v = ray.direction.dot(perpendicular) * reciprocal
    guard v >= -1e-10, u + v <= 1 + 1e-10 else { return nil }
    let distance = other.dot(perpendicular) * reciprocal
    guard distance.isFinite, distance >= 0, distance <= limit else { return nil }
    return distance
  }

  private static func contains(_ point: Vector3, face: Face, mesh: PreparedMesh) -> Bool {
    func projected(_ point: Vector3) -> (Double, Double) {
      switch face.projectionAxis {
      case 0: return (point.y, point.z)
      case 1: return (point.x, point.z)
      default: return (point.x, point.y)
      }
    }
    let (x, y) = projected(point)
    var inside = false
    var previous = projected(mesh.vertices[face.indices.last!])
    for index in face.indices {
      let current = projected(mesh.vertices[index])
      let cross =
        (current.0 - previous.0) * (y - previous.1) - (current.1 - previous.1) * (x - previous.0)
      if abs(cross) < 1e-9 && x >= min(previous.0, current.0) - 1e-9
        && x <= max(previous.0, current.0) + 1e-9 && y >= min(previous.1, current.1) - 1e-9
        && y <= max(previous.1, current.1) + 1e-9
      {
        return true
      }
      if (previous.1 > y) != (current.1 > y),
        x < (current.0 - previous.0) * (y - previous.1) / (current.1 - previous.1) + previous.0
      {
        inside.toggle()
      }
      previous = current
    }
    return inside
  }

  private static func precedes(_ first: GameplayHitTarget, _ second: GameplayHitTarget) -> Bool {
    func key(_ target: GameplayHitTarget) -> (Int, Int) {
      switch target {
      case .celestial(.planet): return (0, 0)
      case .celestial(.sun): return (0, 1)
      case .body(let id): return (1, id)
      case .player: return (2, 0)
      }
    }
    return key(first) < key(second)
  }

  private static func finite(_ point: Vector3) -> Bool {
    point.x.isFinite && point.y.isFinite && point.z.isFinite
  }
  private static func length(_ point: Vector3) -> Double { hypot(hypot(point.x, point.y), point.z) }
}
