import Foundation
import Testing

@testable import L337Core

private func rangePolicyGame() throws -> Game {
  // Controlled unit boundary with the same paid preparation; travel is exercised by the journey.
  var game = try ScriptProcurementFixture.freshG03FlightGame()
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
  // Isolate this controlled unit's attacker without changing the actual journey's traffic.
  let stationActor = try #require(game.commander.flightSimulation.anchors?.station.identity)
  for retained in game.bodies.indices where game.bodies[retained].id != id {
    if game.bodies[retained].physical?.npc != nil {
      game.bodies[retained].hostile = false
      game.bodies[retained].physical?.npc?.intention = .dock(stationActor)
    }
  }
  let index = try #require(game.bodies.firstIndex { $0.id == id })
  game.bodies[index].missiles = 0
  game.bodies[index].physical?.catalogueShipID = ShipCatalogue.nativeShip(.cobra)?.id
  game.bodies[index].physical?.npc?.legal = .init(value: 16)
  game.bodies[index].physical?.npc?.routeProvenance = .generated
  let spawn = SpawnIdentity(
    system: game.systemIdentity, visit: game.commander.flightSimulation.visit,
    sequence: 900, member: 0, producer: .ambient)
  game.bodies[index].physical?.spawnIdentity = spawn
  game.selectFlightTool(.combatLaser)
  return game
}

@Test(arguments: [
  "ordinary", "missiles", "script-source", "foreign-spawn", "missing-spawn", "naval", "mission",
  "blackjack", "catalogue", "missing-resources", "population", "special", "velocity", "unjoined",
  "protected", "duplicate",
])
func procurementFarExemptionRequiresJoinedOrdinaryPulseOnlyActor(condition: String) throws {
  var game = try rangePolicyGame()
  let index = game.bodies.count - 1
  switch condition {
  case "missiles": game.bodies[index].missiles = 1
  case "script-source": game.bodies[index].physical?.spawnIdentity?.producer = .mission
  case "foreign-spawn":
    let foreignSpawn = SpawnIdentity(
      system: game.systemIdentity, visit: game.commander.flightSimulation.visit + 1,
      sequence: 900, member: 0)
    game.bodies[index].physical?.spawnIdentity = foreignSpawn
  case "missing-spawn": game.bodies[index].physical?.spawnIdentity = nil
  case "naval": game.bodies[index].navalTarget = true
  case "mission": game.bodies[index].missionInstanceID = UUID()
  case "blackjack": game.bodies[index].blackjackIdentity = UUID()
  case "catalogue": game.bodies[index].physical?.catalogueShipID = "SH026"
  case "missing-resources": game.bodies[index].physical?.npc?.resources = nil
  case "population": game.bodies[index].physical?.population = .mission
  case "special": game.bodies[index].hull = .thargoid
  case "velocity": game.bodies[index].physical?.velocity.x = .nan
  case "unjoined": game.bodies[index].physical = nil
  default: break
  }
  var context = try #require(game.gameplayContext())
  if condition == "protected", let actor = game.bodies[index].physical?.identity {
    var protection = context.protection
    protection.protectedActors.insert(actor)
    context = EncounterContext(
      system: context.system, seed: context.seed, government: context.government,
      visit: context.visit, revision: context.revision, physicalTime: context.physicalTime,
      anchors: context.anchors, player: context.player, actors: context.actors,
      protection: protection, budget: context.budget, perceptionRadius: context.perceptionRadius,
      depletedRocks: context.depletedRocks, miningPresence: context.miningPresence)
  }
  if condition == "duplicate", let actor = game.bodies[index].physical?.identity,
    let snapshot = context.actors.first(where: { $0.identity == actor })
  {
    context = EncounterContext(
      system: context.system, seed: context.seed, government: context.government,
      visit: context.visit, revision: context.revision, physicalTime: context.physicalTime,
      anchors: context.anchors, player: context.player, actors: context.actors + [snapshot],
      protection: context.protection, budget: context.budget,
      perceptionRadius: context.perceptionRadius)
  }
  let classified = ScriptProcurementRangePolicy.pulseOnly(game.bodies[index], context: context)
  #expect(classified == (condition == "ordinary"))
}

