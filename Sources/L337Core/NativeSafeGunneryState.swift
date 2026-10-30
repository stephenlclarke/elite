import Foundation

struct NativeSafeGunneryPermission: Codable, Sendable, Equatable {
  let mission: UUID
  let owner: UUID
  let carrier: UUID
  let dock: NativeMainStationDockReceipt
  let consent: ScriptChoiceReceipt
  let acceptedAt: Double

  var valid: Bool {
    acceptedAt.isFinite && (0...1e12).contains(acceptedAt)
      && dock.valid && dock.commanderOwner == owner
      && dock.station.system == NativeSafeGunnery.location
      && consent.instance == mission && consent.choice == NativePracticeSource.consentChoice
      && consent.group == NativePracticeSource.consentGroup
      && consent.committed.nativeMainDock == dock && consent.committed.mainStation
      && consent.committed.valid
  }
}

/// Saved native progress. Narrative flags cannot supply hits, quiet time, or terminal authority.
struct NativeSafeGunneryState: Codable, Sendable, Equatable {
  let permission: NativeSafeGunneryPermission
  private(set) var progress: NativeSafeGunneryProgress?
  private(set) var quietSeconds = 0.0
  private(set) var lastFrameTime: Double?
  private(set) var quietAnchorAt: Double?
  private(set) var lastDischargeEmission: UInt64 = 0
  private(set) var pendingProjectiles: [UInt64: AttackOrigin] = [:]
  private(set) var ordinaryHit: CombatIncident?
  var terminalOperation: UUID?
  var terminalDock: NativeMainStationDockReceipt?
  var terminalOutcome: ScriptOutcome?

  var ready: Bool {
    valid && ordinaryHit == nil && terminalOutcome == nil
      && progress?.threeDistinctHits == true && quietSeconds == NativeSafeGunnery.quietSeconds
      && pendingProjectiles.isEmpty
  }

  var valid: Bool {
    guard permission.valid, quietSeconds.isFinite,
      (0...NativeSafeGunnery.quietSeconds).contains(quietSeconds),
      lastFrameTime.map({ $0.isFinite && (0...1e12).contains($0) }) ?? true,
      quietAnchorAt.map({ $0.isFinite && (0...1e12).contains($0) }) ?? true,
      pendingProjectiles.count <= PopulationClass.projectile.maximum,
      terminalOutcome.map({ [.complete, .failed, .abandoned].contains($0) }) ?? true,
      (terminalOperation == nil) == (terminalOutcome == nil)
    else { return false }
    guard let progress else {
      return quietSeconds == 0 && lastFrameTime == nil && quietAnchorAt == nil
        && terminalOutcome != .complete && terminalDock == nil
        && (terminalOutcome != .failed || ordinaryHit != nil)
        && (ordinaryHit == nil || terminalOutcome == nil || terminalOutcome == .failed)
        && (terminalOutcome.map {
          terminalOperation
            == ScriptIdentity.uuid(
              "safe-gunnery-terminal-v1:\(permission.mission):\($0.rawValue)")
        } ?? true)
        && pendingProjectiles.allSatisfy {
          $0.key == $0.value.emissionID && $0.key <= lastDischargeEmission && validOrigin($0.value)
        }
        && (ordinaryHit.map { validOrdinaryHit($0) } ?? true)
    }
    let native = progress.original.permission
    guard progress.valid, native.mission == permission.mission, native.owner == permission.owner,
      native.carrier == permission.carrier, native.consent == permission.consent,
      native.digest == NativeSafeGunnery.digest,
      let lastFrameTime, let quietAnchorAt, quietAnchorAt >= native.begunAt,
      quietAnchorAt <= lastFrameTime,
      quietAnchorAt >= (progress.hits.map(\.time).max() ?? native.begunAt),
      abs(quietSeconds - min(NativeSafeGunnery.quietSeconds, lastFrameTime - quietAnchorAt))
        <= 1e-9,
      quietSeconds == 0 || (progress.threeDistinctHits && pendingProjectiles.isEmpty)
    else { return false }
    for (emission, origin) in pendingProjectiles {
      guard emission == origin.emissionID, emission > 0, emission <= lastDischargeEmission,
        origin.owner == native.player, origin.emittedAt >= permission.acceptedAt,
        origin.emittedAt.isFinite,
        let actor = origin.ordnance, actor.entity >= 2, actor.system == native.player.system,
        actor.visit == native.player.visit,
        !progress.original.beacons.contains(where: { $0.actor == actor })
      else { return false }
    }
    if let hit = ordinaryHit {
      guard hit.origin.owner.visit >= native.player.visit,
        hit.physicalTime >= native.begunAt, validOrdinaryHit(hit),
        [.hit, .destruction, .componentDestruction].contains(hit.outcome), let victim = hit.victim,
        !progress.original.beacons.contains(where: { $0.actor == victim }), quietSeconds == 0
      else { return false }
    }
    if let outcome = terminalOutcome {
      guard
        terminalOperation
          == ScriptIdentity.uuid(
            "safe-gunnery-terminal-v1:\(permission.mission):\(outcome.rawValue)")
      else { return false }
      if outcome == .failed, ordinaryHit == nil { return false }
      if ordinaryHit != nil, outcome != .failed { return false }
      if outcome == .complete {
        guard ordinaryHit == nil, progress.threeDistinctHits,
          quietSeconds == NativeSafeGunnery.quietSeconds, pendingProjectiles.isEmpty,
          let terminalDock, terminalDock.valid,
          terminalDock.commanderOwner == permission.owner,
          terminalDock.station == permission.dock.station,
          terminalDock.sequence > permission.dock.sequence,
          terminalDock.actor.visit >= native.player.visit
        else { return false }
      } else if terminalDock != nil {
        return false
      }
    } else if terminalDock != nil {
      return false
    }
    return true
  }

