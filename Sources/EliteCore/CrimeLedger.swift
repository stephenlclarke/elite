import Foundation

public enum CrimeKind: String, Codable, Sendable {
  case noFire, assault, policeAssault, stationAttack, murder, policeMurder
}

public enum SecurityNotice: String, Codable, Sendable {
  case weaponsProhibited, unlawfulAttack, distressReceived, stationAlarm, securityCooldown
  case dockingDenied, offenderDockingWarning
  public var text: String {
    switch self {
    case .weaponsProhibited: "WEAPONS PROHIBITED NEAR STATION"
    case .unlawfulAttack: "UNLAWFUL ATTACK RECORDED"
    case .distressReceived: "DISTRESS RECEIVED; POLICE RESPONDING"
    case .stationAlarm: "STATION UNDER ATTACK; SECURITY LAUNCHING"
    case .securityCooldown: "STATION SECURITY STANDING DOWN"
    case .dockingDenied: "DOCKING PERMISSION DENIED"
    case .offenderDockingWarning: "OFFENDER - DOCK WITHOUT FURTHER VIOLENCE"
    }
  }
}

public struct VerifiedCrimeReport: Equatable, Codable, Sendable {
  public let incidentID: UInt64
  public let offender: ActorIdentity
  public let victim: ActorIdentity?
  public let kind: CrimeKind
  public let physicalTime: Double
  public let position: Vector3
}

/// Only the authoritative mission adapter may supply a source reward entitlement.
public struct MissionBountyEntitlement: Equatable, Codable, Sendable {
  public let owner: ActorIdentity
  public let victim: ActorIdentity
  public let amountTenths: Int
  public let authorizesAttack: Bool
}

public struct DeathSettlement: Equatable, Codable, Sendable {
  public let victim: ActorIdentity
  public let owner: ActorIdentity
  public let lawful: Bool
  public let bountyTenths: Int
}

public struct CrimeResolution: Equatable, Codable, Sendable {
  public var accepted = false
  public var offender: ActorIdentity?
  public var legalPenalty = 0
  public var unlawful = false
  public var lawfulSelfDefence = false
  public var firstAggressor: ActorIdentity?
  public var death: DeathSettlement?
  public var report: VerifiedCrimeReport?
  public var notices: [SecurityNotice] = []
}

private struct AttackWindow: Equatable, Codable, Sendable {
  var owner: ActorIdentity
  var victim: ActorIdentity
  let victimLegal: LegalRecord
  let victimRole: NPCRole?
  var firstAggressor: ActorIdentity
  let unlawful: Bool
  let offence: CrimeKind
  let authorityAction: Bool
  var lastAttack: Double
}

private struct MissWindow: Equatable, Codable, Sendable {
  var owner: ActorIdentity
  var lastDischarge: Double
  var charged: Bool
}

private struct MissileAttack: Equatable, Codable, Sendable {
  let emissionID: UInt64
  let ordnance: ActorIdentity?
  let attack: AttackWindow
  // Tracking may follow a surviving NPC; launch judgement and emission attribution stay frozen.
  var currentOwner: ActorIdentity? = nil
  var currentVictim: ActorIdentity? = nil
}

private struct AttackJudgement {
  let window: AttackWindow
  let firstInWindow: Bool
  let lawful: Bool
  let selfDefence: Bool
  let entitlement: MissionBountyEntitlement?
}

