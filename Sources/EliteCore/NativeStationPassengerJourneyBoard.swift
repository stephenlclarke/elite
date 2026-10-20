import Foundation

enum NativeStationPassengerJourneyAction: String, Sendable, Equatable {
  case request, board, receive, cancel
  var title: String {
    switch self {
    case .request: "Mira Talen and Oren Vey / request passage replies"
    case .board: "Board both consenting original people"
    case .receive: "Renas reception / receive the same two people"
    case .cancel: "Avenor reception / cancel and release both people"
    }
  }
  var action: String {
    switch self {
    case .request: "Request replies"
    case .board: "Board both"
    case .receive: "Receive both"
    case .cancel: "Release both"
    }
  }
}

extension Game {
  var stationPassengerPack: ScriptPack? {
    scriptPacks.first {
      $0.manifest.stateID == NativeStationPassengerJourney.stateID
        && $0.digest == NativeStationPassengerJourney.digest
        && $0.manifest.stationJourney?.valid == true
    }
  }
  var stationPassengerRows: [ContractBoardRow] {
    guard stationPassengerPack != nil else { return [] }
    let state = commander.nativePeople?.stationJourney
    let actions: [NativeStationPassengerJourneyAction]
    if state?.terminalOperation != nil { return [] }
    if state?.boarding != nil {
      actions =
        contractStation == NativeStationPassengerJourney.source ? [.receive, .cancel] : [.receive]
    } else {
      guard contractStation == NativeStationPassengerJourney.source else { return [] }
      actions = state?.latestOffer == nil ? [.request] : [.request, .board]
    }
    return actions.map { action in
      let row = NativePeopleStationRow.journey(action)
      return .init(
        board: row.key, offer: nil, title: action.title,
        reason: stationPassengerQuote(action).issues.first, people: row)
    }
  }
  func stationPassengerQuote(_ action: NativeStationPassengerJourneyAction)
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
    if !commander.valid { issues.append("Current person or accommodation custody is invalid.") }
    if stationPassengerPack == nil {
      issues.append("The original cabin-journey content is unavailable.")
    }
    let source = commander.nativePeople?.stationJourney
    var members = source?.references ?? []
    if members.isEmpty, let owner = commander.equipmentOwnerID,
      let definition = stationPassengerPack?.manifest.stationJourney
    {
      members = definition.people.map {
        .station(.init(owner: owner, batch: definition.batch, person: $0.id))
      }
    }
    switch action {
    case .request:
      if contractStation != NativeStationPassengerJourney.source || source?.boarding != nil {
        issues.append("The original people must still be waiting with their Avenor custodian.")
      }
    case .board:
      if let reason = stationPassengerBoardingIssue(source) { issues.append(reason) }
    case .receive, .cancel:
      let required =
        action == .receive
        ? NativeStationPassengerJourney.destination : NativeStationPassengerJourney.source
      if contractStation != required {
        issues.append(
          action == .receive
            ? "Reach the agreed Renas main orbital receiver."
            : "Return both people to the actual Avenor custodian.")
      }
      guard let source, source.boarding != nil, source.terminalOperation == nil else {
        issues.append("Both original people must actually be aboard.")
        return .init(
          row: .journey(action), commander: commander, context: context, members: members,
          price: action == .receive ? NativeStationPassengerJourney.reward : 0,
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
      row: .journey(action), commander: commander, context: context, members: members,
      price: action == .receive ? NativeStationPassengerJourney.reward : 0, stock: members.count,
      epoch: nativeStationRuntimeEpoch, issues: issues)
  }
  private func stationPassengerBoardingIssue(_ source: NativeStationPassengerJourneyState?)
    -> String?
  {
    guard contractStation == NativeStationPassengerJourney.source,
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
    guard replies.count == 2, replies.allSatisfy({ $0.kind == .accept }),
      source.people.enumerated().allSatisfy({ index, person in
        replies[index].person == person.identity
          && replies[index].personRevision == person.currentRequest?.revision
          && person.currentRequest?.intent == .passage
      })
    else {
      return
        "Both original people must genuinely accept the current offer; refused or withdrawn replies board nobody."
    }
    guard commander.passengerFit?.allowed == true, offer.berths.count == 2,
      offer.berths.allSatisfy({ offered in
        commander.accommodation.fittedBerths.contains(where: {
          $0 == offered && !$0.use.used && $0.lifeSupportWorking && $0.humanoidCompatible
        })
      })
    else {
      return
        "Fit two actual empty compatible berths with working life support, then request fresh replies."
    }
    let systems = Universe.systemsIncludingPlugh(number: 0)
    guard systems[7].distance(to: systems[185]) <= commander.maximumJumpDistance else {
      return "Refuel or refit for the actual one-leg Renas passage."
    }
    return nil
  }

  mutating func applyStationPassengerAction(
    _ quote: NativePeopleStationQuote, action: NativeStationPassengerJourneyAction
  ) throws {
    let current = stationPassengerQuote(action)
    guard screen == .contracts, contractBoard.detail, contractBoard.selected?.people == quote.row,
      contractBoard.peopleQuote?.reviewToken == quote.reviewToken,
      quote.allowed, current.allowed, quote.members == current.members,
      quote.price == current.price, quote.resources == commander.contractQuoteResources,
      quote.epoch == nativeStationRuntimeEpoch, let context = quote.context,
      acceptsNativeMainStationArrivalContext(context), let pack = stationPassengerPack
    else {
      throw MissionPackError(
        "Source, person replies, carrier or receiver changed; review this actual action again.")
    }
    switch action {
    case .request: try requestStationPassengers(pack, context: context)
    case .board: try boardStationPassengers(pack, operation: quote.reviewToken)
    case .receive, .cancel:
      try transferStationPassengerJourney(
        members: quote.members, dock: context.receipt, operation: quote.reviewToken)
    }
    guard commander.valid else { throw SaveError.invalidCommander }
  }

  private mutating func requestStationPassengers(
    _ pack: ScriptPack, context: NativeMainStationArrivalContext
  ) throws {
    guard let owner = commander.equipmentOwnerID, let definition = pack.manifest.stationJourney,
      definition.valid, context.receipt.station.world == owner,
      context.receipt.station.system == SystemIdentity(galaxy: 0, system: 7)
    else { throw SaveError.invalidCommander }
    ensureScriptCalendar(origin: .newCommander)
    var custody = commander.nativePeople ?? .init(owner: owner)
    var source =
      custody.stationJourney
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
    guard source.definition == definition, source.digest == pack.digest, source.boarding == nil
    else { throw SaveError.invalidCommander }
    try NativeStationPassengerJourney.requestConsent(
      state: &source, game: self, destination: .init(galaxy: 0, system: 185))
    custody.stationJourney = source
    commander.savedNativePeopleCustody = custody
  }

  private mutating func boardStationPassengers(_ pack: ScriptPack, operation: UUID) throws {
    try OriginalServiceReservationPolicy.requireAvailableSlot(commander.scriptState)
    guard stationPassengerBoardingIssue(commander.nativePeople?.stationJourney) == nil,
      var custody = commander.nativePeople, var source = custody.stationJourney,
      let offer = source.latestOffer,
      custody.revision < UInt64(NativePeopleCustodyState.maximumPeople * 2),
      custody.admissions.count <= NativePeopleCustodyState.maximumPeople - 2
    else { throw SaveError.invalidCommander }
    let key = "passage-" + offer.id.uuidString.lowercased()
    let boardKey = pack.digest + "/cabin-journey/" + NativeStationPassengerJourney.source.key
    let offerID = ScriptIdentity.uuid("contract-offer-v1:\(boardKey):0:\(key)")
    let missionID = Self.contractJobIdentity(offerID)
    guard commander.scriptState.instances[missionID] == nil else {
      throw MissionPackError("These same people are already allocated to their passage.")
    }
    let nativeOffer = ScriptContractOffer(
      id: offerID, key: key, title: "Mira and Oren / L1 H0 / 610 CR / untimed",
      briefing:
        "Carry these same two consenting native station people from Avenor to Renas. Two fitted life-supported berths; no extra cargo or deposit. 610 CR only at actual complete reception.",
      destinationGalaxy: 0, destinationSystem: 185, reward: NativeStationPassengerJourney.reward,
      deposit: 0, failureReward: 0, refundOnFailure: false, duration: 0,
      parameters: NativeStationPassengerJourney.parameters(source, offer: offer))
    let job = ScriptContractJob(
      boardKey: boardKey, provider: pack.manifest.id, version: pack.manifest.version,
      digest: pack.digest, station: NativeStationPassengerJourney.source, boardRevision: 0,
      group: NativeStationPassengerJourney.stateID, offer: nativeOffer, clock: .local,
      acceptedAt: commander.scriptState.clock(.local), deadline: nil)
    var boardOffer = nativeOffer
    boardOffer.status = .accepted(missionID)
    commander.contracts.boards[boardKey] = .init(
      id: "cabin-journey", provider: pack.manifest.id,
      version: pack.manifest.version, digest: pack.digest, title: "Original native cabin journey",
      station: NativeStationPassengerJourney.source, revision: 0, seed: 0, clock: .local,
      period: 3600, group: NativeStationPassengerJourney.stateID, offers: [boardOffer])
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
      let reference = NativePersonReference.station(person.identity)
      guard !custody.admissions.contains(where: { $0.person == reference }),
        let slot = commander.accommodation.ownedBerths.firstIndex(where: {
          $0.id == boarding.berths[index]
        })
      else { throw SaveError.invalidCommander }
      commander.accommodation.ownedBerths[slot].use = .nativePerson(reference)
      custody.admissions.append(
        .init(
          person: reference, origin: .stationPassenger, operation: operation,
          actor: boarding.dock.actor, collector: boarding.collector, owner: source.owner,
          hull: boarding.carrier,
          tool: boarding.berths[index], inventoryRevision: boarding.inventoryRevision,
          physicalTime: boarding.physicalTime, epoch: boarding.epoch, revision: custody.revision))
    }
    source.boarding = boarding
    custody.stationJourney = source
    commander.savedNativePeopleCustody = custody
    var mission = ScriptInstance(
      id: missionID, definition: NativeStationPassengerJourney.stateID,
      version: pack.manifest.version, digest: pack.digest)
    mission.contract = job
    mission.milestones = [0]
    commander.scriptState.instances[missionID] = mission
    emitScriptEvent("mission.accepted", only: missionID)
  }

