import Foundation
import Testing

@testable import EliteCore

@Test func typedUnaffordableFoodPledgeRefreshesTrialBoardWithoutChangingProperty() async throws {
  let fixture = try PledgeFixture()
  defer { fixture.clean() }
  var live = fixture.game(cash: 100000, food: 0)
  live.commander.name = "PLEDGE REFUSAL"
  try #require(live.commander.valid)
  let runtime = GameRuntime(game: live, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  let liveCommander = await runtime.snapshot().commander
  let liveBytes = try Data(contentsOf: fixture.save)

  await runtime.key("gallery-open")
  try await runtime.startScriptGalleryTrial(packDigest: fixture.pack.digest)
  let namespaceValue = await runtime.gallerySaveDirectory()
  let namespace = try #require(namespaceValue)
  defer { try? FileManager.default.removeItem(at: namespace) }
  await runtime.key("screen:7")
  let market = await runtime.snapshot()
  #expect(market.isMissionTrial && market.docked && market.screen == .buy)
  #expect(market.commander.cargo[Game.pledgeFood] == 0)

  await runtime.key("contracts-open")
  let board = await runtime.snapshot()
  #expect(board.screen == .contracts && !board.contractBoard.detail)
  // Funded credit offers exercise actual acceptance simulation during the error refresh.
  let creditRows = board.contractBoard.rows.filter { $0.offer?.key.hasPrefix("credits-") == true }
  #expect(creditRows.count == 3 && creditRows.allSatisfy { $0.reason == nil })
  let target = try #require(board.contractBoard.rows.firstIndex { $0.offer?.key == "food-3" })
  let delta = target - board.contractBoard.selection
  for _ in 0..<abs(delta) {
    let painted = await runtime.snapshot().scriptPagePresentation
    await runtime.scriptPageKey(delta > 0 ? "down" : "up", expected: painted)
  }
  let selected = await runtime.snapshot()
  #expect(selected.contractBoard.selected?.offer?.key == "food-3")
  await runtime.scriptPageKey("return", expected: selected.scriptPagePresentation)
  let detail = await runtime.snapshot()
  #expect(detail.contractBoard.detail && detail.contractBoard.action == .back)
  #expect(detail.contractBoard.quote?.allowed == false)
  #expect(detail.contractBoard.quote?.pledge?.variant == .food)
  #expect(detail.contractBoard.quote?.pledge?.amount == 5)
  await runtime.scriptPageKey("right", expected: detail.scriptPagePresentation)
  let accepting = await runtime.snapshot()
  #expect(accepting.contractBoard.action == .accept)
  #expect(accepting.commander.cargo[Game.pledgeFood] == 0)
  #expect(accepting.commander.scriptState.instances.isEmpty)
  #expect(accepting.commander.scriptState.pledgeLedger == nil)
  let oldPainted = accepting.scriptPagePresentation

  await runtime.scriptPageKey("return", expected: oldPainted)
  let refreshed = await runtime.snapshot()
  #expect(refreshed.screen == .contracts && !refreshed.contractBoard.detail)
  #expect(refreshed.contractBoard.quote == nil)
  #expect(refreshed.message.contains("Review the offer again"))
  #expect(refreshed.commander == accepting.commander)
  #expect(refreshed.commander.credits == accepting.commander.credits)
  #expect(refreshed.commander.cargo[Game.pledgeFood] == 0)
  #expect(refreshed.commander.scriptState.instances.isEmpty)
  #expect(refreshed.commander.scriptState.pledgeLedger == nil)
  #expect(refreshed.contractBoard.selected?.offer?.key == "food-3")
  #expect(refreshed.contractBoard.selected?.offer?.status == .available)
  let refreshedCredits = refreshed.contractBoard.rows.filter {
    $0.offer?.key.hasPrefix("credits-") == true
  }
  #expect(refreshedCredits.count == 3 && refreshedCredits.allSatisfy { $0.reason == nil })
  let freshPainted = refreshed.scriptPagePresentation
  #expect(freshPainted.valid && freshPainted != oldPainted)
  let bytesAfterRefusal = try Data(contentsOf: fixture.save)
  #expect(bytesAfterRefusal == liveBytes)

  await runtime.scriptPageKey("return", expected: oldPainted)
  let stale = await runtime.snapshot()
  #expect(stale.message == "CONTACT CHANGED - REVIEW THE CURRENT PAGE")
  #expect(stale.commander == refreshed.commander)
  #expect(stale.screen == .contracts && !stale.contractBoard.detail)
  #expect(stale.scriptPagePresentation == freshPainted)
  await runtime.scriptPageKey("return", expected: freshPainted)
  let reviewed = await runtime.snapshot()
  #expect(reviewed.contractBoard.detail && reviewed.contractBoard.action == .back)
  #expect(reviewed.contractBoard.selected?.offer?.key == "food-3")
  #expect(reviewed.contractBoard.quote?.allowed == false)
  #expect(reviewed.commander == accepting.commander)

  try await runtime.returnFromScriptGalleryTrial()
  let returned = await runtime.snapshot()
  #expect(!returned.isMissionTrial && returned.commander == liveCommander)
  let returnedBytes = try Data(contentsOf: fixture.save)
  #expect(returnedBytes == liveBytes)
}
