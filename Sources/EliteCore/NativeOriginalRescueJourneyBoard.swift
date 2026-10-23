import Foundation

enum NativeOriginalRescueAction: String, Equatable, Sendable {
  case accept, care, request, board, receive, cancel
  var title: String {
    switch self {
    case .accept: "Neri Voss and Ilan Rook / original capsule rescue"
    case .care: "Cedamar rescue care / receive this original living capsule"
    case .request: "Neri and Ilan / request voluntary Celalen replies"
    case .board: "Board the same two cared-for consenting people"
    case .receive: "Celalen / receive both people and their original record"
    case .cancel: "Cedamar / safe return and cancel rescue transport"
    }
  }
  var action: String {
    switch self {
    case .accept: "Accept incident"
    case .care: "Receive capsule"
    case .request: "Request replies"
    case .board: "Board both"
    case .receive: "Receive all"
    case .cancel: "Return safely"
    }
  }
}

private struct NativeOriginalRescueAcceptance: Sendable {
  let owner: UUID
  let carrier: UUID
  let definition: NativeOriginalRescueDefinition
  let slots: [PassengerBerth]
  let boardKey: String
  let key: String
  let offerID: UUID
  let missionID: UUID
}

extension Game {
  var originalRescuePack: ScriptPack? {
    scriptPacks.first {
      $0.manifest.stateID == NativeOriginalRescueJourney.stateID
        && $0.digest == NativeOriginalRescueJourney.digest
        && $0.manifest.originalRescue?.valid == true
    }
  }
  var originalRescueRows: [ContractBoardRow] {
    guard originalRescuePack != nil else { return [] }
    let state = commander.nativePeople?.originalRescue
    guard state?.terminalOperation == nil else { return [] }
    let actions: [NativeOriginalRescueAction]
    if state == nil {
      guard contractStation == NativeOriginalRescueJourney.source else { return [] }
      actions = [.accept]
    } else if contractStation == NativeOriginalRescueJourney.source {
      actions = [.care, .request, .board, .cancel]
    } else {
      actions = [.receive]
    }
    return actions.map { action in
      let row = NativePeopleStationRow.rescue(action)
      return .init(
        board: row.key, offer: nil, title: action.title,
        reason: originalRescueQuote(action).issues.first, people: row)
    }
  }
  @inline(never)
  func originalRescueQuote(_ action: NativeOriginalRescueAction) -> NativePeopleStationQuote {
    var issues: [String] = []
    var context: NativeMainStationArrivalContext?
    if case .living(let destination) = nativeOriginalMainStationDestination {
      context = nativeMainStationArrivalContext(for: destination.identity)
    }
    if context == nil { issues.append("Use the actual living original main orbital station.") }
    if !scriptDurabilityAvailable { issues.append("Choose a writable commander save.") }
    if !Self.originalRescueCommanderIsValid(self) {
      issues.append("Current native custody or fitting is invalid.")
    }
    if originalRescuePack == nil { issues.append("Original rescue content is unavailable.") }
    return originalRescueActionQuote(action, context: context, initialIssues: issues)
  }

