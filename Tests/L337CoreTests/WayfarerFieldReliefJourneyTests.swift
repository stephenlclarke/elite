import Foundation
import Testing

@testable import L337Core

struct WayfarerFieldReliefJourneyTests {
  @Test func onlyTheJoinedInstalledOriginalReleasesPhysicalFitWhileOtherContractsStillReserve()
    async throws
  {
    let f = try WayfarerFieldReliefFixture()
    defer { f.native.files.clean() }
    var runtime = try await f.runtime(stage: .held)
    await runtime.nativeCommand {
      $0.commander.xyzzyActive = true
      $0.commander.unlimitedCargo = true
    }
    let held = await runtime.snapshot().commander
    #expect(held.nativeUtility?.heldTonnes == 4 && held.requiresContractFit)
    #expect(held.tradeCargoCapacity == held.standardCargoCapacity)
    runtime = try await f.native.target(from: runtime)
    let quote = try await runtime.nativeUtilityQuote(.install)
    try await runtime.confirmNativeUtility(quote)
    let installed = await runtime.snapshot().commander
    let state = try f.mission(installed)
    let leaf = try #require(state.savedFieldRelief)
    #expect(state.outcome == .active && state.contract?.settled == false)
    #expect(installed.nativeUtility?.heldTonnes == 0)
    #expect(installed.fieldReliefInstallationNeedsNoHold(state) && !installed.requiresContractFit)
    #expect(installed.tradeCargoCapacity == installed.capacity)
    #expect(installed.capacity > installed.standardCargoCapacity)
    #expect(OriginalServiceReservationPolicy.activeCount(installed.scriptState) == 1)

    // Counterfactual leaf only: never published, and never alters original native property.
    var forgedJob = NativeUtilityConsignment(
      id: leaf.job.id, originalUnits: [UUID(), UUID(), UUID(), UUID()],
      hull: leaf.job.hull, source: leaf.job.source, route: leaf.job.route,
      firstLegReach: leaf.job.firstLegReach, fullTankReach: leaf.job.fullTankReach,
      rewardTenths: leaf.job.rewardTenths)
    forgedJob.phase = .installed
    forgedJob.installation = leaf.job.installation
    var forgedState = state
    forgedState.savedFieldRelief = leaf.replacing(forgedJob)
    var unjoined = installed
    unjoined.scriptState.instances[state.id] = forgedState
    #expect(!unjoined.fieldReliefInstallationNeedsNoHold(forgedState))
    #expect(unjoined.requiresContractFit)
    #expect(unjoined.tradeCargoCapacity == unjoined.standardCargoCapacity)
    #expect(!WayfarerFieldReliefSave.validateClaims(unjoined))
    #expect(unjoined.nativeUtility == installed.nativeUtility)
    #expect(await runtime.snapshot().commander == installed)

    runtime = try await f.native.source(from: runtime)
    let packs = try fieldReliefCapPacks(root: f.native.files.root)
    let other = try #require(packs.first)
    try await runtime.fieldReliefAcceptCapPacks([other])
    let mixed = await runtime.snapshot().commander
    let actual = try f.mission(mixed)
    #expect(mixed.fieldReliefInstallationNeedsNoHold(actual))
    #expect(mixed.requiresContractFit && mixed.tradeCargoCapacity == mixed.standardCargoCapacity)
    #expect(OriginalServiceReservationPolicy.activeCount(mixed.scriptState) == 2)
    #expect(mixed.nativeUtility == installed.nativeUtility)
    #expect(mixed.valid)
  }

