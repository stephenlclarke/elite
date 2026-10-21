import Foundation

enum NativeMeasuredExtractionSave {
  static let version = 55
  static let alienVersion = 56
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func lowerSchema(_ schema: Int?) -> Int? {
    guard contains(schema) else { return schema }
    return schema == alienVersion
      ? WayfarerRecordRecoverySave.alienVersion : WayfarerRecordRecoverySave.version
  }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    if commander.scriptState.savedMeasuredExtractionSource != nil { return true }
    for mission in commander.scriptState.instances.values {
      if mission.definition == NativeMeasuredExtraction.stateID
        || mission.digest == NativeMeasuredExtraction.digest
        || mission.savedMeasuredExtraction != nil
      {
        return true
      }
    }
    for board in commander.contracts.boards.values {
      if board.group == NativeMeasuredExtraction.stateID
        || board.digest == NativeMeasuredExtraction.digest
        || (board.provider == "l337.contract" && board.id == NativeMeasuredExtraction.boardID)
      {
        return true
      }
    }
    return false
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

  static func validateClaims(_ commander: borrowing Commander, requireRecordedLoss: Bool = false)
    -> Bool
  {
    guard let source = commander.scriptState.savedMeasuredExtractionSource else {
      return !hasClaims(commander)
    }
    guard source.root == NativeMeasuredExtraction.root, source.owner.valid,
      source.owner.world == commander.equipmentOwnerID, source.owner.system == source.root.system,
      source.id == NativeMeasuredExtraction.identity(source.owner),
      source.registration.station == source.owner,
      historicalDock(source.registration, commander: commander),
      source.originals.count == 12,
      source.originals.map(\.id) == NativeMeasuredExtraction.originals(source.owner).map(\.id),
      source.originals.map(\.payload)
        == NativeMeasuredExtraction.originals(source.owner).map(\.payload),
      let mission = commander.scriptState.instances[source.mission],
      let state = mission.savedMeasuredExtraction,
      stateValid(
        state, mission: mission, source: source, commander: commander,
        requireRecordedLoss: requireRecordedLoss)
    else { return false }
    var missions = 0
    var boards = 0
    for instance in commander.scriptState.instances.values {
      if instance.definition == NativeMeasuredExtraction.stateID
        || instance.digest == NativeMeasuredExtraction.digest
        || instance.savedMeasuredExtraction != nil
      {
        guard instance.id == mission.id else { return false }
        missions += 1
      }
    }
    for board in commander.contracts.boards.values {
      if board.group == NativeMeasuredExtraction.stateID
        || board.digest == NativeMeasuredExtraction.digest
        || (board.provider == "l337.contract" && board.id == NativeMeasuredExtraction.boardID)
      {
        guard board.id == NativeMeasuredExtraction.boardID,
          board.digest == NativeMeasuredExtraction.digest,
          board.group == NativeMeasuredExtraction.stateID
        else { return false }
        boards += 1
      }
    }
    return missions == 1 && boards == 1
  }

