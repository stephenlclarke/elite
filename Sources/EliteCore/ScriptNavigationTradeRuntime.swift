import Foundation

struct ScriptNavigationTradeRefusal: Error, LocalizedError, Sendable {
  let message: String
  var errorDescription: String? { message }
}

extension Game {
  private static func navigationTradeMoney(_ value: Int) -> String {
    String(format: "%.1f CR", Double(value) / 10)
  }

  func navigationTradeDock() -> NativeMainStationDockReceipt? {
    guard let receipt = commander.nativeStations?.currentMainDock,
      nativeMainStationArrivalContext(for: receipt.station) != nil
    else { return nil }
    return receipt
  }

  func navigationTradeUnavailable(_ pack: ScriptPack, binding: ScriptNavigationTradeBinding?)
    -> String?
  {
    guard
      pack.manifest.capabilities.contains(ScriptNavigationTradeContent.capability)
        || pack.manifest.stateID == ScriptNavigationTradeContent.sourceID
    else { return nil }
    guard ScriptNavigationTradeContent.matches(pack) else {
      return "This training requires its exact approved runtime content."
    }
    guard let binding, binding.matches(self) else {
      let retainedRoute = commander.scriptState.instances.values.contains {
        $0.outcome == .active && $0.savedNavigationTrade != nil
      }
      if !retainedRoute, selectedSystem == commander.system,
        let original = try? Universe.originalWorld(
          galaxy: commander.galaxy, system: commander.system),
        systems.indices.contains(commander.system),
        systems[commander.system] == Universe.nativeSystem(original)
      {
        return
          "Select a different reachable original-world destination on the chart, then reopen Mission Contacts."
      }
      return
        "Restore the installed original-world route records, then select an ordinary destination and reopen Mission Contacts."
    }
    return nil
  }

  func navigationTradeQuery(_ instance: ScriptInstance) -> ScriptValue {
    guard let record = instance.savedNavigationTrade else {
      return .object(["stage": .string("unconfirmed")])
    }
    return .object([
      "stage": .string(record.stage.rawValue),
      "fuel_units_used": .integer(Int64(record.fuelUnitsUsed)),
      "fuel_paid": .integer(Int64(record.fuelPaid)),
      "buy_paid": record.buy.map { .integer(Int64($0.price)) } ?? .null,
      "sale_received": record.sale.map { .integer(Int64($0.price)) } ?? .null,
      "cash_difference": record.cashDifference.map { .integer(Int64($0)) } ?? .null,
    ])
  }

  func navigationTradeContactText(_ instance: ScriptInstance) -> String? {
    guard instance.definition == ScriptNavigationTradeContent.sourceID else { return nil }
    guard let record = instance.savedNavigationTrade else {
      guard Commodity.all.indices.contains(selection), market.indices.contains(selection),
        systems.indices.contains(selectedSystem)
      else { return nil }
      guard Commodity.all[selection].unit == "t", ![3, 6, 10, 16].contains(selection) else {
        return "Select a legal commodity sold by the tonne before confirming this practice."
      }
      return "Selected: " + Commodity.all[selection].name + ", 1t; " + currentSystem.name + " -> "
        + targetSystem.name + ". Range " + String(currentSystem.distance(to: targetSystem))
        + " LY; free hold " + String(max(0, commander.tradeCargoCapacity - commander.cargoTonnes))
        + "t; stock " + String(market[selection].quantity) + "; actual price "
        + Self.navigationTradeMoney(market[selection].price)
        + ". Confirm checks the actual fitting and fuel."
    }
    let next: String
    switch record.stage {
    case .awaitingBuy: next = "Buy the quoted tonne at " + record.training.system.name + "."
    case .held:
      next =
        record.routeVerified
        ? "Sell the identified tonne through the market at " + record.destination.system.name + "."
        : "Fly the selected direct route from " + record.training.system.name + " to "
          + record.destination.system.name + "."
    case .sold:
      next =
        "Return by actual flight to " + record.training.system.name
        + " and confirm training reception."
    case .lost:
      next = "Report the actual cargo loss; a replacement tonne cannot complete this practice."
    case .received: next = "Training reception retained."
    case .cancelled: next = "Practice cancelled; actual funds and surviving cargo retained."
    }
    var summary: String = next
    summary += "\nBuy: "
    summary += record.buy.map { Self.navigationTradeMoney($0.price) } ?? "pending"
    summary += "; sale: "
    summary += record.sale.map { Self.navigationTradeMoney($0.price) } ?? "pending"
    summary += "; fuel used: " + String(record.fuelUnitsUsed)
    summary += " units; actual fuel spending: " + Self.navigationTradeMoney(record.fuelPaid)
    summary += "; cash difference: "
    summary += record.cashDifference.map(Self.navigationTradeMoney) ?? "pending"
    summary += ". No tutorial payment."
    return summary
  }

