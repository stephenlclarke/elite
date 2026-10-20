import Foundation

enum NativeOriginalEvacuationAction: String, Sendable, Equatable {
  case request, board, receive, cancel
  var title: String {
    switch self {
    case .request: "Sera Venn, Tavi Noll, Eren Pell and Mara Quill / request passage replies"
    case .board: "Board all four consenting original people"
    case .receive: "Renas reception / receive the same four people"
    case .cancel: "Avenor reception / cancel and release all four people"
    }
  }
  var action: String {
    switch self {
    case .request: "Request replies"
    case .board: "Board all four"
    case .receive: "Receive all four"
    case .cancel: "Return all four"
    }
  }
}

extension Game {
  var originalEvacuationPack: ScriptPack? {
    scriptPacks.first {
      $0.manifest.stateID == NativeOriginalEvacuation.stateID
        && $0.digest == NativeOriginalEvacuation.digest
        && $0.manifest.orbitalEvacuation?.valid == true
    }
  }
  var originalEvacuationRows: [ContractBoardRow] {
    guard originalEvacuationPack != nil else { return [] }
    let state = commander.nativePeople?.orbitalEvacuation
    let actions: [NativeOriginalEvacuationAction]
    if state?.terminalOperation != nil || state?.withdrawal != nil { return [] }
    if state?.boarding != nil {
      actions =
        contractStation == NativeOriginalEvacuation.source ? [.receive, .cancel] : [.receive]
    } else {
      guard contractStation == NativeOriginalEvacuation.source else { return [] }
      actions = state?.latestOffer == nil ? [.request] : [.request, .board, .cancel]
    }
    return actions.map { action in
      let row = NativePeopleStationRow.evacuation(action)
      return .init(
        board: row.key, offer: nil, title: action.title,
        reason: originalEvacuationQuote(action).issues.first, people: row)
    }
  }
  @inline(never)
  func originalEvacuationQuote(_ action: NativeOriginalEvacuationAction)
    -> NativePeopleStationQuote
  {
    var issues: [String] = []
    var context: NativeMainStationArrivalContext?
    if case .living(let destination) = nativeOriginalMainStationDestination {
      context = nativeMainStationArrivalContext(for: destination.identity)
    }
    if context == nil {
      issues.append("Use the actual living main orbital station and resume play.")
    }
    if !scriptDurabilityAvailable { issues.append("Choose a writable commander save.") }
    if !Self.originalEvacuationCommanderIsValid(self) {
      issues.append("Current person or accommodation custody is invalid.")
    }
    if originalEvacuationPack == nil {
      issues.append("The original orbital-evacuation content is unavailable.")
    }
    return originalEvacuationActionQuote(action, context: context, initialIssues: issues)
  }
  @inline(never)
  private func originalEvacuationActionQuote(
    _ action: NativeOriginalEvacuationAction, context: NativeMainStationArrivalContext?,
    initialIssues: [String]
  ) -> NativePeopleStationQuote {
    var issues = initialIssues
    let source = commander.nativePeople?.orbitalEvacuation
    var members = source?.references ?? []
    if members.isEmpty, let owner = commander.equipmentOwnerID,
      let definition = originalEvacuationPack?.manifest.orbitalEvacuation
    {
      members = definition.people.map {
        .evacuation(.init(owner: owner, batch: definition.batch, person: $0.id))
      }
    }
    switch action {
    case .request:
      if contractStation != NativeOriginalEvacuation.source || source?.boarding != nil
        || source?.withdrawal != nil
      {
        issues.append("The original people must still be waiting with their Avenor custodian.")
      }
    case .board:
      if let reason = originalEvacuationBoardingIssue(source) { issues.append(reason) }
    case .receive, .cancel:
      if action == .cancel, let source, source.boarding == nil, source.withdrawal == nil,
        contractStation == NativeOriginalEvacuation.source
      {
        break
      }
      let required =
        action == .receive
        ? NativeOriginalEvacuation.destination : NativeOriginalEvacuation.source
      if contractStation != required {
        issues.append(
          action == .receive
            ? "Reach the agreed Renas main orbital receiver."
            : "Return all four people to the actual Avenor custodian.")
      }
      guard let source, source.boarding != nil, source.terminalOperation == nil else {
        issues.append("All four original people must actually be aboard.")
        return .init(
          row: .evacuation(action), commander: commander, context: context, members: members,
          price: action == .receive ? NativeOriginalEvacuation.reward : 0,
          stock: members.count,
          epoch: nativeStationRuntimeEpoch, issues: issues)
      }
      if !source.references.allSatisfy({ person in
        commander.nativePeople?.held.contains(where: { $0.person == person }) == true
      }) {
        issues.append("A missing, dead or previously released individual cannot be replaced.")
      }
    }
    return .init(
      row: .evacuation(action), commander: commander, context: context, members: members,
      price: action == .receive ? NativeOriginalEvacuation.reward : 0, stock: members.count,
      epoch: nativeStationRuntimeEpoch, issues: issues)
  }
  private func originalEvacuationBoardingIssue(_ source: NativeOriginalEvacuationState?)
    -> String?
  {
    guard contractStation == NativeOriginalEvacuation.source,
      nativeMainStationDockEvidenceIsCurrent,
      let source, source.boarding == nil, let offer = source.latestOffer,
      offer.dock == commander.nativeStations?.currentMainDock,
      offer.carrier == commander.hullInstanceID,
      offer.epoch == nativeStationRuntimeEpoch,
      offer.inventoryRevision == commander.equipmentInventory?.revision,
      offer.path == [7, 185], offer.destination == SystemIdentity(galaxy: 0, system: 185)
    else { return "Request fresh native replies at the actual Avenor source." }
    if OriginalServiceReservationPolicy.activeCount(commander.scriptState)
      >= OriginalServiceReservationPolicy.maximumActive
    {
      return "Three Original contracts or services are already active."
    }
    let replies = source.latestReplies(for: offer)
    guard replies.count == 4, replies.allSatisfy({ $0.kind == .accept }),
      source.people.enumerated().allSatisfy({ index, person in
        replies[index].person == person.identity
          && replies[index].personRevision == person.currentRequest?.revision
          && person.currentRequest?.intent == .passage
      })
    else {
      return
        "All four original people must genuinely accept the current offer; refused or withdrawn replies board nobody."
    }
    guard commander.passengerFit?.allowed == true, offer.berths.count == 4,
      offer.berths.allSatisfy({ offered in
        commander.accommodation.fittedBerths.contains(where: {
          $0 == offered && !$0.use.used && $0.lifeSupportWorking && $0.humanoidCompatible
        })
      })
    else {
      return
        "Fit four actual empty compatible berths with working life support, then request fresh replies."
    }
    let systems = Universe.systemsIncludingPlugh(number: 0)
    guard systems[7].distance(to: systems[185]) <= commander.maximumJumpDistance else {
      return "Refuel or refit for the actual one-leg Renas passage."
    }
    return nil
  }

