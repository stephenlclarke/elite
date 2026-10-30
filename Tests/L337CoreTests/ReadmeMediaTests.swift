import Foundation
import Testing

@testable import L337Core

struct ReadmeMediaTests {
  @Test func completeTapeUsesTheActualGalleryAndIncludesExactlyOneAndAHalfTurns() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    let manifest =
      try JSONSerialization.jsonObject(
        with: Data(contentsOf: root.appendingPathComponent("docs/ships/manifest.json")))
      as? [String: Any]
    let ids = try #require(manifest?.keys.sorted())
    #expect(ReadmeMedia.galleryShipIDs == ids)
    #expect(ids.count == 171 && Set(ids).count == ids.count)
    let angles = ReadmeMedia.galleryAngles
    #expect(angles.count == 37)
    #expect(angles.first == 0)
    #expect(abs(try #require(angles.last) - 3 * .pi) < 1e-12)
    #expect(zip(angles, angles.dropFirst()).allSatisfy { $0.0 < $0.1 })
    #expect(abs(angles[24] - 2 * .pi) < 1e-12)
    #expect(ReadmeMedia.frameCount == 6375)
    #expect(abs(ReadmeMedia.duration - 640.38) < 1e-9)
  }

  @Test(arguments: ShipCatalogue.all.map(\.id))
  func everyGalleryCardUsesItsRealMeshAndNameAtTheActualRotationEndpoints(id: String) throws {
    let ship = try #require(ShipCatalogue.ship(id))
    let mesh = try #require(ship.previewMesh)
    let game = Game(executive: false)
    let commander = game.commander
    let screen = game.screen
    let bodies = game.bodies
    for angle in [0.0, Double.pi, 3 * Double.pi] {
      let frame = try Display.galleryShipPresentation(
        game, shipID: id, angle: angle, width: 1024, height: 768)
      #expect(frame.hasShipSurfaces)
      #expect(
        frame.labels.map(\.text) == [
          "SHIP GALLERY", id + " - " + ship.name, "1.5 FULL ROTATIONS",
        ])
      #expect(!frame.rasterizeGraphics && frame.responsive)
      #expect(
        frame.labels.allSatisfy {
          $0.bounds.x >= 0 && $0.bounds.maxX <= frame.canvas.width
            && $0.bounds.y >= 0 && $0.bounds.maxY <= frame.canvas.height
        })
      var reference = Frame()
      reference.responsive = true
      reference.rasterizeGraphics = false
      reference.canvas = frame.canvas
      reference.flightClip = frame.flightClip
      var presentation = game
      presentation.screen = .front
      presentation.commander.shipDisplayStyle = .shadedPanels
      var body = SpaceBody(id: 0, hull: .cobra, position: .init(0, 0, 400))
      body.orientation.rotate(pitch: 0.3, roll: 0.15, yaw: angle)
      Display.draw(
        body, game: presentation, into: &reference,
        projection: .init(center: .init(512, 768 * 0.47), focal: 768 * 1.15),
        mesh: mesh, screen: .front)
      #expect(
        frame.graphics == reference.graphics && frame.worldGraphics == reference.worldGraphics)
    }
    #expect(game.screen == screen && game.commander == commander && game.bodies == bodies)
  }

  @Test func galleryExportRefusesMissingShipsAndNonfiniteAngles() {
    for (id, angle) in [("SH999", 0.0), ("SH002", Double.nan), ("SH002", .infinity)] {
      #expect(throws: ShipFileError.self) {
        try Display.galleryShipPresentation(
          Game(executive: false), shipID: id, angle: angle, width: 1024, height: 768)
      }
    }
  }

  @Test func dockingScreenshotUsesTheActualPortAndFourAcceptedIncomingLaserEmissions() throws {
    let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/profiled-skirmish")
    let manifest = try Data(contentsOf: directory.appendingPathComponent("manifest.toml"))
    let game = try ReadmeMedia.dockingUnderAttackScene(sourceDirectory: directory)
    #expect(try Data(contentsOf: directory.appendingPathComponent("manifest.toml")) == manifest)
    #expect(!game.docked && game.screen == .front && game.laserFlash == 0)
    let station = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
    #expect(abs(station.entrancePosition.x) < 1e-6 && abs(station.entrancePosition.y) < 1e-6)
    #expect(abs(station.entrancePosition.z - 1400) < 1e-6)
    #expect(station.entranceNormal.z < -0.999 && station.entranceUp.y > 0.999)
    let attackers = game.bodies.filter { $0.scriptNPC != nil }
    #expect(attackers.count == 4 && Set(attackers.compactMap(\.missionActorID)).count == 4)
    let layout = CockpitLayout(game: game, width: 1024, height: 768)
    for body in attackers {
      #expect(body.hostile && body.position.z > 0 && body.position.z < station.entrancePosition.z)
      let descriptor = try #require(game.currentMissionActorDescriptor(bodyID: body.id))
      #expect(descriptor.encounterAdmitted && descriptor.presence == "present")
      let npc = try #require(body.scriptNPC)
      let weapon = try #require(npc.fit.definition.lasers?.first { $0.id == "forward" })
      let gun = try #require(npc.guns[weapon.id])
      #expect(npc.shots == 1 && gun.cooldown == weapon.interval)
      #expect(abs(body.energy - (npc.fit.definition.energy - weapon.energy)) < 1e-9)
      let beamRange = try #require(gun.beamRange)
      #expect(gun.heat == weapon.heat && beamRange > 0)
      #expect(npc.intent?.mode == .attack && npc.intent?.player == true)
      let muzzle = body.position + body.orientation.apply(weapon.muzzle * npc.fit.definition.scale)
      let direction = body.orientation.apply(gun.aim ?? weapon.direction)
      #expect(gun.aim == nil)
      #expect(direction.unit.dot(muzzle.unit * -1) > 0.999)
      #expect(direction.unit.dot(muzzle.unit * -1) >= cos(weapon.arc) - 1e-9)
      let actualContact = try game.nearestMissionCollision(
        from: muzzle, direction: direction.unit, range: weapon.range, radius: 0,
        excludingBodyIDs: [body.id], includePlayer: true)
      let contact = try #require(actualContact)
      #expect(contact.hit.target == .player && abs(contact.hit.distance - beamRange) < 1e-6)
      var beams = Frame()
      beams.responsive = true
      beams.rasterizeGraphics = false
      beams.canvas = .init(x: 0, y: 0, width: layout.width, height: layout.height)
      beams.flightClip = layout.flightClip
      Display.drawScriptBeams(
        body, game: game, into: &beams,
        projection: layout.projection, screen: .front)
      #expect(beams.shipPanels.count == 1)
      let panel = try #require(beams.shipPanels.first)
      try #require(panel.vertices.count >= 3)
      let extent =
        panel.vertices.flatMap { a in
          panel.vertices.map { b in hypot(a.x - b.x, a.y - b.y) }
        }.max() ?? 0
      let twiceArea = panel.vertices.indices.reduce(0.0) { area, index in
        let a = panel.vertices[index]
        let b = panel.vertices[(index + 1) % panel.vertices.count]
        return area + a.x * b.y - b.x * a.y
      }
      #expect(extent >= 48 && abs(twiceArea) / 2 >= 24)
      #expect(
        panel.vertices.allSatisfy {
          $0.x.isFinite && $0.y.isFinite
            && $0.x >= layout.flightClip.x - 1e-9 && $0.x <= layout.flightClip.maxX + 1e-9
            && $0.y >= layout.flightClip.y - 1e-9 && $0.y <= layout.flightClip.maxY + 1e-9
        })
    }
  }
}
