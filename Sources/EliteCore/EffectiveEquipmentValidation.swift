import Foundation

extension Commander {
  /// These are runtime safety bounds, not current grade or terminal limits.
  /// Stronger finite grandfathered components remain physical property unchanged.
  func validateEffectiveEquipmentStatistics() throws {
    guard let native = ShipCatalogue.ship(shipID)?.game,
      (0...FuelStorage.maximumCount).contains(fuelStorageUnits)
    else {
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
    let extraFuel = fuelStorageUnits.multipliedReportingOverflow(by: FuelStorage.unitCapacity)
    let capacity = native.fuel.addingReportingOverflow(extraFuel.partialValue)
    guard !extraFuel.overflow, !capacity.overflow, capacity.partialValue > 0 else {
      throw CommanderEquipmentError.invalidRuntimeStatistics
    }
    let fuelReach =
      jumpFuelMultiplier > 0
      ? Double(capacity.partialValue) / (10 * jumpFuelMultiplier) : jumpCap
    var radii = [min(jumpCap, fuelReach)]
    if let search = navigationTier?.radius(
      capacity: capacity.partialValue, fuelMultiplier: jumpFuelMultiplier)
    {
      radii.append(search)
    }
    guard
      radii.allSatisfy({ radius in
        let scale = ceil(radius * 10)
        return radius.isFinite && radius >= 0 && scale.isFinite && scale < Double(Int.max)
      })
    else { throw CommanderEquipmentError.invalidRuntimeStatistics }
  }
}
