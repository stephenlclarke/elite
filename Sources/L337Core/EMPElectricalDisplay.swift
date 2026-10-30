import Foundation

extension Game {
  var electricalHUDLines: [String] {
    var lines: [String] = []
    if let reserve = commander.savedPlayerElectrical {
      let capacity = commander.performance.energy
      let power = min(capacity, reserve.remaining)
      lines.append(
        "POWER: " + String(format: "%.1f / %.1f", power, capacity)
          + (playerEMPDisabled ? " - DISABLED" : ""))
    }
    if let charge = commander.savedEMPCharge {
      switch charge.phase {
      case .charging:
        let remaining = max(0, charge.startedAt + 10 - commander.flightSimulation.physicalTime)
        lines.append("EMP CHARGE: " + String(format: "%.1f S", remaining))
      case .cancelled:
        lines.append(charge.cancellingECM == nil ? "EMP: CANCELLED" : "EMP: CANCELLED BY ECM")
      case .released: break
      }
    }
    return lines
  }
}
