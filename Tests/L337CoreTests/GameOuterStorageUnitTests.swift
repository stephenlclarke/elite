import Foundation
import Testing

@testable import L337Core

struct GameOuterStorageUnitTests {
  @Test func outerRuntimeValueKeepsBoundedCopyFootprint() {
    let size = MemoryLayout<Game>.size
    let stride = MemoryLayout<Game>.stride
    let alignment = MemoryLayout<Game>.alignment
    print("Game value layout: size=\(size), stride=\(stride), alignment=\(alignment)")
    #expect(size > 0 && size <= 64)
  }

  @Test func retainedRuntimeValuesDetachNestedSceneUIAndCommanderWritesWithoutNewDefaults() throws {
    var original = Game(executive: false)
    var body = SpaceBody(id: 42, hull: .cobra, position: .init(1, 2, 3))
    body.physical = .init(
      identity: .init(system: .init(galaxy: 0, system: 7), visit: 1, entity: 42),
      population: .civilian, npc: nil)
    original.bodies = [body]
    original.contractBoard.selection = 2
    original.screenHistory = [.status]
    let retained = original
    let commander = original.commander
    let epoch = original.nativeStationRuntimeEpoch
    let inventory = original.inventoryContextEpoch
    let ecm = original.ecmControl.epoch
    let presentation = original.contractBoard.presentationGeneration
    let systems = original.systems
    var changed = original
    changed.energy -= 10
    changed.bodies[0].position.x += 9
    changed.bodies[0].physical?.velocity.y = 4
    changed.contractBoard.selection = 5
    changed.screenHistory.append(.front)
    changed.commander.credits += 1
    changed.systems.removeLast()

    #expect(original.bodies == [body] && retained.bodies == [body])
    #expect(changed.bodies[0].position.x == 10)
    #expect(changed.bodies[0].physical?.velocity.y == 4)
    #expect(original.contractBoard.selection == 2 && retained.contractBoard.selection == 2)
    #expect(changed.contractBoard.selection == 5)
    #expect(original.screenHistory == [.status] && changed.screenHistory == [.status, .front])
    #expect(original.commander == commander && retained.commander == commander)
    #expect(changed.commander.credits == commander.credits + 1)
    #expect(original.systems == systems && retained.systems == systems)
    #expect(changed.systems == Array(systems.dropLast()))
    #expect(changed.nativeStationRuntimeEpoch == epoch)
    #expect(changed.inventoryContextEpoch == inventory)
    #expect(changed.ecmControl.epoch == ecm)
    #expect(changed.contractBoard.presentationGeneration == presentation)

    original.bodies[0].position.z = 90
    original.contractBoard.scroll = 8
    #expect(changed.bodies[0].position.z == 3 && retained.bodies[0].position.z == 3)
    #expect(changed.contractBoard.scroll == 0 && retained.contractBoard.scroll == 0)
    var borrowedSnapshot = original.withReadOnlyStoredGame { game in copy game }
    borrowedSnapshot.message = "owned snapshot"
    #expect(original.message.isEmpty && retained.message.isEmpty)
    #expect(borrowedSnapshot.message == "owned snapshot")
  }

  @Test(arguments: ["assignment", "inout-replacement", "inout-unchanged"])
  func epochWritesResetOnlyTheirOwnedRuntimeAndPreserveRetainedSnapshots(mode: String) {
    var game = Game(executive: false)
    game.nativeOrbitalOutlookRuntime.reason = "retained outlook"
    game.nativeOriginalSurveyRuntime = .init(reason: "retained survey")
    game.nativeGlassMeridianRuntime = .init(reason: "retained clocks")
    let retained = game
    let previous = game.nativeStationRuntimeEpoch
    let replacement = UUID()
    func replace(_ value: inout UUID) { value = replacement }
    func retain(_ value: inout UUID) { _ = value }
    switch mode {
    case "assignment": game.nativeStationRuntimeEpoch = replacement
    case "inout-replacement": replace(&game.nativeStationRuntimeEpoch)
    default: retain(&game.nativeStationRuntimeEpoch)
    }
    #expect(game.nativeStationRuntimeEpoch == (mode == "inout-unchanged" ? previous : replacement))
    #expect(game.nativeOrbitalOutlookRuntime == NativeOrbitalOutlookRuntime())
    #expect(game.nativeOriginalSurveyRuntime == nil && game.nativeGlassMeridianRuntime == nil)
    #expect(retained.nativeStationRuntimeEpoch == previous)
    #expect(retained.nativeOrbitalOutlookRuntime.reason == "retained outlook")
    #expect(retained.nativeOriginalSurveyRuntime?.reason == "retained survey")
    #expect(retained.nativeGlassMeridianRuntime?.reason == "retained clocks")
    #expect(retained.commander == game.commander)
  }
}
