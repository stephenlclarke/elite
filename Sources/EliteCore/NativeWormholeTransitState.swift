import Foundation

/// Explicit authored drive units. Fuel is the profiled NPC's own reservoir, in native LY.
/// The component alias must resolve to the actual surviving fitted component at activation/entry.
public struct ScriptNPCDriveDefinition: Codable, Sendable, Equatable {
  public let component: String
  public let rangeLightYears: Double
  public let activationSeconds: Double
  public let massLockScale: Double
  public let fuelUnit: String
  var valid: Bool {
    PackValidation.localID(component) && fuelUnit == "native-light-years"
      && rangeLightYears.isFinite && (0.001...200).contains(rangeLightYears)
      && activationSeconds.isFinite && (0.1...3600).contains(activationSeconds)
      && massLockScale.isFinite && (0.01...10).contains(massLockScale)
  }
}

/// Saved route facts are never an installed catalogue authority.
struct NativeWormholeRoute: Codable, Sendable, Equatable {
  let catalogueRevision: String
  let origin: ScriptNavigationTradeEndpoint
  let destination: ScriptNavigationTradeEndpoint
  let distanceLightYears: Double
  /// Actual destination-world exit in system coordinates, supplied by its native adapter.
  let exit: ShipPose
  var seconds: Double { distanceLightYears * distanceLightYears * 3600 }
  var valid: Bool {
    ScriptCompletionReceipt.validDigest(catalogueRevision)
      && origin.valid && destination.valid && origin.galaxy == destination.galaxy
      && origin.worldID != destination.worldID && origin.location != destination.location
      && distanceLightYears.isFinite && (0.001...200).contains(distanceLightYears)
      && exit.position.finite && exit.position.length <= 1e9 && exit.orientation.validRotation
  }
}

/// Nonserialized binding to G1's single authenticated live original-world catalogue.
/// This source requires that production-world leaf; names, aliases and BBC coordinates cannot bind it.
struct OriginalWorldJourneyContext: Sendable, Equatable {
  let route: NativeWormholeRoute
  static func production(in game: borrowing Game, destinationWorld: String) -> Self? {
    let catalogue = Universe.originalWorlds
    guard let source = game.currentSystem.original,
      (try? catalogue.world(key: source.key)) == source,
      source.galaxy == game.commander.galaxy, source.system == game.commander.system,
      let destination = try? catalogue.world(key: destinationWorld),
      destination.key == destinationWorld, source.key != destination.key,
      source.galaxy == destination.galaxy,
      let fingerprint = OriginalWorldCatalogue.approvedFingerprints["catalogue.json"],
      let distance = try? catalogue.distanceLY(from: source.key, to: destination.key),
      game.systems.indices.contains(destination.system),
      game.systems[destination.system].original == destination
    else { return nil }
    var exit = FlightSimulationState()
    exit.enter(.init(galaxy: destination.galaxy, system: destination.system), arriving: true)
    let route = NativeWormholeRoute(
      catalogueRevision: fingerprint,
      origin: .init(worldID: source.key, galaxy: source.galaxy, system: game.currentSystem),
      destination: .init(
        worldID: destination.key, galaxy: destination.galaxy,
        system: game.systems[destination.system]), distanceLightYears: distance, exit: exit.pose)
    let context = Self(route: route)
    return context.matches(game, at: game.systemIdentity) ? context : nil
  }
  /// A retained route is rejoined to the live catalogue at either endpoint, never authorized
  /// just because its serialized facts survived loading or the destination scene is present.
  static func production(for route: NativeWormholeRoute, in game: borrowing Game) -> Self? {
    let context = Self(route: route)
    return context.matches(game, at: game.systemIdentity) ? context : nil
  }
  func matches(_ game: borrowing Game, at location: SystemIdentity) -> Bool {
    guard route.valid, location == game.systemIdentity,
      location == route.origin.location || location == route.destination.location,
      location.galaxy == route.origin.galaxy
    else { return false }
    guard matchesCatalogue() else { return false }
    return matchesNativeScene(game)
  }

  // Current location was joined to Game above; catalogue values retire before native-scene work.
  @inline(never)
  private func matchesCatalogue() -> Bool {
    let catalogue = Universe.originalWorlds
    guard route.catalogueRevision == OriginalWorldCatalogue.approvedFingerprints["catalogue.json"],
      let source = try? catalogue.world(key: route.origin.worldID),
      let destination = try? catalogue.world(key: route.destination.worldID),
      route.origin.system.original == source, route.destination.system.original == destination,
      source.galaxy == route.origin.galaxy, destination.galaxy == route.destination.galaxy,
      source.system == route.origin.system.id, destination.system == route.destination.system.id,
      let distance = try? catalogue.distanceLY(from: source.key, to: destination.key),
      distance == route.distanceLightYears
    else { return false }
    return true
  }

