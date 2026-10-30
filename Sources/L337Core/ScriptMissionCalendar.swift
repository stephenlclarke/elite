import Foundation

/// Additive projection: old calendar consumers retain their original menu semantics.
public struct ScriptMissionCalendar: Codable, Sendable, Equatable {
  public let origin: Double
  public var seconds: Double
  public var lastNativeOperation: UInt64
  var valid: Bool {
    origin.isFinite && seconds.isFinite && (0...1e12).contains(origin)
      && (origin...1e12).contains(seconds) && lastNativeOperation < UInt64(Int64.max)
  }
}
extension Game {
  var missionCalendarActive: Bool { !paused && !docked && screen.isFlight }
  mutating func ensureMissionCalendar() {
    ensureScriptCalendar(origin: .newCommander)
    if commander.scriptState.missionCalendar == nil {
      commander.scriptState.missionCalendar = .init(
        origin: commander.scriptState.calendarSeconds,
        seconds: commander.scriptState.calendarSeconds,
        lastNativeOperation: commander.scriptState.calendarLedger?.operation ?? 0)
    }
  }
  func missionCalendarCanAdd(_ seconds: Double) -> Bool {
    commander.scriptState.missionCalendar.map { $0.seconds <= 1e12 - seconds } ?? true
  }
  mutating func mirrorMissionCalendar(seconds: Double, operation: UInt64) {
    guard var calendar = commander.scriptState.missionCalendar,
      operation > calendar.lastNativeOperation
    else { return }
    calendar.seconds += seconds
    calendar.lastNativeOperation = operation
    commander.scriptState.missionCalendar = calendar
  }
}
