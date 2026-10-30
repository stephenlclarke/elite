import Foundation

/// Native wreck history is independent of the ordinary ledger's lifetime pools.
/// A source description is retained evidence; only the runtime can admit its actor.
struct NativeSalvageWreck: Codable, Sendable, Equatable {
  enum Source: Codable, Sendable, Equatable {
    case generated(SalvageSite)
    case emp(actor: ActorIdentity, sequence: UInt64)
  }

  let id: UUID
  let owner: UUID
  let identity: WreckIdentity
  let catalogueShipID: String
  let seed: UInt64
  let source: Source
  let bornAt: Double
  let observedAt: Double
  let binding: ActorIdentity?
  let motion: SalvageWreckMotion
  let destroyedAt: Double?

  var valid: Bool {
    guard (0..<8).contains(identity.system.galaxy),
      (0...256).contains(identity.system.system),
      (SalvageCatalogue.profile(catalogueShipID: catalogueShipID)
        ?? SalvageCatalogue.empProfile(catalogueShipID: catalogueShipID)) != nil,
      bornAt.isFinite, bornAt >= 0, observedAt.isFinite, observedAt >= bornAt,
      motion.pose.position.length.isFinite, motion.velocity.length.isFinite,
      motion.angularVelocity.length.isFinite, Self.validBasis(motion.pose.orientation),
      let energy = motion.energy, energy.isFinite, energy <= 100000
    else { return false }
    if let binding {
      guard binding.system == identity.system, binding.visit > 0, binding.visit < UInt64.max,
        binding.entity >= 2, binding.entity < UInt64.max
      else { return false }
    }
    if let destroyedAt {
      guard destroyedAt.isFinite, destroyedAt >= bornAt, destroyedAt <= observedAt,
        energy <= 0, binding == nil
      else { return false }
    } else if energy <= 0 {
      return false
    }
    switch source {
    case .generated(let site):
      return site.identity == identity && site.catalogueShipID == catalogueShipID
        && site.position.length.isFinite && site.velocity.length.isFinite
        && site.angularVelocity.length.isFinite && Self.validBasis(site.orientation)
        && site.metadata != nil
    case .emp(let actor, let sequence):
      guard actor.system == identity.system, actor.entity >= 2,
        actor.entity < UInt64.max, actor.visit > 0, actor.visit < UInt64.max,
        sequence > 0, sequence < 1_000_000_000, let ordinal = UInt32(exactly: sequence)
      else { return false }
      return identity.site == 0x8000_0000 + ordinal && identity.lineage == actor.visit
    }
  }

  func preserve(_ old: Self) throws {
    guard valid, old.valid, id == old.id, owner == old.owner, identity == old.identity,
      catalogueShipID == old.catalogueShipID, seed == old.seed, source == old.source,
      bornAt == old.bornAt, observedAt >= old.observedAt
    else { throw AlienStorageError.historyChanged }
    // A physical death is permanent. Culling does not create a death or advance motion.
    if old.destroyedAt != nil, self != old { throw AlienStorageError.historyChanged }
  }

  private static func validBasis(_ basis: Basis3) -> Bool {
    let epsilon = 0.00001
    return abs(basis.x.length - 1) < epsilon && abs(basis.y.length - 1) < epsilon
      && abs(basis.z.length - 1) < epsilon && abs(basis.x.dot(basis.y)) < epsilon
      && abs(basis.x.dot(basis.z)) < epsilon && abs(basis.y.dot(basis.z)) < epsilon
      && basis.x.cross(basis.y).dot(basis.z) > 1 - epsilon
  }
}
