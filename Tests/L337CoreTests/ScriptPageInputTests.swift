import Foundation
import Testing

@testable import L337Core

@Test func nativeDisplayedLegacyOfferAcceptsOnceAndRejectsAnEarlierPageAfterTransition()
  async throws
{
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
      "docs/mission-packs/courier.toml")
  let entry = try MissionPackLibrary.read(example)
  var game = Game(executive: false)
  game.screen = .status
  game.missionPacks = try MissionPackLibrary.checked(MissionPackLibrary.bundled.entries + [entry])
  let runtime = GameRuntime(game: game, saveURL: root.appendingPathComponent("commander.json"))
  await runtime.key("contacts-open")
  let offered = await runtime.snapshot()
  let page = offered.scriptPagePresentation
  guard case .legacy(let legacy) = page.page else {
    Issue.record("The native courier contact did not expose its legacy page identity.")
    return
  }
  #expect(legacy.stateID == entry.pack.stateID && legacy.digest == entry.digest && page.valid)
  await runtime.scriptPageKey("return", expected: page)
  let accepted = await runtime.snapshot()
  #expect(accepted.commander.missionProgress[entry.pack.stateID]?.payloads["parcel"] == 1)
  await runtime.scriptPageKey("return", expected: page)
  #expect(await runtime.snapshot().commander == accepted.commander)
}

@Test func invalidQuestionOrLegacyProofAndForeignEpochCannotRunNativeInput() async throws {
  let runtime = GameRuntime(game: Game(executive: false))
  let before = await runtime.snapshot()
  let epoch = before.ecmControl.epoch
  let question = ScriptQuestionIdentity(
    instance: UUID(), dialogue: "decision", token: "current", revision: 1)
  let invalid = [
    ScriptPagePresentation(epoch: UUID(), page: nil),
    .init(epoch: epoch, page: .question(question)),
    .init(
      epoch: epoch,
      page: .question(.init(instance: UUID(), dialogue: "bad/id", token: "t", revision: 1))),
    .init(
      epoch: epoch,
      page: .question(.init(instance: UUID(), dialogue: "decision", token: "", revision: 1))),
    .init(
      epoch: epoch,
      page: .question(
        .init(
          instance: UUID(), dialogue: "decision", token: String(repeating: "x", count: 257),
          revision: 1))),
    .init(
      epoch: epoch,
      page: .question(
        .init(instance: UUID(), dialogue: "decision", token: "t", revision: UInt64.max))),
    .init(epoch: epoch, page: .offer("not-a-digest")),
    .init(
      epoch: epoch,
      page: .legacy(
        .init(
          stateID: "missing", transitionID: "accept", digest: String(repeating: "a", count: 64),
          galaxy: 0, system: 7, committed: false))),
  ]
  for proof in invalid {
    await runtime.scriptPageKey("return", expected: proof)
    await runtime.scriptPageClick(x: 40, y: 478, expected: proof)
    let refused = await runtime.snapshot()
    #expect(
      refused.commander == before.commander && refused.screen == before.screen
        && refused.bodies == before.bodies && refused.docked == before.docked)
  }
  await runtime.scriptPageKey("launch", expected: before.scriptPagePresentation)
  #expect(await runtime.snapshot().docked == before.docked)
  await runtime.scriptPageClick(x: .infinity, y: 478, expected: before.scriptPagePresentation)
  #expect(await runtime.snapshot().commander == before.commander)
}