/// Persisted native launch facts are data, never an authority proof after decoding.
public struct MissionLaunchJudgement: Equatable, Codable, Sendable {
  fileprivate let facts: MissionLaunchLawFacts
  public var origin: AttackOrigin { facts.origin }
  public var victim: ActorIdentity { facts.victim }
  public var victimLegal: LegalRecord { facts.victimLegal }
  public var victimRole: NPCRole? { facts.victimRole }
  public var victimIsStation: Bool { facts.victimIsStation }
  public var firstAggressor: ActorIdentity { facts.firstAggressor }
  public var lawful: Bool { facts.lawful }
  public var unlawful: Bool { facts.unlawful }
  public var lawfulSelfDefence: Bool { facts.selfDefence }
  public var authorityAction: Bool { facts.authorityAction }
  public var inNoFireZone: Bool { facts.inNoFireZone }
  public var offence: CrimeKind { facts.offence }
  public var firstInWindow: Bool { facts.firstInWindow }
  public var emissionPosition: Vector3 { facts.emissionPosition }
  /// Freezing is pure; it neither charges an offence nor creates a threat or incident.
  public var launchEffectsApplied: Bool { false }
  public var valid: Bool {
    func identityValid(_ value: ActorIdentity) -> Bool {
      (0..<8).contains(value.system.galaxy) && (0...256).contains(value.system.system)
        && value.visit > 0 && value.visit < UInt64.max && value.entity < UInt64.max
    }
    return identityValid(origin.owner) && identityValid(victim)
      && identityValid(firstAggressor) && origin.owner != victim
      && victim.system == origin.owner.system && victim.visit == origin.owner.visit
      && firstAggressor.system == origin.owner.system && firstAggressor.visit == origin.owner.visit
      && origin.emissionID > 0 && origin.emissionID < UInt64.max
      && origin.emittedAt.isFinite && origin.emittedAt >= 0 && emissionPosition.finite
      && (0...255).contains(origin.ownerLegalAtEmission.value)
      && origin.ownerLegalAtEmission.bountyTenths >= 0
      && (0...255).contains(victimLegal.value) && victimLegal.bountyTenths >= 0
      && (origin.sourcePart.map { $0.utf8.count <= 256 } ?? true)
      && (origin.ordnance.map {
        identityValid($0) && $0.system == origin.owner.system && $0.visit == origin.owner.visit
      } ?? true)
  }
}

private struct MissionLaunchLawFacts: Equatable, Codable, Sendable {
  let origin: AttackOrigin
  let victim: ActorIdentity
  let victimLegal: LegalRecord
  let victimRole: NPCRole?
  let victimIsStation: Bool
  let firstAggressor: ActorIdentity
  let lawful: Bool
  let unlawful: Bool
  let selfDefence: Bool
  let authorityAction: Bool
  let inNoFireZone: Bool
  let offence: CrimeKind
  let firstInWindow: Bool
  let emissionPosition: Vector3
}

public enum MissionLaunchLawError: Error, Sendable {
  case invalidLaunchFacts
}

/// Pure value state. Runtime integration applies the returned delta and credit atomically.
public struct CrimeLedger: Equatable, Codable, Sendable {
  private var lastIncidentID: UInt64?
  private var attacks: [AttackWindow] = []
  private var misses: [MissWindow] = []
  private var missiles: [MissileAttack] = []
  private var settledDeaths: Set<ActorIdentity> = []
  public init() {}

  /// Call on visit changes after pending physical deaths have been resolved.
  public mutating func beginVisit(system: SystemIdentity, visit: UInt64) {
    attacks.removeAll { $0.owner.system != system || $0.owner.visit != visit }
    misses.removeAll { $0.owner.system != system || $0.owner.visit != visit }
    missiles.removeAll { $0.attack.owner.system != system || $0.attack.owner.visit != visit }
    settledDeaths = Set(settledDeaths.filter { $0.system == system && $0.visit == visit })
  }

