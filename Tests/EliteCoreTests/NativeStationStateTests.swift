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

  func budgetRecords(count: Int) throws -> [NativeStationRecord] {
    let limit = try stationRecordBudget()
    try #require((0...limit + 1).contains(count))
    // Two structural source-class slots per ordinary system keep limit+1 records valid and unique.
    let records = (0..<count).map { index in
      record(
        key: "station-\(index)",
        system: .init(galaxy: (index / 2) / 256, system: (index / 2) % 256),
        definition: index.isMultiple(of: 2) ? "rescue_station" : "rrs_headquarters")
    }
    try #require(records.allSatisfy(\.valid))
    try #require(Set(records.map(\.identity.slot)).count == count)
    return records
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

private func stationRecordBudget() throws -> Int {
  let limit = NativeStationLedger.recordLimit
  try #require(limit > 0 && limit <= NativeStationLedger.maximumSourceRecords)
  // The real source ceiling leaves room for one excess record in the two-class structural domain.
  try #require(NativeStationLedger.maximumSourceRecords == 8 * (256 + 1))
  return limit
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
  let limit = try stationRecordBudget()
  let records = try fixture.budgetRecords(count: limit + 1)
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
  let maximum = try fixture.budgetRecords(count: stationRecordBudget())
  let admitted = try NativeStationLedger(world: fixture.world, records: maximum)
  #expect(admitted.valid)
  #expect(
    try JSONDecoder().decode(NativeStationLedger.self, from: JSONEncoder().encode(admitted))
      == admitted)
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
  let limit = try stationRecordBudget()
  // At the admitted count these malformed elements reach element decoding.
  object["records"] = Array(repeating: "not a station record", count: limit)
  let control = try JSONSerialization.data(withJSONObject: object)
  do {
    _ = try JSONDecoder().decode(NativeStationLedger.self, from: control)
    Issue.record("Malformed admitted-size records must reach element decoding")
  } catch DecodingError.typeMismatch(_, let context) {
    #expect(context.codingPath.first?.stringValue == "records")
    #expect(context.codingPath.last?.intValue == 0)
  }
  // One record over budget must refuse before decoding those same malformed elements.
  object["records"] = Array(repeating: "not a station record", count: limit + 1)
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

@Test func nativeStationBodyBindingUniquenessIncludesSystemAndVisit() throws {
  let fixture = StationStateFixture()
  let way = fixture.record()
  let hq = fixture.record(key: "hq", definition: "rrs_headquarters")
  let foreignSystem = SystemIdentity(galaxy: 1, system: fixture.system.system)
  let foreign = fixture.record(key: "foreign", system: foreignSystem)
  var ledger = try NativeStationLedger(world: fixture.world, records: [way, hq, foreign])
  try ledger.rebind(way.identity, to: fixture.binding(entity: 9, body: 9))
  let before = ledger
  #expect(throws: NativeStationStateError.self) {
    try ledger.rebind(hq.identity, to: fixture.binding(entity: 10, body: 9))
  }
  #expect(ledger == before)
  try ledger.rebind(hq.identity, to: fixture.binding(visit: 2, entity: 10, body: 9))
  #expect(ledger.valid && ledger.records[0].binding?.bodyID == ledger.records[1].binding?.bodyID)
  let other = NativeStationBinding(
    actor: .init(system: foreignSystem, visit: 1, entity: 9), bodyID: 9)
  try ledger.rebind(foreign.identity, to: other)
  #expect(ledger.valid && ledger.records[2].binding == other)
  #expect(ledger.records.allSatisfy { $0.binding?.bodyID == 9 })
}
