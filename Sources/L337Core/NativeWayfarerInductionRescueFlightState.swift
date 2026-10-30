import Foundation

struct NativeRescueFlightAuthorization: Codable, Sendable, Equatable {
  let registration: UUID
  let funding: UUID
  let capture: UUID
  let job: UUID
  let actor: UUID
  let operation: UUID
  let sequence: UInt64
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let flightSeconds: Double
  let calendarSeconds: Double
  let initialFuelLY: Double
  let crew: [UUID]
  let route: NativeRescueRoutePlan

  static func identity(
    registration: UUID, funding: UUID, capture: UUID,
    dock: NativeMainStationDockReceipt, carrier: UUID, revision: UInt64,
    physicalTime: Double, flightSeconds: Double, calendarSeconds: Double,
    initialFuel: Double, sequence: UInt64, route: NativeRescueRoutePlan
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "native-rescue-flight-v1:\(registration):\(funding):\(capture):\(try NativeFlightReception.hash(dock)):\(carrier):\(revision):\(physicalTime.bitPattern):\(flightSeconds.bitPattern):\(calendarSeconds.bitPattern):\(initialFuel.bitPattern):\(sequence):\(try NativeFlightReception.hash(route))"
    )
  }

  func valid(
    root: NativeCrewLogAuthorization, funding: NativeRescueFuelFunding,
    parent: NativeWayfarerInductionState, source: NativeInductionCrewLogSource
  ) -> Bool {
    guard root.valid(parent: parent), funding.valid(authorization: root),
      let original = parent.crewLog, self.capture == original.operation,
      registration == root.operation, self.funding == funding.issue, job == root.job,
      actor == NativeInductionCrewLogPack.actor(job: root.job, role: .launch),
      crew == root.manifest.crew, route.matches(source: source),
      sequence > max(funding.sequence, original.sequence), sequence < UInt64(Int64.max),
      dock.valid, dock.commanderOwner == root.manifest.owner,
      dock.station.world == root.manifest.owner,
      dock.station.system == NativeInductionCrewLogSource.location,
      dock.actor.visit >= original.collector.visit, dock.actor.visit >= root.stationActor.visit,
      dock.sequence
        >= (funding.legacyRebriefDock?.sequence ?? parent.seedReception?.playerDock.sequence ?? 0),
      physicalTime.isFinite, physicalTime >= max(funding.physicalTime, original.physicalTime),
      physicalTime <= 1e12,
      flightSeconds.isFinite, flightSeconds >= max(funding.flightSeconds, original.flightSeconds),
      flightSeconds <= 1e12,
      calendarSeconds.isFinite, (dock.calendarSeconds...1e12).contains(calendarSeconds),
      inventoryRevision < UInt64(Int64.max), initialFuelLY.isFinite,
      (0...source.ship.fuel).contains(initialFuelLY)
    else { return false }
    return operation
      == (try? Self.identity(
        registration: registration, funding: self.funding,
        capture: capture, dock: dock, carrier: carrier, revision: inventoryRevision,
        physicalTime: physicalTime, flightSeconds: flightSeconds, calendarSeconds: calendarSeconds,
        initialFuel: initialFuelLY, sequence: sequence, route: route))
  }
}

struct NativeRescueHopReference: Codable, Sendable, Equatable {
  let hop: Int
  let attempt: Int
  let leg: UUID
  var request: String { "native-rescue-hop-\(hop)-\(attempt)" }
  func valid(authorization: NativeRescueFlightAuthorization) -> Bool {
    (0..<authorization.route.distancesLY.count).contains(hop) && (0..<128).contains(attempt)
      && leg
        == NativeWormholeLeg.identity(
          instance: authorization.job, actor: authorization.actor, request: request)
  }
}

struct NativeRescueFlightState: Codable, Sendable, Equatable {
  let authorization: NativeRescueFlightAuthorization
  var legs: [NativeRescueHopReference] = []
  // Optional histories retain pre-service flight saves without inventing attained contacts.
  var savedFuelContacts: [NativeArkFuelContact]?
  var dockedContact: NativeArkFuelContact?
  var savedExits: [NativeArkBerthExit]?
  var savedBindings: [NativeArkAdmission]?
  var serviceWait: NativeArkServiceWait?
  var fuelContacts: [NativeArkFuelContact] { savedFuelContacts ?? [] }
  var exits: [NativeArkBerthExit] { savedExits ?? [] }
  var bindings: [NativeArkAdmission] { savedBindings ?? [] }

  mutating func recordBinding(_ actor: ActorIdentity, at physicalTime: Double) {
    guard bindings.last?.actor != actor else { return }
    savedBindings = bindings + [.init(actor: actor, physicalTime: physicalTime)]
  }

  func shapeValid(
    root: NativeCrewLogAuthorization, funding: NativeRescueFuelFunding,
    parent: NativeWayfarerInductionState, source: NativeInductionCrewLogSource
  ) -> Bool {
    guard authorization.valid(root: root, funding: funding, parent: parent, source: source),
      legs.count <= 128, Set(legs.map(\.leg)).count == legs.count,
      legs.allSatisfy({ $0.valid(authorization: authorization) }),
      serviceShapeValid(root: root)
    else { return false }
    var previous: NativeRescueHopReference?
    for leg in legs {
      if let previous {
        guard
          (leg.hop == previous.hop && leg.attempt == previous.attempt + 1)
            || (leg.hop == previous.hop + 1 && leg.attempt == 0)
        else { return false }
      } else if leg.hop != 0 || leg.attempt != 0 {
        return false
      }
      previous = leg
    }
    return true
  }
}
