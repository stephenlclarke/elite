import Foundation
import Testing

@testable import EliteCore

private func missileRuntimeGame(hull: Hull = .cobra, distance: Double = 1800) -> Game {
  var game = Game(executive: false)
  game.launch()
  game.speed = 0
  game.commander.flightSimulation.pose.position = .init(0, 0, -3000)
  game.bodies = [.init(id: 70, hull: hull, position: .init(0, 0, distance))]
  game.ensurePhysicalActors()
  game.weaponsTargetID = 70
  game.missileArmed = true
  return game
}

private func missileRuntimeAdvance(_ game: inout Game, delta: Double) {
  game.commander.flightSimulation.advancePhysicalTime(delta)
  game.advanceNavalMissiles(delta: delta)
}

struct GameplayOrdnanceRuntimeTests {
  @Test func actualPlayerLaunchSpendsOneMissileOnlyAfterAdmissionAndNeverKillsInstantly() throws {
    var game = missileRuntimeGame()
    let target = game.bodies[0]
    let player = try #require(game.commander.flightSimulation.player)
    game.key("m")
    let missile = try #require(game.bodies.first { $0.physical?.ordnance != nil })
    let state = try #require(missile.physical?.ordnance)
    #expect(game.commander.missiles == 2 && !game.missileArmed && game.missileCooldown == 1)
    #expect(game.bodies[0].energy == target.energy && game.commander.kills == 0)
    #expect(state.origin.owner == player && state.origin.ordnance == missile.physical?.identity)
    #expect(state.emissionPosition == game.commander.flightSimulation.pose.position)
    #expect(missile.physical?.emissionPosition == state.emissionPosition)
    #expect(state.target == target.physical?.identity && missile.playerMissileTarget == target.id)
    #expect(missile.physical?.spawnIdentity?.producer == .ordnance)
    #expect(game.commander.legal == 8 && game.bodies[0].physical?.npc?.firstAggressor == player)
    missileRuntimeAdvance(&game, delta: 0.1)
    let moved = try #require(game.bodies.first { $0.id == missile.id }?.physical?.ordnance)
    #expect(abs(moved.propulsionTravel - 79.2) < 1e-8 && moved.termination == nil)
    #expect(game.bodies[0].energy == target.energy)
    missileRuntimeAdvance(&game, delta: 3)
    #expect(game.bodies[0].energy == 0 && game.commander.kills == 1)
    #expect(game.bodies[0].physical?.deathOrigin == state.origin)
    missileRuntimeAdvance(&game, delta: 1)
    #expect(game.commander.kills == 1)
  }

  @Test func actualFlightTickAllowsAnOccludingMissileToBeInterceptedByTheVictimsBeam() throws {
    var game = missileRuntimeGame(distance: 1000)
    // This victim fires its front-mounted beam back toward the incoming missile.
    let victimIndex = try #require(game.bodies.firstIndex { $0.id == 70 })
    game.bodies[victimIndex].orientation.x = .init(-1, 0, 0)
    game.bodies[victimIndex].orientation.z = .init(0, 0, -1)
    let launched = game.fireMissile()
    #expect(launched)
    let missile = try #require(game.bodies.first { $0.physical?.ordnance != nil })
    game.tick(delta: 0.02)
    if game.bodies.contains(where: { $0.id == missile.id }),
      let victim = game.bodies.first(where: { $0.id == 70 })
    {
      let contact = try? game.nearestMissionCollision(
        from: victim.position, direction: victim.orientation.z.unit, range: 1500,
        radius: 0, excludingBodyIDs: [victim.id], includePlayer: true)
      FileHandle.standardError.write(
        Data(
          "Missile interception source=\(victim.id) position=\(victim.position) forward=\(victim.orientation.z) role=\(String(describing: victim.physical?.npc?.role)) intent=\(String(describing: victim.physical?.npc?.intention)) cooldown=\(victim.physical?.laserCooldown ?? -1) contact=\(String(describing: contact?.hit.target)) stations=\(game.bodies.filter { $0.hull == .station }.count) missile=\(missile.id)\n"
            .utf8))
    }
    #expect(!game.bodies.contains { $0.id == missile.id })
    #expect(game.bodies.first { $0.id == 70 }?.energy == 100)
    #expect(game.commander.kills == 0 && game.commander.legal == 8)
    #expect(game.commander.missiles == 2)
  }

