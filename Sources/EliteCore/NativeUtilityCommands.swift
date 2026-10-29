import Foundation

struct NativeUtilityQuote: Equatable, Sendable {
  let action: NativeUtilityAction
  let expected: NativeUtilityState
  let hull: UUID
  let inventoryRevision: UInt64
  let source: NativeMainStationArrivalContext?
  let target: NativeUtilityServiceContext?
  let route: [Int]
  let firstLegReach: Double
  let fullTankReach: Double
  var rewardTenths: Int { 6100 + 1100 * max(0, route.count - 1) }
}

extension Game {
  func nativeUtilityQuote(_ action: NativeUtilityAction) throws -> NativeUtilityQuote {
    guard !paused, docked, scriptDurabilityAvailable, commander.valid,
      let utility = commander.nativeUtility, let inventory = commander.equipmentInventory,
      inventory.owner == utility.owner, utility.revision < UInt64(Int64.max) - 1
    else {
      throw MissionPackError("A current dock, original property and durable writer are required.")
    }
    if action != .returnMaterials, fieldReliefPack == nil {
      throw MissionPackError("Restore the original field-relief mission content.")
    }
    if action == .collect {
      try OriginalServiceReservationPolicy.requireAvailableSlot(commander.scriptState)
    }
    var source: NativeMainStationArrivalContext?
    var target: NativeUtilityServiceContext?
    var route: [Int] = []
    let first = commander.maximumJumpDistance
    let full = commander.fullTankJumpDistance
    switch action {
    case .collect:
      guard utility.active == nil, utility.consignments.count < 2,
        let record = commander.nativeStations?.ledger.records.first(where: {
          NativeUtilityState.isTarget($0.identity)
        }),
        record.tombstone == nil,
        let context = nativeMainStationArrivalContext(for: utility.source),
        let total = commander.checkedCargoTonnes, total <= commander.standardCargoCapacity - 4
      else {
        throw MissionPackError(
          "Collect four original tonnes at Avenor with physical hold available.")
      }
      source = context
      route = try nativeUtilityRoute(first: first, full: full)
    case .returnMaterials:
      guard utility.active?.phase == .held,
        let context = nativeMainStationArrivalContext(for: utility.source)
      else { throw MissionPackError("Return the original held materials to their actual source.") }
      source = context
    case .install:
      guard utility.active?.phase == .held, let context = nativeUtilityServiceContext,
        utility.installedCount < 2
      else {
        throw MissionPackError(
          "Installation requires the original materials and the living receiving utility.")
      }
      target = context
    case .receive:
      guard let job = utility.active, job.phase == .installed,
        let installation = job.installation, let context = nativeUtilityServiceContext,
        installation.contact.lifecycle == context.receipt.lifecycleRevision
      else {
        throw MissionPackError(
          "The current engineer must inspect the original installed regulator.")
      }
      target = context
    }
    return .init(
      action: action, expected: utility, hull: inventory.activeHull,
      inventoryRevision: inventory.revision, source: source, target: target, route: route,
      firstLegReach: first, fullTankReach: full)
  }

  private func nativeUtilityRoute(first: Double, full: Double) throws -> [Int] {
    guard first.isFinite, full.isFinite, first > 0, full > 0 else {
      throw MissionPackError("The quoted route requires native fuel reach.")
    }
    let worlds = Universe.systemsIncludingPlugh(number: 0)
    let adjacency = (0..<256).map { a in
      (0..<256).filter { b in a != b && worlds[a].distance(to: worlds[b]) <= max(first, full) }
    }
    guard
      let route = NavigationRouteSearch.path(
        adjacency: adjacency, from: 7, to: 237,
        edgeWeight: { a, b, initial in
          worlds[a].distance(to: worlds[b]) <= (initial ? first : full) ? 1 : nil
        })
    else { throw MissionPackError("No natively reachable route to the receiving headquarters.") }
    return route
  }