  @inline(never)
  private static func stateValid(
    _ state: borrowing NativeMeasuredExtractionState,
    mission: borrowing ScriptInstance, source: borrowing MeasuredSource,
    commander: borrowing Commander,
    requireRecordedLoss: Bool
  ) -> Bool {
    let permission = state.permission
    guard state.definition.valid, permission.source == source.id, permission.mission == mission.id,
      permission.operation == ScriptIdentity.uuid("measured-permit-v1:\(source.id):\(mission.id)"),
      permission.dock == source.registration, permission.player.entity == 0,
      permission.player.system == source.root.system,
      permission.player.visit == permission.dock.actor.visit,
      permission.reach.valid, permission.reach.revision == "elite-canonical-native-reach-v2",
      NativeMeasuredExtraction.route(permission.reach), permission.physicalTime.isFinite,
      permission.physicalTime >= 0,
      permission.physicalTime <= commander.flightSimulation.physicalTime,
      mission.definition == NativeMeasuredExtraction.stateID,
      mission.digest == NativeMeasuredExtraction.digest,
      mission.version == "1.0.0", let job = mission.contract, job.provider == "l337.contract",
      job.version == mission.version, job.digest == mission.digest,
      job.station == NativeMeasuredExtraction.source,
      job.group == mission.definition, job.boardRevision == 0,
      job.boardKey == mission.digest + "/measured-extraction/"
        + NativeMeasuredExtraction.source.key,
      job.offer.key == "measured-extraction",
      job.offer.id
        == ScriptIdentity.uuid("contract-offer-v1:\(job.boardKey):0:measured-extraction"),
      Game.contractJobIdentity(job.offer.id) == mission.id,
      job.offer.reward == NativeMeasuredExtraction.reward, job.offer.deposit == 0,
      job.offer.failureReward == 0, !job.offer.refundOnFailure, job.offer.destinationGalaxy == 0,
      job.offer.destinationSystem == 185, job.offer.duration == 0, job.deadline == nil,
      job.clock == .local,
      let board = commander.contracts.boards[job.boardKey],
      board.id == NativeMeasuredExtraction.boardID,
      board.provider == job.provider, board.digest == job.digest, board.version == job.version,
      board.station == job.station, board.group == job.group, board.revision == 0,
      board.offers.count == 1,
      board.offers.first?.id == job.offer.id, board.offers.first?.status == .accepted(mission.id),
      state.captures.count <= 12, state.losses.count <= 24,
      mission.payloads
        == NativeMeasuredExtraction.payloads(source, state: state, outcome: mission.outcome)
    else { return false }
    var milestones: Set<Int> = [0]
    if let witness = state.extraction {
      guard witnessValid(witness, source: source, state: state, commander: commander) else {
        return false
      }
      milestones.insert(1)
    }
    var captured: Set<UUID> = []
    var actors: Set<ActorIdentity> = []
    for intake in state.captures {
      guard intakeValid(intake, source: source, state: state, commander: commander),
        captured.insert(intake.original).inserted,
        let actor = intake.body.first?.physical?.identity, actors.insert(actor).inserted
      else { return false }
    }
    if captured.count == 12 { milestones.insert(2) }
    var lostInputs: Set<UUID> = []
    var lostProducts: Set<UUID> = []
    var lossOps: Set<UUID> = []
    for loss in state.losses {
      guard lossValid(loss, source: source, state: state, commander: commander),
        lossOps.insert(loss.operation).inserted
      else { return false }
      for id in loss.originals { guard lostInputs.insert(id).inserted else { return false } }
      for id in loss.products { guard lostProducts.insert(id).inserted else { return false } }
    }
    if let processing = state.processing {
      guard processingValid(processing, source: source, state: state, commander: commander) else {
        return false
      }
      milestones.insert(3)
    }
    if let reception = state.reception {
      guard
        receptionValid(
          reception, source: source, state: state, mission: mission, commander: commander)
      else { return false }
    }
    for original in source.originals {
      let capture = state.captures.first { $0.original == original.id }
      let loss = state.losses.first { $0.originals.contains(original.id) }
      let returned = state.reception?.returnedRaw.contains(original.id) == true
      switch original.custody {
      case .unfilled:
        guard capture == nil, loss == nil, !returned, state.processing == nil else { return false }
        if requireRecordedLoss && mission.outcome == .active && state.extraction != nil {
          guard commander.flightSimulation.system == source.root.system,
            commander.miningLedger.pendingPayloads.contains(where: {
              $0.identity == original.payload
            })
          else { return false }
        }
      case .raw(let op):
        guard capture?.operation == op, loss == nil, !returned, state.processing == nil else {
          return false
        }
      case .processed(let op):
        guard capture != nil, loss == nil, !returned, state.processing?.operation == op else {
          return false
        }
      case .returned(let op):
        guard capture != nil, loss == nil, returned, state.reception?.operation == op else {
          return false
        }
      case .lost(let op): guard loss?.operation == op, !returned else { return false }
      }
    }
    if !NativeMeasuredExtraction.rawHeld(source).isEmpty
      || state.processing?.products.contains(where: { $0.custody == .held }) == true
    {
      guard commander.hullInstanceID == permission.carrier else { return false }
    }
    switch mission.outcome {
    case .active:
      guard state.losses.isEmpty, state.reception == nil,
        commander.hullInstanceID == permission.carrier
      else { return false }
    case .complete:
      guard state.losses.isEmpty, state.reception?.complete == true,
        job.settlementAmount == NativeMeasuredExtraction.reward
      else { return false }
      milestones.insert(4)
    case .failed: guard !state.losses.isEmpty, job.settlementAmount == 0 else { return false }
    case .abandoned:
      guard state.reception?.complete == false, job.settlementAmount == 0 else { return false }
    }
    return mission.milestones == milestones
  }

