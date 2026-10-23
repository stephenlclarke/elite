import Foundation

public struct ScriptCourierPreview: Sendable, Equatable {
  public let terms: ScriptCourierTerms
  public var summary: String {
    if OriginalSealedDispatch.matches(terms.declaration) {
      return String(format: "1t | %.1f CR | H0 | Untimed", Double(terms.reward) / 10)
    }
    return String(
      format: "%dt | %.1f CR | %.0fh | PROJECT ESTIMATES", terms.variant.tonnes,
      Double(terms.reward) / 10, terms.duration / 3600)
  }
  public var review: [String] {
    let systems = Universe.systemsIncludingPlugh(number: terms.generation.origin.galaxy)
    if OriginalSealedDispatch.matches(terms.declaration) {
      return [
        "Sealed dispatch - uniquely identified one-tonne record. H0.",
        "Destination: Galaxy \(terms.generation.origin.galaxy + 1), \(systems[terms.destination].name) main orbital station.",
        "Deliver to: Sealed Dispatch Receiving Officer.",
        "Protected package: reserves 1t of real hold. No passenger berths.",
        String(
          format: "Frozen reward: %.1f CR for %d quoted legs.", Double(terms.reward) / 10,
          terms.path.count - 1),
        "Route: " + terms.path.map { systems[$0].name }.joined(separator: " -> "),
        "Untimed. No delivery deadline or perishability allowance.",
        "First hop uses current fuel; later station refuelling costs your money.",
        "No deposit or failure fee. Failure or abandonment pays 0 CR.",
        "Abandon explicitly with the origin Sealed Dispatch Officer. Back changes nothing.",
        "Each offer issues one original consignment. Loss cannot restore that item.",
      ]
    }
    return [
      "Difficulty \(terms.difficulty) - \(terms.variant.title). PROJECT ESTIMATES.",
      "Destination: Galaxy \(terms.generation.origin.galaxy + 1), \(systems[terms.destination].name) main orbital station.",
      "Deliver to: Courier Receiving Officer.",
      terms.variant == .data
        ? "Cargo hold: none (0t); uniquely identified encrypted data."
        : "Protected package: reserves 1t of real hold.",
      String(
        format: "Frozen reward: %.1f CR, based on %d shortest-route hops.",
        Double(terms.reward) / 10, terms.path.count - 1),
      "Route: " + terms.path.map { systems[$0].name }.joined(separator: " -> "),
      String(
        format: "Itinerary lower bound: %.2fh; headroom: %.2fh. Not a delivery guarantee.",
        terms.calendarLowerBoundSeconds / 3600,
        (terms.duration - terms.calendarLowerBoundSeconds) / 3600),
      String(
        format: "Time allowed: %.0f hours of mission game time from acceptance.",
        terms.duration / 3600),
      "Menus and pause do not count. Launch and hyperspace travel time count.",
      "First hop uses current fuel; later station refuelling costs your money. Affordability is not guaranteed.",
      "Route fixes the reward. You may travel by another route.",
      "No deposit or failure fee. Failure or abandonment pays 0 CR. One active courier job.",
      "Abandon explicitly with the origin Courier Dispatch Officer. Back changes nothing.",
      "Reopening keeps these offers. A later scheduled refresh may list new jobs.",
    ]
  }
}

/// Immutable one-action reference keeps complete causal proof off each nested Game value frame.
final class ScriptCourierAdmission: Sendable {
  enum Kind: Sendable, Equatable { case issue, deliver, abandon }
  let kind: Kind
  let instance: UUID
  let item: UUID
  let proof: ScriptCourierActionProof
  let job: ScriptContractJob
  init(
    kind: Kind, instance: UUID, item: UUID, proof: ScriptCourierActionProof, job: ScriptContractJob
  ) {
    self.kind = kind
    self.instance = instance
    self.item = item
    self.proof = proof
    self.job = job
  }
}