  // Keep action-specific temporaries out of the stack used by full Commander validation.
  @inline(never)
  private func originalRescueActionQuote(
    _ action: NativeOriginalRescueAction, context: NativeMainStationArrivalContext?,
    initialIssues: [String]
  ) -> NativePeopleStationQuote {
    var issues = initialIssues
    let state = commander.nativePeople?.originalRescue
    let members = state?.references ?? []
    switch action {
    case .accept:
      if state != nil || contractStation != NativeOriginalRescueJourney.source {
        issues.append("This finite Cedamar incident cannot be accepted again.")
      }
      let berths = commander.accommodation.availablePlaces(privateCabin: true)
      if berths.count < 2 || commander.passengerFit?.allowed != true {
        issues.append("Fit two free compatible working cabins for the original people.")
      }
      if commander.cargoTonnes >= commander.standardCargoCapacity {
        issues.append("One real cargo tonne is required for serial capsules and the record.")
      }
      if !hasNativeRescueTools {
        issues.append("Fit targeting, salvage targeting and Fuel Scoops.")
      }
      if OriginalServiceReservationPolicy.activeCount(commander.scriptState)
        >= OriginalServiceReservationPolicy.maximumActive
      {
        issues.append("Three Original contracts or services are already active.")
      }
      let systems = Universe.systemsIncludingPlugh(number: 0)
      if systems[85].distance(to: systems[241]) > commander.maximumJumpDistance {
        issues.append("Refuel or refit for the actual one-leg Celalen transport.")
      }
    case .care:
      if contractStation != NativeOriginalRescueJourney.source || state?.boarding != nil {
        issues.append("The original sealed capsule requires its Cedamar care custodian.")
      }
      if commander.nativePeople?.heldPods.contains(where: { $0.person.rescue != nil }) != true {
        issues.append("Actually recover one original living capsule first.")
      }
    case .request:
      if contractStation != NativeOriginalRescueJourney.source || state?.boarding != nil {
        issues.append("Request voluntary replies after actual Cedamar care, before boarding.")
      }
      if let state, let custody = commander.nativePeople {
        if !state.references.allSatisfy({ state.care(for: $0, custody: custody) != nil }) {
          issues.append("Both original people must actually be in Cedamar care.")
        }
      } else {
        issues.append("Accept and complete both serial capsule-to-care recoveries first.")
      }
    case .board:
      if let issue = originalRescueBoardingIssue(state) { issues.append(issue) }
    case .receive:
      if contractStation != NativeOriginalRescueJourney.destination {
        issues.append("Reach the actual agreed Celalen main orbital receiver.")
      }
      if let state, let custody = commander.nativePeople {
        if state.boarding == nil || !NativeOriginalRescueJourney.recordCarried(state)
          || !state.references.allSatisfy({ person in custody.held.contains { $0.person == person }
          })
        {
          issues.append(
            "Both same living consenting people and their original physical record are required.")
        }
      } else {
        issues.append("No complete original rescue transport is aboard.")
      }
    case .cancel:
      if contractStation != NativeOriginalRescueJourney.source || state == nil {
        issues.append("Return to actual Cedamar care for a safe cancellation.")
      }
    }
    if state?.terminalOperation != nil { issues.append("This finite incident is already closed.") }
    return .init(
      row: .rescue(action), commander: commander, context: context, members: members,
      price: 0, stock: 0, epoch: nativeStationRuntimeEpoch, issues: issues)
  }
  func originalRescueBoardingIssue(_ state: NativeOriginalRescueJourneyState?) -> String? {
    guard let state, state.boarding == nil, state.terminalOperation == nil,
      contractStation == NativeOriginalRescueJourney.source,
      nativeMainStationDockEvidenceIsCurrent,
      let offer = state.offers.last, offer.dock == commander.nativeStations?.currentMainDock,
      offer.carrier == commander.hullInstanceID,
      offer.inventoryRevision == commander.equipmentInventory?.revision,
      offer.epoch == nativeStationRuntimeEpoch, offer.path == [85, 241],
      offer.berths.count == 2, commander.passengerFit?.allowed == true
    else { return "Request fresh native Celalen transport replies at actual Cedamar care." }
    return originalRescueReservedBerthIssue(state, offer: offer)
  }

  @inline(never)
  private func originalRescueReservedBerthIssue(
    _ state: NativeOriginalRescueJourneyState, offer: NativeStationPassageOffer
  ) -> String? {
    for ordinal in 0..<2 {
      guard let person = state.references[ordinal].rescue,
        let reply = state.replies.last(where: { $0.person == person && $0.offer == offer.id }),
        reply.kind == .accept, reply.request.intent == .passage,
        reply.request.destination == .init(galaxy: 0, system: 241),
        let berth = commander.accommodation.fittedBerths.first(where: {
          $0.id == state.reservedBerths[ordinal]
        }),
        berth == offer.berths[ordinal], berth.lifeSupportWorking, berth.humanoidCompatible,
        berth.use == .reserved(mission: state.mission, person: person.id)
      else { return "Both original people must accept the actual reserved compatible cabins." }
    }
    return nil
  }
  /// Finish read-only freshness checks before reserving a candidate publication frame.
  @inline(never)
  mutating func confirmOriginalRescueAction(
    _ quote: NativePeopleStationQuote, action: NativeOriginalRescueAction
  ) throws {
    let (pack, context) = try validateOriginalRescueAction(quote, action: action)
    try publishOriginalRescueAction(
      action, pack: pack, context: context, operation: quote.reviewToken)
  }

