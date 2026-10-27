import Foundation

/// One physical frame's actual complete endpoints. Only successfully published, matching
/// departures may be absent from the live scene. Never serialized, returned as a receipt or reused.
final class NativeWormholeAttainedCohort {
  private var attained: Game
  private let sample: NativeWormholeMotionSample
  private var publishedDepartures: Set<ActorIdentity> = []

  private init(_ game: borrowing Game, sample: NativeWormholeMotionSample) {
    attained = copy game
    self.sample = sample
  }

  static func capture(in game: borrowing Game, sample: NativeWormholeMotionSample?) -> Self? {
    guard let sample, !game.docked, !game.paused, game.screen != .gameOver,
      sample.system == game.systemIdentity, sample.visit == game.commander.flightSimulation.visit
    else { return nil }
    let duration = game.commander.flightSimulation.physicalTime - sample.physicalTime
    guard duration > 0 && duration <= 0.100001 else { return nil }
    return Self(game, sample: sample)
  }

  private func matches(_ game: borrowing Game, removing: Set<ActorIdentity>) -> Bool {
    guard game.commander.flightSimulation == attained.commander.flightSimulation,
      game.gameplayRevision == attained.gameplayRevision,
      game.nativeStationRuntimeEpoch == attained.nativeStationRuntimeEpoch,
      game.commander.equipmentOwnerID == attained.commander.equipmentOwnerID,
      game.commander.scriptState.calendarSeconds == attained.commander.scriptState.calendarSeconds,
      game.commander.scriptState.geometry == attained.commander.scriptState.geometry,
      game.celestials == attained.celestials,
      game.commander.playerMesh.vertices == attained.commander.playerMesh.vertices,
      game.commander.playerMesh.faces == attained.commander.playerMesh.faces
    else { return false }
    let expected = attained.bodies.filter { body in
      !(body.physical.map { removing.contains($0.identity) } ?? false)
    }
    return game.bodies == expected
  }

  func proveNPC(_ source: NativeNPCDriveSource, in game: borrowing Game) throws {
    guard matches(game, removing: publishedDepartures),
      let before = sample.bodies.first(where: { $0.physical?.identity == source.actor })
    else { throw NativeWormholeRefusal.stale }
    try attained.proveNativeTransitSweep(source: source, before: before, sample: sample)
  }

  func provePlayer(radius: Double, in game: borrowing Game) throws {
    guard matches(game, removing: publishedDepartures) else { throw NativeWormholeRefusal.stale }
    try attained.proveNativeWormholeMotion(
      from: sample.pose.position,
      to: attained.commander.flightSimulation.pose.position, radius: radius,
      excluding: attained.commander.flightSimulation.player, sample: sample, includePlayer: false)
  }

  /// Publication is the only removal witness. A refused writer or an unrelated missing body
  /// cannot expand the set of permissible differences from the attained scene.
  func didPublishDeparture(_ legID: UUID, in game: borrowing Game) {
    guard let leg = game.commander.scriptState.wormholeTransit?.legs[legID],
      let departure = leg.departure, leg.phase == .inTransit,
      departure.physicalTime == attained.commander.flightSimulation.physicalTime,
      departure.calendarSeconds == attained.commander.scriptState.calendarSeconds,
      let original = attained.commander.scriptState.wormholeTransit?.legs[legID],
      original.departure == nil, original.opening?.id == departure.hole,
      attained.bodies.contains(where: {
        $0.missionActorID == original.actor && $0.physical?.identity == departure.nativeActor
      })
    else { return }
    var removing = publishedDepartures
    removing.insert(departure.nativeActor)
    guard matches(game, removing: removing) else { return }
    publishedDepartures = removing
  }
}