  /// Only accepted living same-visit NPC rebindings may reconcile transient threat addresses.
  /// Death replay identities and immutable missile launch evidence are never rewritten.
  public mutating func rebindActors(_ identities: [ActorIdentity: ActorIdentity]) {
    let accepted = identities.filter { old, new in
      old.system == new.system && (0..<8).contains(old.system.galaxy)
        && (0...256).contains(old.system.system)
        && old.visit == new.visit && old.visit > 0 && old.visit < UInt64.max
        && old.entity >= 2 && new.entity > old.entity && new.entity < UInt64.max
    }
    guard !accepted.isEmpty else { return }
    func current(_ actor: ActorIdentity) -> ActorIdentity { accepted[actor] ?? actor }
    var reconciled: [AttackWindow] = []
    for var attack in attacks {
      attack.owner = current(attack.owner)
      attack.victim = current(attack.victim)
      attack.firstAggressor = current(attack.firstAggressor)
      if let index = reconciled.firstIndex(where: {
        $0.owner == attack.owner && $0.victim == attack.victim
      }) {
        // A later window may carry a new legal judgement after the previous window expired.
        if attack.lastAttack > reconciled[index].lastAttack { reconciled[index] = attack }
      } else {
        reconciled.append(attack)
      }
    }
    attacks = reconciled
    var reconciledMisses: [MissWindow] = []
    for var miss in misses {
      miss.owner = current(miss.owner)
      if let index = reconciledMisses.firstIndex(where: { $0.owner == miss.owner }) {
        if miss.lastDischarge > reconciledMisses[index].lastDischarge {
          reconciledMisses[index] = miss
        }
      } else {
        reconciledMisses.append(miss)
      }
    }
    misses = reconciledMisses
    for index in missiles.indices {
      missiles[index].currentOwner = current(
        missiles[index].currentOwner ?? missiles[index].attack.owner)
      missiles[index].currentVictim = current(
        missiles[index].currentVictim ?? missiles[index].attack.victim)
    }
  }

  public mutating func endThreat(_ identity: ActorIdentity) {
    attacks.removeAll { $0.owner == identity || $0.victim == identity }
  }

  /// Expiry/culling is not a victim death. Remove only the completed ordnance's threat.
  public mutating func finishEmission(_ emissionID: UInt64) {
    missiles.removeAll { $0.emissionID == emissionID }
  }

  public mutating func record(
    _ incident: CombatIncident, context: EncounterContext, emissionPosition: Vector3? = nil,
    missionEntitlement: MissionBountyEntitlement? = nil
  ) -> CrimeResolution {
    var result = CrimeResolution()
    guard accepts(incident, context: context) else { return result }
    lastIncidentID = incident.id
    result.accepted = true
    if incident.outcome == .ordnanceInterception {
      finishEmission(incident.origin.emissionID)
      return result
    }
    guard incident.kind != .collision else {
      return result
    }
    let owner = incident.origin.owner
    let actor = snapshot(owner, context: context)
    let sourcePosition = emissionPosition ?? actor?.position ?? incident.position
    let inNoFireZone = (sourcePosition - context.anchors.station.position).length <= 1200
    if incident.outcome == .discharge {
      return missedDischarge(incident, context: context, inZone: inNoFireZone, result: result)
    }
    guard let victim = eligibleVictim(incident, context: context) else { return result }
    let judgement = adjudicate(
      incident, victim: victim, context: context, inNoFireZone: inNoFireZone,
      missionEntitlement: missionEntitlement)
    // Capture current consumer addresses before settlement retires the missile entry.
    // The judgement and death owner retain the immutable emission attribution.
    let currentAttack = currentThreat(judgement.window, incident: incident)
    applyOffence(
      judgement, currentAttack: currentAttack, incident: incident,
      context: context, result: &result)
    remember(judgement.window, incident: incident)
    settleDeath(judgement, incident: incident, result: &result)
    let currentLegal =
      snapshot(currentAttack.owner, context: context)?.legal.value
      ?? incident.origin.ownerLegalAtEmission.value
    result.legalPenalty = min(result.legalPenalty, max(0, 255 - currentLegal))
    return result
  }