private func rangePolicyFacts(range: Double, margin: Double = 0) -> ScriptProcurementPreflightFacts
{
  let player = ActorIdentity(system: .init(galaxy: 0, system: 0), visit: 1, entity: 1)
  var facts = ScriptProcurementPreflightFacts()
  facts.identity = .init(
    player: player, epoch: UUID(), stationEpoch: UUID(), owner: UUID(), revision: 1,
    physicalTime: 1)
  facts.valid = true
  facts.live = true
  facts.mainTargetCurrent = true
  facts.combatLaser = true
  facts.frontLaser = true
  facts.threat = .init(
    identity: .init(system: player.system, visit: 1, entity: 2),
    position: .init(0, 0, range), wanted: true, pulseOnly: true, closingMargin: margin)
  facts.threats = [facts.threat!]
  return facts
}

@Test(arguments: [-0.1, 0.0, 0.1])
func procurementRangeEntryAndExitUseSameClosingMarginBoundary(offset: Double) {
  for margin in [0.0, 36.0] {
    let facts = rangePolicyFacts(range: 1500 + margin + offset, margin: margin)
    #expect(
      facts.requestedDockAction(defensive: true, steps: 0) == (offset > 0 ? .automatic : .react))
    #expect(facts.requestedAction(steps: 0) == (offset > 0 ? .clear : .track))
    #expect(facts.requestedDockAction(defensive: false, steps: 0) == .automatic)
  }
}

@Test(arguments: ["unknown", "incoming", "nearer-known", "gone", "cool", "nearest-changed"])
func procurementRangeAssessmentAndPersistentRetreatUseAllCurrentThreats(condition: String) {
  var facts = rangePolicyFacts(range: 1000)
  facts.pulseHeatBlocked = true
  var budget = ScriptProcurementPilotBudget()
  budget.updateRetreat(facts)
  let phase = budget.retreat
  #expect(phase?.target == facts.threat?.identity)
  facts.pulseHeatBlocked = false
  switch condition {
  case "unknown":
    var unknown = facts.threat!
    unknown = .init(
      identity: .init(system: unknown.identity.system, visit: 1, entity: 3),
      position: .init(0, 0, 6000), wanted: true)
    facts.threats.append(unknown)
  case "incoming":
    let original = facts.threats[0]
    facts.threats[0] = .init(
      identity: original.identity, position: .init(original.position.x, original.position.y, 6000),
      wanted: original.wanted, pulseOnly: original.pulseOnly, closingMargin: original.closingMargin)
    facts.threat = facts.threats[0]
    facts.incoming = true
  case "nearer-known":
    let original = facts.threats[0]
    facts.threats[0] = .init(
      identity: original.identity, position: .init(original.position.x, original.position.y, 6000),
      wanted: original.wanted, pulseOnly: original.pulseOnly, closingMargin: original.closingMargin)
    facts.threat = facts.threats[0]
    var unknown = facts.threat!
    unknown = .init(
      identity: .init(system: unknown.identity.system, visit: 1, entity: 3),
      position: .init(0, 0, 7000), wanted: true)
    facts.threats.append(unknown)
  case "gone":
    facts.threats = []
    facts.threat = nil
  case "nearest-changed":
    let other = ScriptProcurementPreflightThreat(
      identity: .init(system: facts.threat!.identity.system, visit: 1, entity: 3),
      position: .init(0, 0, 900), wanted: true, pulseOnly: true)
    facts.threats.append(other)
    facts.threat = other
  default: break
  }
  budget.updateRetreat(facts)
  if ["cool", "nearest-changed", "incoming"].contains(condition) {
    #expect(budget.retreat == phase)
  } else {
    #expect(budget.retreat == nil)
  }
  #expect(facts.needsDefence == (condition != "gone"))
  #expect(budget.steps == 0 && budget.tabs == 0 && budget.tools == 0)
}

@Test(arguments: [-0.1, 0.0, 0.1])
func procurementHalfActualShieldCapacityStartsEarlyBreakoff(offset: Double) async throws {
  var game = try rangePolicyGame()
  game.laserHeat = 0
  game.frontShield = game.commander.shieldCapacity * 0.5 + offset
  let runtime = GameRuntime(game: game)
  let facts = await runtime.procurementPreflightFacts()
  try #require(facts.valid && !facts.pulseHeatBlocked && facts.threat?.pulseOnly == true)
  try requireLatchPremises(facts)
  var budget = ScriptProcurementPilotBudget()
  budget.updateRetreat(facts)
  #expect((budget.retreat != nil) == (offset <= 0))
}

