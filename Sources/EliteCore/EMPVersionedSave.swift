import Foundation

/// Schema 22 retains electronic disablement and person custody. Older files have neither.
enum EMPVersionedSave {
  enum Part { case commander, world }
  static func rejectFields(_ bytes: Data, part: Part) throws {
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
      throw SaveError.invalidCommander
    }
    func nativeEquipment(_ value: Any?) -> Bool {
      guard let object = value as? [String: Any] else { return false }
      let items = object["items"] as? [[String: Any]] ?? []
      return items.contains { item in
        let node = item["node"] as? [String: Any]
        let location = item["location"] as? [String: Any]
        let slot = location?["slot"] as? [String: Any]
        let utility = slot?["utility"] as? [String: Any]
        return node?["key"] as? String == Equipment.empPirateBlaster
          || utility?["_0"] as? String == "empPirateBlaster"
      }
    }
    func empIncident(_ value: Any) -> Bool {
      if let object = value as? [String: Any] {
        return object["kind"] as? String == "emp" || object.values.contains(where: empIncident)
      }
      if let array = value as? [Any] { return array.contains(where: empIncident) }
      return false
    }
    func trafficTransfer(_ value: Any) -> Bool {
      if let object = value as? [String: Any] {
        return object["terminal"] as? String == "empTransferred"
          || object.values.contains(where: trafficTransfer)
      }
      if let array = value as? [Any] { return array.contains(where: trafficTransfer) }
      return false
    }
    let forbidden: Bool
    switch part {
    case .commander:
      forbidden =
        root.keys.contains("savedEMPState")
        || (root["equipment"] as? [String] ?? []).contains(Equipment.empPirateBlaster)
        || nativeEquipment(root["savedEquipmentInventory"])
        || nativeEquipment(root["ownedEquipment"])
        || root["savedCrimeLedger"].map(empIncident) == true
        || root["savedNPCPersistence"].map(trafficTransfer) == true
    case .world:
      forbidden = (root["bodies"] as? [[String: Any]] ?? []).contains { body in
        guard let physical = body["physical"] as? [String: Any] else { return false }
        return physical.keys.contains("empSource") || physical.keys.contains("empCrewPod")
          || (physical["spawnIdentity"] as? [String: Any])?["producer"] as? String == "emp"
      }
    }
    guard !forbidden else { throw SaveError.invalidCommander }
  }

}

extension EMPState {
  func sceneIsConsistent(_ bodies: [SpaceBody], flight: FlightSimulationState) -> Bool {
    guard valid else { return false }
    let objects = records.values.flatMap { [$0.hull] + $0.pods }
    let bindings = objects.compactMap(\.binding)
    guard Set(bindings).count == bindings.count else { return false }
    for object in objects {
      guard let binding = object.binding else { continue }
      guard binding.system == flight.system, binding.visit == flight.visit,
        binding.entity < flight.nextActor,
        bodies.filter({ $0.physical?.identity == binding }).count == 1,
        var body = bodies.first(where: { $0.physical?.identity == binding })
      else { return false }
      body.position = flight.pose.systemPoint(body.position)
      body.orientation = body.orientation.transformed(by: flight.pose.orientation)
      guard body == object.body else { return false }
    }
    for body in bodies {
      if body.physical?.spawnIdentity?.producer == .emp,
        (body.physical?.empSource == nil) == (body.physical?.empCrewPod == nil)
      {
        return false
      }
      if let source = body.physical?.empSource {
        guard records[source]?.hull.binding == body.physical?.identity else { return false }
      }
      if let person = body.physical?.empCrewPod {
        guard let record = records[person.source], record.pods.indices.contains(person.ordinal),
          record.pods[person.ordinal].binding == body.physical?.identity
        else { return false }
      }
    }
    return true
  }
}
