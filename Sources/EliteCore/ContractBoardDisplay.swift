import Foundation

public struct ContractBoardLayout: Sendable {
  public let left = 24.0
  public let width: Double
  public let listTop = 112.0
  public let listRow = 44.0
  public let listBottom: Double
  public let listCount: Int
  public let detailCount: Int
  public let actions: [(ContractBoardAction, CanvasRect)]
  public let refresh: CanvasRect
  public init(width: Double, height: Double) {
    self.width = max(160, width - 48)
    listBottom = height - 90
    listCount = max(1, Int((height - 202) / 44))
    detailCount = max(1, Int((height - 210) / GameTypography.row))
    let button = (self.width - 16) / 3
    actions = ContractBoardAction.allCases.enumerated().map { index, action in
      (
        action,
        .init(x: 24 + Double(index) * (button + 8), y: height - 56, width: button, height: 30)
      )
    }
    refresh = .init(x: width - 190, y: height - 56, width: 166, height: 30)
  }
}
extension Display {
  static func contractDetailRows(_ game: Game, width: Double) -> [String] {
    guard let row = game.contractBoard.selected else { return ["No contract selected."] }
    var rows: [String]
    if let offer = row.offer {
      let destination = Universe.systemsIncludingPlugh(number: offer.destinationGalaxy)[
        offer.destinationSystem
      ].name
      rows = [
        row.title, offer.briefing,
        "Destination: Galaxy \(offer.destinationGalaxy + 1), \(destination) orbital station.",
        String(
          format: "Reward: %.1f CR; deposit: %.1f CR.", Double(offer.reward) / 10,
          Double(offer.deposit) / 10),
        String(
          format: "On failure: %.1f CR; %@.", Double(offer.failureReward) / 10,
          offer.refundOnFailure ? "deposit refunded" : "deposit forfeited"),
        offer.duration == 0
          ? "No deadline."
          : String(
            format: "Time allowed after acceptance: %.1f seconds of %@.", offer.duration,
            game.commander.contracts.boards[row.board]?.clock == .calendar
              ? "commander calendar time, including travel"
              : (game.commander.contracts.boards[row.board]?.clock == .flight
                ? "flight" : "loaded, unpaused play")),
        "Abandonment forfeits the deposit.", "Reading or Back does not accept or start the clock.",
      ]
      rows += game.contractBoard.quote?.issues ?? (row.reason.map { [$0] } ?? [])
    } else {
      rows = [row.reason ?? "This provider is unavailable."]
    }
    let characters = Int(
      min(680, ContractBoardLayout(width: width, height: game.viewportHeight).width)
        / (6 * GameTypography.scale))
    return rows.flatMap { ShowroomText.wrap($0, width: characters) }
  }
  static func contractBoard(_ game: Game, width: Double, height: Double) -> Frame {
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: width, height: height)
    let layout = ContractBoardLayout(width: width, height: height)
    let scale = GameTypography.scale
    let characters = Int(layout.width / (6 * scale))
    func short(_ text: String) -> String {
      text.count <= characters ? text : String(text.prefix(max(1, characters - 3))) + "..."
    }
    frame.label("STATION CONTRACTS", layout.left, 14, scale: scale, ink: .yellow)
    frame.label(
      short(game.currentSystem.name + " / Main orbital station"), layout.left, 38, scale: scale,
      ink: .cyan)
    let active = game.activeContractSummary
    frame.label(
      short(active.first ?? "No active contract assignments."), layout.left, 62, scale: scale,
      ink: active.isEmpty ? .white : .green)
    if game.contractBoard.detail,
      let reason = game.contractBoard.quote?.issues.first ?? game.contractBoard.selected?.reason
    {
      frame.label(short(reason), layout.left, 84, scale: scale, ink: .orange)
    } else if active.count > 1 {
      frame.label(
        "\(active.count) active assignments; see Mission Gallery.", layout.left, 84, scale: scale)
    }
    if game.contractBoard.detail {
      let rows = contractDetailRows(game, width: width)
      let window = ScrollWindow(
        count: rows.count, visible: layout.detailCount, offset: game.contractBoard.scroll)
      for (index, row) in rows.dropFirst(window.offset).prefix(layout.detailCount).enumerated() {
        frame.label(
          row, layout.left, layout.listTop + Double(index) * GameTypography.row, scale: scale)
      }
      if let hint = window.hint {
        frame.label(hint, layout.left, height - 84, scale: scale, ink: .cyan)
      }
      for (action, bounds) in layout.actions {
        let available =
          action == .back
          || (game.contractBoard.quote != nil
            && (action != .accept || game.contractBoard.quote?.allowed == true))
        frame.label(
          (game.contractBoard.action == action ? "> " : "  ") + action.rawValue, bounds.x + 8,
          bounds.y + 10, scale: scale, ink: available ? .cyan : .orange)
      }
      frame.label(
        short("Left/Right: choose  Return: select  Esc: back  Scroll: read"), layout.left,
        height - 18, scale: scale, ink: .cyan)
    } else {
      let start = max(0, game.contractBoard.selection - layout.listCount + 1)
      if game.contractBoard.rows.isEmpty {
        frame.label(
          "No available offers at this station.", layout.left, layout.listTop, scale: scale)
      }
      for (index, row) in game.contractBoard.rows.dropFirst(start).prefix(layout.listCount)
        .enumerated()
      {
        let y = layout.listTop + Double(index) * layout.listRow
        frame.label(
          short((start + index == game.contractBoard.selection ? "> " : "  ") + row.title),
          layout.left, y, scale: scale, ink: .cyan)
        let summary =
          row.reason ?? row.offer.map {
            String(
              format: "Pay %.1f CR / deposit %.1f CR / %@", Double($0.reward) / 10,
              Double($0.deposit) / 10,
              $0.duration == 0 ? "no limit" : String(format: "%.0fs", $0.duration))
          } ?? "Unavailable"
        frame.label(
          short(summary), layout.left, y + 18, scale: scale,
          ink: row.reason == nil ? .white : .orange)
      }
      frame.label(
        "Refresh offers", layout.refresh.x + 8, layout.refresh.y + 10, scale: scale, ink: .cyan)
      frame.label(
        short("Arrows: select  Return/click: briefing  Esc: station"), layout.left, height - 18,
        scale: scale, ink: .cyan)
    }
    if game.messageTime > 0 {
      frame.label(short(game.message), layout.left, height - 68, scale: scale, ink: .orange)
    }
    return frame
  }
}
