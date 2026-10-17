import Foundation

enum RRSCourierRow: Sendable, Equatable {
  case offer(RRSCourierBoard)
  case debrief(UUID)
  case abandon(UUID)
  var canDecline: Bool {
    if case .offer = self { return true }
    return false
  }
  var key: String {
    switch self {
    case .offer(let board): board.key
    case .debrief(let id): "rrs-debrief:" + id.uuidString
    case .abandon(let id): "rrs-abandon:" + id.uuidString
    }
  }
  var title: String {
    switch self {
    case .offer: RRSCourierContent.title
    case .debrief: "RRS / Deliver sealed documents"
    case .abandon: "RRS / Abandon document assignment"
    }
  }
}

/// Transient review binds real private-init service contexts; saved facts never mint authority.
struct RRSCourierQuote: Sendable {
  let row: RRSCourierRow
  let resources: Commander
  let epoch: UUID
  let board: NativeStationBoardContext?
  let destination: NativeMainStationDestinationContext?
  let arrival: NativeMainStationArrivalContext?
  let issues: [String]
  let reviewToken = UUID()
  var allowed: Bool { issues.isEmpty }
}

extension Game {
  mutating func ensureRRSCourierBoard() throws {
    guard let context = nativeStationBoardContext, acceptsNativeStationBoardContext(context),
      let owner = commander.equipmentOwnerID, owner == context.station.world
    else { throw MissionPackError("A genuine current RRS dock and save writer are required.") }
    var ledger = commander.contracts.rrs ?? RRSCourierLedger(owner: owner)
    guard ledger.owner == owner, ledger.valid else { throw SaveError.invalidCommander }
    if ledger.boards[context.station.key]?.hour != context.hour {
      ledger.boards[context.station.key] = .init(station: context.station, hour: context.hour)
    }
    var contracts = commander.contracts
    contracts.rrs = ledger
    commander.contracts = contracts
    guard commander.contractsValid else { throw SaveError.invalidCommander }
  }

  var rrsCourierRows: [ContractBoardRow] {
    guard let ledger = commander.contracts.rrs else { return [] }
    var values: [RRSCourierRow] = []
    if let active = ledger.active {
      values = [.debrief(active.id), .abandon(active.id)]
    } else if let context = nativeStationBoardContext,
      let board = ledger.boards[context.station.key], board.hour == context.hour,
      board.accepted == nil, !board.declined,
      RRSCourierContent.eligible(
        reputation: ledger.reputation, legal: context.legal,
        draw: RRSCourierContent.draw(board.seed))
    {
      values = [.offer(board)]
    }
    return values.map { row in
      .init(
        board: row.key, offer: nil, title: row.title,
        reason: rrsCourierQuote(for: row).issues.first, rrs: row)
    }
  }

