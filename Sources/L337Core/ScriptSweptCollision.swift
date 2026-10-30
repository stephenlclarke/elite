import Foundation

enum ScriptSweptCollision {
  /// Earliest contact of a moving sphere with a closed triangle, including edges/corners.
  static func triangle(
    origin: Vector3, direction: Vector3, range: Double, radius: Double,
    a: Vector3, b: Vector3, c: Vector3
  ) -> Double? {
    let normal = (b - a).cross(c - a).unit
    guard normal.length > 0 else { return nil }
    var candidates: [Double] = []
    let signed = (origin - a).dot(normal)
    if abs(signed) <= radius,
      inside(origin - normal * signed, a: a, b: b, c: c, normal: normal)
    {
      candidates.append(0)
    }
    let slope = direction.dot(normal)
    if abs(slope) > 1e-12 {
      for side in [-radius, radius] {
        let distance = (side - signed) / slope
        let contact = origin + direction * distance - normal * side
        if (0...range).contains(distance), inside(contact, a: a, b: b, c: c, normal: normal) {
          candidates.append(distance)
        }
      }
    }
    for (start, end) in [(a, b), (b, c), (c, a)] {
      if let hit = edge(
        origin: origin, direction: direction, range: range, radius: radius,
        a: start, b: end)
      {
        candidates.append(hit)
      }
      if let hit = sphere(origin: origin - start, direction: direction, radius: radius),
        hit <= range
      {
        candidates.append(hit)
      }
    }
    return candidates.min()
  }
  private static func inside(
    _ point: Vector3, a: Vector3, b: Vector3, c: Vector3, normal: Vector3
  ) -> Bool {
    [(a, b), (b, c), (c, a)].allSatisfy { start, end in
      (end - start).cross(point - start).dot(normal) >= -1e-9
    }
  }
  private static func edge(
    origin: Vector3, direction: Vector3, range: Double, radius: Double, a: Vector3, b: Vector3
  ) -> Double? {
    let segment = b - a
    let length = segment.dot(segment)
    guard length > 1e-18 else { return nil }
    let relative = origin - a
    let axial = relative.dot(segment) / length
    let rate = direction.dot(segment) / length
    let perpendicular = relative - segment * axial
    let motion = direction - segment * rate
    let constant = perpendicular.dot(perpendicular) - radius * radius
    if constant <= 0, (0...1).contains(axial) { return 0 }
    let quadratic = motion.dot(motion)
    let linear = perpendicular.dot(motion)
    guard quadratic > 1e-18 else { return nil }
    let discriminant = linear * linear - quadratic * constant
    guard discriminant >= 0 else { return nil }
    let root = sqrt(discriminant)
    for distance in [(-linear - root) / quadratic, (-linear + root) / quadratic] {
      if (0...range).contains(distance), (0...1).contains(axial + rate * distance) {
        return distance
      }
    }
    return nil
  }
  static func sphere(origin: Vector3, direction: Vector3, radius: Double) -> Double? {
    let constant = origin.dot(origin) - radius * radius
    if constant <= 0 { return 0 }
    let quadratic = direction.dot(direction)
    let linear = origin.dot(direction)
    guard quadratic > 1e-18 else { return nil }
    let discriminant = linear * linear - quadratic * constant
    guard discriminant >= 0 else { return nil }
    let distance = (-linear - sqrt(discriminant)) / quadratic
    return distance >= 0 ? distance : nil
  }
}
