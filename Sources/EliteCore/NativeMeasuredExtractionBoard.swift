import Foundation

enum NativeMeasuredExtractionAction: String, Sendable, Equatable {
  case accept, process, receive, cancel
  var key: String { NativeMeasuredExtraction.stateID + "/" + rawValue }
  var title: String {
    switch self {
    case .accept: "Mining office / accept measured extraction"
    case .process: "Renas processing / grade twelve original tonnes"
    case .receive: "Renas receiver / deliver graded mineral products"
    case .cancel: "Avenor owner / return surviving property unpaid"
    }
  }
}

struct NativeMeasuredExtractionReview: Sendable {
  let action: NativeMeasuredExtractionAction
  let dock: NativeMainStationDockReceipt?
  let carrier: UUID?
  let inventoryRevision: UInt64?
  let epoch: UUID
  let custody: String
  let issues: [String]
  let reviewToken = UUID()
  var allowed: Bool { issues.isEmpty }
}

extension Game {
  var measuredExtractionPack: ScriptPack? {
    scriptPacks.first {
      $0.manifest.stateID == NativeMeasuredExtraction.stateID
        && $0.digest == NativeMeasuredExtraction.digest
        && $0.manifest.measuredExtraction?.valid == true
    }
  }

  var measuredExtractionRows: [ContractBoardRow] {
    guard measuredExtractionPack != nil else { return [] }
    let actions: [NativeMeasuredExtractionAction]
    if let state = measuredExtractionState {
      guard state.reception == nil else { return [] }
      let active = commander.scriptState.instances[state.permission.mission]?.outcome == .active
      if active {
        actions = state.processing == nil ? [.process, .cancel] : [.receive, .cancel]
      } else {
        guard let source = commander.scriptState.savedMeasuredExtractionSource,
          !NativeMeasuredExtraction.rawHeld(source).isEmpty
            || state.processing?.products.contains(where: { $0.custody == .held }) == true
        else { return [] }
        actions = [.cancel]
      }
    } else {
      guard commander.scriptState.savedMeasuredExtractionSource == nil,
        contractStation == NativeMeasuredExtraction.source
      else { return [] }
      actions = [.accept]
    }
    return actions.map { action in
      .init(
        board: action.key, offer: nil, title: action.title,
        reason: measuredExtractionReview(action).issues.first, measuredExtraction: action)
    }
  }

