import Foundation

/// Observed careers are separate from rank points and from visit-local physical actors.
public struct WantedSighting: Codable, Equatable, Sendable {
  public let system: SystemIdentity
  public let position: Vector3
  public let heading: Vector3
  public let destination: SystemIdentity?
  public let time: Double
  var valid: Bool {
    (0..<8).contains(system.galaxy) && (0...256).contains(system.system)
      && position.finite && heading.finite && time.isFinite && time >= 0
      && (destination.map { (0..<8).contains($0.galaxy) && (0...256).contains($0.system) } ?? true)
  }
}

public struct WantedCareer: Codable, Equatable, Sendable {
  public let identity: ActorIdentity
  public let callsign: String
  public var binding: ActorIdentity?
  public var ship: String?
  public var legal: LegalRecord
  public var recordedKills = 0
  public var sighting: WantedSighting?
  public var parked: NPCPersistenceSnapshot?
  public var retired = false
  var eligible: Bool { !retired && legal.wanted && legal.bountyTenths > 0 && parked != nil }
  var valid: Bool {
    let timeValid: Bool
    if let sighting, let parked {
      timeValid = sighting.time <= parked.physicalTime
    } else {
      timeValid = true
    }
    return (0..<8).contains(identity.system.galaxy) && (0...256).contains(identity.system.system)
      && identity.visit > 0 && identity.entity >= 2 && identity.entity < UInt64.max
      && !callsign.isEmpty && callsign.count <= 96
      && (0...8192).contains(recordedKills) && (0...255).contains(legal.value)
      && legal.bountyTenths >= 0
      && (sighting?.valid ?? true)
      && (sighting.map { $0.system == identity.system } ?? true) && (parked?.valid ?? true)
      && (parked.map {
        $0.actor.system == identity.system && $0.actor.visit >= identity.visit
          && $0.actor.entity >= identity.entity && $0.npc.legal == legal
          && ($0.catalogueShipID ?? ShipCatalogue.nativeShip($0.hull)?.id) == ship
      } ?? true)
      && (binding.map { $0.system == identity.system && $0 == parked?.actor } ?? true)
      && timeValid
  }
}

public struct WantedCareerLedger: Codable, Equatable, Sendable {
  public static let maximumCareers = 4096
  /// The existing ordinary pirate bounty: 50 tenths = 5 CR. No board bonus or new curve.
  static let ordinaryBountyTenths = 50
  public private(set) var careers: [ActorIdentity: WantedCareer] = [:]
  public private(set) var playerRecordedKills = 0
  /// Old rank totals are never claimed as literal death history.
  public var earlierHistoryUnknown = true
  private var settled: Set<ActorIdentity> = []
  private var aliases: [ActorIdentity: ActorIdentity] = [:]
  public private(set) var registrationLimited = false
  public private(set) var historyLimited = false
  public init() {}
  public var valid: Bool {
    careers.count <= Self.maximumCareers && settled.count <= 8192 && aliases.count <= 16384
      && (0...8192).contains(playerRecordedKills)
      && earlierHistoryUnknown
      && careers.allSatisfy { $0.key == $0.value.identity && $0.value.valid }
      && aliases.allSatisfy { $0.key.system == $0.value.system && careers[$0.value] != nil }
  }
  func valid(in flight: FlightSimulationState) -> Bool {
    guard valid else { return false }
    let next = flight.nextActor
    let visit = flight.visit
    let time = flight.physicalTime
    return careers.values.allSatisfy {
      $0.identity.entity < next && $0.identity.visit <= visit
        && ($0.parked.map {
          $0.actor.entity < next && $0.actor.visit <= visit && $0.physicalTime <= time
        } ?? true)
    }
      && aliases.keys.allSatisfy {
        $0.entity >= 2 && $0.entity < next && $0.visit > 0 && $0.visit <= visit
      }
      && settled.allSatisfy {
        (0..<8).contains($0.system.galaxy) && (0...256).contains($0.system.system)
          && $0.entity < next && $0.visit > 0 && $0.visit <= visit
      }
  }
  static func playerReward(legal: Int) -> Int { legal > 0 ? ordinaryBountyTenths : 0 }

