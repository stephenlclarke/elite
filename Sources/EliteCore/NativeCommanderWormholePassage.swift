import Foundation

struct NativeCommanderWormholeReceipt: Codable, Sendable, Equatable {
  let opening: UUID
  let source: ActorIdentity
  let arrival: ActorIdentity
  let calendarOperation: UInt64
  let seconds: Double
  let fuelBefore: Int
  let fuelAfter: Int
}

/// Native current-scene authority, created only after an attained physical player crossing.
struct NativeCommanderWormholePassage {
  let opening: NativeWormholeOpening
  let player: ActorIdentity
  let fuelBefore: Int
  let fuelDebit: Int
  private let pose: ShipPose
  private let revision: UInt64
  private let epoch: UUID
  private init(opening: NativeWormholeOpening, player: ActorIdentity,
    fuelBefore: Int, fuelDebit: Int, pose: ShipPose, revision: UInt64, epoch: UUID)
  {
    self.opening = opening
    self.player = player
    self.fuelBefore = fuelBefore
    self.fuelDebit = fuelDebit
    self.pose = pose
    self.revision = revision
    self.epoch = epoch
  }
  func matches(_ game: borrowing Game) -> Bool {
    !game.docked && game.jumpCountdown == nil && !game.playerEMPDisabled
      && game.commander.flightSimulation.player == player
      && game.commander.flightSimulation.pose == pose && game.gameplayRevision == revision
      && game.nativeStationRuntimeEpoch == epoch && game.commander.fuel == fuelBefore
      && game.commander.scriptState.wormholeTransit?.commanderPassages[opening.id] == nil
      && game.commander.scriptState.wormholeTransit?.legs[opening.leg]?.opening == opening
      && opening.route.origin.location == game.systemIdentity
      && game.commander.scriptState.calendarSeconds <= opening.expiresAt
  }
  static func prepare(in game: borrowing Game, opening: NativeWormholeOpening,
    sample: NativeWormholeMotionSample, context: OriginalWorldJourneyContext) throws -> Self
  {
    guard opening.valid, context.route == opening.route,
      context.matches(game, at: game.systemIdentity), game.systemIdentity == opening.route.origin.location,
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
    let radius = try PreparedHull(mesh: game.commander.playerMesh).radius
    guard NativeWormholeSweep.crosses(opening: opening, from: sample.pose.position,
      to: game.commander.flightSimulation.pose.position, hullRadius: radius)
    else { throw NativeWormholeRefusal.wrongWake }
    let debit = game.commander.jumpFuelCost(distance: opening.route.distanceLightYears)
    try game.proveNativeWormholeMotion(from: sample.pose.position,
      to: game.commander.flightSimulation.pose.position, radius: radius,
      excluding: player, sample: sample, includePlayer: false)
    guard debit > 0, game.commander.fuel >= debit, !game.commander.unlimitedFuel else {
      throw NativeWormholeRefusal.insufficientFuel
    }
    return .init(opening: opening, player: player, fuelBefore: game.commander.fuel,
      fuelDebit: debit, pose: game.commander.flightSimulation.pose,
      revision: game.gameplayRevision, epoch: game.nativeStationRuntimeEpoch)
  }
}
