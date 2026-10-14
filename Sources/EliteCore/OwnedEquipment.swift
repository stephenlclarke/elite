import CryptoKit
import Foundation

public enum OwnedGearKind: Codable, Sendable, Equatable {
  case laser(LaserKind)
  case missile
  case module(String)
  case fuelStorage
  public var name: String {
    switch self {
    case .laser(let kind): kind.equipmentName
    case .missile: "Missile"
    case .module(let name): name
    case .fuelStorage: FuelStorage.equipmentName
    }
  }
  var valid: Bool {
    if case .module(let name) = self {
      return Equipment.validNames.contains(name) && LaserKind.from(name) == nil
        && !["Fuel", "Missile"].contains(name)
    }
    return true
  }
  var equipmentUnits: Int {
    switch self {
    case .laser, .missile: return 0
    case .fuelStorage: return 1
    case .module(let name):
      if name == Equipment.legacyDockingComputer { return 0 }
      if name == "Extra Energy Unit" { return 2 }
      if name == Equipment.navalEnergyUnit { return 3 }
      return ShieldBooster.from(name) == nil ? 1 : 2
    }
  }
}
public enum OwnedGearSlot: Codable, Sendable, Equatable, Hashable {
  case laser(LaserMount)
  case pylon(Int)
  case module(String)
  case fuelStorage(Int)
  var stableKey: String {
    switch self {
    case .laser(let mount): "laser:" + mount.rawValue
    case .pylon(let index): "pylon:\(index)"
    case .module(let name): "module:" + name
    case .fuelStorage(let index): "tank:\(index)"
    }
  }
  var valid: Bool {
    switch self {
    case .laser: true
    case .pylon(let index): (0..<32).contains(index)
    case .fuelStorage(let index): (0..<FuelStorage.maximumCount).contains(index)
    case .module(let name): OwnedGearKind.module(name).valid
    }
  }
  func accepts(_ kind: OwnedGearKind) -> Bool {
    switch (self, kind) {
    case (.laser, .laser), (.pylon, .missile), (.fuelStorage, .fuelStorage): true
    case (.module(let slot), .module(let name)): slot == name
    default: false
    }
  }
}
public struct OwnedGear: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let kind: OwnedGearKind
  public var preferredSlot: OwnedGearSlot
  public var fittedSlot: OwnedGearSlot?
  public var condition: Int
  public var modifications: [String: Int]
  public var issuedBy: UUID?
  public var sourceResource: String?
  public var loanOwner: UUID?
  public init(id: UUID = UUID(), kind: OwnedGearKind, slot: OwnedGearSlot) {
    self.id = id
    self.kind = kind
    preferredSlot = slot
    fittedSlot = slot
    condition = 10000
    modifications = [:]
  }
  var valid: Bool {
    kind.valid && preferredSlot.valid && preferredSlot.accepts(kind)
      && (fittedSlot.map { $0.valid && $0.accepts(kind) } ?? true)
      && (0...10000).contains(condition) && modifications.count <= 32
      && modifications.allSatisfy {
        PackValidation.localID($0.key) && (-100000...100000).contains($0.value)
      }
      && (fittedSlot == nil || (condition == 10000 && modifications.isEmpty))
  }
}
public struct OwnedEquipmentInventory: Codable, Sendable, Equatable {
  public var items: [OwnedGear] = []
  public init() {}
  public var stored: [OwnedGear] { items.filter { $0.fittedSlot == nil } }
  public var fitted: [OwnedGear] { items.filter { $0.fittedSlot != nil } }
  public var valid: Bool {
    let slots = fitted.compactMap(\.fittedSlot)
    return items.count <= 10000 && Set(items.map(\.id)).count == items.count
      && Set(slots).count == slots.count && items.allSatisfy(\.valid)
  }
}
extension Commander {
  mutating func storeOwnedModules(_ names: Set<String>, keeping: String) {
    guard var inventory = ownedEquipment else { return }
    for index in inventory.items.indices {
      let item = inventory.items[index]
      if item.fittedSlot != nil, case .module(let name) = item.kind,
        names.contains(name), name != keeping
      {
        inventory.items[index].fittedSlot = nil
      }
    }
    ownedEquipment = inventory
  }
  mutating func storeReplacedLaser(on mount: LaserMount, by kind: LaserKind) {
    guard var inventory = ownedEquipment, laser(on: mount) != kind,
      let index = inventory.items.firstIndex(where: { $0.fittedSlot == .laser(mount) })
    else { return }
    inventory.items[index].fittedSlot = nil
    ownedEquipment = inventory
  }
  var actualEquipmentSlots: [(OwnedGearKind, OwnedGearSlot)] {
    var result: [(OwnedGearKind, OwnedGearSlot)] = []
    for mount in LaserMount.allCases {
      if let laser = laser(on: mount) { result.append((.laser(laser), .laser(mount))) }
    }
    for index in 0..<max(0, min(32, missiles)) { result.append((.missile, .pylon(index))) }
    for name in equipment.sorted() where OwnedGearKind.module(name).valid {
      result.append((.module(name), .module(name)))
    }
    for index in 0..<max(0, min(FuelStorage.maximumCount, fuelStorageUnits)) {
      result.append((.fuelStorage, .fuelStorage(index)))
    }
    return result
  }
  mutating func synchronizeEquipmentInventory(force: Bool = false) {
    guard force || ownedEquipment != nil else { return }
    let importing = ownedEquipment == nil
    var inventory = ownedEquipment ?? OwnedEquipmentInventory()
    let actual = actualEquipmentSlots
    // Consumption/replacement removes only the actual fitted item. Stored gear is never ammunition.
    inventory.items.removeAll { item in
      guard let slot = item.fittedSlot else { return false }
      return !actual.contains { $0.0 == item.kind && $0.1 == slot }
    }
    for (kind, slot) in actual where !inventory.items.contains(where: { $0.fittedSlot == slot }) {
      let identity: UUID
      if importing {
        // Pure legacy previews need no random draw. Ownership starts only at Confirm.
        let source =
          "legacy-player-gear-v1:\(name):\(shipID):\(galaxy):\(system):\(kills):\(slot.stableKey):\(kind.name)"
        let bytes = Array(SHA256.hash(data: Data(source.utf8)))
        identity = UUID(
          uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
          ))
      } else {
        identity = UUID()
      }
      inventory.items.append(OwnedGear(id: identity, kind: kind, slot: slot))
    }
    ownedEquipment = inventory
  }
  var ownedEquipmentValid: Bool {
    guard let inventory = ownedEquipment else { return true }
    let actual = actualEquipmentSlots
    let fitted = inventory.fitted
    return inventory.valid && fitted.count == actual.count
      && actual.allSatisfy { kind, slot in
        fitted.contains { $0.kind == kind && $0.fittedSlot == slot }
      }
  }
  func ownedGearCounts(fitted: Bool) -> ScriptValue {
    let kinds =
      ownedEquipment.map { (fitted ? $0.fitted : $0.stored).map(\.kind) }
      ?? (fitted ? actualEquipmentSlots.map(\.0) : [])
    return .object(Dictionary(grouping: kinds, by: \.name).mapValues { .integer(Int64($0.count)) })
  }
}
