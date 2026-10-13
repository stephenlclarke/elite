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
  public var text: String {
    switch self {
    case .introduction:
      "Blackjack asks you to find Commander Bolts at Gerebied, Galaxy 2. Destroying the unique target earns 20 kg gold, regardless of the killer. Then report at any main station in Galaxy 2. No deadline. This contact has enrolled you; Continue or Back closes this message."
    case .report:
      "Confirm your report to Blackjack. Next: collect one tonne of marked mission firearms at Tegete's main orbital station, Galaxy 2. No payment or item transfer here."
    case .collectFirearm:
      "Transfer one tonne of marked firearms from Blackjack's contact into your hold. One free tonne is required. Keep this mission item aboard until Ceinerxe's main orbital station. Personal cargo and equipment stay aboard."
    case .robbery:
      "Transfer the marked firearm to Blackjack at Ceinerxe's dockside handoff. This completes the station operation, makes you wanted (minimum 64), and directs you to the witness at Edater, Galaxy 2. No on-foot operation is played."
    case .finalReport:
      "Report the witness's destruction at Esdi. Confirm to receive 9,500 CR and clear your bounty once. The campaign then ends. Later offences will remain yours."
    case .collectGold:
      "Your once-earned 20 kg gold is pending collection. Make room for the gold before confirming. This is not a second reward."
    }
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
    if commander.galaxy == 1 && commander.blackjack.stage.wanted {
      commander.legal = max(commander.legal, 64)
    }
  }
  mutating func offerBlackjackHandoff() {
    guard docked, dockedAtMainStation, commander.galaxy == 1,
      ![Screen.mission, .handoff, .gallery, .help, .secret].contains(screen)
    else { return }
    enforceBlackjackWanted()
    let action: BlackjackAction
    switch commander.blackjack.stage {
    case .notStarted:
      guard commander.system == 241 else { return }
      commander.blackjack.stage = .huntBolts
      commander.blackjack.transfers.insert(.contact)
      action = .introduction
    case .reportBolts: action = commander.blackjack.pendingGold ? .collectGold : .report
    case .collectFirearm:
      guard commander.system == 233 else { return }
      action = .collectFirearm
    case .deliverFirearm:
      guard commander.system == 127 else { return }
      action = .robbery
    case .reportWitness:
      guard commander.system == 67 else { return }
      action = .finalReport
    default: return
    }
    blackjackOffer = .init(action: action, galaxy: commander.galaxy, system: commander.system)
    blackjackReturn = screen
    screen = .handoff
    notify("MISSION CONTACT")
  }
  mutating func blackjackHandoffKey(_ key: String) {
    if ["left", "right", "up", "down"].contains(key) { blackjackOffer?.confirmSelected.toggle() }
    if key == "escape" {
      closeBlackjackHandoff()
      return
    }
    guard key == "return" else { return }
    if blackjackOffer?.confirmSelected == false {
      closeBlackjackHandoff()
      return
    }
    confirmBlackjackHandoff()
  }
  mutating func closeBlackjackHandoff() {
    blackjackOffer = nil
    screen = blackjackReturn
  }
  mutating func confirmBlackjackHandoff() {
    guard let offer = blackjackOffer, docked, dockedAtMainStation, offer.galaxy == 1,
      commander.galaxy == offer.galaxy,
      commander.system == offer.system, commander.blackjack.stage == offer.action.stage
    else {
      notify("CONTACT NO LONGER AVAILABLE")
      return
    }
    switch offer.action {
    case .introduction: break
    case .report:
      commander.blackjack.stage = .collectFirearm
      commander.blackjack.transfers.insert(.report)
    case .collectFirearm:
      guard commander.cargoTonnes < commander.capacity, commander.cargo[10] < Int.max / 17 else {
        notify("ONE FREE TONNE REQUIRED - BACK TO TRADE")
        return
      }
      commander.cargo[10] += 1
      commander.blackjack.stage = .deliverFirearm
      commander.blackjack.transfers.insert(.firearmPickup)
    case .robbery:
      guard commander.markedFirearms == 1 && commander.cargo[10] > 0 else {
        notify("MARKED FIREARM REQUIRED")
        return
      }
      commander.cargo[10] -= 1
      commander.blackjack.stage = .huntWitness
      commander.blackjack.transfers.insert(.robberyHandoff)
      commander.legal = max(commander.legal, 64)
    case .finalReport:
      guard commander.credits <= 4_294_967_295 - 95000 else {
        notify("SPEND CREDITS BEFORE COLLECTING REWARD")
        return
      }
      commander.credits += 95000
      commander.legal = 0
      commander.blackjack.stage = .complete
      commander.blackjack.transfers.insert(.finalReward)
    case .collectGold:
      guard commander.blackjack.pendingGold, commander.cargo[13] <= Int.max / 17 - 20 else {
        notify("MAKE SPACE FOR 20 KG GOLD")
        return
      }
      commander.cargo[13] += 20
      commander.blackjack.pendingGold = false
      commander.blackjack.transfers.insert(.goldDelivery)
    }
    closeBlackjackHandoff()
    notify(
      offer.action == .finalReport
        ? "BLACKJACK COMPLETE - 9500 CR RECEIVED" : "BLACKJACK CONTACT COMPLETE")
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
    frame.label("BLACKJACK'S BULLION", left, 20, scale: font, ink: .yellow)
    frame.label(
      "Main orbital station: " + game.currentSystem.name, left, 48, scale: font, ink: .cyan)
    let lines = MissionNotice.wrap(
      game.blackjackOffer?.action.text ?? "Contact unavailable.",
      width: Int(contentWidth / (6 * font)))
    for (index, line) in lines.enumerated() {
      frame.label(line, left, 80 + Double(index) * 19, scale: font)
    }
    if game.messageTime > 0 {
      let messages = MissionNotice.wrap(game.message, width: Int(contentWidth / (6 * font)))
      for (index, line) in messages.enumerated() {
        frame.label(line, left, height - 100 + Double(index) * 16, scale: font, ink: .orange)
      }
    }
    let selected = game.blackjackOffer?.confirmSelected ?? true
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
  public mutating func blackjackHandoffClick(x: Double, y: Double) {
    guard screen == .handoff else { return }
    let contentWidth = min(650, viewportWidth - 48)
    let left = (viewportWidth - contentWidth) / 2
    guard y >= viewportHeight - 52 && y < viewportHeight - 28, x >= left && x < left + contentWidth
    else { return }
    if x < left + contentWidth / 2 { confirmBlackjackHandoff() } else { closeBlackjackHandoff() }
  }
}