  /// Mutation and event-drain staging return before the full semantic validation walk.
  @inline(never)
  private mutating func publishOriginalRescueAction(
    _ action: NativeOriginalRescueAction, pack: ScriptPack,
    context: NativeMainStationArrivalContext, operation: UUID
  ) throws {
    let candidate = try originalRescueCandidate(
      action, pack: pack, context: context, operation: operation)
    guard Self.originalRescueCommanderIsValid(candidate) else { throw SaveError.invalidCommander }
    self = candidate
  }

  /// Borrow the stored commander without materializing an owned comparison or validation copy.
  @inline(never)
  private static func originalRescueCommanderIsValid(_ game: borrowing Game) -> Bool {
    game.withReadOnlyCommander { $0.valid }
  }

  @inline(never)
  func originalRescueCandidate(
    _ action: NativeOriginalRescueAction, pack: ScriptPack,
    context: NativeMainStationArrivalContext, operation: UUID
  ) throws -> Game {
    var candidate = self
    try candidate.mutateOriginalRescueAction(
      action, pack: pack, dock: context.receipt, operation: operation)
    return candidate
  }

  @inline(never)
  func validateOriginalRescueAction(
    _ quote: NativePeopleStationQuote, action: NativeOriginalRescueAction
  ) throws -> (ScriptPack, NativeMainStationArrivalContext) {
    guard originalRescueReviewIsCurrent(quote, action: action),
      originalRescueResourcesMatch(quote), quote.epoch == nativeStationRuntimeEpoch
    else { throw MissionPackError(Self.originalRescueChangedSourceMessage) }
    return try originalRescueActionContext(quote)
  }

  @inline(never)
  private func originalRescueReviewIsCurrent(
    _ quote: NativePeopleStationQuote, action: NativeOriginalRescueAction
  ) -> Bool {
    let current = originalRescueQuote(action)
    return screen == .contracts && contractBoard.detail
      && contractBoard.selected?.people == quote.row
      && contractBoard.peopleQuote?.reviewToken == quote.reviewToken
      && quote.allowed && current.allowed && quote.members == current.members
  }

  @inline(never)
  private func originalRescueResourcesMatch(_ quote: NativePeopleStationQuote) -> Bool {
    quote.resources == commander.contractQuoteResources
  }

  @inline(never)
  private func originalRescueActionContext(
    _ quote: NativePeopleStationQuote
  ) throws -> (ScriptPack, NativeMainStationArrivalContext) {
    guard let context = quote.context, acceptsNativeMainStationArrivalContext(context),
      let pack = originalRescuePack
    else { throw MissionPackError(Self.originalRescueChangedSourceMessage) }
    return (pack, context)
  }

  private static let originalRescueChangedSourceMessage =
    "Original source, custody, fitting or actual receiver changed."

  @inline(never)
  private mutating func mutateOriginalRescueAction(
    _ action: NativeOriginalRescueAction, pack: ScriptPack,
    dock: NativeMainStationDockReceipt, operation: UUID
  ) throws {
    if action == .accept {
      try acceptAndEmitOriginalRescue(pack, dock: dock, operation: operation)
      return
    }
    try mutateContinuingOriginalRescueAction(
      action, pack: pack, dock: dock, operation: operation)
  }

  @inline(never)
  private mutating func acceptAndEmitOriginalRescue(
    _ pack: ScriptPack, dock: NativeMainStationDockReceipt, operation: UUID
  ) throws {
    let mission = try acceptOriginalRescue(pack, dock: dock, operation: operation)
    // Script queries drain only after acceptance staging has returned.
    emitScriptEvent("mission.accepted", only: mission)
  }

