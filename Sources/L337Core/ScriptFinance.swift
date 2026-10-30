import Foundation

enum ScriptFinanceRow: Sendable, Equatable {
  case offer(UUID)
  case repay(UUID)
  case history(UUID)
  var id: UUID {
    switch self {
    case .offer(let id), .repay(let id), .history(let id): id
    }
  }
  var key: String {
    switch self {
    case .offer: "finance/offer/" + id.uuidString
    case .repay: "finance/repay/" + id.uuidString
    case .history: "finance/history/" + id.uuidString
    }
  }
  var operation: ScriptFinanceOperation? {
    switch self {
    case .offer: .borrow
    case .repay: .repay
    case .history: nil
    }
  }
}

/// Reuses the single board review slot and the existing immutable resource snapshot.
struct ScriptFinanceQuote: Sendable {
  let row: ScriptFinanceRow
  private let capturedResources: CommanderSnapshot
  var resources: Commander { capturedResources.value }
  let ledgerRevision: UInt64
  let balance: ScriptFinanceBalance?
  let context: NativeMainStationArrivalContext?
  let epoch: UUID
  let reviewToken = UUID()
  let issues: [String]
  let canDecline: Bool
  var allowed: Bool { row.operation != nil && issues.isEmpty }
  var actionLabel: String {
    switch row.operation {
    case .borrow: "Borrow"
    case .repay: "Repay"
    default: "Closed"
    }
  }
  fileprivate init(
    row: ScriptFinanceRow, commander: Commander, context: NativeMainStationArrivalContext?,
    epoch: UUID, issues: [String], canDecline: Bool
  ) {
    self.row = row
    capturedResources = CommanderSnapshot(commander.contractQuoteResources)
    ledgerRevision = commander.scriptState.financeLedger?.revision ?? 0
    balance = commander.scriptState.financeLedger?.records.first { $0.id == row.id }?
      .balance(at: commander.scriptState.calendarSeconds)
    self.context = context
    self.epoch = epoch
    self.issues = issues
    self.canDecline = canDecline
  }
}

extension ScriptFinanceLedger {
  /// Pure candidate arithmetic. Only the native controller can supply live confirmation authority.
  func applying(
    _ operation: ScriptFinanceOperation, to id: UUID, token: UUID, cash: Int,
    dock: NativeMainStationDockReceipt, calendarSeconds: Double, epoch: UUID
  ) throws -> (ledger: ScriptFinanceLedger, cash: Int, receipt: ScriptFinanceReceipt) {
    guard valid, (0...4_294_967_295).contains(cash), receiptCount < Self.maximumReceipts,
      !records.contains(where: { $0.receipts.contains { $0.token == token } }),
      let index = records.firstIndex(where: { $0.id == id }),
      dock.valid, dock.commanderOwner == owner,
      dock.station == records[index].terms.station(owner: owner),
      calendarSeconds.isFinite, (0...1e12).contains(calendarSeconds)
    else { throw MissionPackError("The financial obligation or confirmation is invalid.") }
    let record = records[index]
    guard let due = record.balance(at: calendarSeconds) else {
      throw MissionPackError("The loan calendar or accrued balance is invalid.")
    }
    let amount: Int
    let afterCash: Int
    let principalAfter: Int
    let interestAfter: Int
    switch operation {
    case .borrow:
      guard record.status == .offered, cash <= 4_294_967_295 - record.terms.principal else {
        throw MissionPackError("The full principal cannot be issued for this offer.")
      }
      amount = record.terms.principal
      afterCash = cash + amount
      principalAfter = amount
      interestAfter = 0
    case .decline:
      guard record.status == .offered else {
        throw MissionPackError("Only an undecided loan offer can be declined.")
      }
      amount = 0
      afterCash = cash
      principalAfter = 0
      interestAfter = 0
    case .repay:
      guard record.status == .outstanding, cash > 0 else {
        throw MissionPackError("Repayment requires an outstanding balance and real credits.")
      }
      amount = min(cash, due.total)
      afterCash = cash - amount
      interestAfter = due.interest - min(amount, due.interest)
      principalAfter = due.principal - max(0, amount - due.interest)
    }
    var candidate = self
    candidate.revision += 1
    let receipt = ScriptFinanceReceipt(
      id: ScriptFinanceReceipt.identity(id, revision: candidate.revision), token: token,
      obligation: id, operation: operation, revision: candidate.revision,
      beforeCash: cash, afterCash: afterCash, beforePrincipal: due.principal,
      afterPrincipal: principalAfter, beforeInterest: due.interest, afterInterest: interestAfter,
      interestAdded: due.assessedInterest - (record.receipts.last?.assessedInterest ?? 0),
      assessedInterest: due.assessedInterest, completedPeriods: due.completedPeriods,
      amount: amount, dock: dock,
      calendarSeconds: calendarSeconds, epoch: epoch)
    candidate.records[index].receipts.append(receipt)
    guard candidate.valid else { throw SaveError.invalidCommander }
    return (candidate, afterCash, receipt)
  }
}

