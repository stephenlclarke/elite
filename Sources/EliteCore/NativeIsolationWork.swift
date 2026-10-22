import Foundation

/// Only the real parent primitive plus fresh original programmer custody can mint this value.
struct NativeIsolationWorkParentAuthority: Equatable, Sendable {
  let parentID: UUID
  let parentDigest: String
  let authorization: UUID
  let issueOperation: UUID
  let owner: UUID
  let issuer: UUID
  let acceptance: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64

  private init(
    parentID: UUID, parentDigest: String, authorization: UUID, issueOperation: UUID,
    owner: UUID, issuer: UUID,
    acceptance: NativeMainStationDockReceipt, carrier: UUID, inventoryRevision: UInt64
  ) {
    self.parentID = parentID
    self.parentDigest = parentDigest
    self.authorization = authorization
    self.issueOperation = issueOperation
    self.owner = owner
    self.issuer = issuer
    self.acceptance = acceptance
    self.carrier = carrier
    self.inventoryRevision = inventoryRevision
  }

  static func resolve(parentID: UUID, commander: borrowing Commander) throws
    -> (authority: Self, primitive: NativeIsolationWorkParentPrimitive)
  {
    guard let parent = commander.scriptState.instances[parentID], parent.outcome == .active,
      parent.suspension == nil, let carrier = commander.hullInstanceID,
      let revision = commander.equipmentInventory?.revision
    else { throw SaveError.invalidCommander }
    let primitive = try NativeIsolationWorkParent.primitive(parent: parent, commander: commander)
    guard primitive.cutoff == nil else { throw SaveError.invalidCommander }
    let value = Self(
      parentID: primitive.parentID, parentDigest: primitive.parentDigest,
      authorization: primitive.authorization, issueOperation: primitive.issueOperation,
      owner: primitive.owner, issuer: primitive.issuer, acceptance: primitive.acceptance,
      carrier: carrier, inventoryRevision: revision)
    _ = try value.programmer(in: commander)
    return (value, primitive)
  }

  /// The opaque parent proof is necessary but insufficient: every use rejoins the live loan.
  func programmer(in commander: borrowing Commander) throws -> NativeIsolationProgrammerBinding {
    guard let parent = commander.scriptState.instances[parentID],
      parent.digest == parentDigest, parent.outcome == .active, parent.suspension == nil,
      commander.equipmentOwnerID == owner, commander.hullInstanceID == carrier,
      commander.equipmentInventory?.revision == inventoryRevision,
      issuer == NativeIsolationProgrammerDefinition.issuer(owner: owner),
      acceptance.station.system == NativeIsolationWorkSource.issuerLocation,
      NativeStationPassengerJourney.historicalDock(acceptance, commander: commander)
    else { throw SaveError.invalidCommander }
    let binding = try NativeIsolationProgrammerCustody.resolve(
      parent: parent, commander: copy commander)
    guard binding.source.mission == parentID, binding.source.packDigest == parentDigest,
      binding.source.resource == NativeIsolationWorkSource.programmerResource,
      binding.issuer == issuer, binding.owner == owner, binding.hull == carrier,
      binding.inventoryRevision == inventoryRevision
    else { throw SaveError.invalidCommander }
    return binding
  }
}

/// These accounts are local utility energy, separate from hull integrity and player resources.
struct NativeIsolationEnergyAccounts: Codable, Equatable, Sendable {
  static let capacity = 10000.0
  private(set) var remainingSupply = capacity
  private(set) var deliveredLoad = 0.0
  var headroom: Double { Self.capacity - deliveredLoad }
  var valid: Bool {
    remainingSupply.isFinite && deliveredLoad.isFinite
      && (0...Self.capacity).contains(remainingSupply)
      && (0...Self.capacity).contains(deliveredLoad)
      && abs(remainingSupply + deliveredLoad - Self.capacity) < 1e-7
  }

  /// Called by the attained native producer; the canonical contact controls real transfer.
  mutating func transfer(seconds: Double, contact: NativeIsolationContact) throws -> Double {
    guard valid, contact.valid, seconds.isFinite, seconds > 0, seconds <= 0.100001 else {
      throw SaveError.invalidCommander
    }
    guard case .connected = contact else { return 0 }
    let amount = min(seconds, remainingSupply, headroom)
    deliveredLoad += amount
    remainingSupply = Self.capacity - deliveredLoad
    guard valid else { throw SaveError.invalidCommander }
    return amount
  }
}

