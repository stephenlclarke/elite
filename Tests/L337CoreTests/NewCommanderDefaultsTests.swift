import Foundation
import Testing

@testable import L337Core

struct NewCommanderDefaultsTests {
  @Test func freshRuntimeUsesApprovedIdentityMoneyWorldShipAndFullFuelWithoutQuests() async throws {
    let game = await GameRuntime(game: Game(executive: false)).snapshot()
    let commander = game.commander
    #expect(commander.name == "Rowan Calder" && commander.credits == 7200)
    #expect(commander.galaxy == 0 && commander.system == 7)
    #expect(game.currentSystem.original?.key == "G01-S007" && game.currentSystem.name == "Avenor")
    #expect(commander.shipID == "SH025" && commander.ship.name == "Peregrine Mk V")
    #expect(commander.fuel == 130 && commander.fuel == commander.fuelCapacity)
    #expect(commander.nativePerformance.cargo == 92 && commander.nativePerformance.jump == 9)
    #expect(commander.valid && commander.missionStage == .notStarted)
    #expect(commander.missionProgress.isEmpty && commander.scriptState.instances.isEmpty)
    #expect(commander.contracts == ScriptContractState())
    #expect(game.energy == commander.performance.energy)
    #expect(game.frontShield == commander.shieldCapacity)
  }

  @Test func originalPeregrineUsesEstimatedPhysicalBoundsAndUnchangedNativeTopology() throws {
    let commander = Commander()
    let ship = commander.ship
    let original = try OriginalFleetShowroomModels.model(for: "SH025")
    let mesh = commander.playerMesh
    let source = original.displayMesh
    let originalExtent = source.vertices.map(\.z).max()! - source.vertices.map(\.z).min()!
    let scale = 120 / originalExtent
    #expect(mesh.faces == source.faces && mesh.materials == source.materials)
    #expect(mesh.faceMaterials == source.faceMaterials)
    #expect(mesh.vertices.count == source.vertices.count)
    for (point, authored) in zip(mesh.vertices, source.vertices) {
      #expect((point - authored * scale).length < 1e-9)
    }
    let dimensions = try #require(ship.dimensions)
    let extents = [
      mesh.vertices.map(\.x).max()! - mesh.vertices.map(\.x).min()!,
      mesh.vertices.map(\.y).max()! - mesh.vertices.map(\.y).min()!,
      mesh.vertices.map(\.z).max()! - mesh.vertices.map(\.z).min()!,
    ]
    for (actual, declared) in zip(extents, dimensions) { #expect(abs(actual - declared) < 1e-9) }
    #expect(abs(extents.max()! - 120) < 1e-9)
    #expect(ship.geometryContext.contains("project estimate"))
    #expect(ship.geometryContext.contains("not an authored measurement"))
    #expect(MainStationGeometry.docking.fits(mesh))
    #expect(NativeStationGeometry.waystation.docking.fits(mesh))
    #expect(NativeStationGeometry.headquarters.docking.fits(mesh))
    #expect(NativeStationGeometry.waystation.exit(for: mesh) != nil)
    #expect(NativeStationGeometry.headquarters.exit(for: mesh) != nil)
    for mount in LaserMount.allCases { #expect(commander.nativePerformance.supports(mount)) }
    #expect(commander.missileCapacity == 9)
    #expect(commander.laser(on: .front) == .pulse)
    for mount in [LaserMount.rear, .left, .right] { #expect(commander.laser(on: mount) == nil) }
  }

  @Test func calibratedOriginalMeshRemainsThePlayerCollisionSurface() throws {
    let mesh = Commander().playerMesh
    let face = try #require(mesh.faces.first)
    let a = mesh.vertices[face[0]]
    let b = mesh.vertices[face[1]]
    let c = mesh.vertices[face[2]]
    let center = (a + b + c) * (1 / 3.0)
    let normal = (b - a).cross(c - a)
    let direction = normal * (1 / normal.length)
    let hit = try #require(
      GameplayRaycast.nearest(
        origin: center + direction * 10, direction: direction * -1, maxDistance: 20,
        bodies: [], playerMesh: mesh))
    #expect(hit.target == .player && hit.distance <= 10.000001)
    let outside = mesh.vertices.map(\.x).max()! + 1
    #expect(
      GameplayRaycast.nearest(
        origin: .init(outside, 0, -1000), direction: .init(0, 0, 1), maxDistance: 2000,
        bodies: [], playerMesh: mesh) == nil)
  }

  @Test func continuePreservesCurrentSavedCommanderInsteadOfApplyingFreshDefaults() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("commander.json")
    var game = Game(executive: false)
    game.commander.name = "Saved Pilot"
    game.commander.credits = 32123
    game.commander.fuel = 83
    let writer = GameRuntime(game: game)
    try await writer.save(to: url)
    let saved = await writer.snapshot()
    let bytes = try Data(contentsOf: url)
    let reader = GameRuntime()
    try await reader.restoreStartup(from: url)
    let loaded = await reader.snapshot()
    #expect(loaded.screen == .title && loaded.commander.name == "Saved Pilot")
    #expect(loaded.commander.credits == 32123 && loaded.commander.fuel == 83)
    #expect(loaded.commander.shipID == saved.commander.shipID)
    #expect(loaded.commander.equipmentOwnerID == saved.commander.equipmentOwnerID)
    #expect(loaded.commander.hullInstanceID == saved.commander.hullInstanceID)
    #expect(loaded.commander.equipmentInventory == saved.commander.equipmentInventory)
    #expect(loaded.commander.equipmentPurchaseHistory == saved.commander.equipmentPurchaseHistory)
    #expect(try Data(contentsOf: url) == bytes)
    await reader.key(" ")
    let continued = await reader.snapshot()
    #expect(continued.screen == .status && continued.commander == loaded.commander)
  }

