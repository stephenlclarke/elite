import Foundation

extension Game {
  /// Actual retained feature state; canonical native inventory and installed library are not triggers.
  public var requiresScriptDurability: Bool {
    if commander.nativeUtility?.consignments.isEmpty == false { return true }
    if commander.usesEMPSaveVersion || commander.usesAlienStorageSaveVersion { return true }
    if isMissionTrial || commander.legacyOwnedEquipment != nil
      || commander.scriptState.calendarLedger != nil
      || !commander.scriptState.instances.isEmpty || !commander.contracts.boards.isEmpty
      || commander.contracts.rrs != nil
    {
      return true
    }
    return commander.scriptState != ScriptEngineState()
      || commander.accommodation != ShipAccommodation()
  }
}
