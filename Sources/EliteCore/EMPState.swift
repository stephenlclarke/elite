import Foundation

/// A person belongs to one original disabled craft, regardless of physical re-admission.
public struct EMPCrewIdentity: Hashable, Codable, Sendable {
  public let source: ActorIdentity
  public let ordinal: Int
}

struct EMPStoredObject: Equatable, Codable, Sendable {
  var body: SpaceBody
  var binding: ActorIdentity?
  var physicalTime: Double

  var valid: Bool {
    guard let physical = body.physical else { return false }
    return body.position.finite && body.orientation.validRotation
      && physical.velocity.finite && physical.angularVelocity.finite
      && body.rotation.isFinite && body.rotationRate.isFinite
      && body.energy.isFinite && (0...1e12).contains(body.energy) && body.missiles >= 0
      && physicalTime.isFinite && physicalTime >= 0
      && (physical.npc?.resources?.valid ?? true)
      && body.missionActorID == nil && body.missionInstanceID == nil
      && body.scriptNPC == nil && body.scriptShot == nil && !body.navalTarget
      && !body.enemyMissile && body.playerMissileTarget == nil && body.missileSourceID == nil
      && body.nativeStationIdentity == nil && physical.npc?.role != .mission
      && body.blackjackRole == nil && body.blackjackIdentity == nil
      && physical.ordnance == nil && physical.payload == nil && physical.rock == nil
      && (!physical.blocksNavalEncounter || physical.npc?.role == .police)
      && (binding == nil || binding == physical.identity)
  }

  init(body: SpaceBody, pose: ShipPose, time: Double) {
    self.body = body
    self.body.position = pose.systemPoint(body.position)
    self.body.orientation = body.orientation.transformed(by: pose.orientation)
    binding = body.physical?.identity
    physicalTime = time
  }
}

enum EMPCrewCustodyOutcome: String, Sendable {
  case aboard, occupiedPod, deceasedWithHull
}

struct EMPHullRecord: Equatable, Codable, Sendable {
  let source: ActorIdentity
  let sequence: UInt64
  let wreck: WreckIdentity
  let crewTotal: Int
  let originalSpawn: SpawnIdentity?
  let originalBodyID: Int
  let custody: EMPSourceCustody
  let disableIncident: CombatIncident
  let weapon: OwnedEquipmentItem
  let weaponOwner: UUID
  var pods: [EMPStoredObject] = []
  var hull: EMPStoredObject
  let cargo: [CommodityAmount]
  let legal: LegalRecord
  var nextEjectionAt = 0.0
  var terminal = false
  var lostCrewCount = 0
  var crewAboard: Int { crewTotal - pods.count - lostCrewCount }
  var deceasedOrdinals: Range<Int> { (crewTotal - lostCrewCount)..<crewTotal }

  func crewOutcome(ordinal: Int) -> EMPCrewCustodyOutcome? {
    guard (0..<crewTotal).contains(ordinal) else { return nil }
    if ordinal < pods.count { return .occupiedPod }
    return deceasedOrdinals.contains(ordinal) ? .deceasedWithHull : .aboard
  }

