import Foundation

extension Game {
  func alienMissileResearchPreview(
    storage id: UUID, inventory: OwnedEquipmentInventory
  ) -> InventoryActionPreview {
    guard let service = nativeAlienServiceContext,
      let stored = commander.alienStorageState?.current.salvage.storedTechnology[id],
      case .technology(let definition, _, _, _) = stored.item.content,
      definition == AlienMissileDefinition.recipe.requiredDefinitionID,
      stored.item.provenance == .alien
    else {
      return .init(label: "", detail: "Dock at PLUGH main station for alien research", command: nil)
    }
    guard !commander.hasAlienMissileResearch else {
      return .init(
        label: "", detail: "Alien seeker research complete; buy rounds at PLUGH", command: nil)
    }
    guard commander.availableCredits >= AlienMissileDefinition.recipe.serviceCostTenths else {
      return .init(label: "", detail: "Alien seeker research requires 1,500 CR", command: nil)
    }
    return .init(
      label: "Research",
      detail: "Use this artefact and 1,500 CR for one prototype and PLUGH supply",
      command: .init(
        owner: inventory.owner, hull: inventory.activeHull,
        context: inventoryContextEpoch, shipID: commander.shipID,
        ownedRevision: inventory.revision,
        sourceRevision: commander.alienStorageState?.current.worldRevision,
        action: .alienMissileResearch(id, service: service)))
  }

  /// The outer inventory candidate publishes payment, original consumption and prototype once.
  mutating func applyAlienMissileResearch(
    storage id: UUID, service: NativeMainStationArrivalContext, expectedWorldRevision: UInt64?
  ) throws {
    guard let currentService = nativeAlienServiceContext, currentService == service,
      acceptsNativeMainStationArrivalContext(service), !commander.hasAlienMissileResearch,
      let current = commander.alienStorageState?.current,
      current.worldRevision == expectedWorldRevision,
      let stored = current.salvage.storedTechnology[id],
      let inventory = commander.equipmentInventory,
      let history = commander.equipmentPurchaseHistory
    else { throw EquipmentRuntimeError.unavailable }
    let operation = UUID()
    let prototype = UUID()
    let proof = AlienMissileResearchReceipt(
      operation: operation, owner: inventory.owner, storage: id,
      source: stored.item.identity, prototype: prototype, hull: inventory.activeHull,
      dock: service.receipt, at: commander.flightSimulation.physicalTime)
    try proof.validate(item: stored.item, collection: stored.receipt, owner: inventory.owner)
    let request = EquipmentPurchaseRequest(
      transaction: operation, newItem: prototype,
      offer: .init(
        node: AlienMissileDefinition.node,
        price: AlienMissileDefinition.recipe.serviceCostTenths, shop: proof.shop, revision: 1),
      location: nil)
    let snapshot = try commander.purchaseSnapshot()
    let quote = try EquipmentPurchaseProgression.quote(
      request: request, snapshot: snapshot, history: history, graph: EquipmentRuntimeCatalog.graph)
    let paid = try EquipmentPurchaseProgression.apply(
      quote, request: request, snapshot: snapshot, history: history,
      graph: EquipmentRuntimeCatalog.graph)
    let item = OwnedEquipmentItem(
      id: paid.item.id, node: paid.item.node, provenance: paid.item.provenance)
    let nextInventory = try inventory.applyingBatch(
      items: inventory.items + [item], expectedRevision: inventory.revision,
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: inventory.activeHull, performance: commander.nativePerformance
      ))
    var world = current.snapshot.world
    guard let index = world.firstIndex(where: { $0.id == stored.record }) else {
      throw AlienStorageError.invalidJoin
    }
    switch world[index] {
    case .companion(let old):
      guard case .collected(let receipt) = old.state, receipt == stored.receipt else {
        throw AlienStorageError.invalidJoin
      }
      world[index] = .companion(
        .init(
          id: old.id, owner: old.owner, plan: old.plan, origin: old.origin, issuedAt: old.issuedAt,
          state: .researched(receipt, proof)))
    case .legacyCurrent(let old):
      guard case .collected(let receipt) = old.state, receipt == stored.receipt else {
        throw AlienStorageError.invalidJoin
      }
      world[index] = .legacyCurrent(
        .init(id: old.id, owner: old.owner, claim: old.claim, state: .researched(receipt, proof)))
    default: throw AlienStorageError.invalidJoin
    }
    let revision = current.worldRevision.addingReportingOverflow(1)
    guard !revision.overflow else { throw AlienStorageError.arithmeticOverflow }
    let old = current.snapshot
    try commander.replaceAlienStorage(
      with: .init(
        owner: old.owner, revision: old.revision, worldRevision: revision.partialValue,
        world: world, sources: old.sources, attachments: old.attachments,
        upgrades: old.upgrades, receipts: old.receipts, commands: old.commands))
    commander.savedEquipmentInventory = nextInventory
    commander.savedEquipmentPurchaseHistory = paid.history
    if !commander.unlimitedCash { commander.credits -= paid.requiredDebit }
    commander.mirrorFittedEquipment()
    guard commander.valid else { throw EquipmentRuntimeError.incompatibleFit }
    notify("ALIEN SEEKER RESEARCH COMPLETE - PROTOTYPE STORED; PLUGH SUPPLY AVAILABLE")
  }
}
