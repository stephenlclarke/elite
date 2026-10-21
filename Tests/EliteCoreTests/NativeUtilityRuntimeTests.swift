import Foundation
import Testing

@testable import EliteCore

/// Controlled source/target scene initialization, not evidence of flying the quoted route.
/// Every successful service still crosses an actual main/RRS native docking boundary.
struct NativeUtilityRuntimeFixture {
  let flight: OriginalSealedDispatchFixture
  var files: ScriptFreightFixture { flight.files }
  var save: URL { files.save }
  init() throws { flight = try OriginalSealedDispatchFixture() }
  func source(escapeReady: Bool = false) async throws -> GameRuntime {
    try await flight.runtime(escapeReady: escapeReady, defaults: true)
  }
  private func launched(from before: consuming Game, system: Int) throws -> Game {
    var game = before
    if game.commander.system != system { try game.departOrdinarySimulation() }
    game.commander.nativeStations?.ledger.depart()
    game.commander.nativeStations?.currentMainDock = nil
    game.invalidateNativeStationAuthority()
    game.commander.system = system
    game.selectedSystem = system
    game.screen = .status
    game.docked = true
    game.dockedAtMainStation = true
    game.commander.fuel = game.commander.fuelCapacity
    game.launch()
    try #require(!game.docked && game.commander.valid)
    return game
  }
  func target(from runtime: GameRuntime) async throws -> GameRuntime {
    var game = try launched(from: await runtime.snapshot(), system: 237)
    let utility = try #require(game.commander.nativeUtility)
    let saved = try #require(game.commander.nativeStations?.pose(for: utility.target))
    let orientation = try #require(
      saved.orientation(at: game.commander.flightSimulation.physicalTime))
    let port = NativeStationGeometry.headquarters.docking
    var pose = ShipPose()
    pose.position = saved.position + orientation.apply(port.center + port.outward)
    pose.orientation.y = orientation.apply(port.up)
    pose.orientation.z = orientation.apply(port.outward) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 2
    let target = GameRuntime(game: game, saveURL: save)
    let arrived = await target.advance(delta: 0.1)
    try #require(arrived.docked && !arrived.dockedAtMainStation)
    try #require(arrived.nativeUtilityServiceContext != nil && arrived.commander.valid)
    return target
  }
  func source(from runtime: GameRuntime) async throws -> GameRuntime {
    let game = try launched(from: await runtime.snapshot(), system: 7)
    let source = GameRuntime(game: game, saveURL: save)
    try await flight.dock(source)
    try #require(await source.snapshot().nativeMainStationDockEvidenceIsCurrent)
    return source
  }
  func reloaded(_ runtime: GameRuntime) async throws -> GameRuntime {
    let before = await runtime.snapshot().commander
    try await runtime.save(to: save)
    let saved = await runtime.snapshot()
    var expected = saved.commander
    #expect(expected.nativeUtility == before.nativeUtility)
    // Predict only documented live RRS scene-address replacement, before reading the save.
    // All logical property, original material, receipt and ordinary actor state stays exact.
    let stations = saved.bodies.indices.filter { saved.bodies[$0].nativeStationIdentity != nil }
    var expectedBodies = saved.bodies
    if !stations.isEmpty {
      var flight = expected.flightSimulation
      var world = try #require(expected.nativeStations)
      let allocatedSpawn = flight.allocateSpawn()
      let sequence = try #require(allocatedSpawn)
      for (member, index) in stations.enumerated() {
        var body = saved.bodies[index]
        let station = try #require(body.nativeStationIdentity)
        let physical = try #require(body.physical)
        let allocatedActor = flight.allocateActor()
        let actor = try #require(allocatedActor)
        body.id = saved.nextBodyID + member
        body.physical = .init(
          identity: actor, population: physical.population, npc: physical.npc,
          velocity: physical.velocity, laserCooldown: physical.laserCooldown,
          rock: physical.rock, payload: physical.payload, attackOrigin: physical.attackOrigin,
          emissionPosition: physical.emissionPosition, deathOrigin: physical.deathOrigin,
          deathIncidentID: physical.deathIncidentID, ordnance: physical.ordnance,
          spawnIdentity: .init(
            system: saved.systemIdentity, visit: flight.visit,
            sequence: sequence, member: UInt16(member), producer: .mission),
          blocksNavalEncounter: physical.blocksNavalEncounter,
          catalogueShipID: physical.catalogueShipID, angularVelocity: physical.angularVelocity,
          canonicalSpin: physical.canonicalSpin, salvage: physical.salvage,
          empSource: physical.empSource, empCrewPod: physical.empCrewPod,
          suspendedNPCIntention: physical.suspendedNPCIntention)
        expectedBodies[index] = body
        try world.ledger.rebind(station, to: .init(actor: actor, bodyID: body.id))
      }
      expected.flightSimulation = flight
      expected.nativeStations = world
    }
    let loaded = GameRuntime()
    let errors = await loaded.loadDefaultScriptPacks(
      directory: files.root.appendingPathComponent("installed"))
    try #require(errors.isEmpty)
    try await loaded.load(from: save, persistMigrations: false)
    let restored = await loaded.snapshot()
    #expect(restored.commander == expected)
    if !stations.isEmpty {
      #expect(restored.bodies == expectedBodies)
      #expect(restored.nextBodyID == saved.nextBodyID + stations.count)
    }
    return loaded
  }
  func recharge(_ input: consuming Game, expected: Double) throws {
    var game = input
    game.launch()
    let index = try #require(
      game.bodies.firstIndex {
        guard let identity = $0.nativeStationIdentity else { return false }
        return NativeUtilityState.isTarget(identity)
      })
    try #require(game.nativeStationBodyIsCurrent(game.bodies[index]))
    game.bodies[index].energy -= 200
    let before = game.bodies[index].energy
    game.advanceNativeStationRecharge(delta: 0.1)
    #expect(abs(game.bodies[index].energy - before - expected / 10) < 0.00001)
    let after = game.bodies[index].energy
    game.advanceNativeStationRecharge(delta: 0)
    #expect(game.bodies[index].energy == after)
  }
  func refusedWrite(_ runtime: GameRuntime, quote: NativeUtilityQuote, label: String) async throws {
    let before = await runtime.snapshot()
    let disk = try ScriptFinanceTestFixture.files(save.deletingLastPathComponent())
    let blocked = try files.blockWrites(label)
    await #expect(throws: (any Error).self) { try await runtime.confirmNativeUtility(quote) }
    let refused = await runtime.snapshot()
    #expect(refused.commander == before.commander && refused.bodies == before.bodies)
    #expect(refused.nativeUtilityServiceContext == before.nativeUtilityServiceContext)
    try files.restoreWrites(blocked, files: disk)
  }
}

