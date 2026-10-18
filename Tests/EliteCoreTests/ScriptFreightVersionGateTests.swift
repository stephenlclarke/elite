import Foundation
import Testing

@testable import EliteCore

/// The freight issue below is native. Provider/empty Alien additions explicitly test storage
/// composition only: they confer no provider readiness, crew care or Alien acquisition authority.
private enum FreightGateFixture {
  static func provider(in commander: inout Commander) throws -> (ScriptPack, UUID) {
    let pack = try ProviderContractFixture.pack()
    let terms = try #require(pack.manifest.providerContract)
    let owner = try #require(commander.equipmentOwnerID)
    let used = try #require(commander.checkedCargoTonnes)
    try #require(used < commander.standardCargoCapacity)
    let id = UUID()
    let subject = UUID()
    let provider = NativeProviderIdentity(
      definition: terms.provider, system: terms.origin, incarnation: UUID())
    func station(_ system: SystemIdentity) -> NativeMainStationIdentity {
      .init(
        world: owner, system: system,
        resource: Game.worldResourceIdentity(
          "main-station-v1:main-orbital:\(system.galaxy):\(system.system)"))
    }
    let state = ScriptProviderContractState(
      instance: id, terms: terms, owner: owner, provider: provider, subject: subject,
      expectedManifest: .init(identity: UUID(), revision: 1, provider: provider, subject: subject),
      origin: station(terms.origin), destination: station(terms.destination),
      item: ScriptProviderContractState.itemID(instance: id, payload: terms.payload),
      acceptedOrder: 1)
    var instance = ScriptInstance(
      id: id, definition: pack.manifest.stateID, version: pack.manifest.version,
      digest: pack.digest)
    instance.savedProviderContract = state
    instance.payloads[terms.payload] = 1
    try #require(state.valid(instance: instance))
    commander.scriptState.instances[id] = instance
    try #require(ScriptProviderVersionedSave.validateClaims(commander))
    return (pack, id)
  }

  static func emptyAlien(in commander: inout Commander) throws {
    let owner = try #require(commander.equipmentOwnerID)
    try commander.replaceAlienStorage(
      with: .init(
        owner: owner, revision: 0, worldRevision: 0,
        world: [], sources: [], attachments: [], upgrades: [], receipts: [], commands: []))
    try #require(commander.usesAlienStorageSaveVersion)
  }

  static func pointer(_ save: URL) throws -> ScriptSavePointer {
    try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: save))
  }

  static func retag(_ save: URL, schema: Int) throws {
    let old = try pointer(save)
    let changed = ScriptSavePointer(
      format: old.format, schemaVersion: schema, generation: old.generation,
      hashes: old.hashes, scope: old.scope, valueCodec: old.valueCodec)
    try JSONEncoder().encode(changed).write(to: save)
  }

  static func copy(_ save: URL, to destination: URL) throws {
    try FileManager.default.createDirectory(
      at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: save, to: destination)
    try FileManager.default.copyItem(
      at: save.appendingPathExtension("missions"),
      to: destination.appendingPathExtension("missions"))
  }

  /// Rehash the actual chunk so a negative tests its schema, rather than just its checksum.
  static func rewrite(
    _ save: URL, chunk: String, change: (inout [String: Any]) throws -> Void
  ) throws {
    let old = try pointer(save)
    let directory = try ScriptSaveStore.generationDirectory(old.generation, from: save)
    let file = directory.appendingPathComponent(chunk)
    let original = try Data(contentsOf: file)
    var object = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
    try change(&object)
    let bytes = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    try bytes.write(to: file)
    var hashes = old.hashes
    hashes[chunk] = ScriptPackLibrary.hash(bytes)
    let changed = ScriptSavePointer(
      format: old.format, schemaVersion: old.schemaVersion, generation: old.generation,
      hashes: hashes, scope: old.scope, valueCodec: old.valueCodec)
    try JSONEncoder().encode(changed).write(to: save)
  }

  static func instance(
    _ id: UUID, in missions: inout [String: Any], change: (inout [String: Any]) -> Void
  ) throws {
    if var dictionary = missions["instances"] as? [String: Any] {
      let key = try #require(dictionary.keys.first { UUID(uuidString: $0) == id })
      var value = try #require(dictionary[key] as? [String: Any])
      change(&value)
      dictionary[key] = value
      missions["instances"] = dictionary
    } else {
      var pairs = try #require(missions["instances"] as? [Any])
      let index = try #require(
        stride(from: 0, to: pairs.count, by: 2).first {
          (pairs[$0] as? String).flatMap(UUID.init(uuidString:)) == id
        })
      var value = try #require(pairs[index + 1] as? [String: Any])
      change(&value)
      pairs[index + 1] = value
      missions["instances"] = pairs
    }
  }
}

