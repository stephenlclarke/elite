import Foundation

extension NativeInductionUtilityRole {
  var workingFault: String { self == .buffer ? "relay-connected" : "valve-open" }
}

struct NativeInductionUtilityArm: Codable, Sendable, Equatable {
  let operation: UUID
  let sequence: UInt64
  let authorization: UUID
  let owner: UUID
  let job: UUID
  let role: NativeInductionUtilityRole
  let module: UUID
  let kit: UUID
  let actor: ActorIdentity
  let player: ActorIdentity
  let carrier: UUID
  let inventoryRevision: UInt64
  let epoch: UUID
  let physicalTime: Double
  let flightSeconds: Double
  var binding: NativeInductionUtilityBinding?

  static func identity(
    authorization: UUID, role: NativeInductionUtilityRole,
    actor: ActorIdentity, player: ActorIdentity, carrier: UUID, revision: UInt64,
    epoch: UUID, time: Double, flightSeconds: Double, sequence: UInt64,
    binding: NativeInductionUtilityBinding? = nil
  ) throws -> UUID {
    let original = ScriptIdentity.uuid(
      "induction-enron-remote-arm-v1:\(authorization):\(role.rawValue):\(try NativeFlightReception.hash(actor)):\(try NativeFlightReception.hash(player)):\(carrier):\(revision):\(epoch):\(time.bitPattern):\(flightSeconds.bitPattern):\(sequence)"
    )
    guard let binding else { return original }
    return ScriptIdentity.uuid(
      "induction-enron-remote-arm-v2:\(original):\(try NativeFlightReception.hash(binding))")
  }
  func valid(
    authorization: NativeInductionUtilityAuthorization,
    source: NativeInductionUtilitySource, role: NativeInductionUtilityRole
  ) -> Bool {
    guard self.authorization == authorization.operation, owner == source.owner,
      job == authorization.job, self.role == role,
      module == source.module(role), kit == source.kit(role),
      actor.system == NativeInductionUtilitySource.location, player.system == actor.system,
      actor.visit >= authorization.dock.actor.visit, actor.visit == player.visit,
      actor.entity > 1, actor.entity < UInt64(Int64.max), player.entity == 0,
      sequence > authorization.sequence, sequence < UInt64(Int64.max),
      inventoryRevision < UInt64(Int64.max), physicalTime.isFinite,
      (authorization.physicalTime...1e12).contains(physicalTime), flightSeconds.isFinite,
      (authorization.flightSeconds...1e12).contains(flightSeconds)
    else { return false }
    if let binding, !binding.valid(job: job, role: role, actor: actor, time: physicalTime) {
      return false
    }
    return operation
      == (try? Self.identity(
        authorization: self.authorization, role: role,
        actor: actor, player: player, carrier: carrier, revision: inventoryRevision,
        epoch: epoch, time: physicalTime, flightSeconds: flightSeconds, sequence: sequence,
        binding: binding))
  }
}

struct NativeInductionUtilityWorkSegment: Codable, Sendable, Equatable {
  let arm: NativeInductionUtilityArm
  var seconds = 0.0
  var intervals: UInt64 = 0
  var first: Double?
  var last: Double?
  var lastRange: Double?
  var lastSpeed: Double?
  var lastAim: Double?

  var valid: Bool {
    guard seconds.isFinite, (0...(20 + 1e-8)).contains(seconds), intervals < 1_000_000_000 else {
      return false
    }
    if intervals == 0 {
      return seconds == 0 && first == nil && last == nil
        && lastRange == nil && lastSpeed == nil && lastAim == nil
    }
    guard let first, let last, let lastRange, let lastSpeed, let lastAim,
      first.isFinite, last.isFinite, first >= arm.physicalTime, last > first, last <= 1e12,
      seconds > 0, seconds <= last - first + 1e-7,
      seconds <= Double(intervals) * 0.100001 + 1e-7
    else { return false }
    return NativeInductionUtilityEnvelope.qualifies(
      range: lastRange, speed: lastSpeed, aim: lastAim, front: true, unobstructed: true)
  }
}

struct NativeInductionUtilityRepair: Codable, Sendable, Equatable {
  let operation: UUID
  let sequence: UInt64
  let authorization: UUID
  let owner: UUID
  let job: UUID
  let role: NativeInductionUtilityRole
  let module: UUID
  let kit: UUID
  let actor: ActorIdentity
  let history: String
  let physicalTime: Double
  let flightSeconds: Double
  static func identity(
    authorization: UUID, module: UUID, kit: UUID,
    history: String, actor: ActorIdentity, time: Double, sequence: UInt64
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-enron-physical-repair-v1:\(authorization):\(module):\(kit):\(history):\(try NativeFlightReception.hash(actor)):\(time.bitPattern):\(sequence)"
    )
  }
}

struct NativeInductionUtilityWork: Codable, Sendable, Equatable {
  static let maximumSegments = 256
  var segments: [NativeInductionUtilityWorkSegment] = []
  var repair: NativeInductionUtilityRepair?
  var seconds: Double { segments.reduce(0) { $0 + $1.seconds } }

  func valid(
    authorization: NativeInductionUtilityAuthorization,
    source: NativeInductionUtilitySource, role: NativeInductionUtilityRole
  ) -> Bool {
    guard !segments.isEmpty, segments.count <= Self.maximumSegments,
      Set(segments.map { $0.arm.operation }).count == segments.count,
      segments.allSatisfy({
        $0.valid && $0.arm.valid(authorization: authorization, source: source, role: role)
      }),
      seconds.isFinite, (0...(20 + 1e-8)).contains(seconds),
      zip(segments, segments.dropFirst()).allSatisfy({
        $0.arm.sequence < $1.arm.sequence
          && ($0.last ?? $0.arm.physicalTime) <= $1.arm.physicalTime
      })
    else { return false }
    guard let repair else { return true }
    guard let last = segments.last, abs(seconds - 20) < 1e-8, repair.sequence > last.arm.sequence,
      repair.sequence < UInt64(Int64.max), repair.authorization == authorization.operation,
      repair.owner == source.owner, repair.job == authorization.job, repair.role == role,
      repair.module == source.module(role), repair.kit == source.kit(role),
      repair.actor == last.arm.actor,
      repair.history == (try? NativeFlightReception.hash(segments)),
      repair.physicalTime.isFinite,
      (last.last ?? last.arm.physicalTime) <= repair.physicalTime, repair.physicalTime <= 1e12,
      repair.flightSeconds.isFinite, (last.arm.flightSeconds...1e12).contains(repair.flightSeconds)
    else { return false }
    return repair.operation
      == (try? NativeInductionUtilityRepair.identity(
        authorization: repair.authorization, module: repair.module, kit: repair.kit,
        history: repair.history, actor: repair.actor, time: repair.physicalTime,
        sequence: repair.sequence))
  }
}

/// Geometry policy only. Passing model numbers never supplies an attained runtime work interval.
enum NativeInductionUtilityEnvelope {
  static func qualifies(
    range: Double, speed: Double, aim: Double,
    front: Bool, unobstructed: Bool
  ) -> Bool {
    front && unobstructed && range.isFinite && (50...150).contains(range)
      && speed.isFinite && (0...1).contains(speed)
      && aim.isFinite && (0...(2 * Double.pi / 180)).contains(aim)
  }
  static func credit(before: Double, start: Double, end: Double) -> Double? {
    guard before.isFinite, (0...(20 + 1e-8)).contains(before), start.isFinite, end.isFinite,
      start >= 0, end > start, end <= 1e12, end - start <= 0.100001
    else { return nil }
    return max(0, min(20 - before, end - start))
  }
}
