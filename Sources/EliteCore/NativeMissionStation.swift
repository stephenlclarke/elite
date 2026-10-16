import Foundation

extension Game {
  /// Called only after the adapter has completed every retained-source hard preflight.
  /// A living out-of-bubble station may reappear; its old physical addresses are never reused.
  @discardableResult
  mutating func restoreNativeMissionStationIfEligible() -> Bool {
    let flight = commander.flightSimulation
    guard !docked, !commander.scriptState.instances.isEmpty,
      !bodies.contains(where: { $0.id == 0 }),
      flight.valid, flight.system == systemIdentity,
      let anchors = flight.anchors, anchors.system == systemIdentity,
      anchors.station.identity.system == systemIdentity,
      anchors.station.identity.visit == flight.visit,
      anchors.station.identity.entity == 1, anchors.station.identity.entity < flight.nextActor,
      !bodies.contains(where: { $0.physical?.identity == anchors.station.identity }),
      let frame = scriptReferenceFrame, frame.valid,
      frame.galaxy == commander.galaxy, frame.system == commander.system,
      frame.station.energy > 0, !frame.station.leavesLocalBubble,
      (flight.pose.systemPoint(frame.station.position) - anchors.station.position).length < 1e-5,
      let context = gameplayContext(), context.budget.total < context.budget.maximum,
      bodies.reduce(0, { $0 + $1.scriptNativeUnits }) < 1024
    else { return false }
    var station = SpaceBody(id: 0, hull: .station, position: frame.station.position)
    station.orientation = frame.station.orientation
    station.rotation = frame.station.rotation
    station.rotationRate = frame.station.rotationRate
    station.energy = frame.station.energy
    station.physical = nativePhysicalActorState(for: station, identity: anchors.station.identity)
    bodies.append(station)
    return true
  }
}
