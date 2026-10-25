import Foundation

/// Per-craft readings in simulation units. Legacy mission hulls remain energy-only.
public struct NPCResources: Equatable, Codable, Sendable {
  public enum Profile: String, Codable, Sendable { case nativeHull, legacyEnergyOnly }
  public let profile: Profile
  public let energyCapacity: Double
  public let energyRecharge: Double
  public let frontCapacity: Double
  public let rearCapacity: Double
  public let shieldRecharge: Double
  public var frontShield: Double
  public var rearShield: Double
  public var laserHeat: Double = 0
  public let heatCapacity: Double
  public let heatCooling: Double
  /// nil preserves an unrecorded legacy tank; it never means a full tank.
  public var fuel: Int?
  public let fuelCapacity: Int?
  public var scoopRemainder: Double = 0
  public var electrical: ElectricalReserve? = nil
  /// Explicit catalogue-backed migration for legacy electrical recovery; hull recharge stays legacy.
  var legacyElectricalRecharge: Double? = nil
  var electricalRecharge: Double { legacyElectricalRecharge ?? energyRecharge }

  public var valid: Bool {
    let fuelValid: Bool
    if let capacity = fuelCapacity {
      fuelValid =
        (0...10000).contains(capacity)
        && (fuel.map { $0 >= 0 && $0 <= capacity } ?? true)
    } else {
      fuelValid = fuel == nil
    }
    return [
      energyCapacity, energyRecharge, frontCapacity, rearCapacity, shieldRecharge,
      frontShield, rearShield, laserHeat, heatCapacity, heatCooling, scoopRemainder,
    ]
    .allSatisfy { $0.isFinite && $0 >= 0 }
      && energyCapacity > 0 && energyCapacity <= 100000
      && frontShield <= frontCapacity && rearShield <= rearCapacity
      && laserHeat <= heatCapacity && scoopRemainder < 1
      && (legacyElectricalRecharge.map {
        profile == .legacyEnergyOnly && $0.isFinite && $0 > 0 && $0 <= 100000
      } ?? true)
      && fuelValid
      && (electrical.map {
        $0.valid && $0.capacity == energyCapacity && $0.recharge == electricalRecharge
      } ?? true)
  }

  public static func stock(_ performance: ShipPerformance) -> NPCResources? {
    guard performance.valid else { return nil }
    return stockProfile(performance)
  }

  /// Catalogue policy, not a fabricated positive price, authenticates unpriced native hulls.
  static func stock(for ship: CatalogueShip) -> NPCResources? {
    guard let performance = ship.game,
      performance.valid(purchasePolicy: ship.catalogue.purchasePolicy),
      ship.catalogue.valid(
        shipID: ship.id, performance: performance, nativeCombat: ship.nativeCombat)
    else { return nil }
    return stockProfile(performance)
  }

  private static func stockProfile(_ performance: ShipPerformance) -> NPCResources {
    .init(
      profile: .nativeHull, energyCapacity: performance.energy,
      energyRecharge: performance.recharge, frontCapacity: performance.shield,
      rearCapacity: performance.shield, shieldRecharge: performance.shieldRecharge,
      frontShield: performance.shield, rearShield: performance.shield,
      heatCapacity: 240, heatCooling: 12,
      fuel: performance.fuel, fuelCapacity: performance.fuel)
  }

  public static func legacyEnergyOnly(maximumEnergy: Double) -> NPCResources? {
    guard maximumEnergy.isFinite, maximumEnergy > 0, maximumEnergy <= 100000 else { return nil }
    return .init(
      profile: .legacyEnergyOnly, energyCapacity: maximumEnergy, energyRecharge: 0,
      frontCapacity: 0, rearCapacity: 0, shieldRecharge: 0,
      frontShield: 0, rearShield: 0, heatCapacity: 240, heatCooling: 12,
      fuel: nil, fuelCapacity: nil)
  }

  public mutating func advance(delta: Double) {
    guard valid, delta.isFinite, delta > 0 else { return }
    frontShield = min(frontCapacity, frontShield + delta * shieldRecharge)
    rearShield = min(rearCapacity, rearShield + delta * shieldRecharge)
    laserHeat = max(0, laserHeat - delta * heatCooling)
  }

  public var canFire: Bool {
    valid && (profile == .legacyEnergyOnly || heatCapacity - laserHeat >= 10)
  }

  public mutating func recordBeam(heat: Double) {
    guard valid, heat.isFinite, heat > 0 else { return }
    laserHeat = min(heatCapacity, laserHeat + heat)
  }

  /// Returns hull damage after absorbing the actual struck facing's charge.
  public mutating func absorb(_ damage: Double, front: Bool) -> Double {
    guard valid, damage.isFinite, damage > 0 else { return damage }
    let absorbed = min(damage, front ? frontShield : rearShield)
    if front { frontShield -= absorbed } else { rearShield -= absorbed }
    return damage - absorbed
  }

  /// Fuel changes only for an admitted jump or actual scoop collection, never cruising.
  public mutating func spendFuel(_ tenthsLY: Int) -> Bool {
    guard valid, tenthsLY >= 0, let fuel, fuel >= tenthsLY else { return false }
    self.fuel = fuel - tenthsLY
    return true
  }

  public mutating func scoopFuel(delta: Double, rate: Double) {
    guard valid, delta.isFinite, delta > 0, rate.isFinite, rate > 0,
      let fuel, let capacity = fuelCapacity, fuel < capacity
    else { return }
    let collected = scoopRemainder + min(Double(capacity - fuel), delta * rate)
    let units = Int(collected)
    self.fuel = min(capacity, fuel + units)
    scoopRemainder = self.fuel == capacity ? 0 : collected - Double(units)
  }

  public var telemetry: TargetTelemetry.Resources {
    .init(
      frontShield: frontShield, frontCapacity: frontCapacity,
      rearShield: rearShield, rearCapacity: rearCapacity,
      laserHeat: laserHeat, heatCapacity: heatCapacity,
      fuelTenthsLY: fuel ?? -1, fuelCapacityTenthsLY: fuelCapacity ?? -1,
      electricalPower: electrical?.remaining, electricalCapacity: electrical?.capacity)
  }
}

public enum NPCFactProvenance: String, Codable, Sendable { case generated, recorded, inferredLocal }