struct NativeUtilityRuntimeTests {

  @Test func nativeBoardReviewDefaultsBackAndRequiresSeparateConfirmedCollection() async throws {
    let f = try NativeUtilityRuntimeFixture()
    defer { f.files.clean() }
    let runtime = try await f.source()
    await runtime.key("contracts-open")
    let board = await runtime.snapshot()
    try #require(board.screen == .contracts)
    let index = try #require(board.contractBoard.rows.firstIndex { $0.utility == .collect })
    for _ in 0..<index { await runtime.key("down") }
    await runtime.key("return")
    let review = await runtime.snapshot()
    #expect(review.contractBoard.detail && review.contractBoard.action == .back)
    #expect(
      Display.contractDetailRows(review, width: 1000).joined(separator: " ").lowercased().contains(
        "frozen payment"))
    let before = review.commander
    await runtime.key("return")
    #expect(await runtime.snapshot().commander == before)
    #expect(await runtime.snapshot().contractBoard.utilityQuote?.quote == nil)
    await runtime.key("return")
    await runtime.key("right")
    await runtime.key("return")
    let collected = await runtime.snapshot()
    #expect(collected.commander.nativeUtility?.heldTonnes == 4)
    #expect(collected.commander.credits == before.credits && collected.commander.valid)
  }

  @Test func actualSourceInstallationCrewReceiptAndTwoNativeRechargeSocketsSurviveColdLoad()
    async throws
  {
    let f = try NativeUtilityRuntimeFixture()
    defer { f.files.clean() }
    var runtime = try await f.source()
    let original = await runtime.snapshot()
    let stock = try #require(original.commander.nativeUtility)
    #expect(stock.materials.count == 8 && stock.consignments.isEmpty)
    #expect(
      original.commander.nativeStations?.ledger.records.first {
        NativeUtilityState.isTarget($0.identity)
      }?.binding == nil)
    for socket in 0..<2 {
      let before = await runtime.snapshot()
      let collect = try await runtime.nativeUtilityQuote(.collect)
      #expect(collect.rewardTenths == 6100 + 1100 * (collect.route.count - 1))
      try await runtime.confirmNativeUtility(collect)
      let held = await runtime.snapshot()
      #expect(held.commander.cargoTonnes == before.commander.cargoTonnes + 4)
      #expect(held.commander.nativeUtility?.active?.originalUnits == stock.units(socket))
      runtime = try await f.reloaded(runtime)
      runtime = try await f.target(from: runtime)
      try f.recharge(await runtime.snapshot(), expected: Double(100 + 10 * socket))
      let install = try await runtime.nativeUtilityQuote(.install)
      let dock = await runtime.snapshot().commander.nativeStations?.ledger.currentDock
      try await runtime.confirmNativeUtility(install)
      let installed = await runtime.snapshot()
      #expect(installed.commander.nativeUtility?.heldTonnes == 0)
      #expect(installed.commander.nativeUtility?.active?.installation?.socket == socket)
      #expect(installed.commander.nativeStations?.ledger.currentDock == dock)
      try f.recharge(installed, expected: Double(110 + 10 * socket))
      runtime = try await f.reloaded(runtime)
      let receive = try await runtime.nativeUtilityQuote(.receive)
      try await runtime.confirmNativeUtility(receive)
      let received = await runtime.snapshot()
      let job = try #require(received.commander.nativeUtility?.consignments.last)
      #expect(job.phase == .received && job.reception?.installation == job.installation?.operation)
      #expect(job.originalUnits == stock.units(socket))
      #expect(received.commander.credits == before.commander.credits + collect.rewardTenths)
      let missionID = WayfarerFieldRelief.instance(job.id)
      let mission = try #require(received.commander.scriptState.instances[missionID])
      #expect(mission.outcome == .complete && mission.savedFieldRelief?.job == job)
      #expect(mission.contract?.settlementAmount == collect.rewardTenths)
      #expect(mission.completionReceipt?.cause?.nativeStation?.receipt == receive.target?.receipt)
      let award = try #require(
        received.commander.scriptState.savedClueJournal?.awards[WayfarerFieldRelief.stateID])
      if let prior = before.commander.scriptState.savedClueJournal?.awards[WayfarerFieldRelief.stateID] {
        #expect(award == prior)
      } else {
        #expect(award.completion == mission.completionReceipt)
      }
      #expect(received.commander.valid)
      await #expect(throws: (any Error).self) { try await runtime.confirmNativeUtility(receive) }
      runtime = try await f.reloaded(runtime)
      if socket == 0 { runtime = try await f.source(from: runtime) }
    }
    let final = await runtime.snapshot().commander
    #expect(
      final.nativeUtility?.consignments.count == 2 && final.nativeUtility?.rechargeBonus == 20)
  }

  @Test func collectInstallReceiveWriterRefusalsAndColdStaleQuotesPreserveOriginalProperty()
    async throws
  {
    let f = try NativeUtilityRuntimeFixture()
    defer { f.files.clean() }
    var runtime = try await f.source()
    let collect = try await runtime.nativeUtilityQuote(.collect)
    try await f.refusedWrite(runtime, quote: collect, label: "utility-collect")
    try await runtime.confirmNativeUtility(collect)
    runtime = try await f.target(from: runtime)
    var install = try await runtime.nativeUtilityQuote(.install)
    try await f.refusedWrite(runtime, quote: install, label: "utility-install")
    runtime = try await f.reloaded(runtime)
    let before = await runtime.snapshot().commander
    let frozenReward = try #require(before.nativeUtility?.active?.rewardTenths)
    await #expect(throws: (any Error).self) { try await runtime.confirmNativeUtility(install) }
    #expect(await runtime.snapshot().commander == before)
    install = try await runtime.nativeUtilityQuote(.install)
    try await runtime.confirmNativeUtility(install)
    let receive = try await runtime.nativeUtilityQuote(.receive)
    try await f.refusedWrite(runtime, quote: receive, label: "utility-receive")
    try await runtime.confirmNativeUtility(receive)
    #expect(await runtime.snapshot().commander.credits == before.credits + frozenReward)
  }

  @Test func wrongDockPausedChangedInventoryAndSubstituteCommodityCannotAuthorizeInstallation()
    async throws
  {
    let f = try NativeUtilityRuntimeFixture()
    defer { f.files.clean() }
    let source = try await f.source()
    await #expect(throws: (any Error).self) { _ = try await source.nativeUtilityQuote(.install) }
    let collect = try await source.nativeUtilityQuote(.collect)
    try await source.confirmNativeUtility(collect)
    let runtime = try await f.target(from: source)
    let quote = try await runtime.nativeUtilityQuote(.install)
    var paused = await runtime.snapshot()
    paused.paused = true
    #expect(throws: (any Error).self) { try paused.confirmNativeUtility(quote) }
    var changed = await runtime.snapshot()
    let inventory = try #require(changed.commander.equipmentInventory)
    changed.commander.savedEquipmentInventory = try OwnedEquipmentInventory(
      owner: inventory.owner,
      activeHull: inventory.activeHull, revision: inventory.revision + 1, items: inventory.items)
    try #require(changed.commander.valid)
    #expect(throws: (any Error).self) { try changed.confirmNativeUtility(quote) }
    changed.commander.cargo[9] = 4
    // Commodity stock does not replace an allocated original unit; strict state validation proves this.
    let state = try #require(changed.commander.nativeUtility)
    var substitute = state
    substitute.consignments[0] = NativeUtilityConsignment(
      id: state.consignments[0].id,
      originalUnits: [UUID(), UUID(), UUID(), UUID()], hull: state.consignments[0].hull,
      source: state.consignments[0].source, route: state.consignments[0].route,
      firstLegReach: state.consignments[0].firstLegReach,
      fullTankReach: state.consignments[0].fullTankReach,
      rewardTenths: state.consignments[0].rewardTenths)
    #expect(!substitute.valid)
    var wrong = await runtime.snapshot()
    wrong.invalidateNativeStationAuthority()
    #expect(throws: (any Error).self) { try wrong.confirmNativeUtility(quote) }
  }

  @Test func exactSourceReturnsRetireStockAndRetryUsesTheOtherOriginalFour() async throws {
    let f = try NativeUtilityRuntimeFixture()
    defer { f.files.clean() }
    let runtime = try await f.source()
    let original = await runtime.snapshot().commander
    let first = try await runtime.nativeUtilityQuote(.collect)
    try await runtime.confirmNativeUtility(first)
    let held = try #require(await runtime.snapshot().commander.nativeUtility?.active)
    let returningFirst = try await runtime.nativeUtilityQuote(.returnMaterials)
    try await runtime.confirmNativeUtility(returningFirst)
    let returned = await runtime.snapshot().commander
    #expect(returned.cargoTonnes == original.cargoTonnes)
    #expect(returned.nativeUtility?.consignments[0].phase == .returned)
    let second = try await runtime.nativeUtilityQuote(.collect)
    try await runtime.confirmNativeUtility(second)
    let active = try #require(await runtime.snapshot().commander.nativeUtility?.active)
    #expect(active.id != held.id && Set(active.originalUnits).isDisjoint(with: held.originalUnits))
    let returningSecond = try await runtime.nativeUtilityQuote(.returnMaterials)
    try await runtime.confirmNativeUtility(returningSecond)
    await #expect(throws: (any Error).self) { _ = try await runtime.nativeUtilityQuote(.collect) }
    #expect(await runtime.snapshot().commander.credits == original.credits)
    _ = try await f.reloaded(runtime)
  }

  @Test
  func xyzzyActualHeldMaterialsConstrainMarketThenInstallationRestoresExistingUnlimitedPolicy()
    async throws
  {
    let f = try NativeUtilityRuntimeFixture()
    defer { f.files.clean() }
    var runtime = try await f.source()
    try await runtime.utilityCapacityPolicyAndMarket(enableXYZzy: true, fill: false)
    let collect = try await runtime.nativeUtilityQuote(.collect)
    try await runtime.confirmNativeUtility(collect)
    try await runtime.utilityCapacityPolicyAndMarket(enableXYZzy: false, fill: true)
    let full = await runtime.snapshot()
    try #require(full.commander.xyzzyActive && full.commander.unlimitedCargo)
    try #require(full.commander.accommodation.fitted.isEmpty)
    try #require(full.commander.nativeUtility?.heldTonnes == 4)
    #expect(full.commander.tradeCargoCapacity == full.commander.standardCargoCapacity)
    #expect(full.marketAvailability(0) == "HOLD FULL")
    await runtime.key("return")
    let refused = await runtime.snapshot()
    #expect(refused.commander == full.commander && refused.market == full.market)
    #expect(refused.commander.valid)
    runtime = try await f.target(from: runtime)
    let install = try await runtime.nativeUtilityQuote(.install)
    try await runtime.confirmNativeUtility(install)
    let installed = await runtime.snapshot().commander
    #expect(installed.nativeUtility?.heldTonnes == 0)
    #expect(
      installed.tradeCargoCapacity == installed.capacity
        && installed.capacity > installed.standardCargoCapacity)
    runtime = try await f.source(from: runtime)
    try await runtime.utilityCapacityPolicyAndMarket(enableXYZzy: false, fill: true)
    let available = await runtime.snapshot()
    try #require(available.commander.cargoTonnes == available.commander.standardCargoCapacity)
    #expect(available.marketAvailability(0) == "BUY")
    await runtime.key("return")
    let bought = await runtime.snapshot()
    #expect(bought.commander.cargo[0] == available.commander.cargo[0] + 1)
    #expect(bought.commander.valid)
  }

  @Test(arguments: [false, true])
  func destroyedActualTargetNeverRestoresHeldOrInstalledMaterials(installed: Bool) async throws {
    let f = try NativeUtilityRuntimeFixture()
    defer { f.files.clean() }
    let source = try await f.source()
    let collect = try await source.nativeUtilityQuote(.collect)
    try await source.confirmNativeUtility(collect)
    let runtime = try await f.target(from: source)
    if installed {
      let quote = try await runtime.nativeUtilityQuote(.install)
      try await runtime.confirmNativeUtility(quote)
    }
    let before = try #require(await runtime.snapshot().commander.nativeUtility)
    await runtime.key("0")
    try await runtime.utilityActualHeadquartersDeath()
    let dead = await runtime.snapshot()
    let record = try #require(
      dead.commander.nativeStations?.ledger.records.first {
        NativeUtilityState.isTarget($0.identity)
      })
    #expect(record.tombstone != nil && record.binding == nil)
    #expect(dead.commander.nativeUtility == before && dead.commander.valid)
    #expect(dead.commander.nativeUtility?.heldTonnes == (installed ? 0 : 4))
    await #expect(throws: (any Error).self) {
      _ = try await runtime.nativeUtilityQuote(installed ? .receive : .install)
    }
    let cold = try await f.reloaded(runtime)
    #expect(await cold.snapshot().commander.nativeUtility == before)
    #expect(
      await cold.snapshot().commander.nativeStations?.ledger.records.first {
        NativeUtilityState.isTarget($0.identity)
      }?.tombstone != nil)
  }

  @Test(arguments: [NativeUtilityLossCause.escape, .shipDestroyed])
  func physicalLossWriterFailureThenRetryRetainsActualOriginalLoss(cause: NativeUtilityLossCause)
    async throws
  {
    let f = try NativeUtilityRuntimeFixture()
    defer { f.files.clean() }
    let runtime = try await f.source(escapeReady: true)
    let collect = try await runtime.nativeUtilityQuote(.collect)
    try await runtime.confirmNativeUtility(collect)
    await runtime.key("0")
    let before = await runtime.snapshot()
    let disk = try ScriptFinanceTestFixture.files(f.save.deletingLastPathComponent())
    let blocked = try f.files.blockWrites("utility-loss")
    if cause == .escape {
      await runtime.key("escape-pod")
    } else {
      try await runtime.utilityActualFatalHit()
      _ = await runtime.advance(delta: 0.1)
    }
    let refused = await runtime.snapshot()
    #expect(refused.commander.nativeUtility == before.commander.nativeUtility)
    if cause == .escape { #expect(refused.commander == before.commander) }
    try f.files.restoreWrites(blocked, files: disk)
    if cause == .escape {
      await runtime.key("escape-pod")
    } else {
      _ = await runtime.advance(delta: 0.1)
    }
    let lost = await runtime.snapshot()
    let job = try #require(lost.commander.nativeUtility?.consignments[0])
    #expect(job.phase == .lost && job.loss?.cause == cause)
    #expect(job.originalUnits == before.commander.nativeUtility?.active?.originalUnits)
    #expect(lost.commander.nativeUtility?.heldTonnes == 0)
    #expect(lost.commander.credits == before.commander.credits)
    #expect(
      lost.commander.scriptState.savedClueJournal == before.commander.scriptState.savedClueJournal)
    #expect(lost.commander.valid)
    _ = try await f.reloaded(runtime)
  }

}

