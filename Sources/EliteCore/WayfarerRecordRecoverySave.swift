import Foundation

enum WayfarerRecordRecoverySave {
  static let version = 53
  static let alienVersion = 54
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func lowerSchema(_ schema: Int?) -> Int? {
    guard contains(schema) else { return schema }
    return schema == alienVersion
      ? NativeIdentifiedSalvageSave.alienVersion : NativeIdentifiedSalvageSave.version
  }

  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    if commander.scriptState.savedRecordRecoverySource != nil { return true }
    for mission in commander.scriptState.instances.values {
      if mission.definition == WayfarerRecordRecovery.stateID
        || mission.digest == WayfarerRecordRecovery.digest || mission.savedRecordRecovery != nil
      {
        return true
      }
    }
    for board in commander.contracts.boards.values {
      if board.group == WayfarerRecordRecovery.stateID
        || board.digest == WayfarerRecordRecovery.digest
        || (board.provider == "l337.wayfarer-service" && board.id == WayfarerRecordRecovery.boardID)
      {
        return true
      }
    }
    return false
  }

  /// Native damage may transiently precede its durable loss record. Cold/publication gates
  /// require that record; this does not roll actual destruction back after a refused writer.
  static func validateClaims(
    _ commander: borrowing Commander, requireRecordedLoss: Bool = false
  ) -> Bool {
    guard let source = commander.scriptState.savedRecordRecoverySource else {
      return !hasClaims(commander)
    }
    guard source.batch == WayfarerRecordRecovery.batch, source.owner.valid,
      source.owner.world == commander.equipmentOwnerID,
      source.owner.system == SystemIdentity(galaxy: 0, system: 85),
      source.id == WayfarerRecordRecovery.sourceIdentity(source.owner),
      WayfarerRecordRecovery.originalIdentitiesValid(source),
      source.registration.station == source.owner,
      historicalDock(source.registration, commander: commander),
      let mission = commander.scriptState.instances[source.allocatedMission],
      let state = mission.savedRecordRecovery,
      stateValid(
        state, instance: mission, source: source, commander: commander,
        requireRecordedLoss: requireRecordedLoss)
    else { return false }
    var missions = 0
    for instance in commander.scriptState.instances.values {
      if instance.definition == WayfarerRecordRecovery.stateID
        || instance.digest == WayfarerRecordRecovery.digest
        || instance.savedRecordRecovery != nil
      {
        guard instance.id == mission.id else { return false }
        missions += 1
      }
    }
    var boards = 0
    for board in commander.contracts.boards.values {
      if board.group == WayfarerRecordRecovery.stateID
        || board.digest == WayfarerRecordRecovery.digest
        || (board.provider == "l337.wayfarer-service" && board.id == WayfarerRecordRecovery.boardID)
      {
        guard board.id == WayfarerRecordRecovery.boardID,
          board.digest == WayfarerRecordRecovery.digest,
          board.group == WayfarerRecordRecovery.stateID
        else { return false }
        boards += 1
      }
    }
    return missions == 1 && boards == 1
  }

  static func historicalDock(_ dock: NativeMainStationDockReceipt, commander: borrowing Commander)
    -> Bool
  {
    guard dock.valid, dock.commanderOwner == commander.equipmentOwnerID,
      let stations = commander.nativeStations, stations.mainStations.contains(dock.station),
      dock.sequence < stations.nextMainDockSequence,
      dock.actor.visit <= commander.flightSimulation.visit,
      dock.calendarSeconds <= commander.scriptState.calendarSeconds
    else { return false }
    return true
  }

  @inline(never)
  private static func stateValid(
    _ state: borrowing WayfarerRecordRecoveryState, instance: borrowing ScriptInstance,
    source: borrowing WayfarerRecordRecoverySource, commander: borrowing Commander,
    requireRecordedLoss: Bool
  ) -> Bool {
    let permission = state.permission
    guard state.definition.valid, state.source == source.id,
      permission.source == source.id, permission.mission == instance.id,
      permission.operation
        == ScriptIdentity.uuid("record-recovery-permit-v1:\(source.id):\(instance.id)"),
      permission.dock == source.registration,
      permission.collector.entity == 0,
      permission.collector.system == source.owner.system,
      permission.collector.visit == permission.dock.actor.visit,
      permission.reach.valid, permission.reach.revision == "elite-canonical-native-reach-v2",
      permission.path == [85, 241, 85],
      WayfarerRecordRecovery.route(reach: permission.reach) == permission.path,
      permission.physicalTime.isFinite, permission.physicalTime >= 0,
      permission.physicalTime <= commander.flightSimulation.physicalTime,
      instance.definition == WayfarerRecordRecovery.stateID,
      instance.digest == WayfarerRecordRecovery.digest, instance.version == "1.0.0",
      let job = instance.contract, job.provider == "l337.wayfarer-service",
      job.version == instance.version,
      job.digest == instance.digest, job.station == WayfarerRecordRecovery.source,
      job.group == WayfarerRecordRecovery.stateID, job.boardRevision == 0,
      job.boardKey == instance.digest + "/record-recovery/" + WayfarerRecordRecovery.source.key,
      job.offer.key == WayfarerRecordRecovery.batch,
      job.offer.id
        == ScriptIdentity.uuid(
          "contract-offer-v1:\(job.boardKey):0:\(WayfarerRecordRecovery.batch)"),
      Game.contractJobIdentity(job.offer.id) == instance.id,
      job.offer.reward == WayfarerRecordRecovery.reward, job.offer.deposit == 0,
      job.offer.failureReward == 0, !job.offer.refundOnFailure,
      job.offer.destinationGalaxy == 0, job.offer.destinationSystem == 85,
      job.offer.duration == 0, job.deadline == nil, job.clock == .local,
      let board = commander.contracts.boards[job.boardKey],
      board.id == WayfarerRecordRecovery.boardID, board.provider == job.provider,
      board.version == job.version, board.digest == job.digest,
      board.group == job.group, board.station == job.station, board.revision == 0,
      board.offers.count == 1, board.offers.first?.id == job.offer.id,
      board.offers.first?.status == .accepted(instance.id),
      state.captures.count <= 1, state.losses.count <= 1,
      instance.payloads
        == WayfarerRecordRecovery.payloads(state, outcome: instance.outcome, source: source)
    else { return false }
    var originals: Set<UUID> = []
    var actors: Set<ActorIdentity> = []
    var milestones: Set<Int> = [0]
    if let identification = state.identification {
      guard identificationValid(identification, state: state, source: source, commander: commander)
      else { return false }
      milestones.insert(1)
    }
    for index in state.captures.indices {
      let originalID = state.captures[index].original
      guard captureValid(state.captures[index], state: state, source: source, commander: commander),
        originals.insert(state.captures[index].original).inserted,
        actors.insert(state.captures[index].actor).inserted,
        let ordinal = source.originals.firstIndex(where: { $0.id == originalID })
      else { return false }
      milestones.insert(ordinal + 2)
    }
    var lost: Set<UUID> = []
    for index in state.losses.indices {
      guard
        lossValid(
          state.losses[index], state: state, source: source, instance: instance,
          commander: commander),
        lost.insert(state.losses[index].original).inserted
      else { return false }
    }
    for original in source.originals {
      let id = original.id
      let capture = state.captures.first { $0.original == id }
      let loss = state.losses.first { $0.original == id }
      let returned = state.reception?.originals.contains(id) == true
      switch original.custody {
      case .cradle:
        guard capture == nil, loss == nil, !returned else { return false }
      case .held(let operation, let carrier):
        guard capture?.operation == operation, capture?.carrier == carrier,
          loss == nil, !returned
        else { return false }
      case .returned(let operation):
        guard capture != nil, loss == nil, returned, state.reception?.operation == operation
        else { return false }
      case .lost(let operation):
        guard loss?.operation == operation, !returned else { return false }
      }
    }
    if requireRecordedLoss {
      for (index, original) in source.originals.enumerated() {
        if instance.ownedEncounters[WayfarerRecordRecovery.encounterID]?.actors[
          WayfarerRecordRecovery.aliases[index]]?.presence == .destroyed
        {
          guard lost.contains(original.id) else { return false }
        }
      }
    }
    if instance.outcome == .active {
      guard state.losses.isEmpty, state.reception == nil,
        commander.hullInstanceID == permission.carrier
      else { return false }
    }
    if !state.held.isEmpty {
      guard commander.hullInstanceID == permission.carrier else { return false }
    }
    if let reception = state.reception {
      guard
        receptionValid(
          reception, state: state, instance: instance, source: source, commander: commander)
      else { return false }
    }
    switch instance.outcome {
    case .active: break
    case .complete:
      guard state.losses.isEmpty, state.captures.count == 1,
        state.reception?.complete == true, job.settlementAmount == WayfarerRecordRecovery.reward,
        let dock = state.reception?.dock,
        instance.completionReceipt?.cause?.nativeMainDock == dock,
        instance.completionReceipt?.committed.nativeMainDock == dock
      else { return false }
      milestones.insert(3)
    case .failed:
      guard !state.losses.isEmpty, job.settlementAmount == 0 else { return false }
    case .abandoned:
      guard state.reception?.complete == false, job.settlementAmount == 0,
        let dock = state.reception?.dock,
        instance.completionReceipt?.cause?.nativeMainDock == dock,
        instance.completionReceipt?.committed.nativeMainDock == dock
      else { return false }
    }
    return instance.milestones == milestones
  }

  @inline(never)
  static func captureValid(
    _ capture: borrowing WayfarerRecordRecoveryCapture,
    state: borrowing WayfarerRecordRecoveryState,
    source: borrowing WayfarerRecordRecoverySource, commander: borrowing Commander
  ) -> Bool {
    let originalID = capture.original
    guard let identification = state.identification,
      capture.identification == identification.operation,
      let identifiedAt = identification.observations.last?.physicalTime,
      capture.startTime >= identifiedAt, capture.physicalTime > identifiedAt,
      let ordinal = source.originals.firstIndex(where: { $0.id == originalID }),
      capture.marker.count == 1,
      capture.operation
        == ScriptIdentity.uuid(
          "record-recovery-pickup-v1:\(state.permission.operation):\(capture.original)"),
      capture.authority == (try? WayfarerRecordRecovery.captureAuthority(capture)),
      capture.carrier == state.permission.carrier,
      capture.logicalActor
        == WayfarerRecordRecovery.actorIdentity(
          mission: state.permission.mission, digest: WayfarerRecordRecovery.digest,
          alias: WayfarerRecordRecovery.aliases[ordinal]),
      capture.actor.system == SystemIdentity(galaxy: 0, system: 241),
      capture.actor.visit > state.permission.dock.actor.visit,
      capture.actor.visit <= commander.flightSimulation.visit,
      capture.actor.entity > 1, capture.actor.entity < commander.flightSimulation.nextActor,
      capture.collector.entity == 0, capture.collector.system == capture.actor.system,
      capture.collector.visit == capture.actor.visit,
      capture.inventoryRevision >= state.permission.inventoryRevision,
      capture.startTime.isFinite, capture.physicalTime.isFinite,
      capture.startTime >= state.permission.physicalTime,
      capture.physicalTime > capture.startTime,
      capture.physicalTime - capture.startTime <= 0.1 + 1e-9,
      capture.physicalTime <= commander.flightSimulation.physicalTime,
      capture.capturePoint.finite, capture.capturePoint.z > 0, capture.capturePoint.y < 0,
      capture.capturePoint.length < 85,
      capture.relativeSpeed.isFinite, capture.relativeSpeed >= 0,
      capture.relativeSpeed <= ScoopApproachController.maximumRelativeSpeed,
      capture.equipment.count == 3, Set(capture.equipment.map(\.id)).count == 3,
      captureMarkerValid(
        capture.marker[0], capture: capture, ordinal: ordinal,
        mission: state.permission.mission, commander: commander)
    else { return false }
    let offset = capture.capturePoint - Vector3(0, -45, 55)
    let radius = 6.322963883093118
    guard abs(offset.x) + radius <= 16, abs(offset.y) + radius <= 16, abs(offset.z) + radius <= 16
    else { return false }
    let slots: [ComponentFittingSlot] = [.targetingCore, .targetingSalvage, .utility(.fuelScoops)]
    for index in capture.equipment.indices {
      guard
        capture.equipment[index].location
          == EquipmentRuntimeCatalog.purchaseLocation(
            .init(hullInstanceID: capture.carrier, slot: slots[index])),
        equipmentHistoryValid(
          capture.equipment[index], owner: source.owner.world, commander: commander)
      else { return false }
    }
    guard TargetingTier.from(capture.equipment[0].node.key) != nil,
      capture.equipment[0].node.family == EquipmentPurchaseCatalog.targeting,
      capture.equipment[1].node.key == "Targeting: Salvage Module",
      capture.equipment[2].node.key == "Fuel Scoops"
    else { return false }
    return true
  }

  @inline(never)
  private static func captureMarkerValid(
    _ marker: borrowing ScriptOwnedActor, capture: borrowing WayfarerRecordRecoveryCapture,
    ordinal: Int, mission: UUID, commander: borrowing Commander
  ) -> Bool {
    guard marker.valid, marker.presence == .present,
      marker.identity == capture.logicalActor,
      marker.alias == WayfarerRecordRecovery.aliases[ordinal],
      marker.body.id >= 0, marker.body.missionInstanceID == mission,
      marker.body.missionActorID == capture.logicalActor,
      marker.body.position == capture.capturePoint,
      marker.body.hull == .cobra, marker.body.physical?.payload == nil,
      marker.body.physical?.npc?.role == .mission, marker.body.physical?.ordnance == nil,
      marker.body.physical?.salvage == nil,
      marker.body.physical?.empCrewPod == nil, marker.body.physical?.empSource == nil,
      marker.body.physical?.identity == capture.actor, marker.body.physical?.population == .mission,
      marker.body.physical?.spawnIdentity?.producer == .mission,
      marker.body.physical?.spawnIdentity?.system == capture.actor.system,
      marker.body.physical?.spawnIdentity?.visit == capture.actor.visit,
      let sequence = marker.body.physical?.spawnIdentity?.sequence,
      sequence > 0, sequence < commander.flightSimulation.nextSpawn,
      marker.body.energy.isFinite, marker.body.energy > 0, !marker.body.hostile,
      let npc = marker.body.scriptNPC,
      WayfarerRecordRecovery.npcValid(npc.fit.definition, package: true),
      npc.fit.models == ["catalogue:SH058": WayfarerRecordRecovery.packageGeometry],
      let retained = commander.scriptState.instances[mission]?.ownedEncounters[
        WayfarerRecordRecovery.encounterID]?.actors[marker.alias],
      retained.identity == marker.identity, retained.presence == .outside,
      retained.body.scriptNPC?.fit == marker.body.scriptNPC?.fit
    else { return false }
    return true
  }

  @inline(never)
  private static func equipmentHistoryValid(
    _ equipment: borrowing EquipmentPurchaseItem, owner: UUID, commander: borrowing Commander
  ) -> Bool {
    let item = equipment.id
    let node = equipment.node
    if let history = commander.savedEquipmentPurchaseHistory {
      for receipt in history.paid where receipt.binding.request.newItem == item {
        guard history.owner == owner, receipt.owner == owner, receipt.node == node else {
          return false
        }
        return equipment.provenance == .paid(owner: owner, transaction: receipt.transaction)
      }
      for receipt in history.legacy where receipt.source.id == item {
        guard history.owner == owner, receipt.owner == owner, receipt.source.node == node else {
          return false
        }
        return equipment.provenance == .legacyUnknown
      }
    }
    switch equipment.provenance {
    case .paid, .legacyUnknown: return false
    case .standard, .grant, .recovered, .reward, .earned, .xyzzy, .missionIssue: return true
    }
  }

  @inline(never)
  private static func lossValid(
    _ loss: borrowing WayfarerRecordRecoveryLoss, state: borrowing WayfarerRecordRecoveryState,
    source: borrowing WayfarerRecordRecoverySource, instance: borrowing ScriptInstance,
    commander: borrowing Commander
  ) -> Bool {
    let originalID = loss.original
    guard let ordinal = source.originals.firstIndex(where: { $0.id == originalID }),
      loss.carrier == state.permission.carrier,
      loss.operation
        == ScriptIdentity.uuid(
          "record-recovery-loss-v1:\(state.permission.operation):\(loss.original):\(loss.kind.rawValue)"
        ),
      loss.authority == (try? WayfarerRecordRecovery.lossAuthority(loss)),
      loss.context.valid, loss.context.calendarSeconds <= commander.scriptState.calendarSeconds,
      loss.collector.entity == 0, loss.collector.visit <= commander.flightSimulation.visit,
      loss.context.galaxy == loss.collector.system.galaxy,
      loss.context.system == loss.collector.system.system,
      loss.physicalTime.isFinite, loss.physicalTime >= state.permission.physicalTime,
      loss.physicalTime <= commander.flightSimulation.physicalTime, loss.energy.isFinite
    else { return false }
    switch loss.kind {
    case .destroyed:
      guard loss.escapePod == nil, loss.marker.count == 1,
        !state.captures.contains(where: { $0.original == originalID }),
        let retained = instance.ownedEncounters[WayfarerRecordRecovery.encounterID]?.actors[
          WayfarerRecordRecovery.aliases[ordinal]], retained.presence == .destroyed,
        retained.identity == loss.marker[0].identity,
        loss.marker[0].valid, loss.marker[0].alias == WayfarerRecordRecovery.aliases[ordinal],
        loss.marker[0].presence == .destroyed, loss.marker[0].body.energy == 0,
        loss.marker[0].body.missionInstanceID == instance.id,
        loss.marker[0].body.missionActorID == loss.marker[0].identity,
        loss.marker[0].body.physical?.population == .mission,
        loss.marker[0].body.physical?.spawnIdentity?.producer == .mission,
        loss.marker[0].body.physical?.identity == loss.actor,
        let npc = loss.marker[0].body.scriptNPC,
        WayfarerRecordRecovery.npcValid(npc.fit.definition, package: true),
        npc.fit.models == ["catalogue:SH058": WayfarerRecordRecovery.packageGeometry],
        retained.body.scriptNPC?.fit == npc.fit,
        loss.marker[0].identity
          == WayfarerRecordRecovery.actorIdentity(
            mission: instance.id, digest: instance.digest,
            alias: WayfarerRecordRecovery.aliases[ordinal])
      else { return false }
    case .hull, .escape:
      guard loss.marker.isEmpty,
        let capture = state.captures.first(where: { $0.original == originalID }),
        loss.actor == capture.actor, loss.physicalTime >= capture.physicalTime,
        !loss.context.docked
      else { return false }
      if loss.kind == .hull {
        guard loss.energy <= 0, loss.escapePod == nil else { return false }
      } else {
        guard loss.energy > 0, let pod = loss.escapePod, pod.node.key == "Escape Pod",
          equipmentHistoryValid(pod, owner: source.owner.world, commander: commander),
          commander.equipmentInventory?.items.contains(where: { $0.id == pod.id }) == false
        else { return false }
      }
    }
    return true
  }

  private static func receptionValid(
    _ receipt: borrowing WayfarerRecordRecoveryReception,
    state: borrowing WayfarerRecordRecoveryState,
    instance: borrowing ScriptInstance, source: borrowing WayfarerRecordRecoverySource,
    commander: borrowing Commander
  ) -> Bool {
    guard historicalDock(receipt.dock, commander: commander), receipt.dock.station == source.owner,
      receipt.carrier == state.permission.carrier,
      receipt.operation
        == ScriptIdentity.uuid(
          "record-recovery-receive-v1:\(state.permission.operation):\(receipt.dock.sequence)"),
      receipt.cause.valid, receipt.committed.valid,
      receipt.cause.nativeMainDock == receipt.dock,
      receipt.committed.nativeMainDock == receipt.dock,
      receipt.originals.count <= 1, Set(receipt.originals).count == receipt.originals.count
    else { return false }
    let lost = Set(state.losses.map(\.original))
    let captured = Set(state.captures.map(\.original))
    let expected = source.originals.filter { captured.contains($0.id) && !lost.contains($0.id) }
      .map(\.id)
    guard receipt.originals == expected else { return false }
    if receipt.complete {
      guard instance.outcome == .complete, expected.count == 1, state.losses.isEmpty,
        receipt.dock.sequence > state.permission.dock.sequence
      else { return false }
      for capture in state.captures {
        guard receipt.dock.actor.visit > capture.actor.visit else { return false }
      }
    } else {
      let outcome = instance.outcome
      guard outcome == .abandoned || outcome == .failed else { return false }
    }
    return true
  }
}

