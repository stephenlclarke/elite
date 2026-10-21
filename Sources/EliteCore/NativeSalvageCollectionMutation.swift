import Foundation

/// Used only inside the actor's scene-sealed private candidate. Structural validation
/// establishes custody and history; the caller supplies actual scoop authority.
struct NativeSalvageCollectionMutation {
  let snapshot: AlienStorageSnapshot
  let cargo: [Int]

  init(
    snapshot previous: AlienStorageSnapshot, record: UUID, lot: SalvageLot,
    hull: UUID, at time: Double, cargo originalCargo: [Int]
  ) throws {
    guard time.isFinite, time >= 0, originalCargo.count == CommodityIdentity.allCases.count,
      originalCargo.allSatisfy({ $0 >= 0 && $0 <= Int.max / 17 }),
      let index = previous.world.firstIndex(where: { $0.id == record })
    else {
      throw AlienStorageError.invalidJoin
    }
    var world = previous.world
    var sources = previous.sources
    var attachments = previous.attachments
    var upgrades = previous.upgrades
    var commands = previous.commands
    var cargo = originalCargo
    let operation = UUID()
    let property = UUID()
    let source: UUID?
    let collection: AlienStorageCompanionCollection?
    if case .technology(let definition, _, _) = lot.content,
      AlienModuleDefinition.isAttachmentDefinition(definition)
    {
      let action: AlienStorageCommand.Action
      if let kind = try? AlienModuleDefinition.kind(for: lot) {
        attachments.append(
          .init(
            id: property, owner: previous.owner, kind: kind,
            source: operation, disposition: .stored,
            contributionBasisPoints: AlienModuleDefinition.baseBonusBasisPoints))
        action = .acquireAttachment(attachment: property, source: operation)
      } else {
        guard
          let kind = AlienModuleKind.allCases.first(where: {
            $0.upgradeDefinitionID == definition
          })
        else { throw AlienStorageError.invalidJoin }
        _ = try AlienModuleDefinition.upgradeBonus(for: lot, kind: kind)
        upgrades.append(
          .init(
            id: property, owner: previous.owner, kind: kind,
            source: operation, disposition: .stored))
        action = .acquireUpgrade(upgrade: property, source: operation)
      }
      let revision = previous.revision.addingReportingOverflow(1)
      guard !revision.overflow else { throw AlienStorageError.arithmeticOverflow }
      sources.append(
        .init(
          id: operation, owner: previous.owner, lot: lot,
          acquisition: operation))
      commands.append(
        .init(
          id: operation, owner: previous.owner,
          revision: revision.partialValue, action: action))
      source = operation
      collection = nil
    } else {
      let effect: AlienStorageCompanionCollection.Effect
      switch lot.content {
      case .commodity(let amount):
        let index = amount.commodity.rawValue
        let before = cargo[index]
        let after = before.addingReportingOverflow(amount.quantity)
        guard amount.quantity > 0, !after.overflow, after.partialValue <= Int.max / 17 else {
          throw AlienStorageError.arithmeticOverflow
        }
        cargo[index] = after.partialValue
        effect = .cargo(amount: amount, before: before, after: after.partialValue)
      case .technology: effect = .technology(storage: property)
      }
      source = nil
      collection = .init(operation: operation, hull: hull, at: time, effect: effect)
    }
    switch world[index] {
    case .lot(let old):
      guard case .pending(let actual, let at, _, _) = old.state,
        actual == lot, time >= at, let source
      else { throw AlienStorageError.invalidJoin }
      world[index] = .lot(
        .init(
          id: old.id, owner: old.owner, plan: old.plan,
          itemIndex: old.itemIndex, issuedAt: old.issuedAt,
          state: .acquired(source: source, at: time)))
    case .companion(let old):
      guard case .pending(let actual, let at, _, _) = old.state,
        actual == lot, time >= at, let collection
      else { throw AlienStorageError.invalidJoin }
      world[index] = .companion(
        .init(
          id: old.id, owner: old.owner, plan: old.plan,
          origin: old.origin, issuedAt: old.issuedAt, state: .collected(collection)))
    case .legacyCurrent(let old):
      guard case .pending(let actual, let at, _, _) = old.state,
        actual == lot, time >= at
      else { throw AlienStorageError.invalidJoin }
      let state: AlienStorageLegacyCurrent.State
      if let source {
        state = .acquired(source: source, at: time)
      } else if let collection {
        state = .collected(collection)
      } else {
        throw AlienStorageError.invalidJoin
      }
      world[index] = .legacyCurrent(
        .init(
          id: old.id, owner: old.owner, claim: old.claim,
          state: state))
    default: throw AlienStorageError.invalidJoin
    }
    let revision = previous.worldRevision.addingReportingOverflow(1)
    guard !revision.overflow, let count = UInt64(exactly: commands.count) else {
      throw AlienStorageError.arithmeticOverflow
    }
    let result = AlienStorageSnapshot(
      owner: previous.owner, revision: count,
      worldRevision: revision.partialValue, world: world, sources: sources,
      attachments: attachments, upgrades: upgrades, receipts: previous.receipts,
      commands: commands)
    try result.validateTransition(from: previous)
    self.snapshot = result
    self.cargo = cargo
  }
}
