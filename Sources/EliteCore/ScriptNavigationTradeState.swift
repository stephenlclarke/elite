import Foundation

/// Original world identity and the actual native system selected at confirmation.
/// These saved facts are evidence; only a native binding supplied by the caller authorizes them.
struct ScriptNavigationTradeEndpoint: Codable, Sendable, Equatable {
  let worldID: String
  let galaxy: Int
  let system: StarSystem
  var valid: Bool {
    guard (0..<8).contains(galaxy), (0..<256).contains(system.id),
      !system.name.isEmpty, system.name.count <= 64, system.x.isFinite, system.y.isFinite,
      (0...7).contains(system.economy), (0...7).contains(system.government),
      (0...32).contains(system.technology)
    else { return false }
    if let original = system.original {
      guard let canonical = try? Universe.originalWorld(galaxy: galaxy, system: system.id) else {
        return false
      }
      return worldID == canonical.key && original == canonical
        && system == Universe.nativeSystem(canonical)
    }
    // Explicit isolated fixture bindings retain their private identifier namespace. Production
    // always requires complete original records above and never authorizes these test endpoints.
    return PackValidation.identifier(worldID)
  }
  var location: SystemIdentity { .init(galaxy: galaxy, system: system.id) }
}

/// A single selected-route binding, not a mutable registry or saved authorization.
/// Native endpoint bindings are re-resolved against the installed original world authority.
struct ScriptNavigationTradeBinding: Sendable, Equatable {
  let training: ScriptNavigationTradeEndpoint
  let destination: ScriptNavigationTradeEndpoint
  static func production(in game: borrowing Game) -> Self? {
    let active = game.commander.scriptState.instances.values.filter { $0.outcome == .active }
    if let record = active.compactMap(\.savedNavigationTrade).first(where: {
      $0.stage == .awaitingBuy || $0.held || $0.stage == .sold || $0.stage == .lost
    }) {
      return production(for: record)
    }
    return selectedRoute(in: game)
  }
  static func selectedRoute(in game: borrowing Game) -> Self? {
    guard let training = endpoint(galaxy: game.commander.galaxy, system: game.commander.system),
      let destination = endpoint(galaxy: game.commander.galaxy, system: game.selectedSystem)
    else { return nil }
    let result = Self(training: training, destination: destination)
    return result.valid && result.matches(game) ? result : nil
  }
  static func production(for record: borrowing ScriptNavigationTradeState) -> Self? {
    guard
      let training = endpoint(galaxy: record.training.galaxy, system: record.training.system.id),
      let destination = endpoint(
        galaxy: record.destination.galaxy, system: record.destination.system.id),
      training == record.training, destination == record.destination
    else { return nil }
    let result = Self(training: training, destination: destination)
    return result.valid ? result : nil
  }
  private static func endpoint(galaxy: Int, system: Int) -> ScriptNavigationTradeEndpoint? {
    guard let world = try? Universe.originalWorld(galaxy: galaxy, system: system) else {
      return nil
    }
    let native = Universe.nativeSystem(world)
    return .init(worldID: world.key, galaxy: galaxy, system: native)
  }
  var valid: Bool {
    training.valid && destination.valid && training.galaxy == destination.galaxy
      && training.worldID != destination.worldID && training.system.id != destination.system.id
  }
  func matches(_ game: borrowing Game) -> Bool {
    guard valid else { return false }
    let galaxy = game.commander.galaxy
    guard galaxy == training.galaxy else { return false }
    let systems = game.systems
    return systems.indices.contains(training.system.id)
      && systems.indices.contains(destination.system.id)
      && systems[training.system.id] == training.system
      && systems[destination.system.id] == destination.system
  }
}

