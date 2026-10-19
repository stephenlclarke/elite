import Foundation

/// RRS logical identity. Neither a scene body number nor a visit actor identifies a station.
struct NativeStationIdentity: Hashable, Codable, Sendable {
  let world: UUID
  let system: SystemIdentity
  let definition: String
  let version: String
  let key: String

  var valid: Bool {
    (0..<8).contains(system.galaxy) && (0..<256).contains(system.system)
      && ["rescue_station", "rrs_headquarters"].contains(definition)
      && version == "1.5.4" && Self.token(key)
  }

  /// One logical source-class slot per system, independent of provenance or display key.
  var slot: NativeStationSlot { .init(world: world, system: system, definition: definition) }

  private static func token(_ value: String) -> Bool {
    guard !value.isEmpty, value.utf8.count <= 80 else { return false }
    for byte in value.utf8 {
      switch byte {
      case 48...57, 65...90, 97...122, 45, 46, 95: break
      default: return false
      }
    }
    return true
  }
}

struct NativeStationSlot: Hashable, Sendable {
  let world: UUID
  let system: SystemIdentity
  let definition: String
}

enum NativeStationCapability: String, Hashable, Codable, Sendable { case rrsContractBoard }
enum NativeStationCapabilityOrigin: String, Codable, Sendable { case source, projectExtension }

/// Structural metadata only. G1's checked source adapter must establish authenticity.
struct NativeStationDescriptor: Equatable, Codable, Sendable {
  let definition: String
  let version: String
  let boardOrigin: NativeStationCapabilityOrigin
  let capabilities: [NativeStationCapability]

  var sourceRoles: [String] {
    [
      definition == "rescue_station" ? "rescue_station" : "rrs_galactic_hq",
      "rrs_group_spacestation",
    ]
  }

  func matches(_ identity: NativeStationIdentity) -> Bool {
    definition == identity.definition && version == identity.version
      && Set(capabilities).count == capabilities.count
      && ((definition == "rescue_station" && boardOrigin == .source)
        || (definition == "rrs_headquarters" && boardOrigin == .projectExtension))
  }
}

struct NativeStationBinding: Equatable, Codable, Sendable {
  let actor: ActorIdentity
  let bodyID: Int

  func valid(for identity: NativeStationIdentity) -> Bool {
    actor.system == identity.system && actor.visit > 0 && actor.visit <= UInt64(Int64.max)
      && actor.entity >= 2 && actor.entity <= UInt64(Int64.max) && bodyID > 0
  }
}

private struct NativeStationBodyBinding: Hashable {
  let system: SystemIdentity
  let visit: UInt64
  let bodyID: Int

  init(_ binding: NativeStationBinding) {
    system = binding.actor.system
    visit = binding.actor.visit
    bodyID = binding.bodyID
  }
}

struct NativeStationTombstone: Equatable, Codable, Sendable {
  let revision: UInt64
  let destroyedBinding: NativeStationBinding
}

struct NativeStationRecord: Equatable, Codable, Sendable {
  let identity: NativeStationIdentity
  let descriptor: NativeStationDescriptor
  var revision: UInt64
  var binding: NativeStationBinding?
  var tombstone: NativeStationTombstone?

  var valid: Bool {
    identity.valid && descriptor.matches(identity) && revision > 0
      && revision < UInt64(Int64.max) && (binding?.valid(for: identity) ?? true)
      && (tombstone.map {
        $0.revision == revision && $0.destroyedBinding.valid(for: identity) && binding == nil
      } ?? true)
  }
}

/// Frozen evidence of actual docking, retained across load and subsequent visit rebinding.
struct NativeStationDockReceipt: Equatable, Codable, Sendable {
  let station: NativeStationIdentity
  let lifecycleRevision: UInt64
  let dockingBinding: NativeStationBinding
  let sequence: UInt64
  let commanderOwner: UUID
}

/// Never decoded or saved. Only the trusted native boundary can request a fresh context.
struct NativeStationServiceContext: Equatable, Sendable {
  let receipt: NativeStationDockReceipt
  let capability: NativeStationCapability
  let runtimeEpoch: UUID

  fileprivate init(
    receipt: NativeStationDockReceipt, capability: NativeStationCapability, runtimeEpoch: UUID
  ) {
    self.receipt = receipt
    self.capability = capability
    self.runtimeEpoch = runtimeEpoch
  }
}

enum NativeStationStateError: Error { case invalidState, unavailable }

struct NativeStationLedger: Equatable, Codable, Sendable {
  /// At most one source waystation per ordinary world plus one HQ per galaxy.
  static let maximumSourceRecords = 8 * (256 + 1)
  static var recordLimit: Int { NativeStationSource.bindings.count }
  let world: UUID
  private(set) var records: [NativeStationRecord]
  private(set) var nextDockSequence: UInt64
  private(set) var currentDock: NativeStationDockReceipt?

  /// Explicit activation only; decoding never invents a namespace, record or arrival.
  init(world: UUID, records: [NativeStationRecord]) throws {
    self.world = world
    self.records = records
    nextDockSequence = 1
    currentDock = nil
    guard valid else { throw NativeStationStateError.invalidState }
  }