  /// Reentry uses only sealed current contacts and immutable launch law. Ordinary incident
  /// admission remains same-visit; this entry point never invents a replacement attack origin.
  mutating func recordMissionReentryImpact(
    _ proof: MissionNativeImpactProof, eventID: UInt64, outcome: AttackOutcome,
    context: EncounterContext
  ) -> CrimeResolution {
    var result = CrimeResolution()
    guard proof.system == context.system, proof.visit == context.visit,
      proof.sceneRevision == context.revision, context.visit > 0, context.visit < UInt64.max,
      context.physicalTime.isFinite, context.physicalTime >= 0, proof.hit.point.finite,
      proof.archive.map({
        $0.origin.emittedAt.isFinite && $0.origin.emittedAt <= context.physicalTime
      }) ?? true,
      context.player.position.finite, context.player.orientation.validRotation,
      let projectile = proof.projectileBody.physical?.identity,
      context.actors.filter({
        $0.identity == projectile && $0.energy == proof.projectileBody.energy && $0.energy > 0
      }).count == 1,
      eventID > 0, eventID < UInt64.max,
      lastIncidentID.map({ eventID > $0 }) ?? true,
      [.hit, .destruction, .componentDestruction, .ordnanceInterception].contains(outcome)
    else { return result }
    let impactPosition =
      context.player.position + context.player.orientation.apply(proof.hit.point)
    guard impactPosition.finite else { return result }
    if case .body(let id) = proof.hit.target {
      guard let body = proof.targetBody, body.id == id,
        body.physical?.identity == proof.currentVictim,
        context.actors.filter({
          $0.identity == proof.currentVictim && $0.hull == body.hull && $0.energy == body.energy
            && $0.npc == body.physical?.npc
        }).count == 1
      else { return result }
    } else if case .player = proof.hit.target {
      guard proof.currentVictim == context.player.identity else { return result }
    }
    if let source = proof.currentSource {
      guard
        context.actors.filter({
          $0.identity == source && $0.energy.isFinite && $0.energy > 0 && $0.npc?.role == .mission
        }).count == 1
      else { return result }
    }
    lastIncidentID = eventID
    result.accepted = true
    guard outcome != .ordnanceInterception,
      let victimID = proof.currentVictim, let victim = snapshot(victimID, context: context),
      victimID.system == context.system, victimID.visit == context.visit,
      ![Hull.cargo, .asteroid, .missile].contains(victim.hull),
      !settledDeaths.contains(victimID)
    else { return result }
    if let salvage = victim.salvage, [.wreck, .section].contains(salvage.category),
      salvage.ownership == .abandoned, salvage.claimant == nil, victim.npc == nil,
      victim.hull != .station, !context.protection.protectedActors.contains(victimID)
    {
      return result
    }
    guard let frozen = proof.frozenJudgement, frozen.valid,
      let ownerID = proof.currentSource, let owner = snapshot(ownerID, context: context),
      ownerID != victimID, ownerID.system == context.system, ownerID.visit == context.visit,
      owner.energy.isFinite, owner.energy > 0, owner.npc?.role == .mission,
      let archive = proof.archive
    else {
      // Physical death still becomes irreversible, without attributing it to an unknown actor.
      if outcome == .destruction { settledDeaths.insert(victimID) }
      return result
    }
    switch archive.intendedTarget {
    case .player:
      guard case .player = proof.hit.target else { return result }
    case .actor(let instance, let actor, _):
      guard proof.targetBody?.missionInstanceID == instance,
        proof.targetBody?.missionActorID == actor
      else { return result }
    }
    let aggressor: ActorIdentity
    if frozen.firstAggressor == frozen.origin.owner {
      aggressor = ownerID
    } else if frozen.firstAggressor == frozen.victim {
      aggressor = victimID
    } else {
      if outcome == .destruction { settledDeaths.insert(victimID) }
      return result
    }
    let first =
      frozen.firstInWindow
      && !attacks.contains {
        $0.owner == ownerID && $0.victim == victimID && context.physicalTime - $0.lastAttack <= 10
      }
    let window = AttackWindow(
      owner: ownerID, victim: victimID, victimLegal: frozen.victimLegal,
      victimRole: frozen.victimRole, firstAggressor: aggressor, unlawful: frozen.unlawful,
      offence: frozen.offence, authorityAction: frozen.authorityAction,
      lastAttack: context.physicalTime)
    let judgement = AttackJudgement(
      window: window, firstInWindow: first, lawful: frozen.lawful,
      selfDefence: frozen.lawfulSelfDefence, entitlement: nil)
    result.unlawful = frozen.unlawful
    result.lawfulSelfDefence = frozen.lawfulSelfDefence
    result.firstAggressor = aggressor
    if frozen.unlawful {
      result.offender = ownerID
      if first {
        result.legalPenalty = penalty(for: frozen.offence)
        result.notices.append(.unlawfulAttack)
      }
      // Resolve the actual current contact through the camera carried by this context.
      if victim.hull == .station
        || (impactPosition - context.anchors.station.position).length <= 6000
        || context.actors.contains(where: {
          $0.identity != ownerID && $0.npc?.role == .police && $0.energy > 0
            && !context.protection.protectedActors.contains($0.identity)
            && ($0.position - impactPosition).length <= 2500
        })
      {
        result.report = .init(
          incidentID: eventID, offender: ownerID, victim: victimID, kind: frozen.offence,
          physicalTime: context.physicalTime, position: impactPosition)
      }
    }
    attacks.removeAll { $0.owner == ownerID && $0.victim == victimID }
    attacks.append(window)
    settleDeath(
      judgement, outcome: outcome, victimIsStation: frozen.victimIsStation,
      emissionID: nil, result: &result)
    result.legalPenalty = min(result.legalPenalty, max(0, 255 - owner.legal.value))
    return result
  }