  @inline(never)
  mutating func confirmOriginalEvacuationAction(
    _ quote: NativePeopleStationQuote, action: NativeOriginalEvacuationAction
  ) throws {
    try validateOriginalEvacuationAction(quote, action: action)
    let candidate = try originalEvacuationCandidate(quote, action: action)
    guard Self.originalEvacuationCommanderIsValid(candidate) else {
      throw SaveError.invalidCommander
    }
    self = candidate
  }
  @inline(never)
  private static func originalEvacuationCommanderIsValid(_ game: borrowing Game) -> Bool {
    game.withReadOnlyCommander { $0.valid }
  }
  @inline(never)
  private func validateOriginalEvacuationAction(
    _ quote: NativePeopleStationQuote, action: NativeOriginalEvacuationAction
  ) throws {
    let current = originalEvacuationQuote(action)
    guard screen == .contracts, contractBoard.detail, contractBoard.selected?.people == quote.row,
      contractBoard.peopleQuote?.reviewToken == quote.reviewToken,
      quote.allowed, current.allowed, quote.members == current.members,
      quote.price == current.price, quote.resources == commander.contractQuoteResources,
      quote.epoch == nativeStationRuntimeEpoch, let context = quote.context,
      acceptsNativeMainStationArrivalContext(context), originalEvacuationPack != nil
    else {
      throw MissionPackError(
        "Source, person replies, carrier or receiver changed; review this actual action again.")
    }
  }
  @inline(never)
  private func originalEvacuationCandidate(
    _ quote: NativePeopleStationQuote, action: NativeOriginalEvacuationAction
  ) throws -> Game {
    var candidate = self
    try candidate.applyOriginalEvacuationMutation(quote, action: action)
    return candidate
  }
  @inline(never)
  private mutating func applyOriginalEvacuationMutation(
    _ quote: NativePeopleStationQuote, action: NativeOriginalEvacuationAction
  ) throws {
    guard let pack = originalEvacuationPack, let context = quote.context else {
      throw SaveError.invalidCommander
    }
    switch action {
    case .request: try requestOriginalEvacuations(pack, context: context)
    case .board:
      let missionID = try boardOriginalEvacuations(pack, operation: quote.reviewToken)
      emitScriptEvent("mission.accepted", only: missionID)
    case .cancel where commander.nativePeople?.orbitalEvacuation?.boarding == nil:
      try withdrawOriginalEvacuation(operation: quote.reviewToken, dock: context.receipt)
    case .receive, .cancel:
      try transferOriginalEvacuationJourney(
        members: quote.members, dock: context.receipt, operation: quote.reviewToken)
    }
  }