@Test(arguments: [-0.001, 0.0, 0.001])
func procurementHeatBreakoffUsesActualNextFrameCooling(offset: Double) async throws {
  var game = try rangePolicyGame()
  game.laserHeat = 241.2 + offset
  let runtime = GameRuntime(game: game)
  let facts = await runtime.procurementPreflightFacts()
  try #require(facts.valid && facts.threat?.pulseOnly == true)
  #expect(facts.pulseHeatBlocked == (offset >= 0))
}

@Test func procurementRetreatUsesOrdinaryAdvanceAndRejectsStaleRejoinWithoutSpendingStock()
  async throws
{
  var game = try rangePolicyGame()
  game.laserHeat = 241.3
  let runtime = GameRuntime(game: game)
  let before = await runtime.snapshot()
  let facts = await runtime.procurementPreflightFacts()
  try #require(facts.valid && facts.threat?.pulseOnly == true && facts.pulseHeatBlocked)
  try requireLatchPremises(facts)
  var budget = ScriptProcurementPilotBudget()
  budget.updateRetreat(facts)
  let phase = try #require(budget.retreat)
  let result = await runtime.procurementPilotStep(
    expected: facts, steps: budget.steps, automatic: false, diagnostic: false, retreat: phase)
  try #require(result.status == .defensive)
  let recorded = budget.recordAdvance(automatic: false)
  try #require(recorded)
  let after = await runtime.snapshot()
  let cleared = await runtime.controls
  #expect(
    after.commander.flightSimulation.physicalTime > before.commander.flightSimulation.physicalTime)
  #expect(
    after.commander.flightSimulation.pose.orientation
      != before.commander.flightSimulation.pose.orientation)
  #expect(after.speed > before.speed)
  #expect(
    abs(
      after.commander.flightSimulation.physicalTime
        - before.commander.flightSimulation.physicalTime - 0.1) < 1e-8)
  #expect(after.commander.missiles == before.commander.missiles)
  #expect(
    after.commander.credits == before.commander.credits
      && after.commander.cargo == before.commander.cargo)
  #expect(after.commander.equipmentInventory == before.commander.equipmentInventory)
  #expect(after.commander.legal == 0 && budget.missileDefence.attempted.isEmpty)
  #expect(cleared.pitch == 0 && cleared.yaw == 0 && cleared.throttle == 0 && !cleared.fire)
  let current = await runtime.procurementPreflightFacts()
  try #require(current.valid && current.live && !current.paused && !current.docked)
  try #require(!current.automaticEngaged && !current.pulseHeatBlocked)
  let player = try #require(after.commander.flightSimulation.player)
  let targets = after.bodies.filter { $0.physical?.identity == phase.target }
  try #require(targets.count <= 1)
  if let target = targets.first {
    try #require(target.energy.isFinite)
    let npc = try #require(target.physical?.npc)
    #expect(target.energy <= 0 || npc.intention != .engage(player))
  }
  // Native disappearance or disengagement is observed, never forced by this test pilot.
  #expect(!current.needsDefence)
  budget.updateRetreat(current)
  #expect(budget.retreat == nil)
  #expect(budget.steps == 1)
  #expect(budget.tabs == 0 && budget.tools == 0)
  let stale = await runtime.procurementPilotStep(
    expected: facts, steps: budget.steps, automatic: false, diagnostic: false, retreat: phase)
  let unchanged = await runtime.snapshot()
  #expect(stale.status == .refused && unchanged.commander == after.commander)
  #expect(unchanged.bodies == after.bodies && unchanged.gameplayRevision == after.gameplayRevision)
}

