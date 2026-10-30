import Foundation
import Testing

@testable import L337Core

private func stationNavigationGame(_ position: Vector3) -> Game {
  var game = Game(executive: false)
  game.launch()
  game.speed = 0
  game.messageTime = 0
  game.bodies = [.init(id: 0, hull: .station, position: position)]
  return game
}

private func stationLabels(_ navigation: StationNavigation, layout: CockpitLayout, frame: Frame)
  -> [BitmapLabel]
{
  let texts = [
    navigation.distanceText, navigation.bearingText(layout: layout), navigation.elevationText,
  ]
  return frame.labels.filter { texts.contains($0.text) }
}

@Test func stationBearingsUseAllFourCamerasWithoutMirroringTheWorld() throws {
  var game = stationNavigationGame(.init(300, 200, 1000))
  let expected: [(Screen, Vector3, Double)] = [
    (.front, .init(300, 200, 1000), 1), (.rear, .init(-300, 200, -1000), -1),
    (.left, .init(1000, 200, -300), 1), (.right, .init(-1000, 200, 300), -1),
  ]
  let distance = game.bodies[0].position.length
  for (screen, position, horizontal) in expected {
    game.screen = screen
    let navigation = try #require(game.stationNavigation)
    #expect(navigation.viewPosition == position)
    #expect(navigation.distance == distance)
    #expect(navigation.bearingDegrees * horizontal > 0)
    #expect(navigation.elevationDegrees > 0)
    #expect(navigation.arrowDirection.x * horizontal > 0 && navigation.arrowDirection.y < 0)
    #expect(navigation.behind == (screen == .rear || screen == .left))
    let layout = CockpitLayout(game: game, width: 512, height: 518)
    let frame = Display.cockpit(game, width: 512, height: 518)
    let labels = stationLabels(navigation, layout: layout, frame: frame)
    #expect(labels.count == 3 && labels.allSatisfy { $0.ink == .yellow })
    #expect(navigation.bearingText(layout: layout).contains("BEHIND") == navigation.behind)
  }
}

@Test func aRealFlyPastMovesTheStationAcrossSideCamerasAndThenIntoTheRearView() throws {
  var game = stationNavigationGame(.init(1000, 200, 300))
  game.speed = 32
  let initial = game.bodies[0].position
  game.screen = .right
  let before = try #require(game.stationNavigation)
  #expect(before.viewPosition.x < 0 && before.viewPosition.z > 0)
  let layout = CockpitLayout(game: game, width: 512, height: 518)
  #expect(layout.projection.point(before.viewPosition).x < layout.projection.center.x)
  for _ in 0..<6 { game.tick(delta: 0.1) }
  let position = try #require(game.bodies.first { $0.id == 0 }).position
  #expect(position.x == initial.x && position.y == initial.y && position.z < 0)
  #expect(abs(position.z - (initial.z - 32 * 18 * 0.6)) < 1e-8)
  let after = try #require(game.stationNavigation)
  #expect(after.viewPosition.x > 0 && after.viewPosition.z > 0)
  #expect(layout.projection.point(after.viewPosition).x > layout.projection.center.x)
  for screen in [Screen.front, .rear, .left, .right] {
    game.screen = screen
    let navigation = try #require(game.stationNavigation)
    #expect(navigation.viewPosition == game.viewPosition(position))
    #expect(navigation.distance == position.length)
    if screen == .front { #expect(navigation.behind) }
    if screen == .rear { #expect(!navigation.behind && navigation.bearingDegrees < 0) }
    if screen == .left { #expect(navigation.behind && navigation.bearingDegrees < 0) }
    if screen == .right { #expect(!navigation.behind && navigation.bearingDegrees > 0) }
  }
}

@Test func stationNavigationPersistsBeyondScannerRangeWithoutRevealingOtherTargets() throws {
  var game = stationNavigationGame(.init(200_000, -80_000, -120_000))
  game.bodies.append(.init(id: 7, hull: .constrictor, position: .init(100, 0, 1000), hostile: true))
  game.weaponsTargetID = 7
  #expect(game.commander.targetingTier == nil && game.targetInformation == nil)
  for screen in [Screen.front, .rear, .left, .right] {
    game.screen = screen
    let navigation = try #require(game.stationNavigation)
    #expect(navigation.distance > 200_000 && navigation.stationID == 0)
    let layout = CockpitLayout(game: game, width: 512, height: 518)
    let frame = Display.cockpit(game, width: 512, height: 518)
    #expect(stationLabels(navigation, layout: layout, frame: frame).count == 3)
    #expect(frame.labels.contains { $0.text.contains("units") && $0.text.hasPrefix("STATION") })
    #expect(!frame.labels.contains { $0.text.contains("Constrictor") || $0.text.contains("#7") })
  }
}

@Test func stationChoiceUsesSelectedStationThenMainThenNearestAndRejectsDeadOrMissingBodies() throws
{
  var game = stationNavigationGame(.init(0, 0, 50_000))
  let outpost = SpaceBody(id: 9, hull: .station, position: .init(500, 100, 1000))
  game.bodies.append(outpost)
  #expect(game.stationNavigation?.stationID == 0)
  game.autoPilot.cycle([outpost], frontIDs: [], signature: "station-navigation")
  #expect(game.stationNavigation?.stationID == 9)
  game.autoPilot.disengage()
  game.bodies[0].energy = 0
  #expect(game.stationNavigation?.stationID == 9)
  game.bodies.append(.init(id: 8, hull: .station, position: .init(-500, 100, 1000)))
  #expect(game.stationNavigation?.stationID == 8)
  game.bodies = [.init(id: 0, hull: .cobra, position: .init(0, 0, 100))]
  #expect(game.stationNavigation == nil)
  game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 100))]
  game.bodies[0].energy = 0
  #expect(game.stationNavigation == nil)
  let empty = Display.cockpit(game, width: 512, height: 518)
  #expect(!empty.labels.contains { $0.text.hasPrefix("STATION") })
  game.bodies[0].energy = 100
  game.bodies[0].position.x = .nan
  #expect(game.stationNavigation == nil)
  game.bodies = []
  #expect(game.stationNavigation == nil)
  game = stationNavigationGame(.init(0, 0, 500))
  game.screen = .status
  #expect(game.stationNavigation == nil)
  game.screen = .front
  game.docked = true
  #expect(game.stationNavigation == nil)
}

@Test func stationCueAvoidsTargetCameraAndFlightOverlaysAtTheSmallestWindow() throws {
  var game = stationNavigationGame(.init(30_000, 40_000, -50_000))
  try game.commander.grantEquipment(
    TargetingTier.military.equipmentName, at: .targetingCore,
    provenance: .grant("station cue targeting fixture"))
  #expect(game.commander.equipmentInventory != nil && game.commander.targetingTier == .military)
  let target = SpaceBody(id: 7, hull: .cobra, position: .init(100, 0, 1000))
  game.bodies.append(target)
  game.autoPilot.cycle([target], frontIDs: [7], signature: "station-navigation")
  game.targetPanelExpanded = true
  game.paused = true
  game.dockingComputer = true
  game.jumpCountdown = 9
  game.message = "TEST FLIGHT MESSAGE"
  game.messageTime = 5
  for (width, height) in [(512.0, 518.0), (768, 768), (1512, 982)] {
    let navigation = try #require(game.stationNavigation)
    let layout = CockpitLayout(game: game, width: width, height: height)
    let frame = Display.cockpit(game, width: width, height: height)
    let labels = stationLabels(navigation, layout: layout, frame: frame)
    #expect(labels.count == 3)
    for label in labels {
      #expect(label.bounds.x >= 12 && label.bounds.maxX <= width - 12)
      #expect(label.bounds.y >= layout.flightClip.y && label.bounds.maxY < layout.flightClip.maxY)
      for other in frame.labels where label != other {
        #expect(
          label.bounds.maxX <= other.bounds.x || other.bounds.maxX <= label.bounds.x
            || label.bounds.maxY <= other.bounds.y || other.bounds.maxY <= label.bounds.y,
          "Station label must not overlap \(other.text)")
      }
    }
  }
}

