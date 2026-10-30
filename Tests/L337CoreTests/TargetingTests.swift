import Foundation
import Testing

@testable import L337Core

private func computerGame(_ tier: TargetingTier) -> Game {
  var game = Game(executive: false)
  game.commander.installTargetingComputer(tier)
  game.launch()
  game.speed = 0
  #expect(game.commander.targetingTier == tier)
  game.ecmControl = ECMControl()
  return game
}

@Test(arguments: TargetingTier.allCases)
func legacyUnadoptedTargetsUseStatusFallbackWithoutInventingWorkAuthority(tier: TargetingTier)
  throws
{
  var game = computerGame(tier)
  for (hull, hostile) in [
    (Hull.cobra, false), (.cobra, true), (.cargo, false), (.asteroid, false),
    (.missile, false), (.station, false),
  ] {
    let body = SpaceBody(id: 90, hull: hull, position: .init(0, 0, 500), hostile: hostile)
    game.bodies = [body]
    game.weaponsTargetID = body.id
    #expect(game.workGuidance == nil && body.physical == nil)
    let flightBefore = game.commander.flightSimulation
    let info = game.targetInformation
    if hull == .station && tier < .docking {
      #expect(info == nil)
    } else if tier < .identification {
      #expect(info?.status == nil && info?.fields.isEmpty == true)
    } else {
      let expected = hull == .station ? game.autoPilot.status : hostile ? "Hostile" : "Neutral"
      #expect(info?.status == expected)
      let panelInfo = try #require(info)
      let cockpit = CockpitLayout(game: game, width: 512, height: 518)
      let panel = TargetPanelLayout(game: game, info: panelInfo, cockpit: cockpit)
      let statusTop = panel.y + panel.row * Double(panel.headings.count)
      let statusBottom = statusTop + panel.row * Double(panel.statuses.count)
      let expectedInk: Ink = hostile ? .red : .cyan
      let frame = Display.cockpit(game, width: 512, height: 518)
      let statusRows = frame.labels.filter {
        $0.x == panel.x && $0.y >= statusTop && $0.y < statusBottom
      }.sorted { $0.y < $1.y }
      #expect(!statusRows.isEmpty && statusRows.allSatisfy { $0.ink == expectedInk })
      #expect(statusRows.map(\.text).joined(separator: " ") == expected + " I: Detail")
      #expect(
        statusRows.allSatisfy {
          $0.x >= 256 && $0.y >= 32 && $0.bounds.maxX <= 512
            && $0.bounds.maxY <= frame.flightClip.maxY
        })
    }
    // Looking at an unadopted target must not allocate a physical actor or a controller.
    #expect(game.bodies[0].physical == nil && game.workGuidance == nil)
    #expect(game.commander.flightSimulation == flightBefore)
  }
}

@Test func workStatusRequiresARealMatchingPhysicalIdentity() throws {
  var game = computerGame(.military)
  let allocated = game.commander.flightSimulation.allocateActor()
  let parent = try #require(allocated)
  let allocatedOther = game.commander.flightSimulation.allocateActor()
  let other = try #require(allocatedOther)
  var body = SpaceBody(id: 90, hull: .cobra, position: .init(0, 0, 500), hostile: true)
  // A synthetic controller isolates disclosure; this is not a work-motion or engagement fixture.
  game.workGuidance = .init(
    parent: parent, mode: .hold(.salvage),
    surface: .init(point: .init(0, 0, 500), normal: .init(0, 0, -1), radius: nil, section: nil),
    collectionOffset: 0,
    controller: .init(parent: parent, wreck: nil, category: .wreck),
    scoop: .init(parent: parent), velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0))
  game.workGuidance?.status = "HOLDING WORK TARGET"
  for identity in [ActorIdentity?.some(parent), .some(other), .none] {
    body.physical = identity.map { .init(identity: $0, population: .civilian) }
    let info = game.information(for: body)
    #expect(info?.status == (identity == parent ? "HOLDING WORK TARGET" : "Hostile"))
  }
  game.workGuidance = nil
  body.physical = .init(identity: parent, population: .civilian)
  #expect(game.information(for: body)?.status == "Hostile")
}

