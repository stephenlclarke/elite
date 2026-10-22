import Foundation

enum NativeC01SurveyorSave {
  static let version = 129
  static let alienVersion = 130
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    commander.scriptState.instances.values.contains { $0.savedGlassMeridian?.surveyor != nil }
  }
  /// New C01 envelopes may carry existing optional families, each still using its closed validator.
  static func lowerSchema(_ schema: Int?) -> Int? {
    guard contains(schema) else { return schema }
    return schema == alienVersion
      ? NativeInductionCrewLogSave.alienVersion : NativeInductionCrewLogSave.version
  }
  private static func instances(_ raw: Any?) throws -> [[String: Any]] {
    guard let raw else { return [] }
    let values: [Any]
    if let objects = raw as? [String: Any], objects.count <= 128 {
      values = Array(objects.values)
    } else if let pairs = raw as? [Any], pairs.count <= 256, pairs.count.isMultiple(of: 2) {
      values = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
    } else {
      throw SaveError.invalidCommander
    }
    return try values.map {
      guard let object = $0 as? [String: Any] else { throw SaveError.invalidCommander }
      return object
    }
  }
  static func validateFields(_ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?)
    throws
  {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      !root.keys.contains("surveyor"), !root.keys.contains("nativeC01Surveyor")
    else { throw SaveError.invalidCommander }
    func check(_ object: [String: Any], embedded: Bool) throws {
      for mission in try instances(object["instances"]) {
        guard !mission.keys.contains("surveyor"), !mission.keys.contains("nativeC01Surveyor")
        else { throw SaveError.invalidCommander }
        guard let opening = mission["savedGlassMeridian"] as? [String: Any],
          opening.keys.contains("surveyor")
        else { continue }
        guard contains(schema), !embedded,
          mission["definition"] as? String == NativeGlassMeridian.stateID,
          mission["digest"] as? String == NativeGlassMeridian.digest
        else { throw SaveError.invalidCommander }
        let decoded = try JSONDecoder().decode(
          NativeGlassMeridianState.self, from: JSONSerialization.data(withJSONObject: opening))
        guard decoded.surveyor != nil, NativeC01Surveyor.shapeValid(decoded),
          (opening as NSDictionary).isEqual(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
        else { throw SaveError.invalidCommander }
      }
    }
    if part == .missions { try check(root, embedded: false) }
    if part == .commander, let embedded = root["savedScriptState"] as? [String: Any] {
      try check(embedded, embedded: true)
    }
  }

  static func valid(_ mission: ScriptInstance, commander: borrowing Commander) -> Bool {
    guard let state = mission.savedGlassMeridian, NativeC01Surveyor.shapeValid(state) else {
      return false
    }
    guard let surveyor = state.surveyor else {
      return mission.ownedEncounters[NativeC01Surveyor.encounter] == nil
    }
    let source = surveyor.source
    guard source.physicalTime <= commander.flightSimulation.physicalTime,
      source.visit <= commander.flightSimulation.visit,
      let group = mission.ownedEncounters[NativeC01Surveyor.encounter], group.valid, group.admitted,
      group.galaxy == 0, group.system == 164,
      Set(group.actors.keys) == Set(NativeC01Surveyor.aliases)
    else { return false }
    for (index, alias) in NativeC01Surveyor.aliases.enumerated() {
      guard let actor = group.actors[alias],
        NativeC01Surveyor.original(actor, mission: mission.id, recorder: index == 1),
        let binding = actor.body.physical?.identity, binding.system == NativeC01Surveyor.location,
        binding.visit >= source.visit, binding.visit <= commander.flightSimulation.visit,
        binding.entity > 1, binding.entity < commander.flightSimulation.nextActor,
        actor.body.physical.map({ NativeC01Surveyor.nativeValid($0, recorder: index == 1) })
          == true,
        (actor.body.physical?.spawnIdentity?.sequence ?? UInt64.max)
          < commander.flightSimulation.nextSpawn
      else { return false }
      if index == 1 {
        if surveyor.capture != nil {
          guard actor.presence == .outside else { return false }
        } else if let loss = surveyor.loss, loss.kind == .recorderDestroyed {
          guard actor.presence == .destroyed, loss.marker == actor else { return false }
        } else if actor.presence == .destroyed {
          return false
        }
      }
    }
    if let capture = surveyor.capture {
      guard capture.physicalTime <= commander.flightSimulation.physicalTime,
        capture.collector.visit <= commander.flightSimulation.visit,
        capture.inventoryRevision < UInt64(Int64.max),
        let actor = group.actors[NativeC01Surveyor.aliases[1]],
        actor.identity == capture.marker.identity,
        actor.body.physical?.identity == capture.marker.body.physical?.identity,
        let owner = commander.equipmentOwnerID,
        capture.scoop.node == EquipmentRuntimeCatalog.node(for: "Fuel Scoops"),
        equipmentHistoryValid(capture.scoop, owner: owner, commander: commander),
        commander.equipmentInventory?.owner == owner
      else { return false }
    }
    if let loss = surveyor.loss {
      guard loss.physicalTime <= commander.flightSimulation.physicalTime,
        loss.collector.visit <= commander.flightSimulation.visit
      else { return false }
      if let pod = loss.escapePod {
        guard let owner = commander.equipmentOwnerID,
          pod.node == EquipmentRuntimeCatalog.node(for: "Escape Pod"),
          equipmentHistoryValid(pod, owner: owner, commander: commander),
          commander.equipmentInventory?.items.contains(where: { $0.id == pod.id }) == false
        else { return false }
      }
    }
    return true
  }

  private static func equipmentHistoryValid(
    _ item: EquipmentPurchaseItem, owner: UUID, commander: borrowing Commander
  ) -> Bool {
    if let history = commander.savedEquipmentPurchaseHistory {
      for receipt in history.paid where receipt.binding.request.newItem == item.id {
        return history.owner == owner && receipt.owner == owner && receipt.node == item.node
          && item.provenance == .paid(owner: owner, transaction: receipt.transaction)
      }
      for receipt in history.legacy where receipt.source.id == item.id {
        return history.owner == owner && receipt.owner == owner && receipt.source.node == item.node
          && item.provenance == .legacyUnknown
      }
    }
    switch item.provenance {
    case .paid, .legacyUnknown: return false
    case .standard, .grant, .recovered, .reward, .earned, .xyzzy, .missionIssue: return true
    }
  }

}
