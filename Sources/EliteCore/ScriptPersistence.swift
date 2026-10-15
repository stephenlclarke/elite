import Foundation

struct ScriptWorldSave: Codable, Sendable {
  var simulation: ScriptSimulationSave?
  var referenceFrame: ScriptReferenceFrame?
  var contractScreen: ContractScreenSave?
  var bodies: [SpaceBody]
  var market: [MarketItem]
  var docked: Bool
  var mainStation: Bool
  var screen: Screen
  var speed: Double
  var time: Double
  var energy: Double
  var frontShield: Double
  var rearShield: Double
  var laserHeat: Double
  var jumpCountdown: Double?
  var selectedSystem: Int
  var nextBodyID: Int
  var valid: Bool {
    (simulation?.valid ?? true) && (referenceFrame?.valid ?? true)
      && (contractScreen?.valid ?? true) && bodies.count <= 1024
      && bodies.reduce(0, { $0 + $1.scriptNativeUnits }) <= 1024
      && Set(bodies.map(\.id)).count == bodies.count
      && Set(bodies.compactMap(\.missionActorID)).count
        == bodies.filter { $0.missionActorID != nil }.count
      && bodies.allSatisfy { body in
        body.id >= 0 && (body.scriptNPC?.valid ?? true)
          && (body.scriptNPC == nil || body.missionActorID != nil)
          && (body.scriptShot?.valid ?? true)
          && (body.scriptShot == nil
            || body.hull == .missile && body.scriptNPC == nil
              && body.missionActorID == nil && body.missionInstanceID == nil)
          && [
            body.position.x, body.position.y, body.position.z, body.energy, body.rotation,
            body.rotationRate,
          ].allSatisfy { $0.isFinite && abs($0) <= 1e12 }
      }
      && market.count == 17
      && market.allSatisfy {
        (0...1_000_000).contains($0.price) && (0...1_000_000).contains($0.quantity)
      }
      && [speed, time, energy, frontShield, rearShield, laserHeat].allSatisfy {
        $0.isFinite && (0...1e12).contains($0)
      }
      && (jumpCountdown.map { $0.isFinite && (0...1e12).contains($0) } ?? true)
      && (0...256).contains(selectedSystem) && (0..<1_000_000_000).contains(nextBodyID)
      && nextBodyID >= (bodies.map(\.id).max() ?? 0)
  }
  func consistent(with commander: Commander) -> Bool {
    let stationKey = "main-orbital:\(commander.galaxy):\(commander.system)"
    if let resource = commander.scriptState.stationResources[stationKey] {
      let actual = bodies.first { $0.id == 0 && $0.hull == .station }
      if resource.destroyed {
        guard actual == nil, !(docked && mainStation),
          referenceFrame.map({ $0.station.energy <= 0 }) ?? true
        else { return false }
      } else if let actual, actual.energy != resource.energy {
        return false
      }
    }
    var records: [UUID: (UUID, Int, Int, ScriptOwnedActor)] = [:]
    for instance in commander.scriptState.instances.values {
      for encounter in instance.ownedEncounters.values {
        for actor in encounter.actors.values {
          guard records[actor.identity] == nil else { return false }
          records[actor.identity] = (instance.id, encounter.galaxy, encounter.system, actor)
        }
      }
    }
    let shotBodies = bodies.filter { $0.scriptShot != nil }
    let expectedShots = commander.scriptState.projectiles.values.filter { $0.presence == .present }
    guard shotBodies.count == expectedShots.count,
      expectedShots.allSatisfy({ $0.galaxy == commander.galaxy && $0.system == commander.system })
    else { return false }
    for body in shotBodies {
      guard let shot = body.scriptShot,
        let record = commander.scriptState.projectiles[shot.identity],
        record.presence == .present, record.body.id == body.id, let anchor = referenceFrame?.station
      else { return false }
      var canonical = shot
      canonical.velocity = anchor.orientation.inverse(shot.velocity)
      guard canonical == record.body.scriptShot else { return false }
    }
    if let ledger = commander.scriptState.calendarLedger {
      if let journey = ledger.pendingJourney {
        guard !docked, jumpCountdown != nil, journey.galaxy == commander.galaxy,
          journey.origin == commander.system
        else { return false }
      } else if jumpCountdown != nil && !ledger.legacyUntrackedJourney {
        return false
      }
      if ledger.legacyUntrackedJourney && (docked || jumpCountdown == nil) { return false }
    }
    let physical = bodies.filter { $0.missionActorID != nil }
    let expected = records.values.filter { $0.3.presence == .present }
    guard physical.count == expected.count,
      expected.allSatisfy({ $0.1 == commander.galaxy && $0.2 == commander.system })
    else { return false }
    for body in physical {
      var canonicalNPC = body.scriptNPC
      if let velocity = canonicalNPC?.velocity, let anchor = referenceFrame?.station {
        canonicalNPC?.velocity = anchor.orientation.inverse(velocity)
      }
      guard let identity = body.missionActorID, let record = records[identity],
        body.missionInstanceID == record.0, record.3.presence == .present,
        body.id == record.3.body.id, body.hull == record.3.body.hull,
        canonicalNPC == record.3.body.scriptNPC,
        body.energy == record.3.body.energy, body.missiles == record.3.body.missiles,
        body.ecmEnabled == record.3.body.ecmEnabled, body.hostile == record.3.body.hostile
      else { return false }
    }
    return true
  }
}
struct ScriptSavePointer: Codable {
  let format: String
  let schemaVersion: Int
  let generation: String
  let hashes: [String: String]
  var scope: String? = nil
  var valueCodec: String? = nil
}