@Test func computerTiersGateAcquisitionAndShipGroupsStayAheadOfStations() throws {
  for tier in TargetingTier.allCases {
    var game = computerGame(tier)
    game.screen = .left
    game.bodies = [
      .init(id: 0, hull: .station, position: .init(0, 0, 400)),
      .init(id: 1, hull: .cobra, position: .init(0, 0, 1800)),
      .init(id: 2, hull: .viper, position: .init(0, 0, 900)),
      .init(id: 3, hull: .sidewinder, position: .init(0, 0, -100)),
      .init(id: 4, hull: .cargo, position: .init(0, 0, 50)),
      .init(id: 5, hull: .asteroid, position: .init(0, 0, 50)),
    ]
    game.ensurePhysicalActors()
    let stations = game.bodies.filter { $0.hull == .station && $0.energy > 0 }.sorted {
      $0.position.length == $1.position.length
        ? $0.id < $1.id : $0.position.length < $1.position.length
    }
    try #require(stations.contains { $0.id == 0 })
    try #require(stations.contains { $0.nativeStationIdentity != nil })
    for station in stations where station.nativeStationIdentity != nil {
      try #require(game.nativeStationBodyIsCurrent(station))
    }
    try #require(game.commander.targetingTier == tier)
    let expected =
      [2, 1] + (tier >= .advanced ? [3] : [])
      + (tier >= .docking ? stations.map(\.id) : [])
    var visited: [Int] = []
    for id in expected {
      game.key("tab")
      #expect(game.autoPilot.targetID == id)
      if let target = game.autoPilot.targetID { visited.append(target) }
    }
    #expect(visited == expected && Set(visited).count == expected.count)
    game.key("tab")
    #expect(game.autoPilot.targetID == 2)
  }
}
@Test func frontVisibilityUsesRenderedEdgesAndChangingMembershipNeverRepeatsVisitedShips() {
  var game = computerGame(.advanced)
  let layout = CockpitLayout(game: game, width: game.viewportWidth, height: game.viewportHeight)
  let edgeX = game.viewportWidth / 2 * 1000 / layout.projection.focal
  let visibleEdge = SpaceBody(id: 1, hull: .cobra, position: .init(edgeX + 10, 0, 1000))
  #expect(!layout.flightClip.contains(layout.projection.point(visibleEdge.position)))
  #expect(Display.visibleInFront(visibleEdge, game: game, layout: layout))
  let outside = SpaceBody(id: 2, hull: .cobra, position: .init(edgeX + 100, 0, 1000))
  #expect(!Display.visibleInFront(outside, game: game, layout: layout))
  game.bodies = [visibleEdge, outside, .init(id: 3, hull: .viper, position: .init(0, 0, -500))]
  game.key("tab")
  #expect(game.autoPilot.targetID == 1)
  game.bodies[1].position = .init(0, 0, 100)
  game.key("tab")
  #expect(game.autoPilot.targetID == 3)
  game.bodies.append(.init(id: 4, hull: .cobra, position: .init(0, 0, 200)))
  game.key("tab")
  #expect(game.autoPilot.targetID == 2)
  game.bodies.removeAll { $0.id == 2 }
  game.key("tab")
  #expect(game.autoPilot.targetID == 4)
  game.key("tab")
  #expect(game.autoPilot.targetID == 4)
}
@Test func targetingUpgradesUseLaserRelatedPricesAndPersistOneEffectiveTier() async throws {
  var game = Game(executive: false)
  let computers = Equipment.all.filter { TargetingTier.from($0.name) != nil }
  let requiredLevel = try #require(computers.map(\.requiredTechnologyLevel).max())
  game.commander.system = try #require(
    game.systems.first { !$0.isPlugh && $0.technology >= requiredLevel }?.id)
  game.commander.credits = 1_000_000
  for tier in TargetingTier.allCases {
    game.selection = try #require(Equipment.all.firstIndex { $0.name == tier.equipmentName })
    let before = game.commander.credits
    game.purchase()
    #expect(game.commander.targetingTier == tier && game.commander.credits == before - tier.price)
    #expect(game.commander.equipment.filter { TargetingTier.from($0) != nil }.count == 1)
    game.purchase()
    #expect(game.commander.credits == before - tier.price)
  }
  #expect(TargetingTier.basic.price == 8000)
  #expect(TargetingTier.military.price == 120000)
  game.commander.equipment.insert(TargetingTier.basic.equipmentName)
  #expect(game.commander.targetingTier == .military)
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: url)
  try await runtime.load(from: url)
  let commander = await runtime.snapshot().commander
  #expect(
    commander.targetingTier == .military
      && !commander.equipment.contains(TargetingTier.basic.equipmentName))
}
@Test func targetInformationDoesNotLeakHigherTierReadingsAndNeverUsesPlayerValues() throws {
  for tier in TargetingTier.allCases {
    var game = computerGame(tier)
    var target = SpaceBody(id: 17, hull: .constrictor, position: .init(0, 0, 1000), hostile: true)
    target.missiles = 2
    target.ecmEnabled = true
    game.bodies = [target]
    game.ensurePhysicalActors()
    // This disclosure fixture intentionally has no observed resource readings.
    game.bodies[0].physical?.npc?.resources = nil
    game.key("tab")
    let info = game.targetInformation
    #expect(info?.id == 17)
    #expect((info?.model != nil) == (tier >= .identification))
    #expect((info?.fields.contains { $0.label == "Origin" } ?? false) == (tier >= .pirate))
    #expect((info?.fields.contains { $0.label == "Missiles" } ?? false) == (tier == .military))
    if tier == .military {
      #expect(info?.fields.first { $0.label == "Missiles" }?.value == "2")
      #expect(info?.fields.first { $0.label == "Front shield" }?.value == "Unknown")
      #expect(info?.fields.first { $0.label == "Rear shield" }?.value == "Unknown")
      #expect(info?.fields.first { $0.label == "Fuel" }?.value == "Unknown")
      game.ecmFrames = 20
      game.enemyECMSource = 17
      #expect(game.targetInformation?.fields.first { $0.label == "ECM active" }?.value == "Yes")
    }
    let inventory = try #require(game.commander.equipmentInventory)
    let core = try #require(game.commander.fittedEquipment(at: .targetingCore))
    try game.commander.storeEquipment(core, expectedRevision: inventory.revision)
    try game.commander.grantEquipment(
      TargetingTier.basic.equipmentName, at: .targetingCore,
      provenance: .grant("disclosure downgrade fixture"))
    #expect(game.commander.targetingTier == .basic)
    #expect(game.targetInformation?.fields.isEmpty == true && game.targetInformation?.model == nil)
    game.bodies = []
    game.tick(delta: 0.01)
    #expect(game.targetInformation == nil && game.weaponsTargetID == nil)
  }
}
@Test func targetCameraIsLiveBoundedAndIndependentOfPlayerViewAndSimulation() {
  var game = computerGame(.military)
  game.commander.shipDisplayStyle = .whiteWireframe
  game.bodies = [.init(id: 1, hull: .cobra, position: .init(0, 0, 1000))]
  game.ensurePhysicalActors()
  // An explicitly unknown route must remain unknown in the independent camera.
  game.bodies[0].physical?.npc?.routeProvenance = nil
  game.key("tab")
  game.screen = .rear
  game.targetPanelExpanded = true
  let original = game.bodies
  for width in [512.0, 768, 1512] {
    let frame = Display.cockpit(game, width: width, height: 768)
    #expect(frame.labels.contains { $0.text == "Cobra Mk III #1" })
    #expect(frame.labels.contains { $0.text == "Origin: Unknown" })
    for label in frame.labels { #expect(label.bounds.maxX <= width && label.bounds.maxY <= 768) }
    let preview = frame.shipLines
    #expect(!preview.isEmpty)
    game.bodies[0].rotation += 0.4
    let rotated = Display.cockpit(game, width: width, height: 768)
    #expect(rotated.shipLines != preview && game.screen == .rear && game.time == 0)
  }
  #expect(game.bodies[0].position == original[0].position)
  game.key("i")
  #expect(game.targetPanelExpanded == false)
  #expect(
    !Display.cockpit(game, width: 1512, height: 768).labels.contains {
      $0.text == "Origin: Unknown"
    })
}
@Test func autoDockBrakesFromHighSpeedAndHandlesOffAxisAndAwayFacingStarts() throws {
  for (position, angle, speed) in [
    (Vector3(600, 400, 2400), 0.7, 32.0), (Vector3(0, 0, 2400), Double.pi, 24.0),
  ] {
    var game = computerGame(.docking)
    let anchor = try #require(
      game.currentNativeMainStationAnchor(at: game.commander.flightSimulation.physicalTime))
    var orientation = Basis3()
    orientation.rotate(pitch: angle * 0.3, roll: 0, yaw: angle)
    // The existing native approach fixture uses this inverse observer transform.
    let camera = anchor.orientation.composed(with: orientation.transposed)
    NativeStationTestFixture.reframe(
      &game, to: .init(position: anchor.position - camera.apply(position), orientation: camera))
    let station = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
    try #require(station.physical?.identity == anchor.identity)
    #expect((station.position - position).length < 1e-8)
    for axis in [Vector3(1, 0, 0), .init(0, 1, 0), .init(0, 0, 1)] {
      #expect((station.orientation.apply(axis) - orientation.apply(axis)).length < 1e-8)
    }
    game.speed = speed
    for _ in 0..<(game.bodies.count * 2) {
      game.key("tab")
      if game.autoPilot.targetActor == anchor.identity { break }
    }
    try #require(game.autoPilot.targetID == 0 && game.autoPilot.targetActor == anchor.identity)
    var collision = false
    for _ in 0..<9000 where !game.docked {
      game.tick(delta: 0.02)
      collision = collision || game.message == "DOCKING COLLISION"
    }
    #expect(game.docked && !collision)
    #expect(game.nativeMainStationDockEvidenceIsCurrent)
  }
}

