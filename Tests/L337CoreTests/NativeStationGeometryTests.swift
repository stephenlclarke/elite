import Testing

@testable import L337Core

@Test func nativeRRSGeometryRetainsStructuralSourceBoundsAndPorts() {
  let way = NativeStationGeometry.waystation
  #expect(way.mesh.vertices.count == 152)
  #expect(way.mesh.faces.count == 272)
  #expect(way.bounds.minimum == Vector3(-675, -150, -500))
  #expect(way.bounds.maximum == Vector3(675, 150, 500))
  #expect(way.docking.center == Vector3(0, 0, -350))
  #expect(way.launch.center == Vector3(0, 0, 350))
  #expect(way.docking.outward == Vector3(0, 0, -1))
  #expect(way.launch.outward == Vector3(0, 0, 1))
  #expect(way.docking.tunnelDepth == 140)
  #expect(way.docking.aperture.count == 8)
  #expect(way.kind.sourceRoles == ["rescue_station", "rrs_group_spacestation"])
  let hq = NativeStationGeometry.headquarters
  #expect(hq.mesh.vertices.count == 280)
  #expect(hq.mesh.faces.count == 413)
  #expect(hq.bounds.minimum == Vector3(-1585.29214, -1779.0468, -1860.83266))
  #expect(hq.bounds.maximum == Vector3(1566.54969, 1716.77885, 1931.09101))
  #expect(hq.docking.center == Vector3(250, 86.5, -1860.8))
  #expect(hq.launch == hq.docking)
  #expect(hq.docking.tunnelDepth == 350)
  #expect(hq.kind.sourceDefinition == "rrs_headquarters")
  #expect(hq.kind.sourceRoles == ["rrs_galactic_hq", "rrs_group_spacestation"])
}

@Test func nativeRRSRotationAdaptsFaceConventionAndPreservesSeparateLaunchDock() {
  let native = NativeStationGeometry.nativePoint
  #expect(native(Vector3(1, 0, 0)).cross(native(Vector3(0, 1, 0))) == native(Vector3(0, 0, 1)))
  let mesh = NativeStationGeometry.waystation.mesh
  let face = mesh.faces[0]
  let normal = (mesh.vertices[face[1]] - mesh.vertices[face[0]])
    .cross(mesh.vertices[face[2]] - mesh.vertices[face[0]])
  // Proper Y180 preserves handedness; the explicit native surface convention
  // reverses the source triangle so native back-face culling sees the right side.
  #expect(normal == Vector3(0, -700, 0))
  // Actual source launch subentity applies X180 before native Y180.
  #expect(mesh.vertices[136] == Vector3(-112.80569, 46.72565, 210))
}

@Test func nativeRRSPlacementUsesCanonicalAnchorsAndRefusesUnsafeInputs() throws {
  var flight = FlightSimulationState()
  flight.enter(.init(galaxy: 0, system: 237), arriving: true)
  let anchors = try #require(flight.anchors)
  let half = anchors.planet.position * 0.5
  let expected =
    half * 0.7 + anchors.sun.position * (half.length / anchors.sun.position.length * 0.3)
  #expect(NativeStationGeometry.waystation.position(in: anchors) == expected)
  let hq = try #require(NativeStationGeometry.headquarters.position(in: anchors))
  #expect(abs(hq.length - (anchors.arrival - anchors.station.position).length) < 1e-8)
  #expect(abs(hq.dot(anchors.sun.position)) < 1e-5)
  #expect(abs(hq.dot(anchors.planet.position)) < 1e-5)
  #expect(hq.dot(anchors.sun.position.cross(anchors.planet.position)) > 0)
  for badSun in [Vector3(0, 0, 0), .init(.nan, 0, 1)] {
    let bad = SystemAnchors(
      system: anchors.system, station: anchors.station, arrival: anchors.arrival,
      planet: anchors.planet, sun: .init(position: badSun, radius: 1100))
    #expect(NativeStationGeometry.waystation.position(in: bad) == nil)
    #expect(NativeStationGeometry.headquarters.position(in: bad) == nil)
  }
  let parallel = SystemAnchors(
    system: anchors.system, station: anchors.station,
    arrival: anchors.arrival, planet: anchors.planet,
    sun: .init(position: anchors.planet.position * 2, radius: 1100))
  #expect(NativeStationGeometry.headquarters.position(in: parallel) == nil)
  let overlap = SystemAnchors(
    system: anchors.system, station: anchors.station,
    arrival: anchors.arrival, planet: .init(position: anchors.planet.position, radius: 100000),
    sun: anchors.sun)
  #expect(NativeStationGeometry.waystation.position(in: overlap) == nil)
  #expect(NativeStationGeometry.headquarters.position(in: overlap) == nil)
}

