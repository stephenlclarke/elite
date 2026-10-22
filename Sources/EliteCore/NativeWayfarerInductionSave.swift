import Foundation

enum NativeWayfarerInductionSave {
  static let version = 73
  static let alienVersion = 74
  static func contains(_ schema: Int?) -> Bool {
    supportsContinuation(schema) || schema == 67 || schema == 68
  }
  static func isAlien(_ schema: Int?) -> Bool {
    schema == alienVersion || schema == 72 || schema == 70 || schema == 68
  }
  static func supportsContinuation(_ schema: Int?) -> Bool {
    supportsCassetteService(schema) || schema == 69 || schema == 70
  }
  static func supportsCassetteService(_ schema: Int?) -> Bool {
    supportsVaultKey(schema) || schema == 71 || schema == 72
  }
  static func supportsVaultKey(_ schema: Int?) -> Bool {
    schema == version || schema == alienVersion
  }
  static func lowerSchema(_ schema: Int?) -> Int? {
    guard contains(schema) else { return schema }
    return isAlien(schema)
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
      mission.milestones == state.milestones,
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
    if let reception = state.reception {
      guard world.mainStations.contains(reception.dock.station),
        reception.dock.sequence < world.nextMainDockSequence,
        reception.dock.actor.visit <= commander.flightSimulation.visit,
        reception.physicalTime <= commander.flightSimulation.physicalTime,
        reception.flightSeconds <= commander.scriptState.flightSeconds
      else { return false }
    }
    if let cassette = state.cassette {
      guard world.mainStations.contains(cassette.dock.station),
        cassette.dock.sequence < world.nextMainDockSequence,
        cassette.dock.actor.visit <= commander.flightSimulation.visit,
        cassette.physicalTime <= commander.flightSimulation.physicalTime,
        cassette.flightSeconds <= commander.scriptState.flightSeconds
      else { return false }
    }
    if let service = state.cassetteService {
      guard world.mainStations.contains(service.dock.station),
        service.dock.sequence < world.nextMainDockSequence,
        service.dock.actor.visit <= commander.flightSimulation.visit,
        service.physicalTime <= commander.flightSimulation.physicalTime,
        service.flightSeconds <= commander.scriptState.flightSeconds
      else { return false }
    }
    if let key = state.seedKey {
      guard world.mainStations.contains(key.dock.station),
        key.dock.sequence < world.nextMainDockSequence,
        key.dock.actor.visit <= commander.flightSimulation.visit,
        key.physicalTime <= commander.flightSimulation.physicalTime,
        key.flightSeconds <= commander.scriptState.flightSeconds
      else { return false }
    }
    if let capture = state.crewLog {
      guard capture.sequence <= commander.scriptState.nextEvent,
        mission.hasAcknowledged(capture.sequence),
        capture.physicalTime <= commander.flightSimulation.physicalTime,
        capture.flightSeconds <= commander.scriptState.flightSeconds,
        capture.actor.visit <= commander.flightSimulation.visit
      else { return false }
    }
    if let choice = state.charterChoice,
      !NativeInductionCharterSave.claimsValid(choice, mission: mission, commander: commander)
    {
      return false
    }
    if let capacity = state.charterCapacity,
      !NativeInductionCapacitySave.claimsValid(capacity, mission: mission, commander: commander)
    {
      return false
    }
    if let signatures = state.charterSignatures,
      !NativeInductionCharterConsentSave.signaturesValid(
        signatures, mission: mission, commander: commander)
    {
      return false
    }
    if let audit = state.charterAudit,
      !NativeInductionCharterAuditSave.claimsValid(audit, mission: mission, commander: commander)
    {
      return false
    }
    for loss in [state.loss, state.cassetteLoss, state.seedKeyLoss, state.crewLogLoss].compactMap({
      $0
    }) {
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
          guard bytes.count <= (leaf.keys.contains("charterCapacity") ? 1_048_576 : 32_768) else {
            throw SaveError.invalidCommander
          }
          let decoded = try JSONDecoder().decode(NativeWayfarerInductionState.self, from: bytes)
          guard
            supportsContinuation(schema)
              || (decoded.reception == nil && decoded.cassette == nil
                && decoded.cassetteLoss == nil)
          else { throw SaveError.invalidCommander }
          guard supportsCassetteService(schema) || decoded.cassetteService == nil else {
            throw SaveError.invalidCommander
          }
          guard supportsVaultKey(schema) || (decoded.seedKey == nil && decoded.seedKeyLoss == nil)
          else {
            throw SaveError.invalidCommander
          }
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
