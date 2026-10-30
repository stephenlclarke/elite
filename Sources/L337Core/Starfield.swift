import Foundation

/// Persistent stars share the ships' camera motion; throttle never repositions them.
public struct Starfield: Sendable, Equatable {
  public private(set) var positions: [Vector3] = []
  private var randomState: UInt64 = 0x5354_4152_4649_454c

  public init() {
    for _ in 0..<768 { positions.append(makeStar(distance: 700 + unit() * 6300)) }
  }

  public mutating func advance(
    delta: Double, speed: Double, pitch: Double, roll: Double, yaw: Double = 0,
    translation: Vector3 = .init(0, 0, 0)
  ) {
    for index in positions.indices {
      var star = positions[index].rotated(
        pitch: pitch * delta, roll: roll * delta, yaw: yaw * delta)
      star = star - translation * delta
      star.z -= speed * delta * 18
      if star.length < 300 || star.length > 9000 { star = makeStar(distance: 7000) }
      positions[index] = star
    }
  }

  /// Apply actual native-world camera motion without reconstructing its integration.
  /// Invalid poses or derived points leave every star and the random stream unchanged.
  @discardableResult
  public mutating func advance(from startPose: ShipPose, to endPose: ShipPose) -> Bool {
    guard startPose.position.finite, startPose.position.length.isFinite,
      endPose.position.finite, endPose.position.length.isFinite,
      startPose.orientation.validRotation, endPose.orientation.validRotation,
      (startPose.orientation.x.cross(startPose.orientation.y) - startPose.orientation.z).length
        < 0.0001,
      (endPose.orientation.x.cross(endPose.orientation.y) - endPose.orientation.z).length < 0.0001
    else { return false }
    let moved = positions.map { endPose.shipPoint(startPose.systemPoint($0)) }
    guard moved.allSatisfy({ $0.finite && $0.length.isFinite }) else { return false }
    // An unchanged camera must not introduce rounding drift or consume random stars.
    if startPose == endPose { return true }
    for index in positions.indices {
      var star = moved[index]
      if star.length < 300 || star.length > 9000 { star = makeStar(distance: 7000) }
      positions[index] = star
    }
    return true
  }

  private mutating func makeStar(distance: Double) -> Vector3 {
    let z = unit() * 2 - 1
    let angle = unit() * 2 * .pi
    let radius = sqrt(1 - z * z)
    return Vector3(radius * cos(angle), radius * sin(angle), z) * distance
  }

  private mutating func unit() -> Double {
    randomState = randomState &* 6_364_136_223_846_793_005 &+ 1
    return Double(randomState >> 32) / Double(UInt32.max)
  }
}