  @inline(never)
  private mutating func withdrawOriginalEvacuation(
    operation: UUID, dock: NativeMainStationDockReceipt
  ) throws {
    guard var custody = commander.nativePeople, var source = custody.orbitalEvacuation,
      source.boarding == nil, source.withdrawal == nil,
      dock == commander.nativeStations?.currentMainDock, source.source == dock.station,
      source.people.allSatisfy({ $0.travelRequests.count < 64 })
    else { throw SaveError.invalidCommander }
    for i in source.people.indices {
      source.people[i].travelRequests.append(
        .init(
          revision: UInt64(source.people[i].travelRequests.count + 1),
          destination: .init(galaxy: 0, system: 185), intent: .withdrawn))
    }
    try NativeOriginalEvacuation.requestConsent(
      state: &source, game: self, destination: .init(galaxy: 0, system: 185))
    source.withdrawal = .init(
      operation: operation, dock: dock, epoch: nativeStationRuntimeEpoch,
      physicalTime: commander.flightSimulation.physicalTime)
    custody.orbitalEvacuation = source
    commander.savedNativePeopleCustody = custody
  }

  @inline(never)
  private mutating func requestOriginalEvacuations(
    _ pack: ScriptPack, context: NativeMainStationArrivalContext
  ) throws {
    var source = try prepareOriginalEvacuationConsent(pack, context: context)
    try NativeOriginalEvacuation.requestConsent(
      state: &source, game: self, destination: .init(galaxy: 0, system: 185))
    publishOriginalEvacuationConsent(source)
  }

  /// Retire original roster preparation before the native consent walk reserves its values.
  @inline(never)
  private mutating func prepareOriginalEvacuationConsent(
    _ pack: ScriptPack, context: NativeMainStationArrivalContext
  ) throws -> NativeOriginalEvacuationState {
    guard let owner = withReadOnlyCommander({ $0.equipmentOwnerID }),
      let definition = pack.manifest.orbitalEvacuation,
      definition.valid, context.receipt.station.world == owner,
      context.receipt.station.system == SystemIdentity(galaxy: 0, system: 7)
    else { throw SaveError.invalidCommander }
    ensureScriptCalendar(origin: .newCommander)
    let source =
      withReadOnlyCommander { $0.nativePeople?.orbitalEvacuation }
      ?? .init(
        owner: owner, definition: definition,
        version: pack.manifest.version, digest: pack.digest, source: context.receipt.station,
        registration: context.receipt, stationActor: context.receipt.actor,
        people: definition.people.map { person in
          .init(
            identity: .init(owner: owner, batch: definition.batch, person: person.id),
            name: person.name,
            custodian: context.receipt.station,
            travelRequests: [
              .init(revision: 1, destination: .init(galaxy: 0, system: 185), intent: .passage)
            ])
        })
    guard source.definition == definition, source.digest == pack.digest, source.boarding == nil,
      source.withdrawal == nil
    else { throw SaveError.invalidCommander }
    return source
  }

  /// Copy the custody value only after the native consent walk has completed.
  @inline(never)
  private mutating func publishOriginalEvacuationConsent(
    _ source: borrowing NativeOriginalEvacuationState
  ) {
    let owner = source.owner
    var custody = withReadOnlyCommander { $0.nativePeople } ?? .init(owner: owner)
    custody.orbitalEvacuation = copy source
    commander.savedNativePeopleCustody = custody
  }

