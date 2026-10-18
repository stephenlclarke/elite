import Foundation

/// Derived once from the fully validated world at a load or mutation boundary.
/// These values locate current custody; they grant no collection or spawn permission.
struct AlienNativeSalvageIndex: Sendable {
  struct Pending: Sendable {
    let record: UUID
    let lot: SalvageLot
    let physicalTime: Double
    let offer: SpawnIdentity?
    let binding: ActorIdentity?
  }

  struct StoredTechnology: Sendable {
    let record: UUID
    let item: SalvageLootItem
    let receipt: AlienStorageCompanionCollection
  }

  let native: NativeSalvagePlanView
  let sections: Set<WreckSectionIdentity>
  let wrecksWithSections: Set<WreckIdentity>
  let pending: [SalvageLotIdentity: Pending]
  let pendingBySystem: [SystemIdentity: [Pending]]
  let storedTechnology: [UUID: StoredTechnology]

  init(_ records: [AlienStorageWorldRecord]) throws {
    var sections: Set<WreckSectionIdentity> = []
    var pending: [SalvageLotIdentity: Pending] = [:]
    var storedTechnology: [UUID: StoredTechnology] = [:]
    let native = try NativeSalvagePlanView(records)
    let plans = native.plans
    var claims: [UUID: AlienStorageLegacyLot] = [:]
    var emissions: [UUID: [AlienStorageEmissionOrigin: SalvageLootItem]] = [:]
    for record in records {
      if case .legacyLot(let claim) = record { claims[claim.id] = claim }
    }
    func store(
      record: UUID, item: SalvageLootItem, receipt: AlienStorageCompanionCollection
    ) throws {
      guard case .technology(let storage) = receipt.effect,
        case .technology(let definition, _, _, _) = item.content,
        !AlienModuleDefinition.isAttachmentDefinition(definition),
        storedTechnology.updateValue(
          .init(record: record, item: item, receipt: receipt), forKey: storage) == nil
      else { throw AlienStorageError.invalidJoin }
    }
    for record in records {
      let value: Pending?
      switch record {
      case .plan(let plan):
        guard sections.insert(plan.plan.section).inserted else {
          throw AlienStorageError.duplicateKey
        }
        value = nil
      case .nativeInspection(let inspection):
        guard sections.insert(inspection.plan.section).inserted else {
          throw AlienStorageError.duplicateKey
        }
        value = nil
      case .nativeWreck, .nativeWork: value = nil
      case .legacySection(let section):
        guard sections.insert(section.plan.section).inserted else {
          throw AlienStorageError.duplicateKey
        }
        value = nil
      case .lot(let item):
        if case .pending(let lot, let time, let offer, let binding) = item.state {
          value = .init(
            record: item.id, lot: lot, physicalTime: time, offer: offer, binding: binding)
        } else {
          value = nil
        }
      case .companion(let item):
        if case .pending(let lot, let time, let offer, let binding) = item.state {
          value = .init(
            record: item.id, lot: lot, physicalTime: time, offer: offer, binding: binding)
        } else {
          value = nil
          if case .collected(let receipt) = item.state, case .technology = receipt.effect {
            guard let plan = plans[item.plan] else { throw AlienStorageError.invalidJoin }
            if emissions[item.plan] == nil {
              emissions[item.plan] = try native.emissions(for: plan)
            }
            guard let original = emissions[item.plan]?[item.origin] else {
              throw AlienStorageError.invalidJoin
            }
            try store(record: item.id, item: original, receipt: receipt)
          }
        }
      case .legacyCurrent(let item):
        if case .pending(let lot, let time, let offer, let binding) = item.state {
          value = .init(
            record: item.id, lot: lot, physicalTime: time, offer: offer, binding: binding)
        } else {
          value = nil
          if case .collected(let receipt) = item.state, case .technology = receipt.effect {
            guard let claim = claims[item.claim], case .pending(let lot, _, _) = claim.state,
              let original = lot.loot
            else { throw AlienStorageError.invalidJoin }
            try store(record: item.id, item: original, receipt: receipt)
          }
        }
      case .legacyLot, .legacySettlement, .legacySettlementItem: value = nil
      }
      if let value {
        guard pending.updateValue(value, forKey: value.lot.identity) == nil else {
          throw AlienStorageError.duplicateKey
        }
      }
    }
    self.native = native
    self.sections = sections
    wrecksWithSections = Set(sections.map(\.wreck))
    self.pending = pending
    pendingBySystem = Dictionary(
      grouping: Array(pending.values), by: { $0.lot.identity.section.wreck.system })
    self.storedTechnology = storedTechnology
  }
}

extension Game {
  /// Admission needs the retained original shape before a new actor can be bound.
  /// Reading that shape does not authenticate a scene actor or permit collection.
  func salvageLotForGeometry(_ identity: SalvageLotIdentity) -> SalvageLot? {
    let native = commander.alienStorageState?.current.salvage
    if native?.sections.contains(identity.section) == true
      || commander.salvageLedger.nativeTransferredSectionIdentities.contains(identity.section)
    {
      guard commander.alienStorageStateValid else { return nil }
      return native?.pending[identity]?.lot
    }
    return commander.salvageLedger.pendingLots.first { $0.identity == identity }
  }

  /// Physical consumers use the same held original lot for its geometry and custody.
  /// A transferred section can never fall back to its retired legacy custody pool.
  func currentSalvageLot(for body: SpaceBody) -> SalvageLot? {
    guard let physical = body.physical,
      let payload = physical.payload, case .salvage(let identity) = payload
    else { return nil }
    let native = commander.alienStorageState?.current.salvage
    if native?.sections.contains(identity.section) == true
      || commander.salvageLedger.nativeTransferredSectionIdentities.contains(identity.section)
    {
      guard commander.alienStorageStateValid, physical.identity.system == systemIdentity,
        physical.identity.visit == commander.flightSimulation.visit,
        let pending = native?.pending[identity], pending.binding == physical.identity,
        commander.nativeSalvageBodyOwnershipMatches(body, lot: pending.lot),
        !commander.salvageLedger.ownsPhysicalActor(physical.identity)
      else { return nil }
      return nativeSalvageMotion[identity]?.lot ?? pending.lot
    }
    guard physical.identity.system == systemIdentity,
      physical.identity.visit == commander.flightSimulation.visit,
      commander.salvageLedger.boundActor(for: identity) == physical.identity
    else {
      return nil
    }
    return salvageLotForGeometry(identity)
  }
}
