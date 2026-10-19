import Foundation

struct ScriptFreightIssueReceipt: Codable, Sendable, Equatable {
  let sequence: UInt64
  let clock: Double
  let context: ScriptEventContext
}

struct ScriptFreightTransfer: Codable, Sendable, Equatable {
  let units: [UUID]
  let choice: String
}

enum ScriptFreightTerminalCause: String, Codable, Sendable {
  case delivered, abandoned, expired, shipDestroyed, escapePod
  var outcome: ScriptOutcome {
    switch self {
    case .delivered: return .complete
    case .abandoned: return .abandoned
    default: return .failed
    }
  }
}

struct ScriptFreightPendingLoss: Codable, Sendable, Equatable {
  let id: UUID
  let units: [UUID]
  let clock: Double
  let context: ScriptEventContext
}

struct ScriptFreightTerminal: Codable, Sendable, Equatable {
  let cause: ScriptFreightTerminalCause
  let sequence: UInt64
  let clock: Double
  let removed: [UUID]
}

/// One-tonne issuer-owned units never enter ordinary commodity inventory.
struct ScriptOwnedCargoState: Codable, Sendable, Equatable {
  static let payloadKey = "g03-freight-consignment"
  let schema: Int
  let owner: UUID
  let instance: UUID
  let issuer: ContractStationIdentity
  let commodity: Int
  let consignment: UUID
  let issued: [UUID]
  let issue: ScriptFreightIssueReceipt
  var held: [UUID]
  var transfers: [UInt64: ScriptFreightTransfer] = [:]
  var pendingLoss: ScriptFreightPendingLoss?
  var terminal: ScriptFreightTerminal?

  static func consignmentID(owner: UUID, instance: UUID) -> UUID {
    ScriptIdentity.uuid("freight-consignment-v1:" + owner.uuidString + ":" + instance.uuidString)
  }
  static func unitIDs(consignment: UUID, quantity: Int) -> [UUID] {
    guard (1...10).contains(quantity) else { return [] }
    return (0..<quantity).map {
      ScriptIdentity.uuid("freight-unit-v1:" + consignment.uuidString + ":" + String($0))
    }
  }
  func valid(state: borrowing ScriptInstance, engine: borrowing ScriptEngineState) -> Bool {
    guard schema == 1, let job = state.contract, let plan = job.offer.freightPlan,
      ScriptFreightGeneration.valid(job), owner == plan.owner, instance == state.id,
      issuer == plan.origin, commodity == plan.commodity?.rawValue,
      state.courier == nil, state.savedProviderContract == nil,
      state.campaignParent == nil, state.choiceReceipts.isEmpty, state.timers.isEmpty,
      state.ownedEncounters.isEmpty, state.gearIssues.isEmpty,
      state.milestones == (terminal?.cause == .delivered ? Set([0]) : Set<Int>()),
      consignment == Self.consignmentID(owner: owner, instance: instance),
      issued == Self.unitIDs(consignment: consignment, quantity: plan.quantity),
      Set(issued).count == plan.quantity,
      issue.sequence > 0, issue.sequence <= engine.nextEvent,
      state.hasAcknowledged(issue.sequence), issue.clock == job.acceptedAt,
      issue.context.valid, issue.context.revision == 0, issue.context.mainStation,
      issue.context.nativeMainDock != nil, issue.context.galaxy == issuer.galaxy,
      issue.context.system == issuer.system,
      (engine.missionCalendar?.seconds ?? -1) >= issue.clock,
      Set(state.collections.keys) == [plan.template.id],
      let collection = state.collections[plan.template.id],
      collection.definition == plan.collection,
      Set(transfers.keys) == Set(collection.lots.keys), transfers.count <= plan.quantity,
      Set(transfers.keys) == Set(state.conversationReceipts.keys),
      state.payloads == [Self.payloadKey: held.count]
    else { return false }
    var remaining = issued
    for sequence in transfers.keys.sorted() {
      guard let transfer = transfers[sequence], let lot = collection.lots[sequence],
        let choice = state.conversationReceipts[sequence],
        sequence > issue.sequence, ["freight-one", "freight-all"].contains(transfer.choice),
        choice.choice == transfer.choice, choice.dialogue == plan.deliveryContact,
        choice.cause == lot.cause, choice.committed == lot.committed,
        choice.revision == lot.revision, lot.dialogue == plan.deliveryContact,
        lot.items.count == 1, let item = lot.items.first,
        item.commodity == commodity, item.unit == "t", item.quantity == transfer.units.count,
        !transfer.units.isEmpty,
        transfer.units
          == Array(remaining.prefix(transfer.choice == "freight-one" ? 1 : remaining.count))
      else { return false }
      remaining.removeFirst(transfer.units.count)
    }
    if let loss = pendingLoss {
      guard terminal == nil, loss.units == remaining, !remaining.isEmpty, !loss.context.docked,
        loss.id == ScriptIdentity.uuid("freight-fatal-v1:" + consignment.uuidString),
        loss.context.valid, loss.clock.isFinite, loss.clock >= issue.clock,
        loss.clock <= engine.clock(.missionCalendar)
      else { return false }
    }
    if let terminal {
      guard state.outcome == terminal.cause.outcome, job.settled,
        terminal.sequence > issue.sequence, terminal.sequence <= engine.nextEvent,
        state.hasAcknowledged(terminal.sequence), terminal.clock == job.settledAt,
        terminal.clock <= engine.clock(.missionCalendar),
        held.isEmpty, pendingLoss == nil,
        let receipt = state.completionReceipt, receipt.sequence == terminal.sequence,
        receipt.outcome == state.outcome, plan.deadlineMatches(job)
      else { return false }
      if terminal.cause == .delivered {
        return remaining.isEmpty && terminal.removed.isEmpty && collection.complete
          && transfers[terminal.sequence] != nil
          && plan.permitsDelivery(at: terminal.clock, deadline: job.deadline)
          && job.settlementAmount == plan.successPayment
      }
      guard terminal.removed == remaining, !remaining.isEmpty, job.settlementAmount == 0 else {
        return false
      }
      return (terminal.cause != .expired
        || plan.permitsExpiry(at: terminal.clock, deadline: job.deadline))
        && (terminal.cause != .abandoned
          || plan.permitsDelivery(at: terminal.clock, deadline: job.deadline))
    }
    guard state.outcome == .active, !job.settled, state.completionReceipt == nil else {
      return false
    }
    return held == remaining && !remaining.isEmpty
  }
}

