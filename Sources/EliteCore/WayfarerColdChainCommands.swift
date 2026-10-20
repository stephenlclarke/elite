import Foundation

struct WayfarerColdChainSite: Codable, Sendable, Equatable {
  let galaxy: Int
  let system: Int
  let resourceKey: String
  var valid: Bool {
    (0..<8).contains(galaxy) && (0..<256).contains(system)
      && resourceKey == "main-orbital:\(galaxy):\(system)"
  }
  func matches(_ station: NativeMainStationIdentity) -> Bool {
    valid && station.valid && station.key == resourceKey
      && station.system == SystemIdentity(galaxy: galaxy, system: system)
  }
}

enum WayfarerColdChainProfile: String, Codable, Sendable { case seedTransfer = "seed-transfer" }
struct WayfarerSeedCustodianDefinition: Codable, Sendable, Equatable {
  let id: String
  let name: String
  var valid: Bool { PackValidation.localID(id) && (1...160).contains(name.count) }
}

/// All finite stock and quotation terms come from installed immutable content.
struct WayfarerColdChainDefinition: Codable, Sendable, Equatable {
  static let stateID = "l337.wayfarer-service/cold-chain"
  static let payloadKey = "wayfarer-sealed-medical-sample"
  static let timerID = "wayfarer-sample-integrity"
  static let seedStateID = "l337.wayfarer-service/seed-transfer"
  static func isNativeDefinition(_ id: String) -> Bool { id == stateID || id == seedStateID }
  let source: WayfarerColdChainSite
  let objective: WayfarerColdChainSite
  let receiver: WayfarerColdChainSite
  let batch: String
  let stockUnits: Int
  let tonnes: Int
  let maximumActive: Int
  let route: [Int]
  let hazardTier: Int
  let flightAllowance: Double
  let rewardNative: Int
  var profile: WayfarerColdChainProfile? = nil
  var sourceCustodian: WayfarerSeedCustodianDefinition? = nil
  var receiverCustodian: WayfarerSeedCustodianDefinition? = nil
  var isSeedTransfer: Bool { profile == .seedTransfer }
  var instanceDefinition: String { isSeedTransfer ? Self.seedStateID : Self.stateID }
  var payloadID: String { isSeedTransfer ? "wayfarer-sealed-seed-lot" : Self.payloadKey }
  var integrityTimerID: String { isSeedTransfer ? "wayfarer-seed-integrity" : Self.timerID }
  func instanceIdentity(unit: UUID) -> UUID {
    ScriptIdentity.uuid(
      (isSeedTransfer ? "wayfarer-seed-service-v1:" : "wayfarer-service-v1:") + unit.uuidString)
  }
  var valid: Bool {
    guard source.valid, objective.valid, receiver.valid,
      source.galaxy == objective.galaxy, source.galaxy == receiver.galaxy,
      PackValidation.localID(batch), (1...128).contains(stockUnits),
      tonnes == (isSeedTransfer ? 3 : 1), maximumActive == 3, (2...256).contains(route.count),
      route.first == source.system, route.last == receiver.system,
      route.contains(objective.system), route.allSatisfy({ (0..<256).contains($0) }),
      flightAllowance.isFinite, flightAllowance > 0, flightAllowance <= 1e9,
      hazardTier >= 0
    else { return false }
    if isSeedTransfer {
      guard source.galaxy == 0, source.system == 241, objective == receiver,
        receiver.system == 85, route == [241, 85], stockUnits == 6, hazardTier == 0,
        let sourceCustodian, let receiverCustodian, sourceCustodian.valid, receiverCustodian.valid,
        sourceCustodian.id != receiverCustodian.id, sourceCustodian.name != receiverCustodian.name
      else { return false }
    } else if sourceCustodian != nil || receiverCustodian != nil {
      return false
    }
    let (hazard, overflow) = hazardTier.multipliedReportingOverflow(by: isSeedTransfer ? 1100 : 900)
    let base = isSeedTransfer ? 5100 + 950 * (route.count - 1) : 3200 + 850 * (route.count - 1)
    return !overflow && hazard <= 4_294_967_295 - base && rewardNative == base + hazard
  }
}

enum WayfarerColdChainUnitStatus: String, Codable, Sendable {
  case available, held, received, failed
}
struct WayfarerColdChainStockUnit: Codable, Sendable, Equatable {
  let id: UUID
  var status: WayfarerColdChainUnitStatus = .available
  var instance: UUID?
}
struct WayfarerColdChainStockSource: Codable, Sendable, Equatable {
  let identity: UUID
  let owner: UUID
  let definition: WayfarerColdChainDefinition
  let version: String
  let digest: String
  let initializedAt: NativeMainStationDockReceipt
  var units: [String: WayfarerColdChainStockUnit]

