import Foundation
import Testing

@testable import EliteCore

private func electricalGame() throws -> Game {
  var game = try empFixture()
  game.bodies[0].physical?.velocity = .init(0, 0, 0)
  game.bodies[0].physical?.angularVelocity = .init(0, 0, 0)
  game.bodies[0].rotationRate = 0
  return game
}

/// Isolate the release boundary on its actual authoritative simulation clock.
/// Full actor/native acceptance below uses real ticks rather than this unit helper.
private func releaseElectricalPulse(_ game: inout Game) throws {
  let began = game.fireEMPPirateBlaster()
  try #require(began)
  game.commander.flightSimulation.advancePhysicalTime(10)
  game.advanceEMPCharge(triggerHeld: true)
}

struct EMPElectricalRuntimeTests {
  @Test func chargingUsesRealSimulationSecondsAndRepeatedTriggerDoesNotRestartIt() throws {
    var game = try electricalGame()
    let target = game.bodies[0].physical?.identity
    let hull = game.bodies[0].energy
    let start = game.commander.flightSimulation.physicalTime
    let began = game.fireEMPPirateBlaster()
    try #require(began)
    let charge = game.commander.savedEMPCharge
    let repeatRequest = game.fireEMPPirateBlaster()
    #expect(!repeatRequest && game.commander.savedEMPCharge == charge)
    for _ in 0..<99 { game.tick(delta: 0.1) }
    #expect(game.commander.savedEMPCharge?.phase == .charging)
    #expect(game.commander.savedEMPState == nil)
    #expect(
      game.bodies.first { $0.physical?.identity == target }?.physical?.npc?.resources?.electrical
        == nil)
    game.tick(delta: 0.1)
    #expect(abs(game.commander.flightSimulation.physicalTime - start - 10) < 1e-8)
    #expect(game.commander.savedEMPCharge?.phase == .released)
    let actual = try #require(game.bodies.first { $0.physical?.identity == target })
    #expect(actual.energy >= hull && actual.physical?.empSource == nil)
    #expect(actual.physical?.npc?.resources?.electrical != nil)
    #expect(game.dischargeAudio.events.last?.tool == .empPirateBlaster)
  }

  @Test func realAttributedECMPreventsReleaseAfterItsTransientFieldExpires() throws {
    var game = try electricalGame()
    let began = game.fireEMPPirateBlaster()
    try #require(began)
    try game.commander.grantEquipment(
      "E.C.M. System", at: .utility(.ecm),
      provenance: .grant("EMP ECM boundary"))
    let emitter = try #require(game.commander.flightSimulation.player)
    game.ecm()
    try #require(game.ecmFrames > 0)
    let cancellation = try #require(game.commander.savedEMPCharge?.cancellingECM)
    #expect(cancellation.emitter == emitter && game.commander.savedEMPCharge?.phase == .cancelled)
    let eventCount = game.ecmControl.events.count
    var controls = Controls()
    controls.fire = true
    for _ in 0..<101 { game.tick(delta: 0.1, controls: controls) }
    #expect(game.ecmFrames == 0 && game.commander.savedEMPCharge?.phase == .cancelled)
    #expect(game.commander.savedEMPCharge?.cancellingECM == cancellation)
    #expect(game.commander.savedEMPState == nil && game.dischargeAudio.events.isEmpty)
    #expect(game.ecmControl.events.count == eventCount)
  }

  @Test func releaseRevalidatesCurrentWeaponAndRealNearestOccludingMeshWithoutCost() throws {
    var game = try electricalGame()
    let began = game.fireEMPPirateBlaster()
    try #require(began)
    game.bodies.append(.init(id: 99, hull: .asteroid, position: .init(0, 0, 300)))
    game.ensurePhysicalActors()
    let energy = game.energy
    let heat = game.laserHeat
    let nextEmission = game.commander.flightSimulation.nextEmission
    game.commander.flightSimulation.advancePhysicalTime(10)
    game.advanceEMPCharge(triggerHeld: true)
    #expect(game.commander.savedEMPCharge?.phase == .released)
    #expect(game.commander.savedEMPState == nil && game.commander.savedPlayerElectrical == nil)
    #expect(game.energy == energy && game.laserHeat == heat)
    #expect(game.commander.flightSimulation.nextEmission == nextEmission)
    #expect(game.dischargeAudio.events.isEmpty)
  }

  @Test func primaryUsesOnlyTheStruckShieldThenElectricalReserveAndNeverHullEnergy() throws {
    var game = try electricalGame()
    var resources = try #require(game.bodies[0].physical?.npc?.resources)
    resources.frontShield = 90
    resources.rearShield = 7
    game.bodies[0].physical?.npc?.resources = resources
    let original = game.bodies[0]
    try releaseElectricalPulse(&game)
    let target = try #require(game.bodies.first { $0.id == original.id })
    let actual = try #require(target.physical?.npc?.resources)
    #expect(actual.frontShield == 90 && actual.rearShield == 0)
    #expect(actual.electrical?.remaining == resources.energyCapacity - 25)
    #expect(target.energy == original.energy && target.physical?.empSource == nil)
    #expect(game.commander.savedEMPState == nil)
    #expect(
      game.commander.savedPlayerElectrical?.remaining == game.commander.performance.energy - 8)
    #expect(game.laserHeat == 18 && game.fireCooldown == 1.5)
  }

  @Test func onlyRealZeroDisablesAndDeadlineReturnsCurrentHullAndRemainingOriginalPeople() throws {
    var game = try electricalGame()
    var resources = try #require(game.bodies[0].physical?.npc?.resources)
    resources.frontShield = 0
    resources.rearShield = 0
    var electrical = try #require(
      ElectricalReserve(
        capacity: resources.energyCapacity,
        recharge: resources.energyRecharge, at: game.commander.flightSimulation.physicalTime))
    let lowered = electrical.drain(resources.energyCapacity - 5, at: electrical.physicalTime)
    try #require(lowered)
    resources.electrical = electrical
    game.bodies[0].physical?.npc?.resources = resources
    let original = game.bodies[0]
    try releaseElectricalPulse(&game)
    let source = try #require(game.bodies[0].physical?.empSource)
    let disabled = try #require(game.commander.savedEMPState?.records[source])
    #expect(disabled.crewAboard == disabled.crewTotal && !disabled.isRecovered)
    #expect(
      game.isEMPDisabled(game.bodies[0])
        && game.targetColourCue(for: game.bodies[0]) == .recoverable)
    // No ejection tick occurs in this boundary test; recovery must use the exact
    // current damaged craft, not its original stock capacity or condition.
    game.bodies[0].energy = original.energy - 3
    let updated = game.persistEMPState()
    try #require(updated)
    game.commander.flightSimulation.advancePhysicalTime(30)
    game.advanceEMPActors()
    #expect(game.isEMPDisabled(game.bodies[0]))
    game.commander.flightSimulation.advancePhysicalTime(0.1)
    game.advanceEMPActors()
    let recovered = try #require(game.commander.savedEMPState?.records[source])
    let body = try #require(
      game.bodies.first { $0.physical?.identity == original.physical?.identity })
    #expect(
      recovered.isRecovered && !recovered.terminal && recovered.crewAboard == disabled.crewTotal)
    #expect(body.energy == original.energy - 3 && body.physical?.empSource == nil)
    #expect(body.physical?.salvage == nil && !game.isEMPDisabled(body))
    #expect(game.commander.npcPersistence.binding(for: source) == body.physical?.identity)
    #expect(game.commander.npcPersistence.terminalReason(for: source) == nil)
    #expect(body.physical?.npc?.ordinaryCargo == original.physical?.npc?.ordinaryCargo)
    #expect(game.commander.valid)
  }

  @Test func reserveUpgradeClampsWithoutRefillingAndDisabledRechargeWaitsForItsOriginalDeadline()
    throws
  {
    var reserve = try #require(ElectricalReserve(capacity: 100, recharge: 2, at: 0))
    let drained = reserve.drain(80, at: 0)
    try #require(drained)
    let upgraded = reserve.advance(to: 0, capacity: 200, recharge: 4)
    #expect(upgraded && reserve.remaining == 20)
    let zero = reserve.drain(20, at: 1)
    #expect(zero && reserve.disabledAt == 1)
    let progressed = reserve.advance(to: 30, capacity: 200, recharge: 4)
    #expect(progressed && reserve.remaining == 0 && reserve.recoveryAt == 31)
    let early = reserve.recover(at: 30)
    #expect(!early && reserve.disabledAt == 1)
    let recovered = reserve.recover(at: 32)
    #expect(recovered && reserve.remaining == 4 && reserve.disabledAt == nil)
    #expect(reserve.valid)
  }
}

