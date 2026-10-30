import Foundation

/// Attempt-local native values. Copying Game shares immutable evidence, never mutable custody.
final class NativeMeasuredExtractionPending: Sendable {
  let extraction: MeasuredExtractionWitness?
  let intakes: [MeasuredIntake]
  let losses: [MeasuredLoss]
  fileprivate init(
    extraction: MeasuredExtractionWitness?, intakes: [MeasuredIntake], losses: [MeasuredLoss]
  ) {
    self.extraction = extraction
    self.intakes = intakes
    self.losses = losses
  }
}
final class MeasuredHitAttempt: Sendable {
  let witness: MeasuredExtractionWitness
  fileprivate init(_ witness: MeasuredExtractionWitness) { self.witness = witness }
}
final class MeasuredProtectedIntakePermit: Sendable {
  let receipt: MeasuredIntake
  fileprivate init(_ receipt: MeasuredIntake) { self.receipt = receipt }
}

extension Game {
  @inline(never)
  func beginMeasuredExtractionHit(body: borrowing SpaceBody, incident: CombatIncident)
    -> MeasuredHitAttempt?
  {
    guard let state = measuredExtractionState, state.extraction == nil,
      nativeMeasuredExtractionPending?.losses.isEmpty != false,
      commander.scriptState.instances[state.permission.mission]?.outcome == .active,
      incident.kind == .laser, incident.laser == .mining,
      incident.origin.owner == commander.flightSimulation.player,
      incident.origin.ordnance == nil, incident.victim == body.physical?.identity,
      informationTargetBody?.physical?.identity == incident.victim,
      body.physical?.rock == NativeMeasuredExtraction.root,
      body.physical?.identity.system == systemIdentity,
      body.physical?.identity.visit == commander.flightSimulation.visit,
      hasMeasuredExtractionFit, let tool = commander.fittedMiningWorkTool,
      incident.origin.sourcePart == "work-tool:" + tool.id.uuidString,
      let core = commander.fittedEquipment(at: .targetingCore),
      let module = commander.fittedEquipment(at: .targetingMining),
      let snapshot = try? commander.purchaseSnapshot(),
      snapshot.activeHull == state.permission.carrier,
      let toolItem = snapshot.items.first(where: { $0.id == tool.id }),
      let coreItem = snapshot.items.first(where: { $0.id == core.id }),
      let moduleItem = snapshot.items.first(where: { $0.id == module.id })
    else { return nil }
    let operation = ScriptIdentity.uuid(
      "measured-extraction-v1:\(state.permission.operation):\(incident.id)")
    let snapshotBody = copy body
    return .init(
      .init(
        operation: operation, permission: state.permission.operation,
        incident: incident, body: [snapshotBody], emitted: [],
        equipment: [coreItem, moduleItem, toolItem],
        carrier: snapshot.activeHull, inventoryRevision: snapshot.revision,
        epoch: nativeStationRuntimeEpoch, authority: operation))
  }

  @inline(never)
  mutating func observeMeasuredExtractionResult(
    attempt: MeasuredHitAttempt?, body: borrowing SpaceBody, incident: CombatIncident,
    result: MiningHitResult
  ) {
    guard body.physical?.rock == NativeMeasuredExtraction.root, let state = measuredExtractionState,
      commander.scriptState.instances[state.permission.mission]?.outcome == .active,
      state.extraction == nil
    else { return }
    switch result {
    case .extracted(let payloads):
      guard let attempt,
        commander.miningLedger.appliedMeasuredExtraction(
          rock: NativeMeasuredExtraction.root, incident: incident.id, emitted: payloads)
      else {
        stageMeasuredSourceFailure(body: body, incident: incident)
        return
      }
      let prior = attempt.witness
      var witness = MeasuredExtractionWitness(
        operation: prior.operation, permission: prior.permission, incident: prior.incident,
        body: prior.body, emitted: payloads, equipment: prior.equipment, carrier: prior.carrier,
        inventoryRevision: prior.inventoryRevision, epoch: prior.epoch, authority: prior.operation)
      guard let authority = try? NativeMeasuredExtraction.extractionAuthority(witness) else {
        return
      }
      witness.authority = authority
      nativeMeasuredExtractionPending = .init(
        extraction: witness,
        intakes: nativeMeasuredExtractionPending?.intakes ?? [],
        losses: nativeMeasuredExtractionPending?.losses ?? [])
    case .destroyed: stageMeasuredSourceFailure(body: body, incident: incident)
    case .damaged:
      if incident.laser != .mining || incident.origin.owner != commander.flightSimulation.player {
        stageMeasuredSourceFailure(body: body, incident: incident)
      }
    case .ignored, .capacityRefused: break
    }
  }

