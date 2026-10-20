import Foundation

enum NativePeopleStationRow: Equatable, Sendable {
  case journey(NativeStationPassengerJourneyAction)
  case outlook(NativeOrbitalOutlookJourneyAction)
  case rescue(NativeOriginalRescueAction)
  case evacuation(NativeOriginalEvacuationAction)
  case care(NativePeopleOrigin)
  case sale(NativePersonReference)
  case history(UUID)
  var key: String {
    switch self {
    case .journey(let action): "people/journey/" + action.rawValue
    case .outlook(let action): "people/outlook/" + action.rawValue
    case .rescue(let action): "people/rescue/" + action.rawValue
    case .evacuation(let action): "people/evacuation/" + action.rawValue
    case .care(let origin): "people/care/" + origin.rawValue
    case .sale(let person): "people/sale/" + person.key
    case .history(let id): "people/history/" + id.uuidString
    }
  }
  var action: String {
    switch self {
    case .journey(let action): action.action
    case .outlook(let action): action.action
    case .rescue(let action): action.action
    case .evacuation(let action): action.action
    case .care: "Transfer to care"
    case .sale: "Sell one"
    case .history: "Closed"
    }
  }
  var transactional: Bool {
    if case .history = self { return false }
    return true
  }
}

struct NativePeopleStationQuote: Sendable {
  let row: NativePeopleStationRow
  private let snapshot: CommanderSnapshot
  var resources: Commander { snapshot.value }
  let context: NativeMainStationArrivalContext?
  let members: [NativePersonReference]
  let price: Int
  let stock: Int
  let epoch: UUID
  let reviewToken = UUID()
  let issues: [String]
  var allowed: Bool { row.transactional && issues.isEmpty }
  init(
    row: NativePeopleStationRow, commander: Commander, context: NativeMainStationArrivalContext?,
    members: [NativePersonReference], price: Int, stock: Int, epoch: UUID, issues: [String]
  ) {
    self.row = row
    snapshot = CommanderSnapshot(commander.contractQuoteResources)
    self.context = context
    self.members = members
    self.price = price
    self.stock = stock
    self.epoch = epoch
    self.issues = issues
  }
}

