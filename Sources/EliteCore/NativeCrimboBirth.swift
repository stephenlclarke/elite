import Foundation

/// New estimated project birth policy. This immutable origin never owns later crew outcomes.
struct NativeCrimboOriginalBirth: Equatable, Codable, Sendable {
  static let crewPolicy = "native-crimbo-crew-v1"
  static let avionicsPolicy = "native-crimbo-link-v1"
  let world: UUID
  let provider: NativeProviderIdentity
  let member: UUID
  let logical: NPCLogicalIdentity
  let firstSpawn: SpawnIdentity
  let catalogueShipID: String
  let crewCount: Int
  let admittedAt: Double
  let crewPolicyRevision: String
  let avionicsPolicyRevision: String

  func valid(member original: NativeCrimboMember, registry: NativeCrimboRegistry) -> Bool {
    world == registry.world && provider == registry.provider && member == original.identity
      && original.ownership.logical == logical && catalogueShipID == original.catalogueShipID
      && crewCount == 1 && crewPolicyRevision == Self.crewPolicy
      && avionicsPolicyRevision == Self.avionicsPolicy
      && admittedAt.isFinite && admittedAt >= 0
      && firstSpawn.system == NativeCrimboRegistry.system && firstSpawn.producer == .provider
      && firstSpawn.sequence == registry.spawnSequence && firstSpawn.member == UInt16(original.slot)
      && firstSpawn.visit == logical.firstActor.visit && logical.firstActor.entity > 1
      && logical.firstActor.system == firstSpawn.system
  }

  /// Only the actual first pending admission calls this after the complete ordinary ACK.
  static func admitted(
    member: NativeCrimboMember, logical: NPCLogicalIdentity, spawn: SpawnIdentity,
    registry: NativeCrimboRegistry, time: Double
  ) throws -> Self {
    guard member.ownership == .pending, member.originalBirth == nil,
      let ship = ShipCatalogue.ship(member.catalogueShipID), ship.catalogue.origin == .human,
      try ShipAccommodationProfile(ship: ship).operatingCrew == 1
    else { throw NativeCrimboError.invalidTransfer }
    return .init(
      world: registry.world, provider: registry.provider, member: member.identity,
      logical: logical, firstSpawn: spawn, catalogueShipID: member.catalogueShipID, crewCount: 1,
      admittedAt: time, crewPolicyRevision: crewPolicy, avionicsPolicyRevision: avionicsPolicy)
  }
}

extension Commander {
  /// Full graph check, not EMP dictionary-key equality. Historical custody is never restored here.
  func nativeCrimboEMPJoin(
    member: NativeCrimboMember, logical: NPCLogicalIdentity, record: EMPHullRecord
  ) -> Bool {
    guard record.valid, empCustodyStateValid, record.source == logical.firstActor,
      record.custody.valid, record.custody.kind == .ordinary,
      record.custody.logical == logical.firstActor,
      let original = record.custody.original.body.physical,
      original.catalogueShipID == member.catalogueShipID,
      original.npc?.role == member.role, record.custody.original.body.hull == member.hull,
      record.originalSpawn == original.spawnIdentity,
      let traffic = record.custody.traffic,
      NativeCrimboRegistry.matches(traffic, member: member), traffic.actor == original.identity,
      record.activeTrafficTransfer.map({ NativeCrimboRegistry.matches($0, member: member) }) == true
    else { return false }
    if let birth = member.originalBirth {
      guard birth.logical == logical, birth.crewCount == record.crewTotal else { return false }
    }
    return true
  }
}

extension Game {
  /// G1 invokes only in the actual EMP candidate after its native record/ACK is validated.
  /// Unknown older birth does not grant mission evidence or make the original immune to EMP.
  mutating func observeNativeCrimboEMPTransition(source: ActorIdentity) -> Bool {
    guard nativeCrimboLifecycleAvailable, var registry = commander.savedCrimboState,
      let index = registry.members.firstIndex(where: { $0.ownership.logical?.firstActor == source })
    else { return true }
    let member = registry.members[index]
    guard registry.world == commander.equipmentOwnerID, (try? registry.validate()) != nil,
      let logical = member.ownership.logical, let record = commander.savedEMPState?.records[source],
      commander.nativeCrimboEMPJoin(member: member, logical: logical, record: record)
    else { return false }
    if case .terminal(_, let reason) = member.ownership {
      return (record.terminal || record.savedOrdinaryTerminal != nil)
        && reason == (record.savedOrdinaryTerminal ?? .destroyed)
    }
    if record.terminal || record.savedOrdinaryTerminal != nil {
      registry.members[index].ownership = .terminal(
        logical, record.savedOrdinaryTerminal ?? .destroyed)
    } else if record.isRecovered {
      guard record.crewAboard > 0,
        commander.npcPersistence.terminalReason(for: source) == nil,
        let snapshot = commander.npcPersistence.snapshot(for: source),
        NativeCrimboRegistry.matches(snapshot, member: member)
      else { return false }
      registry.members[index].ownership = .live(logical)
    } else {
      guard commander.npcPersistence.terminalReason(for: source) == .empTransferred,
        commander.npcPersistence.empTransfers[source] == record.activeTrafficTransfer
      else { return false }
      registry.members[index].ownership = .electrical(logical, source)
    }
    guard (try? registry.validate()) != nil else { return false }
    commander.savedCrimboState = registry
    nativeCrimboMotionSample = nil
    nativeCrimboAttainedMotion = nil
    return true
  }
}
