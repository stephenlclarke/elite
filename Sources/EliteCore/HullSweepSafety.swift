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
  fileprivate let hasUnresolvedSupport: Bool
  fileprivate let nativeGeometryID = UUID()

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
    // Retain every original finite three-vertex convex support. A standalone
    // collection with no certified surface is still invalid, not a manufactured solid.
    guard triangles.contains(where: \.hasResolvedArea)
    else { throw HullSweepFailure.invalidGeometry }
    self.triangles = triangles
    hasUnresolvedSupport = triangles.contains(where: \.unresolvedSupport)
    triangleCount = triangles.count
    radius = vertices.map(\.length).max() ?? 0
    guard radius.isFinite, radius > 0 else { throw HullSweepFailure.invalidGeometry }
    components = sweepComponents(
      vertices: vertices, faces: faces, triangles: faceTriangles, geometry: triangles)
    isClosed = components.allSatisfy { $0.closed && $0.hasResolvedSurface }
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
      if hull.hasUnresolvedSupport {
        if node.bounds.certifiedLowerSquared(to: point) >= SweepInterval(best).square.upper {
          continue
        }
      } else if node.bounds.distanceSquared(to: point) >= best * best {
        continue
      }
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
    return try surfaceMeshDistance(
      player, pose: ship, obstacle: obstacle, pose: target, work: &work)
  }

  /// Native continuous queries have already proved a clear starting configuration.
  /// All original triangles remain barriers; this never manufactures an open component's volume.
  private static func surfaceMeshDistance(
    _ player: PreparedHull, pose ship: ShipPose, obstacle: PreparedHull, pose target: ShipPose,
    work: inout SweepWork
  ) throws -> Double {
    if player.nodes[0].children != nil {
      return try dualMeshDistance(player, pose: ship, obstacle: obstacle, pose: target, work: &work)
    }
    var best = Double.infinity
    for original in player.triangles {
      let triangle = SweepTriangle(
        a: target.shipPoint(ship.systemPoint(original.a)),
        b: target.shipPoint(ship.systemPoint(original.b)),
        c: target.shipPoint(ship.systemPoint(original.c)), conditioned: original.conditioned,
        unresolvedSupport: original.unresolvedSupport, transformedFrom: original)
      best = try triangleDistance(triangle, hull: obstacle, startingBest: best, work: &work)
      if best < 1e-9 { return 0 }
    }
    return best
  }

  /// Large-player path: every popped pair pays for both node examinations. Bounds and
  /// transformed primitives are cached only within this charged distance query.
  private static func dualMeshDistance(
    _ player: PreparedHull, pose ship: ShipPose, obstacle: PreparedHull, pose target: ShipPose,
    work: inout SweepWork
  ) throws -> Double {
    var best = Double.infinity
    var pending = [(0, 0)]
    var boundsCache: [Int: SweepBounds] = [:]
    var triangleCache: [Int: SweepTriangle] = [:]
    while let (playerIndex, targetIndex) = pending.popLast() {
      try work.node()
      try work.node()
      let left = player.nodes[playerIndex]
      let right = obstacle.nodes[targetIndex]
      let bounds: SweepBounds
      if let cached = boundsCache[playerIndex] {
        bounds = cached
      } else {
        bounds = sweepTransformedBounds(left.bounds, pose: ship, target: target)
        boundsCache[playerIndex] = bounds
      }
      if best.isFinite, bounds.finite, right.bounds.finite {
        let lower = bounds.certifiedLowerSquared(to: right.bounds)
        let upper = SweepInterval(best).square.upper
        // Infinity/unknown is never a pruning certificate, including infinity >= infinity.
        if lower.isFinite, upper.isFinite, lower >= upper { continue }
      }
      if left.children == nil, right.children == nil {
        for first in left.triangles {
          var rowTriangle: SweepTriangle?
          var rowBounds: SweepBounds?
          for (offset, second) in right.triangles.enumerated() {
            try work.triangle()
            let triangle: SweepTriangle
            if let cached = rowTriangle {
              triangle = cached
            } else if let cached = triangleCache[first] {
              triangle = cached
              rowTriangle = cached
            } else {
              let original = player.triangles[first]
              let a = target.shipPoint(ship.systemPoint(original.a))
              let b = target.shipPoint(ship.systemPoint(original.b))
              let c = target.shipPoint(ship.systemPoint(original.c))
              guard sweepFinite(a), sweepFinite(b), sweepFinite(c) else {
                throw HullSweepFailure.unproven
              }
              triangle = SweepTriangle(
                a: a, b: b, c: c, conditioned: original.conditioned,
                unresolvedSupport: original.unresolvedSupport, transformedFrom: original)
              triangleCache[first] = triangle
              rowTriangle = triangle
            }
            if offset == 0, best.isFinite {
              // The first paid pair covers this one bounded row/leaf certificate.
              // The ordinary gap only decides whether to attempt an outward proof.
              let bounds: SweepBounds
              if let cached = rowBounds {
                bounds = cached
              } else {
                bounds = triangle.bounds
                rowBounds = bounds
              }
              let upper = SweepInterval(best).square.upper
              if bounds.finite, right.bounds.finite, upper.isFinite,
                bounds.distanceSquared(to: right.bounds) > upper
              {
                let lower = bounds.certifiedLowerSquared(to: right.bounds)
                if lower.isFinite, lower >= upper { break }
              }
            }
            let candidate = obstacle.triangles[second]
            if best.isFinite, triangle.hasResolvedArea, candidate.hasResolvedArea,
              !triangle.conditioned, !candidate.conditioned,
              !triangle.unresolvedSupport, !candidate.unresolvedSupport
            {
              // This pair is already paid. Only an outward certificate can replace
              // its feature kernel; uncertain and conditioned pairs keep that kernel.
              let pairBounds: SweepBounds
              if let cached = rowBounds {
                pairBounds = cached
              } else {
                pairBounds = triangle.bounds
                rowBounds = pairBounds
              }
              let candidateBounds = candidate.bounds
              let upper = SweepInterval(best).square.upper
              if pairBounds.finite, candidateBounds.finite, upper.isFinite,
                pairBounds.distanceSquared(to: candidateBounds) > upper
              {
                let lower = pairBounds.certifiedLowerSquared(to: candidateBounds)
                if lower.isFinite, lower >= upper { continue }
              }
            }
            best = min(best, sweepTriangleDistance(triangle, candidate))
            if best < 1e-9 { return 0 }
          }
        }
      } else if let (a, b) = left.children,
        right.children == nil
          || (left.bounds.upper - left.bounds.lower).length
            >= (right.bounds.upper - right.bounds.lower).length
      {
        // Approximate center gaps choose visitation only; certificates above alone prune.
        let first = right.bounds.distanceSquared(
          to: target.shipPoint(ship.systemPoint(player.nodes[a].bounds.center)))
        let second = right.bounds.distanceSquared(
          to: target.shipPoint(ship.systemPoint(player.nodes[b].bounds.center)))
        pending +=
          second < first
          ? [(a, targetIndex), (b, targetIndex)]
          : [(b, targetIndex), (a, targetIndex)]
      } else if let (a, b) = right.children {
        let center = target.shipPoint(ship.systemPoint(left.bounds.center))
        let first = obstacle.nodes[a].bounds.distanceSquared(to: center)
        let second = obstacle.nodes[b].bounds.distanceSquared(to: center)
        pending +=
          second < first
          ? [(playerIndex, a), (playerIndex, b)]
          : [(playerIndex, b), (playerIndex, a)]
      }
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
      if hull.hasUnresolvedSupport || triangle.unresolvedSupport {
        if node.bounds.certifiedLowerSquared(to: bounds) >= SweepInterval(best).square.upper {
          continue
        }
      } else if node.bounds.distanceSquared(to: bounds) >= best * best {
        continue
      }
      if let (left, right) = node.children {
        // Approximate box gaps order work only; certified pruning above is unchanged.
        let lhs = hull.nodes[left].bounds.distanceSquared(to: bounds)
        let rhs = hull.nodes[right].bounds.distanceSquared(to: bounds)
        pending += rhs < lhs ? [left, right] : [right, left]
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
      guard component.closed, component.hasResolvedSurface else { throw HullSweepFailure.unproven }
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
  static let whole = Self(
    lower: .init(-.infinity, -.infinity, -.infinity),
    upper: .init(.infinity, .infinity, .infinity))
  var finite: Bool { sweepFinite(lower) && sweepFinite(upper) }
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

  func certifiedLowerSquared(to point: Vector3) -> Double {
    certifiedLowerSquared(to: .init(lower: point, upper: point))
  }

  func certifiedLowerSquared(to other: Self) -> Double {
    let x = max(
      0,
      max(
        (SweepInterval(lower.x) - SweepInterval(other.upper.x)).lower,
        (SweepInterval(other.lower.x) - SweepInterval(upper.x)).lower))
    let y = max(
      0,
      max(
        (SweepInterval(lower.y) - SweepInterval(other.upper.y)).lower,
        (SweepInterval(other.lower.y) - SweepInterval(upper.y)).lower))
    let z = max(
      0,
      max(
        (SweepInterval(lower.z) - SweepInterval(other.upper.z)).lower,
        (SweepInterval(other.lower.z) - SweepInterval(upper.z)).lower))
    return max(
      0, (SweepInterval(x).square + SweepInterval(y).square + SweepInterval(z).square).lower)
  }
}

/// Enclose the actual two-stage pose operations, including each rounded intermediate.
/// Do not compose an ideal affine transform: represented vertices may collapse or overflow.
private func sweepTransformedBounds(
  _ bounds: SweepBounds, pose ship: ShipPose, target: ShipPose
) -> SweepBounds {
  let local = SweepIntervalVector(
    x: .init(lower: bounds.lower.x, upper: bounds.upper.x),
    y: .init(lower: bounds.lower.y, upper: bounds.upper.y),
    z: .init(lower: bounds.lower.z, upper: bounds.upper.z))
  // Basis3.apply is (x*v.x + y*v.y) + z*v.z, then ShipPose adds position.
  let world =
    SweepIntervalVector(ship.position)
    + (SweepIntervalVector(ship.orientation.x) * local.x
      + SweepIntervalVector(ship.orientation.y) * local.y
      + SweepIntervalVector(ship.orientation.z) * local.z)
  let relative = world - SweepIntervalVector(target.position)
  // shipVector uses left-associated coordinate products/sums in each dot product.
  let x = relative.dot(SweepIntervalVector(target.orientation.x))
  let y = relative.dot(SweepIntervalVector(target.orientation.y))
  let z = relative.dot(SweepIntervalVector(target.orientation.z))
  guard x.finite, y.finite, z.finite else { return .whole }
  return .init(
    lower: .init(x.lower, y.lower, z.lower), upper: .init(x.upper, y.upper, z.upper))
}

/// The scalar normal chooses a component only. Outward interval arithmetic encloses its
/// exact determinant on the represented vertices; excluding zero certifies nonzero area.
/// Cancellation, underflow, overflow or collapse cannot pass an uncertain certificate.
private func sweepSelectedNormalResolved(
  _ a: Vector3, _ b: Vector3, _ c: Vector3, approximateNormal: Vector3
) -> Bool {
  let first: (Double, Double, Double)
  let second: (Double, Double, Double)
  switch sweepAxis(
    .init(abs(approximateNormal.x), abs(approximateNormal.y), abs(approximateNormal.z)))
  {
  case 0:
    first = (a.y, b.y, c.y)
    second = (a.z, b.z, c.z)
  case 1:
    first = (a.z, b.z, c.z)
    second = (a.x, b.x, c.x)
  default:
    first = (a.x, b.x, c.x)
    second = (a.y, b.y, c.y)
  }
  let determinant =
    (SweepInterval(first.1) - SweepInterval(first.0))
    * (SweepInterval(second.2) - SweepInterval(second.0))
    - (SweepInterval(second.1) - SweepInterval(second.0))
    * (SweepInterval(first.2) - SweepInterval(first.0))
  return determinant.finite && (determinant.lower > 0 || determinant.upper < 0)
}

private struct SweepTriangle: Sendable {
  let a: Vector3
  let b: Vector3
  let c: Vector3
  // Arithmetic reuse for the existing fast query, never an area or separation certificate.
  let fastNormal: Vector3
  let fastNormalSquared: Double
  let fastNormalLength: Double
  let fastRayDeterminantScale: Double
  let conditioned: Bool
  let hasResolvedArea: Bool
  let unresolvedSupport: Bool

  init(
    a: Vector3, b: Vector3, c: Vector3, conditioned: Bool = false, unresolvedSupport: Bool = false,
    transformedFrom original: SweepTriangle? = nil
  ) {
    self.a = a
    self.b = b
    self.c = c
    let first = b - a
    let second = c - a
    let firstLength = first.length
    let secondLength = second.length
    let scale = max(firstLength, max(secondLength, (c - b).length))
    // These are only the boundaries of the pre-existing fast query path, never
    // acceptance. Newly resolved small triangles need conservative queries as well.
    let approximateNormal = first.cross(second)
    fastNormal = approximateNormal
    fastNormalSquared = approximateNormal.dot(approximateNormal)
    let area = approximateNormal.length
    fastNormalLength = area
    fastRayDeterminantScale = 1e-12 * firstLength * secondLength
    let resolved: Bool
    if let original, original.hasResolvedArea, !original.conditioned,
      !original.unresolvedSupport, sweepFinite(a), sweepFinite(b), sweepFinite(c),
      scale.isFinite, area.isFinite, area > scale * scale * 1e-6, area > 1e-9,
      sweepSelectedNormalResolved(a, b, c, approximateNormal: approximateNormal)
    {
      // Reuse prepared resolution only after certifying the represented transformed vertices.
      // One outward determinant avoids constructing a full interval normal and square root.
      resolved = true
    } else {
      let normal = (SweepIntervalVector(b) - SweepIntervalVector(a)).cross(
        SweepIntervalVector(c) - SweepIntervalVector(a))
      let certificate = normal.length
      resolved = certificate.finite && certificate.lower > 0
    }
    let supportOnly = unresolvedSupport || !resolved
    hasResolvedArea = resolved
    self.unresolvedSupport = supportOnly
    self.conditioned =
      conditioned || supportOnly || area <= scale * scale * 1e-6 || area <= 1e-9
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

  static func + (a: Self, b: Self) -> Self {
    .init(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z)
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
  guard let origin = a.first else { return 0 }
  return sweepEnclosedSeparationLowerBound(
    a.map { SweepIntervalVector($0) }, b.map { SweepIntervalVector($0) }, origin: origin, axis: axis
  )
}

private func sweepEnclosedSeparationLowerBound(
  _ a: [SweepIntervalVector], _ b: [SweepIntervalVector], origin: Vector3, axis: Vector3
) -> Double {
  guard sweepFinite(axis), axis.length > 0 else { return 0 }
  let direction = SweepIntervalVector(axis)
  let length = direction.length
  guard length.finite, length.lower > 0 else { return 0 }
  let base = SweepIntervalVector(origin)
  let left = a.map { ($0 - base).dot(direction) }
  let right = b.map { ($0 - base).dot(direction) }
  guard !left.isEmpty, !right.isEmpty, (left + right).allSatisfy(\.finite) else { return 0 }
  let gap = max(
    right.map(\.lower).min()! - left.map(\.upper).max()!,
    left.map(\.lower).min()! - right.map(\.upper).max()!)
  guard gap.isFinite else { return 0 }
  // Both subtraction and division need outward rounding as well as the projections.
  return max(0, (gap.nextDown / length.upper).nextDown)
}

private func sweepConditionedPointSegment(_ point: Vector3, _ a: Vector3, _ b: Vector3) -> Double {
  sweepSeparationLowerBound([point], [a, b], axis: sweepPointSegmentAxis(point, a, b))
}

private func sweepPointSegmentAxis(_ point: Vector3, _ a: Vector3, _ b: Vector3) -> Vector3 {
  let edge = b - a
  let square = edge.dot(edge)
  let fraction = square > 0 ? max(0, min(1, (point - a).dot(edge) / square)) : 0
  return point - a - edge * fraction
}

private let sweepSupportAxes = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]

/// Convex support of the original three vertices retains the filled interior even when
/// its area cannot be resolved. No normal division or edge-only approximation grants safety.
private func sweepSupportPointDistance(_ point: Vector3, _ triangle: SweepTriangle) -> Double {
  let vertices = [triangle.a, triangle.b, triangle.c]
  var axes = sweepSupportAxes
  axes.append((triangle.b - triangle.a).cross(triangle.c - triangle.a))
  for index in 0..<3 {
    axes.append(point - triangle.vertex(at: index))
    let edge = triangle.edge(at: index)
    axes.append(sweepPointSegmentAxis(point, edge.0, edge.1))
  }
  // Ten axes, each projecting at most four original points: bounded work per charged query.
  return axes.map { sweepSeparationLowerBound([point], vertices, axis: $0) }.max() ?? 0
}

private func sweepSupportTriangleDistance(_ a: SweepTriangle, _ b: SweepTriangle) -> Double {
  let left = [a.a, a.b, a.c]
  let right = [b.a, b.b, b.c]
  var axes = sweepSupportAxes
  axes += [(a.b - a.a).cross(a.c - a.a), (b.b - b.a).cross(b.c - b.a)]
  for first in 0..<3 {
    let edgeA = a.edge(at: first)
    for second in 0..<3 {
      let edgeB = b.edge(at: second)
      axes.append(a.vertex(at: first) - b.vertex(at: second))
      axes.append((edgeA.1 - edgeA.0).cross(edgeB.1 - edgeB.0))
      axes.append(sweepSegmentAxis(edgeA, edgeB))
    }
  }
  // Every one of these 32 arbitrary axes certifies separation of the complete supports.
  // In particular intersecting triangles cannot look clear just because their edges are far.
  return axes.map { sweepSeparationLowerBound(left, right, axis: $0) }.max() ?? 0
}

private func sweepConditionedPointTriangle(_ point: Vector3, _ triangle: SweepTriangle) -> Double {
  if triangle.unresolvedSupport { return sweepSupportPointDistance(point, triangle) }
  let a = SweepIntervalVector(triangle.a)
  let normal = (SweepIntervalVector(triangle.b) - a).cross(SweepIntervalVector(triangle.c) - a)
  let length = normal.length
  guard length.finite, length.lower > 0 else { return sweepSupportPointDistance(point, triangle) }
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
    let candidate = sweepRayBoundsInterval(
      origin, direction: direction, bounds: triangle.bounds, maximumDistance: maximumDistance)
  else { return nil }
  if triangle.unresolvedSupport,
    sweepRayMissesSupport(origin, direction: direction, triangle: triangle, candidate: candidate)
  {
    return nil
  }
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

private func sweepRayBoundsInterval(
  _ origin: Vector3, direction: Vector3, bounds: SweepBounds, maximumDistance: Double?
) -> SweepInterval? {
  var entry = 0.0
  var exit = maximumDistance ?? .infinity
  let axes = [
    (origin.x, direction.x, bounds.lower.x, bounds.upper.x),
    (origin.y, direction.y, bounds.lower.y, bounds.upper.y),
    (origin.z, direction.z, bounds.lower.z, bounds.upper.z),
  ]
  for (point, rate, lower, upper) in axes {
    if rate == 0 {
      if point < lower || point > upper { return nil }
      continue
    }
    let first = (SweepInterval(lower) - SweepInterval(point)) / SweepInterval(rate)
    let second = (SweepInterval(upper) - SweepInterval(point)) / SweepInterval(rate)
    // Outward endpoint bounds can only enlarge the candidate interval.
    entry = max(entry, min(first.lower, second.lower))
    exit = min(exit, max(first.upper, second.upper))
    if entry > exit { return nil }
  }
  return .init(lower: entry, upper: exit)
}

private func sweepRayMissesSupport(
  _ origin: Vector3, direction: Vector3, triangle: SweepTriangle, candidate: SweepInterval
) -> Bool {
  guard candidate.finite else { return false }
  let start = origin + direction * candidate.lower
  let end = origin + direction * candidate.upper
  guard sweepFinite(start), sweepFinite(end) else { return false }
  let left = [
    SweepIntervalVector(origin) + SweepIntervalVector(direction) * SweepInterval(candidate.lower),
    SweepIntervalVector(origin) + SweepIntervalVector(direction) * SweepInterval(candidate.upper),
  ]
  let right = [triangle.a, triangle.b, triangle.c].map { SweepIntervalVector($0) }
  var axes = sweepSupportAxes
  for index in 0..<3 {
    let edge = triangle.edge(at: index)
    axes.append(sweepSegmentAxis((start, end), edge))
    axes.append(direction.cross(edge.1 - edge.0))
    axes.append(start - triangle.vertex(at: index))
    axes.append(end - triangle.vertex(at: index))
  }
  // The outward slab interval contains every possible ray/primitive intersection.
  // A positive support gap for this enclosed segment proves a miss; otherwise it is unknown.
  return axes.contains {
    sweepEnclosedSeparationLowerBound(left, right, origin: origin, axis: $0) > 0
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
  let conditioned: Bool
  let hasResolvedSurface: Bool
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
    let hasResolvedSurface = componentTriangles.contains { geometry[$0].hasResolvedArea }
    return .init(
      bounds: bounds, triangles: componentTriangles, closed: closed,
      representative: points[0], conditioned: conditioned, hasResolvedSurface: hasResolvedSurface)
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
  let normal = triangle.fastNormal
  let square = triangle.fastNormalSquared
  let normalOffset = (point - triangle.a).dot(normal)
  let projected = point - normal * (normalOffset / square)
  var inside = true
  for index in 0..<3 {
    let edge = triangle.edge(at: index)
    if !((edge.1 - edge.0).cross(projected - edge.0).dot(normal) >= 0) {
      inside = false
      break
    }
  }
  if inside { return abs(normalOffset) / triangle.fastNormalLength }
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
  guard abs(determinant) > triangle.fastRayDeterminantScale * direction.length else { return nil }
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
  if a.unresolvedSupport || b.unresolvedSupport { return sweepSupportTriangleDistance(a, b) }
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

private func sweepVertexPointSegment(
  _ point: Vector3, _ a: Vector3, edge: Vector3, square: Double
) -> Double {
  let fraction = square > 0 ? max(0, min(1, (point - a).dot(edge) / square)) : 0
  return (point - a - edge * fraction).length
}

private func sweepVertexFastPointTriangle(
  _ point: Vector3, _ triangle: SweepTriangle,
  edges: (Vector3, Vector3, Vector3), squares: (Double, Double, Double)
) -> Double {
  let normal = triangle.fastNormal
  let square = triangle.fastNormalSquared
  let normalOffset = (point - triangle.a).dot(normal)
  let projected = point - normal * (normalOffset / square)
  var inside = true
  if !(edges.0.cross(projected - triangle.a).dot(normal) >= 0) {
    inside = false
  } else if !(edges.1.cross(projected - triangle.b).dot(normal) >= 0) {
    inside = false
  } else if !(edges.2.cross(projected - triangle.c).dot(normal) >= 0) {
    inside = false
  }
  if inside { return abs(normalOffset) / triangle.fastNormalLength }
  var distance = sweepVertexPointSegment(point, triangle.a, edge: edges.0, square: squares.0)
  let second = sweepVertexPointSegment(point, triangle.b, edge: edges.1, square: squares.1)
  if second < distance { distance = second }
  let third = sweepVertexPointSegment(point, triangle.c, edge: edges.2, square: squares.2)
  if third < distance { distance = third }
  return distance
}

private func sweepVertexConditionedPointTriangle(
  _ point: Vector3, _ triangle: SweepTriangle,
  a: SweepIntervalVector, normal: SweepIntervalVector, length: SweepInterval,
  normalSquare: SweepInterval,
  starts: (SweepIntervalVector, SweepIntervalVector, SweepIntervalVector),
  directions: (SweepIntervalVector, SweepIntervalVector, SweepIntervalVector)
) -> Double {
  if triangle.unresolvedSupport { return sweepSupportPointDistance(point, triangle) }
  guard length.finite, length.lower > 0 else { return sweepSupportPointDistance(point, triangle) }
  let offset = SweepIntervalVector(point) - a
  let signedDistance = offset.dot(normal)
  let plane = (signedDistance / length).magnitude
  guard plane.finite else { return 0 }
  let projected = offset - normal * (signedDistance / normalSquare)
  var definitelyOutside = false
  if directions.0.cross(projected - starts.0).dot(normal).upper < 0 {
    definitelyOutside = true
  }
  if directions.1.cross(projected - starts.1).dot(normal).upper < 0 {
    definitelyOutside = true
  }
  if directions.2.cross(projected - starts.2).dot(normal).upper < 0 {
    definitelyOutside = true
  }
  guard definitelyOutside else { return max(0, plane.lower) }
  return (0..<3).map {
    let edge = triangle.edge(at: $0)
    return sweepConditionedPointSegment(point, edge.0, edge.1)
  }.min() ?? 0
}

private func sweepVertexDistance(_ source: SweepTriangle, to target: SweepTriangle) -> Double {
  let conditioned = source.conditioned || target.conditioned
  if !conditioned {
    let edges = (target.b - target.a, target.c - target.b, target.a - target.c)
    let squares = (edges.0.dot(edges.0), edges.1.dot(edges.1), edges.2.dot(edges.2))
    var distance = sweepVertexFastPointTriangle(source.a, target, edges: edges, squares: squares)
    for index in 1..<3 {
      let candidate = sweepVertexFastPointTriangle(
        source.vertex(at: index), target, edges: edges, squares: squares)
      if candidate < distance { distance = candidate }
    }
    return distance
  }
  // Unresolved support keeps the original fallback before preparing or dividing a normal.
  if !target.unresolvedSupport {
    let a = SweepIntervalVector(target.a)
    let normal = (SweepIntervalVector(target.b) - a).cross(SweepIntervalVector(target.c) - a)
    let length = normal.length
    if length.finite, length.lower > 0 {
      let normalSquare = normal.dot(normal)
      let starts = (
        SweepIntervalVector(target.a) - a,
        SweepIntervalVector(target.b) - a,
        SweepIntervalVector(target.c) - a
      )
      let directions = (
        SweepIntervalVector(target.b) - SweepIntervalVector(target.a),
        SweepIntervalVector(target.c) - SweepIntervalVector(target.b),
        SweepIntervalVector(target.a) - SweepIntervalVector(target.c)
      )
      var distance = sweepVertexConditionedPointTriangle(
        source.a, target, a: a, normal: normal, length: length,
        normalSquare: normalSquare, starts: starts, directions: directions)
      for index in 1..<3 {
        let candidate = sweepVertexConditionedPointTriangle(
          source.vertex(at: index), target, a: a, normal: normal, length: length,
          normalSquare: normalSquare, starts: starts, directions: directions)
        if candidate < distance { distance = candidate }
      }
      return distance
    }
  }
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

/// A continuous proof covers every interval before this bracket. It contains a
/// certified native intersection, sampled directly or enclosed by a conditioned
/// material-vertex/face crossing. A sphere overlap is never a contact certificate.
/// A frontier is minted only after the initial volume check and chronological clear prefix.
/// It is immutable geometric evidence, not decoded authority; the one mutable bit is lock-owned.
private final class NativeContactFrontier: @unchecked Sendable {
  let sourceGeometry: UUID
  let targetGeometry: UUID
  let source: ShipPose
  let target: ShipPose
  private let lock = NSLock()
  private var consumed = false
  init(sourceHull: PreparedHull, targetHull: PreparedHull, source: ShipPose, target: ShipPose) {
    sourceGeometry = sourceHull.nativeGeometryID
    targetGeometry = targetHull.nativeGeometryID
    self.source = source
    self.target = target
  }
  func poses(sourceHull: PreparedHull, targetHull: PreparedHull) -> (
    source: ShipPose, target: ShipPose
  )? {
    lock.lock()
    defer { lock.unlock() }
    guard !consumed, sourceGeometry == sourceHull.nativeGeometryID,
      targetGeometry == targetHull.nativeGeometryID
    else { return nil }
    return (source, target)
  }
  func take(
    sourceMotion: HullSceneMotion, sourceHull: PreparedHull,
    targetMotion: HullSceneMotion, targetHull: PreparedHull
  ) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    guard !consumed, sourceGeometry == sourceHull.nativeGeometryID,
      targetGeometry == targetHull.nativeGeometryID,
      sourceMotion.start == source, targetMotion.start == target
    else { return false }
    consumed = true
    return true
  }
}
struct NativeHullContact: Sendable {
  let lowerTime: Double
  let upperTime: Double
  let point: Vector3
  let normal: Vector3
  fileprivate let frontier: NativeContactFrontier?
  fileprivate init(
    lowerTime: Double, upperTime: Double, point: Vector3, normal: Vector3,
    frontier: NativeContactFrontier? = nil
  ) {
    self.lowerTime = lowerTime
    self.upperTime = upperTime
    self.point = point
    self.normal = normal
    self.frontier = frontier
  }
}

enum NativeHullContactResult: Sendable {
  case clear
  case contact(NativeHullContact)
  case refused(HullSweepFailure)
}

extension HullSweepSafety {
  /// Both trajectories are the native step's rigid interpolation of actual endpoints.
  /// Thin crossings cannot be reported clear merely because a sample missed them:
  /// every clear interval needs the same continuous separation envelope as work motion.
  static func firstNativeContact(
    source: HullSceneMotion, hull: PreparedHull, target: HullSceneMotion,
    targetHull: PreparedHull, budget: HullSweepBudget = .standard
  ) -> NativeHullContactResult {
    nativeContactQuery(
      source: source, hull: hull, target: target, targetHull: targetHull,
      frontier: nil, budget: budget)
  }

  static func nativeFrontierPoses(
    _ contact: NativeHullContact, sourceHull: PreparedHull,
    targetHull: PreparedHull
  ) -> (source: ShipPose, target: ShipPose)? {
    contact.frontier?.poses(sourceHull: sourceHull, targetHull: targetHull)
  }

  /// Only the exact immutable pair/lower poses can spend this single-use native proof.
  static func continueNativeContact(
    _ contact: NativeHullContact, source: HullSceneMotion,
    hull: PreparedHull, target: HullSceneMotion, targetHull: PreparedHull,
    budget: HullSweepBudget = .standard
  ) -> NativeHullContactResult {
    guard let frontier = contact.frontier,
      frontier.take(
        sourceMotion: source, sourceHull: hull, targetMotion: target, targetHull: targetHull)
    else { return .refused(.invalidMotion) }
    return nativeContactQuery(
      source: source, hull: hull, target: target, targetHull: targetHull,
      frontier: frontier, budget: budget)
  }

  private static func nativeContactQuery(
    source: HullSceneMotion, hull: PreparedHull,
    target: HullSceneMotion, targetHull: PreparedHull, frontier: NativeContactFrontier?,
    budget: HullSweepBudget
  ) -> NativeHullContactResult {
    var work = SweepWork(budget: budget)
    do {
      try validateMotion(source, player: hull, budget: budget)
      try validateMotion(target, player: targetHull, budget: budget)
      guard source.duration == target.duration, source.requiredClearance == 0,
        target.requiredClearance == 0
      else { throw HullSweepFailure.invalidMotion }
      try work.query()
      let initial: Double
      if frontier != nil {
        initial = try surfaceMeshDistance(
          hull, pose: source.start, obstacle: targetHull,
          pose: target.start, work: &work)
      } else {
        initial = try meshDistance(
          hull, pose: source.start, obstacle: targetHull,
          pose: target.start, work: &work)
      }
      guard initial > 1e-9 else { throw HullSweepFailure.unproven }
      var start = 0.0
      if frontier != nil {
        // A contact inside the first bounded leaf still has a positive clear
        // prefix. Certify that prefix explicitly so each response advances the
        // geometric frontier instead of repeatedly returning a zero lower bound.
        let speed =
          (source.initialVelocity - target.initialVelocity).length
          + (source.acceleration - target.acceleration).length * source.duration
          + source.worldAngularVelocity.length * hull.radius
          + target.worldAngularVelocity.length * targetHull.radius
        if speed > 0 {
          let prefix = min(source.duration * 0.5, initial / (4 * speed))
          guard prefix.isFinite, prefix > 0 else { throw HullSweepFailure.unproven }
          guard
            case .clear = try contactInterval(
              source, hull: hull, target: target, targetHull: targetHull,
              start: 0, end: prefix, depth: 0, known: nil, work: &work)
          else { throw HullSweepFailure.unproven }
          start = prefix
        }
      }
      let result = try contactInterval(
        source, hull: hull, target: target, targetHull: targetHull,
        start: start, end: source.duration, depth: 0, known: nil, work: &work)
      guard case .contact(let contact) = result else { return result }
      let proof = NativeContactFrontier(
        sourceHull: hull, targetHull: targetHull,
        source: shipPose(source, at: contact.lowerTime),
        target: shipPose(target, at: contact.lowerTime))
      return .contact(
        .init(
          lowerTime: contact.lowerTime, upperTime: contact.upperTime,
          point: contact.point, normal: contact.normal, frontier: proof))
    } catch let failure as HullSweepFailure {
      return .refused(failure)
    } catch {
      return .refused(.unproven)
    }
  }

  private static func contactInterval(
    _ source: HullSceneMotion, hull: PreparedHull, target: HullSceneMotion,
    targetHull: PreparedHull, start: Double, end: Double, depth: Int,
    known: NativeHullContact?, work: inout SweepWork
  ) throws -> NativeHullContactResult {
    try work.query()
    if let known, known.upperTime > end,
      try contactPrefixClear(
        source, hull: hull, target: target, targetHull: targetHull,
        start: start, end: end, axis: known.normal, work: &work)
    {
      return .clear
    }
    let middle = (start + end) * 0.5
    let a = shipPose(source, at: middle)
    let b = shipPose(target, at: middle)
    let separation: Double
    do {
      separation = try surfaceMeshDistance(
        hull, pose: a, obstacle: targetHull, pose: b, work: &work)
    } catch HullSweepFailure.insideHull {
      // Containment is an overlap, but only the witness below authorizes an effect.
      separation = 0
    }
    let half = (end - start) * 0.5
    let relativeAcceleration = source.acceleration - target.acceleration
    let speed =
      (source.initialVelocity - target.initialVelocity
      + relativeAcceleration * middle).length
      + relativeAcceleration.length * half
      + source.worldAngularVelocity.length * hull.radius
      + target.worldAngularVelocity.length * targetHull.radius
    let envelope = (speed.nextUp * half).nextUp
    let numerical =
      64 * Double.ulpOfOne
      * max(1, hull.radius + targetHull.radius + a.position.length + b.position.length)
    guard separation.isFinite, envelope.isFinite else { throw HullSweepFailure.invalidMotion }
    if separation - envelope - numerical > 0 { return .clear }
    var witness = known
    if separation <= 1e-9,
      let found = try nativeContactWitness(
        hull, motion: source, target: targetHull, motion: target, time: middle, work: &work),
      witness == nil || middle < witness!.upperTime
    {
      witness = .init(lowerTime: start, upperTime: middle, point: found.0, normal: found.1)
    }
    // A bounded time bracket is allowed only when it contains a proved intersection.
    // Otherwise a tiny/thin/ill-conditioned crossing refuses movement; it is not a miss.
    if depth >= work.budget.subdivisionDepth {
      if try translatedTrianglesClear(
        source, hull: hull, target: target,
        targetHull: targetHull, start: start, end: end, work: &work)
      {
        guard witness == nil || witness!.upperTime > end else { throw HullSweepFailure.unproven }
        return .clear
      }
      if let axial = try axialVertexInterval(
        source, hull: hull, target: target, targetHull: targetHull,
        start: start, end: end, work: &work)
      {
        switch axial {
        case .clear:
          guard witness == nil || witness!.upperTime > end else {
            throw HullSweepFailure.unproven
          }
          return .clear
        case .contact(let entry):
          if witness == nil || entry.upperTime < witness!.upperTime { witness = entry }
        case .refused(let failure): throw failure
        }
      }
      if let entry = try translatedVertexEntry(
        source, hull: hull, target: target, targetHull: targetHull,
        start: start, end: end, work: &work),
        witness == nil || entry.upperTime < witness!.upperTime
      {
        witness = entry
      }
      if witness == nil || witness!.upperTime > end,
        let entry = try translatedEdgeEntry(
          source, hull: hull, target: target,
          targetHull: targetHull, start: start, end: end, work: &work)
      {
        witness = entry
      }
      if witness == nil || witness!.upperTime > end {
        try work.query()
        if let found = try nativeContactWitness(
          hull, motion: source, target: targetHull, motion: target, time: end, work: &work)
        {
          witness = .init(lowerTime: start, upperTime: end, point: found.0, normal: found.1)
        }
      }
      guard let witness, witness.upperTime >= start, witness.upperTime <= end else {
        throw HullSweepFailure.unproven
      }
      return .contact(
        .init(
          lowerTime: start, upperTime: witness.upperTime,
          point: witness.point, normal: witness.normal))
    }
    // A future witness is a separation-axis hint, never evidence of contact in
    // an earlier interval. Keep it while proving the chronological prefix clear.
    let left = try contactInterval(
      source, hull: hull, target: target, targetHull: targetHull,
      start: start, end: middle, depth: depth + 1, known: witness, work: &work)
    switch left {
    case .clear:
      let rightWitness = witness.flatMap { $0.upperTime > middle ? $0 : nil }
      return try contactInterval(
        source, hull: hull, target: target, targetHull: targetHull,
        start: middle, end: end, depth: depth + 1, known: rightWitness, work: &work)
    case .contact, .refused: return left
    }
  }

  /// Fixed orientations admit a direct interval certificate for every actual triangle pair.
  /// An axis is only a hint: outward projections, including coplanar in-plane axes, grant clearance.
  private static func translatedTrianglesClear(
    _ source: HullSceneMotion, hull: PreparedHull,
    target: HullSceneMotion, targetHull: PreparedHull, start: Double, end: Double,
    work: inout SweepWork
  ) throws -> Bool {
    guard source.worldAngularVelocity == .init(0, 0, 0),
      target.worldAngularVelocity == .init(0, 0, 0), source.acceleration == target.acceleration
    else { return false }
    try work.query()
    let time = SweepInterval(lower: start, upper: end)
    let relative =
      SweepIntervalVector(target.start.position) - SweepIntervalVector(source.start.position)
      + (SweepIntervalVector(target.initialVelocity) - SweepIntervalVector(source.initialVelocity))
      * time
    let middle = (start + end) * 0.5
    let numerical =
      64 * Double.ulpOfOne
      * max(
        1,
        hull.radius + targetHull.radius
          + shipPose(source, at: middle).position.length
          + shipPose(target, at: middle).position.length
          + (source.initialVelocity.length + target.initialVelocity.length) * (end - start)
          + (source.acceleration.length + target.acceleration.length) * (end - start)
          * (end - start))
    guard numerical.isFinite else { return false }
    func point(_ local: Vector3, orientation: Basis3) -> SweepIntervalVector {
      SweepIntervalVector(orientation.x) * SweepInterval(local.x)
        + SweepIntervalVector(orientation.y) * SweepInterval(local.y)
        + SweepIntervalVector(orientation.z) * SweepInterval(local.z)
    }
    func bounds(_ box: SweepBounds, orientation: Basis3, offset: SweepIntervalVector) -> SweepBounds
    {
      let local = SweepIntervalVector(
        x: .init(lower: box.lower.x, upper: box.upper.x),
        y: .init(lower: box.lower.y, upper: box.upper.y),
        z: .init(lower: box.lower.z, upper: box.upper.z))
      let world =
        SweepIntervalVector(orientation.x) * local.x
        + SweepIntervalVector(orientation.y) * local.y + SweepIntervalVector(orientation.z)
        * local.z + offset
      return .init(
        lower: .init(world.x.lower, world.y.lower, world.z.lower),
        upper: .init(world.x.upper, world.y.upper, world.z.upper))
    }
    let zero = SweepIntervalVector(.init(0, 0, 0))
    var pending = [(0, 0)]
    while let (leftIndex, rightIndex) = pending.popLast() {
      try work.node()
      try work.node()
      let left = hull.nodes[leftIndex]
      let right = targetHull.nodes[rightIndex]
      let aBounds = bounds(left.bounds, orientation: source.start.orientation, offset: zero)
      let bBounds = bounds(right.bounds, orientation: target.start.orientation, offset: relative)
      guard aBounds.finite, bBounds.finite else { return false }
      let lower = aBounds.certifiedLowerSquared(to: bBounds)
      let upper = SweepInterval(numerical).square.upper
      if lower.isFinite, upper.isFinite, lower > upper { continue }
      if let children = left.children {
        pending += [(children.0, rightIndex), (children.1, rightIndex)]
      } else if let children = right.children {
        pending += [(leftIndex, children.0), (leftIndex, children.1)]
      } else {
        for aIndex in left.triangles {
          let a = hull.triangles[aIndex]
          for bIndex in right.triangles {
            try work.triangle()
            let b = targetHull.triangles[bIndex]
            guard !a.unresolvedSupport, !b.unresolvedSupport else { return false }
            let av = (0..<3).map { point(a.vertex(at: $0), orientation: source.start.orientation) }
            let bv = (0..<3).map {
              point(b.vertex(at: $0), orientation: target.start.orientation) + relative
            }
            let ae = (0..<3).map {
              source.start.orientation.apply(a.edge(at: $0).1 - a.edge(at: $0).0)
            }
            let be = (0..<3).map {
              target.start.orientation.apply(b.edge(at: $0).1 - b.edge(at: $0).0)
            }
            let an = ae[0].cross(ae[1])
            let bn = be[0].cross(be[1])
            var axes = [an, bn]
            axes += ae.flatMap { first in be.map { first.cross($0) } }
            axes += ae.map { an.cross($0) } + be.map { bn.cross($0) }
            var separated = false
            for candidate in axes {
              let length = candidate.length
              guard candidate.finite, length.isFinite, length > 0 else { continue }
              let axis = SweepIntervalVector(candidate * (1 / length))
              let ap = av.map { $0.dot(axis) }
              let bp = bv.map { $0.dot(axis) }
              let aLow = ap.map(\.lower).min() ?? -.infinity
              let aHigh = ap.map(\.upper).max() ?? .infinity
              let bLow = bp.map(\.lower).min() ?? -.infinity
              let bHigh = bp.map(\.upper).max() ?? .infinity
              let gap = max(
                (SweepInterval(bLow) - SweepInterval(aHigh)).lower,
                (SweepInterval(aLow) - SweepInterval(bHigh)).lower)
              if gap.isFinite, gap > numerical {
                separated = true
                break
              }
            }
            guard separated else { return false }
          }
        }
      }
    }
    return true
  }

  /// Projects every native vertex onto an actual contact axis. The translational
  /// envelope and angular displacement bound cover the entire interval; a future
  /// witness supplies only the axis and cannot authorize an earlier collision.
  private static func contactPrefixClear(
    _ source: HullSceneMotion, hull: PreparedHull, target: HullSceneMotion,
    targetHull: PreparedHull, start: Double, end: Double, axis: Vector3,
    work: inout SweepWork
  ) throws -> Bool {
    let middle = (start + end) * 0.5
    let half = (end - start) * 0.5
    let a = shipPose(source, at: middle)
    let b = shipPose(target, at: middle)
    func points(_ hull: PreparedHull, pose: ShipPose) throws -> [SweepIntervalVector] {
      var result: [SweepIntervalVector] = []
      for triangle in hull.triangles {
        try work.triangle()
        for index in 0..<3 {
          result.append(contactWorldPoint(triangle.vertex(at: index), pose: pose))
        }
      }
      return result
    }
    let left = try points(hull, pose: a)
    let right = try points(targetHull, pose: b)
    let gap = sweepEnclosedSeparationLowerBound(left, right, origin: a.position, axis: axis)
    let relativeAcceleration = source.acceleration - target.acceleration
    let velocity = source.initialVelocity - target.initialVelocity + relativeAcceleration * middle
    let direction = SweepIntervalVector(axis)
    let length = direction.length
    guard length.finite, length.lower > 0 else { return false }
    let linear = (SweepIntervalVector(velocity).dot(direction).magnitude / length).upper
    let acceleration =
      (SweepIntervalVector(relativeAcceleration).dot(direction).magnitude / length).upper
    let speed =
      SweepInterval(linear) + SweepInterval(acceleration) * SweepInterval(half)
      + SweepIntervalVector(source.worldAngularVelocity).length * SweepInterval(hull.radius)
      + SweepIntervalVector(target.worldAngularVelocity).length * SweepInterval(targetHull.radius)
    let envelope = (speed * SweepInterval(half)).upper
    let numerical =
      64 * Double.ulpOfOne
      * max(1, hull.radius + targetHull.radius + a.position.length + b.position.length)
    return gap.isFinite && envelope.isFinite && gap - envelope - numerical > 0
  }

  /// A true tip-to-tip meeting has boundary barycentrics on every incident face.
  /// Exact transverse identities and unique native support vertices provide a
  /// separate certificate; no uncertain ray boundary is promoted into a hit.
  private static func axialVertexInterval(
    _ source: HullSceneMotion, hull: PreparedHull, target: HullSceneMotion,
    targetHull: PreparedHull, start: Double, end: Double, work: inout SweepWork
  ) throws -> NativeHullContactResult? {
    let zero = Vector3(0, 0, 0)
    guard source.worldAngularVelocity == zero, target.worldAngularVelocity == zero,
      source.acceleration == target.acceleration,
      !hull.hasUnresolvedSupport, !targetHull.hasUnresolvedSupport
    else { return nil }
    try work.query()
    for axis in 0..<3 {
      let transverse = (0..<3).filter { $0 != axis }
      guard
        transverse.allSatisfy({
          sweepCoordinate(source.start.position, $0) == sweepCoordinate(target.start.position, $0)
            && sweepCoordinate(source.initialVelocity, $0)
              == sweepCoordinate(target.initialVelocity, $0)
        })
      else { continue }
      let left = try axialVertices(
        hull, orientation: source.start.orientation, transverse: transverse, work: &work)
      let right = try axialVertices(
        targetHull, orientation: target.start.orientation, transverse: transverse, work: &work)
      for a in left {
        for b in right {
          let direction = sweepSupportAxes[axis]
          let rawGap =
            (SweepIntervalVector(target.start.position) - SweepIntervalVector(source.start.position)
            + contactWorldPoint(
              b, pose: .init(position: zero, orientation: target.start.orientation))
            - contactWorldPoint(
              a, pose: .init(position: zero, orientation: source.start.orientation)))
            .dot(SweepIntervalVector(direction))
          guard rawGap.finite, rawGap.lower > 0 || rawGap.upper < 0 else { continue }
          let normal = rawGap.lower > 0 ? direction : direction * -1
          guard
            try uniqueVertexSupport(
              hull, point: a, orientation: source.start.orientation,
              normal: normal, maximum: true, work: &work),
            try uniqueVertexSupport(
              targetHull, point: b, orientation: target.start.orientation,
              normal: normal, maximum: false, work: &work)
          else { continue }
          let gap = rawGap.lower > 0 ? rawGap : SweepInterval(0) - rawGap
          let closing =
            (SweepIntervalVector(source.initialVelocity)
            - SweepIntervalVector(target.initialVelocity))
            .dot(SweepIntervalVector(normal))
          let atStart = gap - closing * SweepInterval(start)
          let atEnd = gap - closing * SweepInterval(end)
          let middle = (start + end) * 0.5
          let numerical =
            64 * Double.ulpOfOne
            * max(
              1,
              hull.radius + targetHull.radius
                + shipPose(source, at: middle).position.length
                + shipPose(target, at: middle).position.length)
          if atStart.lower > numerical && atEnd.lower > numerical { return .clear }
          guard closing.finite, closing.lower > 1e-8 else { continue }
          let time = gap / closing
          guard time.finite, time.lower >= start, time.upper <= end else { continue }
          let point = shipPose(source, at: time.upper).systemPoint(a)
          guard point.finite else { throw HullSweepFailure.unproven }
          return .contact(
            .init(lowerTime: start, upperTime: time.upper, point: point, normal: normal))
        }
      }
    }
    return nil
  }

  private static func axialVertices(
    _ hull: PreparedHull, orientation: Basis3, transverse: [Int], work: inout SweepWork
  ) throws -> [Vector3] {
    var result: [Vector3] = []
    var seen = Set<SweepVertexKey>()
    for triangle in hull.triangles {
      try work.triangle()
      for index in 0..<3 {
        let point = triangle.vertex(at: index)
        // Every transverse term is exactly zero by its operands. Rounded
        // cancellation or a small offset cannot stand in for exact collinearity.
        guard
          transverse.allSatisfy({ coordinate in
            (point.x == 0 || sweepCoordinate(orientation.x, coordinate) == 0)
              && (point.y == 0 || sweepCoordinate(orientation.y, coordinate) == 0)
              && (point.z == 0 || sweepCoordinate(orientation.z, coordinate) == 0)
          }), seen.insert(.init(x: point.x, y: point.y, z: point.z)).inserted
        else { continue }
        result.append(point)
      }
    }
    return result
  }

  private static func uniqueVertexSupport(
    _ hull: PreparedHull, point: Vector3, orientation: Basis3,
    normal: Vector3, maximum: Bool, work: inout SweepWork
  ) throws -> Bool {
    let direction = SweepIntervalVector(normal)
    for triangle in hull.triangles {
      try work.triangle()
      for index in 0..<3 {
        let vertex = triangle.vertex(at: index)
        if vertex == point { continue }
        let delta = SweepIntervalVector(vertex) - SweepIntervalVector(point)
        let projection =
          (SweepIntervalVector(orientation.x) * delta.x
          + SweepIntervalVector(orientation.y) * delta.y
          + SweepIntervalVector(orientation.z) * delta.z).dot(direction)
        guard projection.finite, maximum ? projection.upper < 0 : projection.lower > 0 else {
          return false
        }
      }
    }
    return true
  }

  /// Sampling a bounded leaf can miss a thin native feature completely. For fixed
  /// orientations and equal acceleration, a material vertex has an exact straight
  /// relative path. A conditioned ray encloses its real face-crossing time even
  /// when neither the midpoint nor the endpoint intersects. Edge-only or rotating
  /// contacts without another certificate still refuse at the original bound.
  private static func translatedVertexEntry(
    _ source: HullSceneMotion, hull: PreparedHull, target: HullSceneMotion,
    targetHull: PreparedHull, start: Double, end: Double, work: inout SweepWork
  ) throws -> NativeHullContact? {
    guard source.worldAngularVelocity.length == 0, target.worldAngularVelocity.length == 0,
      (source.acceleration - target.acceleration).length == 0,
      !hull.hasUnresolvedSupport, !targetHull.hasUnresolvedSupport
    else { return nil }
    try work.query()
    var earliest: NativeHullContact?
    for reversed in [false, true] {
      let owner = reversed ? target : source
      let container = reversed ? source : target
      let ownerHull = reversed ? targetHull : hull
      let containerHull = reversed ? hull : targetHull
      var seen = Set<SweepVertexKey>()
      let relativeVelocity =
        SweepIntervalVector(owner.initialVelocity)
        - SweepIntervalVector(container.initialVelocity)
      let span = SweepInterval(end) - SweepInterval(start)
      for triangle in ownerHull.triangles {
        try work.triangle()
        for index in 0..<3 {
          let local = triangle.vertex(at: index)
          guard seen.insert(.init(x: local.x, y: local.y, z: local.z)).inserted else { continue }
          // Remove the common world origin before transforming local vertices.
          // This retains an outward certificate without injecting world-offset
          // cancellation into an otherwise well-conditioned small feature.
          let origin =
            SweepIntervalVector(owner.start.position)
            - SweepIntervalVector(container.start.position)
            + SweepIntervalVector(owner.start.orientation.x) * SweepInterval(local.x)
            + SweepIntervalVector(owner.start.orientation.y) * SweepInterval(local.y)
            + SweepIntervalVector(owner.start.orientation.z) * SweepInterval(local.z)
            + relativeVelocity * SweepInterval(start)
          let direction = relativeVelocity * span
          for face in containerHull.triangles {
            try work.triangle()
            guard
              let fraction = translatedFaceCrossing(
                origin, direction: direction, face: face, orientation: container.start.orientation)
            else { continue }
            let time = SweepInterval(start) + span * fraction
            guard time.finite, time.lower >= start, time.upper <= end,
              earliest == nil || time.upper < earliest!.upperTime,
              let normal = contactEntryNormal(
                point: local, owner: owner, face: face, container: container,
                time: time.upper, ownerIsSource: !reversed)
            else { continue }
            let point = shipPose(owner, at: time.upper).systemPoint(local)
            guard point.finite else { throw HullSweepFailure.unproven }
            earliest = .init(lowerTime: start, upperTime: time.upper, point: point, normal: normal)
          }
        }
      }
    }
    return earliest
  }

  /// Two moving material edges can meet without either vertex entering a face.
  /// Cramer's rule over outward intervals certifies the time and both interior
  /// edge parameters; parallel, boundary and unresolved cases remain unknown.
  private static func translatedEdgeEntry(
    _ source: HullSceneMotion, hull: PreparedHull, target: HullSceneMotion,
    targetHull: PreparedHull, start: Double, end: Double, work: inout SweepWork
  ) throws -> NativeHullContact? {
    guard source.worldAngularVelocity.length == 0, target.worldAngularVelocity.length == 0,
      source.acceleration == target.acceleration,
      !hull.hasUnresolvedSupport, !targetHull.hasUnresolvedSupport
    else { return nil }
    let zero = Vector3(0, 0, 0)
    let sourcePose = ShipPose(position: zero, orientation: source.start.orientation)
    let targetPose = ShipPose(position: zero, orientation: target.start.orientation)
    let offset =
      SweepIntervalVector(target.start.position) - SweepIntervalVector(source.start.position)
    let velocity =
      SweepIntervalVector(source.initialVelocity) - SweepIntervalVector(target.initialVelocity)
    var earliest: NativeHullContact?
    for a in hull.triangles {
      for b in targetHull.triangles {
        for i in 0..<3 {
          let sourceEdge = a.edge(at: i)
          let origin = contactWorldPoint(sourceEdge.0, pose: sourcePose)
          let edge = contactWorldPoint(sourceEdge.1, pose: sourcePose) - origin
          for j in 0..<3 {
            try work.triangle()
            let targetEdge = b.edge(at: j)
            let targetOrigin = contactWorldPoint(targetEdge.0, pose: targetPose)
            let other = targetOrigin - contactWorldPoint(targetEdge.1, pose: targetPose)
            let displacement = offset + targetOrigin - origin
            let determinant = edge.dot(other.cross(velocity))
            guard determinant.finite, determinant.lower > 0 || determinant.upper < 0 else {
              continue
            }
            let u = displacement.dot(other.cross(velocity)) / determinant
            let v = edge.dot(displacement.cross(velocity)) / determinant
            let time = edge.dot(other.cross(displacement)) / determinant
            guard u.finite, v.finite, time.finite, u.lower > 0, u.upper < 1,
              v.lower > 0, v.upper < 1, time.lower >= start, time.upper <= end,
              earliest == nil || time.upper < earliest!.upperTime
            else { continue }
            let ae = source.start.orientation.apply(sourceEdge.1 - sourceEdge.0)
            let be = target.start.orientation.apply(targetEdge.1 - targetEdge.0)
            let cross = ae.cross(be)
            guard cross.finite, cross.length.isFinite, cross.length > 0 else { continue }
            var normal = cross * (1 / cross.length)
            let relative = source.initialVelocity - target.initialVelocity
            if relative.dot(normal) < 0 { normal = normal * -1 }
            guard relative.dot(normal) > 1e-8 else { continue }
            let local = sourceEdge.0 + (sourceEdge.1 - sourceEdge.0) * ((u.lower + u.upper) * 0.5)
            let point = shipPose(source, at: time.upper).systemPoint(local)
            guard point.finite else { throw HullSweepFailure.unproven }
            earliest = .init(lowerTime: start, upperTime: time.upper, point: point, normal: normal)
          }
        }
      }
    }
    return earliest
  }

  /// Outward transforms include the actual relative trajectory, avoiding a rounded
  /// endpoint chord. Strict barycentrics and a resolved determinant certify a real
  /// native face crossing; uncertain boundaries remain unknown, never a hit.
  private static func translatedFaceCrossing(
    _ origin: SweepIntervalVector, direction: SweepIntervalVector,
    face: SweepTriangle, orientation: Basis3
  ) -> SweepInterval? {
    let pose = ShipPose(position: .init(0, 0, 0), orientation: orientation)
    let a = contactWorldPoint(face.a, pose: pose)
    let edge = contactWorldPoint(face.b, pose: pose) - a
    let other = contactWorldPoint(face.c, pose: pose) - a
    let cross = direction.cross(other)
    let determinant = edge.dot(cross)
    guard determinant.finite, determinant.lower > 0 || determinant.upper < 0 else { return nil }
    let offset = origin - a
    let u = offset.dot(cross) / determinant
    let perpendicular = offset.cross(edge)
    let v = direction.dot(perpendicular) / determinant
    let fraction = other.dot(perpendicular) / determinant
    let sum = u + v
    guard u.finite, v.finite, fraction.finite,
      u.lower >= 1e-10, v.lower >= 1e-10, sum.upper <= 1 - 1e-10,
      fraction.lower >= 0, fraction.upper <= 1,
      fraction.upper - fraction.lower <= 1e-10 * max(1, abs(fraction.lower))
    else { return nil }
    return fraction
  }

  private static func contactWorldPoint(_ local: Vector3, pose: ShipPose) -> SweepIntervalVector {
    SweepIntervalVector(pose.position)
      + SweepIntervalVector(pose.orientation.x) * SweepInterval(local.x)
      + SweepIntervalVector(pose.orientation.y) * SweepInterval(local.y)
      + SweepIntervalVector(pose.orientation.z) * SweepInterval(local.z)
  }

  /// The sign comes from the actual material point's prior side of the real face,
  /// independent of body centres and velocity. Tangent/exiting features cannot
  /// supply the normal for a positive linear impulse and are searched past.
  private static func contactEntryNormal(
    point: Vector3, owner: HullSceneMotion, face: SweepTriangle, container: HullSceneMotion,
    time: Double, ownerIsSource: Bool
  ) -> Vector3? {
    let oldPoint = contactWorldPoint(point, pose: owner.start)
    let oldA = contactWorldPoint(face.a, pose: container.start)
    let oldB = contactWorldPoint(face.b, pose: container.start)
    let oldC = contactWorldPoint(face.c, pose: container.start)
    let side = (oldPoint - oldA).dot((oldB - oldA).cross(oldC - oldA))
    guard side.finite, side.lower > 0 || side.upper < 0 else { return nil }
    let orientation = shipPose(container, at: time).orientation
    var normal = orientation.apply((face.b - face.a).cross(face.c - face.a)).unit
    if side.lower > 0 { normal = normal * -1 }
    let velocity = owner.initialVelocity - container.initialVelocity
    let acceleration = owner.acceleration - container.acceleration
    // Linear relative velocity is affine, so positive values at both endpoints
    // also cover the conservative impulse frontier within this time span.
    guard normal.finite, normal.length > 0,
      velocity.dot(normal) > 1e-8,
      (velocity + acceleration * time).dot(normal) > 1e-8
    else { return nil }
    return ownerIsSource ? normal : normal * -1
  }

  private static func nativeContactWitness(
    _ hull: PreparedHull, motion source: HullSceneMotion, target: PreparedHull,
    motion other: HullSceneMotion, time: Double, work: inout SweepWork
  ) throws -> (Vector3, Vector3)? {
    let pose = shipPose(source, at: time)
    let targetPose = shipPose(other, at: time)
    for sourceTriangle in hull.triangles {
      let a = SweepTriangle(
        a: pose.systemPoint(sourceTriangle.a), b: pose.systemPoint(sourceTriangle.b),
        c: pose.systemPoint(sourceTriangle.c), conditioned: true,
        unresolvedSupport: sourceTriangle.unresolvedSupport)
      guard !a.unresolvedSupport else { throw HullSweepFailure.unproven }
      for targetTriangle in target.triangles {
        try work.triangle()
        let b = SweepTriangle(
          a: targetPose.systemPoint(targetTriangle.a), b: targetPose.systemPoint(targetTriangle.b),
          c: targetPose.systemPoint(targetTriangle.c), conditioned: true,
          unresolvedSupport: targetTriangle.unresolvedSupport)
        guard !b.unresolvedSupport else { throw HullSweepFailure.unproven }
        for index in 0..<3 {
          let edge = a.edge(at: index)
          let local = sourceTriangle.edge(at: index)
          if let hit = sweepRay(
            edge.0, direction: edge.1 - edge.0, triangle: b,
            conditioned: true, maximumDistance: 1), !hit.boundary,
            hit.distance + hit.uncertainty <= 1,
            let normal = contactEntryNormal(
              point: local.0 + (local.1 - local.0) * hit.distance,
              owner: source, face: targetTriangle, container: other, time: time,
              ownerIsSource: true)
          {
            return (edge.0 + (edge.1 - edge.0) * hit.distance, normal)
          }
        }
        for index in 0..<3 {
          let edge = b.edge(at: index)
          let local = targetTriangle.edge(at: index)
          if let hit = sweepRay(
            edge.0, direction: edge.1 - edge.0, triangle: a,
            conditioned: true, maximumDistance: 1), !hit.boundary,
            hit.distance + hit.uncertainty <= 1,
            let normal = contactEntryNormal(
              point: local.0 + (local.1 - local.0) * hit.distance,
              owner: other, face: sourceTriangle, container: source, time: time,
              ownerIsSource: false)
          {
            return (edge.0 + (edge.1 - edge.0) * hit.distance, normal)
          }
        }
      }
    }
    // In deep/aligned overlap the intersecting side faces may all be tangent.
    // Trace actual surface material points into the other closed hull and use
    // the real crossed entry face, rather than a contained face's arbitrary normal.
    if let found = try containedEntryWitness(
      hull, motion: source, target: target, motion: other, time: time,
      ownerIsSource: true, work: &work)
    {
      return found
    }
    return try containedEntryWitness(
      target, motion: other, target: hull, motion: source, time: time,
      ownerIsSource: false, work: &work)
  }

  private static func containedEntryWitness(
    _ hull: PreparedHull, motion owner: HullSceneMotion, target: PreparedHull,
    motion container: HullSceneMotion, time: Double, ownerIsSource: Bool,
    work: inout SweepWork
  ) throws -> (Vector3, Vector3)? {
    // Only this case has a straight material path in the container's frame.
    // Angular/relative-accelerated motion still needs an actual edge/face witness.
    guard owner.worldAngularVelocity.length == 0, container.worldAngularVelocity.length == 0,
      (owner.acceleration - container.acceleration).length == 0
    else { return nil }
    let pose = shipPose(owner, at: time)
    let other = shipPose(container, at: time)
    for triangle in hull.triangles {
      var candidates = [(triangle.a + triangle.b + triangle.c) * (1 / 3.0)]
      for index in 0..<3 {
        let edge = triangle.edge(at: index)
        candidates.append(edge.0)
        candidates.append((edge.0 + edge.1) * 0.5)
      }
      for local in candidates {
        let point = pose.systemPoint(local)
        let current = other.shipPoint(point)
        let contained: Bool
        do {
          contained = try contains(current, hull: target, work: &work)
        } catch HullSweepFailure.unproven {
          // An uncertain surface sample is not an overlap certificate. Other
          // real material points may resolve; budget failures still propagate.
          continue
        }
        guard contained else { continue }
        let prior = container.start.shipPoint(owner.start.systemPoint(local))
        for face in target.triangles {
          try work.triangle()
          guard !face.unresolvedSupport else { throw HullSweepFailure.unproven }
          if let hit = sweepRay(
            prior, direction: current - prior, triangle: face,
            conditioned: true, maximumDistance: 1), !hit.boundary,
            hit.distance + hit.uncertainty <= 1,
            let normal = contactEntryNormal(
              point: local, owner: owner, face: face, container: container,
              time: time, ownerIsSource: ownerIsSource)
          {
            return (point, normal)
          }
        }
      }
    }
    return nil
  }
}
