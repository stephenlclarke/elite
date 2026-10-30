import AppKit
import L337Core

/// The AppDelegate retains this target; it queues intents rather than mutating simulation state.
@MainActor
final class NativeMissionMenu: NSObject, NSMenuItemValidation {
  private let snapshot: () -> Game?
  private let paintedPresentation: () -> ScriptPagePresentation?
  private let enqueue: (MissionUIIntent) -> Void

  init(
    snapshot: @escaping () -> Game?,
    paintedPresentation: @escaping () -> ScriptPagePresentation?,
    enqueue: @escaping (MissionUIIntent) -> Void
  ) {
    self.snapshot = snapshot
    self.paintedPresentation = paintedPresentation
    self.enqueue = enqueue
  }

  func install(in menu: NSMenu) {
    for item in menu.items {
      if let command = item.representedObject as? String, MissionUIAction(rawValue: command) != nil
      {
        menu.removeItem(item)
      }
    }
    for (index, action) in MissionUIAction.allCases.enumerated() {
      let item = NSMenuItem(
        title: action.title, action: #selector(chooseMissionMenuItem(_:)), keyEquivalent: "")
      item.representedObject = action.rawValue
      item.target = self
      if let game = snapshot() { item.title = action.title(in: game) }
      menu.insertItem(item, at: index)
    }
  }

  func validateMenuItem(_ item: NSMenuItem) -> Bool {
    guard let command = item.representedObject as? String,
      let action = MissionUIAction(rawValue: command), let game = snapshot()
    else { return false }
    item.title = action.title(in: game)
    return action.isEnabled(in: game) && presentation(for: action, in: game) != nil
  }

  @discardableResult
  func choose(_ action: MissionUIAction) -> Bool {
    guard let game = snapshot(), action.isEnabled(in: game),
      let proof = presentation(for: action, in: game)
    else { return false }
    enqueue(.init(action: action, game: game, presentation: proof))
    return true
  }

  private func presentation(for action: MissionUIAction, in game: Game) -> ScriptPagePresentation? {
    guard action.requiresPageProof else { return game.scriptPagePresentation }
    guard let painted = paintedPresentation(), painted == game.scriptPagePresentation else {
      return nil
    }
    return painted
  }

  @objc private func chooseMissionMenuItem(_ sender: NSMenuItem) {
    guard let command = sender.representedObject as? String,
      let action = MissionUIAction(rawValue: command)
    else { return }
    choose(action)
  }
}