  var valid: Bool {
    guard Self.recordLimit <= Self.maximumSourceRecords,
      records.count <= Self.recordLimit, nextDockSequence > 0,
      nextDockSequence < UInt64(Int64.max),
      records.allSatisfy({ $0.valid && $0.identity.world == world }),
      Set(records.map(\.identity)).count == records.count,
      Set(records.map { $0.identity.slot }).count == records.count
    else { return false }
    let bindings = records.compactMap { $0.binding ?? $0.tombstone?.destroyedBinding }
    guard Set(bindings.map(\.actor)).count == bindings.count else { return false }
    // Body numbers are unique only within their system visit.
    guard Set(bindings.map(NativeStationBodyBinding.init)).count == bindings.count else {
      return false
    }
    guard let receipt = currentDock else { return true }
    guard
      !records.contains(where: { record in
        guard record.identity.slot != receipt.station.slot,
          let binding = record.binding ?? record.tombstone?.destroyedBinding
        else { return false }
        return binding.actor == receipt.dockingBinding.actor
          || (binding.actor.system == receipt.dockingBinding.actor.system
            && binding.actor.visit == receipt.dockingBinding.actor.visit
            && binding.bodyID == receipt.dockingBinding.bodyID)
      })
    else { return false }
    return receipt.sequence > 0 && receipt.sequence == nextDockSequence - 1
      && receipt.dockingBinding.valid(for: receipt.station)
      && records.contains {
        $0.identity == receipt.station && $0.tombstone == nil
          && $0.revision == receipt.lifecycleRevision
      }
  }

  /// Native preflight owns the physical proof. Rebinding cannot revive a destroyed station.
  mutating func rebind(_ identity: NativeStationIdentity, to binding: NativeStationBinding) throws {
    guard valid, let index = records.firstIndex(where: { $0.identity == identity }),
      records[index].tombstone == nil, binding.valid(for: identity)
    else { throw NativeStationStateError.unavailable }
    var candidate = self
    candidate.records[index].binding = binding
    guard candidate.valid else { throw NativeStationStateError.invalidState }
    self = candidate
  }

  /// Call only after actual native docking and persistence preflight have succeeded.
  mutating func recordDock(
    at identity: NativeStationIdentity, binding: NativeStationBinding, commanderOwner: UUID?
  ) throws {
    guard let commanderOwner, valid, currentDock == nil, nextDockSequence < UInt64(Int64.max) - 1,
      let record = records.first(where: { $0.identity == identity }), record.tombstone == nil,
      record.binding == binding
    else { throw NativeStationStateError.unavailable }
    currentDock = .init(
      station: identity, lifecycleRevision: record.revision, dockingBinding: binding,
      sequence: nextDockSequence, commanderOwner: commanderOwner)
    nextDockSequence += 1
  }

  mutating func depart() { currentDock = nil }

  mutating func destroy(_ identity: NativeStationIdentity, binding: NativeStationBinding) throws {
    guard valid, let index = records.firstIndex(where: { $0.identity == identity }),
      records[index].tombstone == nil, records[index].binding == binding,
      records[index].revision < UInt64(Int64.max) - 1
    else { throw NativeStationStateError.unavailable }
    records[index].revision += 1
    records[index].tombstone = .init(revision: records[index].revision, destroyedBinding: binding)
    records[index].binding = nil
    if currentDock?.station == identity { currentDock = nil }
  }

  /// G1 supplies actual docked state/system/owner and the current transient runtime epoch.
  func serviceContext(
    capability: NativeStationCapability, docked: Bool, system: SystemIdentity,
    commanderOwner: UUID?, runtimeEpoch: UUID
  ) -> NativeStationServiceContext? {
    guard let commanderOwner, valid, docked, let receipt = currentDock,
      receipt.station.system == system,
      receipt.commanderOwner == commanderOwner,
      records.first(where: { $0.identity == receipt.station })?.descriptor.capabilities.contains(
        capability)
        == true
    else { return nil }
    return .init(receipt: receipt, capability: capability, runtimeEpoch: runtimeEpoch)
  }

  func accepts(
    _ context: NativeStationServiceContext, docked: Bool, system: SystemIdentity,
    commanderOwner: UUID?, runtimeEpoch: UUID
  ) -> Bool {
    serviceContext(
      capability: context.capability, docked: docked, system: system,
      commanderOwner: commanderOwner, runtimeEpoch: runtimeEpoch) == context
  }

  private enum CodingKeys: String, CodingKey { case world, records, nextDockSequence, currentDock }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    world = try values.decode(UUID.self, forKey: .world)
    var entries = try values.nestedUnkeyedContainer(forKey: .records)
    guard Self.recordLimit <= Self.maximumSourceRecords,
      entries.count.map({ $0 <= Self.recordLimit }) ?? true
    else {
      throw DecodingError.dataCorruptedError(
        forKey: .records, in: values, debugDescription: "Native station record limit exceeded.")
    }
    var decoded: [NativeStationRecord] = []
    while !entries.isAtEnd {
      guard decoded.count < Self.recordLimit else {
        throw DecodingError.dataCorruptedError(
          forKey: .records, in: values, debugDescription: "Native station record limit exceeded.")
      }
      decoded.append(try entries.decode(NativeStationRecord.self))
    }
    records = decoded
    nextDockSequence = try values.decode(UInt64.self, forKey: .nextDockSequence)
    currentDock = try values.decodeIfPresent(NativeStationDockReceipt.self, forKey: .currentDock)
    guard valid else {
      throw DecodingError.dataCorruptedError(
        forKey: .records, in: values, debugDescription: "Invalid native station custody.")
    }
  }
}