  func applyNavigationTradeCommand(
    _ command: ScriptValue, event: ScriptEvent, pack: ScriptPack,
    state: inout ScriptInstance, binding: ScriptNavigationTradeBinding?
  ) throws {
    guard let fields = command.object, Set(fields.keys) == ["op"], let op = fields["op"]?.string,
      ScriptNavigationTradeContent.matches(pack), let binding, binding.matches(self),
      state.outcome == .active, state.dialogue == nil,
      event.kind == "dialogue.confirmed", let context = event.context,
      let original = commander.scriptState.instances[state.id],
      let offered = original.dialogue,
      offered.token == event.values["token"]?.string,
      offered.id == event.values["dialogue_id"]?.string,
      offered.revision == original.revision, context.revision == original.revision,
      let dock = navigationTradeDock(), let owner = commander.equipmentOwnerID,
      dock.commanderOwner == owner, !commander.unlimitedCash, !commander.unlimitedFuel
    else {
      throw MissionPackError("Training requires the current confirmed native station contact.")
    }
    let contact = ScriptNavigationTradeContactReceipt(
      operation: UUID(), sequence: event.sequence, context: context, dock: dock)
    switch op {
    case "training.trade.begin":
      guard offered.id == "fit", state.savedNavigationTrade == nil,
        dock.station.system == binding.training.location,
        selectedSystem == binding.destination.system.id,
        Commodity.all.indices.contains(selection), Commodity.all[selection].unit == "t",
        ![3, 6, 10, 16].contains(selection), commander.cargo[selection] == 0,
        commander.cargoTonnes < commander.tradeCargoCapacity,
        let inventory = commander.equipmentInventory, commander.equipmentStateValid,
        commander.fittedComponent(at: .drive) != nil,
        !commander.scriptState.instances.values.contains(where: {
          $0.savedNavigationTrade.map { $0.stage == .awaitingBuy || $0.held || $0.stage == .sold }
            == true
        }), market[selection].quantity > 0, commander.availableCredits >= market[selection].price
      else {
        throw ScriptNavigationTradeRefusal(
          message: "Choose a legal tonne commodity, real stock, fitting and free hold space.")
      }
      let distance = currentSystem.distance(to: binding.destination.system)
      let fuel = commander.jumpFuelCost(distance: distance)
      guard distance > 0, distance <= commander.maximumJumpDistance,
        fuel > 0, fuel <= commander.fuel
      else {
        throw ScriptNavigationTradeRefusal(
          message: "Select a reachable original-world route with actual available fuel.")
      }
      state.savedNavigationTrade = .init(
        owner: owner, instance: state.id, definition: state.definition, version: state.version,
        digest: state.digest, training: binding.training, destination: binding.destination,
        commodity: selection, acceptance: contact, acceptedHull: inventory.activeHull,
        equipmentRevision: inventory.revision, confirmedCapacity: commander.tradeCargoCapacity,
        confirmedCargoTonnes: commander.cargoTonnes, quotedPrice: market[selection].price,
        quotedStock: market[selection].quantity, routeDistance: distance, plannedFuelDebit: fuel)
    case "training.trade.receive":
      guard offered.id == "receive", event.values["choice_id"]?.string == "receive",
        var record = state.savedNavigationTrade, record.stage == .sold, record.sale != nil,
        record.owner == owner, record.training == binding.training,
        record.destination == binding.destination,
        dock.station.system == record.training.location,
        let returned = record.journeys.last,
        returned.journey.destination == record.training.system.id,
        returned.arrivalVisit == dock.actor.visit,
        returned.journey.operation > (record.sale?.calendarOperation ?? UInt64.max),
        dock.sequence > record.acceptance.dock.sequence
      else {
        throw ScriptNavigationTradeRefusal(
          message: "Actual selected-destination sale and return to the training berth are required."
        )
      }
      record.reception = contact
      record.stage = .received
      state.savedNavigationTrade = record
    case "training.trade.cancel":
      guard event.values["choice_id"]?.string == "cancel", var record = state.savedNavigationTrade,
        record.owner == owner, record.stage != .received, record.stage != .lost
      else { throw MissionPackError("Confirm cancellation of the active practice.") }
      record.cancellation = contact
      record.stage = .cancelled
      state.savedNavigationTrade = record
    case "training.trade.acknowledge-loss":
      guard offered.id == "lost", state.savedNavigationTrade?.stage == .lost,
        state.savedNavigationTrade?.loss?.valid == true
      else { throw MissionPackError("Only the actual retained loss can close a failed practice.") }
    default: throw MissionPackError("Unsupported training operation.")
    }
  }