  var valid: Bool {
    guard source.visit > 0, source.entity > 1, source.entity < UInt64.max,
      (0..<8).contains(source.system.galaxy), (0...256).contains(source.system.system),
      custody.valid, custody.logical == source, custody.original.body.id == originalBodyID,
      custody.original.body.physical?.spawnIdentity == originalSpawn,
      custody.original.body.physical?.npc?.ordinaryCargo == cargo,
      custody.original.body.physical?.npc?.legal == legal,
      custody.original.body.hull == hull.body.hull,
      disableIncident.id > 0, disableIncident.kind == .emp, disableIncident.outcome == .hit,
      disableIncident.victim == custody.original.body.physical?.identity,
      disableIncident.victimLegalBeforeAttack == legal,
      disableIncident.victimRole == custody.original.body.physical?.npc?.role,
      !disableIncident.victimIsStation, disableIncident.origin.owner.entity == 0,
      disableIncident.origin.owner.system == source.system,
      disableIncident.origin.owner.visit == custody.original.body.physical?.identity.visit,
      weapon.node == EquipmentRuntimeCatalog.node(for: Equipment.empPirateBlaster),
      weapon.location?.slot == .utility(.empPirateBlaster), weapon.component == nil,
      disableIncident.origin.sourcePart == "emp:" + weapon.id.uuidString,
      disableIncident.origin.emissionID > 0, disableIncident.position.finite,
      disableIncident.physicalTime.isFinite, disableIncident.physicalTime >= 0,
      disableIncident.origin.emittedAt == disableIncident.physicalTime,
      sequence > 0, sequence < 1_000_000_000, originalBodyID >= 0,
      originalSpawn?.system == source.system || originalSpawn == nil, wreck.system == source.system,
      wreck.site == 0x8000_0000 + UInt32(sequence), wreck.lineage == source.visit,
      (1...EMPState.maximumPeople).contains(crewTotal), pods.count <= crewTotal,
      hull.valid, hull.body.physical?.empSource == source,
      hull.body.physical?.empCrewPod == nil,
      hull.body.physical?.spawnIdentity?.producer == .emp,
      hull.body.physical?.spawnIdentity?.sequence == sequence,
      hull.body.physical?.spawnIdentity?.member == 0,
      hull.body.physical?.spawnIdentity?.system == source.system,
      [.cobra, .viper, .sidewinder].contains(hull.body.hull),
      let catalogue = hull.body.physical?.catalogueShipID,
      let ship = ShipCatalogue.ship(catalogue), EMPState.hasSupportedCrew(ship),
      catalogue
        == (custody.original.body.physical?.catalogueShipID
          ?? ShipCatalogue.nativeShip(custody.original.body.hull)?.id),
      let complement = try? ShipAccommodationProfile(ship: ship),
      complement.operatingCrew == crewTotal,
      let profile = SalvageCatalogue.empProfile(catalogueShipID: catalogue),
      let metadata = hull.body.physical?.salvage, metadata.wreck == wreck,
      metadata.category == .wreck, metadata.claimant == nil, metadata.section == nil,
      metadata.lot == nil,
      metadata.bounds == profile.bounds, metadata.workSurfaces == profile.surfaces(wreck: wreck),
      cargo.allSatisfy(\.valid), Set(cargo.map(\.commodity)).count == cargo.count,
      (0...255).contains(legal.value), legal.bountyTenths >= 0,
      nextEjectionAt.isFinite, nextEjectionAt >= 0,
      terminal == (hull.body.energy <= 0),
      lostCrewCount == (terminal ? crewTotal - pods.count : 0)
    else { return false }
    if !terminal {
      guard hull.body.physical?.salvage?.ownership == (crewAboard > 0 ? .occupied : .abandoned),
        (hull.body.physical?.npc != nil) == (crewAboard > 0),
        hull.body.physical?.population
          == (crewAboard > 0 ? custody.original.body.physical?.population : .wreck),
        crewAboard == 0 || hull.body.physical?.npc?.ordinaryCargo == cargo
      else { return false }
    }
    return pods.enumerated().allSatisfy { index, pod in
      pod.valid && pod.body.energy > 0 && pod.body.hull == .cargo
        && pod.body.physical?.empCrewPod == .init(source: source, ordinal: index)
        && pod.body.physical?.empSource == nil && pod.body.physical?.npc == nil
        && pod.body.physical?.spawnIdentity?.producer == .emp
        && pod.body.physical?.spawnIdentity?.sequence == sequence
        && pod.body.physical?.spawnIdentity?.member == UInt16(index + 1)
        && pod.body.physical?.spawnIdentity?.system == source.system
        && pod.body.physical?.population == .cargo && !pod.body.hostile
        && pod.body.physical?.catalogueShipID == "SH040"
        && pod.body.physical?.salvage?.category == .occupiedPod
        && pod.body.physical?.salvage?.ownership == .occupied
        && pod.body.physical?.salvage?.claimant == source
        && pod.body.physical?.salvage?.wreck == nil
        && pod.body.physical?.salvage?.section == nil && pod.body.physical?.salvage?.lot == nil
        && pod.body.physical?.salvage?.workSurfaces.isEmpty == true
    }
  }
}

/// Bounded lifetime custody; traffic culling and system departure never regenerate these people or hulls.
struct EMPState: Equatable, Codable, Sendable {
  static let maximumHulls = 32
  static let maximumPeople = 256
  var records: [ActorIdentity: EMPHullRecord] = [:]
  var nextSequence: UInt64 = 1
  var sources: [ActorIdentity] {
    records.keys.sorted {
      ($0.system.galaxy, $0.system.system, $0.visit, $0.entity)
        < ($1.system.galaxy, $1.system.system, $1.visit, $1.entity)
    }
  }
  static func hasSupportedCrew(_ ship: CatalogueShip) -> Bool {
    if let native = ship.nativeHull,
      [.thargoid, .thargon, .station, .asteroid, .cargo, .missile].contains(native)
    {
      return false
    }
    let name = ship.name.lowercased()
    return !["thargoid", "thargon", "drone", "satellite"].contains(where: name.contains)
  }
  var valid: Bool {
    guard records.count <= Self.maximumHulls, nextSequence > 0, nextSequence < 1_000_000_000,
      records.allSatisfy({
        $0.key == $0.value.source && $0.value.sequence < nextSequence && $0.value.valid
      })
    else { return false }
    // Validate each bounded complement before adding values from an untrusted save.
    return records.values.reduce(0, { $0 + $1.crewTotal }) <= Self.maximumPeople
      && Set(records.values.map(\.sequence)).count == records.count
  }
}

extension Commander {
  var usesEMPSaveVersion: Bool {
    savedEMPState != nil
      || equipmentInventory?.items.contains { $0.node.key == Equipment.empPirateBlaster } == true
  }
}
