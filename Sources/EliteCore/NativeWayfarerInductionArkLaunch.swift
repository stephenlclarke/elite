import Foundation

extension NativeWayfarerInductionState {
  func registeringArk(_ link: NativeInductionArkLink) throws -> NativeWayfarerInductionState {
    guard valid, seedKey != nil, seedKeyLoss == nil, ark == nil else {
      throw SaveError.invalidCommander
    }
    let next = NativeWayfarerInductionState(
      permission: permission, crate: crate, loss: loss, reception: reception,
      cassette: cassette, cassetteLoss: cassetteLoss, cassetteService: cassetteService,
      seedKey: seedKey, ark: link)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }
}

extension Game {
  func inductionArkLaunchIssues() -> [String] {
    guard let parent = wayfarerInductionMission, parent.outcome == .active,
      parent.suspension == nil, let leaf = parent.savedWayfarerInduction, leaf.valid,
      let key = leaf.seedKey, leaf.seedKeyLoss == nil, leaf.ark == nil,
      let service = leaf.cassetteService,
      let source = try? NativeInductionArkSource(
        loan: key, permission: leaf.permission, service: service)
    else { return ["The original custodian key, consent and unused registered ark are required."] }
    guard nativeInductionArkPack != nil else { return ["Restore the original seed-ark service."] }
    guard commander.scriptState.instances.count < 128,
      commander.scriptState.instances[NativeInductionArkPack.instance(registeredArk: source.actor)]
        == nil
    else { return ["The mission record capacity is full or this ark was already issued."] }
    guard
      (try? NativeArkRoutePlan(source: source, escortReachLY: commander.fullTankJumpDistance))
        != nil
    else {
      return [
        "No original-world route is available within the ark drive and your navigation range."
      ]
    }
    return []
  }

  mutating func confirmInductionArkLaunch(
    dock: NativeMainStationDockReceipt, carrier: UUID, revision: UInt64
  ) throws {
    guard inductionArkLaunchIssues().isEmpty, nativeMainStationDockEvidenceIsCurrent,
      commander.nativeStations?.currentMainDock == dock,
      systemIdentity == NativeWayfarerInduction.seedSource,
      commander.hullInstanceID == carrier, commander.equipmentInventory?.revision == revision,
      var parent = wayfarerInductionMission, let leaf = parent.savedWayfarerInduction,
      let key = leaf.seedKey, let service = leaf.cassetteService,
      let pack = nativeInductionArkPack,
      parent.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 2
    else { throw SaveError.invalidCommander }
    let source = try NativeInductionArkSource(
      loan: key, permission: leaf.permission, service: service)
    let route = try NativeArkRoutePlan(
      source: source, escortReachLY: commander.fullTankJumpDistance)
    let job = NativeInductionArkPack.instance(registeredArk: source.actor)
    let physicalTime = commander.flightSimulation.physicalTime
    let operation = try NativeArkLaunchAuthorization.identity(
      registeredArk: source.actor, dock: dock, carrier: carrier,
      revision: revision, physicalTime: physicalTime, route: route)
    let sequence = commander.scriptState.nextEvent + 1
    let authorization = NativeArkLaunchAuthorization(
      owner: source.owner, parent: parent.id, job: job, registeredArk: source.actor,
      actor: NativeInductionArkPack.actor(instance: job), operation: operation,
      stockIssue: ScriptIdentity.uuid("native-ark-initial-stock-v1:\(source.actor):\(operation)"),
      loanOperation: key.operation, sequence: sequence, dock: dock, carrier: carrier,
      inventoryRevision: revision, physicalTime: physicalTime,
      flightSeconds: commander.scriptState.flightSeconds, route: route,
      seeds: source.seeds, crew: source.crew)
    let ark = NativeInductionArkState(
      authorization: authorization, fuel: try NativeArkFuelEscrow(source: source))
    guard ark.shapeValid(source: source, key: key) else { throw SaveError.invalidCommander }
    let link = NativeInductionArkLink(
      job: job, registeredArk: source.actor, operation: operation, loanOperation: key.operation)
    parent.savedWayfarerInduction = try leaf.registeringArk(link)
    parent.revision += 1
    parent.acknowledge(sequence)
    parent.journal.append(
      "Enlirin's custodians registered their one original Haflinger ark, forty seed-tonne units and six living crew. Their 1000 CR fuel escrow stays separate from commander cash. Depart the berth for native ark admission; its own drive and fuel govern every hop."
    )
    var child = ScriptInstance(
      id: job, definition: NativeInductionArkPack.stateID,
      version: NativeInductionArkPack.version, digest: pack.digest)
    child.savedNativeArk = ark
    child.acknowledge(sequence)
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.instances[job] = child
    emitScriptEvent("mission.accepted", only: job)
    notify("ORIGINAL ARK REGISTERED - DEPART ENLIRIN TO ESCORT")
  }
}
