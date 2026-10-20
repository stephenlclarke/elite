import Foundation

typealias WayfarerRepairLoopSite = WayfarerColdChainSite

struct WayfarerRepairLoopDefinition: Codable, Sendable, Equatable {
  static let stateID = "l337.wayfarer-service/repair-loop"
  static let payloadKey = "wayfarer-repair-unit"
  static let gearKey = "repair-unit"
  let source: WayfarerRepairLoopSite
  let workshop: WayfarerRepairLoopSite
  let receiver: WayfarerRepairLoopSite
  let batch: String
  let stockUnits: Int
  let tonnes: Int
  let maximumActive: Int
  let route: [Int]
  let hazardTier: Int
  let rewardNative: Int
  var valid: Bool {
    source.valid && workshop.valid && receiver == source
      && source.galaxy == workshop.galaxy && source.system != workshop.system
      && PackValidation.localID(batch) && stockUnits == 6 && tonnes == 2 && maximumActive == 3
      && route == [source.system, workshop.system, source.system]
      && hazardTier == 0 && rewardNative == 6100
  }
}

enum WayfarerRepairLoopUnitStatus: String, Codable, Sendable {
  case available, held, returned, lost
}
struct WayfarerRepairLoopStockUnit: Codable, Sendable, Equatable {
  let id: UUID
  let original: OwnedEquipmentItem
  var serial: UUID { original.id }
  var status: WayfarerRepairLoopUnitStatus = .available
  var instance: UUID?
  var returnedItem: OwnedEquipmentItem?
}
struct WayfarerRepairLoopStockSource: Codable, Sendable, Equatable {
  let identity: UUID
  let owner: UUID
  let definition: WayfarerRepairLoopDefinition
  let version: String
  let digest: String
  let initializedAt: NativeMainStationDockReceipt
  var units: [String: WayfarerRepairLoopStockUnit]
  static func identity(owner: UUID, terms: WayfarerRepairLoopDefinition) -> UUID {
    ScriptIdentity.uuid(
      "wayfarer-repair-stock-v1:\(owner):\(terms.source.resourceKey):\(terms.batch)")
  }
  static func unitIdentity(source: UUID, index: Int) -> UUID {
    ScriptIdentity.uuid("wayfarer-repair-stock-unit-v1:\(source):\(index)")
  }
  static func instanceIdentity(unit: UUID) -> UUID {
    ScriptIdentity.uuid("wayfarer-repair-instance-v1:\(unit)")
  }
}
struct WayfarerRepairLoopStockLedger: Codable, Sendable, Equatable {
  let owner: UUID
  var sources: [String: WayfarerRepairLoopStockSource]
}

struct WayfarerRepairLoopAdmissionReceipt: Codable, Sendable, Equatable {
  let command: UUID
  let source: EquipmentIssueSource
  let originalItems: [UUID]
}
final class WayfarerRepairLoopServiceReceipt: Codable, Sendable, Equatable {
  let operation: UUID
  let recipe: String
  let inventoryRevision: UInt64
  let instance: UUID
  let sourceUnit: UUID
  let ownerResource: String
  let issue: WayfarerColdChainContact
  let contact: WayfarerColdChainContact
  let epoch: UUID
  let before: OwnedEquipmentItem
  let after: OwnedEquipmentItem
  init(
    operation: UUID, recipe: String, inventoryRevision: UInt64, instance: UUID, sourceUnit: UUID,
    ownerResource: String, issue: WayfarerColdChainContact, contact: WayfarerColdChainContact,
    epoch: UUID, before: OwnedEquipmentItem, after: OwnedEquipmentItem
  ) {
    self.operation = operation
    self.recipe = recipe
    self.inventoryRevision = inventoryRevision
    self.instance = instance
    self.sourceUnit = sourceUnit
    self.ownerResource = ownerResource
    self.issue = issue
    self.contact = contact
    self.epoch = epoch
    self.before = before
    self.after = after
  }
  static func == (a: WayfarerRepairLoopServiceReceipt, b: WayfarerRepairLoopServiceReceipt) -> Bool
  {
    a.operation == b.operation && a.recipe == b.recipe && a.inventoryRevision == b.inventoryRevision
      && a.instance == b.instance && a.sourceUnit == b.sourceUnit
      && a.ownerResource == b.ownerResource && a.issue == b.issue && a.contact == b.contact
      && a.epoch == b.epoch && a.before == b.before && a.after == b.after
  }
}
final class WayfarerRepairLoopReturnReceipt: Codable, Sendable, Equatable {
  let operation: UUID
  let inventoryRevision: UInt64
  let contact: WayfarerColdChainContact
  let epoch: UUID
  let service: UUID
  let originalItems: [UUID]
  let issueSource: EquipmentIssueSource
  let amount: Int
  init(
    operation: UUID, inventoryRevision: UInt64, contact: WayfarerColdChainContact, epoch: UUID,
    service: UUID, originalItems: [UUID], issueSource: EquipmentIssueSource, amount: Int
  ) {
    self.operation = operation
    self.inventoryRevision = inventoryRevision
    self.contact = contact
    self.epoch = epoch
    self.service = service
    self.originalItems = originalItems
    self.issueSource = issueSource
    self.amount = amount
  }
  static func == (a: WayfarerRepairLoopReturnReceipt, b: WayfarerRepairLoopReturnReceipt) -> Bool {
    a.operation == b.operation && a.inventoryRevision == b.inventoryRevision
      && a.contact == b.contact && a.epoch == b.epoch && a.service == b.service
      && a.originalItems == b.originalItems && a.issueSource == b.issueSource
      && a.amount == b.amount
  }
}

