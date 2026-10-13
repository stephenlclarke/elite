import Foundation

extension Game {
  var currentShowroomProfile: ShipProfile { commander.gameShipProfile }
  func comparableShowroomField(
    _ left: ShipSpec?, _ right: ShipSpec?,
    baseline: ShipProfile?, selected: ShipProfile?
  ) -> Bool {
    if baseline?.group == selected?.group { return true }
    guard baseline?.group == "native-current", let left, let right, left.unit == right.unit else {
      return false
    }
    // Physical capacities/counts share units; engine-specific performance pools do not.
    return ["t", "LY", "0.1 LY", "people", "berths", "missiles", "pylons"].contains(left.unit)
  }
}