@Test func procurementHostileNavalMissilesWithNonEngageIntentCannotDisappearFromAssessment()
  async throws
{
  var game = try rangePolicyGame()
  let index = game.bodies.count - 1
  game.bodies[index].hull = .constrictor
  game.bodies[index].navalTarget = true
  game.bodies[index].missiles = 1
  game.bodies[index].position = .init(0, 0, 6000)
  game.bodies[index].physical?.catalogueShipID = ShipCatalogue.nativeShip(.constrictor)?.id
  game.bodies[index].physical?.npc?.intention = .navigate(
    position: .init(10000, 0, 0), speedUnitsPerSecond: 100)
  let runtime = GameRuntime(game: game)
  let before = await runtime.snapshot()
  let facts = await runtime.procurementPreflightFacts()
  #expect(!facts.valid)
  #expect(facts.requestedDockAction(defensive: true, steps: 0) == .refuse)
  let result = await runtime.procurementPilotStep(
    expected: facts, steps: 0, automatic: true, diagnostic: false)
  let after = await runtime.snapshot()
  #expect(result.status == .refused)
  #expect(after.commander == before.commander && after.bodies == before.bodies)
  #expect(after.gameplayRevision == before.gameplayRevision)
}

private func requireLatchPremises(_ facts: ScriptProcurementPreflightFacts) throws {
  try #require(facts.valid && facts.live && !facts.docked && !facts.paused)
  try #require(!facts.automaticEngaged && facts.needsDefence)
  try #require(!facts.threats.isEmpty && facts.threats.allSatisfy(\.pulseOnly))
  try #require(facts.threat?.immediate == true)
}

@Test(arguments: [
  "rear-high", "rear-half", "heat", "front-low", "identity", "far", "gone", "unknown",
])
func procurementReengagementPhaseUsesRearBoundaryHeatAndCurrentIdentity(condition: String) {
  var facts = rangePolicyFacts(range: 1000)
  facts.pulseHeatBlocked = true
  var budget = ScriptProcurementPilotBudget()
  budget.updateRetreat(facts)
  let phase = budget.retreat!
  facts.pulseHeatBlocked = false
  facts.rearShieldLow = condition != "rear-high"
  if condition == "heat" { facts.pulseHeatBlocked = true }
  budget.updateRetreat(facts)
  if ["rear-high", "heat"].contains(condition) {
    #expect(budget.retreat?.mode == .breakAway)
    return
  }
  #expect(budget.retreat?.mode == .reengage && budget.retreat?.target == phase.target)
  switch condition {
  case "front-low": facts.frontShieldLow = true
  case "identity":
    let other = ScriptProcurementPreflightThreat(
      identity: .init(system: phase.target.system, visit: phase.target.visit, entity: 3),
      position: .init(0, 0, 900), wanted: true, pulseOnly: true)
    facts.threats.append(other)
    facts.threat = other
  case "far":
    let old = facts.threat!
    facts.threat = .init(
      identity: old.identity, position: .init(0, 0, 6000), wanted: true, pulseOnly: true)
    facts.threats = [facts.threat!]
  case "gone":
    facts.threat = nil
    facts.threats = []
  case "unknown":
    let old = facts.threat!
    facts.threat = .init(identity: old.identity, position: old.position, wanted: old.wanted)
    facts.threats = [facts.threat!]
  default: break
  }
  budget.updateRetreat(facts)
  if ["far", "gone", "unknown"].contains(condition) {
    #expect(budget.retreat == nil)
  } else {
    #expect(budget.retreat?.mode == .reengage)
    #expect(budget.retreat?.target == facts.threat?.identity)
    #expect(budget.retreat?.permitsCombat(facts) == true)
    facts.pulseHeatBlocked = true
    budget.updateRetreat(facts)
    #expect(budget.retreat?.mode == .breakAway && budget.retreat?.turnSign == phase.turnSign)
  }
  #expect(budget.steps == 0 && budget.tabs == 0 && budget.tools == 0)
}

@Test(arguments: [-0.1, 0.0, 0.1])
func procurementRearHalfCapacityAdmitsReengagementWithoutFrontShieldOscillation(offset: Double)
  async throws
{
  var game = try rangePolicyGame()
  game.laserHeat = 0
  game.frontShield = game.commander.shieldCapacity * 0.25
  game.rearShield = game.commander.rearShieldCapacity * 0.5 + offset
  let runtime = GameRuntime(game: game)
  let facts = await runtime.procurementPreflightFacts()
  try requireLatchPremises(facts)
  try #require(facts.frontShieldLow && !facts.pulseHeatBlocked)
  var budget = ScriptProcurementPilotBudget()
  budget.updateRetreat(facts)
  try #require(budget.retreat?.mode == .breakAway)
  budget.updateRetreat(facts)
  #expect(budget.retreat?.mode == (offset <= 0 ? .reengage : .breakAway))
}