extension WayfarerRecordRecoverySave {
  static func validateFields(_ bytes: Data, part: ScriptFreightVersionedSave.Part, schema: Int?)
    throws
  {
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
      !root.keys.contains("recordRecovery"), !root.keys.contains("savedRecordRecovery")
    else { throw SaveError.invalidCommander }
    func records(_ raw: Any?) throws -> [[String: Any]] {
      guard let raw else { return [] }
      let values: [Any]
      if let map = raw as? [String: Any], map.count <= 128 {
        values = Array(map.values)
      } else if let pairs = raw as? [Any], pairs.count <= 256, pairs.count % 2 == 0 {
        values = stride(from: 1, to: pairs.count, by: 2).map { pairs[$0] }
      } else {
        throw SaveError.invalidCommander
      }
      return try values.map {
        guard let object = $0 as? [String: Any] else { throw SaveError.invalidCommander }
        return object
      }
    }
    func canonical<T: Codable>(_ object: [String: Any], as type: T.Type) throws {
      let raw = try JSONSerialization.data(withJSONObject: object)
      let value = try JSONDecoder().decode(type, from: raw)
      guard
        (object as NSDictionary).isEqual(
          try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)))
      else { throw SaveError.invalidCommander }
    }
    func missions(_ object: [String: Any], embedded: Bool) throws {
      if object.keys.contains("savedRecordRecoverySource") {
        guard contains(schema), !embedded,
          let source = object["savedRecordRecoverySource"] as? [String: Any],
          let originals = source["originals"] as? [Any], originals.count == 1
        else { throw SaveError.invalidCommander }
        try canonical(source, as: WayfarerRecordRecoverySource.self)
      }
      for instance in try records(object["instances"]) {
        let own = instance["definition"] as? String == WayfarerRecordRecovery.stateID
        let pinned = instance["digest"] as? String == WayfarerRecordRecovery.digest
        let leaf = instance.keys.contains("savedRecordRecovery")
        guard own == pinned, own == leaf else { throw SaveError.invalidCommander }
        if own {
          guard contains(schema), !embedded,
            let state = instance["savedRecordRecovery"] as? [String: Any],
            let captures = state["captures"] as? [Any], captures.count <= 1,
            let losses = state["losses"] as? [Any], losses.count <= 1
          else { throw SaveError.invalidCommander }
          if let identification = state["identification"] as? [String: Any] {
            guard let observations = identification["observations"] as? [[String: Any]],
              observations.count == 2
            else { throw SaveError.invalidCommander }
            for observation in observations {
              guard let markers = observation["markers"] as? [Any], markers.count == 2,
                let equipment = observation["equipment"] as? [Any], equipment.count == 2
              else { throw SaveError.invalidCommander }
            }
          }
          for entry in captures {
            guard let capture = entry as? [String: Any],
              let marker = capture["marker"] as? [Any], marker.count == 1,
              let equipment = capture["equipment"] as? [Any], equipment.count == 3
            else { throw SaveError.invalidCommander }
          }
          for entry in losses {
            guard let loss = entry as? [String: Any],
              let marker = loss["marker"] as? [Any], marker.count <= 1
            else { throw SaveError.invalidCommander }
          }
          try canonical(state, as: WayfarerRecordRecoveryState.self)
        }
      }
    }
    func boards(_ object: [String: Any], embedded: Bool) throws {
      guard !object.keys.contains("savedRecordRecoverySource") else {
        throw SaveError.invalidCommander
      }
      for board in try records(object["boards"]) {
        if board["digest"] as? String == WayfarerRecordRecovery.digest
          || board["group"] as? String == WayfarerRecordRecovery.stateID
          || (board["provider"] as? String == "l337.wayfarer-service"
            && board["id"] as? String == WayfarerRecordRecovery.boardID)
        {
          guard contains(schema), !embedded else { throw SaveError.invalidCommander }
        }
      }
    }
    switch part {
    case .missions: try missions(root, embedded: false)
    case .contracts: try boards(root, embedded: false)
    case .commander:
      guard !root.keys.contains("savedRecordRecoverySource") else {
        throw SaveError.invalidCommander
      }
      if let embedded = root["savedScriptState"] as? [String: Any] {
        try missions(embedded, embedded: true)
      }
      if let embedded = root["savedContracts"] as? [String: Any] {
        try boards(embedded, embedded: true)
      }
    }
  }
}

