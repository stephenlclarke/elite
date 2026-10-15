import Foundation

public enum BlackjackAction: String, Sendable {
  case introduction, report, collectFirearm, robbery, finalReport, collectGold
  var stage: BlackjackStage {
    switch self {
    case .introduction: .huntBolts
    case .report, .collectGold: .reportBolts
    case .collectFirearm: .collectFirearm
    case .robbery: .deliverFirearm
    case .finalReport: .reportWitness
    }
  }
  static let allActions: [Self] = [
    .introduction, .report, .collectFirearm, .robbery, .finalReport, .collectGold,
  ]
  public var text: String {
    MissionPackLibrary.bundled.entries.first { $0.pack.mission.binding == "blackjack" }?.pack
      .dialog(rawValue.lowercased())?.text ?? "Contact unavailable."
  }

}
public struct BlackjackOffer: Sendable {
  public let action: BlackjackAction
  public let galaxy: Int
  public let system: Int
  public var confirmSelected = true
}
extension Game {
  mutating func enforceBlackjackWanted() {
    if commander.galaxy == 1 && commander.blackjack.stage.wanted && !commander.xyzzyWantedAmnesty {
      commander.legal = max(commander.legal, 64)
    }
  }
  mutating func offerBlackjackHandoff() {
    guard docked, dockedAtMainStation,
      ![Screen.mission, .handoff, .gallery, .help, .secret].contains(screen)
    else { return }
    enforceBlackjackWanted()
    _ = dispatchMission(.contact)
  }

  mutating func blackjackHandoffKey(_ key: String) {
    if key == "pageup" || key == "pagedown" {
      packDialogScroll = packDialogWindow.moved(key == "pageup" ? -8 : 8)
      return
    }
    if !offeredScriptChoices.isEmpty && ["up", "down"].contains(key) {
      moveScriptChoice(key == "up" ? -1 : 1)
      return
    }
    if ["left", "right", "up", "down"].contains(key) {
      blackjackOffer?.confirmSelected.toggle()
      packOffer?.confirmSelected.toggle()
      if scriptOffer != nil || scriptAvailablePackDigest != nil { scriptConfirmSelected.toggle() }
    }
    if key == "escape" {
      closeBlackjackHandoff()
      return
    }
    guard key == "return" else { return }
    if (scriptOffer != nil || scriptAvailablePackDigest != nil) && !scriptConfirmSelected {
      closeBlackjackHandoff()
      return
    }
    if packOffer?.confirmSelected == false || blackjackOffer?.confirmSelected == false {
      closeBlackjackHandoff()
      return
    }
    confirmBlackjackHandoff()
  }
  mutating func closeBlackjackHandoff() {
    blackjackOffer = nil
    packOffer = nil
    scriptOffer = nil
    scriptPresentedDialogue = nil
    scriptAvailablePackDigest = nil
    scriptChoiceSelection = 0
    screen = blackjackReturn
  }
  mutating func confirmBlackjackHandoff() {
    if let digest = scriptAvailablePackDigest,
      let pack = scriptPacks.first(where: { $0.digest == digest })
    {
      guard !paused, docked, dockedAtMainStation else {
        notify("RETURN TO THE STATION AND RESUME TO CONFIRM")
        return
      }
      do { _ = try acceptScriptMission(pack) } catch { notify(error.localizedDescription) }
      closeBlackjackHandoff()
      return
    }
    if scriptOffer != nil {
      confirmScriptDialogue()
      return
    }
    confirmPackOffer()
  }

}
extension Display {
  public static func blackjackHandoff(_ game: Game, width: Double, height: Double) -> Frame {
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: width, height: height)
    let font = GameTypography.scale
    let contentWidth = min(650, width - 48)
    let left = (width - contentWidth) / 2
    frame.label(
      game.offeredScriptTitle?.uppercased() ?? game.offeredPack?.pack.mission.title.uppercased()
        ?? "MISSION CONTACT", left, 20, scale: font,
      ink: .yellow)
    frame.label(
      "Main orbital station: " + game.currentSystem.name, left, 48, scale: font, ink: .cyan)
    let lines = game.packDialogLines(width: width)
    let window = ScrollWindow(
      count: lines.count, visible: max(1, Int((height - 210 - game.scriptChoiceHeight) / 19)),
      offset: game.packDialogScroll)
    for (index, line) in lines.dropFirst(window.offset).prefix(window.visible).enumerated() {
      frame.label(line, left, 80 + Double(index) * 19, scale: font)
    }
    if window.last > 0 {
      frame.label(
        "Option-Up/Down: read \(window.offset + 1)-\(min(window.count, window.offset + window.visible))/\(window.count)",
        left, height - 120 - game.scriptChoiceHeight, scale: font, ink: .cyan)
    }
    stationChoices(game, frame: &frame, left: left, width: contentWidth, height: height)
    if game.scriptDialogueStale {
      frame.label(
        "Contact changed. Reopen Contacts to confirm.", left, height - 100, scale: font,
        ink: .orange)
    } else if game.messageTime > 0 {
      let messages = MissionNotice.wrap(game.message, width: Int(contentWidth / (6 * font)))
      for (index, line) in messages.enumerated() {
        frame.label(line, left, height - 100 + Double(index) * 16, scale: font, ink: .orange)
      }
    }
    let selected =
      (game.scriptOffer != nil || game.scriptAvailablePackDigest != nil)
      ? game.scriptConfirmSelected
      : game.packOffer?.confirmSelected ?? game.blackjackOffer?.confirmSelected ?? true
    frame.label(
      (selected ? "> " : "  ") + "Confirm / Continue", left, height - 48, scale: font, ink: .cyan)
    frame.label(
      (selected ? "  " : "> ") + "Back", left + contentWidth / 2, height - 48, scale: font,
      ink: .cyan)
    frame.label(
      "Arrows: choose  Return: confirm  Esc: back  K: help", left, height - 22, scale: font)
    return frame
  }
}

extension Game {
  var packDialogLines: [String] {
    packDialogLines(width: viewportWidth)
  }
  func packDialogLines(width: Double) -> [String] {
    MissionNotice.wrap(
      packText(
        offeredScriptText ?? offeredDialog?.text ?? blackjackOffer?.action.text
          ?? "Contact unavailable."),
      width: max(10, Int(min(650, width - 48) / (6 * GameTypography.scale))))
  }
  var packDialogWindow: ScrollWindow {
    .init(
      count: packDialogLines.count,
      visible: max(1, Int((viewportHeight - 210 - scriptChoiceHeight) / 19)),
      offset: packDialogScroll)
  }
  public mutating func blackjackHandoffClick(x: Double, y: Double) {
    guard screen == .handoff else { return }
    let contentWidth = min(650, viewportWidth - 48)
    let left = (viewportWidth - contentWidth) / 2
    if !offeredScriptChoices.isEmpty, y >= viewportHeight - 126,
      y < viewportHeight - 102, x >= left, x < left + contentWidth
    {
      moveScriptChoice(x < left + contentWidth / 2 ? -1 : 1)
      return
    }
    guard y >= viewportHeight - 52 && y < viewportHeight - 28, x >= left && x < left + contentWidth
    else { return }
    if x < left + contentWidth / 2 { confirmBlackjackHandoff() } else { closeBlackjackHandoff() }
  }
}
