import Foundation

/// Derived occupancy only. Existing contract/custody validators retain proof authority.
enum OriginalServiceReservationPolicy {
  static let maximumActive = 3

  static func isContractDefinition(_ definition: String) -> Bool {
    definition.hasPrefix("l337.contract/") || definition.hasPrefix("l337.wayfarer-service/")
  }

  static func occupiesSlot(_ state: borrowing ScriptInstance) -> Bool {
    guard state.outcome == .active else { return false }
    if case .some = state.contract,
      isContractDefinition(state.definition) || state.definition == NativeFlightReception.stateID
        || state.definition == NativeSafeGunnery.stateID
        || state.definition == NativeDefensiveFlight.stateID
    {
      return true
    }
    if case .some = state.savedWayfarerRepairLoop {
      return state.definition == WayfarerRepairLoopDefinition.stateID
    }
    if case .some = state.savedNativeInductionSeed {
      return state.definition == NativeInductionSeedPack.stateID
    }
    if case .some = state.savedNativeInductionWorkshop {
      return state.definition == NativeInductionWorkshopPack.stateID
    }
    if case .some = state.savedNativeInductionClinic {
      return state.definition == NativeInductionClinicPack.stateID
    }
    if case .some = state.savedWayfarerColdChain {
      return WayfarerColdChainDefinition.isNativeDefinition(state.definition)
    }
    return false
  }

  static func activeCount(_ engine: borrowing ScriptEngineState) -> Int {
    var count = 0
    for state in engine.instances.values where occupiesSlot(state) { count += 1 }
    return count
  }

  static func valid(_ engine: borrowing ScriptEngineState) -> Bool {
    activeCount(engine) <= maximumActive
  }

  static func requireAvailableSlot(_ engine: borrowing ScriptEngineState) throws {
    guard activeCount(engine) < maximumActive else {
      throw MissionPackError("Three Original contracts or Wayfarer services are already active.")
    }
  }
}