extension Commander {
  func freightHistoricalContextValid(_ context: ScriptEventContext, requiresDock: Bool) -> Bool {
    guard context.valid, context.localSeconds <= scriptState.localSeconds,
      context.flightSeconds <= scriptState.flightSeconds,
      context.calendarSeconds <= scriptState.calendarSeconds,
      context.transitSeconds <= scriptState.transitSeconds
    else { return false }
    if let facts = context.nativeStation {
      guard let world = nativeStations, let owner = equipmentOwnerID,
        facts.receipt.commanderOwner == owner, world.ledger.world == owner,
        facts.receipt.station.world == owner,
        facts.receipt.sequence < world.ledger.nextDockSequence,
        facts.receipt.dockingBinding.actor.visit <= flightSimulation.visit,
        let record = world.ledger.records.first(where: { $0.identity == facts.receipt.station }),
        facts.receipt.lifecycleRevision <= record.revision
      else { return false }
    }
    guard let dock = context.nativeMainDock else { return !requiresDock }
    guard let world = nativeStations, let owner = equipmentOwnerID else { return false }
    return dock.commanderOwner == owner && world.ledger.world == owner
      && dock.station.world == owner && world.mainStations.contains(dock.station)
      && dock.sequence < world.nextMainDockSequence && dock.actor.visit <= flightSimulation.visit
      && dock.calendarSeconds <= context.calendarSeconds
  }

  func freightStateValid(_ state: borrowing ScriptInstance) -> Bool {
    guard let plan = state.contract?.offer.freightPlan else {
      guard state.savedOwnedCargo == nil else { return false }
      return !ScriptFreightPlan.isMarked(state.contract?.offer.parameters ?? .null)
    }
    guard let cargo = state.savedOwnedCargo, cargo.valid(state: state, engine: scriptState),
      cargo.owner == equipmentOwnerID, state.definition == plan.content.stateID,
      state.version == plan.content.version, state.digest == plan.content.digest,
      freightHistoricalContextValid(cargo.issue.context, requiresDock: true),
      state.collections[plan.template.id]?.lots.values.allSatisfy({ lot in
        lot.cause.nativeMainDock == lot.committed.nativeMainDock
          && freightHistoricalContextValid(lot.cause, requiresDock: true)
          && freightHistoricalContextValid(lot.committed, requiresDock: true)
      }) == true,
      cargo.pendingLoss.map({ freightHistoricalContextValid($0.context, requiresDock: false) })
        ?? true
    else { return false }
    guard let terminal = cargo.terminal else { return true }
    guard let receipt = state.completionReceipt, let cause = receipt.cause,
      receipt.valid(for: state, engine: scriptState),
      freightHistoricalContextValid(
        cause, requiresDock: terminal.cause == .delivered || terminal.cause == .abandoned),
      freightHistoricalContextValid(
        receipt.committed,
        requiresDock: terminal.cause == .delivered || terminal.cause == .abandoned)
    else { return false }
    switch terminal.cause {
    case .delivered:
      guard let lot = state.collections[plan.template.id]?.lots[terminal.sequence] else {
        return false
      }
      return receipt.causeKind == "dialogue.confirmed" && lot.cause == cause
        && lot.revision == receipt.revision && lot.committed == receipt.committed
    case .abandoned:
      return receipt.causeKind == "dialogue.confirmed" && cause.galaxy == plan.origin.galaxy
        && cause.system == plan.origin.system
        && cause.nativeMainDock == receipt.committed.nativeMainDock
    case .expired, .shipDestroyed, .escapePod:
      return receipt.causeKind == "freight.terminated"
        && (terminal.cause == .expired || !cause.docked)
    }
  }

  var freightCargoValid: Bool {
    guard scriptState.instances.values.allSatisfy({ freightStateValid($0) }) else { return false }
    let cargo = scriptState.instances.values.compactMap(\.savedOwnedCargo)
    let units = cargo.flatMap(\.issued)
    guard Set(units).count == units.count else { return false }
    guard cargo.contains(where: { !$0.held.isEmpty }) else { return true }
    guard let tonnes = checkedCargoTonnes else { return false }
    return tonnes <= standardCargoCapacity
  }
}
