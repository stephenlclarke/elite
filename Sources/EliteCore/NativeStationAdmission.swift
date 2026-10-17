import Foundation

enum NativeStationRuntimeError: Error, Equatable {
  case invalidSource, invalidState, unavailable, unsafePlacement, capacity, unsafeEntry, unsafeExit
}

/// Compiled source authority; saved descriptors and Lua fields cannot add a station or service.
struct NativeStationSourceBinding: Equatable, Sendable {
  let system: SystemIdentity
  let kind: NativeStationGeometry.Kind

  var key: String { "\(kind.sourceDefinition)-g\(system.galaxy)-s\(system.system)" }
  var descriptor: NativeStationDescriptor {
    .init(
      definition: kind.sourceDefinition, version: NativeStationGeometry.sourceVersion,
      boardOrigin: kind == .waystation ? .source : .projectExtension,
      capabilities: [.rrsContractBoard])
  }
  var geometry: NativeStationGeometry {
    kind == .waystation ? .waystation : .headquarters
  }
  var rotationRate: Double { kind == .waystation ? 0.02 : 0 }
  var technology: Int { kind == .waystation ? 7 : 0 }

  func identity(world: UUID) -> NativeStationIdentity {
    .init(
      world: world, system: system, definition: kind.sourceDefinition,
      version: NativeStationGeometry.sourceVersion, key: key)
  }
}

enum NativeStationSource {
  static let adapterRevision = "project-native-rrs-v1"
  static let boardRevision = "PROJECT-RRS-BOARD-v1"
  static let routeBindingsSHA256 =
    "3166c79411db815afc32215d00f58e44a6958a279f4e1f3a617ab68a8ac9debb"
  static let headquarters = [237, 98, 5, 149, 35, 213, 66, 7]

  /// Original signed-int32 producer, checked against the retained 2,048-system route oracle.
  static func hasWaystation(galaxy: Int, system: StarSystem) -> Bool {
    guard (0..<8).contains(galaxy), (0..<256).contains(system.id) else { return false }
    var state = UInt32((system.id + 256 * galaxy) * 23)
    for _ in 0..<3 { state = state &* 214013 &+ 2_531_011 }
    let chance = Double(Int32(bitPattern: state)) / 4_294_967_296 + 0.5
    switch system.government {
    case 7: return chance < 0.75
    case 6: return chance < 0.5
    case 5: return chance < 0.25
    default: return false
    }
  }

  static let bindings: [NativeStationSourceBinding] = (0..<8).flatMap { galaxy in
    Universe.galaxy(number: galaxy).flatMap { system -> [NativeStationSourceBinding] in
      var result: [NativeStationSourceBinding] = []
      let identity = SystemIdentity(galaxy: galaxy, system: system.id)
      if hasWaystation(galaxy: galaxy, system: system) {
        result.append(.init(system: identity, kind: .waystation))
      }
      if system.id == headquarters[galaxy] {
        result.append(.init(system: identity, kind: .headquarters))
      }
      return result
    }
  }

  private static let bindingsByKey = Dictionary(uniqueKeysWithValues: bindings.map { ($0.key, $0) })
  private static let positionsByKey: [String: Vector3] = Dictionary(
    uniqueKeysWithValues: bindings.compactMap { binding in
      binding.geometry.position(in: canonicalAnchors(system: binding.system)).map {
        (binding.key, $0)
      }
    })

  static func binding(for identity: NativeStationIdentity) -> NativeStationSourceBinding? {
    guard identity.valid else { return nil }
    guard let binding = bindingsByKey[identity.key], binding.system == identity.system,
      binding.kind.sourceDefinition == identity.definition,
      identity.version == NativeStationGeometry.sourceVersion
    else { return nil }
    return binding
  }

  static func position(for source: NativeStationSourceBinding) -> Vector3? {
    positionsByKey[source.key]
  }

  /// Native origin zero, using the already-persisted simulation calendar without extra adjustments.
  static func boardHour(calendarSeconds: Double) -> Int64? {
    guard calendarSeconds.isFinite, calendarSeconds >= 0 else { return nil }
    let hour = floor(calendarSeconds / 3600)
    guard hour < Double(Int64.max) else { return nil }
    return Int64(hour)
  }

  static func authentic(_ record: NativeStationRecord, owner: UUID) -> Bool {
    guard record.valid, record.identity.world == owner,
      let binding = binding(for: record.identity)
    else { return false }
    return record.descriptor == binding.descriptor
  }

  static func canonicalAnchors(system: SystemIdentity) -> SystemAnchors {
    var flight = FlightSimulationState()
    flight.enter(system, arriving: false)
    return flight.anchors!
  }