  func measuredExtractionReview(_ action: NativeMeasuredExtractionAction)
    -> NativeMeasuredExtractionReview
  {
    var issues: [String] = []
    let required =
      action == .accept || action == .cancel
      ? NativeMeasuredExtraction.source : NativeMeasuredExtraction.destination
    if !nativeMainStationDockEvidenceIsCurrent || contractStation != required {
      issues.append(
        action == .accept || action == .cancel
          ? "Use the actual Avenor mining office."
          : "Use the actual Renas processing and receiving office.")
    }
    if !scriptDurabilityAvailable { issues.append("Choose a writable commander save.") }
    if measuredExtractionPack == nil {
      issues.append("Restore the original measured extraction content.")
    }
    if commander.equipmentOwnerID == nil || commander.hullInstanceID == nil {
      issues.append("Use the actual owned collecting carrier.")
    }
    let state = measuredExtractionState
    if action == .accept {
      if commander.scriptState.savedMeasuredExtractionSource != nil {
        issues.append("This finite source is already allocated.")
      }
      if !hasMeasuredExtractionFit {
        issues.append("Fit targeting, Mining targeting, a mining work tool and Fuel Scoops.")
      }
      if !NativeMeasuredExtraction.route(ScriptCourierReach(commander)) {
        issues.append("Refuel or refit for the actual Avenor to Renas route.")
      }
      if let used = commander.checkedCargoTonnes {
        if used > commander.standardCargoCapacity - 12 {
          issues.append("Free twelve actual hold tonnes.")
        }
      } else {
        issues.append("The current hold claim is invalid.")
      }
      if OriginalServiceReservationPolicy.activeCount(commander.scriptState)
        >= OriginalServiceReservationPolicy.maximumActive
      {
        issues.append("Three Original contracts or services are already active.")
      }
      if let rock = measuredExtractionRock {
        if !commander.miningLedger.measuredSourceIsPristine(rock) {
          issues.append("The original twenty-tonne natural source is no longer fresh.")
        }
      } else {
        issues.append("The natural Avenor field-five source is unavailable.")
      }
    } else if let state, let source = commander.scriptState.savedMeasuredExtractionSource,
      let mission = commander.scriptState.instances[state.permission.mission],
      state.reception == nil
    {
      if commander.hullInstanceID != state.permission.carrier {
        issues.append("Return in the original collecting carrier.")
      }
      switch action {
      case .accept: break
      case .process:
        if mission.outcome != .active || state.processing != nil || state.extraction == nil
          || state.captures.count != 12 || !state.losses.isEmpty
          || NativeMeasuredExtraction.rawHeld(source).count != 12
        {
          issues.append("Bring all twelve exact original raw tonnes for native processing.")
        }
      case .receive:
        if mission.outcome != .active || state.processing?.products.count != 12
          || state.processing?.products.allSatisfy({ $0.custody == .held }) != true
          || !state.losses.isEmpty
        {
          issues.append(
            "Separately process and bring all twelve linked graded products to the receiver.")
        }
      case .cancel:
        if mission.outcome != .active && NativeMeasuredExtraction.rawHeld(source).isEmpty
          && state.processing?.products.contains(where: { $0.custody == .held }) != true
        {
          issues.append("No surviving protected property remains for unpaid owner return.")
        }
      }
    } else {
      issues.append("There is no unreconciled measured extraction permission.")
    }
    var tokens: [String] = []
    if let state {
      tokens.append(state.permission.operation.uuidString)
      tokens.append(state.extraction?.operation.uuidString ?? "unextracted")
      tokens.append(contentsOf: state.captures.map { $0.operation.uuidString })
      tokens.append(contentsOf: state.losses.map { $0.operation.uuidString })
      tokens.append(state.processing?.operation.uuidString ?? "raw")
      if let source = commander.scriptState.savedMeasuredExtractionSource {
        tokens.append((try? NativeMeasuredExtraction.hash(source)) ?? "invalid")
      }
      if let processing = state.processing {
        tokens.append((try? NativeMeasuredExtraction.hash(processing)) ?? "invalid")
      }
      tokens.append(state.reception?.operation.uuidString ?? "open")
    } else {
      tokens.append("unallocated")
    }
    return .init(
      action: action, dock: commander.nativeStations?.currentMainDock,
      carrier: commander.hullInstanceID, inventoryRevision: commander.equipmentInventory?.revision,
      epoch: nativeStationRuntimeEpoch, custody: tokens.joined(separator: ":"), issues: issues)
  }

  mutating func confirmMeasuredExtraction(_ review: NativeMeasuredExtractionReview) throws {
    let current = measuredExtractionReview(review.action)
    guard review.allowed, current.allowed, review.dock == current.dock,
      review.carrier == current.carrier, review.inventoryRevision == current.inventoryRevision,
      review.epoch == current.epoch, review.custody == current.custody,
      let pack = measuredExtractionPack
    else { throw MissionPackError("Source, carrier or custody changed. Review again.") }
    var candidate = self
    switch review.action {
    case .accept: try candidate.acceptMeasuredExtraction(pack)
    case .process: try candidate.processMeasuredExtraction()
    case .receive, .cancel:
      try candidate.receiveMeasuredExtraction(cancel: review.action == .cancel)
    }
    self = candidate
  }

