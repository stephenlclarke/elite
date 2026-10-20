import Foundation

enum NativeMissionActorAdmissionPending: Sendable, Equatable {
  case unavailableArrival, outsideLocalBubble, nativeUnits, allocatorCapacity
  case native(AdmissionRefusal)
}

enum NativeMissionActorAdmissionError: Error, Sendable, Equatable {
  case invalidScene, invalidTemplate, invalidCondition, stalePlan
}

enum NativeMissionActorAdmissionPreparation: Sendable {
  case ready(NativeMissionActorAdmissionPlan)
  case pending(NativeMissionActorAdmissionPending)
  case unchanged
}

/// Only actual source and native-policy preparation can construct this transient plan.
final class NativeMissionActorAdmissionPlan: Sendable {
  let retentionPatch: MissionActorRetentionPatch
  let sceneBodyIDs: [UUID: Int]
  fileprivate let source: MissionActorAdmissionSource
  fileprivate let context: EncounterContext
  fileprivate let anchor: SpaceBody
  fileprivate let previousFlight: FlightSimulationState
  fileprivate let previousBodies: [SpaceBody]
  fileprivate let previousBodyID: Int
  fileprivate let flight: FlightSimulationState
  fileprivate let admittedBodies: [SpaceBody]

  fileprivate init(
    retentionPatch: MissionActorRetentionPatch, sceneBodyIDs: [UUID: Int],
    source: MissionActorAdmissionSource, context: EncounterContext, anchor: SpaceBody,
    previousFlight: FlightSimulationState, previousBodies: [SpaceBody], previousBodyID: Int,
    flight: FlightSimulationState, admittedBodies: [SpaceBody]
  ) {
    self.retentionPatch = retentionPatch
    self.sceneBodyIDs = sceneBodyIDs
    self.source = source
    self.context = context
    self.anchor = anchor
    self.previousFlight = previousFlight
    self.previousBodies = previousBodies
    self.previousBodyID = previousBodyID
    self.flight = flight
    self.admittedBodies = admittedBodies
  }
}

/// A successful physical commit. The adapter publishes its prevalidated selected instance
/// immediately afterwards, without another lookup, fallible operation or actor suspension.
struct NativeMissionActorAdmissionReceipt: Sendable {
  let sceneBodyIDs: [UUID: Int]
  let nativeActors: [UUID: ActorIdentity]
  let retentionPatch: MissionActorRetentionPatch
  fileprivate init(_ plan: NativeMissionActorAdmissionPlan) {
    sceneBodyIDs = plan.sceneBodyIDs
    nativeActors = Dictionary(
      uniqueKeysWithValues: plan.admittedBodies.compactMap { body in
        guard let actor = body.missionActorID, let physical = body.physical else { return nil }
        return (actor, physical.identity)
      })
    retentionPatch = plan.retentionPatch
  }
}

private struct MissionActorAdmissionCohort {
  let templates: [MissionActorAdmissionTemplate]
  let bodies: [SpaceBody]
}

private enum MissionActorAdmissionSelection {
  case outsideLocalBubble, unchanged
  case selected(MissionActorAdmissionCohort)
}

/// Immutable attempt-local values; no Game, Commander, authority or published allocator owner.
private final class MissionActorAdmissionStagedValues: Sendable {
  let previousFlight: FlightSimulationState
  let flight: FlightSimulationState
  let requests: [SpawnRequest]
  let sceneBodyIDs: [UUID: Int]
  let admittedBodies: [SpaceBody]

  init(
    previousFlight: consuming FlightSimulationState, flight: consuming FlightSimulationState,
    requests: consuming [SpawnRequest], sceneBodyIDs: consuming [UUID: Int],
    admittedBodies: consuming [SpaceBody]
  ) {
    self.previousFlight = consume previousFlight
    self.flight = consume flight
    self.requests = consume requests
    self.sceneBodyIDs = consume sceneBodyIDs
    self.admittedBodies = consume admittedBodies
  }
}

