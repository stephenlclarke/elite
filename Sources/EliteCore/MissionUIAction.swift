import Foundation

/// Explicit menu destinations leave the existing flight and numbered-screen keys alone.
public enum MissionUIAction: String, CaseIterable, Sendable {
  case gallery = "gallery-open"
  case contacts = "contacts-open"
  case contracts = "contracts-open"
  case rumours = "rumours-open"
  case trial = "gallery-trial"
  case retry = "mission-resume"
  case returnToCommander = "trial-return"
  case restartTrial = "trial-restart"
  case library = "library-open"

  public var title: String {
    switch self {
    case .gallery: "Mission Gallery"
    case .contacts: "Mission Contacts"
    case .contracts: "Station Contracts"
    case .rumours: "Station Rumours"
    case .trial:
      "Try Selected Mission"
    case .retry: "Retry Selected Mission"
    case .returnToCommander: "Return to Commander"
    case .restartTrial: "Restart Mission Trial"
    case .library: "Mission Library"
    }
  }

  public func title(in game: Game) -> String {
    self == .trial && game.selectedGalleryMissionIsOwnedAssignment ? "Try Campaign" : title
  }

  public func isEnabled(in game: Game) -> Bool {
    switch self {
    case .contracts:
      return game.docked && game.dockedAtMainStation && !game.paused && !game.showroom.trading
        && ![Screen.demo, .title, .gameOver, .help, .secret, .mission, .handoff].contains(
          game.screen)
    case .trial:
      return game.screen == .gallery
        && (game.canTrialSelectedMission || game.canReviewSelectedCampaignTrial)
    case .retry:
      return game.screen == .gallery && game.canRetrySelectedGalleryEntry
    case .returnToCommander, .restartTrial:
      return game.isMissionTrial
    case .library:
      return true
    case .gallery, .contacts, .rumours:
      return !game.paused && !game.acceptsTextInput
        && ![
          Screen.demo, .title, .gameOver, .secret, .help, .mission, .handoff, .showroom, .gallery,
        ]
        .contains(game.screen)
        && (self == .gallery || game.docked)
    }
  }

  /// Page-affecting actions use the actor's existing exact painted-page proof.
  public var requiresPageProof: Bool { self == .contracts || self == .trial || self == .retry }
}

/// Captured in the native input stream. The actor rechecks epoch, availability and page proof.
public struct MissionUIIntent: Sendable, Equatable {
  public let action: MissionUIAction
  public let presentation: ScriptPagePresentation
  public let screen: Screen
  public let inventoryContext: InventoryContextEpoch
  /// Check again inside GameRuntime immediately before dispatch, without an intervening await.
  public func isCurrent(in game: Game) -> Bool {
    screen == game.screen && inventoryContext == game.inventoryContextEpoch
      && presentation.epoch == game.scriptPagePresentation.epoch && action.isEnabled(in: game)
      && (!action.requiresPageProof || presentation == game.scriptPagePresentation)
  }

  public init(action: MissionUIAction, game: Game, presentation: ScriptPagePresentation) {
    self.action = action
    self.presentation = presentation
    screen = game.screen
    inventoryContext = game.inventoryContextEpoch
  }
}

extension GameRuntime {
  /// Validate and dispatch in one actor turn so a restore cannot race the captured proof.
  public func missionUICommand(_ intent: MissionUIIntent) {
    guard intent.isCurrent(in: game) else { return }
    if intent.action.requiresPageProof {
      scriptPageKey(intent.action.rawValue, expected: intent.presentation)
    } else {
      key(intent.action.rawValue)
    }
  }
}
