import Foundation

public enum HullSweepFailure: Error, Sendable, Equatable {
  case invalidGeometry, geometryTooComplex, invalidMotion
  case insideHull, clearanceViolation, unproven, workBudgetExceeded

  public var message: String {
    switch self {
    case .invalidGeometry: "Invalid hull geometry"
    case .geometryTooComplex: "Hull preparation budget exceeded"
    case .invalidMotion: "Invalid swept motion"
    case .insideHull: "Player overlaps a closed hull"
    case .clearanceViolation: "Insufficient hull clearance"
    case .unproven: "Continuous hull clearance not proven"
    case .workBudgetExceeded: "Hull sweep work budget exceeded"
    }
  }
}

public struct HullSweepBudget: Sendable {
  public var distanceQueries: Int
  public var triangleTests: Int
  public var nodeVisits: Int
  public var subdivisionDepth: Int
  public static let standard = Self(
    distanceQueries: 256, triangleTests: 500_000, nodeVisits: 500_000, subdivisionDepth: 12)

  public init(distanceQueries: Int, triangleTests: Int, nodeVisits: Int, subdivisionDepth: Int) {
    self.distanceQueries = distanceQueries
    self.triangleTests = triangleTests
    self.nodeVisits = nodeVisits
    self.subdivisionDepth = subdivisionDepth
  }
}

public struct HullSweepResult: Sendable {
  public let failure: HullSweepFailure?
  public let obstacle: ActorIdentity?
  public let minimumSampledClearance: Double?
  public let distanceQueries: Int
  public let triangleTests: Int
  public let nodeVisits: Int
  public var safe: Bool { failure == nil }
  public var clearance: RelativeWorkClearance {
    failure.map { .blocked($0.message) } ?? .clear
  }
}

/// Pose and angular velocity describe the actual model axes, including any model spin.
public struct HullSweepObstacle: Sendable {
  public let identity: ActorIdentity?
  public let hull: PreparedHull
  public let pose: ShipPose
  public let velocity: Vector3
  public let angularVelocity: Vector3

  public init(
    identity: ActorIdentity? = nil, hull: PreparedHull, pose: ShipPose,
    velocity: Vector3 = .init(0, 0, 0), angularVelocity: Vector3 = .init(0, 0, 0)
  ) {
    self.identity = identity
    self.hull = hull
    self.pose = pose
    self.velocity = velocity
    self.angularVelocity = angularVelocity
  }
}

/// Immutable native triangles/BVH. Cache by geometry revision, never rebuild per physics step.
public struct PreparedHull: Sendable {
  public let radius: Double
  public let triangleCount: Int
  public let isClosed: Bool
  fileprivate let triangles: [SweepTriangle]
  fileprivate let nodes: [SweepNode]
  fileprivate let components: [SweepComponent]

