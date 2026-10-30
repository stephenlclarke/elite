import Foundation

extension Commander {
  func fittedAlienSummary(_ kind: AlienModuleKind) -> AlienAttachmentSummary {
    guard let hull = hullInstanceID, let current = alienStorageState?.current,
      current.owner == equipmentOwnerID
    else {
      return .init(count: 0, bonusBasisPoints: 0)
    }
    return current.summaries(for: hull)[kind] ?? .init(count: 0, bonusBasisPoints: 0)
  }

  var fittedAlienEnergyModuleCount: Int? {
    let count = fittedAlienSummary(.energyCapacity).count.addingReportingOverflow(
      fittedAlienSummary(.energyRecharge).count)
    return count.overflow ? nil : count.partialValue
  }
}

extension Game {
  var nativeAlienServiceContext: NativeMainStationArrivalContext? {
    guard docked, dockedAtMainStation, commander.system == Plugh.systemID,
      commander.alienStorageStateValid,
      case .living(let destination) = nativeOriginalMainStationDestination,
      destination.identity.system == systemIdentity,
      destination.identity.world == commander.equipmentOwnerID
    else { return nil }
    return nativeMainStationArrivalContext(for: destination.identity)
  }
  var nativeAlienFittingAvailable: Bool { nativeAlienServiceContext != nil }

  func nativeAlienInventoryPreview(
    _ id: UUID, upgrade: Bool,
    inventory: OwnedEquipmentInventory
  ) -> InventoryActionPreview {
    guard let current = commander.alienStorageState?.current else {
      return .init(label: "", detail: "Recovered module unavailable", command: nil)
    }
    guard let service = nativeAlienServiceContext else {
      return .init(
        label: "", detail: "Dock at PLUGH main station for free alien refitting", command: nil)
    }
    let action: InventoryCommand.Action
    let label: String
    var extra: [String] = []
    if upgrade {
      guard let source = current.snapshot.upgrades.first(where: { $0.id == id }),
        source.disposition == .stored,
        let attachment = current.snapshot.attachments.filter({
          $0.kind == source.kind && $0.disposition == .fitted(hull: inventory.activeHull)
        }).sorted(by: { $0.id.uuidString < $1.id.uuidString }).first
      else {
        return .init(label: "", detail: "Fit a matching physical alien module first", command: nil)
      }
      action = .alienApplyUpgrade(
        upgrade: id, attachment: attachment.id,
        revision: current.revision, worldRevision: current.worldRevision, service: service)
      label = "Upgrade"
      extra = ["Target physical module: " + attachment.id.uuidString]
    } else {
      guard let attachment = current.snapshot.attachments.first(where: { $0.id == id }) else {
        return .init(label: "", detail: "Recovered module unavailable", command: nil)
      }
      let fit: Bool
      switch attachment.disposition {
      case .stored: fit = true
      case .fitted(let hull):
        guard hull == inventory.activeHull else {
          return .init(label: "", detail: "Module belongs to another owned hull", command: nil)
        }
        fit = false
      case .retired:
        return .init(label: "", detail: "Module is no longer aboard", command: nil)
      }
      action = .alienRelocate(
        id, fit: fit, revision: current.revision,
        worldRevision: current.worldRevision, service: service)
      label = fit ? "Fit" : "Store"
    }
    return .init(
      label: label, detail: "PLUGH fitting: 0 CR; source retained",
      command: .init(
        owner: inventory.owner, hull: inventory.activeHull,
        context: inventoryContextEpoch, shipID: commander.shipID,
        ownedRevision: inventory.revision, sourceRevision: current.revision, action: action),
      extraDetails: extra)
  }

