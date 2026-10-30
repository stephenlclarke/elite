import Foundation

extension Commander {
  public static let xyzzyStartingCredits = 10_000_000
  mutating func startXYZzyCash() {
    if !xyzzyCashGranted { credits = Self.xyzzyStartingCredits }
    xyzzyCashGranted = true
    unlimitedCash = false
  }
  /// Recognise old Clarke cheat saves, without changing ordinary commanders' balances.
  mutating func migrateXYZzyPolicy() {
    let legacyXYZzy = name == "CLARKE" && (unlimitedMissiles || unlimitedCargo || autoTrade)
    guard xyzzyActive || legacyXYZzy else { return }
    if unlimitedCash && !xyzzyCashGranted { credits = Self.xyzzyStartingCredits }
    xyzzyCashGranted = true
    unlimitedCash = false
    unlimitedJumps = false
    xyzzyActive = true
  }
}
extension Equipment {
  public static func isReward(_ name: String) -> Bool {
    [navalLaser, ShieldBooster.capital.equipmentName].contains(name)
  }
  public static func rewardLabel(_ name: String) -> String {
    if name == navalLaser { return "XYZZY grant" }
    if name == navalEnergyUnit { return "Naval reward" }
    return "Elite reward"
  }
}
