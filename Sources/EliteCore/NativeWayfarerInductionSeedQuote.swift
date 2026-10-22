import Foundation

enum NativeInductionSeedQuoteScope: String, Codable, Sendable {
  case ownerStation, avenorReadOnlyAudit
}

/// Read-only source proposal. This value grants no pickup, reservation, custody or settlement.
struct NativeInductionSeedQuote: Sendable {
  let scope: NativeInductionSeedQuoteScope
  let family: String
  let familyDigest: String
  let issue: UUID
  let epoch: UUID
  let operatorOwner: UUID
  let stockRevision: UInt64
  let capacityRevision: UInt64
  let capacityFingerprint: String
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let runtimeEpoch: UUID
  let route: NativeInductionSeedRoute
  let terms: NativeInductionSeedTerms
  let offer: WayfarerColdChainOffer

  static func identity(
    source: NativeInductionSeedSource, unit: UUID, scope: NativeInductionSeedQuoteScope,
    stockRevision: UInt64, capacity: NativeInductionCapacityState,
    dock: NativeMainStationDockReceipt,
    carrier: UUID, revision: UInt64, runtimeEpoch: UUID, route: NativeInductionSeedRoute
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-seed-read-only-quote-v1:\(source.issue.operation):\(unit):\(scope.rawValue):\(stockRevision):\(capacity.revision):\(try capacity.fingerprint):\(try NativeFlightReception.hash(dock)):\(carrier):\(revision):\(runtimeEpoch):\(try NativeFlightReception.hash(route))"
    )
  }
  static func prepare(
    source: NativeInductionSeedSource, parent: NativeWayfarerInductionState,
    unit: UUID, scope: NativeInductionSeedQuoteScope, dock: NativeMainStationDockReceipt,
    carrier: UUID, revision: UInt64, runtimeEpoch: UUID, firstReachLY: Double, fullReachLY: Double
  ) throws -> Self {
    guard parent.charterSeedSource == source, source.valid(parent: parent),
      let capacity = parent.charterCapacity,
      source.units.contains(where: {
        $0.id == unit && $0.status == .available && $0.instance == nil
      }),
      dock.valid, dock.commanderOwner == source.issue.commanderOwner,
      dock.station.world == source.issue.commanderOwner,
      dock.sequence >= source.issue.dock.sequence,
      dock.actor.visit >= source.issue.dock.actor.visit,
      dock.calendarSeconds >= source.issue.dock.calendarSeconds,
      revision < UInt64(Int64.max)
    else { throw SaveError.invalidCommander }
    switch scope {
    case .ownerStation:
      guard dock.station == source.issue.dock.station else { throw SaveError.invalidCommander }
    case .avenorReadOnlyAudit:
      guard dock.station == source.delegation.auditor, source.delegation.units.contains(unit),
        dock.sequence > source.issue.dock.sequence,
        dock.actor.visit > source.issue.dock.actor.visit,
        source.delegation.scope == NativeInductionSeedAuditDelegation.readOnlyScope
      else { throw SaveError.invalidCommander }
    }
    let route = try NativeInductionSeedRoute(firstReachLY: firstReachLY, fullReachLY: fullReachLY)
    let terms = try source.issue.profile.terms(epoch: source.issue.epoch, route: route)
    let fingerprint = try capacity.fingerprint
    let id = try Self.identity(
      source: source, unit: unit, scope: scope, stockRevision: source.revision,
      capacity: capacity, dock: dock, carrier: carrier, revision: revision,
      runtimeEpoch: runtimeEpoch, route: route)
    let offer = WayfarerColdChainOffer(
      id: id, sourceID: source.identity.uuidString, stockUnit: unit,
      tonnes: terms.tonnes, rewardNative: terms.rewardNative,
      flightAllowance: terms.flightAllowance,
      galaxy: 0, sourceSystem: terms.source.system, objectiveSystem: terms.objective.system,
      receiverSystem: terms.receiver.system, route: terms.route, hazardTier: terms.hazardTier)
    return .init(
      scope: scope, family: source.issue.family, familyDigest: source.issue.familyDigest,
      issue: source.issue.operation, epoch: source.issue.epoch,
      operatorOwner: source.issue.operatorOwner,
      stockRevision: source.revision, capacityRevision: capacity.revision,
      capacityFingerprint: fingerprint,
      dock: dock, carrier: carrier, inventoryRevision: revision, runtimeEpoch: runtimeEpoch,
      route: route, terms: terms, offer: offer)
  }
}

extension Game {
  func inductionSeedReadOnlyQuote(
    unit: UUID? = nil, scope: NativeInductionSeedQuoteScope = .ownerStation
  )
    throws -> NativeInductionSeedQuote
  {
    guard !isMissionTrial, !paused, docked, energy > 0,
      let mission = wayfarerInductionMission, mission.outcome == .active, mission.suspension == nil,
      let parent = mission.savedWayfarerInduction, let source = parent.charterSeedSource,
      nativeInductionSeedPack != nil, let dock = commander.nativeStations?.currentMainDock,
      nativeMainStationDockEvidenceIsCurrent,
      case .living(let facility) = nativeOriginalMainStationDestination,
      facility.identity == dock.station, facility.observation.actor == dock.actor,
      let resource = commander.scriptState.stationResources[
        source.issue.profile.source.resourceKey],
      resource.valid, !resource.destroyed, resource.energy > 0,
      resource.identity == source.issue.dock.station.resource,
      commander.scriptState.stationResources[source.issue.profile.receiver.resourceKey]?.destroyed
        != true,
      commander.equipmentOwnerID == source.issue.commanderOwner,
      let carrier = commander.hullInstanceID, let revision = commander.equipmentInventory?.revision,
      let unit = unit
        ?? source.units.first(where: { $0.status == .available && $0.instance == nil })?.id
    else {
      throw MissionPackError(
        "Use the actual authorized living source or delegated Avenor read-only contact; original stock, fitting and current navigation must be available."
      )
    }
    return try .prepare(
      source: source, parent: parent, unit: unit, scope: scope, dock: dock,
      carrier: carrier, revision: revision, runtimeEpoch: nativeStationRuntimeEpoch,
      firstReachLY: commander.maximumJumpDistance, fullReachLY: commander.fullTankJumpDistance)
  }
}