@Test func procurementNativeReengagementUsesNormalFacingThrustAndCheckedPlayerFire() async throws {
  var game = try rangePolicyGame()
  game.laserHeat = 0
  game.frontShield = game.commander.shieldCapacity * 0.25
  game.rearShield = game.commander.rearShieldCapacity * 0.5
  let runtime = GameRuntime(game: game)
  let before = await runtime.snapshot()
  let facts = await runtime.procurementPreflightFacts()
  try requireLatchPremises(facts)
  try #require(facts.requestedAction(steps: 0) == .requestFire)
  var budget = ScriptProcurementPilotBudget()
  budget.updateRetreat(facts)
  budget.updateRetreat(facts)
  let phase = try #require(budget.retreat)
  try #require(phase.mode == .reengage && phase.permitsCombat(facts))
  let result = await runtime.procurementPilotStep(
    expected: facts, steps: 0, automatic: false, diagnostic: false, retreat: phase)
  try #require(result.status == .defensive)
  let after = await runtime.snapshot()
  let cleared = await runtime.controls
  #expect(after.speed > before.speed && after.laserHeat > before.laserHeat)
  #expect(
    after.commander.flightSimulation.pose.position
      != before.commander.flightSimulation.pose.position)
  #expect(
    abs(
      after.commander.flightSimulation.physicalTime
        - before.commander.flightSimulation.physicalTime - 0.1) < 1e-8)
  #expect(after.commander.missiles == before.commander.missiles)
  #expect(after.commander.equipmentInventory == before.commander.equipmentInventory)
  #expect(after.commander.equipmentPurchaseHistory == before.commander.equipmentPurchaseHistory)
  #expect(
    after.commander.credits == before.commander.credits
      && after.commander.cargo == before.commander.cargo)
  #expect(after.commander.legal == 0 && budget.missileDefence.attempted.isEmpty)
  #expect(cleared.pitch == 0 && cleared.yaw == 0 && cleared.throttle == 0 && !cleared.fire)
}

@Test(arguments: ["current", "heat", "unknown", "stale", "far"])
func procurementReengagementRetargetsOnlyFreshImmediateKnownSelection(condition: String) {
  var facts = rangePolicyFacts(range: 1000)
  let original = facts.threat!.identity
  var budget = ScriptProcurementPilotBudget()
  budget.retreat = .init(target: original, turnSign: -1, mode: .reengage)
  let selected = ScriptProcurementPreflightThreat(
    identity: .init(system: original.system, visit: original.visit, entity: 3),
    position: .init(0, 0, condition == "far" ? 6000 : 900), wanted: true,
    pulseOnly: condition != "unknown")
  facts.threats.append(selected)
  facts.threat = selected
  facts.frontShieldLow = true
  facts.pulseHeatBlocked = condition == "heat"
  if condition == "stale" { facts.valid = false }
  let fallbackOpportunity = budget.updateRetreat(facts)
  if condition == "current" || condition == "heat" {
    #expect(budget.retreat?.target == selected.identity && budget.retreat?.turnSign == -1)
    #expect(budget.retreat?.mode == (condition == "heat" ? .breakAway : .reengage))
    #expect(fallbackOpportunity)
  } else {
    #expect(budget.retreat?.target != selected.identity && !fallbackOpportunity)
  }
  #expect(budget.steps == 0 && budget.tabs == 0 && budget.tools == 0)
  #expect(budget.missileDefence.attempted.isEmpty)
}

