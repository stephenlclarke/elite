import Foundation
import Testing

@testable import EliteCore

struct NativePeoplePersistenceTests {
  @Test func legacyDataHookAcceptsLaterGenuineEpisodeWithoutInventingAnOldSchedule() throws {
    var game = try NativePeopleTestFixture.withinWindow()
    let source = try NativePeopleTestFixture.source(game)
    var record = try #require(game.commander.savedEMPState?.records[source])
    record.savedDisableEpisodes = nil
    let first = record.disableIncident
    let time = first.physicalTime + 31
    try game.commander.removeFittedEquipment(Equipment.empPirateBlaster)
    try game.commander.grantEquipment(
      Equipment.empPirateBlaster, at: .utility(.empPirateBlaster),
      provenance: .grant("Later actual fitted EMP replacement"))
    let replacement = try #require(game.commander.fittedEquipment(at: .utility(.empPirateBlaster)))
    try #require(replacement.id != record.weapon.id)
    // This is a data-hook boundary fixture, not evidence of actual electrical recovery.
    func laterIncident(emission: UInt64, part: String?, position: Vector3, station: Bool = false)
      -> CombatIncident
    {
      let origin = AttackOrigin(
        emissionID: emission, owner: first.origin.owner,
        emittedAt: time, ownerLegalAtEmission: first.origin.ownerLegalAtEmission, sourcePart: part)
      return CombatIncident(
        id: first.id + 1, physicalTime: time, origin: origin,
        victim: record.hull.body.physical?.identity, kind: .emp, outcome: .hit,
        position: position, victimLegalBeforeAttack: first.victimLegalBeforeAttack,
        firstAggressor: first.firstAggressor, victimRole: first.victimRole, victimIsStation: station
      )
    }
    let part = "emp:" + replacement.id.uuidString
    let later = laterIncident(
      emission: first.origin.emissionID + 1, part: part, position: first.position)
    let schedule = record.aboardOrdinals.map { EMPCrewEjection(ordinal: $0, delay: 45) }
    let prior = record
    let appended = record.appendCrewDisableEpisode(
      incident: later, weapon: replacement, owner: prior.weaponOwner, ejections: schedule)
    try #require(appended)
    #expect(record.disableIncident == first && record.disableEpisodes.count == 2)
    #expect(record.disableEpisodes[0].legacyTiming && record.disableEpisodes[0].ejections.isEmpty)
    #expect(record.currentCrewDisableIncident == later && record.crewDeadline == time + 30)
    #expect(record.crewCensusValid && record.valid)
    #expect(
      record.disableEpisodes[0].weapon == prior.weapon
        && record.disableEpisodes[1].weapon == replacement)
    var foreignOwner = prior
    let foreignAccepted = foreignOwner.appendCrewDisableEpisode(
      incident: later, weapon: replacement, owner: UUID(), ejections: schedule)
    #expect(!foreignAccepted)
    #expect(foreignOwner == prior)
    for bad in [
      laterIncident(emission: 0, part: part, position: first.position),
      laterIncident(
        emission: first.origin.emissionID + 1, part: "laser:not-emp", position: first.position),
      laterIncident(
        emission: first.origin.emissionID + 1, part: first.origin.sourcePart,
        position: first.position),
      laterIncident(
        emission: first.origin.emissionID + 1, part: part, position: .init(.infinity, 0, 0)),
      laterIncident(
        emission: first.origin.emissionID + 1, part: part, position: first.position, station: true),
    ] {
      var refused = prior
      let accepted = refused.appendCrewDisableEpisode(
        incident: bad, weapon: replacement, owner: prior.weaponOwner, ejections: schedule)
      #expect(!accepted)
      #expect(refused == prior)
      var forged = record
      let valid = record.disableEpisodes[1]
      forged.savedDisableEpisodes?[1] = .init(
        incident: bad, weapon: valid.weapon,
        weaponOwner: valid.weaponOwner, ejections: valid.ejections,
        legacyTiming: valid.legacyTiming,
        actorBindings: valid.actorBindings, legacyPods: valid.legacyPods,
        legacyNextEjectionAt: valid.legacyNextEjectionAt, legacyEmissions: valid.legacyEmissions)
      #expect(!forged.crewCensusValid && !forged.valid)
    }
    let original = record
    let repeated = record.appendCrewDisableEpisode(
      incident: later, weapon: replacement, owner: original.weaponOwner, ejections: schedule)
    #expect(!repeated)
    #expect(record == original)
  }

  @Test func legacy22AbsentFieldsRemainAbsentUntilRealRuntimeUpgradeAndKeepUnknownOldTimes()
    async throws
  {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativePeopleTestFixture.disabled()
    let source = try NativePeopleTestFixture.source(game)
    // Restore the exact pre-24 record shape: original producer, no sampled schedule or captures.
    game.commander.savedEMPState?.records[source]?.savedDisableEpisodes = nil
    game.commander.savedEMPState?.records[source]?.nextEjectionAt =
      game.commander.flightSimulation.physicalTime + 1
    try #require(game.commander.valid)
    let writer = GameRuntime(game: game, saveURL: storage.url)
    try await writer.save(to: storage.url)
    let bytes = try Data(contentsOf: storage.url)
    #expect(try JSONDecoder().decode(ScriptSavePointer.self, from: bytes).schemaVersion == 22)
    let reader = GameRuntime()
    try await reader.load(from: storage.url, persistMigrations: false)
    #expect(
      await reader.snapshot().commander.savedEMPState?.records[source]?.savedDisableEpisodes == nil)
    for _ in 0..<15 { _ = await reader.advance(delta: 0.1) }
    let upgraded = await reader.snapshot()
    let record = try #require(upgraded.commander.savedEMPState?.records[source])
    let episode = try #require(record.disableEpisodes.first)
    #expect(episode.legacyTiming && episode.ejections.isEmpty && episode.legacyPods.isEmpty)
    #expect(episode.legacyEmissions.count == 1 && episode.legacyEmissions[0].ordinal == 0)
    #expect(episode.legacyEmissions[0].time >= episode.legacyNextEjectionAt!)
    #expect(record.valid && upgraded.commander.valid)
    var frozenLegacy = record
    frozenLegacy.savedDisableEpisodes = nil
    try #require(frozenLegacy.valid)
    let installed = frozenLegacy.installLegacyCrewEpisode()
    try #require(installed)
    #expect(frozenLegacy.disableEpisodes[0].legacyPods == [0])
    #expect(frozenLegacy.disableEpisodes[0].legacyEmissions.isEmpty)
    #expect(frozenLegacy.podEjectionLowerBound(for: 0) == record.disableIncident.physicalTime)
    #expect(frozenLegacy.valid)
    try await reader.save(to: storage.url)
    #expect(
      try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: storage.url))
        .schemaVersion == 24)
    var forged = record
    forged.savedDisableEpisodes?[0].legacyEmissions = []
    #expect(!forged.crewCensusValid)
  }

  @Test func realCullAndReadmissionBeforeDeadlineAllowsOriginalCrewCaptureOnNewActor() async throws
  {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativePeopleTestFixture.withinWindow()
    let source = try NativePeopleTestFixture.source(game)
    let original = try #require(game.commander.savedEMPState?.records[source]?.hull.binding)
    game.bodies.removeAll { $0.physical?.identity == original }
    let persistEMPStateResult1 = game.persistEMPState()
    try #require(persistEMPStateResult1)
    game.advanceEMPActors()
    let rejoined = try #require(
      game.bodies.first { $0.physical?.empSource == source }?.physical?.identity)
    try #require(rejoined != original)
    #expect(
      game.commander.savedEMPState?.records[source]?.disableEpisodes.last?.actorBindings.contains(
        rejoined) == true)
    game.commander.cargo[0] = game.commander.standardCargoCapacity - 1
    try NativePeopleTestFixture.aimCutter(&game)
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    let captured = await NativePeopleTestFixture.capture(runtime)
    #expect(captured.commander.nativeCaptiveCount == 1)
    #expect(captured.commander.nativePeople?.heldCaptives.first?.actor == rejoined)
    #expect(captured.commander.nativePeople?.heldCaptives.first?.person.emp.source == source)
    #expect(captured.commander.valid)
  }

  @Test func scheduleOnlyAndCapturedPeopleUseSchema24AndSurviveMissingContent() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativePeopleTestFixture.withinWindow()
    let source = try NativePeopleTestFixture.source(game)
    let schedule = game.commander.savedEMPState?.records[source]?.disableEpisodes
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    try await runtime.save(to: storage.url)
    let initial = try Data(contentsOf: storage.url)
    #expect(try JSONDecoder().decode(ScriptSavePointer.self, from: initial).schemaVersion == 24)
    game.commander.cargo[0] = game.commander.standardCargoCapacity - 1
    try NativePeopleTestFixture.aimCutter(&game)
    let collector = GameRuntime(game: game, saveURL: storage.url)
    _ = await NativePeopleTestFixture.capture(collector)
    let saved = await collector.snapshot()
    try #require(saved.commander.nativeCaptiveCount == 1)
    let reader = GameRuntime()
    try await reader.load(from: storage.url, persistMigrations: false)
    let loaded = await reader.snapshot()
    #expect(loaded.commander.savedEMPState?.records[source]?.disableEpisodes == schedule)
    #expect(loaded.commander.nativePeople == saved.commander.nativePeople)
    #expect(loaded.scriptPacks.isEmpty && loaded.commander.valid)
    #expect(loaded.commander.nativeCaptiveCount == 1 && loaded.commander.cargo[3] == 1)
    let pointer = try JSONDecoder().decode(
      ScriptSavePointer.self, from: Data(contentsOf: storage.url))
    for version in [21, 22, 23] {
      let downgraded = ScriptSavePointer(
        format: pointer.format, schemaVersion: version,
        generation: pointer.generation, hashes: pointer.hashes, scope: pointer.scope,
        valueCodec: pointer.valueCodec)
      #expect(throws: SaveError.invalidCommander) {
        _ = try ScriptSaveStore.read(
          ScriptValueStorage.encoder().encode(downgraded), from: storage.url)
      }
    }
  }

  @Test(arguments: ["savedCrewCaptures", "savedDisableEpisodes", "savedDeceasedOrdinals"])
  func oldHeaderRejectsEveryReservedFieldIncludingNullButIgnoresAuthoredText(field: String) throws {
    for records: Any in [
      ["source": [field: NSNull()]],
      [[:], [field: NSNull()]],
    ] {
      let bytes = try JSONSerialization.data(withJSONObject: ["savedEMPState": ["records": records]]
      )
      #expect(throws: SaveError.invalidCommander) {
        try NativePeopleVersionedSave.rejectFields(bytes)
      }
    }
    let innocent = try JSONSerialization.data(withJSONObject: [
      "scriptState": ["instances": ["data": [field: NSNull()]]], "name": field,
    ])
    try NativePeopleVersionedSave.rejectFields(innocent)
  }

  @Test(arguments: [
    "captures", "ordinals", "episodes", "ejections", "bindings", "deceased", "legacyPods",
    "legacyEmissions",
  ])
  func nestedCollectionsRejectOversizeBeforeDecodingPoisonedChildren(collection: String) throws {
    let field: String
    let maximum: Int
    switch collection {
    case "captures":
      field = "savedCrewCaptures"
      maximum = EMPState.maximumPeople
    case "episodes":
      field = "savedDisableEpisodes"
      maximum = EMPHullRecord.maximumDisableEpisodes
    case "deceased":
      field = "savedDeceasedOrdinals"
      maximum = EMPState.maximumPeople
    default:
      field = collection == "bindings" ? "actorBindings" : collection
      maximum = EMPState.maximumPeople
    }
    let poison = Array(repeating: NSNull(), count: maximum + 1)
    let bytes = try JSONSerialization.data(withJSONObject: [field: poison])
    do {
      if ["captures", "episodes", "deceased"].contains(collection) {
        _ = try JSONDecoder().decode(EMPHullRecord.self, from: bytes)
      } else if collection == "ordinals" {
        _ = try JSONDecoder().decode(NativeCrewCaptureReceipt.self, from: bytes)
      } else {
        // Supply earlier bounded siblings so the poisoned target is reached first.
        var object: [String: Any] = [
          "ejections": [], "actorBindings": [], "legacyPods": [], "legacyEmissions": [],
        ]
        object[field] = poison
        _ = try JSONDecoder().decode(
          EMPCrewDisableEpisode.self, from: JSONSerialization.data(withJSONObject: object))
      }
      Issue.record("Oversized collection accepted")
    } catch DecodingError.dataCorrupted(let context) {
      #expect(context.debugDescription.contains("collection limit exceeded"))
    }
  }

  @Test func missingInitialScheduleMemberAndUnscheduledNewPodFailTheSavedCensus() throws {
    var game = try NativePeopleTestFixture.disabled()
    for _ in 0..<15 { game.tick(delta: 0.1) }
    let source = try NativePeopleTestFixture.source(game)
    var record = try #require(game.commander.savedEMPState?.records[source])
    try #require(record.podIndex(for: 0) != nil)
    record.savedDisableEpisodes?[0].ejections.removeAll { $0.ordinal == 0 }
    #expect(!record.crewCensusValid && !record.valid)
    record = try #require(game.commander.savedEMPState?.records[source])
    let index = try #require(
      record.savedDisableEpisodes?[0].ejections.firstIndex { $0.ordinal == 0 })
    record.savedDisableEpisodes?[0].ejections[index].emittedAt = nil
    #expect(!record.crewCensusValid && !record.valid)
  }

  @Test func actualEscapeFailureRollsBackEquipmentPeopleCargoAndControls() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativePeopleTestFixture.withinWindow()
    try game.commander.grantEquipment(
      "Escape Pod", at: .utility(.escapePod), provenance: .grant("Native escape regression"))
    game.commander.mirrorFittedEquipment()
    game.commander.cargo[0] = game.commander.standardCargoCapacity - 1
    try NativePeopleTestFixture.aimCutter(&game)
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    _ = await NativePeopleTestFixture.capture(runtime)
    var held = Controls()
    held.pitch = 0.2
    await runtime.setControls(held)
    let before = await runtime.snapshot()
    let files = try ScriptFinanceTestFixture.files(storage.directory)
    try storage.blockWriter()
    await runtime.key("escape-pod")
    let failed = await runtime.snapshot()
    #expect(failed.commander == before.commander && failed.docked == before.docked)
    #expect(await runtime.nativePeopleTestControls().pitch == held.pitch)
    #expect(try ScriptFinanceTestFixture.files(storage.backup) == files)
    try storage.restoreWriter()
    await runtime.key("escape-pod")
    let escaped = await runtime.snapshot()
    #expect(escaped.docked && escaped.commander.nativeCaptiveCount == 0)
    #expect(escaped.commander.nativePeople?.transfers.last?.kind == .escape)
    #expect(escaped.commander.nativePeople?.admissions == before.commander.nativePeople?.admissions)
    #expect(
      escaped.commander.savedEMPState?.records.values.first?.crewCaptures
        == before.commander.savedEMPState?.records.values.first?.crewCaptures)
    #expect(!escaped.commander.equipment.contains("Escape Pod"))
    #expect(escaped.message.contains("PEOPLE LEFT WITH ABANDONED SHIP"))
  }

  @Test func fatalFrameFailedWriterKeepsProtectedCustodyUntilOneSuccessfulLossSave() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativePeopleTestFixture.withinWindow()
    game.commander.cargo[0] = game.commander.standardCargoCapacity - 1
    try NativePeopleTestFixture.aimCutter(&game)
    let collector = GameRuntime(game: game, saveURL: storage.url)
    game = await NativePeopleTestFixture.capture(collector)
    let people = try #require(game.commander.nativePeople)
    game.energy = -100
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    let files = try ScriptFinanceTestFixture.files(storage.directory)
    try storage.blockWriter()
    let failed = await runtime.advance(delta: 0.05)
    #expect(failed.screen == .gameOver && failed.energy == 0)
    #expect(failed.commander.nativePeople == people && failed.commander.nativeCaptiveCount == 1)
    #expect(!failed.commander.ordinaryCommodityAmounts.contains { $0.commodity == .slaves })
    #expect(try ScriptFinanceTestFixture.files(storage.backup) == files)
    try storage.restoreWriter()
    try await runtime.save(to: storage.url)
    let saved = await runtime.snapshot()
    #expect(saved.commander.nativePeople?.held.isEmpty == true)
    #expect(saved.commander.nativePeople?.transfers.last?.kind == .loss)
    #expect(saved.commander.nativePeople?.admissions == people.admissions)
    #expect(saved.commander.cargo[3] == 0 && saved.commander.valid)
    try await runtime.save(to: storage.url)
    #expect(await runtime.snapshot().commander.nativePeople?.transfers.count == 1)
  }
}

extension GameRuntime {
  func nativePeopleTestControls() -> Controls { controls }
}
