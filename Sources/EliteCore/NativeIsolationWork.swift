import Foundation

/// Input contract for the separate G11 acceptance producer. No factory or fallback
/// exists here: P02 must authenticate the real parent permission before it can mint this value.
struct NativeIsolationWorkParentAuthority: Equatable, Sendable {
  let parentID: UUID
  let parentDigest: String
  let authorization: UUID
  let owner: UUID
  let issuer: UUID
  let acceptance: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64

  private init(
    parentID: UUID, parentDigest: String, authorization: UUID, owner: UUID, issuer: UUID,
    acceptance: NativeMainStationDockReceipt, carrier: UUID, inventoryRevision: UInt64
  ) {
    self.parentID = parentID
    self.parentDigest = parentDigest
    self.authorization = authorization
    self.owner = owner
    self.issuer = issuer
    self.acceptance = acceptance
    self.carrier = carrier
    self.inventoryRevision = inventoryRevision
  }
}

/// These accounts are local utility energy, separate from hull integrity and player resources.
struct NativeIsolationEnergyAccounts: Codable, Equatable, Sendable {
  static let capacity = 10000.0
  private(set) var remainingSupply = capacity
  private(set) var deliveredLoad = 0.0
  var headroom: Double { Self.capacity - deliveredLoad }
  var valid: Bool {
    remainingSupply.isFinite && deliveredLoad.isFinite
      && (0...Self.capacity).contains(remainingSupply)
      && (0...Self.capacity).contains(deliveredLoad)
      && abs(remainingSupply + deliveredLoad - Self.capacity) < 1e-7
  }

  /// Called by the attained native producer; the canonical contact controls real transfer.
  mutating func transfer(seconds: Double, contact: NativeIsolationContact) throws -> Double {
    guard valid, contact.valid, seconds.isFinite, seconds > 0, seconds <= 0.100001 else {
      throw SaveError.invalidCommander
    }
    guard case .connected = contact else { return 0 }
    let amount = min(seconds, remainingSupply, headroom)
    deliveredLoad += amount
    remainingSupply = Self.capacity - deliveredLoad
    guard valid else { throw SaveError.invalidCommander }
    return amount
  }
}

/// This is the actual producer disconnect, not a journal completion flag.
enum NativeIsolationContact: Codable, Equatable, Sendable {
  case connected
  case latchedOpen(operation: UUID, revision: UInt64)
  var valid: Bool {
    switch self {
    case .connected: true
    case .latchedOpen(_, let revision): revision > 0 && revision < UInt64(Int64.max)
    }
  }
}

enum NativeIsolationWorkEnvelope {
  static let requiredWork = 20.0
  static let requiredObservation = 1.0
  static let maximumSegments = 256

  static func qualifies(range: Double, speed: Double, aim: Double) -> Bool {
    range.isFinite && (50...150).contains(range)
      && speed.isFinite && (0...1).contains(speed)
      && aim.isFinite && (0...(2 * Double.pi / 180)).contains(aim)
  }
  static func interval(start: Double, end: Double) -> Double? {
    guard start.isFinite, end.isFinite, start >= 0, end > start, end <= 1e12,
      end - start <= 0.100001
    else { return nil }
    return end - start
  }
}

/// Historical measurement facts never restore a live arm or its runtime epoch.
struct NativeIsolationMeasurementAuthority: Codable, Equatable, Sendable {
  let parent: UUID
  let authorization: UUID
  let owner: UUID
  let source: UUID
  let role: NativeIsolationWorkRole
  let module: UUID
  let issueOperation: UUID
  let programmer: UUID
  let carrier: UUID
  let inventoryRevision: UInt64
  let actor: ActorIdentity
  let player: ActorIdentity

  var valid: Bool {
    let original = NativeIsolationWorkSource(owner: owner)
    return source == original.id && module == original.module(role)
      && actor.system == NativeIsolationWorkSource.location && actor.entity > 1
      && actor.entity < UInt64(Int64.max) && actor.visit > 0
      && actor.visit < UInt64(Int64.max) && player.system == actor.system
      && player.visit == actor.visit && player.entity == 0
      && inventoryRevision < UInt64(Int64.max)
  }
}