/// An immutable native leaf keeps ScriptInstance and pre-publication snapshots compact.
final class WayfarerRepairLoopCustody: Codable, Sendable, Equatable {
  let owner: UUID
  let source: UUID
  let unit: UUID
  let serial: UUID
  let definition: WayfarerRepairLoopDefinition
  let issue: WayfarerColdChainContact
  let admission: WayfarerRepairLoopAdmissionReceipt
  let service: WayfarerRepairLoopServiceReceipt?
  let returned: WayfarerRepairLoopReturnReceipt?
  let loss: WayfarerColdChainPhysicalLoss?
  init(
    owner: UUID, source: UUID, unit: UUID, serial: UUID,
    definition: WayfarerRepairLoopDefinition, issue: WayfarerColdChainContact,
    admission: WayfarerRepairLoopAdmissionReceipt,
    service: WayfarerRepairLoopServiceReceipt? = nil,
    returned: WayfarerRepairLoopReturnReceipt? = nil, loss: WayfarerColdChainPhysicalLoss? = nil
  ) {
    self.owner = owner
    self.source = source
    self.unit = unit
    self.serial = serial
    self.definition = definition
    self.issue = issue
    self.admission = admission
    self.service = service
    self.returned = returned
    self.loss = loss
  }
  func replacing(
    service: WayfarerRepairLoopServiceReceipt? = nil,
    returned: WayfarerRepairLoopReturnReceipt? = nil, loss: WayfarerColdChainPhysicalLoss? = nil
  ) -> WayfarerRepairLoopCustody {
    .init(
      owner: owner, source: source, unit: unit, serial: serial, definition: definition,
      issue: issue, admission: admission, service: service ?? self.service,
      returned: returned ?? self.returned,
      loss: loss ?? self.loss)
  }
  static func == (a: WayfarerRepairLoopCustody, b: WayfarerRepairLoopCustody) -> Bool {
    a.owner == b.owner && a.source == b.source && a.unit == b.unit && a.serial == b.serial
      && a.definition == b.definition && a.issue == b.issue && a.admission == b.admission
      && a.service == b.service
      && a.returned == b.returned && a.loss == b.loss
  }
}
public struct WayfarerRepairLoopOffer: Sendable {
  public let id: UUID
  public let sourceID: String
  public let stockUnit: UUID
  public let serial: UUID
  public let tonnes: Int
  public let rewardNative: Int
  public let galaxy: Int
  public let sourceSystem: Int
  public let workshopSystem: Int
  public let receiverSystem: Int
  public let route: [Int]
  public let hazardTier: Int
}
public struct WayfarerRepairLoopStageQuote: Sendable {
  public let id: UUID
  public let instance: UUID
  public let serial: UUID
  public let returning: Bool
  public let inventoryRevision: UInt64
  public let instanceRevision: UInt64
  let dock: NativeMainStationDockReceipt
  public let epoch: UUID
}

