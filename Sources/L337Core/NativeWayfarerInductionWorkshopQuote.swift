import Foundation

enum NativeInductionWorkshopQuoteScope: String, Codable, Sendable {
  case ownerStation, avenorReadOnlyAudit
}
struct NativeInductionWorkshopQuote: Codable, Sendable, Equatable {
  let scope: NativeInductionWorkshopQuoteScope
  let issue: UUID
  let familyDigest: String
  let epoch: UUID
  let operatorOwner: UUID
  let stockRevision: UInt64
  let capacityRevision: UInt64
  let capacityFingerprint: String
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let runtimeEpoch: UUID
  let route: NativeInductionWorkshopRoute
  let offer: WayfarerRepairLoopOffer
  static func identity(
    source: NativeInductionWorkshopSource, unit: NativeInductionWorkshopUnit,
    scope: NativeInductionWorkshopQuoteScope, stockRevision: UInt64,
    capacity: NativeInductionCapacityState,
    dock: NativeMainStationDockReceipt, carrier: UUID, fit: UInt64, runtimeEpoch: UUID,
    route: NativeInductionWorkshopRoute
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-original-workshop-quote-v1:\(source.issue.operation):\(unit.id):\(unit.serial):\(scope.rawValue):\(stockRevision):\(capacity.revision):\(try capacity.fingerprint):\(try NativeFlightReception.hash(dock)):\(carrier):\(fit):\(runtimeEpoch):\(try NativeFlightReception.hash(route))"
    )
  }
  static func prepare(
    source: NativeInductionWorkshopSource, parent: NativeWayfarerInductionState,
    unit: UUID, scope: NativeInductionWorkshopQuoteScope, dock: NativeMainStationDockReceipt,
    carrier: UUID, fit: UInt64, runtimeEpoch: UUID, firstReachLY: Double, fullReachLY: Double,
    retainedRoute: NativeInductionWorkshopRoute? = nil
  ) throws -> Self {
    guard parent.charterWorkshopSource == source, source.valid(parent: parent),
      let capacity = parent.charterCapacity,
      let stock = source.units.first(where: {
        $0.id == unit && $0.status == .available && $0.instance == nil
      }),
      dock.valid, dock.commanderOwner == source.issue.commanderOwner,
      dock.sequence >= source.issue.dock.sequence,
      dock.actor.visit >= source.issue.dock.actor.visit,
      dock.calendarSeconds >= source.issue.dock.calendarSeconds, fit < UInt64(Int64.max)
    else { throw SaveError.invalidCommander }
    switch scope {
    case .ownerStation:
      guard dock.station == source.issue.dock.station else { throw SaveError.invalidCommander }
    case .avenorReadOnlyAudit:
      guard dock.station == source.delegation.auditor, source.delegation.units.contains(unit),
        dock.sequence > source.issue.dock.sequence,
        dock.actor.visit > source.issue.dock.actor.visit,
        source.delegation.scope == NativeInductionWorkshopDelegation.readOnlyScope
      else { throw SaveError.invalidCommander }
    }
    let route =
      try retainedRoute
      ?? NativeInductionWorkshopRoute(
        firstReachLY: firstReachLY, fullReachLY: fullReachLY)
    guard route.valid, route.firstReachLY == firstReachLY, route.fullReachLY == fullReachLY else {
      throw SaveError.invalidCommander
    }
    let id = try Self.identity(
      source: source, unit: stock, scope: scope, stockRevision: source.revision,
      capacity: capacity, dock: dock, carrier: carrier, fit: fit, runtimeEpoch: runtimeEpoch,
      route: route)
    let systems = try route.worldKeys.map { try Universe.originalWorlds.world(key: $0).system }
    let offer = WayfarerRepairLoopOffer(
      id: id, sourceID: source.identity.uuidString,
      stockUnit: stock.id, serial: stock.serial, tonnes: 2,
      rewardNative: try source.issue.profile.reward(route: route),
      galaxy: 0, sourceSystem: 0, workshopSystem: 185, receiverSystem: 0, route: systems,
      hazardTier: 0)
    return .init(
      scope: scope, issue: source.issue.operation, familyDigest: source.issue.familyDigest,
      epoch: source.issue.epoch, operatorOwner: source.issue.operatorOwner,
      stockRevision: source.revision, capacityRevision: capacity.revision,
      capacityFingerprint: try capacity.fingerprint,
      dock: dock, carrier: carrier, inventoryRevision: fit, runtimeEpoch: runtimeEpoch,
      route: route, offer: offer)
  }
}
