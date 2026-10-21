import Foundation

extension Game {
  /// The profiled flight pass is the sole motion owner. Its current view velocity supplies
  /// native snapshots and wreck motion without translating the body a second time.
  mutating func synchronizeScriptNPCPhysicalVelocities() {
    for index in bodies.indices {
      guard let velocity = bodies[index].scriptNPC?.velocity else { continue }
      let worldVelocity = commander.flightSimulation.pose.orientation.apply(velocity)
      bodies[index].physical?.velocity = worldVelocity
    }
  }

  /// Mission actor and shot velocities are view-relative. Change their basis once;
  /// their respective flight/shot passes remain the sole translation integrations.
  mutating func rotateScriptNPCVelocities(from before: ShipPose, to after: ShipPose) {
    for index in bodies.indices {
      if let velocity = bodies[index].scriptNPC?.velocity {
        bodies[index].scriptNPC?.velocity = after.shipVector(before.orientation.apply(velocity))
      }
      if let velocity = bodies[index].scriptShot?.velocity {
        bodies[index].scriptShot?.velocity = after.shipVector(before.orientation.apply(velocity))
      }
    }
  }

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