extension Game {
  private func repairLoopPack(_ digest: String) throws -> ScriptPack {
    guard let pack = scriptPacks.first(where: { $0.digest == digest }),
      pack.manifest.stateID == WayfarerRepairLoopDefinition.stateID,
      pack.manifest.repairLoop?.valid == true, scriptUnavailable(pack) == nil
    else { throw MissionPackError("Restore the exact original repair-loop provider.") }
    return pack
  }
  private func repairLoopDock(_ site: WayfarerRepairLoopSite) throws -> NativeMainStationDockReceipt
  {
    guard !paused, docked, screen != .gameOver, energy.isFinite, energy > 0,
      nativeMainStationDockEvidenceIsCurrent,
      let dock = commander.nativeStations?.currentMainDock, dock.valid,
      dock.commanderOwner == commander.equipmentOwnerID, site.matches(dock.station),
      commander.scriptState.stationResources[site.resourceKey]?.destroyed != true
    else { throw MissionPackError("Use the actual declared living workshop or owner contact.") }
    if let resource = commander.scriptState.stationResources[site.resourceKey] {
      guard resource.valid, resource.identity == dock.station.resource else {
        throw SaveError.invalidCommander
      }
    }
    return dock
  }
  private mutating func repairLoopSequence() throws -> UInt64 {
    guard commander.scriptState.nextEvent < UInt64(Int64.max) - 1 else {
      throw SaveError.invalidCommander
    }
    commander.scriptState.nextEvent += 1
    return commander.scriptState.nextEvent
  }
  private func repairLoopContact(
    _ state: ScriptInstance, sequence: UInt64,
    dock: NativeMainStationDockReceipt
  ) -> WayfarerColdChainContact {
    .init(sequence: sequence, dock: dock, context: scriptEventContext(state))
  }
  mutating func initializeWayfarerRepairLoopStock(packDigest: String) throws -> String {
    guard WayfarerRepairLoopSave.validateClaims(commander) else { throw SaveError.invalidCommander }
    let result = try performInitializeRepairLoopStock(packDigest: packDigest)
    guard WayfarerRepairLoopSave.validateClaims(commander) else { throw SaveError.invalidCommander }
    return result
  }

  @inline(never)
  private mutating func performInitializeRepairLoopStock(packDigest: String) throws -> String {
    let pack = try repairLoopPack(packDigest)
    guard let terms = pack.manifest.repairLoop, let owner = commander.equipmentOwnerID else {
      throw SaveError.invalidCommander
    }
    let dock = try repairLoopDock(terms.source)
    let id = WayfarerRepairLoopStockSource.identity(owner: owner, terms: terms)
    var ledger =
      commander.scriptState.savedWayfarerRepairLoopStock ?? .init(owner: owner, sources: [:])
    if let old = ledger.sources[id.uuidString] {
      guard old.definition == terms, old.digest == pack.digest, old.version == pack.manifest.version
      else {
        throw MissionPackError("Original failed stock cannot be replaced or replenished.")
      }
      return id.uuidString
    }
    guard ledger.owner == owner, ledger.sources.count < 128,
      ledger.sources.values.reduce(0, { $0 + $1.units.count }) <= 128 - terms.stockUnits
    else { throw SaveError.invalidCommander }
    var units: [String: WayfarerRepairLoopStockUnit] = [:]
    for ordinal in 0..<terms.stockUnits {
      let unit = WayfarerRepairLoopStockSource.unitIdentity(source: id, index: ordinal)
      let instance = WayfarerRepairLoopStockSource.instanceIdentity(unit: unit)
      let serial = OwnedGear.issuedIdentity(
        mission: instance, resource: WayfarerRepairLoopDefinition.gearKey, index: 0)
      guard let node = EquipmentRuntimeCatalog.node(for: "Fuel Scoops") else {
        throw SaveError.invalidCommander
      }
      let original = OwnedEquipmentItem(
        id: serial, node: node,
        provenance: .missionIssue(
          mission: instance, resource: WayfarerRepairLoopDefinition.gearKey, index: 0,
          packDigest: pack.digest),
        component: EquipmentRuntimeCatalog.stockComponent(for: node, id: serial),
        preferredSlot: EquipmentRuntimeCatalog.slot(for: node),
        nativeRepairLoopCondition: .failed(sourceUnit: unit))
      units[unit.uuidString] = .init(id: unit, original: original)
    }
    ledger.sources[id.uuidString] = .init(
      identity: id, owner: owner, definition: terms,
      version: pack.manifest.version, digest: pack.digest, initializedAt: dock, units: units)
    commander.scriptState.savedWayfarerRepairLoopStock = ledger
    return id.uuidString
  }

