import Foundation

enum NativePeopleDecoding {
  static func array<T: Decodable, K: CodingKey>(
    _ values: KeyedDecodingContainer<K>, key: K, type: T.Type,
    maximum: Int = EMPState.maximumPeople
  ) throws -> [T]? {
    guard values.contains(key), try !values.decodeNil(forKey: key) else { return nil }
    var entries = try values.nestedUnkeyedContainer(forKey: key)
    guard (entries.count ?? 0) <= maximum else {
      throw DecodingError.dataCorruptedError(
        in: entries, debugDescription: "Native person collection limit exceeded.")
    }
    var result: [T] = []
    while !entries.isAtEnd {
      guard result.count < maximum else {
        throw DecodingError.dataCorruptedError(
          in: entries, debugDescription: "Native person collection limit exceeded.")
      }
      result.append(try entries.decode(type))
    }
    return result
  }
}

/// Extensible source reference, not another generated person or crew roster.
public enum NativePersonReference: Hashable, Codable, Sendable {
  case emp(EMPCrewIdentity)
  case station(NativeStationPersonIdentity)
  case rescue(NativeOriginalRescueIdentity)
  case evacuation(NativeOriginalEvacuationIdentity)
  var emp: EMPCrewIdentity? {
    switch self {
    case .emp(let person): person
    case .station, .rescue, .evacuation: nil
    }
  }
  var key: String {
    switch self {
    case .station(let person): return person.key
    case .rescue(let person): return person.key
    case .evacuation(let person): return person.key
    case .emp(let person):
      return
        "emp:\(person.source.system.galaxy):\(person.source.system.system):\(person.source.visit):\(person.source.entity):\(person.ordinal)"
    }
  }
  var rescue: NativeOriginalRescueIdentity? {
    if case .rescue(let person) = self { return person }
    return nil
  }
  var evacuation: NativeOriginalEvacuationIdentity? {
    if case .evacuation(let person) = self { return person }
    return nil
  }
  var nativeID: UUID? { station?.id ?? rescue?.id ?? evacuation?.id }
  var station: NativeStationPersonIdentity? {
    if case .station(let person) = self { return person }
    return nil
  }

}

enum NativePeopleOrigin: String, Codable, Sendable {
  case rescuedPod, capturedCrew, stationPassenger, originalRescuedPod, orbitalEvacuee
}
enum NativePeopleTransfer: String, Codable, Sendable { case care, sale, loss, escape }

/// Permanent discharge from the original hull, retained even after all player custody ends.
struct NativeCrewCaptureReceipt: Equatable, Codable, Sendable {
  let operation: UUID
  let ordinals: [Int]
  let episode: UInt64
  var count: Int { ordinals.count }
  let actor: ActorIdentity
  let collector: ActorIdentity
  let owner: UUID
  let hull: UUID
  let tool: UUID
  let physicalTime: Double
  func valid(record: EMPHullRecord) -> Bool {
    owner == record.weaponOwner && count > 0 && count <= record.crewTotal
      && Set(ordinals).count == count && ordinals == ordinals.sorted()
      && ordinals.allSatisfy({ (0..<record.crewTotal).contains($0) })
      && actor.system == record.source.system
      && actor.entity > 1 && actor.visit > 0 && collector.system == actor.system
      && collector.visit == actor.visit && collector.entity == 0
      && physicalTime.isFinite
      && record.disableEpisodes.contains { entry in
        entry.incident.id == episode && entry.actorBindings.contains(actor)
          && physicalTime >= entry.incident.physicalTime && physicalTime < entry.deadline
          && (entry.legacyTiming
            || ordinals.allSatisfy { ordinal in entry.ejections.contains { $0.ordinal == ordinal } })
      }
  }
  func contains(_ ordinal: Int) -> Bool {
    ordinals.contains(ordinal)
  }
}

