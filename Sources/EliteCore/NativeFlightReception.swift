import Foundation

struct NativeFlightReceptionDefinition: Codable, Sendable, Equatable {
  let profile: String
  var valid: Bool { profile == "native-main-berth-flight-v1" }
}

struct NativeFlightReceptionPermission: Codable, Sendable, Equatable {
  let mission: UUID
  let operation: UUID
  let owner: UUID
  let carrier: UUID
  let inventoryRevision: UInt64
  let dock: NativeMainStationDockReceipt
  let fit: [EquipmentPurchaseItem]
  let epoch: UUID
}

/// Qualified only by the native frame producer below; values alone never grant a terminal.
struct NativeFlightReceptionSample: Codable, Sendable, Equatable {
  let mission: UUID
  let permission: UUID
  let owner: UUID
  let carrier: UUID
  let inventoryRevision: UInt64
  let station: NativeMainStationIdentity
  let player: ActorIdentity
  let actor: ActorIdentity
  let pose: ShipPose
  let stationPosition: Vector3
  let relativeVelocity: Vector3
  let time: Double
  let epoch: UUID

  var qualifies: Bool {
    guard station.valid, station.system.system < 256, owner == station.world,
      player.system == station.system, actor.system == station.system,
      player.entity == 0, actor.entity == 1, player.visit > 0,
      player.visit == actor.visit, player.visit < UInt64(Int64.max),
      pose.position.finite, pose.orientation.validRotation, stationPosition.finite,
      relativeVelocity.finite,
      time.isFinite, (0...1e12).contains(time)
    else { return false }
    let relative = stationPosition - pose.position
    let distance = relative.length
    guard distance.isFinite, (1000...1500).contains(distance) else { return false }
    let forward = pose.orientation.z
    return relative.unit.dot(forward) >= cos(2 * Double.pi / 180)
      && relativeVelocity.dot(relative.unit) > 0
  }

  func sameAuthority(as other: Self) -> Bool {
    mission == other.mission && permission == other.permission && owner == other.owner
      && carrier == other.carrier && inventoryRevision == other.inventoryRevision
      && station == other.station && player == other.player && actor == other.actor
      && epoch == other.epoch
  }
}

struct NativeFlightReceptionReading: Codable, Sendable, Equatable {
  let operation: UUID
  let first: NativeFlightReceptionSample
  let last: NativeFlightReceptionSample
  let authority: UUID

  fileprivate init(first: NativeFlightReceptionSample, last: NativeFlightReceptionSample) throws {
    operation = ScriptIdentity.uuid(
      "flight-reception-reading-v1:\(first.permission):\(first.player.visit)")
    self.first = first
    self.last = last
    authority = try NativeFlightReception.authority(first: first, last: last)
  }
}

struct NativeFlightReceptionState: Codable, Sendable, Equatable {
  let permission: NativeFlightReceptionPermission
  var reading: NativeFlightReceptionReading?
  var terminalOperation: UUID?
  var terminalDock: NativeMainStationDockReceipt?
  var terminalOutcome: ScriptOutcome?
}

/// Attempt-local immutable evidence permits publication retry without replaying flight.
final class NativeFlightReceptionPending: Sendable {
  let reading: NativeFlightReceptionReading
  init(_ reading: NativeFlightReceptionReading) { self.reading = reading }
}

enum NativeFlightReception {
  static let stateID = "l337.training/flight-reception"
  static let capability = "native-flight-reception-v1"
  static let boardID = "flight-reception"
  static let version = "1.0.0"
  static let digest = "bc01834e04f87816c8021b76fabe3d9b8f3af394ff8fcd420c4b7c3acf1350d4"

  static func permissionOperation(
    mission: UUID, owner: UUID, carrier: UUID, revision: UInt64,
    dock: NativeMainStationDockReceipt, fit: [EquipmentPurchaseItem]
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "flight-reception-permission-v1:\(owner):\(mission):\(carrier):\(revision):\(try hash(dock)):\(try hash(fit))"
    )
  }
  static func hash<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return ScriptPackLibrary.hash(try encoder.encode(value))
  }
  static func authority(first: NativeFlightReceptionSample, last: NativeFlightReceptionSample)
    throws -> UUID
  {
    ScriptIdentity.uuid("flight-reception-authority-v1:\(try hash(first)):\(try hash(last))")
  }
  static func measure(first: NativeFlightReceptionSample, last: NativeFlightReceptionSample)
    throws -> NativeFlightReceptionReading
  {
    guard first.qualifies, last.qualifies, first.sameAuthority(as: last),
      last.time > first.time, last.time - first.time <= 0.1 + 1e-9,
      (last.stationPosition - last.pose.position).length
        < (first.stationPosition - first.pose.position).length,
      (last.pose.position - first.pose.position).length > 1e-9
    else { throw SaveError.invalidCommander }
    return try .init(first: first, last: last)
  }
  static func readingValid(_ value: NativeFlightReceptionReading) -> Bool {
    guard let expected = try? measure(first: value.first, last: value.last) else { return false }
    return expected == value
  }
  static func returnReady(_ state: NativeFlightReceptionState, dock: NativeMainStationDockReceipt)
    -> Bool
  {
    guard let reading = state.reading, readingValid(reading), dock.valid,
      reading.first.mission == state.permission.mission,
      reading.first.permission == state.permission.operation,
      reading.first.owner == state.permission.owner,
      reading.first.carrier == state.permission.carrier,
      reading.first.inventoryRevision == state.permission.inventoryRevision,
      reading.first.station == state.permission.dock.station,
      reading.first.player.visit > state.permission.dock.actor.visit,
      dock.station == state.permission.dock.station,
      dock.commanderOwner == state.permission.owner,
      dock.sequence > state.permission.dock.sequence,
      dock.actor.visit >= reading.last.actor.visit
    else { return false }
    return true
  }
}

