import Foundation
import Testing

@testable import EliteCore

private func stationAutoGame() throws -> Game {
  // Controlled native unit boundary. Original mission routes and traffic are not edited.
  var game = Game(executive: false)
  game.screen = .status
  game.commander.system = 0
  game.selectedSystem = 0
  game.market = MarketItem.at(game.currentSystem)
  game.commander.credits = 100000
  try game.prepareG03FlightEquipment()
  try ScriptProcurementFixture.requirePaidG03Preparation(game)
  game.ensureMissionCalendar()
  game.launch()
  let station = try #require(game.commander.flightSimulation.anchors?.station)
  NativePagedSalvageFixture.moveObserver(
    &game, to: .init(position: station.position + .init(0, 0, -5000)))
  let id = game.nextBodyID
  game.nextBodyID += 1
  game.bodies.append(.init(id: id, hull: .cobra, position: .init(0, 0, 1000), hostile: true))
  game.ensurePhysicalActors()
  for index in game.bodies.indices where game.bodies[index].id != id {
    if game.bodies[index].physical?.npc != nil {
      game.bodies[index].hostile = false
      game.bodies[index].physical?.npc?.intention = .dock(station.identity)
    }
  }
  let index = try #require(game.bodies.firstIndex { $0.id == id })
  let spawn = SpawnIdentity(
    system: game.systemIdentity, visit: game.commander.flightSimulation.visit,
    sequence: 900, member: 0, producer: .ambient)
  game.bodies[index].missiles = 0
  game.bodies[index].physical?.spawnIdentity = spawn
  game.bodies[index].physical?.catalogueShipID = ShipCatalogue.nativeShip(.cobra)?.id
  game.bodies[index].physical?.npc?.legal = .init(value: 16)
  game.bodies[index].physical?.npc?.routeProvenance = .generated
  for _ in 0..<32 {
    game.key("tab")
    if game.autoPilot.targetActor == station.identity { break }
  }
  try #require(game.stationAutoDockingActive && game.autoPilot.targetActor == station.identity)
  return game
}

@Test func stationAutoNativeMountedHitPreservesViewToolStationAndWeaponLocks() throws {
  var game = try stationAutoGame()
  game.screen = .rear
  game.selectFlightTool(.miningLaser)
  StationDefenceRefusalObservation.enable(&game)
  StationDefenceRefusalObservation.emit(game, phase: "station-before")
  let before = game
  let attacker = try #require(game.bodies.first { $0.hostile })
  game.fireStationAutoLaser()
  StationDefenceRefusalObservation.emit(game, phase: "station-after")
  let hit = try #require(game.bodies.first { $0.id == attacker.id })
  #expect(hit.energy < attacker.energy && game.laserHeat > before.laserHeat)
  #expect(game.commander.crimeLedger != before.commander.crimeLedger && game.commander.legal == 0)
  #expect(game.screen == before.screen && game.selectedFlightTool == before.selectedFlightTool)
  #expect(game.autoPilot.targetActor == before.autoPilot.targetActor)
  #expect(
    game.weaponsTargetID == before.weaponsTargetID && game.missileArmed == before.missileArmed)
  #expect(game.commander.missiles == before.commander.missiles)
}

@Test(arguments: [
  "clean", "protected", "occluded", "unjoined", "idle-hostile", "disabled-source", "energy",
])
func stationAutoOffensiveRefusalKeepsNativeInventoryAndEmissionState(condition: String) throws {
  var game = try stationAutoGame()
  let index = try #require(game.bodies.firstIndex { $0.hostile })
  switch condition {
  case "clean": game.bodies[index].physical?.npc?.legal = .init()
  case "protected": game.bodies[index].navalTarget = true
  case "unjoined": game.bodies[index].physical = nil
  case "idle-hostile":
    game.bodies[index].physical?.npc?.intention = .navigate(
      position: .init(0, 0, 10000), speedUnitsPerSecond: 100)
  case "energy": game.energy = 1
  case "disabled-source":
    let player = try #require(game.commander.flightSimulation.player)
    game.bodies[index].physical?.empSource = player
  case "occluded":
    let id = game.nextBodyID
    game.nextBodyID += 1
    game.bodies.append(.init(id: id, hull: .cobra, position: .init(0, 0, 500)))
    game.ensurePhysicalActors()
  default: break
  }
  let before = game
  game.fireStationAutoLaser()
  #expect(game.commander == before.commander && game.bodies == before.bodies)
  #expect(game.laserHeat == before.laserHeat && game.fireCooldown == before.fireCooldown)
  #expect(game.autoPilot.targetActor == before.autoPilot.targetActor)
}

@Test(arguments: [
  "wanted", "clean", "protected", "stale", "zone", "self-defence", "prior-unlawful",
])
func stationAutoLawPreviewSharesActualWindowsWithoutAllocatingAnEmission(condition: String) {
  let player = crimeTestActor(1, position: .init(0, 0, condition == "zone" ? 500 : 2000), role: nil)
  let target = crimeTestActor(
    2, position: .init(0, 0, 3000), role: .pirate,
    legal: .init(value: condition == "clean" || condition == "self-defence" ? 0 : 16))
  var protection = MissionProtection()
  if condition == "protected" { protection.protectedActors.insert(target.identity) }
  var ledger = CrimeLedger()
  if condition == "self-defence" {
    _ = ledger.record(
      crimeTestIncident(1, time: 1, owner: target, victim: player),
      context: crimeTestContext(1, player: player, actors: [target]))
  }
  if condition == "prior-unlawful" {
    let clean = crimeTestActor(2)
    _ = ledger.record(
      crimeTestIncident(1, time: 1, owner: player, victim: clean),
      context: crimeTestContext(1, player: player, actors: [clean]))
  }
  let context = crimeTestContext(2, player: player, actors: [target], protection: protection)
  let victim = condition == "stale" ? crimeTestID(2, visit: 2) : target.identity
  let before = ledger
  let allowed = ledger.permitsAutonomousDefence(
    owner: player.identity, victim: victim, context: context)
  #expect(allowed == (condition == "wanted" || condition == "self-defence"))
  #expect(ledger == before)
}

@Test func stationAutoDefensiveAttitudeKeepsStationProgressAndOneCombinedThrustBudget() throws {
  var game = try stationAutoGame()
  let attacker = try #require(game.bodies.firstIndex { $0.hostile })
  game.bodies[attacker].position = .init(1000, 0, 0)
  let before = game.commander.flightSimulation.pose
  let stationActor = game.autoPilot.targetActor
  let station = try #require(game.autoTargetBody)
  let goal = station.entrancePosition + station.entranceNormal * station.stationApproachDistance
  let velocity = game.autoPilot.velocity
  let limit = game.workLimits.acceleration
  game.tick(delta: 0.1)
  #expect(game.autoPilot.targetActor == stationActor && game.stationAutoDockingActive)
  #expect(game.autoPilot.status == "DEFENDING APPROACH")
  #expect(game.flightWorldVelocity.length > 0)
  #expect(
    (game.commander.flightSimulation.pose.position - before.position)
      .dot(before.orientation.apply(goal.unit)) > 0)
  // Compare in world coordinates: rotating the cockpit must not count as extra thrust.
  let priorWorld = before.orientation.apply(velocity)
  #expect((game.flightWorldVelocity - priorWorld).length <= limit * 0.1 + 1e-8)
  #expect(game.flightWorldVelocity.length <= game.workLimits.speed + 1e-8)
  #expect(game.commander.legal == 0)
}

@Test func stationAutoDoorSafetyIgnoresCombatHeadingAndAdditionalEvasionThrust() {
  let station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 350))
  var baseline = AutoTargetControl()
  baseline.setApproachVelocity(.init(0, 0, 120))
  var defending = baseline
  let normal = baseline.steer(target: station, delta: 0.1)
  let defensive = defending.steer(
    target: station, delta: 0.1,
    defence: .init(aim: .init(1000, 0, 0), lateralVelocity: .init(100, 0, 0)))
  #expect(defending.velocity == baseline.velocity && defending.status == baseline.status)
  #expect(
    defensive.pitch == normal.pitch && defensive.yaw == normal.yaw && defensive.roll == normal.roll)
}

@Test(arguments: ["fitted", "absent", "low-energy"])
func stationAutoNativeECMRequiresActualEquipmentAndEnergyWithoutXYZZY(condition: String) throws {
  var game = try stationAutoGame()
  if condition != "absent" {
    try game.commander.grantEquipment(
      "E.C.M. System", at: .utility(.ecm), provenance: .grant("station AUTO unit"))
  }
  let index = try #require(game.bodies.firstIndex { $0.hostile })
  game.bodies[index].missiles = 1
  let id = game.bodies[index].id
  let launched = game.launchGameplayNPCMissile(bodyID: id)
  try #require(launched)
  if condition == "low-energy" { game.energy = 10 }
  let before = game
  try #require(!game.commander.xyzzyActive && !game.commander.autoECM)
  game.detectIncomingMissiles()
  #expect(game.ecmControl.ownFieldActive == (condition == "fitted"))
  #expect(game.energy == before.energy - (condition == "fitted" ? 10 : 0))
  #expect(game.autoPilot.targetActor == before.autoPilot.targetActor)
  #expect(game.weaponsTargetID == before.weaponsTargetID)
  #expect(game.commander.autoECM == before.commander.autoECM)
}

@Test func stationAutoUnknownIncomingAndNonfiniteThreatStillRequestConservativeEvasion() throws {
  var game = try stationAutoGame()
  let index = try #require(game.bodies.firstIndex { $0.hostile })
  game.bodies[index].position.x = .nan
  let id = game.nextBodyID
  game.nextBodyID += 1
  game.bodies.append(.init(id: id, hull: .missile, position: .init(200, 0, -500)))
  // Missing physical ownership must not be interpreted as a friendly missile.
  let station = try #require(game.autoTargetBody)
  let requestedGuidance = game.stationAutoGuidance(target: station)
  let guidance = try #require(requestedGuidance)
  #expect(
    guidance.aim == nil && guidance.lateralVelocity.finite && guidance.lateralVelocity.length > 0)
  let before = game.commander
  game.fireStationAutoLaser()
  #expect(game.commander == before)
}