  /// Called inside the existing native care/loss candidate after its real transfer receipt exists.
  mutating func closeStationPassengerTransfer(_ operation: UUID) throws {
    guard var custody = commander.nativePeople, var source = custody.stationJourney,
      let boarding = source.boarding,
      let transfer = custody.transfers.first(where: { $0.operation == operation })
    else { return }
    let members = transfer.members.filter {
      $0.station?.batch == NativeStationPassengerJourney.batch
    }
    if members.isEmpty { return }
    guard source.terminalOperation == nil, members == source.references,
      var mission = commander.scriptState.instances[boarding.mission], mission.outcome == .active,
      commander.scriptState.nextEvent < UInt64.max - 1, mission.revision < UInt64.max
    else { throw SaveError.invalidCommander }
    let outcome: ScriptOutcome
    switch transfer.kind {
    case .care:
      guard let dock = transfer.dock else { throw SaveError.invalidCommander }
      if NativeStationPassengerJourney.destinationMatches(dock) {
        outcome = .complete
      } else if NativeStationPassengerJourney.sourceMatches(dock) {
        outcome = .abandoned
      } else {
        throw MissionPackError(
          "Only the agreed receiver or actual original custodian can receive these people.")
      }
    case .loss, .escape: outcome = .failed
    case .sale: throw MissionPackError("A consenting station passenger cannot be sold.")
    }
    let previous = mission
    let cause = scriptEventContext(mission)
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
    custody.stationJourney = source
    candidate.savedNativePeopleCustody = custody
    for index in candidate.accommodation.ownedBerths.indices {
      if case .nativePerson(let person) = candidate.accommodation.ownedBerths[index].use,
        members.contains(person)
      {
        candidate.accommodation.ownedBerths[index].use = .empty
      }
    }
    commander = candidate
    mission.completionReceipt = .init(
      instance: mission.id, definition: mission.definition,
      version: mission.version, digest: mission.digest, outcome: outcome, sequence: sequence,
      causeKind: "mission.receipted", cause: cause, committed: scriptEventContext(mission),
      revision: mission.revision, milestones: mission.milestones.sorted(), destroyedEncounters: [],
      deliveredParties: [], returnedEquipment: [],
      settlementAmount: mission.contract?.settlementAmount, choices: nil)
    commander.scriptState.instances[mission.id] = mission
    try awardScriptClue(previous: previous, next: mission, trust: .production)
    if let receipt = mission.completionReceipt { try enqueueScriptCompletion(receipt) }
  }

