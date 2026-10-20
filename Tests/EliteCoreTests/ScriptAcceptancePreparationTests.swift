import Foundation
import Testing

@testable import EliteCore

private func acceptancePreparationPack() throws -> ScriptPack {
  let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/mission-packs/scripted-courier")
  return try ScriptPackLibrary.read(directory)
}

struct ScriptAcceptancePreparationTests {
  @Test func deferredAcceptanceRetainsIdentitySeedAndPendingHandlerWithoutIssuingCargo() throws {
    let pack = try acceptancePreparationPack()
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [pack]
    let id = UUID()
    let seed: UInt64 = 0x4d30_3101
    let before = game.commander
    let accepted = try game.acceptScriptMission(
      pack, instanceID: id, randomSeed: seed, drainAccepted: false)
    let instance = try #require(game.commander.scriptState.instances[id])
    #expect(accepted == id && instance.id == id && instance.randomState == seed)
    #expect(instance.outcome == .active && instance.suspension == nil)
    #expect(instance.definition == pack.manifest.stateID && instance.digest == pack.digest)
    #expect(instance.payloads.isEmpty && instance.milestones.isEmpty)
    let pending = game.commander.scriptState.pendingEvents.filter { $0.instance == id }
    try #require(pending.count == 1)
    #expect(pending[0].kind == "mission.accepted" && pending[0].context != nil)
    #expect(game.commander.credits == before.credits && game.commander.cargo == before.cargo)
    #expect(
      game.commander.fuel == before.fuel
        && game.commander.equipmentOwnerID == before.equipmentOwnerID)
  }

  @Test(arguments: ["unavailable", "duplicate-id", "duplicate-definition", "parent-only"])
  func preparationRefusalPublishesNoPartialInstanceOrEvent(condition: String) throws {
    let original = try acceptancePreparationPack()
    var pack = original
    if condition == "unavailable" || condition == "parent-only" {
      var fields = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(original.manifest))
          as? [String: Any])
      if condition == "unavailable" {
        var capabilities = try #require(fields["capabilities"] as? [String])
        capabilities.append("world-actors-v1")
        fields["capabilities"] = capabilities
      } else {
        var mission = try #require(fields["mission"] as? [String: Any])
        mission["parentOnly"] = true
        fields["mission"] = mission
      }
      let manifest = try JSONDecoder().decode(
        ScriptManifest.self,
        from: JSONSerialization.data(withJSONObject: fields))
      // Uninstalled policy inputs exercise refusal; no native acceptance authority is fabricated.
      pack = ScriptPack(
        manifest: manifest, source: original.source,
        manifestBytes: original.manifestBytes, digest: original.digest)
    }
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [pack]
    let initialID = UUID()
    if condition == "duplicate-id" || condition == "duplicate-definition" {
      _ = try game.acceptScriptMission(pack, instanceID: initialID, drainAccepted: false)
    }
    let requested = condition == "duplicate-id" ? initialID : UUID()
    let before = game.commander
    let bodies = game.bodies
    let revision = game.gameplayRevision
    let nextBody = game.nextBodyID
    #expect(throws: MissionPackError.self) {
      try game.acceptScriptMission(pack, instanceID: requested, drainAccepted: false)
    }
    #expect(game.commander == before && game.bodies == bodies)
    #expect(game.gameplayRevision == revision && game.nextBodyID == nextBody)
  }
}
