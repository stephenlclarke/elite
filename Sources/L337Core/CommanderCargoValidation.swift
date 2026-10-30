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
    guard addCheckedMissionCargo(total: &total) else { return nil }
    guard addCheckedFittedCargo(total: &total) else { return nil }
    guard addCheckedRescueReservationCargo(total: &total) else { return nil }
    guard addCheckedUtilityCargo(total: &total) else { return nil }
    guard addCheckedRescuedPodsCargo(total: &total) else { return nil }
    guard addCheckedStoredMassCargo(total: &total) else { return nil }
    guard addCheckedCommoditiesCargo(total: &total) else { return nil }
    return total
  }

  @inline(never)
  private func addCheckedMissionCargo(total: inout Int) -> Bool {
    guard scriptState.instances.count <= 128, accommodation.ownedBerths.count <= 10000 else {
      return false
    }
    for instance in scriptState.instances.values {
      guard Self.addCheckedInstanceCargo(instance, total: &total) else { return false }
    }
    return true
  }

  @inline(never)
  private static func addCheckedInstanceCargo(
    _ instance: borrowing ScriptInstance, total: inout Int
  ) -> Bool {
    guard addCheckedNavigationInstanceCargo(instance, total: &total) else { return false }
    guard addCheckedSeedInstanceCargo(instance, total: &total) else { return false }
    guard addCheckedWorkshopInstanceCargo(instance, total: &total) else { return false }
    guard addCheckedClinicInstanceCargo(instance, total: &total) else { return false }
    guard addCheckedPayloadsInstanceCargo(instance, total: &total) else { return false }
    return true
  }

  @inline(never)
  private static func addCheckedNavigationInstanceCargo(
    _ instance: borrowing ScriptInstance, total: inout Int
  ) -> Bool {
    // The confirmed practice reserves one slot, then transfers that same slot to actual cargo.
    if instance.hasAwaitingBuyNavigationTrade {
      let reserved = total.addingReportingOverflow(1)
      guard !reserved.overflow else { return false }
      total = reserved.partialValue
    }
    return true
  }

  @inline(never)
  private static func addCheckedSeedInstanceCargo(
    _ instance: borrowing ScriptInstance, total: inout Int
  ) -> Bool {
    let seedTonnes = instance.reservedSeedCargoTonnes
    guard (0...3).contains(seedTonnes) else { return false }
    let seed = total.addingReportingOverflow(seedTonnes)
    guard !seed.overflow else { return false }
    total = seed.partialValue
    return true
  }

  @inline(never)
  private static func addCheckedWorkshopInstanceCargo(
    _ instance: borrowing ScriptInstance, total: inout Int
  ) -> Bool {
    let workshopTonnes = instance.reservedWorkshopCargoTonnes
    guard (0...2).contains(workshopTonnes) else { return false }
    let workshop = total.addingReportingOverflow(workshopTonnes)
    guard !workshop.overflow else { return false }
    total = workshop.partialValue
    return true
  }

  @inline(never)
  private static func addCheckedClinicInstanceCargo(
    _ instance: borrowing ScriptInstance, total: inout Int
  ) -> Bool {
    let clinicTonnes = instance.reservedClinicCargoTonnes
    guard (0...1).contains(clinicTonnes) else { return false }
    let clinic = total.addingReportingOverflow(clinicTonnes)
    guard !clinic.overflow else { return false }
    total = clinic.partialValue
    return true
  }

  @inline(never)
  private static func addCheckedPayloadsInstanceCargo(
    _ instance: borrowing ScriptInstance, total: inout Int
  ) -> Bool {
    let payloads = instance.retainedCargoPayloads
    guard payloads.count <= 128,
      payloads.values.allSatisfy({ (0...1_000_000).contains($0) })
    else { return false }
    for payload in payloads.values {
      let addition = total.addingReportingOverflow(payload)
      guard !addition.overflow else { return false }
      total = addition.partialValue
    }
    return true
  }

  @inline(never)
  private func addCheckedFittedCargo(total: inout Int) -> Bool {
    let programmer = total.addingReportingOverflow(
      NativeIsolationProgrammerDefinition.occupiedTonnes(in: equipmentInventory))
    guard !programmer.overflow else { return false }
    total = programmer.partialValue
    let cabins = accommodation.fittedCabins.count.multipliedReportingOverflow(
      by: AccommodationFitting.tonnesPerCabin)
    guard !cabins.overflow else { return false }
    let occupied = total.addingReportingOverflow(cabins.partialValue)
    guard !occupied.overflow else { return false }
    total = occupied.partialValue
    return true
  }

  @inline(never)
  private func addCheckedRescueReservationCargo(total: inout Int) -> Bool {
    // The exact original pod fulfils this reserved tonne. Care restores the reservation;
    // the original physical record fulfils it last, without another or disappearing tonne.
    if let rescue = nativePeople?.originalRescue, rescue.reservedCargoTonnes > 0 {
      let pod = nativePeople?.heldPods.contains(where: { $0.person.rescue != nil }) == true
      if !pod {
        let reserved = total.addingReportingOverflow(1)
        guard !reserved.overflow else { return false }
        total = reserved.partialValue
      }
    }
    return true
  }

  @inline(never)
  private func addCheckedUtilityCargo(total: inout Int) -> Bool {
    let utility = total.addingReportingOverflow(nativeUtility?.heldTonnes ?? 0)
    guard !utility.overflow else { return false }
    total = utility.partialValue
    return true
  }

  @inline(never)
  private func addCheckedRescuedPodsCargo(total: inout Int) -> Bool {
    let rescue = total.addingReportingOverflow(rescuedPodTonnes)
    guard !rescue.overflow else { return false }
    total = rescue.partialValue
    return true
  }

  @inline(never)
  private func addCheckedStoredMassCargo(total: inout Int) -> Bool {
    guard alienStorageStateValid else { return false }
    // Combine actual stored mass before rounding once. Fitted modules and applied
    // upgrades no longer occupy cargo space.
    let recorderMass = scriptState.instances.values.reduce(0.0) { mass, mission in
      mass + (mission.hasHeldGlassMeridianRecorder ? 8 : 0)
    }
    let mass =
      salvageLedger.inventoryMassKg + (alienStorageState?.current.storedMassKg ?? 0) + recorderMass
    let tonnes = ceil(mass / 1000)
    guard mass.isFinite, mass >= 0, tonnes.isFinite, tonnes < Double(Int.max) else { return false }
    let reserved = total.addingReportingOverflow(Int(tonnes))
    guard !reserved.overflow else { return false }
    total = reserved.partialValue
    return true
  }

  @inline(never)
  private func addCheckedCommoditiesCargo(total: inout Int) -> Bool {
    for (amount, commodity) in zip(cargo, Commodity.all) where commodity.unit == "t" {
      let addition = total.addingReportingOverflow(amount)
      guard !addition.overflow else { return false }
      total = addition.partialValue
    }
    return true
  }

}