private enum MissionActorAdmissionStaging {
  case pending(NativeMissionActorAdmissionPending)
  case staged(MissionActorAdmissionStagedValues)
}

extension Game {
  /// Read at the existing visit guard, then release the computed Commander receiver.
  @inline(never)
  private func currentMissionActorAdmissionVisit() -> UInt64 {
    commander.flightSimulation.visit
  }

  /// Invalid source/scene facts are refused before eligibility, temporary capacity or no-op.
  /// No native counter, body or retained address is published by preparation.
  func prepareMissionActorAdmission(_ source: MissionActorAdmissionSource) throws
    -> NativeMissionActorAdmissionPreparation
  {
    try validateMissionActorAdmissionSource(source)
    let currentContext = gameplayContext()
    try validateMissionActorAdmissionScene(context: currentContext)
    for index in source.actors.indices {
      try validateMissionActorAdmissionTemplate(source.actors[index], source: source)
    }
    guard !docked, source.system == systemIdentity, let context = currentContext,
      let anchor = scriptAnchor
    else { return .pending(.unavailableArrival) }
    guard anchor.position.finite, anchor.position.length.isFinite, anchor.orientation.validRotation,
      context.system == systemIdentity, context.visit == currentMissionActorAdmissionVisit()
    else { throw NativeMissionActorAdmissionError.invalidScene }
    switch try selectMissionActorAdmissionCohort(source, context: context, anchor: anchor) {
    case .outsideLocalBubble: return .pending(.outsideLocalBubble)
    case .unchanged: return .unchanged
    case .selected(let cohort):
      switch try stageMissionActorAdmission(context: context, cohort: cohort) {
      case .pending(let reason): return .pending(reason)
      case .staged(let staged):
        return try Self.finishMissionActorAdmission(
          original: self, source: source, context: context, anchor: anchor,
          templates: cohort.templates, staged: staged)
      }
    }
  }

  /// Selection finishes before native staging starts, so its descriptor/body/binding temporaries
  /// do not share a frame with the physical allocator and condition preparation.
  private func selectMissionActorAdmissionCohort(
    _ source: MissionActorAdmissionSource, context: EncounterContext, anchor: SpaceBody
  ) throws -> MissionActorAdmissionSelection {
    let present = Set(bodies.compactMap(\.missionActorID))
    var selected: [MissionActorAdmissionTemplate] = []
    var prepared: [SpaceBody] = []
    for template in source.actors {
      guard template.presence != .destroyed, template.canonicalBody.energy > 0 else { continue }
      if present.contains(template.actorID) {
        guard source.mode == .retained,
          let body = bodies.first(where: { $0.missionActorID == template.actorID }),
          body.missionInstanceID == source.instanceID,
          body.id == source.retention.actors[template.alias]?.body.id,
          let descriptor = currentMissionActorDescriptor(bodyID: body.id)
        else { throw NativeMissionActorAdmissionError.invalidScene }
        _ = try MissionNativeBridge.bindActor(descriptor: descriptor, body: body, context: context)
        continue
      }
      guard source.mode == .prepared || template.presence != .prepared else {
        throw NativeMissionActorAdmissionError.invalidTemplate
      }
      var body = template.canonicalBody
      body.position = anchor.position + anchor.orientation.apply(body.position)
      body.orientation = body.orientation.transformed(by: anchor.orientation)
      if let velocity = body.scriptNPC?.velocity {
        body.scriptNPC?.velocity = anchor.orientation.apply(velocity)
      }
      guard body.position.finite, body.position.length.isFinite, body.orientation.validRotation,
        body.scriptNPC?.velocity.finite ?? true
      else { throw NativeMissionActorAdmissionError.invalidTemplate }
      if body.leavesLocalBubble {
        if source.mode == .prepared { return .outsideLocalBubble }
        continue
      }
      selected.append(template)
      prepared.append(body)
    }
    guard !selected.isEmpty else { return .unchanged }
    return .selected(.init(templates: selected, bodies: prepared))
  }