@Test(arguments: [false, true])
func stationAutoMissilePublishesNativeFiniteOrExplicitUnlimitedSourceBeforeMotion(unlimited: Bool)
  async throws
{
  let fixture = try ScriptFreightFixture()
  defer { fixture.clean() }
  var game = try stationAutoGame()
  game.commander.unlimitedMissiles = unlimited
  game.laserHeat = 246.4
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  let before = await runtime.snapshot()
  await runtime.advanceStationAutoMissile(delta: 0.1)
  let after = await runtime.snapshot()
  let player = try #require(after.commander.flightSimulation.player)
  let missile = try #require(after.bodies.first { $0.physical?.ordnance?.origin.owner == player })
  let state = try #require(missile.physical?.ordnance)
  #expect(after.commander.missiles == before.commander.missiles - (unlimited ? 0 : 1))
  #expect(state.target == before.bodies.first(where: { $0.hostile })?.physical?.identity)
  #expect(state.origin.ordnance == missile.physical?.identity && state.termination == nil)
  #expect(
    after.ecmControl.events.contains { $0.announcement == .gameplay("AUTO DEFENCE: MISSILE AWAY") })
  #expect(
    after.commander.flightSimulation.physicalTime == before.commander.flightSimulation.physicalTime)
  #expect(
    after.autoPilot.targetActor == before.autoPilot.targetActor
      && after.weaponsTargetID == before.weaponsTargetID)
  #expect(
    after.commander.credits == before.commander.credits
      && after.commander.cargo == before.commander.cargo)
  await runtime.advanceStationAutoMissile(delta: 0.1)
  let repeated = await runtime.snapshot()
  #expect(repeated.commander == after.commander && repeated.bodies == after.bodies)
  try await runtime.load(from: fixture.save, persistMigrations: false)
  let restored = await runtime.snapshot()
  #expect(restored.commander.missiles == after.commander.missiles)
  #expect(restored.commander.equipmentInventory == after.commander.equipmentInventory)
}

@Test func stationAutoMissileSaveRefusalPreservesStockActorsClocksAndCanRecoverOnNewBinding()
  async throws
{
  let fixture = try ScriptFreightFixture()
  defer { fixture.clean() }
  var game = try stationAutoGame()
  game.laserHeat = 246.4
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  let before = await runtime.snapshot()
  let files = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
  let preserved = try fixture.blockWrites("auto-missile")
  await runtime.advanceStationAutoMissile(delta: 0.1)
  let refused = await runtime.snapshot()
  #expect(refused.commander == before.commander && refused.bodies == before.bodies)
  #expect(
    refused.gameplayRevision == before.gameplayRevision
      && refused.missileCooldown == before.missileCooldown)
  #expect(refused.stationAutoDefence?.missilePublicationRefused == true)
  #expect(
    refused.ecmControl.events.last?.announcement
      == .gameplay("AUTO DEFENCE: MISSILE LAUNCH UNAVAILABLE"))
  await runtime.advanceStationAutoMissile(delta: 0.1)
  let suppressed = await runtime.snapshot()
  #expect(suppressed.ecmControl.events == refused.ecmControl.events)
  #expect(suppressed.commander == refused.commander && suppressed.bodies == refused.bodies)
  try fixture.restoreWrites(preserved, files: files)
  let replacement = fixture.root.appendingPathComponent("replacement/commander.json")
  try await runtime.save(to: replacement)
  await runtime.advanceStationAutoMissile(delta: 0.1)
  let recovered = await runtime.snapshot()
  #expect(recovered.commander.missiles == before.commander.missiles - 1)
  #expect(recovered.stationAutoDefence?.missilePublicationRefused == false)
}

@Test func stationAutoManualCancellationClearsDefenceWithoutChangingRemainingNativeEquipment()
  async throws
{
  var game = try stationAutoGame()
  let station = try #require(game.autoTargetBody)
  _ = game.stationAutoGuidance(target: station)
  try #require(game.stationAutoDefence != nil)
  let before = game.commander.equipmentInventory
  var controls = Controls()
  controls.yaw = 0.5
  game.tick(delta: 0.1, controls: controls)
  #expect(game.autoPilot.targetActor == nil && game.stationAutoDefence == nil)
  #expect(game.commander.equipmentInventory == before)
}

@Test(arguments: [false, true])
func stationAutoMilitaryECMOrderWaitsForDurableMissileResponseAndVoice(offAxis: Bool) async throws {
  let fixture = try ScriptFreightFixture()
  defer { fixture.clean() }
  var game = try stationAutoGame()
  try game.commander.grantEquipment(
    TargetingTier.military.equipmentName, at: .targetingCore,
    provenance: .grant("station AUTO unit"))
  try game.commander.grantEquipment(
    "E.C.M. System", at: .utility(.ecm), provenance: .grant("station AUTO unit"))
  game.commander.retaliationEnabled = true
  let index = try #require(game.bodies.firstIndex { $0.hostile })
  game.bodies[index].missiles = 1
  let source = try #require(game.bodies[index].physical?.identity)
  let id = game.bodies[index].id
  let launched = game.launchGameplayNPCMissile(bodyID: id)
  try #require(launched)
  let station = game.autoPilot.targetActor
  let weaponLock = game.weaponsTargetID
  game.detectIncomingMissiles()
  #expect(
    game.ecmControl.events.contains {
      if case .incomingIdentified = $0.announcement { return true }
      return false
    })
  #expect(
    game.ecmControl.events.contains {
      if case .enemyTargeted = $0.announcement { return true }
      return false
    })
  try #require(game.retaliation.pendingResponse(time: game.time)?.actor == source)
  game.fireStationAutoLaser()
  #expect(game.fireCooldown > 0)
  // A real laser response cannot substitute for the confirmed military missile order.
  #expect(game.retaliation.pendingResponse(time: game.time)?.actor == source)
  // Exercise the native field clock, not a fabricated activation or confirmation.
  game.ecmControl.advance(delta: ECMControl.fieldDuration)
  try #require(!game.ecmControl.fieldActive && game.laserHeat < 240)
  #expect(
    game.ecmControl.events.contains {
      if case .missilesDestroyed(let count) = $0.announcement { return count > 0 }
      return false
    })
  if offAxis {
    // Controlled source geometry, with the actual native launch/ECM confirmation retained.
    game.bodies[index].position = .init(400, 0, 1000)
    game.bodies[index].hostile = false
    let player = try #require(game.commander.flightSimulation.player)
    game.bodies[index].physical?.npc?.intention = .flee(player)
  }
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  let before = await runtime.snapshot()
  await runtime.advanceStationAutoMissile(delta: 0.1)
  let after = await runtime.snapshot()
  #expect(after.commander.missiles == before.commander.missiles - 1)
  let player = try #require(after.commander.flightSimulation.player)
  let response = try #require(
    after.bodies.first { $0.energy > 0 && $0.physical?.ordnance?.origin.owner == player })
  #expect(response.physical?.ordnance?.target == source)
  #expect(after.retaliation.pendingResponse(time: after.time) == nil)
  #expect(
    after.ecmControl.events.contains {
      if case .missileLaunched = $0.announcement { return true }
      return false
    })
  #expect(after.autoPilot.targetActor == station && after.weaponsTargetID == weaponLock)
  await runtime.advanceStationAutoMissile(delta: 0.1)
  let repeated = await runtime.snapshot()
  #expect(
    repeated.commander.missiles == after.commander.missiles && repeated.bodies == after.bodies)
}

@Test func stationAutoDuplicateStationCannotAuthorizeWeaponsOrKeepTransientDefence() throws {
  var game = try stationAutoGame()
  let station = try #require(game.autoTargetBody)
  _ = game.stationAutoGuidance(target: station)
  game.bodies.append(station)
  let before = game
  #expect(!game.stationAutoDockingActive && game.stationAutoMissileTarget() == nil)
  game.fireStationAutoLaser()
  #expect(game.commander == before.commander && game.bodies == before.bodies)
  let guidance = game.stationAutoGuidance(target: station)
  #expect(guidance?.hazard == .unknown && game.stationAutoDefence == nil)
}

@Test(arguments: ["field", "incoming", "own-missile", "muzzle-occluded"])
func stationAutoMissileDefersForNativeFieldIncomingOrAlreadyActiveOwnedRound(condition: String)
  throws
{
  var game = try stationAutoGame()
  game.laserHeat = 246.4
  let target = try #require(game.bodies.first { $0.hostile })
  switch condition {
  case "field": game.ecmControl.setLegacyFrames(32)
  case "incoming":
    let index = try #require(game.bodies.firstIndex { $0.id == target.id })
    game.bodies[index].missiles = 1
    let launched = game.launchGameplayNPCMissile(bodyID: target.id)
    try #require(launched)
  case "own-missile":
    let launched = game.launchGameplayMissile(targetBodyID: target.id)
    try #require(launched)
  case "muzzle-occluded":
    let id = game.nextBodyID
    game.nextBodyID += 1
    game.bodies.append(.init(id: id, hull: .cargo, position: .init(0, 0, 70)))
    game.ensurePhysicalActors()
  default: break
  }
  let before = game
  #expect(game.stationAutoMissileTarget() == nil)
  #expect(game.commander == before.commander && game.bodies == before.bodies)
}

@Test(arguments: [1000.0, 3000.0])
func stationAutoOpportunisticMountedFireKeepsFarAttackersOutOfSteeringPolicy(range: Double) throws {
  var game = try stationAutoGame()
  let anchor = try #require(game.commander.flightSimulation.anchors?.station)
  NativePagedSalvageFixture.moveObserver(
    &game, to: .init(position: anchor.position + .init(-8000, 0, -8000)))
  let index = try #require(game.bodies.firstIndex { $0.hostile })
  game.bodies[index].position = .init(0, 0, range)
  let station = try #require(game.autoTargetBody)
  if range > 1500 {
    var baseline = game
    baseline.bodies[index].hostile = false
    baseline.bodies[index].physical?.npc?.intention = .dock(anchor.identity)
    let guidance = game.stationAutoGuidance(target: station)
    #expect(guidance?.hazard == .clear && guidance?.hasManeuver == false)
    game.applyAutoTarget(delta: 0.1, controls: Controls())
    baseline.applyAutoTarget(delta: 0.1, controls: Controls())
    #expect(game.pitch == baseline.pitch && game.yaw == baseline.yaw)
    #expect(game.autoPilot.velocity == baseline.autoPilot.velocity)
  }
  let before = game.bodies[index].energy
  game.fireStationAutoLaser()
  #expect(game.bodies[index].energy < before && game.commander.legal == 0)
  #expect(game.autoPilot.targetActor == station.physical?.identity)
}

