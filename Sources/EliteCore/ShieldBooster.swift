import Foundation

public enum ShieldBooster: Int, Sendable, CaseIterable, Comparable {
  case pulse = 1
  case mining, beam, military, capital
  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.multiplier == rhs.multiplier ? lhs.rawValue < rhs.rawValue : lhs.multiplier < rhs.multiplier
  }
  public var label: String {
    switch self {
    case .pulse: "Pulse"
    case .mining: "Mining"
    case .beam: "Beam"
    case .military: "Military"
    case .capital: "Capital Ship"
    }
  }
  public var equipmentName: String { label + " Shield Booster" }
  public var multiplier: Double {
    if self == .capital { return ShieldBooster.military.multiplier * 3 }
    let laser: LaserKind
    switch self {
    case .pulse: laser = .pulse
    case .mining: laser = .mining
    case .beam: laser = .beam
    case .military: laser = .military
    case .capital: laser = .military
    }
    return 1.5 * (laser.damage / LaserKind.pulse.damage)
  }
  var shopItem: Equipment? {
    guard self != .capital, let laser = Equipment.base.first(where: { $0.name == label + " Laser" })
    else { return nil }
    return .init(name: equipmentName, price: laser.price * 3 / 4, technology: laser.technology)
  }
  static func from(_ name: String) -> Self? { allCases.first { $0.equipmentName == name } }
}
extension Commander {
  public static let eliteThreshold = 6400
  public var shieldBooster: ShieldBooster? {
    if equipmentInventory != nil {
      return fittedEquipment(at: .shield).flatMap { ShieldBooster.from($0.node.key) }
    }
    return equipment.compactMap(ShieldBooster.from).max()
  }
  public var shieldCapacity: Double {
    nativePerformance.shield
      * (fittedComponent(at: .shield)?.statistics[.frontShieldCapacity]
        ?? shieldBooster?.multiplier ?? 1)
  }
  public var rearShieldCapacity: Double {
    nativePerformance.shield
      * (fittedComponent(at: .shield)?.statistics[.rearShieldCapacity]
        ?? shieldBooster?.multiplier ?? 1)
  }
  public var frontShieldRecharge: Double {
    nativePerformance.shieldRecharge
      * (fittedComponent(at: .shield)?.statistics[.frontShieldRecharge] ?? 1)
  }
  public var rearShieldRecharge: Double {
    nativePerformance.shieldRecharge
      * (fittedComponent(at: .shield)?.statistics[.rearShieldRecharge] ?? 1)
  }
  public var effectiveLaser: String { activeLaser?.equipmentName ?? "None" }
  public mutating func installShieldBooster(_ booster: ShieldBooster) {
    let effective = max(booster, shieldBooster ?? booster)
    equipment.subtract(ShieldBooster.allCases.map(\.equipmentName))
    equipment.insert(effective.equipmentName)
  }
}
extension Game {
  mutating func applyDamage(_ damage: Double, front: Bool, energyMultiplier: Double = 1) {
    if damage.isFinite, damage > 0,
      workGuidance != nil || workBraking != nil || selectedFlightTool != .combatLaser
    {
      cancelAutoTarget()
      workFireSuspended = true
      notify("WORK INTERRUPTED - INCOMING DAMAGE")
    }
    let shield = front ? frontShield : rearShield
    energy -= max(0, damage - shield) * energyMultiplier
    if front {
      frontShield = max(0, frontShield - damage)
    } else {
      rearShield = max(0, rearShield - damage)
    }
  }
  mutating func reconcileEliteReward() {
    guard commander.rank == "ELITE", !commander.capitalRewardClaimed else { return }
    var candidate = self
    do {
      try candidate.commander.grantEquipment(
        ShieldBooster.capital.equipmentName, at: .shield, provenance: .reward("elite-rank"))
    } catch {
      notify("ELITE BONUS DEFERRED - EQUIPMENT CUSTODY FULL")
      return
    }
    candidate.commander.capitalRewardClaimed = true
    candidate.preserveEquipmentResourceFractions(from: self)
    self = candidate
    notify("ELITE BONUS: ADVANCED II SHIELD MODULE")
  }
}