  static func identity(owner: UUID, terms: WayfarerColdChainDefinition) -> UUID {
    ScriptIdentity.uuid(
      (terms.isSeedTransfer ? "wayfarer-seed-stock-v1:" : "wayfarer-stock-v1:") + owner.uuidString
        + ":" + terms.source.resourceKey + ":" + terms.batch)
  }
  static func unitIdentity(source: UUID, index: Int) -> UUID {
    ScriptIdentity.uuid("wayfarer-stock-unit-v1:" + source.uuidString + ":" + String(index))
  }
  var valid: Bool {
    guard definition.valid, initializedAt.valid, initializedAt.commanderOwner == owner,
      definition.source.matches(initializedAt.station),
      identity == Self.identity(owner: owner, terms: definition),
      PackValidation.version(version), ScriptCompletionReceipt.validDigest(digest),
      units.count == definition.stockUnits
    else { return false }
    for index in 0..<definition.stockUnits {
      let id = Self.unitIdentity(source: identity, index: index)
      guard let unit = units[id.uuidString], unit.id == id,
        (unit.status == .available) == (unit.instance == nil)
      else { return false }
      if let instance = unit.instance {
        guard instance == definition.instanceIdentity(unit: id) else {
          return false
        }
      }
    }
    return true
  }
}
struct WayfarerColdChainStockLedger: Codable, Sendable, Equatable {
  let owner: UUID
  var sources: [String: WayfarerColdChainStockSource]
}
struct WayfarerColdChainContact: Codable, Sendable, Equatable {
  let sequence: UInt64
  let dock: NativeMainStationDockReceipt
  let context: ScriptEventContext
  var valid: Bool {
    sequence > 0 && sequence < UInt64(Int64.max) && dock.valid && context.valid
      && context.nativeMainDock == dock && context.docked && context.mainStation
      && context.galaxy == dock.station.system.galaxy
      && context.system == dock.station.system.system
  }
}
enum WayfarerColdChainLossCause: String, Codable, Sendable {
  case escapePod, shipDestroyed
  var completionKind: String { self == .escapePod ? "mission.abandoned" : "actor.destroyed" }
}
struct WayfarerColdChainPhysicalLoss: Codable, Sendable, Equatable {
  let cause: WayfarerColdChainLossCause
  let sequence: UInt64
  let context: ScriptEventContext
  let energy: Double
  let visit: UInt64
  var valid: Bool {
    sequence > 0 && sequence < UInt64(Int64.max) && context.valid && !context.docked
      && energy.isFinite && (0...1e12).contains(energy)
      && (cause == .shipDestroyed ? energy == 0 : energy > 0)
      && visit > 0 && visit < UInt64(Int64.max)
  }
}
enum WayfarerSeedCustodianRole: String, Codable, Sendable { case release, acceptance }
struct WayfarerSeedCustodianContact: Codable, Sendable, Equatable {
  let custodian: WayfarerSeedCustodianDefinition
  let role: WayfarerSeedCustodianRole
  let unit: UUID
  let instance: UUID
  let epoch: UUID
  let operation: UUID
  let digest: String
  let contact: WayfarerColdChainContact
  static func identity(
    custodian: WayfarerSeedCustodianDefinition, role: WayfarerSeedCustodianRole,
    unit: UUID, instance: UUID, epoch: UUID, digest: String, contact: WayfarerColdChainContact
  ) -> UUID {
    ScriptIdentity.uuid(
      "wayfarer-seed-custodian-v1:\(custodian.id):\(role.rawValue):\(unit):\(instance):\(epoch):\(digest):\(contact.sequence):\(contact.dock.sequence)"
    )
  }
}
/// Existing native release and receiving operations mint these contacts, never Lua flags.
final class WayfarerSeedTransferCustodianReceipts: Codable, Sendable, Equatable {
  let release: WayfarerSeedCustodianContact
  let acceptance: WayfarerSeedCustodianContact?
  init(release: WayfarerSeedCustodianContact, acceptance: WayfarerSeedCustodianContact? = nil) {
    self.release = release
    self.acceptance = acceptance
  }
  static func == (
    a: WayfarerSeedTransferCustodianReceipts, b: WayfarerSeedTransferCustodianReceipts
  ) -> Bool {
    a.release == b.release && a.acceptance == b.acceptance
  }
}
/// New native leaf only: immutable sharing keeps ordinary ScriptInstance values compact.
/// A transition replaces the leaf; it cannot mutate the pre-publication Game snapshot.
final class WayfarerColdChainCustody: Codable, Sendable, Equatable {
  let owner: UUID
  let source: UUID
  let unit: UUID
  let definition: WayfarerColdChainDefinition
  let issue: WayfarerColdChainContact
  let timer: ScriptTimer
  let integrity: WayfarerColdChain
  let objective: WayfarerColdChainContact?
  let loss: WayfarerColdChainPhysicalLoss?
  let seedTransfer: WayfarerSeedTransferCustodianReceipts?

