import Foundation

extension Game {
  /// Facility life uses the original registered native resources, including outside render range.
  /// A currently visible station/service dialog is not a prerequisite for work at the remote spur.
  var isolationWorkStationsAlive: Bool {
    guard let owner = commander.equipmentOwnerID, let world = commander.nativeStations else {
      return false
    }
    for location in [NativeIsolationWorkSource.issuerLocation, NativeIsolationWorkSource.location] {
      guard
        let station = world.mainStations.first(where: { $0.world == owner && $0.system == location }
        ),
        let resource = commander.scriptState.stationResources[station.key],
        resource.valid, resource.identity == station.resource, !resource.destroyed,
        resource.energy > 0
      else { return false }
    }
    return true
  }

  /// Mirrors an actual native death in the existing retained-actor removal boundary.
  mutating func recordIsolationWorkModuleLoss(_ body: SpaceBody, in child: inout ScriptInstance) {
    guard body.energy <= 0, NativeIsolationWorkPack.marked(child),
      var state = child.savedIsolationWork,
      let index = state.modules.firstIndex(where: {
        body.missionActorID == NativeIsolationWorkPack.actor(job: child.id, role: $0.role)
      }), state.modules[index].loss == nil, state.modules[index].admission != nil,
      let native = body.physical?.identity,
      var parent = commander.scriptState.instances[state.permission.parent],
      child.revision < UInt64(Int64.max) - 1, parent.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { return }
    let sequence = commander.scriptState.nextEvent + 1
    state.modules[index].loss = .init(
      actor: native, sequence: sequence, physicalTime: commander.flightSimulation.physicalTime)
    child.savedIsolationWork = state
    child.revision += 1
    child.acknowledge(sequence)
    parent.revision += 1
    parent.acknowledge(sequence)
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.nextEvent = sequence
    isolationWorkRuntime.dirty = true
    interruptIsolationWork()
  }

  mutating func observeIsolationWorkStationLoss() {
    guard var child = isolationWorkChild, var state = child.savedIsolationWork,
      state.stationLoss == nil, let world = commander.nativeStations,
      let station = world.mainStations.first(where: {
        $0.world == state.permission.owner
          && [NativeIsolationWorkSource.location, NativeIsolationWorkSource.issuerLocation]
            .contains($0.system)
          && commander.scriptState.stationResources[$0.key]?.destroyed == true
      }), var parent = commander.scriptState.instances[state.permission.parent],
      child.revision < UInt64(Int64.max) - 1, parent.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { return }
    let sequence = commander.scriptState.nextEvent + 1
    state.stationLoss = .init(
      station: station, sequence: sequence, physicalTime: commander.flightSimulation.physicalTime)
    child.savedIsolationWork = state
    child.revision += 1
    child.acknowledge(sequence)
    parent.revision += 1
    parent.acknowledge(sequence)
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[child.id] = child
    commander.scriptState.instances[parent.id] = parent
    isolationWorkRuntime.dirty = true
    interruptIsolationWork()
  }

  /// Runs inside the real prepared-encounter candidate, after native admission has committed.
  /// The first station-relative poses are frozen here; reload/re-entry cannot mint another pair.
  mutating func recordIsolationWorkAdmission(in child: inout ScriptInstance) throws {
    guard NativeIsolationWorkPack.marked(child) else { return }
    guard var state = child.savedIsolationWork,
      state.modules.allSatisfy({ $0.admission == nil }),
      let group = child.ownedEncounters[NativeIsolationWorkPack.encounter], group.admitted,
      let anchor = currentNativeMainStationAnchor(at: commander.flightSimulation.physicalTime),
      anchor.identity.system == NativeIsolationWorkSource.location,
      var parent = commander.scriptState.instances[state.permission.parent],
      child.revision < UInt64(Int64.max) - 1, parent.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let sequence = commander.scriptState.nextEvent + 1
    let original = NativeIsolationWorkSource(owner: state.permission.owner)
    let time = commander.flightSimulation.physicalTime
    for index in state.modules.indices {
      let role = state.modules[index].role
      guard let retained = group.actors[role.rawValue], retained.presence == .present,
        let actual = bodies.first(where: { $0.missionActorID == retained.identity }),
        let native = actual.physical,
        native.identity.system == anchor.identity.system,
        native.identity.visit == anchor.identity.visit,
        native.population == .mission, native.npc?.role == .mission,
        let fit = actual.scriptNPC?.fit, original.matches(fit)
      else { throw SaveError.invalidCommander }
      let expected = try original.initialPose(role, reference: anchor)
      let pose = modelPose(of: actual)
      guard (pose.position - expected.position).length < 1e-5,
        (pose.orientation.x - expected.orientation.x).length < 1e-8,
        (pose.orientation.y - expected.orientation.y).length < 1e-8,
        (pose.orientation.z - expected.orientation.z).length < 1e-8
      else { throw SaveError.invalidCommander }
      state.modules[index].admission = .init(
        source: original.id, role: role, logicalActor: retained.identity, actor: native.identity,
        station: anchor, pose: expected, geometry: try NativeIsolationWorkSource.geometryHash,
        sequence: sequence, physicalTime: time)
      state.modules[index].binding = native.identity
    }
    guard state.shapeValid else { throw SaveError.invalidCommander }
    child.savedIsolationWork = state
    child.revision += 1
    child.acknowledge(sequence)
    parent.revision += 1
    parent.acknowledge(sequence)
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.nextEvent = sequence
  }

