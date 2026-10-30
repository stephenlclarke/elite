import Foundation

/// Fuel-only policy. Physical thermal exposure and lethal solar/planet impacts stay independent.
struct SolarFuelCollection: Sendable, Equatable {
  let state: SolarScoopState
  let fuel: Int
  let remainder: Double

  static func hasFittedScoops(_ inventory: OwnedEquipmentInventory?) -> Bool {
    guard let inventory, let node = EquipmentRuntimeCatalog.node(for: "Fuel Scoops") else {
      return false
    }
    return inventory.items.contains {
      $0.node == node && $0.location?.hullInstanceID == inventory.activeHull
        && $0.location?.slot == .utility(.fuelScoops)
    }
  }

  static func step(
    delta: Double, sun: CelestialBody?, forwardSpeed: Double,
    fitted: Bool, fuel: Int, capacity: Int, remainder: Double
  ) -> Self {
    func result(_ state: SolarScoopState, fuel: Int? = nil, remainder: Double = 0) -> Self {
      .init(state: state, fuel: fuel ?? fuelAtStart, remainder: remainder)
    }
    let fuelAtStart = fuel
    // Invalid restored inputs never reach Int conversion; large finite gains saturate at capacity.
    guard delta.isFinite, delta > 0,
      forwardSpeed.isFinite, remainder.isFinite, (0...1).contains(remainder),
      capacity >= 0, (0...capacity).contains(fuel),
      let sun, sun.kind == .sun, sun.position.finite, sun.radius.isFinite, sun.radius > 0
    else { return result(.inactive) }
    let distance = sun.position.length
    guard distance.isFinite, distance > sun.radius, distance / sun.radius <= 3 else {
      return result(.inactive)
    }
    guard fitted else { return result(.noScoops) }
    guard fuel < capacity else { return result(.tankFull) }
    guard forwardSpeed > 0, sun.position.z / max(1, distance) >= 0.8 else {
      return result(.turnTowardSun)
    }
    let accumulated = remainder + delta * 7 * min(1, forwardSpeed / 8)
    guard accumulated.isFinite else { return result(.inactive) }
    let whole = floor(accumulated + 1e-9)
    if whole >= Double(capacity - fuel) { return result(.tankFull, fuel: capacity) }
    let gained = Int(whole)
    let nextFuel = fuel + gained
    if nextFuel == capacity { return result(.tankFull, fuel: nextFuel) }
    return result(.collecting, fuel: nextFuel, remainder: max(0, accumulated - Double(gained)))
  }
}