  private mutating func acceptMeasuredExtraction(_ pack: ScriptPack) throws {
    try OriginalServiceReservationPolicy.requireAvailableSlot(commander.scriptState)
    guard commander.scriptState.savedMeasuredExtractionSource == nil,
      let dock = commander.nativeStations?.currentMainDock,
      let player = commander.flightSimulation.player, let carrier = commander.hullInstanceID,
      let inventory = commander.equipmentInventory,
      let definition = pack.manifest.measuredExtraction,
      let rock = measuredExtractionRock, commander.miningLedger.measuredSourceIsPristine(rock)
    else { throw SaveError.invalidCommander }
    let sourceID = NativeMeasuredExtraction.identity(dock.station)
    let key = pack.digest + "/measured-extraction/" + NativeMeasuredExtraction.source.key
    let offerID = ScriptIdentity.uuid("contract-offer-v1:\(key):0:measured-extraction")
    let missionID = Self.contractJobIdentity(offerID)
    guard commander.scriptState.instances[missionID] == nil else {
      throw SaveError.invalidCommander
    }
    let offer = ScriptContractOffer(
      id: offerID, key: "measured-extraction",
      title: "Measured extraction / 12t / 890 CR / untimed",
      briefing: pack.manifest.mission.briefing,
      destinationGalaxy: 0, destinationSystem: 185, reward: NativeMeasuredExtraction.reward,
      deposit: 0, failureReward: 0, refundOnFailure: false, duration: 0, parameters: .object([:]))
    var accepted = offer
    accepted.status = .accepted(missionID)
    commander.contracts.boards[key] = .init(
      id: NativeMeasuredExtraction.boardID,
      provider: pack.manifest.id, version: pack.manifest.version, digest: pack.digest,
      title: "Avenor measured extraction", station: NativeMeasuredExtraction.source,
      revision: 0, seed: 0, clock: .local, period: 3600, group: NativeMeasuredExtraction.stateID,
      offers: [accepted])
    let source = MeasuredSource(
      id: sourceID, owner: dock.station, registration: dock,
      root: NativeMeasuredExtraction.root, mission: missionID,
      originals: NativeMeasuredExtraction.originals(dock.station))
    let state = NativeMeasuredExtractionState(
      definition: definition,
      permission: .init(
        operation: ScriptIdentity.uuid("measured-permit-v1:\(sourceID):\(missionID)"),
        mission: missionID, source: sourceID, carrier: carrier, player: player, dock: dock,
        reach: ScriptCourierReach(commander), inventoryRevision: inventory.revision,
        physicalTime: commander.flightSimulation.physicalTime))
    var mission = ScriptInstance(
      id: missionID, definition: NativeMeasuredExtraction.stateID,
      version: pack.manifest.version, digest: pack.digest)
    mission.contract = .init(
      boardKey: key, provider: pack.manifest.id, version: pack.manifest.version,
      digest: pack.digest, station: NativeMeasuredExtraction.source, boardRevision: 0,
      group: NativeMeasuredExtraction.stateID, offer: offer, clock: .local,
      acceptedAt: commander.scriptState.clock(.local), deadline: nil)
    mission.savedMeasuredExtraction = state
    mission.payloads = NativeMeasuredExtraction.payloads(source, state: state, outcome: .active)
    mission.milestones = [0]
    commander.scriptState.savedMeasuredExtractionSource = source
    commander.scriptState.instances[missionID] = mission
    emitScriptEvent("mission.accepted", only: missionID)
    notify("EXTRACTION PERMISSION RECORDED - TWELVE TONNES RESERVED")
  }

  private mutating func processMeasuredExtraction() throws {
    guard var state = measuredExtractionState,
      var source = commander.scriptState.savedMeasuredExtractionSource,
      var mission = commander.scriptState.instances[state.permission.mission],
      mission.outcome == .active,
      let dock = commander.nativeStations?.currentMainDock, nativeMainStationDockEvidenceIsCurrent,
      contractStation == NativeMeasuredExtraction.destination,
      state.processing == nil, state.extraction != nil, state.captures.count == 12,
      state.losses.isEmpty, NativeMeasuredExtraction.rawHeld(source).count == 12,
      commander.hullInstanceID == state.permission.carrier
    else { throw SaveError.invalidCommander }
    let operation = ScriptIdentity.uuid(
      "measured-process-v1:\(state.permission.operation):\(dock.sequence)")
    let inputs = source.originals.map(\.id)
    let products = inputs.map { input in
      MeasuredProduct(
        id: ScriptIdentity.uuid("measured-product-v1:\(operation):\(input)"), input: input,
        massKg: 1000)
    }
    for index in source.originals.indices {
      source.originals[index].custody = .processed(operation)
    }
    state.processing = .init(operation: operation, dock: dock, inputs: inputs, products: products)
    mission.savedMeasuredExtraction = state
    mission.milestones.insert(3)
    mission.payloads = NativeMeasuredExtraction.payloads(
      source, state: state, outcome: mission.outcome)
    commander.scriptState.savedMeasuredExtractionSource = source
    commander.scriptState.instances[mission.id] = mission
    notify("TWELVE ORIGINAL TONNES GRADED - SEPARATE RECEIVER REVIEW REQUIRED; NO PAYMENT")
  }

