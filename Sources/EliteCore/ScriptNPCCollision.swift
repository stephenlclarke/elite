import Foundation

struct ScriptNPCHit {
  let body: Int
  let component: String?
  let distance: Double
}

extension Game {
  /// Ray tests use measured source meshes and component transforms, never showroom sizes.
  func scriptNPCHit(
    from origin: Vector3, direction: Vector3, range: Double, excluding owner: UUID? = nil,
    profiledOnly: Bool = false, radius: Double = 0
  ) -> ScriptNPCHit? {
    var closest: ScriptNPCHit?
    for index in bodies.indices {
      let body = bodies[index]
      guard body.energy > 0, owner == nil || body.missionActorID != owner,
        body.scriptShot == nil, !profiledOnly || body.scriptNPC != nil
      else { continue }
      let offset = body.position - origin
      let along = max(0, min(range, offset.dot(direction)))
      guard (offset - direction * along).length <= scriptNPCRadius(body) + radius else { continue }
      guard let npc = body.scriptNPC else {
        if let distance = Self.scriptMeshRay(
          origin: origin, direction: direction,
          range: closest?.distance ?? range, mesh: Mesh.hull(body.hull), position: body.position,
          orientation: body.modelBasis, scale: 1, radius: radius)
        {
          closest = .init(body: index, component: nil, distance: distance)
        }
        continue
      }
      func consider(
        _ reference: String, position: Vector3, orientation: Basis3, scale: Double,
        component: String?
      ) {
        guard let mesh = scriptModel(reference, fit: npc.fit),
          let distance = Self.scriptMeshRay(
            origin: origin, direction: direction,
            range: closest?.distance ?? range, mesh: mesh, position: position,
            orientation: orientation, scale: scale, radius: radius)
        else { return }
        closest = .init(body: index, component: component, distance: distance)
      }
      let definition = npc.fit.definition
      consider(
        definition.model, position: body.position, orientation: body.orientation,
        scale: definition.scale, component: nil)
      for component in definition.components ?? [] where component.solid {
        guard (npc.components[component.id]?.energy ?? 0) > 0 else { continue }
        consider(
          component.model,
          position: body.position + body.orientation.apply(component.position * definition.scale),
          orientation: component.orientation.transformed(by: body.orientation),
          scale: component.scale * definition.scale, component: component.id)
      }
    }
    return closest
  }
  static func scriptMeshRay(
    origin: Vector3, direction: Vector3, range: Double, mesh: Mesh, position: Vector3,
    orientation: Basis3, scale: Double, radius: Double = 0
  ) -> Double? {
    let origin = orientation.inverse(origin - position) * (1 / scale)
    let direction = orientation.inverse(direction) * (1 / scale)
    var nearest = range
    var found = false
    for face in mesh.faces {
      let a = mesh.vertices[face[0]]
      for index in 1..<(face.count - 1) {
        let b = mesh.vertices[face[index]]
        let c = mesh.vertices[face[index + 1]]
        if radius > 0 {
          if let distance = ScriptSweptCollision.triangle(
            origin: origin, direction: direction,
            range: nearest, radius: radius / scale, a: a, b: b, c: c)
          {
            found = true
            nearest = distance
          }
          continue
        }
        let edge = b - a
        let other = c - a
        let p = direction.cross(other)
        let det = edge.dot(p)
        guard abs(det) > 1e-12 else { continue }
        let inverse = 1 / det
        let relative = origin - a
        let u = relative.dot(p) * inverse
        guard (0...1).contains(u) else { continue }
        let q = relative.cross(edge)
        let v = direction.dot(q) * inverse
        guard v >= 0, u + v <= 1 else { continue }
        let distance = other.dot(q) * inverse
        if distance >= 0 && distance <= nearest {
          found = true
          nearest = distance
        }
      }
    }
    return found ? nearest : nil
  }
  var scriptPlayerMesh: Mesh {
    commander.ship.nativeDesign?.rawMesh ?? commander.ship.design.rawMesh
  }
  func scriptPlayerHit(from origin: Vector3, direction: Vector3, range: Double, radius: Double = 0)
    -> Double?
  {
    return Self.scriptMeshRay(
      origin: origin, direction: direction, range: range,
      mesh: scriptPlayerMesh, position: .init(0, 0, 0),
      orientation: Basis3(), scale: 1, radius: radius)
  }
  mutating func damageScriptNPC(_ hit: ScriptNPCHit, amount: Double, player: Bool, attacker: UUID?)
  {
    guard bodies.indices.contains(hit.body), amount.isFinite, amount > 0,
      bodies[hit.body].energy > 0
    else { return }
    guard var npc = bodies[hit.body].scriptNPC else {
      // The main orbital station remains protected under the existing native docking model.
      let minimum = bodies[hit.body].hull == .station ? 1.0 : 0
      bodies[hit.body].energy = max(minimum, bodies[hit.body].energy - amount)
      if bodies[hit.body].energy == 0 { bodies[hit.body].destroyedByPlayer = player }
      return
    }
    var removed = false
    if let key = hit.component, var component = npc.components[key], component.energy > 0 {
      component.energy = max(0, component.energy - amount)
      removed = component.energy == 0
      npc.components[key] = component
    } else if hit.component == nil {
      bodies[hit.body].energy = max(0, bodies[hit.body].energy - amount)
      if bodies[hit.body].energy == 0 { bodies[hit.body].destroyedByPlayer = player }
    } else {
      return
    }
    bodies[hit.body].scriptNPC = npc
    if player { bodies[hit.body].hostile = true }
    guard let instance = bodies[hit.body].missionInstanceID,
      let identity = bodies[hit.body].missionActorID
    else { return }
    var values: [String: ScriptValue] = [
      "actor_id": .string(identity.uuidString),
      "amount": .number(amount), "player": .bool(player),
      "attacker_id": attacker.map { .string($0.uuidString) } ?? .null,
    ]
    if let key = hit.component, let component = npc.components[key] {
      values["component"] = .string(key)
      values["component_id"] = .string(component.identity.uuidString)
    }
    emitScriptEvent("actor.damaged", values: values, only: instance, drain: false)
    if removed {
      emitScriptEvent("component.destroyed", values: values, only: instance, drain: false)
    }
  }
}

extension SpaceBody {
  var modelBasis: Basis3 {
    var basis = Basis3()
    basis.x = modelVector(.init(1, 0, 0))
    basis.y = modelVector(.init(0, 1, 0))
    basis.z = modelVector(.init(0, 0, 1))
    return basis
  }
}
