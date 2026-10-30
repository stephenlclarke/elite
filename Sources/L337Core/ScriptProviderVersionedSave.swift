import Foundation

/// G1 composes this boundary only after the alien-companion version 27 boundary is installed.
/// This helper intentionally does not change the commander writer or maximum accepted version.
enum ScriptProviderVersionedSave {
  static let version = 28
  enum Part { case commander, missions }
  static func rejectFields(_ bytes: Data, part: Part) throws {
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
      throw SaveError.invalidCommander
    }
    let engine: [String: Any]
    switch part {
    case .commander: engine = root["savedScriptState"] as? [String: Any] ?? [:]
    case .missions: engine = root
    }
    let instances: [Any]
    if let dictionary = engine["instances"] as? [String: Any] {
      instances = Array(dictionary.values)
    } else if let pairs = engine["instances"] as? [Any], pairs.count % 2 == 0 {
      instances = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
    } else {
      instances = []
    }
    // Key presence, including null, is forbidden below the reserved boundary.
    guard
      !instances.contains(where: {
        ($0 as? [String: Any])?.keys.contains("savedProviderContract") == true
      })
    else {
      throw SaveError.invalidCommander
    }
  }

  static func validateClaims(_ commander: Commander) -> Bool {
    commander.scriptState.instances.values.allSatisfy { instance in
      guard let state = instance.savedProviderContract else { return true }
      guard state.valid(instance: instance), state.owner == commander.equipmentOwnerID else {
        return false
      }
      if let crew = state.crew {
        guard let people = commander.nativePeople, people.valid(commander: commander),
          people.admissions.contains(where: { $0.person == crew.person }),
          people.transfers.contains(where: {
            $0.operation == crew.operation && $0.kind == .care && $0.members.contains(crew.person)
              && $0.dock == crew.dock && $0.owner == state.owner
          })
        else { return false }
      }
      if let sale = state.betrayal?.personSale {
        guard
          commander.nativePeople?.transfers.contains(where: {
            $0.operation == sale && $0.kind == .sale
          }) == true
        else { return false }
      }
      return true
    }
  }
}

extension Commander {
  var usesProviderContractSaveVersion: Bool {
    scriptState.instances.values.contains { $0.savedProviderContract != nil }
  }
}
