import Foundation
import Testing

@testable import EliteCore

struct MissionRuntimeNativeCompatibilityTests {
  @Test func activeNativeTrialSaveUsesItsPrivateWriterAndCannotOverwriteTheLiveCommander()
    async throws
  {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let live = folder.appendingPathComponent("live.json")
    let original = Data("original live commander".utf8)
    try original.write(to: live)
    var game = Game(executive: false)
    game.isMissionTrial = true
    let runtime = GameRuntime(game: game, saveURL: live)
    let namespace = try #require(await runtime.gallerySaveDirectory())
    defer { try? FileManager.default.removeItem(at: namespace) }
    let receipt = try await runtime.commanderFileOperationForInterface(
      .save(live), activePath: true)
    #expect(receipt.isTrial && receipt.url.deletingLastPathComponent() == namespace)
    #expect(try Data(contentsOf: live) == original)
    let trialBytes = try Data(contentsOf: receipt.url)
    var refused = false
    do {
      _ = try await runtime.commanderFileOperationForInterface(.save(live), activePath: false)
    } catch { refused = true }
    let afterLive = try Data(contentsOf: live)
    #expect(refused && afterLive == original)
    #expect(try Data(contentsOf: receipt.url) == trialBytes)
  }

  @Test func ordinaryActorInitFlightAndSaveKeepTheExistingDirectCommanderJSONContract() async throws
  {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("commander.json")
    var game = Game(executive: false)
    game.screen = .status
    let runtime = GameRuntime(game: game)
    let initial = await runtime.snapshot()
    #expect(initial.commander.scriptState == ScriptEngineState())
    await runtime.key("0")
    _ = await runtime.advance(delta: 0.1)
    let flying = await runtime.snapshot()
    #expect(flying.commander.scriptState == ScriptEngineState())
    #expect(!flying.requiresScriptDurability)
    try await runtime.save(to: url)
    let data = try Data(contentsOf: url)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object["schemaVersion"] == nil && object["savedScriptState"] == nil)
    let commander = try JSONDecoder().decode(Commander.self, from: data)
    #expect(commander.valid && commander.savedEquipmentVersion == 2)
    #expect(commander.equipmentOwnerID == initial.commander.equipmentOwnerID)
  }

  @Test func anExistingEmptyMissionCalendarStillUsesVersionedStorageAndRoundTrips() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("commander.json")
    var game = Game(executive: false)
    game.screen = .status
    game.commander.scriptState.calendarLedger = .init(origin: .newCommander)
    let runtime = GameRuntime(game: game)
    let initial = await runtime.snapshot()
    #expect(initial.requiresScriptDurability)
    _ = await runtime.advance(delta: 0.1)
    let advanced = await runtime.snapshot()
    #expect(advanced.commander.scriptState.calendarSeconds == 0.1)
    try await runtime.save(to: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: url))
    #expect(pointer.schemaVersion == 21)
    try await runtime.load(from: url)
    let restored = await runtime.snapshot()
    #expect(restored.commander.scriptState == advanced.commander.scriptState)
    #expect(restored.commander.equipmentInventory == advanced.commander.equipmentInventory)
    #expect(restored.commander.valid)
  }

  @Test func failedMissionPublicationRollsBackAnActualTypedNativeMissilePurchase() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    var game = Game(executive: false)
    game.commander.missiles = 0
    game.commander.credits = 100000
    game.commander.scriptState.calendarLedger = .init(origin: .newCommander)
    game.screen = .equipment
    game.selection = try #require(Equipment.all.firstIndex { $0.name == "Missile" })
    let runtime = GameRuntime(game: game, saveURL: directory)
    let before = await runtime.snapshot()
    let context = try #require(before.equipmentPurchaseContext)
    let result = await runtime.equipmentTransaction(.purchase(context))
    let after = await runtime.snapshot()
    #expect(result == .refused(.invalidState))
    #expect(after.commander == before.commander && after.bodies == before.bodies)
    #expect(after.inventoryContextEpoch == before.inventoryContextEpoch)
    #expect(after.commander.missiles == 0)
  }

  @Test func failedFileLoadKeepsTheActiveMissionWriterAndAllExistingState() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let active = folder.appendingPathComponent("active.json")
    let invalid = folder.appendingPathComponent("invalid.json")
    try Data("{}".utf8).write(to: invalid)
    let runtime = GameRuntime(saveURL: active)
    let before = await runtime.snapshot()
    var refused = false
    do { try await runtime.load(from: invalid) } catch { refused = true }
    let after = await runtime.snapshot()
    let writer = await runtime.scriptSaveURL
    #expect(refused && writer == active)
    #expect(after.commander == before.commander && after.bodies == before.bodies)
    #expect(after.inventoryContextEpoch == before.inventoryContextEpoch)
  }
}
