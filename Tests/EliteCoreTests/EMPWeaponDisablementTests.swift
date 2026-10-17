import Testing

@testable import EliteCore

struct EMPWeaponDisablementTests {
  @Test func disabledOccupiedHostileCannotEmitLegacyAIOrNavalWeaponsOrSpendAmmunition() throws {
    var game = try empFixture(hostile: true)
    game.commander.retaliationEnabled = false
    game.commander.autoECM = false
    game.commander.cargo[CommodityIdentity.food.rawValue] = 1
    game.bodies[0].missiles = 2
    game.bodies[0].orientation.rotate(pitch: 0, roll: 0, yaw: .pi)
    let id = game.bodies[0].id
    let actor = try #require(game.bodies[0].physical?.identity)
    var armed = game
    let emission = armed.commander.flightSimulation.nextEmission
    armed.emitLegacyNPCBeam(bodyID: id, damage: 1)
    #expect(armed.commander.flightSimulation.nextEmission > emission)
    let armedHeat = try #require(armed.bodies[0].physical?.npc?.resources?.laserHeat)
    let originalHeat = try #require(game.bodies[0].physical?.npc?.resources?.laserHeat)
    #expect(armedHeat > originalHeat)
    let fired = game.fireEMPPirateBlaster()
    try #require(fired)
    let source = try #require(game.bodies[0].physical?.empSource)
    let custody = try #require(game.commander.savedEMPState?.records[source])
    try #require(custody.crewAboard > 0 && custody.pods.isEmpty)
    let before = game.commander
    let body = game.bodies[0]
    let playerResources = [game.energy, game.frontShield, game.rearShield]
    game.emitLegacyNPCBeam(bodyID: id, damage: 1000)
    let launched = game.launchGameplayNPCMissile(bodyID: id)
    #expect(!launched)
    game.navalTactics()
    game.enemyAction(index: 0, dt: 0.1)
    #expect(game.commander == before && game.bodies[0] == body)
    #expect([game.energy, game.frontShield, game.rearShield] == playerResources)
    let context = try #require(game.gameplayContext())
    try #require(
      TrafficIntent.intents(context: context).contains {
        $0.actor == actor && $0.action == .engage(context.player.identity)
      })
    game.advanceGameplayEncounters(delta: 0)
    let after = try #require(game.bodies.first { $0.physical?.identity == actor })
    #expect(after.energy == body.energy && after.missiles == body.missiles)
    #expect(after.physical?.npc?.resources == body.physical?.npc?.resources)
    #expect(after.physical?.laserCooldown == body.physical?.laserCooldown)
    #expect(!game.bodies.contains { $0.physical?.ordnance?.origin.owner == actor })
    #expect(game.commander.legal == before.legal)
    #expect(
      game.commander.savedEMPState?.records[source]?.disableIncident == custody.disableIncident)
    #expect(game.commander.savedEMPState?.records[source]?.cargo == custody.cargo)
    #expect(game.commander.savedEMPState?.records[source]?.crewAboard == custody.crewTotal)
    #expect(game.targetColourCue(for: after) == .recoverable && after.hostile)
  }

  @Test func missileActuallyFiredBeforeEMPContinuesWithOriginalOwnerAndRedThreatCue() throws {
    var game = try empFixture(hostile: true)
    game.commander.autoECM = false
    game.commander.retaliationEnabled = false
    game.bodies[0].missiles = 2
    let owner = try #require(game.bodies[0].physical?.identity)
    let id = game.bodies[0].id
    let launched = game.launchGameplayNPCMissile(bodyID: id)
    try #require(launched)
    let missileActor = try #require(game.bodies.first { $0.enemyMissile }?.physical?.identity)
    // Aim at the actual Cobra's wing through real camera motion, clearing its emitted missile.
    var controls = Controls()
    controls.yaw = 0.045 / (0.1 * game.commander.performance.yaw)
    game.tick(delta: 0.1, controls: controls)
    let contact = try #require(
      game.nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1), range: Game.empRange,
        radius: 0, includePlayer: false))
    try #require(contact.hit.target == .body(id))
    let before = try #require(
      game.bodies.first { $0.physical?.identity == missileActor }?.physical?.ordnance)
    let fired = game.fireEMPPirateBlaster()
    try #require(fired)
    let disabled = try #require(game.bodies.first { $0.id == id })
    #expect(game.targetColourCue(for: disabled) == .recoverable)
    #expect(disabled.missiles == 1)
    let refused = game.launchGameplayNPCMissile(bodyID: id)
    #expect(!refused)
    game.tick(delta: 0.1)
    let missile = try #require(game.bodies.first { $0.physical?.identity == missileActor })
    let continuing = try #require(missile.physical?.ordnance)
    #expect(continuing.origin == before.origin && continuing.origin.owner == owner)
    #expect(continuing.termination == nil && continuing.position != before.position)
    #expect(missile.energy > 0 && missile.hostile && missile.enemyMissile)
    #expect(game.flightStatus == "Hostile")
    for style in ShipDisplayStyle.allCases {
      game.commander.shipDisplayStyle = style
      #expect(game.targetColourCue(for: missile) == .hostile)
      let parent = try #require(game.bodies.first { $0.id == id })
      #expect(game.targetColourCue(for: parent) == .recoverable)
      for selected in [false, true] {
        game.weaponsTargetID = selected ? missile.id : nil
        let hud = Display.cockpit(game, width: 768, height: 768)
        #expect(
          hud.graphics.contains {
            if case .line(let line) = $0 {
              line.ink == .red && line.y0 > hud.flightClip.maxY
            } else {
              false
            }
          })
        if selected {
          #expect(
            hud.labels.contains { $0.ink == .red && $0.text.contains("#" + String(missile.id)) })
        }
      }
      var frame = Frame()
      frame.rasterizeGraphics = false
      Display.targetWorldGlow(
        missile, game: game, projection: .legacy,
        scene: GameplayRaycast.prepareOcclusionScene(game), context: game.gameplayContext(),
        into: &frame)
      let lines = frame.graphics.compactMap {
        if case .glow(let line) = $0 { line } else { nil as WireLine? }
      }
      #expect(!lines.isEmpty && lines.allSatisfy { $0.ink == .red })
    }
  }
}
