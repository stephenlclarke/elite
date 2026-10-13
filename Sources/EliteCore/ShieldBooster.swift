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
  public var shieldBooster: ShieldBooster? { equipment.compactMap(ShieldBooster.from).max() }
  public var shieldCapacity: Double { 255 * (shieldBooster?.multiplier ?? 1) }
  public var effectiveLaser: String { activeLaser?.equipmentName ?? "None" }
  public mutating func installShieldBooster(_ booster: ShieldBooster) {
    let effective = max(booster, shieldBooster ?? booster)
    equipment.subtract(ShieldBooster.allCases.map(\.equipmentName))
    equipment.insert(effective.equipmentName)
  }
}
extension Game {
  mutating func applyDamage(_ damage: Double, front: Bool, energyMultiplier: Double = 1) {
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
    commander.capitalRewardClaimed = true
    let oldCapacity = commander.shieldCapacity
    commander.installShieldBooster(.capital)
    frontShield = frontShield / oldCapacity * commander.shieldCapacity
    rearShield = rearShield / oldCapacity * commander.shieldCapacity
    notify("ELITE BONUS: CAPITAL SHIP SHIELD BOOSTER")
  }
}
