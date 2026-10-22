import Foundation
import Testing

@testable import EliteCore

struct NativeStationSnapshotUnitTests {
  @Test func exactSnapshotRejectsEveryStoredFieldChangeAndDuplicateOrAbsentBodies() throws {
    let fixture = try NativeStationSnapshotFixture()
    let expected = fixture.body
    let names = [
      "id", "hull", "position", "rotation", "orientation", "rotationRate", "energy", "hostile",
      "navalTarget", "missiles", "playerMissileTarget", "enemyMissile", "missileSourceID",
      "destroyedByPlayer", "missionActorID", "missionInstanceID", "blackjackIdentity",
      "blackjackRole",
      "blackjackLaserCooldown", "scriptNPC", "scriptShot", "ecmEnabled", "physical",
      "nativeStationIdentity",
    ]
    // Adding a stored body field requires extending the exact comparator and this oracle.
    #expect(Set(Mirror(reflecting: expected).children.compactMap(\.label)) == Set(names))
    #expect(NativeStationSnapshot.matches(expected, in: [expected]))
    #expect(!NativeStationSnapshot.matches(expected, in: []))
    #expect(!NativeStationSnapshot.matches(expected, in: [expected, expected]))
    let encoded = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(expected)) as? [String: Any])
    for name in names {
      var changed = encoded
      switch name {
      case "id": changed[name] = 7
      case "hull": changed[name] = Hull.cobra.rawValue
      case "position": changed[name] = ["x": 1, "y": 2, "z": 3]
      case "orientation":
        var basis = try #require(changed[name] as? [String: Any])
        basis["x"] = ["x": 0, "y": 1, "z": 0]
        changed[name] = basis
      case "rotation", "rotationRate", "energy": changed[name] = 17.0
      case "missiles": changed[name] = 9
      case "hostile", "navalTarget", "enemyMissile", "ecmEnabled": changed[name] = true
      default: changed.removeValue(forKey: name)
      }
      let data = try JSONSerialization.data(withJSONObject: changed)
      let actual = try JSONDecoder().decode(SpaceBody.self, from: data)
      #expect(actual != expected, Comment(rawValue: name))
      #expect(!NativeStationSnapshot.matches(expected, in: [actual]), Comment(rawValue: name))
      #expect(!NativeStationSnapshot.matches(actual, in: [expected]), Comment(rawValue: name))
    }
    var unrelated = expected
    unrelated.id = 8
    #expect(NativeStationSnapshot.matches(expected, in: [unrelated, expected]))
  }

  @Test func authenticEntryAttackStillUsesMountedGunPhysicalEvasionAndOneBudget() async throws {
    // Keep the complete existing crash-path assertions through the actor-owned tick.
    try await stationAutoAuthenticEntryAttackUsesMountedGunAndPhysicalEvasionWithOneBudget()
  }
}

private final class NativeStationSnapshotFixture {
  let body: SpaceBody

  init() throws {
    var body = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 0))
    body.playerMissileTarget = 2
    body.missileSourceID = 3
    body.destroyedByPlayer = false
    body.missionActorID = UUID()
    body.missionInstanceID = UUID()
    body.blackjackIdentity = UUID()
    body.blackjackRole = .bolts
    body.blackjackLaserCooldown = 4
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledGlassMeridianDirectory)
    let definition = try #require(pack.manifest.npcs?.first)
    let design = try #require(pack.models[definition.model])
    let hash = ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(design))
    body.scriptNPC = .init(
      fit: .init(definition: definition, models: [definition.model: hash]),
      fuel: 0, guns: [:], components: [:])
    body.scriptShot = .init(
      identity: UUID(), owner: UUID(), instance: UUID(), weapon: "laser", component: nil,
      velocity: .init(0, 0, 1), age: 0, lifetime: 1, damage: 1, radius: 1, collisionDelay: 0)
    body.physical = .init(
      identity: .init(system: .init(galaxy: 0, system: 0), visit: 1, entity: 1),
      population: .mission, npc: nil)
    body.nativeStationIdentity = .init(
      world: UUID(), system: .init(galaxy: 0, system: 0), definition: "rescue_station",
      version: "1.5.4", key: "station")
    self.body = body
  }
}
