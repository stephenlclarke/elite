import Foundation
import Testing

@testable import EliteCore

private func empNativeFlight() throws -> Game {
  var game = Game(executive: false)
  try game.commander.prepareEquipment(legacy: false)
  try game.commander.grantEquipment(
    Equipment.empPirateBlaster, at: .utility(.empPirateBlaster),
    provenance: .grant("EMP native boundary regression"))
  try fitEliteEMPTestEnergy(&game)
  game.launch()
  try #require(!game.docked && game.commander.valid)
  game.speed = 0
  game.selectFlightTool(.empPirateBlaster)
  return game
}

/// Complete the actual countdown and native arrival; selecting a chart destination never edits the system.
private func empTravel(to destination: Int, game: inout Game) throws {
  let origin = game.commander.system
  try #require(destination != origin)
  game.selectedSystem = destination
  let station = try #require(game.commander.flightSimulation.anchors?.station)
  let outward = (game.commander.flightSimulation.pose.position - station.position).unit
  try #require(outward.finite && outward.length > 0)
  for frame in 0..<200 where game.massLocked {
    let direction = game.commander.flightSimulation.pose.shipVector(outward)
    var controls = Controls()
    controls.throttle = 1
    controls.yaw = max(
      -1,
      min(
        1,
        atan2(direction.x, direction.z)
          / max(0.001, game.commander.performance.yaw * 0.1)))
    controls.pitch = max(
      -1,
      min(
        1,
        atan2(direction.y, hypot(direction.x, direction.z))
          / max(0.001, game.commander.performance.pitch * 0.1)))
    game.tick(delta: 0.1, controls: controls)
    let continuingFlight = game.screen != .gameOver && !game.docked
    var failureDetails = ""
    if !continuingFlight {
      let flight = game.commander.flightSimulation
      let emp = game.commander.savedEMPState?.records.values.first
      failureDetails =
        "EMP travel stopped: origin=\(origin), destination=\(destination), frame=\(frame), "
        + "time=\(flight.physicalTime), pose=\(flight.pose), screen=\(game.screen), "
        + "docked=\(game.docked), energy=\(game.energy), "
        + "shields=\(game.frontShield)/\(game.rearShield), "
        + "temperature=\(game.cabinTemperature), altitude=\(game.altitude), "
        + "message=\(game.message), speed=\(game.speed), outward=\(outward), "
        + "station=\(station.position), stationRange=\((flight.pose.position - station.position).length), "
        + "throttle=\(controls.throttle), pitch=\(controls.pitch), yaw=\(controls.yaw), "
        + "sampledEMPRecord=\(String(describing: emp?.source)), "
        + "empCrew=\(String(describing: emp?.crewAboard)), "
        + "empDeadline=\(String(describing: emp?.crewDeadline)), "
        + "empRecovered=\(String(describing: emp?.isRecovered)), "
        + "retainedPlayerThreatEvidence=\(empRetainedPlayerThreatEvidence(game))"
    }
    try #require(continuingFlight, Comment(rawValue: failureDetails))
  }
  let freeToJump = !game.massLocked
  try #require(freeToJump)
  let fuel = game.commander.fuel
  let debit = game.commander.jumpFuelCost(
    distance: game.currentSystem.distance(to: game.targetSystem))
  try #require(!game.commander.unlimitedFuel && debit > 0 && debit <= fuel)
  game.beginHyperspace()
  let countdown = try #require(game.jumpCountdown)
  try #require(countdown.isFinite && countdown > 0)
  for _ in 0..<(Int(ceil(countdown / 0.1)) + 2) where game.jumpCountdown != nil {
    game.tick(delta: 0.1)
  }
  try #require(game.commander.system == destination && game.jumpCountdown == nil)
  #expect(game.commander.fuel < fuel)
  #expect(game.commander.fuel == fuel - debit)
  #expect(game.commander.flightSimulation.system == game.systemIdentity)
}

private struct EMPTravelThreatLedger: Decodable {
  struct Window: Decodable {
    let owner: ActorIdentity
    let victim: ActorIdentity
    let lastAttack: Double
    let unlawful: Bool
    let authorityAction: Bool
  }
  let attacks: [Window]
}