@Test(arguments: [Screen.front, .rear, .left, .right])
func renderedVertexViewsPreserveIndependentNearPlaneAndViewportClipWitness(screen: Screen) {
  var game = Game(executive: false)
  game.screen = screen
  game.commander.shipDisplayStyle = .whiteWireframe
  var orientation = Basis3()
  switch screen {
  case .rear:
    orientation.x = .init(-1, 0, 0)
    orientation.z = .init(0, 0, -1)
  case .left:
    orientation.x = .init(0, 0, 1)
    orientation.z = .init(-1, 0, 0)
  case .right:
    orientation.x = .init(0, 0, -1)
    orientation.z = .init(1, 0, 0)
  default: break
  }
  var body = SpaceBody(
    id: 904, hull: .cobra, position: orientation.apply(.init(3, -2, 0)))
  body.orientation = orientation
  let mesh = Mesh(
    vertices: [.init(-23, 2, 0), .init(-5, 6, 4), .init(7, -2, 4)],
    faces: [[0, 1, 2]], preserveWinding: true)
  var frame = Frame()
  frame.rasterizeGraphics = false
  frame.canvas = .init(x: 0, y: 0, width: 100, height: 100)
  frame.flightClip = frame.canvas
  let projection = FlightProjection(center: .init(50, 50), focal: 10)
  Display.draw(body, game: game, into: &frame, projection: projection, mesh: mesh)
  // Every view yields A=(-20,0,0), B=(-2,4,4), C=(10,-4,4).
  // Near-plane intersections project to (-105,40) and (-75,60); the viewport clips x to 0.
  let expected: [WireLine] = [
    .init(x0: 0, y0: 40, x1: 45, y1: 40, ink: .white),
    .init(x0: 45, y0: 40, x1: 75, y1: 60, ink: .white),
    .init(x0: 75, y0: 60, x1: 0, y1: 60, ink: .white),
  ]
  #expect(frame.shipLines == expected)
  let afterScreen = game.screen
  let afterStyle = game.withReadOnlyCommander { $0.shipDisplayStyle }
  let afterTime = game.time
  #expect(afterScreen == screen && afterStyle == .whiteWireframe && afterTime == 0)
}

