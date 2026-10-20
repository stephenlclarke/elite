import Foundation

/// Selection facts are descriptive. Only the same-turn collector can issue a capture seal.
public struct NativeOriginalRescueSelectionFacts: Sendable, Equatable {
  let logicalActor: UUID
  let alias: String
  let fits: Bool
  let isPerson: Bool
}

private struct NativeOriginalRescueCaptureSeal {
  let gate: NativePeopleFailureGate
  let alias: String
  let logicalActor: UUID
  let time: Double
  let revision: UInt64
  let tool: EquipmentPurchaseItem
  let operation: UUID
}

extension NativeOriginalRescueJourney {
  static let recordCaptureReceiptPrefix = "original-rescue-record-"

  static func recordCaptureReceipt(_ operation: UUID) -> String {
    recordCaptureReceiptPrefix + operation.uuidString.lowercased()
  }

  @inline(never)
  static func consumed(_ actor: UUID, commander: borrowing Commander) -> Bool {
    guard let custody = commander.nativePeople, let state = custody.originalRescue,
      state.owner == commander.equipmentOwnerID, state.definition.valid,
      state.version == "1.0.0", state.digest == digest
    else { return false }
    if let capture = state.captures.first(where: { $0.logicalActor == actor }) {
      guard let ordinal = aliases.prefix(2).firstIndex(of: capture.alias),
        state.references.indices.contains(ordinal),
        let admission = custody.admissions.first(where: { $0.person == state.references[ordinal] }),
        validAdmission(admission, commander: commander)
      else { return false }
      return captureValid(capture, state: state, commander: commander)
    }
    guard let record = state.record, record.logicalActor == actor,
      record.alias == "emergency-record", let boarding = state.boarding,
      record.physicalTime >= boarding.physicalTime
    else { return false }
    return captureValid(record, state: state, commander: commander)
  }
  static func marker(_ body: borrowing SpaceBody, commander: borrowing Commander) -> Bool {
    guard let mission = body.missionInstanceID, let actor = body.missionActorID else {
      return false
    }
    for index in commander.scriptState.instances.indices {
      if commander.scriptState.instances.keys[index] == mission {
        if commander.scriptState.instances.values[index].definition == stateID { return true }
      }
    }
    guard let state = commander.nativePeople?.originalRescue, state.mission == mission else {
      return false
    }
    return aliases.contains { actorIdentity(mission: mission, alias: $0) == actor }
  }
}

extension Game {
  @inline(never)
  func originalRescueFacts(_ body: borrowing SpaceBody, context: EncounterContext)
    -> NativeOriginalRescueSelectionFacts?
  {
    let currentBody = copy body
    let currentBodies = bodies
    return withReadOnlyCommander { commander in
      Self.originalRescueFacts(
        currentBody, context: context, commander: commander, bodies: currentBodies)
    }
  }

  @inline(never)
  private static func originalRescueFacts(
    _ body: borrowing SpaceBody, context: borrowing EncounterContext,
    commander: borrowing Commander, bodies: borrowing [SpaceBody]
  ) -> NativeOriginalRescueSelectionFacts? {
    guard let state = commander.nativePeople?.originalRescue, state.terminalOperation == nil,
      state.owner == commander.equipmentOwnerID, state.definition.valid,
      state.version == "1.0.0", state.digest == NativeOriginalRescueJourney.digest,
      state.carrier == commander.hullInstanceID, state.registration.commanderOwner == state.owner,
      let actor = body.physical?.identity, actor.system == context.system,
      actor.visit == context.visit, body.physical?.population == .mission,
      body.physical?.spawnIdentity?.producer == .mission,
      body.physical?.spawnIdentity?.system == actor.system,
      body.physical?.spawnIdentity?.visit == actor.visit,
      let spawn = body.physical?.spawnIdentity?.sequence,
      spawn > 0, spawn < commander.flightSimulation.nextSpawn,
      context.system == SystemIdentity(galaxy: 0, system: 85),
      let logical = body.missionActorID, body.missionInstanceID == state.mission,
      let alias = NativeOriginalRescueJourney.aliases.first(where: {
        NativeOriginalRescueJourney.actorIdentity(mission: state.mission, alias: $0) == logical
      }),
      !NativeOriginalRescueJourney.consumed(logical, commander: commander),
      NativeOriginalRescueJourney.liveActorMatches(
        commander: commander, mission: state.mission, alias: alias,
        logical: logical, bodyID: body.id, actor: actor),
      body.energy.isFinite, body.energy > 0,
      body.physical?.empCrewPod == nil, body.physical?.empSource == nil,
      body.physical?.payload == nil, body.blackjackIdentity == nil,
      body.scriptNPC?.fit.definition.model == "catalogue:SH040",
      body.scriptNPC?.fit.definition.scale == 1,
      body.scriptNPC?.fit.definition.speed == 0,
      body.scriptNPC?.fit.definition.lasers?.isEmpty ?? true
    else { return nil }
    var matchingActors = 0
    for index in bodies.indices {
      if bodies[index].physical?.identity == actor { matchingActors += 1 }
    }
    guard matchingActors == 1 else { return nil }
    let isPerson = alias != "emergency-record"
    let held = commander.nativePeople?.heldPods.contains(where: { $0.person.rescue != nil }) == true
    let ready = isPerson || state.boarding != nil
    let fits: Bool
    if ready && !held {
      let cargoTonnes = commander.cargoTonnes
      let capacity = commander.standardCargoCapacity
      fits = cargoTonnes <= capacity
    } else {
      fits = false
    }
    return .init(logicalActor: logical, alias: alias, fits: fits, isPerson: isPerson)
  }