  init(
    owner: UUID, source: UUID, unit: UUID, definition: WayfarerColdChainDefinition,
    issue: WayfarerColdChainContact, timer: ScriptTimer, integrity: WayfarerColdChain,
    objective: WayfarerColdChainContact? = nil, loss: WayfarerColdChainPhysicalLoss? = nil,
    seedTransfer: WayfarerSeedTransferCustodianReceipts? = nil
  ) {
    self.owner = owner
    self.source = source
    self.unit = unit
    self.definition = definition
    self.issue = issue
    self.timer = timer
    self.integrity = integrity
    self.objective = objective
    self.loss = loss
    self.seedTransfer = seedTransfer
  }

  func replacing(
    integrity: WayfarerColdChain, objective: WayfarerColdChainContact? = nil,
    loss: WayfarerColdChainPhysicalLoss? = nil,
    seedTransfer: WayfarerSeedTransferCustodianReceipts? = nil
  ) -> WayfarerColdChainCustody {
    .init(
      owner: owner, source: source, unit: unit, definition: definition, issue: issue, timer: timer,
      integrity: integrity, objective: objective ?? self.objective, loss: loss ?? self.loss,
      seedTransfer: seedTransfer ?? self.seedTransfer)
  }

  static func == (lhs: WayfarerColdChainCustody, rhs: WayfarerColdChainCustody) -> Bool {
    lhs === rhs
      || (lhs.owner == rhs.owner && lhs.source == rhs.source && lhs.unit == rhs.unit
        && lhs.definition == rhs.definition && lhs.issue == rhs.issue && lhs.timer == rhs.timer
        && lhs.integrity == rhs.integrity && lhs.objective == rhs.objective && lhs.loss == rhs.loss
        && lhs.seedTransfer == rhs.seedTransfer)
  }
}

public struct WayfarerColdChainOffer: Sendable {
  public let id: UUID
  public let sourceID: String
  public let stockUnit: UUID
  public let tonnes: Int
  public let rewardNative: Int
  public let flightAllowance: Double
  public let galaxy: Int
  public let sourceSystem: Int
  public let objectiveSystem: Int
  public let receiverSystem: Int
  public let route: [Int]
  public let hazardTier: Int
}

extension Game {
  private func wayfarerPack(_ digest: String) throws -> ScriptPack {
    guard let pack = scriptPacks.first(where: { $0.digest == digest }),
      let terms = pack.manifest.coldChain, terms.valid,
      pack.manifest.stateID == terms.instanceDefinition, scriptUnavailable(pack) == nil
    else { throw MissionPackError("Install the exact native cold-chain declaration.") }
    return pack
  }

  private func wayfarerDock(_ site: WayfarerColdChainSite) throws -> NativeMainStationDockReceipt {
    guard !paused, docked, screen != .gameOver, energy.isFinite, energy > 0,
      nativeMainStationDockEvidenceIsCurrent,
      let dock = commander.nativeStations?.currentMainDock, dock.valid,
      dock.commanderOwner == commander.equipmentOwnerID, site.matches(dock.station),
      commander.scriptState.stationResources[site.resourceKey]?.destroyed != true
    else { throw MissionPackError("Use the actual declared living station contact.") }
    if let resource = commander.scriptState.stationResources[site.resourceKey] {
      guard resource.valid, resource.identity == dock.station.resource,
        resource.key == site.resourceKey, !resource.destroyed
      else { throw SaveError.invalidCommander }
    }
    return dock
  }

  /// Native world/content initialization is separate from acceptance and never replenishes a batch.
  mutating func initializeWayfarerColdChainStock(packDigest: String) throws -> String {
    let pack = try wayfarerPack(packDigest)
    guard let terms = pack.manifest.coldChain, let owner = commander.equipmentOwnerID else {
      throw SaveError.invalidCommander
    }
    let dock = try wayfarerDock(terms.source)
    var ledger =
      commander.scriptState.savedWayfarerColdChainStock
      ?? WayfarerColdChainStockLedger(owner: owner, sources: [:])
    guard ledger.owner == owner else { throw SaveError.invalidCommander }
    let id = WayfarerColdChainStockSource.identity(owner: owner, terms: terms)
    if let existing = ledger.sources[id.uuidString] {
      guard existing.definition == terms, existing.version == pack.manifest.version,
        existing.digest == pack.digest, existing.valid
      else { throw MissionPackError("Original stock terms cannot be replaced or replenished.") }
      return id.uuidString
    }
    guard ledger.sources.count < 128,
      ledger.sources.values.reduce(0, { $0 + $1.units.count }) <= 128 - terms.stockUnits
    else { throw MissionPackError("The retained original stock limit is reached.") }
    var units: [String: WayfarerColdChainStockUnit] = [:]
    for index in 0..<terms.stockUnits {
      let unit = WayfarerColdChainStockSource.unitIdentity(source: id, index: index)
      units[unit.uuidString] = .init(id: unit)
    }
    if commander.scriptState.stationResources[terms.source.resourceKey] == nil {
      var resource = ScriptStationResource(
        identity: dock.station.resource, galaxy: terms.source.galaxy, system: terms.source.system)
      if let anchor = scriptAnchor {
        guard anchor.energy.isFinite, anchor.energy > 0 else { throw SaveError.invalidCommander }
        resource.energy = anchor.energy
      }
      commander.scriptState.stationResources[terms.source.resourceKey] = resource
    }
    ledger.sources[id.uuidString] = .init(
      identity: id, owner: owner, definition: terms, version: pack.manifest.version,
      digest: pack.digest, initializedAt: dock, units: units)
    commander.scriptState.savedWayfarerColdChainStock = ledger
    guard WayfarerColdChainSave.validateClaims(commander) else { throw SaveError.invalidCommander }
    return id.uuidString
  }

