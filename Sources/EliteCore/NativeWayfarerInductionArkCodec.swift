import Foundation

extension NativeInductionArkSave {
  /// Validate this feature before lowering its schema for the older C08 gates.
  static func validateFields(
    _ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?
  ) throws {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      !root.keys.contains("savedNativeArk"), !root.keys.contains("nativeArk")
    else { throw SaveError.invalidCommander }
    if let world = root["nativeStations"] as? [String: Any], world.keys.contains("arkFuel") {
      guard part == .commander,
        schema == version || schema == alienVersion || schema == 77 || schema == 78,
        let stocks = world["arkFuel"] as? [[String: Any]], !stocks.isEmpty,
        stocks.count <= NativeMainStationIdentity.maximumCount
      else { throw SaveError.invalidCommander }
      for stock in stocks {
        let bytes = try JSONSerialization.data(withJSONObject: stock)
        guard bytes.count <= 262_144 else { throw SaveError.invalidCommander }
        let decoded = try JSONDecoder().decode(NativeArkStationFuel.self, from: bytes)
        guard decoded.valid,
          (stock as NSDictionary).isEqual(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
        else { throw SaveError.invalidCommander }
      }
    }
    if part == .missions {
      try validateInstances(root["instances"], schema: schema, embedded: false)
    }
    if part == .commander, let embedded = root["savedScriptState"] as? [String: Any] {
      try validateInstances(embedded["instances"], schema: schema, embedded: true)
    }
  }

  private static func validateInstances(_ raw: Any?, schema: Int?, embedded: Bool) throws {
    guard let raw else { return }
    let values: [Any]
    if let dictionary = raw as? [String: Any], dictionary.count <= 128 {
      values = Array(dictionary.values)
    } else if let pairs = raw as? [Any], pairs.count <= 256, pairs.count.isMultiple(of: 2) {
      values = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
    } else {
      throw SaveError.invalidCommander
    }
    for value in values {
      guard let mission = value as? [String: Any] else { throw SaveError.invalidCommander }
      let own = mission["definition"] as? String == NativeInductionArkPack.stateID
      let pinned = mission["digest"] as? String == NativeInductionArkPack.digest
      let claimed = mission.keys.contains("savedNativeArk")
      guard own == pinned, own == claimed else { throw SaveError.invalidCommander }
      if let parent = mission["savedWayfarerInduction"] as? [String: Any],
        parent.keys.contains("ark")
      {
        guard !embedded, contains(schema) else { throw SaveError.invalidCommander }
      }
      if let parent = mission["savedWayfarerInduction"] as? [String: Any],
        parent.keys.contains("seedReception")
      {
        guard !embedded, schema == version || schema == alienVersion else {
          throw SaveError.invalidCommander
        }
      }
      if own {
        guard !embedded, contains(schema), let leaf = mission["savedNativeArk"] as? [String: Any]
        else { throw SaveError.invalidCommander }
        let bytes = try JSONSerialization.data(withJSONObject: leaf)
        guard bytes.count <= 524_288, let bank = leaf["fuel"] as? [String: Any] else {
          throw SaveError.invalidCommander
        }
        if schema != version && schema != alienVersion {
          guard leaf["reception"] == nil, bank["closure"] == nil else {
            throw SaveError.invalidCommander
          }
        }
        if schema == 75 || schema == 76 {
          guard leaf["serviceWait"] == nil, leaf["savedExits"] == nil,
            (leaf["fuelContacts"] as? [Any])?.isEmpty == true,
            (bank["purchases"] as? [Any])?.isEmpty == true
          else { throw SaveError.invalidCommander }
        }
        _ = try NativeArkFuelEscrow.decodeClosed(JSONSerialization.data(withJSONObject: bank))
        let decoded = try JSONDecoder().decode(NativeInductionArkState.self, from: bytes)
        guard
          (leaf as NSDictionary).isEqual(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
        else { throw SaveError.invalidCommander }
      }
    }
  }
}
