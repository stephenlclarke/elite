import Foundation
import Testing

@testable import L337Core

struct RawNativeSaveAuthorityTests {
  @Test(arguments: [false, true])
  func rawPureLedgerDockCannotRestoreNativeAuthority(main: Bool) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativeStationTestFixture.launched()
    try await verifyRawDockRefusal(&game, main: main, storage: storage)
  }

  @Test(arguments: [false, true])
  func genuineVersionedDockStillRestoresNativeAuthority(main: Bool) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativeStationTestFixture.approach(kind: .waystation)
    try await verifyVersionedDockRestore(&game, main: main, storage: storage)
  }

  @Test(arguments: [false, true])
  func ordinaryLegacySaveWithoutStationStateStillLoads(explicitNull: Bool) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = Game(executive: false)
    try await verifyLegacyWithoutStations(&game, explicitNull: explicitNull, storage: storage)
  }

  @Test func rawRRSCustodyWithoutStationWorldIsRejectedBeforeCommanderDecode() throws {
    // Unknown typed state must not be silently discarded or treated as legacy data.
    let data = Data(#"{"savedContracts":{"boards":{},"rrs":{"jobs":[]}}}"#.utf8)
    #expect(throws: SaveError.invalidCommander) {
      try ScriptSaveJSONPreflight.rejectCourierFields(data, location: .rawCommander)
    }
    #expect(throws: SaveError.invalidCommander) {
      try ScriptSaveJSONPreflight.rejectCourierFields(data, location: .currentCommanderHeader)
    }
  }
}

private func verifyRawDockRefusal(
  _ game: inout Game, main: Bool, storage: NativeStationTestStorage
) async throws {
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  try await runtime.save(to: storage.url)
  game = await runtime.snapshot()
  let beforeCommander = game.commander
  let beforeWorld = try rawAuthorityWorldBytes(game)
  let beforeFiles = try rawAuthorityFiles(storage.directory)
  let station = try #require(game.bodies.first { $0.nativeStationIdentity != nil })
  let identity = try #require(station.nativeStationIdentity)
  let actor = try #require(station.physical?.identity)
  let mainActor = try #require(game.commander.flightSimulation.anchors?.station.identity)
  let owner = try #require(game.commander.equipmentOwnerID)
  let original = try #require(game.commander.nativeStations?.mainStations.first)
  game.dock(atMainStation: main)
  if main {
    let calendarSeconds = game.commander.scriptState.calendarSeconds
    game.commander.nativeStations?.currentMainDock = .init(
      station: original, actor: mainActor, commanderOwner: owner,
      sequence: 1, calendarSeconds: calendarSeconds)
    game.commander.nativeStations?.nextMainDockSequence = 2
  } else {
    try game.commander.nativeStations?.ledger.recordDock(
      at: identity, binding: .init(actor: actor, bodyID: station.id), commanderOwner: owner)
  }
  #expect(game.commander.valid)
  #expect(!game.nativeStationDockEvidenceIsCurrent && !game.nativeMainStationDockEvidenceIsCurrent)
  let raw = storage.root.appendingPathComponent("raw-dock.json")
  let bytes = try JSONEncoder().encode(game.commander)
  try bytes.write(to: raw)
  // This is structurally valid Commander data, rather than a malformed-decoder rejection.
  #expect(try JSONDecoder().decode(Commander.self, from: bytes) == game.commander)
  await #expect(throws: SaveError.invalidCommander) {
    try await runtime.load(from: raw, persistMigrations: false)
  }
  game = await runtime.snapshot()
  let wholeCommanderPreserved = game.commander == beforeCommander
  #expect(wholeCommanderPreserved)
  #expect(try rawAuthorityWorldBytes(game) == beforeWorld)
  #expect(try rawAuthorityFiles(storage.directory) == beforeFiles)
  #expect(try Data(contentsOf: raw) == bytes)
  #expect(game.nativeStationBoardContext == nil)
  #expect(game.nativeMainStationArrivalContext(for: original) == nil)
}

