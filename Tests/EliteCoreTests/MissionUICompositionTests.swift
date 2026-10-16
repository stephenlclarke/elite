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
    let opened = game.interfaceKey("library-open")
    #expect(opened)
    #expect(game.screen == .library)
    let closed = game.interfaceKey("escape")
    #expect(closed)
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
    let intent = MissionUIIntent(
      action: .contracts, game: game, presentation: game.scriptPagePresentation)
    #expect(intent.isCurrent(in: game))
    let stale = MissionUIIntent(
      action: .contracts, game: game, presentation: .init(epoch: UUID(), page: nil))
    #expect(!stale.isCurrent(in: game))
    game.docked = false
    #expect(!intent.isCurrent(in: game))
  }

  @Test func sameEpochDifferentScreenRefusesNonPageAction() {
    var game = Game(executive: false)
    game.screen = .status
    let intent = MissionUIIntent(
      action: .library, game: game, presentation: game.scriptPagePresentation)
    let epoch = game.scriptPagePresentation.epoch
    game.screen = .front
    #expect(game.scriptPagePresentation.epoch == epoch)
    #expect(MissionUIAction.library.isEnabled(in: game))
    #expect(!intent.isCurrent(in: game))
  }

  @Test func successfulTrialReturnDoesNotReviveParentNonPageIntent() async throws {
    let examples = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/scripted-passengers")
    let pack = try ScriptPackLibrary.read(examples)
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [pack]
    game.openGallery()
    let runtime = GameRuntime(game: game)
    let parent = await runtime.snapshot()
    let oldIntent = MissionUIIntent(
      action: .library, game: parent, presentation: parent.scriptPagePresentation)
    #expect(oldIntent.isCurrent(in: parent))
    try await runtime.startScriptGalleryTrial(packDigest: pack.digest, seed: 42)
    let namespace = try #require(await runtime.gallerySaveDirectory())
    defer { try? FileManager.default.removeItem(at: namespace) }
    #expect(await runtime.snapshot().isMissionTrial)
    try await runtime.returnFromScriptGalleryTrial()
    let restored = await runtime.snapshot()
    #expect(!restored.isMissionTrial)
    #expect(restored.screen == parent.screen)
    #expect(restored.ecmControl.epoch == parent.ecmControl.epoch)
    #expect(restored.inventoryContextEpoch != parent.inventoryContextEpoch)
    #expect(!oldIntent.isCurrent(in: restored))
    await runtime.missionUICommand(oldIntent)
    let refused = await runtime.snapshot()
    #expect(refused.screen == parent.screen && refused.commander == parent.commander)
    await runtime.missionUICommand(
      .init(action: .library, game: refused, presentation: refused.scriptPagePresentation))
    let opened = await runtime.snapshot()
    #expect(opened.screen == .library && opened.commander == parent.commander)
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