  func wayfarerColdChainQuote(sourceID: String) throws -> WayfarerColdChainOffer {
    try OriginalServiceReservationPolicy.requireAvailableSlot(commander.scriptState)
    guard let ledger = commander.scriptState.savedWayfarerColdChainStock,
      ledger.owner == commander.equipmentOwnerID, let source = ledger.sources[sourceID],
      source.valid,
      let unit = source.units.values.filter({ $0.status == .available })
        .sorted(by: { $0.id.uuidString < $1.id.uuidString }).first
    else { throw MissionPackError("No original medical sample remains available.") }
    let pack = try wayfarerPack(source.digest)
    guard pack.manifest.coldChain == source.definition else { throw SaveError.invalidCommander }
    let dock = try wayfarerDock(source.definition.source)
    let terms = source.definition
    let systems = Universe.systemsIncludingPlugh(number: terms.source.galaxy)
    for (index, edge) in zip(terms.route, terms.route.dropFirst()).enumerated() {
      let cap = index == 0 ? commander.maximumJumpDistance : commander.fullTankJumpDistance
      guard systems[edge.0].distance(to: systems[edge.1]) <= cap else {
        throw MissionPackError("The complete quoted itinerary must be natively reachable.")
      }
    }
    let quote = ScriptIdentity.uuid(
      "wayfarer-offer-v1:" + unit.id.uuidString + ":" + String(dock.sequence)
        + ":" + ecmControl.epoch.uuidString + ":" + source.digest)
    return .init(
      id: quote, sourceID: sourceID, stockUnit: unit.id, tonnes: terms.tonnes,
      rewardNative: terms.rewardNative, flightAllowance: terms.flightAllowance,
      galaxy: terms.source.galaxy, sourceSystem: terms.source.system,
      objectiveSystem: terms.objective.system, receiverSystem: terms.receiver.system,
      route: terms.route, hazardTier: terms.hazardTier)
  }
}

extension Game {
  private func wayfarerContact(
    state: ScriptInstance, dock: NativeMainStationDockReceipt, sequence: UInt64
  ) -> WayfarerColdChainContact {
    .init(sequence: sequence, dock: dock, context: scriptEventContext(state))
  }

  private func seedCustodianContact(
    terms: WayfarerColdChainDefinition, state: ScriptInstance,
    unit: UUID, role: WayfarerSeedCustodianRole, contact: WayfarerColdChainContact
  ) throws -> WayfarerSeedCustodianContact {
    guard terms.isSeedTransfer,
      let custodian = role == .release ? terms.sourceCustodian : terms.receiverCustodian,
      contact.valid,
      (role == .release ? terms.source : terms.receiver).matches(contact.dock.station),
      state.definition == terms.instanceDefinition
    else { throw SaveError.invalidCommander }
    return .init(
      custodian: custodian, role: role, unit: unit, instance: state.id, epoch: ecmControl.epoch,
      operation: WayfarerSeedCustodianContact.identity(
        custodian: custodian, role: role, unit: unit,
        instance: state.id, epoch: ecmControl.epoch, digest: state.digest, contact: contact),
      digest: state.digest, contact: contact)
  }
  private func seedReleaseReceipts(
    terms: WayfarerColdChainDefinition, state: ScriptInstance,
    unit: UUID, contact: WayfarerColdChainContact
  ) throws -> WayfarerSeedTransferCustodianReceipts? {
    guard terms.isSeedTransfer else { return nil }
    return try .init(
      release: seedCustodianContact(
        terms: terms, state: state, unit: unit, role: .release, contact: contact))
  }

  private mutating func nextWayfarerSequence() throws -> UInt64 {
    guard commander.scriptState.nextEvent < UInt64(Int64.max) - 1 else {
      throw MissionPackError("Native cold-chain receipt capacity is reached.")
    }
    commander.scriptState.nextEvent += 1
    return commander.scriptState.nextEvent
  }

