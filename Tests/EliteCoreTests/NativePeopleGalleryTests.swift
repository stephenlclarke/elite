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
    let world = game.commander.flightSimulation.pose.systemPoint(body.position)
    var pose = ShipPose()
    pose.position = world - Vector3(0, 0, 1000)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 0
    game.screen = .front
    let fireEMPPirateBlasterResult1 = game.fireEMPPirateBlaster()
    try #require(fireEMPPirateBlasterResult1)
    try NativePeopleTestFixture.aimCutter(&game)
  }
}