  /// Admission precedes the existing market mutation. No event or cargo-balance scan creates proof.
  func navigationTradeMarketAdmission(buying: Bool, index: Int) throws -> UUID? {
    guard
      let state = commander.scriptState.instances.values.first(where: {
        guard let record = $0.savedNavigationTrade, record.commodity == index else { return false }
        return buying ? record.stage == .awaitingBuy : record.held
      }), let record = state.savedNavigationTrade
    else { return nil }
    if !buying, commander.sellableCargo(index) > 0,
      !(record.routeVerified && systemIdentity == record.destination.location
        && navigationTradeDock()?.actor.visit == record.journeys.last?.arrivalVisit
        && record.journeys.last?.journey.destination == record.destination.system.id)
    {
      return nil  // Only unreserved ordinary cargo is sold; the identified tonne stays held.
    }
    guard !paused, !commander.unlimitedCash, let dock = navigationTradeDock(),
      dock.commanderOwner == record.owner
    else {
      throw MissionPackError("Trade practice requires the actual native dock and ordinary funds.")
    }
    if buying {
      guard systemIdentity == record.training.location, commander.cargo[index] == 0,
        commander.hullInstanceID == record.acceptedHull,
        commander.equipmentInventory?.revision == record.equipmentRevision,
        commander.cargoTonnes == record.confirmedCargoTonnes + 1,
        commander.tradeCargoCapacity == record.confirmedCapacity,
        market[index].price == record.quotedPrice, market[index].quantity == record.quotedStock
      else {
        throw MissionPackError(
          "Training fitting or stock changed; cancel and confirm a new practice.")
      }
    } else {
      guard record.routeVerified, systemIdentity == record.destination.location,
        dock.actor.visit == record.journeys.last?.arrivalVisit,
        record.journeys.last?.journey.destination == record.destination.system.id,
        commander.credits <= 4_294_967_295 - market[index].bidPrice
      else {
        if commander.sellableCargo(index) > 0 { return nil }
        throw MissionPackError(
          "The identified tonne requires its selected destination and actual travel receipt.")
      }
    }
    return state.id
  }