extension NativeCrewCaptureReceipt {
  private enum CodingKeys: String, CodingKey {
    case operation, ordinals, episode, actor, collector, owner, hull, tool, physicalTime
  }
  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    guard let ordinals = try NativePeopleDecoding.array(values, key: .ordinals, type: Int.self)
    else { throw SaveError.invalidCommander }
    self.init(
      operation: try values.decode(UUID.self, forKey: .operation), ordinals: ordinals,
      episode: try values.decode(UInt64.self, forKey: .episode),
      actor: try values.decode(ActorIdentity.self, forKey: .actor),
      collector: try values.decode(ActorIdentity.self, forKey: .collector),
      owner: try values.decode(UUID.self, forKey: .owner),
      hull: try values.decode(UUID.self, forKey: .hull),
      tool: try values.decode(UUID.self, forKey: .tool),
      physicalTime: try values.decode(Double.self, forKey: .physicalTime))
  }
}

struct NativePeopleAdmission: Equatable, Codable, Sendable {
  let person: NativePersonReference
  let origin: NativePeopleOrigin
  let operation: UUID
  let actor: ActorIdentity
  let collector: ActorIdentity
  let owner: UUID
  let hull: UUID
  let tool: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let epoch: UUID
  let revision: UInt64
  func valid(commander: Commander) -> Bool {
    if case .evacuation = person {
      return NativeOriginalEvacuation.validAdmission(self, commander: commander)
    }
    if case .rescue = person {
      return NativeOriginalRescueJourney.validAdmission(self, commander: commander)
    }
    if case .station = person {
      return person.station?.batch == NativeOrbitalOutlookJourney.batch
        ? NativeOrbitalOutlookJourney.validAdmission(self, commander: commander)
        : NativeStationPassengerJourney.validAdmission(self, commander: commander)
    }
    guard let identity = person.emp else { return false }
    guard owner == commander.equipmentOwnerID,
      let record = commander.savedEMPState?.records[identity.source], record.valid,
      (0..<record.crewTotal).contains(identity.ordinal), actor.entity > 1,
      actor.system == identity.source.system, actor.visit > 0,
      actor.visit <= commander.flightSimulation.visit,
      actor.entity < commander.flightSimulation.nextActor,
      collector.system == actor.system && collector.visit == actor.visit && collector.entity == 0,
      physicalTime.isFinite, physicalTime >= record.disableIncident.physicalTime,
      physicalTime <= commander.flightSimulation.physicalTime, revision > 0
    else { return false }
    switch origin {
    case .stationPassenger, .originalRescuedPod, .orbitalEvacuee: return false
    case .rescuedPod:
      guard let index = record.podIndex(for: identity.ordinal),
        let emitted = record.podEjectionLowerBound(for: identity.ordinal), physicalTime >= emitted
      else { return false }
      return record.pods[index].body.physical?.identity == actor
        && record.pods[index].binding == nil
    case .capturedCrew:
      return record.crewCaptures.contains {
        $0.operation == operation && $0.contains(identity.ordinal) && $0.actor == actor
          && $0.collector == collector && $0.owner == owner && $0.hull == hull
          && $0.tool == tool && $0.physicalTime == physicalTime
      }
    }
  }
}

struct NativePeopleTransferReceipt: Equatable, Codable, Sendable {
  let operation: UUID
  let members: [NativePersonReference]
  let kind: NativePeopleTransfer
  let dock: NativeMainStationDockReceipt?
  let collector: ActorIdentity
  let owner: UUID
  let physicalTime: Double
  let calendarSeconds: Double
  let beforeCash: Int
  let afterCash: Int
  let beforeSlaves: Int
  let afterSlaves: Int
  let price: Int
  let epoch: UUID
  let revision: UInt64
}