  @inline(never)
  private func matchesNativeScene(_ game: borrowing Game) -> Bool {
    let systems = game.systems
    var nativeExit = FlightSimulationState()
    nativeExit.enter(route.destination.location, arriving: true)
    guard nativeExit.pose == route.exit else { return false }
    return [route.origin, route.destination].allSatisfy {
      systems.indices.contains($0.system.id) && systems[$0.system.id] == $0.system
    }
  }
}

struct NativeWormholeOpening: Codable, Sendable, Equatable {
  let id: UUID
  let leg: UUID
  let route: NativeWormholeRoute
  let sourceActor: ActorIdentity
  let entrance: ShipPose
  let radius: Double
  let openedAt: Double
  let openedPhysicalTime: Double
  let expiresAt: Double
  var valid: Bool {
    id == ScriptIdentity.uuid("native-wormhole-v1:\(leg)")
      && route.valid && sourceActor.system == route.origin.location
      && sourceActor.visit > 0 && sourceActor.entity > 0
      && entrance.position.finite && entrance.position.length <= 1e9
      && entrance.orientation.validRotation && radius.isFinite && (1...100_000).contains(radius)
      && openedAt.isFinite && expiresAt.isFinite && (0...1e12).contains(openedAt)
      && openedPhysicalTime.isFinite && (0...1e12).contains(openedPhysicalTime)
      && openedAt <= 1e12 - 120 && expiresAt == openedAt + 120
  }
}

struct NativeWormholeDeparture: Codable, Sendable, Equatable {
  let hole: UUID
  let nativeActor: ActorIdentity
  let calendarSeconds: Double
  let physicalTime: Double
  let revision: UInt64
  let fuelBefore: Double
  let fuelAfter: Double
  /// Complete actual condition after debit; historical physical addresses are not live authority.
  let body: SpaceBody
}

struct NativeWormholeArrival: Codable, Sendable, Equatable {
  let nativeActor: ActorIdentity
  let calendarSeconds: Double
}

struct NativeWormholeLeg: Codable, Sendable, Equatable {
  enum Phase: String, Codable, Sendable {
    case requested, spooling, open, inTransit, arrivalPending, arrived, cancelled
  }
  let id: UUID
  let instance: UUID
  let actor: UUID
  let encounter: String
  let alias: String
  let request: String
  let destinationWorld: String
  let requestedAt: Double
  var phase: Phase = .requested
  var attempts = 0
  var nextAttemptAt = 0.0
  var arrivalAttemptVisit: UInt64?
  var refusal: String?
  var route: NativeWormholeRoute?
  var spooledAt: Double?
  var spoolActor: ActorIdentity?
  var spoolPhysicalTime: Double?
  var driveComponent: UUID?
  var driveTerms: ScriptNPCDriveDefinition?
  var opening: NativeWormholeOpening?
  var departure: NativeWormholeDeparture?
  var arrival: NativeWormholeArrival?
  var dueAt: Double? {
    departure.flatMap { departure in route.map { departure.calendarSeconds + $0.seconds } }
  }
  static func identity(instance: UUID, actor: UUID, request: String) -> UUID {
    ScriptIdentity.uuid("native-npc-transit-v1:\(instance):\(actor):\(request)")
  }
  var valid: Bool {
    guard requestFieldsValid() else { return false }
    return receiptsAndPhaseValid()
  }

  // Early identifiers must not share a frame with later full departure-body validation values.
  @inline(never)
  private func requestFieldsValid() -> Bool {
    guard id == Self.identity(instance: instance, actor: actor, request: request),
      PackValidation.localID(request), PackValidation.localID(encounter),
      PackValidation.localID(alias),
      PackValidation.localID(destinationWorld), requestedAt.isFinite,
      (0...1e12).contains(requestedAt), nextAttemptAt.isFinite,
      (0...1e12).contains(nextAttemptAt), (0...128).contains(attempts),
      refusal.map({ $0.utf8.count <= 240 }) ?? true,
      route.map({ $0.valid && $0.destination.worldID == destinationWorld }) ?? true,
      spooledAt.map({ $0.isFinite && (requestedAt...1e12).contains($0) }) ?? true,
      spoolPhysicalTime.map({ $0.isFinite && (0...1e12).contains($0) }) ?? true
    else { return false }
    return true
  }

