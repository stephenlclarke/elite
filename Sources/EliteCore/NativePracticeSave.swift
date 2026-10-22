import Foundation

enum NativePracticeSave {
  static let version = 121
  static let alienVersion = 122
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }

  static func supportsPractice(_ schema: Int?) -> Bool {
    contains(schema) || schema == 123 || schema == 124 || schema == 125 || schema == 126
  }

  static func publicationVersion(practice: Bool, crewLog: Bool, alien: Bool) -> Int? {
    guard practice else { return nil }
    let own = alien ? alienVersion : version
    let previous =
      alien ? NativeInductionCrewLogSave.alienVersion : NativeInductionCrewLogSave.version
    return crewLog ? max(own, previous) : own
  }

  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    commander.scriptState.instances.values.contains { $0.savedNativePractice != nil }
  }

  static func sceneValid(_ world: ScriptWorldSave, commander: borrowing Commander) -> Bool {
    let flight = commander.flightSimulation
    let practices = commander.scriptState.instances.values.compactMap(\.savedNativePractice)
    for body in world.bodies {
      guard let identity = body.physical?.identity else { continue }
      for practice in practices where practice.beacons.contains(where: { $0.actor == identity }) {
        guard practice.endedAt == nil, practice.permission.player == flight.player,
          practice.beacon(for: body, pose: flight.pose) != nil,
          world.bodies.filter({ $0.physical?.identity == identity }).count == 1
        else { return false }
      }
    }
    return true
  }

  static func validateArchiveFields(
    _ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?, alien: Bool
  ) throws {
    try validateFields(data, part: part, schema: schema)
    let predecessor =
      contains(schema)
      ? (alien ? NativeInductionCrewLogSave.alienVersion : NativeInductionCrewLogSave.version)
      : schema
    try ScriptSaveJSONPreflight.validateRepairLoopFields(data, part: part, schema: predecessor)
  }

  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    let engine = commander.scriptState
    let flight = commander.flightSimulation
    let practices = engine.instances.values.compactMap(\.savedNativePractice)
    guard practices.count <= 128,
      Set(practices.map { $0.permission.operation }).count == practices.count,
      Set(practices.flatMap { $0.beacons.map(\.actor) }).count == practices.count * 3,
      Set(practices.flatMap { $0.beacons.map(\.spawn) }).count == practices.count * 3,
      practices.filter({ $0.endedAt == nil && $0.permission.player == flight.player }).count <= 1
    else { return false }
    for instance in engine.instances.values {
      guard let practice = instance.savedNativePractice else { continue }
      guard
        valid(
          practice, instance: instance, engine: engine,
          owner: commander.equipmentOwnerID, flight: flight)
      else { return false }
    }
    return true
  }

  static func valid(
    _ practice: NativePracticeState, instance: ScriptInstance, engine: ScriptEngineState,
    owner: UUID, flight: FlightSimulationState
  ) -> Bool {
    let permission = practice.permission
    return practice.valid && permission.mission == instance.id
      && permission.owner == owner && permission.lesson.rawValue == instance.definition
      && permission.digest == instance.digest
      && instance.choiceReceipts[NativePracticeSource.consentGroup] == permission.consent
      && permission.consent.valid(for: instance, engine: engine)
      && permission.player.visit <= flight.visit
      && permission.begunAt <= flight.physicalTime
      && (practice.endedAt.map { $0 <= flight.physicalTime } ?? true)
      && practice.beacons.allSatisfy {
        $0.actor.entity < flight.nextActor && $0.spawn.sequence < flight.nextSpawn
      }
      && practice.hits.allSatisfy {
        $0.origin.emissionID < flight.nextEmission && $0.time <= flight.physicalTime
          && ($0.origin.ordnance.map { $0.entity < flight.nextActor } ?? true)
      }
  }

  /// Strict decode/re-encode rejects unknown fields at every depth of the native leaf.
  /// Earlier envelopes and embedded Commander copies cannot silently discard authority.
  static func validateFields(
    _ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?
  ) throws {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      !root.keys.contains("savedNativePractice"), !root.keys.contains("nativePractice")
    else { throw SaveError.invalidCommander }
    switch part {
    case .missions: try validateInstances(root["instances"], schema: schema, embedded: false)
    case .commander:
      if let embedded = root["savedScriptState"] as? [String: Any] {
        try validateInstances(embedded["instances"], schema: schema, embedded: true)
      }
    case .contracts: break
    }
  }

  private static func validateInstances(_ raw: Any?, schema: Int?, embedded: Bool) throws {
    guard let raw else { return }
    let entries: [Any]
    if let dictionary = raw as? [String: Any], dictionary.count <= 128 {
      entries = Array(dictionary.values)
    } else if let pairs = raw as? [Any], pairs.count <= 256, pairs.count.isMultiple(of: 2) {
      entries = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
    } else {
      throw SaveError.invalidCommander
    }
    for entry in entries {
      guard let instance = entry as? [String: Any], !instance.keys.contains("nativePractice") else {
        throw SaveError.invalidCommander
      }
      guard instance.keys.contains("savedNativePractice") else { continue }
      guard supportsPractice(schema), !embedded,
        let leaf = instance["savedNativePractice"] as? [String: Any],
        let beacons = leaf["beacons"] as? [Any], beacons.count == 3,
        let hits = leaf["hits"] as? [Any], hits.count <= 3,
        let source = instance["definition"] as? String,
        NativePracticeLesson(rawValue: source) != nil
      else { throw SaveError.invalidCommander }
      let state = try JSONDecoder().decode(
        NativePracticeState.self, from: JSONSerialization.data(withJSONObject: leaf))
      let canonical = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
      guard state.valid, (leaf as NSDictionary).isEqual(canonical),
        state.permission.lesson.rawValue == source,
        instance["digest"] as? String == state.permission.digest,
        instance["id"] as? String == state.permission.mission.uuidString
      else { throw SaveError.invalidCommander }
    }
  }
}