private func verifyVersionedDockRestore(
  _ game: inout Game, main: Bool, storage: NativeStationTestStorage
) async throws {
  if main {
    let station = try #require(game.bodies.first { $0.id == 0 })
    let old = game.commander.flightSimulation.pose
    var pose = ShipPose()
    pose.position = old.systemPoint(station.entrancePosition + station.entranceNormal * 2)
    pose.orientation.y = old.orientation.apply(station.entranceUp)
    pose.orientation.z = old.orientation.apply(station.entranceNormal) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 3
  }
  let runtime = GameRuntime(game: game, saveURL: storage.url)
  for _ in 0..<100 where !game.docked { game = await runtime.advance(delta: 0.1) }
  #expect(game.docked && game.dockedAtMainStation == main)
  #expect(
    main ? game.nativeMainStationDockEvidenceIsCurrent : game.nativeStationDockEvidenceIsCurrent)
  try await runtime.save(to: storage.url)
  game = await runtime.snapshot()
  let beforeCommander = game.commander
  let beforeFiles = try rawAuthorityFiles(storage.directory)
  let pointer = try JSONDecoder().decode(
    ScriptSavePointer.self, from: Data(contentsOf: storage.url))
  #expect(pointer.schemaVersion == 26)
  let currentBytes = try Data(contentsOf: storage.url)
  let (strictSaved, strictWorld) = try ScriptSaveStore.read(currentBytes, from: storage.url)
  #expect(strictSaved.valid && strictWorld.consistent(with: strictSaved))
  let downgraded = ScriptSavePointer(
    format: pointer.format, schemaVersion: 20, generation: pointer.generation,
    hashes: pointer.hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
  #expect(throws: SaveError.invalidCommander) {
    _ = try ScriptSaveStore.read(JSONEncoder().encode(downgraded), from: storage.url)
  }
  let oldEpoch = game.nativeStationRuntimeEpoch
  let reloaded = GameRuntime(game: Game(executive: false))
  try await reloaded.load(from: storage.url, persistMigrations: false)
  game = await reloaded.snapshot()
  let wholeCommanderPreserved = game.commander == beforeCommander
  #expect(wholeCommanderPreserved && game.docked && game.dockedAtMainStation == main)
  #expect(game.nativeStationRuntimeEpoch != oldEpoch)
  if main {
    let receipt = try #require(game.commander.nativeStations?.currentMainDock)
    #expect(game.nativeMainStationArrivalContext(for: receipt.station) != nil)
  } else {
    #expect(game.nativeStationBoardContext != nil)
  }
  let afterFiles = try rawAuthorityFiles(storage.directory)
  #expect(afterFiles == beforeFiles)
}

private func verifyLegacyWithoutStations(
  _ game: inout Game, explicitNull: Bool, storage: NativeStationTestStorage
) async throws {
  let commander = game.commander
  let seedBytes = try legacyStationRawSeedBytes(commander)
  let seedObject = try JSONSerialization.jsonObject(with: seedBytes)
  var object = try #require(seedObject as? [String: Any])
  if explicitNull {
    object["nativeStations"] = NSNull()
    object["savedContracts"] = ["boards": [:], "rrs": NSNull()] as [String: Any]
  }
  let raw = storage.root.appendingPathComponent("legacy.json")
  let bytes = try JSONSerialization.data(withJSONObject: object)
  // Preserve the independently constructed raw input's explicit-null contract representation.
  let rawCommander = try JSONDecoder().decode(Commander.self, from: bytes)
  #expect(rawCommander.contracts == commander.contracts)
  if explicitNull {
    #expect(object["nativeStations"] is NSNull)
    let contracts = try #require(object["savedContracts"] as? [String: Any])
    #expect(contracts["rrs"] is NSNull)
  } else {
    #expect(object["nativeStations"] == nil && object["savedContracts"] == nil)
  }
  try bytes.write(to: raw)
  let beforeFiles = try legacyStationSourceFiles(storage.root)
  let runtime = GameRuntime(game: game)
  try await runtime.load(from: raw, persistMigrations: false)
  game = await runtime.snapshot()
  #expect(game.commander.nativeStations == nil && game.commander.contracts.rrs == nil)
  #expect(game.docked && game.dockedAtMainStation)
  #expect(game.commander.credits == commander.credits && game.commander.cargo == commander.cargo)
  try expectLegacyStationStockMigration(from: rawCommander, to: game.commander)
  #expect(game.nativeStationBoardContext == nil)
  #expect(!game.nativeStationDockEvidenceIsCurrent && !game.nativeMainStationDockEvidenceIsCurrent)
  let afterBytes = try Data(contentsOf: raw)
  let afterFiles = try legacyStationSourceFiles(storage.root)
  #expect(afterBytes == bytes && afterFiles == beforeFiles)
}