  func rrsCourierQuote(for row: RRSCourierRow) -> RRSCourierQuote {
    var issues: [String] = []
    var boardContext: NativeStationBoardContext?
    var destination: NativeMainStationDestinationContext?
    var arrival: NativeMainStationArrivalContext?
    let ledger = commander.contracts.rrs
    if !scriptDurabilityAvailable { issues.append("Bind a writable commander save first.") }
    if paused { issues.append("Resume play before confirming.") }
    if ledger?.valid(for: commander) != true {
      issues.append("RRS ledger ownership is unavailable.")
    }
    switch row {
    case .offer(let board):
      boardContext = nativeStationBoardContext
      if let context = boardContext,
        acceptsNativeStationBoardContext(context), context.station == board.station,
        context.hour == board.hour, ledger?.boards[board.station.key] == board
      {
        if !RRSCourierContent.eligible(
          reputation: ledger?.reputation ?? Int.min, legal: context.legal,
          draw: RRSCourierContent.draw(board.seed))
        {
          issues.append("Requires RRS reputation at least -10 and bounty at most 50.")
        }
      } else {
        issues.append("The station, board hour or dock authority changed. Refresh offers.")
      }
      if board.declined || board.accepted != nil {
        issues.append("This offer is no longer available.")
      }
      if ledger?.active != nil { issues.append("Only one RRS assignment may be active.") }
      if (ledger?.jobs.count ?? RRSCourierLedger.maximumJobs) >= RRSCourierLedger.maximumJobs {
        issues.append("RRS receipt capacity reached.")
      }
      if case .living(let context) = nativeOriginalMainStationDestination,
        context.identity.system == board.station.system,
        context.identity.world == board.station.world, acceptsNativeMainStationDestination(context)
      {
        destination = context
      } else {
        issues.append("The living original main station cannot currently be proved.")
      }
    case .debrief(let id), .abandon(let id):
      guard let active = ledger?.active, active.id == id else {
        issues.append("This assignment has already ended.")
        return .init(
          row: row, resources: commander.contractQuoteResources,
          epoch: nativeStationRuntimeEpoch, board: nil, destination: nil, arrival: nil,
          issues: issues)
      }
      if rrsCourierFailure(for: active) != nil {
        issues.append("This assignment has failed; its outcome must be saved first.")
      }
      if case .debrief = row {
        arrival = nativeMainStationArrivalContext(for: active.destination)
        if arrival == nil {
          issues.append("Dock at the original main orbital station to Confirm delivery.")
        }
      } else if !docked
        || (nativeStationBoardContext == nil
          && nativeMainStationArrivalContext(for: active.destination) == nil)
      {
        issues.append("Confirm abandonment at a proved RRS or original main station dock.")
      }
    }
    return .init(
      row: row, resources: commander.contractQuoteResources,
      epoch: nativeStationRuntimeEpoch, board: boardContext, destination: destination,
      arrival: arrival, issues: issues)
  }

  mutating func confirmRRSCourier(_ quote: RRSCourierQuote) throws {
    guard quote.allowed, quote.epoch == nativeStationRuntimeEpoch,
      quote.resources == commander.contractQuoteResources,
      rrsCourierQuote(for: quote.row).allowed
    else { throw MissionPackError("The RRS review changed. Read the current briefing again.") }
    switch quote.row {
    case .offer(var board):
      guard let context = quote.board, let destination = quote.destination,
        acceptsNativeStationBoardContext(context), acceptsNativeMainStationDestination(destination),
        var ledger = commander.contracts.rrs, ledger.active == nil,
        let source = NativeStationSource.binding(for: context.station)
      else { throw MissionPackError("RRS acceptance authority is stale.") }
      board.accepted = board.offer
      let job = RRSCourierJob(
        board: board, origin: context.service.receipt,
        descriptor: source.descriptor,
        destination: destination.identity, acceptedAt: commander.scriptState.calendarSeconds,
        acceptedLegal: context.legal, acceptedReputation: ledger.reputation,
        acceptedEpoch: context.service.runtimeEpoch, boardProfile: context.profileRevision,
        adapterRevision: context.adapterRevision, geometryRevision: context.geometryRevision,
        sourceSHA256: RRSCourierContent.source,
        packet: RRSCourierContent.packetID(board.offer))
      ledger.boards[board.station.key] = board
      ledger.jobs.append(job)
      try publishRRSCourierLedger(ledger)
    case .debrief(let id):
      guard let arrival = quote.arrival, acceptsNativeMainStationArrivalContext(arrival) else {
        throw MissionPackError(
          "A genuine current arrival at the original main station is required.")
      }
      try settleRRSCourier(id, outcome: .delivered, arrival: arrival.receipt)
    case .abandon(let id):
      try settleRRSCourier(id, outcome: .abandoned)
    }
  }

  mutating func declineRRSCourier(_ quote: RRSCourierQuote) throws {
    guard case .offer(var board) = quote.row, let context = quote.board,
      quote.epoch == nativeStationRuntimeEpoch, quote.resources == commander.contractQuoteResources,
      acceptsNativeStationBoardContext(context), var ledger = commander.contracts.rrs,
      ledger.boards[board.station.key] == board, board.accepted == nil, !board.declined
    else { throw MissionPackError("This RRS offer changed. Refresh offers.") }
    board.declined = true
    ledger.boards[board.station.key] = board
    try publishRRSCourierLedger(ledger)
  }