@Test(arguments: [-0.1, 0.1])
func stationAutoMountedFireUsesActualMeshContactAtNativeBeamRangeBoundary(offset: Double) throws {
  var game = try stationAutoGame()
  let anchor = try #require(game.commander.flightSimulation.anchors?.station)
  NativePagedSalvageFixture.moveObserver(
    &game, to: .init(position: anchor.position + .init(-8000, 0, -8000)))
  let index = try #require(game.bodies.firstIndex { $0.hostile })
  game.bodies[index].position = .init(0, 0, 1000)
  let contact = try #require(
    try game.nearestMissionCollision(
      from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000, radius: 0,
      excludingBodyIDs: [], includePlayer: false))
  try #require(contact.selectedTargetBody?.id == game.bodies[index].id)
  let surfaceOffset = 1000 - contact.hit.distance
  game.bodies[index].position = .init(0, 0, 6000 + surfaceOffset + offset)
  let before = game
  game.fireStationAutoLaser()
  #expect((game.bodies[index].energy < before.bodies[index].energy) == (offset < 0))
  #expect(game.commander.legal == 0 && game.autoPilot.targetActor == before.autoPilot.targetActor)
}

@Test func stationAutoNeutralFrameReservesNativeECMCostInsteadOfStarvingItWithAnAlignedLaserShot()
  async throws
{
  var game = try stationAutoGame()
  try game.commander.grantEquipment(
    "E.C.M. System", at: .utility(.ecm), provenance: .grant("station AUTO unit"))
  let target = try #require(game.bodies.first { $0.hostile })
  let id = game.nextBodyID
  game.nextBodyID += 1
  game.bodies.append(.init(id: id, hull: .cobra, position: .init(400, 0, 1000), hostile: true))
  game.ensurePhysicalActors()
  let index = try #require(game.bodies.firstIndex { $0.id == id })
  let spawn = SpawnIdentity(
    system: game.systemIdentity, visit: game.commander.flightSimulation.visit,
    sequence: 902, member: 0, producer: .ambient)
  game.bodies[index].physical?.spawnIdentity = spawn
  game.bodies[index].physical?.catalogueShipID = ShipCatalogue.nativeShip(.cobra)?.id
  game.bodies[index].physical?.npc?.legal = .init(value: 16)
  game.bodies[index].physical?.npc?.routeProvenance = .generated
  game.bodies[index].missiles = 1
  let launched = game.launchGameplayNPCMissile(bodyID: id)
  try #require(launched)
  let recovery = 0.1 * game.commander.performance.recharge * game.commander.energyRechargeMultiplier
  game.energy = ECMControl.activationEnergyCost + Game.combatLaserEnergyCost * 0.5 - recovery
  let contact = try #require(
    try game.nearestMissionCollision(
      from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000, radius: 0,
      excludingBodyIDs: [], includePlayer: false))
  try #require(contact.selectedTargetBody?.id == target.id)
  try #require(game.energy > 0 && game.energy + recovery > ECMControl.activationEnergyCost)
  let runtime = GameRuntime(game: game)
  let before = await runtime.snapshot()
  let held = await runtime.controls
  try #require(held.pitch == 0 && held.yaw == 0 && held.throttle == 0 && !held.fire)
  let after = await runtime.advance(delta: 0.1)
  #expect(after.ecmControl.ownFieldActive && after.energy > 0)
  #expect(after.laserHeat == before.laserHeat && after.fireCooldown == before.fireCooldown)
  #expect(abs(after.energy - Game.combatLaserEnergyCost * 0.5) < 1e-8)
  #expect(after.commander.missiles == before.commander.missiles && after.commander.legal == 0)
  #expect(after.autoPilot.targetActor == before.autoPilot.targetActor)
  #expect(
    after.commander.flightSimulation.pose.position
      != before.commander.flightSimulation.pose.position)
}

private func stationAutoEntryBoundary() async throws -> Game {
  var game = try stationAutoGame()
  let station = try #require(game.autoTargetBody)
  let stationActor = try #require(station.physical?.identity)
  // A controlled, initially resting unit at the genuine external staging point.
  // Only ordinary native ticks establish its subsequent entry attitude and phase.
  for index in game.bodies.indices where game.bodies[index].physical?.npc != nil {
    game.bodies[index].hostile = false
    game.bodies[index].physical?.npc?.legal = .init()
    game.bodies[index].physical?.npc?.intention = .dock(stationActor)
  }
  let pose = game.commander.flightSimulation.pose
  let goal = pose.systemPoint(
    station.entrancePosition + station.entranceNormal * station.stationApproachDistance)
  let forward = pose.orientation.apply(station.entranceNormal * -1).unit
  let up = pose.orientation.apply(station.entranceUp).unit
  var orientation = Basis3()
  orientation.z = forward
  orientation.x = up.cross(forward).unit
  orientation.y = forward.cross(orientation.x).unit
  NativePagedSalvageFixture.moveObserver(&game, to: .init(position: goal, orientation: orientation))
  game.speed = 0
  game.autoPilot.setApproachVelocity(.init(0, 0, 0))
  let runtime = GameRuntime(game: game)
  for _ in 0..<128 {
    if game.autoPilot.finalApproach { break }
    game = await runtime.advance(delta: 0.1)
  }
  try #require(game.stationAutoDockingActive && game.autoPilot.finalApproach && !game.docked)
  return game
}

private func stationAutoAddNativeAttacker(_ game: inout Game, position: Vector3, sequence: UInt64)
  throws -> Int
{
  let id = game.nextBodyID
  game.nextBodyID += 1
  game.bodies.append(.init(id: id, hull: .cobra, position: position, hostile: true))
  game.ensurePhysicalActors()
  let index = try #require(game.bodies.firstIndex { $0.id == id })
  let spawn = SpawnIdentity(
    system: game.systemIdentity, visit: game.commander.flightSimulation.visit,
    sequence: sequence, member: 0, producer: .ambient)
  game.bodies[index].physical?.spawnIdentity = spawn
  game.bodies[index].physical?.catalogueShipID = ShipCatalogue.nativeShip(.cobra)?.id
  game.bodies[index].physical?.npc?.legal = .init(value: 16)
  game.bodies[index].physical?.npc?.routeProvenance = .generated
  return id
}

@Test func stationAutoAuthenticatedColdOffAxisResponsePublishesWhileGenuineEntryAttitudeContinues()
  async throws
{
  let fixture = try ScriptFreightFixture()
  defer { fixture.clean() }
  var game = try await stationAutoEntryBoundary()
  let id = try stationAutoAddNativeAttacker(&game, position: .init(400, 0, 1000), sequence: 903)
  let actor = try #require(game.bodies.first { $0.id == id }?.physical?.identity)
  let player = try #require(game.commander.flightSimulation.player)
  let shield = game.frontShield
  // The existing native NPC beam makes its own origin, physical hit and law window.
  game.emitLegacyNPCBeam(bodyID: id, damage: LaserKind.pulse.damage)
  try #require(game.frontShield < shield)
  let attackContext = try #require(game.gameplayContext())
  try #require(
    game.commander.crimeLedger.hasCurrentUnlawfulAttack(
      from: actor, against: player, context: attackContext))
  let nearer = try stationAutoAddNativeAttacker(&game, position: .init(-400, 0, 500), sequence: 904)
  let nearerActor = try #require(game.bodies.first { $0.id == nearer }?.physical?.identity)
  let context = try #require(game.gameplayContext())
  try #require(
    !game.commander.crimeLedger.hasCurrentUnlawfulAttack(
      from: nearerActor, against: player, context: context))
  try #require(game.laserHeat == 0 && game.stationAutoMissileTarget()?.physical?.identity == actor)
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  let before = await runtime.snapshot()
  await runtime.advanceStationAutoMissile(delta: 0.1)
  let staged = await runtime.snapshot()
  let missile = try #require(
    staged.bodies.first { $0.energy > 0 && $0.physical?.ordnance?.origin.owner == player })
  #expect(
    missile.physical?.ordnance?.target == actor
      && staged.commander.missiles == before.commander.missiles - 1)
  #expect(
    staged.autoPilot.finalApproach && staged.autoPilot.targetActor == before.autoPilot.targetActor)
  #expect(staged.autoPilot.velocity == before.autoPilot.velocity)
  #expect(staged.pitch == before.pitch && staged.yaw == before.yaw && staged.roll == before.roll)
  #expect(staged.weaponsTargetID == before.weaponsTargetID && staged.commander.legal == 0)
  #expect(
    staged.commander.flightSimulation.physicalTime == before.commander.flightSimulation.physicalTime
  )
  let moved = await runtime.advance(delta: 0.1)
  #expect(moved.autoPilot.stationDefencePhase == .defending && !moved.autoPilot.finalApproach)
  #expect(moved.autoPilot.targetActor == before.autoPilot.targetActor)
  #expect(
    moved.commander.flightSimulation.pose.position
      != staged.commander.flightSimulation.pose.position)
  #expect(
    (moved.flightWorldVelocity - staged.flightWorldVelocity).length
      <= staged.workLimits.acceleration * 0.1 + 1e-8)
  let station = try #require(moved.autoTargetBody)
  #expect(station.position.length > station.stationClearanceRadius)
}