  @Test func twoOriginalBatchesPayTheirFrozenQuotesAndKeepOnePermanentClue() async throws {
    let f = try WayfarerFieldReliefFixture()
    defer { f.native.files.clean() }
    var runtime = try await f.native.source()
    let initial = await runtime.snapshot().commander
    var expectedCredits = initial.credits
    var originalSets: [Set<UUID>] = []
    var firstAward: ScriptClueAward?
    for index in 0..<2 {
      if index > 0 { runtime = try await f.native.source(from: runtime) }
      let quote = try await runtime.nativeUtilityQuote(.collect)
      let frozen = 6100 + 1100 * (quote.route.count - 1)
      try #require(quote.rewardTenths == frozen)
      try await runtime.confirmNativeUtility(quote)
      var state = try f.mission(await runtime.snapshot().commander)
      #expect(state.outcome == .active && state.milestones == [0])
      #expect(state.contract?.deadline == nil && state.contract?.offer.deposit == 0)
      #expect(OriginalServiceReservationPolicy.activeCount(
        await runtime.snapshot().commander.scriptState) == 1)
      let originals = try #require(state.savedFieldRelief?.job.originalUnits)
      originalSets.append(Set(originals))
      #expect(await runtime.snapshot().commander.credits == expectedCredits)
      runtime = try await f.native.target(from: runtime)
      let install = try await runtime.nativeUtilityQuote(.install)
      try await runtime.confirmNativeUtility(install)
      state = try f.mission(await runtime.snapshot().commander)
      #expect(state.outcome == .active && state.milestones == [0, 1])
      #expect(state.savedFieldRelief?.job.installation?.socket == index)
      #expect(await runtime.snapshot().commander.credits == expectedCredits)
      #expect(await runtime.snapshot().commander.nativeUtility?.heldTonnes == 0)
      let receive = try await runtime.nativeUtilityQuote(.receive)
      try await runtime.confirmNativeUtility(receive)
      expectedCredits += frozen
      let paid = await runtime.snapshot().commander
      state = try f.mission(paid)
      #expect(state.outcome == .complete && state.milestones == [0, 1, 2])
      #expect(state.contract?.settlementAmount == frozen && paid.credits == expectedCredits)
      #expect(state.savedFieldRelief?.job.originalUnits == originals)
      #expect(state.completionReceipt?.cause?.nativeStation?.receipt == receive.target?.receipt)
      #expect(WayfarerFieldReliefSave.validateClaims(paid, requireRecordedLoss: true))
      let award = try #require(paid.scriptState.savedClueJournal?.awards[WayfarerFieldRelief.stateID])
      if let firstAward { #expect(award == firstAward) } else { firstAward = award }
      #expect(paid.scriptState.savedClueJournal?.awards.count == 1)
      await #expect(throws: (any Error).self) { try await runtime.confirmNativeUtility(receive) }
      #expect(await runtime.snapshot().commander == paid)
      runtime = try await f.native.reloaded(runtime)
    }
    #expect(originalSets.count == 2 && originalSets[0].isDisjoint(with: originalSets[1]))
    #expect(await runtime.snapshot().commander.nativeUtility?.availableMaterials.isEmpty == true)
    await runtime.key("0")
    try await runtime.utilityActualHeadquartersDeath()
    let retained = await runtime.snapshot().commander
    #expect(retained.scriptState.savedClueJournal?.awards[WayfarerFieldRelief.stateID] == firstAward)
    #expect(retained.scriptState.instances.values.filter {
      $0.definition == WayfarerFieldRelief.stateID && $0.outcome == .complete
    }.count == 2)
    _ = try await f.native.reloaded(runtime)
  }

  @Test func boardBackStaleConfirmationAndThreeRealContractsCannotAllocateMoreProperty()
    async throws
  {
    let f = try WayfarerFieldReliefFixture()
    defer { f.native.files.clean() }
    let runtime = try await f.native.source()
    let stale = try await runtime.nativeUtilityQuote(.collect)
    await runtime.key("contracts-open")
    let listed = await runtime.snapshot()
    let index = try #require(listed.contractBoard.rows.firstIndex { $0.utility == .collect })
    for _ in 0..<index { await runtime.key("down") }
    await runtime.key("return")
    let detail = await runtime.snapshot()
    #expect(detail.contractBoard.action == .back)
    let before = detail.commander
    await runtime.key("return")
    #expect(await runtime.snapshot().commander == before)
    await runtime.key("return")
    await runtime.key("right")
    await runtime.key("return")
    let collected = await runtime.snapshot().commander
    #expect(collected.nativeUtility?.heldTonnes == 4)
    await #expect(throws: (any Error).self) { try await runtime.confirmNativeUtility(stale) }
    #expect(await runtime.snapshot().commander == collected)

    let capped = try await f.native.source()
    let packs = try fieldReliefCapPacks(root: f.native.files.root)
    try await capped.fieldReliefAcceptCapPacks(packs)
    let full = await capped.snapshot().commander
    #expect(OriginalServiceReservationPolicy.activeCount(full.scriptState) == 3)
    await #expect(throws: (any Error).self) { _ = try await capped.nativeUtilityQuote(.collect) }
    #expect(await capped.snapshot().commander == full)
    #expect(full.nativeUtility?.consignments.isEmpty == true)
  }

  @Test(arguments: ["collect", "install", "receive"])
  func refusedWriterPreservesNativePropertyMissionCashAndClueTogether(stage: String) async throws {
    let f = try WayfarerFieldReliefFixture()
    defer { f.native.files.clean() }
    var runtime = try await f.native.source()
    let action: NativeUtilityAction
    if stage == "collect" { action = .collect }
    else {
      let collect = try await runtime.nativeUtilityQuote(.collect)
      try await runtime.confirmNativeUtility(collect)
      runtime = try await f.native.target(from: runtime)
      if stage == "receive" {
        let install = try await runtime.nativeUtilityQuote(.install)
        try await runtime.confirmNativeUtility(install)
        action = .receive
      } else { action = .install }
    }
    let quote = try await runtime.nativeUtilityQuote(action)
    let before = await runtime.snapshot().commander
    try await f.native.refusedWrite(runtime, quote: quote, label: "field-relief-" + stage)
    #expect(await runtime.snapshot().commander == before)
    try await runtime.confirmNativeUtility(quote)
    let committed = await runtime.snapshot().commander
    #expect(committed != before && WayfarerFieldReliefSave.validateClaims(
      committed, requireRecordedLoss: true))
    #expect(committed.credits == before.credits + (stage == "receive" ? quote.expected.active!.rewardTenths : 0))
  }

  @Test(arguments: ["held", "installed", "received", "lost"])
  func coldLoadRetainsExactOriginalChainAndTerminalPayment(stage: String) async throws {
    let f = try WayfarerFieldReliefFixture()
    defer { f.native.files.clean() }
    let runtime: GameRuntime
    if stage == "lost" {
      runtime = try await f.native.source(escapeReady: true)
      let collect = try await runtime.nativeUtilityQuote(.collect)
      try await runtime.confirmNativeUtility(collect)
      await runtime.key("0")
      await runtime.key("escape-pod")
    } else {
      runtime = try await f.runtime(stage: stage == "held" ? .held : stage == "installed" ? .installed : .received)
    }
    let before = await runtime.snapshot().commander
    let cold = try await f.native.reloaded(runtime)
    let after = await cold.snapshot().commander
    #expect(after.nativeUtility == before.nativeUtility)
    #expect(after.scriptState.instances == before.scriptState.instances)
    #expect(after.credits == before.credits && after.scriptState.savedClueJournal == before.scriptState.savedClueJournal)
    #expect(WayfarerFieldReliefSave.validateClaims(after, requireRecordedLoss: true))
    if stage == "received" {
      await #expect(throws: (any Error).self) { _ = try await cold.nativeUtilityQuote(.receive) }
      #expect(await cold.snapshot().commander == after)
    }
  }

  @Test(arguments: ["return", "escape", "fatal", "target-held", "target-installed"])
  func actualFailureRetainsOriginalLossAndNeverPaysOrRestocks(cause: String) async throws {
    let f = try WayfarerFieldReliefFixture()
    defer { f.native.files.clean() }
    var runtime = try await f.native.source(escapeReady: true)
    let collect = try await runtime.nativeUtilityQuote(.collect)
    try await runtime.confirmNativeUtility(collect)
    let before = await runtime.snapshot().commander
    if cause == "return" {
      let quote = try await runtime.nativeUtilityQuote(.returnMaterials)
      try await runtime.confirmNativeUtility(quote)
    } else if cause.hasPrefix("target") {
      runtime = try await f.native.target(from: runtime)
      if cause == "target-installed" {
        let quote = try await runtime.nativeUtilityQuote(.install)
        try await runtime.confirmNativeUtility(quote)
      }
      await runtime.key("0")
      let live = await runtime.snapshot()
      let disk = try ScriptFinanceTestFixture.files(f.native.save.deletingLastPathComponent())
      let blocked = try f.native.files.blockWrites("field-relief-target")
      await #expect(throws: (any Error).self) { try await runtime.utilityActualHeadquartersDeath() }
      let refused = await runtime.snapshot()
      #expect(refused.commander == live.commander && refused.bodies == live.bodies)
      try f.native.files.restoreWrites(blocked, files: disk)
      try await runtime.utilityActualHeadquartersDeath()
    } else {
      await runtime.key("0")
      if cause == "escape" { await runtime.key("escape-pod") }
      else {
        try await runtime.utilityActualFatalHit()
        _ = await runtime.advance(delta: 0.1)
      }
    }
    let failed = await runtime.snapshot().commander
    let state = try f.mission(failed)
    #expect(state.outcome == (cause == "return" ? .abandoned : .failed))
    #expect(state.contract?.settlementAmount == 0 && failed.credits == before.credits)
    #expect(failed.scriptState.savedClueJournal == nil)
    #expect(failed.nativeUtility?.availableMaterials.count == 4)
    #expect(failed.nativeUtility?.consignments.first?.originalUnits == before.nativeUtility?.consignments.first?.originalUnits)
    #expect(OriginalServiceReservationPolicy.activeCount(failed.scriptState) == 0)
    _ = try await f.native.reloaded(runtime)
    if cause == "target-held" {
      runtime = try await f.native.source(from: runtime)
      let quote = try await runtime.nativeUtilityQuote(.returnMaterials)
      try await runtime.confirmNativeUtility(quote)
      let returned = try f.mission(await runtime.snapshot().commander)
      #expect(returned.completionReceipt == state.completionReceipt)
      #expect(returned.savedFieldRelief == state.savedFieldRelief)
    }
  }

  @Test(arguments: [false, true])
  func missingOrEditedProductionPackCannotConsumeAnActualEngineerReceipt(edited: Bool) async throws {
    let f = try WayfarerFieldReliefFixture()
    defer { f.native.files.clean() }
    let runtime = try await f.runtime(stage: .installed)
    let quote = try await runtime.nativeUtilityQuote(.receive)
    let before = await runtime.snapshot()
    let original = try #require(before.fieldReliefPack)
    var packs: [ScriptPack] = []
    if edited {
      let folder = f.native.files.root.appendingPathComponent("edited-relief")
      try FileManager.default.copyItem(at: ScriptPackLibrary.bundledFieldReliefDirectory, to: folder)
      let manifest = folder.appendingPathComponent("manifest.toml")
      let text = try String(contentsOf: manifest, encoding: .utf8)
      try (text + "\n# changed production content\n").write(
        to: manifest, atomically: true, encoding: .utf8)
      let changed = try ScriptPackLibrary.read(folder)
      #expect(changed.digest != original.digest)
      packs = [changed]
    }
    await runtime.fieldReliefSetPacks(packs)
    await #expect(throws: (any Error).self) { try await runtime.confirmNativeUtility(quote) }
    #expect(await runtime.snapshot().commander == before.commander)
    await runtime.fieldReliefSetPacks(before.scriptPacks)
    try await runtime.confirmNativeUtility(quote)
    #expect(try f.mission(await runtime.snapshot().commander).outcome == .complete)
  }

  @Test func creditLimitRefusesWholeReceptionThenTheSameOriginalCanSettleOnce() async throws {
    let f = try WayfarerFieldReliefFixture()
    defer { f.native.files.clean() }
    let runtime = try await f.runtime(stage: .installed)
    let quote = try await runtime.nativeUtilityQuote(.receive)
    let reward = try #require(quote.expected.active?.rewardTenths)
    await runtime.nativeCommand { $0.commander.credits = 4_294_967_295 }
    let before = await runtime.snapshot().commander
    await #expect(throws: (any Error).self) { try await runtime.confirmNativeUtility(quote) }
    #expect(await runtime.snapshot().commander == before)
    await runtime.nativeCommand { $0.commander.credits = 4_294_967_295 - reward }
    try await runtime.confirmNativeUtility(quote)
    let after = await runtime.snapshot().commander
    #expect(after.credits == 4_294_967_295)
    #expect(try f.mission(after).contract?.settlementAmount == reward)
    await #expect(throws: (any Error).self) { try await runtime.confirmNativeUtility(quote) }
    #expect(await runtime.snapshot().commander == after)
  }
}

