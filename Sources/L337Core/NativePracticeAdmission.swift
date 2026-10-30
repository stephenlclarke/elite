import Foundation

enum NativePracticeAdmission {
  /// Conservative full-geometry boxes enclose every real hull, including station appendages.
  /// Missing/invalid geometry refuses the volume rather than treating unobserved space as clear.
  static func volumeClear(
    _ practice: NativePracticeState, context: EncounterContext, bodies: [SpaceBody],
    meshes: [Int: Mesh], pose: ShipPose, playerRadius: Double
  ) -> Bool {
    let volume = practice.permission.volume
    guard practice.valid, practice.endedAt == nil,
      context.player.identity == practice.permission.player,
      context.system == practice.permission.player.system,
      context.visit == practice.permission.player.visit,
      context.physicalTime >= practice.permission.begunAt,
      playerRadius.isFinite, playerRadius > 0,
      (volume.position - context.player.position).length > volume.radius + playerRadius + 64,
      (volume.position - context.anchors.planet.position).length
        > volume.radius + context.anchors.planet.radius,
      (volume.position - context.anchors.sun.position).length
        > volume.radius + context.anchors.sun.radius * 4,
      Set(bodies.map(\.id)).count == bodies.count,
      Set(context.actors.map(\.identity)).count == context.actors.count
    else { return false }
    for actor in context.actors where actor.energy > 0 {
      let matching = bodies.filter { $0.physical?.identity == actor.identity }
      guard matching.count == 1, let body = matching.first else { return false }
      if practice.beacon(for: body, pose: pose) != nil { continue }
      guard let mesh = meshes[body.id], !mesh.vertices.isEmpty, !mesh.faces.isEmpty,
        body.position.finite, body.orientation.validRotation, body.rotation.isFinite,
        mesh.vertices.allSatisfy(\.finite),
        mesh.faces.allSatisfy({ $0.count >= 3 && $0.allSatisfy(mesh.vertices.indices.contains) })
      else { return false }
      let points = mesh.vertices.map { pose.systemPoint(body.position + body.modelVector($0)) }
      guard points.allSatisfy(\.finite),
        let x = points.map(\.x).min(), let maxX = points.map(\.x).max(),
        let y = points.map(\.y).min(), let maxY = points.map(\.y).max(),
        let z = points.map(\.z).min(), let maxZ = points.map(\.z).max()
      else { return false }
      let nearest = Vector3(
        max(x, min(maxX, volume.position.x)), max(y, min(maxY, volume.position.y)),
        max(z, min(maxZ, volume.position.z)))
      let clearance = (volume.position - nearest).length - volume.radius
      let numerical = 1e-8 * max(1, volume.position.length + nearest.length + volume.radius)
      guard clearance.isFinite, numerical.isFinite, clearance > 64 + numerical else { return false }
    }
    // An unadopted live body is not evidence of vacant space.
    return bodies.allSatisfy { body in
      body.energy <= 0 || context.actors.contains { $0.identity == body.physical?.identity }
    }
  }
}
