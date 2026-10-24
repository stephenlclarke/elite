import Foundation

/// Atomic reception of the original living people and their original protected recorder.
struct NativeInductionRescueReception: Codable, Sendable, Equatable {
  let operation: UUID
  let sequence: UInt64
  let owner: UUID
  let parent: UUID
  let job: UUID
  let registration: UUID
  let flight: UUID
  let capture: UUID
  let launch: UUID
  let recorder: UUID
  let target: String
  let crew: [UUID]
  let launchDock: NativeArkFuelContact
  let playerDock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let flightSeconds: Double

  static let receivingTarget = "enmadan-live-crew-received"
  static func identity(
    registration: UUID, flight: UUID, capture: UUID,
    launchDock: NativeArkFuelContact, playerDock: NativeMainStationDockReceipt,
    carrier: UUID, revision: UInt64, physicalTime: Double, flightSeconds: Double, crew: [UUID]
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "native-original-rescue-reception-v1:\(registration):\(flight):\(capture):\(try NativeFlightReception.hash(launchDock)):\(try NativeFlightReception.hash(playerDock)):\(carrier):\(revision):\(physicalTime.bitPattern):\(flightSeconds.bitPattern):\(try NativeFlightReception.hash(crew))"
    )
  }
  func valid(permission: NativeInductionPermission, original: NativeCrewLogCapture) -> Bool {
    let manifest = NativeInductionCrewLogManifest(permission: permission)
    guard owner == manifest.owner, parent == manifest.mission,
      job == original.job, registration == original.issue, capture == original.operation,
      launch == manifest.launch, recorder == manifest.recorder, recorder == original.original,
      crew == manifest.crew, crew.count == 2, Set(crew).count == 2,
      target == Self.receivingTarget, sequence > original.sequence, sequence < UInt64(Int64.max),
      launchDock.valid, launchDock.mission == parent, launchDock.ark == launch,
      launchDock.station.world == owner,
      launchDock.station.system == NativeInductionCrewLogSource.receiver,
      playerDock.valid, playerDock.commanderOwner == owner,
      playerDock.station == launchDock.station,
      playerDock.sequence > 0, playerDock.actor.visit > original.collector.visit,
      playerDock.actor.visit >= launchDock.stationActor.visit,
      inventoryRevision < UInt64(Int64.max), physicalTime.isFinite,
      (max(original.physicalTime, launchDock.physicalTime)...1e12).contains(physicalTime),
      flightSeconds.isFinite, (original.flightSeconds...1e12).contains(flightSeconds)
    else { return false }
    return operation
      == (try? Self.identity(
        registration: registration, flight: flight,
        capture: capture, launchDock: launchDock, playerDock: playerDock, carrier: carrier,
        revision: inventoryRevision, physicalTime: physicalTime, flightSeconds: flightSeconds,
        crew: crew))
  }
}

struct NativeRescueFuelReturn: Codable, Sendable, Equatable {
  let operation: UUID
  let receiving: UUID
  let recipient: UUID
  let balanceBefore: Int
  let returnedCredits: Int
  static func identity(issue: UUID, receiving: UUID, credits: Int) -> UUID {
    ScriptIdentity.uuid("native-original-rescue-fuel-return-v1:\(issue):\(receiving):\(credits)")
  }
}

extension NativeWayfarerInductionState {
  func receivingOriginalRescue(_ receipt: NativeInductionRescueReception) throws -> Self {
    guard valid, let crewLog, crewLogLoss == nil, rescueReception == nil,
      receipt.valid(permission: permission, original: crewLog), receipt.carrier == crewLogCarrier,
      receipt.inventoryRevision >= (crewLogInventoryRevision ?? UInt64.max)
    else { throw SaveError.invalidCommander }
    let next = Self(
      permission: permission, crate: crate, loss: loss, reception: reception,
      cassette: cassette, cassetteLoss: cassetteLoss, cassetteService: cassetteService,
      seedKey: seedKey, seedKeyLoss: seedKeyLoss, ark: ark, seedReception: seedReception,
      crewLog: crewLog, crewLogHullCustody: crewLogHullCustody, rescueReception: receipt)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }
}