extension NativePeopleTransferReceipt {
  private enum CodingKeys: String, CodingKey {
    case operation, members, kind, dock, collector, owner, physicalTime, calendarSeconds
    case beforeCash, afterCash, beforeSlaves, afterSlaves, price, epoch, revision
  }
  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    guard
      let members = try NativePeopleDecoding.array(
        values, key: .members, type: NativePersonReference.self)
    else { throw SaveError.invalidCommander }
    self.init(
      operation: try values.decode(UUID.self, forKey: .operation), members: members,
      kind: try values.decode(NativePeopleTransfer.self, forKey: .kind),
      dock: try values.decodeIfPresent(NativeMainStationDockReceipt.self, forKey: .dock),
      collector: try values.decode(ActorIdentity.self, forKey: .collector),
      owner: try values.decode(UUID.self, forKey: .owner),
      physicalTime: try values.decode(Double.self, forKey: .physicalTime),
      calendarSeconds: try values.decode(Double.self, forKey: .calendarSeconds),
      beforeCash: try values.decode(Int.self, forKey: .beforeCash),
      afterCash: try values.decode(Int.self, forKey: .afterCash),
      beforeSlaves: try values.decode(Int.self, forKey: .beforeSlaves),
      afterSlaves: try values.decode(Int.self, forKey: .afterSlaves),
      price: try values.decode(Int.self, forKey: .price),
      epoch: try values.decode(UUID.self, forKey: .epoch),
      revision: try values.decode(UInt64.self, forKey: .revision))
  }
}

/// Player custody only. Outbound receipts do not assert a permanent station population.
struct NativePeopleCustodyState: Equatable, Codable, Sendable {
  static let maximumPeople = EMPState.maximumPeople
  // Storage never escapes this value. Every mutable access detaches a shared reference first.
  // The unchecked conformance is confined to this private COW backing; callers receive values.
  private final class Storage: @unchecked Sendable {
    let owner: UUID
    var revision: UInt64 = 0
    var stationJourney: NativeStationPassengerJourneyState? = nil
    var outlookJourney: NativeOrbitalOutlookJourneyState? = nil
    var originalRescue: NativeOriginalRescueJourneyState? = nil
    var orbitalEvacuation: NativeOriginalEvacuationState? = nil
    var admissions: [NativePeopleAdmission] = []
    var transfers: [NativePeopleTransferReceipt] = []

    init(owner: UUID) { self.owner = owner }

    @inline(never)
    convenience init(copying source: Storage) {
      self.init(owner: source.owner)
      copyRevision(from: source)
      copyStationJourney(from: source)
      copyOutlookJourney(from: source)
      copyOriginalRescue(from: source)
      copyOrbitalEvacuation(from: source)
      copyAdmissions(from: source)
      copyTransfers(from: source)
    }

    @inline(never)
    private func copyRevision(from source: Storage) {
      revision = source.revision
    }

    @inline(never)
    private func copyStationJourney(from source: Storage) {
      stationJourney = source.stationJourney
    }

    @inline(never)
    private func copyOutlookJourney(from source: Storage) {
      outlookJourney = source.outlookJourney
    }

    @inline(never)
    private func copyOriginalRescue(from source: Storage) {
      originalRescue = source.originalRescue
    }

    @inline(never)
    private func copyOrbitalEvacuation(from source: Storage) {
      orbitalEvacuation = source.orbitalEvacuation
    }

    @inline(never)
    private func copyAdmissions(from source: Storage) {
      admissions = source.admissions
    }

    @inline(never)
    private func copyTransfers(from source: Storage) {
      transfers = source.transfers
    }
  }

  private var storage: Storage

  init(owner: UUID) { storage = Storage(owner: owner) }

  @inline(never)
  private mutating func ensureUniqueStorage() {
    if !isKnownUniquelyReferenced(&storage) { storage = Storage(copying: storage) }
  }

  var owner: UUID { storage.owner }

  var revision: UInt64 {
    _read { yield storage.revision }
    set {
      ensureUniqueStorage()
      storage.revision = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &storage.revision
    }
  }