@Test(arguments: ["clean-unhurt", "wanted-unhurt", "station-occluded", "craft-occluded"])
func stationAutoColdMissileRequiresActualAttackAndClearExplicitSourcePath(condition: String)
  async throws
{
  var game = try await stationAutoEntryBoundary()
  let id = try stationAutoAddNativeAttacker(&game, position: .init(400, 0, 1000), sequence: 905)
  let index = try #require(game.bodies.firstIndex { $0.id == id })
  let actor = try #require(game.bodies[index].physical?.identity)
  let player = try #require(game.commander.flightSimulation.player)
  if condition == "clean-unhurt" { game.bodies[index].physical?.npc?.legal = .init() }
  if condition == "station-occluded" || condition == "craft-occluded" {
    let shield = game.frontShield
    game.emitLegacyNPCBeam(bodyID: id, damage: LaserKind.pulse.damage)
    try #require(game.frontShield < shield)
    let context = try #require(game.gameplayContext())
    try #require(
      game.commander.crimeLedger.hasCurrentUnlawfulAttack(
        from: actor, against: player, context: context))
    if condition == "station-occluded" {
      let station = try #require(game.autoTargetBody)
      let overrides = game.gameplayMeshOverrides
      let stationMesh = overrides[station.id] ?? Mesh.hull(station.hull)
      let targetMesh = overrides[id] ?? Mesh.hull(game.bodies[index].hull)
      let stationRadius = try #require(stationMesh.vertices.map(\.length).max())
      let targetRadius = try #require(targetMesh.vertices.map(\.length).max())
      let muzzle = Vector3(0, 0, 24)
      var hiddenPosition: Vector3?
      // Search the bounded actual face set without excluding any scene body.
      for face in stationMesh.faces where face.count >= 3 {
        let center =
          (stationMesh.vertices[face[0]] + stationMesh.vertices[face[1]]
            + stationMesh.vertices[face[2]]) * (1.0 / 3.0)
        let offset = station.position + station.modelVector(center) - muzzle
        guard offset.length > 0,
          let contact = try game.nearestMissionCollision(
            from: muzzle, direction: offset.unit, range: offset.length + stationRadius,
            radius: 0, excludingBodyIDs: [], includePlayer: false),
          case .body(let first) = contact.hit.target, first == station.id
        else { continue }
        let beyondBounds =
          (station.position - muzzle).dot(offset.unit)
          + stationRadius + targetRadius + 1
        hiddenPosition = muzzle + offset.unit * beyondBounds
        break
      }
      let hidden = try #require(hiddenPosition)
      game.bodies[index].position = hidden
      game.bodies[index].physical?.npc?.intention = .engage(player)
      let offset = hidden - Vector3(0, 0, 24)
      let occlusion = try #require(
        try game.nearestMissionCollision(
          from: .init(0, 0, 24), direction: offset.unit, range: offset.length, radius: 0,
          excludingBodyIDs: [], includePlayer: false))
      try #require(occlusion.selectedTargetBody?.id == station.id)
      let cover = try #require(
        try game.nearestMissionCollision(
          from: hidden, direction: hidden.unit * -1, range: hidden.length,
          radius: 0, excludingBodyIDs: [id], includePlayer: true))
      try #require(cover.selectedTargetBody?.id == station.id)
      let guidance = game.stationAutoGuidance(target: station)
      #expect(guidance?.hazard == .clear && guidance?.handoverAllowed == true)
      #expect(guidance?.transitGoal == nil)
      game.applyAutoTarget(delta: 0.1, controls: Controls())
      #expect(
        game.autoPilot.finalApproach && game.autoPilot.targetActor == station.physical?.identity)
    } else {
      let blocker = game.nextBodyID
      game.nextBodyID += 1
      game.bodies.append(.init(id: blocker, hull: .cobra, position: .init(200, 0, 512)))
      game.ensurePhysicalActors()
      let offset = game.bodies[index].position - Vector3(0, 0, 24)
      let occlusion = try #require(
        try game.nearestMissionCollision(
          from: .init(0, 0, 24), direction: offset.unit, range: offset.length, radius: 0,
          excludingBodyIDs: [], includePlayer: false))
      try #require(occlusion.selectedTargetBody?.id == blocker)
    }
  }
  let before = game
  #expect(game.laserHeat == 0 && game.stationAutoMissileTarget() == nil)
  #expect(game.commander == before.commander && game.bodies == before.bodies)
  #expect(
    game.autoPilot.finalApproach && game.autoPilot.targetActor == before.autoPilot.targetActor)
}

@Test func stationAutoDefenceSuspendsEntryUntilCurrentHazardsClearAndReacquiresSpin() {
  var station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 1090))
  station.rotationRate = 0
  var control = AutoTargetControl()
  _ = control.steer(target: station, delta: 0.1)
  #expect(control.finalApproach && control.ready)
  var defence = StationAutoGuidance(
    aim: .init(0, 0, 600), lateralVelocity: .init(0, 0, 0),
    hazard: .active, interruptionAllowed: true, clearanceRadius: 400)
  let prior = control.velocity
  _ = control.steer(target: station, delta: 0.1, defence: defence)
  #expect(control.stationDefencePhase == .defending && !control.finalApproach && !control.ready)
  #expect((control.velocity - prior).length <= 24 + 1e-8)
  // A resting external goal must not silently restage an ongoing defensive episode.
  for hazard in [StationAutoHazard.active, .closing, .unknown] {
    defence.hazard = hazard
    for _ in 0..<4 {
      _ = control.steer(target: station, delta: 0.1, defence: defence)
      #expect(control.stationDefencePhase == .defending && !control.finalApproach && !control.ready)
    }
  }
  defence.hazard = .clear
  station.rotation = 0.6
  _ = control.steer(target: station, delta: 0.1, defence: defence)
  #expect(!control.finalApproach && !control.ready && control.status == "MATCHING SPIN")
  station.rotation = 0
  for _ in 0..<16 {
    if control.finalApproach { break }
    _ = control.steer(target: station, delta: 0.1, defence: defence)
  }
  #expect(control.finalApproach && control.ready)
}

@Test(arguments: ["structure", "stopping", "pending-entry"])
func stationAutoInterruptionRetainsNativeEntrySafetyWithoutStoppingClearance(condition: String) {
  var station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 1090))
  station.rotationRate = 0
  var normal = AutoTargetControl()
  _ = normal.steer(target: station, delta: 0.1)
  #expect(normal.finalApproach)
  if condition == "structure" { station.position.z = 350 }
  if condition == "stopping" { normal.setApproachVelocity(.init(40, 0, 800)) }
  var defended = normal
  let baseline = normal.steer(target: station, delta: 0.1)
  let response = defended.steer(
    target: station, delta: 0.1,
    defence: .init(
      aim: .init(600, 0, 0), lateralVelocity: .init(100, 0, 0),
      hazard: .active, interruptionAllowed: condition != "pending-entry", clearanceRadius: 400))
  #expect(defended.stationDefencePhase == .approach && defended.finalApproach)
  #expect(defended.velocity == normal.velocity)
  #expect(
    response.pitch == baseline.pitch && response.yaw == baseline.yaw
      && response.roll == baseline.roll)
}

@Test func stationAutoCurrentNativeFleeAssessesEveryAttackerAndUnknownOrdnanceStaysConservative()
  async throws
{
  var game = try await stationAutoEntryBoundary()
  let first = try stationAutoAddNativeAttacker(&game, position: .init(0, 0, 600), sequence: 906)
  let second = try stationAutoAddNativeAttacker(&game, position: .init(300, 0, 800), sequence: 907)
  game.emitLegacyNPCBeam(bodyID: first, damage: LaserKind.pulse.damage)
  game.emitLegacyNPCBeam(bodyID: second, damage: LaserKind.pulse.damage)
  let station = try #require(game.autoTargetBody)
  let context = try #require(game.gameplayContext())
  let playerActor = try #require(game.commander.flightSimulation.player)
  for id in [first, second] {
    let actor = try #require(game.bodies.first { $0.id == id }?.physical?.identity)
    try #require(
      game.commander.crimeLedger.hasCurrentUnlawfulAttack(
        from: actor, against: playerActor, context: context))
  }
  var guidance = game.stationAutoGuidance(target: station)
  #expect(guidance?.hazard == .active)
  let firstIndex = try #require(game.bodies.firstIndex { $0.id == first })
  game.bodies[firstIndex].hostile = false
  let player = try #require(game.commander.flightSimulation.player)
  game.bodies[firstIndex].physical?.npc?.intention = .flee(player)
  guidance = game.stationAutoGuidance(target: station)
  #expect(guidance?.hazard == .active)
  let secondIndex = try #require(game.bodies.firstIndex { $0.id == second })
  game.bodies[secondIndex].hostile = false
  game.bodies[secondIndex].physical?.npc?.intention = .flee(player)
  guidance = game.stationAutoGuidance(target: station)
  #expect(guidance?.hazard == .clear)
  let id = game.nextBodyID
  game.nextBodyID += 1
  var unknown = SpaceBody(id: id, hull: .missile, position: .init(100, 0, 300))
  unknown.enemyMissile = true
  game.bodies.append(unknown)
  let before = game
  guidance = game.stationAutoGuidance(target: station)
  #expect(guidance?.hazard == .unknown)
  #expect(game.commander == before.commander && game.bodies == before.bodies)
  #expect(
    game.laserHeat == before.laserHeat && game.commander.missiles == before.commander.missiles)
}

@Test func stationAutoAuthenticEntryAttackUsesMountedGunAndPhysicalEvasionWithOneBudget()
  async throws
{
  var game = try await stationAutoEntryBoundary()
  let id = try stationAutoAddNativeAttacker(&game, position: .init(0, 0, 600), sequence: 908)
  let shield = game.frontShield
  game.emitLegacyNPCBeam(bodyID: id, damage: LaserKind.pulse.damage)
  try #require(game.frontShield < shield)
  let before = game
  let victim = try #require(before.bodies.first { $0.id == id })
  let runtime = GameRuntime(game: game)
  game = await runtime.advance(delta: 0.1)
  let hit = try #require(game.bodies.first { $0.id == id })
  #expect(game.autoPilot.stationDefencePhase == .defending && !game.autoPilot.finalApproach)
  #expect(game.autoPilot.targetActor == before.autoPilot.targetActor)
  #expect(
    game.commander.flightSimulation.pose.position != before.commander.flightSimulation.pose.position
  )
  #expect(
    (game.flightWorldVelocity - before.flightWorldVelocity).length
      <= before.workLimits.acceleration * 0.1 + 1e-8)
  #expect(hit.energy < victim.energy && game.laserHeat > before.laserHeat && game.fireCooldown > 0)
  #expect(game.commander.missiles == before.commander.missiles && game.commander.legal == 0)
  let station = try #require(game.autoTargetBody)
  #expect(station.position.length > station.stationClearanceRadius)
}

@Test(arguments: ["q", "manual"])
func stationAutoCancellationPreservesFullEvasiveMomentumAndNativeCoasting(condition: String)
  async throws
{
  var game = try stationAutoGame()
  game.autoPilot.setApproachVelocity(.init(90, -40, -70))
  game.speed = 3
  let before = game.flightWorldVelocity
  if condition == "q" {
    game.key("q")
  } else {
    var controls = Controls()
    controls.pitch = 0.2
    game.applyAutoTarget(delta: 0.1, controls: controls)
  }
  #expect(game.autoPilot.targetID == nil && game.manualResidualFlight && game.speed == 0)
  #expect((game.flightWorldVelocity - before).length < 1e-8)
  let released = game.commander.flightSimulation.pose.position
  let runtime = GameRuntime(game: game)
  game = await runtime.advance(delta: 0.1)
  #expect((game.flightWorldVelocity - before).length <= game.workLimits.acceleration * 0.1 + 1e-8)
  #expect((game.commander.flightSimulation.pose.position - released - before * 0.1).length < 1e-8)
}