  private mutating func receiveMeasuredExtraction(cancel: Bool) throws {
    guard var state = measuredExtractionState,
      var source = commander.scriptState.savedMeasuredExtractionSource,
      var mission = commander.scriptState.instances[state.permission.mission],
      state.reception == nil,
      let dock = commander.nativeStations?.currentMainDock, nativeMainStationDockEvidenceIsCurrent,
      commander.hullInstanceID == state.permission.carrier,
      contractStation
        == (cancel ? NativeMeasuredExtraction.source : NativeMeasuredExtraction.destination)
    else { throw SaveError.invalidCommander }
    let raw = NativeMeasuredExtraction.rawHeld(source)
    let held = (state.processing?.products ?? []).filter { $0.custody == .held }.map(\.id)
    let complete = !cancel && mission.outcome == .active && held.count == 12 && state.losses.isEmpty
    guard complete || (cancel && (mission.outcome == .active || !raw.isEmpty || !held.isEmpty))
    else { throw SaveError.invalidCommander }
    let operation = ScriptIdentity.uuid(
      "measured-receive-v1:\(state.permission.operation):\(dock.sequence)")
    let cause = scriptEventContext(mission)
    state.reception = .init(
      operation: operation, dock: dock, products: complete ? held : [],
      returnedRaw: cancel ? raw : [], returnedProducts: cancel ? held : [], complete: complete,
      cause: cause, committed: cause)
    for index in source.originals.indices where raw.contains(source.originals[index].id) {
      source.originals[index].custody = .returned(operation)
    }
    if var processing = state.processing {
      for index in processing.products.indices where held.contains(processing.products[index].id) {
        processing.products[index].custody = complete ? .received(operation) : .returned(operation)
      }
      state.processing = processing
    }
    commander.scriptState.savedMeasuredExtractionSource = source
    if mission.outcome == .active {
      try finishMeasuredExtraction(state, outcome: complete ? .complete : .abandoned)
    } else {
      mission.savedMeasuredExtraction = state
      mission.payloads = NativeMeasuredExtraction.payloads(
        source, state: state, outcome: mission.outcome)
      commander.scriptState.instances[mission.id] = mission
    }
    nativeMeasuredExtractionPending = nil
    notify(
      complete
        ? "GRADED PRODUCTS RECEIVED - 890 CR PAYMENT RECORDED"
        : "SURVIVING PROPERTY RETURNED UNPAID")
  }

  mutating func finishMeasuredExtraction(
    _ state: NativeMeasuredExtractionState, outcome: ScriptOutcome
  ) throws {
    guard var mission = commander.scriptState.instances[state.permission.mission],
      mission.outcome == .active,
      mission.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      let source = commander.scriptState.savedMeasuredExtractionSource
    else { throw SaveError.invalidCommander }
    let previous = mission
    let cause = scriptEventContext(mission)
    var candidate = commander
    try settleContract(outcome, state: &mission, candidate: &candidate)
    candidate.scriptState.nextEvent += 1
    let sequence = candidate.scriptState.nextEvent
    mission.outcome = outcome
    mission.revision += 1
    mission.dialogue = nil
    mission.acknowledge(sequence)
    if outcome == .complete { mission.milestones.insert(4) }
    commander = candidate
    let committed = scriptEventContext(mission)
    var next = state
    if let receipt = next.reception {
      next.reception = .init(
        operation: receipt.operation, dock: receipt.dock, products: receipt.products,
        returnedRaw: receipt.returnedRaw, returnedProducts: receipt.returnedProducts,
        complete: receipt.complete,
        cause: receipt.cause, committed: committed)
    }
    mission.savedMeasuredExtraction = next
    mission.payloads = NativeMeasuredExtraction.payloads(source, state: next, outcome: outcome)
    mission.completionReceipt = .init(
      instance: mission.id, definition: mission.definition,
      version: mission.version, digest: mission.digest, outcome: outcome, sequence: sequence,
      causeKind: "mission.receipted", cause: cause, committed: committed,
      revision: mission.revision,
      milestones: mission.milestones.sorted(), destroyedEncounters: [], deliveredParties: [],
      returnedEquipment: [], settlementAmount: mission.contract?.settlementAmount, choices: nil)
    commander.scriptState.instances[mission.id] = mission
    try awardScriptClue(previous: previous, next: mission, trust: .production)
    if let receipt = mission.completionReceipt { try enqueueScriptCompletion(receipt) }
  }

  func measuredExtractionDetail(_ action: NativeMeasuredExtractionAction) -> [String] {
    let lines = [
      "Avenor mining office grants permission for twelve originals from natural field 5, rock 0.",
      "Use targeting, Mining targeting, a mining work tool and Fuel Scoops. Select the actual source and use W/Return.",
      "Native extraction yields twenty tonnes: twelve protected originals and eight ordinary tonnes.",
      "Collect all twelve before leaving Avenor. Departed or destroyed originals cannot be replaced.",
      "Renas processing consumes twelve original raw tonnes and creates twelve linked graded products, conserving 12000 kg.",
      "Separately review receiving at Renas for 890 CR and the family trace, once. Processing pays nothing.",
      "Surviving property after failure remains real hold mass until actual unpaid Avenor owner return or loss.",
      "No deposit, deadline, cabins or fungible commodity substitution. Back changes no permission, custody or cash.",
    ]
    return lines
      + (contractBoard.measuredExtractionQuote ?? measuredExtractionReview(action)).issues
  }
}
