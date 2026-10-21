import Foundation

enum NativeOrbitalOutlookJourneyAction: String, Sendable, Equatable {
  case request, board, receive, cancel
  var title: String {
    switch self {
    case .request: "Lysa Renn and Tovan Hale / request passage replies"
    case .board: "Board both consenting original people"
    case .receive: "Avenor return reception / receive both after three views"
    case .cancel: "Avenor care / cancel this outlook journey"
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
  var orbitalOutlookPack: ScriptPack? {
    scriptPacks.first {
      $0.manifest.stateID == NativeOrbitalOutlookJourney.stateID
        && $0.digest == NativeOrbitalOutlookJourney.digest
        && $0.manifest.orbitalOutlook?.valid == true
    }
  }
  var orbitalOutlookRows: [ContractBoardRow] {
    guard orbitalOutlookPack != nil else { return [] }
    let state = commander.nativePeople?.outlookJourney
    let actions: [NativeOrbitalOutlookJourneyAction]
    if state?.terminalOperation != nil { return [] }
    if state?.boarding != nil {
      actions =
        contractStation == NativeOrbitalOutlookJourney.source ? [.receive, .cancel] : [.receive]
    } else {
      guard contractStation == NativeOrbitalOutlookJourney.source else { return [] }
      actions = state?.latestOffer == nil ? [.request] : [.request, .board]
    }
    return actions.map { action in
      let row = NativePeopleStationRow.outlook(action)
      return .init(
        board: row.key, offer: nil, title: action.title,
        reason: orbitalOutlookQuote(action).issues.first, people: row)
    }
  }
  func orbitalOutlookQuote(_ action: NativeOrbitalOutlookJourneyAction)
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
    if orbitalOutlookPack == nil {
      issues.append("The original orbital-outlook content is unavailable.")
    }
    let source = commander.nativePeople?.outlookJourney
    var members = source?.references ?? []
    if members.isEmpty, let owner = commander.equipmentOwnerID,
      let definition = orbitalOutlookPack?.manifest.orbitalOutlook
    {
      members = definition.people.map {
        .station(.init(owner: owner, batch: definition.batch, person: $0.id))
      }
    }
    switch action {
    case .request:
      if contractStation != NativeOrbitalOutlookJourney.source || source?.boarding != nil {
        issues.append("The original people must still be waiting with their Avenor custodian.")
      }
    case .board:
      if let reason = orbitalOutlookBoardingIssue(source) { issues.append(reason) }
    case .receive, .cancel:
      let required =
        action == .receive
        ? NativeOrbitalOutlookJourney.destination : NativeOrbitalOutlookJourney.source
      if contractStation != required {
        issues.append(
          action == .receive
            ? "Return to the agreed Avenor main orbital receiver."
            : "Return both people to the actual Avenor custodian.")
      }
      guard let source, source.boarding != nil, source.terminalOperation == nil else {
        issues.append("Both original people must actually be aboard.")
        return .init(
          row: .outlook(action), commander: commander, context: context, members: members,
          price: action == .receive ? NativeOrbitalOutlookJourney.reward : 0,
          stock: members.count,
          epoch: nativeStationRuntimeEpoch, issues: issues)
      }
      if action == .receive, let dock = context?.receipt,
        !NativeOrbitalOutlookJourney.returnReady(source, dock: dock)
      {
        issues.append("Complete all three ordered Renas views, then actually return to Avenor.")
      }
      if action == .cancel, let dock = context?.receipt,
        NativeOrbitalOutlookJourney.returnReady(source, dock: dock)
      {
        issues.append("The completed return is ready for reception; review Receive both.")
      }
      if !source.references.allSatisfy({ person in
        commander.nativePeople?.held.contains(where: { $0.person == person }) == true
      }) {
        issues.append("A missing, dead or previously released individual cannot be replaced.")
      }
    }
    return .init(
      row: .outlook(action), commander: commander, context: context, members: members,
      price: action == .receive ? NativeOrbitalOutlookJourney.reward : 0, stock: members.count,
      epoch: nativeStationRuntimeEpoch, issues: issues)
  }
  private func orbitalOutlookBoardingIssue(_ source: NativeOrbitalOutlookJourneyState?)
    -> String?
  {
    guard contractStation == NativeOrbitalOutlookJourney.source,
      nativeMainStationDockEvidenceIsCurrent,
      let source, source.boarding == nil, let offer = source.latestOffer,
      offer.dock == commander.nativeStations?.currentMainDock,
      offer.carrier == commander.hullInstanceID,
      offer.epoch == nativeStationRuntimeEpoch,
      offer.inventoryRevision == commander.equipmentInventory?.revision,
      offer.path == [7, 185, 7], offer.itinerary == NativeOrbitalOutlookJourney.views,
      offer.destination == SystemIdentity(galaxy: 0, system: 7)
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
        commander.accommodation.availablePlaces(privateCabin: true).contains(where: {
          $0 == offered && !$0.use.used && $0.lifeSupportWorking && $0.humanoidCompatible
        })
      })
    else {
      return
        "Fit two separate empty awake-compatible cabins with working life support, then request fresh replies."
    }
    let systems = Universe.systemsIncludingPlugh(number: 0)
    guard systems[7].distance(to: systems[185]) <= commander.maximumJumpDistance else {
      return "Refuel or refit for the actual one-leg Renas passage."
    }
    return nil
  }

  mutating func applyOrbitalOutlookAction(
    _ quote: NativePeopleStationQuote, action: NativeOrbitalOutlookJourneyAction
  ) throws {
    let current = orbitalOutlookQuote(action)
    guard screen == .contracts, contractBoard.detail, contractBoard.selected?.people == quote.row,
      contractBoard.peopleQuote?.reviewToken == quote.reviewToken,
      quote.allowed, current.allowed, quote.members == current.members,
      quote.price == current.price, quote.resources == commander.contractQuoteResources,
      quote.epoch == nativeStationRuntimeEpoch, let context = quote.context,
      acceptsNativeMainStationArrivalContext(context), let pack = orbitalOutlookPack
    else {
      throw MissionPackError(
        "Source, person replies, carrier or receiver changed; review this actual action again.")
    }
    switch action {
    case .request: try requestOrbitalOutlooks(pack, context: context)
    case .board: try boardOrbitalOutlooks(pack, operation: quote.reviewToken)
    case .receive, .cancel:
      try transferOrbitalOutlookJourney(
        members: quote.members, dock: context.receipt, operation: quote.reviewToken,
        receive: action == .receive)
    }
    guard commander.valid else { throw SaveError.invalidCommander }
  }

  private mutating func requestOrbitalOutlooks(
    _ pack: ScriptPack, context: NativeMainStationArrivalContext
  ) throws {
    guard let owner = commander.equipmentOwnerID, let definition = pack.manifest.orbitalOutlook,
      definition.valid, context.receipt.station.world == owner,
      context.receipt.station.system == SystemIdentity(galaxy: 0, system: 7)
    else { throw SaveError.invalidCommander }
    ensureScriptCalendar(origin: .newCommander)
    var custody = commander.nativePeople ?? .init(owner: owner)
    var source =
      custody.outlookJourney
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
              .init(
                revision: 1, destination: .init(galaxy: 0, system: 7),
                itinerary: definition.itinerary, intent: .passage)
            ])
        })
    guard source.definition == definition, source.digest == pack.digest, source.boarding == nil
    else { throw SaveError.invalidCommander }
    try NativeOrbitalOutlookJourney.requestConsent(
      state: &source, game: self, destination: .init(galaxy: 0, system: 7))
    custody.outlookJourney = source
    commander.savedNativePeopleCustody = custody
  }

  private mutating func boardOrbitalOutlooks(_ pack: ScriptPack, operation: UUID) throws {
    try OriginalServiceReservationPolicy.requireAvailableSlot(commander.scriptState)
    guard orbitalOutlookBoardingIssue(commander.nativePeople?.outlookJourney) == nil,
      var custody = commander.nativePeople, var source = custody.outlookJourney,
      let offer = source.latestOffer,
      custody.revision < UInt64(NativePeopleCustodyState.maximumPeople * 2),
      custody.admissions.count <= NativePeopleCustodyState.maximumPeople - 2
    else { throw SaveError.invalidCommander }
    let key = "passage-" + offer.id.uuidString.lowercased()
    let boardKey = pack.digest + "/orbital-outlook/" + NativeOrbitalOutlookJourney.source.key
    let offerID = ScriptIdentity.uuid("contract-offer-v1:\(boardKey):0:\(key)")
    let missionID = Self.contractJobIdentity(offerID)
    guard commander.scriptState.instances[missionID] == nil else {
      throw MissionPackError("These same people are already allocated to their passage.")
    }
    let nativeOffer = ScriptContractOffer(
      id: offerID, key: key, title: "Lysa and Tovan / L2 H0 / 870 CR / untimed",
      briefing:
        "Carry these same two consenting native station people from Avenor through three ordered Renas views and back to Avenor. Two fitted life-supported berths; no extra cargo or deposit. 870 CR only at actual complete reception.",
      destinationGalaxy: 0, destinationSystem: 7, reward: NativeOrbitalOutlookJourney.reward,
      deposit: 0, failureReward: 0, refundOnFailure: false, duration: 0,
      parameters: NativeOrbitalOutlookJourney.parameters(source, offer: offer))
    let job = ScriptContractJob(
      boardKey: boardKey, provider: pack.manifest.id, version: pack.manifest.version,
      digest: pack.digest, station: NativeOrbitalOutlookJourney.source, boardRevision: 0,
      group: NativeOrbitalOutlookJourney.stateID, offer: nativeOffer, clock: .local,
      acceptedAt: commander.scriptState.clock(.local), deadline: nil)
    var boardOffer = nativeOffer
    boardOffer.status = .accepted(missionID)
    commander.contracts.boards[boardKey] = .init(
      id: "orbital-outlook", provider: pack.manifest.id,
      version: pack.manifest.version, digest: pack.digest, title: "Original native cabin journey",
      station: NativeOrbitalOutlookJourney.source, revision: 0, seed: 0, clock: .local,
      period: 3600, group: NativeOrbitalOutlookJourney.stateID, offers: [boardOffer])
    let replies = source.latestReplies(for: offer)
    let ordinals = try replies.map { reply -> Int in
      guard let index = source.replies.firstIndex(of: reply) else {
        throw SaveError.invalidCommander
      }
      return index
    }
    let boarding = NativeOrbitalOutlookBoarding(
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
      commander.accommodation.ownedBerths[slot].mode = .awake
      commander.accommodation.ownedBerths[slot].privateCabin = true
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
    custody.outlookJourney = source
    commander.savedNativePeopleCustody = custody
    var mission = ScriptInstance(
      id: missionID, definition: NativeOrbitalOutlookJourney.stateID,
      version: pack.manifest.version, digest: pack.digest)
    mission.contract = job
    mission.milestones = [0]
    commander.scriptState.instances[missionID] = mission
    emitScriptEvent("mission.accepted", only: missionID)
  }

  /// Called inside the existing native care/loss candidate after its real transfer receipt exists.
  mutating func closeOrbitalOutlookTransfer(_ operation: UUID) throws {
    guard var custody = commander.nativePeople, var source = custody.outlookJourney,
      let boarding = source.boarding,
      let transfer = custody.transfers.first(where: { $0.operation == operation })
    else { return }
    let members = transfer.members.filter { $0.station?.batch == NativeOrbitalOutlookJourney.batch }
    if members.isEmpty { return }
    guard source.terminalOperation == nil, members == source.references,
      var mission = commander.scriptState.instances[boarding.mission], mission.outcome == .active,
      commander.scriptState.nextEvent < UInt64.max - 1, mission.revision < UInt64.max
    else { throw SaveError.invalidCommander }
    let outcome: ScriptOutcome
    switch transfer.kind {
    case .care:
      guard let dock = transfer.dock else { throw SaveError.invalidCommander }
      if NativeOrbitalOutlookJourney.returnReady(source, dock: dock) {
        outcome = .complete
      } else if NativeOrbitalOutlookJourney.sourceMatches(dock) {
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
    if outcome == .complete { mission.milestones.insert(4) }
    mission.acknowledge(sequence)
    source.terminalOperation = operation
    custody.outlookJourney = source
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

  var orbitalOutlookFacts: [String] {
    guard orbitalOutlookPack != nil || commander.nativePeople?.outlookJourney != nil else {
      return []
    }
    var facts = [nativeStationRuntimeEpoch.uuidString]
    if let source = commander.nativePeople?.outlookJourney {
      facts += source.people.map { $0.identity.key }
      facts += [
        String(source.offers.count), String(source.replies.count),
        String(describing: source.boarding?.mission), String(describing: source.terminalOperation),
      ]
    }
    facts += commander.accommodation.cabinFacts
    return facts
  }
  func orbitalOutlookDetail(_ action: NativeOrbitalOutlookJourneyAction) -> [String] {
    let quote = contractBoard.peopleQuote ?? orbitalOutlookQuote(action)
    var lines = [
      "Lysa Renn and Tovan Hale / original native Avenor people",
      "Agreed itinerary: Avenor - three ordered Renas views - Avenor; L2 H0, 870 CR, untimed.",
      "Two separate awake-compatible life-supported cabins; no additional cargo or deposit.",
      "Requesting passage is not consent or boarding. Both native replies and both actual berths are required.",
      "Each view needs 12 continuous native flight seconds: front view, fitted targeting, 250-1500 surface flight units, 2 degree aim and clear nearest-hit sight.",
      "Pause freezes observation. Interruption or load resets only the unfinished view; completed views persist.",
      "Actual Avenor return care after all three views pays once; the third scan alone pays nothing.",
      "Back changes no person, request, cabin, cash or clue.",
    ]
    if let source = commander.nativePeople?.outlookJourney, let offer = source.latestOffer {
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