  private func accepts(_ incident: CombatIncident, context: EncounterContext) -> Bool {
    incident.physicalTime.isFinite && context.physicalTime.isFinite
      && incident.physicalTime >= 0 && incident.physicalTime <= context.physicalTime + 1e-8
      && incident.position.finite && incident.origin.owner.system == context.system
      && incident.origin.owner.visit == context.visit
      && (lastIncidentID.map { incident.id > $0 } ?? true)
  }

  private func eligibleVictim(_ incident: CombatIncident, context: EncounterContext)
    -> ActorIdentity?
  {
    guard let victim = incident.victim, victim != incident.origin.owner,
      victim.system == context.system, victim.visit == context.visit,
      incident.outcome != .targetedLaunch || incident.kind == .missile,
      !settledDeaths.contains(victim),
      incident.victimIsStation || incident.victimLegalBeforeAttack != nil
    else { return nil }
    if let actor = snapshot(victim, context: context) {
      if [.cargo, .asteroid, .missile].contains(actor.hull) { return nil }
      if let salvage = actor.salvage, [.wreck, .section].contains(salvage.category),
        salvage.ownership == .abandoned, salvage.claimant == nil, actor.npc == nil,
        !incident.victimIsStation,
        !context.protection.protectedActors.contains(actor.identity)
      {
        return nil
      }
    }
    return victim
  }

