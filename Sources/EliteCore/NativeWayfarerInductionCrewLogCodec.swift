import Foundation

extension NativeInductionCrewLogSave {
  static func validateFields(
    _ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?
  ) throws {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      !root.keys.contains("savedNativeCrewLog"), !root.keys.contains("nativeCrewLog"),
      !root.keys.contains("savedNativeInductionUtility"),
      !root.keys.contains("nativeInductionUtility"),
      !root.keys.contains("savedNativeInductionClinic"),
      !root.keys.contains("nativeInductionClinic"),
      !root.keys.contains("charterClinicSource"), !root.keys.contains("nativeInductionClinicSource")
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
      guard !mission.keys.contains("nativeInductionClinic"),
        !mission.keys.contains("charterClinicSource"),
        !mission.keys.contains("nativeInductionClinicSource")
      else { throw SaveError.invalidCommander }
      try NativeInductionUtilitySave.validateFields(mission, schema: schema, embedded: embedded)
      let own = mission["definition"] as? String == NativeInductionCrewLogPack.stateID
      let pinned = mission["digest"] as? String == NativeInductionCrewLogPack.digest
      let claimed = mission.keys.contains("savedNativeCrewLog")
      guard own == pinned, own == claimed else { throw SaveError.invalidCommander }
      if let parent = mission["savedWayfarerInduction"] as? [String: Any],
        parent.keys.contains("crewLog") || parent.keys.contains("crewLogLoss")
      {
        guard supportsPickup(schema), !embedded,
          mission["definition"] as? String == NativeWayfarerInduction.stateID,
          mission["digest"] as? String == NativeWayfarerInduction.digest
        else { throw SaveError.invalidCommander }
      }
      if let parent = mission["savedWayfarerInduction"] as? [String: Any],
        parent.keys.contains("crewLogHullCustody")
      {
        guard supportsHullCustody(schema), !embedded else { throw SaveError.invalidCommander }
      }
      if let parent = mission["savedWayfarerInduction"] as? [String: Any],
        parent.keys.contains("rescueReception")
      {
        guard supportsRescueReceiving(schema), !embedded,
          mission["definition"] as? String == NativeWayfarerInduction.stateID,
          mission["digest"] as? String == NativeWayfarerInduction.digest
        else { throw SaveError.invalidCommander }
      }
      if let parent = mission["savedWayfarerInduction"] as? [String: Any],
        parent.keys.contains("utilityReception")
      {
        guard supportsUtilityWork(schema), !embedded,
          mission["definition"] as? String == NativeWayfarerInduction.stateID,
          mission["digest"] as? String == NativeWayfarerInduction.digest
        else { throw SaveError.invalidCommander }
      }
      if let parent = mission["savedWayfarerInduction"] as? [String: Any],
        parent.keys.contains("charterChoice")
      {
        guard supportsCharterChoice(schema), !embedded,
          mission["definition"] as? String == NativeWayfarerInduction.stateID,
          mission["digest"] as? String == NativeWayfarerInduction.digest
        else { throw SaveError.invalidCommander }
      }
      if let parent = mission["savedWayfarerInduction"] as? [String: Any],
        parent.keys.contains("charterCapacity")
      {
        guard supportsCharterCapacity(schema), !embedded,
          mission["definition"] as? String == NativeWayfarerInduction.stateID,
          mission["digest"] as? String == NativeWayfarerInduction.digest
        else { throw SaveError.invalidCommander }
      }
      if let parent = mission["savedWayfarerInduction"] as? [String: Any],
        parent.keys.contains("charterSignatures")
          || ((parent["charterCapacity"] as? [String: Any])?["events"] as? [Any])?.isEmpty == false
      {
        guard supportsCharterConsent(schema), !embedded,
          mission["definition"] as? String == NativeWayfarerInduction.stateID,
          mission["digest"] as? String == NativeWayfarerInduction.digest
        else { throw SaveError.invalidCommander }
      }
      let clinic = mission["definition"] as? String == NativeInductionClinicPack.stateID
      let clinicPin = mission["digest"] as? String == NativeInductionClinicPack.digest
      let clinicClaim = mission.keys.contains("savedNativeInductionClinic")
      guard clinic == clinicPin, clinic == clinicClaim else { throw SaveError.invalidCommander }
      if clinic {
        guard supportsClinicAcceptance(schema), !embedded,
          let leaf = mission["savedNativeInductionClinic"] as? [String: Any]
        else { throw SaveError.invalidCommander }
        if leaf.keys.contains("custody") {
          guard supportsClinicCustody(schema) else { throw SaveError.invalidCommander }
        }
        let bytes = try JSONSerialization.data(withJSONObject: leaf)
        guard bytes.count <= 131072 else { throw SaveError.invalidCommander }
        let decoded = try JSONDecoder().decode(NativeInductionClinicContract.self, from: bytes)
        guard
          (leaf as NSDictionary).isEqual(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
        else { throw SaveError.invalidCommander }
      }
      if let parent = mission["savedWayfarerInduction"] as? [String: Any],
        parent.keys.contains("charterClinicSource")
      {
        if let source = parent["charterClinicSource"] as? [String: Any],
          source.keys.contains("history")
        {
          guard supportsClinicAcceptance(schema), !embedded else {
            throw SaveError.invalidCommander
          }
          if let history = source["history"] as? [[String: Any]],
            history.contains(where: {
              !["reserved", "cancelled", "failedBeforePickup"].contains($0["kind"] as? String ?? "")
            })
          {
            guard supportsClinicCustody(schema) else { throw SaveError.invalidCommander }
          }
        }
        guard supportsClinicSource(schema), !embedded,
          mission["definition"] as? String == NativeWayfarerInduction.stateID,
          mission["digest"] as? String == NativeWayfarerInduction.digest
        else { throw SaveError.invalidCommander }
      }
      if own {
        guard contains(schema), !embedded,
          let leaf = mission["savedNativeCrewLog"] as? [String: Any],
          let auth = leaf["authorization"] as? [String: Any],
          let manifest = auth["manifest"] as? [String: Any],
          let crew = manifest["crew"] as? [Any], crew.count == 2,
          let losses = leaf["losses"] as? [Any], losses.count <= 3
        else { throw SaveError.invalidCommander }
        if leaf.keys.contains("rescueFuel") || leaf.keys.contains("rescueReserve") {
          guard supportsRescueFunding(schema),
            let rawBank = leaf["rescueFuel"] as? [String: Any],
            let rawReserve = leaf["rescueReserve"] as? [String: Any]
          else { throw SaveError.invalidCommander }
          _ = try NativeRescueFuelEscrow.decodeClosed(
            JSONSerialization.data(withJSONObject: rawBank))
          let reserveBytes = try JSONSerialization.data(withJSONObject: rawReserve)
          guard reserveBytes.count <= 8192 else { throw SaveError.invalidCommander }
          let reserve = try JSONDecoder().decode(NativeRescueLaunchReserve.self, from: reserveBytes)
          guard
            (rawReserve as NSDictionary).isEqual(
              try JSONSerialization.jsonObject(with: JSONEncoder().encode(reserve)))
          else { throw SaveError.invalidCommander }
        }
        if leaf.keys.contains("flight") {
          guard supportsRescueFlight(schema) else { throw SaveError.invalidCommander }
          if let flight = leaf["flight"] as? [String: Any],
            !Set(flight.keys).isDisjoint(with: [
              "savedFuelContacts", "dockedContact", "savedExits", "savedBindings", "serviceWait",
            ])
          {
            guard supportsRescueService(schema) else { throw SaveError.invalidCommander }
          }
        }
        if leaf.keys.contains("rescueReception")
          || (leaf["rescueFuel"] as? [String: Any])?.keys.contains("closure") == true
        {
          guard supportsRescueReceiving(schema) else { throw SaveError.invalidCommander }
        }
        let bytes = try JSONSerialization.data(withJSONObject: leaf)
        guard supportsPickup(schema) || leaf["capture"] == nil else {
          throw SaveError.invalidCommander
        }
        guard bytes.count <= 524_288 else { throw SaveError.invalidCommander }
        let decoded = try JSONDecoder().decode(NativeInductionCrewLogState.self, from: bytes)
        guard
          (leaf as NSDictionary).isEqual(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
        else { throw SaveError.invalidCommander }
      }
    }
  }
}
