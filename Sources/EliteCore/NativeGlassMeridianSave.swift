import Foundation

enum NativeGlassMeridianSave {
  static let version = 63
  static let alienVersion = 64
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func lowerSchema(_ schema: Int?) -> Int? {
    guard contains(schema) else { return schema }
    return schema == alienVersion
      ? NativeFleetDiscoverySave.alienVersion : NativeFleetDiscoverySave.version
  }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    for mission in commander.scriptState.instances.values {
      if mission.definition == NativeGlassMeridian.stateID
        || mission.digest == NativeGlassMeridian.digest || mission.savedGlassMeridian != nil
      {
        return true
      }
    }
    return false
  }
  @inline(never)
  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    var count = 0
    for mission in commander.scriptState.instances.values {
      guard
        mission.definition == NativeGlassMeridian.stateID
          || mission.digest == NativeGlassMeridian.digest || mission.savedGlassMeridian != nil
      else { continue }
      count += 1
      guard count == 1, valid(mission, commander: commander) else { return false }
    }
    return true
  }

  @inline(never)
  private static func valid(_ mission: ScriptInstance, commander: borrowing Commander) -> Bool {
    guard mission.definition == NativeGlassMeridian.stateID,
      mission.digest == NativeGlassMeridian.digest,
      mission.version == NativeGlassMeridian.version, mission.outcome == .active,
      mission.contract == nil, mission.completionReceipt == nil, mission.dialogue == nil,
      mission.payloads.isEmpty, mission.gearIssues.isEmpty, mission.timers.isEmpty,
      let state = mission.savedGlassMeridian, let owner = commander.equipmentOwnerID,
      let world = commander.nativeStations,
      let discovery = commander.scriptState.savedFleetDiscovery,
      state.permission.owner == owner, discovery.owner == owner,
      NativeGlassMeridian.readingsValid(state), NativeGlassMeridian.lossesValid(state),
      NativeC01SurveyorSave.valid(mission, commander: commander),
      NativeC01ReservationAuditSave.valid(mission, commander: commander)
    else { return false }
    let p = state.permission
    guard p.mission == mission.id,
      mission.id == ScriptIdentity.uuid("glass-meridian-commission-v1:\(owner)"),
      p.dock.valid, p.dock.commanderOwner == owner,
      p.dock.station.system == SystemIdentity(galaxy: 0, system: 7),
      world.mainStations.contains(p.dock.station), p.dock.sequence < world.nextMainDockSequence,
      p.operation
        == (try? NativeGlassMeridian.operation(mission: mission.id, owner: owner, dock: p.dock)),
      p.physicalTime.isFinite, p.physicalTime >= 0,
      p.physicalTime <= commander.flightSimulation.physicalTime,
      p.dock.actor.visit <= commander.flightSimulation.visit,
      p.fit.count <= OwnedEquipmentInventory.maximumCount + 1, !p.fit.isEmpty,
      Set(p.fit.map(\.id)).count == p.fit.count,
      p.fit.allSatisfy({ item in
        EquipmentRuntimeCatalog.graph.nodes.contains(where: { $0.id == item.node })
      }),
      p.fit.allSatisfy({ $0.location == nil || $0.location?.hull == p.carrier }),
      NativeGlassMeridian.qualified(visited: p.visited, identified: p.identified, owner: owner),
      Set(p.visited).count == p.visited.count,
      p.visited.allSatisfy({ world.mainStations.contains($0) }),
      p.identified.allSatisfy({
        discovery.entries[$0.ship]?.identification == $0
          && $0.physicalTime <= p.physicalTime && $0.actor.visit <= p.dock.actor.visit
      }),
      mission.milestones
        == (state.reservationCase?.audit != nil
          ? Set([0, 1, 2, 3])
          : state.surveyor?.capture != nil
            ? Set([0, 1, 2]) : state.readings.count == 2 ? Set([0, 1]) : Set([0])),
      Set(mission.ownedEncounters.keys).isSubset(
        of: Set(
          NativeGlassMeridian.encounters
            + (state.surveyor == nil ? [] : [NativeC01Surveyor.encounter])))
    else { return false }
    for sealed in state.readings {
      let r = sealed.reading
      guard r.end <= commander.flightSimulation.physicalTime,
        r.actor.visit <= commander.flightSimulation.visit,
        let current = mission.ownedEncounters[NativeGlassMeridian.encounters[r.ordinal]]?
          .actors[NativeGlassMeridian.targets[r.ordinal]],
        current.identity == r.marker
      else { return false }
    }
    for loss in state.losses {
      guard loss.physicalTime <= commander.flightSimulation.physicalTime,
        let actor = loss.marker.body.physical?.identity,
        actor.visit <= commander.flightSimulation.visit
      else { return false }
    }
    for (ordinal, key) in NativeGlassMeridian.encounters.enumerated() {
      guard let encounter = mission.ownedEncounters[key] else { continue }
      let alias = NativeGlassMeridian.targets[ordinal]
      let generation = state.losses.filter { $0.ordinal == ordinal }.count
      guard encounter.galaxy == 0, encounter.system == 185,
        Set(encounter.actors.keys) == [alias],
        let actor = encounter.actors[alias],
        actor.identity
          == NativeGlassMeridian.actor(
            mission: mission.id, ordinal: ordinal, generation: generation)
      else { return false }
      if let binding = actor.body.physical?.identity,
        state.losses.contains(where: { $0.marker.body.physical?.identity == binding })
      {
        return false
      }
    }
    return true
  }

  /// Bound parent arrays before either the opening or reservation envelope decodes them.
  static func boundedFields(_ value: [String: Any]) -> Bool {
    guard let readings = value["readings"] as? [Any], readings.count <= 2,
      let losses = value["losses"] as? [Any], losses.count <= 128,
      let permission = value["permission"] as? [String: Any],
      let fit = permission["fit"] as? [Any], fit.count <= OwnedEquipmentInventory.maximumCount + 1,
      let visited = permission["visited"] as? [Any],
      visited.count <= NativeMainStationIdentity.maximumCount,
      let identified = permission["identified"] as? [Any], identified.count <= 171
    else { return false }
    return true
  }

  static func validateFields(
    _ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?,
    supportsSurveyor: Bool = false
  )
    throws
  {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      !root.keys.contains("savedGlassMeridian"), !root.keys.contains("glassMeridian")
    else {
      throw SaveError.invalidCommander
    }
    func instances(_ raw: Any?) throws -> [[String: Any]] {
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
        guard let value = $0 as? [String: Any] else { throw SaveError.invalidCommander }
        return value
      }
    }
    func validate(_ object: [String: Any], embedded: Bool) throws {
      for mission in try instances(object["instances"]) {
        let own = mission["definition"] as? String == NativeGlassMeridian.stateID
        let pinned = mission["digest"] as? String == NativeGlassMeridian.digest
        let leaf = mission.keys.contains("savedGlassMeridian")
        guard own == pinned, own == leaf else { throw SaveError.invalidCommander }
        if own {
          guard contains(schema), !embedded,
            let value = mission["savedGlassMeridian"] as? [String: Any],
            boundedFields(value)
          else {
            throw SaveError.invalidCommander
          }
          if value.keys.contains("surveyor"), !supportsSurveyor { throw SaveError.invalidCommander }
          let decoded = try JSONDecoder().decode(
            NativeGlassMeridianState.self,
            from: JSONSerialization.data(withJSONObject: value))
          guard NativeGlassMeridian.readingsValid(decoded),
            NativeGlassMeridian.lossesValid(decoded),
            (value as NSDictionary).isEqual(
              try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
          else {
            throw SaveError.invalidCommander
          }
        }
      }
    }
    if part == .missions { try validate(root, embedded: false) }
    if part == .commander, let embedded = root["savedScriptState"] as? [String: Any] {
      try validate(embedded, embedded: true)
    }
  }
}