  /// Pure plasma launch adjudication. Call only after actual native emission admission.
  /// Persisting this value does not grant reentry authority; the bridge revalidates its joins.
  public func freezeMissionLaunchJudgement(
    origin: AttackOrigin, intendedVictim: ActorSnapshot, emissionPosition: Vector3,
    context: EncounterContext
  ) throws -> MissionLaunchJudgement {
    guard context.physicalTime.isFinite, context.physicalTime >= 0,
      origin.owner.system == context.system, origin.owner.visit == context.visit,
      origin.emittedAt == context.physicalTime,
      let owner = snapshot(origin.owner, context: context), owner.energy > 0,
      owner.legal == origin.ownerLegalAtEmission,
      snapshot(intendedVictim.identity, context: context) == intendedVictim,
      intendedVictim.identity != origin.owner, intendedVictim.energy > 0,
      intendedVictim.identity.system == context.system,
      intendedVictim.identity.visit == context.visit,
      ![Hull.cargo, .asteroid, .missile].contains(intendedVictim.hull),
      !settledDeaths.contains(intendedVictim.identity), emissionPosition.finite
    else { throw MissionLaunchLawError.invalidLaunchFacts }
    if let salvage = intendedVictim.salvage, [.wreck, .section].contains(salvage.category),
      salvage.ownership == .abandoned, salvage.claimant == nil, intendedVictim.npc == nil,
      intendedVictim.hull != .station,
      !context.protection.protectedActors.contains(intendedVictim.identity)
    {
      throw MissionLaunchLawError.invalidLaunchFacts
    }
    let inZone = (emissionPosition - context.anchors.station.position).length <= 1200
    let judgement = judgeAttack(
      origin: origin, kind: .plasma, isDestruction: false,
      victim: intendedVictim.identity, victimLegal: intendedVictim.legal,
      victimRole: intendedVictim.npc?.role, victimIsStation: intendedVictim.hull == .station,
      time: context.physicalTime, context: context, inNoFireZone: inZone, missionEntitlement: nil)
    let value = MissionLaunchJudgement(
      facts: .init(
        origin: origin, victim: intendedVictim.identity, victimLegal: judgement.window.victimLegal,
        victimRole: judgement.window.victimRole, victimIsStation: intendedVictim.hull == .station,
        firstAggressor: judgement.window.firstAggressor, lawful: judgement.lawful,
        unlawful: judgement.window.unlawful, selfDefence: judgement.selfDefence,
        authorityAction: judgement.window.authorityAction, inNoFireZone: inZone,
        offence: judgement.window.offence, firstInWindow: judgement.firstInWindow,
        emissionPosition: emissionPosition))
    guard value.valid else { throw MissionLaunchLawError.invalidLaunchFacts }
    return value
  }

  private func adjudicate(
    _ incident: CombatIncident, victim: ActorIdentity, context: EncounterContext,
    inNoFireZone: Bool, missionEntitlement: MissionBountyEntitlement?
  ) -> AttackJudgement {
    judgeAttack(
      origin: incident.origin, kind: incident.kind, isDestruction: incident.outcome == .destruction,
      victim: victim, victimLegal: incident.victimLegalBeforeAttack,
      victimRole: incident.victimRole,
      victimIsStation: incident.victimIsStation, time: incident.physicalTime,
      context: context, inNoFireZone: inNoFireZone, missionEntitlement: missionEntitlement)
  }

  private func judgeAttack(
    origin: AttackOrigin, kind: AttackKind, isDestruction: Bool,
    victim: ActorIdentity, victimLegal: LegalRecord?, victimRole: NPCRole?, victimIsStation: Bool,
    time: Double, context: EncounterContext, inNoFireZone: Bool,
    missionEntitlement: MissionBountyEntitlement?
  ) -> AttackJudgement {
    let owner = origin.owner
    let defence = attacks.first {
      $0.owner == victim && $0.victim == owner && $0.unlawful
        && threatActive($0, time: time, context: context, dying: isDestruction)
    }
    let entitlement = missionEntitlement.flatMap {
      $0.owner == owner && $0.victim == victim && $0.amountTenths >= 0 ? $0 : nil
    }
    let missileLaunch = missiles.first {
      kind == .missile && $0.emissionID == origin.emissionID
        && $0.attack.owner == owner && ($0.currentVictim ?? $0.attack.victim) == victim
    }
    let previous =
      missileLaunch?.attack
      ?? attacks.first {
        $0.owner == owner && $0.victim == victim && time - $0.lastAttack <= 10
      }
    let legalBefore = previous?.victimLegal ?? victimLegal ?? LegalRecord()
    let roleBefore = previous?.victimRole ?? victimRole
    let authority =
      missileLaunch?.attack.authorityAction
      ?? lawfulAuthority(
        owner: owner, victim: victim, legal: legalBefore, time: time, context: context)
    let lawful =
      missileLaunch.map { !$0.attack.unlawful }
      ?? (!victimIsStation
        && (defence != nil || authority
          || (!inNoFireZone && (legalBefore.wanted || entitlement?.authorizesAttack == true))))
    let firstAggressor = previous?.firstAggressor ?? defence?.firstAggressor ?? owner
    let window = AttackWindow(
      owner: owner, victim: victim, victimLegal: legalBefore, victimRole: roleBefore,
      firstAggressor: firstAggressor, unlawful: previous?.unlawful ?? !lawful,
      offence: offence(station: victimIsStation, role: roleBefore, legal: legalBefore),
      authorityAction: authority, lastAttack: time)
    return .init(
      window: window, firstInWindow: previous == nil, lawful: lawful,
      selfDefence: defence != nil, entitlement: entitlement)
  }

