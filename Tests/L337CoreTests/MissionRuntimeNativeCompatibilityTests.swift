import Foundation
import Testing

@testable import L337Core

struct MissionRuntimeNativeCompatibilityTests {
  @Test func theActualRuntimePausesNativeFlightAndCountdownWhileTheLibraryIsOpen() async throws {
    var game = Game(executive: false)
    game.screen = .status
    game.commander.scriptState.calendarLedger = .init(origin: .newCommander)
    game.launch()
    game.bodies = []
    game.celestials = []
    game.selectedSystem = try #require(
      game.systems.first {
        $0.id != game.commander.system && game.currentSystem.distance(to: $0) <= 7
          && game.currentSystem.distance(to: $0) >= 1
      }?.id)
    game.beginHyperspace()
    try #require(game.jumpCountdown != nil)
    let runtime = GameRuntime(game: game)
    var controls = Controls()
    controls.pitch = 0.4
    controls.throttle = 0.8
    await runtime.setControls(controls)
    await runtime.key("library-open")
    let opened = await runtime.snapshot()
    try #require(opened.screen == .library)
    for _ in 0..<5 { _ = await runtime.advance(delta: 0.1) }
    let reading = await runtime.snapshot()
    #expect(reading.commander.flightSimulation == opened.commander.flightSimulation)
    #expect(reading.bodies == opened.bodies && reading.celestials == opened.celestials)
    #expect(reading.time == opened.time && reading.jumpCountdown == opened.jumpCountdown)
    #expect(reading.commander.scriptState == opened.commander.scriptState)
    await runtime.key("escape")
    let closed = await runtime.snapshot()
    try #require(closed.screen == .front)
    _ = await runtime.advance(delta: 0.1)
    let resumed = await runtime.snapshot()
    #expect(resumed.time > closed.time)
    #expect(
      resumed.commander.flightSimulation.physicalTime
        > closed.commander.flightSimulation.physicalTime)
    let remaining = try #require(resumed.jumpCountdown)
    let previous = try #require(closed.jumpCountdown)
    #expect(remaining < previous)
  }

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
    let proposedNamespace = await runtime.gallerySaveDirectory()
    let namespace = try #require(proposedNamespace)
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

  @Test func ordinaryActorInitDefersDurabilityUntilFirstVersionedSave() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("commander.json")
    var game = Game(executive: false)
    game.screen = .status
    let runtime = GameRuntime(game: game)
    let initial = await runtime.snapshot()
    #expect(initial.commander.scriptState == ScriptEngineState())
    #expect(initial.commander.nativeStations == nil && !initial.requiresScriptDurability)
    try await runtime.save(to: url)
    let ordinaryData = try Data(contentsOf: url)
    let firstPointer = try JSONDecoder().decode(ScriptSavePointer.self, from: ordinaryData)
    #expect(firstPointer.schemaVersion == 26 && firstPointer.scope == "commander")
    let (ordinary, _) = try ScriptSaveStore.read(ordinaryData, from: url)
    #expect(ordinary.valid && ordinary.savedEquipmentVersion == 3)
    #expect(ordinary.usesModularDriveSaveVersion && ordinary.usesEconomyMiningSaveVersion)
    #expect(ordinary.scriptState.instances.isEmpty && ordinary.nativeStations == nil)
    #expect(ordinary.equipmentOwnerID == initial.commander.equipmentOwnerID)
    await runtime.key("0")
    _ = await runtime.advance(delta: 0.1)
    let flying = await runtime.snapshot()
    #expect(flying.commander.nativeStations != nil && flying.requiresScriptDurability)
    let calendar = try #require(flying.commander.scriptState.calendarLedger)
    #expect(calendar.origin == .newCommander && calendar.operation == 1)
    #expect(calendar.lastAdjustment?.kind == .launch)
    #expect(flying.commander.scriptState.calendarSeconds == 600.1)
    #expect(flying.commander.scriptState.missionCalendar == nil)
    #expect(flying.commander.scriptState.instances.isEmpty)
    try await runtime.save(to: url)
    let data = try Data(contentsOf: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: data)
    #expect(pointer.schemaVersion == 26 && pointer.scope == "commander")
    let (commander, _) = try ScriptSaveStore.read(data, from: url)
    #expect(commander.valid && commander.savedEquipmentVersion == 3)
    #expect(commander.equipmentOwnerID == initial.commander.equipmentOwnerID)
    let committed = await runtime.snapshot()
    #expect(commander.scriptState == committed.commander.scriptState)
    #expect(commander.nativeStations == committed.commander.nativeStations)
    #expect(commander.equipmentInventory == committed.commander.equipmentInventory)
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
    let bytes = try Data(contentsOf: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == 26)
    let (strictSaved, strictWorld) = try ScriptSaveStore.read(bytes, from: url)
    #expect(strictSaved.valid && strictWorld.valid && strictWorld.consistent(with: strictSaved))
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