  mutating func pickUpWayfarerColdChain(sourceID: String, quotedOfferID: UUID) throws -> UUID {
    let quote = try wayfarerColdChainQuote(sourceID: sourceID)
    guard quote.id == quotedOfferID,
      var ledger = commander.scriptState.savedWayfarerColdChainStock,
      var source = ledger.sources[sourceID], var unit = source.units[quote.stockUnit.uuidString],
      unit.status == .available, unit.instance == nil,
      let occupied = commander.checkedCargoTonnes,
      occupied <= commander.standardCargoCapacity - source.definition.tonnes,
      commander.scriptState.instances.count < 128,
      commander.scriptState.instances.values.filter({
        $0.definition.hasPrefix("l337.wayfarer-service/") && $0.outcome == .active
      }).count < source.definition.maximumActive
    else { throw MissionPackError("Review original available stock with a real free tonne.") }
    let terms = source.definition
    let dock = try wayfarerDock(terms.source)
    let now = commander.scriptState.clock(.flight)
    guard now <= 1e12 - terms.flightAllowance else { throw SaveError.invalidCommander }
    let id = terms.instanceIdentity(unit: unit.id)
    guard commander.scriptState.instances[id] == nil else { throw SaveError.invalidCommander }
    let sequence = try nextWayfarerSequence()
    var state = ScriptInstance(
      id: id, definition: terms.instanceDefinition,
      version: source.version, digest: source.digest)
    let timer = ScriptTimer(
      id: terms.integrityTimerID, domain: .flight,
      due: now + terms.flightAllowance, interval: 0, policy: .once)
    let binding = WayfarerColdChainBinding(
      owner: source.owner, instance: id, consignment: unit.id,
      receiver: Self.worldResourceIdentity("main-station-v1:" + terms.receiver.resourceKey),
      timerID: timer.id)
    let contact = wayfarerContact(state: state, dock: dock, sequence: sequence)
    let integrity = try WayfarerColdChain(
      snapshot: .init(binding: binding, timer: timer, context: contact.context),
      allowance: terms.flightAllowance, issueSequence: sequence)
    state.savedWayfarerColdChain = .init(
      owner: source.owner, source: source.identity, unit: unit.id, definition: terms,
      issue: contact, timer: timer, integrity: integrity,
      seedTransfer: try seedReleaseReceipts(
        terms: terms, state: state, unit: unit.id, contact: contact))
    state.payloads[terms.payloadID] = terms.tonnes
    state.timers[timer.id] = timer
    state.acknowledge(sequence)
    state.journal.append(
      terms.isSeedTransfer
        ? "Original sealed seed lot released by \(terms.sourceCustodian!.name): three protected tonnes."
        : "Original sealed medical sample aboard: one protected tonne.")
    unit.status = .held
    unit.instance = id
    source.units[unit.id.uuidString] = unit
    ledger.sources[sourceID] = source
    commander.scriptState.savedWayfarerColdChainStock = ledger
    commander.scriptState.instances[id] = state
    guard WayfarerColdChainSave.validateClaims(commander) else { throw SaveError.invalidCommander }
    return id
  }

  fileprivate func requireWayfarerColdChainInstance(_ id: UUID, active: Bool = false) throws {
    guard commander.scriptState.savedWayfarerColdChainStock != nil,
      let state = commander.scriptState.instances[id],
      WayfarerColdChainDefinition.isNativeDefinition(state.definition),
      let custody = state.savedWayfarerColdChain,
      state.definition == custody.definition.instanceDefinition,
      !active || state.outcome == .active
    else { throw MissionPackError("Original native cold-chain instance required.") }
  }

  func wayfarerColdChainRemaining(_ id: UUID) throws -> Double {
    try requireWayfarerColdChainInstance(id)
    return try evaluateWayfarerColdChainRemaining(id)
  }

  @inline(never)
  private func evaluateWayfarerColdChainRemaining(_ id: UUID) throws -> Double {
    guard WayfarerColdChainSave.validateClaims(commander),
      let state = commander.scriptState.instances[id], let custody = state.savedWayfarerColdChain,
      custody.owner == commander.equipmentOwnerID
    else { throw MissionPackError("Original native sample custody is required.") }
    if state.outcome != .active { return custody.integrity.remaining }
    if commander.scriptState.clock(.flight) >= custody.timer.due { return 0 }
    guard state.timers[custody.timer.id] == custody.timer else { throw SaveError.invalidCommander }
    return try custody.integrity.observing(
      .init(
        binding: custody.integrity.binding, timer: custody.timer, context: scriptEventContext(state)
      )
    ).remaining
  }

  private func wayfarerHeldState(_ id: UUID) throws -> ScriptInstance {
    guard WayfarerColdChainSave.validateClaims(commander),
      let state = commander.scriptState.instances[id],
      WayfarerColdChainDefinition.isNativeDefinition(state.definition), state.outcome == .active,
      state.suspension == nil, state.revision < UInt64(Int64.max) - 1,
      let custody = state.savedWayfarerColdChain,
      custody.owner == commander.equipmentOwnerID, custody.integrity.terminal == nil,
      custody.loss == nil,
      state.timers[custody.definition.integrityTimerID] == custody.timer,
      commander.scriptState.clock(.flight) < custody.timer.due
    else { throw MissionPackError("Original held, viable native sample custody is required.") }
    let pack = try wayfarerPack(state.digest)
    guard pack.manifest.coldChain == custody.definition, pack.manifest.version == state.version
    else {
      throw MissionPackError("Restore the original immutable cold-chain terms.")
    }
    return state
  }