  mutating func observe(
    _ snapshot: NPCPersistenceSnapshot, logical: ActorIdentity, visible: Bool
  ) {
    guard snapshot.valid, snapshot.actor.system == logical.system else { return }
    if careers[logical] == nil {
      guard visible else { return }
      guard careers.count < Self.maximumCareers else {
        registrationLimited = true
        return
      }
    }
    var career =
      careers[logical]
      ?? WantedCareer(
        identity: logical,
        callsign:
          "Pilot G\(logical.system.galaxy + 1)-S\(logical.system.system)-V\(logical.visit)-A\(logical.entity)",
        binding: snapshot.actor,
        ship: snapshot.catalogueShipID ?? ShipCatalogue.nativeShip(snapshot.hull)?.id,
        legal: snapshot.npc.legal)
    guard !career.retired else { return }
    if aliases[snapshot.actor] == nil {
      if aliases.count < 16384 {
        aliases[snapshot.actor] = logical
      } else {
        registrationLimited = true
      }
    }
    career.binding = snapshot.actor
    career.ship = snapshot.catalogueShipID ?? ShipCatalogue.nativeShip(snapshot.hull)?.id
    career.legal = snapshot.npc.legal
    career.parked = snapshot
    if visible {
      let destination =
        snapshot.npc.destination != snapshot.actor.system
          && (snapshot.npc.routeProvenance == .generated
            || snapshot.npc.routeProvenance == .recorded)
        ? snapshot.npc.destination : nil
      career.sighting = .init(
        system: snapshot.actor.system, position: snapshot.position,
        heading: snapshot.orientation.z, destination: destination, time: snapshot.physicalTime)
    }
    careers[logical] = career
  }

  mutating func retire(_ logical: ActorIdentity) {
    careers[logical]?.retired = true
    careers[logical]?.binding = nil
    careers[logical]?.parked = nil
  }

  mutating func reconcile(_ ledger: NPCPersistenceLedger, system: SystemIdentity) {
    for key in Array(careers.keys) where key.system == system {
      if ledger.terminalReason(for: key) != nil {
        retire(key)
        continue
      }
      if let snapshot = ledger.snapshot(for: key) {
        observe(snapshot, logical: key, visible: false)
      }
      careers[key]?.binding = ledger.binding(for: key)
    }
  }

  /// Called only for the accepted once-only native death settlement, never a cull or rank gift.
  @discardableResult
  mutating func record(_ death: DeathSettlement, player: ActorIdentity, shipDeath: Bool) -> Bool {
    guard shipDeath, death.owner != death.victim, !settled.contains(death.victim) else {
      return false
    }
    guard settled.count < 8192 else {
      historyLimited = true
      if let key = aliases[death.victim]
        ?? careers.first(where: { $0.value.binding == death.victim })?.key
      {
        retire(key)
      }
      return false
    }
    settled.insert(death.victim)
    if death.owner == player {
      playerRecordedKills += 1
    } else if let key = aliases[death.owner]
      ?? careers.first(where: { $0.value.binding == death.owner })?.key
    {
      careers[key]?.recordedKills += 1
    }
    if let key = aliases[death.victim]
      ?? careers.first(where: { $0.value.binding == death.victim })?.key
    {
      retire(key)
    }
    return true
  }
}

struct WantedBoardEntry: Equatable, Sendable {
  let identity: ActorIdentity?
  let name: String
  let ship: String?
  let legal: LegalRecord
  let recordedKills: Int
  let sighting: WantedSighting?
  var isPlayer: Bool { identity == nil }
  var stableKey: String {
    identity.map { "\($0.system.galaxy):\($0.system.system):\($0.visit):\($0.entity)" } ?? "PLAYER"
  }
  static func precedes(_ a: Self, _ b: Self) -> Bool {
    if a.legal.bountyTenths != b.legal.bountyTenths {
      return a.legal.bountyTenths > b.legal.bountyTenths
    }
    if a.recordedKills != b.recordedKills { return a.recordedKills > b.recordedKills }
    if a.legal.value != b.legal.value { return a.legal.value > b.legal.value }
    return a.stableKey < b.stableKey
  }

}

