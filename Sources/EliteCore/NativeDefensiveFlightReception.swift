import Foundation

enum NativeDefensiveFlightReception {
  static func allowed(
    state: NativeDefensiveFlightState, provider: NativePracticeState,
    dock: NativeMainStationDockReceipt, owner: UUID, carrier: UUID
  ) -> Bool {
    guard state.ready, state.permission.owner == owner, state.permission.carrier == carrier,
      state.matches(provider), provider.endedAt != nil,
      let calendar = state.disengagedCalendar, dock.valid, dock.commanderOwner == owner,
      dock.station == state.permission.dock.station, dock.sequence > state.permission.dock.sequence,
      dock.calendarSeconds > calendar,
      let original = state.original, dock.actor.visit >= original.permission.player.visit
    else { return false }
    return true
  }
}