@Test(arguments: ShipDisplayStyle.allCases)
func frontVisibilityPreservesGenuineNativeStationGeometryAndRevokedAuthority(
  style: ShipDisplayStyle
) throws {
  var game = try NativeStationTestFixture.launched()
  game.commander.shipDisplayStyle = style
  game.screen = .left
  let stationIDs = game.bodies.filter { $0.nativeStationIdentity != nil }.map(\.id)
  try #require(stationIDs.count == 2)
  for id in stationIDs {
    let original = try #require(game.bodies.first { $0.id == id })
    var pose = ShipPose()
    pose.position =
      game.commander.flightSimulation.pose.systemPoint(original.position)
      - Vector3(0, 0, 10000)
    NativeStationTestFixture.reframe(&game, to: pose)
    let station = try #require(game.bodies.first { $0.id == id })
    let identity = try #require(station.nativeStationIdentity)
    let physical = try #require(station.physical)
    let world = try #require(game.commander.nativeStations)
    let flight = game.commander.flightSimulation
    let layout = CockpitLayout(game: game, width: game.viewportWidth, height: game.viewportHeight)
    try #require(game.nativeStationBodyIsCurrent(station))
    #expect(Display.visibleInFront(station, game: game, layout: layout))
    let visibleWorld = game.commander.nativeStations
    let visibleFlight = game.commander.flightSimulation
    #expect(visibleWorld == world && visibleFlight == flight)

    // Retaining source markers cannot substitute for the actual admitted body binding.
    var unbound = station
    unbound.id += 10000
    #expect(!Display.visibleInFront(unbound, game: game, layout: layout))
    game.commander.nativeStations = nil
    #expect(!Display.visibleInFront(station, game: game, layout: layout))
    #expect(game.commander.nativeStations == nil)
    game.commander.nativeStations = world
    try game.commander.nativeStations?.ledger.destroy(
      identity, binding: .init(actor: physical.identity, bodyID: station.id))
    let destroyed = game.commander.nativeStations
    #expect(!Display.visibleInFront(station, game: game, layout: layout))
    let afterDestroyed = game.commander.nativeStations
    #expect(afterDestroyed == destroyed)
    game.commander.nativeStations = world
    #expect(Display.visibleInFront(station, game: game, layout: layout))
    let afterWorld = game.commander.nativeStations
    let afterFlight = game.commander.flightSimulation
    let afterStyle = game.commander.shipDisplayStyle
    #expect(afterWorld == world && afterFlight == flight)
    #expect(game.screen == .left && afterStyle == style)
  }
}

