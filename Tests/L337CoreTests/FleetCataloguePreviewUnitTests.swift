import Foundation
import Testing

@testable import L337Core

struct FleetCataloguePreviewUnitTests {
  private func eligible() throws -> CatalogueShip {
    try #require(
      ShipCatalogue.all.first { $0.originalDefinition != nil && $0.catalogue.discoveryEligible })
  }
  private func evidence(_ ship: CatalogueShip, owner: UUID) -> FleetDiscoveryEvidence {
    let system = SystemIdentity(galaxy: 0, system: 7)
    return .init(
      owner: owner, ship: ship.id, kind: .encounter,
      actor: .init(system: system, visit: 1, entity: 2),
      player: .init(system: system, visit: 1, entity: 0), physicalTime: 1,
      death: nil, mainDock: nil, secondaryDock: nil)
  }
  private var mesh: Mesh {
    Mesh(
      vertices: [.init(-10, -10, -10), .init(10, -10, -10), .init(0, 10, -10), .init(0, 0, 10)],
      faces: [[0, 2, 1], [0, 1, 3], [1, 2, 3], [2, 0, 3]],
      details: [.init(start: 0, end: 1, face: 0)],
      materials: [.init(name: "surface detail", colour: Ink.gold.rawValue, emissive: true)],
      faceMaterials: [0, 0, 0, 0],
      faceTextures: Array(
        repeating: .init(asset: "surface-detail", uv: [[0, 0], [1, 0], [0, 1]]), count: 4))
  }
  private func frame() -> Frame {
    var frame = Frame()
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: 200, height: 200)
    frame.flightClip = frame.canvas
    return frame
  }

  @Test func onlyTheOwnersRecordedEncounterRevealsWireframeAndOwnershipRetainsShading() throws {
    let ship = try eligible()
    let owner = UUID()
    var discovery = NativeFleetDiscovery(owner: owner)
    #expect(
      FleetCataloguePreview.mode(ship: ship, owner: owner, ownedShip: "", discovery: nil)
        == .silhouette)
    try discovery.record(evidence(ship, owner: owner))
    let before = discovery
    #expect(
      FleetCataloguePreview.mode(ship: ship, owner: owner, ownedShip: "", discovery: discovery)
        == .recordedWireframe)
    #expect(
      FleetCataloguePreview.mode(ship: ship, owner: UUID(), ownedShip: "", discovery: discovery)
        == .silhouette)
    #expect(
      FleetCataloguePreview.mode(ship: ship, owner: nil, ownedShip: "", discovery: discovery)
        == .silhouette)
    #expect(
      FleetCataloguePreview.mode(ship: ship, owner: owner, ownedShip: ship.id, discovery: nil)
        == .shaded)
    #expect(discovery == before && discovery.entries[ship.id]?.blueprintEarned == false)
    // Reading the source profile keeps all authored values available without recording a sighting.
    #expect(!ship.sourceProfilesIncludingOriginal.isEmpty)
    for value in ShipCatalogue.all
    where value.originalDefinition == nil || !value.catalogue.discoveryEligible {
      #expect(
        FleetCataloguePreview.mode(ship: value, owner: owner, ownedShip: "", discovery: nil)
          == .shaded)
    }
  }

  @Test func rotatingSilhouetteKeepsProjectedHullButRevealsNoMaterialsTexturesOrInternalEdges() {
    let projection = FlightProjection(center: .init(100, 100), focal: 200)
    var previous: [Graphic]?
    for angle in [0.0, 0.7, 1.8] {
      var body = SpaceBody(id: 0, hull: .cobra, position: .init(0, 0, 100))
      body.orientation.rotate(pitch: 0.25 + angle * 0.3, roll: angle * 0.15, yaw: angle)
      var output = frame()
      FleetCataloguePreview.drawSilhouette(mesh, body: body, projection: projection, into: &output)
      #expect(!output.graphics.isEmpty)
      for command in output.graphics {
        guard case .panel(let panel) = command else {
          Issue.record("A silhouette exposed an edge, texture or other surface detail.")
          continue
        }
        #expect(panel.colour == Ink.white.rawValue)
        #expect(panel.vertices.allSatisfy(output.flightClip.contains))
      }
      if let previous { #expect(output.graphics != previous) }
      previous = output.graphics
    }
    #expect(mesh.materials[0].colour == Ink.gold.rawValue && !mesh.details.isEmpty)
    #expect(mesh.faceTextures.compactMap { $0 }.count == 4)
  }

  @Test func silhouetteClipsNearPlaneAndViewportAndRefusesNonFiniteProjectionInputs() {
    let projection = FlightProjection(center: .init(100, 100), focal: 200)
    var body = SpaceBody(id: 0, hull: .cobra, position: .init(6, 0, 5))
    var output = frame()
    FleetCataloguePreview.drawSilhouette(mesh, body: body, projection: projection, into: &output)
    #expect(!output.graphics.isEmpty)
    for command in output.graphics {
      if case .panel(let panel) = command {
        #expect(panel.vertices.allSatisfy(output.flightClip.contains))
      }
    }
    output = frame()
    body.position.x = .nan
    FleetCataloguePreview.drawSilhouette(mesh, body: body, projection: projection, into: &output)
    #expect(output.graphics.isEmpty)
    body.position = .init(0, 0, -100)
    FleetCataloguePreview.drawSilhouette(mesh, body: body, projection: projection, into: &output)
    #expect(output.graphics.isEmpty)
  }
}