  private mutating func stageMeasuredSourceFailure(
    body: borrowing SpaceBody, incident: CombatIncident
  ) {
    guard let source = commander.scriptState.savedMeasuredExtractionSource else { return }
    let ids = source.originals.compactMap { original -> UUID? in
      if case .unfilled = original.custody { return original.id }
      return nil
    }
    let snapshotBody = copy body
    stageMeasuredLoss(
      kind: .source, originals: ids, products: [], bodies: [snapshotBody],
      payloads: [], incident: incident, pod: nil)
  }

  func measuredPayloadIsAllocated(_ payload: PayloadIdentity) -> Bool {
    guard let original = measuredOriginal(payload), let state = measuredExtractionState,
      commander.scriptState.instances[state.permission.mission]?.outcome == .active
    else { return false }
    if case .unfilled = original.custody { return true }
    return false
  }

  func measuredExtractionFacts(_ body: SpaceBody, context: EncounterContext)
    -> NativeMeasuredExtractionSelectionFacts?
  {
    guard let payload = body.physical?.payload, measuredPayloadIsAllocated(payload),
      let physical = body.physical, physical.identity.system == context.system,
      physical.identity.visit == context.visit,
      commander.miningLedger.boundActor(for: payload) == physical.identity,
      body.energy > 0, let state = measuredExtractionState, state.extraction != nil,
      state.permission.carrier == commander.hullInstanceID
    else { return nil }
    return .init(fits: commander.cargoTonnes <= commander.standardCargoCapacity)
  }

  mutating func observeMeasuredIntake(_ body: SpaceBody) {
    guard let allocatedPayload = body.physical?.payload,
      measuredPayloadIsAllocated(allocatedPayload),
      !docked, !paused, screen.isFlight, energy > 0,
      pendingNativeStationDock == nil, let state = measuredExtractionState,
      let extraction = state.extraction,
      let source = commander.scriptState.savedMeasuredExtractionSource,
      let physical = body.physical, let payload = physical.payload,
      let original = source.originals.first(where: { $0.payload == payload }),
      body.hull == .cargo, body.energy.isFinite, body.energy > 0,
      body.position.z > 0, body.position.y < 0, body.position.length < 85,
      physical.spawnIdentity?.producer == .mining,
      physical.identity.system == systemIdentity,
      physical.identity.visit == commander.flightSimulation.visit,
      commander.miningLedger.boundActor(for: payload) == physical.identity,
      let item = commander.miningLedger.pendingPayloads.first(where: { $0.identity == payload }),
      item.amount == .init(commodity: .minerals, quantity: 1),
      let context = gameplayContext(), automaticScoopShapeCompatible(body, context: context),
      let mesh = recordRecoveryCompatibleMesh(body, context: context),
      let radius = mesh.vertices.map(\.length).max(), radius.isFinite, radius > 0,
      mesh.vertices == Mesh.hull(.cargo).vertices,
      mesh.faces == Mesh.hull(.cargo).faces,
      let player = commander.flightSimulation.player,
      let scoops = commander.fittedEquipment(at: .utility(.fuelScoops)),
      commander.targetingTier != nil, commander.fittedEquipment(at: .targetingMining) != nil,
      let inventory = try? commander.purchaseSnapshot(),
      inventory.activeHull == state.permission.carrier,
      let fitted = inventory.items.first(where: { $0.id == scoops.id }),
      commander.cargoTonnes <= commander.standardCargoCapacity
    else { return }
    let offset = body.position - Vector3(0, -45, 55)
    guard abs(offset.x) <= 16, abs(offset.y) <= 16,
      abs(offset.z) <= 16
    else { return }
    let omega =
      lastAppliedWorkMotion?.worldAngularVelocity.length ?? abs(pitch) + abs(yaw) + abs(roll)
    let speed =
      (physical.velocity - flightWorldVelocity).length
      + omega * Vector3(0, -45, 55).length + physical.angularVelocity.length * radius
    guard speed.isFinite, speed <= ScoopApproachController.maximumRelativeSpeed,
      !(nativeMeasuredExtractionPending?.intakes.contains { $0.original == original.id } ?? false)
    else { return }
    if let work = workGuidance {
      guard work.parent == physical.identity, work.mode == .autoScoop(.mining),
        lastAppliedWorkMotion?.end == commander.flightSimulation.pose
      else { return }
    }
    let operation = ScriptIdentity.uuid(
      "measured-intake-v1:\(state.permission.operation):\(original.id)")
    var capture = MeasuredIntake(
      operation: operation, permission: state.permission.operation,
      extraction: extraction.operation, original: original.id, payload: item, body: [body],
      player: player, carrier: inventory.activeHull, inventoryRevision: inventory.revision,
      scoops: fitted, relativeSpeed: speed, physicalTime: context.physicalTime,
      epoch: nativeStationRuntimeEpoch, authority: operation)
    guard let authority = try? NativeMeasuredExtraction.intakeAuthority(capture) else { return }
    capture.authority = authority
    nativeMeasuredExtractionPending = .init(
      extraction: nativeMeasuredExtractionPending?.extraction,
      intakes: (nativeMeasuredExtractionPending?.intakes ?? []) + [capture],
      losses: nativeMeasuredExtractionPending?.losses ?? [])
  }