struct ScriptNavigationMarketReceipt: Codable, Sendable, Equatable {
  enum Direction: String, Codable, Sendable { case buy, sell }
  let operation: UUID
  let direction: Direction
  let calendarOperation: UInt64
  let dock: NativeMainStationDockReceipt
  let price: Int
  let stockBefore: Int
  let stockAfter: Int
  let cargoBefore: Int
  let cargoAfter: Int
  let creditsBefore: Int
  let creditsAfter: Int
  var valid: Bool {
    guard dock.valid, (0...1_000_000).contains(price),
      [stockBefore, stockAfter].allSatisfy({ (0...1_000_000).contains($0) }),
      [cargoBefore, cargoAfter].allSatisfy({ (0...1_000_000).contains($0) }),
      [creditsBefore, creditsAfter].allSatisfy({ (0...4_294_967_295).contains($0) })
    else { return false }
    return direction == .buy
      ? stockBefore > 0 && stockAfter == stockBefore - 1 && cargoAfter == cargoBefore + 1
        && creditsAfter == creditsBefore - price
      : cargoBefore > 0 && cargoAfter == cargoBefore - 1 && stockAfter == stockBefore + 1
        && creditsAfter == creditsBefore + price
  }
}

struct ScriptNavigationFuelReceipt: Codable, Sendable, Equatable {
  let operation: UUID
  let calendarOperation: UInt64
  let location: SystemIdentity
  let unitsBefore: Int
  let unitsAfter: Int
  let creditsBefore: Int
  let creditsAfter: Int
  let paid: Int
  var valid: Bool {
    (0...10_000).contains(unitsBefore) && (0...10_000).contains(unitsAfter)
      && unitsAfter > unitsBefore && (0...1_000_000).contains(paid)
      && [creditsBefore, creditsAfter].allSatisfy { (0...4_294_967_295).contains($0) }
      && creditsAfter == creditsBefore - paid
      && (0..<8).contains(location.galaxy) && (0...256).contains(location.system)
  }
}

struct ScriptNavigationJourneyReceipt: Codable, Sendable, Equatable {
  let operation: UUID
  let journey: ScriptCalendarJourney
  let arrivalVisit: UInt64
  let fuelBefore: Int
  let fuelAfter: Int
  var valid: Bool {
    journey.valid && journey.nativeFuelDebit > 0 && arrivalVisit > 0
      && arrivalVisit < UInt64(Int64.max) && (0...10_000).contains(fuelBefore)
      && (0...10_000).contains(fuelAfter)
      && fuelAfter == fuelBefore - journey.nativeFuelDebit
  }
}

struct ScriptNavigationTradeContactReceipt: Codable, Sendable, Equatable {
  let operation: UUID
  let sequence: UInt64
  let context: ScriptEventContext
  let dock: NativeMainStationDockReceipt
  var valid: Bool {
    sequence > 0 && context.valid && context.docked && context.mainStation && dock.valid
      && dock.calendarSeconds <= context.calendarSeconds
      && dock.station.system == .init(galaxy: context.galaxy, system: context.system)
  }
}

struct ScriptNavigationTradeLoss: Codable, Sendable, Equatable {
  let operation: UUID
  let context: ScriptEventContext
  let cause: String
  var valid: Bool { context.valid && cause == "escape-pod" }
}

/// One real identified tonne, carried in ordinary cargo exactly once and reserved from unrelated sale.
struct ScriptNavigationTradeState: Codable, Sendable, Equatable {
  enum Stage: String, Codable, Sendable { case awaitingBuy, held, sold, received, cancelled, lost }
  let owner: UUID
  let instance: UUID
  let definition: String
  let version: String
  let digest: String
  let training: ScriptNavigationTradeEndpoint
  let destination: ScriptNavigationTradeEndpoint
  let commodity: Int
  let acceptance: ScriptNavigationTradeContactReceipt
  let acceptedHull: UUID
  let equipmentRevision: UInt64
  let confirmedCapacity: Int
  let confirmedCargoTonnes: Int
  let quotedPrice: Int
  let quotedStock: Int
  let routeDistance: Double
  let plannedFuelDebit: Int
  var stage: Stage = .awaitingBuy
  var buy: ScriptNavigationMarketReceipt?
  var journeys: [ScriptNavigationJourneyReceipt] = []
  var fuelPurchases: [ScriptNavigationFuelReceipt] = []
  var sale: ScriptNavigationMarketReceipt?
  var reception: ScriptNavigationTradeContactReceipt?
  var cancellation: ScriptNavigationTradeContactReceipt?
  var loss: ScriptNavigationTradeLoss?