  @inline(never)
  private mutating func mutateContinuingOriginalRescueAction(
    _ action: NativeOriginalRescueAction, pack: ScriptPack,
    dock: NativeMainStationDockReceipt, operation: UUID
  ) throws {
    switch action {
    case .accept:
      try acceptAndEmitOriginalRescue(pack, dock: dock, operation: operation)
    case .care:
      try transferOriginalRescueCare(
        dock: dock, operation: operation, final: false)
    case .request: try requestOriginalRescueConsent()
    case .board: try boardOriginalRescue(operation: operation)
    case .receive:
      try receiveOriginalRescueRecord(dock: dock, operation: operation)
      try transferOriginalRescueCare(
        dock: dock, operation: operation, final: true)
    case .cancel:
      if commander.nativePeople?.originalRescue.map(NativeOriginalRescueJourney.recordCarried)
        == true
      {
        try receiveOriginalRescueRecord(dock: dock, operation: operation)
      }
      if commander.nativePeople?.held.contains(where: { $0.person.rescue != nil }) == true {
        try transferOriginalRescueCare(
          dock: dock, operation: operation, final: false)
      }
      if commander.nativePeople?.originalRescue?.terminalOperation == nil {
        try finishOriginalRescue(outcome: .abandoned, operation: operation)
      }
    }
  }

  @inline(never)
  private mutating func requestOriginalRescueConsent() throws {
    var state = try withReadOnlyCommander { commander in
      guard let state = commander.nativePeople?.originalRescue else {
        throw SaveError.invalidCommander
      }
      return state
    }
    try NativeOriginalRescueJourney.requestConsent(state: &state, game: self)
    try publishOriginalRescueConsent(state)
  }

  /// Retire the consent walk before copying the custody value for its unpublished update.
  @inline(never)
  private mutating func publishOriginalRescueConsent(
    _ state: borrowing NativeOriginalRescueJourneyState
  ) throws {
    guard var custody = withReadOnlyCommander({ $0.nativePeople }) else {
      throw SaveError.invalidCommander
    }
    custody.originalRescue = copy state
    commander.savedNativePeopleCustody = custody
  }

  @inline(never)
  private mutating func acceptOriginalRescue(
    _ pack: ScriptPack, dock: NativeMainStationDockReceipt, operation: UUID
  ) throws -> UUID {
    let acceptance = try prepareOriginalRescueAcceptance(pack, dock: dock)
    let job = stageOriginalRescueOffer(pack, acceptance: acceptance)
    try stageOriginalRescueCustody(acceptance, pack: pack, dock: dock, operation: operation)
    stageOriginalRescueMission(pack, missionID: acceptance.missionID, job: job)
    return acceptance.missionID
  }

  @inline(never)
  private mutating func prepareOriginalRescueAcceptance(
    _ pack: ScriptPack, dock: NativeMainStationDockReceipt
  ) throws -> NativeOriginalRescueAcceptance {
    try OriginalServiceReservationPolicy.requireAvailableSlot(commander.scriptState)
    guard let owner = commander.equipmentOwnerID, let carrier = commander.hullInstanceID,
      let definition = pack.manifest.originalRescue, definition.valid,
      commander.nativePeople?.originalRescue == nil,
      NativeOriginalRescueJourney.sourceMatches(dock)
    else { throw SaveError.invalidCommander }
    ensureScriptCalendar(origin: .newCommander)
    let slots = Array(
      commander.accommodation.availablePlaces(privateCabin: true).sorted {
        $0.id.uuidString < $1.id.uuidString
      }.prefix(2))
    guard slots.count == 2 else { throw SaveError.invalidCommander }
    let boardKey = pack.digest + "/custody-rescue/" + NativeOriginalRescueJourney.source.key
    let key = "original-" + NativeOriginalRescueJourney.batch
    let offerID = ScriptIdentity.uuid("contract-offer-v1:\(boardKey):0:\(key)")
    let missionID = Self.contractJobIdentity(offerID)
    guard commander.scriptState.instances[missionID] == nil else {
      throw SaveError.invalidCommander
    }
    return .init(
      owner: owner, carrier: carrier, definition: definition, slots: slots,
      boardKey: boardKey, key: key, offerID: offerID, missionID: missionID)
  }