@Test func procurementTwoActorReengagementRejoinsNewSelectedRayBeforeOrdinaryFire() async throws {
  var game = try rangePolicyGame()
  let oldIndex = game.bodies.count - 1
  let original = try #require(game.bodies[oldIndex].physical?.identity)
  game.bodies[oldIndex].position = .init(300, 0, 1000)
  let id = game.nextBodyID
  game.nextBodyID += 1
  game.bodies.append(.init(id: id, hull: .cobra, position: .init(0, 0, 500), hostile: true))
  game.ensurePhysicalActors()
  let index = try #require(game.bodies.firstIndex { $0.id == id })
  let selected = try #require(game.bodies[index].physical?.identity)
  let spawn = SpawnIdentity(
    system: game.systemIdentity, visit: game.commander.flightSimulation.visit,
    sequence: 901, member: 0, producer: .ambient)
  game.bodies[index].missiles = 0
  game.bodies[index].physical?.spawnIdentity = spawn
  game.bodies[index].physical?.catalogueShipID = ShipCatalogue.nativeShip(.cobra)?.id
  game.bodies[index].physical?.npc?.legal = .init(value: 16)
  game.bodies[index].physical?.npc?.routeProvenance = .generated
  game.frontShield = game.commander.shieldCapacity * 0.25
  game.rearShield = game.commander.rearShieldCapacity * 0.5
  game.laserHeat = 0
  let runtime = GameRuntime(game: game)
  let before = await runtime.snapshot()
  let facts = await runtime.procurementPreflightFacts()
  try requireLatchPremises(facts)
  try #require(facts.threats.count == 2 && facts.threat?.identity == selected)
  try #require(facts.requestedAction(steps: 0) == .requestFire)
  var budget = ScriptProcurementPilotBudget()
  budget.retreat = .init(target: original, turnSign: -1, mode: .reengage)
  let fallbackOpportunity = budget.updateRetreat(facts)
  let phase = try #require(budget.retreat)
  try #require(fallbackOpportunity && phase.target == selected && phase.permitsCombat(facts))
  // Heat is cold: the unchanged native fallback must preserve all three original rounds.
  budget = try await runtime.procurementMissileFallback(expected: facts, budget: budget)
  let fresh = await runtime.procurementPreflightFacts()
  let result = await runtime.procurementPilotStep(
    expected: fresh, steps: 0, automatic: false, diagnostic: false, retreat: phase)
  try #require(result.status == .defensive)
  let after = await runtime.snapshot()
  let newBefore = try #require(before.bodies.first { $0.physical?.identity == selected })
  let newAfter = try #require(after.bodies.first { $0.physical?.identity == selected })
  let oldBefore = try #require(before.bodies.first { $0.physical?.identity == original })
  let oldAfter = try #require(after.bodies.first { $0.physical?.identity == original })
  #expect(newAfter.energy < newBefore.energy && oldAfter.energy == oldBefore.energy)
  #expect(after.laserHeat > before.laserHeat && after.speed > before.speed)
  #expect(
    after.commander.flightSimulation.pose.position
      != before.commander.flightSimulation.pose.position)
  #expect(after.commander.missiles == before.commander.missiles)
  #expect(after.commander.equipmentInventory == before.commander.equipmentInventory)
  #expect(
    after.commander.credits == before.commander.credits
      && after.commander.cargo == before.commander.cargo)
  #expect(after.commander.legal == 0 && budget.missileDefence.attempted.isEmpty)
  #expect(
    abs(
      after.commander.flightSimulation.physicalTime
        - before.commander.flightSimulation.physicalTime - 0.1) < 1e-8)
  let cleared = await runtime.controls
  #expect(cleared.pitch == 0 && cleared.yaw == 0 && cleared.throttle == 0 && !cleared.fire)
}

private func procurementNearStationDefenceGame(authenticate: Bool) throws -> Game {
  var game = try rangePolicyGame()
  let station = try #require(game.commander.flightSimulation.anchors?.station)
  let index = try #require(game.bodies.firstIndex { $0.hostile })
  // Controlled unit geometry: station behind the player, selected native attacker ahead.
  NativePagedSalvageFixture.moveObserver(
    &game, to: .init(position: station.position + .init(0, 0, 800)))
  game.bodies[index].position = .init(0, 0, 600)
  if authenticate {
    let shield = game.frontShield
    game.emitLegacyNPCBeam(bodyID: game.bodies[index].id, damage: LaserKind.pulse.damage)
    try #require(game.frontShield < shield)
    let context = try #require(game.gameplayContext())
    let actor = try #require(game.bodies[index].physical?.identity)
    try #require(
      game.commander.crimeLedger.hasCurrentUnlawfulAttack(
        from: actor, against: context.player.identity, context: context))
  }
  return game
}

