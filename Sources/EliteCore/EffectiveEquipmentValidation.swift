import Foundation

extension Commander {
  /// These are runtime safety bounds, not current grade or terminal limits.
  /// Stronger finite grandfathered components remain physical property unchanged.
  func validateEffectiveEquipmentStatistics() throws {
    guard let native = ShipCatalogue.ship(shipID)?.game else {
      throw CommanderEquipmentError.invalidRuntimeStatistics
    }
    let effective = performance
    let products = [
      effective.energy, effective.spool, native.recharge * energyRechargeMultiplier,
      shieldCapacity, rearShieldCapacity, frontShieldRecharge, rearShieldRecharge,
    ]
    guard products.allSatisfy({ $0.isFinite && $0 >= 0 }),
      effective.energy > 0, effective.spool > 0
    else { throw CommanderEquipmentError.invalidRuntimeStatistics }
    // Native and PLUGH coordinates are eight-bit; this is StarSystem.distance's
    // maximum possible route. Fuel cost is converted to Int before reach refusal.
    let maximumDistance = floor(hypot(255, 127.5)) * 4 / 10
    let maximumFuelCost = (maximumDistance * 10 * jumpFuelMultiplier).rounded()
    guard maximumFuelCost.isFinite, maximumFuelCost >= 0,
      maximumFuelCost < Double(Int.max)
    else { throw CommanderEquipmentError.invalidRuntimeStatistics }
  }
}