/// Publication is synchronous inside GameRuntime: no actor reentrancy can overwrite newer simulation state.
enum ScriptSaveStore {
  static func write(
    commander: Commander, world: ScriptWorldSave, to url: URL, scope: String = "commander"
  ) throws {
    guard ["commander", "gallery"].contains(scope), commander.scriptState.calendarLedger != nil,
      commander.valid, world.valid,
      world.consistent(with: commander)
    else {
      throw SaveError.invalidCommander
    }
    let semantic = JSONEncoder()
    guard try semantic.encode(commander.scriptState).count <= 33_554_432,
      try semantic.encode(commander.contracts).count <= 33_554_432
    else { throw SaveError.invalidCommander }
    let encoder = ScriptValueStorage.encoder()
    var header = commander
    header.scriptState = ScriptEngineState()
    header.contracts = ScriptContractState()
    let chunks = [
      "commander.json": try encoder.encode(header),
      "missions.json": try encoder.encode(commander.scriptState),
      "world.json": try encoder.encode(world),
      "contracts.json": try encoder.encode(commander.contracts),
    ]
    guard chunks["commander.json"]!.count <= 4_194_304,
      chunks["missions.json"]!.count <= 134_217_728,
      chunks["world.json"]!.count <= 8_388_608
        && chunks["contracts.json"]!.count <= 134_217_728
    else { throw SaveError.invalidCommander }
    let generation = UUID().uuidString
    let root = url.appendingPathExtension("missions")
    let directory = root.appendingPathComponent(generation, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    // Never replace an old generation; a failed publication leaves the previous pointer valid.
    for key in chunks.keys.sorted() {
      try chunks[key]!.write(to: directory.appendingPathComponent(key), options: .atomic)
    }
    let pointer = ScriptSavePointer(
      format: "elite-script-save", schemaVersion: 16, generation: generation,
      hashes: chunks.mapValues(ScriptPackLibrary.hash), scope: scope,
      valueCodec: ScriptValueStorage.codec)
    let bytes = try encoder.encode(pointer)
    try bytes.write(to: url, options: .atomic)
  }
  static func generationDirectory(_ generation: String, from url: URL) throws -> URL {
    guard UUID(uuidString: generation)?.uuidString == generation else {
      throw SaveError.invalidCommander
    }
    return url.appendingPathExtension("missions").appendingPathComponent(
      generation, isDirectory: true)
  }
  static func read(_ pointerBytes: Data, from url: URL) throws -> (Commander, ScriptWorldSave) {
    guard pointerBytes.count <= 262144 else { throw SaveError.invalidCommander }
    try ScriptSaveJSONPreflight.validate(pointerBytes)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    let names: Set<String> =
      pointer.schemaVersion >= 8
      ? ["commander.json", "missions.json", "world.json", "contracts.json"]
      : ["commander.json", "missions.json", "world.json"]
    guard pointer.format == "elite-script-save", (2...16).contains(pointer.schemaVersion),
      UUID(uuidString: pointer.generation)?.uuidString == pointer.generation,
      Set(pointer.hashes.keys) == names,
      pointer.schemaVersion < 6 || ["commander", "gallery"].contains(pointer.scope ?? "")
    else { throw SaveError.invalidCommander }
    guard
      pointer.schemaVersion >= 13
        ? pointer.valueCodec == ScriptValueStorage.codec : pointer.valueCodec == nil
    else {
      throw SaveError.invalidCommander
    }
    let typed = pointer.schemaVersion >= 13
    let storedLimit = typed ? 134_217_728 : 33_554_432
    let directory = try generationDirectory(pointer.generation, from: url)
    var chunks: [String: Data] = [:]
    var limits = [
      ("commander.json", 4_194_304), ("missions.json", storedLimit), ("world.json", 8_388_608),
    ]
    if pointer.schemaVersion >= 8 { limits.append(("contracts.json", storedLimit)) }
    for (name, limit) in limits {
      let location = directory.appendingPathComponent(name)
      let properties = try location.resourceValues(forKeys: [
        .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
      ])
      guard properties.isRegularFile == true, properties.isSymbolicLink != true,
        (properties.fileSize ?? Int.max) <= limit
      else { throw SaveError.invalidCommander }
      let data = try Data(contentsOf: location)
      guard data.count <= limit, ScriptPackLibrary.hash(data) == pointer.hashes[name] else {
        throw SaveError.invalidCommander
      }
      try ScriptSaveJSONPreflight.validate(data)
      chunks[name] = data
    }
    var commander = try ScriptValueStorage.decoder(typed: typed).decode(
      Commander.self, from: chunks["commander.json"]!)
    if pointer.schemaVersion <= 4 { commander.migrateLegacyPassengerMarker() }
    commander.scriptState = try ScriptValueStorage.decoder(typed: typed).decode(
      ScriptEngineState.self, from: chunks["missions.json"]!)
    if let bytes = chunks["contracts.json"] {
      commander.contracts = try ScriptValueStorage.decoder(typed: typed).decode(
        ScriptContractState.self, from: bytes)
    } else if !commander.contracts.boards.isEmpty
      || commander.scriptState.instances.values.contains(where: { $0.contract != nil })
    {
      throw SaveError.invalidCommander
    }
    let world = try ScriptValueStorage.decoder(typed: typed).decode(
      ScriptWorldSave.self, from: chunks["world.json"]!)
    let semantic = JSONEncoder()
    guard try semantic.encode(commander.scriptState).count <= 33_554_432,
      try semantic.encode(commander.contracts).count <= 33_554_432,
      pointer.schemaVersion < 10 || commander.scriptState.calendarLedger != nil,
      commander.valid, world.valid, world.consistent(with: commander)
    else {
      throw SaveError.invalidCommander
    }
    return (commander, world)
  }
}

extension Game {
  var scriptWorldSave: ScriptWorldSave {
    ScriptWorldSave(
      simulation: scriptSimulationSave, referenceFrame: scriptReferenceFrame,
      contractScreen: commander.contracts.boards.isEmpty ? nil : contractBoard.save, bodies: bodies,
      market: market, docked: docked,
      mainStation: dockedAtMainStation,
      screen: screen, speed: speed, time: scriptStartupTime ?? time, energy: energy,
      frontShield: frontShield,
      rearShield: rearShield, laserHeat: laserHeat, jumpCountdown: jumpCountdown,
      selectedSystem: selectedSystem, nextBodyID: nextBodyID)
  }
  mutating func restoreScriptWorld(_ world: ScriptWorldSave) {
    restoreScriptSimulation(world.simulation)
    scriptReferenceFrame = world.referenceFrame
    bodies = world.bodies
    market = world.market
    docked = world.docked
    dockedAtMainStation = world.mainStation
    // Pending contacts restore through Contacts, not a stale UI selection token.
    screen = world.screen.isFlight ? world.screen : .status
    speed = world.speed
    time = world.time
    energy = world.energy
    frontShield = world.frontShield
    rearShield = world.rearShield
    laserHeat = world.laserHeat
    jumpCountdown = world.jumpCountdown
    selectedSystem = world.selectedSystem
    nextBodyID = world.nextBodyID
    if let saved = world.contractScreen {
      contractBoard.restoredSelection = saved.selection
      contractBoard.previous = saved.previous
      contractBoard.action = saved.action
      contractBoard.scroll = saved.scroll
    }
    if world.screen == .contracts, docked, dockedAtMainStation, let saved = world.contractScreen {
      screen = .contracts
      refreshContractRows(restoring: saved)
    }
  }
}
