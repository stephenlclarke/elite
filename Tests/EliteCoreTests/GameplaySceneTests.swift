import Foundation
import Testing

@testable import EliteCore

@Test func gameplaySceneCreatesCanonicalFieldsAndIndependentActorIdentities() throws {
  var game = Game(executive: false)
  game.launch()
  let context = try #require(game.gameplayContext())
  #expect((2...4).contains(game.miningFields.count))
  #expect(Set(context.actors.map(\.identity)).count == game.bodies.count)
  #expect(!context.actors.contains { $0.identity == context.player.identity })
  #expect(context.player.legal.value == game.commander.legal)
  #expect(context.anchors.station.position == .init(0, 0, 0))
  #expect(context.actors.first { $0.hull == .cobra }?.npc?.role == .trader)
  #expect(context.actors.first { $0.hull == .cobra }?.legal.wanted == false)
  for rock in game.miningFields.flatMap(\.rocks) {
    #expect((rock.position - context.anchors.planet.position).length - rock.radius >= 4500)
    #expect((rock.position - context.anchors.sun.position).length - rock.radius >= 4400)
  }
}

@Test func gameplaySceneWorldAnchorsStayFixedWhileCameraMoves() throws {
  var game = Game(executive: false)
  game.launch()
  let original = try #require(game.gameplayContext())
  let fields = game.miningFields
  var controls = Controls()
  controls.pitch = 0.1
  controls.roll = 0.2
  controls.yaw = -0.1
  for _ in 0..<128 {
    game.tick(delta: 0.05, controls: controls)
  }
  let moved = try #require(game.gameplayContext())
  #expect((moved.anchors.station.position - original.anchors.station.position).length < 1e-6)
  #expect(moved.anchors.planet == original.anchors.planet)
  #expect(moved.anchors.sun == original.anchors.sun)
  #expect(game.miningFields == fields)
  for celestial in game.celestials {
    let world = game.commander.flightSimulation.pose.systemPoint(celestial.position)
    let anchor = celestial.kind == .planet ? moved.anchors.planet : moved.anchors.sun
    #expect((world - anchor.position).length < 1e-6)
  }
}

@Test func gameplayPhysicalClockFreezesOnExcludedScreensAndPause() {
  var game = Game(executive: false)
  game.launch()
  game.tick(delta: 0.1)
  let physical = game.commander.flightSimulation.physicalTime
  for screen in [Screen.title, .demo, .help, .gallery, .navigation, .handoff, .rumour, .mission] {
    game.screen = screen
    game.tick(delta: 0.1)
    #expect(game.commander.flightSimulation.physicalTime == physical)
  }
  game.screen = .front
  game.paused = true
  game.tick(delta: 0.1)
  #expect(game.commander.flightSimulation.physicalTime == physical)
  game.paused = false
  game.tick(delta: 0.1)
  #expect(abs(game.commander.flightSimulation.physicalTime - physical - 0.1) < 1e-12)
}

@Test func gameplayCurrentSaveRoundTripPreservesCommanderProperty() throws {
  var game = Game(executive: false)
  game.commander.credits = 123456
  game.commander.cargo[13] = 7
  game.commander.legal = 12
  game.launch()
  game.tick(delta: 0.1)
  let data = try JSONEncoder().encode(game.commander)
  let restored = try JSONDecoder().decode(Commander.self, from: data)
  #expect(restored == game.commander && restored.valid)
  #expect(restored.credits == 123456 && restored.cargo[13] == 7)
  #expect(restored.legal == 12 && restored.equipment == game.commander.equipment)
  #expect(restored.flightSimulation == game.commander.flightSimulation)
  #expect(restored.wantedCareers == game.commander.wantedCareers)
}

@Test func gameplayFieldGenerationDoesNotConsumeMissionRandomStream() {
  var game = Game(executive: false)
  var reference = game
  game.launch()
  for _ in 0..<64 {
    let actual = game.randomByte()
    let expected = reference.randomByte()
    #expect(actual == expected)
  }
}
