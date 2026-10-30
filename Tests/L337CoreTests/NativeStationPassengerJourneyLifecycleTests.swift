import Foundation
import Testing

@testable import L337Core

struct NativeStationPassengerJourneyLifecycleTests {
  @Test func journeyActualRenasCarePaysOnceAndReleasesTheSameTwoNativePeople() async throws {
    let f = try NativeStationJourneyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let source = try await f.board(runtime)
    let boarding = try #require(source.boarding)
    try await f.flight.travel(runtime, path: [7, 185])
    let before = await runtime.snapshot().commander
    try await f.confirm(runtime, .receive)
    let done = await runtime.snapshot()
    let receipt = try #require(done.commander.nativePeople?.transfers.last)
    #expect(receipt.kind == .care && receipt.members == source.references)
    #expect(done.commander.scriptState.instances[boarding.mission]?.outcome == .complete)
    #expect(done.commander.credits == before.credits + 6100)
    #expect(done.commander.accommodation.fittedBerths.allSatisfy { !$0.use.used })
    #expect(done.commander.nativePeople?.stationJourney?.references == source.references)
    let award = try #require(
      done.commander.scriptState.savedClueJournal?.awards[NativeStationPassengerJourney.stateID])
    #expect(award.clueID == "cabin-journey-family-trace")
    #expect(done.commander.valid)
    #expect(done.stationPassengerQuote(.receive).allowed == false)
    #expect(done.stationPassengerQuote(.request).allowed == false)
    await runtime.key("contracts-open")
    let replay = await runtime.snapshot()
    #expect(replay.commander == done.commander)
  }

  @Test func journeyReceiverWriterFailurePreservesPeopleCashBerthsAndClue() async throws {
    let f = try NativeStationJourneyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.board(runtime)
    try await f.flight.travel(runtime, path: [7, 185])
    let page = try await NativePeopleTestFixture.review(runtime, row: .journey(.receive))
    await runtime.scriptPageKey("right", expected: page)
    let before = await runtime.snapshot().commander
    let bytes = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let held = try f.files.blockWrites("journey-receiver")
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    try f.files.restoreWrites(held, files: bytes)
    try await f.confirm(runtime, .receive)
    #expect(await runtime.snapshot().commander.credits == before.credits + 6100)
  }

  @Test func journeySourceCancellationUsesCareWithoutPaymentOrRepopulation() async throws {
    let f = try NativeStationJourneyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let source = try await f.board(runtime)
    let boarding = try #require(source.boarding)
    let before = await runtime.snapshot().commander
    try await f.confirm(runtime, .cancel)
    let done = await runtime.snapshot()
    #expect(done.commander.scriptState.instances[boarding.mission]?.outcome == .abandoned)
    #expect(done.commander.nativePeople?.transfers.last?.members == source.references)
    #expect(done.commander.nativePeople?.transfers.last?.kind == .care)
    #expect(
      done.commander.credits == before.credits && done.commander.scriptState.savedClueJournal == nil
    )
    #expect(done.commander.accommodation.fittedBerths.allSatisfy { !$0.use.used })
    #expect(done.stationPassengerRows.isEmpty && done.commander.valid)
    try await runtime.load(from: f.save, persistMigrations: false)
    let cold = await runtime.snapshot()
    #expect(cold.commander.nativePeople?.stationJourney?.references == source.references)
    #expect(cold.commander.nativePeople?.stationJourney?.terminalOperation != nil)
  }

  @Test(arguments: [false, true])
  func journeyOccupiedEscapeRefusesWhileActualFatalLossClosesWithoutPayment(escape: Bool)
    async throws
  {
    let f = try NativeStationJourneyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime(escapeReady: escape)
    let source = try await f.board(runtime)
    let boarding = try #require(source.boarding)
    await runtime.key("escape")
    await runtime.key("0")
    _ = await runtime.advance(delta: 0.1)
    let before = await runtime.snapshot()
    try #require(!before.docked)
    if escape {
      await runtime.key("escape-pod")
      let refused = await runtime.snapshot()
      #expect(refused.commander == before.commander)
      #expect(refused.energy == before.energy && refused.bodies == before.bodies)
      #expect(refused.commander.scriptState.instances[boarding.mission]?.outcome == .active)
    } else {
      try await runtime.supplyFatalHullHit()
      _ = await runtime.advance(delta: 0.1)
      let lost = await runtime.snapshot()
      #expect(lost.commander.scriptState.instances[boarding.mission]?.outcome == .failed)
      #expect(lost.commander.nativePeople?.transfers.last?.kind == .loss)
      #expect(lost.commander.nativePeople?.transfers.last?.members == source.references)
      #expect(lost.commander.credits == before.commander.credits)
      #expect(lost.commander.scriptState.savedClueJournal == nil)
      #expect(lost.commander.accommodation.fittedBerths.allSatisfy { !$0.use.used })
      #expect(lost.commander.valid)
    }
  }

  @Test(arguments: [false, true], [false, true])
  func journeyGenuineEnvelopeUses41Or42WithIndependentG02Claims(alien: Bool, supply: Bool)
    async throws
  {
    let f = try NativeStationJourneyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let source = try await f.board(runtime)
    if supply {
      let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledConsentedFreightDirectory)
      await runtime.nativeCommand { $0.scriptPacks.append(pack) }
      let key = try await runtime.generateContractBoard(packDigest: pack.digest)
      let snapshot = await runtime.snapshot()
      let offer = try #require(snapshot.commander.contracts.boards[key]?.offers.first)
      let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
      try #require(quote.allowed, "\(quote.issues)")
      _ = try await runtime.confirmContract(quote)
    }
    var game = await runtime.snapshot()
    if alien {
      let owner = try #require(game.commander.equipmentOwnerID)
      try game.commander.replaceAlienStorage(
        with: .init(
          owner: owner, revision: 0, worldRevision: 0,
          world: [], sources: [], attachments: [], upgrades: [], receipts: [], commands: []))
    }
    let prepared = try GameRuntime.prepareNativeSaveState(game)
    let url = f.files.root.appendingPathComponent("journey-envelope/commander.json")
    let publication = try ScriptSaveStore.write(
      commander: prepared.commander, world: prepared.game.scriptWorldSave, to: url)
    var published = prepared.commander
    published.publishAlienStorage(publication)
    let bytes = try Data(contentsOf: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == (alien ? 42 : 41))
    let (cold, world) = try ScriptSaveStore.read(bytes, from: url)
    #expect(cold.nativePeople?.stationJourney?.references == source.references)
    #expect((cold.scriptState.savedOriginalConsentedFreightSupply != nil) == supply)
    #expect(OriginalConsentedFreightSupplySave.validateClaims(cold))
    #expect(cold == published && world.consistent(with: cold))
    #expect(NativeStationPassengerJourneySave.validateClaims(cold))
  }
  @Test func journeyClosedEnvelopeRejectsStrippedNullUnknownDuplicateAndOlderClaims() async throws {
    let f = try NativeStationJourneyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.board(runtime)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: f.save))
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: f.save)
    let file = directory.appendingPathComponent("commander.json")
    let original = try Data(contentsOf: file)
    defer { try? original.write(to: file) }
    for mode in ["stripped", "null", "unknown", "duplicate", "foreign", "older"] {
      let raw = try JSONSerialization.jsonObject(with: original)
      var object = try #require(raw as? [String: Any])
      var custody = try #require(object["savedNativePeopleCustody"] as? [String: Any])
      var source = try #require(custody["stationJourney"] as? [String: Any])
      if mode == "stripped" { custody.removeValue(forKey: "stationJourney") }
      if mode == "null" { custody["stationJourney"] = NSNull() }
      if mode == "unknown" { source["playerConsent"] = true }
      if mode == "duplicate" {
        var people = try #require(source["people"] as? [[String: Any]])
        people[1] = people[0]
        source["people"] = people
      }
      if mode == "foreign" { source["owner"] = UUID().uuidString }
      if !["stripped", "null"].contains(mode) { custody["stationJourney"] = source }
      object["savedNativePeopleCustody"] = custody
      let bytes = try JSONSerialization.data(withJSONObject: object)
      try bytes.write(to: file)
      var hashes = pointer.hashes
      hashes["commander.json"] = ScriptPackLibrary.hash(bytes)
      let changed = ScriptSavePointer(
        format: pointer.format,
        schemaVersion: mode == "older" ? 39 : 41, generation: pointer.generation,
        hashes: hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
      #expect(throws: (any Error).self) {
        try ScriptSaveStore.read(JSONEncoder().encode(changed), from: f.save)
      }
      try original.write(to: file)
    }
    let misplaced = try JSONSerialization.data(withJSONObject: ["stationJourney": [:]])
    #expect(throws: (any Error).self) {
      try NativeStationPassengerJourneySave.validateFields(misplaced, part: .missions, schema: 41)
    }
  }

  @Test func journeyRehashedSaveRejectsOrphanMissionBoardAndWithdrawnEffectiveConsent() async throws
  {
    let f = try NativeStationJourneyFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.board(runtime)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: f.save))
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: f.save)
    for mode in ["mission", "board", "withdrawn", "later-reply"] {
      let name =
        mode == "mission" ? "missions.json" : mode == "board" ? "contracts.json" : "commander.json"
      let file = directory.appendingPathComponent(name)
      let original = try Data(contentsOf: file)
      defer { try? original.write(to: file) }
      let raw = try JSONSerialization.jsonObject(with: original)
      var object = try #require(raw as? [String: Any])
      if mode == "mission" {
        let orphan = ScriptInstance(
          id: UUID(), definition: NativeStationPassengerJourney.stateID,
          version: f.pack.manifest.version, digest: f.pack.digest)
        let encoded = try JSONEncoder().encode(orphan)
        let record = try JSONSerialization.jsonObject(with: encoded)
        var instances = try #require(object["instances"] as? [Any])
        instances.append(contentsOf: [orphan.id.uuidString, record])
        object["instances"] = instances
      } else if mode == "board" {
        var boards = try #require(object["boards"] as? [String: Any])
        let originalBoard = try #require(boards.values.first as? [String: Any])
        var orphan = originalBoard
        orphan["id"] = "orphan-journey"
        orphan["offers"] = []
        let key = f.pack.digest + "/orphan-journey/" + NativeStationPassengerJourney.source.key
        boards[key] = orphan
        object["boards"] = boards
      } else {
        var custody = try #require(object["savedNativePeopleCustody"] as? [String: Any])
        var source = try #require(custody["stationJourney"] as? [String: Any])
        var people = try #require(source["people"] as? [[String: Any]])
        for index in people.indices {
          var requests = try #require(people[index]["travelRequests"] as? [[String: Any]])
          var request = try #require(requests.last)
          request["revision"] = 2
          request["intent"] = "withdrawn"
          requests.append(request)
          people[index]["travelRequests"] = requests
        }
        source["people"] = people
        if mode == "later-reply" {
          var replies = try #require(source["replies"] as? [[String: Any]])
          let originalReplies = replies
          for var reply in originalReplies {
            reply["sequence"] = replies.count + 1
            reply["personRevision"] = 2
            reply["kind"] = "withdraw"
            replies.append(reply)
          }
          source["replies"] = replies
        }
        custody["stationJourney"] = source
        object["savedNativePeopleCustody"] = custody
      }
      let bytes = try JSONSerialization.data(withJSONObject: object)
      if mode == "mission" {
        let generic = try JSONDecoder().decode(ScriptEngineState.self, from: bytes)
        #expect(generic.valid)
      } else if mode == "board" {
        let generic = try JSONDecoder().decode(ScriptContractState.self, from: bytes)
        #expect(generic.valid)
      }
      let part: ScriptFreightVersionedSave.Part =
        mode == "mission" ? .missions : mode == "board" ? .contracts : .commander
      try NativeStationPassengerJourneySave.validateFields(bytes, part: part, schema: 41)
      try bytes.write(to: file)
      var hashes = pointer.hashes
      hashes[name] = ScriptPackLibrary.hash(bytes)
      let changed = ScriptSavePointer(
        format: pointer.format, schemaVersion: 41,
        generation: pointer.generation, hashes: hashes, scope: pointer.scope,
        valueCodec: pointer.valueCodec)
      #expect(throws: (any Error).self) {
        try ScriptSaveStore.read(JSONEncoder().encode(changed), from: f.save)
      }
      try original.write(to: file)
    }
  }

}