  mutating func confirmWayfarerColdChainObjective(_ id: UUID) throws {
    try requireWayfarerColdChainInstance(id, active: true)
    try performWayfarerColdChainObjective(id)
  }

  @inline(never)
  private mutating func performWayfarerColdChainObjective(_ id: UUID) throws {
    var state = try wayfarerHeldState(id)
    guard var custody = state.savedWayfarerColdChain else { throw SaveError.invalidCommander }
    let dock = try wayfarerDock(custody.definition.objective)
    guard dock.sequence > custody.issue.dock.sequence else {
      throw MissionPackError("Attain the original declared objective after pickup.")
    }
    if let prior = custody.objective {
      guard prior.dock == dock else { throw MissionPackError("Objective was already recorded.") }
      return
    }
    let sequence = try nextWayfarerSequence()
    let contact = wayfarerContact(state: state, dock: dock, sequence: sequence)
    let integrity = try custody.integrity.observing(
      .init(binding: custody.integrity.binding, timer: custody.timer, context: contact.context))
    custody = custody.replacing(integrity: integrity, objective: contact)
    state.savedWayfarerColdChain = custody
    state.revision += 1
    state.acknowledge(sequence)
    commander.scriptState.instances[id] = state
    guard WayfarerColdChainSave.validateClaims(commander) else { throw SaveError.invalidCommander }
  }

  private func wayfarerCompletion(
    state: ScriptInstance, cause: ScriptEventContext, sequence: UInt64,
    kind: String
  ) -> ScriptCompletionReceipt {
    .init(
      instance: state.id, definition: state.definition, version: state.version,
      digest: state.digest,
      outcome: state.outcome, sequence: sequence, causeKind: kind,
      cause: cause, committed: scriptEventContext(state), revision: state.revision,
      milestones: state.milestones.sorted(), destroyedEncounters: [], deliveredParties: [],
      returnedEquipment: [], settlementAmount: nil, choices: nil)
  }

  mutating func receiveWayfarerColdChain(
    _ id: UUID, clueTrust: ScriptClueTrustCatalog = .production
  ) throws {
    try requireWayfarerColdChainInstance(id, active: true)
    try performWayfarerColdChainReception(id, clueTrust: clueTrust)
  }

  @inline(never)
  private mutating func performWayfarerColdChainReception(
    _ id: UUID, clueTrust: ScriptClueTrustCatalog
  ) throws {
    var state = try wayfarerHeldState(id)
    let previous = state
    guard var custody = state.savedWayfarerColdChain, let objective = custody.objective,
      var ledger = commander.scriptState.savedWayfarerColdChainStock,
      var source = ledger.sources[custody.source.uuidString],
      var unit = source.units[custody.unit.uuidString], unit.status == .held, unit.instance == id
    else { throw MissionPackError("Actual original objective and stock custody are required.") }
    let dock = try wayfarerDock(custody.definition.receiver)
    guard dock.sequence >= objective.dock.sequence,
      dock.actor.visit >= objective.dock.actor.visit,
      (0...4_294_967_295).contains(commander.credits),
      commander.credits <= 4_294_967_295 - custody.definition.rewardNative
    else { throw MissionPackError("Reopen the actual receiver without overflowing credits.") }
    let sequence = try nextWayfarerSequence()
    let contact = wayfarerContact(state: state, dock: dock, sequence: sequence)
    // This reuses a descriptive receipt shape, never the closed G02 contract authority.
    let receipt = ScriptCourierTerminalReceipt(
      id: ScriptCourierCustody.terminalIdentity(custody.unit), item: custody.unit,
      cause: .delivered,
      proof: .init(
        sequence: sequence, token: "wayfarer-native-reception", revision: state.revision,
        epoch: ecmControl.epoch, clock: contact.context.calendarSeconds, station: contractStation),
      amount: custody.definition.rewardNative)
    let integrity = try custody.integrity.receiving(
      .init(binding: custody.integrity.binding, timer: custody.timer, context: contact.context),
      receipt: receipt)
    let seedReceipts: WayfarerSeedTransferCustodianReceipts?
    if custody.definition.isSeedTransfer {
      guard let prior = custody.seedTransfer else { throw SaveError.invalidCommander }
      let acceptance = try seedCustodianContact(
        terms: custody.definition, state: state,
        unit: custody.unit, role: .acceptance, contact: contact)
      seedReceipts = .init(release: prior.release, acceptance: acceptance)
    } else {
      seedReceipts = nil
    }
    custody = custody.replacing(integrity: integrity, seedTransfer: seedReceipts)
    state.savedWayfarerColdChain = custody
    state.payloads.removeValue(forKey: custody.definition.payloadID)
    state.timers.removeValue(forKey: custody.definition.integrityTimerID)
    state.outcome = .complete
    state.milestones.insert(0)
    state.dialogue = nil
    state.revision += 1
    state.acknowledge(sequence)
    state.completionReceipt = wayfarerCompletion(
      state: state, cause: contact.context, sequence: sequence,
      kind: "dialogue.confirmed")
    unit.status = .received
    source.units[unit.id.uuidString] = unit
    ledger.sources[custody.source.uuidString] = source
    commander.scriptState.savedWayfarerColdChainStock = ledger
    commander.scriptState.instances[id] = state
    commander.scriptState.pendingEvents.removeAll { $0.instance == id }
    commander.credits += custody.definition.rewardNative
    try awardScriptClue(previous: previous, next: state, trust: clueTrust)
    if let receipt = state.completionReceipt { try enqueueScriptCompletion(receipt) }
    guard WayfarerColdChainSave.validateClaims(commander) else { throw SaveError.invalidCommander }
  }

