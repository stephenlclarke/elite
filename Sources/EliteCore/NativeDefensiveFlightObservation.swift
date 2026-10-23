import Foundation

/// A live observation capability. It is never decoded, and only this native producer can mint it.
struct NativeDefensiveFlightObservation: Sendable {
  let sample: NativeDefensiveFlightSample
  fileprivate init(_ sample: NativeDefensiveFlightSample) { self.sample = sample }
}

extension Game {
  func defensiveFlightObservation() -> NativeDefensiveFlightObservation? {
    defensiveFlightSample().map(NativeDefensiveFlightObservation.init)
  }

  /// Read-only native producer. Its before/after values are consumed only on the actual tick.
  /// This never changes target selection, steering, equipment, traffic or attack authority.
  func defensiveFlightSample() -> NativeDefensiveFlightSample? {
    guard !paused, !docked, !isMissionTrial, screen.isFlight,
      let active = activeDefensiveFlight, !active.state.workVerified, active.state.failure == nil,
      active.state.permission.owner == commander.equipmentOwnerID,
      active.state.permission.carrier == commander.hullInstanceID,
      active.instance.suspension == nil, let provider = active.instance.savedNativePractice,
      nativePracticeCurrent(provider, instance: active.instance), active.state.matches(provider),
      let radius = active.state.hullRadius,
      let actualRadius = commander.playerMesh.vertices.map(\.length).max(),
      abs(actualRadius - radius) <= 1e-8,
      let player = commander.flightSimulation.player,
      let reading = NativeDefensiveFlightGeometry.reading(
        practice: provider, player: player, pose: commander.flightSimulation.pose,
        worldVelocity: flightWorldVelocity, time: commander.flightSimulation.physicalTime),
      provider.beacons.allSatisfy({ beacon in
        bodies.filter({ $0.physical?.identity == beacon.actor }).count == 1
          && bodies.contains(where: {
            provider.beacon(for: $0, pose: commander.flightSimulation.pose) == beacon
          })
      })
    else { return nil }
    let manual =
      autoPilot.targetID == nil && !dockingComputer && workGuidance == nil
      && workBraking == nil && !playerEMPDisabled && jumpCountdown == nil
      && pendingNativeStationDock == nil && energy.isFinite && energy > 0
    let pose = commander.flightSimulation.pose
    let toCentre = pose.shipVector(provider.permission.position(1) - pose.position)
    var centreContact: ActorIdentity?
    if screen == .front, toCentre.length > 1e-9,
      let hit = try? nearestMissionCollision(
        from: .init(0, 0, 0), direction: toCentre.unit, range: toCentre.length + 6,
        radius: 0, includePlayer: false),
      let body = hit.selectedTargetBody,
      provider.beacon(for: body, pose: pose)?.ordinal == 1
    {
      centreContact = body.physical?.identity
    }
    return .init(
      reading: reading, manual: manual,
      clear: defensiveFlightCourseIsClear(provider, radius: radius),
      centreContact: centreContact)
  }
}
