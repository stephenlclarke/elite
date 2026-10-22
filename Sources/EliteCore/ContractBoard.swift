import Foundation

public enum ContractBoardAction: String, Codable, Sendable, CaseIterable {
  case accept = "Accept"
  case decline = "Decline"
  case back = "Back"
}
public struct ContractBoardRow: Sendable {
  public let board: String
  public let offer: ScriptContractOffer?
  public let title: String
  public let reason: String?
  var rrs: RRSCourierRow? = nil
  var finance: ScriptFinanceRow? = nil
  var people: NativePeopleStationRow? = nil
  var provider: ProviderContractRow? = nil
  var repairLoop: WayfarerRepairLoopBoardRow? = nil
  var coldChain: WayfarerColdChainBoardRow? = nil
  var survey: NativeOriginalSurveyAction? = nil
  var glassMeridian: NativeGlassMeridianAction? = nil
  var wayfarerInduction: NativeWayfarerInductionAction? = nil
  var inductionCapacityUnit: UUID? = nil
  var flightReception: NativeFlightReceptionAction? = nil
  var measuredExtraction: NativeMeasuredExtractionAction? = nil
  var recordRecovery: WayfarerRecordRecoveryAction? = nil
  var identifiedSalvage: NativeIdentifiedSalvageAction? = nil
  var utility: NativeUtilityAction? = nil
  public var key: String {
    if let utility { return utility.utilityKey }
    if let key = wayfarerInduction?.key {
      return key + (inductionCapacityUnit.map { "/unit/" + $0.uuidString } ?? "")
    }
    if let key = glassMeridian?.key { return key }
    if let key = flightReception?.key { return key }
    if let key: String = measuredExtraction?.key { return key }
    if let key: String = recordRecovery?.key { return key }
    if let key: String = identifiedSalvage?.key { return key }
    if let key: String = survey?.key { return key }
    if let key: String = repairLoop?.key { return key }
    if let key: String = coldChain?.key { return key }
    if let key: String = provider?.key { return key }
    if let key: String = people?.key { return key }
    if let key: String = finance?.key { return key }
    if let key: String = rrs?.key { return key }
    return board + "/" + (offer?.id.uuidString ?? "unavailable")
  }
}
public struct ContractScreenSave: Codable, Sendable {
  public let selection: String?
  public let detail: Bool
  public let action: ContractBoardAction
  public let scroll: Int
  public let previous: Screen
  var valid: Bool {
    (selection?.count ?? 0) <= 512 && (0...100000).contains(scroll) && previous != .contracts
  }
}
private enum ContractBoardReview: Sendable {
  case contract(ContractAcceptanceQuote)
  case rrs(RRSCourierQuote)
  case finance(ScriptFinanceQuote)
  case people(NativePeopleStationQuote)
  case provider(ProviderContractQuote)
  case repairLoop(WayfarerRepairLoopBoardReview)
  case coldChain(WayfarerColdChainBoardReview)
  case survey(NativeOriginalSurveyReview)
  case glassMeridian(NativeGlassMeridianReview)
  case wayfarerInduction(NativeWayfarerInductionReview)
  case flightReception(NativeFlightReceptionReview)
  case measuredExtraction(NativeMeasuredExtractionReview)
  case recordRecovery(WayfarerRecordRecoveryReview)
  case identifiedSalvage(NativeIdentifiedSalvageReview)
  case utility(NativeUtilityBoardReview)
}

