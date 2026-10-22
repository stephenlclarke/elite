import Foundation

/// Permanent source-to-prototype proof, retained after the paid prototype is fired.
struct AlienMissileResearchReceipt: Codable, Equatable, Sendable {
  let operation: UUID
  let owner: UUID
  let storage: UUID
  let source: SalvageLotIdentity
  let prototype: UUID
  let hull: UUID
  let dock: NativeMainStationDockReceipt
  let at: Double

  var shop: String {
    "galaxy:\(dock.station.system.galaxy)/system:\(Plugh.systemID)/alien-seeker-research"
  }

  func validate(item: SalvageLootItem, collection: AlienStorageCompanionCollection, owner: UUID)
    throws
  {
    guard self.owner == owner, dock.valid, dock.commanderOwner == owner,
      dock.station.system.system == Plugh.systemID,
      at.isFinite, at >= collection.at, source == item.identity,
      case .technology(let collected) = collection.effect, storage == collected,
      Set([operation, collection.operation, prototype, storage]).count == 4,
      case .technology(let definition, _, _, let axis) = item.content,
      definition == AlienMissileDefinition.recipe.requiredDefinitionID,
      item.provenance == .alien, item.effect == .researchAndSale, axis == nil
    else { throw AlienStorageError.invalidJoin }
  }
}

extension AlienStorageCompanion.State {
  var collection: AlienStorageCompanionCollection? {
    switch self {
    case .collected(let value), .researched(let value, _): value
    default: nil
    }
  }
}

extension AlienStorageLegacyCurrent.State {
  var collection: AlienStorageCompanionCollection? {
    switch self {
    case .collected(let value), .researched(let value, _): value
    default: nil
    }
  }
}

extension Commander {
  var hasAlienMissileResearch: Bool {
    guard let storage = alienStorageState?.current, storage.owner == equipmentOwnerID else {
      return false
    }
    return !storage.salvage.missileResearch.isEmpty
  }

  /// Cold saves and mutations must retain both the original custody and exact paid receipt.
  func validateAlienMissileResearch() throws {
    let research = alienStorageState?.current.salvage.missileResearch ?? []
    guard let inventory = equipmentInventory, let history = equipmentPurchaseHistory else {
      guard research.isEmpty else { throw AlienStorageError.invalidJoin }
      return
    }
    let alienPayments = history.paid.filter { $0.node == AlienMissileDefinition.node }
    guard
      !research.isEmpty || !alienPayments.isEmpty
        || inventory.items.contains(where: { $0.node == AlienMissileDefinition.node })
    else { return }
    guard research.count == 1 else { throw AlienStorageError.invalidJoin }
    let researchSources = Set(research.map(\.source))
    guard researchSources.count == research.count,
      !salvageLedger.inventory.contains(where: { researchSources.contains($0.identity) }),
      !salvageLedger.pendingLots.contains(where: { researchSources.contains($0.identity) }),
      !salvageLedger.containsSettlementSource(in: researchSources)
    else { throw AlienStorageError.invalidJoin }
    let payments = Dictionary(uniqueKeysWithValues: alienPayments.map { ($0.transaction, $0) })
    for proof in research {
      guard proof.owner == inventory.owner,
        NativeStationPassengerJourney.historicalDock(proof.dock, commander: self),
        let paid = payments[proof.operation], paid.owner == proof.owner,
        paid.node == AlienMissileDefinition.node,
        paid.price == AlienMissileDefinition.recipe.serviceCostTenths,
        paid.binding.request.newItem == proof.prototype,
        paid.binding.request.offer.shop == proof.shop,
        paid.binding.snapshot.owner == proof.owner,
        paid.binding.snapshot.activeHull == proof.hull,
        paid.binding.snapshot.funds >= paid.price,
        paid.binding.request.location == nil,
        !paid.binding.snapshot.items.contains(where: { $0.id == proof.prototype })
      else { throw AlienStorageError.invalidJoin }
    }
    let researchPayments = Set(research.map(\.operation))
    let firstResearchRevision = research.compactMap {
      payments[$0.operation]?.binding.historyRevision
    }.min()
    for paid in alienPayments {
      if paid.binding.request.offer.shop.hasSuffix("/alien-seeker-research") {
        guard researchPayments.contains(paid.transaction) else {
          throw AlienStorageError.invalidJoin
        }
      } else {
        guard let firstResearchRevision,
          firstResearchRevision < paid.binding.historyRevision,
          paid.price == Plugh.discount(AlienMissileDefinition.repeatPriceTenths),
          (0..<8).contains(where: {
            paid.binding.request.offer.shop == "galaxy:\($0)/system:\(Plugh.systemID)"
          })
        else { throw AlienStorageError.invalidJoin }
      }
    }
    for item in inventory.items where item.node == AlienMissileDefinition.node {
      guard case .paid(let owner, let transaction) = item.provenance,
        owner == inventory.owner, let paid = payments[transaction],
        paid.node == item.node, paid.binding.request.newItem == item.id
      else { throw AlienStorageError.invalidJoin }
    }
  }
}
