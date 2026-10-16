import Foundation
import Testing

@testable import EliteCore

private func ordnanceRequire<T>(_ value: T?) throws -> T { try #require(value) }

private func ordnanceGame() -> Game {
  var game = Game(executive: false)
  game.docked = false
  game.screen = .front
  game.commander.flightSimulation.enter(game.systemIdentity, arriving: true)
  game.commander.flightSimulation.pose.position = .init(0, 0, -3000)
  return game
}

@discardableResult
private func ordnanceActor(
  _ game: inout Game, id: Int = 10, hull: Hull = .cobra,
  position: Vector3 = .init(0, 0, 10000), legal: LegalRecord = .init()
) throws -> ActorIdentity {
  let identity = try ordnanceRequire(game.commander.flightSimulation.allocateActor())
  var body = SpaceBody(id: id, hull: hull, position: position)
  body.energy = 100
  body.physical = .init(
    identity: identity, population: .civilian,
    npc: .init(
      role: .trader, legal: legal, origin: game.systemIdentity, destination: game.systemIdentity))
  game.bodies.append(body)
  return identity
}

private func ordnanceShot(
  _ game: inout Game, profile: OrdnanceProfile = .standardMissile,
  target: ActorIdentity? = nil, owner: ActorIdentity? = nil,
  position: Vector3? = nil, direction: Vector3 = .init(0, 0, 1),
  launcherVelocity: Vector3 = .init(0, 0, 0)
) throws -> OrdnanceState {
  let owner = try ordnanceRequire(owner ?? game.commander.flightSimulation.player)
  let identity = try ordnanceRequire(game.commander.flightSimulation.allocateActor())
  let origin = try ordnanceRequire(game.makeAttackOrigin(owner: owner, ordnance: identity))
  let position = position ?? game.commander.flightSimulation.pose.position
  let state = try ordnanceRequire(
    OrdnanceState(
      profile: profile, origin: origin, target: target, position: position,
      direction: direction, launcherVelocity: launcherVelocity))
  var body = SpaceBody(
    id: 20, hull: .missile, position: game.commander.flightSimulation.pose.shipPoint(position))
  body.physical = .init(identity: identity, population: .projectile, npc: nil, attackOrigin: origin)
  game.bodies.append(body)
  return state
}

private func ordnanceAdvance(
  _ game: inout Game, state: inout OrdnanceState, time: Double,
  pulses: [ECMActivationIdentity] = []
) throws -> OrdnanceUpdate {
  game.commander.flightSimulation.advancePhysicalTime(
    time - game.commander.flightSimulation.physicalTime)
  let context = try ordnanceRequire(game.gameplayContext())
  return game.advanceOrdnance(bodyID: 20, state: &state, context: context, activeECM: pulses)
}

struct GameplayOrdnanceTests {
  @Test func finiteStandardMissileMovesAtNativeSpeedAndDoesNotTunnelThroughNearestHull() throws {
    var game = ordnanceGame()
    let target = try ordnanceActor(
      &game, position: .init(0, 0, 2000), legal: .init(value: 64, bountyTenths: 1000))
    try ordnanceActor(&game, id: 11, position: .init(0, 0, 1000))
    var state = try ordnanceShot(&game, target: target)
    let first = try ordnanceAdvance(&game, state: &state, time: 0.1)
    #expect(first.termination == nil && abs(state.propulsionTravel - 79.2) < 1e-8)
    #expect(abs(state.position.z + 2920.8) < 1e-8 && (game.bodies.last?.energy ?? 0) > 0)
    let impact = try ordnanceAdvance(&game, state: &state, time: 3)
    #expect(impact.hit?.target == .body(11) && impact.termination == .impact && impact.endedNow)
    #expect(game.bodies[0].energy == 100 && game.bodies[1].energy == 0)
    #expect(
      game.commander.legal == 40 && game.commander.credits == 1000 && game.commander.kills == 1)
    #expect(game.bodies[1].physical?.deathOrigin == state.origin)
    let repeated = try ordnanceAdvance(&game, state: &state, time: 4)
    #expect(!repeated.endedNow && repeated.hit == nil && game.commander.kills == 1)
  }

  @Test func actualStationOccludesTargetAndRecordsAttackDespiteItsInvulnerability() throws {
    var game = ordnanceGame()
    let target = try ordnanceActor(&game, position: .init(0, 0, 5000))
    game.bodies.append(.init(id: 0, hull: .station, position: .init(0, 0, 3000)))
    game.ensurePhysicalActors()
    let initialEnergy = game.bodies[1].energy
    var state = try ordnanceShot(&game, target: target)
    let impact = try ordnanceAdvance(&game, state: &state, time: 5)
    #expect(impact.hit?.target == .body(0) && impact.incident?.victimIsStation == true)
    #expect(game.bodies[0].energy == 100 && game.bodies[1].energy == initialEnergy)
    #expect(game.commander.legal == 64 && game.commander.stationSecurity.phase == .alarm)
    #expect(game.commander.kills == 0 && game.bodies.count == 3)
  }

  @Test func celestialBlocksBallisticPlasmaWithoutDamagingTheShipBehindIt() throws {
    var game = ordnanceGame()
    try ordnanceActor(&game, position: .init(0, 0, 1000))
    game.celestials = [.init(kind: .planet, position: .init(0, 0, 400), radius: 100)]
    var state = try ordnanceShot(&game, profile: .plasma)
    let impact = try ordnanceAdvance(&game, state: &state, time: 2)
    #expect(impact.hit?.target == .celestial(.planet) && impact.termination == .impact)
    #expect(abs(state.position.z + 2700) < 1e-8 && game.bodies[0].energy == 100)
    #expect(
      impact.incident?.kind == .plasma && game.commander.legal == 0 && game.commander.kills == 0)
  }

  @Test func plasmaInheritsLauncherVelocityButRangeCountsOnlyItsOwnPropulsion() throws {
    for inherited in [0.0, 10000] {
      var game = ordnanceGame()
      var state = try ordnanceShot(
        &game, profile: .plasma, launcherVelocity: .init(0, 0, inherited))
      let expired = try ordnanceAdvance(&game, state: &state, time: 1_000_000)
      #expect(expired.termination == .rangeExpired && expired.endedNow)
      #expect(abs(state.position.z - (-3000 + (600 + inherited) * 2)) < 1e-8)
      #expect(state.propulsionTravel == 1200 && state.lastUpdatedAt == 2 && state.valid)
      #expect(
        game.bodies.last?.energy == 0 && game.commander.kills == 0 && game.commander.credits == 1000
      )
    }
    #expect(OrdnanceProfile.plasma.energyCost == 12 && OrdnanceProfile.plasma.heat == 8)
    #expect(OrdnanceProfile.plasma.firingInterval == 1 && OrdnanceProfile.plasma.damage == 40)
  }

  @Test func constantWorldFlightIsIndependentOfCameraAndTickPartition() throws {
    var one = ordnanceGame()
    var split = ordnanceGame()
    var stateOne = try ordnanceShot(&one, profile: .plasma, launcherVelocity: .init(25, 0, 20))
    var stateSplit = try ordnanceShot(&split, profile: .plasma, launcherVelocity: .init(25, 0, 20))
    _ = try ordnanceAdvance(&one, state: &stateOne, time: 1)
    for time in [0.1, 0.23, 0.6, 0.9, 1.0] {
      split.commander.flightSimulation.pose.position = .init(1000 * time, 100 * time, -3000)
      split.commander.flightSimulation.pose.orientation.rotate(pitch: 0.05, roll: 0.08, yaw: -0.04)
      _ = try ordnanceAdvance(&split, state: &stateSplit, time: time)
      stateSplit = try JSONDecoder().decode(
        OrdnanceState.self, from: JSONEncoder().encode(stateSplit))
    }
    #expect((stateOne.position - stateSplit.position).length < 1e-8)
    #expect(abs(stateOne.propulsionTravel - stateSplit.propulsionTravel) < 1e-8)
    let rendered = try ordnanceRequire(split.bodies.last?.position)
    #expect(
      (split.commander.flightSimulation.pose.systemPoint(rendered) - stateSplit.position).length
        < 1e-8)
  }

  @Test func alienSeekerTurnsAtMostThreeRadiansPerSecondIncludingAntipodalTargets() throws {
    for targetPosition in [Vector3(10000, 0, 0), .init(0, 0, -10000)] {
      var game = ordnanceGame()
      let target = try ordnanceActor(&game, position: targetPosition)
      var state = try ordnanceShot(&game, profile: .alienSeeker, target: target)
      _ = try ordnanceAdvance(&game, state: &state, time: 0.1)
      let turn = acos(max(-1, min(1, state.direction.dot(.init(0, 0, 1)))))
      #expect(abs(turn - 0.3) < 1e-8 && state.valid && state.direction.finite)
      #expect(abs(state.propulsionTravel - 99) < 1e-8 && state.termination == nil)
    }
  }

  @Test func alienSeekerSurvivesOneUniqueECMActivationAcrossTicksAndPersistence() throws {
    var game = ordnanceGame()
    let target = try ordnanceActor(&game)
    var state = try ordnanceShot(&game, profile: .alienSeeker, target: target)
    let emitter = try ordnanceRequire(game.commander.flightSimulation.player)
    let firstPulse = ECMActivationIdentity(emitter: emitter, sequence: 1)
    let first = try ordnanceAdvance(
      &game, state: &state, time: 0, pulses: [firstPulse, firstPulse])
    #expect(first.resistedECM && !first.endedNow && state.termination == nil)
    state = try JSONDecoder().decode(OrdnanceState.self, from: JSONEncoder().encode(state))
    for time in [0.1, 0.2] {
      let repeated = try ordnanceAdvance(&game, state: &state, time: time, pulses: [firstPulse])
      #expect(!repeated.resistedECM && !repeated.endedNow && state.termination == nil)
    }
    let secondPulse = ECMActivationIdentity(emitter: emitter, sequence: 2)
    let destroyed = try ordnanceAdvance(&game, state: &state, time: 0.3, pulses: [secondPulse])
    #expect(destroyed.termination == .ecm && destroyed.endedNow && !destroyed.resistedECM)
    let duplicate = try ordnanceAdvance(&game, state: &state, time: 0.4, pulses: [secondPulse])
    #expect(!duplicate.endedNow && game.commander.kills == 0 && game.commander.credits == 1000)
  }

  @Test func simultaneousDistinctEmittersAreUniqueAndPulseOrderIsDeterministic() throws {
    for reversed in [false, true] {
      var game = ordnanceGame()
      let target = try ordnanceActor(&game)
      let player = try ordnanceRequire(game.commander.flightSimulation.player)
      var state = try ordnanceShot(&game, profile: .alienSeeker, target: target)
      let pulses = [
        ECMActivationIdentity(emitter: player, sequence: 1), .init(emitter: target, sequence: 1),
      ]
      let update = try ordnanceAdvance(
        &game, state: &state, time: 0, pulses: reversed ? Array(pulses.reversed()) : pulses)
      #expect(update.termination == .ecm && update.resistedECM && update.endedNow)
      #expect(state.resistedECM == pulses[0])
    }
  }

  @Test(arguments: [OrdnanceProfile.standardMissile, .plasma])
  func standardMissileIsECMVulnerableWhilePlasmaIsImmune(_ profile: OrdnanceProfile) throws {
    var game = ordnanceGame()
    let target = try ordnanceActor(&game)
    var state = try ordnanceShot(&game, profile: profile, target: target)
    let pulse = ECMActivationIdentity(
      emitter: try ordnanceRequire(game.commander.flightSimulation.player), sequence: 1)
    let update = try ordnanceAdvance(&game, state: &state, time: 0.1, pulses: [pulse])
    #expect((update.termination == .ecm) == (profile == .standardMissile))
    #expect((game.bodies.last?.energy == 0) == (profile == .standardMissile))
    #expect(game.commander.kills == 0 && state.resistedECM == nil)
  }

  @Test func missileRetainsOriginalNPCOwnerAfterEmitterDisappearsAndHitsPlayerShields() throws {
    var game = ordnanceGame()
    let shooter = try ordnanceActor(
      &game, id: 11, position: .init(0, 0, 1000), legal: .init(value: 64, bountyTenths: 1000))
    let player = try ordnanceRequire(game.commander.flightSimulation.player)
    var state = try ordnanceShot(
      &game, target: player, owner: shooter, position: .init(0, 0, -2000),
      direction: .init(0, 0, -1))
    game.bodies.removeFirst()
    let impact = try ordnanceAdvance(&game, state: &state, time: 2)
    #expect(impact.hit?.target == .player && impact.incident?.origin.owner == shooter)
    #expect(impact.incident?.origin.ordnance == state.origin.ordnance)
    #expect(impact.incident?.origin.ownerLegalAtEmission.value == 64)
    #expect(game.frontShield == 5 && game.energy == 256 && game.commander.kills == 0)
  }

  @Test func muzzleProtectionEndsBeforeALaterPathCrossesTheEmitter() throws {
    var game = ordnanceGame()
    let target = try ordnanceActor(&game, position: .init(0, 0, 1000))
    var state = try ordnanceShot(&game, target: target)
    _ = try ordnanceAdvance(&game, state: &state, time: 0.2)
    #expect(state.muzzleCleared && state.termination == nil && game.frontShield == 255)
    game.bodies[0].position = .init(0, 0, -1000)
    let returned = try ordnanceAdvance(&game, state: &state, time: 0.5)
    #expect(returned.hit?.target == .player && returned.termination == .impact)
    #expect(game.frontShield == 5 && game.commander.legal == 0)
  }

  @Test func lostTargetsCullAndInterceptionHaveSeparateTerminalReasonsAndNoShipCredit() throws {
    for reason in [OrdnanceEnd.targetLost, .culled, .destroyed] {
      var game = ordnanceGame()
      let target = try ordnanceActor(&game)
      var state = try ordnanceShot(&game, target: target)
      switch reason {
      case .targetLost: game.bodies[0].energy = 0
      case .culled: game.bodies.removeLast()
      default:
        let player = try ordnanceRequire(game.commander.flightSimulation.player)
        let origin = try ordnanceRequire(game.makeAttackOrigin(owner: player))
        game.applyCombatHit(
          .init(target: .body(20), distance: 0, point: .init(0, 0, 0)), origin: origin,
          kind: .laser, damage: 15)
      }
      let ended = try ordnanceAdvance(&game, state: &state, time: 0.1)
      #expect(ended.termination == reason && ended.endedNow)
      #expect(
        game.commander.kills == 0 && game.commander.credits == 1000 && game.commander.legal == 0)
    }
  }

  @Test func missingBodyIdentityCannotKillARecycledBodyAndMalformedStateIsRejected() throws {
    var game = ordnanceGame()
    let target = try ordnanceActor(&game)
    var state = try ordnanceShot(&game, target: target)
    game.bodies.removeLast()
    try ordnanceActor(&game, id: 20)
    let missing = try ordnanceAdvance(&game, state: &state, time: 0.1)
    #expect(missing.termination == .culled && game.bodies.last?.energy == 100)
    #expect(
      OrdnanceState(
        profile: .plasma, origin: state.origin, position: .init(0, 0, 0), direction: .init(0, 0, 0))
        == nil)
    let subnormal = OrdnanceState(
      profile: .plasma, origin: state.origin, position: .init(0, 0, 0),
      direction: .init(Double.leastNonzeroMagnitude, 0, 0))
    #expect(subnormal?.valid == true && subnormal?.direction == .init(1, 0, 0))
    let context = try ordnanceRequire(game.gameplayContext())
    var invalid = try ordnanceRequire(subnormal)
    let future =
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(invalid)) as? [String: Any]
    var corrupt = try ordnanceRequire(future)
    corrupt["propulsionTravel"] = -1
    invalid = try JSONDecoder().decode(
      OrdnanceState.self, from: JSONSerialization.data(withJSONObject: corrupt))
    let rejected = game.advanceOrdnance(bodyID: 20, state: &invalid, context: context)
    #expect(rejected.termination == .invalidState && game.bodies.last?.energy == 100)
  }
}
