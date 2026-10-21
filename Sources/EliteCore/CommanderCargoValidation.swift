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
    guard scriptState.instances.count <= 128, accommodation.ownedBerths.count <= 10000 else {
      return nil
    }
    for instance in scriptState.instances.values {
      // The confirmed practice reserves one slot, then transfers that same slot to actual cargo.
      if instance.savedNavigationTrade?.stage == .awaitingBuy {
        let reserved = total.addingReportingOverflow(1)
        guard !reserved.overflow else { return nil }
        total = reserved.partialValue
      }
      guard instance.payloads.count <= 128,
        instance.payloads.values.allSatisfy({ (0...1_000_000).contains($0) })
      else { return nil }
      for payload in instance.payloads.values {
        let addition = total.addingReportingOverflow(payload)
        guard !addition.overflow else { return nil }
        total = addition.partialValue
      }
    }
    let cabins = accommodation.fittedBerths.count.multipliedReportingOverflow(by: 5)
    guard !cabins.overflow else { return nil }
    let occupied = total.addingReportingOverflow(cabins.partialValue)
    guard !occupied.overflow else { return nil }
    total = occupied.partialValue
    let rescue = total.addingReportingOverflow(rescuedPodTonnes)
    guard !rescue.overflow else { return nil }
    total = rescue.partialValue
    guard alienStorageStateValid else { return nil }
    // Combine actual stored mass before rounding once. Fitted modules and applied
    // upgrades no longer occupy cargo space.
    let mass = salvageLedger.inventoryMassKg + (alienStorageState?.current.storedMassKg ?? 0)
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
