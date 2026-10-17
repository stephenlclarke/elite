import Foundation
import Testing

@testable import EliteCore

struct NativeRescueTargetingTests {
  @Test func tabActuallySelectsAndAutomaticallyCollectsOneOriginalProtectedPod() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let game = try NativePeopleTestFixture.podApproach()
    let pod = try #require(game.bodies.first { $0.physical?.empCrewPod != nil })
    let person = try #require(pod.physical?.empCrewPod)
    let actor = try #require(pod.physical?.identity)
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    await runtime.key("tab")
    #expect(await runtime.snapshot().workGuidance?.parent == actor)
    #expect(await runtime.snapshot().workGuidance?.mode == .autoScoop(.salvage))
    for _ in 0..<6000 {
      if await runtime.snapshot().commander.rescuedPodTonnes > 0 { break }
      _ = await runtime.advance(delta: 0.05)
    }
    let collected = await runtime.snapshot()
    let admission = try #require(collected.commander.nativePeople?.heldPods.first)
    #expect(admission.person == .emp(person) && admission.actor == actor)
    #expect(
      collected.commander.cargo == game.commander.cargo && collected.commander.rescuedPodTonnes == 1
    )
    #expect(
      collected.commander.accommodation.people.isEmpty
        && collected.commander.accommodation.fitted.isEmpty)
    #expect(!collected.bodies.contains { $0.physical?.empCrewPod == person })
    let record = try #require(collected.commander.savedEMPState?.records[person.source])
    let podIndex = try #require(record.podIndex(for: person.ordinal))
    #expect(record.pods[podIndex].binding == nil)
    #expect(collected.commander.valid)
    for _ in 0..<40 { _ = await runtime.advance(delta: 0.05) }
    #expect(
      await runtime.snapshot().commander.nativePeople?.admissions.filter {
        $0.person == .emp(person)
      }.count == 1)
    #expect(await runtime.snapshot().bodies.contains { $0.physical?.empCrewPod == person } == false)
    var stationGame = await runtime.snapshot()
    try NativePeopleTestFixture.station(&stationGame)
    let receiver = GameRuntime(game: stationGame, saveURL: storage.url)
    try await ScriptFinanceTestFixture.enterMain(receiver)
    let cash = await receiver.snapshot().commander.credits
    try await NativePeopleTestFixture.confirm(receiver, row: .care(.rescuedPod))
    let received = await receiver.snapshot()
    #expect(received.commander.rescuedPodTonnes == 0 && received.commander.nativeCaptiveCount == 0)
    #expect(received.commander.nativePeople?.transfers.last?.members == [.emp(person)])
    #expect(received.commander.nativePeople?.transfers.last?.kind == .care)
    #expect(received.commander.credits == cash && received.commander.valid)
  }

  @Test(arguments: ["module", "scoops", "hold", "core", "foreign"])
  func actualPodColourAndSelectionKeepIndependentHardwareAndCustodyRules(reason: String) throws {
    var game = try NativePeopleTestFixture.podApproach()
    let index = try #require(game.bodies.firstIndex { $0.physical?.empCrewPod != nil })
    if reason == "module" { try game.commander.removeFittedEquipment("Targeting: Salvage Module") }
    if reason == "scoops" { try game.commander.removeFittedEquipment("Fuel Scoops") }
    if reason == "core" {
      try game.commander.removeFittedEquipment(TargetingTier.military.equipmentName)
    }
    if reason == "hold" { game.commander.cargo[0] = game.commander.standardCargoCapacity }
    if reason == "foreign" {
      let original = try #require(game.bodies[index].physical?.empCrewPod)
      game.bodies[index].physical?.empCrewPod = .init(source: original.source, ordinal: 255)
    }
    let body = game.bodies[index]
    let context = try #require(game.gameplayContext())
    let candidate = try #require(
      game.workTargetCandidate(for: body, context: context, frontVisible: true))
    let decision = WorkTargetSelection.evaluate(
      candidate, system: context.system, visit: context.visit,
      capabilities: game.workTargetCapabilities)
    #expect(decision.mode == nil)
    #expect(
      game.targetColourCue(for: body, context: context)
        == (reason == "foreign" ? .ordinary : .recoverable))
    #expect(game.commander.nativePeople == nil && game.commander.cargo[3] == 0)
  }

  @Test func failedAutomaticCollectionPreservesLivePodAndRecoverableController() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = GameRuntime(game: try NativePeopleTestFixture.podApproach(), saveURL: storage.url)
    try await runtime.save(to: storage.url)
    let files = try ScriptFinanceTestFixture.files(storage.directory)
    await runtime.key("tab")
    let parent = try #require(await runtime.snapshot().workGuidance?.parent)
    try storage.blockWriter()
    for _ in 0..<6000 {
      if await runtime.snapshot().message.contains("CAPTURE NOT SAVED") { break }
      _ = await runtime.advance(delta: 0.05)
    }
    let failed = await runtime.snapshot()
    #expect(failed.message.contains("SAVE TO RETRY"))
    #expect(failed.commander.nativePeople == nil)
    #expect(failed.bodies.contains { $0.physical?.identity == parent })
    #expect(failed.workGuidance?.parent == parent)
    #expect(try ScriptFinanceTestFixture.files(storage.backup) == files)
    try storage.restoreWriter()
    try await runtime.save(to: storage.url)
    for _ in 0..<400 {
      if await runtime.snapshot().commander.rescuedPodTonnes > 0 { break }
      _ = await runtime.advance(delta: 0.05)
    }
    #expect(await runtime.snapshot().commander.rescuedPodTonnes == 1)
  }
}