  @inline(never)
  private mutating func stageOriginalRescueOffer(
    _ pack: ScriptPack, acceptance: NativeOriginalRescueAcceptance
  ) -> ScriptContractJob {
    let boardKey = acceptance.boardKey
    let key = acceptance.key
    let offerID = acceptance.offerID
    let missionID = acceptance.missionID
    let offer = ScriptContractOffer(
      id: offerID, key: key, title: "Neri and Ilan / L1 H0 / 1020 CR / untimed",
      briefing:
        "Two original living capsules, serial Cedamar care, same-person voluntary transport, original physical emergency record and actual Celalen reception. Two cabins and one protected cargo tonne; zero deposit.",
      destinationGalaxy: 0, destinationSystem: 241, reward: NativeOriginalRescueJourney.reward,
      deposit: 0, failureReward: 0, refundOnFailure: false, duration: 0,
      parameters: .object(["original_rescue": .string(NativeOriginalRescueJourney.batch)]))
    let job = ScriptContractJob(
      boardKey: boardKey, provider: pack.manifest.id,
      version: pack.manifest.version, digest: pack.digest,
      station: NativeOriginalRescueJourney.source,
      boardRevision: 0, group: NativeOriginalRescueJourney.stateID, offer: offer, clock: .local,
      acceptedAt: commander.scriptState.clock(.local), deadline: nil)
    var accepted = offer
    accepted.status = .accepted(missionID)
    commander.contracts.boards[boardKey] = .init(
      id: NativeOriginalRescueJourney.boardID,
      provider: pack.manifest.id, version: pack.manifest.version, digest: pack.digest,
      title: "Original consented custody rescue", station: NativeOriginalRescueJourney.source,
      revision: 0, seed: 0, clock: .local, period: 3600,
      group: NativeOriginalRescueJourney.stateID, offers: [accepted])
    return job
  }

  @inline(never)
  private mutating func stageOriginalRescueCustody(
    _ acceptance: NativeOriginalRescueAcceptance, pack: ScriptPack,
    dock: NativeMainStationDockReceipt, operation: UUID
  ) throws {
    let owner = acceptance.owner
    var custody = commander.nativePeople ?? .init(owner: owner)
    let state = originalRescueAcceptanceState(
      acceptance, pack: pack, dock: dock, operation: operation)
    try reserveOriginalRescueAcceptanceBerths(
      acceptance.slots, state: state, missionID: acceptance.missionID)
    custody.originalRescue = state
    commander.savedNativePeopleCustody = custody
  }

  @inline(never)
  private func originalRescueAcceptanceState(
    _ acceptance: NativeOriginalRescueAcceptance, pack: ScriptPack,
    dock: NativeMainStationDockReceipt, operation: UUID
  ) -> NativeOriginalRescueJourneyState {
    let owner = acceptance.owner
    let definition = acceptance.definition
    let carrier = acceptance.carrier
    let slots = acceptance.slots
    let missionID = acceptance.missionID
    return NativeOriginalRescueJourneyState(
      owner: owner, definition: definition,
      version: pack.manifest.version, digest: pack.digest, registration: dock,
      registeredAt: commander.flightSimulation.physicalTime,
      inventoryRevision: commander.equipmentInventory?.revision ?? 0,
      operation: operation, mission: missionID, carrier: carrier, reservedBerths: slots.map(\.id))
  }

  @inline(never)
  private mutating func reserveOriginalRescueAcceptanceBerths(
    _ slots: borrowing [PassengerBerth], state: borrowing NativeOriginalRescueJourneyState,
    missionID: UUID
  ) throws {
    for ordinal in 0..<2 {
      guard
        let index = commander.accommodation.ownedBerths.firstIndex(where: {
          $0.id == slots[ordinal].id
        }),
        let person = state.references[ordinal].rescue
      else { throw SaveError.invalidCommander }
      commander.accommodation.ownedBerths[index].mode = .awake
      commander.accommodation.ownedBerths[index].privateCabin = true
      commander.accommodation.ownedBerths[index].use = .reserved(
        mission: missionID, person: person.id)
    }
  }

  @inline(never)
  private mutating func stageOriginalRescueMission(
    _ pack: ScriptPack, missionID: UUID, job: ScriptContractJob
  ) {
    var mission = ScriptInstance(
      id: missionID, definition: NativeOriginalRescueJourney.stateID,
      version: pack.manifest.version, digest: pack.digest)
    mission.contract = job
    mission.milestones = [0]
    commander.scriptState.instances[missionID] = mission
  }

