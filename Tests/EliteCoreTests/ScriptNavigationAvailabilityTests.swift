import Foundation
import Testing

@testable import EliteCore

private func navigationAvailabilityPack() throws -> ScriptPack {
  let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/mission-packs/l337-navigation-trade")
  return try ScriptPackLibrary.read(directory)
}

struct ScriptNavigationAvailabilityTests {
  @Test(arguments: ["neither", "capability", "source-id"])
  func onlyExistingNavigationClaimsRequireApprovedContent(claim: String) throws {
    let approved = try navigationAvailabilityPack()
    var fields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(approved.manifest)) as? [String: Any])
    if claim != "capability" {
      let capabilities = try #require(fields["capabilities"] as? [String])
      fields["capabilities"] = capabilities.filter { $0 != ScriptNavigationTradeContent.capability }
    }
    if claim != "source-id" {
      fields["id"] = "test.unrelated-availability"
    }
    let manifest = try JSONDecoder().decode(
      ScriptManifest.self,
      from: JSONSerialization.data(withJSONObject: fields))
    // Uninstalled manifest values exercise applicability/refusal only, never content authority.
    let pack = ScriptPack(
      manifest: manifest, source: approved.source,
      manifestBytes: approved.manifestBytes, digest: approved.digest)
    var game = Game(executive: false)
    game.screen = .status
    game.selectedSystem = 6
    game.scriptDurabilityAvailable = false
    let actual = try #require(ScriptNavigationTradeBinding.selectedRoute(in: game))
    let invalid = ScriptNavigationTradeBinding(
      training: actual.training, destination: actual.training)
    try #require(!invalid.valid && !ScriptNavigationTradeContent.matches(pack))
    let expected =
      claim == "neither"
      ? "Choose a commander save before running this mission."
      : "This training requires its exact approved runtime content."
    let before = game.commander
    #expect(game.scriptUnavailable(pack) == expected)
    #expect(game.scriptUnavailable(pack, navigationBinding: invalid) == expected)
    #expect(game.commander == before)
  }

  @Test func approvedNavigationRetainsDefaultExplicitBindingAndRefusalOrder() throws {
    let pack = try navigationAvailabilityPack()
    try #require(ScriptNavigationTradeContent.matches(pack))
    var game = Game(executive: false)
    game.screen = .status
    game.selectedSystem = 6
    game.scriptDurabilityAvailable = true
    let binding = try #require(ScriptNavigationTradeBinding.selectedRoute(in: game))
    #expect(game.scriptUnavailable(pack) == nil)
    #expect(game.scriptUnavailable(pack, navigationBinding: binding) == nil)
    let invalid = ScriptNavigationTradeBinding(
      training: binding.training, destination: binding.training)
    let bindingRefusal =
      "Navigation and trade practice awaits installed original-world endpoint bindings."
    #expect(game.scriptUnavailable(pack, navigationBinding: invalid) == bindingRefusal)
    game.selectedSystem = game.commander.system
    #expect(game.scriptUnavailable(pack) == bindingRefusal)
    #expect(game.scriptUnavailable(pack, navigationBinding: binding) == nil)
    game.scriptDurabilityAvailable = false
    #expect(game.scriptUnavailable(pack) == bindingRefusal)
    #expect(
      game.scriptUnavailable(pack, navigationBinding: binding)
        == "Choose a commander save before running this mission.")
  }
}
