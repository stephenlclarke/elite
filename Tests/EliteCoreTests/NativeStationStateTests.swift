import Foundation
import Testing

@testable import EliteCore

private struct StationStateFixture {
  let world = UUID()
  let owner = UUID()
  let system = SystemIdentity(galaxy: 0, system: 237)

  func record(
    key: String = "waystation", system: SystemIdentity? = nil,
    definition: String = "rescue_station",
    capabilities: [NativeStationCapability] = [.rrsContractBoard]
  )
    -> NativeStationRecord
  {
    .init(
      identity: .init(
        world: world, system: system ?? self.system, definition: definition, version: "1.5.4",
        key: key),
      descriptor: .init(
        definition: definition, version: "1.5.4",
        boardOrigin: definition == "rescue_station" ? .source : .projectExtension,
        capabilities: capabilities), revision: 1, binding: nil, tombstone: nil)
  }

  func binding(visit: UInt64 = 1, entity: UInt64 = 9, body: Int = 9) -> NativeStationBinding {
    .init(actor: .init(system: system, visit: visit, entity: entity), bodyID: body)
  }

  func docked() throws -> NativeStationLedger {
    let record = record()
    var ledger = try NativeStationLedger(world: world, records: [record])
    let binding = binding()
    try ledger.rebind(record.identity, to: binding)
    try ledger.recordDock(at: record.identity, binding: binding, commanderOwner: owner)
    return ledger
  }
}

@Test func nativeStationLoadPreservesCustodyAndOnlyLiveContextUsesEpoch() throws {
  let fixture = StationStateFixture()
  let ledger = try fixture.docked()
  let epoch = UUID()
  let context = try #require(
    ledger.serviceContext(
      capability: .rrsContractBoard, docked: true, system: fixture.system,
      commanderOwner: fixture.owner, runtimeEpoch: epoch))
  let bytes = try JSONEncoder().encode(ledger)
  let loaded = try JSONDecoder().decode(NativeStationLedger.self, from: bytes)
  #expect(loaded == ledger && loaded.currentDock?.sequence == 1 && loaded.nextDockSequence == 2)
  #expect(loaded.world == fixture.world)
  #expect(
    loaded.accepts(
      context, docked: true, system: fixture.system, commanderOwner: fixture.owner,
      runtimeEpoch: epoch))
  let newEpoch = UUID()
  #expect(
    !loaded.accepts(
      context, docked: true, system: fixture.system, commanderOwner: fixture.owner,
      runtimeEpoch: newEpoch))
  let fresh = try #require(
    loaded.serviceContext(
      capability: .rrsContractBoard, docked: true, system: fixture.system,
      commanderOwner: fixture.owner, runtimeEpoch: newEpoch))
  #expect(fresh.receipt == context.receipt && fresh.runtimeEpoch == newEpoch)
  #expect(loaded.currentDock == ledger.currentDock && loaded.nextDockSequence == 2)
  #expect(
    loaded.serviceContext(
      capability: .rrsContractBoard, docked: false, system: fixture.system,
      commanderOwner: fixture.owner, runtimeEpoch: newEpoch) == nil)
  #expect(
    loaded.serviceContext(
      capability: .rrsContractBoard, docked: true, system: fixture.system,
      commanderOwner: UUID(), runtimeEpoch: newEpoch) == nil)
  #expect(
    loaded.serviceContext(
      capability: .rrsContractBoard, docked: true, system: fixture.system,
      commanderOwner: nil, runtimeEpoch: newEpoch) == nil)
  #expect(
    loaded.serviceContext(
      capability: .rrsContractBoard, docked: true, system: .init(galaxy: 0, system: 1),
      commanderOwner: fixture.owner, runtimeEpoch: newEpoch) == nil)
}

