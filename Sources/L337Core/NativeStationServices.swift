import Foundation

/// A live board boundary, not a saved offer and not authority obtainable from a Lua snapshot.
struct NativeStationBoardContext: Equatable, Sendable {
  let service: NativeStationServiceContext
  let hour: Int64
  let profileRevision: String
  let adapterRevision: String
  let geometryRevision: String
  let legal: Int
  var station: NativeStationIdentity { service.receipt.station }
  fileprivate init(service: NativeStationServiceContext, hour: Int64, legal: Int) {
    self.service = service
    self.hour = hour
    profileRevision = NativeStationSource.boardRevision
    adapterRevision = NativeStationSource.adapterRevision
    geometryRevision = NativeStationGeometry.adapterRevision
    self.legal = legal
  }
}

struct NativeMainStationDestinationContext: Equatable, Sendable {
  let identity: NativeMainStationIdentity
  let resource: ScriptStationResource
  let observation: NativeMainStationObservation
  let runtimeEpoch: UUID
  fileprivate init(
    identity: NativeMainStationIdentity, resource: ScriptStationResource,
    observation: NativeMainStationObservation, runtimeEpoch: UUID
  ) {
    self.identity = identity
    self.resource = resource
    self.observation = observation
    self.runtimeEpoch = runtimeEpoch
  }
}

enum NativeMainStationDestinationState: Sendable {
  case living(NativeMainStationDestinationContext)
  case destroyed(NativeMainStationIdentity)
  case unavailable
}

struct NativeMainStationArrivalContext: Equatable, Sendable {
  let receipt: NativeMainStationDockReceipt
  let destination: NativeMainStationDestinationContext
  let runtimeEpoch: UUID
  fileprivate init(
    receipt: NativeMainStationDockReceipt, destination: NativeMainStationDestinationContext
  ) {
    self.receipt = receipt
    self.destination = destination
    runtimeEpoch = destination.runtimeEpoch
  }
}

struct NativeStationEventFacts: Equatable, Codable, Sendable {
  let receipt: NativeStationDockReceipt
  let descriptor: NativeStationDescriptor
  var valid: Bool {
    guard receipt.station.valid, receipt.commanderOwner == receipt.station.world,
      receipt.dockingBinding.valid(for: receipt.station),
      receipt.sequence > 0, receipt.sequence < UInt64(Int64.max),
      receipt.lifecycleRevision > 0, receipt.lifecycleRevision < UInt64(Int64.max),
      let source = NativeStationSource.binding(for: receipt.station)
    else { return false }
    return descriptor == source.descriptor
  }
  var value: ScriptValue {
    .object([
      "world": .string(receipt.station.world.uuidString),
      "station_id": .string(receipt.station.key),
      "definition": .string(receipt.station.definition),
      "version": .string(receipt.station.version),
      "board_origin": .string(descriptor.boardOrigin == .source ? "source" : "project_extension"),
      "capabilities": .array([.string("rrs_contract_board")]),
      "docking_sequence": .integer(Int64(receipt.sequence)),
      "lifecycle_revision": .integer(Int64(receipt.lifecycleRevision)),
    ])
  }
}

extension Game {
  var nativeStationEventFacts: NativeStationEventFacts? {
    guard docked, !dockedAtMainStation, commander.nativeStationStateValid,
      nativeStationDockEvidenceIsCurrent,
      let world = commander.nativeStations, let receipt = world.ledger.currentDock,
      let record = world.ledger.records.first(where: { $0.identity == receipt.station })
    else { return nil }
    let facts = NativeStationEventFacts(receipt: receipt, descriptor: record.descriptor)
    return facts.valid ? facts : nil
  }
  var nativeOriginalMainStationDestination: NativeMainStationDestinationState {
    let system = systemIdentity
    let originalActor = commander.flightSimulation.anchors?.station.identity
    guard let world = commander.nativeStations, commander.nativeStationStateValid,
      let identity = world.mainStations.first(where: { $0.system == system }),
      let resource = commander.scriptState.stationResources[identity.key],
      resource.valid, resource.identity == identity.resource
    else { return .unavailable }
    if resource.destroyed { return .destroyed(identity) }
    guard resource.energy > 0,
      let observation = world.mainObservations.first(where: { $0.station == identity })
    else { return .unavailable }
    let observed: Bool
    if docked, let receipt = world.ledger.currentDock {
      observed =
        nativeStationDockEvidenceIsCurrent
        && observation.actor.visit == receipt.dockingBinding.actor.visit
    } else if docked, let receipt = world.currentMainDock {
      observed =
        nativeMainStationDockEvidenceIsCurrent
        && receipt.station == identity && receipt.actor == observation.actor
    } else {
      observed =
        !docked
        && bodies.contains {
          $0.id == 0 && $0.hull == .station && $0.energy > 0
            && $0.physical?.identity == observation.actor
            && $0.physical?.identity == originalActor
        }
    }
    guard observed else { return .unavailable }
    return .living(
      .init(
        identity: identity, resource: resource, observation: observation,
        runtimeEpoch: nativeStationRuntimeEpoch))
  }

  func acceptsNativeMainStationDestination(_ context: NativeMainStationDestinationContext) -> Bool {
    guard case .living(let actual) = nativeOriginalMainStationDestination else { return false }
    return actual == context
  }

  func nativeMainStationArrivalContext(
    for destination: NativeMainStationIdentity
  ) -> NativeMainStationArrivalContext? {
    guard docked, dockedAtMainStation, !paused, scriptDurabilityAvailable,
      nativeMainStationDockEvidenceIsCurrent,
      let receipt = commander.nativeStations?.currentMainDock, receipt.station == destination,
      case .living(let actual) = nativeOriginalMainStationDestination,
      actual.identity == destination, receipt.actor == actual.observation.actor
    else { return nil }
    return .init(receipt: receipt, destination: actual)
  }

