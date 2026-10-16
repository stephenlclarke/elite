import Foundation

public enum FlightAnnouncement: Sendable, Equatable {
  case missileDetected, ecmActivated
  case missilesDestroyed(Int)
  case incomingIdentified
  case enemyTargeted(String)
  case missileLaunched(String)
  case cannotRetaliate(String)
  case gameplay(String)
  var urgentGameplay: Bool {
    guard case .gameplay(let text) = self else { return false }
    return ["ENERGY LOW", "COLLISION", "GAME OVER", "INCOMING MISSILE"].contains {
      text.uppercased().contains($0)
    }
  }
  public var text: String {
    switch self {
    case .gameplay(let text): return text
    case .incomingIdentified: return "Incoming missile identified"
    case .enemyTargeted(let identity): return "Enemy craft targeted, " + identity
    case .missileLaunched(let identity): return "Missile launched at enemy craft, " + identity
    case .cannotRetaliate(let reason): return "Unable to retaliate, " + reason
    case .missileDetected: return "Missile Detected"
    case .ecmActivated: return "ECM Activated"
    case .missilesDestroyed(let count):
      return "\(count) \(count == 1 ? "missile" : "missiles") destroyed by ECM"
    }
  }
}
public struct SpeechEvent: Sendable, Equatable {
  public let id: Int
  public let announcement: FlightAnnouncement
}

/// A destruction belongs to the player's field only while its activation is live.
public struct ECMControl: Sendable {
  public private(set) var events: [SpeechEvent] = []
  public private(set) var epoch = UUID()
  private var nextEvent = 0
  private var seen: Set<Int> = []
  /// Preserve the native 32-frame field at the documented 60 Hz reference cadence.
  public static let referenceFramesPerSecond = 60.0
  public static let fieldDuration = 32.0 / referenceFramesPerSecond
  public private(set) var remainingDuration = 0.0
  private var ownedActivation = false
  private static let completionTolerance = 1e-10
  public var fieldActive: Bool { remainingDuration > 0 }
  var legacyFrames: Int { Self.legacyFrames(forRemainingDuration: remainingDuration) ?? 0 }
  static func legacyFrames(forRemainingDuration duration: Double) -> Int? {
    guard duration.isFinite, duration >= 0 else { return nil }
    guard duration > 0 else { return 0 }
    let frames = ceil(max(0, duration * Self.referenceFramesPerSecond - 1e-9))
    return frames >= Double(Int.max) ? Int.max : Int(frames)
  }
  /// Explicit save admission restores time, without inheriting live activation ownership or events.
  @discardableResult
  mutating func restoreRemainingDuration(_ duration: Double) -> Bool {
    guard duration.isFinite,
      (0...(1024.0 / Self.referenceFramesPerSecond)).contains(duration)
    else { return false }
    self = ECMControl()
    remainingDuration = duration
    return true
  }
  /// Compatibility writes use the same clock; refreshing an owned field retains its owner.
  mutating func setLegacyFrames(_ frames: Int) {
    guard frames > 0 else {
      finishField()
      return
    }
    remainingDuration = Double(frames) / Self.referenceFramesPerSecond
  }
  mutating func activateExternalField() {
    finishField()
    remainingDuration = Self.fieldDuration
  }
  public private(set) var activation = 0
  public var ownFieldActive: Bool { fieldActive && ownedActivation }
  private var destroyed = 0
  public init() {}
  mutating func emit(_ announcement: FlightAnnouncement) {
    nextEvent += 1
    events.append(.init(id: nextEvent, announcement: announcement))
    if events.count > 32 { events.removeFirst(events.count - 32) }
  }
  mutating func detect(_ bodies: [SpaceBody]) -> Bool {
    let ids = Set(bodies.filter { $0.enemyMissile && $0.energy > 0 }.map(\.id))
    let fresh = !ids.subtracting(seen).isEmpty
    seen = ids
    if fresh { emit(.missileDetected) }
    return !ids.isEmpty
  }
  mutating func activate(destroyed count: Int) {
    remainingDuration = Self.fieldDuration
    ownedActivation = true
    activation += 1
    destroyed = count
    emit(.ecmActivated)
  }
  mutating func recordDestruction() {
    if ownFieldActive { destroyed += 1 }
  }
  mutating func advance(delta: Double = 1.0 / ECMControl.referenceFramesPerSecond) {
    guard delta.isFinite, delta > 0, fieldActive else { return }
    remainingDuration = max(0, remainingDuration - delta)
    if remainingDuration <= Self.completionTolerance { finishField() }
  }
  private mutating func finishField() {
    remainingDuration = 0
    if ownedActivation && destroyed > 0 { emit(.missilesDestroyed(destroyed)) }
    destroyed = 0
    ownedActivation = false
  }

}

extension Game {
  mutating func detectIncomingMissiles() {
    let incoming = ecmControl.detect(bodies)
    detectRetaliationSources()
    if incoming && commander.xyzzyActive && commander.autoECM && ecmFrames == 0 { ecm() }
  }
}

/// Coalesce a backlog into one ordered detection/activation/outcome cycle.
public struct AnnouncementQueue: Sendable {
  public private(set) var pending: [FlightAnnouncement] = []
  public init() {}
  public mutating func append(_ values: [FlightAnnouncement]) {
    for value in values {
      if case .gameplay = value, pending.last == value { continue }
      if case .gameplay = value, !value.urgentGameplay {
        pending.append(value)
      } else {
        let index =
          pending.firstIndex {
            if case .gameplay = $0 { return !$0.urgentGameplay }
            return false
          } ?? pending.endIndex
        pending.insert(value, at: index)
      }
    }
    if pending.count > 24 { coalesce() }
  }
  private mutating func coalesce() {
    let old = pending
    pending = []
    for value in [FlightAnnouncement.missileDetected, .incomingIdentified] where old.contains(value)
    { pending.append(value) }
    if let target = old.last(where: {
      if case .enemyTargeted = $0 { return true }
      return false
    }) {
      pending.append(target)
    }
    if old.contains(.ecmActivated) { pending.append(.ecmActivated) }
    let count = old.reduce(0) { sum, value in
      if case .missilesDestroyed(let count) = value { return sum + count }
      return sum
    }
    if count > 0 { pending.append(.missilesDestroyed(count)) }
    for kind in 0...1 {
      if let value = old.last(where: { value in
        if kind == 0, case .missileLaunched = value { return true }
        if kind == 1, case .cannotRetaliate = value { return true }
        return false
      }) {
        pending.append(value)
      }
    }
    let messages = old.filter {
      if case .gameplay = $0 { return true }
      return false
    }
    pending.append(contentsOf: messages.suffix(8))
  }
  public mutating func next() -> String? { pending.isEmpty ? nil : pending.removeFirst().text }
  public mutating func clear() { pending = [] }
}
