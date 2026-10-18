import Foundation
import Testing

@testable import EliteCore

private func rangePolicyGame() throws -> Game {
  // Controlled unit boundary with the same paid preparation; travel is exercised by the journey.
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
  let index = try #require(game.bodies.firstIndex { $0.id == id })
  game.bodies[index].missiles = 0
  game.bodies[index].physical?.catalogueShipID = ShipCatalogue.nativeShip(.cobra)?.id
  game.bodies[index].physical?.npc?.legal = .init(value: 16)
  game.bodies[index].physical?.spawnIdentity = .init(
    system: game.systemIdentity, visit: game.commander.flightSimulation.visit,
    sequence: 900, member: 0, producer: .ambient)
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
    game.bodies[index].physical?.spawnIdentity = .init(
      system: game.systemIdentity, visit: game.commander.flightSimulation.visit + 1,
      sequence: 900, member: 0)
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
    context.protection.protectedActors.insert(actor)
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
    facts.threats[0].position.z = 6000
    facts.threat = facts.threats[0]
    facts.incoming = true
  case "nearer-known":
    facts.threats[0].position.z = 6000
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
  try #require(current.valid && !current.pulseHeatBlocked)
  budget.updateRetreat(current)
  #expect(budget.retreat == phase && budget.steps == 1 && budget.tabs == 0 && budget.tools == 0)
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
