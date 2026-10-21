import Foundation

extension Game {
  /// The original deadline wins over ejection/capture at the same physical time.
  mutating func recoverEMPHulls() {
    guard let state = commander.savedEMPState else { return }
    let now = commander.flightSimulation.physicalTime
    for source in state.sources {
      guard let record = commander.savedEMPState?.records[source], !record.terminal,
        !record.isRecovered, record.crewAboard > 0, record.crewDeadline.map({ now >= $0 }) == true
      else { continue }
      var candidate = self
      guard candidate.recoverEMPHull(source: source), candidate.commander.valid else { continue }
      self = candidate
    }
    restoreRecoveredEMPArchives()
  }

  private mutating func recoverEMPHull(source: ActorIdentity) -> Bool {
    guard var record = commander.savedEMPState?.records[source], record.valid,
      !record.terminal, !record.isRecovered, record.crewAboard > 0,
      let deadline = record.crewDeadline,
      commander.flightSimulation.physicalTime >= deadline
    else { return false }
    let now = commander.flightSimulation.physicalTime
    var body = record.hull.body
    let binding = record.hull.binding
    if let binding {
      guard let actual = bodies.first(where: { $0.physical?.identity == binding }),
        actual.physical?.empSource == source, actual.energy > 0
      else { return false }
      body = actual
      body.position = commander.flightSimulation.pose.systemPoint(actual.position)
      body.orientation = actual.orientation.transformed(
        by: commander.flightSimulation.pose.orientation)
    }
    if binding == nil, let physical = body.physical {
      let elapsed = now - record.hull.physicalTime
      guard elapsed.isFinite, elapsed >= 0 else { return false }
      body.position = body.position + physical.velocity * elapsed
      body.orientation = RelativeWorkController.rotated(
        body.orientation,
        omega: physical.angularVelocity, delta: elapsed)
      body.rotation += body.rotationRate * elapsed
    }
    guard var physical = body.physical, var npc = physical.npc else { return false }
    if npc.resources?.profile == .legacyEnergyOnly, npc.resources?.legacyElectricalRecharge == nil {
      guard let catalogue = physical.catalogueShipID,
        let native = ShipCatalogue.ship(catalogue)?.game, native.valid
      else { return false }
      npc.resources?.legacyElectricalRecharge = native.recharge
    }
    var reserve = npc.resources?.electrical
    // A genuine older disable episode has no separate electrical field; its
    // current native capacity/recharge supply the explicit migration boundary.
    if reserve == nil, let resources = npc.resources,
      var migrated = ElectricalReserve(
        capacity: resources.energyCapacity,
        recharge: resources.electricalRecharge, at: record.currentCrewDisableIncident.physicalTime)
    {
      guard
        migrated.drain(resources.energyCapacity, at: record.currentCrewDisableIncident.physicalTime)
      else { return false }
      reserve = migrated
    }
    guard reserve?.recover(at: now) == true else { return false }
    npc.resources?.electrical = reserve
    physical.npc = npc
    physical.empSource = nil
    physical.salvage = nil
    physical.spawnIdentity = nil
    body.physical = physical
    record.savedRecoveredAt = now
    record.hull = .init(body: body, pose: ShipPose(), time: now)
    record.hull.binding = binding
    if source.system == systemIdentity, let transfer = record.activeTrafficTransfer {
      guard let context = gameplayContext(),
        let snapshot = NPCPersistenceSnapshot.capture(
          body: body, pose: ShipPose(),
          physicalTime: now, protection: context.protection),
        let spawn = commander.npcPersistence.returnEMPTransfer(
          logical: source,
          expectedTransfer: transfer, current: snapshot, bind: binding != nil,
          protection: context.protection)
      else { return false }
      body.physical?.spawnIdentity = spawn
      record.hull.body.physical?.spawnIdentity = spawn
    } else if let binding {
      // Non-traffic police keep their current security assignment and actual actor.
      // A new source-attributed security address replaces the disabled producer.
      guard record.custody.kind == .police,
        let sequence = commander.flightSimulation.allocateSpawn()
      else { return false }
      let spawn = SpawnIdentity(
        system: binding.system, visit: binding.visit,
        sequence: sequence, member: 0, producer: .security)
      body.physical?.spawnIdentity = spawn
      record.hull.body.physical?.spawnIdentity = spawn
    }
    guard record.valid else { return false }
    commander.savedEMPState?.records[source] = record
    if let binding, let index = bodies.firstIndex(where: { $0.physical?.identity == binding }) {
      body.position = commander.flightSimulation.pose.shipPoint(body.position)
      body.orientation = body.orientation.relative(to: commander.flightSimulation.pose.orientation)
      bodies[index] = body
    }
    notify("SHIP ELECTRICAL POWER RECOVERED - CREW REMAIN ABOARD")
    return true
  }