  public init(mesh: Mesh, maximumTriangles: Int = 20_000) throws {
    guard maximumTriangles > 0, maximumTriangles <= 100_000,
      !mesh.vertices.isEmpty, !mesh.faces.isEmpty
    else { throw HullSweepFailure.invalidGeometry }
    guard mesh.vertices.count <= maximumTriangles * 3,
      mesh.faces.count <= maximumTriangles,
      mesh.faces.allSatisfy({ $0.count <= 256 }),
      mesh.faces.reduce(0, { $0 + max(1, $1.count - 2) }) <= maximumTriangles
    else { throw HullSweepFailure.geometryTooComplex }
    guard mesh.vertices.allSatisfy(sweepFinite) else { throw HullSweepFailure.invalidGeometry }
    var welded: [SweepVertexKey: Int] = [:]
    var vertices: [Vector3] = []
    let remap = mesh.vertices.map { point in
      let key = SweepVertexKey(x: point.x, y: point.y, z: point.z)
      if let index = welded[key] { return index }
      let index = vertices.count
      welded[key] = index
      vertices.append(point)
      return index
    }
    var faces: [[Int]] = []
    var faceTriangles: [[Int]] = []
    var triangles: [SweepTriangle] = []
    for face in mesh.faces {
      guard face.count >= 3, face.allSatisfy(mesh.vertices.indices.contains) else {
        throw HullSweepFailure.invalidGeometry
      }
      var indices = face.map { remap[$0] }
      if indices.first == indices.last { indices.removeLast() }
      guard indices.count >= 3, Set(indices).count == indices.count else {
        throw HullSweepFailure.invalidGeometry
      }
      let generated = try sweepTriangulate(indices.map { vertices[$0] })
      faces.append(indices)
      faceTriangles.append(Array(triangles.count..<(triangles.count + generated.count)))
      triangles += generated
    }
    guard !triangles.isEmpty else { throw HullSweepFailure.invalidGeometry }
    guard
      triangles.allSatisfy({ triangle in
        let first = triangle.b - triangle.a
        let second = triangle.c - triangle.a
        let scale = max(first.length, max(second.length, (triangle.c - triangle.b).length))
        return sweepFinite(first.cross(second)) && first.cross(second).length > scale * scale * 1e-6
      })
    else { throw HullSweepFailure.invalidGeometry }
    self.triangles = triangles
    triangleCount = triangles.count
    radius = vertices.map(\.length).max() ?? 0
    guard radius.isFinite, radius > 0 else { throw HullSweepFailure.invalidGeometry }
    components = sweepComponents(vertices: vertices, faces: faces, triangles: faceTriangles)
    isClosed = components.allSatisfy(\.closed)
    self.nodes = sweepBVH(triangles)
  }
}

public enum HullSweepSafety {
  /// A player sphere is an enclosing collision bound, not a substitute for target surfaces.
  /// Exact-player mode additionally tests triangle pairs, with BVH pruning and the same budget.
  public static func validate(
    _ sweep: RelativeWorkSweep, target: PreparedHull, player: PreparedHull? = nil,
    obstacles: [HullSweepObstacle] = [], budget: HullSweepBudget = .standard
  ) -> HullSweepResult {
    var work = SweepWork(budget: budget)
    var obstacleID: ActorIdentity? = sweep.target.identity
    do {
      try validateMotion(sweep, player: player, budget: budget)
      let primary = HullSweepObstacle(
        identity: sweep.target.identity, hull: target, pose: sweep.target.pose,
        velocity: sweep.target.velocity, angularVelocity: sweep.target.angularVelocity)
      for obstacle in [primary] + obstacles {
        obstacleID = obstacle.identity
        guard sweepValid(obstacle.pose), sweepFinite(obstacle.velocity),
          sweepFinite(obstacle.angularVelocity)
        else { throw HullSweepFailure.invalidMotion }
        try prove(sweep, obstacle: obstacle, player: player, work: &work)
      }
      return result(nil, obstacle: nil, work: work)
    } catch let failure as HullSweepFailure {
      return result(failure, obstacle: obstacleID, work: work)
    } catch {
      return result(.unproven, obstacle: obstacleID, work: work)
    }
  }

  private static func result(
    _ failure: HullSweepFailure?, obstacle: ActorIdentity?, work: SweepWork
  ) -> HullSweepResult {
    .init(
      failure: failure, obstacle: obstacle,
      minimumSampledClearance: work.minimum.isFinite ? work.minimum : nil,
      distanceQueries: work.queries, triangleTests: work.tests, nodeVisits: work.nodes)
  }

