import Foundation

extension Game {
  /// Fixed paid preparation shared by G03 native flights and freshly constructed Gallery trials.
  /// The complete fit publishes together; an unavailable quote cannot leave a partial purchase.
  mutating func prepareG03FlightEquipment() throws {
    guard docked, !paused,
      let origin = try? Universe.originalWorlds.world(
        galaxy: commander.galaxy, system: commander.system),
      systems.indices.contains(origin.system),
      currentSystem == Universe.galaxy(number: origin.galaxy)[origin.system],
      !commander.unlimitedCash, commander.scriptState.instances.isEmpty,
      commander.contracts.boards.isEmpty
    else {
      throw MissionPackError("Prepare this G03 flight at an installed ordinary world's shop.")
    }
    let purchases: [(String, Int, ComponentFittingSlot)] = [
      (TargetingTier.basic.equipmentName, 8000, .targetingCore),
      (TargetingTier.advanced.equipmentName, 20000, .targetingCore),
      (TargetingTier.docking.equipmentName, 40000, .targetingCore),
      (ShieldBooster.pulse.equipmentName, 3000, .shield),
      ("Extra Energy Unit", 72000, .energy),
    ]
    var candidate = self
    try candidate.commander.prepareEquipment(legacy: false)
    let before = candidate.commander
    for (name, price, slot) in purchases {
      guard let item = Equipment.all.first(where: { $0.name == name }),
        candidate.equipmentAvailable(item), candidate.shopPrice(item) == price
      else { throw EquipmentRuntimeError.unavailable }
      let quote = try candidate.quoteEquipmentPurchase(item)
      guard quote.purchase.requiredDebit == price else { throw EquipmentRuntimeError.unavailable }
      let fitted = try candidate.applyEquipmentPurchase(quote)
      guard fitted,
        candidate.commander.fittedEquipment(at: slot)?.id == quote.request.newItem
      else { throw EquipmentRuntimeError.incompatibleFit }
    }
    guard candidate.commander.credits == before.credits - 143000,
      candidate.commander.equipmentOwnerID == before.equipmentOwnerID,
      candidate.commander.hullInstanceID == before.hullInstanceID,
      candidate.commander.cargo == before.cargo, candidate.commander.fuel == before.fuel,
      candidate.commander.galaxy == before.galaxy, candidate.commander.system == before.system,
      candidate.commander.flightSimulation == before.flightSimulation,
      candidate.commander.missiles == before.missiles, candidate.commander.valid
    else { throw EquipmentRuntimeError.incompatibleFit }
    self = candidate
  }
}
