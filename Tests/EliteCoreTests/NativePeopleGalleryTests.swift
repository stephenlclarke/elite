import Foundation
import Testing

@testable import EliteCore

struct NativePeopleGalleryTests {
  @Test func isolatedNativeTrialUsesRealProducerAndRestartReturnProtectLiveFiles() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var live = Game(executive: false)
    live.screen = .status
    let runtime = GameRuntime(game: live, saveURL: storage.url)
    try await runtime.save(to: storage.url)
    await runtime.key("gallery-open")
    let before = await runtime.snapshot().commander
    let files = try ScriptFinanceTestFixture.files(storage.directory)
    try await runtime.startScriptGalleryTrial(packDigest: NativePeopleGallery.digest, seed: 0)
    let namespace = try #require(await runtime.gallerySaveDirectory())
    defer { try? FileManager.default.removeItem(at: namespace) }
    let initial = await runtime.snapshot()
    #expect(initial.isMissionTrial && initial.trialDigest == NativePeopleGallery.digest)
    #expect(initial.commander.nativePeople == nil && initial.commander.savedEMPState == nil)
    let source = try #require(initial.bodies.first { $0.id == initial.weaponsTargetID })
    #expect(source.physical?.spawnIdentity?.producer == .ambient)
    #expect(source.physical?.npc != nil && source.physical?.empCrewPod == nil)
    #expect(initial.commander.equipmentOwnerID != before.equipmentOwnerID)
    try await runtime.nativePeopleTrialAimAndDisable()
    let collected = await NativePeopleTestFixture.capture(runtime)
    #expect(collected.commander.nativeCaptiveCount == 5)
    #expect(
      collected.commander.nativePeople?.admissions.allSatisfy { $0.origin == .capturedCrew } == true
    )
    #expect(collected.commander.valid)
    await #expect(throws: (any Error).self) { try await runtime.save(to: storage.url) }
    #expect(try ScriptFinanceTestFixture.files(storage.directory) == files)
    try await runtime.restartScriptGalleryTrial()
    #expect(await runtime.snapshot().commander.nativePeople == nil)
    #expect(await runtime.snapshot().commander.savedEMPState == nil)
    try await runtime.returnFromScriptGalleryTrial()
    #expect(await runtime.snapshot().commander == before)
    #expect(try ScriptFinanceTestFixture.files(storage.directory) == files)
  }
}

extension GameRuntime {
  func nativePeopleTrialAimAndDisable() throws {
    let body = try #require(game.bodies.first { $0.id == game.weaponsTargetID })
    let actor = try #require(body.physical?.identity)
    try fitEliteEMPTestEnergy(&game)
    let remaining = try disableNativeEMPActor(actor, game: &game)
    game.selectFlightTool(.salvageCutter)
    while game.workTargetFilter != .salvage { game.key("f") }
    for _ in 0...game.bodies.count {
      game.key("tab")
      if game.workGuidance?.parent == actor { break }
    }
    try #require(game.workGuidance?.parent == actor)
    for _ in 0..<remaining {
      if game.workGuidance?.holding == true { return }
      game.tick(delta: 0.1)
      let actual = try #require(game.bodies.first { $0.physical?.identity == actor })
      let context = try #require(game.gameplayContext())
      try #require(game.nativeCrewCaptureAvailable(actual, context: context))
      try #require(game.screen != .gameOver && !game.docked)
    }
    try #require(
      game.workGuidance?.holding == true,
      "Native cutter approach did not reach the real work surface inside the shared flight budget")
  }
}