extension Game {
  mutating func registerFinanceOffer(
    _ command: ScriptValue, event: ScriptEvent, pack: ScriptPack, state: ScriptInstance
  ) throws {
    guard let fields = command.object, Set(fields.keys) == ["op", "id"],
      fields["op"]?.string == "finance.offer", let id = fields["id"]?.string,
      pack.manifest.capabilities.contains("finance-obligations-basic-v2"),
      let terms = pack.manifest.loans?.first(where: { $0.id == id }), terms.valid,
      state.outcome == .active, state.suspension == nil,
      state.definition == pack.manifest.stateID, state.version == pack.manifest.version,
      state.digest == pack.digest, event.instance == state.id, let cause = event.context,
      cause.valid, cause.docked, cause.mainStation,
      cause.galaxy == terms.galaxy, cause.system == terms.system,
      docked, dockedAtMainStation, commander.galaxy == terms.galaxy,
      commander.system == terms.system, scriptDurabilityAvailable,
      let owner = commander.equipmentOwnerID
    else {
      throw MissionPackError(
        "Loan offers require their declared active station contact and save writer.")
    }
    let source = ScriptFinanceSource(
      instance: state.id, definition: state.definition, version: state.version,
      digest: state.digest, sequence: event.sequence, cause: cause)
    var ledger = commander.scriptState.financeLedger ?? .init(owner: owner)
    guard ledger.owner == owner, ledger.records.isEmpty || ledger.valid else {
      throw SaveError.invalidCommander
    }
    let identity = source.identity(owner: owner, loan: id)
    if let existing = ledger.records.first(where: { $0.id == identity }) {
      guard existing.terms == terms, existing.source.matches(state) else {
        throw MissionPackError("Changed financial terms require an explicit content migration.")
      }
      return
    }
    guard ledger.records.count < ScriptFinanceLedger.maximumRecords else {
      throw MissionPackError("The financial record limit has been reached.")
    }
    ledger.revision += 1
    ledger.records.append(
      .init(id: identity, terms: terms, source: source, createdRevision: ledger.revision))
    guard ledger.valid else { throw SaveError.invalidCommander }
    commander.scriptState.financeLedger = ledger
  }

  var financeRows: [ContractBoardRow] {
    guard let ledger = commander.scriptState.financeLedger else { return [] }
    return ledger.records.sorted { $0.id.uuidString < $1.id.uuidString }.map { record in
      let row: ScriptFinanceRow
      switch record.status {
      case .offered: row = .offer(record.id)
      case .outstanding: row = .repay(record.id)
      case .declined, .paid: row = .history(record.id)
      }
      return .init(
        board: row.key, offer: nil,
        title: "Finance / " + record.terms.title + " / " + record.status.rawValue,
        reason: financeQuote(for: row).issues.first, finance: row)
    }
  }

  func financeQuote(for row: ScriptFinanceRow) -> ScriptFinanceQuote {
    var issues: [String] = []
    var borrowIssues: [String] = []
    var context: NativeMainStationArrivalContext?
    let ledger = commander.scriptState.financeLedger
    if row.operation != nil, !scriptDurabilityAvailable {
      issues.append("Choose a writable commander save first.")
    }
    guard commander.financeStateValid, (0...4_294_967_295).contains(commander.credits) else {
      return .init(
        row: row, commander: commander, context: nil, epoch: nativeStationRuntimeEpoch,
        issues: issues + ["The financial ledger owner, source or resources are invalid."],
        canDecline: false)
    }
    if let ledger, let record = ledger.records.first(where: { $0.id == row.id }) {
      if record.balance(at: commander.scriptState.calendarSeconds) == nil {
        issues.append("The loan calendar or accrued balance is invalid.")
      }
      if row.operation != nil {
        context = nativeMainStationArrivalContext(for: record.terms.station(owner: ledger.owner))
        if context == nil {
          issues.append("Return to the proved original main station and resume play.")
        }
      }
      switch row {
      case .offer:
        if record.status != .offered { issues.append("This loan offer has already been decided.") }
        if !financeOfferParentAvailable(record) {
          issues.append("The exact active parent and loan provider are unavailable.")
        }
        if commander.credits > 4_294_967_295 - record.terms.principal {
          borrowIssues.append("The full principal would exceed the native credit limit.")
        }
      case .repay:
        if record.status != .outstanding { issues.append("This balance is already closed.") }
        if commander.credits == 0 {
          issues.append("No real credits are available; the principal remains outstanding.")
        }
      case .history: break
      }
      if row.operation != nil && ledger.receiptCount >= ScriptFinanceLedger.maximumReceipts {
        issues.append("The financial receipt limit has been reached.")
      }
    } else {
      issues.append("This financial record is unavailable.")
    }
    return .init(
      row: row, commander: commander, context: context,
      epoch: nativeStationRuntimeEpoch, issues: issues + borrowIssues,
      canDecline: row.operation == .borrow && issues.isEmpty)
  }

