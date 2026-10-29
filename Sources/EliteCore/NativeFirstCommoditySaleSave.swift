import Foundation

enum NativeFirstCommoditySaleSave {
  static let version = 65
  static let alienVersion = 66
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func lowerSchema(_ schema: Int?) -> Int? {
    guard contains(schema) else { return schema }
    return schema == alienVersion
      ? NativeGlassMeridianSave.alienVersion : NativeGlassMeridianSave.version
  }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    commander.scriptState.firstNativeCommoditySale != nil
  }

  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    guard let evidence = commander.scriptState.firstNativeCommoditySale else { return true }
    guard evidence.valid, evidence.owner == commander.equipmentOwnerID,
      let world = commander.nativeStations,
      world.mainStations.contains(evidence.dock.station),
      evidence.dock.sequence < world.nextMainDockSequence,
      evidence.dock.actor.visit <= commander.flightSimulation.visit,
      evidence.physicalTime <= commander.flightSimulation.physicalTime,
      evidence.calendarOperation <= (commander.scriptState.calendarLedger?.operation ?? 0)
    else { return false }
    return true
  }

  static func validateFields(
    _ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?
  ) throws {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw SaveError.invalidCommander
    }
    if let raw = root["firstNativeCommoditySale"] {
      guard part == .missions, contains(schema), let leaf = raw as? [String: Any] else {
        throw SaveError.invalidCommander
      }
      let decoded = try JSONDecoder().decode(
        NativeFirstCommoditySale.self, from: JSONSerialization.data(withJSONObject: leaf))
      guard decoded.valid,
        (leaf as NSDictionary).isEqual(
          try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
      else { throw SaveError.invalidCommander }
    }
    if part == .commander, let embedded = root["savedScriptState"] as? [String: Any],
      embedded.keys.contains("firstNativeCommoditySale")
    {
      throw SaveError.invalidCommander
    }
  }
}