  static func witnessValid(
    _ witness: borrowing MeasuredExtractionWitness, source: borrowing MeasuredSource,
    state: borrowing NativeMeasuredExtractionState, commander: borrowing Commander
  ) -> Bool {
    let incident = witness.incident
    guard witness.permission == state.permission.operation,
      witness.carrier == state.permission.carrier,
      witness.operation
        == ScriptIdentity.uuid(
          "measured-extraction-v1:\(state.permission.operation):\(incident.id)"),
      witness.authority == (try? NativeMeasuredExtraction.extractionAuthority(witness)),
      witness.body.count == 1, witness.emitted.count == 20, witness.equipment.count == 3,
      incident.kind == .laser, incident.laser == .mining, incident.origin.ordnance == nil,
      incident.origin.owner.entity == 0, incident.origin.owner.system == source.root.system,
      incident.origin.owner.visit >= state.permission.player.visit,
      incident.origin.owner.visit <= commander.flightSimulation.visit,
      incident.origin.emissionID > 0, incident.origin.emittedAt.isFinite,
      incident.origin.emittedAt >= state.permission.physicalTime,
      incident.origin.emittedAt <= incident.physicalTime,
      incident.id > 0, incident.physicalTime.isFinite,
      incident.physicalTime >= state.permission.physicalTime,
      incident.physicalTime <= commander.flightSimulation.physicalTime,
      let body = witness.body.first, body.hull == .asteroid, body.energy.isFinite, body.energy > 0,
      body.physical?.rock == source.root, body.physical?.payload == nil,
      body.physical?.spawnIdentity?.producer == .asteroids,
      body.physical?.spawnIdentity?.sequence == 61, body.scriptNPC == nil,
      body.missionInstanceID == nil, body.missionActorID == nil,
      body.physical?.npc == nil, body.physical?.ordnance == nil,
      let actor = body.physical?.identity, actor == incident.victim,
      actor.system == source.root.system, actor.visit == incident.origin.owner.visit,
      actor.entity > 1, actor.entity < commander.flightSimulation.nextActor,
      witness.inventoryRevision >= state.permission.inventoryRevision,
      commander.miningLedger.isDepleted(source.root),
      commander.miningLedger.breakups[source.root] == nil,
      Set(witness.equipment.map(\.id)).count == 3,
      incident.origin.sourcePart == "work-tool:" + witness.equipment[2].id.uuidString,
      witness.equipment[0].node.family == EquipmentPurchaseCatalog.targeting,
      TargetingTier.from(witness.equipment[0].node.key) != nil,
      witness.equipment[1].node.key == "Targeting: Mining Module",
      witness.equipment[2].node.key == LaserKind.mining.equipmentName
    else { return false }
    let slots: [ComponentFittingSlot] = [.targetingCore, .targetingMining, .utility(.miningLaser)]
    for index in slots.indices {
      guard
        witness.equipment[index].location
          == EquipmentRuntimeCatalog.purchaseLocation(
            .init(hullInstanceID: witness.carrier, slot: slots[index])),
        equipmentHistoryValid(
          witness.equipment[index], owner: source.owner.world, commander: commander)
      else { return false }
    }
    for (index, payload) in witness.emitted.enumerated() {
      guard payload.identity == .ore(source.root, fragment: UInt16(index)),
        payload.amount == .init(commodity: .minerals, quantity: 1)
      else { return false }
    }
    return true
  }