  private mutating func boardOriginalEvacuations(_ pack: ScriptPack, operation: UUID) throws -> UUID
  {
    try OriginalServiceReservationPolicy.requireAvailableSlot(commander.scriptState)
    guard originalEvacuationBoardingIssue(commander.nativePeople?.orbitalEvacuation) == nil,
      var custody = commander.nativePeople, var source = custody.orbitalEvacuation,
      let offer = source.latestOffer,
      custody.revision < UInt64(NativePeopleCustodyState.maximumPeople * 2),
      custody.admissions.count <= NativePeopleCustodyState.maximumPeople - 4
    else { throw SaveError.invalidCommander }
    let key = "passage-" + offer.id.uuidString.lowercased()
    let boardKey = pack.digest + "/orbital-evacuation/" + NativeOriginalEvacuation.source.key
    let offerID = ScriptIdentity.uuid("contract-offer-v1:\(boardKey):0:\(key)")
    let missionID = Self.contractJobIdentity(offerID)
    guard commander.scriptState.instances[missionID] == nil else {
      throw MissionPackError("These same people are already allocated to their passage.")
    }
    let nativeOffer = ScriptContractOffer(
      id: offerID, key: key, title: "Four original survivors / L1 H0 / 1065 CR / untimed",
      briefing:
        "Carry these same four consenting native station people from Avenor to Renas. Four fitted life-supported berths; no extra cargo or deposit. 1065 CR only at actual complete reception.",
      destinationGalaxy: 0, destinationSystem: 185, reward: NativeOriginalEvacuation.reward,
      deposit: 0, failureReward: 0, refundOnFailure: false, duration: 0,
      parameters: NativeOriginalEvacuation.parameters(source, offer: offer))
    let job = ScriptContractJob(
      boardKey: boardKey, provider: pack.manifest.id, version: pack.manifest.version,
      digest: pack.digest, station: NativeOriginalEvacuation.source, boardRevision: 0,
      group: NativeOriginalEvacuation.stateID, offer: nativeOffer, clock: .local,
      acceptedAt: commander.scriptState.clock(.local), deadline: nil)
    var boardOffer = nativeOffer
    boardOffer.status = .accepted(missionID)
    commander.contracts.boards[boardKey] = .init(
      id: "orbital-evacuation", provider: pack.manifest.id,
      version: pack.manifest.version, digest: pack.digest, title: "Original native cabin journey",
      station: NativeOriginalEvacuation.source, revision: 0, seed: 0, clock: .local,
      period: 3600, group: NativeOriginalEvacuation.stateID, offers: [boardOffer])
    let replies = source.latestReplies(for: offer)
    let ordinals = try replies.map { reply -> Int in
      guard let index = source.replies.firstIndex(of: reply) else {
        throw SaveError.invalidCommander
      }
      return index
    }
    let boarding = NativeStationPassengerBoarding(
      mission: missionID, offer: offer.id, operation: operation,
      dock: offer.dock, collector: offer.collector, carrier: offer.carrier,
      inventoryRevision: offer.inventoryRevision, berths: offer.berths.map(\.id),
      replyOrdinals: ordinals,
      physicalTime: commander.flightSimulation.physicalTime, epoch: nativeStationRuntimeEpoch)
    custody.revision += 1
    for (index, person) in source.people.enumerated() {
      let reference = NativePersonReference.evacuation(person.identity)
      guard !custody.admissions.contains(where: { $0.person == reference }),
        let slot = commander.accommodation.ownedBerths.firstIndex(where: {
          $0.id == boarding.berths[index]
        })
      else { throw SaveError.invalidCommander }
      commander.accommodation.ownedBerths[slot].use = .nativePerson(reference)
      custody.admissions.append(
        .init(
          person: reference, origin: .orbitalEvacuee, operation: operation,
          actor: boarding.dock.actor, collector: boarding.collector, owner: source.owner,
          hull: boarding.carrier,
          tool: boarding.berths[index], inventoryRevision: boarding.inventoryRevision,
          physicalTime: boarding.physicalTime, epoch: boarding.epoch, revision: custody.revision))
    }
    source.boarding = boarding
    custody.orbitalEvacuation = source
    commander.savedNativePeopleCustody = custody
    var mission = ScriptInstance(
      id: missionID, definition: NativeOriginalEvacuation.stateID,
      version: pack.manifest.version, digest: pack.digest)
    mission.contract = job
    mission.milestones = [0]
    commander.scriptState.instances[missionID] = mission
    return missionID
  }

