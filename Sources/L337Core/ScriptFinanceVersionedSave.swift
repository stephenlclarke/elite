import Foundation

/// Only missions.json in schema 23 may retain native financial obligations.
enum ScriptFinanceVersionedSave {
  enum Part { case missions, commander }
  static func rejectFields(_ bytes: Data, part: Part) throws {
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
      throw SaveError.invalidCommander
    }
    let state: [String: Any]
    switch part {
    case .missions: state = root
    case .commander: state = root["savedScriptState"] as? [String: Any] ?? [:]
    }
    guard !state.keys.contains("financeLedger") else { throw SaveError.invalidCommander }
  }
}