  @inline(never)
  private mutating func boardOriginalRescue(operation: UUID) throws {
    guard originalRescueBoardingIssue(commander.nativePeople?.originalRescue) == nil,
      var custody = commander.nativePeople, var state = custody.originalRescue,
      let offer = state.offers.last,
      custody.revision < UInt64(NativePeopleCustodyState.maximumPeople * 2)
    else { throw SaveError.invalidCommander }
    let replies = try (0..<2).map { ordinal -> Int in
      guard let person = state.references[ordinal].rescue,
        let index = state.replies.lastIndex(where: { $0.person == person && $0.offer == offer.id })
      else { throw SaveError.invalidCommander }
      return index
    }
    custody.revision += 1
    state.boarding = .init(
      operation: operation, offer: offer.id, replies: replies, dock: offer.dock,
      collector: offer.collector, carrier: offer.carrier, berths: offer.berths.map(\.id),
      inventoryRevision: offer.inventoryRevision,
      physicalTime: commander.flightSimulation.physicalTime,
      epoch: nativeStationRuntimeEpoch, revision: custody.revision)
    for ordinal in 0..<2 {
      guard
        let index = commander.accommodation.ownedBerths.firstIndex(where: {
          $0.id == state.reservedBerths[ordinal]
        })
      else { throw SaveError.invalidCommander }
      commander.accommodation.ownedBerths[index].mode = .awake
      commander.accommodation.ownedBerths[index].privateCabin = true
      commander.accommodation.ownedBerths[index].use = .nativePerson(state.references[ordinal])
    }
    custody.originalRescue = state
    commander.savedNativePeopleCustody = custody
  }

  /// Intermediate care never settles the job. Only a complete actual receiver or honest
  /// loss/cancellation reaches the existing contract settlement and once-only clue publisher.
  @inline(never)
  mutating func closeOriginalRescueTransfer(_ operation: UUID) throws {
    if let outcome = try originalRescueTransferOutcome(operation) {
      try finishOriginalRescue(outcome: outcome, operation: operation)
    }
  }

  @inline(never)
  private func originalRescueTransferOutcome(_ operation: UUID) throws -> ScriptOutcome? {
    guard let custody = commander.nativePeople, let state = custody.originalRescue,
      let receipt = custody.transfers.first(where: { $0.operation == operation }),
      receipt.members.contains(where: { $0.rescue != nil })
    else { return nil }
    switch receipt.kind {
    case .sale: throw SaveError.invalidCommander
    case .loss, .escape: return .failed
    case .care:
      guard let dock = receipt.dock else { throw SaveError.invalidCommander }
      if state.boarding == nil {
        guard NativeOriginalRescueJourney.sourceMatches(dock) else {
          throw SaveError.invalidCommander
        }
        return nil
      }
      if NativeOriginalRescueJourney.destinationMatches(dock) {
        guard receipt.members.filter({ $0.rescue != nil }) == state.references,
          let record = state.recordReception, record.operation == operation, record.dock == dock
        else { throw SaveError.invalidCommander }
        return .complete
      } else {
        guard NativeOriginalRescueJourney.sourceMatches(dock) else {
          throw SaveError.invalidCommander
        }
        return .abandoned
      }
    }
  }

  @inline(never)
  mutating func finishOriginalRescue(outcome: ScriptOutcome, operation: UUID) throws {
    let revision = try originalRescueFinishRevision(outcome)
    let cause = Self.scriptEventContext(in: self, revision: revision)
    let (previous, mission, sequence) = try stageOriginalRescueFinish(outcome, operation: operation)
    let committed = Self.scriptEventContext(in: self, revision: mission.revision)
    try publishOriginalRescueCompletion(
      previous: previous, next: mission, sequence: sequence, cause: cause, committed: committed)
  }

  @inline(never)
  private func originalRescueFinishRevision(_ outcome: ScriptOutcome) throws -> UInt64 {
    guard let custody = commander.nativePeople, let state = custody.originalRescue,
      state.terminalOperation == nil,
      let mission = commander.scriptState.instances[state.mission], mission.outcome == .active,
      commander.scriptState.nextEvent < UInt64.max - 1, mission.revision < UInt64.max
    else { throw SaveError.invalidCommander }
    if outcome == .complete || outcome == .abandoned {
      guard nativeMainStationDockEvidenceIsCurrent,
        let dock = commander.nativeStations?.currentMainDock,
        outcome == .complete
          ? NativeOriginalRescueJourney.destinationMatches(dock)
          : NativeOriginalRescueJourney.sourceMatches(dock)
      else { throw SaveError.invalidCommander }
    }
    guard !custody.held.contains(where: { $0.person.rescue != nil }) else {
      throw SaveError.invalidCommander
    }
    return mission.revision
  }