  /// Registered original actors share one actual geometry across capture and work guidance.
  @inline(never)
  func originalRescueCompatibleMesh(
    _ body: borrowing SpaceBody, context: EncounterContext? = nil
  ) -> Mesh? {
    guard NativeOriginalRescueJourney.marker(body, commander: commander) else {
      return gameplayMesh(for: body)
    }
    guard let current = context ?? gameplayContext(),
      originalRescueFacts(body, context: current) != nil
    else { return nil }
    return scriptNPCMesh(body)
  }

  @inline(never)
  func originalRescueMetadata(_ body: borrowing SpaceBody, context: EncounterContext)
    -> SalvageTargetMetadata?
  {
    guard let facts = originalRescueFacts(body, context: context) else { return nil }
    return .init(
      category: facts.isPerson ? .occupiedPod : .cargo, ownership: .missionProtected,
      claimant: nil, wreck: nil, section: nil, lot: nil,
      bounds: .init(center: .init(0, 0, 0), radius: 5.892836433645515), workSurfaces: [])
  }

  fileprivate func originalRescueSeal() -> NativeOriginalRescueCaptureSeal? {
    guard !docked, !paused, screen != .gameOver, energy.isFinite, energy > 0,
      jumpCountdown == nil, pendingNativeStationDock == nil, hasNativeRescueTools,
      commander.valid, let context = gameplayContext(),
      let owner = commander.equipmentOwnerID, let hull = commander.hullInstanceID,
      let inventory = commander.equipmentInventory,
      let scoops = commander.fittedEquipment(at: .utility(.fuelScoops)),
      scoops.location?.hullInstanceID == hull,
      let purchase = try? commander.purchaseSnapshot(),
      let tool = purchase.items.first(where: { $0.id == scoops.id })
    else { return nil }
    for index in bodies.indices {
      guard let facts = originalRescueFacts(bodies[index], context: context), facts.fits,
        automaticScoopShapeCompatible(bodies[index], context: context),
        podInsideRescueAperture(bodies[index]), let actor = bodies[index].physical?.identity
      else { continue }
      if let work = workGuidance {
        guard work.parent == actor, work.mode == .autoScoop(.salvage),
          lastAppliedWorkMotion?.end == commander.flightSimulation.pose
        else { continue }
      }
      return .init(
        gate: .init(
          kind: .pod, subject: actor, player: context.player.identity,
          owner: owner, hull: hull, tool: scoops.id, inventoryRevision: inventory.revision,
          epoch: nativeStationRuntimeEpoch),
        alias: facts.alias, logicalActor: facts.logicalActor, time: context.physicalTime,
        revision: context.revision, tool: tool, operation: UUID())
    }
    return nil
  }

  // Retire the mission mutation before the candidate reaches the save publisher.
  @inline(never)
  private mutating func retainOriginalRescueRecordReceipt(mission id: UUID, operation: UUID) throws
  {
    guard var mission = commander.scriptState.instances[id],
      mission.definition == NativeOriginalRescueJourney.stateID,
      mission.digest == NativeOriginalRescueJourney.digest, mission.outcome == .active,
      mission.receipts.count < 4096,
      !mission.receipts.contains(where: {
        $0.hasPrefix(NativeOriginalRescueJourney.recordCaptureReceiptPrefix)
      })
    else { throw SaveError.invalidCommander }
    mission.receipts.insert(NativeOriginalRescueJourney.recordCaptureReceipt(operation))
    commander.scriptState.instances[id] = mission
  }

