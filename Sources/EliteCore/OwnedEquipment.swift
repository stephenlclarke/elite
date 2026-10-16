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
public struct LegacyOwnedEquipmentInventory: Codable, Sendable, Equatable {
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
