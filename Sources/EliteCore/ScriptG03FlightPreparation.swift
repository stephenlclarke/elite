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
    let purchases: [(String, ComponentFittingSlot)] = [
      (TargetingTier.basic.equipmentName, .targetingCore),
      (TargetingTier.advanced.equipmentName, .targetingCore),
      (TargetingTier.docking.equipmentName, .targetingCore),
      (ShieldBooster.pulse.equipmentName, .shield),
      ("Extra Energy Unit", .energy),
    ]
    var candidate = self
    try candidate.commander.prepareEquipment(legacy: false)
    let before = candidate.commander
    var totalPrice = 0
    for (name, slot) in purchases {
      guard let item = Equipment.all.first(where: { $0.name == name }),
        candidate.equipmentAvailable(item)
      else { throw EquipmentRuntimeError.unavailable }
      let price = candidate.shopPrice(item)
      let quote = try candidate.quoteEquipmentPurchase(item)
      guard quote.purchase.requiredDebit == price else { throw EquipmentRuntimeError.unavailable }
      totalPrice += price
      let fitted = try candidate.applyEquipmentPurchase(quote)
      guard fitted,
        candidate.commander.fittedEquipment(at: slot)?.id == quote.request.newItem
      else { throw EquipmentRuntimeError.incompatibleFit }
    }
    guard candidate.commander.credits == before.credits - totalPrice,
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