extension EMPElectricalRuntimeTests {
  @Test func realTargetCentredSplashCanDisablePlayerWithoutHullDamageAndBombStillWorks() throws {
    var game = try electricalGame()
    game.bodies[0].position = .init(0, 0, 200)
    game.frontShield = 0
    game.rearShield = 32
    var electrical = try #require(
      ElectricalReserve(
        capacity: game.commander.performance.energy,
        recharge: game.commander.performance.recharge * game.commander.energyRechargeMultiplier,
        at: game.commander.flightSimulation.physicalTime))
    let lowered = electrical.drain(electrical.capacity - 9, at: electrical.physicalTime)
    try #require(lowered)
    game.commander.savedPlayerElectrical = electrical
    try game.commander.grantEquipment(
      "Energy Bomb", at: .utility(.energyBomb),
      provenance: .grant("EMP emergency bomb boundary"))
    let hull = game.energy
    try releaseElectricalPulse(&game)
    try #require(game.playerEMPDisabled)
    #expect(game.energy == hull && game.rearShield == 32)
    #expect(game.commander.savedPlayerElectrical?.remaining == 0)
    let emission = game.commander.flightSimulation.nextEmission
    game.fireCooldown = 0
    game.fireLaser()
    game.beginHyperspace()
    #expect(game.commander.flightSimulation.nextEmission == emission && game.jumpCountdown == nil)
    game.energyBomb()
    #expect(game.commander.fittedEquipment(at: .utility(.energyBomb)) == nil)
    #expect(game.energy > 0 && game.commander.valid)
  }

  @Test func actualOwnedEscapeClearsWarmupAndItsOldContextOnlyOnSuccessfulEscape() throws {
    var game = try electricalGame()
    try game.commander.grantEquipment(
      "Escape Pod", at: .utility(.escapePod),
      provenance: .grant("EMP emergency escape boundary"))
    let began = game.fireEMPPirateBlaster()
    try #require(began)
    let owner = game.commander.equipmentOwnerID
    game.escapePod()
    #expect(game.docked && game.commander.valid)
    #expect(game.commander.equipmentOwnerID == owner)
    #expect(game.commander.savedEMPCharge == nil && game.commander.savedPlayerElectrical == nil)
    #expect(game.commander.fittedEquipment(at: .utility(.escapePod)) == nil)
    game.launch()
    #expect(!game.docked && game.commander.valid && !game.playerEMPDisabled)
  }

  @Test func newElectricalFieldsCannotBeErasedByLegacyHeaderOrRawDecoding() throws {
    for key in ["savedPlayerElectrical", "savedEMPCharge"] {
      let bytes = try JSONSerialization.data(withJSONObject: [key: NSNull()])
      #expect(throws: SaveError.self) { try ElectricalVersionedSave.rejectFields(bytes) }
    }
    for key in ["electrical", "legacyElectricalRecharge"] {
      let bytes = try JSONSerialization.data(withJSONObject: [
        "bodies": [["physical": ["npc": ["resources": [key: NSNull()]]]]]
      ])
      #expect(throws: SaveError.self) { try ElectricalVersionedSave.rejectFields(bytes) }
    }
    try ElectricalVersionedSave.rejectFields(
      try JSONSerialization.data(withJSONObject: [
        "savedScriptState": ["data": ["electrical": 4]],
        "bodies": [["scriptNPC": ["data": ["electrical": 7]]]],
      ]))
  }
}

