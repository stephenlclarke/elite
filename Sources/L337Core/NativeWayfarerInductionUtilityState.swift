import Foundation

struct NativeInductionUtilityAuthorization: Codable, Sendable, Equatable {
  let owner: UUID
  let parent: UUID
  let reception: UUID
  let issue: UUID
  let job: UUID
  let operation: UUID
  let sequence: UInt64
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let flightSeconds: Double

  init(
    parent: NativeWayfarerInductionState, dock: NativeMainStationDockReceipt,
    carrier: UUID, revision: UInt64, physicalTime: Double, flightSeconds: Double,
    sequence: UInt64
  ) throws {
    let source = try NativeInductionUtilitySource(parent: parent)
    owner = source.owner
    self.parent = source.parent
    reception = source.reception
    issue = source.issue
    job = NativeInductionUtilityPack.instance(issue: issue)
    self.sequence = sequence
    self.dock = dock
    self.carrier = carrier
    inventoryRevision = revision
    self.physicalTime = physicalTime
    self.flightSeconds = flightSeconds
    operation = try Self.identity(
      issue: issue, dock: dock, carrier: carrier, revision: revision,
      physicalTime: physicalTime, flightSeconds: flightSeconds, sequence: sequence)
    guard valid(parent: parent) else { throw SaveError.invalidCommander }
  }
  static func identity(
    issue: UUID, dock: NativeMainStationDockReceipt,
    carrier: UUID, revision: UInt64, physicalTime: Double, flightSeconds: Double,
    sequence: UInt64
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "induction-enron-maintenance-authorization-v1:\(issue):\(try NativeFlightReception.hash(dock)):\(carrier):\(revision):\(physicalTime.bitPattern):\(flightSeconds.bitPattern):\(sequence)"
    )
  }
  func valid(parent: NativeWayfarerInductionState) -> Bool {
    guard let source = try? NativeInductionUtilitySource(parent: parent),
      let reception = parent.rescueReception, owner == source.owner, self.parent == source.parent,
      self.reception == source.reception, issue == source.issue,
      job == NativeInductionUtilityPack.instance(issue: source.issue),
      sequence > reception.sequence, sequence < UInt64(Int64.max),
      dock.valid, dock.commanderOwner == owner, dock.station.world == owner,
      dock.station.system == NativeInductionUtilitySource.location,
      dock.sequence > reception.playerDock.sequence,
      dock.actor.visit > reception.playerDock.actor.visit,
      dock.calendarSeconds >= reception.playerDock.calendarSeconds,
      inventoryRevision < UInt64(Int64.max), physicalTime.isFinite,
      (reception.physicalTime...1e12).contains(physicalTime), flightSeconds.isFinite,
      (reception.flightSeconds...1e12).contains(flightSeconds)
    else { return false }
    return operation
      == (try? Self.identity(
        issue: issue, dock: dock, carrier: carrier,
        revision: inventoryRevision, physicalTime: physicalTime,
        flightSeconds: flightSeconds, sequence: sequence))
  }
}

/// One crew-owned local kit and initial mechanical fault per original module, never player cargo.
struct NativeInductionUtilityModule: Codable, Sendable, Equatable {
  let role: NativeInductionUtilityRole
  let module: UUID
  let kit: UUID
  var fault: String
  var availableKits: Int
  var work: NativeInductionUtilityWork?
  init(source: NativeInductionUtilitySource, role: NativeInductionUtilityRole) {
    self.role = role
    module = source.module(role)
    kit = source.kit(role)
    fault = role.initialFault
    availableKits = 1
  }
}

struct NativeInductionUtilityState: Codable, Sendable, Equatable {
  let authorization: NativeInductionUtilityAuthorization
  var modules: [NativeInductionUtilityModule]
  var admission: [String: NativeArkAdmission]?
  var receiving: NativeInductionUtilityReception?
  init(authorization: NativeInductionUtilityAuthorization, source: NativeInductionUtilitySource) {
    self.authorization = authorization
    modules = NativeInductionUtilityRole.allCases.map { .init(source: source, role: $0) }
  }
  func shapeValid(parent: NativeWayfarerInductionState) -> Bool {
    guard authorization.valid(parent: parent),
      let source = try? NativeInductionUtilitySource(parent: parent),
      modules.count == 3,
      zip(modules, NativeInductionUtilityRole.allCases).allSatisfy({ module, role in
        module.role == role && module.module == source.module(role)
          && module.kit == source.kit(role)
          && module.valid(authorization: authorization, source: source)
      }),
      Set(modules.map(\.module) + modules.map(\.kit)).count == 6
    else { return false }
    if modules.contains(where: { $0.work != nil }) && admission == nil { return false }
    if let admission {
      guard Set(admission.keys) == Set(NativeInductionUtilityRole.allCases.map(\.rawValue)),
        Set(admission.values.map(\.actor)).count == 3,
        Set(admission.values.map { $0.actor.visit }).count == 1,
        admission.values.allSatisfy({
          $0.actor.system == NativeInductionUtilitySource.location
            && $0.actor.visit >= authorization.dock.actor.visit
            && $0.actor.entity > 1 && $0.actor.entity < UInt64(Int64.max)
            && $0.physicalTime.isFinite
            && (authorization.physicalTime...1e12).contains($0.physicalTime)
        })
      else { return false }
    }
    guard receiving == parent.utilityReception else { return false }
    if let receiving {
      guard let rescue = parent.rescueReception,
        receiving.valid(permission: parent.permission, rescue: rescue),
        receiving.authorization == authorization.operation,
        receiving.repairs == modules.compactMap({ $0.work?.repair?.operation }),
        modules.allSatisfy({
          $0.availableKits == 0 && $0.work?.repair != nil && $0.fault == $0.role.workingFault
        }),
        receiving.dock.station == authorization.dock.station,
        receiving.dock.sequence > authorization.dock.sequence,
        receiving.sequence
          > (modules.compactMap({ $0.work?.repair?.sequence }).max() ?? UInt64.max),
        receiving.physicalTime
          >= (modules.compactMap({ $0.work?.repair?.physicalTime }).max() ?? .infinity),
        receiving.flightSeconds
          >= (modules.compactMap({ $0.work?.repair?.flightSeconds }).max() ?? .infinity)
      else { return false }
    }
    return true
  }
}

extension NativeInductionUtilityModule {
  func valid(
    authorization: NativeInductionUtilityAuthorization, source: NativeInductionUtilitySource
  ) -> Bool {
    if let work {
      guard work.valid(authorization: authorization, source: source, role: role) else {
        return false
      }
      if work.repair != nil { return availableKits == 0 && fault == role.workingFault }
    }
    return availableKits == 1 && fault == role.initialFault
  }
}
