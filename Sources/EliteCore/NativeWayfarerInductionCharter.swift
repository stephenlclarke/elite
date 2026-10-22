import Foundation

enum NativeInductionCharterPolicy: String, Codable, Sendable, CaseIterable {
  case pooledWindows = "pooled-windows"
  case protectedReservations = "protected-reservations"
  var title: String { self == .pooledWindows ? "Pooled windows" : "Protected reservations" }
  var consequence: String {
    switch self {
    case .pooledWindows:
      "Pool only free surplus above each owner's protected two-unit minimum; never borrow protected capacity."
    case .protectedReservations:
      "Keep unreleased capacity with its original owner; pooling requires that owner's explicit signed release of an exact free surplus unit."
    }
  }
}

/// Fixed approved charter terms, separate from cargo, tools, berths and the contract-count cap.
struct NativeInductionCharterTerms: Codable, Sendable, Equatable {
  let unitsPerOperator: Int
  let protectedMinimum: Int
  let unit: String
  let epoch: UUID
  static func original(epoch: UUID) -> Self {
    .init(
      unitsPerOperator: 6, protectedMinimum: 2,
      unit: "one-concurrent-independently-quoted-consignment-authorization", epoch: epoch)
  }
  var valid: Bool { self == Self.original(epoch: epoch) }
}

struct NativeInductionCharterChoice: Codable, Sendable, Equatable {
  let operation: UUID
  let sequence: UInt64
  let owner: UUID
  let parent: UUID
  let utility: UUID
  let policy: NativeInductionCharterPolicy
  let terms: NativeInductionCharterTerms
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let flightSeconds: Double

  static func epoch(owner: UUID, parent: UUID, utility: UUID) -> UUID {
    ScriptIdentity.uuid("induction-charter-epoch-v1:\(owner):\(parent):\(utility)")
  }
  static func identity(
    utility: UUID, policy: NativeInductionCharterPolicy, terms: NativeInductionCharterTerms,
    dock: NativeMainStationDockReceipt, carrier: UUID, revision: UInt64,
    time: Double, flightSeconds: Double, sequence: UInt64
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-charter-choice-v1:\(utility):\(policy.rawValue):\(try NativeFlightReception.hash(terms)):\(try NativeFlightReception.hash(dock)):\(carrier):\(revision):\(time.bitPattern):\(flightSeconds.bitPattern):\(sequence)"
    )
  }
  func valid(permission: NativeInductionPermission, utility: NativeInductionUtilityReception)
    -> Bool
  {
    guard self.utility == utility.operation, owner == permission.owner,
      parent == permission.mission,
      sequence > utility.sequence, sequence < UInt64(Int64.max), terms.valid,
      terms.epoch == Self.epoch(owner: owner, parent: parent, utility: utility.operation),
      dock.valid, dock.commanderOwner == owner, dock.station.world == owner,
      dock.station.system == NativeWayfarerInduction.source,
      dock.sequence > utility.dock.sequence, dock.actor.visit > utility.dock.actor.visit,
      dock.calendarSeconds >= utility.dock.calendarSeconds,
      inventoryRevision < UInt64(Int64.max), physicalTime.isFinite,
      (utility.physicalTime...1e12).contains(physicalTime), flightSeconds.isFinite,
      (utility.flightSeconds...1e12).contains(flightSeconds)
    else { return false }
    return operation
      == (try? Self.identity(
        utility: self.utility, policy: policy, terms: terms,
        dock: dock, carrier: carrier, revision: inventoryRevision, time: physicalTime,
        flightSeconds: flightSeconds, sequence: sequence))
  }
}

extension NativeWayfarerInductionState {
  func choosingCharter(_ receipt: NativeInductionCharterChoice) throws -> Self {
    guard valid, let utilityReception, charterChoice == nil,
      receipt.valid(permission: permission, utility: utilityReception)
    else { throw SaveError.invalidCommander }
    let next = Self(
      permission: permission, crate: crate, loss: loss, reception: reception,
      cassette: cassette, cassetteLoss: cassetteLoss, cassetteService: cassetteService,
      seedKey: seedKey, seedKeyLoss: seedKeyLoss, ark: ark, seedReception: seedReception,
      crewLog: crewLog, crewLogLoss: crewLogLoss, crewLogHullCustody: crewLogHullCustody,
      rescueReception: rescueReception, utilityReception: utilityReception, charterChoice: receipt)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }
}
