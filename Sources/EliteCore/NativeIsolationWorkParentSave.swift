import Foundation

enum NativeIsolationWorkParentSave {
  static let version = 133
  static let alienVersion = 134
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func lowerSchema(_ schema: Int?) -> Int? {
    guard contains(schema) else { return schema }
    return schema == alienVersion
      ? NativeIsolationWorkSave.alienVersion : NativeIsolationWorkSave.version
  }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    commander.scriptState.instances.values.contains(where: NativeIsolationWorkParent.marked)
  }
  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    let parents = commander.scriptState.instances.values.filter(NativeIsolationWorkParent.marked)
    guard parents.count <= 1 else { return false }
    for parent in parents {
      guard (try? NativeIsolationWorkParent.primitive(parent: parent, commander: commander)) != nil,
        parent.outcome == .active, parent.contract?.settled == false,
        parent.completionReceipt == nil,
        parent.milestones == [0], parent.data == .object([:]),
        parent.timers.isEmpty, parent.dialogue == nil,
        parent.ownedEncounters.isEmpty, parent.campaignParent == nil,
        parent.campaignChildren.isEmpty
      else { return false }
      if case .returned? = parent.savedIsolationWorkParent?.cutoff { return false }
      guard let proof = parent.savedIsolationWorkParent,
        let child = commander.scriptState.instances[
          NativeIsolationWorkPack.instance(source: proof.source)],
        child.definition == NativeIsolationWorkPack.stateID,
        child.digest == NativeIsolationWorkPack.digest,
        let provider = child.savedIsolationWork, provider.source == proof.source,
        provider.permission.parent == parent.id,
        provider.permission.parentDigest == parent.digest,
        provider.permission.authorization == proof.authorization,
        provider.permission.issueOperation == proof.issue.operation,
        provider.permission.owner == proof.owner, provider.permission.issuer == proof.issuer,
        provider.permission.programmer == proof.issue.original
      else { return false }
    }
    return true
  }
  static func validateFields(_ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?)
    throws
  {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      !root.keys.contains("savedIsolationWorkParent"), !root.keys.contains("isolationWorkParent")
    else { throw SaveError.invalidCommander }
    func validate(_ raw: Any?, embedded: Bool) throws {
      guard let raw else { return }
      let values: [Any]
      if let dictionary = raw as? [String: Any], dictionary.count <= 128 {
        values = Array(dictionary.values)
      } else if let pairs = raw as? [Any], pairs.count <= 256, pairs.count.isMultiple(of: 2) {
        values = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
      } else {
        throw SaveError.invalidCommander
      }
      for raw in values {
        guard let mission = raw as? [String: Any], !mission.keys.contains("isolationWorkParent")
        else {
          throw SaveError.invalidCommander
        }
        let own = mission["definition"] as? String == NativeIsolationWorkParent.stateID
        let pinned = mission["digest"] as? String == NativeIsolationWorkParent.digest
        let claimed = mission.keys.contains("savedIsolationWorkParent")
        guard own == pinned, own == claimed else { throw SaveError.invalidCommander }
        if own {
          guard contains(schema), !embedded,
            let value = mission["savedIsolationWorkParent"] as? [String: Any]
          else { throw SaveError.invalidCommander }
          let decoded = try JSONDecoder().decode(
            NativeIsolationWorkParentState.self, from: JSONSerialization.data(withJSONObject: value)
          )
          guard
            (value as NSDictionary).isEqual(
              try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
          else { throw SaveError.invalidCommander }
        }
      }
    }
    if part == .missions { try validate(root["instances"], embedded: false) }
    if part == .commander, let embedded = root["savedScriptState"] as? [String: Any] {
      try validate(embedded["instances"], embedded: true)
    }
  }
}
