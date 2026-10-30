import Foundation

extension Game {
  func inductionArkReplacementIssues() -> [String] {
    guard let parent = wayfarerInductionMission, parent.outcome == .active,
      parent.suspension == nil, let leaf = parent.savedWayfarerInduction,
      leaf.seedReception == nil, let link = leaf.ark,
      let old = commander.scriptState.instances[link.job]?.savedNativeArk, old.loss != nil
    else {
      return ["A proved original ark destruction is required; disappearance is not a stock source."]
    }
    guard parent.savedArkRecovery == nil else {
      return [
        "The single custodian reserve was consumed. No further hull, seed, crew or fuel funding is available."
      ]
    }
    guard let key = leaf.seedKey, leaf.seedKeyLoss == nil,
      leaf.payloads == [NativeWayfarerInduction.keyPayload: 1]
    else {
      return [
        "Recover the original borrowed key through its actual authored custody path; no new key is minted."
      ]
    }
    guard NativeInductionArkSave.validateClaims(commander), old.reception == nil,
      old.authorization.reserve == nil, old.fuel.closure == nil,
      let service = leaf.cassetteService,
      nativeMainStationDockEvidenceIsCurrent,
      let dock = commander.nativeStations?.currentMainDock,
      dock.station.system == NativeWayfarerInduction.seedSource,
      let pack = nativeInductionArkPack, NativeInductionArkPack.matches(pack)
    else {
      return [
        "Use the actual Enlirin custodian berth with the original lost-ark evidence and exact service content."
      ]
    }
    let reserve =
      parent.savedArkReserve
      ?? NativeInductionArkReserve(permission: leaf.permission, legacyRebriefDock: dock)
    guard
      let source = try? NativeInductionArkSource(
        loan: key, permission: leaf.permission,
        service: service, reserve: reserve), commander.scriptState.instances.count < 128,
      commander.scriptState.instances[NativeInductionArkPack.instance(registeredArk: source.actor)]
        == nil,
      (try? NativeArkRoutePlan(source: source, escortReachLY: commander.fullTankJumpDistance))
        != nil
    else {
      return [
        "The one finite reserved source, mission capacity and an escort-reachable route must be available."
      ]
    }
    return []
  }

  mutating func confirmInductionArkReplacement(
    dock: NativeMainStationDockReceipt,
    carrier: UUID, revision: UInt64
  ) throws {
    guard inductionArkReplacementIssues().isEmpty, nativeMainStationDockEvidenceIsCurrent,
      commander.nativeStations?.currentMainDock == dock,
      commander.hullInstanceID == carrier, commander.equipmentInventory?.revision == revision,
      var parent = wayfarerInductionMission, let leaf = parent.savedWayfarerInduction,
      let oldLink = leaf.ark, var retired = commander.scriptState.instances[oldLink.job],
      let old = retired.savedNativeArk, let loss = old.loss,
      let key = leaf.seedKey, let service = leaf.cassetteService,
      parent.revision < UInt64(Int64.max) - 1, retired.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 2,
      let pack = nativeInductionArkPack
    else { throw SaveError.invalidCommander }
    let reserve =
      parent.savedArkReserve
      ?? NativeInductionArkReserve(permission: leaf.permission, legacyRebriefDock: dock)
    let source = try NativeInductionArkSource(
      loan: key, permission: leaf.permission, service: service, reserve: reserve)
    let route = try NativeArkRoutePlan(
      source: source, escortReachLY: commander.fullTankJumpDistance)
    let sequence = commander.scriptState.nextEvent + 1
    let physicalTime = commander.flightSimulation.physicalTime
    let flightSeconds = commander.scriptState.flightSeconds
    let authorization = try NativeArkLaunchAuthorization.preparing(
      source: source, dock: dock,
      carrier: carrier, revision: revision, physicalTime: physicalTime,
      flightSeconds: flightSeconds, route: route, sequence: sequence)
    let replacement = NativeInductionArkLink(
      job: authorization.job, registeredArk: source.actor,
      operation: authorization.operation, loanOperation: key.operation)
    let receipt = NativeArkRecoveryReceipt(
      operation: try NativeArkRecoveryReceipt.identity(
        reserve: reserve, retired: oldLink, loss: loss, dock: dock, carrier: carrier,
        revision: revision, physicalTime: physicalTime), sequence: sequence,
      reserveIssue: reserve.issue, retired: oldLink, replacement: replacement,
      priorLoss: loss, dock: dock, carrier: carrier, inventoryRevision: revision,
      physicalTime: physicalTime, flightSeconds: flightSeconds)
    let nextParent = try leaf.replacingDestroyedArk(receipt, reserve: reserve)
    let bank = try old.fuel.retiring(at: receipt)
    let ark = NativeInductionArkState(authorization: authorization, fuel: try .init(source: source))
    guard ark.shapeValid(source: source, key: key) else { throw SaveError.invalidCommander }
    retired.savedNativeArk = old.replacing(fuel: bank)
    retired.revision += 1
    retired.acknowledge(sequence)
    retired.journal.append(
      "The destroyed original ark remains lost. Its unused escrow returned to its custodian; the single separately allocated reserve is now consumed. No old crew, seed or hull was resurrected."
    )
    parent.savedArkReserve = reserve
    parent.savedArkRecovery = receipt
    parent.savedWayfarerInduction = nextParent
    parent.revision += 1
    parent.acknowledge(sequence)
    parent.journal.append(
      "Enlirin's actual custodian rebrief consented to one reserved Haflinger, forty distinct reserved seed tonnes, six distinct reserved crew and its own 1000 CR fuel issue. The original borrowed key stays aboard; no payment or progress is granted. No further reserve exists."
    )
    var child = ScriptInstance(
      id: authorization.job, definition: NativeInductionArkPack.stateID,
      version: NativeInductionArkPack.version, digest: pack.digest)
    child.savedNativeArk = ark
    child.acknowledge(sequence)
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[retired.id] = retired
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.instances[child.id] = child
    emitScriptEvent("mission.accepted", only: child.id)
    notify("ONE CUSTODIAN RESERVE CONSUMED - DEPART ENLIRIN TO ESCORT")
  }
}