  func acceptsNativeMainStationArrivalContext(_ context: NativeMainStationArrivalContext) -> Bool {
    nativeMainStationArrivalContext(for: context.receipt.station) == context
  }

  var nativeStationBoardContext: NativeStationBoardContext? {
    guard docked, !dockedAtMainStation, !paused, scriptDurabilityAvailable,
      nativeStationDockEvidenceIsCurrent,
      pendingNativeStationDock == nil,
      commander.nativeStationStateValid, let world = commander.nativeStations,
      let receipt = world.ledger.currentDock,
      let record = world.ledger.records.first(where: { $0.identity == receipt.station }),
      NativeStationSource.authentic(record, owner: world.ledger.world),
      let service = world.ledger.serviceContext(
        capability: .rrsContractBoard, docked: docked, system: systemIdentity,
        commanderOwner: commander.equipmentOwnerID, runtimeEpoch: nativeStationRuntimeEpoch),
      let hour = NativeStationSource.boardHour(
        calendarSeconds: commander.scriptState.calendarSeconds)
    else { return nil }
    return .init(service: service, hour: hour, legal: commander.legal)
  }

  func acceptsNativeStationBoardContext(_ context: NativeStationBoardContext) -> Bool {
    nativeStationBoardContext == context
      && commander.nativeStations?.ledger.accepts(
        context.service, docked: docked, system: systemIdentity,
        commanderOwner: commander.equipmentOwnerID, runtimeEpoch: nativeStationRuntimeEpoch) == true
  }

  /// Source waystation/HQ limited markets need their own adapters; a board grants no shop.
  var stationAllowsMarketServices: Bool {
    docked && dockedAtMainStation && commander.nativeStationStateValid
      && commander.nativeStations?.ledger.currentDock == nil
  }
  var stationAllowsEquipmentServices: Bool { stationAllowsMarketServices }

  var nativeStationName: String? {
    guard let receipt = commander.nativeStations?.ledger.currentDock,
      let source = NativeStationSource.binding(for: receipt.station)
    else { return nil }
    return source.kind == .waystation ? "RRS Waystation" : "RRS Headquarters"
  }

  /// Factual query data never contains the sealed context or an executable service token.
  var nativeStationFacts: ScriptValue {
    guard docked, !dockedAtMainStation, let world = commander.nativeStations,
      nativeStationDockEvidenceIsCurrent,
      commander.nativeStationStateValid, let receipt = world.ledger.currentDock,
      let source = NativeStationSource.binding(for: receipt.station)
    else { return .null }
    return .object([
      "world": .string(world.ledger.world.uuidString), "station_id": .string(receipt.station.key),
      "definition": .string(receipt.station.definition),
      "version": .string(receipt.station.version),
      "roles": .array(source.descriptor.sourceRoles.map(ScriptValue.string)),
      "board_origin": .string(
        source.descriptor.boardOrigin == .source ? "source" : "project_extension"),
      "capabilities": .array([.string("rrs_contract_board")]),
      "docking_sequence": .integer(Int64(receipt.sequence)),
      "lifecycle_revision": .integer(Int64(receipt.lifecycleRevision)),
      "technology": .integer(Int64(source.technology)),
      "market_available": .bool(false), "equipment_available": .bool(false),
      "board_hour": NativeStationSource.boardHour(
        calendarSeconds: commander.scriptState.calendarSeconds
      )
      .map(ScriptValue.integer) ?? .null,
    ])
  }
}

extension GameRuntime {
  func nativeStationBoardContext() -> NativeStationBoardContext? { game.nativeStationBoardContext }
  func acceptsNativeStationBoardContext(_ context: NativeStationBoardContext) -> Bool {
    game.acceptsNativeStationBoardContext(context)
  }
  func nativeOriginalMainStationDestination() -> NativeMainStationDestinationState {
    game.nativeOriginalMainStationDestination
  }
  func nativeMainStationArrivalContext(for station: NativeMainStationIdentity)
    -> NativeMainStationArrivalContext?
  {
    game.nativeMainStationArrivalContext(for: station)
  }
}

/// Ephemeral project utility service, independent of RRS board/shop capabilities.
struct NativeUtilityServiceContext: Equatable, Sendable {
  let receipt: NativeStationDockReceipt
  let runtimeEpoch: UUID
  let utilityRevision: UInt64
  let engineer: UUID
  fileprivate init(
    receipt: NativeStationDockReceipt, runtimeEpoch: UUID, utility: NativeUtilityState
  ) {
    self.receipt = receipt
    self.runtimeEpoch = runtimeEpoch
    utilityRevision = utility.revision
    engineer = utility.engineer
  }
}
extension Game {
  var nativeUtilityServiceContext: NativeUtilityServiceContext? {
    guard docked, !dockedAtMainStation, !paused, scriptDurabilityAvailable,
      nativeStationDockEvidenceIsCurrent, pendingNativeStationDock == nil,
      commander.nativeStationStateValid, let world = commander.nativeStations,
      let receipt = world.ledger.currentDock,
      let record = world.ledger.records.first(where: { $0.identity == receipt.station }),
      NativeUtilityState.isTarget(record.identity), record.tombstone == nil,
      NativeStationSource.authentic(record, owner: world.ledger.world),
      record.binding == receipt.dockingBinding, record.revision == receipt.lifecycleRevision,
      receipt.commanderOwner == commander.equipmentOwnerID,
      let pose = world.pose(for: record.identity), pose.energy > 0,
      let utility = record.utility, utility.valid
    else { return nil }
    return .init(receipt: receipt, runtimeEpoch: nativeStationRuntimeEpoch, utility: utility)
  }
}