@Test func nativeRRSAperturesAndExitsCheckEveryEffectiveFlyableHull() throws {
  let ships = ShipCatalogue.all.filter { $0.game != nil }
  #expect(ships.count == 162)
  for ship in ships {
    var commander = Commander()
    commander.shipID = ship.id
    let player = commander.playerMesh
    for geometry in [NativeStationGeometry.waystation, .headquarters] {
      // Independent rectangular/diagonal half-plane calculation on the actual effective mesh.
      let fits = player.vertices.allSatisfy { vertex in
        if geometry.kind == .headquarters { return abs(vertex.x) < 125 && abs(vertex.y) < 62.5 }
        return abs(vertex.x) < 106.72374 && abs(vertex.y) < 106.72374
          && abs(vertex.x) + abs(vertex.y) < 150.93016
      }
      #expect(geometry.docking.fits(player) == fits, "\(ship.id) docking")
      #expect(geometry.launch.fits(player) == fits, "\(ship.id) launch")
      let exit = geometry.exit(for: player)
      #expect((exit != nil) == fits, "\(ship.id) exit refusal")
      if let exit {
        #expect(exit.orientation.x.cross(exit.orientation.y) == exit.orientation.z)
        #expect(exit.orientation.apply(.init(0, 0, 1)) == exit.direction)
        for vertex in player.vertices {
          let point = exit.center + exit.orientation.apply(vertex)
          let separation = point.dot(exit.direction) - geometry.bounds.support(exit.direction)
          #expect(separation >= exit.clearance - 1e-9, "\(ship.id) exit bound")
          #expect(
            (point + exit.direction * 10000).dot(exit.direction)
              > geometry.bounds.support(exit.direction), "\(ship.id) outward ray")
        }
      }
    }
  }
}

private func stationProbe(_ halfWidth: Double, _ halfHeight: Double) -> Mesh {
  Mesh(
    vertices: [
      .init(-halfWidth, -halfHeight, -1), .init(halfWidth, -halfHeight, -1),
      .init(halfWidth, halfHeight, 1), .init(-halfWidth, halfHeight, 1),
    ],
    faces: [[0, 1, 2], [0, 2, 3], [0, 3, 1], [1, 3, 2]])
}

@Test func nativeRRSAperturesRefuseBoundaryOversizeAndInvalidGeometry() {
  let way = NativeStationGeometry.waystation
  let hq = NativeStationGeometry.headquarters
  #expect(hq.docking.fits(stationProbe(124, 61)))
  #expect(!hq.docking.fits(stationProbe(125, 61)))
  #expect(!hq.docking.fits(stationProbe(124, 62.5)))
  #expect(!hq.docking.fits(stationProbe(124, 61), margin: 2))
  #expect(!way.docking.fits(stationProbe(100, 100)))
  #expect(way.docking.fits(stationProbe(75, 75)))
  #expect(!way.docking.fits(stationProbe(.infinity, 1)))
  #expect(!way.docking.fits(stationProbe(1, 1), margin: .nan))
  #expect(hq.exit(for: stationProbe(125, 1)) == nil)
  #expect(hq.exit(for: stationProbe(1, 1), clearance: 0) == nil)
  #expect(hq.exit(for: stationProbe(1, 1), clearance: .infinity) == nil)
}
