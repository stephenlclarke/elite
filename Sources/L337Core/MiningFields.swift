import Foundation

public struct MiningRock: Equatable, Codable, Sendable {
  public let identity: RockIdentity
  public let position: Vector3
  public let radius: Double
  public let energy: Double

  /// Birth mass uses native commodity units, not collision-space metres or volume.
  public var birthMassKg: Double? {
    guard let chunk = AsteroidBeltDefinition.chunk(for: identity) else { return nil }
    return Double(chunk.units) * AsteroidBreakup.kilogramsPerUnit(chunk.content.commodity)
  }
}

public struct MiningField: Equatable, Codable, Sendable {
  public let position: Vector3
  public let rocks: [MiningRock]
}

/// Geometry is canonical system space. Visits and camera transforms never seed ore.
public enum MiningFields {
  public static func generate(
    anchors: SystemAnchors, seed: UInt64, includingLegacy: Bool = false
  ) -> [MiningField] {
    // Compatibility entry point for callers not yet carrying commander context.
    generate(
      anchors: anchors, seed: seed,
      ringPresent: AsteroidBeltDefinition.isPresent(identity: anchors.system, seed: seed),
      includingLegacy: includingLegacy)
  }

  /// Gameplay and charts resolve presence through the same commander ledger.
  public static func generate(
    anchors: SystemAnchors, seed: UInt64, ringPresent: Bool, includingLegacy: Bool = false
  ) -> [MiningField] {
    let retained = includingLegacy ? legacyFields(anchors: anchors, seed: seed) : []
    guard ringPresent,
      let radius = AsteroidBeltDefinition.radius(anchors: anchors),
      anchors.planet.radius.isFinite, anchors.planet.radius > 0,
      anchors.sun.radius.isFinite, anchors.sun.radius > 0
    else { return retained }
    let radial = (anchors.planet.position - anchors.sun.position).unit
    let cardinals = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]
    let reference = cardinals.min { abs(radial.dot($0)) < abs(radial.dot($1)) }!
    let tangent = radial.cross(reference).unit
    guard tangent.length > 0 else { return retained }
    var random = FieldRandom(
      state: AsteroidBeltDefinition.mixed(identity: anchors.system, salt: seed))
    let phase = random.unit() * 2 * .pi
    var fields = retained
    // Three separated sectors, four rocks each: a sparse ring, never a filled torus.
    for sector in 0..<3 {
      let angle = phase + Double(sector) * 2 * .pi / 3
      let center =
        anchors.sun.position
        + radial * (cos(angle) * radius) + tangent * (sin(angle) * radius)
      var rocks: [MiningRock] = []
      for index in 0..<4 {
        let identity = RockIdentity(
          system: anchors.system, field: UInt16(sector + 4), rock: UInt16(index))
        guard let chunk = AsteroidBeltDefinition.chunk(for: identity) else { continue }
        let offset = (Double(index) - 1.5) * 170 / radius
        let distance = radius + (random.unit() * 2 - 1) * AsteroidBeltDefinition.radialHalfWidth
        let position =
          anchors.sun.position
          + radial * (cos(angle + offset) * distance)
          + tangent * (sin(angle + offset) * distance)
        guard safe(position, radius: chunk.radius, anchors: anchors) else { continue }
        rocks.append(
          .init(identity: identity, position: position, radius: chunk.radius, energy: chunk.energy))
      }
      if !rocks.isEmpty { fields.append(.init(position: center, rocks: rocks)) }
    }
    // Unsafe anchors yield no ring sectors, never a substitute planet-centred shell.
    return fields
  }

  public static func legacyFields(anchors: SystemAnchors, seed: UInt64) -> [MiningField] {
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