  private static func validateMotion(
    _ sweep: RelativeWorkSweep, player: PreparedHull?, budget: HullSweepBudget
  ) throws {
    guard sweepValid(sweep.start), sweepValid(sweep.end), sweepValid(sweep.target.pose),
      sweepValid(sweep.targetEnd), sweepFinite(sweep.initialVelocity),
      sweepFinite(sweep.acceleration), sweepFinite(sweep.angularVelocity),
      sweepFinite(sweep.target.velocity), sweepFinite(sweep.target.angularVelocity),
      sweep.duration.isFinite, sweep.duration > 0,
      sweep.playerRadius.isFinite, sweep.playerRadius >= 0,
      sweep.requiredClearance.isFinite, sweep.requiredClearance >= 0,
      budget.distanceQueries > 0, budget.triangleTests > 0, budget.nodeVisits > 0,
      (0...20).contains(budget.subdivisionDepth),
      player.map({ $0.radius <= sweep.playerRadius + 1e-8 }) ?? true
    else { throw HullSweepFailure.invalidMotion }
    let expected = shipPose(sweep, at: sweep.duration)
    let targetExpected = sweepPose(
      sweep.target.pose, velocity: sweep.target.velocity,
      omega: sweep.target.angularVelocity, time: sweep.duration)
    guard sweepSame(expected, sweep.end), sweepSame(targetExpected, sweep.targetEnd) else {
      throw HullSweepFailure.invalidMotion
    }
  }

  private static func shipPose(_ sweep: RelativeWorkSweep, at time: Double) -> ShipPose {
    var pose = sweepPose(
      sweep.start, velocity: sweep.initialVelocity, omega: sweep.angularVelocity, time: time)
    pose.position = pose.position + sweep.acceleration * (0.5 * time * time)
    return pose
  }

  private static func prove(
    _ sweep: RelativeWorkSweep, obstacle: HullSweepObstacle, player: PreparedHull?,
    work: inout SweepWork
  ) throws {
    // Endpoints are necessary but insufficient: every interval needs a motion-envelope proof.
    _ = try distance(sweep, obstacle: obstacle, player: player, at: 0, work: &work)
    _ = try distance(sweep, obstacle: obstacle, player: player, at: sweep.duration, work: &work)
    var intervals: [(Double, Double, Int)] = [(0, sweep.duration, 0)]
    while let (start, end, depth) = intervals.popLast() {
      let middle = (start + end) * 0.5
      let half = (end - start) * 0.5
      let separation = try distance(
        sweep, obstacle: obstacle, player: player, at: middle, work: &work)
      let relativeSpeed =
        (sweep.initialVelocity + sweep.acceleration * middle - obstacle.velocity).length
        + sweep.acceleration.length * half
      let angularSpeed =
        obstacle.angularVelocity.length * obstacle.hull.radius
        + (player == nil ? 0 : sweep.angularVelocity.length * sweep.playerRadius)
      let envelope = (relativeSpeed + angularSpeed) * half
      guard envelope.isFinite else { throw HullSweepFailure.invalidMotion }
      // Keep numerical headroom as well as the continuous-motion envelope.
      let numerical =
        1e-8
        * max(
          1,
          obstacle.hull.radius + sweep.playerRadius + sweep.start.position.length
            + obstacle.pose.position.length)
      if separation - envelope - numerical > sweep.requiredClearance { continue }
      guard depth < work.budget.subdivisionDepth else { throw HullSweepFailure.unproven }
      intervals.append((middle, end, depth + 1))
      intervals.append((start, middle, depth + 1))
    }
  }

  private static func distance(
    _ sweep: RelativeWorkSweep, obstacle: HullSweepObstacle, player: PreparedHull?, at time: Double,
    work: inout SweepWork
  ) throws -> Double {
    try work.query()
    let ship = shipPose(sweep, at: time)
    let target = sweepPose(
      obstacle.pose, velocity: obstacle.velocity, omega: obstacle.angularVelocity, time: time)
    guard sweepValid(ship), sweepValid(target) else { throw HullSweepFailure.invalidMotion }
    let separation: Double
    if let player {
      separation = try meshDistance(
        player, pose: ship, obstacle: obstacle.hull, pose: target, work: &work)
    } else {
      let point = target.shipPoint(ship.position)
      let distance = try pointDistance(point, hull: obstacle.hull, work: &work)
      if try contains(point, hull: obstacle.hull, work: &work) {
        throw HullSweepFailure.insideHull
      }
      separation = max(0, distance - sweep.playerRadius)
    }
    guard separation.isFinite else { throw HullSweepFailure.invalidMotion }
    work.minimum = min(work.minimum, separation)
    guard separation >= sweep.requiredClearance, separation > 1e-9 else {
      throw HullSweepFailure.clearanceViolation
    }
    return separation
  }