  var stationJourney: NativeStationPassengerJourneyState? {
    _read { yield storage.stationJourney }
    set {
      ensureUniqueStorage()
      storage.stationJourney = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &storage.stationJourney
    }
  }

  var outlookJourney: NativeOrbitalOutlookJourneyState? {
    _read { yield storage.outlookJourney }
    set {
      ensureUniqueStorage()
      storage.outlookJourney = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &storage.outlookJourney
    }
  }

  var originalRescue: NativeOriginalRescueJourneyState? {
    _read { yield storage.originalRescue }
    set {
      ensureUniqueStorage()
      storage.originalRescue = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &storage.originalRescue
    }
  }

  var orbitalEvacuation: NativeOriginalEvacuationState? {
    _read { yield storage.orbitalEvacuation }
    set {
      ensureUniqueStorage()
      storage.orbitalEvacuation = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &storage.orbitalEvacuation
    }
  }

  var admissions: [NativePeopleAdmission] {
    _read { yield storage.admissions }
    set {
      ensureUniqueStorage()
      storage.admissions = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &storage.admissions
    }
  }

  var transfers: [NativePeopleTransferReceipt] {
    _read { yield storage.transfers }
    set {
      ensureUniqueStorage()
      storage.transfers = newValue
    }
    _modify {
      ensureUniqueStorage()
      yield &storage.transfers
    }
  }

  @inline(never)
  static func == (lhs: Self, rhs: Self) -> Bool {
    guard equalOwner(lhs.storage, rhs.storage) else { return false }
    guard equalRevision(lhs.storage, rhs.storage) else { return false }
    guard equalStationJourney(lhs.storage, rhs.storage) else { return false }
    guard equalOutlookJourney(lhs.storage, rhs.storage) else { return false }
    guard equalOriginalRescue(lhs.storage, rhs.storage) else { return false }
    guard equalOrbitalEvacuation(lhs.storage, rhs.storage) else { return false }
    guard equalAdmissions(lhs.storage, rhs.storage) else { return false }
    guard equalTransfers(lhs.storage, rhs.storage) else { return false }
    return true
  }

  @inline(never)
  private static func equalOwner(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.owner == rhs.owner
  }

  @inline(never)
  private static func equalRevision(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.revision == rhs.revision
  }

  @inline(never)
  private static func equalStationJourney(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.stationJourney == rhs.stationJourney
  }

  @inline(never)
  private static func equalOutlookJourney(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.outlookJourney == rhs.outlookJourney
  }

  @inline(never)
  private static func equalOriginalRescue(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.originalRescue == rhs.originalRescue
  }

  @inline(never)
  private static func equalOrbitalEvacuation(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.orbitalEvacuation == rhs.orbitalEvacuation
  }

  @inline(never)
  private static func equalAdmissions(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.admissions == rhs.admissions
  }

  @inline(never)
  private static func equalTransfers(_ lhs: Storage, _ rhs: Storage) -> Bool {
    lhs.transfers == rhs.transfers
  }

  func transfer(for person: NativePersonReference) -> NativePeopleTransferReceipt? {
    if person.rescue != nil, let boarding = originalRescue?.boarding {
      return transfers.first { $0.revision > boarding.revision && $0.members.contains(person) }
    }
    return transfers.first { $0.members.contains(person) }
  }
  var held: [NativePeopleAdmission] {
    admissions.filter { transfer(for: $0.person) == nil }.sorted { $0.person.key < $1.person.key }
  }
  var heldCaptives: [NativePeopleAdmission] { held.filter { $0.origin == .capturedCrew } }
  var heldPods: [NativePeopleAdmission] {
    held.filter {
      $0.origin == .rescuedPod
        || ($0.origin == .originalRescuedPod && originalRescue?.boarding == nil)
    }
  }
  func valid(commander: Commander) -> Bool {
    guard custodyIdentityValid(commander: commander) else { return false }
    guard custodyStationSourceValid(commander: commander) else { return false }
    guard custodyOutlookSourceValid(commander: commander) else { return false }
    guard custodyRescueSourceValid(commander: commander) else { return false }
    guard custodyEvacuationSourceValid(commander: commander) else { return false }
    guard custodyAdmissionsValid(commander: commander) else { return false }
    guard custodyTransfersValid(commander: commander) else { return false }
    return custodyRevisionsValid(commander: commander)
  }