  func wayfarerRepairLoopQuote(sourceID: String) throws -> WayfarerRepairLoopOffer {
    try OriginalServiceReservationPolicy.requireAvailableSlot(commander.scriptState)
    guard let ledger = commander.scriptState.savedWayfarerRepairLoopStock,
      ledger.owner == commander.equipmentOwnerID, let source = ledger.sources[sourceID],
      let unit = source.units.values.filter({ $0.status == .available }).sorted(by: {
        $0.id.uuidString < $1.id.uuidString
      }).first,
      let inventory = commander.equipmentInventory,
      inventory.ordinaryItemCount < OwnedEquipmentInventory.maximumCount,
      let occupied = commander.checkedCargoTonnes, occupied <= commander.standardCargoCapacity - 2,
      commander.scriptState.instances.count < 128
    else {
      throw MissionPackError(
        "An original failed unit, two free tonnes and inventory space are required.")
    }
    let pack = try repairLoopPack(source.digest)
    guard pack.manifest.repairLoop == source.definition else { throw SaveError.invalidCommander }
    let dock = try repairLoopDock(source.definition.source)
    let systems = Universe.systemsIncludingPlugh(number: source.definition.source.galaxy)
    for (index, edge) in zip(source.definition.route, source.definition.route.dropFirst())
      .enumerated()
    {
      guard
        systems[edge.0].distance(to: systems[edge.1])
          <= (index == 0 ? commander.maximumJumpDistance : commander.fullTankJumpDistance)
      else { throw MissionPackError("The complete quoted repair loop must be natively reachable.") }
    }
    let quote = ScriptIdentity.uuid(
      "wayfarer-repair-offer-v1:\(unit.id):\(dock.sequence):\(ecmControl.epoch):\(inventory.revision):\(source.digest)"
    )
    return .init(
      id: quote, sourceID: sourceID, stockUnit: unit.id, serial: unit.serial,
      tonnes: 2, rewardNative: source.definition.rewardNative,
      galaxy: source.definition.source.galaxy,
      sourceSystem: source.definition.source.system,
      workshopSystem: source.definition.workshop.system,
      receiverSystem: source.definition.receiver.system, route: source.definition.route,
      hazardTier: source.definition.hazardTier)
  }

  mutating func pickUpWayfarerRepairLoop(sourceID: String, quotedOfferID: UUID) throws -> UUID {
    guard WayfarerRepairLoopSave.validateClaims(commander) else { throw SaveError.invalidCommander }
    let result = try performPickUpRepairLoop(sourceID: sourceID, quotedOfferID: quotedOfferID)
    guard WayfarerRepairLoopSave.validateClaims(commander) else { throw SaveError.invalidCommander }
    return result
  }