@Test func nativeStationRebindingRetainsHistoricalDockAndDestructionCannotRevive() throws {
  let fixture = StationStateFixture()
  var ledger = try fixture.docked()
  let oldReceipt = try #require(ledger.currentDock)
  let newBinding = fixture.binding(visit: 2, entity: 12, body: 12)
  try ledger.rebind(oldReceipt.station, to: newBinding)
  #expect(ledger.valid && ledger.currentDock == oldReceipt && ledger.nextDockSequence == 2)
  let before = ledger
  #expect(throws: NativeStationStateError.self) {
    try ledger.destroy(oldReceipt.station, binding: oldReceipt.dockingBinding)
  }
  #expect(ledger == before)
  ledger.depart()
  try ledger.recordDock(at: oldReceipt.station, binding: newBinding, commanderOwner: fixture.owner)
  #expect(ledger.currentDock?.sequence == 2 && ledger.nextDockSequence == 3)
  try ledger.destroy(oldReceipt.station, binding: newBinding)
  #expect(ledger.valid && ledger.currentDock == nil && ledger.records[0].revision == 2)
  #expect(ledger.records[0].binding == nil)
  #expect(ledger.records[0].tombstone?.destroyedBinding == newBinding)
  let destroyed = ledger
  #expect(throws: NativeStationStateError.self) {
    try ledger.rebind(oldReceipt.station, to: fixture.binding(visit: 3))
  }
  #expect(throws: NativeStationStateError.self) {
    try ledger.recordDock(
      at: oldReceipt.station, binding: newBinding, commanderOwner: fixture.owner)
  }
  #expect(ledger == destroyed)
  #expect(
    try JSONDecoder().decode(NativeStationLedger.self, from: JSONEncoder().encode(ledger)) == ledger
  )
}

@Test func nativeStationRegistryRejectsDuplicateForeignAndUnboundedState() throws {
  let fixture = StationStateFixture()
  let record = fixture.record()
  #expect(throws: NativeStationStateError.self) {
    _ = try NativeStationLedger(world: fixture.world, records: [record, record])
  }
  #expect(throws: NativeStationStateError.self) {
    _ = try NativeStationLedger(world: UUID(), records: [record])
  }
  #expect(throws: NativeStationStateError.self) {
    _ = try NativeStationLedger(
      world: fixture.world, records: [record, fixture.record(key: "alias")])
  }
  let changedVersion = NativeStationIdentity(
    world: fixture.world, system: fixture.system, definition: "rescue_station",
    version: "1.5.5", key: "replacement")
  #expect(!changedVersion.valid && changedVersion.slot == record.identity.slot)
  let records = (0..<373).map {
    fixture.record(key: "station-\($0)", system: .init(galaxy: $0 / 256, system: $0 % 256))
  }
  #expect(throws: NativeStationStateError.self) {
    _ = try NativeStationLedger(world: fixture.world, records: records)
  }
  var ledger = try NativeStationLedger(
    world: fixture.world,
    records: [record, fixture.record(key: "hq", definition: "rrs_headquarters")])
  try ledger.rebind(record.identity, to: fixture.binding())
  let before = ledger
  let otherIdentity = ledger.records[1].identity
  #expect(throws: NativeStationStateError.self) {
    try ledger.rebind(otherIdentity, to: fixture.binding())
  }
  #expect(ledger == before)
  let foreign = NativeStationBinding(
    actor: .init(system: .init(galaxy: 1, system: 237), visit: 1, entity: 9), bodyID: 9)
  #expect(throws: NativeStationStateError.self) { try ledger.rebind(record.identity, to: foreign) }
  #expect(ledger == before)
}

@Test func nativeStationDecodeRefusesMissingNamespaceOverflowAndInconsistentDock() throws {
  let fixture = StationStateFixture()
  let ledger = try fixture.docked()
  let bytes = try JSONEncoder().encode(ledger)
  let original = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
  for field in ["world", "nextDockSequence", "records", "currentDock"] {
    var object = original
    if field == "world" { object.removeValue(forKey: field) }
    if field == "nextDockSequence" { object[field] = UInt64.max }
    if field == "records" { object[field] = [] }
    if field == "currentDock" {
      var receipt = try #require(object[field] as? [String: Any])
      receipt["lifecycleRevision"] = 2
      object[field] = receipt
    }
    let invalid = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: (any Error).self) {
      _ = try JSONDecoder().decode(NativeStationLedger.self, from: invalid)
    }
  }
}

@Test func nativeStationEmptyCapabilitiesGrantNoService() throws {
  let fixture = StationStateFixture()
  let record = fixture.record(capabilities: [])
  var ledger = try NativeStationLedger(world: fixture.world, records: [record])
  try ledger.rebind(record.identity, to: fixture.binding())
  try ledger.recordDock(
    at: record.identity, binding: fixture.binding(), commanderOwner: fixture.owner)
  #expect(ledger.valid && ledger.currentDock != nil)
  #expect(
    ledger.serviceContext(
      capability: .rrsContractBoard, docked: true, system: fixture.system,
      commanderOwner: fixture.owner, runtimeEpoch: UUID()) == nil)
}