  @inline(never)
  private func custodyIdentityValid(commander: borrowing Commander) -> Bool {
    guard owner == commander.equipmentOwnerID,
      !admissions.isEmpty || stationJourney != nil || outlookJourney != nil
        || originalRescue != nil || orbitalEvacuation != nil
    else { return false }
    return true
  }

  @inline(never)
  private func custodyStationSourceValid(commander: borrowing Commander) -> Bool {
    return NativeStationPassengerJourney.validSource(
      stationJourney, custody: self, commander: commander)
  }

  @inline(never)
  private func custodyOutlookSourceValid(commander: borrowing Commander) -> Bool {
    return NativeOrbitalOutlookJourney.validSource(
      outlookJourney, custody: self, commander: commander)
  }

  @inline(never)
  private func custodyRescueSourceValid(commander: borrowing Commander) -> Bool {
    return NativeOriginalRescueJourney.validSource(
      originalRescue, custody: self, commander: commander)
  }

  @inline(never)
  private func custodyEvacuationSourceValid(commander: borrowing Commander) -> Bool {
    return NativeOriginalEvacuation.validSource(
      orbitalEvacuation, custody: self, commander: commander)
  }

  @inline(never)
  private func custodyAdmissionsValid(commander: Commander) -> Bool {
    guard admissions.count <= Self.maximumPeople, transfers.count <= Self.maximumPeople,
      Set(admissions.map(\.person)).count == admissions.count,
      admissions.allSatisfy({ $0.valid(commander: commander) && $0.revision <= revision }),
      Set(transfers.map(\.operation)).count == transfers.count,
      (revision > 0
        || (admissions.isEmpty && transfers.isEmpty
          && (stationJourney != nil || outlookJourney != nil || originalRescue != nil
            || orbitalEvacuation != nil)))
        && revision <= UInt64(Self.maximumPeople * 2)
    else { return false }
    return true
  }

  @inline(never)
  private func custodyTransfersValid(commander: Commander) -> Bool {
    var terminal: Set<NativePersonReference> = []
    for transfer in transfers {
      guard transfer.owner == owner, (1...Self.maximumPeople).contains(transfer.members.count),
        Set(transfer.members).count == transfer.members.count,
        transfer.members.allSatisfy({ person in
          if person.rescue != nil { return true }
          return terminal.insert(person).inserted
        }),
        transfer.revision > 0 && transfer.revision <= revision,
        transfer.physicalTime.isFinite
          && transfer.physicalTime <= commander.flightSimulation.physicalTime,
        transfer.calendarSeconds.isFinite
          && (0...commander.scriptState.calendarSeconds).contains(transfer.calendarSeconds),
        [transfer.beforeCash, transfer.afterCash].allSatisfy({ (0...4_294_967_295).contains($0) }),
        transfer.beforeSlaves >= 0, transfer.afterSlaves >= 0, transfer.price >= 0,
        transfer.collector.entity == 0, transfer.collector.visit > 0,
        transfer.collector.visit <= commander.flightSimulation.visit
      else { return false }
      let people = transfer.members.compactMap { member in admissions.first { $0.person == member }
      }
      guard people.count == transfer.members.count,
        people.allSatisfy({
          $0.revision < transfer.revision && $0.physicalTime <= transfer.physicalTime
        })
      else { return false }
      let captives = people.filter { $0.origin == .capturedCrew }.count
      guard transfer.beforeSlaves >= captives,
        transfer.afterSlaves == (transfer.kind == .escape ? 0 : transfer.beforeSlaves - captives)
      else { return false }
      if transfer.kind == .loss || transfer.kind == .escape {
        guard transfer.dock == nil, transfer.price == 0, transfer.beforeCash == transfer.afterCash
        else { return false }
      } else {
        guard let dock = transfer.dock, dock.valid, dock.commanderOwner == owner,
          dock.actor.system == transfer.collector.system,
          dock.actor.visit == transfer.collector.visit,
          dock.calendarSeconds <= transfer.calendarSeconds,
          let world = commander.nativeStations, world.mainStations.contains(dock.station),
          dock.sequence < world.nextMainDockSequence
        else { return false }
        if transfer.kind == .sale {
          guard captives == 1, people.count == 1, transfer.price <= 1_000_000,
            transfer.beforeCash <= 4_294_967_295 - transfer.price,
            transfer.afterCash == transfer.beforeCash + transfer.price
          else { return false }
        } else {
          guard transfer.price == 0, transfer.beforeCash == transfer.afterCash else { return false }
        }
      }
    }
    return true
  }