  @inline(never)
  fileprivate mutating func applyOriginalRescueCapture(_ seal: NativeOriginalRescueCaptureSeal)
    throws
  {
    guard let actual = originalRescueSeal(), actual.gate == seal.gate,
      actual.alias == seal.alias, actual.logicalActor == seal.logicalActor,
      actual.time == seal.time, actual.revision == seal.revision, actual.tool == seal.tool,
      var custody = commander.nativePeople, var state = custody.originalRescue,
      let index = bodies.firstIndex(where: { $0.physical?.identity == seal.gate.subject }),
      custody.revision < UInt64(NativePeopleCustodyState.maximumPeople * 2)
    else { throw SaveError.invalidCommander }
    let capture = NativeOriginalRescueCapture(
      authority: try NativeOriginalRescueJourney.captureAuthority(
        operation: seal.operation,
        actor: seal.gate.subject, tool: seal.tool, inventory: seal.gate.inventoryRevision,
        epoch: seal.gate.epoch, time: seal.time),
      operation: seal.operation, logicalActor: seal.logicalActor, alias: seal.alias,
      actor: seal.gate.subject, collector: seal.gate.player, owner: seal.gate.owner,
      carrier: seal.gate.hull, tool: seal.tool, inventoryRevision: seal.gate.inventoryRevision,
      physicalTime: seal.time, epoch: seal.gate.epoch,
      revision: seal.alias == "emergency-record" ? custody.revision : custody.revision + 1)
    if seal.alias == "emergency-record" {
      guard state.record == nil, state.boarding != nil else { throw SaveError.invalidCommander }
      try retainOriginalRescueRecordReceipt(mission: state.mission, operation: capture.operation)
      state.record = capture
    } else {
      guard let ordinal = NativeOriginalRescueJourney.aliases.prefix(2).firstIndex(of: seal.alias),
        state.captures.count < 2,
        custody.admissions.count < NativePeopleCustodyState.maximumPeople
      else { throw SaveError.invalidCommander }
      let person = NativePersonReference.rescue(
        .init(
          owner: state.owner,
          batch: NativeOriginalRescueJourney.batch, ordinal: ordinal))
      guard !custody.admissions.contains(where: { $0.person == person }) else {
        throw SaveError.invalidCommander
      }
      custody.revision += 1
      custody.admissions.append(
        .init(
          person: person, origin: .originalRescuedPod, operation: capture.operation,
          actor: capture.actor, collector: capture.collector, owner: capture.owner,
          hull: capture.carrier, tool: capture.tool.id,
          inventoryRevision: capture.inventoryRevision,
          physicalTime: capture.physicalTime, epoch: capture.epoch, revision: custody.revision))
      state.captures.append(capture)
    }
    // Actual consumption uses the existing non-death removal path. Retained capture proof,
    // rather than a new presence enum or an energy edit, prevents occupied reprojection.
    let body = bodies[index]
    recordScriptActorRemoval(body, destroyed: false)
    workTargetCollected(body)
    bodies.remove(at: index)
    custody.originalRescue = state
    commander.savedNativePeopleCustody = custody
  }
}

extension GameRuntime {
  /// Reuses the post-motion native people seam; no tick/render caller can assert collection.
  @inline(never)
  func commitOriginalRescueCapture(startTime: Double, startPlayer: ActorIdentity?) -> Bool {
    guard game.commander.nativePeople?.originalRescue != nil else { return false }
    guard startTime.isFinite, startPlayer == game.commander.flightSimulation.player else {
      return false
    }
    let interval = game.commander.flightSimulation.physicalTime - startTime
    guard interval > 0, interval <= 0.1 + 1e-9, let seal = game.originalRescueSeal() else {
      return false
    }
    if nativePeopleFailureGate == seal.gate { return true }
    guard let publish = scriptPublisher() else { return true }
    var candidate = game
    do {
      try candidate.applyOriginalRescueCapture(seal)
      guard candidate.commander.valid else { throw SaveError.invalidCommander }
      try publish(&candidate)
      game = candidate
      nativePeopleFailureGate = nil
      game.notify(
        seal.alias == "emergency-record"
          ? "ORIGINAL EMERGENCY RECORD RECOVERED - PROTECTED 1T"
          : "ORIGINAL LIVING CAPSULE RECOVERED - PROTECTED 1T")
    } catch {
      nativePeopleFailureGate = seal.gate
      game.notify("ORIGINAL RESCUE NOT SAVED - SAVE TO RETRY OR LEAVE AND RETURN")
    }
    return true
  }
}
