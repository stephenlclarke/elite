import Foundation

enum WayfarerRepairLoopSave {
  static let version = 37
  static let alienVersion = 38
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    if commander.scriptState.savedWayfarerRepairLoopStock != nil { return true }
    for index in commander.scriptState.instances.indices {
      if commander.scriptState.instances.values[index].savedWayfarerRepairLoop != nil {
        return true
      }
    }
    guard let inventory = commander.equipmentInventory else { return false }
    return inventory.items.contains { $0.nativeRepairLoopCondition != nil }
  }
  static func validateDeclaration(_ manifest: ScriptManifest) throws {
    guard let terms = manifest.repairLoop else {
      guard manifest.stateID != WayfarerRepairLoopDefinition.stateID else {
        throw MissionPackError("W02 requires its closed current failed-unit producer.")
      }
      return
    }
    guard manifest.stateID == WayfarerRepairLoopDefinition.stateID, terms.valid,
      Set(manifest.capabilities)
        == Set(["script-lua-v1", "story-v2", "durable-commands-v2", "owned-equipment-v2"]),
      manifest.coldChain == nil, manifest.board == nil, manifest.courier == nil,
      manifest.freight == nil, manifest.procurement == nil, manifest.providerContract == nil,
      manifest.pledge == nil, manifest.mission.milestones.count == 1,
      manifest.mission.parentOnly != true,
      (manifest.mission.requiredCollections ?? []).isEmpty,
      (manifest.mission.requiredChoiceGroups ?? []).isEmpty,
      (manifest.mission.requiredBooks ?? []).isEmpty,
      (manifest.mission.requiredDestructionEncounters ?? []).isEmpty,
      (manifest.mission.requiredPassengerParties ?? []).isEmpty,
      (manifest.mission.requiredEquipmentReturns ?? []).isEmpty,
      (manifest.collections ?? []).isEmpty, (manifest.worldJobs ?? []).isEmpty,
      (manifest.children ?? []).isEmpty, (manifest.encounters ?? []).isEmpty,
      (manifest.passengerParties ?? []).isEmpty, (manifest.loans ?? []).isEmpty,
      (manifest.dialogs ?? []).isEmpty, (manifest.books ?? []).isEmpty,
      (manifest.receiptRequirements ?? []).isEmpty, (manifest.answerRequirements ?? []).isEmpty,
      (manifest.npcs ?? []).isEmpty, (manifest.modules ?? []).isEmpty,
      manifest.handlers.count == 1, manifest.handlers[0].event == "mission.accepted",
      let gear = manifest.equipment, gear.count == 1,
      gear[0].id == WayfarerRepairLoopDefinition.gearKey,
      gear[0].name == "Fuel Scoops", gear[0].quantity == 1, gear[0].loan,
      gear[0].mount == nil, gear[0].returnPolicy == "all"
    else { throw MissionPackError("Invalid closed native W02 transport-only repair declaration.") }
  }

  static func engineValid(_ engine: borrowing ScriptEngineState) -> Bool {
    guard OriginalServiceReservationPolicy.valid(engine) else { return false }
    guard let ledger = engine.savedWayfarerRepairLoopStock else {
      for index in engine.instances.indices {
        let hasCustody = engine.instances.values[index].savedWayfarerRepairLoop != nil
        let definition = engine.instances.values[index].definition
        if hasCustody || definition == WayfarerRepairLoopDefinition.stateID { return false }
      }
      return true
    }
    guard sourceCatalogValid(ledger, engine: engine) else { return false }
    return admittedStatesValid(engine)
  }

  // Predeclared item checks finish before any retained mission/receipt validation begins.
  @inline(never)
  private static func sourceCatalogValid(
    _ ledger: borrowing WayfarerRepairLoopStockLedger,
    engine: borrowing ScriptEngineState
  ) -> Bool {
    guard !ledger.sources.isEmpty, ledger.sources.count <= 128 else { return false }
    var count = 0
    var serials: Set<UUID> = []
    var nativeInstances: Set<UUID> = []
    for key in ledger.sources.keys {
      guard let source = ledger.sources[key], key == source.identity.uuidString,
        source.owner == ledger.owner, source.definition.valid, source.initializedAt.valid,
        source.initializedAt.commanderOwner == source.owner,
        source.definition.source.matches(source.initializedAt.station),
        source.identity
          == WayfarerRepairLoopStockSource.identity(owner: source.owner, terms: source.definition),
        PackValidation.version(source.version), ScriptCompletionReceipt.validDigest(source.digest),
        source.units.count == source.definition.stockUnits
      else { return false }
      count += source.units.count
      guard count <= 128 else { return false }
      for ordinal in 0..<source.definition.stockUnits {
        let unitID = WayfarerRepairLoopStockSource.unitIdentity(
          source: source.identity, index: ordinal)
        let instanceID = WayfarerRepairLoopStockSource.instanceIdentity(unit: unitID)
        let serial = OwnedGear.issuedIdentity(
          mission: instanceID, resource: WayfarerRepairLoopDefinition.gearKey, index: 0)
        guard let unit = source.units[unitID.uuidString], unit.id == unitID,
          unit.serial == serial, serials.insert(serial).inserted,
          let node = EquipmentRuntimeCatalog.node(for: "Fuel Scoops"),
          unit.original.node == node, unit.original.location == nil,
          unit.original.boundHull == nil, unit.original.retainedLegacyState == nil,
          unit.original.component == EquipmentRuntimeCatalog.stockComponent(for: node, id: serial),
          unit.original.preferredSlot == EquipmentRuntimeCatalog.slot(for: node),
          unit.original.nativeRepairLoopCondition == .failed(sourceUnit: unitID),
          unit.original.provenance
            == .missionIssue(
              mission: instanceID,
              resource: WayfarerRepairLoopDefinition.gearKey, index: 0, packDigest: source.digest)
        else { return false }
        if unit.status == .available {
          guard unit.instance == nil, unit.returnedItem == nil,
            !engine.instances.keys.contains(instanceID)
          else { return false }
        } else {
          guard unit.instance == instanceID, nativeInstances.insert(instanceID).inserted,
            let index = engine.instances.index(forKey: instanceID),
            engine.instances.values[index].savedWayfarerRepairLoop != nil
          else { return false }
        }
      }
    }
    return true
  }

  @inline(never)
  private static func admittedStatesValid(_ engine: borrowing ScriptEngineState) -> Bool {
    guard let ledger = engine.savedWayfarerRepairLoopStock else { return false }
    for index in engine.instances.indices {
      guard let custody = engine.instances.values[index].savedWayfarerRepairLoop else {
        if engine.instances.values[index].definition == WayfarerRepairLoopDefinition.stateID {
          return false
        }
        continue
      }
      guard let source = ledger.sources[custody.source.uuidString],
        let unitIndex = source.units.index(forKey: custody.unit.uuidString),
        source.units.values[unitIndex].status != .available,
        validState(
          engine.instances.values[index], unit: source.units.values[unitIndex], source: source,
          engine: engine)
      else { return false }
    }
    return true
  }

  @inline(never)
  private static func validState(
    _ state: borrowing ScriptInstance,
    unit: borrowing WayfarerRepairLoopStockUnit, source: borrowing WayfarerRepairLoopStockSource,
    engine: borrowing ScriptEngineState
  ) -> Bool {
    guard issueStateValid(state, unit: unit, source: source, engine: engine) else { return false }
    guard serviceStateValid(state, unit: unit, source: source, engine: engine) else { return false }
    return terminalStateValid(state, unit: unit, source: source, engine: engine)
  }

  @inline(never)
  private static func issueStateValid(
    _ state: borrowing ScriptInstance,
    unit: borrowing WayfarerRepairLoopStockUnit, source: borrowing WayfarerRepairLoopStockSource,
    engine: borrowing ScriptEngineState
  ) -> Bool {
    guard let custody = state.savedWayfarerRepairLoop, state.id == unit.instance,
      state.definition == WayfarerRepairLoopDefinition.stateID, state.digest == source.digest,
      state.version == source.version, state.contract == nil, state.courier == nil,
      state.savedWayfarerColdChain == nil, state.savedOwnedCargo == nil,
      state.savedProviderContract == nil, state.savedNavigationTrade == nil,
      state.collections.isEmpty, state.timers.isEmpty, state.choiceReceipts.isEmpty,
      custody.owner == source.owner, custody.source == source.identity, custody.unit == unit.id,
      custody.serial == unit.serial, custody.definition == source.definition,
      custody.issue.valid, source.definition.source.matches(custody.issue.dock.station),
      custody.issue.dock.commanderOwner == source.owner,
      custody.issue.dock.sequence >= source.initializedAt.sequence,
      custody.issue.sequence <= engine.nextEvent, state.hasAcknowledged(custody.issue.sequence),
      state.gearIssues.count == 1,
      let gear = state.gearIssues[WayfarerRepairLoopDefinition.gearKey],
      gear.valid(for: state), gear.loan, !gear.returnRemaining, gear.savedGearVersion == 2,
      gear.items == [unit.serial], gear.displacements?.isEmpty ?? true,
      gear.source
        == EquipmentIssueSource(
          mission: state.id, resource: WayfarerRepairLoopDefinition.gearKey,
          packDigest: state.digest),
      gear.node == unit.original.node,
      custody.admission.command
        == ScriptIdentity.uuid("repair-loop-issue:\(unit.id):\(custody.issue.sequence)"),
      custody.admission.source == gear.source, custody.admission.originalItems == gear.items,
      custody.issue.context.revision == 0,
      state.revision == 1 + (custody.service == nil ? 0 : 1) + (state.outcome == .active ? 0 : 1)
    else { return false }
    return true
  }

  @inline(never)
  private static func serviceStateValid(
    _ state: borrowing ScriptInstance,
    unit: borrowing WayfarerRepairLoopStockUnit, source: borrowing WayfarerRepairLoopStockSource,
    engine: borrowing ScriptEngineState
  ) -> Bool {
    guard let custody = state.savedWayfarerRepairLoop else { return false }
    guard let service = custody.service else { return true }
    guard
      service.operation
        == operationIdentity(
          state.id, returning: false,
          revision: service.contact.context.revision, inventory: service.inventoryRevision,
          dock: service.contact.dock.sequence, epoch: service.epoch, digest: state.digest),
      service.contact.context.revision == 1, service.instance == state.id,
      service.sourceUnit == unit.id, service.recipe == "relay-continuity-restoration-v1",
      service.issue == custody.issue, service.ownerResource == source.definition.source.resourceKey,
      service.contact.valid, service.contact.dock.commanderOwner == source.owner,
      source.definition.workshop.matches(service.contact.dock.station),
      service.contact.dock.sequence > custody.issue.dock.sequence,
      service.contact.sequence > custody.issue.sequence,
      service.contact.sequence <= engine.nextEvent,
      state.hasAcknowledged(service.contact.sequence), service.before == unit.original
    else { return false }
    return repairedItemValid(
      service.after, original: unit.original, unit: unit.id, operation: service.operation)
  }

  @inline(never)
  private static func repairedItemValid(
    _ after: borrowing OwnedEquipmentItem,
    original: borrowing OwnedEquipmentItem, unit: UUID, operation: UUID
  ) -> Bool {
    guard after.id == original.id, after.node == original.node,
      after.provenance == original.provenance, after.component == original.component,
      after.location == original.location, after.boundHull == original.boundHull,
      after.preferredSlot == original.preferredSlot,
      after.retainedLegacyState == original.retainedLegacyState,
      after.nativeRepairLoopCondition == .operational(sourceUnit: unit, operation: operation)
    else { return false }
    return true
  }

  @inline(never)
  private static func terminalStateValid(
    _ state: borrowing ScriptInstance,
    unit: borrowing WayfarerRepairLoopStockUnit, source: borrowing WayfarerRepairLoopStockSource,
    engine: borrowing ScriptEngineState
  ) -> Bool {
    guard let custody = state.savedWayfarerRepairLoop,
      let gear = state.gearIssues[WayfarerRepairLoopDefinition.gearKey]
    else { return false }
    switch unit.status {
    case .available: return false
    case .held:
      guard state.outcome == .active, state.completionReceipt == nil,
        state.payloads == [WayfarerRepairLoopDefinition.payloadKey: 2], state.milestones.isEmpty
      else { return false }
      guard unit.returnedItem == nil else { return false }
      return custody.returned == nil && custody.loss == nil
        && gear.status == .issued && gear.consumed.isEmpty
    case .returned:
      guard state.outcome == .complete, let receipt = custody.returned,
        let service = custody.service, custody.loss == nil,
        receipt.operation
          == operationIdentity(
            state.id, returning: true,
            revision: receipt.contact.context.revision, inventory: receipt.inventoryRevision,
            dock: receipt.contact.dock.sequence, epoch: receipt.epoch, digest: state.digest),
        receipt.contact.context.revision == 2, receipt.contact.valid,
        source.definition.receiver.matches(receipt.contact.dock.station),
        receipt.contact.dock.commanderOwner == source.owner,
        receipt.contact.dock.sequence > service.contact.dock.sequence,
        receipt.contact.sequence > service.contact.sequence,
        receipt.contact.sequence <= engine.nextEvent,
        state.hasAcknowledged(receipt.contact.sequence), receipt.service == service.operation,
        receipt.originalItems == gear.items, receipt.issueSource == gear.source,
        receipt.amount == source.definition.rewardNative, gear.status == .returned,
        gear.consumed.isEmpty, unit.returnedItem == service.after, state.payloads.isEmpty,
        state.milestones == [0]
      else { return false }
      return completionValid(
        state, engine: engine, sequence: receipt.contact.sequence,
        context: receipt.contact.context, kind: "dialogue.confirmed")
    case .lost:
      guard state.outcome == .failed, let loss = custody.loss, loss.valid,
        loss.sequence > (custody.service?.contact.sequence ?? custody.issue.sequence),
        loss.sequence <= engine.nextEvent, custody.returned == nil, unit.returnedItem == nil,
        state.payloads.isEmpty, state.milestones.isEmpty, gear.status == .issued,
        gear.consumed == [unit.serial]
      else { return false }
      return completionValid(
        state, engine: engine, sequence: loss.sequence, context: loss.context,
        kind: loss.cause.completionKind)
    }
  }
  @inline(never)
  private static func completionValid(
    _ state: borrowing ScriptInstance,
    engine: borrowing ScriptEngineState, sequence: UInt64, context: ScriptEventContext, kind: String
  ) -> Bool {
    guard let completion = state.completionReceipt, completion.valid(for: state, engine: engine),
      completion.sequence == sequence, completion.cause == context, completion.causeKind == kind
    else { return false }
    return true
  }
  private static func operationIdentity(
    _ id: UUID, returning: Bool, revision: UInt64,
    inventory: UInt64, dock: UInt64, epoch: UUID, digest: String
  ) -> UUID {
    ScriptIdentity.uuid(
      "wayfarer-repair-operation-v1:\(id):\(returning):\(revision):\(inventory):\(dock):\(epoch):\(digest)"
    )
  }

  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    guard engineValid(commander.scriptState) else { return false }
    guard let ledger = commander.scriptState.savedWayfarerRepairLoopStock else {
      guard let inventory = commander.equipmentInventory else { return true }
      return !inventory.items.contains { $0.nativeRepairLoopCondition != nil }
    }
    guard ledger.owner == commander.equipmentOwnerID, let world = commander.nativeStations,
      world.ledger.world == ledger.owner, let occupied = commander.checkedCargoTonnes,
      occupied <= commander.standardCargoCapacity, commander.equipmentInventory != nil
    else { return false }
    guard historicalClaimsValid(commander) else { return false }
    return inventoryClaimsValid(commander)
  }

  @inline(never)
  private static func historicalClaimsValid(_ commander: borrowing Commander) -> Bool {
    guard let ledger = commander.scriptState.savedWayfarerRepairLoopStock else { return false }
    for key in ledger.sources.keys {
      guard dockValid(ledger.sources[key]!.initializedAt, commander: commander) else {
        return false
      }
    }
    for index in commander.scriptState.instances.indices {
      guard let custody = commander.scriptState.instances.values[index].savedWayfarerRepairLoop
      else {
        continue
      }
      guard dockValid(custody.issue.dock, commander: commander),
        commander.freightHistoricalContextValid(custody.issue.context, requiresDock: true)
      else { return false }
      if let service = custody.service {
        guard dockValid(service.contact.dock, commander: commander),
          commander.freightHistoricalContextValid(service.contact.context, requiresDock: true)
        else { return false }
      }
      if let receipt = custody.returned {
        guard dockValid(receipt.contact.dock, commander: commander),
          commander.freightHistoricalContextValid(receipt.contact.context, requiresDock: true)
        else { return false }
      }
      if let loss = custody.loss {
        guard loss.visit <= commander.flightSimulation.visit,
          commander.freightHistoricalContextValid(loss.context, requiresDock: false)
        else { return false }
      }
      if let completion = commander.scriptState.instances.values[index].completionReceipt {
        let complete = commander.scriptState.instances.values[index].outcome == .complete
        guard commander.freightHistoricalContextValid(completion.committed, requiresDock: complete)
        else { return false }
      }
    }
    return true
  }

  @inline(never)
  private static func inventoryClaimsValid(_ commander: borrowing Commander) -> Bool {
    guard let ledger = commander.scriptState.savedWayfarerRepairLoopStock,
      let inventory = commander.equipmentInventory
    else { return false }
    var held: Set<UUID> = []
    for key in ledger.sources.keys {
      let source = ledger.sources[key]!
      for key in source.units.keys {
        let unit = source.units[key]!
        let index = itemIndex(inventory, id: unit.serial)
        if unit.status != .held {
          guard index == nil else { return false }
          continue
        }
        guard let index, let id = unit.instance,
          let stateIndex = commander.scriptState.instances.index(forKey: id),
          let custody = commander.scriptState.instances.values[stateIndex].savedWayfarerRepairLoop
        else { return false }
        if let service = custody.service {
          guard inventory.items[index] == service.after else { return false }
        } else {
          guard inventory.items[index] == unit.original else { return false }
        }
        held.insert(unit.serial)
      }
    }
    for index in inventory.items.indices {
      if inventory.items[index].nativeRepairLoopCondition != nil {
        guard held.contains(inventory.items[index].id) else { return false }
      }
    }
    return true
  }
  private static func itemIndex(_ inventory: borrowing OwnedEquipmentInventory, id: UUID) -> Int? {
    for index in inventory.items.indices where inventory.items[index].id == id { return index }
    return nil
  }
  private static func dockValid(
    _ dock: NativeMainStationDockReceipt, commander: borrowing Commander
  ) -> Bool {
    guard let world = commander.nativeStations else { return false }
    let owner = commander.equipmentOwnerID
    let visit = commander.flightSimulation.visit
    let calendar = commander.scriptState.calendarSeconds
    return dock.valid && dock.commanderOwner == owner
      && world.mainStations.contains(dock.station) && world.ledger.world == dock.station.world
      && dock.sequence < world.nextMainDockSequence && dock.actor.visit <= visit
      && dock.calendarSeconds <= calendar
  }

  /// Only the closed native payloads are decoded here. Round-trip shape equality rejects
  /// unknown/null claims before the ordinary reader can silently discard their fields.
  static func validateFields(_ bytes: Data, part: ScriptFreightVersionedSave.Part, schema: Int?)
    throws
  {
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
      throw SaveError.invalidCommander
    }
    let stock = "savedWayfarerRepairLoopStock"
    let custody = "savedWayfarerRepairLoop"
    let condition = "nativeRepairLoopCondition"
    let reserved = Set([stock, custody, condition])
    func reject(_ raw: Any) throws {
      if let object = raw as? [String: Any] {
        guard Set(object.keys).isDisjoint(with: reserved) else { throw SaveError.invalidCommander }
        for value in object.values { try reject(value) }
      } else if let values = raw as? [Any] {
        for value in values { try reject(value) }
      }
    }
    func strict<T: Codable>(_ raw: Any, _ type: T.Type) throws {
      guard !(raw is NSNull) else { throw SaveError.invalidCommander }
      let bytes = try JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys])
      let decoded = try JSONDecoder().decode(type, from: bytes)
      let normalized = try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded))
      guard
        bytes == (try JSONSerialization.data(withJSONObject: normalized, options: [.sortedKeys]))
      else { throw SaveError.invalidCommander }
    }
    func records(_ raw: Any?) throws -> [[String: Any]] {
      if let objects = raw as? [String: Any] {
        guard objects.count <= 128 else { throw SaveError.invalidCommander }
        return try objects.values.map {
          guard let value = $0 as? [String: Any] else { throw SaveError.invalidCommander }
          return value
        }
      }
      if let array = raw as? [Any] {
        guard array.count <= 256, array.count % 2 == 0 else { throw SaveError.invalidCommander }
        return try stride(from: 1, to: array.count, by: 2).map { index in
          guard let value = array[index] as? [String: Any] else { throw SaveError.invalidCommander }
          return value
        }
      }
      guard raw == nil else { throw SaveError.invalidCommander }
      return []
    }
    func missions(_ object: [String: Any]) throws {
      var rest = object
      if let raw = rest.removeValue(forKey: stock) {
        guard contains(schema) else { throw SaveError.invalidCommander }
        guard let fields = raw as? [String: Any],
          let sources = fields["sources"] as? [String: Any], !sources.isEmpty,
          sources.count <= 128
        else { throw SaveError.invalidCommander }
        var total = 0
        for value in sources.values {
          guard let source = value as? [String: Any],
            let units = source["units"] as? [String: Any], units.count == 6
          else {
            throw SaveError.invalidCommander
          }
          total += units.count
          guard total <= 128 else { throw SaveError.invalidCommander }
        }
        try strict(raw, WayfarerRepairLoopStockLedger.self)
        let data = try JSONSerialization.data(withJSONObject: raw)
        let ledger = try JSONDecoder().decode(WayfarerRepairLoopStockLedger.self, from: data)
        guard !ledger.sources.isEmpty, ledger.sources.count <= 128,
          ledger.sources.values.reduce(0, { $0 + $1.units.count }) <= 128
        else { throw SaveError.invalidCommander }
      }
      let instances = try records(rest.removeValue(forKey: "instances"))
      for instance in instances {
        var remainder = instance
        if let raw = remainder.removeValue(forKey: custody) {
          guard contains(schema), object[stock] != nil else { throw SaveError.invalidCommander }
          try strict(raw, WayfarerRepairLoopCustody.self)
        }
        try reject(remainder)
      }
      try reject(rest)
    }
    switch part {
    case .missions: try missions(root)
    case .contracts: try reject(root)
    case .commander:
      var rest = root
      if let engine = rest.removeValue(forKey: "savedScriptState") {
        guard let object = engine as? [String: Any] else { throw SaveError.invalidCommander }
        try missions(object)
      }
      if let inventory = rest.removeValue(forKey: "savedEquipmentInventory") {
        guard var object = inventory as? [String: Any],
          let items = object.removeValue(forKey: "items") as? [[String: Any]], items.count <= 257
        else { throw SaveError.invalidCommander }
        try reject(object)
        for item in items {
          var fields = item
          if let raw = fields.removeValue(forKey: condition) {
            guard contains(schema) else { throw SaveError.invalidCommander }
            try strict(raw, NativeRepairLoopCondition.self)
          }
          try reject(fields)
        }
      }
      try reject(rest)
    }
  }
}
