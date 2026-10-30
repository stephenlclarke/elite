import Foundation

enum NativeIsolationProgrammerError: Error, Equatable {
  case unavailableOriginal
}

/// A fresh read of the existing issue obligation; it owns no item or duplicate loan history.
struct NativeIsolationProgrammerBinding: Equatable, Sendable {
  let source: EquipmentIssueSource
  let issuer: UUID
  let serial: UUID
  let owner: UUID
  let hull: UUID
  let inventoryRevision: UInt64
}

enum NativeIsolationProgrammerCustody {
  /// Even a returned or lost original reserves its historical source. A new parent is not new stock.
  static func hasIssuedOriginal(in commander: Commander) -> Bool {
    commander.scriptState.instances.values.contains {
      $0.gearIssues[NativeIsolationProgrammerDefinition.resource] != nil
    }
  }

  /// The caller must first authenticate its actual native parent permission. This projection
  /// independently rejoins the canonical inventory, exact source and retained loan obligation.
  static func resolve(parent: ScriptInstance, commander: Commander) throws
    -> NativeIsolationProgrammerBinding
  {
    guard commander.scriptState.instances[parent.id]?.digest == parent.digest,
      commander.scriptState.instances[parent.id]?.gearIssues == parent.gearIssues,
      let inventory = commander.equipmentInventory,
      let issue = parent.gearIssues[NativeIsolationProgrammerDefinition.resource],
      issue.valid(for: parent), issue.kind == .module(NativeIsolationProgrammerDefinition.name),
      issue.loan, !issue.returnRemaining, issue.status == .issued, issue.consumed.isEmpty,
      issue.items == [NativeIsolationProgrammerDefinition.serial(parent: parent.id)],
      issue.displacements == [], issue.legacyMissingItems == nil,
      let obligation = issue.obligation,
      (try? commander.equipmentIssueObligations())?.contains(obligation) == true,
      let item = inventory.items.first(where: { $0.id == issue.items[0] }),
      item.node == NativeIsolationProgrammerDefinition.node, item.location == nil,
      item.component == nil, item.nativeRepairLoopCondition == nil,
      item.provenance
        == .missionIssue(
          mission: parent.id, resource: NativeIsolationProgrammerDefinition.resource,
          index: 0, packDigest: parent.digest)
    else { throw NativeIsolationProgrammerError.unavailableOriginal }
    return .init(
      source: obligation.source,
      issuer: NativeIsolationProgrammerDefinition.issuer(owner: inventory.owner),
      serial: item.id, owner: inventory.owner, hull: inventory.activeHull,
      inventoryRevision: inventory.revision)
  }
}
