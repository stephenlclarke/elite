import Foundation

public struct ShipTradeQuote: Sendable {
  public let selected: CatalogueShip
  public let purchase: Int
  public let allowance: Int
  public let net: Int
  public let balance: Int
  public let issues: [String]
  public var allowed: Bool { issues.isEmpty }
  public var rows: [String] {
    [
      "Selected: " + selected.name,
      String(format: "Hull price: %.1f CR", Double(purchase) / 10),
      String(format: "Trade-in allowance: %.1f CR", Double(allowance) / 10),
      String(format: "Net %@: %.1f CR", net < 0 ? "credit" : "cost", Double(abs(net)) / 10),
      String(format: "Resulting cash: %.1f CR", Double(balance) / 10),
      "Cargo, fuel, portable equipment and mission property transfer.",
      "Hull-bound fittings leave with the sold hull.",
      "Unsupported portable fittings remain owned in storage.",
      "No new lasers, missiles or free fuel are included.",
    ] + (issues.isEmpty ? ["Compatible fit. Confirm to exchange hulls."] : issues)
  }
}
extension Game {
  public var shipTradeQuote: ShipTradeQuote? {
    guard let selected = showroomShip else { return nil }
    return shipTradeQuote(for: selected)
  }
  func shipTradeQuote(for selected: CatalogueShip) -> ShipTradeQuote? {
    guard let next = selected.game else { return nil }
    let purchase = next.price * 10
    let allowance = commander.performance.price * 10 * 3 / 4
    let net = purchase - allowance
    let balance = commander.unlimitedCash ? commander.credits : commander.credits - net
    var issues: [String] = []
    if next.price <= 0 { issues.append("This hull is unpriced and not for sale.") }
    if !docked || !dockedAtMainStation { issues.append("Exchange requires a main station.") }
    if selected.id == commander.shipID { issues.append("You already own this hull.") }
    if balance < 0 { issues.append("Insufficient cash for this exchange.") }
    if balance > 4_294_967_295 { issues.append("Credit would exceed the account limit.") }
    let projected: Commander
    do {
      projected = try commander.projectedEquipmentTransfer(to: selected.id)
    } catch {
      issues.append("Physical fittings or carried resources are incompatible with this hull.")
      var fallback = commander
      fallback.shipID = selected.id
      projected = fallback
    }
    issues += shipTransferIssues(to: projected)
    return .init(
      selected: selected, purchase: purchase, allowance: allowance, net: net, balance: balance,
      issues: issues)
  }
  private func shipTransferIssues(to projected: Commander) -> [String] {
    let next = projected.performance
    var issues: [String] = []
    if !(commander.nativePeople?.held.isEmpty ?? true)
      || commander.scriptState.instances.values.contains(where: {
        $0.savedOwnedCargo?.held.isEmpty == false
      }),
      commander.cargoTonnes > projected.standardCargoCapacity
    {
      issues.append(
        "Protected people and issuer-owned freight require real hold space. Transfer them explicitly before choosing this hull."
      )
    }
    if commander.cargoTonnes > projected.capacity {
      issues.append(
        "Sell cargo first: hold requires \(commander.cargoTonnes)t; new capacity \(projected.capacity)t. Mission cargo cannot be sold."
      )
    }
    if commander.equipmentInventory == nil,
      commander.equipment.contains("Large Cargo Bay") && next.cargoExpansion == 0
    {
      issues.append("Cargo expansion cannot transfer to this hull. Choose a compatible hull.")
    }
    for mount in LaserMount.allCases
    where projected.laser(on: mount) != nil && !next.supports(mount) {
      issues.append(mount.label + " laser has no matching mount. Choose a compatible hull.")
    }
    if projected.missiles > next.missiles {
      issues.append(
        "Use excess missiles first: \(projected.missiles) held; \(next.missiles) pylons available.")
    }
    if commander.fuel > projected.fuelCapacity {
      issues.append("Use excess fuel first; new tank is smaller.")
    }
    if let plan = commander.navigationPlan,
      zip(plan.path, plan.path.dropFirst()).contains(where: {
        systems[$0].distance(to: systems[$1])
          > projected.fullTankJumpDistance
      })
    {
      issues.append("Clear the incompatible navigation route before exchanging.")
    }
    return issues
  }
  mutating func confirmShipTrade() {
    guard !paused, showroom.trading, let quote = shipTradeQuote, quote.allowed else { return }
    guard ownedEquipmentEventCapacityAvailable else {
      notify("HULL EXCHANGE REFUSED - MISSION EVENT CAPACITY")
      return
    }
    let previous = commander.shipID
    // Re-evaluate the quote at confirmation; no state changes happen on opening or Back.
    do {
      try commitShipTradeCandidate(quote)
    } catch {
      notify("HULL EXCHANGE REFUSED - FITTINGS OR RESOURCES INCOMPATIBLE")
      return
    }
    showroom.baseline = commander.shipID
    showroom.baselineUsesCurrent = true
    showroom.trading = false
    showroom.scroll = 0
    notify("NOW FLYING " + commander.ship.name.uppercased())
    emitScriptEvent(
      "ship.changed", values: ["previous": .string(previous), "ship": .string(commander.shipID)])
  }
  /// Finish the copied fitting transaction before entering mission event dispatch.
  private mutating func commitShipTradeCandidate(_ quote: ShipTradeQuote) throws {
    var candidate = self
    try candidate.commander.prepareEquipment()
    try candidate.commander.transferEquipment(to: quote.selected.id, hullID: UUID())
    candidate.commander.credits = quote.balance
    candidate.preserveEquipmentResourceFractions(from: self)
    self = candidate
  }
  /// Hull and fitting changes reserve their observation before publishing physical custody.
  var ownedEquipmentEventCapacityAvailable: Bool {
    let recipients = commander.scriptState.instances.values.filter { $0.outcome == .active }.count
    return recipients <= 4096
      && commander.scriptState.pendingEvents.count <= 4096 - recipients
      && commander.scriptState.nextEvent <= UInt64(Int64.max) - 1 - UInt64(recipients)
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
