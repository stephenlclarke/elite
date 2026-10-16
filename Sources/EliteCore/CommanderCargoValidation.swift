import Foundation

extension Commander {
  /// Invalid decoded cargo is conservatively full through the public Int accessors.
  /// Admission uses the optional result and refuses it rather than repairing the save.
  var checkedMissionPayloadTonnes: Int? {
    guard missionProgress.count <= 128, missionProgress.values.allSatisfy(\.valid) else {
      return nil
    }
    var total = 0
    for state in missionProgress.values {
      for amount in state.payloads.values {
        let addition = total.addingReportingOverflow(amount)
        guard !addition.overflow else { return nil }
        total = addition.partialValue
      }
    }
    return total
  }

  var checkedCargoTonnes: Int? {
    guard cargo.count == Commodity.all.count,
      cargo.allSatisfy({ $0 >= 0 && $0 <= Int.max / 17 }),
      var total = checkedMissionPayloadTonnes
    else { return nil }
    let mass = salvageLedger.inventoryMassKg
    let tonnes = ceil(mass / 1000)
    guard mass.isFinite, mass >= 0, tonnes.isFinite, tonnes < Double(Int.max) else { return nil }
    let reserved = total.addingReportingOverflow(Int(tonnes))
    guard !reserved.overflow else { return nil }
    total = reserved.partialValue
    for (amount, commodity) in zip(cargo, Commodity.all) where commodity.unit == "t" {
      let addition = total.addingReportingOverflow(amount)
      guard !addition.overflow else { return nil }
      total = addition.partialValue
    }
    return total
  }
}
