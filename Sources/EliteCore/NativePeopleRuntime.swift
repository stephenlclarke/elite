import Foundation

public struct NativePodSelectionFacts: Sendable, Equatable {
  let person: EMPCrewIdentity
  let fits: Bool
}

enum NativePeopleInteraction: Sendable, Equatable { case pod, crew }
struct NativePeopleFailureGate: Sendable, Equatable {
  let kind: NativePeopleInteraction
  let subject: ActorIdentity
  let player: ActorIdentity
  let owner: UUID
  let hull: UUID
  let tool: UUID
  let inventoryRevision: UInt64
  let epoch: UUID
}

/// Issued and consumed in one actor turn; saved facts and target-selection flags cannot mint it.
private struct NativePeopleCaptureSeal {
  let gate: NativePeopleFailureGate
  let source: ActorIdentity
  let ordinals: [Int]
  var count: Int { ordinals.count }
  let physicalTime: Double
  let revision: UInt64
  let operation: UUID
}

extension Game {
  var freeNativePeopleTonnes: Int {
    guard let mass = commander.checkedCargoTonnes, mass >= 0,
      mass <= commander.standardCargoCapacity
    else { return 0 }
    return commander.standardCargoCapacity - mass
  }
  var hasNativeRescueTools: Bool {
    commander.targetingTier != nil
      && commander.fittedEquipment(at: .targetingSalvage) != nil
      && commander.fittedEquipment(at: .utility(.fuelScoops)) != nil
  }
  func nativePodFacts(_ body: SpaceBody, context: EncounterContext) -> NativePodSelectionFacts? {
    guard let physical = body.physical, let person = physical.empCrewPod,
      let record = commander.savedEMPState?.records[person.source], record.valid,
      let podIndex = record.podIndex(for: person.ordinal), commander.worldOwnedPod(person),
      record.pods[podIndex].binding == physical.identity,
      physical.identity.system == context.system, physical.identity.visit == context.visit,
      person.source.system == context.system,
      bodies.filter({ $0.physical?.identity == physical.identity }).count == 1,
      body.hull == .cargo, body.energy.isFinite, body.energy > 0,
      physical.catalogueShipID == "SH040", physical.npc == nil, physical.payload == nil,
      physical.empSource == nil, body.missionActorID == nil, body.scriptNPC == nil,
      body.blackjackIdentity == nil,
      physical.spawnIdentity?.producer == .emp,
      physical.spawnIdentity?.sequence == record.sequence,
      physical.spawnIdentity?.member == UInt16(person.ordinal + 1),
      physical.salvage?.category == .occupiedPod, physical.salvage?.ownership == .occupied,
      physical.salvage?.claimant == person.source,
      // Protection from harm is required; an independent mission claim still forbids rescue.
      body.gameplayProtectionReasons == .empCrewPod,
      context.protection.protectedActors.contains(physical.identity)
    else { return nil }
    return .init(person: person, fits: freeNativePeopleTonnes > 0)
  }
  func nativeCrewCaptureAvailable(_ body: SpaceBody, context: EncounterContext) -> Bool {
    guard let physical = body.physical, let source = physical.empSource,
      let record = commander.savedEMPState?.records[source], record.valid,
      isEMPDisabled(body), record.hull.binding == physical.identity,
      body.energy > 0, record.crewAboard > 0,
      record.crewDeadline.map({ context.physicalTime < $0 }) == true,
      !record.disableEpisodes.isEmpty,
      physical.identity.system == context.system, physical.identity.visit == context.visit,
      !context.protection.protectedActors.contains(physical.identity)
    else { return false }
    return true
  }
  private func podInsideRescueAperture(_ body: SpaceBody) -> Bool {
    let radius = gameplayMesh(for: body).vertices.map(\.length).max() ?? .infinity
    let offset = body.position - Vector3(0, -45, 55)
    guard radius.isFinite, radius > 0, radius <= 16, offset.finite,
      body.position.z > 0, body.position.y < 0, body.position.length < 85,
      abs(offset.x) + radius <= 16, abs(offset.y) + radius <= 16,
      abs(offset.z) + radius <= 16, let physical = body.physical,
      physical.velocity.finite, physical.angularVelocity.finite, flightWorldVelocity.finite
    else { return false }
    let omega: Double
    if workGuidance != nil || workBraking != nil {
      omega = lastAppliedWorkMotion?.worldAngularVelocity.length ?? 0
    } else {
      omega = abs(pitch) + abs(yaw) + abs(roll)
    }
    let speed =
      (physical.velocity - flightWorldVelocity).length
      + omega * Vector3(0, -45, 55).length + physical.angularVelocity.length * radius
    return speed.isFinite && speed <= ScoopApproachController.maximumRelativeSpeed
  }
  fileprivate func nativePeopleCaptureSeal(fire: Bool) -> NativePeopleCaptureSeal? {
    guard !docked, !paused, screen != .gameOver, energy.isFinite, energy > 0,
      jumpCountdown == nil, pendingNativeStationDock == nil, hasNativeRescueTools,
      commander.valid, let context = gameplayContext(),
      let owner = commander.equipmentOwnerID, let hull = commander.hullInstanceID,
      let inventory = commander.equipmentInventory,
      let scoops = commander.fittedEquipment(at: .utility(.fuelScoops)),
      scoops.location?.hullInstanceID == hull
    else { return nil }
    let pods = bodies.compactMap { body -> (SpaceBody, NativePodSelectionFacts)? in
      guard let facts = nativePodFacts(body, context: context), facts.fits,
        automaticScoopShapeCompatible(body, context: context), podInsideRescueAperture(body)
      else { return nil }
      if let work = workGuidance {
        guard work.parent == body.physical?.identity, work.mode == .autoScoop(.salvage),
          lastAppliedWorkMotion?.end == commander.flightSimulation.pose
        else { return nil }
      }
      return (body, facts)
    }.sorted {
      NativePersonReference.emp($0.1.person).key < NativePersonReference.emp($1.1.person).key
    }
    if let (body, facts) = pods.first, let actor = body.physical?.identity {
      return .init(
        gate: .init(
          kind: .pod, subject: actor, player: context.player.identity,
          owner: owner, hull: hull, tool: scoops.id, inventoryRevision: inventory.revision,
          epoch: nativeStationRuntimeEpoch),
        source: facts.person.source, ordinals: [facts.person.ordinal],
        physicalTime: context.physicalTime, revision: context.revision, operation: UUID())
    }
    guard fire, screen == .front, !workFireSuspended, selectedFlightTool == .salvageCutter,
      workGuidance == nil || workGuidance?.holding == true,
      let cutter = commander.fittedEquipment(at: .utility(.salvageCutter)),
      commander.performance.workTools?.contains(.salvageCutter) == true,
      let contact = try? nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 300, radius: 0, includePlayer: false
      ),
      case .body(let id) = contact.hit.target,
      let body = bodies.first(where: { $0.id == id }),
      nativeCrewCaptureAvailable(body, context: context),
      let actor = body.physical?.identity, let source = body.physical?.empSource,
      let record = commander.savedEMPState?.records[source],
      let profile = body.physical?.catalogueShipID.flatMap({
        SalvageCatalogue.empProfile(catalogueShipID: $0)
      }),
      freeNativePeopleTonnes > 0
    else { return nil }
    let pose = modelPose(of: body)
    let hit = commander.flightSimulation.pose.systemPoint(contact.hit.point)
    guard
      profile.sections.contains(where: { section in
        let point = pose.systemPoint(section.localPosition)
        return (point - hit).length <= max(1, section.radius)
          && pose.orientation.apply(section.normal).dot(
            commander.flightSimulation.pose.position - point) > 0
      })
    else { return nil }
    return .init(
      gate: .init(
        kind: .crew, subject: actor, player: context.player.identity, owner: owner,
        hull: hull, tool: cutter.id, inventoryRevision: inventory.revision,
        epoch: nativeStationRuntimeEpoch),
      source: source, ordinals: Array(record.aboardOrdinals.prefix(freeNativePeopleTonnes)),
      physicalTime: context.physicalTime,
      revision: context.revision, operation: UUID())
  }
  fileprivate mutating func applyNativePeopleCapture(
    _ seal: NativePeopleCaptureSeal, fire: Bool, elapsed: Double
  ) throws {
    guard let actual = nativePeopleCaptureSeal(fire: fire), actual.gate == seal.gate,
      actual.source == seal.source, actual.ordinals == seal.ordinals,
      actual.physicalTime == seal.physicalTime, actual.revision == seal.revision,
      elapsed.isFinite, elapsed > 0, elapsed <= 0.1, persistEMPState(),
      var record = commander.savedEMPState?.records[seal.source],
      let index = bodies.firstIndex(where: { $0.physical?.identity == seal.gate.subject })
    else { throw SaveError.invalidCommander }
    var state = commander.nativePeople ?? .init(owner: seal.gate.owner)
    guard state.owner == seal.gate.owner,
      state.admissions.count <= NativePeopleCustodyState.maximumPeople - seal.count,
      state.revision < UInt64(NativePeopleCustodyState.maximumPeople * 2)
    else { throw SaveError.invalidCommander }
    state.revision += 1
    let origin: NativePeopleOrigin = seal.gate.kind == .pod ? .rescuedPod : .capturedCrew
    for ordinal in seal.ordinals {
      let person = NativePersonReference.emp(.init(source: seal.source, ordinal: ordinal))
      guard !state.admissions.contains(where: { $0.person == person }) else {
        throw SaveError.invalidCommander
      }
      state.admissions.append(
        .init(
          person: person, origin: origin, operation: seal.operation,
          actor: seal.gate.subject, collector: seal.gate.player, owner: seal.gate.owner,
          hull: seal.gate.hull, tool: seal.gate.tool,
          inventoryRevision: seal.gate.inventoryRevision,
          physicalTime: seal.physicalTime, epoch: seal.gate.epoch, revision: state.revision))
    }
    if seal.gate.kind == .pod {
      guard let ordinal = seal.ordinals.first, let podIndex = record.podIndex(for: ordinal)
      else { throw SaveError.invalidCommander }
      record.pods[podIndex].binding = nil
      workTargetCollected(bodies[index])
      bodies.remove(at: index)
    } else {
      let energyCost = elapsed * 2
      let heatCost = elapsed * 6
      guard energy > energyCost, laserHeat.isFinite, laserHeat + heatCost < 240,
        commander.cargo[3] <= Int.max / 17 - seal.count
      else { throw SaveError.invalidCommander }
      record.crewCaptures.append(
        .init(
          operation: seal.operation, ordinals: seal.ordinals,
          episode: record.currentCrewDisableIncident.id,
          actor: seal.gate.subject, collector: seal.gate.player,
          owner: seal.gate.owner, hull: seal.gate.hull, tool: seal.gate.tool,
          physicalTime: seal.physicalTime))
      commander.cargo[3] += seal.count
      energy -= energyCost
      laserHeat += heatCost
      laserFlash = 0.08
      dischargeAudio.record(.salvageCutter)
      if record.crewAboard == 0 {
        bodies[index].physical?.npc = nil
        bodies[index].physical?.population = .wreck
        bodies[index].physical?.blocksNavalEncounter = false
        bodies[index].hostile = false
        if let old = bodies[index].physical?.salvage {
          bodies[index].physical?.salvage = .init(
            category: .wreck, ownership: .abandoned,
            claimant: nil, wreck: old.wreck, section: old.section, lot: old.lot,
            bounds: old.bounds, workSurfaces: old.workSurfaces)
        }
        record.hull = .init(
          body: bodies[index], pose: commander.flightSimulation.pose, time: seal.physicalTime)
      }
    }
    commander.savedEMPState?.records[seal.source] = record
    commander.savedNativePeopleCustody = state
    guard commander.valid,
      commander.savedEMPState?.sceneIsConsistent(
        bodies, flight: commander.flightSimulation, people: state) == true
    else { throw SaveError.invalidCommander }
  }

  func nativePeopleInteractionPresent(_ gate: NativePeopleFailureGate, fire: Bool) -> Bool {
    guard gate.epoch == nativeStationRuntimeEpoch, gate.owner == commander.equipmentOwnerID,
      gate.player == commander.flightSimulation.player,
      let body = bodies.first(where: { $0.physical?.identity == gate.subject })
    else { return false }
    if gate.kind == .pod { return podInsideRescueAperture(body) }
    guard fire,
      let contact = try? nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 300, radius: 0, includePlayer: false
      ),
      case .body(let id) = contact.hit.target
    else { return false }
    return id == body.id
  }
}

extension GameRuntime {
  func commitNativePeopleCapture(startTime: Double, startPlayer: ActorIdentity?, delta: Double) {
    guard startTime.isFinite, game.commander.flightSimulation.physicalTime > startTime,
      startPlayer == game.commander.flightSimulation.player
    else { return }
    if let failed = nativePeopleFailureGate,
      !game.nativePeopleInteractionPresent(failed, fire: controls.fire)
    {
      nativePeopleFailureGate = nil
    }
    guard let publish = scriptPublisher(),
      let seal = game.nativePeopleCaptureSeal(fire: controls.fire),
      nativePeopleFailureGate != seal.gate
    else { return }
    var candidate = game
    do {
      try candidate.applyNativePeopleCapture(seal, fire: controls.fire, elapsed: min(delta, 0.1))
      try publish(&candidate)
      game = candidate
      nativePeopleFailureGate = nil
      game.notify(
        seal.gate.kind == .pod
          ? "ESCAPE POD RESCUED - PROTECTED 1T" : "CREW CAPTURED - SLAVES IN HOLD")
    } catch {
      nativePeopleFailureGate = seal.gate
      game.notify("CAPTURE NOT SAVED - SAVE TO RETRY OR LEAVE AND RETURN")
    }
  }
}
