import Foundation

/// Export fixtures only. These scenes never enter a player's commander or save session.
public enum ReadmeMedia {
  public static let introductionFrameCount = 48
  public static let introductionFrameDelay = 0.16
  public static let galleryFrameDelay = 0.10
  /// Include both endpoints: 36 equal angular steps are exactly one and a half turns.
  public static let galleryAngles = (0...36).map { Double($0) * .pi / 12 }
  public static var galleryShipIDs: [String] { ShipCatalogue.all.map(\.id) }
  public static var frameCount: Int {
    introductionFrameCount + galleryShipIDs.count * galleryAngles.count
  }
  public static var duration: Double {
    Double(introductionFrameCount) * introductionFrameDelay
      + Double(galleryShipIDs.count * galleryAngles.count) * galleryFrameDelay
  }

  /// Admit a disposable, explicitly authored capture encounter using the real mission engine.
  /// Its four guns fire through the native boundary; no beam graphics or gun state are forged.
  public static func dockingUnderAttackScene(sourceDirectory: URL) throws -> Game {
    let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(
      "l337-readme-capture-" + UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporary) }
    try FileManager.default.copyItem(at: sourceDirectory, to: temporary)
    let manifestURL = temporary.appendingPathComponent("manifest.toml")
    let original = try String(contentsOf: manifestURL, encoding: .utf8)
    let wing = "  {id=\"wing\", npc=\"training-craft\", x=1000.0, y=0.0, z=4500.0, hostile=true}"
    guard original.components(separatedBy: wing).count == 2 else {
      throw SaveError.invalidCommander
    }
    let extra = """
      \(wing),
        {id="port", npc="training-craft", x=-1000.0, y=0.0, z=4500.0, hostile=true},
        {id="upper", npc="training-craft", x=0.0, y=1000.0, z=6000.0, hostile=true}
      """
    let capture = original.replacingOccurrences(of: wing, with: extra)
      .replacingOccurrences(
        of: "id = \"example.profiled-skirmish\"", with: "id = \"media.docking-capture\"")
    let labelledCapture = capture.replacingOccurrences(
      of: "title = \"Profiled skirmish demonstration\"",
      with: "title = \"README docking-under-attack capture\"")
    try labelledCapture.write(to: manifestURL, atomically: true, encoding: .utf8)
    let pack = try ScriptPackLibrary.read(temporary)
    var game = Game(executive: false)
    game.screen = .status
    try game.commander.prepareEquipment(legacy: false)
    game.commander.retaliationEnabled = false
    game.commander.autoECM = false
    game.scriptPacks = [pack]
    let instance = try game.acceptScriptMission(pack)
    game.launch()
    game.emitScriptEvent("station.undocked")
    game.drainScriptEvents()
    guard !game.docked,
      let station = game.bodies.first(where: { $0.id == 0 && $0.hull == .station }),
      let encounter = game.commander.scriptState.instances[instance]?.ownedEncounters["opponents"],
      encounter.actors.count == 4
    else { throw SaveError.invalidCommander }

    // Move only the capture camera to the real entrance's approach axis. Preserve world poses.
    let previous = game.commander.flightSimulation.pose
    var pose = ShipPose()
    pose.position = previous.systemPoint(station.entrancePosition + station.entranceNormal * 1400)
    pose.orientation.y = previous.orientation.apply(station.entranceUp)
    pose.orientation.z = previous.orientation.apply(station.entranceNormal) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    for index in game.bodies.indices {
      let body = game.bodies[index]
      game.bodies[index].position = pose.shipPoint(previous.systemPoint(body.position))
      game.bodies[index].orientation = body.orientation.transformed(by: previous.orientation)
        .relative(to: pose.orientation)
    }
    for index in game.celestials.indices {
      game.celestials[index].position = pose.shipPoint(
        previous.systemPoint(game.celestials[index].position))
    }
    game.commander.flightSimulation.pose = pose