extension Game {
  var activeFlightReception: (instance: ScriptInstance, state: NativeFlightReceptionState)? {
    for instance in commander.scriptState.instances.values
    where instance.definition == NativeFlightReception.stateID && instance.outcome == .active {
      if let state = instance.savedFlightReception { return (instance, state) }
    }
    return nil
  }

  /// Only real positive native frames with registered station identity and clear geometry qualify.
  func flightReceptionSample() -> NativeFlightReceptionSample? {
    guard !paused, !docked, !playerEMPDisabled, screen == .front, energy.isFinite, energy > 0,
      jumpCountdown == nil, pendingNativeStationDock == nil,
      let active = activeFlightReception, active.state.reading == nil,
      let world = commander.nativeStations, let inventory = commander.equipmentInventory,
      let snapshot = try? commander.purchaseSnapshot(),
      snapshot.items == active.state.permission.fit,
      inventory.activeHull == active.state.permission.carrier,
      inventory.revision == active.state.permission.inventoryRevision,
      inventory.owner == active.state.permission.owner,
      let player = commander.flightSimulation.player,
      let anchor = commander.flightSimulation.anchors?.station,
      let body = bodies.first(where: { $0.id == 0 && $0.hull == .station }),
      body.energy > 0, bodies.filter({ $0.id == 0 }).count == 1,
      let physical = body.physical, physical.identity == anchor.identity,
      let observation = world.mainObservations.first(where: {
        $0.station == active.state.permission.dock.station
      }), observation.actor == physical.identity,
      let resource = commander.scriptState.stationResources[observation.station.key],
      resource.identity == observation.station.resource, !resource.destroyed, resource.energy > 0
    else { return nil }
    let pose = commander.flightSimulation.pose
    let position = pose.systemPoint(body.position)
    let sample = NativeFlightReceptionSample(
      mission: active.instance.id, permission: active.state.permission.operation,
      owner: inventory.owner, carrier: inventory.activeHull, inventoryRevision: inventory.revision,
      station: observation.station, player: player, actor: physical.identity,
      pose: pose, stationPosition: position,
      relativeVelocity: flightWorldVelocity - physical.velocity,
      time: commander.flightSimulation.physicalTime, epoch: nativeStationRuntimeEpoch)
    guard sample.qualifies else { return nil }
    do {
      // An open doorway may leave the centre ray clear. A different nearer body blocks it;
      // no sphere overlap or projected marker is accepted as a docking/arrival receipt.
      if let contact = try nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1),
        range: body.position.length, radius: 0, includePlayer: false),
        contact.hit.target != .body(body.id)
      {
        return nil
      }
    } catch { return nil }
    return sample
  }
}

extension ScriptPackLibrary {
  static func validateFlightReception(_ manifest: ScriptManifest) throws {
    guard let definition = manifest.flightReception else {
      guard !manifest.capabilities.contains("native-flight-reception-v1"),
        manifest.stateID != NativeFlightReception.stateID
      else {
        throw MissionPackError("Flight reception requires its native declaration.")
      }
      return
    }
    guard definition.valid, manifest.stateID == NativeFlightReception.stateID,
      manifest.handlers.count == 1, manifest.handlers.first?.event == "mission.accepted",
      manifest.version == "1.0.0", manifest.mission.milestones.count == 3,
      manifest.mission.parentOnly != true, (manifest.dependencies ?? []).isEmpty,
      (manifest.mission.requiredBooks ?? []).isEmpty,
      Set(manifest.capabilities)
        == Set([
          "script-lua-v1", "story-v2", "durable-commands-v2", "contracts-basic-v2",
          "native-flight-reception-v1",
        ]),
      manifest.board == nil, manifest.fieldRelief == nil, manifest.measuredExtraction == nil,
      manifest.identifiedSalvage == nil, manifest.recordRecovery == nil,
      manifest.originalSurvey == nil, manifest.originalRescue == nil,
      manifest.orbitalEvacuation == nil,
      manifest.stationJourney == nil, manifest.orbitalOutlook == nil,
      manifest.courier == nil, manifest.freight == nil, manifest.procurement == nil,
      manifest.coldChain == nil, manifest.repairLoop == nil, manifest.pledge == nil,
      manifest.providerContract == nil, manifest.trial == nil,
      (manifest.npcs ?? []).isEmpty, (manifest.encounters ?? []).isEmpty,
      (manifest.equipment ?? []).isEmpty, (manifest.passengerParties ?? []).isEmpty,
      (manifest.collections ?? []).isEmpty, (manifest.children ?? []).isEmpty,
      (manifest.worldJobs ?? []).isEmpty, (manifest.loans ?? []).isEmpty,
      (manifest.receiptRequirements ?? []).isEmpty, (manifest.answerRequirements ?? []).isEmpty,
      (manifest.books ?? []).isEmpty, (manifest.models ?? []).isEmpty,
      (manifest.modules ?? []).isEmpty,
      (manifest.dialogs ?? []).isEmpty,
      (manifest.mission.requiredPassengerParties ?? []).isEmpty,
      (manifest.mission.requiredCollections ?? []).isEmpty,
      (manifest.mission.requiredDestructionEncounters ?? []).isEmpty,
      (manifest.mission.requiredEquipmentReturns ?? []).isEmpty,
      (manifest.mission.requiredChoiceGroups ?? []).isEmpty
    else { throw MissionPackError("Invalid closed flight-reception source or recipe.") }
  }
}
