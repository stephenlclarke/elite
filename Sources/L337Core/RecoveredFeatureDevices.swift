import Foundation

enum RecoveredFeatureError: Error, Equatable {
  case unsupportedFeature, missingStoredLot, invalidSource, invalidContext
  case missingTargetingCore, occupiedSlot, staleQuote, commandCollision
  case invalidEvidence, refusedSettlement
}

/// Version of this recovered-feature bridge, not a component grade or health model.
struct RecoveredFeatureDefinition: Equatable, Sendable {
  let definitionID: String
  let feature: SalvageFeature
  let node: EquipmentNodeID
  let slot: ComponentFittingSlot
  let schemaVersion: UInt32

  fileprivate init(
    definitionID: String, feature: SalvageFeature, node: EquipmentNodeID,
    slot: ComponentFittingSlot
  ) {
    self.definitionID = definitionID
    self.feature = feature
    self.node = node
    self.slot = slot
    schemaVersion = 1
  }
}

struct RecoveredFeatureQuote: Sendable {
  let sourceLot: SalvageLot
  let definition: RecoveredFeatureDefinition
  let location: ComponentFittingLocation
  let owner: UUID
  let hull: UUID
  let ownedRevision: UInt64
  let sourceRevision: UInt64
  fileprivate let ownedSnapshot: OwnedEquipmentInventory
  fileprivate let contextSnapshot: OwnedEquipmentContext
}

/// Publish both candidates together, or neither. Cash and purchase history are outside this helper.
struct RecoveredFeatureApplication: Sendable {
  let inventory: OwnedEquipmentInventory
  let ledger: SalvageLedger
  let item: OwnedEquipmentItem
  let receipt: SalvageSettlementReceipt
}

enum RecoveredFeatureDevices {
  static func definition(for definitionID: String) -> RecoveredFeatureDefinition? {
    let feature: SalvageFeature
    let key: String
    let slot: ComponentFittingSlot
    switch definitionID {
    case "feature-mining-targeting":
      feature = .miningTargetingModule
      key = "Targeting: Mining Module"
      slot = .targetingMining
    case "feature-salvage-targeting":
      feature = .salvageTargetingModule
      key = "Targeting: Salvage Module"
      slot = .targetingSalvage
    case "feature-fuel-scoops":
      feature = .fuelScoops
      key = "Fuel Scoops"
      slot = .utility(.fuelScoops)
    case "feature-ecm":
      feature = .ecm
      key = "E.C.M. System"
      slot = .utility(.ecm)
    case "feature-salvage-cutter":
      feature = .salvageCutter
      key = "Salvage Cutter"
      slot = .utility(.salvageCutter)
    default: return nil
    }
    guard let registered = SalvageDefinitions.definition(id: definitionID),
      registered.category == .featureModule, registered.effect == .feature(feature),
      let node = EquipmentRuntimeCatalog.node(for: key),
      EquipmentRuntimeCatalog.slot(for: node) == slot
    else { return nil }
    return .init(definitionID: definitionID, feature: feature, node: node, slot: slot)
  }