private func rawAuthorityWorldBytes(_ game: borrowing Game) throws -> Data {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys]
  return try encoder.encode(game.scriptWorldSave)
}

private func rawAuthorityFiles(_ root: URL) throws -> [String: Data] {
  var result: [String: Data] = [:]
  guard let entries = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
  else { throw NativeStationRuntimeError.invalidState }
  for case let url as URL in entries {
    guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
      continue
    }
    let key = String(url.path.dropFirst(root.path.count))
    result[key] = try Data(contentsOf: url)
  }
  return result
}

// Shared only by the two genuine raw legacy station-absence cases; never prepares or strips a seed.
func legacyStationRawSeedBytes(_ legacy: Commander) throws -> Data {
  try #require(legacy.valid && legacy.equipmentInventory == nil)
  try #require(legacy.equipmentPurchaseHistory == nil && legacy.savedEquipmentVersion == nil)
  try #require(legacy.equipment == Set(["Pulse Laser"]))
  try #require(legacy.laserMounts == LaserMounts(front: .pulse) && legacy.fuelStorageUnits == 0)
  try #require(legacy.nativeStations == nil && legacy.scriptState == ScriptEngineState())
  let bytes = try JSONEncoder().encode(legacy)
  let value = try JSONSerialization.jsonObject(with: bytes)
  let fields = try #require(value as? [String: Any])
  let modern: Set<String> = [
    "savedEquipmentInventory", "savedEquipmentPurchaseHistory", "savedEquipmentVersion",
    "legacyOwnedEquipment", "savedMiningLedger", "savedPlayerElectrical", "savedEMPCharge",
    "savedEMPState", "savedAlienStorageReference", "alienStorageState", "alienStorageCache",
    "savedAlienStorageState", "format", "schemaVersion",
  ]
  try #require(modern.isDisjoint(with: Set(fields.keys)))
  return bytes
}