  @Test func refusedFullProjectilePopulationPreservesAmmoIdentitiesTargetAndCrimeState() throws {
    var game = missileRuntimeGame()
    for id in 100..<132 {
      game.bodies.append(.init(id: id, hull: .missile, position: .init(Double(id) * 10, 0, 4000)))
    }
    game.ensurePhysicalActors()
    let before = game
    let launched = game.fireMissile()
    #expect(!launched)
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(game.nextBodyID == before.nextBodyID && game.missileCooldown == 0)
    #expect(game.missileArmed && game.weaponsTargetID == before.weaponsTargetID)
  }

  @Test func realStationMeshOccludesPlayerMissileAndNeverDamagesTheShipBehindIt() throws {
    var game = missileRuntimeGame(distance: 4000)
    game.bodies.append(.init(id: 0, hull: .station, position: .init(0, 0, 2000)))
    let targetEnergy = game.bodies[0].energy
    let launched = game.fireMissile()
    #expect(launched)
    missileRuntimeAdvance(&game, delta: 5)
    let missile = try #require(game.bodies.first { $0.physical?.ordnance != nil })
    #expect(missile.physical?.ordnance?.termination == .impact)
    #expect(game.commander.stationSecurity.phase == .alarm)
    #expect(game.bodies[0].energy == targetEnergy && game.commander.kills == 0)
    #expect(game.bodies.first { $0.id == 0 }?.energy ?? 0 > 0)
  }

  @Test func nativeShieldedNPCReceivesFiniteDamageInsteadOfLegacyInstantDestruction() throws {
    var game = missileRuntimeGame(distance: 1000)
    let resources = NPCResources(
      profile: .nativeHull, energyCapacity: 100, energyRecharge: 0,
      frontCapacity: 500, rearCapacity: 500, shieldRecharge: 0,
      frontShield: 500, rearShield: 500, heatCapacity: 240, heatCooling: 12,
      fuel: 70, fuelCapacity: 70)
    game.bodies[0].physical?.npc?.resources = resources
    let launched = game.fireMissile()
    #expect(launched)
    missileRuntimeAdvance(&game, delta: 2)
    let remaining = try #require(game.bodies[0].physical?.npc?.resources)
    #expect(game.bodies[0].energy == 100 && game.commander.kills == 0)
    #expect(remaining.frontShield + remaining.rearShield == 750)
  }

  @Test func originalConstrictorStillDiesToOneCloseMissileBeforeItCanActivateECM() throws {
    var game = missileRuntimeGame(hull: .constrictor, distance: 100)
    game.bodies[0].navalTarget = true
    let launched = game.fireMissile()
    #expect(launched && game.bodies[0].energy == 252)
    missileRuntimeAdvance(&game, delta: 0.1)
    #expect(game.bodies[0].energy == 0 && game.ecmFrames == 0)
    #expect(game.bodies.last?.physical?.ordnance?.termination == .impact)
  }

