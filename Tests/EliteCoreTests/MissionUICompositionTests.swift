import Foundation
import Testing

@testable import EliteCore

struct MissionUICompositionTests {
  @Test func contractsRequireAnAvailableMainStationAndLibraryRemainsReadable() {
    var game = Game(executive: false)
    game.screen = .status
    game.docked = true
    #expect(MissionUIAction.contracts.isEnabled(in: game))
    game.dockedAtMainStation = false
    #expect(!MissionUIAction.contracts.isEnabled(in: game))
    game.docked = false
    game.screen = .front
    #expect(!MissionUIAction.contracts.isEnabled(in: game))
    #expect(MissionUIAction.gallery.isEnabled(in: game))
    #expect(!MissionUIAction.contacts.isEnabled(in: game))
    #expect(!MissionUIAction.rumours.isEnabled(in: game))
    game.paused = true
    #expect(MissionUIAction.library.isEnabled(in: game))
    #expect(!MissionUIAction.gallery.isEnabled(in: game))
  }

  @Test func libraryReturnsToFlightWithoutChangingCommanderOrNumberedNavigation() {
    var game = Game(executive: false)
    game.screen = .rear
    game.docked = false
    let commander = game.commander
    #expect(game.interfaceKey("library-open"))
    #expect(game.screen == .library)
    #expect(game.interfaceKey("escape"))
    #expect(game.screen == .rear)
    #expect(game.commander == commander)
    #expect(Game.numberedScreen(1, docked: true) == nil)
    #expect(Game.numberedScreen(2, docked: true) == nil)
    #expect(Game.numberedScreen(7, docked: true) == .buy)
    #expect(Game.numberedScreen(6, docked: false) == .system)
  }

  @Test func staleMenuIntentCannotCrossRuntimeEpochOrContractAvailability() {
    var game = Game(executive: false)
    game.screen = .status
    game.docked = true
    let intent = MissionUIIntent(action: .contracts, presentation: game.scriptPagePresentation)
    #expect(intent.isCurrent(in: game))
    let stale = MissionUIIntent(
      action: .contracts, presentation: .init(epoch: UUID(), page: nil))
    #expect(!stale.isCurrent(in: game))
    game.docked = false
    #expect(!intent.isCurrent(in: game))
  }

  @Test func actorRejectsStaleIntentThenDispatchesCurrentReadOnlyLibraryIntent() async {
    var game = Game(executive: false)
    game.screen = .status
    let runtime = GameRuntime(game: game)
    let stale = MissionUIIntent(
      action: .library, presentation: .init(epoch: UUID(), page: nil))
    await runtime.missionUICommand(stale)
    let unchanged = await runtime.snapshot()
    #expect(unchanged.screen == .status && unchanged.commander == game.commander)
    await runtime.missionUICommand(
      .init(action: .library, presentation: unchanged.scriptPagePresentation))
    let opened = await runtime.snapshot()
    #expect(opened.screen == .library && opened.commander == game.commander)
  }

  @Test func missionPanelsUseResponsivePresentationAtSupportedViewportSizes() {
    var game = Game(executive: false)
    for screen in [Screen.library, .contracts] {
      game.screen = screen
      for size in [512.0, 768.0, 1512.0, 3600.0] {
        let frame = Display.presentation(game, width: size, height: size)
        #expect(frame.responsive)
        #expect(frame.canvas.width == size && frame.canvas.height == size)
        #expect(!frame.labels.isEmpty)
        #expect(frame.inventoryInteraction == nil)
      }
    }
  }
}
