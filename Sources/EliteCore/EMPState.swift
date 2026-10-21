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
  case aboard, occupiedPod, captured, deceasedWithHull
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
  var savedCrewCaptures: [NativeCrewCaptureReceipt]?
  var savedDisableEpisodes: [EMPCrewDisableEpisode]?
  var savedDeceasedOrdinals: [Int]?
  var crewCaptures: [NativeCrewCaptureReceipt] {
    get { savedCrewCaptures ?? [] }
    set { savedCrewCaptures = newValue.isEmpty ? nil : newValue }
  }
  var capturedCrewCount: Int {
    guard crewCaptures.count <= EMPState.maximumPeople,
      crewCaptures.allSatisfy({ (1...EMPState.maximumPeople).contains($0.count) })
    else { return EMPState.maximumPeople + 1 }
    return crewCaptures.reduce(0) { $0 + $1.count }
  }
  var crewAboard: Int {
    guard (1...EMPState.maximumPeople).contains(crewTotal),
      (0...crewTotal).contains(lostCrewCount), pods.count <= crewTotal,
      capturedCrewCount <= crewTotal
    else { return -1 }
    return crewTotal - pods.count - lostCrewCount - capturedCrewCount
  }
  var crewDeadline: Double? {
    let deadline = currentCrewDisableIncident.physicalTime + 30
    return deadline.isFinite && deadline >= currentCrewDisableIncident.physicalTime ? deadline : nil
  }
  var deceasedOrdinals: [Int] {
    if let savedDeceasedOrdinals { return savedDeceasedOrdinals }
    guard (1...EMPState.maximumPeople).contains(crewTotal),
      (0...crewTotal).contains(lostCrewCount)
    else { return [] }
    // Schema 22/23 recorded a contiguous tail before any native captures existed.
    return Array((crewTotal - lostCrewCount)..<crewTotal)
  }

  func crewOutcome(ordinal: Int) -> EMPCrewCustodyOutcome? {
    guard (0..<crewTotal).contains(ordinal) else { return nil }
    if podIndex(for: ordinal) != nil { return .occupiedPod }
    if crewCaptures.contains(where: { $0.contains(ordinal) }) { return .captured }
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
      capturedCrewCount <= crewTotal - pods.count, crewAboard >= 0, crewDeadline != nil,
      crewCensusValid,
      crewCaptures.count <= EMPState.maximumPeople,
      savedCrewCaptures == nil || !crewCaptures.isEmpty,
      Set(crewCaptures.map(\.operation)).count == crewCaptures.count,
      crewCaptures.allSatisfy({ $0.valid(record: self) }),
      crewCaptures.enumerated().allSatisfy({ index, receipt in
        index == 0 || receipt.physicalTime >= crewCaptures[index - 1].physicalTime
      }),
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
      lostCrewCount == (terminal ? crewTotal - pods.count - capturedCrewCount : 0)
    else { return false }
    if !terminal {
      guard hull.body.physical?.salvage?.ownership == (crewAboard > 0 ? .occupied : .abandoned),
        (hull.body.physical?.npc != nil) == (crewAboard > 0),
        hull.body.physical?.population
          == (crewAboard > 0 ? custody.original.body.physical?.population : .wreck),
        crewAboard == 0 || hull.body.physical?.npc?.ordinaryCargo == cargo
      else { return false }
    }
    return pods.allSatisfy { pod in
      guard let person = pod.body.physical?.empCrewPod,
        person.source == source, (0..<crewTotal).contains(person.ordinal)
      else { return false }
      return
        pod.valid && pod.body.energy > 0 && pod.body.hull == .cargo
        && pod.body.physical?.empSource == nil && pod.body.physical?.npc == nil
        && pod.body.physical?.spawnIdentity?.producer == .emp
        && pod.body.physical?.spawnIdentity?.sequence == sequence
        && pod.body.physical?.spawnIdentity?.member == UInt16(person.ordinal + 1)
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

extension EMPHullRecord {
  private enum CodingKeys: String, CodingKey {
    case source, sequence, wreck, crewTotal, originalSpawn, originalBodyID, custody, disableIncident
    case weapon, weaponOwner, pods, hull, cargo, legal, nextEjectionAt, terminal, lostCrewCount,
      savedCrewCaptures, savedDisableEpisodes, savedDeceasedOrdinals
  }
  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    let captures = try NativePeopleDecoding.array(
      values, key: .savedCrewCaptures, type: NativeCrewCaptureReceipt.self)
    let episodes = try NativePeopleDecoding.array(
      values, key: .savedDisableEpisodes, type: EMPCrewDisableEpisode.self,
      maximum: Self.maximumDisableEpisodes)
    let deceased = try NativePeopleDecoding.array(
      values, key: .savedDeceasedOrdinals, type: Int.self)
    guard let pods = try NativePeopleDecoding.array(values, key: .pods, type: EMPStoredObject.self)
    else { throw SaveError.invalidCommander }
    self.init(
      source: try values.decode(ActorIdentity.self, forKey: .source),
      sequence: try values.decode(UInt64.self, forKey: .sequence),
      wreck: try values.decode(WreckIdentity.self, forKey: .wreck),
      crewTotal: try values.decode(Int.self, forKey: .crewTotal),
      originalSpawn: try values.decodeIfPresent(SpawnIdentity.self, forKey: .originalSpawn),
      originalBodyID: try values.decode(Int.self, forKey: .originalBodyID),
      custody: try values.decode(EMPSourceCustody.self, forKey: .custody),
      disableIncident: try values.decode(CombatIncident.self, forKey: .disableIncident),
      weapon: try values.decode(OwnedEquipmentItem.self, forKey: .weapon),
      weaponOwner: try values.decode(UUID.self, forKey: .weaponOwner),
      pods: pods,
      hull: try values.decode(EMPStoredObject.self, forKey: .hull),
      cargo: try values.decode([CommodityAmount].self, forKey: .cargo),
      legal: try values.decode(LegalRecord.self, forKey: .legal),
      nextEjectionAt: try values.decode(Double.self, forKey: .nextEjectionAt),
      terminal: try values.decode(Bool.self, forKey: .terminal),
      lostCrewCount: try values.decode(Int.self, forKey: .lostCrewCount),
      savedCrewCaptures: captures, savedDisableEpisodes: episodes, savedDeceasedOrdinals: deceased)
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
