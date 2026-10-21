import Foundation

enum NativeWayfarerInductionSave {
  static let version = 67
  static let alienVersion = 68
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func lowerSchema(_ schema: Int?) -> Int? {
    guard contains(schema) else { return schema }
    return schema == alienVersion
      ? NativeFirstCommoditySaleSave.alienVersion : NativeFirstCommoditySaleSave.version
  }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    commander.scriptState.instances.values.contains {
      $0.definition == NativeWayfarerInduction.stateID
        || $0.digest == NativeWayfarerInduction.digest
        || $0.savedWayfarerInduction != nil
    }
  }

  @inline(never)
  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    var count = 0
    for mission in commander.scriptState.instances.values {
      guard
        mission.definition == NativeWayfarerInduction.stateID
          || mission.digest == NativeWayfarerInduction.digest
          || mission.savedWayfarerInduction != nil
      else { continue }
      count += 1
      guard count == 1, valid(mission, commander: commander) else { return false }
    }
    return true
  }

  @inline(never)
  private static func valid(_ mission: ScriptInstance, commander: borrowing Commander) -> Bool {
    guard mission.definition == NativeWayfarerInduction.stateID,
      mission.digest == NativeWayfarerInduction.digest,
      mission.version == NativeWayfarerInduction.version,
      mission.outcome == .active, mission.contract == nil, mission.completionReceipt == nil,
      mission.dialogue == nil, mission.timers.isEmpty, mission.ownedEncounters.isEmpty,
      mission.gearIssues.isEmpty, let state = mission.savedWayfarerInduction, state.valid,
      state.permission.mission == mission.id, mission.payloads == state.payloads,
      mission.milestones == (state.crate == nil ? Set([0]) : Set([0, 1])),
      let owner = commander.equipmentOwnerID, owner == state.permission.owner,
      let world = commander.nativeStations,
      state.permission.trade.valid(in: commander.scriptState, owner: owner)
    else { return false }
    let p = state.permission
    guard world.mainStations.contains(p.dock.station),
      p.dock.sequence < world.nextMainDockSequence,
      p.dock.actor.visit <= commander.flightSimulation.visit,
      p.physicalTime <= commander.flightSimulation.physicalTime,
      p.flightSeconds <= commander.scriptState.flightSeconds
    else { return false }
    if let crate = state.crate {
      guard world.mainStations.contains(crate.dock.station),
        crate.dock.sequence < world.nextMainDockSequence,
        crate.dock.actor.visit <= commander.flightSimulation.visit,
        crate.physicalTime <= commander.flightSimulation.physicalTime,
        crate.issuedFlightSeconds <= commander.scriptState.flightSeconds
      else { return false }
    }
    if let loss = state.loss {
      guard loss.physicalTime <= commander.flightSimulation.physicalTime,
        loss.facts.visit <= commander.flightSimulation.visit,
        loss.facts.sequence <= commander.scriptState.nextEvent,
        mission.hasAcknowledged(loss.facts.sequence),
        loss.facts.context.revision < mission.revision,
        loss.facts.context.flightSeconds <= commander.scriptState.flightSeconds,
        loss.facts.context.localSeconds <= commander.scriptState.localSeconds,
        loss.facts.context.calendarSeconds <= commander.scriptState.calendarSeconds,
        loss.facts.context.transitSeconds <= commander.scriptState.transitSeconds
      else { return false }
    }
    return true
  }

  static func validateFields(
    _ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?
  ) throws {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      !root.keys.contains("savedWayfarerInduction"), !root.keys.contains("wayfarerInduction")
    else { throw SaveError.invalidCommander }
    func instances(_ raw: Any?) throws -> [[String: Any]] {
      guard let raw else { return [] }
      let values: [Any]
      if let dictionary = raw as? [String: Any], dictionary.count <= 128 {
        values = Array(dictionary.values)
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
    func validate(_ object: [String: Any], embedded: Bool) throws {
      for mission in try instances(object["instances"]) {
        let own = mission["definition"] as? String == NativeWayfarerInduction.stateID
        let pinned = mission["digest"] as? String == NativeWayfarerInduction.digest
        let claimed = mission.keys.contains("savedWayfarerInduction")
        guard own == pinned, own == claimed else { throw SaveError.invalidCommander }
        if own {
          guard !embedded, contains(schema),
            let leaf = mission["savedWayfarerInduction"] as? [String: Any]
          else { throw SaveError.invalidCommander }
          let bytes = try JSONSerialization.data(withJSONObject: leaf)
          guard bytes.count <= 16_384 else { throw SaveError.invalidCommander }
          let decoded = try JSONDecoder().decode(NativeWayfarerInductionState.self, from: bytes)
          guard decoded.valid,
            (leaf as NSDictionary).isEqual(
              try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
          else { throw SaveError.invalidCommander }
        }
      }
    }
    if part == .missions { try validate(root, embedded: false) }
    if part == .commander, let embedded = root["savedScriptState"] as? [String: Any] {
      try validate(embedded, embedded: true)
    }
  }
}