extension WayfarerRecordRecoverySave {
  @inline(never)
  static func identificationValid(
    _ receipt: borrowing WayfarerRecordRecoveryIdentification,
    state: borrowing WayfarerRecordRecoveryState,
    source: borrowing WayfarerRecordRecoverySource, commander: borrowing Commander
  ) -> Bool {
    guard receipt.observations.count == 2,
      let original = source.originals.first, receipt.original == original.id,
      receipt.source == source.id, receipt.permission == state.permission.operation,
      receipt.operation
        == ScriptIdentity.uuid(
          "record-recovery-identification-v1:\(state.permission.operation):\(original.id)"),
      receipt.authority == (try? WayfarerRecordRecovery.identificationAuthority(receipt)),
      receipt.observations[0].sameAuthority(as: receipt.observations[1]),
      receipt.observations[0].physicalTime >= state.permission.physicalTime,
      receipt.observations[1].physicalTime > receipt.observations[0].physicalTime,
      receipt.observations[1].physicalTime - receipt.observations[0].physicalTime <= 0.1 + 1e-9,
      receipt.observations[1].physicalTime <= commander.flightSimulation.physicalTime,
      let mission = commander.scriptState.instances[state.permission.mission],
      let encounter = mission.ownedEncounters[WayfarerRecordRecovery.encounterID],
      encounter.admitted, encounter.galaxy == 0, encounter.system == 241
    else { return false }
    for observation in receipt.observations {
      guard observation.original == original.id,
        observation.permission == state.permission.operation,
        observation.owner == source.owner.world,
        observation.carrier == state.permission.carrier,
        observation.actor.system == SystemIdentity(galaxy: 0, system: 241),
        observation.actor.visit > state.permission.dock.actor.visit,
        observation.actor.visit <= commander.flightSimulation.visit,
        observation.actor.entity > 1,
        observation.actor.entity < commander.flightSimulation.nextActor,
        observation.player.entity == 0, observation.player.system == observation.actor.system,
        observation.player.visit == observation.actor.visit,
        observation.inventoryRevision >= state.permission.inventoryRevision,
        observation.physicalTime.isFinite, observation.targetPoint.finite,
        observation.surfacePoint.finite, observation.surfaceDistance.isFinite,
        (250...1500).contains(observation.surfaceDistance),
        observation.targetPoint.length > 0,
        observation.targetPoint.unit.dot(Vector3(0, 0, 1)) >= cos(2 * Double.pi / 180),
        (observation.surfacePoint - Vector3(0, 0, observation.surfaceDistance)).length < 1e-6,
        observation.markers.count == 2, observation.equipment.count == 2,
        observation.equipment[0].id != observation.equipment[1].id
      else { return false }
      let slots: [ComponentFittingSlot] = [.targetingCore, .targetingSalvage]
      for index in slots.indices {
        guard
          observation.equipment[index].location
            == EquipmentRuntimeCatalog.purchaseLocation(
              .init(hullInstanceID: observation.carrier, slot: slots[index])),
          equipmentHistoryValid(
            observation.equipment[index], owner: source.owner.world, commander: commander)
        else { return false }
      }
      guard TargetingTier.from(observation.equipment[0].node.key) != nil,
        observation.equipment[0].node.family == EquipmentPurchaseCatalog.targeting,
        observation.equipment[1].node.key == "Targeting: Salvage Module"
      else { return false }
      for index in observation.markers.indices {
        let marker = observation.markers[index]
        let alias = index == 0 ? "cdr-001" : "w05-cradle"
        let model = index == 0 ? "catalogue:SH058" : "catalogue:SH141"
        let hash =
          index == 0
          ? WayfarerRecordRecovery.packageGeometry : WayfarerRecordRecovery.cradleGeometry
        guard marker.valid, marker.alias == alias, marker.presence == .present,
          marker.identity
            == WayfarerRecordRecovery.actorIdentity(
              mission: mission.id, digest: mission.digest, alias: alias),
          marker.body.missionInstanceID == mission.id,
          marker.body.missionActorID == marker.identity,
          marker.body.hull == .cobra, !marker.body.hostile, marker.body.energy > 0,
          marker.body.position.finite, marker.body.orientation.validRotation,
          let physical = marker.body.physical, physical.population == .mission,
          physical.npc?.role == .mission, physical.ordnance == nil, physical.payload == nil,
          physical.rock == nil, physical.salvage == nil, physical.empCrewPod == nil,
          physical.empSource == nil, marker.body.blackjackIdentity == nil,
          physical.identity.system == observation.actor.system,
          physical.identity.visit == observation.actor.visit,
          physical.identity.entity > 1,
          physical.identity.entity < commander.flightSimulation.nextActor,
          physical.spawnIdentity?.producer == .mission,
          physical.spawnIdentity?.system == physical.identity.system,
          physical.spawnIdentity?.visit == physical.identity.visit,
          let sequence = physical.spawnIdentity?.sequence,
          sequence > 0, sequence < commander.flightSimulation.nextSpawn,
          let npc = marker.body.scriptNPC,
          WayfarerRecordRecovery.npcValid(npc.fit.definition, package: index == 0),
          npc.fit.models == [model: hash],
          let retained = encounter.actors[alias], retained.identity == marker.identity,
          retained.body.scriptNPC?.fit == npc.fit
        else { return false }
        if index == 0 {
          guard physical.identity == observation.actor,
            marker.body.position == observation.targetPoint
          else { return false }
        }
      }
    }
    return true
  }
}
