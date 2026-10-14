import Foundation

public struct EquipmentTransferPlan: Sendable {
  public let commander: Commander
  public let issues: [String]
  public let storageRows: [String]
}
extension Commander {
  func equipmentTransfer(to shipID: String) -> EquipmentTransferPlan {
    var candidate = self
    guard ownedEquipmentValid else {
      return .init(
        commander: candidate, issues: ["Owned equipment does not match the actual fit."],
        storageRows: [])
    }
    candidate.synchronizeEquipmentInventory(force: true)
    guard ShipCatalogue.ship(shipID)?.game != nil,
      let profile = ShipCatalogue.ship(shipID).flatMap({ try? ShipAccommodationProfile(ship: $0) })
    else {
      return .init(
        commander: candidate, issues: ["This hull has no compatible equipment adapter."],
        storageRows: [])
    }
    candidate.shipID = shipID
    var inventory = candidate.ownedEquipment!
    let previouslyFitted = Set(inventory.fitted.map(\.id))
    for index in inventory.items.indices { inventory.items[index].fittedSlot = nil }
    candidate.ownedEquipment = inventory
    candidate.laserMounts = LaserMounts()
    candidate.equipment = equipment.filter { LaserKind.from($0) != nil }
    candidate.missiles = 0
    candidate.fuelStorageUnits = 0
    let occupied = accommodation.fittedBerths.filter { $0.use.used }
    candidate.accommodation.fitted = Set(occupied.map(\.id))
    // Tanks and hold expansion precede optional modules. Previously fitted items have priority.
    let order = inventory.items.indices.sorted { a, b in
      func rank(_ index: Int) -> Int {
        let item = inventory.items[index]
        let current = previouslyFitted.contains(item.id) ? 0 : 100
        switch item.kind {
        case .fuelStorage: return current
        case .module("Large Cargo Bay"): return current + 1
        case .module(let name):
          if let tier = TargetingTier.from(name) { return current + 30 - tier.rawValue }
          if let tier = NavigationTier.from(name) { return current + 30 - tier.rawValue }
          if let tier = ShieldBooster.from(name) { return current + 30 - tier.rawValue }
          if name == Equipment.navalEnergyUnit { return current + 20 }
          return current + 30
        default: return current + 2
        }
      }
      return rank(a) == rank(b) ? a < b : rank(a) < rank(b)
    }
    for index in order {
      _ = candidate.fitOwnedGear(at: index, equipmentBudget: profile.equipmentUnits)
    }
    let empty = accommodation.ownedBerths.filter { !$0.use.used }.sorted { a, b in
      let left = accommodation.fitted.contains(a.id)
      let right = accommodation.fitted.contains(b.id)
      return left == right ? a.id.uuidString < b.id.uuidString : left
    }
    for berth in empty {
      var proposed = candidate
      proposed.accommodation.fitted.insert(berth.id)
      if proposed.passengerFit?.allowed == true { candidate = proposed }
    }
    var issues = candidate.passengerFit?.issues ?? ["This hull has no accommodation adapter."]
    if candidate.cargoTonnes > candidate.capacity {
      issues.append("Sell cargo first: the actual cargo and occupied cabins cannot fit this hull.")
    }
    if candidate.fuel > candidate.fuelCapacity {
      issues.append("Use excess fuel first; the fitted tank is smaller.")
    }
    let stored = candidate.ownedEquipment!.stored
    let counts = Dictionary(grouping: stored, by: { $0.kind.name }).mapValues(\.count)
    var rows = counts.keys.sorted().map { "Stored: \(counts[$0]!) x \($0)" }
    let cabins = candidate.accommodation.storedBerths.count
    if cabins > 0 { rows.append("Stored: \(cabins) empty passenger cabins") }
    return .init(commander: candidate, issues: issues, storageRows: rows)
  }
  @discardableResult
  mutating func fitOwnedGear(
    at index: Int, equipmentBudget: Int, mount requested: LaserMount? = nil
  ) -> Bool {
    guard var inventory = ownedEquipment, inventory.items.indices.contains(index) else {
      return false
    }
    let item = inventory.items[index]
    guard item.fittedSlot == nil, item.condition == 10000, item.modifications.isEmpty,
      commonEquipmentUnits + accommodation.fitted.count + item.kind.equipmentUnits
        <= equipmentBudget
    else { return false }
    let slot: OwnedGearSlot
    switch item.kind {
    case .laser(let laser):
      guard case .laser(let preferred) = item.preferredSlot else { return false }
      let mount = requested ?? preferred
      guard performance.supports(mount), self.laser(on: mount) == nil else { return false }
      var mounts = laserMounts
      mounts[mount] = laser
      laserMounts = mounts
      equipment.insert(laser.equipmentName)
      slot = .laser(mount)
    case .missile:
      guard missiles < missileCapacity else { return false }
      slot = .pylon(missiles)
      missiles += 1
    case .fuelStorage:
      guard fuelStorageUnits < FuelStorage.maximumCount else { return false }
      slot = .fuelStorage(fuelStorageUnits)
      fuelStorageUnits += 1
    case .module(let name):
      guard !equipment.contains(name) else { return false }
      if name == "Large Cargo Bay" && performance.cargoExpansion == 0 { return false }
      if TargetingTier.from(name) != nil || name == Equipment.legacyDockingComputer {
        guard targetingTier == nil else { return false }
      }
      if NavigationTier.from(name) != nil && navigationTier != nil { return false }
      if ShieldBooster.from(name) != nil && shieldBooster != nil { return false }
      if ["Extra Energy Unit", Equipment.navalEnergyUnit].contains(name)
        && !equipment.isDisjoint(with: ["Extra Energy Unit", Equipment.navalEnergyUnit])
      {
        return false
      }
      equipment.insert(name)
      slot = .module(name)
    }
    inventory.items[index].fittedSlot = slot
    ownedEquipment = inventory
    return true
  }
  mutating func applyOwnedEquipmentFit() {
    guard var inventory = ownedEquipment else { return }
    equipment = Set(
      inventory.items.compactMap { item -> String? in
        if case .laser(let laser) = item.kind { return laser.equipmentName }
        if item.fittedSlot != nil, case .module(let name) = item.kind { return name }
        return nil
      })
    var mounts = LaserMounts()
    var pylons = 0
    var tanks = 0
    for index in inventory.items.indices {
      guard let slot = inventory.items[index].fittedSlot else { continue }
      switch (slot, inventory.items[index].kind) {
      case (.laser(let mount), .laser(let laser)): mounts[mount] = laser
      case (.pylon, .missile):
        inventory.items[index].fittedSlot = .pylon(pylons)
        pylons += 1
      case (.fuelStorage, .fuelStorage):
        inventory.items[index].fittedSlot = .fuelStorage(tanks)
        tanks += 1
      default: break
      }
    }
    laserMounts = mounts
    missiles = pylons
    fuelStorageUnits = tanks
    ownedEquipment = inventory
  }
}
