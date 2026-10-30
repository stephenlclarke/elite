import Foundation
import Testing

@testable import L337Core

struct OriginalStationRegistryTests {
  @Test(arguments: [0, 7, 237])
  func actualOriginalWorldLaunchUsesTheCompleteInstalledStationInventory(system: Int) throws {
    var game = Game(executive: false)
    game.screen = .status
    game.commander.system = system
    game.selectedSystem = system
    try game.commander.prepareEquipment(legacy: false)
    try #require(game.commander.valid)
    game.launch()
    try #require(!game.docked, Comment(rawValue: game.message))
    #expect(game.commander.valid && game.screen == .front)
    let world = try #require(game.commander.nativeStations)
    #expect(NativeStationSource.bindings.count == 382)
    #expect(world.ledger.records.count == NativeStationSource.bindings.count)
    #expect(world.ledger.records.count <= NativeStationLedger.maximumSourceRecords)
    #expect(
      world.ledger.records.allSatisfy {
        NativeStationSource.authentic($0, owner: world.ledger.world)
      })
    let restored = try JSONDecoder().decode(
      NativeStationWorld.self,
      from: JSONEncoder().encode(world))
    #expect(restored == world && restored.valid)
  }

  @Test(arguments: ["missing", "duplicate"])
  func installedSourceInventoryCannotBeDroppedOrDuplicatedByACurrentSave(condition: String) throws {
    let world = try NativeStationWorld(owner: UUID())
    var root = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(world))
        as? [String: Any])
    var ledger = try #require(root["ledger"] as? [String: Any])
    var records = try #require(ledger["records"] as? [[String: Any]])
    if condition == "missing" {
      records.removeLast()
    } else {
      records[records.count - 1] = records[0]
    }
    ledger["records"] = records
    root["ledger"] = ledger
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(
        NativeStationWorld.self,
        from: JSONSerialization.data(withJSONObject: root))
    }
  }
}
