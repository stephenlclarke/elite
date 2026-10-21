import Foundation
import Testing

@testable import EliteCore

struct ScriptFinanceGalleryTests {
  @Test func isolatedTrialBorrowRestartAndReturnNeverTouchLiveDebtOrFiles() async throws {
    let fixture = try ScriptFinanceTestFixture()
    defer { fixture.storage.clean() }
    let runtime = try await fixture.runtime()
    try await ScriptFinanceTestFixture.confirm(runtime)
    await runtime.key("gallery-open")
    let live = await runtime.snapshot().commander
    let liveFiles = try ScriptFinanceTestFixture.files(fixture.storage.directory)
    try await runtime.startScriptGalleryTrial(packDigest: fixture.pack.digest, seed: 123)
    let namespace = try #require(await runtime.gallerySaveDirectory())
    defer { try? FileManager.default.removeItem(at: namespace) }
    let pending = await runtime.snapshot().commander
    #expect(pending.credits == 1000 && pending.scriptState.financeLedger?.receiptCount == 0)
    #expect(pending.scriptState.financeLedger?.owner != live.scriptState.financeLedger?.owner)
    // A trial starts at a Boolean initial dock; it must not fabricate service authority.
    _ = try await ScriptFinanceTestFixture.review(runtime)
    #expect(await runtime.snapshot().contractBoard.financeQuote?.allowed == false)
    await runtime.key("escape")
    await runtime.key("escape")
    await runtime.key("0")
    try #require(await runtime.snapshot().docked == false)
    try await runtime.financeTestApproachMain()
    try await ScriptFinanceTestFixture.enterMain(runtime)
    try await ScriptFinanceTestFixture.confirm(runtime)
    #expect(await runtime.snapshot().commander.credits == 3000)
    #expect(await runtime.snapshot().commander.scriptState.financeLedger?.receiptCount == 1)
    await #expect(throws: (any Error).self) {
      try await runtime.save(to: fixture.storage.url)
    }
    #expect(try ScriptFinanceTestFixture.files(fixture.storage.directory) == liveFiles)
    // The parent trial's restart replaces its own isolated obligations, never the live ledger.
    try await runtime.restartScriptGalleryTrial()
    #expect(await runtime.snapshot().commander.scriptState.financeLedger?.receiptCount == 0)
    try await runtime.returnFromScriptGalleryTrial()
    #expect(await runtime.snapshot().commander == live)
    #expect(try ScriptFinanceTestFixture.files(fixture.storage.directory) == liveFiles)
  }

  @Test func failedTrialWriterKeepsCashLedgerAndLiveNamespaceUntouched() async throws {
    let fixture = try ScriptFinanceTestFixture()
    defer { fixture.storage.clean() }
    let liveRuntime = try await fixture.runtime()
    let liveFiles = try ScriptFinanceTestFixture.files(fixture.storage.directory)
    var trial = await liveRuntime.snapshot()
    trial.isMissionTrial = true
    let runtime = try GameRuntime(trialGame: trial)
    let namespace = try #require(await runtime.gallerySaveDirectory())
    defer { try? FileManager.default.removeItem(at: namespace) }
    let page = try await ScriptFinanceTestFixture.review(runtime)
    await runtime.scriptPageKey("right", expected: page)
    let before = await runtime.snapshot().commander
    let trialFiles = try ScriptFinanceTestFixture.files(namespace)
    let backup = namespace.appendingPathExtension("finance-backup")
    try FileManager.default.moveItem(at: namespace, to: backup)
    defer { try? FileManager.default.removeItem(at: backup) }
    try Data("blocked trial writer".utf8).write(to: namespace)
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    #expect(try ScriptFinanceTestFixture.files(backup) == trialFiles)
    #expect(try ScriptFinanceTestFixture.files(fixture.storage.directory) == liveFiles)
    try FileManager.default.removeItem(at: namespace)
    try FileManager.default.moveItem(at: backup, to: namespace)
  }
}

extension GameRuntime {
  /// Position the physical test approach only; the real swept-entry path must mint the receipt.
  func financeTestApproachMain() throws {
    try ScriptFinanceTestFixture.approachMain(&game)
  }
}