  @inline(never)
  private mutating func stageOriginalRescueFinish(
    _ outcome: ScriptOutcome, operation: UUID
  ) throws -> (ScriptInstance, ScriptInstance, UInt64) {
    // The read-only preconditions and cause extraction completed synchronously; no reentry
    // can change these values before this unpublished mutation stage.
    guard var custody = commander.nativePeople, var state = custody.originalRescue,
      var mission = commander.scriptState.instances[state.mission]
    else { throw SaveError.invalidCommander }
    if outcome == .complete || outcome == .abandoned {
      guard let dock = commander.nativeStations?.currentMainDock else {
        throw SaveError.invalidCommander
      }
      state.terminalDock = dock
    }
    let previous = mission
    var candidate = commander
    try settleContract(outcome, state: &mission, candidate: &candidate)
    candidate.scriptState.nextEvent += 1
    let sequence = candidate.scriptState.nextEvent
    mission.outcome = outcome
    mission.revision += 1
    mission.dialogue = nil
    if outcome == .complete { mission.milestones.insert(1) }
    mission.acknowledge(sequence)
    state.terminalOperation = operation
    custody.originalRescue = state
    candidate.savedNativePeopleCustody = custody
    for index in candidate.accommodation.ownedBerths.indices {
      if state.reservedBerths.contains(candidate.accommodation.ownedBerths[index].id) {
        candidate.accommodation.ownedBerths[index].use = .empty
      }
    }
    commander = candidate
    return (previous, mission, sequence)
  }

  @inline(never)
  private mutating func publishOriginalRescueCompletion(
    previous: borrowing ScriptInstance, next: borrowing ScriptInstance, sequence: UInt64,
    cause: borrowing ScriptEventContext, committed: borrowing ScriptEventContext
  ) throws {
    var mission = copy next
    mission.completionReceipt = .init(
      instance: mission.id, definition: mission.definition,
      version: mission.version, digest: mission.digest, outcome: mission.outcome,
      sequence: sequence,
      causeKind: "mission.receipted", cause: copy cause, committed: copy committed,
      revision: mission.revision, milestones: mission.milestones.sorted(), destroyedEncounters: [],
      deliveredParties: [], returnedEquipment: [],
      settlementAmount: mission.contract?.settlementAmount,
      choices: nil)
    commander.scriptState.instances[mission.id] = mission
    try awardScriptClue(previous: copy previous, next: mission, trust: .production)
    if let receipt = mission.completionReceipt { try enqueueScriptCompletion(receipt) }
  }

  func originalRescueDetail(_ action: NativeOriginalRescueAction) -> [String] {
    let state = commander.nativePeople?.originalRescue
    let care =
      state?.references.filter { person in
        commander.nativePeople.map { state?.care(for: person, custody: $0) != nil } == true
      }.count ?? 0
    return [
      "Neri Voss and Ilan Rook / original Cedamar incident / Celalen receiver",
      "Two working compatible cabins, one protected cargo tonne, serial local rescue and care.",
      "Care accepts each original person for assessment and frees its capsule tonne; it is not transport consent.",
      "Request native replies after both care receptions, then separately board those same people.",
      "Recover their original physical emergency record last. Ordinary crates cannot substitute.",
      "L1 H0 / 1020 CR only at actual complete Celalen reception; zero deposit and no deadline.",
      "Actual capsules recovered: \(state?.captures.count ?? 0)/2; Cedamar care: \(care)/2.",
      "Actual boarding: \(state?.boarding != nil); original record aboard: \(state.map(NativeOriginalRescueJourney.recordCarried) ?? false).",
      "Destroyed, empty or unrelated capsules never produce survivors. Cancellation and loss pay no reward or clue.",
    ] + originalRescueQuote(action).issues
  }
  var originalRescueFactsForPage: [String] {
    guard let state = commander.nativePeople?.originalRescue else { return [] }
    return [
      state.owner.uuidString, state.operation.uuidString, String(state.captures.count),
      String(state.offers.count), String(state.replies.count), String(describing: state.boarding),
      String(describing: state.record?.operation), String(describing: state.terminalOperation),
    ] + commander.accommodation.cabinFacts
  }
}