  @inline(never)
  private func custodyRevisionsValid(commander: Commander) -> Bool {
    var revisions = Set(admissions.map(\.revision) + transfers.map(\.revision))
    if let boarding = originalRescue?.boarding { revisions.insert(boarding.revision) }
    return revisions.count == Int(revision) && revisions == (revision == 0 ? [] : Set(1...revision))
      && commander.cargo[CommodityIdentity.slaves.rawValue] >= heldCaptives.count
  }
  private enum CodingKeys: String, CodingKey {
    case owner, revision, admissions, transfers, stationJourney, outlookJourney, originalRescue,
      orbitalEvacuation
  }
  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    self.init(owner: try values.decode(UUID.self, forKey: .owner))
    revision = try values.decode(UInt64.self, forKey: .revision)
    stationJourney = try values.decodeIfPresent(
      NativeStationPassengerJourneyState.self, forKey: .stationJourney)
    outlookJourney = try values.decodeIfPresent(
      NativeOrbitalOutlookJourneyState.self, forKey: .outlookJourney)
    originalRescue = try values.decodeIfPresent(
      NativeOriginalRescueJourneyState.self, forKey: .originalRescue)
    orbitalEvacuation = try values.decodeIfPresent(
      NativeOriginalEvacuationState.self, forKey: .orbitalEvacuation)
    admissions = try Self.bounded(values, key: .admissions, type: NativePeopleAdmission.self)
    transfers = try Self.bounded(values, key: .transfers, type: NativePeopleTransferReceipt.self)
  }
  func encode(to encoder: any Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try Self.encodeOwner(storage, into: &values)
    try Self.encodeRevision(storage, into: &values)
    try Self.encodeStationJourney(storage, into: &values)
    try Self.encodeOutlookJourney(storage, into: &values)
    try Self.encodeOriginalRescue(storage, into: &values)
    try Self.encodeOrbitalEvacuation(storage, into: &values)
    try Self.encodeAdmissions(storage, into: &values)
    try Self.encodeTransfers(storage, into: &values)
  }

  @inline(never)
  private static func encodeOwner(
    _ storage: Storage, into values: inout KeyedEncodingContainer<CodingKeys>
  ) throws {
    try values.encode(storage.owner, forKey: .owner)
  }

  @inline(never)
  private static func encodeRevision(
    _ storage: Storage, into values: inout KeyedEncodingContainer<CodingKeys>
  ) throws {
    try values.encode(storage.revision, forKey: .revision)
  }

  @inline(never)
  private static func encodeStationJourney(
    _ storage: Storage, into values: inout KeyedEncodingContainer<CodingKeys>
  ) throws {
    try values.encodeIfPresent(storage.stationJourney, forKey: .stationJourney)
  }

  @inline(never)
  private static func encodeOutlookJourney(
    _ storage: Storage, into values: inout KeyedEncodingContainer<CodingKeys>
  ) throws {
    try values.encodeIfPresent(storage.outlookJourney, forKey: .outlookJourney)
  }

  @inline(never)
  private static func encodeOriginalRescue(
    _ storage: Storage, into values: inout KeyedEncodingContainer<CodingKeys>
  ) throws {
    try values.encodeIfPresent(storage.originalRescue, forKey: .originalRescue)
  }

  @inline(never)
  private static func encodeOrbitalEvacuation(
    _ storage: Storage, into values: inout KeyedEncodingContainer<CodingKeys>
  ) throws {
    try values.encodeIfPresent(storage.orbitalEvacuation, forKey: .orbitalEvacuation)
  }

  @inline(never)
  private static func encodeAdmissions(
    _ storage: Storage, into values: inout KeyedEncodingContainer<CodingKeys>
  ) throws {
    try values.encode(storage.admissions, forKey: .admissions)
  }

  @inline(never)
  private static func encodeTransfers(
    _ storage: Storage, into values: inout KeyedEncodingContainer<CodingKeys>
  ) throws {
    try values.encode(storage.transfers, forKey: .transfers)
  }

  private static func bounded<T: Decodable>(
    _ values: KeyedDecodingContainer<CodingKeys>, key: CodingKeys, type: T.Type
  ) throws -> [T] {
    var entries = try values.nestedUnkeyedContainer(forKey: key)
    guard (entries.count ?? 0) <= maximumPeople else { throw SaveError.invalidCommander }
    var result: [T] = []
    while !entries.isAtEnd {
      guard result.count < maximumPeople else { throw SaveError.invalidCommander }
      result.append(try entries.decode(type))
    }
    return result
  }
}

