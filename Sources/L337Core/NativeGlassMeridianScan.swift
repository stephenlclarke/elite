import Foundation

extension Game {
  func glassMeridianSample() -> NativeOriginalSurveySample? {
    guard !paused, !docked, !playerEMPDisabled, screen == .front, energy.isFinite, energy > 0,
      jumpCountdown == nil, pendingNativeStationDock == nil,
      systemIdentity == NativeGlassMeridian.objective,
      glassMeridianPack != nil,
      let mission = glassMeridianMission, mission.outcome == .active, mission.suspension == nil,
      let state = mission.savedGlassMeridian, state.readings.count < 2,
      let equipment = commander.fittedEquipment(at: .targetingCore), commander.targetingTier != nil,
      let inventory = commander.equipmentInventory, inventory.owner == state.permission.owner,
      let player = commander.flightSimulation.player, let selected = informationTargetBody,
      let physical = selected.physical, selected.energy > 0, !selected.hostile,
      equipment.location?.hullInstanceID == inventory.activeHull,
      let ordinal = NativeGlassMeridian.targets.indices.first(where: { index in
        mission.ownedEncounters[NativeGlassMeridian.encounters[index]]?
          .actors[NativeGlassMeridian.targets[index]]?.identity == selected.missionActorID
      }), !state.readings.contains(where: { $0.reading.ordinal == ordinal }),
      let encounter = mission.ownedEncounters[NativeGlassMeridian.encounters[ordinal]],
      encounter.admitted,
      let actor = encounter.actors[NativeGlassMeridian.targets[ordinal]],
      actor.presence == .present, actor.identity == selected.missionActorID,
      selected.missionInstanceID == mission.id, actor.body.id == selected.id,
      actor.body.physical?.identity == physical.identity,
      physical.identity.system == player.system, physical.identity.visit == player.visit,
      physical.identity.entity > 1,
      selected.scriptNPC?.fit.definition.id == NativeGlassMeridian.markerID,
      selected.position.finite, selected.position.length > 0,
      selected.position.unit.dot(Vector3(0, 0, 1)) >= cos(2 * Double.pi / 180),
      let contact = try? nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1),
        range: 1500, radius: 0, includePlayer: false),
      contact.hit.target == .body(selected.id), (250...1500).contains(contact.hit.distance)
    else { return nil }
    return .init(
      mission: mission.id, permission: state.permission.operation, owner: inventory.owner,
      carrier: inventory.activeHull, equipment: equipment.id, inventoryRevision: inventory.revision,
      ordinal: ordinal, marker: actor.identity, actor: physical.identity, player: player,
      time: commander.flightSimulation.physicalTime, epoch: nativeStationRuntimeEpoch)
  }

  mutating func applyGlassMeridianPending() throws -> Bool {
    guard let pending = nativeGlassMeridianRuntime?.pending?.sealed else { return false }
    guard var mission = glassMeridianMission, var state = mission.savedGlassMeridian,
      mission.outcome == .active, pending.reading.permission == state.permission.operation,
      !state.readings.contains(where: { $0.reading.ordinal == pending.reading.ordinal })
    else { throw SaveError.invalidCommander }
    state.readings.append(pending)
    guard NativeGlassMeridian.readingsValid(state) else { throw SaveError.invalidCommander }
    mission.savedGlassMeridian = state
    if state.readings.count == 2 {
      mission.milestones.insert(1)
    }
    commander.scriptState.instances[mission.id] = mission
    nativeGlassMeridianRuntime?.pending = nil
    return true
  }
}

extension GameRuntime {
  func commitGlassMeridianScan(start: NativeOriginalSurveySample?) {
    guard game.glassMeridianMission != nil else { return }
    if game.nativeGlassMeridianRuntime == nil { game.nativeGlassMeridianRuntime = .init() }
    if game.nativeGlassMeridianRuntime?.pending == nil, !game.paused {
      stageGlassMeridianReading(start: start)
    }
    guard game.nativeGlassMeridianRuntime?.pending != nil, let publish = scriptPublisher() else {
      return
    }
    var candidate = game
    do {
      _ = try candidate.applyGlassMeridianPending()
      try publish(&candidate)
      game = candidate
    } catch { game.notify("CLOCK READING NOT SAVED - SAME MEASURED EVIDENCE RETAINED") }
  }
  @inline(never)
  private func stageGlassMeridianReading(start: NativeOriginalSurveySample?) {
    guard let start, let end = game.glassMeridianSample(), start.sameAuthority(as: end),
      end.time > start.time, end.time - start.time <= 0.1 + 1e-9
    else {
      game.nativeGlassMeridianRuntime?.observation = nil
      return
    }
    guard
      let observation = try? NativeGlassMeridian.observe(
        previous: game.nativeGlassMeridianRuntime?.observation, first: start, last: end)
    else {
      game.nativeGlassMeridianRuntime?.observation = nil
      return
    }
    game.nativeGlassMeridianRuntime?.observation = observation
    guard observation.seconds >= 12,
      let mission = game.glassMeridianMission, let state = mission.savedGlassMeridian,
      let purchase = try? game.commander.purchaseSnapshot(),
      let equipment = purchase.items.first(where: { $0.id == end.equipment }),
      let marker = mission.ownedEncounters[NativeGlassMeridian.encounters[end.ordinal]]?
        .actors[NativeGlassMeridian.targets[end.ordinal]]
    else { return }
    do {
      let operation = NativeGlassMeridian.readingOperation(
        permission: state.permission.operation, ordinal: end.ordinal)
      let authorityID = try NativeOriginalSurvey.authorityIdentity(
        operation: operation, equipment: equipment,
        inventoryRevision: end.inventoryRevision, epoch: end.epoch, actor: end.actor)
      let reading = NativeOriginalSurveyReading(
        operation: operation, authority: authorityID,
        mission: end.mission, permission: end.permission, owner: end.owner, carrier: end.carrier,
        equipment: end.equipment, inventoryRevision: end.inventoryRevision, ordinal: end.ordinal,
        marker: end.marker, actor: end.actor, player: end.player, start: observation.first.time,
        end: end.time, qualifiedSeconds: observation.seconds, intervals: observation.intervals,
        epoch: end.epoch, revision: UInt64(end.ordinal + 1))
      let authority = NativeOriginalSurveyAuthority(
        id: authorityID, operation: operation,
        permission: end.permission, owner: end.owner, carrier: end.carrier,
        inventoryRevision: end.inventoryRevision, epoch: end.epoch, equipment: equipment,
        marker: marker, observedAt: end.time)
      game.nativeGlassMeridianRuntime?.pending = .init(
        .init(reading: reading, authority: authority))
      game.nativeGlassMeridianRuntime?.observation = nil
    } catch { return }

  }

}