/// Failure-only retained windows are threat evidence, not a per-hit damage or fatal-hit history.
private func empRetainedPlayerThreatEvidence(_ game: borrowing Game) -> String {
  guard let player = game.commander.flightSimulation.player else {
    return "unavailable: no player identity"
  }
  do {
    let bytes = try JSONEncoder().encode(game.commander.crimeLedger)
    let ledger = try JSONDecoder().decode(EMPTravelThreatLedger.self, from: bytes)
    let windows = ledger.attacks.filter { $0.victim == player }.sorted {
      $0.lastAttack == $1.lastAttack
        ? $0.owner.entity < $1.owner.entity : $0.lastAttack > $1.lastAttack
    }.prefix(4)
    var evidence: [String] = []
    for window in windows {
      let body = game.bodies.first { $0.physical?.identity == window.owner }
      evidence.append(
        "owner=\(window.owner), lastAttack=\(window.lastAttack), unlawful=\(window.unlawful), "
          + "authorityAction=\(window.authorityAction), "
          + "currentRole=\(String(describing: body?.physical?.npc?.role)), "
          + "currentSpawnProducer=\(String(describing: body?.physical?.spawnIdentity?.producer)), "
          + "currentPosition=\(String(describing: body?.position))")
    }
    return "[" + evidence.joined(separator: "; ") + "]"
  } catch {
    return "unavailable: \(error)"
  }
}

private func empOtherSystem(_ game: Game) throws -> Int {
  let reachable = game.knownSystems.filter {
    let distance = game.currentSystem.distance(to: $0)
    return $0.id != game.commander.system && $0.id != Plugh.systemID
      && distance > 0 && distance <= game.commander.maximumJumpDistance
      && game.commander.jumpFuelCost(distance: distance) <= game.commander.fuel
  }.sorted {
    let left = game.currentSystem.distance(to: $0)
    let right = game.currentSystem.distance(to: $1)
    return left == right ? $0.id < $1.id : left < right
  }
  return try #require(reachable.first?.id)
}

private func empRoundTrip(
  _ game: inout Game, directory: URL
) async throws {
  let origin = game.commander.system
  let destination = try empOtherSystem(game)
  try empTravel(to: destination, game: &game)
  game.dock()
  try #require(game.docked && game.commander.system == destination)
  let file = directory.appendingPathComponent("between-systems.json")
  let returnSystem = try #require(game.systems.first { $0.id == origin })
  let returnDistance = game.currentSystem.distance(to: returnSystem)
  let returnDebit = game.commander.jumpFuelCost(distance: returnDistance)
  try #require(returnDistance <= game.commander.jumpCap && returnDebit > 0)
  let needsFuel = game.commander.fuel < returnDebit
  if needsFuel {
    game.screen = .equipment
    game.selection = try #require(Equipment.all.firstIndex { $0.name == "Fuel" })
  }
  let writer = GameRuntime(game: game)
  try await writer.save(to: file)
  if needsFuel {
    let beforePurchase = await writer.snapshot()
    let fuelItem = Equipment.all[beforePurchase.selection]
    let price = beforePurchase.shopPrice(fuelItem)
    try #require(fuelItem.name == "Fuel" && price > 0)
    try #require(
      !beforePurchase.commander.unlimitedCash
        && beforePurchase.commander.availableCredits >= price)
    let context = try #require(beforePurchase.equipmentPurchaseContext)
    let result = await writer.equipmentTransaction(.purchase(context))
    try #require(result.applied)
    let refuelled = await writer.snapshot()
    #expect(refuelled.commander.fuel == refuelled.commander.fuelCapacity)
    #expect(refuelled.commander.credits == beforePurchase.commander.credits - price)
    try #require(refuelled.commander.fuel >= returnDebit)
  }
  let published = await writer.snapshot()
  let reader = GameRuntime()
  try await reader.load(from: file, persistMigrations: false)
  game = await reader.snapshot()
  #expect(game.commander.fuel == published.commander.fuel)
  #expect(game.commander.credits == published.commander.credits)
  try #require(game.docked && game.commander.system == destination)
  try #require(game.commander.fuel >= returnDebit)
  game.launch()
  try #require(!game.docked)
  try empTravel(to: origin, game: &game)
  game.dock()
  try #require(game.docked && game.commander.system == origin)
  game.launch()
  try #require(!game.docked && game.commander.system == origin)
  for _ in 0..<5 { game.tick(delta: 0.1) }
}

