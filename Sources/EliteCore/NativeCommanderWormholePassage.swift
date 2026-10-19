import Foundation

struct NativeCommanderWormholeReceipt: Codable, Sendable, Equatable {
  let opening: UUID
  let source: ActorIdentity
  let arrival: ActorIdentity
  let calendarOperation: UInt64
  let seconds: Double
  let fuelBefore: Int
  let fuelAfter: Int
  let fuelDebit: Int
}

/// Native current-scene authority, created only after an attained physical player crossing.
struct NativeCommanderWormholePassage {
  let opening: NativeWormholeOpening
  let player: ActorIdentity
  let fuelBefore: Int
  let fuelDebit: Int
  // These private proof fields also keep the synthesized memberwise initializer private.
  private let pose: ShipPose
  private let revision: UInt64
  private let epoch: UUID
  func matches(_ game: borrowing Game) -> Bool {
    guard !game.docked, game.jumpCountdown == nil, !game.playerEMPDisabled,
      game.commander.flightSimulation.player == player,
      game.commander.flightSimulation.pose == pose, game.gameplayRevision == revision,
      game.nativeStationRuntimeEpoch == epoch, game.commander.fuel == fuelBefore,
      game.commander.scriptState.wormholeTransit?.commanderPassages[opening.id] == nil,
      game.commander.scriptState.wormholeTransit?.legs[opening.leg]?.opening == opening,
      opening.route.origin.location == game.systemIdentity,
      game.commander.scriptState.calendarSeconds <= opening.expiresAt
    else { return false }
    return true
  }
  static func prepare(
    in game: borrowing Game, opening: NativeWormholeOpening,
    sample: NativeWormholeMotionSample, context: OriginalWorldJourneyContext,
    cohort: NativeWormholeAttainedCohort
  ) throws -> Self {
    guard opening.valid, context.route == opening.route,
      game.commander.scriptState.wormholeTransit?.legs[opening.leg]?.opening == opening,
      context.matches(game, at: game.systemIdentity),
      game.systemIdentity == opening.route.origin.location,
      sample.system == game.systemIdentity, sample.visit == game.commander.flightSimulation.visit,
      !game.docked, game.screen != .gameOver, !game.paused, !game.playerEMPDisabled,
      game.jumpCountdown == nil, let player = game.commander.flightSimulation.player,
      game.commander.fittedComponent(at: .drive) != nil,
      game.commander.hyperspaceDrivePolicy != nil, !game.hyperspaceMassLocked,
      game.commander.maximumJumpDistance >= opening.route.distanceLightYears,
      game.commander.scriptState.calendarSeconds >= opening.openedAt,
      game.commander.scriptState.calendarSeconds <= opening.expiresAt,
      game.commander.scriptState.wormholeTransit?.commanderPassages[opening.id] == nil
    else { throw NativeWormholeRefusal.wrongWake }
    let radius = try NativeWormholeSweep.radius(game.commander.playerMesh)
    guard
      NativeWormholeSweep.crosses(
        opening: opening, from: sample.pose.position,
        to: game.commander.flightSimulation.pose.position, hullRadius: radius)
    else { throw NativeWormholeRefusal.wrongWake }
    let debit = game.commander.jumpFuelCost(distance: opening.route.distanceLightYears)
    try cohort.provePlayer(radius: radius, in: game)
    guard debit > 0, game.commander.fuel >= debit, !game.commander.unlimitedFuel else {
      throw NativeWormholeRefusal.insufficientFuel
    }
    return .init(
      opening: opening, player: player, fuelBefore: game.commander.fuel,
      fuelDebit: debit, pose: game.commander.flightSimulation.pose,
      revision: game.gameplayRevision, epoch: game.nativeStationRuntimeEpoch)
  }
}
