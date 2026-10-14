import Foundation

struct ScriptWorldSave: Codable, Sendable {
  var simulation: ScriptSimulationSave?
  var referenceFrame: ScriptReferenceFrame?
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
    (simulation?.valid ?? true) && (referenceFrame?.valid ?? true) && bodies.count <= 1024
      && Set(bodies.map(\.id)).count == bodies.count
      && Set(bodies.compactMap(\.missionActorID)).count
        == bodies.filter { $0.missionActorID != nil }.count
      && bodies.allSatisfy { body in
        body.id >= 0
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
    var records: [UUID: (UUID, Int, Int, ScriptOwnedActor)] = [:]
    for instance in commander.scriptState.instances.values {
      for encounter in instance.ownedEncounters.values {
        for actor in encounter.actors.values {
          guard records[actor.identity] == nil else { return false }
          records[actor.identity] = (instance.id, encounter.galaxy, encounter.system, actor)
        }
      }
    }
    let physical = bodies.filter { $0.missionActorID != nil }
    let expected = records.values.filter { $0.3.presence == .present }
    guard physical.count == expected.count,
      expected.allSatisfy({ $0.1 == commander.galaxy && $0.2 == commander.system })
    else { return false }
    for body in physical {
      guard let identity = body.missionActorID, let record = records[identity],
        body.missionInstanceID == record.0, record.3.presence == .present,
        body.id == record.3.body.id, body.hull == record.3.body.hull,
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
}

/// Publication is synchronous inside GameRuntime: no actor reentrancy can overwrite newer simulation state.
enum ScriptSaveStore {
  static func write(commander: Commander, world: ScriptWorldSave, to url: URL) throws {
    guard commander.valid, world.valid, world.consistent(with: commander) else {
      throw SaveError.invalidCommander
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    var header = commander
    header.scriptState = ScriptEngineState()
    let chunks = [
      "commander.json": try encoder.encode(header),
      "missions.json": try encoder.encode(commander.scriptState),
      "world.json": try encoder.encode(world),
    ]
    guard chunks["commander.json"]!.count <= 4_194_304,
      chunks["missions.json"]!.count <= 33_554_432,
      chunks["world.json"]!.count <= 8_388_608
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
      format: "elite-script-save", schemaVersion: 3, generation: generation,
      hashes: chunks.mapValues(ScriptPackLibrary.hash))
    let bytes = try encoder.encode(pointer)
    try bytes.write(to: url, options: .atomic)
  }
  static func read(_ pointerBytes: Data, from url: URL) throws -> (Commander, ScriptWorldSave) {
    guard pointerBytes.count <= 262144 else { throw SaveError.invalidCommander }
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    guard pointer.format == "elite-script-save", (2...3).contains(pointer.schemaVersion),
      UUID(uuidString: pointer.generation)?.uuidString == pointer.generation,
      Set(pointer.hashes.keys) == ["commander.json", "missions.json", "world.json"]
    else { throw SaveError.invalidCommander }
    let directory = url.appendingPathExtension("missions").appendingPathComponent(
      pointer.generation, isDirectory: true)
    var chunks: [String: Data] = [:]
    for (name, limit) in [
      ("commander.json", 4_194_304), ("missions.json", 33_554_432), ("world.json", 8_388_608),
    ] {
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
      chunks[name] = data
    }
    var commander = try JSONDecoder().decode(Commander.self, from: chunks["commander.json"]!)
    commander.scriptState = try JSONDecoder().decode(
      ScriptEngineState.self, from: chunks["missions.json"]!)
    let world = try JSONDecoder().decode(ScriptWorldSave.self, from: chunks["world.json"]!)
    guard commander.valid, world.valid, world.consistent(with: commander) else {
      throw SaveError.invalidCommander
    }
    return (commander, world)
  }
}

extension Game {
  var scriptWorldSave: ScriptWorldSave {
    ScriptWorldSave(
      simulation: scriptSimulationSave, referenceFrame: scriptReferenceFrame, bodies: bodies,
      market: market, docked: docked,
      mainStation: dockedAtMainStation,
      screen: screen, speed: speed, time: time, energy: energy, frontShield: frontShield,
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
  }
}
