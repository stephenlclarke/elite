import Foundation
import Testing

@testable import EliteCore

private func relocateWreckObserver(_ game: inout Game, to position: Vector3) {
  let old = game.commander.flightSimulation.pose
  let translation = old.shipVector(position - old.position)
  game.commander.flightSimulation.pose.position = position
  for index in game.bodies.indices {
    game.bodies[index].position = game.bodies[index].position - translation
  }
  for index in game.celestials.indices {
    game.celestials[index].position = game.celestials[index].position - translation
  }
}

private func salvageWorldGame() throws -> (Game, SalvageSite) {
  // Pick a genuinely generated site; the runtime must not depend on a hand-built wreck.
  for system in 0..<256 {
    var game = Game(executive: false)
    game.commander.system = system
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    game.speed = 0
    game.bodies = []
    game.commander.npcPersistence = .init()
    guard let site = game.salvageSites.first,
      let anchors = game.commander.flightSimulation.anchors,
      let profile = SalvageCatalogue.profile(catalogueShipID: site.catalogueShipID)
    else { continue }
    let offset = profile.bounds.radius + profile.bounds.center.length + 2000
    let directions = [
      Vector3(0, 0, 1), .init(0, 0, -1), .init(1, 0, 0), .init(-1, 0, 0), .init(0, 1, 0),
      .init(0, -1, 0),
    ]
    let observers: [Vector3] = directions.map { direction -> Vector3 in
      let displacement: Vector3 = direction * offset
      return site.position + displacement
    }
    let observer: Vector3? = observers.first { position -> Bool in
      let planetDistance: Double = (position - anchors.planet.position).length
      guard planetDistance > anchors.planet.radius * 2 else { return false }
      let sunDistance: Double = (position - anchors.sun.position).length
      guard sunDistance > anchors.sun.radius * 4 else { return false }
      let stationDistance: Double = (position - anchors.station.position).length
      return stationDistance > 1200
    }
    guard let observer else { continue }
    relocateWreckObserver(&game, to: observer)
    game.activateNearbySalvageSites()
    guard game.bodies.contains(where: { $0.physical?.salvage?.wreck == site.identity }) else {
      continue
    }
    return (game, site)
  }
  throw SaveError.invalidCommander
}

private func actualWreckHit(_ game: inout Game, id: Int, damage: Double) throws {
  let body = try #require(game.bodies.first { $0.id == id })
  let player = try #require(game.commander.flightSimulation.player)
  let allocated = game.makeAttackOrigin(owner: player)
  let origin = try #require(allocated)
  let hit = GameplayHit(target: .body(id), distance: body.position.length, point: body.position)
  let incident = game.applyCombatHit(
    hit, origin: origin, kind: .laser, damage: damage, laser: .pulse)
  #expect(incident != nil)
  game.commander.crimeLedger.finishEmission(origin.emissionID)
}

