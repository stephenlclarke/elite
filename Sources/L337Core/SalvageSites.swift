import Foundation

public enum SalvageSiteKind: String, Hashable, Codable, Sendable {
  case deepSpace, battleSite, miningRegion
}

public struct SalvageSite: Equatable, Codable, Sendable {
  public let identity: WreckIdentity
  public let catalogueShipID: String
  public let kind: SalvageSiteKind
  public let position: Vector3
  public let orientation: Basis3
  public let velocity: Vector3
  /// Canonical radians/second; G1 integrates physical rotation, not a preview animation.
  public let angularVelocity: Vector3
  public let ownership: SalvageOwnership

  public var metadata: SalvageTargetMetadata? {
    guard let profile = SalvageCatalogue.profile(catalogueShipID: catalogueShipID) else {
      return nil
    }
    return .init(
      category: .wreck, ownership: ownership, claimant: nil, wreck: identity,
      section: nil, lot: nil, bounds: profile.bounds,
      workSurfaces: profile.surfaces(wreck: identity))
  }
}

private struct SalvageSiteRandom {
  var state: UInt64
  mutating func next() -> UInt64 {
    state &+= 0x9e37_79b9_7f4a_7c15
    var value = state
    value = (value ^ (value >> 30)) &* 0xbf58_476d_1ce4_e5b9
    value = (value ^ (value >> 27)) &* 0x94d0_49bb_1331_11eb
    return value ^ (value >> 31)
  }
  mutating func unit() -> Double { Double(next() >> 11) / 9_007_199_254_740_992 }
  mutating func direction() -> Vector3 {
    let vector = Vector3(unit() * 2 - 1, unit() * 2 - 1, unit() * 2 - 1)
    return vector.length > 1e-9 ? vector.unit : .init(0, 1, 0)
  }
}

/// Pure site inventory; admission, depletion and current moving poses belong to G1/ledger.
public enum SalvageSites {
  public static func generate(anchors: SystemAnchors, seed: UInt64) -> [SalvageSite] {
    var random = SalvageSiteRandom(
      state: seed ^ 0x5341_4c56_4147_4553
        ^ UInt64(truncatingIfNeeded: anchors.system.galaxy) &* 0x9e37_79b9_7f4a_7c15
        ^ UInt64(truncatingIfNeeded: anchors.system.system))
    let roll = random.next() % 100
    let count = roll < 55 ? 0 : (roll < 93 ? 1 : 2)
    // Existing wreck identities keep their original deterministic source positions.
    let fields = MiningFields.legacyFields(anchors: anchors, seed: seed)
    var result: [SalvageSite] = []
    for index in 0..<count {
      let infrastructure = random.next() % 16 == 0
      let profiles = SalvageCatalogue.all.filter {
        infrastructure ? $0.role == .abandonedInfrastructure : $0.role != .abandonedInfrastructure
      }
      guard !profiles.isEmpty else { continue }
      let profile = profiles[Int(random.next() % UInt64(profiles.count))]
      let lineage = random.next()
      let requestedKind = [SalvageSiteKind.deepSpace, .battleSite, .miningRegion][
        Int(random.next() % 3)]
      let kind: SalvageSiteKind =
        requestedKind == .miningRegion && fields.isEmpty ? .deepSpace : requestedKind
      // The swept sphere contains the whole actual mesh even when its origin is off-centre.
      let sweptRadius = profile.bounds.radius + profile.bounds.center.length
      var position: Vector3?
      for attempt in 0..<64 {
        let direction = random.direction()
        let candidate: Vector3
        switch kind {
        case .miningRegion where !fields.isEmpty:
          let field = fields[(index + attempt) % fields.count]
          candidate = field.position + direction * (sweptRadius + 2500 + random.unit() * 2000)
        case .battleSite:
          let midpoint = (anchors.station.position + anchors.arrival) * 0.5
          candidate = midpoint + direction * (6000 + sweptRadius + random.unit() * 6000)
        default:
          let center = (anchors.planet.position + anchors.sun.position) * 0.5
          candidate = center + direction * (18000 + sweptRadius + random.unit() * 12000)
        }
        if safe(candidate, radius: sweptRadius, anchors: anchors),
          !result.contains(where: { existing in
            guard let other = SalvageCatalogue.profile(catalogueShipID: existing.catalogueShipID)
            else { return true }
            return (existing.position - candidate).length < sweptRadius + other.bounds.radius
              + other.bounds.center.length + 500
          })
        {
          position = candidate
          break
        }
      }
      guard let position else { continue }
      var orientation = Basis3()
      orientation.rotate(
        pitch: random.unit() * 2 * .pi, roll: random.unit() * 2 * .pi, yaw: random.unit() * 2 * .pi)
      let velocity = random.direction() * (2 + random.unit() * 6)
      let angular = random.direction() * min(0.02, 8 / max(1, sweptRadius))
      result.append(
        .init(
          identity: .init(system: anchors.system, site: UInt32(index), lineage: lineage),
          catalogueShipID: profile.catalogueShipID, kind: kind, position: position,
          orientation: orientation,
          velocity: velocity, angularVelocity: angular, ownership: .abandoned))
    }
    return result
  }

  private static func safe(_ position: Vector3, radius: Double, anchors: SystemAnchors) -> Bool {
    position.x.isFinite && position.y.isFinite && position.z.isFinite
      && (position - anchors.station.position).length > 1200 + radius
      && (position - anchors.arrival).length > 1500 + radius
      && (position - anchors.planet.position).length > anchors.planet.radius * 3 + radius
      && (position - anchors.sun.position).length > anchors.sun.radius * 4 + radius
  }
}