  var held: Bool { buy != nil && sale == nil && cancellation == nil && loss == nil }
  var selectedJourney: ScriptNavigationJourneyReceipt? {
    journeys.first {
      $0.journey.galaxy == training.galaxy && $0.journey.origin == training.system.id
        && $0.journey.destination == destination.system.id
        && $0.journey.nativeFuelDebit == plannedFuelDebit
        && $0.journey.operation > (buy?.calendarOperation ?? UInt64.max)
    }
  }
  var routeVerified: Bool { selectedJourney != nil }
  var fuelUnitsUsed: Int { journeys.reduce(0) { $0 + $1.journey.nativeFuelDebit } }
  var fuelPaid: Int { fuelPurchases.reduce(0) { $0 + $1.paid } }
  var commodityDifference: Int? { sale.flatMap { sale in buy.map { sale.price - $0.price } } }
  var cashDifference: Int? { commodityDifference.map { $0 - fuelPaid } }
  var operations: [UUID] {
    [acceptance.operation]
      + [
        buy?.operation, sale?.operation, reception?.operation,
        cancellation?.operation, loss?.operation,
      ].compactMap { $0 }
      + journeys.map(\.operation) + fuelPurchases.map(\.operation)
  }

  func valid(instance state: ScriptInstance, engine: ScriptEngineState) -> Bool {
    guard instance == state.id && definition == state.definition && version == state.version,
      digest == state.digest, training.valid, destination.valid,
      training.galaxy == destination.galaxy && training.worldID != destination.worldID,
      training.system.id != destination.system.id,
      Commodity.all.indices.contains(commodity), Commodity.all[commodity].unit == "t",
      ![3, 6, 10, 16].contains(commodity), acceptance.valid,
      acceptance.sequence <= engine.nextEvent && state.hasAcknowledged(acceptance.sequence),
      acceptance.dock.commanderOwner == owner,
      acceptance.dock.station.system == training.location,
      acceptance.context.galaxy == training.galaxy
        && acceptance.context.system == training.system.id,
      confirmedCapacity > confirmedCargoTonnes && confirmedCargoTonnes >= 0,
      confirmedCapacity <= 1_000_000 && equipmentRevision < UInt64(Int64.max),
      acceptance.context.localSeconds <= engine.localSeconds,
      acceptance.context.flightSeconds <= engine.flightSeconds,
      acceptance.context.calendarSeconds <= engine.calendarSeconds,
      acceptance.context.transitSeconds <= engine.transitSeconds,
      (0...1_000_000).contains(quotedPrice) && (1...1_000_000).contains(quotedStock),
      routeDistance > 0 && routeDistance <= 200,
      routeDistance == training.system.distance(to: destination.system), plannedFuelDebit > 0,
      journeys.count <= 64 && fuelPurchases.count <= 64,
      journeys.allSatisfy(\.valid) && fuelPurchases.allSatisfy(\.valid),
      Set(operations).count == operations.count,
      [buy, sale].compactMap({ $0 }).allSatisfy({
        $0.valid && $0.dock.commanderOwner == owner
          && $0.calendarOperation <= (engine.calendarLedger?.operation ?? 0)
      }),
      zip(journeys, journeys.dropFirst()).allSatisfy({ $0.journey.operation < $1.journey.operation }
      ),
      journeys.allSatisfy({ $0.journey.operation <= (engine.calendarLedger?.operation ?? 0) }),
      fuelPurchases.allSatisfy({ $0.calendarOperation <= (engine.calendarLedger?.operation ?? 0) })
    else { return false }
    if let buy {
      guard buy.direction == .buy, buy.dock.station.system == training.location,
        buy.price == quotedPrice, buy.stockBefore == quotedStock, buy.cargoBefore == 0
      else { return false }
    }
    if let sale {
      guard buy != nil, let selectedJourney, sale.direction == .sell,
        sale.dock.station.system == destination.location,
        journeys.contains(where: {
          $0.journey.galaxy == destination.galaxy && $0.journey.destination == destination.system.id
            && $0.arrivalVisit == sale.dock.actor.visit
            && $0.journey.operation >= selectedJourney.journey.operation
            && $0.journey.operation <= sale.calendarOperation
        })
      else { return false }
    }
    for contact in [reception, cancellation].compactMap({ $0 }) {
      guard contact.valid, contact.dock.commanderOwner == owner,
        contact.sequence > acceptance.sequence && contact.sequence <= engine.nextEvent,
        state.hasAcknowledged(contact.sequence), contact.context.revision <= state.revision,
        contact.context.localSeconds <= engine.localSeconds,
        contact.context.flightSeconds <= engine.flightSeconds,
        contact.context.calendarSeconds <= engine.calendarSeconds,
        contact.context.transitSeconds <= engine.transitSeconds
      else { return false }
    }
    if let loss {
      guard loss.valid, loss.context.revision <= state.revision,
        loss.context.localSeconds <= engine.localSeconds,
        loss.context.flightSeconds <= engine.flightSeconds,
        loss.context.calendarSeconds <= engine.calendarSeconds,
        loss.context.transitSeconds <= engine.transitSeconds
      else { return false }
    }
    switch stage {
    case .awaitingBuy:
      return state.outcome == .active && buy == nil && sale == nil && journeys.isEmpty
        && reception == nil && cancellation == nil && loss == nil
    case .held:
      return state.outcome == .active && held && reception == nil
    case .sold:
      return state.outcome == .active && sale != nil && reception == nil
        && cancellation == nil && loss == nil
    case .received:
      guard let reception else { return false }
      return state.outcome == .complete && sale != nil
        && reception.dock.station.system == training.location
        && reception.dock.sequence > acceptance.dock.sequence
        && journeys.last?.journey.destination == training.system.id
        && reception.dock.actor.visit == journeys.last?.arrivalVisit
        && (journeys.last?.journey.operation ?? 0) > (sale?.calendarOperation ?? UInt64.max)
        && cancellation == nil && loss == nil
    case .cancelled:
      return state.outcome == .abandoned && cancellation != nil && reception == nil && loss == nil
    case .lost:
      return state.outcome != .complete && state.outcome != .abandoned && loss?.valid == true
        && buy != nil && sale == nil && reception == nil && cancellation == nil
    }
  }
}

extension Commander {
  func reservedNavigationTradeCargo(_ commodity: Int) -> Int {
    scriptState.instances.values.reduce(0) { count, instance in
      count
        + (instance.savedNavigationTrade?.held == true
          && instance.savedNavigationTrade?.commodity == commodity ? 1 : 0)
    }
  }
  var navigationTradeStateValid: Bool {
    guard cargo.count == Commodity.all.count, scriptState.instances.count <= 128 else {
      return false
    }
    let records = scriptState.instances.values.compactMap(\.savedNavigationTrade)
    guard !records.isEmpty else { return true }
    var held: [Int: Int] = [:]
    for record in records {
      guard record.owner == equipmentOwnerID, Commodity.all.indices.contains(record.commodity)
      else { return false }
      if record.held { held[record.commodity, default: 0] += 1 }
    }
    let operations = records.flatMap(\.operations)
    return records.filter { $0.stage == .awaitingBuy || $0.held || $0.stage == .sold }.count <= 1
      && held.allSatisfy { $0.value <= cargo[$0.key] }
      && Set(operations).count == operations.count
  }
}