extension Game {
  var nativePeopleRows: [ContractBoardRow] {
    let journeys =
      stationPassengerRows + orbitalOutlookRows + originalRescueRows + originalEvacuationRows
    guard let state = commander.nativePeople else { return journeys }
    var rows: [NativePeopleStationRow] = []
    if state.heldPods.contains(where: { $0.origin == .rescuedPod }) {
      rows.append(.care(.rescuedPod))
    }
    if !state.heldCaptives.isEmpty {
      rows.append(.care(.capturedCrew))
      rows += state.heldCaptives.map { .sale($0.person) }
    }
    rows += state.transfers.map { .history($0.operation) }
    return journeys
      + rows.map { row in
        let title: String
        switch row {
        case .journey(let action): title = action.title
        case .outlook(let action): title = action.title
        case .rescue(let action): title = action.title
        case .evacuation(let action): title = action.title
        case .care(.orbitalEvacuee): title = "Original evacuation / agreed receiver"
        case .care(.stationPassenger):
          title = "Original station passengers / agreed passage reception"
        case .care(.originalRescuedPod): title = "Original rescue / agreed care and transport"
        case .care(.rescuedPod): title = "Rescued capsules / orbital receiving care"
        case .care(.capturedCrew): title = "Release captured crew / orbital receiving care"
        case .sale: title = "Slaves / review one captured crew member"
        case .history: title = "People / transfer history"
        }
        return .init(
          board: row.key, offer: nil, title: title,
          reason: nativePeopleQuote(row).issues.first, people: row)
      }
  }
  func nativePeopleQuote(_ row: NativePeopleStationRow) -> NativePeopleStationQuote {
    if case .journey(let action) = row { return stationPassengerQuote(action) }
    if case .outlook(let action) = row { return orbitalOutlookQuote(action) }
    if case .rescue(let action) = row { return originalRescueQuote(action) }
    if case .evacuation(let action) = row { return originalEvacuationQuote(action) }
    var issues: [String] = []
    var members: [NativePersonReference] = []
    var context: NativeMainStationArrivalContext?
    let price: Int
    if case .sale = row { price = market[3].price } else { price = 0 }
    if !commander.nativePeopleStateValid { issues.append("Person custody is invalid.") }
    if let state = commander.nativePeople {
      switch row {
      case .journey, .outlook, .rescue, .evacuation: break
      case .care(let origin):
        members = state.held.filter { $0.origin == origin }.map(\.person)
        if origin == .originalRescuedPod {
          issues.append("Use this original rescue's exact care and receiver row.")
        }
        if origin == .orbitalEvacuee {
          issues.append("Use the original evacuation group receiver row.")
        }
        if origin == .stationPassenger {
          issues.append("Use the original passage's agreed native receiver.")
        }
      case .sale(let person):
        if state.heldCaptives.contains(where: { $0.person == person }) { members = [person] }
        if !stationAllowsMarketServices {
          issues.append("A working main-station market is required.")
        }
        if !(0...1_000_000).contains(price) || commander.credits > 4_294_967_295 - max(0, price)
          || !(0..<1_000_000).contains(market[3].quantity)
        {
          issues.append("The complete market transfer cannot fit its current cash or stock limits.")
        }
      case .history(let id):
        if !state.transfers.contains(where: { $0.operation == id }) {
          issues.append("This receipt is unavailable.")
        }
      }
    } else {
      issues.append("No retained people are available.")
    }
    if row.transactional {
      if !scriptDurabilityAvailable { issues.append("Choose a writable commander save first.") }
      if members.isEmpty { issues.append("No matching people remain aboard.") }
      if case .living(let destination) = nativeOriginalMainStationDestination {
        context = nativeMainStationArrivalContext(for: destination.identity)
      }
      if context == nil {
        issues.append("Return to a proved original main orbital station and resume play.")
      }
    }
    return .init(
      row: row, commander: commander, context: context, members: members,
      price: price, stock: market[3].quantity, epoch: nativeStationRuntimeEpoch, issues: issues)
  }
  mutating func confirmNativePeople(_ quote: NativePeopleStationQuote) throws {
    if case .journey(let action) = quote.row {
      var candidate = self
      try candidate.applyStationPassengerAction(quote, action: action)
      self = candidate
      return
    }
    if case .outlook(let action) = quote.row {
      var candidate = self
      try candidate.applyOrbitalOutlookAction(quote, action: action)
      self = candidate
      return
    }
    if case .rescue(let action) = quote.row {
      try confirmOriginalRescueAction(quote, action: action)
      return
    }
    if case .evacuation(let action) = quote.row {
      try confirmOriginalEvacuationAction(quote, action: action)
      return
    }
    let current = nativePeopleQuote(quote.row)
    guard screen == .contracts, contractBoard.detail, contractBoard.selected?.people == quote.row,
      contractBoard.peopleQuote?.reviewToken == quote.reviewToken,
      quote.allowed, current.allowed, quote.members == current.members,
      quote.price == current.price, quote.stock == current.stock,
      quote.resources == commander.contractQuoteResources, quote.epoch == nativeStationRuntimeEpoch,
      let context = quote.context, acceptsNativeMainStationArrivalContext(context)
    else { throw MissionPackError("People, market or station changed. Review the transfer again.") }
    var candidate = self
    let kind: NativePeopleTransfer
    switch quote.row {
    case .journey, .outlook, .rescue, .evacuation: throw SaveError.invalidCommander
    case .care: kind = .care
    case .sale: kind = .sale
    case .history: throw SaveError.invalidCommander
    }
    try candidate.transferNativePeople(
      quote.members, kind: kind, dock: context.receipt,
      price: quote.price, operation: quote.reviewToken)
    if kind == .sale { candidate.market[3].quantity += 1 }
    guard candidate.commander.valid else { throw SaveError.invalidCommander }
    self = candidate
  }
  @inline(never)
  private mutating func transferNativePeople(
    _ members: [NativePersonReference], kind: NativePeopleTransfer,
    dock: NativeMainStationDockReceipt?, price: Int, operation: UUID
  ) throws {
    try stageNativePeopleTransfer(
      members, kind: kind, dock: dock, price: price, operation: operation)
    try closeStationPassengerTransfer(operation)
    try closeOrbitalOutlookTransfer(operation)
    try closeOriginalRescueTransfer(operation)
    try closeOriginalEvacuationTransfer(operation)
    guard Self.transferredNativePeopleCommanderIsValid(self) else {
      throw SaveError.invalidCommander
    }
  }