  mutating func begin(_ provider: NativePracticeState) throws {
    guard valid, progress == nil, terminalOutcome == nil, ordinaryHit == nil,
      provider.permission.mission == permission.mission,
      provider.permission.owner == permission.owner,
      provider.permission.carrier == permission.carrier,
      provider.permission.consent == permission.consent,
      provider.permission.digest == NativeSafeGunnery.digest
    else { throw SaveError.invalidCommander }
    progress = try .init(beginning: provider)
    lastFrameTime = provider.permission.begunAt
    quietAnchorAt = provider.permission.begunAt
  }

  mutating func synchronize(_ provider: NativePracticeState) throws {
    guard valid, ordinaryHit == nil, terminalOutcome == nil, let progress else {
      throw SaveError.invalidCommander
    }
    let observed = try progress.observing(provider)
    if observed.hits.count > progress.hits.count,
      let endpoint = observed.hits.filter({ !progress.hits.contains($0) }).map(\.time).max()
    {
      quietSeconds = 0
      lastFrameTime = max(lastFrameTime ?? endpoint, endpoint)
      quietAnchorAt = lastFrameTime
    }
    self.progress = observed
  }

  mutating func discharge(time: Double, emission: UInt64? = nil) {
    guard terminalOutcome == nil, ordinaryHit == nil,
      time.isFinite, time >= permission.acceptedAt, time >= (lastFrameTime ?? time)
    else { return }
    if let emission {
      guard emission > lastDischargeEmission else { return }
      lastDischargeEmission = emission
    }
    quietSeconds = 0
    if progress != nil {
      lastFrameTime = time
      quietAnchorAt = time
    }
  }

  mutating func launch(_ origin: AttackOrigin, time: Double) throws {
    guard valid, ordinaryHit == nil, terminalOutcome == nil, validOrigin(origin),
      time.isFinite, time >= permission.acceptedAt, time >= (lastFrameTime ?? time),
      origin.emissionID > lastDischargeEmission,
      pendingProjectiles.count < PopulationClass.projectile.maximum,
      progress.map({ origin.owner == $0.original.permission.player }) ?? true
    else { throw SaveError.invalidCommander }
    discharge(time: time, emission: origin.emissionID)
    pendingProjectiles[origin.emissionID] = origin
  }