  @inline(never)
  private mutating func performPickUpRepairLoop(sourceID: String, quotedOfferID: UUID) throws
    -> UUID
  {
    let quote = try wayfarerRepairLoopQuote(sourceID: sourceID)
    guard quote.id == quotedOfferID,
      var ledger = commander.scriptState.savedWayfarerRepairLoopStock,
      var source = ledger.sources[sourceID], var unit = source.units[quote.stockUnit.uuidString],
      let inventory = commander.equipmentInventory,
      let gear = try repairLoopPack(source.digest).manifest.equipment?.first
    else { throw MissionPackError("Review the original failed unit before pickup.") }
    let id = WayfarerRepairLoopStockSource.instanceIdentity(unit: unit.id)
    guard commander.scriptState.instances[id] == nil, let node = gear.kind?.canonicalNode else {
      throw SaveError.invalidCommander
    }
    let dock = try repairLoopDock(source.definition.source)
    let sequence = try repairLoopSequence()
    var state = ScriptInstance(
      id: id, definition: WayfarerRepairLoopDefinition.stateID, version: source.version,
      digest: source.digest)
    let issue = repairLoopContact(state, sequence: sequence, dock: dock)
    let issueSource = EquipmentIssueSource(
      mission: id, resource: WayfarerRepairLoopDefinition.gearKey, packDigest: source.digest)
    let device = IssuedDeviceRequest(
      id: unit.serial, node: node, index: 0,
      preferredSlot: unit.original.preferredSlot,
      nativeRepairLoopCondition: .failed(sourceUnit: unit.id))
    let request = EquipmentIssueRequest(
      command: ScriptIdentity.uuid("repair-loop-issue:\(unit.id):\(sequence)"),
      source: issueSource, devices: [device], fitting: .held)
    let context = EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull, performance: commander.nativePerformance)
    let obligations = try commander.equipmentIssueObligations()
    let budget = try commander.equipmentFitBudget(projectedItems: inventory.items + [unit.original])
    let admission = try EquipmentIssueTransactions.quoteAdmission(
      request: request, inventory: inventory, context: context, obligations: obligations,
      budget: budget)
    let applied = try EquipmentIssueTransactions.applyAdmission(
      quote: admission, inventory: inventory, context: context, obligations: obligations,
      budget: budget)
    guard applied.inventory.items.first(where: { $0.id == unit.serial }) == unit.original,
      applied.receipt.originalItems == [unit.serial], applied.receipt.operation == .issued
    else { throw SaveError.invalidCommander }
    state.gearIssues[gear.id] = .init(
      resource: gear.id, kind: gear.kind!, items: [unit.serial], loan: true,
      returnRemaining: false, savedGearVersion: 2, source: issueSource, node: node,
      displacements: [])
    state.payloads[WayfarerRepairLoopDefinition.payloadKey] = 2
    state.savedWayfarerRepairLoop = .init(
      owner: source.owner, source: source.identity, unit: unit.id,
      serial: unit.serial, definition: source.definition, issue: issue,
      admission: .init(
        command: applied.receipt.command, source: applied.receipt.source,
        originalItems: applied.receipt.originalItems))
    state.revision = 1
    state.acknowledge(sequence)
    unit.status = .held
    unit.instance = id
    source.units[unit.id.uuidString] = unit
    ledger.sources[sourceID] = source
    commander.savedEquipmentInventory = applied.inventory
    commander.scriptState.savedWayfarerRepairLoopStock = ledger
    commander.scriptState.instances[id] = state
    guard commander.checkedCargoTonnes.map({ $0 <= commander.standardCargoCapacity }) == true
    else { throw SaveError.invalidCommander }
    return id
  }

  func wayfarerRepairLoopStageQuote(_ id: UUID, returning: Bool) throws
    -> WayfarerRepairLoopStageQuote
  {
    guard let state = commander.scriptState.instances[id], state.outcome == .active,
      state.suspension == nil,
      let custody = state.savedWayfarerRepairLoop, custody.owner == commander.equipmentOwnerID,
      let inventory = commander.equipmentInventory,
      let item = inventory.items.first(where: { $0.id == custody.serial }), item.location == nil,
      state.revision < UInt64(Int64.max) - 1,
      state.gearIssues[WayfarerRepairLoopDefinition.gearKey]?.loan == true
    else { throw SaveError.invalidCommander }
    let pack = try repairLoopPack(state.digest)
    guard pack.manifest.repairLoop == custody.definition else { throw SaveError.invalidCommander }
    let dock = try repairLoopDock(
      returning ? custody.definition.receiver : custody.definition.workshop)
    if returning {
      guard let service = custody.service, custody.returned == nil, custody.loss == nil,
        item == service.after, dock.sequence > service.contact.dock.sequence,
        commander.credits <= 4_294_967_295 - custody.definition.rewardNative
      else {
        throw MissionPackError(
          "Return the same serviced serial to its original owner without overflowing credits.")
      }
    } else {
      guard custody.service == nil, custody.loss == nil,
        item.nativeRepairLoopCondition == .failed(sourceUnit: custody.unit),
        dock.sequence > custody.issue.dock.sequence
      else {
        throw MissionPackError("Service the same original failed serial at its declared workshop.")
      }
    }
    let operation = ScriptIdentity.uuid(
      "wayfarer-repair-operation-v1:\(id):\(returning):\(state.revision):\(inventory.revision):\(dock.sequence):\(ecmControl.epoch):\(state.digest)"
    )
    return .init(
      id: operation, instance: id, serial: item.id, returning: returning,
      inventoryRevision: inventory.revision, instanceRevision: state.revision, dock: dock,
      epoch: ecmControl.epoch)
  }
  func wayfarerRepairLoopDiagnostic(_ id: UUID) throws -> String {
    guard let state = commander.scriptState.instances[id],
      let custody = state.savedWayfarerRepairLoop,
      let item = commander.equipmentInventory?.items.first(where: { $0.id == custody.serial }),
      let condition = item.nativeRepairLoopCondition
    else { throw SaveError.invalidCommander }
    return "\(item.id.uuidString) - \(condition.diagnostic)"
  }

  mutating func serviceWayfarerRepairLoop(_ id: UUID, quotedOperationID: UUID) throws {
    guard WayfarerRepairLoopSave.validateClaims(commander) else { throw SaveError.invalidCommander }
    try performServiceRepairLoop(id, quotedOperationID: quotedOperationID)
    guard WayfarerRepairLoopSave.validateClaims(commander) else { throw SaveError.invalidCommander }
  }

  @inline(never)
  private mutating func performServiceRepairLoop(_ id: UUID, quotedOperationID: UUID) throws {
    let quote = try wayfarerRepairLoopStageQuote(id, returning: false)
    guard quote.id == quotedOperationID, var state = commander.scriptState.instances[id],
      let custody = state.savedWayfarerRepairLoop, var inventory = commander.equipmentInventory,
      let before = inventory.items.first(where: { $0.id == custody.serial })
    else { throw SaveError.invalidCommander }
    let sequence = try repairLoopSequence()
    try inventory.repairOriginal(
      expected: before, operation: quote.id, sourceUnit: custody.unit,
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: inventory.activeHull, performance: commander.nativePerformance
      ))
    let after = inventory.items.first { $0.id == custody.serial }!
    let receipt = WayfarerRepairLoopServiceReceipt(
      operation: quote.id, recipe: "relay-continuity-restoration-v1",
      inventoryRevision: quote.inventoryRevision,
      instance: id, sourceUnit: custody.unit, ownerResource: custody.definition.source.resourceKey,
      issue: custody.issue, contact: repairLoopContact(state, sequence: sequence, dock: quote.dock),
      epoch: ecmControl.epoch, before: before, after: after)
    state.savedWayfarerRepairLoop = custody.replacing(service: receipt)
    state.revision += 1
    state.acknowledge(sequence)
    commander.savedEquipmentInventory = inventory
    commander.scriptState.instances[id] = state
  }

  mutating func returnWayfarerRepairLoop(
    _ id: UUID, quotedOperationID: UUID, clueTrust: ScriptClueTrustCatalog = .production
  ) throws {
    guard WayfarerRepairLoopSave.validateClaims(commander) else { throw SaveError.invalidCommander }
    try performReturnRepairLoop(id, quotedOperationID: quotedOperationID, clueTrust: clueTrust)
    guard WayfarerRepairLoopSave.validateClaims(commander) else { throw SaveError.invalidCommander }
  }

  @inline(never)
  private mutating func performReturnRepairLoop(
    _ id: UUID, quotedOperationID: UUID, clueTrust: ScriptClueTrustCatalog
  ) throws {
    let quote = try wayfarerRepairLoopStageQuote(id, returning: true)
    guard quote.id == quotedOperationID, var state = commander.scriptState.instances[id],
      let custody = state.savedWayfarerRepairLoop, let service = custody.service,
      let record = state.gearIssues[WayfarerRepairLoopDefinition.gearKey],
      var ledger = commander.scriptState.savedWayfarerRepairLoopStock,
      var source = ledger.sources[custody.source.uuidString],
      var unit = source.units[custody.unit.uuidString]
    else { throw SaveError.invalidCommander }
    let previous = state
    let sequence = try repairLoopSequence()
    let contact = repairLoopContact(state, sequence: sequence, dock: quote.dock)
    guard let issueSource = record.source else { throw SaveError.invalidCommander }
    var candidateCommander = commander
    _ = try settleScriptGear(
      record, release: false, command: quote.id, state: &state, candidate: &candidateCommander)
    commander = candidateCommander
    guard state.gearIssues[record.resource]?.status == .returned else {
      throw SaveError.invalidCommander
    }
    let receipt = WayfarerRepairLoopReturnReceipt(
      operation: quote.id, inventoryRevision: quote.inventoryRevision, contact: contact,
      epoch: ecmControl.epoch,
      service: service.operation, originalItems: record.items, issueSource: issueSource,
      amount: custody.definition.rewardNative)
    state.savedWayfarerRepairLoop = custody.replacing(returned: receipt)
    state.payloads.removeValue(forKey: WayfarerRepairLoopDefinition.payloadKey)
    state.outcome = .complete
    state.milestones.insert(0)
    state.revision += 1
    state.acknowledge(sequence)
    state.completionReceipt = repairLoopCompletion(
      state, context: contact.context, sequence: sequence, kind: "dialogue.confirmed")
    commander.credits += custody.definition.rewardNative
    unit.status = .returned
    unit.returnedItem = service.after
    source.units[unit.id.uuidString] = unit
    ledger.sources[source.identity.uuidString] = source
    commander.scriptState.savedWayfarerRepairLoopStock = ledger
    commander.scriptState.instances[id] = state
    try awardScriptClue(previous: previous, next: state, trust: clueTrust)
    if let completion = state.completionReceipt { try enqueueScriptCompletion(completion) }
  }
  private func repairLoopCompletion(
    _ state: ScriptInstance, context: ScriptEventContext,
    sequence: UInt64, kind: String
  ) -> ScriptCompletionReceipt {
    .init(
      instance: state.id, definition: state.definition, version: state.version,
      digest: state.digest,
      outcome: state.outcome, sequence: sequence, causeKind: kind, cause: context,
      committed: scriptEventContext(state), revision: state.revision,
      milestones: state.milestones.sorted(),
      destroyedEncounters: [], deliveredParties: [],
      returnedEquipment: state.outcome == .complete ? [WayfarerRepairLoopDefinition.gearKey] : [],
      settlementAmount: nil, choices: nil)
  }

  mutating func recordWayfarerRepairLoopPhysicalLoss(_ cause: WayfarerColdChainLossCause) throws {
    guard WayfarerRepairLoopSave.validateClaims(commander) else { throw SaveError.invalidCommander }
    guard !docked, energy.isFinite,
      cause == .shipDestroyed ? screen == .gameOver && energy <= 0 : screen.isFlight && energy > 0
    else { throw SaveError.invalidCommander }
    try performRepairLoopPhysicalLoss(cause)
    guard WayfarerRepairLoopSave.validateClaims(commander) else { throw SaveError.invalidCommander }
  }

  @inline(never)
  private mutating func performRepairLoopPhysicalLoss(_ cause: WayfarerColdChainLossCause) throws {
    let ids = commander.scriptState.instances.values.filter {
      $0.savedWayfarerRepairLoop != nil && $0.outcome == .active
    }.map(\.id).sorted { $0.uuidString < $1.uuidString }
    for id in ids {
      guard var state = commander.scriptState.instances[id],
        let custody = state.savedWayfarerRepairLoop,
        let inventory = commander.equipmentInventory,
        let item = inventory.items.first(where: { $0.id == custody.serial }),
        var ledger = commander.scriptState.savedWayfarerRepairLoopStock,
        var source = ledger.sources[custody.source.uuidString],
        var unit = source.units[custody.unit.uuidString],
        state.revision < UInt64(Int64.max) - 1
      else { throw SaveError.invalidCommander }
      let sequence = try repairLoopSequence()
      let context = scriptEventContext(state)
      let loss = WayfarerColdChainPhysicalLoss(
        cause: cause, sequence: sequence, context: context,
        energy: max(0, energy), visit: commander.flightSimulation.visit)
      guard let delta = try commander.scriptState.gearConsumptionDelta(for: item) else {
        throw SaveError.invalidCommander
      }
      commander.scriptState = try commander.scriptState.applying(delta)
      state = commander.scriptState.instances[id]!
      commander.savedEquipmentInventory = try inventory.applyingBatch(
        items: inventory.items.filter { $0.id != item.id },
        expectedRevision: inventory.revision,
        context: EquipmentRuntimeCatalog.context(
          owner: inventory.owner, hull: inventory.activeHull,
          performance: commander.nativePerformance))
      state.savedWayfarerRepairLoop = custody.replacing(loss: loss)
      state.payloads.removeValue(forKey: WayfarerRepairLoopDefinition.payloadKey)
      state.outcome = .failed
      state.revision += 1
      state.acknowledge(sequence)
      state.completionReceipt = repairLoopCompletion(
        state, context: context, sequence: sequence, kind: cause.completionKind)
      unit.status = .lost
      source.units[unit.id.uuidString] = unit
      ledger.sources[source.identity.uuidString] = source
      commander.scriptState.savedWayfarerRepairLoopStock = ledger
      commander.scriptState.instances[id] = state
      commander.scriptState.pendingEvents.removeAll { $0.instance == id }
      if let completion = state.completionReceipt { try enqueueScriptCompletion(completion) }
    }
  }
  mutating func loseWayfarerRepairLoopOnEscape() -> Bool {
    guard
      commander.scriptState.instances.values.contains(where: {
        $0.savedWayfarerRepairLoop != nil && $0.outcome == .active
      })
    else { return true }
    do {
      try recordWayfarerRepairLoopPhysicalLoss(.escapePod)
      return true
    } catch { return false }
  }
}

