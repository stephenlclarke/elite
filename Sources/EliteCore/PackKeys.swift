import Foundation
import TOMLDecoder

enum PackKeys {
  static func validate(_ data: Data) throws {
    let root = try TOMLTable(source: data)
    try keys(
      root,
      allowed:
        "schemaVersion id version minimumEngine capabilities dependencies priority source license mission stages transitions dialogs clues encounters"
    )
    try keys(
      root.table(forKey: "mission"),
      allowed: "id title initialStage briefing destination reward prerequisites milestones binding")
    let tables = [
      "stages": "id objective completed terminal outcome legacyValues legacyWrite",
      "transitions": "id from event to conditions actions dialog confirmation notification",
      "dialogs": "id text ship delaySeconds",
      "clues": "galaxy systems texts", "encounters": "id stage galaxy system kind",
    ]
    for (name, allowed) in tables where root.contains(key: name) {
      let array = try root.array(forKey: name)
      for index in 0..<array.count {
        let table = try array.table(atIndex: index)
        try keys(table, allowed: allowed)
        if name == "transitions" {
          for (child, fields) in [
            "conditions": "field op value text", "actions": "kind key amount",
          ] where table.contains(key: child) {
            let values = try table.array(forKey: child)
            for item in 0..<values.count { try keys(values.table(atIndex: item), allowed: fields) }
          }
        }
      }
    }
  }
  private static func keys(_ table: TOMLTable, allowed: String) throws {
    let unknown = Set(table.keys).subtracting(allowed.split(separator: " ").map(String.init))
    guard unknown.isEmpty else {
      throw MissionPackError("Unknown TOML keys: " + unknown.sorted().joined(separator: ", "))
    }
  }
}