  mutating func endedProjectile(_ origin: AttackOrigin, time: Double) {
    guard terminalOutcome == nil, ordinaryHit == nil,
      pendingProjectiles[origin.emissionID] == origin,
      time.isFinite, time >= permission.acceptedAt, time >= (lastFrameTime ?? time)
    else { return }
    pendingProjectiles.removeValue(forKey: origin.emissionID)
    quietSeconds = 0
    if progress != nil {
      lastFrameTime = time
      quietAnchorAt = time
    }
  }

  mutating func observeFlight(time: Double, delta: Double) throws {
    guard valid, ordinaryHit == nil, terminalOutcome == nil,
      let previous = lastFrameTime, time.isFinite, delta.isFinite, delta > 0,
      time >= previous
    else { throw SaveError.invalidCommander }
    // A discharge/hit at the current frame endpoint never credits its preceding frame.
    if time == previous { return }
    guard abs(time - previous - delta) <= max(1e-9 * max(1, delta), 4 * max(time.ulp, previous.ulp))
    else {
      quietSeconds = 0
      lastFrameTime = time
      quietAnchorAt = time
      return
    }
    lastFrameTime = time
    guard progress?.threeDistinctHits == true, pendingProjectiles.isEmpty else {
      quietSeconds = 0
      quietAnchorAt = time
      return
    }
    guard let quietAnchorAt else { throw SaveError.invalidCommander }
    quietSeconds = min(NativeSafeGunnery.quietSeconds, time - quietAnchorAt)
  }

  mutating func recordOrdinaryHit(_ incident: CombatIncident) {
    guard ordinaryHit == nil, terminalOutcome == nil, validOrdinaryHit(incident),
      progress.map({
        incident.origin.owner.visit >= $0.original.permission.player.visit
          && incident.physicalTime >= $0.original.permission.begunAt
          && !$0.original.beacons.contains(where: { $0.actor == incident.victim })
      }) ?? true
    else { return }
    ordinaryHit = incident
    quietSeconds = 0
    if progress != nil {
      lastFrameTime = incident.physicalTime
      quietAnchorAt = incident.physicalTime
    }
  }

  private func validOrigin(_ origin: AttackOrigin) -> Bool {
    origin.emissionID > 0 && origin.owner.entity == 0
      && origin.owner.system == NativeSafeGunnery.location
      && origin.owner.visit > permission.dock.actor.visit
      && origin.emittedAt.isFinite && origin.emittedAt >= permission.acceptedAt
      && origin.ordnance.map({
        $0.entity >= 2 && $0.system == origin.owner.system && $0.visit == origin.owner.visit
      }) == true
  }

  private func validOrdinaryHit(_ incident: CombatIncident) -> Bool {
    incident.id > 0 && incident.id < UInt64.max
      && [.hit, .destruction, .componentDestruction].contains(incident.outcome)
      && incident.victim?.system == incident.origin.owner.system
      && incident.victim?.visit == incident.origin.owner.visit
      && incident.origin.emissionID > 0
      && incident.origin.emittedAt.isFinite && incident.origin.emittedAt >= 0
      && incident.origin.emittedAt <= incident.physicalTime && incident.origin.owner.entity == 0
      && incident.origin.owner.visit > permission.dock.actor.visit
      && incident.physicalTime.isFinite && incident.physicalTime >= permission.acceptedAt
  }
}

enum NativeSafeGunnery {
  static let stateID = "l337.training/safe-gunnery"
  static let version = "1.0.0"
  static let location = SystemIdentity(galaxy: 0, system: 7)
  static let boardID = "safe-gunnery"
  static let quietSeconds = 3.0
  static let digest = "4e55aeba14211b7b064088f1248602161a53c728f5447f1bd29a3f7cec6f81d7"
}
