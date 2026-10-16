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

  private func adjudicate(
    _ incident: CombatIncident, victim: ActorIdentity, context: EncounterContext,
    inNoFireZone: Bool, missionEntitlement: MissionBountyEntitlement?
  ) -> AttackJudgement {
    let owner = incident.origin.owner
    let time = incident.physicalTime
    let defence = attacks.first {
      $0.owner == victim && $0.victim == owner && $0.unlawful
        && threatActive($0, time: time, context: context, dying: incident.outcome == .destruction)
    }
    let entitlement = missionEntitlement.flatMap {
      $0.owner == owner && $0.victim == victim && $0.amountTenths >= 0 ? $0 : nil
    }
    let missileLaunch = missiles.first {
      incident.kind == .missile && $0.emissionID == incident.origin.emissionID
        && $0.attack.owner == owner && ($0.currentVictim ?? $0.attack.victim) == victim
    }
    let previous =
      missileLaunch?.attack
      ?? attacks.first {
        $0.owner == owner && $0.victim == victim && time - $0.lastAttack <= 10
      }
    let legalBefore = previous?.victimLegal ?? incident.victimLegalBeforeAttack ?? LegalRecord()
    let roleBefore = previous?.victimRole ?? incident.victimRole
    let authority =
      missileLaunch?.attack.authorityAction
      ?? lawfulAuthority(
        owner: owner, victim: victim, legal: legalBefore, time: time, context: context)
    let lawful =
      missileLaunch.map { !$0.attack.unlawful }
      ?? (!incident.victimIsStation
        && (defence != nil || authority
          || (!inNoFireZone && (legalBefore.wanted || entitlement?.authorizesAttack == true))))
    let firstAggressor = previous?.firstAggressor ?? defence?.firstAggressor ?? owner
    let window = AttackWindow(
      owner: owner, victim: victim, victimLegal: legalBefore, victimRole: roleBefore,
      firstAggressor: firstAggressor, unlawful: previous?.unlawful ?? !lawful,
      offence: offence(station: incident.victimIsStation, role: roleBefore, legal: legalBefore),
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
    let attack = judgement.window
    guard incident.outcome == .destruction, settledDeaths.insert(attack.victim).inserted else {
      return
    }
    if attack.unlawful && !incident.victimIsStation && !attack.victimLegal.wanted {
      result.legalPenalty += penalty(for: attack.victimRole == .police ? .policeMurder : .murder)
    }
    let lawful = judgement.lawful && !attack.unlawful
    let bounty =
      lawful ? (judgement.entitlement?.amountTenths ?? max(0, attack.victimLegal.bountyTenths)) : 0
    result.death = .init(
      victim: attack.victim, owner: attack.owner, lawful: lawful, bountyTenths: bounty)
    finishEmission(incident.origin.emissionID)
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