  var stationPassengerFacts: [String] {
    guard stationPassengerPack != nil || commander.nativePeople?.stationJourney != nil else {
      return []
    }
    var facts = [nativeStationRuntimeEpoch.uuidString]
    if let source = commander.nativePeople?.stationJourney {
      facts += source.people.map { $0.identity.key }
      facts += [
        String(source.offers.count), String(source.replies.count),
        String(describing: source.boarding?.mission), String(describing: source.terminalOperation),
      ]
    }
    facts += commander.accommodation.fittedBerths.map {
      "\($0.id):\($0.use):\($0.lifeSupportWorking):\($0.humanoidCompatible)"
    }
    return facts
  }
  func stationPassengerDetail(_ action: NativeStationPassengerJourneyAction) -> [String] {
    let quote = contractBoard.peopleQuote ?? stationPassengerQuote(action)
    var lines = [
      "Mira Talen and Oren Vey / original native Avenor people",
      "Agreed destination: Renas main orbital; actual L1 H0, 610 CR, untimed.",
      "Two actual free compatible life-supported berths; no additional cargo or deposit.",
      "Requesting passage is not consent or boarding. Both native replies and both actual berths are required.",
      "Back changes no person, request, cabin, cash or clue.",
    ]
    if let source = commander.nativePeople?.stationJourney, let offer = source.latestOffer {
      lines += source.latestReplies(for: offer).map {
        "\($0.person.person): native \($0.kind.rawValue) / request \($0.personRevision)."
      }
      if source.boarding != nil {
        lines.append(
          "The same two original native references are actually aboard until real care reception or recorded loss."
        )
      }
    }
    return lines + quote.issues
  }
}
