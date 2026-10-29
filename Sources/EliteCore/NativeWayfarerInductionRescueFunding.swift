import Foundation

/// Exactly one original rescue fuel issue. Legacy sources need actual consented rebrief, never load.
struct NativeRescueFuelFunding: Codable, Sendable, Equatable {
  let owner: UUID
  let parent: UUID
  let custodian: UUID
  let launch: UUID
  let registration: UUID
  let issue: UUID
  let operation: UUID
  let sequence: UInt64
  let credits: Int
  let physicalTime: Double
  let flightSeconds: Double
  let legacyRebriefDock: NativeMainStationDockReceipt?

  init(
    authorization: NativeCrewLogAuthorization, sequence: UInt64? = nil,
    physicalTime: Double? = nil, flightSeconds: Double? = nil,
    legacyRebriefDock: NativeMainStationDockReceipt? = nil
  ) {
    let manifest = authorization.manifest
    owner = manifest.owner
    parent = manifest.mission
    custodian = manifest.custodian
    launch = manifest.launch
    registration = authorization.operation
    issue = Self.identity(authorization)
    credits = NativeRescueFuelEscrow.initialCredits
    self.sequence = sequence ?? authorization.sequence
    self.physicalTime = physicalTime ?? authorization.physicalTime
    self.flightSeconds = flightSeconds ?? authorization.flightSeconds
    self.legacyRebriefDock = legacyRebriefDock
    operation = Self.operation(
      issue: issue, sequence: self.sequence,
      physicalTime: self.physicalTime, flightSeconds: self.flightSeconds, dock: legacyRebriefDock)
  }
  static func identity(_ authorization: NativeCrewLogAuthorization) -> UUID {
    identity(
      owner: authorization.manifest.owner, launch: authorization.manifest.launch,
      registration: authorization.operation)
  }
  static func identity(owner: UUID, launch: UUID, registration: UUID) -> UUID {
    ScriptIdentity.uuid("induction-rescue-original-fuel-v1:\(owner):\(launch):\(registration)")
  }
  var shapeValid: Bool {
    parent == NativeWayfarerInduction.mission(owner: owner)
      && issue == Self.identity(owner: owner, launch: launch, registration: registration)
      && credits == NativeRescueFuelEscrow.initialCredits
      && sequence > 0 && sequence < UInt64(Int64.max)
      && physicalTime.isFinite && (0...1e12).contains(physicalTime)
      && flightSeconds.isFinite && (0...1e12).contains(flightSeconds)
      && operation
        == Self.operation(
          issue: issue, sequence: sequence,
          physicalTime: physicalTime, flightSeconds: flightSeconds, dock: legacyRebriefDock)
  }
  static func operation(
    issue: UUID, sequence: UInt64, physicalTime: Double,
    flightSeconds: Double, dock: NativeMainStationDockReceipt?
  ) -> UUID {
    let berth = dock.flatMap { try? NativeFlightReception.hash($0) } ?? "registration"
    return ScriptIdentity.uuid(
      "induction-rescue-funding-receipt-v1:\(issue):\(sequence):\(physicalTime.bitPattern):\(flightSeconds.bitPattern):\(berth)"
    )
  }
  func valid(authorization: NativeCrewLogAuthorization) -> Bool {
    guard shapeValid, owner == authorization.manifest.owner,
      parent == authorization.manifest.mission,
      custodian == authorization.manifest.custodian,
      launch == authorization.manifest.launch, registration == authorization.operation,
      issue == Self.identity(authorization), credits == NativeRescueFuelEscrow.initialCredits,
      sequence >= authorization.sequence, sequence < UInt64(Int64.max),
      physicalTime.isFinite, (authorization.physicalTime...1e12).contains(physicalTime),
      flightSeconds.isFinite, (authorization.flightSeconds...1e12).contains(flightSeconds),
      operation
        == Self.operation(
          issue: issue, sequence: sequence,
          physicalTime: physicalTime, flightSeconds: flightSeconds, dock: legacyRebriefDock)
    else { return false }
    if let dock = legacyRebriefDock {
      return dock.valid && dock.commanderOwner == owner && dock.station.world == owner
        && dock.station.system == NativeInductionCrewLogSource.location
        && dock.actor.visit >= authorization.stationActor.visit
        && sequence > authorization.sequence
    }
    return sequence == authorization.sequence && physicalTime == authorization.physicalTime
      && flightSeconds == authorization.flightSeconds
  }
}

/// One planned uncrewed hull and separate fuel allocation; it grants no admission or replacement people.
struct NativeRescueLaunchReserve: Codable, Sendable, Equatable {
  let owner: UUID
  let parent: UUID
  let registration: UUID
  let issue: UUID
  let hull: UUID
  let fuelFunding: UUID
  let fuelCredits: Int
  let crew: [UUID]
  init(authorization: NativeCrewLogAuthorization) {
    owner = authorization.manifest.owner
    parent = authorization.manifest.mission
    registration = authorization.operation
    let issue = ScriptIdentity.uuid(
      "induction-rescue-uncrewed-reserve-v1:\(authorization.manifest.launch):\(authorization.operation)"
    )
    self.issue = issue
    hull = ScriptIdentity.uuid("\(issue):hull:SH029")
    fuelFunding = ScriptIdentity.uuid("\(issue):fuel-funding")
    fuelCredits = NativeRescueFuelEscrow.initialCredits
    crew = []
  }
  func valid(authorization: NativeCrewLogAuthorization) -> Bool {
    self == Self(authorization: authorization) && crew.isEmpty
      && !([
        authorization.manifest.tender, authorization.manifest.launch,
        authorization.manifest.recorder,
      ] + authorization.manifest.crew).contains(hull)
  }
}
