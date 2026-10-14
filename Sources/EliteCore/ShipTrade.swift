import Foundation

public struct ShipTradeQuote: Sendable {
  public let selected: CatalogueShip
  public let purchase: Int
  public let allowance: Int
  public let net: Int
  public let balance: Int
  public let issues: [String]
  public var storageRows: [String] = []
  var projected: Commander?
  public var allowed: Bool { issues.isEmpty }
  public var rows: [String] {
    [
      "Selected: " + selected.name,
      String(format: "Hull price: %.1f CR", Double(purchase) / 10),
      String(format: "Trade-in allowance: %.1f CR", Double(allowance) / 10),
      String(format: "Net %@: %.1f CR", net < 0 ? "credit" : "cost", Double(abs(net)) / 10),
      String(format: "Resulting cash: %.1f CR", Double(balance) / 10),
      "Cargo, fuel, people and mission property are preserved.",
      "Compatible equipment transfers; surplus is stored for reuse.",
      "No new lasers, missiles or free fuel are included.",
    ] + storageRows + (issues.isEmpty ? ["Compatible fit. Confirm to exchange hulls."] : issues)
  }
}
extension Game {
  public var shipTradeQuote: ShipTradeQuote? {
    guard let selected = showroomShip, let next = selected.game else { return nil }
    let purchase = next.price * 10
    let allowance = commander.performance.price * 10 * 3 / 4
    let net = purchase - allowance
    let balance = commander.unlimitedCash ? commander.credits : commander.credits - net
    var issues: [String] = []
    if !docked || !dockedAtMainStation { issues.append("Exchange requires a main station.") }
    if selected.id == commander.shipID { issues.append("You already own this hull.") }
    if balance < 0 { issues.append("Insufficient cash for this exchange.") }
    if balance > 4_294_967_295 { issues.append("Credit would exceed the account limit.") }
    let transfer = commander.equipmentTransfer(to: selected.id)
    issues += transfer.issues
    issues += shipTransferIssues(to: transfer.commander)
    return .init(
      selected: selected, purchase: purchase, allowance: allowance, net: net, balance: balance,
      issues: issues, storageRows: transfer.storageRows, projected: transfer.commander)
  }
  private func shipTransferIssues(to projected: Commander) -> [String] {
    var issues: [String] = []
    if let plan = commander.navigationPlan,
      zip(plan.path, plan.path.dropFirst()).contains(where: {
        systems[$0].distance(to: systems[$1])
          > min(projected.jumpCap, Double(projected.fuelCapacity) / 10)
      })
    {
      issues.append("Clear the incompatible navigation route before exchanging.")
    }
    return issues
  }
  mutating func confirmShipTrade() {
    guard !paused, showroom.trading, let quote = shipTradeQuote, quote.allowed,
      let projected = quote.projected
    else { return }
    // Re-evaluate the quote at confirmation; no state changes happen on opening or Back.
    let previousShip = commander.shipID
    commander = projected
    commander.credits = quote.balance
    speed = 0
    energy = commander.performance.energy
    frontShield = commander.shieldCapacity
    rearShield = commander.shieldCapacity
    showroom.baseline = commander.shipID
    showroom.baselineUsesCurrent = true
    showroom.trading = false
    showroom.scroll = 0
    notify("NOW FLYING " + commander.ship.name.uppercased())
    emitScriptEvent(
      "ship.changed",
      values: ["previous": .string(previousShip), "ship": .string(commander.shipID)])
  }
  mutating func shipTradeKey(_ key: String) {
    switch key {
    case "escape": showroom.trading = false
    case "left", "right", "tab": showroom.confirmTrade.toggle()
    case "up", "down", "pageup", "pagedown":
      let count = Display.shipTradeRows(self, width: viewportWidth).count
      let visible = ShipTradeLayout(width: viewportWidth, height: viewportHeight).count
      let window = ScrollWindow(count: count, visible: visible, offset: showroom.tradeScroll)
      showroom.tradeScroll = window.moved(key == "up" || key == "pageup" ? -4 : 4)
    case "return":
      if showroom.confirmTrade { confirmShipTrade() } else { showroom.trading = false }
    default: break
    }
  }
}
