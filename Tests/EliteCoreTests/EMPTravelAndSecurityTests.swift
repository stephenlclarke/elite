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
        + "empRecovered=\(String(describing: emp?.isRecovered))"
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
    let original = try #require(game.bodies.first { $0.id == 1 && $0.hull == .cobra })
    let actor = try #require(original.physical?.identity)
    try disableNativeEMPActor(actor, game: &game)
    let source = try #require(
      game.bodies.first { $0.physical?.identity == actor }?.physical?.empSource)
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
    if after.crewAboard > 0 {
      #expect(after.isRecovered && !game.isEMPDisabled(hulls[0]))
      #expect(hulls[0].physical?.empSource == nil && hulls[0].physical?.npc != nil)
      #expect((hulls[0].physical?.npc?.resources?.electrical?.remaining ?? 0) > 0)
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
