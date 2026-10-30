import Foundation

enum NativeInductionCapacityOperator: String, CaseIterable, Codable, Sendable {
  case clinic, workshop, seed
  var station: SystemIdentity {
    switch self {
    case .clinic: NativeWayfarerInduction.clinic
    case .workshop: NativeWayfarerInduction.workshop
    case .seed: NativeWayfarerInduction.seedSource
    }
  }
  func owner(epoch: UUID) -> UUID {
    ScriptIdentity.uuid("induction-charter-original-operator-v1:\(epoch):\(rawValue)")
  }
}

struct NativeInductionCapacityUnit: Codable, Sendable, Equatable {
  let identity: UUID
  let epoch: UUID
  let operatorID: NativeInductionCapacityOperator
  let owner: UUID
  let slot: Int
  var protected: Bool { slot < 2 }
  static func original(epoch: UUID) -> [Self] {
    NativeInductionCapacityOperator.allCases.flatMap { operatorID in
      (0..<6).map { slot in
        Self(
          identity: ScriptIdentity.uuid(
            "induction-charter-original-unit-v1:\(epoch):\(operatorID.rawValue):\(slot)"),
          epoch: epoch, operatorID: operatorID, owner: operatorID.owner(epoch: epoch), slot: slot)
      }
    }
  }
}

struct NativeInductionCapacityAllocation: Codable, Sendable, Equatable {
  let operation: UUID
  let choice: UUID
  let epoch: UUID
  let policy: NativeInductionCharterPolicy
  let parent: UUID
  let commanderOwner: UUID
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let flightSeconds: Double
  let sequence: UInt64

  init(
    choice: NativeInductionCharterChoice, dock: NativeMainStationDockReceipt,
    carrier: UUID, revision: UInt64, time: Double, flightSeconds: Double, sequence: UInt64
  ) throws {
    self.choice = choice.operation
    epoch = choice.terms.epoch
    policy = choice.policy
    parent = choice.parent
    commanderOwner = choice.owner
    self.dock = dock
    self.carrier = carrier
    inventoryRevision = revision
    physicalTime = time
    self.flightSeconds = flightSeconds
    self.sequence = sequence
    operation = try Self.identity(
      choice: choice.operation, dock: dock, carrier: carrier,
      revision: revision, time: time, flightSeconds: flightSeconds, sequence: sequence)
    guard valid(choice: choice) else { throw SaveError.invalidCommander }
  }
  static func identity(
    choice: UUID, dock: NativeMainStationDockReceipt, carrier: UUID,
    revision: UInt64, time: Double, flightSeconds: Double, sequence: UInt64
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-original-charter-capacity-v1:\(choice):\(try NativeFlightReception.hash(dock)):\(carrier):\(revision):\(time.bitPattern):\(flightSeconds.bitPattern):\(sequence)"
    )
  }
  func valid(choice: NativeInductionCharterChoice) -> Bool {
    guard self.choice == choice.operation, epoch == choice.terms.epoch, policy == choice.policy,
      parent == choice.parent, commanderOwner == choice.owner, choice.terms.valid,
      dock.valid, dock.commanderOwner == commanderOwner, dock.station.world == commanderOwner,
      dock.station.system == NativeWayfarerInduction.source, dock.station == choice.dock.station,
      dock.sequence >= choice.dock.sequence, dock.actor.visit >= choice.dock.actor.visit,
      dock.calendarSeconds >= choice.dock.calendarSeconds,
      inventoryRevision < UInt64(Int64.max), physicalTime.isFinite,
      (choice.physicalTime...1e12).contains(physicalTime), flightSeconds.isFinite,
      (choice.flightSeconds...1e12).contains(flightSeconds),
      sequence >= choice.sequence, sequence < UInt64(Int64.max)
    else { return false }
    return operation
      == (try? Self.identity(
        choice: self.choice, dock: dock, carrier: carrier,
        revision: inventoryRevision, time: physicalTime, flightSeconds: flightSeconds,
        sequence: sequence))
  }
}
