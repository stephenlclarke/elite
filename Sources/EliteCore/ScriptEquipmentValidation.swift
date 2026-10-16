import Foundation

extension OwnedEquipmentItem {
  /// Every actual physical consumption emits these values, including personal devices with no issue delta.
  public var scriptConsumptionValues: [String: ScriptValue] {
    let name =
      retainedLegacyState?.originalEquipmentName
      ?? (node == EquipmentRuntimeCatalog.standardMissile ? "Missile" : node.key)
    return ["item": .string(id.uuidString), "name": .string(name)]
  }
}

extension LegacyOwnedEquipmentInventory {
  /// Explicit old-save admission only. Historical nonloan absence does not imply consumption.
  public func validateIssues(in engine: ScriptEngineState) throws {
    guard valid else { throw EquipmentMigrationError.unsupportedLegacyState }
    let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    for (id, instance) in engine.instances {
      guard id == instance.id else { throw EquipmentMigrationError.obligationMismatch }
      for (key, record) in instance.gearIssues {
        guard key == record.resource, (record.savedGearVersion ?? 1) == 1,
          record.valid(for: instance)
        else {
          throw EquipmentMigrationError.obligationMismatch
        }
        for id in record.items {
          let present = byID[id] != nil
          if record.status == .returned || record.consumed.contains(id) {
            guard !present else { throw EquipmentMigrationError.obligationMismatch }
          } else if record.loan && record.status == .issued && !present {
            throw EquipmentMigrationError.obligationMismatch
          } else if let item = byID[id] {
            guard item.kind == record.kind, item.issuedBy == instance.id,
              item.sourceResource == record.resource,
              item.loanOwner == (record.loan && record.status == .issued ? instance.id : nil)
            else { throw EquipmentMigrationError.obligationMismatch }
          }
        }
      }
    }
    for item in items {
      guard let mission = item.issuedBy else {
        guard item.sourceResource == nil, item.loanOwner == nil else {
          throw EquipmentMigrationError.obligationMismatch
        }
        continue
      }
      guard let resource = item.sourceResource,
        let record = engine.instances[mission]?.gearIssues[resource],
        record.items.contains(item.id), record.kind == item.kind,
        record.status != .returned, !record.consumed.contains(item.id),
        item.loanOwner == (record.loan && record.status == .issued ? mission : nil)
      else { throw EquipmentMigrationError.obligationMismatch }
    }
  }
}

extension Commander {
  /// Includes suspended/missing-content issues. Neither getters nor content presence create rights.
  public func equipmentIssueObligations() throws -> [EquipmentIssueObligationSnapshot] {
    var result: [EquipmentIssueObligationSnapshot] = []
    for (id, instance) in scriptState.instances.sorted(by: { $0.key.uuidString < $1.key.uuidString }
    ) {
      guard id == instance.id else { throw EquipmentMigrationError.obligationMismatch }
      for (key, record) in instance.gearIssues.sorted(by: { $0.key < $1.key }) {
        guard key == record.resource, record.valid(for: instance),
          let obligation = record.obligation
        else {
          throw EquipmentMigrationError.obligationMismatch
        }
        result.append(obligation)
      }
    }
    try validateIssueObligations(result)
    return result
  }

  var issuedEquipmentValid: Bool {
    (try? equipmentIssueObligations()) != nil
  }

  private func validateIssueObligations(_ obligations: [EquipmentIssueObligationSnapshot]) throws {
    guard let inventory = equipmentInventory else {
      guard obligations.isEmpty else { throw EquipmentMigrationError.obligationMismatch }
      return
    }
    try inventory.validate(
      context: EquipmentRuntimeCatalog.context(
        owner: inventory.owner, hull: inventory.activeHull, performance: nativePerformance))
    let originals = obligations.flatMap(\.items)
    guard Set(originals).count == originals.count else {
      throw EquipmentMigrationError.obligationMismatch
    }
    let byID = Dictionary(uniqueKeysWithValues: inventory.items.map { ($0.id, $0) })
    for record in obligations {
      for (index, id) in record.items.enumerated() {
        let item = byID[id]
        let absent =
          record.status == .returned || record.consumed.contains(id)
          || record.legacyMissingItems.contains(id)
        if absent {
          guard item == nil else { throw EquipmentMigrationError.obligationMismatch }
        } else {
          guard let item, item.node == record.node,
            item.provenance
              == .missionIssue(
                mission: record.source.mission, resource: record.source.resource, index: index,
                packDigest: record.source.packDigest)
          else { throw EquipmentMigrationError.obligationMismatch }
        }
      }
    }
    for item in inventory.items {
      guard case .missionIssue(let mission, let resource, let index, let digest) = item.provenance
      else { continue }
      guard let instance = scriptState.instances[mission],
        let record = instance.gearIssues[resource],
        record.savedGearVersion == 2, record.valid(for: instance),
        record.source?.packDigest == digest, record.node == item.node,
        item.retainedLegacyState?.originalEquipmentName
          == (record.kind.name == Equipment.legacyDockingComputer ? record.kind.name : nil),
        record.items.indices.contains(index), record.items[index] == item.id,
        record.status != .returned, !record.consumed.contains(item.id),
        record.legacyMissingItems?.contains(item.id) != true
      else { throw EquipmentMigrationError.obligationMismatch }
    }
  }
}

