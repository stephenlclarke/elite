import Foundation

struct NativeInductionArkLink: Codable, Sendable, Equatable {
  let job: UUID
  let registeredArk: UUID
  let operation: UUID
  let loanOperation: UUID
  var valid: Bool {
    job == NativeInductionArkPack.instance(registeredArk: registeredArk)
  }
}

struct NativeArkLaunchAuthorization: Codable, Sendable, Equatable {
  let owner: UUID
  let parent: UUID
  let job: UUID
  let registeredArk: UUID
  let actor: UUID
  let operation: UUID
  let stockIssue: UUID
  let loanOperation: UUID
  let sequence: UInt64
  let dock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let flightSeconds: Double
  let route: NativeArkRoutePlan
  let seeds: [UUID]
  let crew: [UUID]
  let reserve: NativeInductionArkReserve?

  init(
    owner: UUID, parent: UUID, job: UUID, registeredArk: UUID, actor: UUID,
    operation: UUID, stockIssue: UUID, loanOperation: UUID, sequence: UInt64,
    dock: NativeMainStationDockReceipt, carrier: UUID, inventoryRevision: UInt64,
    physicalTime: Double, flightSeconds: Double, route: NativeArkRoutePlan,
    seeds: [UUID], crew: [UUID], reserve: NativeInductionArkReserve? = nil
  ) {
    self.owner = owner
    self.parent = parent
    self.job = job
    self.registeredArk = registeredArk
    self.actor = actor
    self.operation = operation
    self.stockIssue = stockIssue
    self.loanOperation = loanOperation
    self.sequence = sequence
    self.dock = dock
    self.carrier = carrier
    self.inventoryRevision = inventoryRevision
    self.physicalTime = physicalTime
    self.flightSeconds = flightSeconds
    self.route = route
    self.seeds = seeds
    self.crew = crew
    self.reserve = reserve
  }

  func valid(source: NativeInductionArkSource, key: NativeInductionVaultKeyLoan) -> Bool {
    guard source.valid, reserve == source.reserve, owner == source.owner, parent == source.mission,
      registeredArk == source.actor, loanOperation == key.operation,
      loanOperation == source.loanOperation,
      job == NativeInductionArkPack.instance(registeredArk: registeredArk),
      actor == NativeInductionArkPack.actor(instance: job), sequence > 0,
      sequence < UInt64(Int64.max), dock.valid, dock.commanderOwner == owner,
      dock.station.world == owner, dock.station.system == source.source,
      dock.sequence >= key.dock.sequence, dock.actor.visit >= key.dock.actor.visit,
      dock.calendarSeconds >= key.dock.calendarSeconds,
      physicalTime.isFinite, physicalTime >= key.physicalTime, physicalTime <= 1e12,
      inventoryRevision < UInt64(Int64.max),
      flightSeconds.isFinite, flightSeconds >= key.flightSeconds, flightSeconds <= 1e12,
      route.matches(source: source), seeds == source.seeds, crew == source.crew
    else { return false }
    return operation
      == (try? Self.identity(
        registeredArk: registeredArk, dock: dock, carrier: carrier,
        revision: inventoryRevision, physicalTime: physicalTime, route: route))
      && stockIssue
        == ScriptIdentity.uuid("native-ark-initial-stock-v1:\(registeredArk):\(operation)")
  }
  static func identity(
    registeredArk: UUID, dock: NativeMainStationDockReceipt, carrier: UUID,
    revision: UInt64, physicalTime: Double, route: NativeArkRoutePlan
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "native-ark-launch-v1:\(registeredArk):\(try NativeFlightReception.hash(dock)):\(carrier):\(revision):\(physicalTime.bitPattern):\(try NativeFlightReception.hash(route))"
    )
  }
}

struct NativeArkAdmission: Codable, Sendable, Equatable {
  let actor: ActorIdentity
  let physicalTime: Double
}
struct NativeArkBerthExit: Codable, Sendable, Equatable {
  let contactSequence: UInt64
  let actor: ActorIdentity
  let physicalTime: Double
}
struct NativeArkHullLoss: Codable, Sendable, Equatable {
  let actor: ActorIdentity
  let observedPhysicalTime: Double
}
struct NativeArkHopReference: Codable, Sendable, Equatable {
  let hop: Int
  let attempt: Int
  let leg: UUID
  var request: String { "native-ark-hop-\(hop)-\(attempt)" }
  func valid(authorization: NativeArkLaunchAuthorization) -> Bool {
    (0..<authorization.route.legDistancesLY.count).contains(hop)
      && (0..<128).contains(attempt)
      && leg
        == NativeWormholeLeg.identity(
          instance: authorization.job, actor: authorization.actor, request: request)
  }
}

