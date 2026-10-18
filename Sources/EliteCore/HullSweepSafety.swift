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
  /// Nil inherits the work stand-off; zero still requires proven positive collision separation.
  public let clearanceOverride: Double?

  public init(
    identity: ActorIdentity? = nil, hull: PreparedHull, pose: ShipPose,
    velocity: Vector3 = .init(0, 0, 0), angularVelocity: Vector3 = .init(0, 0, 0),
    clearanceOverride: Double? = nil
  ) {
    self.identity = identity
    self.hull = hull
    self.pose = pose
    self.velocity = velocity
    self.angularVelocity = angularVelocity
    self.clearanceOverride = clearanceOverride
  }
}

/// Exact target-free motion; the simulation supplies every obstacle still present.
public struct HullSceneMotion: Equatable, Sendable {
  public let start: ShipPose
  public let end: ShipPose
  public let initialVelocity: Vector3
  public let acceleration: Vector3
  public let worldAngularVelocity: Vector3
  public let duration: Double
  public let playerRadius: Double
  public let requiredClearance: Double

  public init(
    start: ShipPose, end: ShipPose, initialVelocity: Vector3, acceleration: Vector3,
    worldAngularVelocity: Vector3, duration: Double, playerRadius: Double,
    requiredClearance: Double = 0
  ) {
    self.start = start
    self.end = end
    self.initialVelocity = initialVelocity
    self.acceleration = acceleration
    self.worldAngularVelocity = worldAngularVelocity
    self.duration = duration
    self.playerRadius = playerRadius
    self.requiredClearance = requiredClearance
  }