struct SalvageWorldRuntimeTests {
  @Test func noOpPosePersistenceDockingAndSavingKeepTheAbsentLedgerAbsent() async throws {
    var game = Game(executive: false)
    try NativeSaveTestFixture.prepareCurrentPolicy(&game)
    game.screen = .status
    let before = game.commander
    #expect(game.commander.savedSalvageLedger == nil)
    let unchanged = game.persistSalvagePoses()
    #expect(unchanged && game.commander == before)
    game.dock()
    #expect(game.commander == before && game.commander.savedSalvageLedger == nil)
    let runtime = GameRuntime(game: game)
    let ready = await runtime.snapshot()
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    try await runtime.save(to: url)
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: url)
    #expect(saved == ready.commander && saved.savedSalvageLedger == nil)
    #expect(await runtime.snapshot().commander == ready.commander)
    game.commander.salvageLedger = .init()
    let explicitEmpty = game.commander
    let retainedEmpty = game.persistSalvagePoses()
    #expect(retainedEmpty && game.commander == explicitEmpty)
    #expect(game.commander.savedSalvageLedger != nil)
  }

  @Test func changedActualWreckPoseStillPublishesAndAnIdenticalCaptureIsIdempotent() throws {
    var (game, site) = try salvageWorldGame()
    let index = try #require(
      game.bodies.firstIndex { $0.physical?.salvage?.wreck == site.identity })
    let legacyBefore = game.commander.salvageLedger
    let nativeBefore = try #require(
      game.commander.alienStorageState?.current.salvage.native.wrecks[site.identity])
    #expect(nativeBefore.source == .generated(site))
    game.bodies[index].position = game.bodies[index].position + .init(11, -7, 3)
    game.bodies[index].physical?.velocity = .init(1, 2, 3)
    game.bodies[index].physical?.angularVelocity = .init(0.01, 0.02, 0.03)
    game.bodies[index].energy -= 1
    let body = game.bodies[index]
    let expected = SalvageWreckMotion(
      pose: game.modelPose(of: body), velocity: .init(1, 2, 3),
      angularVelocity: .init(0.01, 0.02, 0.03), energy: body.energy)
    let accepted = game.persistSalvagePoses()
    #expect(accepted)
    let updated = try #require(
      game.commander.alienStorageState?.current.salvage.native.wrecks[site.identity])
    #expect(updated.id == nativeBefore.id && updated.identity == nativeBefore.identity)
    #expect(updated.binding == nativeBefore.binding && updated.owner == nativeBefore.owner)
    #expect(updated.motion == expected)
    #expect(game.commander.salvageLedger == legacyBefore)
    #expect(game.commander.salvageLedger.wreckMotion(for: site.identity) == nil)
    let published = game.commander
    let repeated = game.persistSalvagePoses()
    #expect(repeated && game.commander == published)
  }

  @Test func generatedSiteRetainsCanonicalDriftSpinAndDamageThroughCullAndRealSaveReload()
    async throws
  {
    var (game, site) = try salvageWorldGame()
    let body = try #require(game.bodies.first { $0.physical?.salvage?.wreck == site.identity })
    let firstActor = try #require(body.physical?.identity)
    let legacyBefore = game.commander.salvageLedger
    let nativeBefore = try #require(
      game.commander.alienStorageState?.current.salvage.native.wrecks[site.identity])
    try #require(nativeBefore.source == .generated(site) && nativeBefore.binding == firstActor)
    #expect(body.physical?.population == .wreck && body.rotationRate == 0 && body.missiles == 0)
    let before = game.modelPose(of: body)
    try actualWreckHit(&game, id: body.id, damage: 17)
    let remaining = try #require(game.bodies.first { $0.id == body.id }?.energy)
    game.tick(delta: 0.1)
    let moved = try #require(game.bodies.first { $0.id == body.id })
    let pose = game.modelPose(of: moved)
    let rotation = RelativeWorkController.rotated(
      before.orientation, omega: site.angularVelocity, delta: 0.1)
    #expect((pose.position - before.position - site.velocity * 0.1).length < 1e-8)
    #expect(
      (pose.orientation.x - rotation.x).length < 1e-10
        && (pose.orientation.y - rotation.y).length < 1e-10)
    let observed = try #require(game.nativeSalvageWreckMotion[site.identity])
    #expect(
      observed.actor == firstActor && observed.time == game.commander.flightSimulation.physicalTime)
    #expect(observed.motion.energy == remaining && observed.motion.pose == pose)
    #expect(game.commander.salvageLedger == legacyBefore)
    let observer = game.commander.flightSimulation.pose.position
    relocateWreckObserver(&game, to: observer + .init(50000, 0, 0))
    game.tick(delta: 0.02)
    #expect(!game.bodies.contains { $0.physical?.identity == firstActor })
    let parked = try #require(
      game.commander.alienStorageState?.current.salvage.native.wrecks[site.identity])
    #expect(parked.id == nativeBefore.id && parked.owner == nativeBefore.owner)
    #expect(parked.identity == site.identity && parked.binding == nil && parked.destroyedAt == nil)
    let savedMotion = parked.motion
    #expect(savedMotion.energy == remaining && game.commander.salvageLedger == legacyBefore)
    relocateWreckObserver(&game, to: observer)
    game.activateNearbySalvageSites()
    let returned = try #require(game.bodies.first { $0.physical?.salvage?.wreck == site.identity })
    #expect(returned.physical?.identity != firstActor && returned.energy == remaining)
    #expect((game.modelPose(of: returned).position - savedMotion.pose.position).length < 1e-8)
    #expect(
      (game.modelPose(of: returned).orientation.x - savedMotion.pose.orientation.x).length < 1e-10)
    let rebound = try #require(
      game.commander.alienStorageState?.current.salvage.native.wrecks[site.identity])
    #expect(rebound.id == nativeBefore.id && rebound.binding == returned.physical?.identity)
    let runtime = GameRuntime(game: game)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    try await runtime.save(to: url)
    try await runtime.load(from: url, persistMigrations: false)
    let restored = await runtime.snapshot()
    let restoredWreck = try #require(
      restored.commander.alienStorageState?.current.salvage.native.wrecks[site.identity])
    #expect(restoredWreck.id == nativeBefore.id && restoredWreck.owner == nativeBefore.owner)
    #expect(restoredWreck.motion.energy == remaining && restoredWreck.motion == rebound.motion)
    #expect(restored.commander.salvageLedger == legacyBefore)
    var relaunched = Game(executive: false)
    relaunched.commander = restored.commander
    relaunched.launch()
    relaunched.bodies = []
    relaunched.commander.npcPersistence = .init()
    relocateWreckObserver(&relaunched, to: observer)
    relaunched.activateNearbySalvageSites()
    let reloaded = try #require(
      relaunched.bodies.first { $0.physical?.salvage?.wreck == site.identity })
    #expect(reloaded.energy == remaining && reloaded.rotationRate == 0)
    #expect((relaunched.modelPose(of: reloaded).position - savedMotion.pose.position).length < 1e-8)
  }

  @Test func destroyingAnActualAbandonedSiteMarksTerminalWithoutLivingShipCrimeOrKillCredit()
    async throws
  {
    var (game, site) = try salvageWorldGame()
    let body = try #require(game.bodies.first { $0.physical?.salvage?.wreck == site.identity })
    let nativeBefore = try #require(
      game.commander.alienStorageState?.current.salvage.native.wrecks[site.identity])
    #expect(nativeBefore.source == .generated(site))
    let legacyBefore = game.commander.salvageLedger
    let cash = game.commander.credits
    let kills = game.commander.kills
    let legal = game.commander.legal
    try actualWreckHit(&game, id: body.id, damage: 100000)
    game.resolveDestroyed()
    let terminal = try #require(
      game.commander.alienStorageState?.current.salvage.native.wrecks[site.identity])
    #expect(terminal.id == nativeBefore.id && terminal.identity == site.identity)
    #expect(terminal.destroyedAt != nil && terminal.motion.energy.map { $0 <= 0 } == true)
    #expect(terminal.binding == nil && game.commander.salvageLedger == legacyBefore)
    #expect(!game.bodies.contains { $0.id == body.id })
    #expect(
      game.commander.credits == cash && game.commander.kills == kills
        && game.commander.legal == legal)
    let snapshot = try #require(game.commander.alienStorageState?.current.snapshot)
    game.activateNearbySalvageSites()
    #expect(!game.bodies.contains { $0.physical?.salvage?.wreck == site.identity })
    #expect(game.commander.alienStorageState?.current.snapshot == snapshot)
    let folder = try NativePagedSalvageFixture.folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let decoded = try NativeSaveTestFixture.readVersionedCommander(from: file)
    let restored = try #require(
      decoded.alienStorageState?.current.salvage.native.wrecks[site.identity])
    #expect(restored.id == terminal.id && restored.destroyedAt == terminal.destroyedAt)
    #expect(restored.motion == terminal.motion && restored.binding == nil)
    #expect(decoded.salvageLedger == legacyBefore)
  }

  @Test func failedTerminalMarkRetainsTheActualSourceAndRefusesDockSaveAndBothJumpPaths()
    async throws
  {
    var (game, site) = try salvageWorldGame()
    let index = try #require(
      game.bodies.firstIndex { $0.physical?.salvage?.wreck == site.identity })
    var encoded = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(game.commander.salvageLedger))
        as? [String: Any])
    encoded["revision"] = UInt64.max
    game.commander.salvageLedger = try JSONDecoder().decode(
      SalvageLedger.self, from: JSONSerialization.data(withJSONObject: encoded))
    try game.commander.grantEquipment(
      "Galactic Hyperdrive", at: .utility(.galacticHyperdrive), provenance: .grant("fixture"))
    game.bodies[index].energy = 0
    game.resolveDestroyed()
    #expect(
      game.hasUnsettledWreckDeaths && !game.commander.salvageLedger.isWreckDestroyed(site.identity))
    let before = game.commander
    game.dock()
    #expect(!game.docked && game.commander == before)
    game.arrive()
    #expect(game.commander == before && game.hasUnsettledWreckDeaths)
    game.galacticJump()
    #expect(game.commander == before && game.commander.equipment.contains("Galactic Hyperdrive"))
    let runtime = GameRuntime(game: game)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    var refused = false
    do { try await runtime.save(to: url) } catch { refused = true }
    #expect(refused && !FileManager.default.fileExists(atPath: url.path))
    #expect(await runtime.snapshot().commander == before)
  }

  @Test func occupiedOrClaimedPhysicalHullsKeepTheirOrdinaryCrimeProtection() throws {
    for ownership in [SalvageOwnership.claimed, .occupied] {
      var (game, site) = try salvageWorldGame()
      let index = try #require(
        game.bodies.firstIndex { $0.physical?.salvage?.wreck == site.identity })
      let old = try #require(game.bodies[index].physical?.salvage)
      game.bodies[index].physical?.salvage = .init(
        category: old.category, ownership: ownership, claimant: nil, wreck: old.wreck,
        section: nil, lot: nil, bounds: old.bounds, workSurfaces: old.workSurfaces)
      let legal = game.commander.legal
      try actualWreckHit(&game, id: game.bodies[index].id, damage: 1)
      #expect(game.commander.legal > legal)
    }
  }
}