/// This is the actual producer disconnect, not a journal completion flag.
enum NativeIsolationContact: Codable, Equatable, Sendable {
  case connected
  case latchedOpen(operation: UUID, revision: UInt64)
  var valid: Bool {
    switch self {
    case .connected: true
    case .latchedOpen(_, let revision): revision > 0 && revision < UInt64(Int64.max)
    }
  }
}

enum NativeIsolationWorkEnvelope {
  static let requiredWork = 20.0
  static let requiredObservation = 1.0
  static let maximumSegments = 256

  static func qualifies(range: Double, speed: Double, aim: Double) -> Bool {
    range.isFinite && (50...150).contains(range)
      && speed.isFinite && (0...1).contains(speed)
      && aim.isFinite && (0...(2 * Double.pi / 180)).contains(aim)
  }
  static func interval(start: Double, end: Double) -> Double? {
    guard start.isFinite, end.isFinite, start >= 0, end > start, end <= 1e12,
      end - start <= 0.100001
    else { return nil }
    return end - start
  }
}

/// Historical measurement facts never restore a live arm or its runtime epoch.
struct NativeIsolationMeasurementAuthority: Codable, Equatable, Sendable {
  let parent: UUID
  let authorization: UUID
  let owner: UUID
  let source: UUID
  let role: NativeIsolationWorkRole
  let module: UUID
  let issueOperation: UUID
  let programmer: UUID
  let carrier: UUID
  let inventoryRevision: UInt64
  let actor: ActorIdentity
  let player: ActorIdentity

  var valid: Bool {
    let original = NativeIsolationWorkSource(owner: owner)
    return source == original.id && module == original.module(role)
      && actor.system == NativeIsolationWorkSource.location && actor.entity > 1
      && actor.entity < UInt64(Int64.max) && actor.visit > 0
      && actor.visit < UInt64(Int64.max) && player.system == actor.system
      && player.visit == actor.visit && player.entity == 0
      && inventoryRevision < UInt64(Int64.max)
  }

  func sameOriginal(as other: Self) -> Bool {
    parent == other.parent && authorization == other.authorization && owner == other.owner
      && source == other.source && role == other.role && module == other.module
      && issueOperation == other.issueOperation && programmer == other.programmer
  }
}

enum NativeIsolationMeasurementPhase: String, Codable, Sendable {
  case work, observation
  var requiredSeconds: Double {
    self == .work
      ? NativeIsolationWorkEnvelope.requiredWork
      : NativeIsolationWorkEnvelope.requiredObservation
  }
}

struct NativeIsolationWorkSegment: Codable, Equatable, Sendable {
  let authority: NativeIsolationMeasurementAuthority
  let phase: NativeIsolationMeasurementPhase
  let first: Double
  var last: Double
  var seconds: Double
  var intervals: UInt64
  var lastRange: Double
  var lastSpeed: Double
  var lastAim: Double

  var valid: Bool {
    authority.valid && first.isFinite && last.isFinite && first >= 0 && last > first
      && last <= 1e12 && seconds.isFinite && seconds > 0
      && seconds <= phase.requiredSeconds + 1e-8 && seconds <= last - first + 1e-7
      && intervals > 0 && intervals < 1_000_000_000
      && seconds <= Double(intervals) * 0.100001 + 1e-7
      && NativeIsolationWorkEnvelope.qualifies(range: lastRange, speed: lastSpeed, aim: lastAim)
  }
}

/// Qualifying intervals with the same authority coalesce, including a 60 Hz twenty-second run.
/// Gaps add no time. A history slot records a distinct authority, never a simulation frame.
struct NativeIsolationWorkHistory: Codable, Equatable, Sendable {
  private(set) var segments: [NativeIsolationWorkSegment] = []
  func seconds(_ phase: NativeIsolationMeasurementPhase) -> Double {
    segments.filter { $0.phase == phase }.reduce(0) { $0 + $1.seconds }
  }
  var valid: Bool {
    guard segments.count <= NativeIsolationWorkEnvelope.maximumSegments,
      segments.allSatisfy(\.valid),
      zip(segments, segments.dropFirst()).allSatisfy({ $0.last <= $1.first }),
      [NativeIsolationMeasurementPhase.work, .observation].allSatisfy({
        seconds($0).isFinite && seconds($0) <= $0.requiredSeconds + 1e-8
      })
    else { return false }
    guard let observation = segments.firstIndex(where: { $0.phase == .observation }) else {
      return true
    }
    return abs(seconds(.work) - NativeIsolationWorkEnvelope.requiredWork) < 1e-8
      && segments[observation...].allSatisfy { $0.phase == .observation }
  }