@Test func nativeStationStructuralMetadataAndRevisionLimitsAreChecked() throws {
  let fixture = StationStateFixture()
  let record = fixture.record()
  let maximum = (0..<372).map {
    fixture.record(key: "station-\($0)", system: .init(galaxy: $0 / 256, system: $0 % 256))
  }
  #expect(try NativeStationLedger(world: fixture.world, records: maximum).valid)
  var invalid = record
  invalid.revision = 0
  #expect(!invalid.valid)
  invalid.revision = UInt64.max
  #expect(!invalid.valid)
  invalid = record
  invalid.tombstone = .init(revision: 2, destroyedBinding: fixture.binding())
  #expect(!invalid.valid)
  let duplicateCapabilities = fixture.record(capabilities: [.rrsContractBoard, .rrsContractBoard])
  #expect(!duplicateCapabilities.valid)
  let hq = NativeStationIdentity(
    world: fixture.world, system: fixture.system, definition: "rrs_headquarters",
    version: "1.5.4", key: "hq")
  let hqDescriptor = NativeStationDescriptor(
    definition: "rrs_headquarters", version: "1.5.4", boardOrigin: .projectExtension,
    capabilities: [.rrsContractBoard])
  #expect(hqDescriptor.matches(hq))
  #expect(hqDescriptor.sourceRoles == ["rrs_galactic_hq", "rrs_group_spacestation"])
  #expect(!record.descriptor.matches(hq))
  var ledger = try NativeStationLedger(world: fixture.world, records: [record])
  try ledger.rebind(record.identity, to: fixture.binding())
  let before = ledger
  #expect(throws: NativeStationStateError.self) {
    try ledger.recordDock(at: record.identity, binding: fixture.binding(), commanderOwner: nil)
  }
  #expect(ledger == before && ledger.nextDockSequence == 1 && ledger.currentDock == nil)
}

@Test func nativeStationReservedActorsAndHistoricalDockAliasesRefuse() throws {
  let fixture = StationStateFixture()
  let way = fixture.record()
  let hq = fixture.record(key: "hq", definition: "rrs_headquarters")
  var ledger = try NativeStationLedger(world: fixture.world, records: [way, hq])
  for entity in [UInt64(0), UInt64(1)] {
    let before = ledger
    #expect(throws: NativeStationStateError.self) {
      try ledger.rebind(way.identity, to: fixture.binding(entity: entity))
    }
    #expect(ledger == before)
  }
  let old = fixture.binding()
  try ledger.rebind(way.identity, to: old)
  try ledger.recordDock(at: way.identity, binding: old, commanderOwner: fixture.owner)
  let receipt = ledger.currentDock
  try ledger.rebind(way.identity, to: fixture.binding(visit: 2, entity: 12, body: 12))
  let before = ledger
  for alias in [
    old, fixture.binding(entity: 20, body: old.bodyID),
    fixture.binding(entity: old.actor.entity, body: 20),
  ] {
    #expect(throws: NativeStationStateError.self) { try ledger.rebind(hq.identity, to: alias) }
    #expect(ledger == before && ledger.currentDock == receipt)
  }
  try ledger.rebind(hq.identity, to: fixture.binding(visit: 2, entity: 13, body: 13))
  #expect(ledger.valid && ledger.currentDock == receipt && ledger.nextDockSequence == 2)
}

@Test func nativeStationDecoderRejectsOversizedRecordArrayBeforeDecodingElements() throws {
  let fixture = StationStateFixture()
  let ledger = try NativeStationLedger(world: fixture.world, records: [])
  var object = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger)) as? [String: Any])
  // Invalid elements would produce a type mismatch if decoded before budget admission.
  object["records"] = Array(repeating: "not a station record", count: 373)
  let bytes = try JSONSerialization.data(withJSONObject: object)
  do {
    _ = try JSONDecoder().decode(NativeStationLedger.self, from: bytes)
    Issue.record("Oversized station registry must refuse before element decoding")
  } catch DecodingError.dataCorrupted(let context) {
    #expect(context.debugDescription == "Native station record limit exceeded.")
  }
}

@Test func nativeStationCurrentDockRequiresLatestSequenceButDepartureKeepsHistoryCounter() throws {
  let fixture = StationStateFixture()
  var ledger = try fixture.docked()
  var object = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger)) as? [String: Any])
  object["nextDockSequence"] = ledger.nextDockSequence + 1
  let invalid = try JSONSerialization.data(withJSONObject: object)
  #expect(throws: (any Error).self) {
    _ = try JSONDecoder().decode(NativeStationLedger.self, from: invalid)
  }
  ledger.depart()
  #expect(ledger.valid && ledger.currentDock == nil && ledger.nextDockSequence == 2)
  #expect(
    try JSONDecoder().decode(NativeStationLedger.self, from: JSONEncoder().encode(ledger)) == ledger
  )
}