extension Game {
  func courierPreview(board key: String, offer id: UUID) throws -> ScriptCourierPreview? {
    guard let board = commander.contracts.boards[key],
      let pack = scriptPacks.first(where: { $0.digest == board.digest }),
      pack.manifest.courier != nil
    else { return nil }
    try ScriptPackLibrary.validateCourier(pack.manifest)
    guard let offer = board.offers.first(where: { $0.id == id }), let terms = offer.courier,
      board.valid, terms.declaration == pack.manifest.courier, terms.matches(offer)
    else { throw MissionPackError("Courier terms do not match their frozen native plan.") }
    return .init(terms: terms)
  }
  func requireCourierResources(_ terms: ScriptCourierTerms) throws {
    guard commander.valid, terms.valid, terms.generation.origin == contractStation else {
      throw MissionPackError("Courier acceptance requires its actual origin and valid native fit.")
    }
    guard OriginalSealedDispatch.hasHeadroom(terms) else {
      throw MissionPackError(
        "Frozen itinerary has no deadline headroom. This listing cannot be accepted.")
    }
    guard commander.standardCargoCapacity - commander.cargoTonnes >= terms.variant.tonnes else {
      throw MissionPackError("The protected package requires one free tonne of real hold.")
    }
    let systems = Universe.systemsIncludingPlugh(number: commander.galaxy)
    for (index, edge) in zip(terms.path, terms.path.dropFirst()).enumerated() {
      let cap =
        index == 0
        ? commander.maximumJumpDistance
        : commander.fullTankJumpDistance
      guard systems[edge.0].distance(to: systems[edge.1]) <= cap else {
        throw MissionPackError(
          "Refuel or refit for this frozen route; its destination will not reroll.")
      }
    }
    guard commander.scriptState.missionCalendar != nil,
      commander.scriptState.clock(.missionCalendar) <= 1e12 - terms.duration
    else {
      throw MissionPackError("Courier deadline exceeds the persistent game-clock limit.")
    }
  }
  func courierProof(token: String, revision: UInt64) -> ScriptCourierActionProof {
    .init(
      sequence: commander.scriptState.nextEvent + 1, token: token, revision: revision,
      epoch: ecmControl.epoch, clock: commander.scriptState.clock(.missionCalendar),
      station: contractStation)
  }
  func courierActionComplete(_ admission: ScriptCourierAdmission) -> Bool {
    guard let state = commander.scriptState.instances[admission.instance],
      let custody = state.courier, state.hasAcknowledged(admission.proof.sequence),
      custody.item == admission.item
    else { return false }
    switch admission.kind {
    case .issue:
      return state.outcome == .active && custody.issue == admission.proof && custody.terminal == nil
    case .deliver:
      return custody.terminal?.cause == .delivered && custody.terminal?.proof == admission.proof
        && state.outcome == .complete
    case .abandon:
      return custody.terminal?.cause == .abandoned && custody.terminal?.proof == admission.proof
        && state.outcome == .abandoned
    }
  }
  func applyCourierCommand(
    _ command: ScriptValue, event: ScriptEvent, pack: ScriptPack,
    state: inout ScriptInstance, candidate: inout Commander
  ) throws {
    try ScriptPackLibrary.validateCourier(pack.manifest)
    guard command.object.map({ Set($0.keys) == ["op", "id"] }) == true,
      let receiptID = command["id"]?.string, PackValidation.localID(receiptID),
      let admission = scriptCourierAdmission, admission.instance == state.id,
      admission.item == ScriptCourierCustody.itemIdentity(state.id),
      admission.proof.valid, admission.proof.epoch == ecmControl.epoch,
      admission.proof.clock == candidate.scriptState.clock(.missionCalendar),
      admission.proof.revision == state.revision, event.sequence == admission.proof.sequence,
      event.instance == state.id, state.outcome == .active, state.contract == admission.job,
      let terms = state.contract?.offer.courier, terms.declaration == pack.manifest.courier,
      state.digest == pack.digest, state.version == pack.manifest.version,
      docked, dockedAtMainStation, !paused, contractStation == admission.proof.station,
      event.context == scriptEventContext(state), !state.receipts.contains(receiptID)
    else { throw MissionPackError("Courier action requires its original native confirmation.") }
    let op = command["op"]?.string
    switch admission.kind {
    case .issue:
      guard op == "courier.issue", event.kind == "mission.accepted", state.courier == nil,
        admission.proof.revision == 0, admission.proof.station == admission.job.station,
        state.payloads[ScriptCourierCustody.payloadKey] == nil
      else {
        throw MissionPackError("Only the original acceptance can issue this consignment.")
      }
      state.courier = .init(item: admission.item, issue: admission.proof)
      if terms.variant == .package { state.payloads[ScriptCourierCustody.payloadKey] = 1 }
    case .deliver, .abandon:
      let delivering = admission.kind == .deliver
      let contact =
        delivering ? terms.declaration.deliveryContact : terms.declaration.abandonContact
      let target =
        delivering
        ? ContractStationIdentity(
          galaxy: admission.job.offer.destinationGalaxy,
          system: admission.job.offer.destinationSystem, stationClass: "main-orbital")
        : admission.job.station
      guard op == (delivering ? "courier.deliver" : "courier.abandon"),
        event.kind == "dialogue.confirmed", event.values["token"]?.string == admission.proof.token,
        event.values["dialogue_id"]?.string == contact, state.dialogue?.id == contact,
        state.dialogue?.token == admission.proof.token, state.dialogue?.revision == state.revision,
        target == contractStation, state.courier?.terminal == nil,
        state.courier?.pendingLoss == nil, state.courier?.item == admission.item,
        !delivering
          || OriginalSealedDispatch.deliveryAllowed(admission.job, at: admission.proof.clock)
      else {
        throw MissionPackError("Bring the matching held consignment to its actual named contact.")
      }
      try completeCourier(
        delivering ? .delivered : .abandoned, proof: admission.proof,
        state: &state, candidate: &candidate, pack: pack)
    }
    state.receipts.insert(receiptID)
  }
  func completeCourier(
    _ cause: ScriptCourierTerminalCause, proof: ScriptCourierActionProof,
    state: inout ScriptInstance, candidate: inout Commander, pack: ScriptPack? = nil
  ) throws {
    guard var custody = state.courier, custody.terminal == nil,
      let terms = state.contract?.offer.courier,
      state.payloads[ScriptCourierCustody.payloadKey, default: 0] == terms.variant.tonnes,
      cause != .delivered || custody.pendingLoss == nil
    else {
      throw MissionPackError("Matching unconsumed courier custody is required.")
    }
    custody.terminal = .init(
      id: ScriptCourierCustody.terminalIdentity(custody.item), item: custody.item,
      cause: cause, proof: proof, amount: cause == .delivered ? terms.reward : 0)
    custody.pendingLoss = nil
    state.courier = custody
    state.payloads.removeValue(forKey: ScriptCourierCustody.payloadKey)
    if let pack {
      try finishScriptMission(cause.outcome, pack: pack, state: &state, candidate: &candidate)
    } else {
      guard cause != .delivered && cause != .abandoned else {
        throw MissionPackError("Courier contact requires its exact content.")
      }
      try settleContract(cause.outcome, state: &state, candidate: &candidate)
      state.outcome = cause.outcome
    }
    state.dialogue = nil
    state.timers = [:]
  }
  mutating func markCourierFatalLoss() {
    for id in orderedScriptInstances {
      guard var state = commander.scriptState.instances[id], state.outcome == .active,
        state.contract?.offer.courier?.variant == .package, var custody = state.courier,
        custody.terminal == nil, custody.pendingLoss == nil
      else { continue }
      custody.pendingLoss = .init(
        id: ScriptIdentity.uuid("courier-fatal-v1:" + custody.item.uuidString),
        item: custody.item, clock: commander.scriptState.clock(.missionCalendar),
        station: contractStation, epoch: ecmControl.epoch, context: scriptEventContext(state))
      state.courier = custody
      commander.scriptState.instances[id] = state
    }
  }
  mutating func loseCourierPackagesOnEscape() -> Bool {
    // This runs only after native escape admission, before docking/gear observers.
    resolveCourierTerminals(escape: true)
    return !commander.scriptState.instances.values.contains {
      $0.outcome == .active && $0.contract?.offer.courier?.variant == .package
    }
  }
  @inline(never)
  mutating func resolveCourierTerminals(escape: Bool = false, publish: ScriptPublisher? = nil) {
    resolveProcurementTerminals(publish: publish)
    resolveRRSCourierTerminals(publish: publish)
    guard !Self.courierTerminalInstancesAreEmpty(in: self) else { return }
    resolveNativeCourierTerminals(escape: escape, publish: publish)
  }