  /// Stage only the selected cohort. The immutable heap-owned plan keeps its large snapshots
  /// out of every preparation result value; no Game value is captured or copied into the plan.
  @inline(never)
  private func stageMissionActorAdmission(
    context: EncounterContext, cohort: MissionActorAdmissionCohort
  ) throws -> MissionActorAdmissionStaging {
    let selected = cohort.templates
    var prepared = cohort.bodies
    let units =
      bodies.reduce(0) { $0 + $1.scriptNativeUnits }
      + selected.reduce(0) { $0 + $1.nativeUnits }
    guard units <= 1024 else { return .pending(.nativeUnits) }
    let flight = commander.flightSimulation
    guard prepared.count <= 999_999_999 - nextBodyID,
      UInt64(prepared.count) < UInt64.max - flight.nextActor,
      flight.nextSpawn < UInt64.max - 1
    else { return .pending(.allocatorCapacity) }
    var staged = flight
    guard let sequence = staged.allocateSpawn() else { return .pending(.allocatorCapacity) }
    var requests: [SpawnRequest] = []
    var addresses: [UUID: Int] = [:]
    for index in prepared.indices {
      let template = selected[index]
      guard let actor = staged.allocateActor() else { return .pending(.allocatorCapacity) }
      let spawn = SpawnIdentity(
        system: context.system, visit: context.visit, sequence: sequence,
        member: UInt16(index), producer: .mission)
      prepared[index].id = nextBodyID + index
      let velocity: Vector3
      if let viewVelocity = prepared[index].scriptNPC?.velocity {
        velocity = staged.pose.orientation.apply(viewVelocity)
      } else {
        velocity = template.retainedNativeVelocity ?? .init(0, 0, 0)
      }
      var physical = nativePhysicalActorState(
        for: prepared[index], identity: actor, spawnIdentity: spawn, velocity: velocity)
      if var condition = template.retainedNativeCondition {
        // Condition is retained; references to former visit addresses are not authority.
        if let aggressor = condition.firstAggressor,
          !currentMissionActorTarget(aggressor, context: context)
        {
          condition.firstAggressor = nil
        }
        condition.intention = restoredMissionActorIntention(
          condition.intention, template: template, context: context)
        condition.resources = condition.resources ?? physical.npc?.resources
        physical.npc = condition
      }
      physical.laserCooldown = template.retainedNativeLaserCooldown ?? 0
      let measuredEnergyCapacityValid: Bool
      if let resources = physical.npc?.resources {
        measuredEnergyCapacityValid = resources.energyCapacity == template.maximumHullEnergy
      } else {
        measuredEnergyCapacityValid =
          template.canonicalBody.scriptNPC != nil && template.maximumHullEnergy > 100_000
      }
      guard physical.population == .mission, physical.npc?.role == .mission,
        measuredEnergyCapacityValid, physical.velocity.finite
      else { throw NativeMissionActorAdmissionError.invalidCondition }
      prepared[index].physical = physical
      addresses[template.actorID] = prepared[index].id
      var request = SpawnRequest(
        identity: spawn, population: .mission, hull: prepared[index].hull,
        position: staged.pose.systemPoint(prepared[index].position),
        orientation: prepared[index].orientation.transformed(by: staged.pose.orientation),
        velocity: velocity, npc: physical.npc, rock: nil, payload: nil, priority: .mission)
      request.energy = prepared[index].energy
      requests.append(request)
    }
    guard staged.valid else { throw NativeMissionActorAdmissionError.invalidScene }
    return .staged(
      .init(
        previousFlight: consume flight, flight: consume staged, requests: consume requests,
        sceneBodyIDs: consume addresses, admittedBodies: consume prepared))
  }