  private func lawfulAuthority(
    owner: ActorIdentity, victim: ActorIdentity, legal: LegalRecord, time: Double,
    context: EncounterContext
  ) -> Bool {
    guard let actor = snapshot(owner, context: context), actor.npc?.role == .police,
      actor.legal.value == 0
    else { return false }
    return legal.wanted
      || attacks.contains {
        $0.owner == victim && $0.unlawful && time - $0.lastAttack <= 30
      }
  }

  private func offence(station: Bool, role: NPCRole?, legal: LegalRecord) -> CrimeKind {
    if station { return .stationAttack }
    if role == .police { return .policeAssault }
    if legal.wanted { return .noFire }
    return .assault
  }

  private func applyOffence(
    _ judgement: AttackJudgement, currentAttack attack: AttackWindow,
    incident: CombatIncident, context: EncounterContext, result: inout CrimeResolution
  ) {
    result.unlawful = attack.unlawful
    result.lawfulSelfDefence = judgement.selfDefence
    result.firstAggressor = attack.firstAggressor
    guard attack.unlawful else { return }
    result.offender = attack.owner
    if judgement.firstInWindow {
      result.legalPenalty = penalty(for: attack.offence)
      result.notices.append(.unlawfulAttack)
    }
    if observed(incident, context: context) {
      result.report = .init(
        incidentID: incident.id, offender: attack.owner, victim: attack.victim,
        kind: attack.offence, physicalTime: incident.physicalTime, position: incident.position)
    }
  }

  private func currentThreat(_ attack: AttackWindow, incident: CombatIncident) -> AttackWindow {
    var threat = attack
    guard incident.kind == .missile,
      let launch = missiles.first(where: {
        $0.emissionID == incident.origin.emissionID && $0.attack.owner == incident.origin.owner
      })
    else { return threat }
    threat.owner = launch.currentOwner ?? attack.owner
    if attack.victim == launch.attack.victim || attack.victim == launch.currentVictim {
      threat.victim = launch.currentVictim ?? attack.victim
    }
    if attack.firstAggressor == launch.attack.owner {
      threat.firstAggressor = launch.currentOwner ?? attack.firstAggressor
    } else if attack.firstAggressor == launch.attack.victim {
      threat.firstAggressor = launch.currentVictim ?? attack.firstAggressor
    }
    return threat
  }

  private mutating func remember(_ attack: AttackWindow, incident: CombatIncident) {
    let threat = currentThreat(attack, incident: incident)
    attacks.removeAll { $0.owner == threat.owner && $0.victim == threat.victim }
    attacks.append(threat)
    if incident.kind == .missile && incident.outcome == .targetedLaunch,
      !missiles.contains(where: { $0.emissionID == incident.origin.emissionID })
    {
      missiles.append(
        .init(
          emissionID: incident.origin.emissionID, ordnance: incident.origin.ordnance, attack: attack
        ))
    }
  }

  private mutating func settleDeath(
    _ judgement: AttackJudgement, incident: CombatIncident, result: inout CrimeResolution
  ) {
    settleDeath(
      judgement, outcome: incident.outcome, victimIsStation: incident.victimIsStation,
      emissionID: incident.origin.emissionID, result: &result)
  }