  @inline(never)
  private static func courierTerminalInstancesAreEmpty(in game: borrowing Game) -> Bool {
    game.withReadOnlyCommander { $0.scriptInstancesAreEmpty() }
  }

  @inline(never)
  private mutating func resolveNativeCourierTerminals(escape: Bool, publish: ScriptPublisher?) {
    for id in orderedScriptInstances {
      guard let old = commander.scriptState.instances[id], old.outcome == .active,
        let custody = old.courier, let terms = old.contract?.offer.courier
      else { continue }
      let now = commander.scriptState.clock(.missionCalendar)
      let cause: ScriptCourierTerminalCause
      if custody.pendingLoss != nil {
        cause = .shipDestroyed
      } else if escape && terms.variant == .package {
        cause = .escapePod
      } else if let due = old.contract?.deadline, now > due {
        cause = .expired
      } else {
        continue
      }
      resolveCourierTerminal(cause, id: id, old: old, custody: custody, publish: publish)
    }
  }
  private mutating func resolveCourierTerminal(
    _ cause: ScriptCourierTerminalCause, id: UUID, old: ScriptInstance,
    custody: ScriptCourierCustody, publish: ScriptPublisher?
  ) {
    do {
      var candidate = self
      guard candidate.commander.scriptState.nextEvent < UInt64(Int64.max) - 1 else {
        throw MissionPackError("Courier terminal receipt capacity reached.")
      }
      var state = old
      let nextProof = candidate.courierProof(
        token: "native:" + cause.rawValue, revision: state.revision)
      let proof =
        custody.pendingLoss.map { loss in
          ScriptCourierActionProof(
            sequence: nextProof.sequence, token: "native:" + loss.id.uuidString,
            revision: nextProof.revision, epoch: loss.epoch, clock: loss.clock,
            station: loss.station)
        } ?? nextProof
      candidate.commander.scriptState.nextEvent = proof.sequence
      try completeCourier(cause, proof: proof, state: &state, candidate: &candidate.commander)
      state.revision += 1
      state.acknowledge(proof.sequence)
      state.completionReceipt = candidate.nativeCourierCompletionReceipt(
        state,
        sequence: proof.sequence,
        cause: custody.pendingLoss?.context ?? candidate.scriptEventContext(old))
      if state.journal.count < 512 {
        state.journal.append("Courier " + cause.title + ". Paid: 0 CR.")
      }
      candidate.commander.scriptState.instances[id] = state
      candidate.commander.scriptState.pendingEvents.removeAll { $0.instance == id }
      if let receipt = state.completionReceipt { try candidate.enqueueScriptCompletion(receipt) }
      guard candidate.commander.valid else { throw SaveError.invalidCommander }
      try publish?(&candidate)
      self = candidate
    } catch {
      notify("COURIER OUTCOME NOT SAVED - CONSIGNMENT NOT DELIVERABLE")
    }
  }
  mutating func confirmCourierDialogue(_ id: UUID, dialogue: ScriptDialogue) throws {
    guard scriptCourierAdmission == nil,
      let state = commander.scriptState.instances[id], let job = state.contract,
      let terms = job.offer.courier, state.courier?.pendingLoss == nil,
      state.courier?.terminal == nil, commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      let pack = scriptPack(for: state)
    else { throw MissionPackError("Consignment is not deliverable.") }
    try ScriptPackLibrary.validateCourier(pack.manifest)
    let kind: ScriptCourierAdmission.Kind
    if dialogue.id == terms.declaration.deliveryContact {
      kind = .deliver
    } else if dialogue.id == terms.declaration.abandonContact {
      kind = .abandon
    } else {
      throw MissionPackError("Use the actual courier receiving or dispatch officer.")
    }
    var candidate = self
    let admission = ScriptCourierAdmission(
      kind: kind, instance: id,
      item: ScriptCourierCustody.itemIdentity(id),
      proof: courierProof(token: dialogue.token, revision: state.revision), job: job)
    candidate.scriptCourierAdmission = admission
    candidate.emitScriptEvent(
      "dialogue.confirmed",
      values: [
        "dialogue_id": .string(dialogue.id), "token": .string(dialogue.token),
      ], only: id)
    candidate.scriptCourierAdmission = nil
    guard candidate.courierActionComplete(admission), candidate.commander.valid else {
      throw MissionPackError(
        "Courier handoff did not finish in its original confirmation; nothing transferred.")
    }
    self = candidate
  }
  func courierGallerySummary(_ state: ScriptInstance?) -> String {
    guard let state, let terms = state.contract?.offer.courier, let custody = state.courier else {
      return ""
    }
    let status: String
    if custody.pendingLoss != nil {
      status = "Lost - recording outcome. Not deliverable."
    } else if let terminal = custody.terminal {
      status = terminal.cause.title
    } else {
      status = state.suspension == nil ? "Held" : "Held - mission content unavailable"
    }
    if OriginalSealedDispatch.matches(terms.declaration) {
      return "\n\nSealed dispatch / H0 / Untimed."
        + "\nConsignment \(custody.item.uuidString.prefix(8)): \(status)"
        + "\nProtected hold: \(custody.terminal == nil ? 1 : 0)t. No passenger berths."
        + String(format: "\nFixed reward: %.1f CR.", Double(terms.reward) / 10)
        + "\nReceiving contact: Sealed Dispatch Receiving Officer."
        + (custody.terminal.map { String(format: "\nPaid: %.1f CR.", Double($0.amount) / 10) } ?? "")
    }
    let remaining = max(
      0, (state.contract?.deadline ?? 0) - commander.scriptState.clock(.missionCalendar))
    return "\n\nDifficulty \(terms.difficulty) / \(terms.variant.title) / PROJECT ESTIMATES."
      + "\nConsignment \(custody.item.uuidString.prefix(8)): \(status)"
      + "\nProtected hold: \(custody.terminal == nil ? terms.variant.tonnes : 0)t."
      + String(
        format: "\nRemaining mission time: %.1fs. Fixed reward: %.1f CR.", remaining,
        Double(terms.reward) / 10)
      + "\nReceiving contact: Courier Receiving Officer."
      + (custody.terminal.map { String(format: "\nPaid: %.1f CR.", Double($0.amount) / 10) } ?? "")
  }
}