@Test func stationAutoClearedHazardReturnsToExternalGoalWithoutFollowingCombatBearing() {
  let station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 2000))
  var control = AutoTargetControl()
  var guidance = StationAutoGuidance(
    aim: .init(600, 0, 0), lateralVelocity: .init(80, 0, 0),
    hazard: .active, interruptionAllowed: true, clearanceRadius: 400)
  _ = control.steer(target: station, delta: 0.1, defence: guidance)
  #expect(control.stationDefencePhase == .defending)
  let prior = control.velocity
  guidance.hazard = .clear
  let returning = control.steer(target: station, delta: 0.1, defence: guidance)
  #expect(control.stationDefencePhase == .returning && !control.finalApproach && !control.ready)
  #expect(control.status == "RETURNING TO APPROACH" && returning.pitch == 0 && returning.yaw == 0)
  #expect((control.velocity - prior).length <= 24 + 1e-8)
}

@Test(arguments: [600.0, 1500.000001, 6000.0])
func stationAutoAuthenticPulseHazardUsesNativeRangeAndClosingBuffer(range: Double) throws {
  var game = try stationAutoGame()
  let index = try #require(game.bodies.firstIndex { $0.hostile })
  let id = game.bodies[index].id
  game.emitLegacyNPCBeam(bodyID: id, damage: LaserKind.pulse.damage)
  let context = try #require(game.gameplayContext())
  let actor = try #require(game.bodies[index].physical?.identity)
  try #require(
    game.commander.crimeLedger.hasCurrentUnlawfulAttack(
      from: actor, against: context.player.identity, context: context))
  game.bodies[index].position = .init(0, 0, range)
  let station = try #require(game.autoTargetBody)
  let guidance = game.stationAutoGuidance(target: station)
  let expected: StationAutoHazard = range <= 1500 ? .active : (range < 1501 ? .closing : .clear)
  #expect(guidance?.hazard == expected)
  game.bodies[index].physical?.empSource = context.player.identity
  let staleMarker = game.stationAutoGuidance(target: station)
  #expect(staleMarker?.hazard == .unknown)
}

@Test(arguments: [true, false])
func stationAutoAuthenticatedLauncherRemainsActiveWhenItsProjectileJoinIsLost(joined: Bool) throws {
  var game = try stationAutoGame()
  let index = try #require(game.bodies.firstIndex { $0.hostile })
  game.bodies[index].missiles = 1
  let launched = game.launchGameplayNPCMissile(bodyID: game.bodies[index].id)
  try #require(launched)
  let missile = try #require(game.bodies.firstIndex { $0.physical?.ordnance != nil })
  if !joined { game.bodies[missile].physical = nil }
  let station = try #require(game.autoTargetBody)
  let guidance = game.stationAutoGuidance(target: station)
  // The genuine launch itself authenticates its owner independently of the projectile join.
  let context = try #require(game.gameplayContext())
  let owner = try #require(game.bodies[index].physical?.identity)
  try #require(
    game.commander.crimeLedger.hasCurrentUnlawfulAttack(
      from: owner, against: context.player.identity, context: context))
  #expect(guidance?.hazard == .active)
}

@Test func stationAutoUnjoinedProjectileAloneCannotAuthorizeInterruptionOrFire() async throws {
  var game = try await stationAutoEntryBoundary()
  let id = game.nextBodyID
  game.nextBodyID += 1
  var projectile = SpaceBody(id: id, hull: .missile, position: .init(100, 0, 300))
  projectile.enemyMissile = true
  game.bodies.append(projectile)
  let station = try #require(game.autoTargetBody)
  let context = try #require(game.gameplayContext())
  for body in game.bodies {
    guard let source = body.physical?.identity else { continue }
    try #require(
      !game.commander.crimeLedger.hasCurrentUnlawfulAttack(
        from: source, against: context.player.identity, context: context))
  }
  let guidance = game.stationAutoGuidance(target: station)
  #expect(guidance?.hazard == .unknown && guidance?.aim == nil)
  let before = game
  game.fireStationAutoLaser()
  #expect(game.stationAutoMissileTarget() == nil)
  #expect(game.commander == before.commander && game.bodies == before.bodies)
  #expect(game.laserHeat == before.laserHeat && game.fireCooldown == before.fireCooldown)
  game.applyAutoTarget(delta: 0.1, controls: Controls())
  #expect(game.autoPilot.stationDefencePhase == .approach && game.autoPilot.finalApproach)
  #expect(game.autoPilot.targetActor == before.autoPilot.targetActor)
}

@Test func stationAutoCombatTracePreservesNativeAdmissionCandidateIsolationAndLifecycle()
  async throws
{
  let fixture = try ScriptFreightFixture()
  defer { fixture.clean() }
  let initial = try stationAutoGame()
  let target = try #require(initial.bodies.first { $0.hostile })
  let victim = try #require(target.physical?.identity)
  let player = try #require(initial.commander.flightSimulation.player)
  let ordinary = GameRuntime(game: initial)
  let recording = GameRuntime(game: initial, saveURL: fixture.save)
  await recording.enableStationDefenceDiagnostics()
  try await recording.save(to: fixture.save)
  let withoutTrace = await ordinary.advance(delta: 0.1)
  let observed = await recording.advance(delta: 0.1)
  let ordinaryVictim = try #require(withoutTrace.bodies.first { $0.id == target.id })
  let observedVictim = try #require(observed.bodies.first { $0.id == target.id })
  let trace = try #require(observed.gameplayCombatTrace)
  let accepted = try #require(
    trace.incidents.first {
      $0.origin.owner == player && $0.victim == victim && $0.kind == .laser
        && $0.outcome == .hit && $0.mount == .front
    })
  #expect(withoutTrace.gameplayCombatTrace == nil)
  #expect(ordinaryVictim.energy < target.energy && observedVictim.energy == ordinaryVictim.energy)
  #expect(
    observed.laserHeat == withoutTrace.laserHeat
      && observed.fireCooldown == withoutTrace.fireCooldown)
  #expect(
    observed.energy == withoutTrace.energy && observed.frontShield == withoutTrace.frontShield)
  #expect(
    observed.commander.legal == withoutTrace.commander.legal
      && observed.commander.missiles == withoutTrace.commander.missiles)
  #expect(observed.flightWorldVelocity == withoutTrace.flightWorldVelocity)

  let contact = try #require(
    try observed.nearestMissionCollision(
      from: .init(0, 0, 0), direction: observedVictim.position.unit,
      range: observedVictim.position.length, radius: 0, excludingBodyIDs: [], includePlayer: false))
  try #require(contact.selectedTargetBody?.physical?.identity == victim)
  var rejected = observed
  // Reuse a real origin and mesh contact; malformed damage must fail native admission.
  let refused = rejected.applyCombatHit(
    contact.hit, origin: accepted.origin, kind: .laser, damage: .nan)
  #expect(refused == nil)
  #expect(rejected.commander == observed.commander && rejected.bodies == observed.bodies)
  #expect(rejected.gameplayCombatTrace?.incidents == trace.incidents)

  do {
    var discardedCandidate = observed
    let launched = discardedCandidate.launchGameplayMissile(targetBodyID: target.id)
    try #require(launched)
    #expect(discardedCandidate.commander.missiles == observed.commander.missiles - 1)
    #expect(
      discardedCandidate.gameplayCombatTrace?.incidents.contains {
        $0.origin.owner == player && $0.victim == victim && $0.kind == .missile
          && $0.outcome == .targetedLaunch && $0.origin.ordnance != nil
      } == true)
  }
  // The installed value still owns its original physical stock, bodies and observations.
  let installed = await recording.snapshot()
  #expect(installed.commander == observed.commander && installed.bodies == observed.bodies)
  #expect(
    installed.gameplayCombatTrace?.epoch == trace.epoch
      && installed.gameplayCombatTrace?.incidents == trace.incidents
      && installed.gameplayCombatTrace?.dropped == trace.dropped)
  let restarted = GameRuntime(game: observed)
  let freshRuntime = await restarted.snapshot()
  #expect(freshRuntime.gameplayCombatTrace == nil)
  try await recording.load(from: fixture.save, persistMigrations: false)
  let loaded = await recording.snapshot()
  #expect(loaded.gameplayCombatTrace == nil)
  #expect(loaded.commander.missiles == initial.commander.missiles)
}

@Test func stationAutoUncoveredNativeBeamCannotHandOverToStationaryAlignment() async throws {
  var game = try await stationAutoEntryBoundary()
  let id = try stationAutoAddNativeAttacker(&game, position: .init(300, 0, -1000), sequence: 909)
  let actor = try #require(game.bodies.first { $0.id == id }?.physical?.identity)
  let player = try #require(game.commander.flightSimulation.player)
  let destination = game.autoPilot.targetActor
  let shields = game.frontShield + game.rearShield
  // The actual emitter and native ray establish damage and the current law window.
  game.emitLegacyNPCBeam(bodyID: id, damage: LaserKind.pulse.damage)
  try #require(game.frontShield + game.rearShield < shields)
  let context = try #require(game.gameplayContext())
  try #require(
    game.commander.crimeLedger.hasCurrentUnlawfulAttack(
      from: actor, against: player, context: context))
  let initialPosition = game.commander.flightSimulation.pose.position
  for _ in 0..<8 {
    let station = try #require(game.autoTargetBody)
    let observation = game.stationAutoGuidance(target: station)
    let guidance = try #require(observation)
    #expect(guidance.hazard == .active && !guidance.joinedIncoming && !guidance.handoverAllowed)
    let transit = try #require(guidance.transitGoal)
    let attacker = try #require(game.bodies.first { $0.id == id })
    let away = station.position - attacker.position
    #expect(transit.finite && (transit - station.position).length > guidance.clearanceRadius)
    #expect((transit - station.position).dot(away) > 0)
    let before = game.flightWorldVelocity
    game.tick(delta: 0.1)
    #expect(game.autoPilot.stationDefencePhase == .defending)
    #expect(!game.autoPilot.ready && !game.autoPilot.finalApproach)
    #expect(game.autoPilot.targetActor == destination && game.screen != .gameOver)
    #expect((game.flightWorldVelocity - before).length <= game.workLimits.acceleration * 0.1 + 1e-8)
    #expect(station.position.length > station.stationClearanceRadius)
  }
  #expect((game.commander.flightSimulation.pose.position - initialPosition).length > 0)
}

