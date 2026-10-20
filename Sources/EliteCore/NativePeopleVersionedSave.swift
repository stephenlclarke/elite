import Foundation

enum NativePeopleVersionedSave {
  static func validateStationPassengerFields(
    _ bytes: Data, part: ScriptFreightVersionedSave.Part, schema: Int?
  ) throws {
    try NativeOrbitalOutlookJourneySave.validateFields(bytes, part: part, schema: schema)
    try NativeStationPassengerJourneySave.validateFields(
      bytes, part: part, schema: NativeOrbitalOutlookJourneySave.lowerSchema(schema))
  }

  static func rejectFields(_ bytes: Data) throws {
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
      !root.keys.contains("savedNativePeopleCustody")
    else { throw SaveError.invalidCommander }
    let state = root["savedEMPState"] as? [String: Any] ?? [:]
    let records: [Any]
    if let dictionary = state["records"] as? [String: Any] {
      records = Array(dictionary.values)
    } else if let pairs = state["records"] as? [Any], pairs.count % 2 == 0 {
      records = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
    } else {
      records = []
    }
    guard
      !records.contains(where: {
        guard let record = $0 as? [String: Any] else { return false }
        return ["savedCrewCaptures", "savedDisableEpisodes", "savedDeceasedOrdinals"].contains {
          record.keys.contains($0)
        }
      })
    else { throw SaveError.invalidCommander }
  }
}

extension Commander {
  var usesNativePeopleSaveVersion: Bool {
    savedNativePeopleCustody != nil
      || savedEMPState?.records.values.contains(where: {
        $0.savedCrewCaptures != nil || $0.savedDisableEpisodes != nil
          || $0.savedDeceasedOrdinals != nil
      }) == true
  }
}