    let aliases = ["lead", "wing", "port", "upper"]
    let positions = [
      Vector3(-145, 85, 620), Vector3(160, 100, 760),
      Vector3(-190, -105, 910), Vector3(220, -80, 1060),
    ]
    for (alias, position) in zip(aliases, positions) {
      guard let actor = encounter.actors[alias],
        let index = game.bodies.firstIndex(where: { $0.missionActorID == actor.identity })
      else { throw SaveError.invalidCommander }
      var facing = Basis3()
      facing.z = position.unit * -1
      facing.x = Vector3(0, 1, 0).cross(facing.z).unit
      facing.y = facing.z.cross(facing.x)
      game.bodies[index].position = position
      game.bodies[index].orientation = facing
      game.bodies[index].rotation = 0
      game.bodies[index].rotationRate = 0
      game.bodies[index].scriptNPC?.intent = .init(
        request: "readme-attack", mode: .attack, target: nil, player: true,
        offset: .init(0, 0, 0), speed: 0, tolerance: 1)
    }
    for alias in aliases {
      guard let actor = encounter.actors[alias],
        let index = game.bodies.firstIndex(where: { $0.missionActorID == actor.identity })
      else { throw SaveError.invalidCommander }
      game.bodies[index].orientation = try incomingSurfaceFacing(game.bodies[index], game: game)
    }
    game.persistScriptActors()
    for alias in aliases {
      guard let actor = encounter.actors[alias],
        let body = game.bodies.first(where: { $0.missionActorID == actor.identity }),
        let shots = body.scriptNPC?.shots
      else { throw SaveError.invalidCommander }
      guard
        let impact = try game.fireMissionNativeLaser(
          bodyID: body.id, weaponID: "forward", componentID: nil),
        impact.target == .player, impact.damageAdmitted, impact.damage > 0
      else { throw SaveError.invalidCommander }
      guard game.bodies.first(where: { $0.id == body.id })?.scriptNPC?.shots == shots + 1 else {
        throw SaveError.invalidCommander
      }
    }
    game.speed = 8
    game.screen = .front
    game.commander.shipDisplayStyle = .shadedPanels
    game.prepareFlightWeaponDisplay()
    return game
  }

  /// Aim at a real off-axis hull surface, not the camera origin where a beam projects to a point.
  /// The ordinary gun acceptance and native impact boundary still own the actual shot.
  private static func incomingSurfaceFacing(_ body: SpaceBody, game: Game) throws -> Basis3 {
    guard let npc = body.scriptNPC,
      let weapon = npc.fit.definition.lasers?.first(where: { $0.id == "forward" })
    else { throw SaveError.invalidCommander }
    let mesh = game.commander.playerMesh
    var candidates: [Vector3] = []
    for face in mesh.faces where face.count >= 3 && face.allSatisfy(mesh.vertices.indices.contains)
    {
      let a = mesh.vertices[face[0]]
      let b = mesh.vertices[face[1]]
      let c = mesh.vertices[face[2]]
      candidates += [
        (a + b + c) * (1 / 3.0), (a * 2 + b + c) * 0.25,
        (a + b * 2 + c) * 0.25, (a + b + c * 2) * 0.25,
      ]
    }
    candidates.sort { $0.x * $0.x + $0.y * $0.y < $1.x * $1.x + $1.y * $1.y }
    let projection = FlightProjection(center: .init(512, 300), focal: 768)
    for point in candidates where point.finite {
      var facing = Basis3()
      facing.z = (point - body.position).unit
      facing.x = Vector3(0, 1, 0).cross(facing.z).unit
      facing.y = facing.z.cross(facing.x)
      let muzzle = body.position + facing.apply(weapon.muzzle * npc.fit.definition.scale)
      let direction = facing.apply(weapon.direction).unit
      let centerDirection = muzzle.unit * -1
      guard direction.dot(centerDirection) > 0.999,
        facing.inverse(centerDirection).dot(weapon.direction) >= cos(weapon.arc) - 1e-9,
        let contact = try game.nearestMissionCollision(
          from: muzzle, direction: direction, range: weapon.range, radius: 0,
          excludingBodyIDs: [body.id], includePlayer: true),
        contact.hit.target == .player,
        let line = Display.project(muzzle, contact.hit.point, projection: projection),
        hypot(line.2 - line.0, line.3 - line.1) >= 64
      else { continue }
      return facing
    }
    throw SaveError.invalidCommander
  }
}