extension Game {
  func wantedCareerIsOrdinary(_ body: SpaceBody) -> Bool {
    guard let physical = body.physical, physical.npc?.role != .mission,
      body.gameplayProtectionReasons.isEmpty, !physical.blocksNavalEncounter,
      physical.spawnIdentity?.producer != .provider, physical.spawnIdentity?.producer != .mission,
      !isNativeCrimboMember(physical.identity)
    else { return false }
    return true
  }

  var wantedBoard: [WantedBoardEntry] {
    let galaxy = commander.galaxy
    let ledger = commander.wantedCareers
    var rows = ledger.careers.values.filter {
      $0.identity.system.galaxy == galaxy && $0.eligible
    }.map {
      WantedBoardEntry(
        identity: $0.identity, name: $0.callsign, ship: $0.ship, legal: $0.legal,
        recordedKills: $0.recordedKills, sighting: $0.sighting)
    }
    if commander.legal > 0 {
      rows.append(
        .init(
          identity: nil, name: commander.name + " (YOU)", ship: commander.shipID,
          legal: .init(
            value: min(255, commander.legal),
            bountyTenths: WantedCareerLedger.playerReward(legal: commander.legal)),
          recordedKills: ledger.playerRecordedKills, sighting: nil))
    }
    return Array(rows.sorted(by: WantedBoardEntry.precedes).prefix(10))
  }

  func wantedRank(for body: SpaceBody) -> Int? {
    guard body.hull.isTargetShip, body.energy > 0, wantedCareerIsOrdinary(body),
      body.physical?.ordnance == nil,
      body.physical?.empCrewPod == nil, body.physical?.payload == nil,
      body.physical?.salvage == nil, body.gameplayProtectionReasons.isEmpty,
      let physical = body.physical, let npc = physical.npc, npc.legal.wanted,
      npc.legal.bountyTenths > 0,
      bodies.filter({ $0.physical?.identity == physical.identity }).count == 1,
      bodies.first(where: { $0.physical?.identity == physical.identity }) == body,
      let logical = commander.npcPersistence.logicalIdentity(for: physical.identity),
      let career = commander.wantedCareers.careers[logical], career.binding == physical.identity,
      career.legal == npc.legal,
      career.ship == (physical.catalogueShipID ?? ShipCatalogue.nativeShip(body.hull)?.id)
    else { return nil }
    // Rank the current joined craft with a bounded scan; world cues do not sort
    // and allocate a whole board for each rendered body.
    let galaxy = commander.galaxy
    let ledger = commander.wantedCareers
    let entry = WantedBoardEntry(
      identity: logical, name: career.callsign, ship: career.ship,
      legal: career.legal, recordedKills: career.recordedKills, sighting: career.sighting)
    guard career.eligible else { return nil }
    var rank = 1
    for other in ledger.careers.values
    where other.identity != logical
      && other.identity.system.galaxy == galaxy && other.eligible
    {
      let candidate = WantedBoardEntry(
        identity: other.identity, name: other.callsign,
        ship: other.ship, legal: other.legal, recordedKills: other.recordedKills,
        sighting: other.sighting)
      if WantedBoardEntry.precedes(candidate, entry) { rank += 1 }
      if rank > 10 { return nil }
    }
    if commander.legal > 0 {
      let player = WantedBoardEntry(
        identity: nil, name: commander.name, ship: commander.shipID,
        legal: .init(
          value: min(255, commander.legal),
          bountyTenths: WantedCareerLedger.playerReward(legal: commander.legal)),
        recordedKills: ledger.playerRecordedKills, sighting: nil)
      if WantedBoardEntry.precedes(player, entry) { rank += 1 }
    }
    return rank <= 10 ? rank : nil
  }

  func wantedNotice(for body: SpaceBody) -> String? {
    guard let rank = wantedRank(for: body), let reward = body.physical?.npc?.legal.bountyTenths
    else { return nil }
    return "WANTED #\(rank) / \(Self.wantedCredits(reward)) CR"
  }
  static func wantedCredits(_ tenths: Int) -> String { "\(tenths / 10).\(tenths % 10)" }
}