private func fieldReliefCapPacks(root: URL) throws -> [ScriptPack] {
  let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/mission-packs/scripted-contracts")
  return try (0..<3).map { index in
    let folder = root.appendingPathComponent("cap-relief-\(index)")
    try FileManager.default.copyItem(at: example, to: folder)
    let manifest = folder.appendingPathComponent("manifest.toml")
    let text = try String(contentsOf: manifest, encoding: .utf8)
      .replacingOccurrences(of: "example.scripted-contracts", with: "l337.contract")
      .replacingOccurrences(of: "sample-run", with: "relief-cap-\(index)")
      .replacingOccurrences(of: "sample-work", with: "relief-cap-\(index)")
    try text.write(to: manifest, atomically: true, encoding: .utf8)
    return try ScriptPackLibrary.read(folder)
  }
}

extension GameRuntime {
  fileprivate func fieldReliefAcceptCapPacks(_ packs: [ScriptPack]) throws {
    try scriptCommand { game in
      game.scriptPacks += packs
      for pack in packs {
        let key = try game.ensureContractBoard(pack)
        let offer = try #require(game.commander.contracts.boards[key]?.offers.first)
        let quote = game.contractAcceptanceQuote(board: key, offer: offer.id)
        try #require(quote.allowed)
        _ = try game.confirmContract(quote)
      }
    }
  }
  fileprivate func fieldReliefSetPacks(_ packs: [ScriptPack]) { game.scriptPacks = packs }
}