  /// Saved native adaptation. Source HQ random orientation is not claimed as deterministic parity.
  static func initialOrientation(_ identity: NativeStationIdentity) -> Basis3 {
    guard identity.definition == NativeStationGeometry.Kind.headquarters.sourceDefinition else {
      return Basis3()
    }
    var seed: UInt64 = 14_695_981_039_346_656_037
    for byte in (identity.world.uuidString + ":" + identity.key).utf8 {
      seed = (seed ^ UInt64(byte)) &* 1_099_511_628_211
    }
    func angle(_ value: UInt64) -> Double {
      Double(value & 0xffff) / 65536 * 2 * .pi
    }
    var orientation = Basis3()
    orientation.rotate(pitch: angle(seed), roll: angle(seed >> 16), yaw: angle(seed >> 32))
    return orientation
  }
}

struct NativeStationSavedPose: Equatable, Codable, Sendable {
  let station: NativeStationIdentity
  let position: Vector3
  let orientation: Basis3

  var valid: Bool {
    guard let source = NativeStationSource.binding(for: station),
      position.finite, position.length.isFinite, orientation.validRotation,
      position == NativeStationSource.position(for: source)
    else { return false }
    return orientation == NativeStationSource.initialOrientation(station)
  }

  func orientation(at physicalTime: Double) -> Basis3? {
    guard physicalTime.isFinite, physicalTime >= 0,
      let source = NativeStationSource.binding(for: station)
    else { return nil }
    var spin = Basis3()
    spin.rotate(
      pitch: 0, roll: (physicalTime * source.rotationRate).truncatingRemainder(dividingBy: 2 * .pi),
      yaw: 0)
    var result = Basis3()
    result.x = orientation.apply(spin.x)
    result.y = orientation.apply(spin.y)
    result.z = orientation.apply(spin.z)
    return result.validRotation ? result : nil
  }
}

/// Persistent source/pose wrapper; G3 owns the unchanged logical lifecycle and receipt ledger.
struct NativeStationWorld: Equatable, Codable, Sendable {
  let adapterRevision: String
  let geometryRevision: String
  let clockOrigin: Double
  var ledger: NativeStationLedger
  let poses: [NativeStationSavedPose]

  init(owner: UUID) throws {
    guard NativeStationSource.bindings.count == NativeStationLedger.recordLimit else {
      throw NativeStationRuntimeError.invalidSource
    }
    adapterRevision = NativeStationSource.adapterRevision
    geometryRevision = NativeStationGeometry.adapterRevision
    // Native simulation-calendar origin, not the original engine's absolute ship-clock epoch.
    clockOrigin = 0
    let records = NativeStationSource.bindings.map { binding in
      NativeStationRecord(
        identity: binding.identity(world: owner), descriptor: binding.descriptor,
        revision: 1, binding: nil, tombstone: nil)
    }
    ledger = try NativeStationLedger(world: owner, records: records)
    poses = try NativeStationSource.bindings.map { binding in
      guard let position = NativeStationSource.position(for: binding)
      else { throw NativeStationRuntimeError.unsafePlacement }
      let station = binding.identity(world: owner)
      return .init(
        station: station, position: position,
        orientation: NativeStationSource.initialOrientation(station))
    }
    guard valid else { throw NativeStationRuntimeError.invalidState }
  }

  var valid: Bool {
    guard adapterRevision == NativeStationSource.adapterRevision,
      geometryRevision == NativeStationGeometry.adapterRevision, clockOrigin == 0,
      ledger.valid, ledger.records.count == NativeStationLedger.recordLimit,
      poses.count == ledger.records.count, Set(poses.map(\.station)).count == poses.count,
      ledger.records.allSatisfy({ NativeStationSource.authentic($0, owner: ledger.world) }),
      poses.allSatisfy(\.valid), Set(poses.map(\.station)) == Set(ledger.records.map(\.identity))
    else { return false }
    return ledger.currentDock.map { $0.commanderOwner == ledger.world } ?? true
  }

  func pose(for station: NativeStationIdentity) -> NativeStationSavedPose? {
    poses.first { $0.station == station }
  }

  private enum CodingKeys: String, CodingKey {
    case adapterRevision, geometryRevision, clockOrigin, ledger, poses
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    adapterRevision = try values.decode(String.self, forKey: .adapterRevision)
    geometryRevision = try values.decode(String.self, forKey: .geometryRevision)
    clockOrigin = try values.decode(Double.self, forKey: .clockOrigin)
    ledger = try values.decode(NativeStationLedger.self, forKey: .ledger)
    var entries = try values.nestedUnkeyedContainer(forKey: .poses)
    guard entries.count.map({ $0 <= NativeStationLedger.recordLimit }) ?? true else {
      throw NativeStationRuntimeError.invalidState
    }
    var result: [NativeStationSavedPose] = []
    while !entries.isAtEnd {
      guard result.count < NativeStationLedger.recordLimit else {
        throw NativeStationRuntimeError.invalidState
      }
      result.append(try entries.decode(NativeStationSavedPose.self))
    }
    poses = result
    guard valid else { throw NativeStationRuntimeError.invalidState }
  }
}
