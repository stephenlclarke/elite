import Foundation

public enum CargoCollectionRefusal: String, Codable, Sendable {
  case unavailable, protectedPayload, noScoops, invalidApproach, fullHold, invalidCargo
}

public enum CargoCollectionReceipt: Equatable, Codable, Sendable {
  case collected(CommodityAmount)
  case refused(CargoCollectionRefusal)
}

/// Ordinary cargo retains its native market unit; kilograms never consume tonnes.
public struct TypedCargoPayload: Equatable, Codable, Sendable {
  public let identity: PayloadIdentity
  public let amount: CommodityAmount
  public let position: Vector3
  public let velocity: Vector3

  public init(
    identity: PayloadIdentity, amount: CommodityAmount, position: Vector3,
    velocity: Vector3 = Vector3(0, 0, 0)
  ) {
    self.identity = identity
    self.amount = amount
    self.position = position
    self.velocity = velocity
  }

  public func collect(
    into cargo: inout [Int], freeTonnes: Int, hasScoops: Bool,
    approachAllowed: Bool, protection: MissionProtection
  ) -> CargoCollectionReceipt {
    if case .mission = identity { return .refused(.protectedPayload) }
    guard !protection.protectedPayloads.contains(identity) else {
      return .refused(.protectedPayload)
    }
    guard hasScoops else { return .refused(.noScoops) }
    guard approachAllowed else { return .refused(.invalidApproach) }
    let index = amount.commodity.rawValue
    guard amount.valid, cargo.count == CommodityIdentity.allCases.count,
      cargo.allSatisfy({ $0 >= 0 && $0 <= Int.max / 17 }),
      cargo[index] <= Int.max / 17 - amount.quantity
    else { return .refused(.invalidCargo) }
    guard amount.tonnes == 0 || amount.tonnes <= freeTonnes else {
      return .refused(.fullHold)
    }
    cargo[index] += amount.quantity
    return .collected(amount)
  }

  /// Caller supplies the available ordinary manifest, excluding mission custody.
  public static func wreck(
    actor: ActorIdentity, manifest: [CommodityAmount], position: Vector3,
    protection: MissionProtection
  ) -> [TypedCargoPayload] {
    guard !protection.protectedActors.contains(actor) else { return [] }
    return manifest.prefix(CommodityIdentity.allCases.count).enumerated().compactMap {
      index, amount in
      guard amount.valid else { return nil }
      let identity = PayloadIdentity.wreck(actor, lot: UInt16(index))
      guard !protection.protectedPayloads.contains(identity) else { return nil }
      return TypedCargoPayload(identity: identity, amount: amount, position: position)
    }
  }
}