extension EMPElectricalRuntimeTests {
  @Test func actualSelfDisableAndTabCannotRestartPoweredWorkUntilEarnedRecovery() throws {
    var game = try electricalGame()
    game.bodies[0].position = .init(0, 0, 200)
    game.frontShield = 0
    game.speed = 1
    try game.commander.grantEquipment(
      "Energy Bomb", at: .utility(.energyBomb),
      provenance: .grant("EMP propulsion boundary"))
    try game.commander.grantEquipment(
      "Targeting: Mining Module", at: .targetingMining,
      provenance: .grant("EMP propulsion boundary"))
    try game.commander.grantEquipment(
      LaserKind.mining.equipmentName, at: .utility(.miningLaser),
      provenance: .grant("EMP propulsion boundary"))
    var electrical = try #require(
      ElectricalReserve(
        capacity: game.commander.performance.energy,
        recharge: game.commander.performance.recharge * game.commander.energyRechargeMultiplier,
        at: game.commander.flightSimulation.physicalTime))
    let lowered = electrical.drain(electrical.capacity - 9, at: electrical.physicalTime)
    try #require(lowered)
    game.commander.savedPlayerElectrical = electrical
    try releaseElectricalPulse(&game)
    try #require(game.playerEMPDisabled)
    let momentum = game.flightWorldVelocity
    // Exercise the owned emergency route rather than making the hostile emitter
    // invulnerable, suppressing its weapons or teleporting it out of the scene.
    game.energyBomb()
    let anchors = try #require(game.commander.flightSimulation.anchors)
    game.miningFields = MiningFields.generate(anchors: anchors, seed: game.gameplaySeed)
    let rock = try #require(game.miningFields.first?.rocks.first)
    let allocated = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocated)
    var body = SpaceBody(id: 80, hull: .asteroid, position: .init(0, 0, 1500))
    body.energy = rock.energy
    body.physical = .init(identity: actor, population: .asteroid, rock: rock.identity)
    game.bodies.append(body)
    game.nextBodyID = max(81, game.nextBodyID)
    game.key("f")
    try #require(game.workTargetFilter == .mining)
    var control = game
    game.key("tab")
    for _ in 0..<10 {
      game.tick(delta: 0.1)
      control.tick(delta: 0.1)
      #expect(game.playerEMPDisabled && game.workGuidance == nil && game.workBraking == nil)
      #expect(game.lastAppliedWorkMotion == nil)
      #expect(game.commander.flightSimulation.pose == control.commander.flightSimulation.pose)
      #expect((game.flightWorldVelocity - momentum).length < 1e-8)
      #expect(game.energy == control.energy && game.commander == control.commander)
    }
    for _ in 0..<301 where game.playerEMPDisabled { game.tick(delta: 0.1) }
    try #require(!game.playerEMPDisabled && game.screen != .gameOver)
    game.key("tab")
    try #require(game.workGuidance?.parent == actor)
    game.tick(delta: 0.1)
    #expect(game.lastAppliedWorkMotion != nil)
  }

  @Test func cockpitReportsElectricalPowerHullAndActualWarmupSeparately() throws {
    var game = try electricalGame()
    let began = game.fireEMPPirateBlaster()
    try #require(began)
    game.tick(delta: 0.1)
    let charging = Display.cockpit(game, width: 768, height: 768)
    #expect(charging.labels.contains { $0.text.contains("EMP CHARGE: 9.9 S") })
    game.commander.flightSimulation.advancePhysicalTime(10)
    game.advanceEMPCharge(triggerHeld: true)
    let frame = Display.cockpit(game, width: 768, height: 768)
    #expect(frame.labels.contains { $0.text == "Hull" })
    #expect(frame.labels.contains { $0.text.contains("POWER:") })
    let body = try #require(game.bodies.first { $0.id == 42 })
    let fields = TargetTelemetry.fields(
      facts: game.telemetryFacts(for: body), tier: .military,
      targetIsShip: true, observerGalaxy: game.commander.galaxy)
    #expect(fields.contains { $0.label == "Electrical power" })
  }
}