enum NativeIsolationMeasurementPhase: String, Codable, Sendable {
  case work, observation
  var requiredSeconds: Double {
    self == .work
      ? NativeIsolationWorkEnvelope.requiredWork
      : NativeIsolationWorkEnvelope.requiredObservation
  }
}

struct NativeIsolationWorkSegment: Codable, Equatable, Sendable {
  let authority: NativeIsolationMeasurementAuthority
  let phase: NativeIsolationMeasurementPhase
  let first: Double
  var last: Double
  var seconds: Double
  var intervals: UInt64
  var lastRange: Double
  var lastSpeed: Double
  var lastAim: Double

  var valid: Bool {
    authority.valid && first.isFinite && last.isFinite && first >= 0 && last > first
      && last <= 1e12 && seconds.isFinite && seconds > 0
      && seconds <= phase.requiredSeconds + 1e-8 && seconds <= last - first + 1e-7
      && intervals > 0 && intervals < 1_000_000_000
      && seconds <= Double(intervals) * 0.100001 + 1e-7
      && NativeIsolationWorkEnvelope.qualifies(range: lastRange, speed: lastSpeed, aim: lastAim)
  }
}

/// Qualifying intervals with the same authority coalesce, including a 60 Hz twenty-second run.
/// Gaps add no time. A history slot records a distinct authority, never a simulation frame.
struct NativeIsolationWorkHistory: Codable, Equatable, Sendable {
  private(set) var segments: [NativeIsolationWorkSegment] = []
  func seconds(_ phase: NativeIsolationMeasurementPhase) -> Double {
    segments.filter { $0.phase == phase }.reduce(0) { $0 + $1.seconds }
  }
  var valid: Bool {
    guard segments.count <= NativeIsolationWorkEnvelope.maximumSegments,
      segments.allSatisfy(\.valid),
      zip(segments, segments.dropFirst()).allSatisfy({ $0.last <= $1.first }),
      [NativeIsolationMeasurementPhase.work, .observation].allSatisfy({
        seconds($0).isFinite && seconds($0) <= $0.requiredSeconds + 1e-8
      })
    else { return false }
    guard let observation = segments.firstIndex(where: { $0.phase == .observation }) else {
      return true
    }
    return abs(seconds(.work) - NativeIsolationWorkEnvelope.requiredWork) < 1e-8
      && segments[observation...].allSatisfy { $0.phase == .observation }
  }

  /// Pure history accounting. Only private native endpoint/meter producers supply runtime facts.
  mutating func record(
    authority: NativeIsolationMeasurementAuthority, phase: NativeIsolationMeasurementPhase,
    start: Double, end: Double, range: Double, speed: Double, aim: Double
  ) throws {
    guard valid, authority.valid,
      let interval = NativeIsolationWorkEnvelope.interval(start: start, end: end),
      NativeIsolationWorkEnvelope.qualifies(range: range, speed: speed, aim: aim),
      start >= (segments.last?.last ?? 0)
    else { throw SaveError.invalidCommander }
    if phase == .observation {
      guard abs(seconds(.work) - NativeIsolationWorkEnvelope.requiredWork) < 1e-8 else {
        throw SaveError.invalidCommander
      }
    } else if segments.contains(where: { $0.phase == .observation }) {
      throw SaveError.invalidCommander
    }
    let credit = min(interval, max(0, phase.requiredSeconds - seconds(phase)))
    guard credit > 0 else { return }
    if var last = segments.last, last.authority == authority, last.phase == phase,
      last.intervals < 999_999_999
    {
      last.last = end
      last.seconds += credit
      last.intervals += 1
      last.lastRange = range
      last.lastSpeed = speed
      last.lastAim = aim
      segments[segments.count - 1] = last
    } else {
      guard segments.count < NativeIsolationWorkEnvelope.maximumSegments else {
        throw SaveError.invalidCommander
      }
      segments.append(
        .init(
          authority: authority, phase: phase, first: start, last: end, seconds: credit,
          intervals: 1, lastRange: range, lastSpeed: speed, lastAim: aim))
    }
    guard valid else { throw SaveError.invalidCommander }
  }
}
