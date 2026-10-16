import Foundation

extension Game {
  /// Project retained station facts through the one actual native camera pose.
  /// Guided work motion and manual flight use the same transform; no second pose
  /// integration or guessed speed/pitch displacement advances the mission frame.
  mutating func advanceNativeMissionFrame(from before: ShipPose, to after: ShipPose, delta: Double)
  {
    guard !bodies.contains(where: { $0.id == 0 && $0.hull == .station }),
      var frame = scriptReferenceFrame, frame.galaxy == commander.galaxy,
      frame.system == commander.system
    else { return }
    frame.station.position = after.shipPoint(before.systemPoint(frame.station.position))
    var orientation = Basis3()
    orientation.x = after.shipVector(before.orientation.apply(frame.station.orientation.x))
    orientation.y = after.shipVector(before.orientation.apply(frame.station.orientation.y))
    orientation.z = after.shipVector(before.orientation.apply(frame.station.orientation.z))
    frame.station.orientation = orientation
    frame.station.rotation += frame.station.rotationRate * delta
    scriptReferenceFrame = frame
  }
}
