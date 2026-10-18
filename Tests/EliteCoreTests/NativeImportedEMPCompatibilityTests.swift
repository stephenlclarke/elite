import Foundation
import Testing

@testable import EliteCore

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
    #expect(loaded.commander == saved.commander && loaded.bodies == saved.bodies)
    #expect(nativeEMPHulls(loaded, source: source).count == 1)
    let observedFileBytes = try Data(contentsOf: file)
    #expect(observedFileBytes == bytes)
  }
}