  mutating func confirmNativeUtility(_ quote: NativeUtilityQuote) throws {
    let current = try nativeUtilityQuote(quote.action)
    guard current == quote else {
      throw MissionPackError("The utility operation changed; review it again.")
    }
    var state = quote.expected
    state.revision += 1
    switch quote.action {
    case .collect:
      guard let source = quote.source else { throw SaveError.invalidCommander }
      let index = state.consignments.count
      state.consignments.append(
        .init(
          id: state.consignmentID(index), originalUnits: state.units(index),
          hull: quote.hull, source: .init(source.receipt), route: quote.route,
          firstLegReach: quote.firstLegReach, fullTankReach: quote.fullTankReach,
          rewardTenths: quote.rewardTenths))
    case .install:
      guard let target = quote.target,
        let index = state.consignments.firstIndex(where: { $0.phase == .held })
      else { throw SaveError.invalidCommander }
      let used = Set(state.consignments.compactMap { $0.installation?.socket })
      guard let socket = (0..<2).first(where: { !used.contains($0) }) else {
        throw SaveError.invalidCommander
      }
      let id = state.consignments[index].id
      let receipt = NativeUtilityInstallation(
        operation: state.operation(id, stage: "install", revision: state.revision),
        component: state.component(socket), engineer: target.engineer, socket: socket,
        contact: .init(target.receipt), revision: state.revision)
      state.consignments[index].installation = receipt
      state.consignments[index].phase = .installed
    case .receive:
      guard let target = quote.target,
        let index = state.consignments.firstIndex(where: { $0.phase == .installed }),
        let installed = state.consignments[index].installation
      else { throw SaveError.invalidCommander }
      let id = state.consignments[index].id
      state.consignments[index].reception = .init(
        operation: state.operation(id, stage: "receive", revision: state.revision),
        installation: installed.operation, engineer: target.engineer,
        contact: .init(target.receipt), revision: state.revision)
      state.consignments[index].phase = .received
    case .returnMaterials:
      guard let source = quote.source,
        let index = state.consignments.firstIndex(where: { $0.phase == .held })
      else { throw SaveError.invalidCommander }
      state.consignments[index].returned = .init(source.receipt)
      state.consignments[index].phase = .returned
    }
    try replaceNativeUtility(state, previous: quote.expected, action: quote.action)
    notify(
      quote.action == .receive
        ? "CREW RECEIPT AND FIELD RELIEF PAYMENT RECORDED"
        : "UTILITY PROPERTY RECORDED")
  }

  private mutating func replaceNativeUtility(
    _ state: NativeUtilityState, previous: NativeUtilityState, action: NativeUtilityAction?
  ) throws {
    guard var world = commander.nativeStations else { throw SaveError.invalidCommander }
    try world.ledger.replaceUtility(state)
    var candidate = commander
    candidate.nativeStations = world
    // Swap with the existing candidate, so native and story joins become valid together.
    // On refusal the original Commander is restored before the actor publication boundary.
    swap(&commander, &candidate)
    do {
      try applyFieldReliefTransition(previous: previous, action: action)
      guard commander.valid else { throw SaveError.invalidCommander }
    } catch {
      swap(&commander, &candidate)
      throw error
    }
  }

  mutating func recordNativeUtilityLoss(_ cause: NativeUtilityLossCause) throws {
    guard var state = commander.nativeUtility, state.heldTonnes > 0 else { return }
    guard scriptDurabilityAvailable, !docked, !paused, energy.isFinite,
      cause == .shipDestroyed ? screen == .gameOver && energy <= 0 : screen.isFlight && energy > 0,
      state.revision < UInt64(Int64.max) - 1,
      let index = state.consignments.firstIndex(where: { $0.phase == .held })
    else { throw SaveError.invalidCommander }
    state.revision += 1
    state.consignments[index].loss = .init(
      cause: cause, visit: commander.flightSimulation.visit,
      physicalTime: commander.flightSimulation.physicalTime, energy: energy)
    state.consignments[index].phase = .lost
    try replaceNativeUtility(state, previous: commander.nativeUtility!, action: nil)
  }
  mutating func loseNativeUtilityOnEscape() throws { try recordNativeUtilityLoss(.escape) }
}

extension GameRuntime {
  func nativeUtilityQuote(_ action: NativeUtilityAction) throws -> NativeUtilityQuote {
    try game.nativeUtilityQuote(action)
  }
  func confirmNativeUtility(_ quote: NativeUtilityQuote) throws {
    try scriptCommand { try $0.confirmNativeUtility(quote) }
  }
  func commitNativeUtilityFatalLoss() {
    guard (game.commander.nativeUtility?.heldTonnes ?? 0) > 0,
      !game.docked, game.screen == .gameOver, game.energy.isFinite, game.energy <= 0
    else { return }
    do { try scriptCommand { try $0.recordNativeUtilityLoss(.shipDestroyed) } } catch {
      game.notify("UTILITY MATERIAL LOSS NOT SAVED - ORIGINAL CUSTODY RETAINED")
    }
  }
}
