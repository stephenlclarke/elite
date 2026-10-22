import Foundation
import Testing

@testable import EliteCore

struct NativeIsolationContractUnitTests {
  @Test func unpaidSameDockReturnRemovesOnlyOriginalAndReleasesSlotWithoutCashOrClue() async throws
  {
    let fixture = try await IsolationWorkFixture()
    let before = fixture.game.commander
    let source = try fixture.state()
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    let runtime = GameRuntime(game: fixture.game)
    _ = try await runtime.registerNewCommanderDestination(at: files.save)
    try await runtime.scriptCommand { candidate in
      try candidate.confirmIsolationWorkParent(candidate.isolationWorkParentReview(.returnUnpaid))
    }
    let ended = await runtime.snapshot()
    let parent = try #require(ended.isolationWorkParentMission)
    #expect(parent.outcome == .abandoned && parent.contract?.settlementAmount == 0)
    #expect(
      ended.commander.credits == before.credits
        && ended.commander.cargoTonnes == before.cargoTonnes - 1)
    #expect(ended.commander.scriptState.savedClueJournal == nil)
    #expect(ended.isolationWorkChild?.savedIsolationWork == source)
    #expect(OriginalServiceReservationPolicy.activeCount(ended.commander.scriptState) == 0)
    #expect(NativeIsolationProgrammerCustody.hasIssuedOriginal(in: ended.commander))
    #expect(!ended.isolationWorkParentReview(.accept).allowed)
    let bytes = try Data(contentsOf: files.save)
    let (cold, _) = try ScriptSaveStore.read(bytes, from: files.save)
    #expect(NativeIsolationContractSave.validateClaims(cold))
    #expect(cold.scriptState.instances[parent.id]?.completionReceipt == parent.completionReceipt)
  }

  @Test func awayAbandonRetainsLoanAndActualPassiveSourceFlowThenAllowsUnpaidPropertyReturn()
    async throws
  {
    let fixture = try await IsolationWorkFixture()
    try fixture.admit()
    let source = try fixture.state()
    let before = fixture.game.commander
    try fixture.game.abandonIsolationWork()
    #expect(fixture.game.commander.credits == before.credits)
    #expect(fixture.game.commander.cargoTonnes == before.cargoTonnes)
    #expect(fixture.game.currentIsolationWorkParentAuthority == nil)
    #expect(OriginalServiceReservationPolicy.activeCount(fixture.game.commander.scriptState) == 0)
    try fixture.tick()
    let continued = try fixture.state()
    #expect(
      continued.source == source.source
        && continued.modules.allSatisfy { $0.accounts.deliveredLoad > 0 })
    #expect(continued.modules.allSatisfy { $0.history.segments.isEmpty && $0.opening == nil })
    #expect(NativeIsolationContractSave.validateClaims(fixture.game.commander))

    // An explicit unpaid ending at the issuer may also leave the original held until a later
    // property-return action; that return must not settle the contract twice.
    let issuer = try await IsolationWorkFixture()
    try issuer.game.abandonIsolationWork()
    let ended = try #require(
      issuer.game.isolationWorkParentMission?.savedIsolationWorkParent?.terminal)
    let dock = try #require(issuer.game.commander.nativeStations?.currentMainDock)
    let arrival = try #require(issuer.game.nativeMainStationArrivalContext(for: dock.station))
    let cash = issuer.game.commander.credits
    try issuer.game.returnIsolationProgrammerUnpaid(at: arrival)
    #expect(issuer.game.commander.credits == cash)
    #expect(issuer.game.isolationWorkParentMission?.savedIsolationWorkParent?.terminal == ended)
    #expect(NativeIsolationContractSave.validateClaims(issuer.game.commander))
    #expect(issuer.game.commander.valid)
  }

  @Test func staleNativeReviewAndActualWriterRefusalCannotReturnOriginalOrCloseJob() async throws {
    let stale = try await IsolationWorkFixture()
    let quote = stale.game.isolationWorkParentReview(.returnUnpaid)
    #expect(quote.allowed)
    stale.game.invalidateNativeStationAuthority()
    let untouched = stale.game.commander
    #expect(throws: (any Error).self) { try stale.game.confirmIsolationWorkParent(quote) }
    #expect(stale.game.commander == untouched)

    let fixture = try await IsolationWorkFixture()
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    try FileManager.default.createDirectory(
      at: files.save.deletingLastPathComponent(), withIntermediateDirectories: true)
    let runtime = GameRuntime(game: fixture.game)
    _ = try await runtime.registerNewCommanderDestination(at: files.save)
    let before = await runtime.snapshot().commander
    try Data("occupied".utf8).write(to: files.save)
    await #expect(throws: (any Error).self) {
      try await runtime.scriptCommand { candidate in
        try candidate.confirmIsolationWorkParent(candidate.isolationWorkParentReview(.returnUnpaid))
      }
    }
    #expect(await runtime.snapshot().commander == before)
    #expect(try String(contentsOf: files.save, encoding: .utf8) == "occupied")
  }

  @Test func sameBirthIncompleteSourceAndForgedTerminalCannotSupplySuccessfulReception()
    async throws
  {
    let fixture = try await IsolationWorkFixture()
    let before = fixture.game.commander
    let quote = fixture.game.isolationWorkParentReview(.receive)
    #expect(!quote.allowed)
    #expect(throws: (any Error).self) { try fixture.game.confirmIsolationWorkParent(quote) }
    #expect(fixture.game.commander == before)
    let dock = try #require(fixture.game.commander.nativeStations?.currentMainDock)
    let arrival = try #require(fixture.game.nativeMainStationArrivalContext(for: dock.station))
    let returned = try fixture.game.stageIsolationProgrammerReturn(
      parentID: fixture.primitive.parentID, arrival: arrival)
    var parent = try #require(fixture.game.isolationWorkParentMission)
    var proof = try #require(parent.savedIsolationWorkParent)
    let sequence = fixture.game.commander.scriptState.nextEvent + 1
    let facts = NativeIsolationContractTerminalFacts(
      parent: parent.id, authorization: proof.authorization, issueOperation: proof.issue.operation,
      owner: proof.owner, source: proof.source, outcome: .complete, sequence: sequence,
      physicalTime: fixture.game.commander.flightSimulation.physicalTime,
      cause: fixture.game.scriptEventContext(parent), dock: dock, returnedCommand: returned.command,
      verifications: [UUID(), UUID()], failure: nil)
    proof.terminal = .init(
      operation: try NativeIsolationContractTerminal.identity(facts), facts: facts)
    parent.savedIsolationWorkParent = proof
    parent.outcome = .complete
    parent.milestones = [0, 1, 2]
    parent.revision += 1
    parent.acknowledge(sequence)
    parent.contract?.settled = true
    parent.contract?.settlementOutcome = .complete
    parent.contract?.settlementAmount = 9700
    parent.contract?.settledAt = fixture.game.commander.scriptState.calendarSeconds
    fixture.game.commander.scriptState.nextEvent = sequence
    fixture.game.refreshIsolationContractReceipt(&parent)
    fixture.game.commander.scriptState.instances[parent.id] = parent
    #expect(!NativeIsolationContractSave.validateClaims(fixture.game.commander))
    #expect(!fixture.game.commander.valid)
  }
}