/// Real actor references live in the normal owned-encounter/transit ledger, never a copied hull.
final class NativeInductionArkState: Codable, Sendable, Equatable {
  let authorization: NativeArkLaunchAuthorization
  let fuel: NativeArkFuelEscrow
  let admission: NativeArkAdmission?
  let legs: [NativeArkHopReference]
  let loss: NativeArkHullLoss?
  let fuelContacts: [NativeArkFuelContact]
  let dockedContact: NativeArkFuelContact?
  let exitedContacts: [UInt64]
  let serviceWait: NativeArkServiceWait?
  let reception: NativeInductionSeedReception?
  private let savedExits: [NativeArkBerthExit]?
  var exits: [NativeArkBerthExit] { savedExits ?? [] }
  init(
    authorization: NativeArkLaunchAuthorization, fuel: NativeArkFuelEscrow,
    admission: NativeArkAdmission? = nil, legs: [NativeArkHopReference] = [],
    loss: NativeArkHullLoss? = nil, fuelContacts: [NativeArkFuelContact] = [],
    dockedContact: NativeArkFuelContact? = nil, exitedContacts: [UInt64] = [],
    serviceWait: NativeArkServiceWait? = nil, exits: [NativeArkBerthExit] = [],
    reception: NativeInductionSeedReception? = nil
  ) {
    self.authorization = authorization
    self.fuel = fuel
    self.admission = admission
    self.legs = legs
    self.loss = loss
    self.fuelContacts = fuelContacts
    self.dockedContact = dockedContact
    self.exitedContacts = exitedContacts
    self.serviceWait = serviceWait
    self.reception = reception
    self.savedExits = exits.isEmpty ? nil : exits
  }
  static func == (a: NativeInductionArkState, b: NativeInductionArkState) -> Bool {
    a.authorization == b.authorization && a.fuel == b.fuel && a.admission == b.admission
      && a.legs == b.legs && a.loss == b.loss && a.fuelContacts == b.fuelContacts
      && a.dockedContact == b.dockedContact && a.exitedContacts == b.exitedContacts
      && a.serviceWait == b.serviceWait && a.exits == b.exits && a.reception == b.reception
  }
  func replacing(
    admission: NativeArkAdmission? = nil, legs: [NativeArkHopReference]? = nil,
    loss: NativeArkHullLoss? = nil, fuel: NativeArkFuelEscrow? = nil,
    fuelContacts: [NativeArkFuelContact]? = nil,
    dockedContact: NativeArkFuelContact? = nil, clearsDock: Bool = false,
    exitedContacts: [UInt64]? = nil, serviceWait: NativeArkServiceWait? = nil,
    clearsServiceWait: Bool = false, exits: [NativeArkBerthExit]? = nil,
    reception: NativeInductionSeedReception? = nil
  ) -> NativeInductionArkState {
    let resolvedFuel: NativeArkFuelEscrow = fuel ?? self.fuel
    let resolvedAdmission: NativeArkAdmission? = admission ?? self.admission
    let resolvedLegs: [NativeArkHopReference] = legs ?? self.legs
    let resolvedLoss: NativeArkHullLoss? = loss ?? self.loss
    let resolvedContacts: [NativeArkFuelContact] = fuelContacts ?? self.fuelContacts
    let resolvedDock: NativeArkFuelContact? =
      clearsDock ? nil : (dockedContact ?? self.dockedContact)
    let resolvedExited: [UInt64] = exitedContacts ?? self.exitedContacts
    let resolvedWait: NativeArkServiceWait? =
      clearsServiceWait ? nil : (serviceWait ?? self.serviceWait)
    let resolvedExits: [NativeArkBerthExit] = exits ?? self.exits
    let resolvedReception: NativeInductionSeedReception? = reception ?? self.reception
    return NativeInductionArkState(
      authorization: authorization, fuel: resolvedFuel, admission: resolvedAdmission,
      legs: resolvedLegs, loss: resolvedLoss, fuelContacts: resolvedContacts,
      dockedContact: resolvedDock, exitedContacts: resolvedExited,
      serviceWait: resolvedWait, exits: resolvedExits, reception: resolvedReception)
  }
  var livingCrew: Int { admission != nil && loss == nil ? authorization.crew.count : 0 }
  var intactSeedTonnes: Int {
    admission != nil && loss == nil && reception == nil ? authorization.seeds.count : 0
  }
  var deliveredSeedTonnes: Int { reception?.seeds.count ?? 0 }