  private func financeOfferParentAvailable(_ record: ScriptFinanceRecord) -> Bool {
    guard let parent = commander.scriptState.instances[record.source.instance],
      record.source.matches(parent), parent.outcome == .active, parent.suspension == nil,
      let pack = scriptPack(for: parent), scriptUnavailable(pack) == nil
    else { return false }
    return pack.manifest.loans?.contains(record.terms) == true
  }

  mutating func confirmFinance(_ quote: ScriptFinanceQuote, declining: Bool = false) throws {
    guard screen == .contracts, contractBoard.detail,
      contractBoard.selected?.finance == quote.row,
      contractBoard.financeQuote?.reviewToken == quote.reviewToken,
      declining ? quote.canDecline : quote.allowed,
      quote.epoch == nativeStationRuntimeEpoch,
      quote.resources == commander.contractQuoteResources,
      let ledger = commander.scriptState.financeLedger, ledger.revision == quote.ledgerRevision,
      let due = ledger.records.first(where: { $0.id == quote.row.id })?
        .balance(at: commander.scriptState.calendarSeconds), quote.balance == due,
      let context = quote.context, acceptsNativeMainStationArrivalContext(context),
      declining ? financeQuote(for: quote.row).canDecline : financeQuote(for: quote.row).allowed,
      let operation = declining ? ScriptFinanceOperation.decline : quote.row.operation,
      !declining || quote.row == .offer(quote.row.id)
    else {
      throw MissionPackError("Your balance, location or loan changed. Review the current terms.")
    }
    var candidate = self
    let result = try ledger.applying(
      operation, to: quote.row.id, token: quote.reviewToken, cash: commander.credits,
      dock: context.receipt, calendarSeconds: commander.scriptState.calendarSeconds,
      epoch: quote.epoch)
    candidate.commander.credits = result.cash
    candidate.commander.scriptState.financeLedger = result.ledger
    guard candidate.commander.valid else { throw SaveError.invalidCommander }
    self = candidate
  }

  func financeQuery(_ state: ScriptInstance) -> ScriptValue {
    let records =
      commander.scriptState.financeLedger?.records.filter { $0.source.instance == state.id } ?? []
    return .object(
      Dictionary(
        uniqueKeysWithValues: records.map { record in
          guard let due = record.balance(at: commander.scriptState.calendarSeconds) else {
            return (record.terms.id, ScriptValue.object(["status": .string("unavailable")]))
          }
          return (
            record.terms.id,
            ScriptValue.object([
              "status": .string(record.status.rawValue),
              "principal": .integer(Int64(record.terms.principal)),
              "remaining": .integer(Int64(due.total)),
              "remaining_principal": .integer(Int64(due.principal)),
              "accrued_interest": .integer(Int64(due.interest)),
              "assessed_interest": .integer(Int64(due.assessedInterest)),
              "completed_periods": .integer(Int64(due.completedPeriods)),
              "calendar_seconds": .number(commander.scriptState.calendarSeconds),
              "interest_profile": .string(record.terms.profile),
              "rate_basis_points": .integer(Int64(record.terms.interest?.rateBasisPoints ?? 0)),
              "period_seconds": .integer(Int64(record.terms.interest?.periodSeconds ?? 0)),
              "rounding": .string(record.terms.interest?.rounding.rawValue ?? "none"),
              "maximum_interest": .integer(Int64(record.terms.interest?.maximumInterest ?? 0)),
              "receipts": .integer(Int64(record.receipts.count)),
            ])
          )
        }))
  }

