import Foundation
import Testing

@testable import EliteCore

struct NativeOrbitalOutlookScanTests {
  @Test func outlookOnlyOrderedDistinctRealMarkersProduceMeasuredReadings() async throws {
    let f = try NativeOrbitalOutlookFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.board(runtime)
    try await f.renas(runtime)
    try await f.aim(runtime, ordinal: 1)
    for _ in 0..<125 { _ = await runtime.advance(delta: 0.1) }
    #expect(try await f.source(runtime).readings.isEmpty)
    try await f.view(runtime, ordinal: 0)
    let first = try await f.source(runtime)
    let reading = try #require(first.readings.first)
    #expect(reading.ordinal == 0 && reading.people == first.references)
    #expect(reading.end - reading.start >= 12 && reading.qualifiedSeconds >= 12)
    #expect(reading.intervals >= 120 && reading.actor.visit == reading.player.visit)
    #expect(await runtime.snapshot().orbitalOutlookScanStatus?.contains("1/3") == true)
    try await f.aim(runtime, ordinal: 0)
    for _ in 0..<125 { _ = await runtime.advance(delta: 0.1) }
    #expect(try await f.source(runtime).readings == first.readings)
    try await f.aim(runtime, ordinal: 2)
    _ = await runtime.advance(delta: 0.1)
    #expect(try await f.source(runtime).readings == first.readings)
    try await f.view(runtime, ordinal: 1)
    try await f.view(runtime, ordinal: 2)
    let complete = try await f.source(runtime)
    #expect(complete.readings.map(\.ordinal) == [0, 1, 2])
    #expect(Set(complete.readings.map(\.marker)).count == 3)
    #expect(Set(complete.readings.map(\.operation)).count == 3)
    #expect(complete.terminalOperation == nil)
  }

