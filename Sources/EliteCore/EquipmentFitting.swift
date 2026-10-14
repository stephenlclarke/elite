import Foundation

public struct OwnedGearFitQuote: Sendable {
  public let item: UUID
  public let fitted: Bool
  public let issues: [String]
  public var allowed: Bool { issues.isEmpty }
  let before: Commander
  let after: Commander
}
extension Game {
  func ownedFittedGear(named name: String) -> OwnedGear? {
    commander.ownedEquipment?.fitted.first { $0.kind.name == name }
  }
  mutating func recordOwnedGearConsumption(_ item: OwnedGear?) {
    guard let item else { return }
    if let mission = item.issuedBy, let resource = item.sourceResource {
      commander.scriptState.instances[mission]?.gearIssues[resource]?.consumed.insert(item.id)
    }
    emitScriptEvent(
      "gear.consumed",
      values: ["item": .string(item.id.uuidString), "name": .string(item.kind.name)], drain: false)
  }
  public func ownedGearFitQuote(_ id: UUID, fitted: Bool, mount: LaserMount? = nil)
    -> OwnedGearFitQuote
  {
    var candidate = commander
    var issues: [String] = []
    if !docked || !dockedAtMainStation || paused {
      issues.append("Refitting requires a main orbital station.")
    }
    if !candidate.ownedEquipmentValid {
      issues.append("Owned equipment does not match the actual fit.")
    }
    if let inventory = candidate.ownedEquipment,
      let index = inventory.items.firstIndex(where: { $0.id == id }),
      let profile = try? ShipAccommodationProfile(ship: candidate.ship)
    {
      if fitted {
        if !candidate.fitOwnedGear(at: index, equipmentBudget: profile.equipmentUnits, mount: mount)
        {
          issues.append("No compatible empty mount, pylon or equipment space for this item.")
        }
      } else if inventory.items[index].fittedSlot != nil {
        candidate.ownedEquipment?.items[index].fittedSlot = nil
        candidate.applyOwnedEquipmentFit()
      } else {
        issues.append("This item is already stored.")
      }
      let legacyStorage =
        !fitted && candidate.xyzzyActive && candidate.accommodation.fitted.isEmpty
        && !candidate.requiresContractFit
      if !legacyStorage {
        issues +=
          candidate.passengerFit?.issues ?? ["The hull has no compatible equipment adapter."]
      }
      if candidate.fuel > candidate.fuelCapacity {
        issues.append("Use excess fuel before storing its tank.")
      }
      if !candidate.valid && issues.isEmpty {
        issues.append("The resulting cargo, route or equipment fit is invalid.")
      }
    } else {
      issues.append("This owned equipment item is unavailable.")
    }
    return .init(item: id, fitted: fitted, issues: issues, before: commander, after: candidate)
  }
  mutating func confirmOwnedGearFit(_ quote: OwnedGearFitQuote) throws {
    guard docked, dockedAtMainStation, !paused, quote.allowed, commander == quote.before,
      quote.after.valid
    else { throw MissionPackError("The equipment quote changed; review the actual fit again.") }
    let oldShieldCapacity = commander.shieldCapacity
    commander = quote.after
    frontShield = frontShield / oldShieldCapacity * commander.shieldCapacity
    rearShield = rearShield / oldShieldCapacity * commander.shieldCapacity
    notify(quote.fitted ? "OWNED EQUIPMENT REFITTED" : "OWNED EQUIPMENT STORED")
    emitScriptEvent(
      "equipment.changed",
      values: ["item": .string(quote.item.uuidString), "fitted": .bool(quote.fitted)])
  }
  func selectedOwnedGear(fitted: Bool) -> OwnedGear? {
    guard Equipment.all.indices.contains(selection), let inventory = commander.ownedEquipment else {
      return nil
    }
    let name = Equipment.all[selection].name
    return inventory.items.first { item in
      guard item.kind.name == name, (item.fittedSlot != nil) == fitted else { return false }
      if fitted, case .laser = item.kind { return item.fittedSlot == .laser(equipmentMount) }
      return true
    }
  }
  mutating func ownedEquipmentKey(_ key: String) -> Bool {
    guard screen == .equipment, ["s", "r"].contains(key), Equipment.all.indices.contains(selection),
      Equipment.all[selection].name != PassengerCabin.equipmentName,
      Equipment.all[selection].name != "Fuel"
    else { return false }
    if !docked || !dockedAtMainStation || paused {
      notify("REFITTING REQUIRES A MAIN STATION")
      return true
    }
    var candidate = self
    candidate.commander.synchronizeEquipmentInventory(force: true)
    guard let item = candidate.selectedOwnedGear(fitted: key == "s") else {
      notify(key == "s" ? "NO FITTED OWNED ITEM HERE" : "NO OWNED ITEM IN STORAGE")
      return true
    }
    let quote = candidate.ownedGearFitQuote(item.id, fitted: key == "r", mount: equipmentMount)
    do {
      try candidate.confirmOwnedGearFit(quote)
      self = candidate
    } catch { notify(quote.issues.first ?? error.localizedDescription) }
    return true
  }
}
extension GameRuntime {
  public func ownedGearFitQuote(_ id: UUID, fitted: Bool, mount: LaserMount? = nil)
    -> OwnedGearFitQuote
  {
    game.ownedGearFitQuote(id, fitted: fitted, mount: mount)
  }
  public func confirmOwnedGearFit(_ quote: OwnedGearFitQuote) throws {
    try scriptCommand { try $0.confirmOwnedGearFit(quote) }
  }
}