  func shapeValid(source: NativeInductionArkSource, key: NativeInductionVaultKeyLoan) -> Bool {
    let a = authorization
    guard a.valid(source: source, key: key), fuel.valid, fuel.issue == source.issue,
      fuel.owner == a.owner, fuel.mission == a.parent, fuel.ark == a.registeredArk,
      fuel.loanOperation == a.loanOperation, legs.count <= 128,
      Set(legs.map(\.leg)).count == legs.count, legs.allSatisfy({ $0.valid(authorization: a) }),
      fuelContacts.count <= 128, Set(fuelContacts.map(\.sequence)).count == fuelContacts.count,
      fuelContacts.allSatisfy({
        $0.valid && $0.mission == a.parent && $0.ark == a.registeredArk
          && $0.station.world == a.owner && $0.physicalTime >= a.physicalTime
      }),
      exitedContacts == exitedContacts.sorted(), Set(exitedContacts).count == exitedContacts.count,
      exitedContacts.allSatisfy({ sequence in fuelContacts.contains { $0.sequence == sequence } }),
      fuel.purchases.allSatisfy({ purchase in fuelContacts.contains(purchase.request.offer.contact)
      })
    else { return false }
    guard fuelContacts.enumerated().allSatisfy({ $0.element.sequence == UInt64($0.offset + 1) }),
      exitedContacts == fuelContacts.filter({ $0 != dockedContact }).map(\.sequence),
      fuel.refusal.map({ fuelContacts.contains($0.request.offer.contact) }) ?? true,
      serviceWait == nil || dockedContact != nil
    else { return false }
    guard exits.map(\.contactSequence) == exitedContacts,
      zip(fuelContacts, fuelContacts.dropFirst()).allSatisfy({
        $0.physicalTime < $1.physicalTime && $0.arkActor.visit <= $1.arkActor.visit
      })
    else { return false }
    for exit in exits {
      guard let contact = fuelContacts.first(where: { $0.sequence == exit.contactSequence }),
        exit.actor != contact.arkActor,
        exit.actor.system == contact.station.system, exit.actor.visit >= contact.arkActor.visit,
        exit.actor.visit < UInt64(Int64.max), exit.actor.entity > 1,
        exit.actor.entity < UInt64(Int64.max),
        exit.physicalTime.isFinite, exit.physicalTime >= contact.physicalTime,
        exit.physicalTime <= 1e12
      else { return false }
    }
    if let dockedContact {
      guard fuelContacts.last == dockedContact, !exitedContacts.contains(dockedContact.sequence)
      else { return false }
    }
    if let admission {
      guard admission.actor.system == source.source, admission.actor.visit >= a.dock.actor.visit,
        admission.actor.entity > 1, admission.actor.entity < UInt64(Int64.max),
        admission.physicalTime.isFinite, admission.physicalTime >= a.physicalTime,
        admission.physicalTime <= 1e12
      else { return false }
    } else if !legs.isEmpty || loss != nil || !fuelContacts.isEmpty || !fuel.purchases.isEmpty {
      return false
    }
    if let reception {
      let link = NativeInductionArkLink(
        job: a.job, registeredArk: a.registeredArk,
        operation: a.operation, loanOperation: a.loanOperation)
      guard loss == nil, reception.valid(key: key, link: link),
        reception.seeds == a.seeds, reception.crew == a.crew,
        reception.arkDock == dockedContact, reception.owner == a.owner,
        reception.parent == a.parent, reception.flightSeconds >= a.flightSeconds,
        fuel.closure?.receivingOperation == reception.operation
      else { return false }
    } else if let closure = fuel.closure {
      guard loss != nil, closure.receivingOperation == nil, closure.recoveryOperation != nil else {
        return false
      }
    }
    if let loss {
      guard loss.actor.visit >= a.dock.actor.visit, loss.actor.visit < UInt64(Int64.max),
        loss.actor.entity > 1, loss.actor.entity < UInt64(Int64.max),
        loss.observedPhysicalTime.isFinite,
        loss.observedPhysicalTime >= (admission?.physicalTime ?? .infinity),
        loss.observedPhysicalTime <= 1e12
      else { return false }
    }
    return true
  }
}

extension NativeArkLaunchAuthorization {
  static func preparing(
    source: NativeInductionArkSource, dock: NativeMainStationDockReceipt,
    carrier: UUID, revision: UInt64, physicalTime: Double, flightSeconds: Double,
    route: NativeArkRoutePlan, sequence: UInt64
  ) throws -> NativeArkLaunchAuthorization {
    let job = NativeInductionArkPack.instance(registeredArk: source.actor)
    let operation = try identity(
      registeredArk: source.actor, dock: dock,
      carrier: carrier, revision: revision, physicalTime: physicalTime, route: route)
    return NativeArkLaunchAuthorization(
      owner: source.owner, parent: source.mission,
      job: job, registeredArk: source.actor, actor: NativeInductionArkPack.actor(instance: job),
      operation: operation,
      stockIssue: ScriptIdentity.uuid("native-ark-initial-stock-v1:\(source.actor):\(operation)"),
      loanOperation: source.loanOperation, sequence: sequence, dock: dock,
      carrier: carrier, inventoryRevision: revision, physicalTime: physicalTime,
      flightSeconds: flightSeconds, route: route, seeds: source.seeds, crew: source.crew,
      reserve: source.reserve)
  }
}
