import Foundation

struct ScriptWorldSave: Codable, Sendable {
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
    bodies.count <= 1024 && Set(bodies.map(\.id)).count == bodies.count
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
    guard commander.valid, world.valid else { throw SaveError.invalidCommander }
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
      format: "elite-script-save", schemaVersion: 2, generation: generation,
      hashes: chunks.mapValues(ScriptPackLibrary.hash))
    let bytes = try encoder.encode(pointer)
    try bytes.write(to: url, options: .atomic)
  }
  static func read(_ pointerBytes: Data, from url: URL) throws -> (Commander, ScriptWorldSave) {
    guard pointerBytes.count <= 262144 else { throw SaveError.invalidCommander }
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    guard pointer.format == "elite-script-save", pointer.schemaVersion == 2,
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
    guard commander.valid, world.valid else { throw SaveError.invalidCommander }
    return (commander, world)
  }
}

extension Game {
  var scriptWorldSave: ScriptWorldSave {
    ScriptWorldSave(
      bodies: bodies, market: market, docked: docked, mainStation: dockedAtMainStation,
      screen: screen, speed: speed, time: time, energy: energy, frontShield: frontShield,
      rearShield: rearShield, laserHeat: laserHeat, jumpCountdown: jumpCountdown,
      selectedSystem: selectedSystem, nextBodyID: nextBodyID)
  }
  mutating func restoreScriptWorld(_ world: ScriptWorldSave) {
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