  /// Mirror the current owner before culling, save or departure. The immutable
  /// initial custody snapshot is historical evidence and is never a restoration source.
  func updateRecoveredEMPArchive(_ record: inout EMPHullRecord, pose: ShipPose, now: Double) -> Bool
  {
    guard record.isRecovered else { return false }
    if record.savedOrdinaryTerminal != nil { return true }
    let binding = commander.npcPersistence.binding(for: record.source) ?? record.hull.binding
    if let binding, let actual = bodies.first(where: { $0.physical?.identity == binding }) {
      guard actual.physical?.empSource == nil, actual.physical?.empCrewPod == nil,
        actual.physical?.salvage == nil
      else { return false }
      record.hull = .init(body: actual, pose: pose, time: now)
      if actual.energy <= 0 { retireRecoveredRecord(&record, reason: .destroyed) }
      return record.valid
    }
    record.hull.binding = nil
    if let snapshot = commander.npcPersistence.unboundSnapshots[record.source] {
      var body = record.hull.body
      body.position = snapshot.position
      body.orientation = snapshot.orientation
      body.rotation = snapshot.rotation
      body.rotationRate = snapshot.rotationRate
      body.energy = snapshot.energy
      body.missiles = snapshot.missiles
      body.ecmEnabled = snapshot.ecmEnabled
      body.hostile = snapshot.hostile
      guard body.physical?.identity == snapshot.actor else { return false }
      body.physical?.npc = snapshot.npc
      body.physical?.population = snapshot.population
      body.physical?.velocity = snapshot.velocity
      body.physical?.angularVelocity = snapshot.angularVelocity
      body.physical?.laserCooldown = snapshot.laserCooldown
      body.physical?.catalogueShipID = snapshot.catalogueShipID
      record.hull = .init(body: body, pose: ShipPose(), time: snapshot.physicalTime)
      record.hull.binding = nil
    } else if commander.npcPersistence.terminalReason(for: record.source) == nil {
      let elapsed = now - record.hull.physicalTime
      guard elapsed.isFinite, elapsed >= 0, let physical = record.hull.body.physical else {
        return false
      }
      record.hull.body.position = record.hull.body.position + physical.velocity * elapsed
      record.hull.body.orientation = RelativeWorkController.rotated(
        record.hull.body.orientation,
        omega: physical.angularVelocity, delta: elapsed)
      record.hull.body.rotation += record.hull.body.rotationRate * elapsed
      if var resources = physical.npc?.resources {
        if var reserve = resources.electrical {
          guard
            reserve.advance(
              to: now, capacity: resources.energyCapacity,
              recharge: resources.electricalRecharge)
          else { return false }
          resources.electrical = reserve
        }
        resources.advance(delta: elapsed)
        if resources.profile == .nativeHull {
          record.hull.body.energy = min(
            resources.energyCapacity,
            record.hull.body.energy + elapsed * resources.energyRecharge)
        }
        record.hull.body.physical?.npc?.resources = resources
      }
      record.hull.physicalTime = now
    }
    return record.valid
  }

  private func retireRecoveredRecord(_ record: inout EMPHullRecord, reason: NPCTerminalReason) {
    record.savedOrdinaryTerminal = reason
    record.hull.binding = nil
    if reason == .destroyed {
      record.savedDeceasedOrdinals = record.aboardOrdinals.isEmpty ? nil : record.aboardOrdinals
      record.terminal = true
      record.lostCrewCount = record.crewTotal - record.pods.count - record.capturedCrewCount
    }
  }