  private static func pointDistance(
    _ point: Vector3, hull: PreparedHull, work: inout SweepWork
  ) throws -> Double {
    var best = Double.infinity
    var pending = [0]
    while let index = pending.popLast() {
      try work.node()
      let node = hull.nodes[index]
      if node.bounds.distanceSquared(to: point) >= best * best { continue }
      if let (left, right) = node.children {
        let lhs = hull.nodes[left].bounds.distanceSquared(to: point)
        let rhs = hull.nodes[right].bounds.distanceSquared(to: point)
        pending += lhs < rhs ? [right, left] : [left, right]
      } else {
        for index in node.triangles {
          try work.triangle()
          best = min(best, sweepPointTriangle(point, hull.triangles[index]))
        }
      }
    }
    return best
  }

  private static func meshDistance(
    _ player: PreparedHull, pose ship: ShipPose, obstacle: PreparedHull, pose target: ShipPose,
    work: inout SweepWork
  ) throws -> Double {
    for component in player.components {
      let point = target.shipPoint(ship.systemPoint(component.representative))
      if try contains(point, hull: obstacle, work: &work) { throw HullSweepFailure.insideHull }
    }
    for component in obstacle.components {
      let point = ship.shipPoint(target.systemPoint(component.representative))
      if try contains(point, hull: player, work: &work) { throw HullSweepFailure.insideHull }
    }
    var best = Double.infinity
    for original in player.triangles {
      let triangle = SweepTriangle(
        a: target.shipPoint(ship.systemPoint(original.a)),
        b: target.shipPoint(ship.systemPoint(original.b)),
        c: target.shipPoint(ship.systemPoint(original.c)))
      best = try triangleDistance(triangle, hull: obstacle, startingBest: best, work: &work)
      if best < 1e-9 { return 0 }
    }
    return best
  }

  private static func triangleDistance(
    _ triangle: SweepTriangle, hull: PreparedHull, startingBest: Double, work: inout SweepWork
  ) throws -> Double {
    var best = startingBest
    var pending = [0]
    while let index = pending.popLast() {
      try work.node()
      let node = hull.nodes[index]
      if node.bounds.distanceSquared(to: triangle.bounds) >= best * best { continue }
      if let (left, right) = node.children {
        pending += [right, left]
      } else {
        for index in node.triangles {
          try work.triangle()
          best = min(best, sweepTriangleDistance(triangle, hull.triangles[index]))
        }
      }
    }
    return best
  }

  private static func contains(
    _ point: Vector3, hull: PreparedHull, work: inout SweepWork
  ) throws -> Bool {
    for component in hull.components where component.bounds.contains(point) {
      guard component.closed else { throw HullSweepFailure.unproven }
      if try inside(point, hull: hull, component: component, work: &work) { return true }
    }
    return false
  }

  private static func inside(
    _ point: Vector3, hull: PreparedHull, component: SweepComponent, work: inout SweepWork
  ) throws -> Bool {
    for direction in [Vector3(1, 0.371, 0.529), .init(0.293, 1, 0.613), .init(0.419, 0.227, 1)] {
      if let parity = try rayParity(
        point, direction: direction, hull: hull, component: component, work: &work)
      {
        return parity
      }
    }
    throw HullSweepFailure.unproven
  }
  private static func rayParity(
    _ point: Vector3, direction: Vector3, hull: PreparedHull, component: SweepComponent,
    work: inout SweepWork
  ) throws -> Bool? {
    var hits: [Double] = []
    for index in component.triangles {
      try work.triangle()
      if let hit = sweepRay(point, direction: direction, triangle: hull.triangles[index]) {
        if hit.boundary {
          return nil
        }
        hits.append(hit.distance)
      }
    }
    hits.sort()
    var distinct: [Double] = []
    for hit in hits where distinct.last.map({ abs($0 - hit) > 1e-8 * max(1, abs(hit)) }) ?? true {
      distinct.append(hit)
    }
    return distinct.count % 2 == 1
  }

}

