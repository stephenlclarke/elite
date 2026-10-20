import Foundation
import Testing

@testable import EliteCore

struct NativePeopleStationTests {
  @Test func actualNamedSaleTransfersExactlyOneOriginalPersonAndOneMarketUnit() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await NativePeopleTestFixture.capturedRuntime(storage: storage)
    let before = await runtime.snapshot()
    let person = try #require(before.commander.nativePeople?.heldCaptives.first?.person)
    let identity = try #require(person.emp)
    let source = identity.source
    let captures = before.commander.savedEMPState?.records[source]?.crewCaptures
    let page = try await NativePeopleTestFixture.review(runtime, row: .sale(person))
    #expect(await runtime.snapshot().contractBoard.action == .back)
    #expect(await runtime.snapshot().contractBoard.peopleQuote?.members == [person])
    await runtime.scriptPageKey("right", expected: page)
    await runtime.scriptPageKey("return", expected: page)
    let after = await runtime.snapshot()
    let receipt = try #require(after.commander.nativePeople?.transfers.last)
    #expect(receipt.kind == .sale && receipt.members == [person] && receipt.dock != nil)
    #expect(after.commander.nativeCaptiveCount == 1 && after.commander.cargo[3] == 1)
    #expect(after.commander.credits == before.commander.credits + before.market[3].price)
    #expect(after.market[3].quantity == before.market[3].quantity + 1)
    #expect(after.commander.savedEMPState?.records[source]?.crewCaptures == captures)
    #expect(after.commander.valid)
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander.nativePeople?.transfers.count == 1)
  }

  @Test func actualCareClosesCustodyWithoutRewardAndHistoryRemainsReadableWithoutAuthority()
    async throws
  {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await NativePeopleTestFixture.capturedRuntime(storage: storage)
    let before = await runtime.snapshot().commander
    try await NativePeopleTestFixture.confirm(runtime, row: .care(.capturedCrew))
    let after = await runtime.snapshot()
    let receipt = try #require(after.commander.nativePeople?.transfers.last)
    #expect(receipt.kind == .care && receipt.members.count == 2)
    #expect(after.commander.nativeCaptiveCount == 0 && after.commander.cargo[3] == 0)
    #expect(after.commander.credits == before.credits && after.commander.kills == before.kills)
    #expect(after.commander.nativePeople?.admissions == before.nativePeople?.admissions)
    var readOnly = after
    readOnly.invalidateNativeStationAuthority()
    readOnly.scriptDurabilityAvailable = false
    #expect(readOnly.nativePeopleQuote(.history(receipt.operation)).issues.isEmpty)
    #expect(readOnly.nativePeopleQuote(.care(.capturedCrew)).allowed == false)
    let reader = GameRuntime(game: readOnly)
    _ = try await NativePeopleTestFixture.review(reader, row: .history(receipt.operation))
    #expect(
      await reader.snapshot().nativePeopleDetail.contains {
        $0.contains("permanent station population")
      })
  }

  @Test func failedActualTransferWriterPreservesPeopleMoneyMarketAndPriorFiles() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await NativePeopleTestFixture.capturedRuntime(storage: storage)
    let person = try #require(
      await runtime.snapshot().commander.nativePeople?.heldCaptives.first?.person)
    let page = try await NativePeopleTestFixture.review(runtime, row: .sale(person))
    await runtime.scriptPageKey("right", expected: page)
    let before = await runtime.snapshot()
    let files = try ScriptFinanceTestFixture.files(storage.directory)
    try storage.blockWriter()
    await runtime.scriptPageKey("return", expected: page)
    let failed = await runtime.snapshot()
    #expect(failed.commander == before.commander && failed.market == before.market)
    #expect(try ScriptFinanceTestFixture.files(storage.backup) == files)
    try storage.restoreWriter()
    try await NativePeopleTestFixture.confirm(runtime, row: .sale(person))
    #expect(await runtime.snapshot().commander.nativePeople?.transfers.count == 1)
  }

  @Test func stalePaintedPageCannotTransferAfterMarketChanges() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await NativePeopleTestFixture.capturedRuntime(storage: storage)
    let person = try #require(
      await runtime.snapshot().commander.nativePeople?.heldCaptives.first?.person)
    let page = try await NativePeopleTestFixture.review(runtime, row: .sale(person))
    await runtime.scriptPageKey("right", expected: page)
    var game = await runtime.snapshot()
    game.market[3].price += 1
    let changed = GameRuntime(game: game, saveURL: storage.url)
    let before = await changed.snapshot().commander
    await changed.scriptPageKey("return", expected: page)
    #expect(await changed.snapshot().commander == before)
    #expect(await changed.snapshot().commander.nativePeople?.transfers.isEmpty == true)
  }
}