  @Test func lostTargetCannotRetargetAnUnrelatedShipWithReusedDisplayID() throws {
    var game = missileRuntimeGame()
    let launched = game.fireMissile()
    #expect(launched)
    let original = try #require(game.bodies[0].physical?.identity)
    let missile = try #require(game.bodies.first { $0.physical?.ordnance != nil })
    game.bodies.removeFirst()
    game.bodies.append(.init(id: 70, hull: .cobra, position: .init(0, 0, 1000)))
    game.ensurePhysicalActors()
    #expect(game.bodies.last?.physical?.identity != original)
    missileRuntimeAdvance(&game, delta: 2)
    #expect(game.bodies.first { $0.id == 70 }?.energy == 100 && game.commander.kills == 0)
    #expect(
      game.bodies.first { $0.id == missile.id }?.physical?.ordnance?.termination == .targetLost)
  }

  @Test func realNPCLauncherDoesNotLoseItsMissileOwnerWhenTheCraftIsRemoved() throws {
    var game = missileRuntimeGame(distance: 1000)
    let initialCash = game.commander.credits
    game.frontShield = 100
    let ownerIndex = try #require(game.bodies.firstIndex { $0.id == 70 })
    let mesh = game.commander.playerMesh
    let surface = try #require(
      mesh.faces.lazy.compactMap { face -> Vector3? in
        guard face.count == 3, face.allSatisfy(mesh.vertices.indices.contains) else { return nil }
        let a = mesh.vertices[face[0]]
        let b = mesh.vertices[face[1]]
        let c = mesh.vertices[face[2]]
        guard (b - a).cross(c - a).length > 0 else { return nil }
        let center = (a + b + c) * (1 / 3.0)
        return center.finite && center.z > 0 && center.length > 0 ? center : nil
      }.first)
    let outward = surface.unit
    let launch = outward * 1000
    #expect(launch.length > (mesh.vertices.map(\.length).max() ?? 0) + 24)
    game.bodies[ownerIndex].position = launch
    let contact = try #require(
      try game.nearestMissionCollision(
        from: launch - outward * 24, direction: outward * -1, range: 1000,
        radius: 0, excludingBodyIDs: [70], includePlayer: true))
    try #require(contact.hit.target == .player && contact.hit.point.z > 0)
    game.bodies[ownerIndex].missiles = 1
    let owner = try #require(game.bodies[ownerIndex].physical?.identity)
    let launched = game.launchGameplayNPCMissile(bodyID: 70)
    #expect(launched)
    let secondLaunch = game.launchGameplayNPCMissile(bodyID: 70)
    let spentOwner = try #require(game.bodies.first { $0.physical?.identity == owner })
    #expect(spentOwner.missiles == 0)
    #expect(!secondLaunch)
    let missile = try #require(game.bodies.first { $0.physical?.ordnance?.origin.owner == owner })
    let missileIdentity = try #require(missile.physical?.identity)
    #expect(missile.enemyMissile && missile.missileSourceID == 70)
    game.bodies.removeAll { $0.physical?.identity == owner }
    #expect(!game.bodies.contains { $0.physical?.identity == owner })
    missileRuntimeAdvance(&game, delta: 2)
    let retainedMissile = try #require(
      game.bodies.first { $0.physical?.identity == missileIdentity })
    #expect(retainedMissile.id == missile.id)
    let state = try #require(retainedMissile.physical?.ordnance)
    #expect(state.origin.owner == owner)
    #expect(
      state.termination == .impact,
      Comment(
        rawValue:
          "Native missile termination: \(String(describing: state.termination)); position: \(state.position); clock: \(state.lastUpdatedAt)/\(game.commander.flightSimulation.physicalTime); message: \(game.message)"
      ))
    #expect(game.frontShield == 0)
    #expect(game.energy < game.commander.performance.energy)
    #expect(game.commander.kills == 0)
    #expect(game.commander.credits == initialCash)
  }

  @Test func actualECMFieldRespectsTypedPlasmaAndOneActivationSeekerResistance() throws {
    for profile in OrdnanceProfile.allCases {
      var game = missileRuntimeGame(distance: 4000)
      let launched = game.fireMissile()
      #expect(launched)
      let index = try #require(
        game.bodies.indices.first { game.bodies[$0].physical?.ordnance != nil })
      let old = try #require(game.bodies[index].physical?.ordnance)
      game.bodies[index].physical?.ordnance = try #require(
        OrdnanceState(
          profile: profile, origin: old.origin, target: old.target, position: old.position,
          direction: old.direction))
      game.commander.equipment.insert("E.C.M. System")
      game.ecm()
      let first = try #require(game.bodies[index].physical?.ordnance)
      #expect((first.termination == .ecm) == (profile == .standardMissile))
      #expect((first.resistedECM != nil) == (profile == .alienSeeker))
      for _ in 0..<32 {
        game.advanceGameplayOrdnance(allowEnemyECM: false)
        game.ecmControl.advance()
      }
      #expect(
        game.ecmControl.events.contains { $0.announcement == .missilesDestroyed(1) }
          == (profile == .standardMissile))
      game.ecmFrames = 0
      game.ecm()
      let second = try #require(game.bodies[index].physical?.ordnance)
      #expect((second.termination == .ecm) == (profile != .plasma))
      #expect(game.commander.kills == 0)
    }
  }

  @Test(arguments: [false, true])
  func retaliationNeverTargetsAReplacementForTheActualMissileLauncher(
    replaceAfterIdentification: Bool
  ) throws {
    var game = missileRuntimeGame(distance: 4000)
    game.weaponsTargetID = nil
    game.bodies[0].missiles = 1
    try game.commander.grantEquipment(
      TargetingTier.military.equipmentName, at: .targetingCore,
      provenance: .grant("ordnance targeting fixture"))
    #expect(game.commander.equipmentInventory != nil && game.commander.targetingTier == .military)
    game.commander.equipment.insert("E.C.M. System")
    let owner = try #require(game.bodies[0].physical?.identity)
    let launched = game.launchGameplayNPCMissile(bodyID: 70)
    #expect(launched)
    if replaceAfterIdentification { game.detectRetaliationSources() }
    game.bodies.removeFirst()
    game.bodies.append(.init(id: 70, hull: .cobra, position: .init(0, 0, 4000)))
    game.ensurePhysicalActors()
    let replacement = try #require(game.bodies.last?.physical?.identity)
    #expect(owner != replacement)
    game.ecm()
    for _ in 0..<32 {
      game.advanceGameplayOrdnance(allowEnemyECM: false)
      game.ecmControl.advance()
    }
    game.ecmFrames = 0
    game.advanceRetaliation()
    #expect(game.commander.missiles == 3 && game.commander.legal == 0)
    #expect(game.bodies.last?.energy == 100)
    #expect(
      !game.ecmControl.events.contains {
        if case .missileLaunched = $0.announcement { return true }
        return false
      })
    if !replaceAfterIdentification {
      #expect(!game.ecmControl.events.contains { $0.announcement == .incomingIdentified })
      #expect(game.weaponsTargetID == nil)
    }
  }

  @Test func queuedReturnFireRechecksLauncherIdentityAfterECMConfirmation() throws {
    var game = missileRuntimeGame(distance: 4000)
    game.weaponsTargetID = nil
    game.bodies[0].missiles = 1
    try game.commander.grantEquipment(
      TargetingTier.military.equipmentName, at: .targetingCore,
      provenance: .grant("ordnance targeting fixture"))
    #expect(game.commander.equipmentInventory != nil && game.commander.targetingTier == .military)
    game.commander.equipment.insert("E.C.M. System")
    let launched = game.launchGameplayNPCMissile(bodyID: 70)
    #expect(launched)
    game.ecm()
    #expect(game.ecmControl.events.contains { $0.announcement == .incomingIdentified })
    game.bodies.removeFirst()
    game.bodies.append(.init(id: 70, hull: .cobra, position: .init(0, 0, 4000)))
    game.ensurePhysicalActors()
    game.ecmFrames = 0
    game.advanceRetaliation()
    #expect(game.commander.missiles == 3 && game.commander.legal == 0)
    #expect(
      game.ecmControl.events.contains {
        $0.announcement == .cannotRetaliate("Enemy craft no longer available")
      })
  }

  @Test func missileMayLaunchInScoopableCoronaWithoutSpendingAmmoInsideTheSun() throws {
    var game = missileRuntimeGame()
    let anchors = try #require(game.commander.flightSimulation.anchors)
    game.commander.flightSimulation.pose.position = anchors.sun.position + .init(0, 0, -3000)
    let launched = game.fireMissile()
    #expect(launched)
    game = missileRuntimeGame()
    game.commander.flightSimulation.pose.position = anchors.sun.position
    let before = game.commander
    let unsafeLaunch = game.fireMissile()
    #expect(!unsafeLaunch && game.commander == before && game.missileArmed)
  }
}