  /// Retire the original complement while the actual body and logical binding still exist.
  @discardableResult
  mutating func retireRecoveredEMPActor(_ actor: ActorIdentity, reason: NPCTerminalReason) -> Bool {
    guard
      let source = commander.savedEMPState?.records.first(where: {
        $0.value.isRecovered && $0.value.savedOrdinaryTerminal == nil
          && ($0.value.hull.binding == actor
            || commander.npcPersistence.binding(for: $0.key) == actor)
      })?.key
    else { return true }
    guard var record = commander.savedEMPState?.records[source],
      let body = bodies.first(where: { $0.physical?.identity == actor }),
      (reason == .destroyed) == (body.energy <= 0)
    else { return false }
    record.hull = .init(
      body: body, pose: commander.flightSimulation.pose,
      time: commander.flightSimulation.physicalTime)
    retireRecoveredRecord(&record, reason: reason)
    guard record.valid else { return false }
    commander.savedEMPState?.records[source] = record
    return true
  }

  private mutating func restoreRecoveredEMPArchives() {
    guard let state = commander.savedEMPState, let context = gameplayContext() else { return }
    for source in state.sources where source.system == systemIdentity {
      guard let record = commander.savedEMPState?.records[source], record.isRecovered,
        !record.terminal, record.savedOrdinaryTerminal == nil,
        record.hull.binding == nil,
        commander.npcPersistence.snapshot(for: source) == nil
      else { continue }
      if let transfer = record.activeTrafficTransfer {
        guard
          let snapshot = NPCPersistenceSnapshot.capture(
            body: record.hull.body, pose: ShipPose(),
            physicalTime: record.hull.physicalTime, protection: context.protection)
        else { continue }
        _ = commander.npcPersistence.returnEMPTransfer(
          logical: source, expectedTransfer: transfer,
          current: snapshot, bind: false, protection: context.protection)
      } else if record.custody.kind == .police {
        admitRecoveredPolice(source: source)
      }
    }
  }

  /// Security recomputes its current assignment after admission; old assignments are not replayed.
  private mutating func admitRecoveredPolice(source: ActorIdentity) {
    guard let record = commander.savedEMPState?.records[source], let context = gameplayContext(),
      let physical = record.hull.body.physical, let npc = physical.npc,
      (record.hull.body.position - context.player.position).length <= context.perceptionRadius,
      let sequence = commander.flightSimulation.allocateSpawn()
    else { return }
    let request = SpawnRequest(
      identity: .init(
        system: context.system, visit: context.visit,
        sequence: sequence, member: 0, producer: .security), population: .police,
      hull: record.hull.body.hull, position: record.hull.body.position,
      orientation: record.hull.body.orientation, velocity: physical.velocity, npc: npc,
      rock: nil, payload: nil, priority: .police, catalogueShipID: physical.catalogueShipID,
      energy: record.hull.body.energy, angularVelocity: physical.angularVelocity)
    let receipts = admitEncounterPlan(
      .init(
        system: context.system, visit: context.visit,
        revision: context.revision, batches: [.init(requests: [request], atomic: true)], intents: []
      ))
    guard let actor = receipts.first?.actor,
      let index = bodies.firstIndex(where: { $0.physical?.identity == actor }),
      var admitted = bodies[index].physical
    else { return }
    var body = record.hull.body
    body.id = bodies[index].id
    body.position = commander.flightSimulation.pose.shipPoint(body.position)
    body.orientation = body.orientation.relative(to: commander.flightSimulation.pose.orientation)
    admitted.npc = npc
    admitted.blocksNavalEncounter = physical.blocksNavalEncounter
    admitted.angularVelocity = physical.angularVelocity
    admitted.laserCooldown = physical.laserCooldown
    admitted.canonicalSpin = physical.canonicalSpin
    body.physical = admitted
    bodies[index] = body
    let captured = EMPStoredObject(
      body: body, pose: commander.flightSimulation.pose,
      time: context.physicalTime)
    commander.savedEMPState?.records[source]?.hull = captured
  }
}