  @Test(arguments: [
    "range", "aim", "occluded", "equipment", "caller-clamped", "missing-interval", "epoch", "view",
    "culled",
  ])
  func outlookNativeFrameQualificationResetsGapsAndHonorsOnlyMeasuredTime(reason: String)
    async throws
  {
    let f = try NativeOrbitalOutlookFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.board(runtime)
    try await f.renas(runtime)
    try await f.aim(runtime, ordinal: 0)
    for _ in 0..<10 { _ = await runtime.advance(delta: 0.1) }
    let qualified = await runtime.snapshot()
    let previous = try #require(qualified.nativeOrbitalOutlookRuntime.observation)
    if reason == "range" { try await f.aim(runtime, ordinal: 0, distance: 2000) }
    if reason == "aim" {
      await runtime.nativeCommand { game in
        var pose = game.commander.flightSimulation.pose
        let right = pose.orientation.x
        let forward = pose.orientation.z
        pose.orientation.x = right * cos(0.2) + forward * sin(0.2)
        pose.orientation.z = forward * cos(0.2) - right * sin(0.2)
        NativeStationTestFixture.reframe(&game, to: pose)
      }
      let turned = await runtime.snapshot()
      let target = try #require(turned.informationTargetBody)
      try #require(target.position.z / target.position.length < cos(2 * .pi / 180))
      try #require(turned.orbitalOutlookSample() == nil)
    }
    if reason == "occluded" {
      await runtime.nativeCommand { game in
        let id = game.nextBodyID
        game.nextBodyID += 1
        game.bodies.append(.init(id: id, hull: .cargo, position: .init(0, 0, 500)))
        game.ensurePhysicalActors()
      }
    }
    if reason == "equipment" {
      await runtime.nativeCommand { game in
        guard let key = game.commander.fittedEquipment(at: .targetingCore)?.node.key else { return }
        try? game.commander.removeFittedEquipment(key)
      }
    }
    if reason == "epoch" { await runtime.nativeCommand { $0.invalidateNativeStationAuthority() } }
    if reason == "view" { await runtime.key("1") }
    if reason == "culled" {
      let target = try #require(qualified.informationTargetBody)
      let marker = try #require(target.missionActorID)
      let mission = try #require(target.missionInstanceID)
      await runtime.nativeCommand { game in
        var pose = game.commander.flightSimulation.pose
        pose.position = pose.position + pose.orientation.z * 100_000
        NativeStationTestFixture.reframe(&game, to: pose)
        game.tick(delta: 0.1)
      }
      let culled = await runtime.snapshot()
      try #require(!culled.bodies.contains { $0.missionActorID == marker })
      let retained = try #require(
        culled.commander.scriptState.instances[mission]?.ownedEncounters[
          NativeOrbitalOutlookJourney.encounterID]?.actors[NativeOrbitalOutlookJourney.views[0]])
      try #require(retained.identity == marker && retained.presence == .outside)
      try #require(culled.orbitalOutlookSample() == nil)
    }
    if reason == "missing-interval" {
      // A real native tick outside the observing ingress creates an actual unobserved time gap.
      await runtime.nativeCommand { $0.tick(delta: 0.1) }
    }
    _ = await runtime.advance(delta: reason == "caller-clamped" ? 0.2 : 0.1)
    let after = await runtime.snapshot()
    #expect(after.commander.nativePeople?.outlookJourney?.readings.isEmpty == true)
    let elapsed = after.nativeOrbitalOutlookRuntime.observation?.seconds ?? 0
    if reason == "caller-clamped" {
      let nativeDelta =
        after.commander.flightSimulation.physicalTime
        - qualified.commander.flightSimulation.physicalTime
      #expect(nativeDelta > 0 && nativeDelta <= 0.1 + 1e-9)
      #expect(abs(elapsed - previous.seconds - nativeDelta) < 1e-8)
    } else {
      #expect(elapsed < 0.11)
    }
    #expect(after.commander.scriptState.savedClueJournal == nil)
  }

  @Test func outlookActuallyDestroyedMarkerCannotBeScannedOrReplacedByItsHull() async throws {
    let f = try NativeOrbitalOutlookFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let source = try await f.board(runtime)
    let boarding = try #require(source.boarding)
    try await f.renas(runtime)
    try await f.aim(runtime, ordinal: 0)
    await runtime.key("u")
    var controls = Controls()
    controls.fire = true
    await runtime.setControls(controls)
    for _ in 0..<500 {
      let game = await runtime.snapshot()
      if game.commander.scriptState.instances[boarding.mission]?.ownedEncounters[
        NativeOrbitalOutlookJourney.encounterID]?.actors[NativeOrbitalOutlookJourney.views[0]]?
        .presence == .destroyed
      {
        break
      }
      _ = await runtime.advance(delta: 0.05)
    }
    await runtime.setControls(Controls())
    let destroyed = await runtime.snapshot()
    #expect(
      destroyed.commander.scriptState.instances[boarding.mission]?.ownedEncounters[
        NativeOrbitalOutlookJourney.encounterID]?.actors[NativeOrbitalOutlookJourney.views[0]]?
        .presence == .destroyed)
    #expect(destroyed.commander.nativePeople?.outlookJourney?.readings.isEmpty == true)
    #expect(destroyed.orbitalOutlookSample() == nil)
    for _ in 0..<125 { _ = await runtime.advance(delta: 0.1) }
    #expect(try await f.source(runtime).readings.isEmpty)
    #expect(await runtime.snapshot().commander.scriptState.savedClueJournal == nil)
  }

  @Test func outlookPauseAndReadOnlyPanelDoNotAccrueAndColdLoadResetsOnlyPartialView() async throws
  {
    let f = try NativeOrbitalOutlookFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.board(runtime)
    try await f.renas(runtime)
    try await f.view(runtime, ordinal: 0)
    try await f.aim(runtime, ordinal: 1)
    for _ in 0..<20 { _ = await runtime.advance(delta: 0.1) }
    let before = await runtime.snapshot()
    let partial = try #require(before.nativeOrbitalOutlookRuntime.observation)
    for _ in 0..<10 {
      let game = await runtime.snapshot()
      if let info = game.targetInformation {
        _ = TargetPanelLayout(
          game: game, info: info,
          cockpit: CockpitLayout(game: game, width: game.viewportWidth, height: game.viewportHeight)
        )
      }
      _ = game.scriptCommanderQuery
      _ = game.orbitalOutlookScanStatus
    }
    #expect(await runtime.snapshot().nativeOrbitalOutlookRuntime.observation == partial)
    await runtime.key("pause")
    for _ in 0..<20 { _ = await runtime.advance(delta: 0.1) }
    #expect(await runtime.snapshot().nativeOrbitalOutlookRuntime.observation == partial)
    #expect(
      await runtime.snapshot().commander.flightSimulation.physicalTime
        == before.commander.flightSimulation.physicalTime)
    await runtime.key("pause")
    try await runtime.save(to: f.save)
    try await runtime.load(from: f.save, persistMigrations: false)
    let cold = await runtime.snapshot()
    #expect(
      cold.commander.nativePeople?.outlookJourney?.readings
        == before.commander.nativePeople?.outlookJourney?.readings)
    #expect(
      cold.nativeOrbitalOutlookRuntime.observation == nil
        && cold.nativeOrbitalOutlookRuntime.pending == nil)
    await runtime.key("0")
    try await f.aim(runtime, ordinal: 1)
    _ = await runtime.advance(delta: 0.1)
    #expect(await runtime.snapshot().nativeOrbitalOutlookRuntime.observation?.seconds ?? 0 < 0.11)
    #expect(try await f.source(runtime).readings.count == 1)
  }

  @Test func outlookCompletedAuthoritySurvivesActualTargetingRefitAndColdEpochRotation()
    async throws
  {
    let f = try NativeOrbitalOutlookFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.board(runtime)
    try await f.renas(runtime)
    try await f.view(runtime, ordinal: 0)
    let original = try await f.source(runtime)
    let reading = try #require(original.readings.first)
    try await f.base.flight.dock(runtime)
    await runtime.procurementRefuel()
    try await f.base.flight.travel(runtime, path: [185, 7])
    let before = await runtime.snapshot()
    try await runtime.outlookBuyTargetingIdentification()
    let refitted = await runtime.snapshot()
    #expect(refitted.commander.targetingTier == .identification)
    #expect(refitted.commander.fittedEquipment(at: .targetingCore)?.id != reading.equipment)
    #expect(refitted.commander.credits < before.commander.credits)
    #expect(refitted.commander.equipmentInventory?.revision != reading.inventoryRevision)
    try await runtime.save(to: f.save)
    let oldEpoch = await runtime.snapshot().nativeStationRuntimeEpoch
    try await runtime.load(from: f.save, persistMigrations: false)
    let cold = await runtime.snapshot()
    #expect(
      cold.nativeStationRuntimeEpoch != oldEpoch && cold.nativeStationRuntimeEpoch != reading.epoch)
    #expect(cold.commander.nativePeople?.outlookJourney?.readings == original.readings)
    #expect(cold.commander.nativePeople?.outlookJourney?.authorities == original.authorities)
    #expect(NativeOrbitalOutlookJourneySave.validateClaims(cold.commander))
    try await f.renas(runtime)
    try await f.view(runtime, ordinal: 1)
    let continued = try await f.source(runtime)
    #expect(continued.readings[0] == reading)
    #expect(continued.readings[1].equipment != reading.equipment)
  }

  @Test func outlookReadingWriterRefusalRetainsOnlyMeasuredReceiptAndNeverRollsBackPhysics()
    async throws
  {
    let f = try NativeOrbitalOutlookFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.board(runtime)
    try await f.renas(runtime)
    try await f.aim(runtime, ordinal: 0)
    for _ in 0..<119 { _ = await runtime.advance(delta: 0.1) }
    let before = await runtime.snapshot()
    let files = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let held = try f.files.blockWrites("outlook-scan")
    for _ in 0..<3 {
      _ = await runtime.advance(delta: 0.1)
      if await runtime.snapshot().nativeOrbitalOutlookRuntime.pending != nil { break }
    }
    let failed = await runtime.snapshot()
    let pending = try #require(failed.nativeOrbitalOutlookRuntime.pending)
    let reading = pending.reading
    #expect(
      failed.commander.flightSimulation.physicalTime
        > before.commander.flightSimulation.physicalTime)
    #expect(failed.commander.nativePeople == before.commander.nativePeople)
    #expect(failed.commander.credits == before.commander.credits)
    #expect(failed.commander.scriptState.savedClueJournal == nil)
    try f.files.restoreWrites(held, files: files)
    _ = await runtime.advance(delta: 0.1)
    let committed = await runtime.snapshot()
    #expect(committed.commander.nativePeople?.outlookJourney?.readings == [reading])
    #expect(
      committed.commander.flightSimulation.physicalTime
        > failed.commander.flightSimulation.physicalTime)
    #expect(committed.nativeOrbitalOutlookRuntime.pending == nil)
    _ = await runtime.advance(delta: 0.1)
    #expect(await runtime.snapshot().commander.nativePeople?.outlookJourney?.readings == [reading])
  }

  @Test func outlookReturnCareWriterFailureKeepsPeopleReadingsCashAndClueAtomic() async throws {
    let f = try NativeOrbitalOutlookFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.board(runtime)
    try await f.renas(runtime)
    try await f.allViews(runtime)
    try await f.returnHome(runtime)
    let page = try await NativePeopleTestFixture.review(runtime, row: .outlook(.receive))
    await runtime.scriptPageKey("right", expected: page)
    let before = await runtime.snapshot().commander
    let files = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let held = try f.files.blockWrites("outlook-return")
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    try f.files.restoreWrites(held, files: files)
    try await f.confirm(runtime, .receive)
    #expect(await runtime.snapshot().commander.credits == before.credits + 8700)
    #expect(await runtime.snapshot().commander.nativePeople?.outlookJourney?.readings.count == 3)
  }

  @Test(arguments: [false, true], [false, true])
  func outlookGenuine43And44ColdJoinsIndependentlyPreserveG02G04AndG05(alien: Bool, composed: Bool)
    async throws
  {
    let f = try NativeOrbitalOutlookFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime(coexist: composed)
    if composed {
      _ = try await f.base.board(runtime)
      let supply = try ScriptPackLibrary.read(ScriptPackLibrary.bundledConsentedFreightDirectory)
      await runtime.nativeCommand { $0.scriptPacks.append(supply) }
      let key = try await runtime.generateContractBoard(packDigest: supply.digest)
      let offer = try #require(
        await runtime.snapshot().commander.contracts.boards[key]?.offers.first)
      let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
      try #require(quote.allowed)
      _ = try await runtime.confirmContract(quote)
      try await f.base.flight.travel(runtime, path: [7, 185])
      await runtime.key("contacts-open")
      try await ScriptFreightFixture.confirm(runtime, all: true)
      try await f.base.confirm(runtime, .receive)
      await runtime.procurementRefuel()
      try await f.base.flight.travel(runtime, path: [185, 7])
    }
    let source = try await f.board(runtime)
    try await f.renas(runtime)
    try await f.view(runtime, ordinal: 0)
    var game = await runtime.snapshot()
    if alien {
      let owner = try #require(game.commander.equipmentOwnerID)
      try game.commander.replaceAlienStorage(
        with: .init(
          owner: owner, revision: 0, worldRevision: 0,
          world: [], sources: [], attachments: [], upgrades: [], receipts: [], commands: []))
    }
    let prepared = try GameRuntime.prepareNativeSaveState(game)
    let url = f.files.root.appendingPathComponent("outlook-envelope/commander.json")
    let publication = try ScriptSaveStore.write(
      commander: prepared.commander,
      world: prepared.game.scriptWorldSave, to: url)
    var expected = prepared.commander
    expected.publishAlienStorage(publication)
    let bytes = try Data(contentsOf: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == (alien ? 44 : 43))
    let (cold, world) = try ScriptSaveStore.read(bytes, from: url)
    #expect(cold == expected && world.consistent(with: cold))
    #expect(cold.nativePeople?.outlookJourney?.references == source.references)
    #expect(cold.nativePeople?.outlookJourney?.readings.count == 1)
    #expect((cold.nativePeople?.stationJourney != nil) == composed)
    #expect((cold.scriptState.savedOriginalConsentedFreightSupply != nil) == composed)
    #expect(NativeOrbitalOutlookJourneySave.validateClaims(cold))
    #expect(NativeStationPassengerJourneySave.validateClaims(cold))
    #expect(OriginalConsentedFreightSupplySave.validateClaims(cold))
  }

  @Test func outlookRehashedSaveRejectsUnknownStrippedCrossFamilyAndForgedReadingJoins()
    async throws
  {
    let f = try NativeOrbitalOutlookFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.board(runtime)
    try await f.renas(runtime)
    try await f.view(runtime, ordinal: 0)
    try await runtime.save(to: f.save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: f.save))
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: f.save)
    let file = directory.appendingPathComponent("commander.json")
    let original = try Data(contentsOf: file)
    defer { try? original.write(to: file) }
    let observed = await runtime.snapshot()
    let other = try #require(observed.commander.nativePeople?.outlookJourney?.boarding)
    let otherActor = try #require(
      observed.commander.scriptState.instances[other.mission]?.ownedEncounters[
        NativeOrbitalOutlookJourney.encounterID]?.actors[NativeOrbitalOutlookJourney.views[1]]?.body
        .physical?.identity)
    let otherActorJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(otherActor))
    for mode in [
      "stripped", "null", "partial", "duplicate", "ordinal", "marker", "family", "older",
      "equipment", "inventory", "epoch", "actor", "authority-equipment", "authority-epoch",
      "authority-actor",
    ] {
      var object = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
      var custody = try #require(object["savedNativePeopleCustody"] as? [String: Any])
      var source = try #require(custody["outlookJourney"] as? [String: Any])
      if mode == "stripped" { custody.removeValue(forKey: "outlookJourney") }
      if mode == "null" { custody["outlookJourney"] = NSNull() }
      if mode == "partial" { source["partialSeconds"] = 12 }
      var readings = try #require(source["readings"] as? [[String: Any]])
      if mode == "duplicate" { readings.append(readings[0]) }
      if mode == "ordinal" { readings[0]["ordinal"] = 2 }
      if mode == "marker" { readings[0]["marker"] = UUID().uuidString }
      if mode == "equipment" { readings[0]["equipment"] = UUID().uuidString }
      if mode == "inventory" { readings[0]["inventoryRevision"] = 999999 }
      if mode == "epoch" { readings[0]["epoch"] = UUID().uuidString }
      if mode == "actor" { readings[0]["actor"] = otherActorJSON }
      if mode.hasPrefix("authority-") {
        var authorities = try #require(source["authorities"] as? [[String: Any]])
        if mode == "authority-epoch" { authorities[0]["epoch"] = UUID().uuidString }
        if mode == "authority-equipment" {
          var equipment = try #require(authorities[0]["equipment"] as? [String: Any])
          equipment["id"] = UUID().uuidString
          authorities[0]["equipment"] = equipment
        }
        if mode == "authority-actor" {
          var marker = try #require(authorities[0]["marker"] as? [String: Any])
          var body = try #require(marker["body"] as? [String: Any])
          var physical = try #require(body["physical"] as? [String: Any])
          physical["identity"] = otherActorJSON
          body["physical"] = physical
          marker["body"] = body
          authorities[0]["marker"] = marker
        }
        source["authorities"] = authorities
      }
      if mode == "family" {
        var people = try #require(source["people"] as? [[String: Any]])
        var identity = try #require(people[0]["identity"] as? [String: Any])
        identity["batch"] = NativeStationPassengerJourney.batch
        identity["person"] = "mira-talen"
        people[0]["identity"] = identity
        source["people"] = people
      }
      source["readings"] = readings
      if !["stripped", "null"].contains(mode) { custody["outlookJourney"] = source }
      object["savedNativePeopleCustody"] = custody
      let bytes = try JSONSerialization.data(withJSONObject: object)
      if ["equipment", "inventory", "epoch", "actor"].contains(mode) || mode.hasPrefix("authority-")
      {
        // Well-formed native fields must reach semantic authority validation, not fail syntax.
        try NativeOrbitalOutlookJourneySave.validateFields(bytes, part: .commander, schema: 43)
      }
      try bytes.write(to: file)
      var hashes = pointer.hashes
      hashes["commander.json"] = ScriptPackLibrary.hash(bytes)
      let changed = ScriptSavePointer(
        format: pointer.format, schemaVersion: mode == "older" ? 41 : 43,
        generation: pointer.generation, hashes: hashes, scope: pointer.scope,
        valueCodec: pointer.valueCodec)
      #expect(throws: (any Error).self) {
        try ScriptSaveStore.read(JSONEncoder().encode(changed), from: f.save)
      }
      try original.write(to: file)
    }
  }
  @Test func outlookColdAdmissionRejectsOrphanAndWithdrawnFullItineraryClaims() async throws {
    let f = try NativeOrbitalOutlookFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    _ = try await f.board(runtime)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: f.save))
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: f.save)
    for mode in ["orphan", "withdrawn"] {
      let name = mode == "orphan" ? "missions.json" : "commander.json"
      let file = directory.appendingPathComponent(name)
      let original = try Data(contentsOf: file)
      defer { try? original.write(to: file) }
      var object = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
      if mode == "orphan" {
        let orphan = ScriptInstance(
          id: UUID(), definition: NativeOrbitalOutlookJourney.stateID,
          version: f.pack.manifest.version, digest: f.pack.digest)
        var instances = try #require(object["instances"] as? [Any])
        instances.append(contentsOf: [
          orphan.id.uuidString,
          try JSONSerialization.jsonObject(with: JSONEncoder().encode(orphan)),
        ])
        object["instances"] = instances
      } else {
        var custody = try #require(object["savedNativePeopleCustody"] as? [String: Any])
        var source = try #require(custody["outlookJourney"] as? [String: Any])
        var people = try #require(source["people"] as? [[String: Any]])
        for index in people.indices {
          var requests = try #require(people[index]["travelRequests"] as? [[String: Any]])
          var request = try #require(requests.first)
          request["revision"] = 2
          request["intent"] = "withdrawn"
          requests.append(request)
          people[index]["travelRequests"] = requests
        }
        source["people"] = people
        custody["outlookJourney"] = source
        object["savedNativePeopleCustody"] = custody
      }
      let bytes = try JSONSerialization.data(withJSONObject: object)
      if mode == "orphan" {
        let engine = try JSONDecoder().decode(ScriptEngineState.self, from: bytes)
        #expect(engine.valid)
      }
      try NativeOrbitalOutlookJourneySave.validateFields(
        bytes,
        part: mode == "orphan" ? .missions : .commander, schema: 43)
      try bytes.write(to: file)
      var hashes = pointer.hashes
      hashes[name] = ScriptPackLibrary.hash(bytes)
      let changed = ScriptSavePointer(
        format: pointer.format, schemaVersion: 43,
        generation: pointer.generation, hashes: hashes, scope: pointer.scope,
        valueCodec: pointer.valueCodec)
      #expect(throws: (any Error).self) {
        try ScriptSaveStore.read(JSONEncoder().encode(changed), from: f.save)
      }
      try original.write(to: file)
    }
  }

}

extension GameRuntime {
  func outlookBuyTargetingIdentification() throws {
    try scriptCommand { game in
      let item = try #require(
        Equipment.all.first { $0.name == TargetingTier.identification.equipmentName })
      let quote = try game.quoteEquipmentPurchase(item)
      let bought = try game.applyEquipmentPurchase(quote)
      try #require(bought)
    }
  }
}