@Test func stationCompassShowsDirectlyAheadAsternVerticalAndCrowdedHeaderFallback() throws {
  var game = stationNavigationGame(.init(0, 0, 16_000))
  var navigation = try #require(game.stationNavigation)
  #expect(navigation.arrowDirection == .init(0, 0))
  game.bodies[0].position = .init(0, 0, -16_000)
  navigation = try #require(game.stationNavigation)
  #expect(navigation.arrowDirection == .init(1, 0))
  game.bodies[0].position = .init(0, -16_000, 0)
  navigation = try #require(game.stationNavigation)
  #expect(navigation.arrowDirection == .init(0, 1) && navigation.elevationText == "DOWN 90 DEG")
  game.bodies[0].position = .init(20_000, 30_000, -40_000)
  navigation = try #require(game.stationNavigation)
  let layout = CockpitLayout(game: game, width: 512, height: 518)
  var frame = Frame()
  frame.canvas = .init(x: 0, y: 0, width: 512, height: 518)
  frame.flightClip = layout.flightClip
  frame.rasterizeGraphics = false
  frame.graphics.append(
    .panel(
      .init(
        vertices: [
          .init(0, 24), .init(512, 24), .init(512, layout.flightClip.maxY),
          .init(0, layout.flightClip.maxY),
        ], colour: Ink.black.rawValue)))
  Display.stationDirection(game, layout: layout, into: &frame)
  let label = try #require(frame.labels.first)
  #expect(label.y == 8 && label.text.contains("BEHIND") && label.text.contains("R"))
  #expect(label.text.contains("U") && label.bounds.maxX <= 500 && label.bounds.x > 100)
  for distance in [50.0, 2_000_000, 2_000_000_000] {
    game.bodies[0].position = .init(0, 0, distance)
    #expect(try #require(game.stationNavigation).distanceText.count <= 30)
  }
}

@Test func stationCompassCentersWhenTinyAlignmentResidualsReadAsZeroDegrees() throws {
  var game = stationNavigationGame(.init(-0.00001, 0.00002, 526))
  let layout = CockpitLayout(game: game, width: 512, height: 518)
  for position in [Vector3(-0.00001, 0.00002, 526), .init(4, -4, 526)] {
    game.bodies[0].position = position
    let navigation = try #require(game.stationNavigation)
    #expect(navigation.bearingText(layout: layout) == "AHEAD 0 DEG")
    #expect(navigation.elevationText == "LEVEL 0 DEG")
    #expect(navigation.arrowDirection == .init(0, 0))
    let frame = Display.cockpit(game, width: 512, height: 518)
    #expect(stationLabels(navigation, layout: layout, frame: frame).count == 3)
  }
  for position in [Vector3(5, 0, 526), .init(0, -5, 526), .init(-4, 4, -526)] {
    game.bodies[0].position = position
    #expect(try #require(game.stationNavigation).arrowDirection != .init(0, 0))
  }
  game.bodies[0].position = .init(0, 0, -526)
  #expect(try #require(game.stationNavigation).arrowDirection == .init(1, 0))
}