extension Commander {
  var nativePeople: NativePeopleCustodyState? { savedNativePeopleCustody }
  var nativeCaptiveCount: Int { nativePeople?.heldCaptives.count ?? 0 }
  var rescuedPodTonnes: Int { nativePeople?.heldPods.count ?? 0 }
  var nativePeopleStateValid: Bool {
    guard nativePeopleSourcesPresent else { return false }
    guard let state = nativePeople else {
      return savedEMPState?.records.values.allSatisfy({ $0.crewCaptures.isEmpty }) ?? true
    }
    guard cargo.count == Commodity.all.count, state.valid(commander: self),
      let mass = checkedCargoTonnes, state.held.isEmpty || mass <= standardCargoCapacity
    else { return false }
    return savedEMPState?.records.values.allSatisfy { record in
      record.crewCaptures.allSatisfy { capture in
        capture.ordinals.allSatisfy { ordinal in
          state.admissions.contains {
            $0.person == .emp(.init(source: record.source, ordinal: ordinal))
              && $0.origin == .capturedCrew && $0.operation == capture.operation
          }
        }
      }
    } ?? !state.admissions.contains(where: { $0.person.emp != nil })
  }
  @inline(never)
  private var nativePeopleSourcesPresent: Bool {
    if NativeOriginalEvacuation.nativeInstancePresent(self)
      && nativePeople?.orbitalEvacuation == nil
    {
      return false
    }
    if NativeOriginalRescueJourney.hasMission(self) && nativePeople?.originalRescue == nil {
      return false
    }
    if NativeOrbitalOutlookJourney.nativeInstancePresent(self)
      && nativePeople?.outlookJourney == nil
    {
      return false
    }
    if NativeStationPassengerJourney.nativeInstancePresent(self)
      && nativePeople?.stationJourney == nil
    {
      return false
    }
    return true
  }
  func worldOwnedPod(_ person: EMPCrewIdentity) -> Bool {
    !(nativePeople?.admissions.contains { $0.person == .emp(person) } ?? false)
  }
}
