import Foundation

/// W04 field-relief native prerequisite. These receipts grant neither money nor clues.
enum NativeUtilityPhase: String, Codable, Sendable {
  case held, installed, received, lost, returned
}
enum NativeUtilityAction: String, Sendable { case collect, install, receive, returnMaterials }
enum NativeUtilityLossCause: String, Codable, Sendable { case escape, shipDestroyed }

/// Bounded current schema; never fills missing state while decoding.
enum NativeUtilityCoding {
  struct Key: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
  }
  static func require(_ decoder: Decoder, _ required: Set<String>, optional: Set<String> = [])
    throws
  {
    let keys = Set(try decoder.container(keyedBy: Key.self).allKeys.map(\.stringValue))
    guard required.isSubset(of: keys), keys.isSubset(of: required.union(optional)) else {
      throw SaveError.invalidCommander
    }
  }
  static func array<T: Decodable, K: CodingKey>(
    _ type: T.Type, key: K, container: KeyedDecodingContainer<K>, limit: Int
  ) throws -> [T] {
    var input = try container.nestedUnkeyedContainer(forKey: key)
    guard let count = input.count, count <= limit else { throw SaveError.invalidCommander }
    var values: [T] = []
    while !input.isAtEnd {
      guard values.count < limit else { throw SaveError.invalidCommander }
      values.append(try input.decode(T.self))
    }
    return values
  }
}

/// Historical contact scalars are copied only from a sealed actual main-station arrival.
struct NativeUtilitySourceContact: Equatable, Codable, Sendable {
  let sequence: UInt64
  let visit: UInt64
  let calendarSeconds: Double
  init(_ receipt: NativeMainStationDockReceipt) {
    sequence = receipt.sequence
    visit = receipt.actor.visit
    calendarSeconds = receipt.calendarSeconds
  }
  var valid: Bool {
    sequence > 0 && sequence < UInt64(Int64.max) && visit > 0 && visit < UInt64(Int64.max)
      && calendarSeconds.isFinite && (0...1e12).contains(calendarSeconds)
  }
  private enum CodingKeys: String, CodingKey { case sequence, visit, calendarSeconds }
  init(from decoder: Decoder) throws {
    try NativeUtilityCoding.require(decoder, ["sequence", "visit", "calendarSeconds"])
    let c = try decoder.container(keyedBy: CodingKeys.self)
    sequence = try c.decode(UInt64.self, forKey: .sequence)
    visit = try c.decode(UInt64.self, forKey: .visit)
    calendarSeconds = try c.decode(Double.self, forKey: .calendarSeconds)
    guard valid else { throw SaveError.invalidCommander }
  }
}

/// Exact station lifecycle/actor contact, not a saved capability or reusable runtime authority.
struct NativeUtilityStationContact: Equatable, Codable, Sendable {
  let sequence: UInt64
  let lifecycle: UInt64
  let visit: UInt64
  let entity: UInt64
  let body: Int
  init(_ receipt: NativeStationDockReceipt) {
    sequence = receipt.sequence
    lifecycle = receipt.lifecycleRevision
    visit = receipt.dockingBinding.actor.visit
    entity = receipt.dockingBinding.actor.entity
    body = receipt.dockingBinding.bodyID
  }
  var valid: Bool {
    sequence > 0 && sequence < UInt64(Int64.max) && lifecycle > 0 && lifecycle < UInt64(Int64.max)
      && visit > 0 && visit <= UInt64(Int64.max) && entity >= 2 && entity <= UInt64(Int64.max)
      && body > 0
  }
  private enum CodingKeys: String, CodingKey { case sequence, lifecycle, visit, entity, body }
  init(from decoder: Decoder) throws {
    try NativeUtilityCoding.require(decoder, ["sequence", "lifecycle", "visit", "entity", "body"])
    let c = try decoder.container(keyedBy: CodingKeys.self)
    sequence = try c.decode(UInt64.self, forKey: .sequence)
    lifecycle = try c.decode(UInt64.self, forKey: .lifecycle)
    visit = try c.decode(UInt64.self, forKey: .visit)
    entity = try c.decode(UInt64.self, forKey: .entity)
    body = try c.decode(Int.self, forKey: .body)
    guard valid else { throw SaveError.invalidCommander }
  }
}