  var financeDetail: [String] {
    guard commander.financeStateValid, (0...4_294_967_295).contains(commander.credits),
      let row = contractBoard.selected?.finance,
      let ledger = commander.scriptState.financeLedger,
      let record = ledger.records.first(where: { $0.id == row.id }),
      let due = record.balance(at: commander.scriptState.calendarSeconds)
    else { return ["Financial record unavailable."] }
    let amount =
      row.operation == .borrow ? record.terms.principal : min(commander.credits, due.total)
    let after = row.operation == .borrow ? commander.credits + amount : commander.credits - amount
    let place = Universe.systemsIncludingPlugh(number: record.terms.galaxy)[record.terms.system]
      .name
    var rows = [
      record.terms.title,
      "Principal: \(Self.financeMoney(record.terms.principal)). Remaining: \(Self.financeMoney(due.total)).",
      "Real balance: \(Self.financeMoney(commander.credits)).",
      "Manual service: Galaxy \(record.terms.galaxy + 1), \(place) original main orbital station.",
      "The obligation survives campaign completion, abandonment and missing content.",
    ]
    if let interest = record.terms.interest {
      rows += [
        "Simple interest: \(String(format: "%.2f", Double(interest.rateBasisPoints) / 100))% per \(interest.periodSeconds) calendar seconds.",
        "Round \(interest.rounding.rawValue) per period to 0.1 CR; lifetime interest cap \(Self.financeMoney(interest.maximumInterest)).",
        "Principal owed: \(Self.financeMoney(due.principal)); interest owed: \(Self.financeMoney(due.interest)).",
        "Interest assessed so far: \(Self.financeMoney(due.assessedInterest)).",
        "Period-end remaining principal only; interest never compounds. Payments clear interest first.",
        "Periods start at Borrow, never reset on partial payment. No interest before Borrow or after payoff.",
        "Only completed periods accrue; reading does not charge cash or create receipts. No deadline.",
      ]
      if let quoted = contractBoard.financeQuote?.balance, quoted != due {
        rows.append("Accrued balance changed. Refresh this review before Confirm.")
      }
    } else {
      rows.insert("Fixed-principal loan; no interest or deadline.", at: 1)
    }
    if row.operation == .borrow {
      rows += [
        "Borrow \(Self.financeMoney(amount)); resulting balance \(Self.financeMoney(after)).",
        "Confirm issues the full principal once. Decline ends this offer; Back changes nothing.",
      ]
    } else if row.operation == .repay {
      rows += [
        "Pay \(Self.financeMoney(amount)); resulting balance \(Self.financeMoney(after)).",
        "Remaining debt after payment: \(Self.financeMoney(due.total - amount)).",
        "A short payment carries the remaining debt.",
      ]
    } else {
      rows.append("Closed history: \(record.status.rawValue). No further transfer is available.")
    }
    if let receipt = record.receipts.last {
      rows.append(
        "Last receipt: \(receipt.operation.rawValue), \(Self.financeMoney(receipt.amount)); balance after \(Self.financeMoney(receipt.afterCash))."
      )
    }
    return rows + (contractBoard.financeQuote?.issues ?? [])
  }
  private static func financeMoney(_ value: Int) -> String {
    String(format: "%.1f CR", Double(value) / 10)
  }

  var financePageFacts: [String] {
    guard let ledger = commander.scriptState.financeLedger else { return [] }
    var facts = [
      ledger.owner.uuidString, String(ledger.revision), nativeStationRuntimeEpoch.uuidString,
    ]
    if let row = contractBoard.selected?.finance,
      let record = ledger.records.first(where: { $0.id == row.id })
    {
      facts += [record.id.uuidString, record.status.rawValue]
      if let due = record.balance(at: commander.scriptState.calendarSeconds) {
        facts += [
          String(due.principal), String(due.interest), String(due.assessedInterest),
          String(due.completedPeriods),
        ]
      }
      let quote = financeQuote(for: row)
      facts += quote.issues
      if let context = quote.context {
        facts += [
          String(context.receipt.sequence), context.receipt.station.key,
          String(context.receipt.actor.visit),
        ]
      }
    }
    return facts
  }
}

extension ScriptPackLibrary {
  static func validateFinance(_ manifest: ScriptManifest) throws {
    let loans = manifest.loans ?? []
    guard loans.count <= 16, Set(loans.map(\.id)).count == loans.count,
      loans.allSatisfy(\.valid),
      loans.allSatisfy({
        $0.interest == nil
          || [ScriptFinanceInterest.capability, "mission-calendar-v2"]
            .allSatisfy(manifest.capabilities.contains)
      }),
      loans.isEmpty
        || ["story-v2", "durable-commands-v2", "finance-obligations-basic-v2"]
          .allSatisfy(manifest.capabilities.contains)
    else { throw MissionPackError("Invalid or unsupported loan declarations.") }
  }
}
