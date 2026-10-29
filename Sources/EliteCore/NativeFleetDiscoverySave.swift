import Foundation

enum NativeFleetDiscoverySave {
  static let version = 61
  static let alienVersion = 62
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func lowerSchema(_ schema: Int?) -> Int? {
    guard contains(schema) else { return schema }
    return schema == alienVersion
      ? NativeFlightReceptionSave.alienVersion : NativeFlightReceptionSave.version
  }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    commander.scriptState.savedFleetDiscovery != nil
  }

  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    guard let state = commander.scriptState.savedFleetDiscovery else { return true }
    guard state.valid, state.owner == commander.equipmentOwnerID else { return false }
    for entry in state.entries.values {
      for evidence in [entry.encounter, entry.identification, entry.milestone].compactMap({ $0 }) {
        guard evidence.physicalTime <= commander.flightSimulation.physicalTime,
          evidence.actor.visit <= commander.flightSimulation.visit
        else { return false }
        if evidence.actor.visit == commander.flightSimulation.visit,
          evidence.actor.entity >= commander.flightSimulation.nextActor
        {
          return false
        }
        if let dock = evidence.mainDock {
          guard let world = commander.nativeStations, world.mainStations.contains(dock.station),
            dock.sequence < world.nextMainDockSequence
          else { return false }
        }
        if let dock = evidence.secondaryDock {
          guard let world = commander.nativeStations,
            dock.sequence < world.ledger.nextDockSequence,
            world.ledger.records.contains(where: { $0.identity == dock.station })
          else { return false }
        }
      }
    }
    return true
  }

  static func validateFields(
    _ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?
  ) throws {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw SaveError.invalidCommander
    }
    if part == .missions, let raw = root["savedFleetDiscovery"] {
      guard contains(schema), let leaf = raw as? [String: Any],
        let entries = leaf["entries"] as? [String: Any], !entries.isEmpty, entries.count <= 171
      else {
        throw SaveError.invalidCommander
      }
      let decoded = try JSONDecoder().decode(
        NativeFleetDiscovery.self,
        from: JSONSerialization.data(withJSONObject: leaf))
      guard decoded.valid,
        (leaf as NSDictionary).isEqual(
          try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
      else {
        throw SaveError.invalidCommander
      }
    } else if root.keys.contains("savedFleetDiscovery") {
      throw SaveError.invalidCommander
    }
    if part == .commander, let embedded = root["savedScriptState"] as? [String: Any],
      embedded.keys.contains("savedFleetDiscovery")
    {
      throw SaveError.invalidCommander
    }
  }
}
