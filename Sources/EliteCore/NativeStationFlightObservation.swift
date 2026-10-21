import Foundation

/// Read-only diagnostic values from the same live bodies, mesh and sweep as native flight.
/// A conservative failed clearance proof is not an exact penetration-depth measurement.
public struct NativeStationFlightObservation: Codable, Sendable {
  public let bodyID: Int
  public let definition: String
  public let sourceVersion: String
  public let sourceKey: String
  public let actor: ActorIdentity
  public let world: UUID
  public let renderedPose: ShipPose
  public let canonicalPose: ShipPose
  public let viewPosition: Vector3
  public let meshVertices: Int
  public let meshFaces: Int
  public let meshMinimum: Vector3
  public let meshMaximum: Vector3
  public let meshRadius: Double
  public let playerRadius: Double
  public let centerRange: Double
  public let rigidPoseConsistent: Bool
  public let sweepClear: Bool?
}

extension Game {
  public func nativeStationFlightObservations(from before: ShipPose?, delta: Double?)
    -> [NativeStationFlightObservation]
  {
    guard let world = commander.nativeStations else { return [] }
    let flight = commander.flightSimulation
    let player = commander.playerMesh
    let playerRadius = player.vertices.map(\.length).max() ?? .infinity
    return bodies.compactMap { body in
      guard let identity = body.nativeStationIdentity, let actor = body.physical?.identity,
        nativeStationBodyIsCurrent(body), let saved = world.pose(for: identity),
        let source = NativeStationSource.binding(for: identity),
        let end = saved.orientation(at: flight.physicalTime),
        let currentPosition = world.currentPosition(for: .rrs(identity), at: flight.physicalTime)
      else { return nil }
      let geometry = source.geometry
      let radius = geometry.mesh.vertices.map(\.length).max() ?? .infinity
      let distance = (currentPosition - flight.pose.position).length
      let clear: Bool?
      if let before, let delta, delta.isFinite, delta > 0, delta <= 0.1,
        let start = saved.orientation(at: max(0, flight.physicalTime - delta)),
        let oldPosition = world.currentPosition(
          for: .rrs(identity), at: max(0, flight.physicalTime - delta))
      {
        let displacement =
          (flight.pose.position - before.position).length
          + (currentPosition - oldPosition).length
        if distance > radius + playerRadius + displacement {
          clear = true
        } else {
          let angle = (abs(pitch) + abs(roll) + abs(yaw) + source.rotationRate) * delta
          let margin =
            (radius + playerRadius + displacement) * angle
            + world.stationSweepMargin(
              .rrs(identity), from: max(0, flight.physicalTime - delta),
              to: flight.physicalTime)
          clear = nativeStationHullSweepClear(
            player, from: before, to: flight.pose, saved: saved,
            fromOrientation: start, toOrientation: end, margin: margin, mesh: geometry.mesh,
            fromPosition: oldPosition, toPosition: currentPosition)
        }
      } else {
        clear = nil
      }
      return .init(
        bodyID: body.id, definition: identity.definition, sourceVersion: identity.version,
        sourceKey: identity.key, actor: actor, world: identity.world,
        renderedPose: modelPose(of: body),
        canonicalPose: .init(position: currentPosition, orientation: end),
        viewPosition: viewPosition(body.position),
        meshVertices: geometry.mesh.vertices.count, meshFaces: geometry.mesh.faces.count,
        meshMinimum: geometry.bounds.minimum, meshMaximum: geometry.bounds.maximum,
        meshRadius: radius, playerRadius: playerRadius, centerRange: distance,
        rigidPoseConsistent: world.bodyRigidPoseIsConsistent(body, flight: flight),
        sweepClear: clear)
    }
  }
}
