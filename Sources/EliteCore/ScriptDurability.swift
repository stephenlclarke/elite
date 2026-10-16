import Foundation

extension Game {
  /// Actual retained feature state; canonical native inventory and installed library are not triggers.
  public var requiresScriptDurability: Bool {
    if isMissionTrial || commander.legacyOwnedEquipment != nil
      || commander.scriptState.calendarLedger != nil
      || !commander.scriptState.instances.isEmpty || !commander.contracts.boards.isEmpty
    {
      return true
    }
    return commander.scriptState != ScriptEngineState()
      || commander.accommodation != ShipAccommodation()
  }
}