  func applyWayfarerColdChainExpiry(
    event: ScriptEvent, state: inout ScriptInstance, candidate: inout Commander
  ) throws {
    guard WayfarerColdChainDefinition.isNativeDefinition(state.definition),
      state.outcome == .active,
      var custody = state.savedWayfarerColdChain, custody.loss == nil,
      custody.owner == candidate.equipmentOwnerID,
      event.instance == state.id, event.sequence > custody.issue.sequence,
      event.sequence <= candidate.scriptState.nextEvent, !state.hasAcknowledged(event.sequence),
      WayfarerColdChainSave.pendingExpiry(state, engine: candidate.scriptState) == event,
      let context = event.context,
      candidate.freightHistoricalContextValid(context, requiresDock: context.docked),
      var ledger = candidate.scriptState.savedWayfarerColdChainStock,
      var source = ledger.sources[custody.source.uuidString],
      var unit = source.units[custody.unit.uuidString], unit.status == .held,
      unit.instance == state.id
    else {
      throw MissionPackError("Expiry requires the actual original native one-shot timer event.")
    }
    let integrity = try custody.integrity.spoiling(
      binding: custody.integrity.binding, event: event)
    custody = custody.replacing(integrity: integrity)
    state.savedWayfarerColdChain = custody
    state.payloads.removeValue(forKey: custody.definition.payloadID)
    state.outcome = .failed
    state.dialogue = nil
    // The existing director records the native event revision, acknowledgement and completion.
    unit.status = .failed
    source.units[unit.id.uuidString] = unit
    ledger.sources[custody.source.uuidString] = source
    candidate.scriptState.savedWayfarerColdChainStock = ledger
  }

  @inline(never)
  mutating func retryWayfarerColdChainExpiry(_ id: UUID) throws {
    guard !scriptDispatching, !scriptEventsDeferred,
      WayfarerColdChainSave.validateClaims(commander),
      let state = commander.scriptState.instances[id], state.suspension != nil,
      let custody = state.savedWayfarerColdChain,
      let event = WayfarerColdChainSave.pendingExpiry(state, engine: commander.scriptState)
    else { throw MissionPackError("A suspended original native expiry is required.") }
    let pack = try wayfarerPack(state.digest)
    guard pack.manifest.version == state.version, pack.manifest.coldChain == custody.definition
    else { throw MissionPackError("Restore the original immutable cold-chain terms.") }
    commander.scriptState.instances[id]?.suspension = nil
    // The enclosing scriptCommand publishes once. Failure restores the suspended pending original.
    drainScriptEvents()
    guard let next = commander.scriptState.instances[id], next.outcome == .failed,
      next.suspension == nil, next.completionReceipt?.sequence == event.sequence,
      next.completionReceipt?.cause == event.context,
      next.hasAcknowledged(event.sequence),
      case .some(.spoiled(let receipt)) = next.savedWayfarerColdChain?.integrity.terminal,
      receipt.sequence == event.sequence, receipt.context == event.context,
      WayfarerColdChainSave.validateClaims(commander)
    else { throw MissionPackError("The original native expiry could not be committed.") }
  }
}