struct ScriptFreightVersionGateTests {
  @Test func nativeFreightComposesWithStorageOnlyProviderAndEmptyAlien() async throws {
    let fixture = try ScriptFreightFixture()
    defer { fixture.clean() }
    let (runtime, id, _) = try await fixture.accepted(row: 1)
    let game = await runtime.snapshot()
    let prepared = try GameRuntime.prepareNativeSaveState(game)
    let originalCargo = try #require(prepared.commander.scriptState.instances[id]?.savedOwnedCargo)
    for alien in [false, true] {
      for provider in [false, true] {
        var commander = prepared.commander
        var providerID: UUID?
        var packs = [fixture.pack]
        if provider {
          let addition = try FreightGateFixture.provider(in: &commander)
          packs.append(addition.0)
          providerID = addition.1
        }
        if alien { try FreightGateFixture.emptyAlien(in: &commander) }
        try #require(commander.valid && ScriptFreightVersionedSave.validateClaims(commander))
        let save = fixture.root.appendingPathComponent("matrix-\(alien)-\(provider)/commander.json")
        try ScriptSaveStore.write(
          commander: commander, world: prepared.game.scriptWorldSave, to: save)
        let pointer = try FreightGateFixture.pointer(save)
        #expect(pointer.schemaVersion == (alien ? 30 : 29))
        #expect(pointer.valueCodec == ScriptValueStorage.codec)
        let nativeNames: Set<String> = [
          "commander.json", "missions.json", "world.json", "contracts.json",
        ]
        #expect(
          Set(pointer.hashes.keys)
            == (alien
              ? nativeNames.union([AlienStorageVersionedSave.rootName]) : nativeNames))
        let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: save)
        let headerBytes = try Data(contentsOf: directory.appendingPathComponent("commander.json"))
        let header = try ScriptValueStorage.decoder(typed: true).decode(
          Commander.self, from: headerBytes)
        #expect(header.scriptState.instances.isEmpty && header.contracts.boards.isEmpty)
        let loaded = try ScriptSaveStore.read(Data(contentsOf: save), from: save)
        #expect(loaded.0.scriptState.instances[id]?.savedOwnedCargo == originalCargo)
        #expect(loaded.0.usesAlienStorageSaveVersion == alien)
        #expect(loaded.0.usesProviderContractSaveVersion == provider)
        #expect(loaded.1.consistent(with: loaded.0))
        if let providerID {
          #expect(
            loaded.0.scriptState.instances[providerID]
              == commander.scriptState.instances[providerID])
          let state = try #require(
            loaded.0.scriptState.instances[providerID]?.savedProviderContract)
          #expect(
            state.owner == commander.equipmentOwnerID && state.crew == nil && state.core == nil)
          #expect(state.manifest == nil && state.branch == nil && state.basePaid == 0)
        }
        var destination = Game(executive: false)
        destination.scriptPacks = packs
        let reader = GameRuntime(game: destination)
        try await reader.load(from: save, persistMigrations: false)
        let restored = await reader.snapshot()
        #expect(restored.commander.scriptState.instances[id]?.savedOwnedCargo == originalCargo)
        #expect(restored.commander.usesProviderContractSaveVersion == provider)
        #expect(restored.commander.usesAlienStorageSaveVersion == alien)
      }
    }
  }

  @Test func oldEnvelopesRejectPresenceAndNewEnvelopesRejectMalformedNativeFields() throws {
    let id = UUID().uuidString
    for value in [NSNull(), 1, [:] as [String: Any]] as [Any] {
      for pairs in [false, true] {
        let native: [String: Any] = ["savedOwnedCargo": value]
        let provider: [String: Any] = ["savedProviderContract": value]
        for instance in [native, provider] {
          let entries: Any = pairs ? [id, instance] as [Any] : [id: instance]
          let bytes = try JSONSerialization.data(withJSONObject: ["instances": entries])
          for schema in 2...30 {
            #expect(throws: (any Error).self) {
              try ScriptSaveJSONPreflight.validateFreightFields(
                bytes, part: .missions, schema: schema)
            }
          }
          let header = try JSONSerialization.data(
            withJSONObject: ["savedScriptState": ["instances": entries]])
          for schema in [nil, 21, 27, 28, 29, 30] as [Int?] {
            #expect(throws: (any Error).self) {
              try ScriptSaveJSONPreflight.validateFreightFields(
                header, part: .commander, schema: schema)
            }
          }
        }
      }
    }
    let authored: [String: Any] = [
      "instances": [
        id: [
          "data": ["savedProviderContract": NSNull(), "savedOwnedCargo": 1, "freightPlan": 2],
          "payloads": ["savedProviderContract": 1, "freightGeneration": 1],
        ]
      ]
    ]
    let bytes = try JSONSerialization.data(withJSONObject: authored)
    for schema in 2...30 {
      try ScriptSaveJSONPreflight.validateFreightFields(bytes, part: .missions, schema: schema)
    }
    for schema in [29, 30] {
      for key in ["savedOwnedCargo", "freightPlan", "freightGeneration"] {
        let wrongRoot = try JSONSerialization.data(withJSONObject: [key: NSNull()])
        #expect(throws: (any Error).self) {
          try ScriptSaveJSONPreflight.validateFreightFields(
            wrongRoot, part: .missions, schema: schema)
        }
        let board = try JSONSerialization.data(
          withJSONObject: ["boards": ["board": ["offers": [], key: NSNull()]]])
        #expect(throws: (any Error).self) {
          try ScriptSaveJSONPreflight.validateFreightFields(
            board, part: .contracts, schema: schema)
        }
      }
    }
  }

  @Test func nativeFreightCannotDowngradeOrReplaceTypedCommander() async throws {
    let fixture = try ScriptFreightFixture()
    defer { fixture.clean() }
    let (runtime, _, _) = try await fixture.accepted(row: 1)
    let game = await runtime.snapshot()
    try await runtime.save(to: fixture.save)
    for schema in 21...28 {
      let save = fixture.root.appendingPathComponent("downgrade-\(schema)/commander.json")
      try FreightGateFixture.copy(fixture.save, to: save)
      try FreightGateFixture.retag(save, schema: schema)
      #expect(throws: (any Error).self) {
        _ = try ScriptSaveStore.read(Data(contentsOf: save), from: save)
      }
    }
    var destination = Game(executive: false)
    let before = try ScriptValueStorage.encoder().encode(destination.commander)
    #expect(!destination.load(game.commander))
    #expect(try ScriptValueStorage.encoder().encode(destination.commander) == before)
    // Existing native flags may also refuse this genuine commander. No stripped bypass fixture
    // is substituted to make a claim about which guard caused the refusal.
    var ordinary = Commander()
    ordinary.name = "ORDINARY LOAD"
    #expect(destination.load(ordinary) && destination.commander.name == ordinary.name)
  }

  @Test func freightVersionRequiresActualFreightAndProviderOnlyRemainsUnsupported() async throws {
    let fixture = try ScriptFreightFixture()
    defer { fixture.clean() }
    let runtime = try await fixture.nativeRuntime()
    let game = await runtime.snapshot()
    let prepared = try GameRuntime.prepareNativeSaveState(game)
    for alien in [false, true] {
      var commander = prepared.commander
      if alien { try FreightGateFixture.emptyAlien(in: &commander) }
      let save = fixture.root.appendingPathComponent("ordinary-\(alien)/commander.json")
      try ScriptSaveStore.write(
        commander: commander, world: prepared.game.scriptWorldSave, to: save)
      let original = try FreightGateFixture.pointer(save)
      #expect(original.schemaVersion <= 27)
      _ = try ScriptSaveStore.read(Data(contentsOf: save), from: save)
      try FreightGateFixture.retag(save, schema: alien ? 30 : 29)
      #expect(throws: (any Error).self) {
        _ = try ScriptSaveStore.read(Data(contentsOf: save), from: save)
      }
      _ = try FreightGateFixture.provider(in: &commander)
      try #require(commander.valid && !commander.usesFreightNativeSaveVersion)
      let pointerBefore = try Data(contentsOf: save)
      #expect(throws: SaveError.self) {
        try ScriptSaveStore.write(
          commander: commander, world: prepared.game.scriptWorldSave, to: save)
      }
      #expect(try Data(contentsOf: save) == pointerBefore)
    }
  }

  @Test func rehashedMalformedChunksFailWithoutMutatingRuntimeOrDisk() async throws {
    let fixture = try ScriptFreightFixture()
    defer { fixture.clean() }
    let (runtime, id, _) = try await fixture.accepted(row: 1)
    let before = await runtime.snapshot()
    let prepared = try GameRuntime.prepareNativeSaveState(before)
    var commander = prepared.commander
    try FreightGateFixture.emptyAlien(in: &commander)
    let original = fixture.root.appendingPathComponent("corruption-source/commander.json")
    try ScriptSaveStore.write(
      commander: commander, world: prepared.game.scriptWorldSave, to: original)
    let worldBefore = try ScriptValueStorage.encoder().encode(before.scriptWorldSave)
    for fault in [
      "custody-null", "provider-null", "header", "world", "root-hash", "missing", "symlink",
      "extra-chunk",
    ] {
      let save = fixture.root.appendingPathComponent("corrupt-\(fault)/commander.json")
      try FreightGateFixture.copy(original, to: save)
      let pointer = try FreightGateFixture.pointer(save)
      let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: save)
      switch fault {
      case "custody-null", "provider-null":
        try FreightGateFixture.rewrite(save, chunk: "missions.json") { missions in
          try FreightGateFixture.instance(id, in: &missions) {
            $0[fault == "custody-null" ? "savedOwnedCargo" : "savedProviderContract"] = NSNull()
          }
        }
      case "header":
        try FreightGateFixture.rewrite(save, chunk: "commander.json") {
          $0["savedScriptState"] = ["instances": [id.uuidString: ["savedOwnedCargo": NSNull()]]]
        }
      case "world":
        try FreightGateFixture.rewrite(save, chunk: "world.json") { $0["energy"] = -1 }
      case "root-hash":
        try Data("{}".utf8).write(
          to: directory.appendingPathComponent(AlienStorageVersionedSave.rootName))
      case "missing", "symlink":
        let chunk = directory.appendingPathComponent("contracts.json")
        if fault == "symlink" {
          let target = fixture.root.appendingPathComponent("outside-contracts.json")
          try FileManager.default.copyItem(at: chunk, to: target)
          try FileManager.default.removeItem(at: chunk)
          try FileManager.default.createSymbolicLink(at: chunk, withDestinationURL: target)
        } else {
          try FileManager.default.removeItem(at: chunk)
        }
      default:
        var hashes = pointer.hashes
        hashes["extra.json"] = ScriptPackLibrary.hash(Data("{}".utf8))
        let changed = ScriptSavePointer(
          format: pointer.format, schemaVersion: pointer.schemaVersion,
          generation: pointer.generation, hashes: hashes, scope: pointer.scope,
          valueCodec: pointer.valueCodec)
        try JSONEncoder().encode(changed).write(to: save)
      }
      let filesBefore = try ScriptFinanceTestFixture.files(save.deletingLastPathComponent())
      await #expect(throws: (any Error).self) {
        try await runtime.load(from: save, persistMigrations: false)
      }
      let after = await runtime.snapshot()
      #expect(after.commander == before.commander)
      #expect(try ScriptValueStorage.encoder().encode(after.scriptWorldSave) == worldBefore)
      #expect(try ScriptFinanceTestFixture.files(save.deletingLastPathComponent()) == filesBefore)
    }
  }

  @Test func gameOverFreightRequiresRetainedLossOrTerminalEvidence() async throws {
    let fixture = try ScriptFreightFixture()
    defer { fixture.clean() }
    let (runtime, id, _) = try await fixture.accepted(row: 1)
    await runtime.key("0")
    let parent = fixture.save.deletingLastPathComponent()
    let preserved = fixture.root.appendingPathComponent("preserved")
    try FileManager.default.moveItem(at: parent, to: preserved)
    try Data([1]).write(to: parent)
    try await runtime.freightFatalHit()
    _ = await runtime.advance(delta: 0.1)
    let dead = await runtime.snapshot()
    let pending = try #require(
      dead.commander.scriptState.instances[id]?.savedOwnedCargo?.pendingLoss)
    try #require(dead.screen == .gameOver)
    let prepared = try GameRuntime.prepareNativeSaveState(dead)
    let save = fixture.root.appendingPathComponent("pending-loss/commander.json")
    try ScriptSaveStore.write(
      commander: prepared.commander, world: prepared.game.scriptWorldSave, to: save)
    let loaded = try ScriptSaveStore.read(Data(contentsOf: save), from: save)
    #expect(loaded.0.scriptState.instances[id]?.savedOwnedCargo?.pendingLoss == pending)
    #expect(loaded.0.scriptState.instances[id]?.savedOwnedCargo?.held == pending.units)
    var missing = prepared.commander
    missing.scriptState.instances[id]?.savedOwnedCargo?.pendingLoss = nil
    #expect(throws: SaveError.self) {
      try ScriptSaveStore.write(commander: missing, world: prepared.game.scriptWorldSave, to: save)
    }
    let reader = GameRuntime(game: dead)
    try await reader.load(from: save, persistMigrations: false)
    let restored = await reader.snapshot()
    let state = try #require(restored.commander.scriptState.instances[id])
    #expect(state.savedOwnedCargo?.terminal?.cause == .shipDestroyed)
    #expect(state.savedOwnedCargo?.terminal?.removed == pending.units)
    #expect(state.completionReceipt?.cause == pending.context)
    #expect(state.contract?.settlementAmount == 0)
  }
}