struct NativeUtilityInstallation: Equatable, Codable, Sendable {
  let operation: UUID
  let component: UUID
  let engineer: UUID
  let socket: Int
  let contact: NativeUtilityStationContact
  let revision: UInt64
  private enum CodingKeys: String, CodingKey {
    case operation, component, engineer, socket, contact, revision
  }
  init(
    operation: UUID, component: UUID, engineer: UUID, socket: Int,
    contact: NativeUtilityStationContact, revision: UInt64
  ) {
    self.operation = operation
    self.component = component
    self.engineer = engineer
    self.socket = socket
    self.contact = contact
    self.revision = revision
  }
  init(from decoder: Decoder) throws {
    try NativeUtilityCoding.require(
      decoder, ["operation", "component", "engineer", "socket", "contact", "revision"])
    let c = try decoder.container(keyedBy: CodingKeys.self)
    operation = try c.decode(UUID.self, forKey: .operation)
    component = try c.decode(UUID.self, forKey: .component)
    engineer = try c.decode(UUID.self, forKey: .engineer)
    socket = try c.decode(Int.self, forKey: .socket)
    contact = try c.decode(NativeUtilityStationContact.self, forKey: .contact)
    revision = try c.decode(UInt64.self, forKey: .revision)
  }
}
struct NativeUtilityReception: Equatable, Codable, Sendable {
  let operation: UUID
  let installation: UUID
  let engineer: UUID
  let contact: NativeUtilityStationContact
  let revision: UInt64
  init(
    operation: UUID, installation: UUID, engineer: UUID,
    contact: NativeUtilityStationContact, revision: UInt64
  ) {
    self.operation = operation
    self.installation = installation
    self.engineer = engineer
    self.contact = contact
    self.revision = revision
  }
  private enum CodingKeys: String, CodingKey {
    case operation, installation, engineer, contact, revision
  }
  init(from decoder: Decoder) throws {
    try NativeUtilityCoding.require(
      decoder, ["operation", "installation", "engineer", "contact", "revision"])
    let c = try decoder.container(keyedBy: CodingKeys.self)
    operation = try c.decode(UUID.self, forKey: .operation)
    installation = try c.decode(UUID.self, forKey: .installation)
    engineer = try c.decode(UUID.self, forKey: .engineer)
    contact = try c.decode(NativeUtilityStationContact.self, forKey: .contact)
    revision = try c.decode(UInt64.self, forKey: .revision)
  }
}
struct NativeUtilityPhysicalLoss: Equatable, Codable, Sendable {
  let cause: NativeUtilityLossCause
  let visit: UInt64
  let physicalTime: Double
  let energy: Double
  init(cause: NativeUtilityLossCause, visit: UInt64, physicalTime: Double, energy: Double) {
    self.cause = cause
    self.visit = visit
    self.physicalTime = physicalTime
    self.energy = energy
  }
  var valid: Bool {
    visit > 0 && visit < UInt64(Int64.max) && physicalTime.isFinite && physicalTime >= 0
      && energy.isFinite && (cause == .shipDestroyed ? energy <= 0 : energy > 0)
  }
  private enum CodingKeys: String, CodingKey { case cause, visit, physicalTime, energy }
  init(from decoder: Decoder) throws {
    try NativeUtilityCoding.require(decoder, ["cause", "visit", "physicalTime", "energy"])
    let c = try decoder.container(keyedBy: CodingKeys.self)
    cause = try c.decode(NativeUtilityLossCause.self, forKey: .cause)
    visit = try c.decode(UInt64.self, forKey: .visit)
    physicalTime = try c.decode(Double.self, forKey: .physicalTime)
    energy = try c.decode(Double.self, forKey: .energy)
    guard valid else { throw SaveError.invalidCommander }
  }
}
struct NativeUtilityConsignment: Equatable, Codable, Sendable {
  let id: UUID
  let originalUnits: [UUID]
  let hull: UUID
  let source: NativeUtilitySourceContact
  let route: [Int]
  let firstLegReach: Double
  let fullTankReach: Double
  let rewardTenths: Int
  var phase: NativeUtilityPhase
  var installation: NativeUtilityInstallation?
  var reception: NativeUtilityReception?
  var loss: NativeUtilityPhysicalLoss?
  var returned: NativeUtilitySourceContact?
  init(
    id: UUID, originalUnits: [UUID], hull: UUID, source: NativeUtilitySourceContact,
    route: [Int], firstLegReach: Double, fullTankReach: Double, rewardTenths: Int
  ) {
    self.id = id
    self.originalUnits = originalUnits
    self.hull = hull
    self.source = source
    self.route = route
    self.firstLegReach = firstLegReach
    self.fullTankReach = fullTankReach
    self.rewardTenths = rewardTenths
    phase = .held
  }
  private enum CodingKeys: String, CodingKey {
    case id, originalUnits, hull, source, route, firstLegReach, fullTankReach, rewardTenths
    case phase, installation, reception, loss, returned
  }
  init(from decoder: Decoder) throws {
    try NativeUtilityCoding.require(
      decoder,
      [
        "id", "originalUnits", "hull", "source", "route", "firstLegReach", "fullTankReach",
        "rewardTenths", "phase",
      ],
      optional: ["installation", "reception", "loss", "returned"])
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(UUID.self, forKey: .id)
    originalUnits = try NativeUtilityCoding.array(
      UUID.self, key: .originalUnits, container: c, limit: 4)
    hull = try c.decode(UUID.self, forKey: .hull)
    source = try c.decode(NativeUtilitySourceContact.self, forKey: .source)
    route = try NativeUtilityCoding.array(Int.self, key: .route, container: c, limit: 256)
    firstLegReach = try c.decode(Double.self, forKey: .firstLegReach)
    fullTankReach = try c.decode(Double.self, forKey: .fullTankReach)
    rewardTenths = try c.decode(Int.self, forKey: .rewardTenths)
    phase = try c.decode(NativeUtilityPhase.self, forKey: .phase)
    installation = try c.decodeIfPresent(NativeUtilityInstallation.self, forKey: .installation)
    reception = try c.decodeIfPresent(NativeUtilityReception.self, forKey: .reception)
    loss = try c.decodeIfPresent(NativeUtilityPhysicalLoss.self, forKey: .loss)
    returned = try c.decodeIfPresent(NativeUtilitySourceContact.self, forKey: .returned)
  }
}
struct NativeUtilityState: Equatable, Codable, Sendable {
  let owner: UUID
  let materials: [UUID]
  var revision: UInt64
  var consignments: [NativeUtilityConsignment]
  init(owner: UUID) {
    self.owner = owner
    materials = (0..<8).map { ScriptIdentity.uuid("field-relief-material-v1:\(owner):\($0)") }
    revision = 1
    consignments = []
  }
  static func target(owner: UUID) -> NativeStationIdentity {
    .init(
      world: owner, system: .init(galaxy: 0, system: 237), definition: "rrs_headquarters",
      version: "1.5.4", key: "rrs_headquarters-g0-s237")
  }
  static func isTarget(_ identity: NativeStationIdentity) -> Bool {
    identity == target(owner: identity.world)
  }
  var target: NativeStationIdentity { Self.target(owner: owner) }
  var source: NativeMainStationIdentity {
    .init(
      world: owner, system: .init(galaxy: 0, system: 7),
      resource: Game.worldResourceIdentity("main-station-v1:main-orbital:0:7"))
  }
  var engineer: UUID { ScriptIdentity.uuid("field-relief-engineer-v1:\(owner)") }
  func consignmentID(_ index: Int) -> UUID {
    ScriptIdentity.uuid("field-relief-consignment-v1:\(owner):\(index)")
  }
  func units(_ index: Int) -> [UUID] {
    Array(materials[index * 4..<index * 4 + 4])
  }
  func component(_ socket: Int) -> UUID {
    ScriptIdentity.uuid("field-relief-regulator-v1:\(owner):\(socket)")
  }
  func operation(_ id: UUID, stage: String, revision: UInt64) -> UUID {
    ScriptIdentity.uuid("field-relief-operation-v1:\(id):\(stage):\(revision)")
  }
  var availableMaterials: [UUID] { Array(materials.dropFirst(consignments.count * 4)) }
  var heldTonnes: Int { consignments.filter { $0.phase == .held }.count * 4 }
  var installedCount: Int { consignments.filter { $0.installation != nil }.count }
  var rechargeBonus: Double { Double(installedCount) * 10 }
  var active: NativeUtilityConsignment? {
    consignments.first { $0.phase == .held || $0.phase == .installed }
  }
  var valid: Bool {
    guard revision > 0, revision < UInt64(Int64.max), consignments.count <= 2,
      materials == (0..<8).map({ ScriptIdentity.uuid("field-relief-material-v1:\(owner):\($0)") }),
      consignments.filter({ $0.phase == .held || $0.phase == .installed }).count <= 1
    else { return false }
    let systems = Universe.systemsIncludingPlugh(number: 0)
    var sockets = Set<Int>()
    var operations = Set<UUID>()
    var expectedRevision: UInt64 = 1
    for (index, job) in consignments.enumerated() {
      expectedRevision += 1
      if index < consignments.count - 1, job.phase == .held || job.phase == .installed {
        return false
      }
      guard job.id == consignmentID(index), job.originalUnits == units(index), job.source.valid,
        (2...256).contains(job.route.count), Set(job.route).count == job.route.count,
        job.route.first == 7, job.route.last == 237,
        job.route.allSatisfy({ (0..<256).contains($0) }),
        job.firstLegReach.isFinite, job.fullTankReach.isFinite,
        (0.0001...1e6).contains(job.firstLegReach), (0.0001...1e6).contains(job.fullTankReach),
        job.rewardTenths == 6100 + 1100 * (job.route.count - 1)
      else { return false }
      for (leg, pair) in zip(job.route, job.route.dropFirst()).enumerated() {
        guard
          systems[pair.0].distance(to: systems[pair.1])
            <= (leg == 0 ? job.firstLegReach : job.fullTankReach)
        else { return false }
      }
      if let installed = job.installation {
        expectedRevision += 1
        guard [.installed, .received].contains(job.phase), (0..<2).contains(installed.socket),
          sockets.insert(installed.socket).inserted,
          installed.component == component(installed.socket),
          installed.engineer == engineer, installed.contact.valid,
          installed.contact.visit >= job.source.visit,
          installed.revision == expectedRevision, installed.revision <= revision,
          installed.operation == operation(job.id, stage: "install", revision: installed.revision),
          operations.insert(installed.operation).inserted
        else { return false }
      }
      if let received = job.reception {
        expectedRevision += 1
        guard job.phase == .received, let installed = job.installation,
          received.installation == installed.operation, received.engineer == engineer,
          received.contact.valid, received.contact.lifecycle == installed.contact.lifecycle,
          received.contact.sequence >= installed.contact.sequence,
          received.contact.visit >= installed.contact.visit,
          received.revision == expectedRevision, received.revision <= revision,
          received.operation == operation(job.id, stage: "receive", revision: received.revision),
          operations.insert(received.operation).inserted
        else { return false }
      }
      if job.phase == .lost || job.phase == .returned { expectedRevision += 1 }
      switch job.phase {
      case .held:
        guard job.installation == nil, job.reception == nil, job.loss == nil, job.returned == nil
        else { return false }
      case .installed:
        guard job.installation != nil, job.reception == nil, job.loss == nil, job.returned == nil
        else { return false }
      case .received:
        guard job.installation != nil, job.reception != nil, job.loss == nil, job.returned == nil
        else { return false }
      case .lost:
        guard job.installation == nil, job.reception == nil, job.loss?.valid == true,
          job.returned == nil, (job.loss?.visit ?? 0) >= job.source.visit
        else { return false }
      case .returned:
        guard job.installation == nil, job.reception == nil, job.loss == nil,
          job.returned?.valid == true,
          (job.returned?.sequence ?? 0) >= job.source.sequence,
          (job.returned?.visit ?? 0) >= job.source.visit,
          (job.returned?.calendarSeconds ?? -1) >= job.source.calendarSeconds
        else { return false }
      }
    }
    return revision == expectedRevision
  }
  private enum CodingKeys: String, CodingKey { case owner, materials, revision, consignments }
  init(from decoder: Decoder) throws {
    try NativeUtilityCoding.require(decoder, ["owner", "materials", "revision", "consignments"])
    let c = try decoder.container(keyedBy: CodingKeys.self)
    owner = try c.decode(UUID.self, forKey: .owner)
    materials = try NativeUtilityCoding.array(UUID.self, key: .materials, container: c, limit: 8)
    revision = try c.decode(UInt64.self, forKey: .revision)
    consignments = try NativeUtilityCoding.array(
      NativeUtilityConsignment.self, key: .consignments, container: c, limit: 2)
    guard valid else { throw SaveError.invalidCommander }
  }
}