  var isolationWorkChild: ScriptInstance? {
    guard let owner = commander.equipmentOwnerID else { return nil }
    let original = NativeIsolationWorkSource(owner: owner)
    return commander.scriptState.instances[NativeIsolationWorkPack.instance(source: original.id)]
  }

  var currentIsolationWorkParentAuthority: NativeIsolationWorkParentAuthority? {
    guard let child = isolationWorkChild, child.suspension == nil,
      child.definition == NativeIsolationWorkPack.stateID,
      child.digest == NativeIsolationWorkPack.digest,
      let state = child.savedIsolationWork,
      nativeIsolationWorkPack != nil
    else { return nil }
    guard
      let value = try? NativeIsolationWorkParentAuthority.resolve(
        parentID: state.permission.parent, commander: commander
      ).authority,
      state.permission.matches(
        value, programmer: NativeIsolationProgrammerDefinition.serial(parent: value.parentID))
    else { return nil }
    return value
  }

  var nativeIsolationWorkPack: ScriptPack? {
    scriptPacks.first(where: NativeIsolationWorkPack.matches)
  }

  /// Called only inside the parent's actual Confirm candidate after canonical issue.
  /// This neither publishes nor executes a nested Lua transaction.
  mutating func authorizeIsolationWork(parentID: UUID) throws {
    guard !isMissionTrial, !paused, docked, dockedAtMainStation,
      nativeMainStationDockEvidenceIsCurrent, scriptDurabilityAvailable,
      nativeIsolationWorkPack != nil
    else { throw SaveError.invalidCommander }
    let resolved = try NativeIsolationWorkParentAuthority.resolve(
      parentID: parentID, commander: commander)
    let authority = resolved.authority
    let primitive = resolved.primitive
    guard let arrival = nativeMainStationArrivalContext(for: authority.acceptance.station),
      arrival.receipt == authority.acceptance, acceptsNativeMainStationArrivalContext(arrival)
    else { throw SaveError.invalidCommander }
    let original = NativeIsolationWorkSource(owner: authority.owner)
    let job = NativeIsolationWorkPack.instance(source: original.id)
    if let existing = commander.scriptState.instances[job] {
      guard existing.definition == NativeIsolationWorkPack.stateID,
        existing.digest == NativeIsolationWorkPack.digest, let state = existing.savedIsolationWork,
        state.source == original.id,
        state.permission.matches(
          authority, programmer: NativeIsolationProgrammerDefinition.serial(parent: parentID))
      else { throw SaveError.invalidCommander }
      return
    }
    guard commander.scriptState.instances.count < 128,
      !commander.scriptState.instances.values.contains(where: { NativeIsolationWorkPack.marked($0) }
      ),
      primitive.sequence <= commander.scriptState.nextEvent,
      primitive.physicalTime == commander.flightSimulation.physicalTime,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 2,
      commander.scriptState.pendingEvents.count < 4096,
      var parent = commander.scriptState.instances[parentID],
      parent.hasAcknowledged(primitive.sequence), parent.revision < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let sequence = commander.scriptState.nextEvent + 1
    let permission = try NativeIsolationWorkPermission(
      authority: authority, commander: commander, sequence: sequence)
    let state = try NativeIsolationWorkState(permission: permission)
    guard state.shapeValid else { throw SaveError.invalidCommander }
    var child = ScriptInstance(
      id: job, definition: NativeIsolationWorkPack.stateID,
      version: NativeIsolationWorkPack.version, digest: NativeIsolationWorkPack.digest)
    child.savedIsolationWork = state
    child.revision = 1
    child.acknowledge(sequence)
    parent.acknowledge(sequence)
    parent.revision += 1
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[parentID] = parent
    commander.scriptState.instances[job] = child
    emitScriptEvent("mission.accepted", only: job, drain: false)
  }
}