func expectLegacyStationStockMigration(from legacy: Commander, to migrated: Commander) throws {
  try #require(legacy.equipmentInventory == nil && legacy.savedEquipmentVersion == nil)
  let inventory = try #require(migrated.equipmentInventory)
  try #require(inventory.owner != inventory.activeHull)
  // Only allocated IDs are observed; nodes, slots, origins, statistics and provenance are independent.
  let foundations: [(ComponentFittingSlot, String, ComponentTemplate?)] = [
    (.shield, "Basic Shield", EquipmentModuleTemplates.shield.grades[0]),
    (
      .navigation, NavigationTier.basic.equipmentName, EquipmentModuleTemplates.navigation.grades[0]
    ),
    (.energy, "Basic Energy System", EquipmentModuleTemplates.energy.grades[0]),
    (.drive, HyperspaceDriveTier.basic.label, HyperspaceDriveDefinition.template(for: .basic)),
    (.laser(.front), LaserKind.pulse.equipmentName, nil),
  ]
  var items: [OwnedEquipmentItem] = []
  for (slot, key, template) in foundations {
    let node = try #require(EquipmentRuntimeCatalog.node(for: key))
    let location = ComponentFittingLocation(hullInstanceID: inventory.activeHull, slot: slot)
    let allocated = try #require(inventory.items.first { $0.location == location })
    let component = template.map {
      ComponentInstance(id: allocated.id, origin: $0, statistics: $0.statistics, grade: $0.identity)
    }
    items.append(
      .init(
        id: allocated.id, node: node, provenance: .standard, component: component,
        location: location))
  }
  var entitlements: [EquipmentLegacyEntitlement] = []
  for pylon in 0..<legacy.missiles {
    let location = ComponentFittingLocation(
      hullInstanceID: inventory.activeHull, slot: .missilePylon(pylon))
    let allocated = try #require(inventory.items.first { $0.location == location })
    let item = OwnedEquipmentItem(
      id: allocated.id, node: EquipmentRuntimeCatalog.standardMissile, provenance: .legacyUnknown,
      location: location)
    items.append(item)
    let entitlement = try EquipmentPurchaseProgression.legacyEntitlement(
      for: .init(
        id: item.id, node: EquipmentRuntimeCatalog.standardMissile, provenance: .legacyUnknown),
      owner: inventory.owner, graph: EquipmentRuntimeCatalog.graph)
    entitlements.append(entitlement)
  }
  let ids = Set(items.map(\.id))
  try #require(ids.count == legacy.missiles + 5)
  try #require(!ids.contains(inventory.owner) && !ids.contains(inventory.activeHull))
  let expectedInventory = try OwnedEquipmentInventory(
    owner: inventory.owner, activeHull: inventory.activeHull, revision: 0, items: items)
  let expectedHistory = EquipmentPurchaseHistory(
    owner: inventory.owner, revision: 0, paid: [], legacy: entitlements)
  try #require(inventory == expectedInventory)
  try #require(migrated.equipmentPurchaseHistory == expectedHistory)
  try #require(inventory.items.filter(\.isReservedStockDrive).count == 1)
  try #require(inventory.ordinaryItemCount == legacy.missiles + 4)
  let drive = try #require(inventory.items.first { $0.isReservedStockDrive })
  try #require(drive.node == HyperspaceDriveDefinition.node(for: .basic))
  try #require(drive.component?.origin == HyperspaceDriveDefinition.template(for: .basic))
  try #require(migrated.valid && migrated.savedEquipmentVersion == 3)
  try #require(migrated.missiles == legacy.missiles)
  var mining = MiningLedger.legacyUnworked()
  let system = try #require(
    Universe.systemsIncludingPlugh(number: legacy.galaxy).first { $0.id == legacy.system })
  try mining.migratePresence(current: .init(system: system, galaxy: legacy.galaxy), historical: [])
  var expected = legacy
  expected.savedEquipmentInventory = expectedInventory
  expected.savedEquipmentPurchaseHistory = expectedHistory
  expected.savedEquipmentVersion = 3
  expected.equipment.insert(HyperspaceDriveTier.basic.label)
  expected.laserMounts = LaserMounts(front: .pulse)
  expected.fuelStorageUnits = 0
  expected.miningLedger = mining
  // Complete scalar/state equality permits only these independently reconstructed migration fields.
  try #require(migrated == expected)
}

func legacyStationSourceFiles(_ root: URL) throws -> [String: Data] {
  let entries = try #require(
    FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]))
  var files: [String: Data] = [:]
  for case let url as URL in entries {
    let values = try url.resourceValues(forKeys: [.isRegularFileKey])
    guard values.isRegularFile == true else { continue }
    let relative = String(url.path.dropFirst(root.path.count))
    files[relative] = try Data(contentsOf: url)
  }
  return files
}
