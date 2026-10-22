import Foundation

extension NativeInductionCrewLogSave {
  static func validateFields(
    _ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?
  ) throws {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      !root.keys.contains("savedNativeCrewLog"), !root.keys.contains("nativeCrewLog")
    else { throw SaveError.invalidCommander }
    if part == .missions {
      try validateInstances(root["instances"], schema: schema, embedded: false)
    }
    if part == .commander, let embedded = root["savedScriptState"] as? [String: Any] {
      try validateInstances(embedded["instances"], schema: schema, embedded: true)
    }
  }
  private static func validateInstances(_ raw: Any?, schema: Int?, embedded: Bool) throws {
    guard let raw else { return }
    let instances: [Any]
    if let dictionary = raw as? [String: Any], dictionary.count <= 128 {
      instances = Array(dictionary.values)
    } else if let pairs = raw as? [Any], pairs.count <= 256, pairs.count.isMultiple(of: 2) {
      instances = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
    } else {
      throw SaveError.invalidCommander
    }
    for entry in instances {
      guard let mission = entry as? [String: Any] else { throw SaveError.invalidCommander }
      let own = mission["definition"] as? String == NativeInductionCrewLogPack.stateID
      let pinned = mission["digest"] as? String == NativeInductionCrewLogPack.digest
      let claimed = mission.keys.contains("savedNativeCrewLog")
      guard own == pinned, own == claimed else { throw SaveError.invalidCommander }
      if own {
        guard contains(schema), !embedded,
          let leaf = mission["savedNativeCrewLog"] as? [String: Any],
          let auth = leaf["authorization"] as? [String: Any],
          let manifest = auth["manifest"] as? [String: Any],
          let crew = manifest["crew"] as? [Any], crew.count == 2,
          let losses = leaf["losses"] as? [Any], losses.count <= 3
        else { throw SaveError.invalidCommander }
        let bytes = try JSONSerialization.data(withJSONObject: leaf)
        guard bytes.count <= 16_384 else { throw SaveError.invalidCommander }
        let decoded = try JSONDecoder().decode(NativeInductionCrewLogState.self, from: bytes)
        guard
          (leaf as NSDictionary).isEqual(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
        else { throw SaveError.invalidCommander }
      }
    }
  }
}