  private mutating func publishRRSCourierLedger(_ ledger: RRSCourierLedger, reward: Int = 0) throws
  {
    var candidate = commander
    var contracts = candidate.contracts
    contracts.rrs = ledger
    candidate.contracts = contracts
    let credits = candidate.credits.addingReportingOverflow(reward)
    guard !credits.overflow else { throw SaveError.invalidCommander }
    candidate.credits = credits.partialValue
    guard candidate.valid else { throw SaveError.invalidCommander }
    commander = candidate
  }

  private mutating func settleRRSCourier(
    _ id: UUID, outcome: RRSCourierOutcome, arrival: NativeMainStationDockReceipt? = nil
  ) throws {
    guard var ledger = commander.contracts.rrs,
      let index = ledger.jobs.firstIndex(where: { $0.id == id && $0.terminal == nil })
    else { throw MissionPackError("This RRS assignment has already ended.") }
    ledger.jobs[index].terminal = .init(
      outcome: outcome, calendarSeconds: commander.scriptState.calendarSeconds,
      runtimeEpoch: nativeStationRuntimeEpoch, system: systemIdentity, arrival: arrival)
    try publishRRSCourierLedger(ledger, reward: outcome.reward)
  }

  private func rrsCourierFailure(for job: RRSCourierJob) -> RRSCourierOutcome? {
    if systemIdentity.galaxy != job.destination.system.galaxy { return .newGalaxy }
    if systemIdentity != job.destination.system { return .departedSystem }
    if case .destroyed(let actual) = nativeOriginalMainStationDestination,
      actual == job.destination
    {
      return .originalMainDestroyed
    }
    return nil
  }

  mutating func resolveRRSCourierTerminals(publish: ScriptPublisher? = nil) {
    guard !paused, scriptDurabilityAvailable, let active = commander.contracts.rrs?.active,
      let cause = rrsCourierFailure(for: active)
    else { return }
    do {
      var candidate = self
      try candidate.settleRRSCourier(active.id, outcome: cause)
      candidate.notify("RRS ASSIGNMENT FAILED - 0 CR / REPUTATION -10")
      try publish?(&candidate)
      self = candidate
    } catch { notify("RRS OUTCOME NOT SAVED - DOCUMENT DELIVERY SUSPENDED") }
  }

  var rrsCourierDetail: [String] {
    guard let row = contractBoard.selected?.rrs else { return [] }
    let prefix: [String]
    switch row {
    case .offer: prefix = [row.title, RRSCourierContent.briefing]
    case .debrief:
      prefix = [
        row.title,
        "Confirm transfers the protected packet and records 30.0 CR / reputation +2 once.",
      ]
    case .abandon:
      prefix = [
        row.title, "Confirm destroys packet custody and records 0 CR / reputation -10 once.",
      ]
    }
    return prefix + RRSCourierContent.terms + (contractBoard.rrsQuote?.issues ?? [])
  }

  var rrsCourierPageFacts: [String] {
    var fields = [nativeStationRuntimeEpoch.uuidString]
    if let context = nativeStationBoardContext {
      fields += [
        context.station.world.uuidString, context.station.key, String(context.hour),
        context.profileRevision, context.adapterRevision, context.geometryRevision,
        String(context.service.receipt.sequence), String(context.service.receipt.lifecycleRevision),
      ]
    }
    if let ledger = commander.contracts.rrs {
      fields += [
        String(ledger.reputation), String(ledger.completed), String(ledger.failed),
        ledger.active?.id.uuidString ?? "", ledger.active?.packet.uuidString ?? "",
      ]
    }
    if let row = contractBoard.selected?.rrs {
      fields += [row.key] + rrsCourierQuote(for: row).issues
    }
    if let active = commander.contracts.rrs?.active,
      let arrival = nativeMainStationArrivalContext(for: active.destination)
    {
      fields += [
        arrival.receipt.station.world.uuidString, arrival.receipt.station.key,
        String(arrival.receipt.sequence), String(arrival.receipt.calendarSeconds),
        String(arrival.receipt.actor.visit),
      ]
    }
    return fields
  }
}

extension GameRuntime {
  func confirmRRSCourier(_ quote: RRSCourierQuote) throws {
    try scriptCommand { try $0.confirmRRSCourier(quote) }
  }
  func declineRRSCourier(_ quote: RRSCourierQuote) throws {
    try scriptCommand { try $0.declineRRSCourier(quote) }
  }
}