extension Game {
  func validateInstalledCourierContent() throws {
    try validateInstalledProcurementContent()
    for state in commander.scriptState.instances.values {
      guard let terms = state.contract?.offer.courier, let pack = scriptPack(for: state) else {
        continue
      }
      try ScriptPackLibrary.validateCourier(pack.manifest)
      guard terms.declaration == pack.manifest.courier else { throw SaveError.invalidCommander }
    }
    for board in commander.contracts.boards.values where board.courierGeneration != nil {
      guard let pack = scriptPacks.first(where: { $0.digest == board.digest }) else { continue }
      try ScriptPackLibrary.validateCourier(pack.manifest)
      guard board.offers.allSatisfy({ $0.courier?.declaration == pack.manifest.courier }) else {
        throw SaveError.invalidCommander
      }
    }
  }
}

extension Game {
  /// A renderer consumes the same typed binding as confirmation; text never grants authority.
  var presentedCourier: ScriptInstance? {
    guard let id = scriptOffer, let state = commander.scriptState.instances[id],
      let shown = scriptPresentedDialogue, state.dialogue == shown,
      shown.revision == state.revision,
      shown.galaxy == commander.galaxy, shown.system == commander.system,
      docked, dockedAtMainStation, let terms = state.contract?.offer.courier,
      let pack = scriptPack(for: state),
      (try? ScriptPackLibrary.validateCourier(pack.manifest)) != nil,
      pack.manifest.courier == terms.declaration, state.courier != nil
    else { return nil }
    return state
  }
  var courierContactActionLabel: String? {
    guard let state = presentedCourier, state.outcome == .active, state.suspension == nil,
      state.courier?.terminal == nil, state.courier?.pendingLoss == nil,
      let job = state.contract, let terms = job.offer.courier
    else { return nil }
    if scriptPresentedDialogue?.id == terms.declaration.deliveryContact,
      commander.galaxy == job.offer.destinationGalaxy,
      commander.system == job.offer.destinationSystem
    {
      return "Deliver"
    }
    if scriptPresentedDialogue?.id == terms.declaration.abandonContact,
      contractStation == job.station
    {
      return "Abandon"
    }
    return nil
  }
  var courierContactDetails: String {
    presentedCourier.map { courierGallerySummary($0) } ?? ""
  }
}

extension Game {
  /// Native terminal safety remains usable without Lua or the original content package.
  func nativeCourierCompletionReceipt(
    _ state: ScriptInstance, sequence: UInt64,
    cause: ScriptEventContext
  ) -> ScriptCompletionReceipt {
    let delivered = commander.accommodation.people.values.filter { person in
      guard person.mission == state.id else { return false }
      if case .delivered = person.location { return true }
      return false
    }
    return .init(
      instance: state.id, definition: state.definition, version: state.version,
      digest: state.digest, outcome: state.outcome, sequence: sequence,
      causeKind: "courier.terminated",
      cause: cause, committed: scriptEventContext(state), revision: state.revision,
      milestones: state.milestones.sorted(),
      destroyedEncounters: state.ownedEncounters.values.filter(\.destroyed).map(\.id).sorted(),
      deliveredParties: Set(delivered.map(\.party)).sorted(),
      returnedEquipment: state.gearIssues.values.filter { $0.status == .returned }.map(\.resource)
        .sorted(),
      settlementAmount: state.contract?.settlementAmount,
      choices: state.choiceReceipts.isEmpty ? nil : state.choiceReceipts)
  }
}
