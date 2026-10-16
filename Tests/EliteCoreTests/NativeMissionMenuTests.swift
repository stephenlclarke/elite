import AppKit
import EliteCore
import Testing

@testable import EliteMac

@Suite(.serialized)
struct NativeMissionMenuTests {
  @MainActor @Test func installationPreservesExistingAcceleratorsAndIsIdempotent() {
    let menu = NSMenu()
    let pause = NSMenuItem(title: "Pause", action: nil, keyEquivalent: "p")
    pause.keyEquivalentModifierMask = .command
    menu.addItem(pause)
    let target = NativeMissionMenu(
      snapshot: { nil },
      enqueue: { _ in
        // Installation with no snapshot must not enqueue an action.
        Issue.record("Unexpected mission menu action")
      })
    target.install(in: menu)
    target.install(in: menu)
    #expect(menu.items.count == MissionUIAction.allCases.count + 1)
    #expect(menu.items.last === pause)
    #expect(pause.keyEquivalent == "p" && pause.keyEquivalentModifierMask == .command)
    for item in menu.items.dropLast() {
      #expect(!item.title.isEmpty)
      #expect(item.keyEquivalent.isEmpty)
      #expect(!target.validateMenuItem(item))
    }
    #expect(!target.choose(.gallery))
  }

  @MainActor @Test func choiceCapturesProofAndRechecksLatestAvailabilityWithoutMutatingGame() {
    var game = Game(executive: false)
    game.screen = .status
    game.docked = true
    let commander = game.commander
    var intents: [MissionUIIntent] = []
    let target = NativeMissionMenu(snapshot: { game }, enqueue: { intents.append($0) })
    #expect(target.choose(.contracts))
    #expect(intents == [.init(action: .contracts, presentation: game.scriptPagePresentation)])
    #expect(game.commander == commander && game.screen == .status)
    game.docked = false
    #expect(!target.choose(.contracts))
    #expect(intents.count == 1)
    let menu = NSMenu()
    target.install(in: menu)
    let contracts = menu.items.first { $0.representedObject as? String == "contracts-open" }
    #expect(contracts.map { target.validateMenuItem($0) } == false)
    #expect(target.choose(.library))
    #expect(intents.last?.action == .library)
  }
}