  mutating func applyNativeAlienFitting(_ action: InventoryCommand.Action) throws {
    guard nativeAlienFittingAvailable, let hull = commander.hullInstanceID,
      let current = commander.alienStorageState?.current
    else { throw SaveError.invalidCommander }
    let previous = current.snapshot
    var attachments = previous.attachments
    var upgrades = previous.upgrades
    var receipts = previous.receipts
    let operation = UUID()
    let command: AlienStorageCommand.Action
    let expectedRevision: UInt64
    let expectedWorld: UInt64
    switch action {
    case .alienRelocate(let id, let fit, let revision, let worldRevision, let service):
      guard acceptsNativeMainStationArrivalContext(service) else {
        throw SaveError.invalidCommander
      }
      expectedRevision = revision
      expectedWorld = worldRevision
      guard let index = attachments.firstIndex(where: { $0.id == id }) else {
        throw AlienStorageError.invalidJoin
      }
      let old = attachments[index]
      guard fit ? old.disposition == .stored : old.disposition == .fitted(hull: hull) else {
        throw AlienStorageError.historyChanged
      }
      let destination: AlienStorageDisposition = fit ? .fitted(hull: hull) : .stored
      attachments[index] = .init(
        id: old.id, owner: old.owner, kind: old.kind,
        source: old.source, disposition: destination,
        contributionBasisPoints: old.contributionBasisPoints)
      command = .relocate(attachment: id, to: destination)
    case .alienApplyUpgrade(
      let upgradeID, let attachmentID, let revision, let worldRevision, let service):
      guard acceptsNativeMainStationArrivalContext(service) else {
        throw SaveError.invalidCommander
      }
      expectedRevision = revision
      expectedWorld = worldRevision
      guard let index = attachments.firstIndex(where: { $0.id == attachmentID }),
        let upgradeIndex = upgrades.firstIndex(where: { $0.id == upgradeID }),
        attachments[index].disposition == .fitted(hull: hull),
        upgrades[upgradeIndex].disposition == .stored,
        attachments[index].kind == upgrades[upgradeIndex].kind,
        let source = previous.sources.first(where: { $0.id == upgrades[upgradeIndex].source })
      else {
        throw AlienStorageError.invalidJoin
      }
      let old = attachments[index]
      let bonus = try AlienModuleDefinition.upgradeBonus(for: source.lot, kind: old.kind)
      let contribution = old.contributionBasisPoints.addingReportingOverflow(bonus)
      guard !contribution.overflow else { throw AlienStorageError.arithmeticOverflow }
      attachments[index] = .init(
        id: old.id, owner: old.owner, kind: old.kind,
        source: old.source, disposition: old.disposition,
        contributionBasisPoints: contribution.partialValue)
      let upgrade = upgrades[upgradeIndex]
      upgrades[upgradeIndex] = .init(
        id: upgrade.id, owner: upgrade.owner, kind: upgrade.kind,
        source: upgrade.source, disposition: .applied(attachment: old.id, operation: operation))
      receipts.append(
        .init(
          id: UUID(), owner: previous.owner, operation: operation,
          effect: .upgrade(attachment: old.id, upgrade: upgrade.id, basisPoints: bonus)))
      command = .applyUpgrade(attachment: old.id, upgrade: upgrade.id)
    default: throw AlienStorageError.invalidJoin
    }
    guard expectedRevision == previous.revision, expectedWorld == previous.worldRevision else {
      throw AlienStorageError.historyChanged
    }
    let revision = previous.revision.addingReportingOverflow(1)
    guard !revision.overflow else { throw AlienStorageError.arithmeticOverflow }
    var commands = previous.commands
    commands.append(
      .init(
        id: operation, owner: previous.owner,
        revision: revision.partialValue, action: command))
    try commander.replaceAlienStorage(
      with: .init(
        owner: previous.owner,
        revision: revision.partialValue, worldRevision: previous.worldRevision,
        world: previous.world, sources: previous.sources, attachments: attachments,
        upgrades: upgrades, receipts: receipts, commands: commands))
    guard commander.valid, let used = commander.checkedCargoTonnes,
      used <= commander.capacity
    else { throw SaveError.invalidCommander }
    // A larger capacity never grants charge. Stowing clamps only excess existing charge.
    energy = min(energy, commander.performance.energy)
    frontShield = min(frontShield, commander.shieldCapacity)
    rearShield = min(rearShield, commander.rearShieldCapacity)
    notify("ALIEN MODULE REFITTED - 0 CR")
  }
}

extension Commander {
  /// The existing whole-hull exchange supplies actual old/new owned hull identities.
  /// Every fitted physical module moves once with a permanent receipt; stored property stays held.
  mutating func transferAlienFittings(from oldHull: UUID, to newHull: UUID) throws {
    guard let previous = alienStorageState?.current.snapshot else { return }
    let members = previous.attachments.filter { $0.disposition == .fitted(hull: oldHull) }
    guard !members.isEmpty else { return }
    guard oldHull != newHull, hullInstanceID == newHull,
      let count = UInt64(exactly: members.count)
    else { throw AlienStorageError.invalidJoin }
    let revision = previous.revision.addingReportingOverflow(1)
    guard !revision.overflow else { throw AlienStorageError.arithmeticOverflow }
    let operation = UUID()
    let attachments = previous.attachments.map { item in
      guard item.disposition == .fitted(hull: oldHull) else { return item }
      return AlienStorageAttachment(
        id: item.id, owner: item.owner, kind: item.kind,
        source: item.source, disposition: .fitted(hull: newHull),
        contributionBasisPoints: item.contributionBasisPoints)
    }
    var receipts = previous.receipts
    receipts.append(
      contentsOf: members.map {
        .init(
          id: UUID(), owner: previous.owner, operation: operation,
          effect: .transfer(attachment: $0.id))
      })
    var commands = previous.commands
    commands.append(
      .init(
        id: operation, owner: previous.owner, revision: revision.partialValue,
        action: .transferHull(from: oldHull, to: newHull, members: count)))
    try replaceAlienStorage(
      with: .init(
        owner: previous.owner, revision: revision.partialValue,
        worldRevision: previous.worldRevision, world: previous.world, sources: previous.sources,
        attachments: attachments, upgrades: previous.upgrades, receipts: receipts,
        commands: commands))
  }
}