@Test func stationAutoClosingHandoverUsesActualBrakingBoundaryAndKeepsOneThrustBudget() {
  var station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 2000))
  station.rotationRate = 0
  var control = AutoTargetControl()
  control.setApproachVelocity(.init(0, 0, 600))
  var pressure = StationAutoGuidance(
    aim: .init(1000, 0, 0), lateralVelocity: .init(150, 0, 0),
    hazard: .active, interruptionAllowed: true, clearanceRadius: 400, handoverAllowed: true)
  _ = control.steer(target: station, delta: 0.1, defence: pressure)
  pressure.hazard = .closing
  let outside = control.velocity
  _ = control.steer(target: station, delta: 0.1, defence: pressure)
  #expect(control.stationDefencePhase == .defending)
  #expect((control.velocity - outside).length <= 24 + 1e-8)
  station.position.z = 1800
  let before = control.velocity
  let steering = control.steer(target: station, delta: 0.1, defence: pressure)
  #expect(control.stationDefencePhase == .returning && !control.ready && !control.finalApproach)
  #expect(steering.pitch == 0 && steering.yaw == 0)
  #expect((control.velocity - before).length <= 24 + 1e-8)
  #expect(control.velocity.length > AutoTargetControl.policyLimits.speed)
}

@Test func stationAutoClosingHandoverKeepsReturningThroughFreshReadinessAndSpin() {
  var station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 1090))
  station.rotationRate = 0
  var control = AutoTargetControl()
  _ = control.steer(target: station, delta: 0.1)
  #expect(control.finalApproach)
  var pressure = StationAutoGuidance(
    aim: .init(600, 0, 0), lateralVelocity: .init(150, 0, 0),
    hazard: .active, interruptionAllowed: true, clearanceRadius: 400, handoverAllowed: true)
  _ = control.steer(target: station, delta: 0.1, defence: pressure)
  #expect(control.stationDefencePhase == .defending && !control.finalApproach && !control.ready)
  pressure.hazard = .closing
  station.rotation = 0.6
  for _ in 0..<8 {
    let before = control.velocity
    _ = control.steer(target: station, delta: 0.1, defence: pressure)
    #expect(control.stationDefencePhase == .returning && !control.finalApproach && !control.ready)
    #expect((control.velocity - before).length <= 24 + 1e-8)
  }
  station.rotation = 0
  for _ in 0..<32 {
    if control.finalApproach { break }
    _ = control.steer(target: station, delta: 0.1, defence: pressure)
  }
  #expect(control.stationDefencePhase == .returning && control.finalApproach && control.ready)
  for _ in 0..<8 {
    let before = control.velocity
    _ = control.steer(target: station, delta: 0.1, defence: pressure)
    #expect(control.stationDefencePhase == .returning && control.finalApproach)
    #expect((control.velocity - before).length <= 24 + 1e-8)
  }
}

@Test func stationAutoBlockedStationRouteCannotUseDirectGoalForBeamHandover() {
  var station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 1600))
  station.orientation.rotate(pitch: 0, roll: 0, yaw: .pi)
  var control = AutoTargetControl()
  control.setApproachVelocity(.init(2000, 0, 0))
  let pressure = StationAutoGuidance(
    aim: .init(1000, 0, 0), lateralVelocity: .init(150, 0, 0),
    hazard: .active, interruptionAllowed: true, clearanceRadius: 500, handoverAllowed: true)
  for _ in 0..<4 {
    let before = control.velocity
    _ = control.steer(target: station, delta: 0.1, defence: pressure)
    #expect(control.stationDefencePhase == .defending && !control.finalApproach)
    #expect((control.velocity - before).length <= 24 + 1e-8)
    #expect(control.velocity.length > AutoTargetControl.policyLimits.speed)
  }
}

@Test(arguments: ["unknown-projectile", "malformed-threat", "ambiguous-threat", "stale-EMP"])
func stationAutoMixedAuthenticBeamAndUnknownFactsCannotGrantHandover(condition: String) async throws
{
  var game = try await stationAutoEntryBoundary()
  let id = try stationAutoAddNativeAttacker(&game, position: .init(300, 0, -600), sequence: 910)
  game.emitLegacyNPCBeam(bodyID: id, damage: LaserKind.pulse.damage)
  let source = try #require(game.bodies.first { $0.id == id }?.physical?.identity)
  let context = try #require(game.gameplayContext())
  try #require(
    game.commander.crimeLedger.hasCurrentUnlawfulAttack(
      from: source, against: context.player.identity, context: context))
  game.applyAutoTarget(delta: 0.1, controls: Controls())
  try #require(game.autoPilot.stationDefencePhase == .defending && !game.autoPilot.finalApproach)
  if condition == "unknown-projectile" {
    let projectile = game.nextBodyID
    game.nextBodyID += 1
    game.bodies.append(.init(id: projectile, hull: .missile, position: .init(100, 0, 300)))
  } else {
    let other = try stationAutoAddNativeAttacker(
      &game, position: .init(500, 0, -800), sequence: 911)
    let index = try #require(game.bodies.firstIndex { $0.id == other })
    switch condition {
    case "malformed-threat": game.bodies[index].position.x = .nan
    case "ambiguous-threat": game.bodies.append(game.bodies[index])
    case "stale-EMP": game.bodies[index].physical?.empSource = context.player.identity
    default: break
    }
  }
  let station = try #require(game.autoTargetBody)
  let requested = game.stationAutoGuidance(target: station)
  let guidance = try #require(requested)
  let expected: StationAutoHazard =
    condition == "malformed-threat" || condition == "ambiguous-threat" ? .unknown : .active
  #expect(guidance.hazard == expected && !guidance.handoverAllowed && !guidance.joinedIncoming)
  for _ in 0..<8 {
    let before = game.flightWorldVelocity
    game.applyAutoTarget(delta: 0.1, controls: Controls())
    #expect(game.autoPilot.stationDefencePhase == .defending && !game.autoPilot.finalApproach)
    #expect(!game.autoPilot.ready)
    #expect((game.flightWorldVelocity - before).length <= game.workLimits.acceleration * 0.1 + 1e-8)
  }
}

@Test func stationAutoNewJoinedOrdnanceInterruptsBeamHandoverWithStoppingClearance() async throws {
  var game = try await stationAutoEntryBoundary()
  let id = try stationAutoAddNativeAttacker(&game, position: .init(300, 0, -600), sequence: 912)
  game.emitLegacyNPCBeam(bodyID: id, damage: LaserKind.pulse.damage)
  let destination = game.autoPilot.targetActor
  game.applyAutoTarget(delta: 0.1, controls: Controls())
  #expect(game.autoPilot.stationDefencePhase == .defending)
  let index = try #require(game.bodies.firstIndex { $0.id == id })
  let player = try #require(game.commander.flightSimulation.player)
  game.bodies[index].hostile = false
  game.bodies[index].physical?.npc?.intention = .flee(player)
  let returningStation = try #require(game.autoTargetBody)
  let clear = game.stationAutoGuidance(target: returningStation)
  try #require(clear?.hazard == .clear)
  game.applyAutoTarget(delta: 0.1, controls: Controls())
  #expect(game.autoPilot.stationDefencePhase == .returning)
  game.bodies[index].hostile = true
  game.bodies[index].physical?.npc?.intention = .engage(player)
  game.bodies[index].missiles = 1
  let launched = game.launchGameplayNPCMissile(bodyID: id)
  try #require(launched)
  let station = try #require(game.autoTargetBody)
  let requested = game.stationAutoGuidance(target: station)
  let guidance = try #require(requested)
  #expect(guidance.hazard == .active && guidance.joinedIncoming && !guidance.handoverAllowed)
  let before = game.flightWorldVelocity
  game.applyAutoTarget(delta: 0.1, controls: Controls())
  #expect(
    game.autoPilot.stationDefencePhase == .defending && !game.autoPilot.ready
      && !game.autoPilot.finalApproach)
  #expect(game.autoPilot.targetActor == destination)
  #expect((game.flightWorldVelocity - before).length <= game.workLimits.acceleration * 0.1 + 1e-8)
  #expect(station.position.length > station.stationClearanceRadius)
}

@Test func stationAutoHandoverRevokesExteriorReadinessWhenMixedUnknownsAppear() {
  var station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 1090))
  station.rotationRate = 0
  var control = AutoTargetControl()
  _ = control.steer(target: station, delta: 0.1)
  var observations = StationAutoGuidance(
    aim: .init(600, 0, 0), lateralVelocity: .init(150, 0, 0),
    hazard: .active, interruptionAllowed: true, clearanceRadius: 400, handoverAllowed: true)
  _ = control.steer(target: station, delta: 0.1, defence: observations)
  observations.hazard = .closing
  for _ in 0..<16 {
    if control.finalApproach { break }
    _ = control.steer(target: station, delta: 0.1, defence: observations)
  }
  #expect(control.stationDefencePhase == .returning && control.finalApproach && control.ready)
  // Unknown observations revoke the prior safe closing-pressure handover.
  observations.hazard = .unknown
  observations.handoverAllowed = false
  let before = control.velocity
  _ = control.steer(target: station, delta: 0.1, defence: observations)
  #expect(control.stationDefencePhase == .returning && !control.finalApproach && !control.ready)
  #expect((control.velocity - before).length <= 24 + 1e-8)
  observations.hazard = .closing
  observations.handoverAllowed = true
  for _ in 0..<16 {
    if control.finalApproach { break }
    _ = control.steer(target: station, delta: 0.1, defence: observations)
  }
  #expect(control.stationDefencePhase == .returning && control.finalApproach && control.ready)
}

@Test func stationAutoActualNativeFinalTrajectoryBrakesBeforeStrictEntryAndPublishesRealDock()
  async throws
{
  let fixture = try ScriptFreightFixture()
  defer { fixture.clean() }
  var game = try await stationAutoEntryBoundary()
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  var peak = 0.0
  var nearFrames = 0
  var crossingWasSlow = false
  for _ in 0..<512 {
    let before = game
    let station = try #require(before.autoTargetBody)
    let distance = -station.entrancePosition.dot(station.entranceNormal)
    game = await runtime.advance(delta: 0.1)
    if game.docked {
      crossingWasSlow =
        before.flightWorldVelocity.length < 144
        && before.flightWorldVelocity.length <= 48 + 1e-8
      break
    }
    let speed = game.flightWorldVelocity.length
    peak = max(peak, speed)
    #expect(
      (game.flightWorldVelocity - before.flightWorldVelocity).length
        <= before.workLimits.acceleration * 0.1 + 1e-8)
    #expect(speed <= before.workLimits.speed + 1e-8)
    if speed > 48 + 1e-8 {
      #expect(
        speed * 0.1 + (speed * speed - 48 * 48) / (2 * before.workLimits.acceleration)
          <= distance - 200 + 1e-6)
    }
    if distance <= 200 {
      nearFrames += 1
      #expect(speed <= 48 + 1e-8)
    }
    #expect(game.screen != .gameOver && game.message != "DOCKING COLLISION")
  }
  #expect(peak > 144 && nearFrames > 0 && crossingWasSlow)
  #expect(game.docked && game.nativeMainStationDockEvidenceIsCurrent)
}