public struct ScriptGearConsumptionDelta: Sendable {
  public var eventKind: String { "gear.consumed" }
  public let source: EquipmentIssueSource
  public let item: UUID
  public let before: ScriptGearIssue
  public let after: ScriptGearIssue
  public let values: [String: ScriptValue]
  fileprivate init(
    source: EquipmentIssueSource, item: UUID, before: ScriptGearIssue, after: ScriptGearIssue,
    values: [String: ScriptValue]
  ) {
    self.source = source
    self.item = item
    self.before = before
    self.after = after
    self.values = values
  }
}

extension ScriptEngineState {
  /// Native own-loan fitting must retain any newly pinned personal displacement history too.
  public func applying(_ receipt: EquipmentIssueReceipt) throws -> Self {
    guard let instance = instances[receipt.source.mission],
      let before = instance.gearIssues[receipt.source.resource],
      before.savedGearVersion == 2, before.valid(for: instance), before.source == receipt.source,
      before.items == receipt.originalItems, before.consumed == receipt.consumedItems,
      receipt.displacements.starts(with: before.displacements ?? [])
    else { throw EquipmentIssueError.staleObligation }
    var after = before.replacingDisplacements(receipt.displacements)
    switch receipt.operation {
    case .stored, .refitted:
      guard before.status != .returned else { throw EquipmentIssueError.staleObligation }
    case .returned:
      guard before.status == .issued else { throw EquipmentIssueError.staleObligation }
      after.status = .returned
    case .released:
      guard before.status == .issued, before.loan else { throw EquipmentIssueError.staleObligation }
      after.status = .released
    case .issued: throw EquipmentIssueError.invalidRequest
    }
    guard after.valid(for: instance) else { throw EquipmentIssueError.staleObligation }
    var staged = self
    staged.instances[receipt.source.mission]?.gearIssues[receipt.source.resource] = after
    return staged
  }

  /// Receives the complete actual removed item. Virtual launches never call this physical adapter.
  public func gearConsumptionDelta(for removed: OwnedEquipmentItem) throws
    -> ScriptGearConsumptionDelta?
  {
    guard case .missionIssue(let mission, let resource, let index, let digest) = removed.provenance
    else { return nil }
    guard let instance = instances[mission], let before = instance.gearIssues[resource],
      before.savedGearVersion == 2, before.valid(for: instance),
      before.source?.packDigest == digest, before.node == removed.node,
      removed.retainedLegacyState?.originalEquipmentName
        == (before.kind.name == Equipment.legacyDockingComputer ? before.kind.name : nil),
      before.items.indices.contains(index), before.items[index] == removed.id,
      before.status != .returned, !before.consumed.contains(removed.id),
      before.legacyMissingItems?.contains(removed.id) != true, let source = before.source
    else { throw EquipmentMigrationError.obligationMismatch }
    var after = before
    after.consumed.insert(removed.id)
    // Return-all issues may legitimately have consumed originals; settlement then refuses.
    guard after.status != .returned, after.valid else {
      throw EquipmentMigrationError.obligationMismatch
    }
    return .init(
      source: source, item: removed.id, before: before, after: after,
      values: removed.scriptConsumptionValues)
  }

  public func applying(_ delta: ScriptGearConsumptionDelta) throws -> Self {
    var expected = delta.before
    expected.consumed.insert(delta.item)
    guard instances[delta.source.mission]?.gearIssues[delta.source.resource] == delta.before,
      delta.before.source == delta.source, delta.after.source == delta.source,
      delta.after == expected
    else { throw EquipmentIssueError.staleObligation }
    var staged = self
    staged.instances[delta.source.mission]?.gearIssues[delta.source.resource] = delta.after
    return staged
  }
}