  /// Pure history accounting. Only private native endpoint/meter producers supply runtime facts.
  mutating func record(
    authority: NativeIsolationMeasurementAuthority, phase: NativeIsolationMeasurementPhase,
    start: Double, end: Double, range: Double, speed: Double, aim: Double
  ) throws {
    guard valid, authority.valid,
      let interval = NativeIsolationWorkEnvelope.interval(start: start, end: end),
      NativeIsolationWorkEnvelope.qualifies(range: range, speed: speed, aim: aim),
      start >= (segments.last?.last ?? 0)
    else { throw SaveError.invalidCommander }
    if phase == .observation {
      guard abs(seconds(.work) - NativeIsolationWorkEnvelope.requiredWork) < 1e-8 else {
        throw SaveError.invalidCommander
      }
    } else if segments.contains(where: { $0.phase == .observation }) {
      throw SaveError.invalidCommander
    }
    let credit = min(interval, max(0, phase.requiredSeconds - seconds(phase)))
    guard credit > 0 else { return }
    if var last = segments.last, last.authority == authority, last.phase == phase,
      last.intervals < 999_999_999
    {
      last.last = end
      last.seconds += credit
      last.intervals += 1
      last.lastRange = range
      last.lastSpeed = speed
      last.lastAim = aim
      segments[segments.count - 1] = last
    } else {
      guard segments.count < NativeIsolationWorkEnvelope.maximumSegments else {
        throw SaveError.invalidCommander
      }
      segments.append(
        .init(
          authority: authority, phase: phase, first: start, last: end, seconds: credit,
          intervals: 1, lastRange: range, lastSpeed: speed, lastAim: aim))
    }
    guard valid else { throw SaveError.invalidCommander }
  }
}

struct NativeIsolationWorkPermission: Codable, Equatable, Sendable {
  let parent: UUID
  let parentDigest: String
  let authorization: UUID
  let issueOperation: UUID
  let owner: UUID
  let issuer: UUID
  let programmer: UUID
  let carrier: UUID
  let inventoryRevision: UInt64
  let acceptance: NativeMainStationDockReceipt
  let sequence: UInt64
  let physicalTime: Double

  init(
    authority: NativeIsolationWorkParentAuthority, commander: borrowing Commander,
    sequence: UInt64
  ) throws {
    let binding = try authority.programmer(in: commander)
    guard sequence > 0, sequence < UInt64(Int64.max) else {
      throw SaveError.invalidCommander
    }
    parent = authority.parentID
    parentDigest = authority.parentDigest
    authorization = authority.authorization
    issueOperation = authority.issueOperation
    owner = authority.owner
    issuer = authority.issuer
    programmer = binding.serial
    carrier = binding.hull
    inventoryRevision = binding.inventoryRevision
    acceptance = authority.acceptance
    self.sequence = sequence
    physicalTime = commander.flightSimulation.physicalTime
    guard valid else { throw SaveError.invalidCommander }
  }

  var valid: Bool {
    ScriptCompletionReceipt.validDigest(parentDigest)
      && issuer == NativeIsolationWorkSource(owner: owner).issuer
      && programmer == NativeIsolationProgrammerDefinition.serial(parent: parent)
      && acceptance.valid && acceptance.commanderOwner == owner
      && acceptance.station.system == NativeIsolationWorkSource.issuerLocation
      && sequence > 0 && sequence < UInt64(Int64.max)
      && inventoryRevision < UInt64(Int64.max)
      && physicalTime.isFinite && (0...1e12).contains(physicalTime)
  }
  func matches(_ authority: NativeIsolationWorkParentAuthority, programmer: UUID) -> Bool {
    parent == authority.parentID && parentDigest == authority.parentDigest
      && authorization == authority.authorization && issueOperation == authority.issueOperation
      && owner == authority.owner && issuer == authority.issuer && self.programmer == programmer
  }
}

struct NativeIsolationWorkAdmission: Codable, Equatable, Sendable {
  let source: UUID
  let role: NativeIsolationWorkRole
  let logicalActor: UUID
  let actor: ActorIdentity
  let station: StationAnchor
  let pose: ShipPose
  let geometry: String
  let sequence: UInt64
  let physicalTime: Double