  static func quote(
    lotID: SalvageLotIdentity, ledger: SalvageLedger,
    inventory: OwnedEquipmentInventory, context: OwnedEquipmentContext
  ) throws -> RecoveredFeatureQuote {
    try inventory.validate(context: context)
    try validateRecoveredFeatures(inventory: inventory, ledger: ledger)
    guard let lot = ledger.inventory.first(where: { $0.identity == lotID }) else {
      throw RecoveredFeatureError.missingStoredLot
    }
    guard case .technology(let id, _, _) = lot.content, let definition = definition(for: id) else {
      throw RecoveredFeatureError.unsupportedFeature
    }
    guard validSource(lot, definition: definition) else {
      throw RecoveredFeatureError.invalidSource
    }
    let location = ComponentFittingLocation(
      hullInstanceID: inventory.activeHull, slot: definition.slot)
    guard context.supportedSlots.contains(definition.slot),
      context.nodes[definition.node]?.slots.contains(definition.slot) == true
    else { throw RecoveredFeatureError.invalidContext }
    guard !inventory.items.contains(where: { $0.location == location }) else {
      throw RecoveredFeatureError.occupiedSlot
    }
    guard !inventory.items.contains(where: { $0.provenance == .recovered(lotID) }) else {
      throw RecoveredFeatureError.invalidEvidence
    }
    if definition.feature.requiresTargetingCore {
      guard
        inventory.items.contains(where: {
          $0.location?.hullInstanceID == inventory.activeHull && $0.location?.slot == .targetingCore
            && $0.node.family == EquipmentPurchaseCatalog.targeting
            && TargetingTier.from($0.node.key) != nil
        })
      else { throw RecoveredFeatureError.missingTargetingCore }
    }
    return .init(
      sourceLot: lot, definition: definition, location: location,
      owner: inventory.owner, hull: inventory.activeHull,
      ownedRevision: inventory.revision, sourceRevision: ledger.revision,
      ownedSnapshot: inventory, contextSnapshot: context)
  }

  static func apply(
    quote: RecoveredFeatureQuote, commandID: UUID, inventory: OwnedEquipmentInventory,
    ledger: SalvageLedger, context: OwnedEquipmentContext
  ) throws -> RecoveredFeatureApplication {
    // A prior command can never mint a second device, including when its original item is gone.
    guard ledger.settlementReceipt(for: commandID) == nil,
      !inventory.items.contains(where: { $0.id == commandID })
    else { throw RecoveredFeatureError.commandCollision }
    guard inventory == quote.ownedSnapshot, context == quote.contextSnapshot,
      inventory.owner == quote.owner, inventory.activeHull == quote.hull,
      inventory.revision == quote.ownedRevision, ledger.revision == quote.sourceRevision
    else { throw RecoveredFeatureError.staleQuote }
    let current = try self.quote(
      lotID: quote.sourceLot.identity, ledger: ledger, inventory: inventory, context: context)
    guard current.sourceLot == quote.sourceLot, current.definition == quote.definition,
      current.location == quote.location
    else { throw RecoveredFeatureError.staleQuote }
    let binding = SalvageTransactionBinding.equipment(
      target: .hull(instance: quote.hull), expectedComponentInstanceID: nil,
      templateVersion: quote.definition.schemaVersion, axis: nil,
      feature: quote.definition.feature, location: quote.location)
    guard
      let proposal = ledger.prepareSettlement(
        command: commandID, items: [quote.sourceLot.identity], action: .fit(axis: nil, mount: nil),
        binding: binding), proposal.items == [quote.sourceLot]
    else { throw RecoveredFeatureError.refusedSettlement }
    var owned = inventory
    var source = ledger
    let held = OwnedEquipmentItem(
      id: commandID, node: quote.definition.node, provenance: .recovered(quote.sourceLot.identity))
    try owned.admit(held, expectedRevision: owned.revision, context: context)
    try owned.fit(
      expected: held, at: quote.location, expectedRevision: owned.revision, context: context)
    let receipt = source.commitSettlement(proposal)
    guard receipt == .committed(proposal),
      let item = owned.items.first(where: { $0.id == commandID }),
      self.source(for: item, ledger: source) == quote.sourceLot
    else { throw RecoveredFeatureError.refusedSettlement }
    try validateRecoveredFeatures(inventory: owned, ledger: source)
    return .init(inventory: owned, ledger: source, item: item, receipt: receipt)
  }