@Test func procurementNearStationSelfDefenceUsesRealCurrentLawAndNativeHit() async throws {
  let game = try procurementNearStationDefenceGame(authenticate: true)
  let runtime = GameRuntime(game: game)
  // Existing bounded accepted-combat observation is used only to assert the native hit.
  await runtime.enableStationDefenceDiagnostics()
  let before = await runtime.snapshot()
  let facts = await runtime.procurementPreflightFacts()
  let target = try #require(facts.threat?.identity)
  let player = try #require(before.commander.flightSimulation.player)
  try #require(facts.valid && facts.live && !facts.outsideNoFireZones)
  try #require(facts.lawfulForwardDefence && facts.exactForwardHit)
  try #require(facts.requestedAction(steps: 0) == .requestFire)
  let result = await runtime.procurementPilotStep(
    expected: facts, steps: 0, automatic: false, diagnostic: false)
  try #require(result.status == .defensive)
  let after = await runtime.snapshot()
  #expect(
    after.gameplayCombatTrace?.incidents.contains {
      $0.origin.owner == player && $0.victim == target && $0.kind == .laser && $0.outcome == .hit
    } == true)
  #expect(after.laserHeat > before.laserHeat && after.commander.legal == 0)
  #expect(after.commander.credits == before.commander.credits)
  #expect(after.commander.cargo == before.commander.cargo)
  #expect(after.commander.missiles == before.commander.missiles)
  #expect(after.commander.equipmentInventory == before.commander.equipmentInventory)
  #expect(after.commander.equipmentPurchaseHistory == before.commander.equipmentPurchaseHistory)
}

@Test(arguments: ["unauthenticated", "expired", "obstructed"])
func procurementNearStationFireRequiresCurrentDefenceAndExactRay(condition: String) async throws {
  var game = try procurementNearStationDefenceGame(authenticate: condition != "unauthenticated")
  let index = try #require(game.bodies.firstIndex { $0.hostile })
  let actor = try #require(game.bodies[index].physical?.identity)
  if condition == "expired" {
    let player = try #require(game.commander.flightSimulation.player)
    game.bodies[index].hostile = false
    game.bodies[index].physical?.npc?.intention = .flee(player)
    game.commander.flightSimulation.advancePhysicalTime(11)
    let context = try #require(game.gameplayContext())
    try #require(
      !game.commander.crimeLedger.hasCurrentUnlawfulAttack(
        from: actor, against: player, context: context))
  } else if condition == "obstructed" {
    let blocker = game.nextBodyID
    game.nextBodyID += 1
    game.bodies.append(.init(id: blocker, hull: .asteroid, position: .init(0, 0, 300)))
    game.ensurePhysicalActors()
  }
  let runtime = GameRuntime(game: game)
  let facts = await runtime.procurementPreflightFacts()
  try #require(facts.valid && facts.live && !facts.outsideNoFireZones)
  #expect(!facts.lawfulForwardDefence && facts.requestedAction(steps: 0) != .requestFire)
  if condition == "unauthenticated" {
    #expect(facts.exactForwardHit && facts.threat?.identity == actor)
  } else if condition == "obstructed" {
    #expect(!facts.exactForwardHit && facts.threat?.identity == actor)
  } else {
    #expect(facts.threat == nil)
  }
}

@Test(arguments: ["forged-law", "stale-time"])
func procurementNearStationAtUseRejectsForgedOrStaleDefenceFacts(condition: String) async throws {
  let game = try procurementNearStationDefenceGame(authenticate: condition == "stale-time")
  let runtime = GameRuntime(game: game)
  var expected = await runtime.procurementPreflightFacts()
  try #require(expected.valid && !expected.outsideNoFireZones && expected.exactForwardHit)
  if condition == "forged-law" {
    try #require(!expected.lawfulForwardDefence)
    expected.lawfulForwardDefence = true
  } else {
    try #require(expected.lawfulForwardDefence)
    _ = await runtime.advance(delta: 0.1)
  }
  let before = await runtime.snapshot()
  let controls = await runtime.controls
  let result = await runtime.procurementPilotStep(
    expected: expected, steps: 0, automatic: false, diagnostic: false)
  let after = await runtime.snapshot()
  let retainedControls = await runtime.controls
  #expect(result.status == .refused)
  #expect(after.commander == before.commander && after.bodies == before.bodies)
  #expect(after.laserHeat == before.laserHeat && after.fireCooldown == before.fireCooldown)
  #expect(
    retainedControls.fire == controls.fire && retainedControls.throttle == controls.throttle
      && retainedControls.pitch == controls.pitch && retainedControls.yaw == controls.yaw)
}