extension GameRuntime {
  func commitWayfarerRepairLoopFatalLoss() {
    guard game.commander.scriptState.savedWayfarerRepairLoopStock != nil,
      game.screen == .gameOver, !game.docked, game.energy <= 0,
      game.commander.scriptState.instances.values.contains(where: {
        $0.savedWayfarerRepairLoop != nil && $0.outcome == .active
      })
    else { return }
    publishWayfarerRepairLoopFatalLoss()
  }
  @inline(never)
  private func publishWayfarerRepairLoopFatalLoss() {
    do { try scriptCommand { try $0.recordWayfarerRepairLoopPhysicalLoss(.shipDestroyed) } } catch {
      game.notify("REPAIR UNIT LOSS NOT SAVED - ORIGINAL CUSTODY RETAINED")
    }
  }
  public func initializeWayfarerRepairLoopStock(packDigest: String) throws -> String {
    try scriptCommand { try $0.initializeWayfarerRepairLoopStock(packDigest: packDigest) }
  }
  public func wayfarerRepairLoopQuote(sourceID: String) throws -> WayfarerRepairLoopOffer {
    try game.wayfarerRepairLoopQuote(sourceID: sourceID)
  }
  public func pickUpWayfarerRepairLoop(sourceID: String, quotedOfferID: UUID) throws -> UUID {
    try scriptCommand {
      try $0.pickUpWayfarerRepairLoop(sourceID: sourceID, quotedOfferID: quotedOfferID)
    }
  }
  public func wayfarerRepairLoopStageQuote(instance: UUID, returning: Bool) throws
    -> WayfarerRepairLoopStageQuote
  {
    try game.wayfarerRepairLoopStageQuote(instance, returning: returning)
  }
  public func serviceWayfarerRepairLoop(instance: UUID, quotedOperationID: UUID) throws {
    try scriptCommand {
      try $0.serviceWayfarerRepairLoop(instance, quotedOperationID: quotedOperationID)
    }
  }
  public func returnWayfarerRepairLoop(instance: UUID, quotedOperationID: UUID) throws {
    try scriptCommand {
      try $0.returnWayfarerRepairLoop(instance, quotedOperationID: quotedOperationID)
    }
  }
}