  @inline(never)
  private func receiptsAndPhaseValid() -> Bool {
    if let opening {
      guard opening.valid, opening.leg == id, opening.route == route,
        let spooledAt, opening.openedAt >= spooledAt,
        driveComponent != nil, driveTerms?.valid == true,
        spoolActor == opening.sourceActor, let spoolPhysicalTime,
        opening.openedPhysicalTime - spoolPhysicalTime
          >= (driveTerms?.activationSeconds ?? .infinity)
      else { return false }
    }
    if let departure {
      guard let opening, let route, departure.hole == opening.id,
        departure.nativeActor == opening.sourceActor,
        departure.nativeActor.visit > 0, departure.nativeActor.entity > 0,
        departure.calendarSeconds.isFinite,
        (opening.openedAt...opening.expiresAt).contains(departure.calendarSeconds),
        departure.physicalTime.isFinite && (0...1e12).contains(departure.physicalTime),
        departure.physicalTime >= opening.openedPhysicalTime,
        departure.revision < UInt64.max,
        departure.fuelBefore.isFinite && departure.fuelAfter.isFinite,
        departure.fuelAfter >= 0,
        departure.fuelAfter == departure.fuelBefore - route.distanceLightYears,
        departure.body.missionActorID == actor, departure.body.missionInstanceID == instance,
        departure.body.physical?.identity == departure.nativeActor,
        departure.body.energy > 0, departure.body.scriptNPC?.valid == true,
        driveTerms == departure.body.scriptNPC?.fit.definition.drive,
        departure.fuelBefore <= (departure.body.scriptNPC?.fit.definition.fuel ?? -1),
        departure.body.scriptNPC?.components[driveTerms?.component ?? ""]?.identity
          == driveComponent,
        departure.body.scriptNPC?.fuel == departure.fuelAfter,
        let dueAt, dueAt <= 1e12
      else { return false }
    }
    if let arrival {
      guard let dueAt, let route, arrival.calendarSeconds.isFinite,
        (dueAt...1e12).contains(arrival.calendarSeconds),
        arrival.nativeActor.system == route.destination.location,
        arrival.nativeActor.visit > 0, arrival.nativeActor.entity > 0
      else { return false }
    }
    switch phase {
    case .requested: return opening == nil && departure == nil && arrival == nil
    case .spooling:
      return route != nil && spooledAt != nil && driveComponent != nil
        && spoolActor != nil && spoolPhysicalTime != nil
        && driveTerms?.valid == true && opening == nil && departure == nil
    case .open: return opening != nil && departure == nil && arrival == nil
    case .inTransit, .arrivalPending: return departure != nil && arrival == nil
    case .arrived: return arrival != nil
    case .cancelled: return departure == nil && arrival == nil
    }
  }
}

/// Invocation-local history fields only; full leg/body validation remains with the typed ledger.
private struct NativeWormholeActorHistoryFacts: Sendable {
  let instance: UUID
  let actor: UUID
  let hasDeparture: Bool
  let arrivalDate: Double?
  let destination: SystemIdentity?

  @inline(never)
  static func project(_ legs: borrowing [NativeWormholeLeg]) -> [Self] {
    var facts: [Self] = []
    for index in legs.indices {
      let hasDeparture: Bool
      if case .some = legs[index].departure {
        hasDeparture = true
      } else {
        hasDeparture = false
      }
      facts.append(
        .init(
          instance: legs[index].instance, actor: legs[index].actor,
          hasDeparture: hasDeparture, arrivalDate: legs[index].arrival?.calendarSeconds,
          destination: legs[index].route?.destination.location))
    }
    return facts
  }
}

struct NativeWormholeTransitState: Codable, Sendable, Equatable {
  let owner: UUID
  var legs: [UUID: NativeWormholeLeg] = [:]
  var commanderPassages: [UUID: NativeCommanderWormholeReceipt] = [:]
  var valid: Bool {
    guard legs.count <= 128, commanderPassages.count <= 128,
      legs.allSatisfy({ $0.key == $0.value.id && $0.value.valid }),
      commanderPassages.allSatisfy({ id, receipt in
        guard id == receipt.opening,
          let hole = legs.values.compactMap(\.opening).first(where: { $0.id == id })
        else { return false }
        return receipt.source.system == hole.route.origin.location
          && receipt.arrival.system == hole.route.destination.location
          && receipt.source.visit > 0 && receipt.arrival.visit > receipt.source.visit
          && receipt.source.entity == 0 && receipt.arrival.entity == 0
          && receipt.calendarOperation > 0 && receipt.seconds == hole.route.seconds
          && (0...10_000).contains(receipt.fuelBefore) && receipt.fuelAfter >= 0
          && (1...10_000).contains(receipt.fuelDebit)
          && receipt.fuelAfter == receipt.fuelBefore - receipt.fuelDebit
      })
    else {
      return false
    }
    // An actor cannot be in two concurrent journeys. Finished history never authorizes a new leg.
    let active = legs.values.filter { ![.arrived, .cancelled].contains($0.phase) }
    return Set(active.map(\.actor)).count == active.count
  }
}