extension Commander {
  var nativeUtility: NativeUtilityState? {
    nativeStations?.ledger.records.first(where: { NativeUtilityState.isTarget($0.identity) })?
      .utility
  }
  var nativeUtilityStateValid: Bool {
    guard let utility = nativeUtility else { return nativeStations == nil }
    guard utility.valid, utility.owner == equipmentOwnerID, let world = nativeStations else {
      return false
    }
    if utility.heldTonnes > 0 {
      guard let total = checkedCargoTonnes, total <= standardCargoCapacity,
        utility.active?.hull == hullInstanceID
      else { return false }
    }
    if !utility.consignments.isEmpty {
      guard nativeStations?.mainStations.contains(utility.source) == true,
        scriptState.stationResources[utility.source.key]?.identity == utility.source.resource
      else { return false }
    }
    let visit = flightSimulation.visit
    for job in utility.consignments {
      guard job.source.sequence < world.nextMainDockSequence, job.source.visit <= visit else {
        return false
      }
      if let returned = job.returned,
        returned.sequence >= world.nextMainDockSequence || returned.visit > visit
      {
        return false
      }
      if let installed = job.installation,
        installed.contact.sequence >= world.ledger.nextDockSequence
          || installed.contact.visit > visit
      {
        return false
      }
      if let received = job.reception,
        received.contact.sequence >= world.ledger.nextDockSequence || received.contact.visit > visit
      {
        return false
      }
      if let loss = job.loss,
        loss.physicalTime > flightSimulation.physicalTime || loss.visit > visit
      {
        return false
      }
    }
    return true
  }
}
