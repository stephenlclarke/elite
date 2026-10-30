import Foundation

struct ProviderMissionObservationTerms: Equatable, Codable, Sendable {
  let contactRange: Double
  let contactSpeed: Double
  let contactSeconds: Double
  let escortRange: Double
  let escortSeconds: Double
  let checkpoints: [Double]
  var maximumDistance: Double { checkpoints.last ?? 0 }
  var completedBits: UInt8 { UInt8((UInt16(1) << checkpoints.count) - 1) }
  var valid: Bool {
    [contactRange, contactSpeed, contactSeconds, escortRange, escortSeconds].allSatisfy {
      $0.isFinite && $0 > 0 && $0 <= 1e9
    }
      && (1...8).contains(checkpoints.count)
      && checkpoints.allSatisfy { $0.isFinite && $0 > 0 && $0 <= 1e9 }
      && zip(checkpoints, checkpoints.dropFirst()).allSatisfy { $0.0 < $0.1 }
  }
  private enum CodingKeys: String, CodingKey {
    case contactRange, contactSpeed, contactSeconds, escortRange, escortSeconds, checkpoints
  }
}
extension ProviderMissionObservationTerms {
  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    checkpoints = try ScriptProviderBounded.array(
      values, key: .checkpoints, type: Double.self, maximum: 8)
    contactRange = try values.decode(Double.self, forKey: .contactRange)
    contactSpeed = try values.decode(Double.self, forKey: .contactSpeed)
    contactSeconds = try values.decode(Double.self, forKey: .contactSeconds)
    escortRange = try values.decode(Double.self, forKey: .escortRange)
    escortSeconds = try values.decode(Double.self, forKey: .escortSeconds)
    guard valid else { throw SaveError.invalidCommander }
  }
}

struct ProviderMissionInterval: Equatable, Sendable {
  let provider: NativeProviderIdentity
  let subject: UUID
  let sceneGeneration: UUID
  let startFrame: UInt64
  let endFrame: UInt64
  let startTime: Double
  let endTime: Double
  let forwardMeters: Double
  let rangeMeters: Double
  let relativeMetersPerSecond: Double
  let actualSensorContact: Bool
  let communications: Bool
  let unpausedFreeFlight: Bool
  let trackingThroughout: Bool
  let continuous: Bool
  var valid: Bool {
    provider.valid && startFrame < endFrame && endFrame < UInt64(Int64.max)
      && [startTime, endTime, forwardMeters, rangeMeters, relativeMetersPerSecond].allSatisfy(
        \.isFinite)
      && startTime >= 0 && endTime > startTime && endTime - startTime <= 0.100001
      && rangeMeters >= 0 && relativeMetersPerSecond >= 0
  }
}

struct ProviderMissionBaseline: Equatable, Codable, Sendable {
  let runtimeEpoch: UUID
  let sceneGeneration: UUID
  let frame: UInt64
  let time: Double
}

struct ProviderMissionProgress: Equatable, Codable, Sendable {
  var requested = false
  var handshakeSeconds = 0.0
  var distanceMeters = 0.0
  var escortSeconds = 0.0
  var checkpointBits: UInt8 = 0
  var baseline: ProviderMissionBaseline?
  func valid(terms: ProviderMissionObservationTerms) -> Bool {
    terms.valid && handshakeSeconds.isFinite
      && (0...terms.contactSeconds).contains(handshakeSeconds)
      && distanceMeters.isFinite && (0...terms.maximumDistance).contains(distanceMeters)
      && escortSeconds.isFinite && (0...terms.escortSeconds).contains(escortSeconds)
      && checkpointBits <= terms.completedBits
      && terms.checkpoints.indices.allSatisfy { index in
        ((checkpointBits & (1 << index)) != 0) == (distanceMeters >= terms.checkpoints[index])
      }
      && (baseline.map {
        $0.frame > 0 && $0.frame < UInt64(Int64.max) && $0.time.isFinite && $0.time >= 0
      } ?? true)
  }
}

enum ProviderMissionObservation {
  static func hasActualContact(
    _ interval: ProviderMissionInterval,
    terms: ProviderMissionObservationTerms
  ) -> Bool {
    interval.valid && terms.valid && interval.actualSensorContact && interval.communications
      && interval.unpausedFreeFlight && interval.rangeMeters <= terms.contactRange
      && interval.relativeMetersPerSecond <= terms.contactSpeed
  }
  struct Result: Equatable, Sendable {
    let progress: ProviderMissionProgress
    let contactCompleted: Bool
    let newCheckpoints: UInt8
    let fullReady: Bool
  }

  /// Folds only an admitted native interval; requested orbit phase is deliberately absent.
  static func fold(
    _ previous: ProviderMissionProgress, interval: ProviderMissionInterval,
    runtimeEpoch: UUID, terms: ProviderMissionObservationTerms,
    manifestReceived: Bool, calibrationOpen: Bool
  ) throws -> Result {
    guard previous.valid(terms: terms), interval.valid else {
      throw MissionPackError("Invalid native route interval.")
    }
    if let baseline = previous.baseline, baseline.runtimeEpoch == runtimeEpoch,
      baseline.sceneGeneration == interval.sceneGeneration
    {
      guard interval.endFrame > baseline.frame, interval.endTime > baseline.time else {
        throw MissionPackError("Native route interval was already observed.")
      }
    }
    var next = previous
    let continuous =
      interval.continuous
      && previous.baseline.map {
        $0.runtimeEpoch == runtimeEpoch && $0.sceneGeneration == interval.sceneGeneration
          && $0.frame == interval.startFrame
          && $0.time == interval.startTime
      } == true
    next.baseline = .init(
      runtimeEpoch: runtimeEpoch, sceneGeneration: interval.sceneGeneration,
      frame: interval.endFrame, time: interval.endTime)
    let contact = continuous && hasActualContact(interval, terms: terms)
    let dt = interval.endTime - interval.startTime
    if !manifestReceived {
      next.handshakeSeconds =
        previous.requested && contact
        ? min(terms.contactSeconds, previous.handshakeSeconds + dt) : 0
      return .init(
        progress: next, contactCompleted: next.handshakeSeconds >= terms.contactSeconds,
        newCheckpoints: 0, fullReady: false)
    }
    let qualified =
      continuous && calibrationOpen && interval.trackingThroughout
      && interval.communications && interval.unpausedFreeFlight
      && interval.rangeMeters <= terms.escortRange
      && interval.forwardMeters >= 0
    if qualified {
      next.distanceMeters = min(
        terms.maximumDistance, previous.distanceMeters + interval.forwardMeters)
      next.escortSeconds = min(terms.escortSeconds, previous.escortSeconds + dt)
      for index in terms.checkpoints.indices where next.distanceMeters >= terms.checkpoints[index] {
        next.checkpointBits |= 1 << index
      }
    }
    guard next.valid(terms: terms) else {
      throw MissionPackError("Unrepresentable provider progress.")
    }
    return .init(
      progress: next, contactCompleted: false,
      newCheckpoints: next.checkpointBits & ~previous.checkpointBits,
      fullReady: next.checkpointBits == terms.completedBits
        && next.escortSeconds >= terms.escortSeconds)
  }
}
