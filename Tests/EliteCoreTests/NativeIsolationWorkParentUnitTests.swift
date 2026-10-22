import Foundation
import Testing

@testable import EliteCore

struct NativeIsolationWorkParentUnitTests {
  private func prepared() async throws -> Game {
    var game = Game(executive: false)
    game.scriptPacks = [
      try ScriptPackLibrary.read(ScriptPackLibrary.bundledIsolationWorkParentDirectory),
      try ScriptPackLibrary.read(ScriptPackLibrary.bundledIsolationWorkDirectory),
    ]
    let runtime = GameRuntime(game: game)
    try await runtime.startNewCommander()
    let destination = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString)
    _ = try await runtime.registerNewCommanderDestination(at: destination)
    return await runtime.snapshot()
  }
  private func arrival(_ game: Game) throws -> NativeMainStationArrivalContext {
    let receipt = try #require(game.commander.nativeStations?.currentMainDock)
    return try #require(game.nativeMainStationArrivalContext(for: receipt.station))
  }
  private func stage(_ game: inout Game) throws -> NativeIsolationWorkParentPrimitive {
    let primitive = try game.stageIsolationParent(
      arrival: arrival(game),
      expectedInventoryRevision: #require(game.commander.equipmentInventory?.revision))
    try game.authorizeIsolationWork(parentID: primitive.parentID)
    return primitive
  }

  @Test func stableRoundTripQuoteUsesExactContentAndNoDeadline() throws {
    let owner = UUID()
    let offer = NativeIsolationWorkParent.offer(owner: owner)
    #expect(offer == NativeIsolationWorkParent.offer(owner: owner))
    #expect(offer != NativeIsolationWorkParent.offer(owner: UUID()))
    #expect(offer.reward == 9700 && offer.deposit == 0 && offer.failureReward == 0)
    #expect(
      offer.duration == 0
        && offer.parameters == .object(["legs": .integer(2), "hazard": .integer(0)]))
    let job = NativeIsolationWorkParent.job(owner: owner, acceptedAt: 120)
    #expect(job.valid && job.deadline == nil && !job.settled)
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledIsolationWorkParentDirectory)
    #expect(NativeIsolationWorkParent.matches(pack))
  }

  @Test func genuineAcceptanceRetainsActualIssueAndOriginalReturnCutoff() async throws {
    var game = try await prepared()
    let before = game.commander
    let context = try arrival(game)
    let primitive = try stage(&game)
    let parent = try #require(game.commander.scriptState.instances[primitive.parentID])
    let saved = try #require(parent.savedIsolationWorkParent)
    #expect(primitive.issueOperation == saved.issue.operation)
    #expect(primitive.acceptance == context.receipt && primitive.cutoff == nil)
    #expect(saved.source == NativeIsolationWorkParent.source(owner: primitive.owner))
    #expect(
      game.commander.credits == before.credits
        && game.commander.cargoTonnes == before.cargoTonnes + 1)
    #expect(OriginalServiceReservationPolicy.activeCount(game.commander.scriptState) == 1)
    #expect(NativeIsolationWorkParentSave.validateClaims(game.commander))
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    var fresh = Game(executive: false)
    fresh.scriptPacks = game.scriptPacks
    let runtime = GameRuntime(game: fresh)
    try await runtime.startNewCommander()
    try FileManager.default.createDirectory(
      at: files.save.deletingLastPathComponent(), withIntermediateDirectories: true)
    _ = try await runtime.registerNewCommanderDestination(at: files.save)
    let untouched = await runtime.snapshot().commander
    // Occupy the registered exclusive destination after registration: real publisher refusal.
    try Data("existing destination".utf8).write(to: files.save)
    await #expect(throws: (any Error).self) {
      try await runtime.scriptCommand { candidate in
        let dock = try #require(candidate.commander.nativeStations?.currentMainDock)
        let arrival = try #require(candidate.nativeMainStationArrivalContext(for: dock.station))
        let primitive = try candidate.stageIsolationParent(
          arrival: arrival,
          expectedInventoryRevision: #require(candidate.commander.equipmentInventory?.revision))
        try candidate.authorizeIsolationWork(parentID: primitive.parentID)
      }
    }
    #expect(await runtime.snapshot().commander == untouched)
    #expect(try String(contentsOf: files.save, encoding: .utf8) == "existing destination")
    let issued = game.commander
    #expect(throws: (any Error).self) { _ = try stage(&game) }
    #expect(game.commander == issued)
    let receipt = try game.stageIsolationProgrammerReturn(parentID: parent.id, arrival: context)
    let returned = try #require(game.commander.scriptState.instances[parent.id])
    let historical = try NativeIsolationWorkParent.primitive(
      parent: returned, commander: game.commander)
    #expect(receipt.operation == .returned && receipt.command == historical.cutoff?.operation)
    #expect((historical.cutoff?.sequence ?? 0) > primitive.sequence)
    #expect(
      game.commander.cargoTonnes == before.cargoTonnes && game.commander.credits == before.credits)
    #expect(NativeIsolationProgrammerCustody.hasIssuedOriginal(in: game.commander))
    #expect(throws: NativeIsolationProgrammerError.unavailableOriginal) {
      _ = try NativeIsolationProgrammerCustody.resolve(parent: returned, commander: game.commander)
    }
  }

  @Test func staleNativeContextAndFullHoldRefuseWithoutOriginalOrReservation() async throws {
    var game = try await prepared()
    let context = try arrival(game)
    let revision = try #require(game.commander.equipmentInventory?.revision)
    game.invalidateNativeStationAuthority()
    let before = game.commander
    #expect(throws: (any Error).self) {
      _ = try game.stageIsolationParent(arrival: context, expectedInventoryRevision: revision)
    }
    #expect(game.commander == before)
    var full = try await prepared()
    full.commander.cargo[0] = full.commander.standardCargoCapacity
    let fullBefore = full.commander
    #expect(throws: (any Error).self) { _ = try stage(&full) }
    #expect(
      full.commander == fullBefore
        && !NativeIsolationProgrammerCustody.hasIssuedOriginal(in: full.commander))
  }

  @Test func threeRealServiceReservationsRefuseFourthAndPreviewChangesNothing() async throws {
    var game = try await prepared()
    let before = game.commander
    #expect(game.isolationWorkParentReview(.accept).allowed)
    #expect(game.commander == before)
    for index in 0..<3 {
      var job = NativeIsolationWorkParent.job(owner: UUID(), acceptedAt: 0)
      // Independent existing contract slots, not extra G11 originals or permissions.
      job.settled = false
      var parent = ScriptInstance(
        id: UUID(), definition: "l337.contract/fixture-\(index)", version: "1.0.0",
        digest: String(repeating: "a", count: 64))
      parent.contract = job
      game.commander.scriptState.instances[parent.id] = parent
    }
    let occupied = game.commander
    #expect(!game.isolationWorkParentReview(.accept).allowed)
    #expect(throws: (any Error).self) { _ = try stage(&game) }
    #expect(game.commander == occupied)
  }

  @Test func strictParentCodecRejectsErasureUnknownFieldsAndDowngrade() async throws {
    var game = try await prepared()
    let primitive = try stage(&game)
    let bytes = try JSONEncoder().encode(game.commander.scriptState)
    try NativeIsolationWorkParentSave.validateFields(bytes, part: .missions, schema: 133)
    #expect(throws: (any Error).self) {
      try NativeIsolationWorkParentSave.validateFields(bytes, part: .missions, schema: 115)
    }
    var parent = try #require(game.commander.scriptState.instances[primitive.parentID])
    parent.savedIsolationWorkParent = nil
    game.commander.scriptState.instances[parent.id] = parent
    #expect(!NativeIsolationWorkParentSave.validateClaims(game.commander))
    let erased = try JSONEncoder().encode(game.commander.scriptState)
    #expect(throws: (any Error).self) {
      try NativeIsolationWorkParentSave.validateFields(erased, part: .missions, schema: 133)
    }
    var raw = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    raw["savedIsolationWorkParent"] = [:]
    let injected = try JSONSerialization.data(withJSONObject: raw)
    #expect(throws: (any Error).self) {
      try NativeIsolationWorkParentSave.validateFields(injected, part: .missions, schema: 133)
    }
  }

  @Test func genericAcceptanceCannotMintNativeParent() async throws {
    var game = try await prepared()
    let pack = try #require(game.scriptPacks.first)
    let before = game.commander
    #expect(throws: (any Error).self) { _ = try game.acceptScriptMission(pack) }
    #expect(game.commander == before)

  }
}
