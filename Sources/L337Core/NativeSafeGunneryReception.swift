import Foundation

enum NativeSafeGunneryReception {
  /// Native callers must independently establish that this is the actual current doorway receipt.
  /// This pure join never treats reaching the range, ending a timer or opening a board as reception.
  static func allowed(
    state: NativeSafeGunneryState, provider: NativePracticeState,
    dock: NativeMainStationDockReceipt, owner: UUID, carrier: UUID
  ) -> Bool {
    state.ready && state.permission.owner == owner && state.permission.carrier == carrier
      && dock.valid && dock.commanderOwner == owner
      && dock.station == state.permission.dock.station
      && dock.sequence > state.permission.dock.sequence
      && dock.calendarSeconds >= state.permission.dock.calendarSeconds
      && state.progress?.matches(provider) == true
      && state.progress.map({ dock.actor.visit >= $0.original.permission.player.visit }) == true
  }
}