  func valid(source original: NativeIsolationWorkSource, permission: NativeIsolationWorkPermission)
    -> Bool
  {
    source == original.id
      && logicalActor
        == NativeIsolationWorkPack.actor(
          job: NativeIsolationWorkPack.instance(source: source), role: role)
      && actor.system == NativeIsolationWorkSource.location
      && actor.visit == station.identity.visit && actor.entity > 1
      && actor.entity < UInt64(Int64.max) && station.identity.entity == 1
      && pose == (try? original.initialPose(role, reference: station))
      && geometry == (try? NativeIsolationWorkSource.geometryHash)
      && sequence > permission.sequence && sequence < UInt64(Int64.max)
      && physicalTime.isFinite && physicalTime >= permission.physicalTime && physicalTime <= 1e12
  }
}

/// Saved evidence of an actual producer step. This is never accepted as a live endpoint.
struct NativeIsolationMeterEvidence: Codable, Equatable, Sendable {
  let actor: ActorIdentity
  let peer: ActorIdentity
  let sequence: UInt64
  let start: Double
  let end: Double
  let contact: NativeIsolationContact
  let before: NativeIsolationEnergyAccounts
  let after: NativeIsolationEnergyAccounts
  let transferred: Double

  var valid: Bool {
    guard before.valid, after.valid, contact.valid,
      let elapsed = NativeIsolationWorkEnvelope.interval(start: start, end: end),
      sequence > 0, sequence < UInt64(Int64.max), transferred.isFinite, transferred >= 0,
      actor.system == NativeIsolationWorkSource.location, peer.system == actor.system,
      peer.visit == actor.visit, actor.entity > 1, peer.entity > 1,
      actor.entity != peer.entity, actor.visit > 0,
      abs(before.remainingSupply - after.remainingSupply - transferred) < 1e-7,
      abs(after.deliveredLoad - before.deliveredLoad - transferred) < 1e-7
    else { return false }
    let expected: Double
    switch contact {
    case .connected: expected = min(elapsed, before.remainingSupply, before.headroom)
    case .latchedOpen: expected = 0
    }
    return abs(transferred - expected) < 1e-7
  }
}

struct NativeIsolationWorkOpening: Codable, Equatable, Sendable {
  let operation: UUID
  let sequence: UInt64
  let authority: NativeIsolationMeasurementAuthority
  let geometry: String
  let workHistory: String
  let contactRevision: UInt64
  let meter: NativeIsolationMeterEvidence

  static func identity(
    authority: NativeIsolationMeasurementAuthority, history: String,
    meter: NativeIsolationMeterEvidence, revision: UInt64, sequence: UInt64
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "g11-isolation-open-v1:\(try NativeFlightReception.hash(authority)):\(history):\(try NativeFlightReception.hash(meter)):\(revision):\(sequence)"
    )
  }
  func valid(history: NativeIsolationWorkHistory) -> Bool {
    let work = history.segments.filter { $0.phase == .work }
    return authority.valid && history.valid && abs(history.seconds(.work) - 20) < 1e-8
      && work.allSatisfy({ $0.authority.sameOriginal(as: authority) })
      && (work.last?.last ?? .infinity) <= meter.end
      && workHistory == (try? NativeFlightReception.hash(work))
      && geometry == (try? NativeIsolationWorkSource.geometryHash)
      && contactRevision > 0 && contactRevision < UInt64(Int64.max)
      && sequence > 0 && sequence < UInt64(Int64.max)
      && meter.valid && meter.actor == authority.actor && meter.contact == .connected
      && meter.transferred > 0 && meter.before.remainingSupply > 0 && meter.before.headroom > 0
      && meter.after.remainingSupply > 0 && meter.after.headroom > 0
      && operation
        == (try? Self.identity(
          authority: authority, history: workHistory, meter: meter,
          revision: contactRevision, sequence: sequence))
  }
}

struct NativeIsolationVerification: Codable, Equatable, Sendable {
  let operation: UUID
  let sequence: UInt64
  let authority: NativeIsolationMeasurementAuthority
  let opening: UUID
  let geometry: String
  let workHistory: String
  let observationHistory: String
  let first: NativeIsolationMeterEvidence
  let last: NativeIsolationMeterEvidence

