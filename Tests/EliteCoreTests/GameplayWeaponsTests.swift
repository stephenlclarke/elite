import Foundation
import Testing

@testable import EliteCore

private func weaponsGame() -> Game {
  var game = Game(executive: false)
  game.docked = false
  game.screen = .front
  game.speed = 0
  game.commander.flightSimulation.enter(game.systemIdentity, arriving: true)
  game.commander.flightSimulation.pose.position = .init(0, 0, -3000)
  game.bodies = []
  game.celestials = []
  return game
}

struct GameplayWeaponsTests {
  @Test(arguments: LaserMount.allCases)
  func everyCombatMountUsesItsPhysicalDirection(_ mount: LaserMount) {
    var game = weaponsGame()
    game.commander.installLaser(.pulse, on: mount)
    game.screen = Screen(rawValue: mount.rawValue)!
    let position: Vector3
    switch mount {
    case .front: position = .init(0, 0, 500)
    case .rear: position = .init(0, 0, -500)
    case .left: position = .init(-500, 0, 0)
    case .right: position = .init(500, 0, 0)
    }
    var target = SpaceBody(id: 10, hull: .cargo, position: position)
    target.energy = 100
    game.bodies = [target]
    game.fireLaser()
    #expect(game.bodies[0].energy == 85)
    #expect(game.fireCooldown == LaserKind.pulse.firingInterval && game.energy == 255)
  }

  @Test func nearestActualHullWinsRegardlessOfBodyArrayOrderAndWeaponLock() {
    var game = weaponsGame()
    var far = SpaceBody(id: 10, hull: .sidewinder, position: .init(0, 0, 1000))
    var near = SpaceBody(id: 11, hull: .cargo, position: .init(0, 0, 500))
    far.energy = 100
    near.energy = 100
    game.bodies = [far, near]
    game.weaponsTargetID = far.id
    game.fireLaser()
    #expect(game.bodies[0].energy == 100 && game.bodies[1].energy == 85)
  }

  @Test func oldAimConeDoesNotDamageAHullTheBeamMisses() {
    var game = weaponsGame()
    var body = SpaceBody(id: 10, hull: .cargo, position: .init(60, 0, 2000))
    body.energy = 100
    game.bodies = [body]
    game.fireLaser()
    #expect(game.bodies[0].energy == 100 && game.commander.kills == 0)
  }

  @Test func stationAndPlanetOccludeTargetsAndStationFireRaisesAlarm() {
    var game = weaponsGame()
    var behind = SpaceBody(id: 10, hull: .cargo, position: .init(0, 0, 1000))
    behind.energy = 100
    let station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 500))
    game.bodies = [behind, station]
    game.fireLaser()
    #expect(game.bodies[0].energy == 100 && game.bodies[1].energy == station.energy)
    #expect(game.commander.legal > 0 && game.commander.stationSecurity.phase != .calm)
    var planetGame = weaponsGame()
    planetGame.bodies = [behind]
    planetGame.celestials = [.init(kind: .planet, position: .init(0, 0, 250), radius: 100)]
    planetGame.fireLaser()
    #expect(planetGame.bodies[0].energy == 100 && planetGame.commander.kills == 0)
  }

  @Test func killingACleanTraderDoesNotGainABountyFromItsRetaliationFlag() {
    var game = weaponsGame()
    var trader = SpaceBody(id: 10, hull: .sidewinder, position: .init(0, 0, 500))
    trader.energy = 10
    game.bodies = [trader]
    let cash = game.commander.credits
    game.fireLaser()
    #expect(game.bodies[0].hostile && game.bodies[0].energy == 0)
    #expect(game.commander.legal > 0 && game.commander.kills == 1)
    #expect(game.commander.credits == cash)
    game.resolveDestroyed()
    game.resolveDestroyed()
    #expect(game.commander.kills == 1 && game.commander.credits == cash)
  }

  @Test func attributedBombPreservesNativeImmunityAndSettlesEachVictimOnce() {
    var game = weaponsGame()
    game.commander.equipment.insert("Energy Bomb")
    let protected = SpaceBody(id: 1, hull: .constrictor, position: .init(0, 0, 1000))
    var pirate = SpaceBody(id: 2, hull: .sidewinder, position: .init(500, 0, 1000), hostile: true)
    pirate.energy = 100
    game.bodies = [protected, pirate]
    game.energyBomb()
    #expect(game.bodies[0].energy == protected.energy && game.bodies[1].energy == 0)
    #expect(game.commander.kills == 1)
    let cash = game.commander.credits
    game.resolveDestroyed()
    #expect(game.commander.kills == 1 && game.commander.credits == cash)
    #expect(!game.commander.equipment.contains("Energy Bomb"))
  }

  @Test func scriptedNPCBeamCanHitAnInterveningHullInsteadOfThePlayer() {
    var game = weaponsGame()
    let attacker = SpaceBody(id: 1, hull: .sidewinder, position: .init(0, 0, 1000), hostile: true)
    var blocker = SpaceBody(id: 2, hull: .cargo, position: .init(0, 0, 500))
    blocker.energy = 100
    game.bodies = [attacker, blocker]
    let shield = game.frontShield
    game.emitLegacyNPCBeam(bodyID: attacker.id, damage: 20)
    #expect(game.bodies[1].energy == 80 && game.frontShield == shield)
  }

  @Test func actualMiningBeamDepletesTheMatchedRockAndCreatesFiniteTypedOre() throws {
    var game = weaponsGame()
    game.beginGameplayVisit(arriving: true)
    let rock = try #require(game.miningFields.first?.rocks.first)
    game.commander.flightSimulation.pose.position = rock.position - Vector3(0, 0, 300)
    game.celestials = []
    game.commander.installLaser(.mining, on: .front)
    let allocated = game.commander.flightSimulation.allocateActor()
    let identity = try #require(allocated)
    var body = SpaceBody(id: 10, hull: .asteroid, position: .init(0, 0, 300))
    body.energy = rock.energy
    body.physical = .init(identity: identity, population: .asteroid, rock: rock.identity)
    game.bodies = [body]
    for _ in 0..<4 {
      game.fireCooldown = 0
      game.fireLaser()
    }
    #expect(game.commander.miningLedger.isDepleted(rock.identity) && game.bodies[0].energy == 0)
    let pending = game.commander.miningLedger.pendingPayloads
    #expect(!pending.isEmpty && game.commander.cargo.allSatisfy { $0 == 0 })
    game.fireCooldown = 0
    game.fireLaser()
    #expect(game.commander.miningLedger.pendingPayloads == pending)
    #expect(game.commander.kills == 0 && game.commander.credits == 1000)
  }
}
