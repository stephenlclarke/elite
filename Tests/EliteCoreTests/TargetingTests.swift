import Foundation
import Testing

@testable import EliteCore

private func computerGame(_ tier: TargetingTier) -> Game {
  var game = Game(executive: false)
  game.launch()
  game.speed = 0
  game.commander.installTargetingComputer(tier)
  game.ecmControl = ECMControl()
  return game
}
@Test func computerTiersGateAcquisitionAndShipGroupsStayAheadOfStations() {
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
    let expected = [2, 1] + (tier >= .advanced ? [3] : []) + (tier >= .docking ? [0] : [])
    for id in expected {
      game.key("r")
      #expect(game.autoPilot.targetID == id)
    }
    game.key("r")
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
  game.key("r")
  #expect(game.autoPilot.targetID == 1)
  game.bodies[1].position = .init(0, 0, 100)
  game.key("r")
  #expect(game.autoPilot.targetID == 3)
  game.bodies.append(.init(id: 4, hull: .cobra, position: .init(0, 0, 200)))
  game.key("r")
  #expect(game.autoPilot.targetID == 2)
  game.bodies.removeAll { $0.id == 2 }
  game.key("r")
  #expect(game.autoPilot.targetID == 4)
  game.key("r")
  #expect(game.autoPilot.targetID == 4)
}
@Test func targetingUpgradesUseLaserRelatedPricesAndPersistOneEffectiveTier() async throws {
  var game = Game(executive: false)
  game.commander.system = try #require(game.systems.firstIndex { $0.technology >= 10 })
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
  #expect(TargetingTier.basic.price == 2 * Equipment.all[4].price)
  #expect(
    TargetingTier.military.price == 2 * Equipment.all.first { $0.name == "Military Laser" }!.price)
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
@Test func targetInformationDoesNotLeakHigherTierReadingsAndNeverUsesPlayerValues() {
  for tier in TargetingTier.allCases {
    var game = computerGame(tier)
    var target = SpaceBody(id: 17, hull: .constrictor, position: .init(0, 0, 1000), hostile: true)
    target.missiles = 2
    target.ecmEnabled = true
    game.bodies = [target]
    game.key("r")
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
    game.commander.equipment = [TargetingTier.basic.equipmentName]
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
  game.key("r")
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
@Test func autoDockBrakesFromHighSpeedAndHandlesOffAxisAndAwayFacingStarts() {
  for (position, angle, speed) in [
    (Vector3(600, 400, 2400), 0.7, 32.0), (Vector3(0, 0, 2400), Double.pi, 24.0),
  ] {
    var game = computerGame(.docking)
    var station = SpaceBody(id: 0, hull: .station, position: position)
    station.orientation.rotate(pitch: angle * 0.3, roll: 0, yaw: angle)
    game.bodies = [station]
    game.speed = speed
    game.key("r")
    var collision = false
    for _ in 0..<9000 where !game.docked {
      game.tick(delta: 0.02)
      collision = collision || game.message == "DOCKING COLLISION"
    }
    #expect(game.docked && !collision)
  }
}
