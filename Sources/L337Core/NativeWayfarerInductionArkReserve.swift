import Foundation

/// The one initial custodian reserve allocation. Reservation alone admits no ship or people.
struct NativeInductionArkReserve: Codable, Sendable, Equatable {
  let mission: UUID
  let owner: UUID
  let commission: UUID
  let issue: UUID
  let hull: UUID
  let seeds: [UUID]
  let crew: [UUID]
  let fuelFunding: UUID
  let fuelCredits: Int
  /// Older commissions acquire their initial reserve only at the real consented rebrief.
  let legacyRebriefDock: NativeMainStationDockReceipt?

  init(
    permission: NativeInductionPermission, legacyRebriefDock: NativeMainStationDockReceipt? = nil
  ) {
    mission = permission.mission
    owner = permission.owner
    commission = permission.operation
    let issue = Self.identity(permission)
    self.issue = issue
    hull = ScriptIdentity.uuid("\(issue):hull:SH061")
    seeds = (0..<40).map { ScriptIdentity.uuid("\(issue):seed:\($0)") }
    crew = (0..<6).map { ScriptIdentity.uuid("\(issue):crew:\($0)") }
    fuelFunding = Self.funding(owner: owner, mission: mission)
    fuelCredits = NativeArkFuelEscrow.initialCredits
    self.legacyRebriefDock = legacyRebriefDock
  }
  static func identity(_ permission: NativeInductionPermission) -> UUID {
    ScriptIdentity.uuid(
      "induction-custodian-reserve-v1:\(permission.owner):\(permission.mission):\(permission.operation)"
    )
  }
  static func funding(owner: UUID, mission: UUID) -> UUID {
    ScriptIdentity.uuid("induction-custodian-reserve-funds-v1:\(owner):\(mission)")
  }
  func valid(permission: NativeInductionPermission) -> Bool {
    let expected = Self(permission: permission, legacyRebriefDock: legacyRebriefDock)
    guard self == expected, mission == NativeWayfarerInduction.mission(owner: owner) else {
      return false
    }
    if let dock = legacyRebriefDock {
      return dock.valid && dock.commanderOwner == owner && dock.station.world == owner
        && dock.station.system == NativeWayfarerInduction.seedSource
        && dock.sequence > permission.dock.sequence
        && dock.actor.visit > permission.dock.actor.visit
        && dock.calendarSeconds >= permission.dock.calendarSeconds
    }
    return true
  }
}

enum NativeInductionArkIssue: Int, Codable, Sendable {
  case original = 0
  case reserve = 1
}
