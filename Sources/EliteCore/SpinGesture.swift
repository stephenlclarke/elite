import Foundation

/// Deliberate circles around the physical pad's centre, enabled only in Spin mode.
struct SpinGesture: Sendable, Equatable {
  private var previous: SIMD2<Double>?
  private var sweep = 0.0
  private var travel = 0.0
  private var samples = 0
  private var latched = false
  var progress: Double { min(1, abs(sweep) / (5 * .pi / 3)) }

  mutating func reset() { self = Self() }

  mutating func update(_ point: SIMD2<Double>) -> SpinDirection? {
    guard !latched else { return nil }
    let vector = point - SIMD2(0.5, 0.5)
    let radius = sqrt(vector.x * vector.x + vector.y * vector.y)
    guard (0.12...0.46).contains(radius) else {
      reset()
      return nil
    }
    guard let previous else {
      self.previous = vector
      return nil
    }
    let angle = atan2(
      previous.x * vector.y - previous.y * vector.x,
      previous.x * vector.x + previous.y * vector.y)
    self.previous = vector
    guard abs(angle) <= .pi / 4 else {
      reset()
      self.previous = vector
      return nil
    }
    sweep += angle
    travel += abs(angle)
    if abs(angle) > 0.02 { samples += 1 }
    if travel > 0.8 && abs(sweep) / travel < 0.85 {
      reset()
      self.previous = vector
      return nil
    }
    guard progress >= 1 && samples >= 16 else { return nil }
    let direction: SpinDirection = sweep < 0 ? .clockwise : .anticlockwise
    latched = true
    sweep = 0
    return direction
  }
}
