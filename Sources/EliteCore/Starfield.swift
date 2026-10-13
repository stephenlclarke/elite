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