@Test func stationAutoReturningAcquiresSpinDuringRealExteriorMotionWithoutPrematureEntry()
  async throws
{
  var game = try await stationAutoEntryBoundary()
  let station = try #require(game.autoTargetBody)
  let pose = game.commander.flightSimulation.pose
  var start = pose
  start.position = pose.position + pose.orientation.apply(station.entranceNormal) * 600
  start.orientation.rotate(pitch: 0, roll: 0.9, yaw: 0.4)
  // Only the initial fixture is reframed; subsequent attitude and translation are native ticks.
  NativePagedSalvageFixture.moveObserver(&game, to: start)
  game.speed = 0
  game.autoPilot.setApproachVelocity(.init(0, 0, 0))
  let id = try stationAutoAddNativeAttacker(&game, position: .init(300, 0, -1000), sequence: 913)
  game.emitLegacyNPCBeam(bodyID: id, damage: LaserKind.pulse.damage)
  let actor = try #require(game.bodies.first { $0.id == id }?.physical?.identity)
  let player = try #require(game.commander.flightSimulation.player)
  let context = try #require(game.gameplayContext())
  try #require(
    game.commander.crimeLedger.hasCurrentUnlawfulAttack(
      from: actor, against: player, context: context))
  let destination = game.autoPilot.targetActor
  var sawDefence = false
  var sawMovingAcquisition = false
  var sawCorrectiveMovingPhase = false
  let delta = 0.1
  var moved = 0.0
  var freshFinal = false
  for _ in 0..<256 {
    let before = game
    game.tick(delta: delta)
    let distance =
      (game.commander.flightSimulation.pose.position
      - before.commander.flightSimulation.pose.position).length
    moved += distance
    sawDefence = sawDefence || game.autoPilot.stationDefencePhase == .defending
    #expect(game.autoPilot.targetActor == destination && game.screen != .gameOver)
    #expect(
      (game.flightWorldVelocity - before.flightWorldVelocity).length
        <= game.workLimits.acceleration * delta + 1e-8)
    #expect(abs(game.autoPilot.rollRate) <= min(1, game.workLimits.rollRate) + 1e-8)
    #expect(abs(game.autoPilot.rollRate - before.autoPilot.rollRate) <= 0.8 * delta + 1e-8)
    if game.autoPilot.stationDefencePhase == .returning && game.autoPilot.positionError > 40 {
      #expect(!game.autoPilot.ready && !game.autoPilot.finalApproach)
      if distance > 0 && abs(game.roll) > 1e-4 {
        sawMovingAcquisition = true
        let currentStation = try #require(game.autoTargetBody)
        let actualUp = currentStation.entranceUp
        // Native camera rotation applies pitch, then yaw, then roll. Undo only that last
        // camera roll; actual station spin/world geometry and actual pitch/yaw remain intact.
        let withoutCameraRoll = actualUp.rotated(pitch: 0, roll: -game.roll * delta, yaw: 0)
        if hypot(actualUp.x, actualUp.y) > sqrt(Double.ulpOfOne) {
          let actualPhase = abs(atan2(actualUp.x, actualUp.y))
          let uncorrectedPhase = abs(atan2(withoutCameraRoll.x, withoutCameraRoll.y))
          let roundoff = max(actualPhase.ulp, uncorrectedPhase.ulp) * 16
          sawCorrectiveMovingPhase =
            sawCorrectiveMovingPhase
            || actualPhase + roundoff < uncorrectedPhase
        }
        #expect(
          game.commander.flightSimulation.pose.orientation
            != before.commander.flightSimulation.pose.orientation)
      }
    }
    let invalidEntryAcquisition =
      before.flightWorldVelocity.length >= 1
      || game.autoPilot.positionError >= 40 || game.autoPilot.facingError >= 0.02
      || abs(game.autoPilot.phaseError) >= 0.03 || game.autoPilot.rateError >= 0.02
    if invalidEntryAcquisition {
      #expect(!game.autoPilot.ready && !game.autoPilot.finalApproach)
    }
    if game.autoPilot.ready {
      #expect(before.flightWorldVelocity.length < 1 && game.autoPilot.positionError < 40)
      #expect(
        game.autoPilot.facingError < 0.02 && abs(game.autoPilot.phaseError) < 0.03
          && game.autoPilot.rateError < 0.02)
    }
    if sawDefence && game.autoPilot.finalApproach {
      freshFinal = true
      break
    }
  }
  #expect(sawDefence && sawMovingAcquisition && moved > 100)
  #expect(sawCorrectiveMovingPhase)
  #expect(
    freshFinal,
    Comment(
      "Status: \(game.autoPilot.status), goal: \(game.autoPilot.positionError), facing: \(game.autoPilot.facingError), phase: \(game.autoPilot.phaseError), rate: \(game.autoPilot.rateError), velocity: \(game.flightWorldVelocity)"
    ))
}

/// Controlled native selection boundary, using real emitted beams for both attack joins.
/// The original history flights, loadout, traffic and assertions remain unchanged.
private func stationAutoTrackingPair() throws -> (game: Game, retained: Int, contender: Int) {
  var game = try stationAutoGame()
  let first = try #require(game.bodies.firstIndex { $0.hostile })
  let retained = game.bodies[first].id
  let contender = try stationAutoAddNativeAttacker(
    &game, position: .init(300, 0, 1150), sequence: 940)
  let second = try #require(game.bodies.firstIndex { $0.id == contender })
  game.bodies[first].missiles = 0
  game.bodies[second].missiles = 0
  game.emitLegacyNPCBeam(bodyID: retained, damage: LaserKind.pulse.damage)
  game.emitLegacyNPCBeam(bodyID: contender, damage: LaserKind.pulse.damage)
  let context = try #require(game.gameplayContext())
  for id in [retained, contender] {
    let actor = try #require(game.bodies.first { $0.id == id }?.physical?.identity)
    try #require(
      game.commander.crimeLedger.hasCurrentUnlawfulAttack(
        from: actor, against: context.player.identity, context: context))
  }
  let station = try #require(game.autoTargetBody)
  _ = game.stationAutoGuidance(target: station)
  try #require(game.stationAutoDefence?.combatActor == game.bodies[first].physical?.identity)
  return (game, retained, contender)
}

@Test func stationAutoResponseKeepsCurrentActorWhenNearestDistancesCross() throws {
  let pair = try stationAutoTrackingPair()
  var game = pair.game
  let first = try #require(game.bodies.firstIndex { $0.id == pair.retained })
  let second = try #require(game.bodies.firstIndex { $0.id == pair.contender })
  let retained = try #require(game.bodies[first].physical?.identity)
  let destination = game.autoPilot.targetActor
  game.bodies[first].position = .init(0, 0, 1100)
  game.bodies[second].position = .init(100, 0, 600)
  let station = try #require(game.autoTargetBody)
  let guidanceValue = game.stationAutoGuidance(target: station)
  let guidance = try #require(guidanceValue)
  #expect(game.stationAutoDefence?.combatActor == retained)
  #expect(guidance.aim == game.bodies[first].position)
  #expect(game.autoPilot.targetActor == destination && game.commander.legal == 0)
}

@Test(arguments: ["dead", "outside-current-range"])
func stationAutoResponseReplacesCurrentActorAndResetsMotion(condition: String) throws {
  let pair = try stationAutoTrackingPair()
  var game = pair.game
  let first = try #require(game.bodies.firstIndex { $0.id == pair.retained })
  let second = try #require(game.bodies.firstIndex { $0.id == pair.contender })
  let station = try #require(game.autoTargetBody)
  let limits = game.workLimits
  let initialValue = game.stationAutoGuidance(target: station)
  let initial = try #require(initialValue)
  _ = game.autoPilot.steer(target: station, delta: 0.1, limits: limits, defence: initial)
  game.bodies[first].position = .init(50, 0, 1000)
  let movingValue = game.stationAutoGuidance(target: station)
  let moving = try #require(movingValue)
  _ = game.autoPilot.steer(target: station, delta: 0.1, limits: limits, defence: moving)
  if condition == "dead" {
    game.bodies[first].energy = 0
  } else {
    game.bodies[first].position = .init(0, 0, 9000)
  }
  game.bodies[second].position = .init(-25, 0, 1000)
  let replacementValue = game.stationAutoGuidance(target: station)
  let replacement = try #require(replacementValue)
  #expect(game.stationAutoDefence?.combatActor == game.bodies[second].physical?.identity)
  #expect(replacement.aim == game.bodies[second].position)
  let actual = game.autoPilot.steer(
    target: station, delta: 0.1, limits: limits, defence: replacement)
  var fresh = AutoTargetControl()
  let expected = fresh.steer(target: station, delta: 0.1, limits: limits, defence: replacement)
  // A new actor starts from its own bearing, without the previous actor's measured motion.
  #expect(actual.pitch == expected.pitch && actual.yaw == expected.yaw)
}

@Test func stationAutoConfirmedMilitaryResponsePreemptsRetainedActor() throws {
  let pair = try stationAutoTrackingPair()
  var game = pair.game
  // Same controlled military/ECM unit fit used by the existing native confirmation tests.
  try game.commander.grantEquipment(
    TargetingTier.military.equipmentName, at: .targetingCore,
    provenance: .grant("station AUTO unit"))
  try game.commander.grantEquipment(
    "E.C.M. System", at: .utility(.ecm), provenance: .grant("station AUTO unit"))
  game.commander.retaliationEnabled = true
  let second = try #require(game.bodies.firstIndex { $0.id == pair.contender })
  game.bodies[second].missiles = 1
  let actor = try #require(game.bodies[second].physical?.identity)
  let launched = game.launchGameplayNPCMissile(bodyID: pair.contender)
  try #require(launched)
  game.detectIncomingMissiles()
  try #require(game.retaliation.pendingResponse(time: game.time)?.actor == actor)
  let station = try #require(game.autoTargetBody)
  let destination = game.autoPilot.targetActor
  let guidanceValue = game.stationAutoGuidance(target: station)
  let guidance = try #require(guidanceValue)
  #expect(game.stationAutoDefence?.combatActor == actor)
  #expect(guidance.aim == game.bodies[second].position)
  #expect(game.retaliation.pendingResponse(time: game.time)?.actor == actor)
  #expect(game.autoPilot.targetActor == destination && game.commander.legal == 0)
}