  static func identity(
    opening: UUID, authority: NativeIsolationMeasurementAuthority, observation: String,
    first: NativeIsolationMeterEvidence, last: NativeIsolationMeterEvidence, sequence: UInt64
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "g11-isolation-verified-v1:\(opening):\(try NativeFlightReception.hash(authority)):\(observation):\(try NativeFlightReception.hash(first)):\(try NativeFlightReception.hash(last)):\(sequence)"
    )
  }
  func valid(opened: NativeIsolationWorkOpening, history: NativeIsolationWorkHistory) -> Bool {
    let observations = history.segments.filter { $0.phase == .observation }
    let contact = NativeIsolationContact.latchedOpen(
      operation: opened.operation, revision: opened.contactRevision)
    return opened.valid(history: history) && authority.valid && history.valid
      && authority.sameOriginal(as: opened.authority)
      && opening == opened.operation && geometry == opened.geometry
      && workHistory == opened.workHistory
      && abs(history.seconds(.observation) - 1) < 1e-8
      && observationHistory == (try? NativeFlightReception.hash(observations))
      && observations.allSatisfy({ $0.authority.sameOriginal(as: authority) })
      && observations.first?.first == first.start
      && (observations.last?.last ?? .infinity) <= last.end && last.actor == authority.actor
      && first.valid && last.valid && first.sequence > opened.meter.sequence
      && last.sequence >= first.sequence && first.start >= opened.meter.end
      && first.end > opened.meter.end && last.end >= first.end
      && first.contact == contact && last.contact == contact
      && first.transferred == 0 && last.transferred == 0
      && first.before.remainingSupply > 0 && first.before.headroom > 0
      && last.after.remainingSupply > 0 && last.after.headroom > 0
      && sequence > opened.sequence && sequence < UInt64(Int64.max)
      && operation
        == (try? Self.identity(
          opening: opening, authority: authority, observation: observationHistory,
          first: first, last: last, sequence: sequence))
  }
}

struct NativeIsolationModuleLoss: Codable, Equatable, Sendable {
  let actor: ActorIdentity
  let sequence: UInt64
  let physicalTime: Double
}

struct NativeIsolationStationLoss: Codable, Equatable, Sendable {
  let station: NativeMainStationIdentity
  let sequence: UInt64
  let physicalTime: Double
}

struct NativeIsolationWorkModule: Codable, Equatable, Sendable {
  let role: NativeIsolationWorkRole
  let module: UUID
  let supply: UUID
  let load: UUID
  var accounts = NativeIsolationEnergyAccounts()
  var connectedSeconds = 0.0
  var contact = NativeIsolationContact.connected
  var history = NativeIsolationWorkHistory()
  var admission: NativeIsolationWorkAdmission?
  var retainedPose: ShipPose?
  var binding: ActorIdentity?
  var lastMeter: NativeIsolationMeterEvidence?
  var observationFirst: NativeIsolationMeterEvidence?
  var opening: NativeIsolationWorkOpening?
  var verification: NativeIsolationVerification?
  var loss: NativeIsolationModuleLoss?

  init(source: NativeIsolationWorkSource, role: NativeIsolationWorkRole) {
    self.role = role
    module = source.module(role)
    supply = source.supply(role)
    load = source.load(role)
  }