  /// Read-only outcome and event context return before owning custody/mission mutation values.
  @inline(never)
  mutating func closeOriginalEvacuationTransfer(_ operation: UUID) throws {
    guard let result = try originalEvacuationTransferOutcome(operation) else { return }
    let cause = Self.scriptEventContext(in: self, revision: result.1)
    let (previous, mission, sequence) = try stageOriginalEvacuationFinish(
      operation, outcome: result.0)
    let committed = Self.scriptEventContext(in: self, revision: mission.revision)
    try publishOriginalEvacuationCompletion(
      previous: previous, next: mission, sequence: sequence, cause: cause, committed: committed)
  }
  @inline(never)
  private func originalEvacuationTransferOutcome(_ operation: UUID) throws -> (
    ScriptOutcome, UInt64
  )? {
    guard let custody = commander.nativePeople, let source = custody.orbitalEvacuation,
      let boarding = source.boarding,
      let transfer = custody.transfers.first(where: { $0.operation == operation })
    else { return nil }
    let members = transfer.members.filter { $0.evacuation != nil }
    if members.isEmpty { return nil }
    guard source.terminalOperation == nil, members == source.references,
      let mission = commander.scriptState.instances[boarding.mission], mission.outcome == .active,
      commander.scriptState.nextEvent < UInt64.max - 1, mission.revision < UInt64.max
    else { throw SaveError.invalidCommander }
    let outcome: ScriptOutcome
    switch transfer.kind {
    case .care:
      guard let dock = transfer.dock else { throw SaveError.invalidCommander }
      if NativeOriginalEvacuation.destinationMatches(dock) {
        outcome = .complete
      } else if NativeOriginalEvacuation.sourceMatches(dock) {
        outcome = .abandoned
      } else {
        throw MissionPackError("Use the agreed Renas receiver or actual Avenor return.")
      }
    case .loss, .escape: outcome = .failed
    case .sale: throw MissionPackError("These consenting people cannot be sold.")
    }
    return (outcome, mission.revision)
  }
  @inline(never)
  private mutating func stageOriginalEvacuationFinish(_ operation: UUID, outcome: ScriptOutcome)
    throws -> (ScriptInstance, ScriptInstance, UInt64)
  {
    guard var custody = commander.nativePeople, var source = custody.orbitalEvacuation,
      let boarding = source.boarding,
      var mission = commander.scriptState.instances[boarding.mission],
      let transfer = custody.transfers.first(where: { $0.operation == operation })
    else { throw SaveError.invalidCommander }
    let members = transfer.members.filter { $0.evacuation != nil }
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
    source.terminalOperation = operation
    custody.orbitalEvacuation = source
    candidate.savedNativePeopleCustody = custody
    for index in candidate.accommodation.ownedBerths.indices {
      if case .nativePerson(let person) = candidate.accommodation.ownedBerths[index].use,
        members.contains(person)
      {
        candidate.accommodation.ownedBerths[index].use = .empty
      }
    }
    commander = candidate
    return (previous, mission, sequence)
  }
  @inline(never)
  private mutating func publishOriginalEvacuationCompletion(
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
      settlementAmount: mission.contract?.settlementAmount, choices: nil)
    commander.scriptState.instances[mission.id] = mission
    try awardScriptClue(previous: copy previous, next: mission, trust: .production)
    if let receipt = mission.completionReceipt { try enqueueScriptCompletion(receipt) }
  }

  var originalEvacuationFacts: [String] {
    guard originalEvacuationPack != nil || commander.nativePeople?.orbitalEvacuation != nil else {
      return []
    }
    var facts = [nativeStationRuntimeEpoch.uuidString]
    if let source = commander.nativePeople?.orbitalEvacuation {
      facts += source.people.map { $0.identity.key }
      facts += [
        String(source.offers.count), String(source.replies.count),
        String(describing: source.withdrawal),
        String(describing: source.boarding?.mission), String(describing: source.terminalOperation),
      ]
    }
    facts += commander.accommodation.fittedBerths.map {
      "\($0.id):\($0.use):\($0.lifeSupportWorking):\($0.humanoidCompatible)"
    }
    return facts
  }
  func originalEvacuationDetail(_ action: NativeOriginalEvacuationAction) -> [String] {
    let quote = contractBoard.peopleQuote ?? originalEvacuationQuote(action)
    var lines = [
      "Sera Venn, Tavi Noll, Eren Pell and Mara Quill / original native Avenor people",
      "Agreed destination: Renas main orbital; actual L1 H0, 1065 CR, untimed.",
      "Four actual free compatible life-supported berths; no additional cargo or deposit.",
      "Requesting passage is not consent or boarding. All four native replies and all four actual berths are required.",
      "Back changes no person, request, cabin, cash or clue.",
    ]
    if let source = commander.nativePeople?.orbitalEvacuation, let offer = source.latestOffer {
      lines += source.latestReplies(for: offer).map {
        "\($0.person.person): native \($0.kind.rawValue) / request \($0.personRevision)."
      }
      if source.boarding != nil {
        lines.append(
          "The same four original native references are actually aboard until real care reception or recorded loss."
        )
      }
    }
    return lines + quote.issues
  }
}