  @inline(never)
  private static func transferredNativePeopleCommanderIsValid(_ game: borrowing Game) -> Bool {
    game.withReadOnlyCommander { $0.valid }
  }

  @inline(never)
  private mutating func stageNativePeopleTransfer(
    _ members: [NativePersonReference], kind: NativePeopleTransfer,
    dock: NativeMainStationDockReceipt?, price: Int, operation: UUID
  ) throws {
    guard var state = commander.nativePeople, state.valid(commander: commander),
      !members.isEmpty, members.count <= NativePeopleCustodyState.maximumPeople,
      Set(members).count == members.count,
      members.allSatisfy({ member in state.held.contains { $0.person == member } }),
      state.transfers.count < NativePeopleCustodyState.maximumPeople,
      state.revision < UInt64(NativePeopleCustodyState.maximumPeople * 2),
      let player = commander.flightSimulation.player
    else { throw SaveError.invalidCommander }
    let captives = state.heldCaptives.filter { members.contains($0.person) }.count
    let cash = commander.credits
    let slaves = commander.cargo[3]
    guard slaves >= captives, (0...4_294_967_295).contains(cash),
      price >= 0, price <= 1_000_000, cash <= 4_294_967_295 - price
    else { throw SaveError.invalidCommander }
    state.revision += 1
    state.transfers.append(
      .init(
        operation: operation, members: members, kind: kind, dock: dock,
        collector: player, owner: state.owner,
        physicalTime: commander.flightSimulation.physicalTime,
        calendarSeconds: commander.scriptState.calendarSeconds, beforeCash: cash,
        afterCash: cash + price, beforeSlaves: slaves,
        afterSlaves: kind == .escape ? 0 : slaves - captives,
        price: price, epoch: nativeStationRuntimeEpoch, revision: state.revision))
    commander.cargo[3] = kind == .escape ? 0 : slaves - captives
    commander.credits += price
    commander.savedNativePeopleCustody = state
  }
  mutating func recordNativePeopleLossIfNeeded() throws {
    guard screen == .gameOver, energy.isFinite, energy <= 0,
      let state = commander.nativePeople, !state.held.isEmpty
    else { return }
    try transferNativePeople(
      state.held.map(\.person), kind: .loss, dock: nil, price: 0, operation: UUID())
  }
  mutating func abandonNativePeopleOnEscape() throws {
    guard let state = commander.nativePeople, !state.held.isEmpty else { return }
    try transferNativePeople(
      state.held.map(\.person), kind: .escape, dock: nil, price: 0, operation: UUID())
  }
  mutating func reviewNativeCaptiveSale() -> Bool {
    guard let person = commander.nativePeople?.heldCaptives.first?.person else { return false }
    openContractBoard()
    guard screen == .contracts,
      let index = contractBoard.rows.firstIndex(where: { $0.people == .sale(person) })
    else { return true }
    contractBoard.selection = index
    contractBoard.detail = true
    contractBoard.action = .back
    refreshSelectedContractQuote()
    return true
  }
  mutating func transferOrbitalOutlookJourney(
    members: [NativePersonReference], dock: NativeMainStationDockReceipt, operation: UUID,
    receive: Bool
  ) throws {
    guard nativeMainStationDockEvidenceIsCurrent, dock == commander.nativeStations?.currentMainDock,
      let custody = commander.nativePeople, let source = custody.outlookJourney,
      source.boarding != nil, source.terminalOperation == nil, members == source.references,
      NativeOrbitalOutlookJourney.sourceMatches(dock),
      receive
        ? NativeOrbitalOutlookJourney.returnReady(source, dock: dock)
        : !NativeOrbitalOutlookJourney.returnReady(source, dock: dock),
      members.allSatisfy({ person in custody.held.contains { $0.person == person } })
    else { throw SaveError.invalidCommander }
    try transferNativePeople(members, kind: .care, dock: dock, price: 0, operation: operation)
  }
  @inline(never)
  mutating func transferOriginalEvacuationJourney(
    members: [NativePersonReference], dock: NativeMainStationDockReceipt, operation: UUID
  ) throws {
    try validateOriginalEvacuationTransfer(members: members, dock: dock)
    try transferNativePeople(members, kind: .care, dock: dock, price: 0, operation: operation)
  }
  @inline(never)
  private func validateOriginalEvacuationTransfer(
    members: [NativePersonReference], dock: NativeMainStationDockReceipt
  ) throws {
    guard nativeMainStationDockEvidenceIsCurrent, dock == commander.nativeStations?.currentMainDock,
      let custody = commander.nativePeople, let source = custody.orbitalEvacuation,
      source.boarding != nil, source.terminalOperation == nil, members == source.references,
      members.allSatisfy({ person in custody.held.contains { $0.person == person } }),
      NativeOriginalEvacuation.sourceMatches(dock)
        || NativeOriginalEvacuation.destinationMatches(dock)
    else {
      throw MissionPackError(
        "All four original living people need the agreed receiver or actual source return.")
    }
  }
  mutating func transferStationPassengerJourney(
    members: [NativePersonReference], dock: NativeMainStationDockReceipt, operation: UUID
  ) throws {
    guard nativeMainStationDockEvidenceIsCurrent, dock == commander.nativeStations?.currentMainDock,
      let state = commander.nativePeople, let journey = state.stationJourney,
      journey.boarding != nil, journey.terminalOperation == nil, members == journey.references,
      members.allSatisfy({ member in state.held.contains { $0.person == member } }),
      NativeStationPassengerJourney.sourceMatches(dock)
        || NativeStationPassengerJourney.destinationMatches(dock)
    else {
      throw MissionPackError(
        "The same two living original people require their actual agreed care receiver.")
    }
    try transferNativePeople(members, kind: .care, dock: dock, price: 0, operation: operation)
  }