extension GameRuntime {

  /// Controlled preference/cargo policy fixture; preserves actual owned material and dock authority.
  fileprivate func utilityCapacityPolicyAndMarket(enableXYZzy: Bool, fill: Bool) throws {
    try scriptCommand { game in
      if enableXYZzy {
        game.commander.xyzzyActive = true
        game.commander.unlimitedCargo = true
      }
      if fill {
        game.commander.cargo[0] += game.commander.standardCargoCapacity - game.commander.cargoTonnes
        game.market[0].quantity = 2
        game.screen = .buy
        game.selection = 0
      }
      guard game.commander.valid else { throw SaveError.invalidCommander }
    }
  }
  /// Actual native collision/hit and lifecycle settlement; no energy/tombstone assignment.
  func utilityActualHeadquartersDeath() throws {
    try scriptCommand { game in
      let body = try #require(
        game.bodies.first { $0.nativeStationIdentity.map(NativeUtilityState.isTarget) == true })
      let identity = try #require(body.nativeStationIdentity)
      let saved = try #require(game.commander.nativeStations?.pose(for: identity))
      let orientation = try #require(
        saved.orientation(at: game.commander.flightSimulation.physicalTime))
      let geometry = NativeStationGeometry.headquarters
      let face = geometry.mesh.faces[0].map { geometry.mesh.vertices[$0] }
      let center = face.reduce(Vector3(0, 0, 0), +) * (1 / Double(face.count))
      let outward = (face[1] - face[0]).cross(face[2] - face[0]).unit
      let radius = game.commander.playerMesh.vertices.map(\.length).max() ?? 100
      let separation = geometry.bounds.support(outward) - center.dot(outward) + radius + 1000
      var pose = ShipPose()
      pose.position = saved.position + orientation.apply(center + outward * separation)
      pose.orientation.z = orientation.apply(outward) * -1
      let up = abs(pose.orientation.z.y) < 0.9 ? Vector3(0, 1, 0) : .init(1, 0, 0)
      pose.orientation.y = (up - pose.orientation.z * up.dot(pose.orientation.z)).unit
      pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
      NativeStationTestFixture.reframe(&game, to: pose)
      let contact = try #require(
        try game.nearestMissionCollision(
          from: .init(0, 0, 0),
          direction: .init(0, 0, 1), range: separation + 2000, radius: 0, includePlayer: false))
      try #require(contact.hit.target == .body(body.id))
      let player = try #require(game.commander.flightSimulation.player)
      let allocated = game.makeAttackOrigin(owner: player)
      let origin = try #require(allocated)
      let applied = game.applyCombatHit(
        contact.hit, origin: origin, kind: .laser, damage: body.energy + 1)
      try #require(applied != nil)
      game.resolveDestroyed()
    }
  }
  /// Controlled actor and ray produce the actual fatal native hit; no forged loss receipt.
  func utilityActualFatalHit() throws {
    let mesh = game.commander.playerMesh
    let face = try #require(
      mesh.faces.first { indices in
        indices.count == 3
          && (mesh.vertices[indices[0]] + mesh.vertices[indices[1]] + mesh.vertices[indices[2]]).z
            > 0
      })
    let center =
      (mesh.vertices[face[0]] + mesh.vertices[face[1]] + mesh.vertices[face[2]]) * (1.0 / 3.0)
    let position = center.unit * 500
    let id = game.nextBodyID
    game.nextBodyID += 1
    game.bodies.append(.init(id: id, hull: .cobra, position: position, hostile: true))
    game.ensurePhysicalActors()
    let actor = try #require(game.bodies.first { $0.id == id }?.physical?.identity)
    let contact = try game.nearestMissionCollision(
      from: position, direction: position.unit * -1,
      range: position.length + 1, radius: 0, excludingBodyIDs: [id], includePlayer: true)
    let hit = try #require(contact?.hit)
    try #require(hit.target == .player)
    let allocated = game.makeAttackOrigin(owner: actor)
    let origin = try #require(allocated)
    let damage = game.energy + game.frontShield + game.rearShield + 1
    let result = game.applyCombatHit(hit, origin: origin, kind: .laser, damage: damage)
    try #require(result != nil)
  }
}
