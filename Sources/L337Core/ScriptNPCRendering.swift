import Foundation

extension Game {
  /// Assemble in source coordinates so one depth sort handles overlapping solid components.
  func scriptNPCMesh(_ body: SpaceBody) -> Mesh? {
    if let shot = body.scriptShot {
      let r = shot.radius
      return Mesh(
        vertices: [
          .init(r, 0, 0), .init(-r, 0, 0), .init(0, r, 0),
          .init(0, -r, 0), .init(0, 0, r), .init(0, 0, -r),
        ],
        faces: [
          [0, 2, 4], [4, 2, 1], [1, 2, 5], [5, 2, 0],
          [4, 3, 0], [1, 3, 4], [5, 3, 1], [0, 3, 5],
        ],
        materials: [.init(name: "Plasma", colour: Ink.redOrange.rawValue, emissive: true)],
        faceMaterials: Array(repeating: 0, count: 8))
    }
    guard let npc = body.scriptNPC,
      let root = scriptModel(npc.fit.definition.model, fit: npc.fit)
    else { return nil }
    var vertices: [Vector3] = []
    var faces: [[Int]] = []
    var details: [MeshDetail] = []
    var materials: [ShipMaterial] = []
    var assignments: [Int] = []
    var textures: [ShipMeshTexture?] = []
    func append(_ mesh: Mesh, position: Vector3, orientation: Basis3, scale: Double) {
      let vertexBase = vertices.count
      let faceBase = faces.count
      let materialBase = materials.count
      if !mesh.faceTextures.isEmpty {
        if textures.isEmpty { textures = Array(repeating: nil, count: faceBase) }
        textures += mesh.faceTextures
      } else if !textures.isEmpty {
        textures += Array(repeating: nil, count: mesh.faces.count)
      }
      vertices += mesh.vertices.map {
        (position + orientation.apply($0 * scale)) * npc.fit.definition.scale
      }
      faces += mesh.faces.map { $0.map { $0 + vertexBase } }
      details += mesh.details.map {
        .init(start: $0.start + vertexBase, end: $0.end + vertexBase, face: $0.face + faceBase)
      }
      if mesh.materials.isEmpty {
        materials.append(
          .init(name: "Native fallback", colour: body.hull.ink.rawValue, emissive: false))
        assignments += Array(repeating: materialBase, count: mesh.faces.count)
      } else {
        materials += mesh.materials
        assignments += mesh.faceMaterials.map { $0 + materialBase }
      }
    }
    append(root, position: .init(0, 0, 0), orientation: Basis3(), scale: 1)
    for spec in npc.fit.definition.components ?? [] {
      guard npc.components[spec.id]?.energy ?? 0 > 0,
        let mesh = scriptModel(spec.model, fit: npc.fit)
      else { continue }
      append(mesh, position: spec.position, orientation: spec.orientation, scale: spec.scale)
    }
    return Mesh(
      vertices: vertices, faces: faces, details: details, materials: materials,
      faceMaterials: assignments, faceTextures: textures, preserveWinding: true)
  }
}

extension Display {
  static func drawScriptBeams(
    _ body: SpaceBody, game: borrowing Game, into frame: inout Frame,
    projection: FlightProjection, screen: Screen? = nil
  ) {
    guard let npc = body.scriptNPC else { return }
    let view: Screen
    if let screen {
      view = screen
    } else {
      view = game.screen
    }
    func beam(
      _ weapon: ScriptNPCWeapon, state: ScriptNPCGunState?, position: Vector3,
      orientation: Basis3, scale: Double
    ) {
      guard let state, let range = state.beamRange, weapon.kind == .laser,
        state.cooldown > max(0, weapon.interval - 0.05)
      else { return }
      let start = position + orientation.apply(weapon.muzzle * scale)
      let end = start + orientation.apply(state.aim ?? weapon.direction) * range
      guard
        let line = project(
          Game.viewPosition(start, screen: view), Game.viewPosition(end, screen: view),
          projection: projection)
      else { return }
      let length = hypot(line.2 - line.0, line.3 - line.1)
      guard length > 1e-9 else { return }
      let x = (line.3 - line.1) / length * 0.6
      let y = (line.2 - line.0) / length * 0.6
      frame.panel(
        [
          .init(line.0 - x, line.1 + y), .init(line.2 - x, line.3 + y),
          .init(line.2 + x, line.3 - y), .init(line.0 + x, line.1 - y),
        ],
        colour: weapon.colour ?? Ink.redOrange.rawValue)
    }
    for weapon in npc.fit.definition.lasers ?? [] {
      beam(
        weapon, state: npc.guns[weapon.id], position: body.position,
        orientation: body.orientation, scale: npc.fit.definition.scale)
    }
    for component in npc.fit.definition.components ?? [] {
      guard let actual = npc.components[component.id], actual.energy > 0 else { continue }
      for weapon in component.weapons ?? [] {
        beam(
          weapon, state: actual.guns[weapon.id],
          position: body.position
            + body.orientation.apply(component.position * npc.fit.definition.scale),
          orientation: component.orientation.transformed(by: body.orientation),
          scale: component.scale * npc.fit.definition.scale)
      }
    }
  }
}