extension Commander {
  var nativeWormholeHistoryValid: Bool {
    guard let transit = scriptState.wormholeTransit else { return true }
    guard transit.owner == equipmentOwnerID else { return false }
    func nativeAddress(_ actor: ActorIdentity) -> Bool {
      actor.visit > 0 && actor.visit <= flightSimulation.visit
        && actor.entity < flightSimulation.nextActor
    }
    return transit.legs.values.allSatisfy { leg in
      (leg.opening.map {
        nativeAddress($0.sourceActor) && $0.openedPhysicalTime <= flightSimulation.physicalTime
      } ?? true)
        && (leg.spoolPhysicalTime.map { $0 <= flightSimulation.physicalTime } ?? true)
        && (leg.arrivalAttemptVisit.map { $0 <= flightSimulation.visit } ?? true)
        && (leg.spoolActor.map(nativeAddress) ?? true)
        && (leg.departure.map { nativeAddress($0.nativeActor) } ?? true)
        && (leg.arrival.map { nativeAddress($0.nativeActor) } ?? true)
    }
      && transit.commanderPassages.values.allSatisfy {
        nativeAddress($0.source) && nativeAddress($0.arrival)
      }
  }
}

extension ScriptEngineState {
  var nativeWormholeStateValid: Bool {
    guard wormholeTransit?.valid ?? true else { return false }
    return nativeWormholeOwnerAndHistoryValid()
  }

  // Validate the typed ledger before retaining the later owned-actor/history traversal values.
  @inline(never)
  private func nativeWormholeOwnerAndHistoryValid() -> Bool {
    guard
      (wormholeTransit?.commanderPassages ?? [:]).values.allSatisfy({
        $0.calendarOperation <= (calendarLedger?.operation ?? 0) && $0.seconds <= transitSeconds
      })
    else { return false }
    let legs = Array((wormholeTransit?.legs ?? [:]).values)
    if !legs.isEmpty {
      guard nativeWormholeLegOwnersValid(legs) else { return false }
    }
    let history = NativeWormholeActorHistoryFacts.project(legs)
    return nativeWormholeOwnedActorHistoriesValid(history)
  }

  @inline(never)
  private func nativeWormholeLegOwnersValid(_ legs: [NativeWormholeLeg]) -> Bool {
    for leg in legs {
      guard let instance = instances[leg.instance],
        let encounter = instance.ownedEncounters[leg.encounter],
        let actor = encounter.actors[leg.alias], actor.identity == leg.actor,
        leg.requestedAt <= calendarSeconds
      else { return false }
      if let departure = leg.departure {
        guard departure.calendarSeconds <= calendarSeconds else { return false }
        if leg.arrival == nil {
          guard [.inTransit, .arrivalPending].contains(actor.presence),
            actor.body == departure.body
          else { return false }
        }
      }
      if let arrival = leg.arrival {
        guard arrival.calendarSeconds <= calendarSeconds else { return false }
      }
    }
    return true
  }

  // Even with no ledger, every owned actor must prove any transit presence or relocation.
  @inline(never)
  private func nativeWormholeOwnedActorHistoriesValid(
    _ legs: [NativeWormholeActorHistoryFacts]
  ) -> Bool {
    for instance in instances.values {
      for encounter in instance.ownedEncounters.values {
        for actor in encounter.actors.values {
          guard
            Self.nativeWormholeActorHistoryValid(
              instance: instance.id, actor: actor.identity, presence: actor.presence,
              location: actor.transitLocation, legs: legs)
          else { return false }
        }
      }
    }
    return true
  }

  // History selection needs only these scalar owner facts, not another full actor/body capture.
  @inline(never)
  private static func nativeWormholeActorHistoryValid(
    instance: UUID, actor: UUID, presence: ScriptActorPresence,
    location: SystemIdentity?, legs: [NativeWormholeActorHistoryFacts]
  ) -> Bool {
    let history = legs.filter { $0.instance == instance && $0.actor == actor }
    if [.inTransit, .arrivalPending].contains(presence) {
      guard history.contains(where: { $0.hasDeparture && $0.arrivalDate == nil }) else {
        return false
      }
    }
    let arrivals = history.filter { $0.arrivalDate != nil }
    let dates = arrivals.compactMap(\.arrivalDate)
    guard Set(dates).count == dates.count else { return false }
    let latest = arrivals.max {
      ($0.arrivalDate ?? -.infinity) < ($1.arrivalDate ?? -.infinity)
    }
    guard location == latest?.destination else { return false }
    return true
  }
}