struct EMPTravelAndSecurityTests {
  @Test func actualHyperspaceDockReloadAndReturnRetainOneNativeHullAndItsOriginalPeople()
    async throws
  {
    var game = try empNativeFlight()
    let nativeIndex = try #require(game.bodies.firstIndex { $0.id == 1 && $0.hull == .cobra })
    let fresh = game.bodies[nativeIndex]
    try #require(fresh.physical?.catalogueShipID == nil)
    let beforeCommander = game.commander
    let beforeBodies = game.bodies
    let beforeEnergy = game.energy
    let beforeShields = (game.frontShield, game.rearShield)
    let beforeBodyCursor = game.nextBodyID
    let beforeRandom = game.scriptSimulationSave.randomState
    let beforeTime = game.time
    let catalogueID = try #require(
      fresh.physical?.catalogueShipID ?? ShipCatalogue.nativeShip(fresh.hull)?.id)
    try #require(catalogueID == "SH023")
    let catalogue = try #require(ShipCatalogue.ship(catalogueID))
    let native = try #require(catalogue.game)
    try #require(native.valid && native.recharge == 2 && catalogue.nativeHull == fresh.hull)
    // This persistence scenario starts with existing nonfatal power damage, before original capture.
    var worn = try #require(fresh.physical?.npc?.resources)
    try #require(worn.valid && worn.profile == .legacyEnergyOnly)
    try #require(worn.frontShield == 0 && worn.rearShield == 0 && worn.electrical == nil)
    try #require(
      worn.legacyElectricalRecharge == nil || worn.legacyElectricalRecharge == native.recharge)
    let now = game.commander.flightSimulation.physicalTime
    var reserve = try #require(
      ElectricalReserve(capacity: worn.energyCapacity, recharge: native.recharge, at: now))
    let drained = reserve.drain(worn.energyCapacity - 1, at: now)
    try #require(
      drained && reserve.remaining == 1 && reserve.disabledAt == nil && reserve.physicalTime == now)
    worn.legacyElectricalRecharge = native.recharge
    worn.electrical = reserve
    try #require(worn.valid)
    var expectedBody = fresh
    expectedBody.physical?.npc?.resources = worn
    game.bodies[nativeIndex].physical?.npc?.resources = worn
    var expectedBodies = beforeBodies
    expectedBodies[nativeIndex] = expectedBody
    try #require(game.bodies == expectedBodies && game.commander == beforeCommander)
    try #require(
      game.energy == beforeEnergy && game.frontShield == beforeShields.0
        && game.rearShield == beforeShields.1)
    try #require(game.nextBodyID == beforeBodyCursor && game.time == beforeTime)
    try #require(game.scriptSimulationSave.randomState == beforeRandom)
    let pulse = try EMPPulseProfile.resolve(for: game.commander)
    try #require(pulse.power == 80 && pulse.warmup == 10)
    try #require(1 + native.recharge * (pulse.warmup + 0.1) < pulse.power)
    let original = game.bodies[nativeIndex]
    try #require(original.physical?.catalogueShipID == nil)
    try #require(original.physical?.empSource == nil && game.commander.savedEMPState == nil)
    try #require(!game.isEMPDisabled(original))
    let actor = try #require(original.physical?.identity)
    let emissionsBefore = game.dischargeAudio.events.filter { $0.tool == .empPirateBlaster }.count
    try disableNativeEMPActor(actor, game: &game)
    try #require(
      game.dischargeAudio.events.filter { $0.tool == .empPirateBlaster }.count == emissionsBefore
        + 1)
    let released = try #require(game.commander.savedEMPCharge)
    let releasedAt = try #require(released.endedAt)
    try #require(
      released.phase == .released && abs(releasedAt - released.startedAt - pulse.warmup) < 1e-8)
    let source = try #require(
      game.bodies.first { $0.physical?.identity == actor }?.physical?.empSource)
    let disabled = try #require(game.commander.savedEMPState?.records[source])
    try #require(disabled.hull.body.physical?.catalogueShipID == catalogueID)
    let expectedRecoveryDeadline = disabled.disableIncident.physicalTime + 30
    try #require(disabled.crewDeadline == expectedRecoveryDeadline)
    for _ in 0..<30 { game.tick(delta: 0.1) }
    let empPersistenceResult = game.persistEMPState()
    try #require(empPersistenceResult)
    let before = try #require(game.commander.savedEMPState?.records[source])
    try #require(before.originalBodyID == 1 && before.originalSpawn == nil)
    expectOriginalEMPCrewConserved(before)
    #expect(before.crewCaptures.isEmpty && before.lostCrewCount == 0)
    let people = Set(before.pods.compactMap { $0.body.physical?.empCrewPod })
    let legal = game.commander.legal
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try await empRoundTrip(&game, directory: directory)
    let after = try #require(game.commander.savedEMPState?.records[source])
    #expect(after.source == before.source && after.wreck == before.wreck)
    #expect(after.custody == before.custody && after.disableIncident == before.disableIncident)
    #expect(after.cargo == before.cargo && after.legal == before.legal)
    #expect(game.commander.legal >= legal)
    #expect(after.crewTotal == before.crewTotal)
    expectOriginalEMPCrewConserved(after)
    let survivingPeople = Set(after.pods.compactMap { $0.body.physical?.empCrewPod })
    #expect(people.isSubset(of: survivingPeople))
    let hulls = nativeEMPHulls(game, source: source)
    try #require(hulls.count == 1)
    #expect(hulls[0].physical?.identity != before.hull.binding)
    #expect(hulls[0].hull == original.hull && hulls[0].energy >= before.hull.body.energy)
    #expect(hulls[0].physical?.catalogueShipID == before.hull.body.physical?.catalogueShipID)
    try #require(after.crewDeadline == expectedRecoveryDeadline)
    if after.crewAboard > 0 {
      let deadlineReached = game.commander.flightSimulation.physicalTime >= expectedRecoveryDeadline
      #expect(after.isRecovered == deadlineReached)
      #expect(game.isEMPDisabled(hulls[0]) == !deadlineReached)
      #expect(hulls[0].physical?.npc?.role == original.physical?.npc?.role)
      let electrical = try #require(hulls[0].physical?.npc?.resources?.electrical)
      if deadlineReached {
        #expect(hulls[0].physical?.empSource == nil)
        #expect(electrical.remaining > 0 && electrical.disabledAt == nil)
      } else {
        #expect(hulls[0].physical?.empSource == source)
        #expect(electrical.remaining == 0 && electrical.disabledAt != nil)
      }
    } else {
      #expect(!after.isRecovered && game.isEMPDisabled(hulls[0]))
      #expect(hulls[0].physical?.npc == nil)
      #expect(hulls[0].physical?.velocity == before.hull.body.physical?.velocity)
      #expect(hulls[0].physical?.angularVelocity == before.hull.body.physical?.angularVelocity)
    }
    #expect(
      !game.bodies.contains {
        $0.id == before.originalBodyID && $0.hull == original.hull
          && $0.physical?.spawnIdentity == before.originalSpawn && $0.physical?.empSource == nil
      })
    let admittedPeople = game.bodies.compactMap { $0.physical?.empCrewPod }.filter {
      $0.source == source
    }
    #expect(Set(admittedPeople).count == admittedPeople.count)
    #expect(Set(admittedPeople).isSubset(of: survivingPeople))
    let returned = directory.appendingPathComponent("returned.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: returned)
    try await runtime.load(from: returned, persistMigrations: false)
    for _ in 0..<20 { _ = await runtime.advance(delta: 0.1) }
    let reloaded = await runtime.snapshot()
    #expect(nativeEMPHulls(reloaded, source: source).count == 1)
    let retained = try #require(reloaded.commander.savedEMPState?.records[source])
    expectOriginalEMPCrewConserved(retained)
    #expect(Set(retained.pods.compactMap { $0.body.physical?.empCrewPod }) == survivingPeople)
    #expect(retained.disableEpisodes == after.disableEpisodes)
    #expect(reloaded.commander.savedEMPState?.records[source]?.cargo == before.cargo)
  }

  @Test func fullStockNativeCobraRequiresTwoRealPulsesAndCannotAttackAfterElectricalZero() throws {
    var game = try empNativeFlight()
    let original = try #require(game.bodies.first { $0.id == 1 && $0.hull == .cobra })
    let actor = try #require(original.physical?.identity)
    let npc = try #require(original.physical?.npc)
    let resources = try #require(npc.resources)
    let player = try #require(game.commander.flightSimulation.player)
    let catalogueID = try #require(
      original.physical?.catalogueShipID ?? ShipCatalogue.nativeShip(original.hull)?.id)
    try #require(catalogueID == "SH023")
    let catalogue = try #require(ShipCatalogue.ship(catalogueID))
    let native = try #require(catalogue.game)
    let crew = try ShipAccommodationProfile(ship: catalogue).operatingCrew
    try #require(native.valid && native.recharge == 2 && catalogue.nativeHull == original.hull)
    try #require(resources.valid && resources.profile == .legacyEnergyOnly)
    try #require(resources.energyCapacity == original.energy && resources.energyRecharge == 0)
    try #require(resources.frontShield == 0 && resources.rearShield == 0)
    try #require(resources.electrical == nil && resources.legacyElectricalRecharge == nil)
    try #require(original.physical?.empSource == nil && game.commander.savedEMPState == nil)
    let hardware = try #require(game.commander.equipmentInventory)
    let history = try #require(game.commander.equipmentPurchaseHistory)
    let weapon = try #require(game.commander.fittedEquipment(at: .utility(.empPirateBlaster)))
    let credits = game.commander.credits
    let cargo = game.commander.cargo
    let legal = game.commander.legal
    let kills = game.commander.kills
    let pulse = try EMPPulseProfile.resolve(for: game.commander)
    try #require(pulse.power == 80 && pulse.warmup == 10)
    try #require(resources.energyCapacity > pulse.power)
    let startedAt = game.commander.flightSimulation.physicalTime
    let emissionsBefore = game.dischargeAudio.events.filter { $0.tool == .empPirateBlaster }.count
    // One original 800-frame helper keeps both charges, real aiming and every native control unchanged.
    let remainingFrames = try disableNativeEMPActor(actor, game: &game) { scene in
      try establishNativeCobraRetaliation(
        actor, player: player, emissionsBefore: emissionsBefore, legalBefore: legal, game: &scene)
    }
    try verifyFullStockCobraAfterPulses(
      &game, original: original, actor: actor, npc: npc, player: player,
      catalogueID: catalogueID, crew: crew, hardware: hardware, history: history, weapon: weapon,
      credits: credits, cargo: cargo, legal: legal, kills: kills, pulse: pulse,
      startedAt: startedAt, emissionsBefore: emissionsBefore, remainingFrames: remainingFrames)
  }

  // Establish a real pre-disable attack after the first unlawful EMP pulse, preserving its law.
  @inline(never)
  private func establishNativeCobraRetaliation(
    _ actor: ActorIdentity, player: ActorIdentity, emissionsBefore: Int, legalBefore: Int,
    game: inout Game
  ) throws {
    let body = try #require(game.bodies.first { $0.physical?.identity == actor })
    try #require(game.commander.flightSimulation.player == player)
    try #require(body.energy > 0 && !game.isEMPDisabled(body) && body.hostile)
    try #require(body.position.length > 0 && body.position.length < 1500)
    try #require(game.commander.legal > legalBefore)
    try #require(
      game.dischargeAudio.events.filter { $0.tool == .empPirateBlaster }.count == emissionsBefore + 1)
    try #require(body.physical?.npc?.intention == .engage(player))
    let remaining = try #require(body.physical?.npc?.resources?.electrical?.remaining)
    try #require(remaining > 0)
    let contact = try game.nearestMissionCollision(
      from: body.position, direction: body.position.unit * -1,
      range: body.position.length + 1, radius: 0,
      excludingBodyIDs: [body.id], includePlayer: true)
    try #require(contact?.hit.target == .player)
    let emission = game.commander.flightSimulation.nextEmission
    let shields = game.frontShield + game.rearShield
    let energy = game.energy
    let legal = game.commander.legal
    // Same native beam and damage as one 0.1-second ordinary Cobra enemyAction step.
    game.emitLegacyNPCBeam(bodyID: body.id, damage: 0.1 * 6 * 2, energyMultiplier: 2)
    try #require(game.commander.flightSimulation.nextEmission == emission + 1)
    try #require(game.frontShield + game.rearShield < shields || game.energy < energy)
    try #require(game.commander.legal == legal)
    let bytes = try JSONEncoder().encode(game.commander.crimeLedger)
    let ledger = try JSONDecoder().decode(EMPTravelThreatLedger.self, from: bytes)
    let windows = ledger.attacks.filter { $0.owner == actor }
    try #require(windows.count == 1)
    let window = try #require(windows.first)
    try #require(window.victim == player)
    try #require(window.lastAttack == game.commander.flightSimulation.physicalTime)
  }

  @inline(never)
  private func verifyFullStockCobraAfterPulses(
    _ game: inout Game, original: SpaceBody, actor: ActorIdentity, npc: NPCState,
    player: ActorIdentity, catalogueID: String, crew: Int,
    hardware: OwnedEquipmentInventory, history: EquipmentPurchaseHistory, weapon: OwnedEquipmentItem,
    credits: Int, cargo: [Int], legal: Int, kills: Int, pulse: EMPPulseProfile,
    startedAt: Double, emissionsBefore: Int, remainingFrames: Int
  ) throws {
    try #require((0...800).contains(remainingFrames))
    let elapsed = game.commander.flightSimulation.physicalTime - startedAt
    try #require(elapsed >= 2 * pulse.warmup && elapsed <= 800 * 0.1 + 1e-8)
    let emissions = game.dischargeAudio.events.filter { $0.tool == .empPirateBlaster }
    try #require(emissions.count == emissionsBefore + 2)
    let charge = try #require(game.commander.savedEMPCharge)
    let releasedAt = try #require(charge.endedAt)
    try #require(charge.phase == .released && charge.player == player && charge.target == actor)
    try #require(charge.weapon == weapon.id)
    try #require(abs(releasedAt - charge.startedAt - pulse.warmup) < 1e-8)
    let disabled = try #require(game.bodies.first { $0.physical?.identity == actor })
    let source = try #require(disabled.physical?.empSource)
    let record = try #require(game.commander.savedEMPState?.records[source])
    try #require(
      source == actor && record.originalBodyID == original.id && record.originalSpawn == nil)
    try #require(record.custody.kind == .ordinary && record.custody.valid)
    try #require(
      record.custody.logical == actor && record.custody.original.body.physical?.identity == actor)
    try #require(record.custody.traffic?.actor == actor && record.custody.assignment == nil)
    try #require(
      record.disableIncident.victim == actor && record.disableIncident.origin.owner == player)
    try #require(record.disableIncident.physicalTime == releasedAt)
    try #require(record.disableIncident.origin.sourcePart == "emp:" + weapon.id.uuidString)
    try #require(record.weapon == weapon && record.weaponOwner == hardware.owner)
    try #require(disabled.hull == original.hull && disabled.energy == original.energy)
    try #require(disabled.physical?.catalogueShipID == catalogueID)
    try #require(record.hull.body.physical?.catalogueShipID == catalogueID)
    try #require(record.hull.body.energy == original.energy)
    try #require(record.cargo == npc.ordinaryCargo && record.legal == npc.legal)
    try #require(record.crewTotal == crew && record.crewAboard == crew)
    try #require(record.pods.isEmpty && record.crewCaptures.isEmpty && record.lostCrewCount == 0)
    expectOriginalEMPCrewConserved(record)
    let zero = try #require(disabled.physical?.npc?.resources?.electrical)
    try #require(
      game.isEMPDisabled(disabled) && zero.remaining == 0 && zero.disabledAt == releasedAt)
    try #require(
      game.commander.equipmentInventory == hardware
        && game.commander.equipmentPurchaseHistory == history)
    try #require(
      game.commander.credits == credits && game.commander.cargo == cargo
        && game.commander.kills == kills)
    try #require(game.commander.legal > legal && game.screen != .gameOver && !game.docked)
    let beforeLedgerBytes = try JSONEncoder().encode(game.commander.crimeLedger)
    let beforeLedger = try JSONDecoder().decode(EMPTravelThreatLedger.self, from: beforeLedgerBytes)
    let priorWindows = beforeLedger.attacks.filter { $0.owner == actor }
    try #require(priorWindows.count == 1)
    let priorWindow = try #require(priorWindows.first)
    try #require(priorWindow.victim == player && priorWindow.lastAttack.isFinite)
    try #require(priorWindow.lastAttack <= record.disableIncident.physicalTime)
    let fireReleased = Controls()
    try #require(!fireReleased.fire)
    game.tick(delta: 0.1, controls: fireReleased)
    let stillDisabled = try #require(game.bodies.first { $0.physical?.identity == actor })
    let stillZero = try #require(stillDisabled.physical?.npc?.resources?.electrical)
    try #require(game.isEMPDisabled(stillDisabled) && stillZero.remaining == 0)
    try #require(stillZero.disabledAt == releasedAt)
    let afterLedgerBytes = try JSONEncoder().encode(game.commander.crimeLedger)
    let afterLedger = try JSONDecoder().decode(EMPTravelThreatLedger.self, from: afterLedgerBytes)
    let windows = afterLedger.attacks.filter { $0.owner == actor }
    try #require(windows.count == priorWindows.count)
    let window = try #require(windows.first)
    try #require(window.owner == priorWindow.owner && window.victim == priorWindow.victim)
    try #require(
      window.unlawful == priorWindow.unlawful
        && window.authorityAction == priorWindow.authorityAction)
    try #require(window.lastAttack == priorWindow.lastAttack && window.lastAttack <= releasedAt)
    let retained = try #require(game.commander.savedEMPState?.records[source])
    try #require(
      retained.disableIncident == record.disableIncident && retained.custody == record.custody)
    try #require(retained.cargo == npc.ordinaryCargo && retained.legal == npc.legal)
    expectOriginalEMPCrewConserved(retained)
    try #require(
      game.commander.equipmentInventory == hardware
        && game.commander.equipmentPurchaseHistory == history)
    try #require(game.commander.legal >= legal && game.screen != .gameOver && !game.docked)
  }

  @Test func aHealthyAssignedOfficerTakesOneRealShieldFirstPulseWithoutInventedZeroOrCrew() throws {
    var game = try empNativeFlight()
    game.advanceGameplayEncounters(delta: 0.1)
    game.advanceGameplayEncounters(delta: 0.1)
    let officer = try #require(
      game.bodies.first {
        $0.physical?.spawnIdentity?.producer == .security && $0.physical?.npc?.role == .police
      })
    let actor = try #require(officer.physical?.identity)
    let player = try #require(game.commander.flightSimulation.player)
    let originalResources = try #require(officer.physical?.npc?.resources)
    try #require(originalResources.energyCapacity == 180 && officer.energy == 180)
    try #require(originalResources.frontShield == 255 && originalResources.rearShield == 255)
    try #require(originalResources.electrical == nil)
    try #require(game.commander.stationSecurity.assignments.contains { $0.actor == actor })
    let legal = game.commander.legal
    let cash = game.commander.credits
    let kills = game.commander.kills
    let inventory = game.commander.equipmentInventory
    let pulse = try EMPPulseProfile.resolve(for: game.commander)
    try #require(pulse.power == 80 && pulse.warmup == 10)
    try disableNativeEMPActor(actor, game: &game, stopAfterFirstEmission: true)
    let charge = try #require(game.commander.savedEMPCharge)
    let endedAt = try #require(charge.endedAt)
    #expect(charge.phase == .released && charge.player == player && charge.target == actor)
    #expect(abs(endedAt - charge.startedAt - pulse.warmup) < 1e-8)
    #expect(game.dischargeAudio.events.filter { $0.tool == .empPirateBlaster }.count == 1)
    let actual = try #require(game.bodies.first { $0.physical?.identity == actor })
    let resources = try #require(actual.physical?.npc?.resources)
    #expect([resources.frontShield, resources.rearShield].sorted() == [175, 255])
    #expect(resources.electrical?.remaining == 180 && resources.electrical?.disabledAt == nil)
    #expect(actual.energy == officer.energy && actual.physical?.npc?.role == .police)
    #expect(actual.physical?.npc?.firstAggressor == player)
    #expect(actual.physical?.empSource == nil && actual.physical?.salvage == nil)
    #expect(game.commander.savedEMPState == nil && !game.isEMPDisabled(actual))
    #expect(game.commander.stationSecurity.assignments.contains { $0.actor == actor })
    #expect(
      game.commander.legal > legal && game.commander.credits == cash
        && game.commander.kills == kills)
    #expect(game.commander.equipmentInventory == inventory)
    try #require(game.frontShield > 0 && game.rearShield > 0 && !game.playerEMPDisabled)
    #expect(
      game.commander.savedPlayerElectrical?.remaining == game.commander.performance.energy
        - pulse.energyCost)
    #expect(game.laserHeat == pulse.heatCost && game.fireCooldown == pulse.cooldown)
    #expect(!game.docked && game.screen != .gameOver && game.commander.valid)
  }

  @Test(arguments: [false, true])
  func actualAssignedSecurityShipRetainsSourceAndLawThroughEjectionOrDeathAndRoundTrip(
    lethal: Bool
  ) async throws {
    var game = try empNativeFlight()
    // Calm security creates its own patrol request at the real station exit; the runtime
    // admits and acknowledges it, then the next security update assigns the actual actor.
    game.advanceGameplayEncounters(delta: 0.1)
    game.advanceGameplayEncounters(delta: 0.1)
    let officer = try #require(
      game.bodies.first {
        $0.physical?.spawnIdentity?.producer == .security && $0.physical?.npc?.role == .police
      })
    let actor = try #require(officer.physical?.identity)
    try #require(game.commander.stationSecurity.assignments.contains { $0.actor == actor })
    let expectedCatalogue = try #require(
      officer.physical?.catalogueShipID ?? ShipCatalogue.nativeShip(officer.hull)?.id)
    try #require(expectedCatalogue == "SH136" && officer.hull == .viper)
    let nativeDefinition = try #require(ShipCatalogue.ship(expectedCatalogue)?.game)
    try #require(nativeDefinition.valid)
    let assignment = try #require(
      game.commander.stationSecurity.assignments.first {
        $0.actor == actor
      })
    // This custody scenario retains a genuinely admitted officer with existing, nonfatal power damage.
    let officerIndex = try #require(game.bodies.firstIndex { $0.physical?.identity == actor })
    var worn = try #require(game.bodies[officerIndex].physical?.npc?.resources)
    let frontOverflow = worn.absorb(worn.frontShield, front: true)
    let rearOverflow = worn.absorb(worn.rearShield, front: false)
    try #require(frontOverflow == 0 && rearOverflow == 0)
    let now = game.commander.flightSimulation.physicalTime
    var reserve = try #require(
      ElectricalReserve(capacity: worn.energyCapacity, recharge: worn.electricalRecharge, at: now))
    let drained = reserve.drain(worn.energyCapacity - 1, at: now)
    try #require(drained && reserve.remaining == 1 && reserve.disabledAt == nil)
    worn.electrical = reserve
    game.bodies[officerIndex].physical?.npc?.resources = worn
    try #require(game.bodies[officerIndex].energy == officer.energy && officer.energy == 180)
    try #require(
      game.bodies[officerIndex].physical?.empSource == nil && game.commander.savedEMPState == nil)
    try #require(game.commander.stationSecurity.assignments.contains { $0.actor == actor })
    let legal = game.commander.legal
    try disableNativeEMPActor(actor, game: &game)
    let source = try #require(
      game.bodies.first { $0.physical?.identity == actor }?.physical?.empSource)
    let proof = try #require(game.commander.savedEMPState?.records[source])
    let expectedRecoveryDeadline = proof.disableIncident.physicalTime + 30
    try #require(proof.crewDeadline == expectedRecoveryDeadline)
    try #require(proof.hull.body.physical?.catalogueShipID == expectedCatalogue)
    #expect(proof.custody.kind == .police && proof.custody.assignment?.actor == assignment.actor)
    #expect(proof.custody.assignment?.actor == actor && proof.custody.valid)
    #expect(proof.custody.traffic != nil)
    #expect(proof.originalSpawn?.producer == .security)
    #expect(proof.disableIncident.victim == actor && proof.disableIncident.victimRole == .police)
    #expect(game.commander.legal > legal)
    if lethal {
      let body = try #require(game.bodies.first { $0.physical?.empSource == source })
      let player = try #require(game.commander.flightSimulation.player)
      let originResult = game.makeAttackOrigin(owner: player)
      let origin = try #require(originResult)
      _ = game.applyCombatHit(
        .init(target: .body(body.id), distance: body.position.length, point: body.position),
        origin: origin, kind: .laser, damage: 10000)
      game.resolveDestroyed()
      let dead = try #require(game.commander.savedEMPState?.records[source])
      #expect(dead.terminal && dead.lostCrewCount == dead.crewTotal && dead.pods.isEmpty)
      #expect(dead.hull.body.physical?.deathOrigin == origin)
    } else {
      for _ in 0..<40 { game.tick(delta: 0.1) }
      let retained = try #require(game.commander.savedEMPState?.records[source])
      expectOriginalEMPCrewConserved(retained)
      #expect(!retained.isRecovered && retained.lostCrewCount == 0 && retained.crewCaptures.isEmpty)
    }
    let before = try #require(game.commander.savedEMPState?.records[source])
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try await empRoundTrip(&game, directory: directory)
    let after = try #require(game.commander.savedEMPState?.records[source])
    #expect(after.custody == before.custody && after.disableIncident == before.disableIncident)
    #expect(after.cargo == before.cargo && after.legal == before.legal)
    #expect(after.terminal == lethal && after.lostCrewCount == before.lostCrewCount)
    expectOriginalEMPCrewConserved(after)
    let beforePeople = Set(before.pods.compactMap { $0.body.physical?.empCrewPod })
    let afterPeople = Set(after.pods.compactMap { $0.body.physical?.empCrewPod })
    #expect(beforePeople.isSubset(of: afterPeople))
    #expect(nativeEMPHulls(game, source: source).count == (lethal ? 0 : 1))
    if !lethal {
      let current = try #require(nativeEMPHulls(game, source: source).first)
      #expect(current.physical?.catalogueShipID == expectedCatalogue)
      #expect(current.hull == officer.hull && current.physical?.identity == after.hull.binding)
      try #require(after.crewDeadline == expectedRecoveryDeadline)
      if after.crewAboard > 0 {
        let deadlineReached =
          game.commander.flightSimulation.physicalTime >= expectedRecoveryDeadline
        #expect(after.isRecovered == deadlineReached)
        #expect(game.isEMPDisabled(current) == !deadlineReached)
        #expect(current.physical?.npc?.role == officer.physical?.npc?.role)
        let electrical = try #require(current.physical?.npc?.resources?.electrical)
        if deadlineReached {
          #expect(current.physical?.empSource == nil)
          #expect(electrical.remaining > 0 && electrical.disabledAt == nil)
        } else {
          #expect(current.physical?.empSource == source)
          #expect(electrical.remaining == 0 && electrical.disabledAt != nil)
        }
      } else {
        #expect(!after.isRecovered && game.isEMPDisabled(current))
        #expect(current.physical?.empSource == source && current.physical?.npc == nil)
      }
    }
    let livePods = game.bodies.compactMap { $0.physical?.empCrewPod }
    let liveSourcePeople = Set(livePods.filter { $0.source == source })
    #expect(liveSourcePeople.isSubset(of: afterPeople))
    #expect(!game.bodies.contains { $0.physical?.spawnIdentity == before.originalSpawn })
    for _ in 0..<20 { game.tick(delta: 0.1) }
    #expect(game.commander.savedEMPState?.records[source]?.pods.count == after.pods.count)
    #expect(game.commander.savedEMPState?.records[source]?.lostCrewCount == before.lostCrewCount)
  }
}
