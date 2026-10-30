import Foundation

public enum ScriptCalendarOrigin: String, Codable, Sendable {
  case newCommander, inactiveLegacyMigration
}
public enum ScriptCalendarAdjustmentKind: String, Codable, Sendable { case launch, jump }

public struct ScriptCalendarAdjustment: Codable, Sendable, Equatable {
  public let operation: UInt64
  public let kind: ScriptCalendarAdjustmentKind
  public let seconds: Double
  public let before: Double
  public let after: Double
  var valid: Bool {
    operation > 0 && operation < UInt64(Int64.max)
      && [seconds, before, after].allSatisfy { $0.isFinite && (0...1e12).contains($0) }
      && after == before + seconds
  }
}

public struct ScriptCalendarJourney: Codable, Sendable, Equatable {
  public let operation: UInt64
  public let galaxy: Int
  public let origin: Int
  public let destination: Int
  public let sourceDistance: Double
  public let nativeFuelDebit: Int
  public var seconds: Double { sourceDistance * sourceDistance * 3600 }
  var valid: Bool {
    operation > 0 && operation < UInt64(Int64.max) && (0..<8).contains(galaxy)
      && (0...256).contains(origin) && (0...256).contains(destination) && origin != destination
      && sourceDistance.isFinite && (0...200).contains(sourceDistance)
      && (0...10_000).contains(nativeFuelDebit)
  }
}

/// Selected source-style calendar, with a labelled project epoch and actual native operations.
public struct ScriptCalendarLedger: Codable, Sendable, Equatable {
  public let profile: String
  public let origin: ScriptCalendarOrigin
  public var operation: UInt64 = 0
  public var lastAdjustment: ScriptCalendarAdjustment?
  public var pendingJourney: ScriptCalendarJourney?
  public var legacyUntrackedJourney = false
  public init(origin: ScriptCalendarOrigin) {
    self.origin = origin
    profile = "project-oolite-calendar-v1"
  }
  var valid: Bool {
    profile == "project-oolite-calendar-v1" && operation < UInt64(Int64.max)
      && (lastAdjustment.map { $0.valid && $0.operation <= operation } ?? true)
      && (pendingJourney.map { $0.valid && $0.operation == operation } ?? true)
      && !(legacyUntrackedJourney && pendingJourney != nil)
      && (!legacyUntrackedJourney || origin == .inactiveLegacyMigration)
  }
}

public struct ScriptPulseCounter: Codable, Sendable, Equatable {
  public var value: Int64 = 0
  public var enabled = true
  public var resetOnNextPulse = false
  public init() {}
  var valid: Bool { (0...1_000_000_000).contains(value) }
  /// Source preincrement, except that the requested reset pulse is zero itself.
  mutating func fire() -> Bool {
    guard enabled else { return false }
    if resetOnNextPulse {
      value = 0
      resetOnNextPulse = false
      return true
    }
    if value < 1_000_000_000 { value += 1 }
    return false
  }
}

extension StarSystem {
  /// Native coordinates are already Cartesian light-years; calendar charging uses that unit.
  /// The launch charge and quadratic journey-time policy remain separate from flight fuel.
  func scriptCalendarDistance(to other: StarSystem) -> Double {
    distance(to: other)
  }
}