  static func intakeValid(
    _ intake: borrowing MeasuredIntake, source: borrowing MeasuredSource,
    state: borrowing NativeMeasuredExtractionState, commander: borrowing Commander
  ) -> Bool {
    guard let extraction = state.extraction, intake.extraction == extraction.operation,
      intake.permission == state.permission.operation, intake.carrier == state.permission.carrier,
      intake.operation
        == ScriptIdentity.uuid(
          "measured-intake-v1:\(state.permission.operation):\(intake.original)"),
      intake.authority == (try? NativeMeasuredExtraction.intakeAuthority(intake)),
      let original = source.originals.first(where: { $0.id == intake.original }),
      original.payload == intake.payload.identity, extraction.emitted.contains(intake.payload),
      intake.body.count == 1, let body = intake.body.first, body.hull == .cargo,
      body.energy.isFinite, body.energy > 0, body.physical?.payload == original.payload,
      body.physical?.spawnIdentity?.producer == .mining,
      body.scriptNPC == nil, body.missionInstanceID == nil, body.missionActorID == nil,
      let actor = body.physical?.identity, actor.system == source.root.system,
      actor.visit == extraction.incident.origin.owner.visit, actor.entity > 1,
      actor.entity < commander.flightSimulation.nextActor,
      intake.player.entity == 0, intake.player.system == actor.system,
      intake.player.visit == actor.visit,
      intake.physicalTime.isFinite, intake.physicalTime >= extraction.incident.physicalTime,
      intake.physicalTime <= commander.flightSimulation.physicalTime,
      intake.relativeSpeed.isFinite,
      (0...ScoopApproachController.maximumRelativeSpeed).contains(intake.relativeSpeed),
      body.position.finite, body.position.z > 0, body.position.y < 0, body.position.length < 85,
      intake.inventoryRevision >= state.permission.inventoryRevision,
      intake.scoops.node.key == "Fuel Scoops",
      intake.scoops.location
        == EquipmentRuntimeCatalog.purchaseLocation(
          .init(hullInstanceID: intake.carrier, slot: .utility(.fuelScoops))),
      equipmentHistoryValid(intake.scoops, owner: source.owner.world, commander: commander)
    else { return false }
    let offset = body.position - Vector3(0, -45, 55)
    guard abs(offset.x) <= 16, abs(offset.y) <= 16, abs(offset.z) <= 16,
      body.physical?.catalogueShipID == nil, body.physical?.npc == nil,
      body.physical?.ordnance == nil, body.physical?.rock == nil
    else { return false }
    return true
  }