extension EMPElectricalRuntimeTests {
  @Test func selfDisabledSpinKeepsItsActualInertiaUntilPositiveEarnedPowerReturns() throws {
    var game = try electricalGame()
    game.bodies[0].position = .init(0, 0, 200)
    game.frontShield = 0
    try game.commander.grantEquipment(
      "Energy Bomb", at: .utility(.energyBomb),
      provenance: .grant("EMP spin boundary"))
    var reserve = try #require(
      ElectricalReserve(
        capacity: game.commander.performance.energy,
        recharge: game.commander.performance.recharge * game.commander.energyRechargeMultiplier,
        at: game.commander.flightSimulation.physicalTime))
    let lowered = reserve.drain(reserve.capacity - 9, at: reserve.physicalTime)
    try #require(lowered)
    game.commander.savedPlayerElectrical = reserve
    game.spin.toggleMode()
    game.spin.begin(.clockwise)
    game.spin.advance(delta: 0.1, controls: Controls())
    let inertia = game.spin.actualRate
    let command = game.spin.commandedRate
    try #require(inertia > 0 && inertia < command)
    try releaseElectricalPulse(&game)
    try #require(game.playerEMPDisabled)
    game.energyBomb()
    for _ in 0..<301 where game.playerEMPDisabled {
      let disabledBefore = game.playerEMPDisabled
      game.tick(delta: 0.1)
      if disabledBefore && game.playerEMPDisabled {
        #expect(game.spin.actualRate == inertia && game.spin.commandedRate == command)
      }
    }
    try #require(!game.playerEMPDisabled && game.screen != .gameOver)
    #expect(game.spin.actualRate > inertia && game.spin.actualRate <= command)
  }
}