  public init(from sweep: RelativeWorkSweep) {
    self.init(
      start: sweep.start, end: sweep.end, initialVelocity: sweep.initialVelocity,
      acceleration: sweep.acceleration, worldAngularVelocity: sweep.angularVelocity,
      duration: sweep.duration, playerRadius: sweep.playerRadius,
      requiredClearance: sweep.requiredClearance)
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
    guard triangles.allSatisfy(\.hasResolvedArea)
    else { throw HullSweepFailure.invalidGeometry }
    self.triangles = triangles
    triangleCount = triangles.count
    radius = vertices.map(\.length).max() ?? 0
    guard radius.isFinite, radius > 0 else { throw HullSweepFailure.invalidGeometry }
    components = sweepComponents(
      vertices: vertices, faces: faces, triangles: faceTriangles, geometry: triangles)
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
      try validateObstacles(
        HullSceneMotion(from: sweep), player: player, obstacles: [primary] + obstacles,
        work: &work, obstacleID: &obstacleID)
      return result(nil, obstacle: nil, work: work)
    } catch let failure as HullSweepFailure {
      return result(failure, obstacle: obstacleID, work: work)
    } catch {
      return result(.unproven, obstacle: obstacleID, work: work)
    }
  }

  /// Continuous scene proof without a primary target; empty scenes still validate motion.
  public static func validateSceneMotion(
    _ motion: HullSceneMotion, player: PreparedHull? = nil,
    obstacles: [HullSweepObstacle] = [], budget: HullSweepBudget = .standard
  ) -> HullSweepResult {
    var work = SweepWork(budget: budget)
    var obstacleID: ActorIdentity?
    do {
      try validateMotion(motion, player: player, budget: budget)
      try validateObstacles(
        motion, player: player, obstacles: obstacles, work: &work, obstacleID: &obstacleID)
      return result(nil, obstacle: nil, work: work)
    } catch let failure as HullSweepFailure {
      return result(failure, obstacle: obstacleID, work: work)
    } catch {
      return result(.unproven, obstacle: obstacleID, work: work)
    }
  }

  private static func validateObstacles(
    _ motion: HullSceneMotion, player: PreparedHull?, obstacles: [HullSweepObstacle],
    work: inout SweepWork, obstacleID: inout ActorIdentity?
  ) throws {
    for obstacle in obstacles {
      obstacleID = obstacle.identity
      let requiredClearance = obstacle.clearanceOverride ?? motion.requiredClearance
      guard requiredClearance.isFinite, requiredClearance >= 0, sweepValid(obstacle.pose),
        sweepFinite(obstacle.velocity), sweepFinite(obstacle.angularVelocity)
      else { throw HullSweepFailure.invalidMotion }
      try prove(
        motion, obstacle: obstacle, player: player, requiredClearance: requiredClearance,
        work: &work)
    }
  }

  /// Static admission only; moving work still requires the continuous sweep validator.
  public static func validatePlacement(
    center: Vector3, radius: Double, hull: PreparedHull, pose: ShipPose,
    requiredClearance: Double = 0, budget: HullSweepBudget = .standard
  ) -> HullSweepResult {
    var work = SweepWork(budget: budget)
    do {
      guard sweepFinite(center), radius.isFinite, radius > 0, sweepValid(pose),
        requiredClearance.isFinite, requiredClearance >= 0,
        budget.distanceQueries > 0, budget.triangleTests > 0, budget.nodeVisits > 0,
        (0...20).contains(budget.subdivisionDepth)
      else { throw HullSweepFailure.invalidMotion }
      let point = pose.shipPoint(center)
      guard sweepFinite(point) else { throw HullSweepFailure.invalidMotion }
      try work.query()
      let separation = try pointDistance(point, hull: hull, work: &work) - radius
      guard separation.isFinite else { throw HullSweepFailure.invalidMotion }
      work.minimum = separation
      // Open components with ambiguous containment fail closed in the shared query.
      if try contains(point, hull: hull, work: &work) { throw HullSweepFailure.insideHull }
      guard separation > requiredClearance, separation > 1e-9 else {
        throw HullSweepFailure.clearanceViolation
      }
      let numerical =
        1e-8 * max(1, hull.radius + radius + center.length + pose.position.length)
      guard numerical.isFinite else { throw HullSweepFailure.invalidMotion }
      guard separation - requiredClearance > numerical else { throw HullSweepFailure.unproven }
      return result(nil, obstacle: nil, work: work)
    } catch let failure as HullSweepFailure {
      return result(failure, obstacle: nil, work: work)
    } catch {
      return result(.unproven, obstacle: nil, work: work)
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
    try validateMotion(HullSceneMotion(from: sweep), player: player, budget: budget)
    guard sweepValid(sweep.target.pose), sweepValid(sweep.targetEnd),
      sweepFinite(sweep.target.velocity), sweepFinite(sweep.target.angularVelocity)
    else { throw HullSweepFailure.invalidMotion }
    let targetExpected = sweepPose(
      sweep.target.pose, velocity: sweep.target.velocity,
      omega: sweep.target.angularVelocity, time: sweep.duration)
    guard sweepSame(targetExpected, sweep.targetEnd) else { throw HullSweepFailure.invalidMotion }
  }

  private static func validateMotion(
    _ motion: HullSceneMotion, player: PreparedHull?, budget: HullSweepBudget
  ) throws {
    guard sweepValid(motion.start), sweepValid(motion.end), sweepFinite(motion.initialVelocity),
      sweepFinite(motion.acceleration), sweepFinite(motion.worldAngularVelocity),
      motion.duration.isFinite, motion.duration > 0,
      motion.playerRadius.isFinite, motion.playerRadius >= 0,
      motion.requiredClearance.isFinite, motion.requiredClearance >= 0,
      budget.distanceQueries > 0, budget.triangleTests > 0, budget.nodeVisits > 0,
      (0...20).contains(budget.subdivisionDepth),
      player.map({ $0.radius <= motion.playerRadius + 1e-8 }) ?? true
    else { throw HullSweepFailure.invalidMotion }
    let expected = shipPose(motion, at: motion.duration)
    guard sweepSame(expected, motion.end) else { throw HullSweepFailure.invalidMotion }
  }

  private static func shipPose(_ sweep: HullSceneMotion, at time: Double) -> ShipPose {
    var pose = sweepPose(
      sweep.start, velocity: sweep.initialVelocity, omega: sweep.worldAngularVelocity, time: time)
    pose.position = pose.position + sweep.acceleration * (0.5 * time * time)
    return pose
  }

  private static func prove(
    _ sweep: HullSceneMotion, obstacle: HullSweepObstacle, player: PreparedHull?,
    requiredClearance: Double, work: inout SweepWork
  ) throws {
    // Endpoints are necessary but insufficient: every interval needs a motion-envelope proof.
    _ = try distance(
      sweep, obstacle: obstacle, player: player, at: 0, requiredClearance: requiredClearance,
      work: &work)
    _ = try distance(
      sweep, obstacle: obstacle, player: player, at: sweep.duration,
      requiredClearance: requiredClearance, work: &work)
    var intervals: [(Double, Double, Int)] = [(0, sweep.duration, 0)]
    while let (start, end, depth) = intervals.popLast() {
      let middle = (start + end) * 0.5
      let half = (end - start) * 0.5
      let separation = try distance(
        sweep, obstacle: obstacle, player: player, at: middle, requiredClearance: requiredClearance,
        work: &work)
      let relativeSpeed =
        (sweep.initialVelocity + sweep.acceleration * middle - obstacle.velocity).length
        + sweep.acceleration.length * half
      let angularSpeed =
        obstacle.angularVelocity.length * obstacle.hull.radius
        + (player == nil ? 0 : sweep.worldAngularVelocity.length * sweep.playerRadius)
      let envelope = (relativeSpeed + angularSpeed) * half
      guard envelope.isFinite else { throw HullSweepFailure.invalidMotion }
      // Keep numerical headroom as well as the continuous-motion envelope.
      let numerical =
        1e-8
        * max(
          1,
          obstacle.hull.radius + sweep.playerRadius + sweep.start.position.length
            + obstacle.pose.position.length)
      if separation - envelope - numerical > requiredClearance { continue }
      guard depth < work.budget.subdivisionDepth else { throw HullSweepFailure.unproven }
      intervals.append((middle, end, depth + 1))
      intervals.append((start, middle, depth + 1))
    }
  }

  private static func distance(
    _ sweep: HullSceneMotion, obstacle: HullSweepObstacle, player: PreparedHull?, at time: Double,
    requiredClearance: Double, work: inout SweepWork
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
    guard separation >= requiredClearance, separation > 1e-9 else {
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
        c: target.shipPoint(ship.systemPoint(original.c)), conditioned: original.conditioned)
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
    let bounds = triangle.bounds
    while let index = pending.popLast() {
      try work.node()
      let node = hull.nodes[index]
      if node.bounds.distanceSquared(to: bounds) >= best * best { continue }
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
    var hits: [(distance: Double, uncertainty: Double, conditioned: Bool)] = []
    for index in component.triangles {
      try work.triangle()
      if let hit = sweepRay(
        point, direction: direction, triangle: hull.triangles[index],
        conditioned: component.conditioned)
      {
        if hit.boundary {
          return nil
        }
        hits.append((hit.distance, hit.uncertainty, component.conditioned))
      }
    }
    hits.sort { $0.distance < $1.distance }
    for (before, after) in zip(hits, hits.dropFirst())
    where before.conditioned || after.conditioned {
      let gap =
        (SweepInterval(after.distance)
        - (SweepInterval(before.distance) + SweepInterval(before.uncertainty))).lower
      let furthest = (SweepInterval(abs(after.distance)) + SweepInterval(after.uncertainty)).upper
      let tolerance = (SweepInterval(1e-8) * SweepInterval(max(1, furthest))).upper
      // A thin surface may have a genuinely distinct nearby crossing. Do not merge
      // uncertain crossings into a fictitious outside result as if they were duplicates.
      if gap <= tolerance { return nil }
    }
    var distinct: [Double] = []
    for hit in hits
    where distinct.last.map({ abs($0 - hit.distance) > 1e-8 * max(1, abs(hit.distance)) }) ?? true {
      distinct.append(hit.distance)
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
  let conditioned: Bool

  init(a: Vector3, b: Vector3, c: Vector3, conditioned: Bool = false) {
    self.a = a
    self.b = b
    self.c = c
    let first = b - a
    let second = c - a
    let scale = max(first.length, max(second.length, (c - b).length))
    // These are only the boundaries of the pre-existing fast query path, never
    // acceptance. Newly resolved small triangles need conservative queries as well.
    let area = first.cross(second).length
    self.conditioned = conditioned || area <= scale * scale * 1e-6 || area <= 1e-9
  }

  var hasResolvedArea: Bool {
    let normal = (SweepIntervalVector(b) - SweepIntervalVector(a)).cross(
      SweepIntervalVector(c) - SweepIntervalVector(a))
    let area = normal.length
    return area.finite && area.lower > 0
  }
  func vertex(at index: Int) -> Vector3 {
    switch index {
    case 0: a
    case 1: b
    default: c
    }
  }
  func edge(at index: Int) -> (Vector3, Vector3) {
    switch index {
    case 0: (a, b)
    case 1: (b, c)
    default: (c, a)
    }
  }
  var bounds: SweepBounds {
    .init(
      lower: .init(min(a.x, min(b.x, c.x)), min(a.y, min(b.y, c.y)), min(a.z, min(b.z, c.z))),
      upper: .init(max(a.x, max(b.x, c.x)), max(a.y, max(b.y, c.y)), max(a.z, max(b.z, c.z))))
  }
}

/// Outward rounding encloses operations on the stored Double coordinates. A zero-spanning
/// area is unresolved, not permission to remove a surface or to infer a closed component.
private struct SweepInterval {
  let lower: Double
  let upper: Double

  init(_ value: Double) {
    lower = value
    upper = value
  }

  init(lower: Double, upper: Double) {
    self.lower = lower
    self.upper = upper
  }

  static let whole = Self(lower: -.infinity, upper: .infinity)
  var finite: Bool { lower.isFinite && upper.isFinite }

  private static func enclosing(_ lower: Double, _ upper: Double) -> Self {
    guard !lower.isNaN, !upper.isNaN, lower <= upper else { return .whole }
    return .init(lower: lower.nextDown, upper: upper.nextUp)
  }

  static func + (a: Self, b: Self) -> Self {
    enclosing(a.lower + b.lower, a.upper + b.upper)
  }

  static func - (a: Self, b: Self) -> Self {
    enclosing(a.lower - b.upper, a.upper - b.lower)
  }

  static func * (a: Self, b: Self) -> Self {
    let products = [a.lower * b.lower, a.lower * b.upper, a.upper * b.lower, a.upper * b.upper]
    guard products.allSatisfy({ !$0.isNaN }) else { return .whole }
    return enclosing(products.min()!, products.max()!)
  }

  static func / (a: Self, b: Self) -> Self {
    guard b.lower > 0 || b.upper < 0 else { return .whole }
    return a * enclosing(1 / b.upper, 1 / b.lower)
  }

  var square: Self {
    let maximum = max(abs(lower), abs(upper))
    let minimum = lower <= 0 && upper >= 0 ? 0 : min(abs(lower), abs(upper))
    return .init(
      lower: max(0, (minimum * minimum).nextDown), upper: (maximum * maximum).nextUp)
  }

  var root: Self {
    guard upper >= 0 else { return .whole }
    return .init(
      lower: max(0, sqrt(max(0, lower)).nextDown), upper: sqrt(upper).nextUp)
  }

  var magnitude: Self {
    .init(
      lower: lower <= 0 && upper >= 0 ? 0 : min(abs(lower), abs(upper)),
      upper: max(abs(lower), abs(upper)))
  }
}

private struct SweepIntervalVector {
  let x: SweepInterval
  let y: SweepInterval
  let z: SweepInterval

  init(_ value: Vector3) {
    x = .init(value.x)
    y = .init(value.y)
    z = .init(value.z)
  }

  init(x: SweepInterval, y: SweepInterval, z: SweepInterval) {
    self.x = x
    self.y = y
    self.z = z
  }

  static func - (a: Self, b: Self) -> Self {
    .init(x: a.x - b.x, y: a.y - b.y, z: a.z - b.z)
  }

  static func * (a: Self, b: SweepInterval) -> Self {
    .init(x: a.x * b, y: a.y * b, z: a.z * b)
  }

  func dot(_ other: Self) -> SweepInterval {
    x * other.x + y * other.y + z * other.z
  }

  func cross(_ other: Self) -> Self {
    .init(
      x: y * other.z - z * other.y,
      y: z * other.x - x * other.z,
      z: x * other.y - y * other.x)
  }

  var length: SweepInterval { (x.square + y.square + z.square).root }
}

/// A projection gap along any finite axis is a lower bound on convex-set separation.
/// The approximate closest-feature axis only improves tightness: it cannot grant safety.
private func sweepSeparationLowerBound(_ a: [Vector3], _ b: [Vector3], axis: Vector3) -> Double {
  guard sweepFinite(axis), axis.length > 0, let origin = a.first else { return 0 }
  let direction = SweepIntervalVector(axis)
  let length = direction.length
  guard length.finite, length.lower > 0 else { return 0 }
  let base = SweepIntervalVector(origin)
  let left = a.map { (SweepIntervalVector($0) - base).dot(direction) }
  let right = b.map { (SweepIntervalVector($0) - base).dot(direction) }
  guard (left + right).allSatisfy(\.finite), !right.isEmpty else { return 0 }
  let gap = max(
    right.map(\.lower).min()! - left.map(\.upper).max()!,
    left.map(\.lower).min()! - right.map(\.upper).max()!)
  guard gap.isFinite else { return 0 }
  // Both subtraction and division need outward rounding as well as the projections.
  return max(0, (gap.nextDown / length.upper).nextDown)
}

private func sweepConditionedPointSegment(_ point: Vector3, _ a: Vector3, _ b: Vector3) -> Double {
  let edge = b - a
  let square = edge.dot(edge)
  let fraction = square > 0 ? max(0, min(1, (point - a).dot(edge) / square)) : 0
  return sweepSeparationLowerBound([point], [a, b], axis: point - a - edge * fraction)
}

private func sweepConditionedPointTriangle(_ point: Vector3, _ triangle: SweepTriangle) -> Double {
  let a = SweepIntervalVector(triangle.a)
  let normal = (SweepIntervalVector(triangle.b) - a).cross(SweepIntervalVector(triangle.c) - a)
  let length = normal.length
  guard length.finite, length.lower > 0 else { return 0 }
  let offset = SweepIntervalVector(point) - a
  let signedDistance = offset.dot(normal)
  let plane = (signedDistance / length).magnitude
  guard plane.finite else { return 0 }
  let projected = offset - normal * (signedDistance / normal.dot(normal))
  var definitelyOutside = false
  for index in 0..<3 {
    let edge = triangle.edge(at: index)
    let start = SweepIntervalVector(edge.0) - a
    let direction = SweepIntervalVector(edge.1) - SweepIntervalVector(edge.0)
    if direction.cross(projected - start).dot(normal).upper < 0 {
      definitelyOutside = true
    }
  }
  // When the projection classification is uncertain, the infinite plane is a safe lower
  // bound. It may refuse a close sweep; it never reports a missing thin surface as clear.
  guard definitelyOutside else { return max(0, plane.lower) }
  return (0..<3).map {
    let edge = triangle.edge(at: $0)
    return sweepConditionedPointSegment(point, edge.0, edge.1)
  }.min() ?? 0
}

private func sweepConditionedRay(
  _ origin: Vector3, direction: Vector3, triangle: SweepTriangle, maximumDistance: Double?
) -> (distance: Double, boundary: Bool, uncertainty: Double)? {
  guard
    sweepRayMayReachBounds(
      origin, direction: direction, bounds: triangle.bounds, maximumDistance: maximumDistance)
  else { return nil }
  let a = SweepIntervalVector(triangle.a)
  let edge = SweepIntervalVector(triangle.b) - a
  let other = SweepIntervalVector(triangle.c) - a
  let ray = SweepIntervalVector(direction)
  let cross = ray.cross(other)
  let determinant = edge.dot(cross)
  guard determinant.finite, determinant.lower > 0 || determinant.upper < 0 else {
    return (0, true, .infinity)
  }
  let offset = SweepIntervalVector(origin) - a
  let u = offset.dot(cross) / determinant
  let perpendicular = offset.cross(edge)
  let v = ray.dot(perpendicular) / determinant
  let distance = other.dot(perpendicular) / determinant
  guard u.finite, v.finite, distance.finite else { return (0, true, .infinity) }
  let sum = u + v
  if u.upper < 0 || v.upper < 0 || sum.lower > 1 || distance.upper < 0 { return nil }
  let boundary =
    u.lower < 1e-10 || v.lower < 1e-10 || sum.upper > 1 - 1e-10 || distance.lower < 0
    || distance.upper - distance.lower > 1e-10 * max(1, abs(distance.lower))
  return (max(0, distance.lower), boundary, (distance.upper - distance.lower).nextUp)
}

private func sweepRayMayReachBounds(
  _ origin: Vector3, direction: Vector3, bounds: SweepBounds, maximumDistance: Double?
) -> Bool {
  var entry = 0.0
  var exit = maximumDistance ?? .infinity
  let axes = [
    (origin.x, direction.x, bounds.lower.x, bounds.upper.x),
    (origin.y, direction.y, bounds.lower.y, bounds.upper.y),
    (origin.z, direction.z, bounds.lower.z, bounds.upper.z),
  ]
  for (point, rate, lower, upper) in axes {
    if rate == 0 {
      if point < lower || point > upper { return false }
      continue
    }
    let first = (SweepInterval(lower) - SweepInterval(point)) / SweepInterval(rate)
    let second = (SweepInterval(upper) - SweepInterval(point)) / SweepInterval(rate)
    // Outward endpoint bounds can only enlarge the candidate interval.
    entry = max(entry, min(first.lower, second.lower))
    exit = min(exit, max(first.upper, second.upper))
    if entry > exit { return false }
  }
  return true
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
  let conditioned: Bool
}

private func sweepComponents(
  vertices: [Vector3], faces: [[Int]], triangles: [[Int]], geometry: [SweepTriangle]
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
    let componentTriangles = members.flatMap { triangles[$0] }
    // Thin connecting faces can make broad opposing plates part of a newly supported
    // solid. Parity must condition the whole component even when the ray misses its bridge.
    let conditioned = componentTriangles.contains { geometry[$0].conditioned }
    return .init(
      bounds: bounds, triangles: componentTriangles, closed: closed,
      representative: points[0], conditioned: conditioned)
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
  // An original triangle needs no polygon projection or ear removal. In particular,
  // absolute shoelace cutoffs would discard resolved small/translated source surfaces.
  // PreparedHull applies the same certified area gate to every returned triangle.
  if vertices.count == 3 {
    return [.init(a: vertices[0], b: vertices[1], c: vertices[2])]
  }
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
private func sweepPointTriangle(
  _ point: Vector3, _ triangle: SweepTriangle, conditioned: Bool = false
) -> Double {
  if conditioned || triangle.conditioned { return sweepConditionedPointTriangle(point, triangle) }
  let normal = (triangle.b - triangle.a).cross(triangle.c - triangle.a)
  let square = normal.dot(normal)
  let projected = point - normal * ((point - triangle.a).dot(normal) / square)
  var inside = true
  for index in 0..<3 {
    let edge = triangle.edge(at: index)
    if !((edge.1 - edge.0).cross(projected - edge.0).dot(normal) >= 0) {
      inside = false
      break
    }
  }
  if inside { return abs((point - triangle.a).dot(normal)) / sqrt(square) }
  var distance = sweepPointSegment(point, triangle.a, triangle.b)
  for index in 1..<3 {
    let edge = triangle.edge(at: index)
    let candidate = sweepPointSegment(point, edge.0, edge.1)
    if candidate < distance { distance = candidate }
  }
  return distance
}
private func sweepRay(
  _ origin: Vector3, direction: Vector3, triangle: SweepTriangle, conditioned: Bool = false,
  maximumDistance: Double? = nil
) -> (distance: Double, boundary: Bool, uncertainty: Double)? {
  if conditioned || triangle.conditioned {
    return sweepConditionedRay(
      origin, direction: direction, triangle: triangle, maximumDistance: maximumDistance)
  }
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
  return (distance, min(u, min(v, 1 - u - v)) < 1e-10, 0)
}
private func sweepSegmentAxis(_ a: (Vector3, Vector3), _ b: (Vector3, Vector3)) -> Vector3 {
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
  return r + d * s - e * t
}
private func sweepSegmentDistance(
  _ a: (Vector3, Vector3), _ b: (Vector3, Vector3), conditioned: Bool
) -> Double {
  let closestAxis = sweepSegmentAxis(a, b)
  guard conditioned else { return closestAxis.length }
  // Even when the nearly parallel closest-line calculation is ill-conditioned, every
  // axis below proves only a projection gap. An inaccurate axis can only lower the bound.
  let axes = [closestAxis, a.0 - b.0, a.0 - b.1, a.1 - b.0, a.1 - b.1]
  return axes.map { sweepSeparationLowerBound([a.0, a.1], [b.0, b.1], axis: $0) }.max() ?? 0
}
private func sweepTriangleDistance(_ a: SweepTriangle, _ b: SweepTriangle) -> Double {
  let conditioned = a.conditioned || b.conditioned
  for index in 0..<3 {
    let (start, end) = a.edge(at: index)
    if let hit = sweepRay(
      start, direction: end - start, triangle: b, conditioned: conditioned, maximumDistance: 1),
      hit.distance <= 1
    {
      return 0
    }
  }
  for index in 0..<3 {
    let (start, end) = b.edge(at: index)
    if let hit = sweepRay(
      start, direction: end - start, triangle: a, conditioned: conditioned, maximumDistance: 1),
      hit.distance <= 1
    {
      return 0
    }
  }
  var distance = min(sweepVertexDistance(a, to: b), sweepVertexDistance(b, to: a))
  for firstIndex in 0..<3 {
    let first = a.edge(at: firstIndex)
    for secondIndex in 0..<3 {
      distance = min(
        distance, sweepSegmentDistance(first, b.edge(at: secondIndex), conditioned: conditioned))
    }
  }
  return distance
}

private func sweepVertexDistance(_ source: SweepTriangle, to target: SweepTriangle) -> Double {
  let conditioned = source.conditioned || target.conditioned
  var distance = sweepPointTriangle(source.a, target, conditioned: conditioned)
  for index in 1..<3 {
    let candidate = sweepPointTriangle(source.vertex(at: index), target, conditioned: conditioned)
    if candidate < distance { distance = candidate }
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
