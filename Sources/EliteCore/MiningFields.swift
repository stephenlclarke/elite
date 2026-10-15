import Foundation

public struct MiningRock: Equatable, Codable, Sendable {
  public let identity: RockIdentity
  public let position: Vector3
  public let radius: Double
  public let energy: Double
}

public struct MiningField: Equatable, Codable, Sendable {
  public let position: Vector3
  public let rocks: [MiningRock]
}

/// Geometry is canonical system space. Visits and camera transforms never seed ore.
public enum MiningFields {
  public static func generate(anchors: SystemAnchors, seed: UInt64) -> [MiningField] {
    let axis = anchors.sun.position - anchors.planet.position
    guard axis.length.isFinite,
      anchors.planet.radius.isFinite, anchors.planet.radius > 0,
      anchors.sun.radius.isFinite, anchors.sun.radius > 0
    else { return [] }
    let forward = axis.length > 1 ? axis * (1 / axis.length) : Vector3(0, 0, 1)
    let cardinals = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]
    let cardinal = cardinals.min { abs(forward.dot($0)) < abs(forward.dot($1)) }!
    let cross = forward.cross(cardinal)
    let side = cross * (1 / cross.length)
    let up = forward.cross(side)
    var random = FieldRandom(
      state: seed ^ 0x4D49_4E49_4E47_4649
        ^ UInt64(truncatingIfNeeded: anchors.system.galaxy) &* 0x9E37_79B9_7F4A_7C15
        ^ UInt64(truncatingIfNeeded: anchors.system.system))
    let count = 2 + Int(random.next() % 3)
    var fields: [MiningField] = []
    for field in 0..<count {
      let rockCount = 5 + Int(random.next() % 8)
      var center: Vector3?
      // Every candidate reserves the complete rock envelope, never an unsafe fallback.
      for _ in 0..<256 {
        let t = 0.2 + random.unit() * 0.4
        let angle = random.unit() * 2 * .pi
        let lateral = 500 + random.unit() * 1000
        let candidate =
          anchors.planet.position + axis * t
          + side * (cos(angle) * lateral) + up * (sin(angle) * lateral)
        if safe(candidate, radius: 240, anchors: anchors),
          fields.allSatisfy({ ($0.position - candidate).length > 500 })
        {
          center = candidate
          break
        }
      }
      if center == nil {
        // Short or overlapping bands still get a deterministic reachable shell.
        // Triangle inequality keeps this shell outside both celestial envelopes.
        let shell = max(3 * anchors.planet.radius, axis.length + 4 * anchors.sun.radius) + 1000
        for attempt in 0..<32 {
          let angle = Double(attempt + field * 7) * 2 * .pi / 32
          let candidate =
            anchors.planet.position + side * (cos(angle) * shell)
            + up * (sin(angle) * shell)
          if safe(candidate, radius: 240, anchors: anchors),
            fields.allSatisfy({ ($0.position - candidate).length > 500 })
          {
            center = candidate
            break
          }
        }
      }
      guard let center else { continue }
      var rocks: [MiningRock] = []
      for rock in 0..<rockCount {
        let angle = random.unit() * 2 * .pi
        let offset = 40 + random.unit() * 140
        let position =
          center + side * (cos(angle) * offset)
          + up * (sin(angle) * offset) + forward * ((random.unit() - 0.5) * 100)
        let radius = 18 + random.unit() * 22
        guard safe(position, radius: radius, anchors: anchors) else { continue }
        rocks.append(
          .init(
            identity: .init(
              system: anchors.system,
              field: UInt16(field), rock: UInt16(rock)), position: position,
            radius: radius, energy: 100 + Double(random.next() % 101)))
      }
      if !rocks.isEmpty { fields.append(.init(position: center, rocks: rocks)) }
    }
    return fields
  }

  private static func safe(_ point: Vector3, radius: Double, anchors: SystemAnchors) -> Bool {
    point.x.isFinite && point.y.isFinite && point.z.isFinite
      && (point - anchors.planet.position).length >= 3 * anchors.planet.radius + radius
      && (point - anchors.sun.position).length >= 4 * anchors.sun.radius + radius
      && (point - anchors.station.position).length >= 1200 + radius
  }
}

private struct FieldRandom {
  var state: UInt64
  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var value = state
    value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
    value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
    return value ^ (value >> 31)
  }
  mutating func unit() -> Double { Double(next() >> 11) / 9_007_199_254_740_992 }
}