  /// Allocator/physical construction has actually returned before policy and retention work starts.
  @inline(never)
  private static func finishMissionActorAdmission(
    original: borrowing Game, source: borrowing MissionActorAdmissionSource,
    context: EncounterContext, anchor: borrowing SpaceBody,
    templates: [MissionActorAdmissionTemplate], staged: MissionActorAdmissionStagedValues
  ) throws -> NativeMissionActorAdmissionPreparation {
    if let refusal = original.gameplayMissionActorAdmissionRefusal(
      staged.requests, templates: templates, context: context)
    {
      if refusal == .staleContext { throw NativeMissionActorAdmissionError.invalidScene }
      return .pending(.native(refusal))
    }
    let patch = try source.prepareRetentionPatch(sceneBodyIDs: staged.sceneBodyIDs)
    return .ready(
      .init(
        retentionPatch: patch, sceneBodyIDs: staged.sceneBodyIDs, source: copy source,
        context: context, anchor: copy anchor, previousFlight: staged.previousFlight,
        previousBodies: original.bodies, previousBodyID: original.nextBodyID,
        flight: staged.flight, admittedBodies: staged.admittedBodies))
  }

  /// All adapter retention staging must finish before this call. The commit itself appends
  /// the whole cohort and allocators together; it never adopts unrelated bodies or clones Game.
  mutating func commitMissionActorAdmission(_ plan: NativeMissionActorAdmissionPlan) throws
    -> NativeMissionActorAdmissionReceipt
  {
    try validateMissionActorAdmissionSource(plan.source)
    return try commitValidatedMissionActorAdmission(plan)
  }

  /// Keep scene validation and commit storage out of the full source-validation call chain.
  private mutating func commitValidatedMissionActorAdmission(
    _ plan: NativeMissionActorAdmissionPlan
  ) throws -> NativeMissionActorAdmissionReceipt {
    let context = gameplayContext()
    try validateMissionActorAdmissionScene(context: context)
    guard !docked, context == plan.context, scriptAnchor == plan.anchor,
      commander.flightSimulation == plan.previousFlight, nextBodyID == plan.previousBodyID,
      bodies == plan.previousBodies
    else { throw NativeMissionActorAdmissionError.stalePlan }
    let receipt = NativeMissionActorAdmissionReceipt(plan)
    commander.flightSimulation = plan.flight
    bodies.append(contentsOf: plan.admittedBodies)
    nextBodyID += plan.admittedBodies.count
    return receipt
  }

  private func validateMissionActorAdmissionScene(context: EncounterContext?) throws {
    let flight = commander.flightSimulation
    let actualSystem = systemIdentity
    let bodyCursor = nextBodyID
    let identities = bodies.compactMap { $0.physical?.identity }
    let spawns = bodies.compactMap { $0.physical?.spawnIdentity }
    let missions = bodies.compactMap(\.missionActorID)
    guard flight.valid, (1..<1_000_000_000).contains(nextBodyID),
      Set(bodies.map(\.id)).count == bodies.count,
      bodies.allSatisfy({
        (0..<bodyCursor).contains($0.id) && $0.position.finite
          && $0.position.length.isFinite && $0.orientation.validRotation && $0.energy.isFinite
      }),
      Set(identities).count == identities.count, Set(spawns).count == spawns.count,
      Set(missions).count == missions.count,
      identities.allSatisfy({
        $0.system == actualSystem && $0.visit == flight.visit
          && $0.entity > 0 && $0.entity < flight.nextActor
      }),
      spawns.allSatisfy({
        NativeMissionSpawnAddress.isCurrent(
          $0, system: actualSystem, visit: flight.visit, nextFlightSpawn: flight.nextSpawn)
      })
    else { throw NativeMissionActorAdmissionError.invalidScene }
    for body in bodies {
      guard body.energy <= 0 || body.physical != nil else {
        throw NativeMissionActorAdmissionError.invalidScene
      }
      guard body.physical?.velocity.finite ?? true,
        body.physical?.velocity.length.isFinite ?? true,
        body.physical?.npc?.resources?.valid ?? true
      else { throw NativeMissionActorAdmissionError.invalidCondition }
      if body.energy > 0,
        body.missionActorID != nil || body.missionInstanceID != nil || body.scriptNPC != nil
      {
        guard let context, let descriptor = currentMissionActorDescriptor(bodyID: body.id),
          body.physical?.population == .mission, body.physical?.npc?.role == .mission
        else { throw NativeMissionActorAdmissionError.invalidScene }
        do {
          _ = try MissionNativeBridge.bindActor(
            descriptor: descriptor, body: body, context: context)
        } catch {
          throw NativeMissionActorAdmissionError.invalidScene
        }
      }
    }
  }