public struct ContractBoardUI: Sendable {
  public var selection = 0
  public var detail = false
  public var action: ContractBoardAction = .back
  public var scroll = 0
  public var rows: [ContractBoardRow] = []
  private var review: ContractBoardReview?
  public var quote: ContractAcceptanceQuote? {
    get {
      guard case .contract(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .contract(newValue)
      } else if case .contract(_)? = review {
        review = nil
      }
    }
  }
  var rrsQuote: RRSCourierQuote? {
    get {
      guard case .rrs(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .rrs(newValue)
      } else if case .rrs(_)? = review {
        review = nil
      }
    }
  }
  var presentationGeneration = UUID()
  var financeQuote: ScriptFinanceQuote? {
    get {
      guard case .finance(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .finance(newValue)
      } else if case .finance(_)? = review {
        review = nil
      }
    }
  }
  var reviewToken = UUID()
  var peopleQuote: NativePeopleStationQuote? {
    get {
      guard case .people(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .people(newValue)
      } else if case .people(_)? = review {
        review = nil
      }
    }
  }
  var providerQuote: ProviderContractQuote? {
    get {
      guard case .provider(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .provider(newValue)
      } else if case .provider(_)? = review {
        review = nil
      }
    }
  }
  var repairLoopQuote: WayfarerRepairLoopBoardReview? {
    get {
      guard case .repairLoop(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .repairLoop(newValue)
      } else if case .repairLoop(_)? = review {
        review = nil
      }
    }
  }
  var coldChainQuote: WayfarerColdChainBoardReview? {
    get {
      guard case .coldChain(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .coldChain(newValue)
      } else if case .coldChain(_)? = review {
        review = nil
      }
    }
  }
  var previous: Screen = .status
  var restoredSelection: String?
  var surveyQuote: NativeOriginalSurveyReview? {
    get {
      guard case .survey(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .survey(newValue)
      } else if case .survey(_)? = review {
        review = nil
      }
    }
  }
  var wayfarerInductionQuote: NativeWayfarerInductionReview? {
    get {
      guard case .wayfarerInduction(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .wayfarerInduction(newValue)
      } else if case .wayfarerInduction(_)? = review {
        review = nil
      }
    }
  }
  var glassMeridianQuote: NativeGlassMeridianReview? {
    get {
      guard case .glassMeridian(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .glassMeridian(newValue)
      } else if case .glassMeridian(_)? = review {
        review = nil
      }
    }
  }
  var flightReceptionQuote: NativeFlightReceptionReview? {
    get {
      guard case .flightReception(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .flightReception(newValue)
      } else if case .flightReception(_)? = review {
        review = nil
      }
    }
  }
  var measuredExtractionQuote: NativeMeasuredExtractionReview? {
    get {
      guard case .measuredExtraction(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .measuredExtraction(newValue)
      } else if case .measuredExtraction(_)? = review {
        review = nil
      }
    }
  }
  var recordRecoveryQuote: WayfarerRecordRecoveryReview? {
    get {
      guard case .recordRecovery(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .recordRecovery(newValue)
      } else if case .recordRecovery(_)? = review {
        review = nil
      }
    }
  }
  var identifiedSalvageQuote: NativeIdentifiedSalvageReview? {
    get {
      guard case .identifiedSalvage(let quote)? = review else { return nil }
      return quote
    }
    set {
      if let newValue {
        review = .identifiedSalvage(newValue)
      } else if case .identifiedSalvage(_)? = review {
        review = nil
      }
    }
  }
  var utilityQuote: NativeUtilityBoardReview? {
    get {
      guard case .utility(let value)? = review else { return nil }
      return value
    }
    set {
      if let newValue {
        review = .utility(newValue)
      } else if case .utility(_)? = review {
        review = nil
      }
    }
  }
  public init() {}
  var selected: ContractBoardRow? { rows.indices.contains(selection) ? rows[selection] : nil }
  var save: ContractScreenSave {
    .init(
      selection: selected?.key ?? restoredSelection, detail: detail, action: action, scroll: scroll,
      previous: previous)
  }
}
extension Game {
  mutating func openContractBoard() {
    guard docked, dockedAtMainStation || nativeStationBoardContext != nil, !paused,
      ![Screen.title, .demo, .gameOver, .help, .secret, .mission, .handoff].contains(screen),
      !showroom.trading
    else {
      notify("CONTRACTS REQUIRE A MAIN ORBITAL STATION OR PROVED RRS DOCK")
      return
    }
    var candidate = self
    if screen != .contracts { candidate.contractBoard.previous = screen }
    var failures: [String: String] = [:]
    if candidate.nativeStationBoardContext != nil {
      do { try candidate.ensureRRSCourierBoard() } catch {
        notify(String(error.localizedDescription.prefix(512)))
        return
      }
    }
    for pack in scriptPacks
    where dockedAtMainStation && pack.manifest.board != nil
      && scriptUnavailable(pack) == nil
    {
      do { _ = try candidate.ensureContractBoard(pack) } catch {
        failures[pack.digest] = String(error.localizedDescription.prefix(512))
      }
    }
    candidate.prepareWayfarerRepairLoopBoard(failures: &failures)
    candidate.prepareWayfarerColdChainBoard(failures: &failures)
    candidate.refreshContractRows(failures: failures)
    candidate.screen = .contracts
    candidate.contractBoard.detail = false
    candidate.contractBoard.quote = nil
    candidate.contractBoard.rrsQuote = nil
    candidate.contractBoard.financeQuote = nil
    candidate.contractBoard.peopleQuote = nil
    candidate.contractBoard.providerQuote = nil
    candidate.contractBoard.repairLoopQuote = nil
    candidate.contractBoard.coldChainQuote = nil
    candidate.contractBoard.surveyQuote = nil
    candidate.contractBoard.wayfarerInductionQuote = nil
    candidate.contractBoard.glassMeridianQuote = nil
    candidate.contractBoard.flightReceptionQuote = nil
    candidate.contractBoard.measuredExtractionQuote = nil
    candidate.contractBoard.recordRecoveryQuote = nil
    candidate.contractBoard.identifiedSalvageQuote = nil
    candidate.contractBoard.utilityQuote = nil
    candidate.gallery.providerIntent = nil
    candidate.contractBoard.presentationGeneration = UUID()
    publishContractBoard(&candidate)
  }
  // Reserve the publication copy only after row quotes finish their acceptance simulations.
  private mutating func publishContractBoard(_ candidate: inout Game) {
    self = candidate
  }
  mutating func refreshContractRows(
    failures: [String: String] = [:], restoring save: ContractScreenSave? = nil
  ) {
    let selected = save?.selection ?? contractBoard.selected?.key ?? contractBoard.restoredSelection
    var rows =
      rrsCourierRows + financeRows + nativePeopleRows + providerContractRows + originalSurveyRows
      + wayfarerInductionRows
      + glassMeridianRows
      + flightReceptionRows
      + measuredExtractionRows
      + recordRecoveryRows
      + identifiedSalvageRows
      + wayfarerColdChainRows(failures: failures)
      + wayfarerRepairLoopRows(failures: failures)
      + nativeUtilityRows
    for pack in scriptPacks.sorted(by: {
      ($0.manifest.id, $0.manifest.version, $0.digest) < (
        $1.manifest.id, $1.manifest.version, $1.digest
      )
    }) {
      guard dockedAtMainStation, let definition = pack.manifest.board else { continue }
      let key = pack.digest + "/" + definition.id + "/" + contractStation.key
      if let reason = failures[pack.digest] ?? scriptUnavailable(pack) {
        rows.append(.init(board: key, offer: nil, title: definition.title, reason: reason))
      } else if let board = commander.contracts.boards[key],
        board.revision == (try? contractRevision(definition, pack: pack))
      {
        for offer in board.offers where offer.status == .available {
          let quote = contractAcceptanceQuote(board: key, offer: offer.id)
          rows.append(
            .init(board: key, offer: offer, title: offer.title, reason: quote.issues.first))
        }
      }
    }
    contractBoard.rows = rows
    contractBoard.restoredSelection = nil
    contractBoard.selection =
      selected.flatMap { key in rows.firstIndex { $0.key == key } }
      ?? min(contractBoard.selection, max(0, rows.count - 1))
    if let save {
      contractBoard.detail = save.detail && contractBoard.selected != nil
      contractBoard.action = save.action
      contractBoard.scroll = save.scroll
      contractBoard.previous = save.previous
      refreshSelectedContractQuote()
      if contractBoard.quote?.pledge != nil || contractBoard.financeQuote != nil
        || contractBoard.peopleQuote != nil || contractBoard.providerQuote != nil
        || contractBoard.coldChainQuote != nil || contractBoard.repairLoopQuote != nil
        || contractBoard.surveyQuote != nil || contractBoard.wayfarerInductionQuote != nil
        || contractBoard.glassMeridianQuote != nil
        || contractBoard.flightReceptionQuote != nil
        || contractBoard.measuredExtractionQuote != nil
        || contractBoard.recordRecoveryQuote != nil
        || contractBoard.identifiedSalvageQuote != nil || contractBoard.utilityQuote != nil
      {
        contractBoard.action = .back
      }
    }
  }
  mutating func refreshSelectedContractQuote() {
    contractBoard.reviewToken = UUID()
    if let action = contractBoard.selected?.utility {
      contractBoard.utilityQuote = nativeUtilityReview(action)
      return
    }
    contractBoard.utilityQuote = nil
    if let action = contractBoard.selected?.wayfarerInduction {
      contractBoard.wayfarerInductionQuote = wayfarerInductionReview(
        action, prepareClinicQuote: true)
      return
    }
    if let action = contractBoard.selected?.glassMeridian {
      contractBoard.glassMeridianQuote = glassMeridianReview(action)
      return
    }
    if let action = contractBoard.selected?.flightReception {
      contractBoard.flightReceptionQuote = flightReceptionReview(action)
      return
    }
    if let action = contractBoard.selected?.measuredExtraction {
      contractBoard.measuredExtractionQuote = measuredExtractionReview(action)
      return
    }
    if let action = contractBoard.selected?.recordRecovery {
      contractBoard.recordRecoveryQuote = recordRecoveryReview(action)
      return
    }
    if let action = contractBoard.selected?.identifiedSalvage {
      contractBoard.identifiedSalvageQuote = identifiedSalvageReview(action)
      return
    }
    contractBoard.wayfarerInductionQuote = nil
    contractBoard.glassMeridianQuote = nil
    contractBoard.flightReceptionQuote = nil
    contractBoard.measuredExtractionQuote = nil
    contractBoard.recordRecoveryQuote = nil
    contractBoard.identifiedSalvageQuote = nil
    if let action = contractBoard.selected?.survey {
      contractBoard.surveyQuote = originalSurveyReview(action)
      return
    }
    contractBoard.surveyQuote = nil
    if let row = contractBoard.selected?.repairLoop {
      contractBoard.repairLoopQuote = wayfarerRepairLoopReview(row)
      return
    }
    contractBoard.repairLoopQuote = nil
    if let row = contractBoard.selected?.coldChain {
      contractBoard.coldChainQuote = wayfarerColdChainReview(row)
      return
    }
    contractBoard.coldChainQuote = nil
    if let row = contractBoard.selected?.provider {
      contractBoard.providerQuote = .init(
        row: row, issues: contractBoard.selected?.reason.map { [$0] } ?? [])
      return
    }
    contractBoard.providerQuote = nil
    if let row = contractBoard.selected?.people {
      contractBoard.peopleQuote = nativePeopleQuote(row)
      return
    }
    contractBoard.peopleQuote = nil
    if let row = contractBoard.selected?.finance {
      contractBoard.financeQuote = financeQuote(for: row)
      return
    }
    contractBoard.financeQuote = nil
    contractBoard.rrsQuote = contractBoard.selected?.rrs.map { rrsCourierQuote(for: $0) }
    if let row = contractBoard.selected, let offer = row.offer {
      contractBoard.quote = contractAcceptanceQuote(board: row.board, offer: offer.id)
    } else {
      contractBoard.quote = nil
    }
  }
  mutating func contractBoardKey(_ key: String) {
    let previous = scriptContractPageIdentity
    defer { finishContractNavigation(from: previous) }
    if key == "escape" {
      if contractBoard.detail {
        contractBoard.detail = false
        contractBoard.quote = nil
        contractBoard.rrsQuote = nil
        contractBoard.financeQuote = nil
        contractBoard.peopleQuote = nil
        contractBoard.providerQuote = nil
        contractBoard.repairLoopQuote = nil
        contractBoard.coldChainQuote = nil
        contractBoard.utilityQuote = nil
        gallery.providerIntent = nil
      } else {
        screen = contractBoard.previous
      }
      return
    }
    if key == "contract-refresh" {
      openContractBoard()
      return
    }
    if !contractBoard.detail {
      if key == "up" || key == "down" {
        contractBoard.selection = max(
          0, min(contractBoard.rows.count - 1, contractBoard.selection + (key == "up" ? -1 : 1)))
      }
      if key == "return", contractBoard.selected != nil {
        contractBoard.detail = true
        contractBoard.action = .back
        contractBoard.scroll = 0
        refreshSelectedContractQuote()
      }
      return
    }
    if ["left", "right", "tab"].contains(key) {
      let actions = ContractBoardAction.allCases
      let index = actions.firstIndex(of: contractBoard.action)!
      contractBoard.action = actions[(index + (key == "left" ? 2 : 1)) % 3]
    }
    if ["up", "down", "pageup", "pagedown"].contains(key) {
      scrollContractDetail(key)
    }
    guard key == "return" else { return }
    if contractBoard.action == .back {
      contractBoard.detail = false
      contractBoard.quote = nil
      contractBoard.rrsQuote = nil
      contractBoard.financeQuote = nil
      contractBoard.peopleQuote = nil
      contractBoard.providerQuote = nil
      contractBoard.repairLoopQuote = nil
      contractBoard.coldChainQuote = nil
      contractBoard.surveyQuote = nil
      contractBoard.wayfarerInductionQuote = nil
      contractBoard.glassMeridianQuote = nil
      contractBoard.flightReceptionQuote = nil
      contractBoard.measuredExtractionQuote = nil
      contractBoard.recordRecoveryQuote = nil
      contractBoard.identifiedSalvageQuote = nil
      contractBoard.utilityQuote = nil
      gallery.providerIntent = nil
      return
    }
    do {
      if let action = contractBoard.selected?.utility {
        guard contractBoard.action == .accept, let review = contractBoard.utilityQuote,
          review.action == action, let quote = review.quote, review.allowed
        else {
          throw MissionPackError("Review the current utility operation and choose Confirm or Back.")
        }
        try confirmNativeUtility(quote)
        refreshContractRows()
        contractBoard.detail = false
        contractBoard.utilityQuote = nil
        return
      }
      if let action = contractBoard.selected?.wayfarerInduction {
        guard contractBoard.action == .accept, let quote = contractBoard.wayfarerInductionQuote,
          quote.action == action, quote.allowed
        else {
          throw MissionPackError("Review the current induction action and choose Confirm or Back.")
        }
        try confirmWayfarerInduction(quote)
        refreshContractRows()
        contractBoard.detail = false
        contractBoard.wayfarerInductionQuote = nil
        return
      }
      if let action = contractBoard.selected?.glassMeridian {
        guard action == .accept, contractBoard.action == .accept,
          let quote = contractBoard.glassMeridianQuote
        else {
          throw MissionPackError("Read the current investigation; Back preserves it.")
        }
        try confirmGlassMeridian(quote)
        refreshContractRows()
        contractBoard.detail = false
        contractBoard.wayfarerInductionQuote = nil
        contractBoard.glassMeridianQuote = nil
        return
      }
      if let action = contractBoard.selected?.flightReception {
        guard contractBoard.action == .accept, let quote = contractBoard.flightReceptionQuote,
          quote.action == action
        else { throw MissionPackError("Review the practice and choose Confirm or Back.") }
        try confirmFlightReception(quote)
        refreshContractRows()
        contractBoard.detail = false
        contractBoard.wayfarerInductionQuote = nil
        contractBoard.glassMeridianQuote = nil
        contractBoard.flightReceptionQuote = nil
        return
      }
      if let action = contractBoard.selected?.measuredExtraction {
        guard contractBoard.action == .accept, let quote = contractBoard.measuredExtractionQuote,
          quote.action == action
        else {
          throw MissionPackError("Review the extraction operation and choose Confirm or Back.")
        }
        try confirmMeasuredExtraction(quote)
        refreshContractRows()
        contractBoard.detail = false
        contractBoard.wayfarerInductionQuote = nil
        contractBoard.glassMeridianQuote = nil
        contractBoard.flightReceptionQuote = nil
        contractBoard.measuredExtractionQuote = nil
        return
      }
      if let action = contractBoard.selected?.recordRecovery {
        guard contractBoard.action == .accept, let quote = contractBoard.recordRecoveryQuote,
          quote.action == action
        else { throw MissionPackError("Review the depot operation and choose Confirm or Back.") }
        try confirmRecordRecovery(quote)
        refreshContractRows()
        contractBoard.detail = false
        contractBoard.wayfarerInductionQuote = nil
        contractBoard.glassMeridianQuote = nil
        contractBoard.flightReceptionQuote = nil
        contractBoard.measuredExtractionQuote = nil
        contractBoard.recordRecoveryQuote = nil
        return
      }
      if let action = contractBoard.selected?.identifiedSalvage {
        guard contractBoard.action == .accept, let quote = contractBoard.identifiedSalvageQuote,
          quote.action == action
        else { throw MissionPackError("Review the depot operation and choose Confirm or Back.") }
        try confirmIdentifiedSalvage(quote)
        refreshContractRows()
        contractBoard.detail = false
        contractBoard.wayfarerInductionQuote = nil
        contractBoard.glassMeridianQuote = nil
        contractBoard.flightReceptionQuote = nil
        contractBoard.measuredExtractionQuote = nil
        contractBoard.recordRecoveryQuote = nil
        contractBoard.identifiedSalvageQuote = nil
        contractBoard.utilityQuote = nil
        return
      }
      if let action = contractBoard.selected?.survey {
        guard contractBoard.action == .accept, let quote = contractBoard.surveyQuote,
          quote.action == action
        else { throw MissionPackError("Review the survey and choose Confirm or Back.") }
        try confirmOriginalSurvey(quote)
        refreshContractRows()
        contractBoard.detail = false
        contractBoard.surveyQuote = nil
        return
      }
      if let row = contractBoard.selected?.repairLoop {
        guard contractBoard.action == .accept, let quote = contractBoard.repairLoopQuote,
          quote.row == row
        else {
          throw MissionPackError("Review the native service and choose Confirm or Back.")
        }
        try confirmWayfarerRepairLoopBoard(quote)
        refreshContractRows()
        contractBoard.detail = false
        contractBoard.repairLoopQuote = nil
        return
      }
      if let row = contractBoard.selected?.coldChain {
        guard contractBoard.action == .accept, let quote = contractBoard.coldChainQuote,
          quote.row == row
        else {
          throw MissionPackError("Review the native service and choose Confirm or Back.")
        }
        try confirmWayfarerColdChainBoard(quote)
        refreshContractRows()
        contractBoard.detail = false
        contractBoard.repairLoopQuote = nil
        contractBoard.coldChainQuote = nil
        return
      }
      if contractBoard.selected?.provider != nil {
        if contractBoard.action == .decline {
          gallery.providerIntent = nil
          contractBoard.detail = false
          contractBoard.providerQuote = nil
        } else {
          try stageProviderContractIntent()
        }
        return
      }
      if let row = contractBoard.selected?.people {
        guard contractBoard.action == .accept, let quote = contractBoard.peopleQuote,
          quote.row == row
        else {
          throw MissionPackError("Review the person transfer and choose Confirm or Back.")
        }
        try confirmNativePeople(quote)
        refreshContractRows()
        contractBoard.detail = false
        contractBoard.peopleQuote = nil
        notify("PERSON TRANSFER RECORDED")
        return
      }
      if let row = contractBoard.selected?.finance {
        guard let quote = contractBoard.financeQuote, quote.row == row else {
          throw MissionPackError("Review the financial terms before confirming.")
        }
        try confirmFinance(quote, declining: contractBoard.action == .decline)
        refreshContractRows()
        contractBoard.detail = false
        contractBoard.financeQuote = nil
        notify("FINANCIAL DECISION RECORDED")
        return
      }
      if let row = contractBoard.selected?.rrs {
        guard let quote = contractBoard.rrsQuote, quote.row == row else {
          throw MissionPackError("Review the RRS briefing before confirming.")
        }
        if contractBoard.action == .accept {
          try confirmRRSCourier(quote)
          switch row {
          case .offer: notify("RRS DOCUMENT PACKET ACCEPTED - ORIGINAL MAIN STATION")
          case .debrief: notify("RRS DOCUMENTS DELIVERED - 30.0 CR / REPUTATION +2")
          case .abandon: notify("RRS ASSIGNMENT ABANDONED - 0 CR / REPUTATION -10")
          }
        } else {
          try declineRRSCourier(quote)
          notify("RRS OFFER DECLINED")
        }
        refreshContractRows()
        contractBoard.detail = false
        contractBoard.rrsQuote = nil
        contractBoard.quote = nil
        return
      }
      guard let row = contractBoard.selected, let offer = row.offer else {
        throw MissionPackError("This provider is unavailable.")
      }
      if contractBoard.action == .accept {
        guard let quote = contractBoard.quote else {
          throw MissionPackError("Review this offer before accepting.")
        }
        _ = try confirmContract(quote)
        notify(
          quote.pledge == nil
            ? "CONTRACT ACCEPTED - SEE MISSION GALLERY"
            : quote.pledge.map({ OriginalMutualContribution.matches($0.declaration) }) == true
              ? "CEDAMAR ORBITAL RELIEF RESERVE RECEIVED 500.0 CR - NO CASH REWARD"
              : "DONATION COMPLETE - LOCAL STANDING RECORDED")
      } else {
        try declineContract(board: row.board, offer: offer.id)
        notify("OFFER DECLINED")
      }
      refreshContractRows()
      contractBoard.detail = false
      contractBoard.quote = nil
    } catch {
      openContractBoard()
      notify(String(error.localizedDescription.prefix(512)))
    }
  }
  private mutating func scrollContractDetail(_ key: String) {
    let count = Display.contractDetailRows(self, width: viewportWidth).count
    let visible = ContractBoardLayout(width: viewportWidth, height: viewportHeight).detailCount
    let window = ScrollWindow(count: count, visible: visible, offset: contractBoard.scroll)
    contractBoard.scroll = window.moved(key == "up" || key == "pageup" ? -4 : 4)
  }
  public var activeContractSummary: [String] {
    let rrs =
      commander.contracts.rrs?.active.map { job in
        [
          RRSCourierContent.title + " / "
            + Universe.systemsIncludingPlugh(number: job.destination.system.galaxy)[
              job.destination.system.system
            ].name + " / PROTECTED PACKET"
        ]
      } ?? []
    return rrs
      + commander.scriptState.instances.values.filter {
        $0.outcome == .active && $0.contract != nil
      }
      .sorted { $0.id.uuidString < $1.id.uuidString }.map { instance in
        let job = instance.contract!
        let name = Universe.systemsIncludingPlugh(number: job.station.galaxy)[job.station.system]
          .name
        let late = job.deadline.map { commander.scriptState.clock(job.clock) >= $0 } ?? false
        return job.offer.title + " / " + name + (late ? " / OVERDUE" : " / ACTIVE")
      }
  }
  mutating func contractClick(x: Double, y: Double) {
    guard screen == .contracts, !paused, x.isFinite, y.isFinite,
      x >= 0, y >= 0, x <= viewportWidth, y <= viewportHeight
    else { return }
    let layout = ContractBoardLayout(width: viewportWidth, height: viewportHeight)
    let point = ScreenPoint(x, y)
    if contractBoard.detail {
      if let action = layout.actions.first(where: { $0.1.contains(point) })?.0 {
        contractBoard.action = action
        contractBoardKey("return")
      }
    } else if layout.refresh.contains(point) {
      openContractBoard()
    } else if x >= layout.left && x <= layout.left + layout.width && y >= layout.listTop
      && y < layout.listBottom
    {
      let start = max(0, contractBoard.selection - layout.listCount + 1)
      let index = start + Int((y - layout.listTop) / layout.listRow)
      if contractBoard.rows.indices.contains(index) {
        contractBoard.selection = index
        contractBoardKey("return")
      }
    }
  }
}
extension GameRuntime {
  public func contractClick(x: Double, y: Double, expectedOffer: UUID?, detail: Bool, epoch: UUID) {
    guard game.screen == .contracts, game.ecmControl.epoch == epoch,
      game.contractBoard.selected?.finance == nil,
      game.contractBoard.selected?.people == nil,
      game.contractBoard.detail == detail, game.contractBoard.quote?.offer == expectedOffer
    else { return }
    nativeCommand { $0.contractClick(x: x, y: y) }
  }
  public func contractScroll(_ amount: Int) {
    guard game.screen == .contracts else { return }
    game.contractBoardKey(amount < 0 ? "up" : "down")
  }
}