private final class FrontVisibilityRenderFixture {
  var game = Game(executive: false)
}

struct FrontVisibilityRenderUnitTests {
  @Test(
    arguments: [Screen.front, .rear, .left, .right, .demo, .title], ShipDisplayStyle.allCases)
  func frontRenderOverridePreservesOutputAndCallerState(screen: Screen, style: ShipDisplayStyle) {
    let fixture = FrontVisibilityRenderFixture()
    fixture.game.screen = .front
    fixture.game.commander.shipDisplayStyle = style
    let body = SpaceBody(id: 906, hull: .cobra, position: .init(0, 0, 1000))
    let layout = CockpitLayout(game: fixture.game, width: 512, height: 518)
    func emptyFrame() -> Frame {
      var frame = Frame()
      frame.rasterizeGraphics = false
      frame.canvas = .init(x: 0, y: 0, width: layout.width, height: layout.height)
      frame.flightClip = layout.flightClip
      return frame
    }
    var expected = emptyFrame()
    Display.draw(body, game: fixture.game, into: &expected, projection: layout.projection)
    let expectedVisibility = !expected.shipLines.isEmpty || expected.hasShipSurfaces
    #expect(expectedVisibility)

    fixture.game.screen = screen
    let originalTime = fixture.game.time
    var actual = emptyFrame()
    Display.draw(
      body, game: fixture.game, into: &actual, projection: layout.projection, screen: .front)
    #expect(actual == expected)
    #expect(Display.visibleInFront(body, game: fixture.game, layout: layout) == expectedVisibility)
    #expect(fixture.game.screen == screen && fixture.game.time == originalTime)
    #expect(fixture.game.withReadOnlyCommander { $0.shipDisplayStyle } == style)

    if screen == .demo || screen == .title {
      // Ordinary startup drawing still forces panels without changing the saved flight preference.
      var startup = emptyFrame()
      Display.draw(body, game: fixture.game, into: &startup, projection: layout.projection)
      #expect(fixture.game.withReadOnlyCommander { $0.shipDisplayStyle } == style)
      fixture.game.screen = .front
      fixture.game.commander.shipDisplayStyle = .shadedPanels
      var shaded = emptyFrame()
      Display.draw(body, game: fixture.game, into: &shaded, projection: layout.projection)
      #expect(startup == shaded && startup.hasShipSurfaces)
    }
  }

}
