import Foundation

/// The terminal mission keeps its historical snapshot; only the native ledger retires cargo.
enum WayfarerFieldReliefRetirement {
  static func permits(
    _ state: borrowing ScriptInstance, native: NativeUtilityConsignment,
    action: NativeUtilityAction?, targetVisit: UInt64?, currentVisit: UInt64,
    physicalTime: Double
  ) -> Bool {
    guard state.outcome == .failed, let leaf = state.savedFieldRelief,
      leaf.terminalReason == "targetDestroyed", leaf.job.phase == .held,
      (action == nil && native.phase == .lost)
        || (action == .returnMaterials && native.phase == .returned)
    else { return false }
    return joins(
      leaf, native: native, targetVisit: targetVisit, currentVisit: currentVisit,
      physicalTime: physicalTime)
  }

  static func joins(
    _ leaf: WayfarerFieldReliefCustody, native: NativeUtilityConsignment,
    targetVisit: UInt64?, currentVisit: UInt64, physicalTime: Double
  ) -> Bool {
    if leaf.job == native { return true }
    guard leaf.terminalReason == "targetDestroyed", leaf.job.phase == .held,
      let targetVisit, targetVisit > 0, targetVisit <= currentVisit,
      native.installation == nil, native.reception == nil
    else { return false }
    var historical = native
    switch native.phase {
    case .lost:
      guard native.returned == nil, let loss = native.loss, loss.valid,
        loss.visit >= max(targetVisit, native.source.visit), loss.visit <= currentVisit,
        physicalTime.isFinite, physicalTime >= 0, loss.physicalTime <= physicalTime
      else { return false }
      // Native physical time and script calendar/flight time are different clocks.
      historical.loss = nil
    case .returned:
      guard native.loss == nil, let returned = native.returned, returned.valid,
        returned.sequence >= native.source.sequence,
        returned.visit >= max(targetVisit, native.source.visit), returned.visit <= currentVisit,
        returned.calendarSeconds >= native.source.calendarSeconds
      else { return false }
      historical.returned = nil
    default: return false
    }
    historical.phase = .held
    // This comparison retains every original unit, source, hull, route, reach and reward.
    return historical == leaf.job
  }
}