  mutating func recordNavigationTradeMarket(
    instance: UUID, buying: Bool, before: borrowing Game, index: Int
  ) throws {
    guard var record = commander.scriptState.instances[instance]?.savedNavigationTrade,
      let dock = before.navigationTradeDock(), record.owner == commander.equipmentOwnerID
    else { throw SaveError.invalidCommander }
    let receipt = ScriptNavigationMarketReceipt(
      operation: UUID(), direction: buying ? .buy : .sell,
      calendarOperation: commander.scriptState.calendarLedger?.operation ?? 0, dock: dock,
      price: buying ? before.market[index].price : before.market[index].bidPrice,
      stockBefore: before.market[index].quantity,
      stockAfter: market[index].quantity, cargoBefore: before.commander.cargo[index],
      cargoAfter: commander.cargo[index], creditsBefore: before.commander.credits,
      creditsAfter: commander.credits)
    guard receipt.valid else { throw SaveError.invalidCommander }
    if buying {
      record.buy = receipt
      record.stage = .held
    } else {
      record.sale = receipt
      record.stage = .sold
    }
    commander.scriptState.instances[instance]?.savedNavigationTrade = record
  }

  mutating func recordNavigationTradeJourney(
    _ journey: ScriptCalendarJourney?, fuelBefore: Int
  ) throws {
    guard let journey else { return }
    for id in commander.scriptState.instances.keys {
      guard var record = commander.scriptState.instances[id]?.savedNavigationTrade,
        record.buy != nil, [.held, .sold].contains(record.stage)
      else { continue }
      guard record.owner == commander.equipmentOwnerID, record.journeys.count < 64,
        !commander.unlimitedFuel
      else { throw SaveError.invalidCommander }
      let receipt = ScriptNavigationJourneyReceipt(
        operation: UUID(), journey: journey,
        arrivalVisit: commander.flightSimulation.visit, fuelBefore: fuelBefore,
        fuelAfter: commander.fuel)
      guard receipt.valid else { throw SaveError.invalidCommander }
      record.journeys.append(receipt)
      commander.scriptState.instances[id]?.savedNavigationTrade = record
    }
  }

  mutating func loseNavigationTradeOnEscape() {
    for id in commander.scriptState.instances.keys {
      guard var record = commander.scriptState.instances[id]?.savedNavigationTrade, record.held,
        let instance = commander.scriptState.instances[id]
      else { continue }
      record.loss = .init(
        operation: UUID(), context: scriptEventContext(instance), cause: "escape-pod")
      record.stage = .lost
      commander.scriptState.instances[id]?.savedNavigationTrade = record
    }
  }
}

extension Commander {
  var hasActiveNavigationTrade: Bool {
    scriptState.instances.values.contains {
      $0.savedNavigationTrade.map { [.awaitingBuy, .held, .sold].contains($0.stage) } == true
    }
  }
  mutating func recordNavigationTradeFuelPurchase(before: borrowing Commander, paid: Int) throws {
    guard fuel > before.fuel else { return }
    for id in scriptState.instances.keys {
      guard var record = scriptState.instances[id]?.savedNavigationTrade,
        [.awaitingBuy, .held, .sold].contains(record.stage)
      else { continue }
      guard record.owner == equipmentOwnerID, record.fuelPurchases.count < 64,
        !unlimitedCash, !unlimitedFuel
      else { throw SaveError.invalidCommander }
      let receipt = ScriptNavigationFuelReceipt(
        operation: UUID(), calendarOperation: scriptState.calendarLedger?.operation ?? 0,
        location: .init(galaxy: galaxy, system: system), unitsBefore: before.fuel, unitsAfter: fuel,
        creditsBefore: before.credits, creditsAfter: credits, paid: paid)
      guard receipt.valid else { throw SaveError.invalidCommander }
      record.fuelPurchases.append(receipt)
      scriptState.instances[id]?.savedNavigationTrade = record
    }
  }
}

extension GameRuntime {
  /// Uses the ordinary actor transaction and filesystem publisher with one ephemeral native binding.
  /// Public input and loaders never accept this authority value from authored or saved data.
  func navigationTradeCommand<T: Sendable>(
    binding: ScriptNavigationTradeBinding, _ action: @Sendable (inout Game) throws -> T
  ) throws -> T {
    guard binding.matches(game) else { throw SaveError.invalidCommander }
    return try scriptCommand(navigationBinding: binding, action)
  }
}