private func sweepBVH(_ triangles: [SweepTriangle]) -> [SweepNode] {
  var nodes: [SweepNode] = []
  func build(_ indices: [Int]) -> Int {
    let bounds = indices.dropFirst().reduce(triangles[indices[0]].bounds) {
      $0.union(triangles[$1].bounds)
    }
    let index = nodes.count
    nodes.append(.init(bounds: bounds, children: nil, triangles: []))
    if indices.count <= 8 {
      nodes[index] = .init(bounds: bounds, children: nil, triangles: indices)
    } else {
      let extent = bounds.upper - bounds.lower
      let axis = sweepAxis(extent)
      let ordered = indices.sorted {
        let lhs = sweepCoordinate(triangles[$0].bounds.center, axis)
        let rhs = sweepCoordinate(triangles[$1].bounds.center, axis)
        return lhs == rhs ? $0 < $1 : lhs < rhs
      }
      let middle = ordered.count / 2
      let left = build(Array(ordered[..<middle]))
      let right = build(Array(ordered[middle...]))
      nodes[index] = .init(bounds: bounds, children: (left, right), triangles: [])
    }
    return index
  }
  _ = build(Array(triangles.indices))
  return nodes
}

private struct SweepWork {
  let budget: HullSweepBudget
  var queries = 0
  var tests = 0
  var nodes = 0
  var minimum = Double.infinity
  mutating func query() throws {
    guard queries < budget.distanceQueries else { throw HullSweepFailure.workBudgetExceeded }
    queries += 1
  }
  mutating func triangle() throws {
    guard tests < budget.triangleTests else { throw HullSweepFailure.workBudgetExceeded }
    tests += 1
  }
  mutating func node() throws {
    guard nodes < budget.nodeVisits else { throw HullSweepFailure.workBudgetExceeded }
    nodes += 1
  }
}

private struct SweepVertexKey: Hashable {
  let x: Double
  let y: Double
  let z: Double
}
private struct SweepEdge: Hashable {
  let low: Int
  let high: Int
  init(_ a: Int, _ b: Int) {
    low = min(a, b)
    high = max(a, b)
  }
}

private struct SweepBounds: Sendable {
  let lower: Vector3
  let upper: Vector3
  var center: Vector3 { lower * 0.5 + upper * 0.5 }
  func union(_ other: Self) -> Self {
    .init(
      lower: .init(
        min(lower.x, other.lower.x), min(lower.y, other.lower.y), min(lower.z, other.lower.z)),
      upper: .init(
        max(upper.x, other.upper.x), max(upper.y, other.upper.y), max(upper.z, other.upper.z)))
  }
  func contains(_ point: Vector3) -> Bool {
    point.x >= lower.x && point.x <= upper.x && point.y >= lower.y && point.y <= upper.y
      && point.z >= lower.z && point.z <= upper.z
  }
  func distanceSquared(to point: Vector3) -> Double {
    let dx = max(0, max(lower.x - point.x, point.x - upper.x))
    let dy = max(0, max(lower.y - point.y, point.y - upper.y))
    let dz = max(0, max(lower.z - point.z, point.z - upper.z))
    return dx * dx + dy * dy + dz * dz
  }
  func distanceSquared(to other: Self) -> Double {
    let dx = max(0, max(lower.x - other.upper.x, other.lower.x - upper.x))
    let dy = max(0, max(lower.y - other.upper.y, other.lower.y - upper.y))
    let dz = max(0, max(lower.z - other.upper.z, other.lower.z - upper.z))
    return dx * dx + dy * dy + dz * dz
  }
}

