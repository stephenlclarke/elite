import Foundation

private final class NativeCrewLogProgressAttempt {
  var game: Game
  init(_ game: borrowing Game) { self.game = copy game }
}

extension Game {
  /// Register once, then observe actual owned admissions/deaths. No movement or rescue is inferred.
  mutating func advanceInductionCrewLog(publish: ScriptPublisher?) {
    guard let publish, !paused, !docked, !isMissionTrial, screen.isFlight,
      systemIdentity == NativeInductionCrewLogSource.location,
      let parent = wayfarerInductionMission, parent.outcome == .active,
      parent.suspension == nil, parent.savedWayfarerInduction?.seedReception != nil,
      nativeInductionCrewLogPack != nil
    else { return }
    let attempt = NativeCrewLogProgressAttempt(self)
    do {
      let changed = try attempt.game.prepareInductionCrewLogProgress()
      guard changed else { return }
      attempt.game.persistScriptActors()
      guard attempt.game.commander.valid else { throw SaveError.invalidCommander }
      try publish(&attempt.game)
      self = attempt.game
    } catch { return }
  }

  private mutating func prepareInductionCrewLogProgress() throws -> Bool {
    guard var parent = wayfarerInductionMission, let leaf = parent.savedWayfarerInduction,
      let pack = nativeInductionCrewLogPack
    else { return false }
    let source = try NativeInductionCrewLogSource(parent: leaf)
    let job = NativeInductionCrewLogPack.instance(recorder: source.manifest.recorder)
    guard var child = commander.scriptState.instances[job] else {
      guard NativeInductionArkSave.validateClaims(commander),
        commander.scriptState.instances.count < 128,
        parent.revision < UInt64(Int64.max) - 1,
        commander.scriptState.nextEvent < UInt64(Int64.max) - 2,
        let context = gameplayContext(), context.system == NativeInductionCrewLogSource.location,
        context.visit == commander.flightSimulation.visit,
        let station = bodies.first(where: { $0.id == 0 && $0.hull == .station }),
        station.energy > 0, station.nativeStationIdentity == nil,
        station.physical?.identity == context.anchors.station.identity,
        commander.nativeStations?.mainStations.contains(where: {
          $0.world == source.manifest.owner && $0.system == context.system
        }) == true
      else { return false }
      for role in NativeInductionCrewLogRole.allCases {
        _ = try source.initialPose(for: role, reference: context.anchors.station)
      }
      let sequence = commander.scriptState.nextEvent + 1
      let authorization = try NativeCrewLogAuthorization(
        parent: leaf, stationActor: context.anchors.station.identity,
        physicalTime: context.physicalTime, flightSeconds: commander.scriptState.flightSeconds,
        sequence: sequence)
      var issued = ScriptInstance(
        id: job, definition: NativeInductionCrewLogPack.stateID,
        version: NativeInductionCrewLogPack.version, digest: pack.digest)
      issued.savedNativeCrewLog = .init(authorization: authorization)
      issued.acknowledge(sequence)
      parent.acknowledge(sequence)
      parent.revision += 1
      parent.journal.append(
        "Cevilis's custodian source is registered once: one empty mechanically disabled Burro tender, a separate marked Burro launch holding its two original crew, and their original one-tonne custody recorder. Recover only the recorder; no hull, equipment or player cabin transfer is authorized."
      )
      commander.scriptState.nextEvent = sequence
      commander.scriptState.instances[parent.id] = parent
      commander.scriptState.instances[job] = issued
      emitScriptEvent("mission.accepted", only: job)
      notify("CEVILIS CUSTODY SOURCE - ORIGINAL RECORDER / MARKED LAUNCH")
      return true
    }
    guard let previous = child.savedNativeCrewLog, child.suspension == nil,
      child.revision < UInt64(Int64.max) - 1,
      let group = child.ownedEncounters[NativeInductionCrewLogPack.encounter], group.admitted
    else { return false }
    var next = previous
    if next.admission == nil {
      func native(_ role: NativeInductionCrewLogRole) -> ActorIdentity? {
        let logical = NativeInductionCrewLogPack.actor(job: job, role: role)
        guard let retained = group.actors[role.rawValue], retained.identity == logical else {
          return nil
        }
        return retained.body.physical?.identity
      }
      guard let tender = native(.tender), let launch = native(.launch),
        let recorder = native(.recorder)
      else { return false }
      next.admission = .init(
        tender: tender, launch: launch, recorder: recorder,
        physicalTime: commander.flightSimulation.physicalTime)
    }
    for role in NativeInductionCrewLogRole.allCases
    where !next.losses.contains(where: { $0.role == role.rawValue }) {
      guard let retained = group.actors[role.rawValue], retained.presence == .destroyed,
        retained.body.energy == 0, let actor = retained.body.physical?.identity
      else { continue }
      next.losses.append(
        .init(
          role: role.rawValue, actor: actor, physicalTime: commander.flightSimulation.physicalTime))
    }
    guard next != previous else { return false }
    guard next.shapeValid(parent: leaf) else { throw SaveError.invalidCommander }
    child.savedNativeCrewLog = next
    child.revision += 1
    commander.scriptState.instances[job] = child
    return true
  }
}
