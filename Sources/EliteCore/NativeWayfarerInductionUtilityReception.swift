import Foundation

struct NativeInductionUtilityReception: Codable, Sendable, Equatable {
  let operation: UUID
  let sequence: UInt64
  let owner: UUID
  let parent: UUID
  let job: UUID
  let issue: UUID
  let authorization: UUID
  let rescue: UUID
  let operatorID: UUID
  let targets: [String]
  let modules: [UUID]
  let kits: [UUID]
  let repairs: [UUID]
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let flightSeconds: Double

  static func identity(
    authorization: UUID, repairs: [UUID], dock: NativeMainStationDockReceipt,
    carrier: UUID, revision: UInt64, time: Double, flightSeconds: Double, sequence: UInt64
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-enron-live-reception-v1:\(authorization):\(try NativeFlightReception.hash(repairs)):\(try NativeFlightReception.hash(dock)):\(carrier):\(revision):\(time.bitPattern):\(flightSeconds.bitPattern):\(sequence)"
    )
  }
  func valid(permission: NativeInductionPermission, rescue: NativeInductionRescueReception) -> Bool
  {
    let issue = NativeInductionUtilitySource.issueIdentity(
      owner: permission.owner,
      parent: permission.mission, receiving: rescue.operation)
    guard self.issue == issue, owner == permission.owner, parent == permission.mission,
      self.rescue == rescue.operation, job == NativeInductionUtilityPack.instance(issue: issue),
      operatorID == NativeInductionUtilitySource.operatorIdentity(issue: issue),
      targets == NativeInductionUtilityRole.allCases.map(\.target),
      modules
        == NativeInductionUtilityRole.allCases.map({
          NativeInductionUtilitySource.moduleIdentity(issue: issue, role: $0)
        }),
      kits
        == NativeInductionUtilityRole.allCases.map({
          NativeInductionUtilitySource.kitIdentity(issue: issue, role: $0)
        }),
      repairs.count == 3, Set(repairs).count == 3, sequence > rescue.sequence,
      sequence < UInt64(Int64.max),
      dock.valid, dock.commanderOwner == owner, dock.station.world == owner,
      dock.station.system == NativeInductionUtilitySource.location,
      dock.actor.visit > rescue.playerDock.actor.visit, dock.sequence > rescue.playerDock.sequence,
      dock.calendarSeconds >= rescue.playerDock.calendarSeconds,
      inventoryRevision < UInt64(Int64.max), physicalTime.isFinite,
      (rescue.physicalTime...1e12).contains(physicalTime), flightSeconds.isFinite,
      (rescue.flightSeconds...1e12).contains(flightSeconds)
    else { return false }
    return operation
      == (try? Self.identity(
        authorization: authorization, repairs: repairs,
        dock: dock, carrier: carrier, revision: inventoryRevision, time: physicalTime,
        flightSeconds: flightSeconds, sequence: sequence))
  }
}

extension NativeWayfarerInductionState {
  func receivingUtilityRoute(_ receipt: NativeInductionUtilityReception) throws -> Self {
    guard valid, let rescueReception, utilityReception == nil,
      receipt.valid(permission: permission, rescue: rescueReception)
    else { throw SaveError.invalidCommander }
    let next = Self(
      permission: permission, crate: crate, loss: loss, reception: reception,
      cassette: cassette, cassetteLoss: cassetteLoss, cassetteService: cassetteService,
      seedKey: seedKey, seedKeyLoss: seedKeyLoss, ark: ark, seedReception: seedReception,
      crewLog: crewLog, crewLogLoss: crewLogLoss, crewLogHullCustody: crewLogHullCustody,
      rescueReception: rescueReception, utilityReception: receipt)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }
}