  private func currentMissionActorTarget(_ target: ActorIdentity, context: EncounterContext) -> Bool
  {
    target == context.player.identity
      || context.actors.contains { $0.identity == target && $0.energy > 0 }
  }

  /// Address-free navigation survives reentry. Native-address actions require an actual
  /// current target; a new attack target is derived only from immutable declared hostility.
  private func restoredMissionActorIntention(
    _ intention: NPCAction?, template: MissionActorAdmissionTemplate, context: EncounterContext
  ) -> NPCAction? {
    switch intention {
    case .navigate: return intention
    case .engage(let target):
      guard template.declaredHostile else { return nil }
      return .engage(
        currentMissionActorTarget(target, context: context) ? target : context.player.identity)
    case .flee(let target):
      return currentMissionActorTarget(target, context: context) ? intention : nil
    case .dock(let target):
      return target == context.anchors.station.identity ? intention : nil
    case .mine(let rock):
      return miningFields.contains { $0.rocks.contains { $0.identity == rock } }
        && !context.depletedRocks.contains(rock) ? intention : nil
    case .scoop(let payload):
      return context.actors.contains { $0.payload == payload && $0.energy > 0 } ? intention : nil
    case nil: return nil
    }
  }

  private func validateMissionActorAdmissionTemplate(
    _ template: borrowing MissionActorAdmissionTemplate,
    source: borrowing MissionActorAdmissionSource
  ) throws {
    let maximumHullEnergy = template.maximumHullEnergy
    let body = template.canonicalBody
    guard body.id == -1, body.physical == nil, body.missionActorID == template.actorID,
      body.missionInstanceID == source.instanceID,
      template.radius.isFinite, template.radius > 0, template.nativeUnits > 0,
      template.nativeUnits == body.scriptNativeUnits,
      body.energy.isFinite, body.energy >= 0, body.energy <= maximumHullEnergy,
      maximumHullEnergy.isFinite, maximumHullEnergy > 0,
      template.parts.allSatisfy({
        $0.energy.isFinite && $0.energy >= 0
          && $0.maximumEnergy.isFinite && $0.maximumEnergy > 0 && $0.energy <= $0.maximumEnergy
          && $0.mesh.vertices.allSatisfy({ $0.finite && $0.length.isFinite })
      }),
      template.retainedNativeVelocity.map({ $0.finite && $0.length.isFinite }) ?? true,
      template.retainedNativeLaserCooldown.map({ $0.isFinite && $0 >= 0 }) ?? true
    else { throw NativeMissionActorAdmissionError.invalidTemplate }
    if let condition = template.retainedNativeCondition {
      if case .navigate(let position, let speed) = condition.intention {
        let maximumSpeed =
          body.scriptNPC?.fit.definition.speed
          ?? ((ShipCatalogue.nativeShip(body.hull)?.game?.speed ?? 20) * 18)
        guard position.finite, position.length.isFinite, speed.isFinite,
          speed >= 0, speed <= maximumSpeed
        else { throw NativeMissionActorAdmissionError.invalidCondition }
      }
      guard condition.role == .mission, (0...255).contains(condition.legal.value),
        condition.legal.bountyTenths >= 0, condition.resources?.valid ?? true,
        condition.resources.map({ $0.energyCapacity == maximumHullEnergy }) ?? true
      else { throw NativeMissionActorAdmissionError.invalidCondition }
    }
  }
}
