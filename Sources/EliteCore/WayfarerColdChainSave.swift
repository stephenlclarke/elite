import Foundation

enum WayfarerColdChainSave {
  static let version = 35
  static let alienVersion = 36
  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    // Every valid custody instance must join this registry; orphan fields are rejected separately.
    commander.scriptState.savedWayfarerColdChainStock != nil
  }

  static func validateDeclaration(_ manifest: ScriptManifest) throws {
    guard let terms = manifest.coldChain else {
      guard manifest.stateID != WayfarerColdChainDefinition.stateID else {
        throw MissionPackError("W01 requires its closed native cold-chain declaration.")
      }
      return
    }
    guard manifest.stateID == WayfarerColdChainDefinition.stateID, terms.valid,
      Set(manifest.capabilities)
        == Set(["script-lua-v1", "story-v2", "durable-commands-v2", "local-flight-clocks-v2"]),
      manifest.board == nil, manifest.courier == nil, manifest.freight == nil,
      manifest.procurement == nil, manifest.providerContract == nil, manifest.pledge == nil,
      manifest.mission.milestones.count == 1, manifest.mission.parentOnly != true,
      (manifest.mission.requiredCollections ?? []).isEmpty,
      (manifest.mission.requiredChoiceGroups ?? []).isEmpty,
      (manifest.mission.requiredBooks ?? []).isEmpty,
      (manifest.mission.requiredDestructionEncounters ?? []).isEmpty,
      (manifest.mission.requiredPassengerParties ?? []).isEmpty,
      (manifest.mission.requiredEquipmentReturns ?? []).isEmpty,
      (manifest.collections ?? []).isEmpty, (manifest.equipment ?? []).isEmpty,
      (manifest.worldJobs ?? []).isEmpty, (manifest.children ?? []).isEmpty,
      (manifest.encounters ?? []).isEmpty, (manifest.passengerParties ?? []).isEmpty,
      (manifest.loans ?? []).isEmpty, (manifest.dialogs ?? []).isEmpty,
      (manifest.books ?? []).isEmpty, (manifest.receiptRequirements ?? []).isEmpty,
      (manifest.answerRequirements ?? []).isEmpty, (manifest.npcs ?? []).isEmpty,
      (manifest.modules ?? []).isEmpty,
      manifest.handlers.count == 1, manifest.handlers[0].event == "timer.fired"
    else { throw MissionPackError("Invalid closed native W01 stock and quotation declaration.") }
  }

  static func engineValid(_ engine: borrowing ScriptEngineState) -> Bool {
    guard engine.savedWayfarerColdChainStock != nil else {
      return noOrphanInstances(engine)
    }
    return retainedEngineValid(engine)
  }

  @inline(never)
  private static func noOrphanInstances(_ engine: borrowing ScriptEngineState) -> Bool {
    !engine.instances.values.contains {
      $0.savedWayfarerColdChain != nil || $0.definition == WayfarerColdChainDefinition.stateID
    }
  }

  @inline(never)
  private static func retainedEngineValid(_ engine: borrowing ScriptEngineState) -> Bool {
    guard let ledger = engine.savedWayfarerColdChainStock else { return false }
    guard !ledger.sources.isEmpty, ledger.sources.count <= 128 else { return false }
    var active = 0
    for state in engine.instances.values
    where state.definition.hasPrefix("l337.wayfarer-service/") && state.outcome == .active {
      active += 1
      guard active <= 3 else { return false }
    }
    var count = 0
    for (key, source) in ledger.sources {
      guard key == source.identity.uuidString, source.owner == ledger.owner, source.valid else {
        return false
      }
      count += source.units.count
      guard count <= 128 else { return false }
      for unit in source.units.values where unit.status != .available {
        guard let id = unit.instance, let state = engine.instances[id],
          validState(state, source: source, unit: unit, engine: engine)
        else { return false }
      }
    }
    for state in engine.instances.values {
      guard
        state.savedWayfarerColdChain != nil
          || state.definition != WayfarerColdChainDefinition.stateID
      else { return false }
      if let custody = state.savedWayfarerColdChain {
        guard let source = ledger.sources[custody.source.uuidString],
          let unit = source.units[custody.unit.uuidString], unit.instance == state.id,
          validState(state, source: source, unit: unit, engine: engine)
        else { return false }
      }
    }
    return true
  }

  @inline(never)
  private static func validState(
    _ state: borrowing ScriptInstance, source: WayfarerColdChainStockSource,
    unit: WayfarerColdChainStockUnit, engine: borrowing ScriptEngineState
  ) -> Bool {
    guard let custody = state.savedWayfarerColdChain,
      state.definition == WayfarerColdChainDefinition.stateID,
      state.version == source.version, state.digest == source.digest,
      state.revision < UInt64(Int64.max),
      custody.source == source.identity, custody.owner == source.owner,
      custody.unit == unit.id, unit.instance == state.id, custody.definition == source.definition,
      case .none = state.contract, case .none = state.courier, case .none = state.savedOwnedCargo,
      case .none = state.savedProviderContract, case .none = state.savedNavigationTrade,
      case .none = state.campaignParent, state.collections.isEmpty, state.gearIssues.isEmpty,
      state.ownedEncounters.isEmpty, state.choiceReceipts.isEmpty,
      state.conversationReceipts.isEmpty, custody.issue.valid,
      custody.issue.dock.commanderOwner == custody.owner,
      custody.definition.source.matches(custody.issue.dock.station),
      custody.issue.dock.sequence >= source.initializedAt.sequence,
      custody.issue.sequence <= engine.nextEvent, state.hasAcknowledged(custody.issue.sequence),
      custody.timer.valid, custody.timer.id == WayfarerColdChainDefinition.timerID,
      custody.timer.domain == .flight, custody.timer.policy == .once,
      custody.timer.due == custody.issue.context.flightSeconds + custody.definition.flightAllowance,
      custody.integrity.binding
        == WayfarerColdChainBinding(
          owner: custody.owner, instance: state.id, consignment: custody.unit,
          receiver: Game.worldResourceIdentity(
            "main-station-v1:" + custody.definition.receiver.resourceKey),
          timerID: custody.timer.id)
    else { return false }
    if let objective = custody.objective {
      guard objective.valid, custody.definition.objective.matches(objective.dock.station),
        objective.dock.commanderOwner == custody.owner,
        objective.sequence > custody.issue.sequence, objective.sequence <= engine.nextEvent,
        objective.dock.sequence > custody.issue.dock.sequence,
        state.hasAcknowledged(objective.sequence),
        objective.context.flightSeconds >= custody.issue.context.flightSeconds,
        objective.context.flightSeconds < custody.timer.due
      else { return false }
    }
    let latest: ScriptEventContext
    if let loss = custody.loss {
      guard loss.valid, case .none = custody.integrity.terminal, unit.status == .failed,
        state.outcome == .failed, state.payloads.isEmpty, state.timers.isEmpty,
        state.milestones.isEmpty, loss.sequence > custody.issue.sequence,
        loss.sequence <= engine.nextEvent, state.hasAcknowledged(loss.sequence),
        loss.visit >= custody.issue.dock.actor.visit,
        let completion = state.completionReceipt,
        completion.sequence == loss.sequence, completion.cause == loss.context,
        completion.causeKind == loss.cause.completionKind, completion.settlementAmount == nil,
        completion.valid(for: state, engine: engine)
      else { return false }
      latest = loss.context
    } else {
      switch custody.integrity.terminal {
      case nil:
        guard unit.status == .held, state.outcome == .active, case .none = state.completionReceipt,
          state.milestones.isEmpty,
          state.payloads == [WayfarerColdChainDefinition.payloadKey: 1],
          activeTimerValid(state, engine: engine)
        else { return false }
        latest = custody.objective?.context ?? custody.issue.context
      case .some(.received(let receipt)):
        guard unit.status == .received, state.outcome == .complete,
          state.payloads.isEmpty, state.timers.isEmpty, state.milestones == [0],
          let objective = custody.objective, let completion = state.completionReceipt,
          let cause = completion.cause, let dock = cause.nativeMainDock,
          custody.definition.receiver.matches(dock.station),
          dock.commanderOwner == custody.owner, dock.sequence >= objective.dock.sequence,
          cause.flightSeconds < custody.timer.due,
          receipt.item == custody.unit,
          receipt.id == ScriptCourierCustody.terminalIdentity(custody.unit),
          receipt.proof.sequence == completion.sequence,
          receipt.proof.clock == cause.calendarSeconds,
          receipt.proof.sequence > objective.sequence,
          receipt.proof.revision + 1 == state.revision,
          receipt.proof.token == "wayfarer-native-reception",
          receipt.proof.station
            == ContractStationIdentity(
              galaxy: cause.galaxy, system: cause.system, stationClass: "main-orbital"),
          receipt.amount == custody.definition.rewardNative,
          completion.settlementAmount == nil,
          completion.causeKind == "dialogue.confirmed",
          completion.valid(for: state, engine: engine)
        else { return false }
        latest = cause
      case .some(.spoiled(let receipt)):
        guard unit.status == .failed, state.outcome == .failed,
          state.payloads.isEmpty, state.timers.isEmpty, state.milestones.isEmpty,
          let completion = state.completionReceipt, completion.causeKind == "timer.fired",
          completion.sequence == receipt.sequence, completion.cause == receipt.context,
          completion.settlementAmount == nil, completion.valid(for: state, engine: engine)
        else { return false }
        latest = receipt.context
      }
    }
    return latest.flightSeconds <= engine.flightSeconds
      && custody.integrity.matchesNativeState(
        timer: custody.timer, allowance: custody.definition.flightAllowance,
        issueSequence: custody.issue.sequence,
        issuedFlightSeconds: custody.issue.context.flightSeconds, lastContext: latest)
  }

  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    guard commander.scriptState.savedWayfarerColdChainStock != nil else {
      return engineValid(commander.scriptState)
    }
    return retainedClaimsValid(commander)
  }

  /// A consumed one-shot remains authoritative only through its exact native queued event.
  /// Filesystem refusal keeps this event and the director's suspension, not a replacement timer.
  @inline(never)
  static func pendingExpiry(
    _ state: borrowing ScriptInstance, engine: borrowing ScriptEngineState
  ) -> ScriptEvent? {
    guard state.definition == WayfarerColdChainDefinition.stateID, state.outcome == .active,
      state.timers.isEmpty, case .none = state.completionReceipt,
      let custody = state.savedWayfarerColdChain, custody.loss == nil,
      case .none = custody.integrity.terminal
    else { return nil }
    var pending: ScriptEvent?
    for event in engine.pendingEvents
    where event.instance == state.id && event.kind == "timer.fired" {
      guard pending == nil, event.sequence > custody.issue.sequence,
        event.sequence <= engine.nextEvent, !state.hasAcknowledged(event.sequence),
        let context = event.context, context.valid, context.revision == state.revision,
        context.flightSeconds <= engine.flightSeconds,
        context.localSeconds <= engine.localSeconds,
        context.calendarSeconds <= engine.calendarSeconds,
        context.transitSeconds <= engine.transitSeconds,
        Set(event.values.keys) == [
          "timer_id", "pulse", "due", "fired_at", "has_been_run", "clock_exhausted",
          "counters", "reset_counters",
        ],
        event.values["clock_exhausted"] == .bool(false),
        event.values["counters"] == .object([:]),
        event.values["reset_counters"] == .array([]),
        (try? custody.integrity.spoiling(binding: custody.integrity.binding, event: event)) != nil
      else { return nil }
      pending = event
    }
    return pending
  }

  private static func activeTimerValid(
    _ state: borrowing ScriptInstance, engine: borrowing ScriptEngineState
  ) -> Bool {
    guard let custody = state.savedWayfarerColdChain else { return false }
    if state.timers == [custody.timer.id: custody.timer] {
      for event in engine.pendingEvents
      where event.instance == state.id && event.kind == "timer.fired" {
        return false
      }
      return true
    }
    return pendingExpiry(state, engine: engine) != nil
  }

  @inline(never)
  private static func retainedClaimsValid(_ commander: borrowing Commander) -> Bool {
    guard engineValid(commander.scriptState),
      let ledger = commander.scriptState.savedWayfarerColdChainStock
    else { return false }
    guard ledger.owner == commander.equipmentOwnerID,
      let world = commander.nativeStations, world.ledger.world == ledger.owner,
      let mass = commander.checkedCargoTonnes, mass <= commander.standardCargoCapacity
    else { return false }
    for source in ledger.sources.values {
      guard dockValid(source.initializedAt, commander: commander),
        let resource = commander.scriptState.stationResources[source.definition.source.resourceKey],
        resource.valid, resource.identity == source.initializedAt.station.resource,
        resource.key == source.definition.source.resourceKey
      else { return false }
    }
    for state in commander.scriptState.instances.values {
      guard let custody = state.savedWayfarerColdChain else { continue }
      guard dockValid(custody.issue.dock, commander: commander),
        commander.freightHistoricalContextValid(custody.issue.context, requiresDock: true)
      else { return false }
      if let objective = custody.objective {
        guard dockValid(objective.dock, commander: commander),
          commander.freightHistoricalContextValid(objective.context, requiresDock: true)
        else { return false }
      }
      if let pending = pendingExpiry(state, engine: commander.scriptState) {
        guard let context = pending.context,
          commander.freightHistoricalContextValid(context, requiresDock: context.docked)
        else { return false }
      }
      if let loss = custody.loss {
        guard loss.visit <= commander.flightSimulation.visit,
          commander.freightHistoricalContextValid(loss.context, requiresDock: false)
        else { return false }
      }
      if let completion = state.completionReceipt, let cause = completion.cause {
        guard
          commander.freightHistoricalContextValid(cause, requiresDock: state.outcome == .complete),
          commander.freightHistoricalContextValid(
            completion.committed, requiresDock: state.outcome == .complete)
        else { return false }
      }
    }
    return true
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
      && dock.sequence < world.nextMainDockSequence
      && dock.actor.visit <= visit
      && dock.calendarSeconds <= calendar
  }

  /// Existing feature gates retain their own exact shapes under the new outer envelope.
  static func mappedSchema(_ bytes: Data, part: ScriptFreightVersionedSave.Part, alien: Bool) throws
    -> Int
  {
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
      throw SaveError.invalidCommander
    }
    if part == .missions {
      if records(root["instances"]).contains(where: { $0.keys.contains("savedNavigationTrade") }) {
        return alien ? ScriptNavigationTradeSave.alienVersion : ScriptNavigationTradeSave.version
      }
      if root.keys.contains("savedClueJournal") {
        return alien ? ScriptClueVersionedSave.alienVersion : ScriptClueVersionedSave.version
      }
    }
    return alien ? ScriptFreightVersionedSave.alienVersion : ScriptFreightVersionedSave.version
  }

  private static func records(_ raw: Any?) -> [[String: Any]] {
    if let values = raw as? [String: Any] {
      return values.values.compactMap { $0 as? [String: Any] }
    }
    if let values = raw as? [Any], values.count % 2 == 0 {
      return stride(from: 1, to: values.count, by: 2).compactMap { values[$0] as? [String: Any] }
    }
    return []
  }

  static func validateFields(
    _ bytes: Data, part: ScriptFreightVersionedSave.Part, schema: Int?
  ) throws {
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
      throw SaveError.invalidCommander
    }
    let stock = "savedWayfarerColdChainStock"
    let custody = "savedWayfarerColdChain"
    func reject(_ object: [String: Any]) throws {
      guard !object.keys.contains(stock), !object.keys.contains(custody) else {
        throw SaveError.invalidCommander
      }
    }
    func exact(_ object: [String: Any], required: Set<String>, optional: Set<String> = []) throws {
      guard required.isSubset(of: Set(object.keys)),
        Set(object.keys).isSubset(of: required.union(optional)),
        object.values.allSatisfy({ !($0 is NSNull) })
      else { throw SaveError.invalidCommander }
    }
    func definition(_ raw: Any?) throws {
      guard let object = raw as? [String: Any] else { throw SaveError.invalidCommander }
      try exact(
        object,
        required: [
          "source", "objective", "receiver", "batch", "stockUnits", "tonnes", "maximumActive",
          "route", "hazardTier", "flightAllowance", "rewardNative",
        ])
      guard let route = object["route"] as? [Any], (2...256).contains(route.count) else {
        throw SaveError.invalidCommander
      }
      for key in ["source", "objective", "receiver"] {
        guard let site = object[key] as? [String: Any] else { throw SaveError.invalidCommander }
        try exact(site, required: ["galaxy", "system", "resourceKey"])
      }
    }
    func dockFields(_ raw: Any?) throws {
      guard let dock = raw as? [String: Any],
        let station = dock["station"] as? [String: Any],
        let actor = dock["actor"] as? [String: Any]
      else { throw SaveError.invalidCommander }
      try exact(
        dock, required: ["station", "actor", "commanderOwner", "sequence", "calendarSeconds"])
      try exact(station, required: ["world", "system", "resource"])
      try exact(actor, required: ["system", "visit", "entity"])
      for raw in [station["system"], actor["system"]] {
        guard let system = raw as? [String: Any] else { throw SaveError.invalidCommander }
        try exact(system, required: ["galaxy", "system"])
      }
    }
    func contextFields(_ raw: Any?) throws {
      guard let context = raw as? [String: Any] else { throw SaveError.invalidCommander }
      try exact(
        context,
        required: [
          "galaxy", "system", "docked", "mainStation", "revision", "frameSeconds", "localSeconds",
          "flightSeconds", "calendarSeconds", "transitSeconds",
        ], optional: ["playerPosition", "nativeMainDock"])
      if let dock = context["nativeMainDock"] { try dockFields(dock) }
      if let raw = context["playerPosition"] {
        guard let vector = raw as? [String: Any] else { throw SaveError.invalidCommander }
        try exact(vector, required: ["x", "y", "z"])
      }
    }
    func timerFields(_ raw: Any?) throws {
      guard let timer = raw as? [String: Any] else { throw SaveError.invalidCommander }
      try exact(timer, required: ["id", "domain", "due", "interval", "policy", "pulses"])
    }
    func terminalFields(_ raw: Any?) throws {
      guard let terminal = raw as? [String: Any], terminal.count == 1,
        let name = terminal.keys.first, ["received", "spoiled"].contains(name),
        let wrapped = terminal[name] as? [String: Any],
        let receipt = wrapped["_0"] as? [String: Any]
      else { throw SaveError.invalidCommander }
      try exact(wrapped, required: ["_0"])
      if name == "spoiled" {
        try exact(
          receipt, required: ["sequence", "instance", "timerID", "due", "firedAt", "context"])
        try contextFields(receipt["context"])
      } else {
        try exact(receipt, required: ["id", "item", "cause", "proof", "amount"])
        guard let proof = receipt["proof"] as? [String: Any],
          let station = proof["station"] as? [String: Any]
        else { throw SaveError.invalidCommander }
        try exact(proof, required: ["sequence", "token", "revision", "epoch", "clock", "station"])
        try exact(station, required: ["galaxy", "system", "stationClass"])
      }
    }
    func stockFields(_ raw: Any?) throws {
      guard let ledger = raw as? [String: Any],
        let sources = ledger["sources"] as? [String: Any], (1...128).contains(sources.count)
      else { throw SaveError.invalidCommander }
      try exact(ledger, required: ["owner", "sources"])
      var count = 0
      for raw in sources.values {
        guard let source = raw as? [String: Any],
          let units = source["units"] as? [String: Any], (1...128).contains(units.count)
        else { throw SaveError.invalidCommander }
        try exact(
          source,
          required: [
            "identity", "owner", "definition", "version", "digest", "initializedAt", "units",
          ])
        try definition(source["definition"])
        try dockFields(source["initializedAt"])
        count += units.count
        guard count <= 128 else { throw SaveError.invalidCommander }
        for raw in units.values {
          guard let unit = raw as? [String: Any] else { throw SaveError.invalidCommander }
          try exact(unit, required: ["id", "status"], optional: ["instance"])
        }
      }
    }
    func custodyFields(_ raw: Any?) throws {
      guard let value = raw as? [String: Any],
        let timer = value["timer"] as? [String: Any],
        let integrity = value["integrity"] as? [String: Any]
      else { throw SaveError.invalidCommander }
      try exact(
        value,
        required: [
          "owner", "source", "unit", "definition", "issue", "timer", "integrity",
        ], optional: ["objective", "loss"])
      try definition(value["definition"])
      if let raw = value["loss"] {
        guard let loss = raw as? [String: Any] else { throw SaveError.invalidCommander }
        try exact(loss, required: ["cause", "sequence", "context", "energy", "visit"])
        try contextFields(loss["context"])
      }
      try timerFields(timer)
      try timerFields(integrity["timer"])
      try contextFields(integrity["lastContext"])
      if let terminal = integrity["terminal"] { try terminalFields(terminal) }
      try exact(
        integrity,
        required: [
          "schema", "binding", "timer", "allowance", "issuedFlightSeconds", "issueSequence",
          "lastContext",
        ], optional: ["terminal"])
      guard let binding = integrity["binding"] as? [String: Any] else {
        throw SaveError.invalidCommander
      }
      try exact(binding, required: ["owner", "instance", "consignment", "receiver", "timerID"])
      for key in ["issue", "objective"] where value.keys.contains(key) {
        guard let contact = value[key] as? [String: Any] else { throw SaveError.invalidCommander }
        try exact(contact, required: ["sequence", "dock", "context"])
        try dockFields(contact["dock"])
        try contextFields(contact["context"])
      }
    }
    func missions(_ object: [String: Any], allow: Bool) throws {
      guard !object.keys.contains(custody) else { throw SaveError.invalidCommander }
      if let raw = object[stock] {
        guard allow else { throw SaveError.invalidCommander }
        try stockFields(raw)
      }
      let instances = records(object["instances"])
      guard instances.count <= 128 else { throw SaveError.invalidCommander }
      for instance in instances {
        guard !instance.keys.contains(stock) else { throw SaveError.invalidCommander }
        if let raw = instance[custody] {
          guard allow, object.keys.contains(stock) else { throw SaveError.invalidCommander }
          try custodyFields(raw)
        }
        if let contract = instance["contract"] as? [String: Any] {
          try reject(contract)
          if let offer = contract["offer"] as? [String: Any] { try reject(offer) }
        }
      }
    }
    func contracts(_ object: [String: Any]) throws {
      try reject(object)
      for board in records(object["boards"]) {
        try reject(board)
        for offer in board["offers"] as? [[String: Any]] ?? [] { try reject(offer) }
      }
    }
    switch part {
    case .missions: try missions(root, allow: contains(schema))
    case .commander:
      try reject(root)
      if let state = root["savedScriptState"] as? [String: Any] {
        try missions(state, allow: false)
      }
      if let saved = root["savedContracts"] as? [String: Any] { try contracts(saved) }
    case .contracts: try contracts(root)
    }
  }
}
