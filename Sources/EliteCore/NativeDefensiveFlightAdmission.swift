import Foundation

enum NativeDefensiveFlightAdmission {
  /// Full transformed mesh boxes conservatively enclose ordinary actors. The exit prism and
  /// original sphere are inflated by the measured player radius plus the authored 64 m margin.
  static func clear(
    practice: NativePracticeState, pose: ShipPose, context: EncounterContext,
    bodies: [SpaceBody], meshes: [Int: Mesh], radius: Double
  ) -> Bool {
    guard practice.valid, practice.permission.lesson == .defensiveFlight,
      context.player.identity == practice.permission.player,
      context.system == practice.permission.player.system,
      context.visit == practice.permission.player.visit,
      NativeDefensiveFlightGeometry.hullFits(radius: radius),
      Set(bodies.map(\.id)).count == bodies.count,
      Set(context.actors.map(\.identity)).count == context.actors.count
    else { return false }
    let margin = radius + 64
    let frame = practice.permission.frame
    let centre = practice.permission.position(1)
    func local(_ point: Vector3) -> Vector3 { frame.shipVector(point - centre) }
    func nearest(_ p: Vector3, low: Vector3, high: Vector3) -> Vector3 {
      .init(
        max(low.x, min(high.x, p.x)), max(low.y, min(high.y, p.y)), max(low.z, min(high.z, p.z)))
    }
    let low = Vector3(-250 - margin, -150 - margin, -1450 - margin)
    let high = Vector3(250 + margin, 150 + margin, -450 + margin)
    for anchor in [(context.anchors.planet, 1.0), (context.anchors.sun, 4.0)] {
      let point = local(anchor.0.position)
      let size = anchor.0.radius * anchor.1
      guard point.finite, size.isFinite, size > 0,
        point.length > NativePracticeSource.volumeRadius + margin + size,
        (point - nearest(point, low: low, high: high)).length > size
      else { return false }
    }
    for actor in context.actors where actor.energy > 0 {
      let matches = bodies.filter { $0.physical?.identity == actor.identity }
      guard matches.count == 1, let body = matches.first else { return false }
      if practice.beacon(for: body, pose: pose) != nil { continue }
      guard let mesh = meshes[body.id], !mesh.vertices.isEmpty, !mesh.faces.isEmpty,
        mesh.vertices.allSatisfy(\.finite), body.position.finite, body.orientation.validRotation,
        mesh.faces.allSatisfy({ $0.count >= 3 && $0.allSatisfy(mesh.vertices.indices.contains) })
      else { return false }
      let points = mesh.vertices.map {
        local(pose.systemPoint(body.position + body.modelVector($0)))
      }
      guard points.allSatisfy(\.finite),
        let x = points.map(\.x).min(), let maxX = points.map(\.x).max(),
        let y = points.map(\.y).min(), let maxY = points.map(\.y).max(),
        let z = points.map(\.z).min(), let maxZ = points.map(\.z).max()
      else { return false }
      let min = Vector3(x, y, z)
      let max = Vector3(maxX, maxY, maxZ)
      guard
        nearest(.init(0, 0, 0), low: min, high: max).length
          > NativePracticeSource.volumeRadius + margin,
        maxX < low.x || x > high.x || maxY < low.y || y > high.y || maxZ < low.z || z > high.z
      else { return false }
    }
    return bodies.allSatisfy { body in
      body.energy <= 0 || context.actors.contains { $0.identity == body.physical?.identity }
    }
  }
}

extension Game {
  func defensiveFlightCourseIsClear(_ practice: NativePracticeState, radius: Double) -> Bool {
    guard let context = gameplayContext() else { return false }
    var meshes: [Int: Mesh] = [:]
    for body in bodies where body.energy > 0 {
      meshes[body.id] = scriptNPCMesh(body) ?? gameplayMesh(for: body)
    }
    return NativeDefensiveFlightAdmission.clear(
      practice: practice, pose: commander.flightSimulation.pose, context: context,
      bodies: bodies, meshes: meshes, radius: radius)
  }
}