  @inline(never)
  private mutating func stageMeasuredLoss(
    kind: MeasuredLossKind, originals: [UUID], products: [UUID], bodies: [SpaceBody],
    payloads: [TypedCargoPayload], incident: CombatIncident?, pod: EquipmentPurchaseItem?
  ) {
    guard !originals.isEmpty || !products.isEmpty, let state = measuredExtractionState,
      let player = commander.flightSimulation.player, let carrier = commander.hullInstanceID
    else { return }
    let operation = ScriptIdentity.uuid(
      "measured-loss-v1:\(state.permission.operation):\(kind.rawValue):\(originals):\(products)")
    if state.losses.contains(where: { $0.operation == operation }) { return }
    if nativeMeasuredExtractionPending?.losses.contains(where: { $0.operation == operation })
      == true
    {
      return
    }
    var loss = MeasuredLoss(
      operation: operation, kind: kind, originals: originals, products: products,
      bodies: bodies, payloads: payloads, incident: incident, player: player, carrier: carrier,
      energy: energy, escapePod: pod, physicalTime: commander.flightSimulation.physicalTime,
      epoch: nativeStationRuntimeEpoch, authority: operation)
    guard let authority = try? NativeMeasuredExtraction.lossAuthority(loss) else { return }
    loss.authority = authority
    nativeMeasuredExtractionPending = .init(
      extraction: nativeMeasuredExtractionPending?.extraction,
      intakes: (nativeMeasuredExtractionPending?.intakes ?? []).filter {
        !originals.contains($0.original)
      },
      losses: (nativeMeasuredExtractionPending?.losses ?? []) + [loss])
  }

  mutating func observeMeasuredOreDeath(_ body: SpaceBody) {
    guard body.energy <= 0, let payload = body.physical?.payload,
      let original = measuredOriginal(payload), case .unfilled = original.custody,
      commander.miningLedger.boundActor(for: payload) == body.physical?.identity,
      let item = commander.miningLedger.pendingPayloads.first(where: { $0.identity == payload })
    else { return }
    stageMeasuredLoss(
      kind: .destroyed, originals: [original.id], products: [], bodies: [body], payloads: [item],
      incident: nil, pod: nil)
  }

  mutating func recordMeasuredDeparture() throws {
    guard systemIdentity == NativeMeasuredExtraction.root.system,
      let source = commander.scriptState.savedMeasuredExtractionSource
    else { return }
    let pending = commander.miningLedger.pendingPayloads
    var ids: [UUID] = []
    var payloads: [TypedCargoPayload] = []
    for original in source.originals {
      if case .unfilled = original.custody,
        let item = pending.first(where: { $0.identity == original.payload })
      {
        ids.append(original.id)
        payloads.append(item)
      }
    }
    guard !ids.isEmpty else { return }
    stageMeasuredLoss(
      kind: .departed, originals: ids, products: [], bodies: [], payloads: payloads, incident: nil,
      pod: nil)
    // Departure expires these actual world units and changes epoch. Uncommitted intake
    // proposals cannot become aboard cargo merely because the ship leaves.
    if let pending = nativeMeasuredExtractionPending {
      nativeMeasuredExtractionPending = .init(
        extraction: pending.extraction, intakes: [], losses: pending.losses)
    }
    try applyMeasuredPending()
  }

  mutating func stageMeasuredHullLoss(pod: EquipmentPurchaseItem? = nil) {
    guard let source = commander.scriptState.savedMeasuredExtractionSource,
      let state = measuredExtractionState
    else { return }
    if screen == .gameOver && energy.isFinite && energy <= 0,
      let pending = nativeMeasuredExtractionPending
    {
      nativeMeasuredExtractionPending = .init(
        extraction: pending.extraction, intakes: [], losses: pending.losses)
    }
    let raw = NativeMeasuredExtraction.rawHeld(source)
    let products = (state.processing?.products ?? []).filter { $0.custody == .held }.map(\.id)
    if pod != nil || (screen == .gameOver && energy.isFinite && energy <= 0) {
      stageMeasuredLoss(
        kind: pod == nil ? .hull : .escape, originals: raw, products: products,
        bodies: [], payloads: [], incident: nil, pod: pod)
    }
  }