@Test(arguments: ["pitch", "yaw"])
func stationAutoDefensiveTrackerAcquiresMovingBearingWithinTurnAndThrustLimits(axis: String) {
  var station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 5000))
  station.rotationRate = 0
  var control = AutoTargetControl()
  var bearing = Vector3(0, 0, 1000)
  let limits = AutoTargetControl.policyLimits
  let delta = 0.05
  let angularRate = 0.25
  var peakSettledError = 0.0
  for step in 0..<160 {
    // A prescribed moving line of sight plus the actual returned camera rotation closes the loop.
    bearing = bearing.rotated(
      pitch: axis == "pitch" ? -angularRate * delta : 0, roll: 0,
      yaw: axis == "yaw" ? -angularRate * delta : 0)
    if step >= 80 {
      peakSettledError = max(
        peakSettledError,
        hypot(
          atan2(bearing.y, hypot(bearing.x, bearing.z)),
          atan2(bearing.x, bearing.z)))
    }
    let pressure = StationAutoGuidance(
      aim: bearing, lateralVelocity: .init(0, 0, 0), hazard: .active,
      interruptionAllowed: true, clearanceRadius: 400)
    let before = control.velocity
    let steering = control.steer(target: station, delta: delta, limits: limits, defence: pressure)
    #expect(abs(steering.pitch) <= limits.pitchRate && abs(steering.yaw) <= limits.yawRate)
    #expect((control.velocity - before).length <= limits.acceleration * delta + 1e-8)
    #expect(control.velocity.length <= limits.speed + 1e-8)
    #expect(!control.finalApproach && !control.ready)
    let pitch = steering.pitch * delta
    let yaw = steering.yaw * delta
    bearing = bearing.rotated(pitch: pitch, roll: 0, yaw: yaw)
    station.position = station.position.rotated(pitch: pitch, roll: 0, yaw: yaw)
    station.orientation.rotate(pitch: pitch, roll: 0, yaw: yaw)
    control.rotateVelocity(pitch: pitch, roll: 0, yaw: yaw)
  }
  // A proportional chase leaves a persistent lag outside this small firing bearing.
  #expect(peakSettledError < 0.02)
}

@Test func stationAutoReturningReentersDefenceForBeamWithoutIncomingOrdnance() {
  var station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 5000))
  station.rotationRate = 0
  var control = AutoTargetControl()
  let initial = StationAutoGuidance(
    aim: .init(0, 0, 1000), lateralVelocity: .init(0, 0, 0), hazard: .active,
    interruptionAllowed: true, clearanceRadius: 400)
  _ = control.steer(target: station, delta: 0.1, defence: initial)
  let moving = StationAutoGuidance(
    aim: .init(50, 0, 1000), lateralVelocity: .init(0, 0, 0), hazard: .active,
    interruptionAllowed: true, clearanceRadius: 400)
  _ = control.steer(target: station, delta: 0.1, defence: moving)
  let clear = StationAutoGuidance(
    aim: nil, lateralVelocity: .init(0, 0, 0), hazard: .clear,
    interruptionAllowed: true, clearanceRadius: 400)
  _ = control.steer(target: station, delta: 0.1, defence: clear)
  #expect(control.stationDefencePhase == .returning)
  let renewed = StationAutoGuidance(
    aim: .init(-50, 0, 1000), lateralVelocity: .init(0, 0, 0), hazard: .active,
    interruptionAllowed: true, clearanceRadius: 400)
  let before = control.velocity
  let actual = control.steer(target: station, delta: 0.1, defence: renewed)
  var fresh = AutoTargetControl()
  let expected = fresh.steer(target: station, delta: 0.1, defence: renewed)
  #expect(control.stationDefencePhase == .defending && !control.finalApproach && !control.ready)
  #expect((control.velocity - before).length <= 24 + 1e-8)
  #expect(actual.pitch == expected.pitch && actual.yaw == expected.yaw)
}

@Test func stationAutoActiveCoverTransitLeavesTheStagingPointThroughTheClearanceDetour() {
  var station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 1090))
  station.rotationRate = 0
  var control = AutoTargetControl()
  var travelled = Vector3(0, 0, 0)
  let limits = AutoTargetControl.policyLimits
  let delta = 0.1
  for step in 0..<20 {
    // Fixed native-unit geometry: the genuine docking goal starts exactly at the
    // observer, while the requested cover point is beyond the station, not a port.
    let guidance = StationAutoGuidance(
      aim: .init(0, 0, 600), lateralVelocity: .init(50, 0, 0), hazard: .active,
      interruptionAllowed: true, clearanceRadius: 400,
      transitGoal: station.position + Vector3(0, 0, 440))
    let before = control.velocity
    _ = control.steer(target: station, delta: delta, limits: limits, defence: guidance)
    if step == 0 {
      // A direct segment crosses the station. Using the ordinary goal's zero
      // error would bypass the detour and command only inward translation.
      #expect(control.positionError == 0 && control.velocity.x > 0)
    }
    #expect(control.stationDefencePhase == .defending && !control.ready && !control.finalApproach)
    #expect((control.velocity - before).length <= limits.acceleration * delta + 1e-8)
    #expect(control.velocity.length <= limits.speed + 1e-8)
    let movement = control.velocity * delta
    travelled = travelled + movement
    station.position = station.position - movement
    #expect(station.position.length > 400)
  }
  #expect(travelled.length > 100 && control.velocity.length > limits.speed * 0.9)
  // Clearing pressure must recover the original docking route; a stale cover
  // request cannot keep owning translation after this current observation.
  let clear = StationAutoGuidance(
    aim: nil, lateralVelocity: .init(0, 0, 0), hazard: .clear,
    interruptionAllowed: true, clearanceRadius: 400,
    transitGoal: station.position + Vector3(0, 0, 440))
  _ = control.steer(target: station, delta: delta, limits: limits, defence: clear)
  #expect(control.stationDefencePhase == .returning && control.status == "RETURNING TO APPROACH")
}

@Test func stationAutoCoverTransitDoesNotBrakeAtItsIntermediateAvoidanceWaypoint() {
  var station = SpaceBody(id: 0, hull: .station, position: .init(-427, 0, 440))
  station.rotationRate = 0
  let limits = RelativeWorkLimits(
    acceleration: 240, speed: 400, pitchRate: 0.8, yawRate: 0.8, rollRate: 1)
  var control = AutoTargetControl()
  control.setApproachVelocity(.init(200, 0, 320))
  let before = control.velocity
  let incoming = max(0, before.dot(station.position.unit))
  let stopping = incoming * incoming / (2 * limits.acceleration) + incoming * 0.1
  // Exterior transit boundary: stopping distance is available, the final cover
  // point is far away, and an intervening station requires a nearby detour.
  #expect(station.position.length > 400 + stopping)
  let guidance = StationAutoGuidance(
    aim: .init(0, 0, 600), lateralVelocity: .init(50, 0, 0), hazard: .active,
    interruptionAllowed: true, clearanceRadius: 400,
    transitGoal: station.position + Vector3(0, 0, 440))
  _ = control.steer(target: station, delta: 0.1, limits: limits, defence: guidance)
  #expect(control.stationDefencePhase == .defending && !control.ready && !control.finalApproach)
  #expect(control.velocity.length > before.length)
  #expect(control.velocity.length <= limits.speed + 1e-8)
  #expect((control.velocity - before).length <= limits.acceleration * 0.1 + 1e-8)
  #expect((station.position - control.velocity * 0.1).length > 400)
}

@Test func stationAutoWeakFrontShieldFacesCoverWithoutChangingItsTranslationBudget() {
  var station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 1090))
  station.rotationRate = 0
  let pressure = StationAutoGuidance(
    aim: .init(-600, 0, 0), lateralVelocity: .init(50, 0, 0), hazard: .active,
    interruptionAllowed: true, clearanceRadius: 400,
    transitGoal: station.position + Vector3(0, 0, 440))
  var fighting = AutoTargetControl()
  let towardAttacker = fighting.steer(target: station, delta: 0.1, defence: pressure)
  var escape = pressure
  escape.protectFrontShield = true
  var covering = AutoTargetControl()
  let towardCover = covering.steer(target: station, delta: 0.1, defence: escape)
  #expect(towardAttacker.yaw < 0 && towardCover.yaw > 0)
  #expect(covering.velocity == fighting.velocity)
  #expect(covering.velocity.length <= AutoTargetControl.policyLimits.acceleration * 0.1 + 1e-8)
  #expect(covering.stationDefencePhase == .defending && !covering.ready && !covering.finalApproach)
  #expect(abs(towardCover.pitch) <= 0.8 && abs(towardCover.yaw) <= 0.8)
}

@Test(arguments: [true, false])
func stationAutoCurrentShieldBanksChooseCoverOnlyForTheWeakerFront(frontWeaker: Bool) async throws {
  var game = try await stationAutoEntryBoundary()
  let id = try stationAutoAddNativeAttacker(&game, position: .init(300, 0, -1000), sequence: 920)
  game.emitLegacyNPCBeam(bodyID: id, damage: LaserKind.pulse.damage)
  // Controlled initial damage boundary; this does not replenish any real journey.
  if frontWeaker { game.frontShield *= 0.25 } else { game.rearShield *= 0.25 }
  let station = try #require(game.autoTargetBody)
  let commander = game.commander
  let front = game.frontShield
  let rear = game.rearShield
  let bodies = game.bodies
  let observation = game.stationAutoGuidance(target: station)
  let guidance = try #require(observation)
  #expect(guidance.hazard == .active && guidance.transitGoal != nil)
  #expect(guidance.protectFrontShield == frontWeaker)
  #expect(game.commander == commander && game.bodies == bodies)
  #expect(game.frontShield == front && game.rearShield == rear)
  #expect(game.commander.unlimitedMissiles == false && !game.commander.unlimitedCash)
}
