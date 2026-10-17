import Foundation
import Testing

@testable import EliteCore

private func foodInSalvage(_ game: Game, wreck: WreckIdentity) -> Int {
  game.commander.salvageLedger.pendingLots.filter { $0.identity.section.wreck == wreck }.reduce(0) {
    total, lot in
    guard case .commodity(let amount)? = lot.loot?.content, amount.commodity == .food else {
      return total
    }
    return total + amount.quantity
  }
}

struct EMPSalvageTests {
  @Test func actualEjectionPermitsSameHullCuttingAndCargoCannotRollAgainAfterDeathOrReload()
    async throws
  {
    var game = try empFixture()
    game.bodies[0].physical?.velocity = .init(0, 0, 0)
    game.bodies[0].physical?.angularVelocity = .init(0, 0, 0)
    let actor = try #require(game.bodies[0].physical?.identity)
    let catalogue = try #require(game.bodies[0].physical?.catalogueShipID)
    try #require(game.fireEMPPirateBlaster())
    let source = try #require(game.bodies[0].physical?.empSource)
    #expect(!game.fireSalvageCutter(delta: 0.1))
    for _ in 0..<30 { game.tick(delta: 0.1) }
    let record = try #require(game.commander.savedEMPState?.records[source])
    try #require(record.crewAboard == 0 && record.pods.count == record.crewTotal)
    var index = try #require(game.bodies.firstIndex { $0.physical?.empSource == source })
    #expect(
      game.bodies[index].physical?.identity == actor
        && game.bodies[index].physical?.catalogueShipID == catalogue)
    let profile = try #require(game.salvageProfile(for: game.bodies[index]))
    let section = try #require(profile.sections.first { $0.kind == .cargo })
    // Place the actual hull's cargo face in the real cutter ray, preserving its identity and zero drift.
    let forward = section.normal.unit * -1
    let cardinal = abs(forward.y) < 0.8 ? Vector3(0, 1, 0) : .init(1, 0, 0)
    var frame = Basis3()
    frame.z = forward
    frame.x = cardinal.cross(forward).unit
    frame.y = forward.cross(frame.x).unit
    let orientation = frame.transposed
    game.bodies[index].orientation = orientation
    game.bodies[index].position = Vector3(0, 0, 200) - orientation.apply(section.localPosition)
    game.bodies[index].rotation = 0
    game.bodies[index].rotationRate = 0
    try #require(game.persistSalvagePoses())
    let hit = try #require(
      GameplayRaycast.nearest(
        origin: .init(0, 0, 0), direction: .init(0, 0, 1),
        maxDistance: 300, bodies: game.bodies, meshOverrides: game.gameplayMeshOverrides))
    try #require(
      hit.target == .body(game.bodies[index].id) && (hit.point - .init(0, 0, 200)).length < 1e-6)
    let identity = WreckSectionIdentity(wreck: record.wreck, section: section.index)
    for _ in 0..<400 where !game.commander.salvageLedger.isDepleted(identity) {
      _ = game.fireSalvageCutter(delta: 0.1)
      game.tick(delta: 0.1)
    }
    try #require(game.commander.salvageLedger.isDepleted(identity))
    #expect(foodInSalvage(game, wreck: record.wreck) == 2)
    #expect(game.commander.cargo[CommodityIdentity.food.rawValue] == 0)
    let people = game.commander.savedEMPState?.records[source]?.pods.count
    for _ in 0..<50 {
      _ = game.fireSalvageCutter(delta: 0.1)
      game.tick(delta: 0.1)
    }
    #expect(foodInSalvage(game, wreck: record.wreck) == 2)
    #expect(game.commander.savedEMPState?.records[source]?.pods.count == people)
    let credits = game.commander.credits
    let kills = game.commander.kills
    index = try #require(game.bodies.firstIndex { $0.physical?.empSource == source })
    let player = try #require(game.commander.flightSimulation.player)
    let origin = try #require(game.makeAttackOrigin(owner: player))
    let target = game.bodies[index]
    _ = game.applyCombatHit(
      .init(target: .body(target.id), distance: target.position.length, point: target.position),
      origin: origin, kind: .laser, damage: target.energy + 1000)
    game.resolveDestroyed()
    #expect(!game.bodies.contains { $0.physical?.empSource == source })
    #expect(game.commander.savedEMPState?.records[source]?.terminal == true)
    #expect(game.commander.credits == credits && game.commander.kills == kills)
    #expect(foodInSalvage(game, wreck: record.wreck) == 2)
    #expect(game.commander.cargoDebrisLedger.pendingPayloads.isEmpty)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let restored = GameRuntime()
    try await restored.load(from: file, persistMigrations: false)
    for _ in 0..<20 { _ = await restored.advance(delta: 0.1) }
    let loaded = await restored.snapshot()
    #expect(loaded.commander.savedEMPState?.records[source]?.terminal == true)
    #expect(!loaded.bodies.contains { $0.physical?.empSource == source })
    #expect(foodInSalvage(loaded, wreck: record.wreck) == 2)
    #expect(loaded.commander.savedEMPState?.records[source]?.pods.count == people)
  }

  @Test func occupiedPodsRemainPeopleAndCannotBeCutDamagedOrScoopedAsCargo() throws {
    var game = try empFixture()
    try #require(game.fireEMPPirateBlaster())
    for _ in 0..<30 { game.tick(delta: 0.1) }
    let podIndex = try #require(game.bodies.firstIndex { $0.physical?.empCrewPod != nil })
    let person = try #require(game.bodies[podIndex].physical?.empCrewPod)
    let podActor = try #require(game.bodies[podIndex].physical?.identity)
    let energy = game.bodies[podIndex].energy
    let cargo = game.commander.cargo
    let salvage = game.commander.salvageLedger
    game.bodies[podIndex].position = .init(0, -20, 50)
    game.scoopCargo()
    #expect(game.bodies.contains { $0.physical?.identity == podActor })
    #expect(game.commander.cargo == cargo && game.commander.salvageLedger == salvage)
    game.bodies[podIndex].position = .init(0, 0, 200)
    let player = try #require(game.commander.flightSimulation.player)
    let origin = try #require(game.makeAttackOrigin(owner: player))
    _ = game.applyCombatHit(
      .init(target: .body(game.bodies[podIndex].id), distance: 200, point: .init(0, 0, 200)),
      origin: origin, kind: .laser, damage: 10000)
    #expect(game.bodies[podIndex].energy == energy)
    #expect(!game.fireSalvageCutter(delta: 0.1))
    #expect(game.commander.savedEMPState?.records[person.source]?.pods.count == 1)
    #expect(game.commander.cargo == cargo && game.commander.salvageLedger == salvage)
  }

  @Test(arguments: [false, true])
  func lethalAttackRetainsExactDeceasedOrdinalsAndPreviouslyEjectedPeople(partial: Bool)
    async throws
  {
    var game = try empFixture(catalogue: "SH001")
    try #require(game.fireEMPPirateBlaster())
    let source = try #require(game.commander.savedEMPState?.records.keys.first)
    if partial {
      for _ in 0..<12 { game.tick(delta: 0.1) }
    }
    let before = try #require(game.commander.savedEMPState?.records[source])
    try #require(before.pods.count == (partial ? 1 : 0))
    let body = try #require(game.bodies.first { $0.physical?.empSource == source })
    let player = try #require(game.commander.flightSimulation.player)
    let origin = try #require(game.makeAttackOrigin(owner: player))
    _ = game.applyCombatHit(
      .init(target: .body(body.id), distance: body.position.length, point: body.position),
      origin: origin, kind: .laser, damage: 10000)
    game.resolveDestroyed()
    let dead = try #require(game.commander.savedEMPState?.records[source])
    #expect(dead.terminal && dead.valid && dead.crewAboard == 0)
    #expect(dead.lostCrewCount == dead.crewTotal - before.pods.count)
    #expect(dead.pods.count == before.pods.count)
    #expect(dead.hull.body.physical?.deathOrigin == origin)
    for ordinal in 0..<dead.crewTotal {
      #expect(
        dead.crewOutcome(ordinal: ordinal)
          == (ordinal < before.pods.count
            ? .occupiedPod : .deceasedWithHull))
    }
    let cargo = Set(game.commander.cargoDebrisLedger.pendingPayloads.map(\.identity))
    let kills = game.commander.kills
    let credits = game.commander.credits
    game.resolveDestroyed()
    for _ in 0..<40 { game.tick(delta: 0.1) }
    #expect(game.commander.savedEMPState?.records[source]?.lostCrewCount == dead.lostCrewCount)
    #expect(game.commander.savedEMPState?.records[source]?.pods.count == before.pods.count)
    #expect(Set(game.commander.cargoDebrisLedger.pendingPayloads.map(\.identity)) == cargo)
    #expect(game.commander.kills == kills && game.commander.credits == credits)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("commander.json")
    let writer = GameRuntime(game: game)
    try await writer.save(to: file)
    let reader = GameRuntime()
    try await reader.load(from: file, persistMigrations: false)
    for _ in 0..<40 { _ = await reader.advance(delta: 0.1) }
    let restored = await reader.snapshot()
    let retained = try #require(restored.commander.savedEMPState?.records[source])
    #expect(
      retained.lostCrewCount == dead.lostCrewCount
        && retained.deceasedOrdinals == dead.deceasedOrdinals)
    #expect(retained.pods.count == before.pods.count && retained.crewAboard == 0)
    #expect(!restored.bodies.contains { $0.physical?.empSource == source })
    #expect(restored.commander.kills == kills && restored.commander.credits == credits)
  }

  @Test func leavingAndReenteringTheSceneRebindsOneDisabledSourceAndItsOriginalPeople() throws {
    var game = try empFixture()
    try #require(game.fireEMPPirateBlaster())
    for _ in 0..<30 { game.tick(delta: 0.1) }
    try #require(game.persistSalvagePoses())
    let source = try #require(game.commander.savedEMPState?.records.keys.first)
    let original = try #require(game.commander.savedEMPState?.records[source])
    let cargo = original.cargo
    let legal = original.legal
    // Unload the physical scene through the same visit boundary used by native launch/arrival.
    // Move only the observer; retained world poses are the admission source, not regenerated fixtures.
    game.bodies = []
    game.beginGameplayVisit(arriving: false)
    game.celestials = []
    game.miningFields = []
    game.salvageSites = []
    game.commander.flightSimulation.pose.position = original.hull.body.position - .init(0, 0, 1000)
    game.advanceEMPActors()
    let restored = try #require(game.commander.savedEMPState?.records[source])
    let hulls = game.bodies.filter { $0.physical?.empSource == source }
    #expect(hulls.count == 1 && hulls[0].physical?.identity != original.hull.binding)
    #expect(game.isEMPDisabled(hulls[0]) && hulls[0].physical?.npc == nil)
    #expect(hulls[0].physical?.catalogueShipID == original.hull.body.physical?.catalogueShipID)
    #expect(hulls[0].physical?.velocity == original.hull.body.physical?.velocity)
    #expect(hulls[0].physical?.angularVelocity == original.hull.body.physical?.angularVelocity)
    #expect(restored.cargo == cargo && restored.legal == legal && restored.wreck == original.wreck)
    #expect(
      Set(game.bodies.compactMap { $0.physical?.empCrewPod })
        == Set(original.pods.compactMap { $0.body.physical?.empCrewPod }))
    game.advanceEMPActors()
    #expect(game.bodies.filter { $0.physical?.empSource == source }.count == 1)
    #expect(game.commander.savedEMPState?.records[source]?.pods.count == original.crewTotal)
  }
}