  @Test func continuePreservesCurrentImplicitShipIdentityAndOwnedEquipment() async throws {
    var commander = Commander()
    commander.name = "Existing Pilot"
    commander.shipID = "SH023"
    commander.credits = 45678
    commander.fuel = 45
    try commander.prepareEquipment(legacy: false)
    let encoded = try JSONEncoder().encode(commander)
    var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    object.removeValue(forKey: "ownedShipID")
    let implicit = try JSONDecoder().decode(
      Commander.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(implicit.shipID == "SH023" && implicit.valid)
    #expect(implicit.name == commander.name && implicit.credits == commander.credits)
    #expect(implicit.equipmentInventory == commander.equipmentInventory)
    #expect(implicit.equipmentPurchaseHistory == commander.equipmentPurchaseHistory)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("commander.json")
    var game = Game(executive: false)
    game.commander = implicit
    let writer = GameRuntime(game: game)
    try await writer.save(to: url)
    let saved = await writer.snapshot()
    let bytes = try Data(contentsOf: url)
    let reader = GameRuntime()
    try await reader.restoreStartup(from: url)
    let loaded = await reader.snapshot()
    #expect(loaded.commander.shipID == "SH023")
    #expect(loaded.commander.name == "Existing Pilot" && loaded.commander.credits == 45678)
    #expect(loaded.commander.fuel == 45)
    #expect(loaded.commander.equipmentInventory == saved.commander.equipmentInventory)
    #expect(loaded.commander.equipmentPurchaseHistory == saved.commander.equipmentPurchaseHistory)
    #expect(loaded.commander.equipmentOwnerID == saved.commander.equipmentOwnerID)
    #expect(loaded.commander.hullInstanceID == saved.commander.hullInstanceID)
    #expect(loaded.commander.valid && loaded.screen == .title)
    await reader.key(" ")
    let continued = await reader.snapshot()
    #expect(continued.screen == .status && continued.commander == loaded.commander)
    #expect(try Data(contentsOf: url) == bytes)
  }

  @Test func restartUsesCurrentDefaultsAndTitleRetainsTruthfulBuildIdentity() {
    var game = Game(executive: false)
    game.commander.name = "Previous Pilot"
    game.commander.credits = 1
    game.screen = .gameOver
    let directHelp = PlayerHelp.pages(for: game).flatMap(\.rows)
    #expect(directHelp.contains("RETURN / SPACE - NEW COMMANDER"))
    #expect(!directHelp.contains { $0.contains("JAMESON") })
    game.key("k")
    #expect(game.screen == .help && game.helpReturn == .gameOver)
    #expect(PlayerHelp.pages(for: game).flatMap(\.rows).contains("RETURN / SPACE - NEW COMMANDER"))
    #expect(game.commander.name == "Previous Pilot" && game.commander.credits == 1)
    game.key("escape")
    #expect(game.screen == .gameOver)
    game.key("return")
    #expect(game.commander.name == "Rowan Calder" && game.commander.credits == 7200)
    #expect(game.commander.shipID == "SH025" && game.commander.fuel == 130)
    game.screen = .title
    let frame = Display.startupScreen(game, width: 768, height: 768)
    let labels = frame.labels.map(\.text)
    #expect(labels.contains("L337") && !labels.contains("E L I T E"))
    #expect(labels.contains(BuildIdentity.repository))
    #expect(labels.contains(BuildIdentity.current.versionLine))
    #expect(labels.contains(BuildIdentity.current.revisionLine))
    #expect(!frame.shipPanels.isEmpty)
  }
}
