import Foundation
import Testing

@testable import EliteCore

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
    game.commander.nativeStations?.currentMainDock = .init(
      station: original, actor: mainActor, commanderOwner: owner,
      sequence: 1, calendarSeconds: game.commander.scriptState.calendarSeconds)
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
  #expect(try rawAuthorityFiles(storage.directory) == beforeFiles)
}

private func verifyLegacyWithoutStations(
  _ game: inout Game, explicitNull: Bool, storage: NativeStationTestStorage
) async throws {
  try game.commander.prepareEquipment()
  let commander = game.commander
  var object = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(commander)) as? [String: Any])
  if explicitNull {
    object["nativeStations"] = NSNull()
    object["savedContracts"] = ["boards": [:], "rrs": NSNull()] as [String: Any]
  }
  let raw = storage.root.appendingPathComponent("legacy.json")
  let bytes = try JSONSerialization.data(withJSONObject: object)
  try bytes.write(to: raw)
  let runtime = GameRuntime(game: game)
  try await runtime.load(from: raw, persistMigrations: false)
  game = await runtime.snapshot()
  #expect(game.commander.nativeStations == nil && game.commander.contracts.rrs == nil)
  #expect(game.docked && game.dockedAtMainStation)
  #expect(game.commander.credits == commander.credits && game.commander.cargo == commander.cargo)
  #expect(game.commander.equipmentInventory == commander.equipmentInventory)
  #expect(game.nativeStationBoardContext == nil)
  #expect(!game.nativeStationDockEvidenceIsCurrent && !game.nativeMainStationDockEvidenceIsCurrent)
  #expect(try Data(contentsOf: raw) == bytes)
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