  mutating func prepareMeasuredDock() throws {
    guard let pending = nativeMeasuredExtractionPending else { return }
    nativeMeasuredExtractionPending = .init(
      extraction: pending.extraction, intakes: [], losses: pending.losses)
    try applyMeasuredPending()
  }

  func measuredEscapePod() -> EquipmentPurchaseItem? {
    guard let item = commander.fittedEquipment(at: .utility(.escapePod)),
      let snapshot = try? commander.purchaseSnapshot()
    else { return nil }
    return snapshot.items.first { $0.id == item.id }
  }

  mutating func loseMeasuredOnEscape(pod: EquipmentPurchaseItem?) throws {
    guard measuredExtractionState != nil else { return }
    if let pending = nativeMeasuredExtractionPending {
      nativeMeasuredExtractionPending = .init(
        extraction: pending.extraction, intakes: [], losses: pending.losses)
    }
    stageMeasuredHullLoss(pod: pod)
    try applyMeasuredPending()
  }

  @discardableResult
  mutating func applyMeasuredPending() throws -> Bool {
    guard let pending = nativeMeasuredExtractionPending else { return false }
    guard var state = measuredExtractionState,
      var source = commander.scriptState.savedMeasuredExtractionSource,
      var mission = commander.scriptState.instances[state.permission.mission]
    else { throw SaveError.invalidCommander }
    if let witness = pending.extraction, state.extraction == nil {
      guard
        NativeMeasuredExtractionSave.witnessValid(
          witness, source: source, state: state, commander: commander)
      else { throw SaveError.invalidCommander }
      state.extraction = witness
      mission.milestones.insert(1)
    }
    for intake in pending.intakes {
      if state.captures.contains(where: { $0.operation == intake.operation }) { continue }
      guard mission.outcome == .active,
        let index = source.originals.firstIndex(where: { $0.id == intake.original }),
        source.originals[index].custody == .unfilled,
        intake.epoch == nativeStationRuntimeEpoch,
        intake.carrier == commander.hullInstanceID,
        intake.inventoryRevision == commander.equipmentInventory?.revision,
        let body = bodies.firstIndex(where: {
          $0.physical?.identity == intake.body.first?.physical?.identity
        }),
        bodies[body].energy > 0,
        NativeMeasuredExtractionSave.intakeValid(
          intake, source: source, state: state, commander: commander),
        commander.miningLedger.takeMeasuredOriginal(.init(intake)) != nil
      else { throw SaveError.invalidCommander }
      source.originals[index].custody = .raw(intake.operation)
      state.captures.append(intake)
      workTargetCollected(bodies[body])
      bodies.remove(at: body)
    }
    if state.captures.count == 12 { mission.milestones.insert(2) }
    for loss in pending.losses {
      if state.losses.contains(where: { $0.operation == loss.operation }) { continue }
      guard
        NativeMeasuredExtractionSave.lossValid(
          loss, source: source, state: state, commander: commander)
      else { throw SaveError.invalidCommander }
      for index in source.originals.indices
      where loss.originals.contains(source.originals[index].id) {
        source.originals[index].custody = .lost(loss.operation)
      }
      if var processing = state.processing {
        for index in processing.products.indices
        where loss.products.contains(processing.products[index].id) {
          processing.products[index].custody = .lost(loss.operation)
        }
        state.processing = processing
      }
      state.losses.append(loss)
    }
    commander.scriptState.savedMeasuredExtractionSource = source
    mission.savedMeasuredExtraction = state
    mission.payloads = NativeMeasuredExtraction.payloads(
      source, state: state, outcome: mission.outcome)
    commander.scriptState.instances[mission.id] = mission
    if !state.losses.isEmpty && mission.outcome == .active {
      try finishMeasuredExtraction(state, outcome: .failed)
    }
    nativeMeasuredExtractionPending = nil
    return true
  }
}

extension GameRuntime {
  func commitMeasuredExtraction() {
    guard game.measuredExtractionState != nil else { return }
    game.stageMeasuredHullLoss()
    guard game.nativeMeasuredExtractionPending != nil, let publish = scriptPublisher() else {
      return
    }
    var candidate = game
    do {
      guard try candidate.applyMeasuredPending() else { return }
      try publish(&candidate)
      game = candidate
      game.notify("MEASURED EXTRACTION CUSTODY SAVED")
    } catch { game.notify("EXTRACTION CUSTODY NOT SAVED - SAME NATIVE ATTEMPT RETAINED") }
  }
}