extension Game {
  /// Called only by the existing successful native escape candidate or measured fatal transition.
  @inline(never)
  mutating func recordWayfarerColdChainPhysicalLoss(_ cause: WayfarerColdChainLossCause) throws {
    guard !docked, energy.isFinite,
      cause == .shipDestroyed ? screen == .gameOver && energy <= 0 : screen.isFlight && energy > 0
    else { throw MissionPackError("Original attained native carrier loss is required.") }
    let ids = commander.scriptState.instances.values.filter {
      $0.savedWayfarerColdChain != nil && $0.outcome == .active
    }.map(\.id).sorted { $0.uuidString < $1.uuidString }
    for id in ids {
      guard var state = commander.scriptState.instances[id],
        var custody = state.savedWayfarerColdChain, custody.loss == nil,
        state.revision < UInt64(Int64.max) - 1, custody.integrity.terminal == nil,
        custody.owner == commander.equipmentOwnerID,
        state.timers[custody.timer.id] == custody.timer,
        var ledger = commander.scriptState.savedWayfarerColdChainStock,
        var source = ledger.sources[custody.source.uuidString],
        var unit = source.units[custody.unit.uuidString], unit.status == .held, unit.instance == id
      else { throw SaveError.invalidCommander }
      let sequence = try nextWayfarerSequence()
      let context = scriptEventContext(state)
      let integrity = try custody.integrity.observing(
        .init(binding: custody.integrity.binding, timer: custody.timer, context: context))
      let loss = WayfarerColdChainPhysicalLoss(
        cause: cause, sequence: sequence, context: context, energy: max(0, energy),
        visit: commander.flightSimulation.visit)
      custody = custody.replacing(integrity: integrity, loss: loss)
      state.savedWayfarerColdChain = custody
      state.payloads.removeValue(forKey: custody.definition.payloadID)
      state.timers.removeValue(forKey: custody.timer.id)
      state.outcome = .failed
      state.dialogue = nil
      state.revision += 1
      state.acknowledge(sequence)
      state.completionReceipt = wayfarerCompletion(
        state: state, cause: context, sequence: sequence, kind: cause.completionKind)
      unit.status = .failed
      source.units[unit.id.uuidString] = unit
      ledger.sources[custody.source.uuidString] = source
      commander.scriptState.savedWayfarerColdChainStock = ledger
      commander.scriptState.instances[id] = state
      commander.scriptState.pendingEvents.removeAll { $0.instance == id }
      if let receipt = state.completionReceipt { try enqueueScriptCompletion(receipt) }
    }
    guard WayfarerColdChainSave.validateClaims(commander) else { throw SaveError.invalidCommander }
  }

  mutating func loseWayfarerColdChainOnEscape() -> Bool {
    guard commander.scriptState.savedWayfarerColdChainStock != nil else { return true }
    guard
      commander.scriptState.instances.values.contains(where: {
        $0.savedWayfarerColdChain != nil && $0.outcome == .active
      })
    else { return true }
    do {
      try recordWayfarerColdChainPhysicalLoss(.escapePod)
      return true
    } catch { return false }
  }
}

extension GameRuntime {
  /// A failed writer leaves stock, custody, payload and descriptor unchanged; the measured
  /// game-over state permits a later frame to retry the same native loss, never a new sample.
  func commitWayfarerColdChainFatalLoss() {
    guard game.commander.scriptState.savedWayfarerColdChainStock != nil,
      game.screen == .gameOver, !game.docked, game.energy.isFinite, game.energy <= 0,
      game.commander.scriptState.instances.values.contains(where: {
        $0.savedWayfarerColdChain != nil && $0.outcome == .active
      })
    else { return }
    publishWayfarerColdChainFatalLoss()
  }

  @inline(never)
  private func publishWayfarerColdChainFatalLoss() {
    do {
      try scriptCommand { try $0.recordWayfarerColdChainPhysicalLoss(.shipDestroyed) }
    } catch { game.notify("SAMPLE LOSS NOT SAVED - ORIGINAL CUSTODY NOT TRANSFERRED") }
  }
}

extension GameRuntime {
  public func initializeWayfarerColdChainStock(packDigest: String) throws -> String {
    try scriptCommand { try $0.initializeWayfarerColdChainStock(packDigest: packDigest) }
  }
  public func wayfarerColdChainQuote(sourceID: String) throws -> WayfarerColdChainOffer {
    try game.wayfarerColdChainQuote(sourceID: sourceID)
  }
  public func pickUpWayfarerColdChain(sourceID: String, quotedOfferID: UUID) throws -> UUID {
    try scriptCommand {
      try $0.pickUpWayfarerColdChain(sourceID: sourceID, quotedOfferID: quotedOfferID)
    }
  }
  public func wayfarerColdChainRemaining(instance: UUID) throws -> Double {
    try game.wayfarerColdChainRemaining(instance)
  }
  public func confirmWayfarerColdChainObjective(instance: UUID) throws {
    try game.requireWayfarerColdChainInstance(instance, active: true)
    try scriptCommand { try $0.confirmWayfarerColdChainObjective(instance) }
  }
  public func receiveWayfarerColdChain(instance: UUID) throws {
    try game.requireWayfarerColdChainInstance(instance, active: true)
    try scriptCommand { try $0.receiveWayfarerColdChain(instance) }
  }
  public func retryWayfarerColdChainExpiry(instance: UUID) throws {
    try game.requireWayfarerColdChainInstance(instance, active: true)
    try scriptCommand { try $0.retryWayfarerColdChainExpiry(instance) }
  }
}