extension SalvageWorldRuntimeTests {
  @Test(arguments: [false, true])
  func actualSurvivingDamageIsCapturedBeforeEitherDepartureWithoutAnotherTick(galactic: Bool) throws
  {
    var (game, site) = try salvageWorldGame()
    let originalSystem = game.commander.system
    let originalGalaxy = game.commander.galaxy
    let observer = game.commander.flightSimulation.pose.position
    let body = try #require(game.bodies.first { $0.physical?.salvage?.wreck == site.identity })
    if galactic {
      try game.commander.grantEquipment(
        "Galactic Hyperdrive", at: .utility(.galacticHyperdrive), provenance: .grant("fixture"))
    }
    try actualWreckHit(&game, id: body.id, damage: 17)
    let remaining = try #require(game.bodies.first { $0.id == body.id }?.energy)
    #expect(game.commander.salvageLedger.wreckMotion(for: site.identity)?.energy != remaining)
    if galactic {
      game.galacticJump()
      #expect(
        game.commander.galaxy != originalGalaxy
          && !game.commander.equipment.contains("Galactic Hyperdrive"))
    } else {
      let destination = try #require(
        game.knownSystems.first {
          $0.id != originalSystem
            && game.currentSystem.distance(to: $0) <= game.commander.maximumJumpDistance
        })
      game.selectedSystem = destination.id
      game.arrive()
      #expect(game.commander.system == destination.id)
    }
    #expect(game.commander.salvageLedger.wreckMotion(for: site.identity)?.energy == remaining)
    var returned = Game(executive: false)
    returned.commander = game.commander
    returned.commander.system = originalSystem
    returned.commander.galaxy = originalGalaxy
    returned.launch()
    returned.bodies = []
    relocateWreckObserver(&returned, to: observer)
    returned.activateNearbySalvageSites()
    let restored = try #require(
      returned.bodies.first { $0.physical?.salvage?.wreck == site.identity })
    #expect(restored.energy == remaining)
  }

  @Test func invalidLiveSnapshotCannotPublishPartialMotionOrConsumeTheGalacticDrive() async throws {
    var (game, site) = try salvageWorldGame()
    try game.commander.grantEquipment(
      "Galactic Hyperdrive", at: .utility(.galacticHyperdrive), provenance: .grant("fixture"))
    let index = try #require(
      game.bodies.firstIndex { $0.physical?.salvage?.wreck == site.identity })
    game.bodies[index].physical?.angularVelocity = .init(.infinity, 0, 0)
    let before = game.commander
    let stored = game.persistSalvagePoses()
    #expect(!stored && game.commander == before)
    game.dock()
    #expect(!game.docked && game.commander == before)
    game.arrive()
    #expect(game.commander == before)
    game.galacticJump()
    #expect(game.commander == before && game.commander.equipment.contains("Galactic Hyperdrive"))
    let runtime = GameRuntime(game: game)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    var refused = false
    do { try await runtime.save(to: url) } catch { refused = true }
    #expect(refused && !FileManager.default.fileExists(atPath: url.path))
    #expect(await runtime.snapshot().commander == before)
  }

  @Test func optionalWreckHealthMigratesOldRecordsAndRejectsInvalidLiveHealth() throws {
    let (game, site) = try salvageWorldGame()
    let initial = try #require(game.commander.salvageLedger.wreckMotion(for: site.identity))
    var fields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(initial)) as? [String: Any])
    fields.removeValue(forKey: "energy")
    let legacy = try JSONDecoder().decode(
      SalvageWreckMotion.self, from: JSONSerialization.data(withJSONObject: fields))
    #expect(legacy.energy == nil && legacy.pose == initial.pose)
    var ledger = game.commander.salvageLedger
    for energy in [0, -1, Double.infinity, Double.nan, 100001] {
      let before = ledger
      let accepted = ledger.updateWreck(
        identity: site.identity,
        motion: .init(
          pose: initial.pose, velocity: initial.velocity, angularVelocity: initial.angularVelocity,
          energy: energy))
      #expect(!accepted && ledger == before)
    }
  }
}
