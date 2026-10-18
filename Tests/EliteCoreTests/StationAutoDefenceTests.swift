import Foundation
import Testing

@testable import EliteCore

private func stationAutoGame() throws -> Game {
  // Controlled native unit boundary. Original mission routes and traffic are not edited.
  var game = Game(executive: false)
  game.screen = .status
  game.commander.system = 0
  game.selectedSystem = 0
  game.market = MarketItem.at(game.currentSystem, fluctuation: 0)
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
  let before = game
  let attacker = try #require(game.bodies.first { $0.hostile })
  game.fireStationAutoLaser()
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
      game.bodies[index].physical?.npc?.intention = .flee(player)
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
      #expect(guidance?.hazard == .clear)
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