  @inline(never)
  mutating func transferOriginalRescueCare(
    dock: NativeMainStationDockReceipt, operation: UUID, final: Bool
  ) throws {
    let held = try originalRescueCareMembers(dock: dock, operation: operation, final: final)
    try transferNativePeople(held, kind: .care, dock: dock, price: 0, operation: operation)
  }

  @inline(never)
  private func originalRescueCareMembers(
    dock: NativeMainStationDockReceipt, operation: UUID, final: Bool
  ) throws -> [NativePersonReference] {
    guard nativeMainStationDockEvidenceIsCurrent, dock == commander.nativeStations?.currentMainDock,
      let custody = commander.nativePeople, let source = custody.originalRescue,
      source.terminalOperation == nil,
      final
        ? NativeOriginalRescueJourney.destinationMatches(dock)
        : NativeOriginalRescueJourney.sourceMatches(dock)
    else { throw SaveError.invalidCommander }
    let held = custody.held.filter { $0.person.rescue != nil }.map(\.person)
    if final {
      guard source.boarding != nil, held == source.references,
        source.recordReception?.operation == operation, source.recordReception?.dock == dock
      else { throw SaveError.invalidCommander }
    }
    return held
  }

  var nativePeopleDetail: [String] {
    if case .evacuation(let action) = contractBoard.selected?.people {
      return originalEvacuationDetail(action)
    }
    if case .rescue(let action) = contractBoard.selected?.people {
      return originalRescueDetail(action)
    }
    if case .outlook(let action) = contractBoard.selected?.people {
      return orbitalOutlookDetail(action)
    }
    if case .journey(let action)? = contractBoard.selected?.people {
      return stationPassengerDetail(action)
    }

    guard let row = contractBoard.selected?.people, let state = commander.nativePeople else {
      return []
    }
    if case .history(let id) = row,
      let receipt = state.transfers.first(where: { $0.operation == id })
    {
      if commander.nativePeople?.stationJourney?.terminalOperation == id {
        let journey = commander.nativePeople?.stationJourney
        let mission = journey?.boarding.flatMap { commander.scriptState.instances[$0.mission] }
        return [
          "Mira Talen and Oren Vey / original native passage receipt",
          "Actual custody receipt outcome: \(receipt.kind.rawValue); total people in this receipt: \(receipt.members.count).",
          "Actual custody outcome: " + (mission?.outcome.rawValue ?? "unavailable"),
          String(
            format: "Published settlement: %.1f CR.",
            Double(mission?.contract?.settlementAmount ?? 0) / 10),
          "Original native identities, consent and care/loss remain recorded; no replacement people are created.",
        ]
      }
      return [
        "People transfer receipt",
        "Outcome: \(receipt.kind.rawValue). People: \(receipt.members.count).",
        "This closes their player custody. It does not describe a permanent station population.",
        String(format: "Cash transfer: %.1f CR.", Double(receipt.price) / 10),
      ]
    }
    let quote = contractBoard.peopleQuote ?? nativePeopleQuote(row)
    var rows = [
      "People aboard: \(quote.members.count). One tonne per protected unit.",
      "Current real hold: \(commander.cargoTonnes) / \(commander.standardCargoCapacity)t.",
      "Back changes no custody, cargo or cash.",
    ]
    if case .sale = row {
      rows += [
        String(format: "Sell this one captured crew member for %.1f CR.", Double(quote.price) / 10),
        "The sale ends your custody once; the original discharge and sale receipt remain.",
      ]
    } else {
      rows += [
        "Confirm transfers this exact aboard batch to orbital receiving care.",
        "Care means accepted for assessment; no cure, reward or deadline is invented.",
        "Sealed capsules free protected hold; released captives free their Slaves units once.",
      ]
    }
    return rows + quote.issues
  }
  var nativePeoplePageFacts: [String] {
    let journeyFacts =
      stationPassengerFacts + orbitalOutlookFacts + originalRescueFactsForPage
      + originalEvacuationFacts
    guard let state = commander.nativePeople else { return journeyFacts }
    var result =
      journeyFacts + [
        state.owner.uuidString, String(state.revision), nativeStationRuntimeEpoch.uuidString,
      ]
    if let row = contractBoard.selected?.people {
      let quote = nativePeopleQuote(row)
      result += [row.key, String(quote.price), String(quote.stock)] + quote.issues
      result += quote.members.map(\.key)
      if let context = quote.context {
        result += [
          context.receipt.station.key, String(context.receipt.sequence),
          String(context.receipt.actor.visit),
        ]
      }
    }
    return result
  }
}

extension GameRuntime {
  func commitNativePeopleLoss() {
    guard let publish = scriptPublisher() else { return }
    var candidate = game
    do {
      try candidate.recordNativePeopleLossIfNeeded()
      guard candidate.commander != game.commander else { return }
      try publish(&candidate)
      game = candidate
    } catch { game.notify("PERSON CUSTODY LOSS NOT SAVED - RETRY SAVE") }
  }
}
