import Foundation

struct NativeCrewLogAuthorization: Codable, Sendable, Equatable {
  let manifest: NativeInductionCrewLogManifest
  let job: UUID
  let seedReception: UUID
  let operation: UUID
  let sequence: UInt64
  let stationActor: ActorIdentity
  let physicalTime: Double
  let flightSeconds: Double

  init(
    parent: NativeWayfarerInductionState, stationActor: ActorIdentity,
    physicalTime: Double, flightSeconds: Double, sequence: UInt64
  ) throws {
    let source = try NativeInductionCrewLogSource(parent: parent)
    guard let reception = parent.seedReception else { throw SaveError.invalidCommander }
    manifest = source.manifest
    job = NativeInductionCrewLogPack.instance(recorder: source.manifest.recorder)
    seedReception = reception.operation
    self.sequence = sequence
    self.stationActor = stationActor
    self.physicalTime = physicalTime
    self.flightSeconds = flightSeconds
    operation = Self.identity(
      manifest: source.manifest, receiving: reception.operation, station: stationActor,
      physicalTime: physicalTime, flightSeconds: flightSeconds, sequence: sequence)
    guard valid(parent: parent) else { throw SaveError.invalidCommander }
  }

  static func identity(
    manifest: NativeInductionCrewLogManifest, receiving: UUID,
    station: ActorIdentity, physicalTime: Double,
    flightSeconds: Double, sequence: UInt64
  ) -> UUID {
    ScriptIdentity.uuid(
      "induction-crew-log-issue-v1:\(manifest.recorder):\(receiving):\(station.system.galaxy):\(station.system.system):\(station.visit):\(station.entity):\(physicalTime.bitPattern):\(flightSeconds.bitPattern):\(sequence)"
    )
  }

  func valid(parent: NativeWayfarerInductionState) -> Bool {
    guard parent.valid, let receiving = parent.seedReception,
      manifest.valid(permission: parent.permission), seedReception == receiving.operation,
      job == NativeInductionCrewLogPack.instance(recorder: manifest.recorder),
      stationActor.system == NativeInductionCrewLogSource.location,
      stationActor.visit > receiving.playerDock.actor.visit, stationActor.entity == 1,
      sequence > receiving.sequence, sequence < UInt64(Int64.max),
      physicalTime.isFinite, (receiving.physicalTime...1e12).contains(physicalTime),
      flightSeconds.isFinite, (receiving.flightSeconds...1e12).contains(flightSeconds)
    else { return false }
    return operation
      == Self.identity(
        manifest: manifest, receiving: receiving.operation, station: stationActor,
        physicalTime: physicalTime, flightSeconds: flightSeconds, sequence: sequence)
  }
}

struct NativeCrewLogAdmission: Codable, Sendable, Equatable {
  let tender: ActorIdentity
  let launch: ActorIdentity
  let recorder: ActorIdentity
  let physicalTime: Double
  func actor(for role: NativeInductionCrewLogRole) -> ActorIdentity {
    switch role {
    case .tender: tender
    case .launch: launch
    case .recorder: recorder
    }
  }
  func valid(authorization: NativeCrewLogAuthorization) -> Bool {
    let actors = [tender, launch, recorder]
    return Set(actors).count == 3
      && actors.allSatisfy {
        $0.system == NativeInductionCrewLogSource.location && $0.entity > 1
          && $0.visit >= authorization.stationActor.visit && $0.visit == tender.visit
      } && physicalTime.isFinite && (authorization.physicalTime...1e12).contains(physicalTime)
  }
}

struct NativeCrewLogActorLoss: Codable, Sendable, Equatable {
  let role: String
  let actor: ActorIdentity
  let physicalTime: Double
  func valid(admission: NativeCrewLogAdmission, flight: NativeRescueFlightState? = nil) -> Bool {
    guard let role = NativeInductionCrewLogRole(rawValue: role) else { return false }
    let permitted: Bool
    if role == .launch, let flight {
      permitted = flight.authorization.route.worldKeys.contains { key in
        guard let world = try? Universe.originalWorlds.world(key: key) else { return false }
        return actor.system == SystemIdentity(galaxy: world.galaxy, system: world.system)
      }
    } else {
      permitted = actor.system == NativeInductionCrewLogSource.location
    }
    return permitted
      && actor.visit >= admission.actor(for: role).visit && actor.entity > 1
      && physicalTime.isFinite && (admission.physicalTime...1e12).contains(physicalTime)
  }
}

struct NativeInductionCrewLogState: Codable, Sendable, Equatable {
  let authorization: NativeCrewLogAuthorization
  var admission: NativeCrewLogAdmission?
  var losses: [NativeCrewLogActorLoss] = []
  var capture: NativeCrewLogCapture?
  var rescueFuel: NativeRescueFuelEscrow?
  var rescueReserve: NativeRescueLaunchReserve?
  var flight: NativeRescueFlightState?
  var livingCrew: [UUID] {
    admission != nil && !losses.contains(where: { $0.role == "launch" })
      ? authorization.manifest.crew : []
  }
  func shapeValid(parent: NativeWayfarerInductionState) -> Bool {
    guard authorization.valid(parent: parent), losses.count <= 3,
      Set(losses.map(\.role)).count == losses.count
    else { return false }
    if let rescueFuel {
      guard rescueFuel.valid, rescueFuel.funding.valid(authorization: authorization),
        rescueReserve?.valid(authorization: authorization) == true,
        // Actual dock/service publication joins are introduced with the normal flight provider.
        rescueFuel.purchases.isEmpty, rescueFuel.refusal == nil
      else { return false }
      if let dock = rescueFuel.funding.legacyRebriefDock {
        guard let reception = parent.seedReception, let capture,
          rescueFuel.funding.sequence > capture.sequence,
          rescueFuel.funding.physicalTime >= capture.physicalTime,
          rescueFuel.funding.flightSeconds >= capture.flightSeconds,
          dock.sequence > reception.playerDock.sequence,
          dock.calendarSeconds >= reception.playerDock.calendarSeconds
        else { return false }
      }
    } else if rescueReserve != nil {
      return false
    }
    if let flight {
      guard let rescueFuel, capture != nil,
        let source = try? NativeInductionCrewLogSource(parent: parent),
        flight.shapeValid(
          root: authorization, funding: rescueFuel.funding, parent: parent, source: source)
      else { return false }
    }
    guard let admission else { return losses.isEmpty && capture == nil && flight == nil }
    if let capture {
      guard let reception = parent.seedReception,
        capture.valid(permission: parent.permission, reception: reception),
        capture.issue == authorization.operation, capture.job == authorization.job,
        capture.sequence > authorization.sequence,
        capture.startTime >= admission.physicalTime,
        capture.actor.visit >= admission.recorder.visit,
        !losses.contains(where: { $0.role == "recorder" })
      else { return false }
    }
    return admission.valid(authorization: authorization)
      && losses.allSatisfy { $0.valid(admission: admission, flight: flight) }
  }
}