  /// The device UUID is also its original commit UUID; the immutable receipt retains the full lot.
  /// That receipt records its original fitting, while storage or transfer may change today's address.
  static func source(for item: OwnedEquipmentItem, ledger: SalvageLedger) -> SalvageLot? {
    guard case .recovered(let lotID) = item.provenance, item.component == nil,
      item.boundHull == nil,
      case .committed(let proposal) = ledger.settlementReceipt(for: item.id),
      proposal.command == item.id, proposal.action == .fit(axis: nil, mount: nil),
      proposal.items.count == 1, let lot = proposal.items.first, lot.identity == lotID,
      case .technology(let id, _, _) = lot.content, let definition = definition(for: id),
      item.node == definition.node, validSource(lot, definition: definition),
      item.location.map({ $0.slot == definition.slot }) ?? true,
      case .equipment(let target, let expected, let version, let axis, let feature, let location) =
        proposal.binding,
      expected == nil, version == definition.schemaVersion, axis == nil,
      feature == definition.feature, let location, location.slot == definition.slot,
      case .hull(let originalHull) = target, originalHull == location.hullInstanceID
    else { return nil }
    return lot
  }

  /// Feature evidence and discrete receipt presence. Scalar components retain their own contract.
  static func validateRecoveredFeatures(
    inventory: OwnedEquipmentInventory, ledger: SalvageLedger
  ) throws {
    var sources: Set<SalvageLotIdentity> = []
    let nodes = Set(
      [
        "feature-mining-targeting", "feature-salvage-targeting", "feature-fuel-scoops",
        "feature-ecm",
        "feature-salvage-cutter",
      ].compactMap { definition(for: $0)?.node })
    let receiptLots = inventory.items.flatMap { item -> [SalvageLot] in
      if case .committed(let proposal) = ledger.settlementReceipt(for: item.id) {
        return proposal.items
      }
      return []
    }
    let featureSources = Set(
      (receiptLots + ledger.inventory).compactMap { lot in
        guard case .technology(let id, _, _) = lot.content,
          SalvageDefinitions.definition(id: id)?.category == .featureModule
        else { return nil as SalvageLotIdentity? }
        return lot.identity
      })
    for item in inventory.items {
      guard case .recovered(let lotID) = item.provenance else { continue }
      // A discrete recovery without its commit cannot establish a different device origin.
      // Graded scalar components retain their separate evidence contract.
      if item.component == nil, source(for: item, ledger: ledger) == nil {
        throw RecoveredFeatureError.invalidEvidence
      }
      let committedFeatureOrigin: Bool
      if case .committed(let proposal) = ledger.settlementReceipt(for: item.id) {
        committedFeatureOrigin = proposal.items.contains { featureSources.contains($0.identity) }
      } else {
        committedFeatureOrigin = false
      }
      guard nodes.contains(item.node) || featureSources.contains(lotID) || committedFeatureOrigin
      else { continue }
      guard sources.insert(lotID).inserted, source(for: item, ledger: ledger) != nil else {
        throw RecoveredFeatureError.invalidEvidence
      }
    }
  }

  private static func validSource(_ lot: SalvageLot, definition: RecoveredFeatureDefinition) -> Bool
  {
    guard case .technology(let id, let quality, let condition) = lot.content,
      id == definition.definitionID, (0...100).contains(condition),
      let registered = SalvageDefinitions.definition(id: id),
      registered.effect == .feature(definition.feature),
      lot.massKg == registered.massKg, lot.halfExtents == registered.halfExtents,
      lot.position.finite, lot.position.length.isFinite, lot.velocity.finite,
      lot.velocity.length.isFinite
    else { return false }
    guard let fixed = lot.loot else { return true }
    return fixed.identity == lot.identity
      && fixed.content
        == .technology(definitionID: id, quality: quality, conditionPercent: condition, axis: nil)
      && fixed.effect == .feature(definition.feature) && fixed.bonusBasisPoints == 0
      && fixed.massKg == lot.massKg && fixed.halfExtents == lot.halfExtents
      && fixed.provenance == registered.provenance && !fixed.requiresChunking
      && !fixed.legality.commodityIllegal
      && fixed.saleValueTenths
        == SalvageDefinitions.saleValue(definition: registered, conditionPercent: condition)
  }
}