private struct SweepTriangle: Sendable {
  let a: Vector3
  let b: Vector3
  let c: Vector3
  var vertices: [Vector3] { [a, b, c] }
  var edges: [(Vector3, Vector3)] { [(a, b), (b, c), (c, a)] }
  var bounds: SweepBounds {
    .init(
      lower: .init(min(a.x, min(b.x, c.x)), min(a.y, min(b.y, c.y)), min(a.z, min(b.z, c.z))),
      upper: .init(max(a.x, max(b.x, c.x)), max(a.y, max(b.y, c.y)), max(a.z, max(b.z, c.z))))
  }
}

private struct SweepNode: Sendable {
  let bounds: SweepBounds
  let children: (Int, Int)?
  let triangles: [Int]
}
private struct SweepComponent: Sendable {
  let bounds: SweepBounds
  let triangles: [Int]
  let closed: Bool
  let representative: Vector3
}

private func sweepComponents(
  vertices: [Vector3], faces: [[Int]], triangles: [[Int]]
) -> [SweepComponent] {
  var edges: [SweepEdge: [Int]] = [:]
  for (face, indices) in faces.enumerated() {
    for index in indices.indices {
      edges[.init(indices[index], indices[(index + 1) % indices.count]), default: []].append(face)
    }
  }
  var parents = Array(faces.indices)
  func root(_ index: Int) -> Int {
    var value = index
    while parents[value] != value { value = parents[value] }
    var current = index
    while parents[current] != current {
      let next = parents[current]
      parents[current] = value
      current = next
    }
    return value
  }
  for adjacent in edges.values {
    for face in adjacent.dropFirst() {
      let first = root(adjacent[0])
      let second = root(face)
      parents[max(first, second)] = min(first, second)
    }
  }
  var groups: [Int: [Int]] = [:]
  for index in faces.indices { groups[root(index), default: []].append(index) }
  return groups.keys.sorted().map { key in
    let members = groups[key, default: []]
    let points = members.flatMap { faces[$0].map { vertices[$0] } }
    let initial = SweepBounds(lower: points[0], upper: points[0])
    let bounds = points.dropFirst().reduce(initial) { $0.union(.init(lower: $1, upper: $1)) }
    let closed = members.allSatisfy { face in
      let indices = faces[face]
      return indices.indices.allSatisfy {
        edges[.init(indices[$0], indices[($0 + 1) % indices.count])]?.count == 2
      }
    }
    return .init(
      bounds: bounds, triangles: members.flatMap { triangles[$0] }, closed: closed,
      representative: points[0])
  }
}

