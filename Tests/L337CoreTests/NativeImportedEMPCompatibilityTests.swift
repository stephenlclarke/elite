import Foundation
import Testing

@testable import L337Core

struct NativeImportedEMPCompatibilityTests {
  @Test func genuineImportedHumanEMPSourceParksAndRebindsOneActualHullWithoutOffscreenCoast()
    async throws
  {
    // The existing controlled release boundary proves custody compatibility only.
    // It is not the native Gallery's flight, acquisition or 800-frame acceptance proof.
    var game = try empFixture()
    let observedEMPRelease = try releaseDamagedEMPBoundary(&game)
    #expect(observedEMPRelease)
    let source = try #require(game.bodies.first?.physical?.empSource)
    try ejectScheduledEMPCrewBoundary(&game, source: source)
    let before = try #require(game.commander.savedEMPState?.records[source])
    #expect(before.crewAboard == 0 && before.lostCrewCount == 0)
    let body = try #require(game.bodies.first { $0.physical?.empSource == source })
    let profile = try #require(game.salvageProfile(for: body))
    #expect(!profile.sourceRoles.contains(.thargoid))
    var worked: WreckSectionIdentity?
    for section in profile.sections {
      let model = game.modelPose(of: body)
      let surface = model.systemPoint(section.localPosition)
      let normal = model.orientation.apply(section.normal).unit
      var orientation = Basis3()
      orientation.z = normal * -1
      let up = abs(orientation.z.y) < 0.8 ? Vector3(0, 1, 0) : .init(1, 0, 0)
      orientation.x = up.cross(orientation.z).unit
      orientation.y = orientation.z.cross(orientation.x).unit
      NativePagedSalvageFixture.moveObserver(
        &game, to: .init(position: surface + normal * 200, orientation: orientation))
      if game.fireSalvageCutter(delta: 0.1) {
        worked = .init(wreck: before.wreck, section: section.index)
        break
      }
    }
    let identity = try #require(worked)
    #expect(game.nativeSalvageWork == nil)
    #expect(game.commander.alienStorageState?.current.salvage.native.wrecks[before.wreck] == nil)
    let original = try game.commander.salvageLedger.exportNativeSection(identity)
    #expect(original.partialWork == 0.1 && original.plan.source.manifest == before.salvageCargo)
    let imported = try NativeSalvageImport(
      ledger: game.commander.salvageLedger, section: identity,
      owner: try #require(game.commander.equipmentOwnerID),
      at: game.commander.flightSimulation.physicalTime,
      previous: game.commander.alienStorageState?.current.snapshot)
    try imported.apply(to: &game.commander)
    let observedCutterResult = game.fireSalvageCutter(delta: 0.1)
    #expect(observedCutterResult)
    let hot = try #require(game.nativeSalvageWork)
    #expect(hot.cycle.inspection == .legacy(imported.section))
    #expect(hot.cycle.currentWorkSeconds == 0.2 && hot.cycle.releases == 0)
    // A mismatched, still-bound archive must not publish either half of parking
    // or remove the actual body. The original state continues through the real cull.
    let capturedArchive = game.persistEMPState()
    #expect(capturedArchive)
    var mismatched = game
    let originalArchivePosition = try #require(
      mismatched.commander.savedEMPState?.records[source]?.hull.body.position)
    mismatched.commander.savedEMPState?.records[source]?.hull.body.position =
      originalArchivePosition + .init(1, 0, 0)
    #expect(mismatched.commander.valid)
    let mismatchedCommander = mismatched.commander
    let mismatchedBodies = mismatched.bodies
    let observedBody = try #require(mismatched.bodies.first { $0.physical?.identity == hot.actor })
    let observedMismatch = mismatched.observeNativeSalvageWreck(observedBody)
    let refusedPark = mismatched.flushNativeSalvageWrecks(parking: [hot.actor])
    #expect(observedMismatch && !refusedPark)
    #expect(mismatched.commander == mismatchedCommander && mismatched.bodies == mismatchedBodies)
    #expect(mismatched.nativeSalvageWork?.cycle == hot.cycle)
    #expect(mismatched.commander.savedEMPState?.records[source]?.hull.binding == hot.actor)
    #expect(
      mismatched.commander.alienStorageState?.current.salvage.native.wrecks[before.wreck]?.binding
        == hot.actor)
    let oldCrew = Set(before.pods.compactMap { $0.body.physical?.empCrewPod })
    let observer = game.commander.flightSimulation.pose
    NativePagedSalvageFixture.moveObserver(
      &game,
      to: .init(position: observer.position + .init(50000, 0, 0), orientation: observer.orientation)
    )
    game.tick(delta: 0.02)
    let parked = try #require(
      game.commander.alienStorageState?.current.salvage.native.wrecks[before.wreck])
    let archive = try #require(game.commander.savedEMPState?.records[source])
    #expect(parked.binding == nil && archive.hull.binding == nil)
    #expect(!game.bodies.contains { $0.physical?.empSource == source })
    #expect((archive.hull.body.position - parked.motion.pose.position).length < 1e-8)
    for _ in 0..<20 { game.tick(delta: 0.1) }
    let coasted = try #require(game.commander.savedEMPState?.records[source])
    #expect(coasted.hull == archive.hull)
    #expect(game.commander.alienStorageState?.current.salvage.native.wrecks[before.wreck] == parked)
    NativePagedSalvageFixture.moveObserver(&game, to: observer)
    game.advanceEMPActors()
    let returned = nativeEMPHulls(game, source: source)
    #expect(returned.count == 1)
    let actual = try #require(returned.first)
    let bound = try #require(game.commander.savedEMPState?.records[source])
    let native = try #require(
      game.commander.alienStorageState?.current.salvage.native.wrecks[before.wreck])
    #expect(actual.physical?.identity == bound.hull.binding && native.binding == bound.hull.binding)
    let actualPose = game.modelPose(of: actual)
    #expect((actualPose.position - parked.motion.pose.position).length < 1e-8)
    #expect((actualPose.orientation.x - parked.motion.pose.orientation.x).length < 1e-8)
    #expect((actualPose.orientation.y - parked.motion.pose.orientation.y).length < 1e-8)
    #expect((actualPose.orientation.z - parked.motion.pose.orientation.z).length < 1e-8)
    #expect(actual.physical?.velocity == parked.motion.velocity)
    #expect(actual.physical?.angularVelocity == parked.motion.angularVelocity)
    #expect(actual.energy == parked.motion.energy)
    #expect(bound.salvageCargo == before.salvageCargo && bound.salvageLegal == before.salvageLegal)
    #expect(Set(bound.pods.compactMap { $0.body.physical?.empCrewPod }) == oldCrew)
    expectOriginalEMPCrewConserved(bound)
    #expect(
      game.commander.alienStorageState?.current.salvage.native.works[imported.section]?
        .currentWorkSeconds == 0.2)
    #expect(game.commander.alienStorageState?.current.snapshot.sources.isEmpty == true)
    try NativeSaveTestFixture.prepareCurrentPolicy(&game)
    let folder = try NativePagedSalvageFixture.folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let saved = await runtime.snapshot()
    let bytes = try Data(contentsOf: file)
    try await runtime.load(from: file, persistMigrations: false)
    let loaded = await runtime.snapshot()
    // Cold restoration gives the retained source station fresh live addresses. Derive
    // exactly those addresses from the saved cursors; all other fields remain equal.
    let stationIndex = try #require(saved.bodies.firstIndex { $0.nativeStationIdentity != nil })
    try #require(saved.bodies.filter { $0.nativeStationIdentity != nil }.count == 1)
    let station = try #require(saved.bodies[stationIndex].nativeStationIdentity)
    let flight = saved.commander.flightSimulation
    let actor = ActorIdentity(
      system: saved.systemIdentity, visit: flight.visit, entity: flight.nextActor)
    let spawn = SpawnIdentity(
      system: saved.systemIdentity, visit: flight.visit, sequence: flight.nextSpawn,
      member: 0, producer: .mission)
    func object<T: Encodable>(_ value: T) throws -> [String: Any] {
      try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    }
    var expectedCommander = saved.commander
    var expectedBodies = saved.bodies
    var expectedFlight = try object(flight)
    expectedFlight["nextActor"] = flight.nextActor + 1
    expectedFlight["nextSpawn"] = flight.nextSpawn + 1
    expectedCommander.flightSimulation = try JSONDecoder().decode(
      FlightSimulationState.self, from: JSONSerialization.data(withJSONObject: expectedFlight))
    var expectedPhysical = try object(#require(expectedBodies[stationIndex].physical))
    expectedPhysical["identity"] = try object(actor)
    expectedPhysical["spawnIdentity"] = try object(spawn)
    expectedBodies[stationIndex].id = saved.nextBodyID
    expectedBodies[stationIndex].physical = try JSONDecoder().decode(
      PhysicalActorState.self, from: JSONSerialization.data(withJSONObject: expectedPhysical))
    let world = try #require(saved.commander.nativeStations)
    let recordIndex = try #require(world.ledger.records.firstIndex { $0.identity == station })
    var expectedLedger = try object(world.ledger)
    var records = try #require(expectedLedger["records"] as? [[String: Any]])
    records[recordIndex]["binding"] = try object(
      NativeStationBinding(actor: actor, bodyID: saved.nextBodyID))
    expectedLedger["records"] = records
    expectedCommander.nativeStations?.ledger = try JSONDecoder().decode(
      NativeStationLedger.self, from: JSONSerialization.data(withJSONObject: expectedLedger))
    #expect(loaded.commander == expectedCommander && loaded.bodies == expectedBodies)
    #expect(loaded.nextBodyID == saved.nextBodyID + 1)
    #expect(nativeEMPHulls(loaded, source: source).count == 1)
    let observedFileBytes = try Data(contentsOf: file)
    #expect(observedFileBytes == bytes)
  }
}