  func valid(
    permission: NativeIsolationWorkPermission, producerSequence: UInt64, localSeconds: Double
  ) -> Bool {
    let source = NativeIsolationWorkSource(owner: permission.owner)
    guard module == source.module(role), supply == source.supply(role), load == source.load(role),
      accounts.valid, contact.valid, history.valid,
      connectedSeconds.isFinite, connectedSeconds >= 0, connectedSeconds <= localSeconds + 1e-7,
      abs(accounts.deliveredLoad - min(connectedSeconds, NativeIsolationEnergyAccounts.capacity))
        < 1e-7,
      history.seconds(.work) <= connectedSeconds + 1e-7,
      history.segments.allSatisfy({
        let a = $0.authority
        return a.parent == permission.parent && a.authorization == permission.authorization
          && a.owner == permission.owner && a.source == source.id && a.role == role
          && a.module == module && a.issueOperation == permission.issueOperation
          && a.programmer == permission.programmer
      })
    else { return false }
    if let binding {
      guard binding.system == NativeIsolationWorkSource.location, binding.visit > 0,
        binding.entity > 1, binding.entity < UInt64(Int64.max)
      else { return false }
    }
    if let admission {
      guard admission.role == role, admission.valid(source: source, permission: permission),
        let retainedPose, retainedPose.position.finite, retainedPose.position.length <= 1e9,
        retainedPose.orientation.validRotation,
        history.segments.allSatisfy({
          $0.first >= admission.physicalTime && $0.authority.actor.visit >= admission.actor.visit
        })
      else { return false }
    } else if binding != nil || retainedPose != nil || !history.segments.isEmpty || lastMeter != nil
      || loss != nil
    {
      return false
    }
    if let lastMeter {
      guard lastMeter.valid, lastMeter.after == accounts,
        lastMeter.sequence == producerSequence, lastMeter.sequence > 0
      else { return false }
    } else if producerSequence != 0 || localSeconds != 0 {
      return false
    }
    if let loss {
      guard admission != nil, loss.actor.system == NativeIsolationWorkSource.location,
        loss.actor.entity > 1, loss.sequence > permission.sequence,
        loss.sequence < UInt64(Int64.max), loss.physicalTime.isFinite,
        loss.physicalTime >= (admission?.physicalTime ?? .infinity), loss.physicalTime <= 1e12
      else { return false }
    }
    switch contact {
    case .connected:
      return opening == nil && verification == nil && observationFirst == nil
        && history.seconds(.observation) == 0 && abs(connectedSeconds - localSeconds) < 1e-7
    case .latchedOpen(let operation, let revision):
      guard let opening, opening.operation == operation, opening.contactRevision == revision,
        opening.valid(history: history), accounts == opening.meter.after,
        opening.authority.role == role, opening.authority.module == module,
        opening.sequence > (admission?.sequence ?? UInt64.max),
        opening.meter.sequence <= producerSequence
      else { return false }
      if history.seconds(.observation) > 0 {
        guard let observationFirst, observationFirst.valid,
          observationFirst.sequence > opening.meter.sequence,
          observationFirst.start >= opening.meter.end, observationFirst.transferred == 0,
          observationFirst.contact == contact, observationFirst.before == accounts,
          observationFirst.after == accounts
        else { return false }
      } else if observationFirst != nil || verification != nil {
        return false
      }
      if let verification {
        guard verification.valid(opened: opening, history: history),
          verification.first == observationFirst, verification.last.after == accounts,
          verification.last.sequence <= producerSequence
        else { return false }
      }
      return true
    }
  }
}

struct NativeIsolationWorkState: Codable, Equatable, Sendable {
  let permission: NativeIsolationWorkPermission
  let source: UUID
  let job: UUID
  var modules: [NativeIsolationWorkModule]
  var producerSequence: UInt64 = 0
  var localSeconds = 0.0
  var stationLoss: NativeIsolationStationLoss?

  init(permission: NativeIsolationWorkPermission) throws {
    guard permission.valid else { throw SaveError.invalidCommander }
    let original = NativeIsolationWorkSource(owner: permission.owner)
    self.permission = permission
    source = original.id
    job = NativeIsolationWorkPack.instance(source: source)
    modules = NativeIsolationWorkRole.allCases.map { .init(source: original, role: $0) }
  }

  var shapeValid: Bool {
    guard permission.valid, source == NativeIsolationWorkSource(owner: permission.owner).id,
      job == NativeIsolationWorkPack.instance(source: source), modules.count == 2,
      Set(modules.map(\.role)) == Set(NativeIsolationWorkRole.allCases),
      Set(modules.map(\.module)).count == 2, producerSequence < UInt64(Int64.max),
      localSeconds.isFinite, (0...1e12).contains(localSeconds),
      localSeconds <= Double(producerSequence) * 0.100001 + 1e-7,
      modules.allSatisfy({
        $0.valid(
          permission: permission, producerSequence: producerSequence, localSeconds: localSeconds)
      })
    else { return false }
    let bindings = modules.compactMap(\.binding)
    guard Set(bindings).count == bindings.count else { return false }
    let meters = modules.compactMap(\.lastMeter)
    if meters.count == 2 {
      guard meters[0].sequence == meters[1].sequence,
        meters[0].start == meters[1].start, meters[0].end == meters[1].end,
        meters[0].actor == meters[1].peer, meters[1].actor == meters[0].peer,
        modules[0].binding == meters[0].actor, modules[1].binding == meters[1].actor
      else { return false }
    } else if !meters.isEmpty {
      return false
    }
    if let stationLoss {
      guard stationLoss.station.world == permission.owner,
        [NativeIsolationWorkSource.location, NativeIsolationWorkSource.issuerLocation].contains(
          stationLoss.station.system), stationLoss.sequence > permission.sequence,
        stationLoss.sequence < UInt64(Int64.max), stationLoss.physicalTime.isFinite,
        (permission.physicalTime...1e12).contains(stationLoss.physicalTime)
      else { return false }
    }
    return Set(modules.compactMap { $0.opening?.operation }).count
      == modules.filter { $0.opening != nil }.count
      && Set(modules.compactMap { $0.verification?.operation }).count
        == modules.filter { $0.verification != nil }.count
  }
}