  static func lossValid(
    _ loss: borrowing MeasuredLoss, source: borrowing MeasuredSource,
    state: borrowing NativeMeasuredExtractionState, commander: borrowing Commander
  ) -> Bool {
    guard !loss.originals.isEmpty || !loss.products.isEmpty,
      loss.originals.count <= 12, loss.products.count <= 12,
      Set(loss.originals).count == loss.originals.count,
      Set(loss.products).count == loss.products.count,
      loss.originals.allSatisfy({ id in source.originals.contains { $0.id == id } }),
      loss.products.allSatisfy({ id in state.processing?.products.contains { $0.id == id } == true }
      ),
      loss.operation
        == ScriptIdentity.uuid(
          "measured-loss-v1:\(state.permission.operation):\(loss.kind.rawValue):\(loss.originals):\(loss.products)"
        ),
      loss.authority == (try? NativeMeasuredExtraction.lossAuthority(loss)),
      loss.carrier == state.permission.carrier, loss.player.entity == 0,
      loss.player.visit <= commander.flightSimulation.visit, loss.energy.isFinite,
      loss.physicalTime.isFinite, loss.physicalTime >= state.permission.physicalTime,
      loss.physicalTime <= commander.flightSimulation.physicalTime
    else { return false }
    switch loss.kind {
    case .source:
      guard loss.products.isEmpty, loss.bodies.count == 1, loss.payloads.isEmpty,
        let incident = loss.incident, incident.victim == loss.bodies[0].physical?.identity,
        loss.bodies[0].physical?.rock == source.root, state.extraction == nil,
        loss.originals == source.originals.map(\.id)
      else { return false }
    case .destroyed:
      guard loss.products.isEmpty, loss.originals.count == 1, loss.bodies.count == 1,
        loss.bodies[0].energy <= 0, loss.payloads.count == 1,
        loss.bodies[0].physical?.payload == loss.payloads[0].identity,
        source.originals.first(where: { $0.id == loss.originals[0] })?.payload
          == loss.payloads[0].identity,
        !state.captures.contains(where: { $0.original == loss.originals[0] })
      else { return false }
    case .departed:
      guard loss.products.isEmpty, loss.bodies.isEmpty, loss.payloads.count == loss.originals.count,
        loss.player.system == source.root.system, state.extraction != nil
      else { return false }
      for (index, id) in loss.originals.enumerated() {
        guard
          source.originals.first(where: { $0.id == id })?.payload == loss.payloads[index].identity,
          loss.payloads[index].amount == .init(commodity: .minerals, quantity: 1),
          !state.captures.contains(where: { $0.original == id })
        else { return false }
      }
    case .hull, .escape:
      guard loss.bodies.isEmpty, loss.payloads.isEmpty else { return false }
      for id in loss.originals {
        guard state.captures.contains(where: { $0.original == id }), state.processing == nil else {
          return false
        }
      }
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

  private static func processingValid(
    _ processing: borrowing MeasuredProcessing, source: borrowing MeasuredSource,
    state: borrowing NativeMeasuredExtractionState, commander: borrowing Commander
  ) -> Bool {
    guard state.captures.count == 12, state.extraction != nil,
      historicalDock(processing.dock, commander: commander),
      processing.dock.station.system == .init(galaxy: 0, system: 185),
      processing.dock.sequence > state.permission.dock.sequence,
      processing.operation
        == ScriptIdentity.uuid(
          "measured-process-v1:\(state.permission.operation):\(processing.dock.sequence)"),
      processing.inputs == source.originals.map(\.id), processing.products.count == 12
    else { return false }
    for capture in state.captures {
      guard processing.dock.actor.visit > capture.player.visit else { return false }
    }
    for (index, product) in processing.products.enumerated() {
      guard product.input == processing.inputs[index], product.massKg == 1000,
        product.id
          == ScriptIdentity.uuid("measured-product-v1:\(processing.operation):\(product.input)")
      else { return false }
      let loss = state.losses.first { $0.products.contains(product.id) }
      switch product.custody {
      case .held: guard loss == nil, state.reception == nil else { return false }
      case .lost(let op): guard loss?.operation == op else { return false }
      case .received(let op):
        guard loss == nil, state.reception?.complete == true,
          state.reception?.operation == op, state.reception?.products.contains(product.id) == true
        else { return false }
      case .returned(let op):
        guard loss == nil, state.reception?.complete == false,
          state.reception?.operation == op,
          state.reception?.returnedProducts.contains(product.id) == true
        else { return false }
      }
    }
    return true
  }

  private static func receptionValid(
    _ receipt: borrowing MeasuredReception, source: borrowing MeasuredSource,
    state: borrowing NativeMeasuredExtractionState, mission: borrowing ScriptInstance,
    commander: borrowing Commander
  ) -> Bool {
    guard historicalDock(receipt.dock, commander: commander), receipt.cause.valid,
      receipt.committed.valid,
      receipt.cause.nativeMainDock == receipt.dock,
      receipt.committed.nativeMainDock == receipt.dock,
      receipt.operation
        == ScriptIdentity.uuid(
          "measured-receive-v1:\(state.permission.operation):\(receipt.dock.sequence)"),
      Set(receipt.products).count == receipt.products.count,
      Set(receipt.returnedRaw).count == receipt.returnedRaw.count,
      Set(receipt.returnedProducts).count == receipt.returnedProducts.count
    else { return false }
    if receipt.complete {
      guard mission.outcome == .complete, state.losses.isEmpty,
        receipt.returnedRaw.isEmpty, receipt.returnedProducts.isEmpty,
        let processing = state.processing, receipt.products == processing.products.map(\.id),
        receipt.products.count == 12, receipt.dock.station == processing.dock.station,
        receipt.dock.sequence >= processing.dock.sequence,
        mission.completionReceipt?.cause?.nativeMainDock == receipt.dock,
        mission.completionReceipt?.committed.nativeMainDock == receipt.dock
      else { return false }
    } else {
      guard mission.outcome == .failed || mission.outcome == .abandoned,
        receipt.dock.station == source.owner, receipt.products.isEmpty
      else { return false }
      let raw = source.originals.filter { item in
        state.captures.contains(where: { $0.original == item.id }) && state.processing == nil
          && !state.losses.contains(where: { $0.originals.contains(item.id) })
      }.map(\.id)
      let products = (state.processing?.products ?? []).filter { product in
        !state.losses.contains(where: { $0.products.contains(product.id) })
      }.map(\.id)
      guard receipt.returnedRaw == raw, receipt.returnedProducts == products else { return false }
    }
    return true
  }
}

extension NativeMeasuredExtractionSave {
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

}

extension NativeMeasuredExtractionSave {
  static func validateFields(_ bytes: Data, part: ScriptFreightVersionedSave.Part, schema: Int?)
    throws
  {
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
      !root.keys.contains("measuredExtraction"), !root.keys.contains("savedMeasuredExtraction")
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
      if object.keys.contains("savedMeasuredExtractionSource") {
        guard contains(schema), !embedded,
          let source = object["savedMeasuredExtractionSource"] as? [String: Any],
          let originals = source["originals"] as? [Any], originals.count == 12
        else { throw SaveError.invalidCommander }
        try canonical(source, as: MeasuredSource.self)
      }
      for instance in try records(object["instances"]) {
        let own = instance["definition"] as? String == NativeMeasuredExtraction.stateID
        let pinned = instance["digest"] as? String == NativeMeasuredExtraction.digest
        let leaf = instance.keys.contains("savedMeasuredExtraction")
        guard own == pinned, own == leaf else { throw SaveError.invalidCommander }
        if own {
          guard contains(schema), !embedded,
            let state = instance["savedMeasuredExtraction"] as? [String: Any],
            let captures = state["captures"] as? [Any], captures.count <= 12,
            let losses = state["losses"] as? [Any], losses.count <= 24
          else { throw SaveError.invalidCommander }
          if let extraction = state["extraction"] as? [String: Any] {
            guard let body = extraction["body"] as? [Any], body.count == 1,
              let emitted = extraction["emitted"] as? [Any], emitted.count == 20,
              let equipment = extraction["equipment"] as? [Any], equipment.count == 3
            else { throw SaveError.invalidCommander }
          }
          for entry in captures {
            guard let capture = entry as? [String: Any],
              let body = capture["body"] as? [Any], body.count == 1
            else { throw SaveError.invalidCommander }
          }
          for entry in losses {
            guard let loss = entry as? [String: Any],
              let bodies = loss["bodies"] as? [Any], bodies.count <= 1,
              let payloads = loss["payloads"] as? [Any], payloads.count <= 12,
              let originals = loss["originals"] as? [Any], originals.count <= 12,
              let products = loss["products"] as? [Any], products.count <= 12
            else { throw SaveError.invalidCommander }
          }
          if let processing = state["processing"] as? [String: Any] {
            guard let inputs = processing["inputs"] as? [Any], inputs.count == 12,
              let products = processing["products"] as? [Any], products.count == 12
            else { throw SaveError.invalidCommander }
          }
          try canonical(state, as: NativeMeasuredExtractionState.self)
        }
      }
    }
    func boards(_ object: [String: Any], embedded: Bool) throws {
      guard !object.keys.contains("savedMeasuredExtractionSource") else {
        throw SaveError.invalidCommander
      }
      for board in try records(object["boards"]) {
        if board["digest"] as? String == NativeMeasuredExtraction.digest
          || board["group"] as? String == NativeMeasuredExtraction.stateID
          || (board["provider"] as? String == "l337.contract"
            && board["id"] as? String == NativeMeasuredExtraction.boardID)
        {
          guard contains(schema), !embedded else { throw SaveError.invalidCommander }
        }
      }
    }
    switch part {
    case .missions: try missions(root, embedded: false)
    case .contracts: try boards(root, embedded: false)
    case .commander:
      guard !root.keys.contains("savedMeasuredExtractionSource") else {
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