private struct SweepPoint2 {
  let x: Double
  let y: Double
}
private func sweepCross(_ a: SweepPoint2, _ b: SweepPoint2, _ c: SweepPoint2) -> Double {
  (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
}
private func sweepTriangulate(_ vertices: [Vector3]) throws -> [SweepTriangle] {
  let normal = (1..<(vertices.count - 1)).lazy.map {
    (vertices[$0] - vertices[0]).cross(vertices[$0 + 1] - vertices[0])
  }.first { $0.length > 1e-9 }
  guard let normal, sweepFinite(normal) else { throw HullSweepFailure.invalidGeometry }
  let axis = sweepAxis(.init(abs(normal.x), abs(normal.y), abs(normal.z)))
  let points = vertices.map { point -> SweepPoint2 in
    switch axis {
    case 0: .init(x: point.y, y: point.z)
    case 1: .init(x: point.x, y: point.z)
    default: .init(x: point.x, y: point.y)
    }
  }
  try sweepCheckEdges(points)
  let area = points.indices.reduce(0.0) {
    $0 + points[$1].x * points[($1 + 1) % points.count].y
      - points[($1 + 1) % points.count].x * points[$1].y
  }
  guard abs(area) > 1e-9, area.isFinite else { throw HullSweepFailure.invalidGeometry }
  let sign = area > 0 ? 1.0 : -1.0
  return try sweepEars(vertices, points: points, sign: sign)
}

private func sweepPointSegment(_ point: Vector3, _ a: Vector3, _ b: Vector3) -> Double {
  let edge = b - a
  let square = edge.dot(edge)
  let fraction = square > 0 ? max(0, min(1, (point - a).dot(edge) / square)) : 0
  return (point - a - edge * fraction).length
}
private func sweepPointTriangle(_ point: Vector3, _ triangle: SweepTriangle) -> Double {
  let normal = (triangle.b - triangle.a).cross(triangle.c - triangle.a)
  let square = normal.dot(normal)
  let projected = point - normal * ((point - triangle.a).dot(normal) / square)
  let inside = triangle.edges.allSatisfy {
    ($0.1 - $0.0).cross(projected - $0.0).dot(normal) >= 0
  }
  if inside { return abs((point - triangle.a).dot(normal)) / sqrt(square) }
  return triangle.edges.map { sweepPointSegment(point, $0.0, $0.1) }.min() ?? .infinity
}
private func sweepRay(
  _ origin: Vector3, direction: Vector3, triangle: SweepTriangle
) -> (distance: Double, boundary: Bool)? {
  let edge = triangle.b - triangle.a
  let other = triangle.c - triangle.a
  let cross = direction.cross(other)
  let determinant = edge.dot(cross)
  guard abs(determinant) > 1e-12 * edge.length * other.length * direction.length else { return nil }
  let offset = origin - triangle.a
  let u = offset.dot(cross) / determinant
  let perpendicular = offset.cross(edge)
  let v = direction.dot(perpendicular) / determinant
  let distance = other.dot(perpendicular) / determinant
  guard u >= 0, v >= 0, u + v <= 1, distance >= 0 else { return nil }
  return (distance, min(u, min(v, 1 - u - v)) < 1e-10)
}
private func sweepSegmentDistance(_ a: (Vector3, Vector3), _ b: (Vector3, Vector3)) -> Double {
  let d = a.1 - a.0
  let e = b.1 - b.0
  let r = a.0 - b.0
  let aa = d.dot(d)
  let ee = e.dot(e)
  let de = d.dot(e)
  let dr = d.dot(r)
  let er = e.dot(r)
  let denominator = aa * ee - de * de
  var s = denominator > 1e-18 ? max(0, min(1, (de * er - dr * ee) / denominator)) : 0
  var t = (de * s + er) / ee
  if t < 0 {
    t = 0
    s = max(0, min(1, -dr / aa))
  }
  if t > 1 {
    t = 1
    s = max(0, min(1, (de - dr) / aa))
  }
  return (r + d * s - e * t).length
}
private func sweepTriangleDistance(_ a: SweepTriangle, _ b: SweepTriangle) -> Double {
  for (start, end) in a.edges {
    if let hit = sweepRay(start, direction: end - start, triangle: b), hit.distance <= 1 {
      return 0
    }
  }
  for (start, end) in b.edges {
    if let hit = sweepRay(start, direction: end - start, triangle: a), hit.distance <= 1 {
      return 0
    }
  }
  var distance = min(
    a.vertices.map { sweepPointTriangle($0, b) }.min() ?? .infinity,
    b.vertices.map { sweepPointTriangle($0, a) }.min() ?? .infinity)
  for first in a.edges {
    for second in b.edges { distance = min(distance, sweepSegmentDistance(first, second)) }
  }
  return distance
}

private func sweepPose(_ initial: ShipPose, velocity: Vector3, omega: Vector3, time: Double)
  -> ShipPose
{
  var pose = initial
  pose.position = initial.position + velocity * time
  if omega.length > 1e-12 {
    let axis = omega * (1 / omega.length)
    let angle = omega.length * time
    func rotate(_ point: Vector3) -> Vector3 {
      point * cos(angle) + axis.cross(point) * sin(angle) + axis
        * (axis.dot(point) * (1 - cos(angle)))
    }
    pose.orientation.x = rotate(initial.orientation.x)
    pose.orientation.y = rotate(initial.orientation.y)
    pose.orientation.z = rotate(initial.orientation.z)
  }
  return pose
}
private func sweepSame(_ lhs: ShipPose, _ rhs: ShipPose) -> Bool {
  (lhs.position - rhs.position).length < 1e-7
    && (lhs.orientation.x - rhs.orientation.x).length < 1e-7
    && (lhs.orientation.y - rhs.orientation.y).length < 1e-7
    && (lhs.orientation.z - rhs.orientation.z).length < 1e-7
}
private func sweepValid(_ pose: ShipPose) -> Bool {
  let basis = pose.orientation
  return sweepFinite(pose.position) && [basis.x, basis.y, basis.z].allSatisfy(sweepFinite)
    && abs(basis.x.length - 1) < 1e-6 && abs(basis.y.length - 1) < 1e-6
    && abs(basis.z.length - 1) < 1e-6 && abs(basis.x.dot(basis.y)) < 1e-6
    && (basis.x.cross(basis.y) - basis.z).length < 1e-6
}
private func sweepFinite(_ point: Vector3) -> Bool {
  point.x.isFinite && point.y.isFinite && point.z.isFinite && point.length.isFinite
}
private func sweepAxis(_ extent: Vector3) -> Int {
  if extent.x >= extent.y && extent.x >= extent.z { return 0 }
  return extent.y >= extent.z ? 1 : 2
}
private func sweepCoordinate(_ point: Vector3, _ axis: Int) -> Double {
  switch axis {
  case 0: point.x
  case 1: point.y
  default: point.z
  }
}

private func sweepCheckEdges(_ points: [SweepPoint2]) throws {
  for first in points.indices {
    for second in points.indices
    where second > first + 1 && !(first == 0 && second == points.count - 1) {
      let a = points[first]
      let b = points[(first + 1) % points.count]
      let c = points[second]
      let d = points[(second + 1) % points.count]
      if sweepCross(a, b, c) * sweepCross(a, b, d) < 0
        && sweepCross(c, d, a) * sweepCross(c, d, b) < 0
      {
        throw HullSweepFailure.invalidGeometry
      }
    }
  }
}

private func sweepEars(
  _ vertices: [Vector3], points: [SweepPoint2], sign: Double
) throws -> [SweepTriangle] {
  var polygon = Array(vertices.indices)
  var result: [SweepTriangle] = []
  while polygon.count > 3 {
    guard let ear = sweepFindEar(polygon, points: points, sign: sign) else {
      throw HullSweepFailure.invalidGeometry
    }
    if let (a, b, c) = ear.triangle {
      result.append(.init(a: vertices[a], b: vertices[b], c: vertices[c]))
    }
    polygon.remove(at: ear.index)
  }

  guard polygon.count == 3,
    (vertices[polygon[1]] - vertices[polygon[0]]).cross(vertices[polygon[2]] - vertices[polygon[0]])
      .length > 1e-9
  else { throw HullSweepFailure.invalidGeometry }
  result.append(.init(a: vertices[polygon[0]], b: vertices[polygon[1]], c: vertices[polygon[2]]))
  return result
}
private func sweepFindEar(
  _ polygon: [Int], points: [SweepPoint2], sign: Double
) -> (index: Int, triangle: (Int, Int, Int)?)? {
  for index in polygon.indices {
    let a = polygon[(index + polygon.count - 1) % polygon.count]
    let b = polygon[index]
    let c = polygon[(index + 1) % polygon.count]
    let turn = sweepCross(points[a], points[b], points[c]) * sign
    if abs(turn) <= 1e-9 {
      return (index, nil)
    }
    if turn < 0 { continue }
    let occupied = polygon.contains { other in
      other != a && other != b && other != c
        && sweepCross(points[a], points[b], points[other]) * sign >= -1e-9
        && sweepCross(points[b], points[c], points[other]) * sign >= -1e-9
        && sweepCross(points[c], points[a], points[other]) * sign >= -1e-9
    }
    if occupied { continue }
    return (index, (a, b, c))
  }
  return nil
}