  private mutating func settleDeath(
    _ judgement: AttackJudgement, outcome: AttackOutcome, victimIsStation: Bool,
    emissionID: UInt64?, result: inout CrimeResolution
  ) {
    let attack = judgement.window
    guard outcome == .destruction, settledDeaths.insert(attack.victim).inserted else {
      return
    }
    if attack.unlawful && !victimIsStation && !attack.victimLegal.wanted {
      result.legalPenalty += penalty(for: attack.victimRole == .police ? .policeMurder : .murder)
    }
    let lawful = judgement.lawful && !attack.unlawful
    let bounty =
      lawful ? (judgement.entitlement?.amountTenths ?? max(0, attack.victimLegal.bountyTenths)) : 0
    result.death = .init(
      victim: attack.victim, owner: attack.owner, lawful: lawful, bountyTenths: bounty)
    if let emissionID { finishEmission(emissionID) }
  }

  private mutating func missedDischarge(
    _ incident: CombatIncident, context: EncounterContext, inZone: Bool,
    result initial: CrimeResolution
  ) -> CrimeResolution {
    var result = initial
    guard inZone else { return result }
    let owner = incident.origin.owner
    if let defence = attacks.first(where: {
      $0.victim == owner && $0.unlawful
        && threatActive($0, time: incident.physicalTime, context: context, dying: false)
    }) {
      result.lawfulSelfDefence = true
      result.firstAggressor = defence.firstAggressor
      return result
    }
    if let officer = snapshot(owner, context: context),
      case .engage(let target) = officer.npc?.intention,
      let targetSnapshot = snapshot(target, context: context),
      lawfulAuthority(
        owner: owner, victim: target, legal: targetSnapshot.legal,
        time: incident.physicalTime, context: context)
    {
      return result
    }
    if let index = misses.firstIndex(where: {
      $0.owner == owner && incident.physicalTime - $0.lastDischarge <= 10
    }) {
      if !misses[index].charged {
        misses[index].charged = true
        result.legalPenalty = min(
          2, max(0, 255 - (snapshot(owner, context: context)?.legal.value ?? 0)))
        result.notices = [.unlawfulAttack]
      }
      misses[index].lastDischarge = incident.physicalTime
      result.offender = owner
      result.unlawful = true
      result.firstAggressor = owner
      result.report = .init(
        incidentID: incident.id, offender: owner, victim: nil, kind: .noFire,
        physicalTime: incident.physicalTime, position: incident.position)
    } else {
      misses.removeAll { $0.owner == owner }
      misses.append(.init(owner: owner, lastDischarge: incident.physicalTime, charged: false))
      result.notices = [.weaponsProhibited]
    }
    return result
  }

  private func threatActive(
    _ attack: AttackWindow, time: Double, context: EncounterContext, dying: Bool
  ) -> Bool {
    guard let aggressor = snapshot(attack.owner, context: context), aggressor.energy > 0 || dying
    else { return false }
    if time - attack.lastAttack <= 10 { return true }
    if missiles.contains(where: { missile in
      (missile.currentOwner ?? missile.attack.owner) == attack.owner
        && (missile.currentVictim ?? missile.attack.victim) == attack.victim
        && missile.ordnance.map { identity in
          context.actors.contains { $0.identity == identity && $0.energy > 0 }
        } == true
    }) {
      return true
    }
    return aggressor.npc?.intention == .engage(attack.victim)
  }

  private func observed(_ incident: CombatIncident, context: EncounterContext) -> Bool {
    if incident.victimIsStation { return true }
    if (incident.position - context.anchors.station.position).length <= 6000 { return true }
    return context.actors.contains {
      $0.identity != incident.origin.owner && $0.npc?.role == .police && $0.energy > 0
        && !context.protection.protectedActors.contains($0.identity)
        && ($0.position - incident.position).length <= 2500
    }
  }

  private func snapshot(_ identity: ActorIdentity, context: EncounterContext) -> ActorSnapshot? {
    identity == context.player.identity
      ? context.player : context.actors.first { $0.identity == identity }
  }

  private func penalty(for kind: CrimeKind) -> Int {
    switch kind {
    case .noFire: 2
    case .assault: 8
    case .policeAssault, .murder: 32
    case .stationAttack, .policeMurder: 64
    }
  }
}
