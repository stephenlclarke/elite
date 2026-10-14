import CryptoKit
import Foundation
import TOMLDecoder

public struct ScriptHandler: Codable, Sendable {
  public let event: String
  public let function: String
}
public struct ScriptMission: Codable, Sendable {
  public let id: String
  public let title: String
  public let briefing: String
  public let destination: String
  public let reward: String
  public let milestones: [String]
  public let requiredDestructionEncounters: [String]?
  public let requiredPassengerParties: [String]?
}
public struct ScriptDialog: Codable, Sendable {
  public let id: String
  public let text: String
}
public struct ScriptManifest: Codable, Sendable {
  public let schemaVersion: Int
  public let missionAPI: Int
  public let id: String
  public let version: String
  public let minimumEngine: String
  public let capabilities: [String]
  public let dependencies: [String]?
  public let priority: Int
  public let source: String
  public let license: String
  public let environments: [String]
  public let module: String
  public let mission: ScriptMission
  public let handlers: [ScriptHandler]
  public let dialogs: [ScriptDialog]?
  public let encounters: [ScriptEncounterDefinition]?
  public let passengerParties: [ScriptPassengerParty]?
  public var stateID: String { id + "/" + mission.id }
}
public struct ScriptPack: Sendable {
  public let manifest: ScriptManifest
  public let source: Data
  public let manifestBytes: Data
  public let digest: String
  public var missingCapabilities: [String] {
    Set(manifest.capabilities).subtracting(ScriptCapabilities.implemented).sorted()
  }
}

/// Only capabilities with executable native support are advertised.
public enum ScriptCapabilities {
  public static let implemented: Set<String> = [
    "script-lua-v1", "story-v2", "economy-v2", "cargo-v2", "local-flight-clocks-v2",
    "classic-encounters-v2", "charter-passengers-v2",
  ]
  static func playerFeatureName(_ capability: String) -> String {
    let names = [
      "world-actors-v1": "persistent ships and stations",
      "encounter-admission-v1": "physical encounter deployment",
      "flight-ai-v1": "scripted ship navigation", "combat-events-v1": "mission combat tracking",
      "wormhole-transit-v1": "ship travel through wormholes",
      "world-clocks-v1": "mission clocks and station jobs",
      "custody-v1": "passenger and cargo custody",
      "fitting-storage-v1": "equipment transfer and storage",
      "contracts-v1": "station contract boards", "campaigns-v1": "linked campaigns",
      "gallery-world-v1": "mission trial scenarios",
    ]
    return names[capability] ?? "additional mission support"
  }
  static let events: Set<String> = [
    "mission.accepted", "station.docked", "station.undocked", "system.entered", "contact.requested",
    "dialogue.confirmed", "timer.fired", "mission.abandoned", "encounter.admitted",
    "encounter.pending", "actor.destroyed", "actor.removed",
  ]
}

public enum ScriptPackLibrary {
  public static func read(_ directory: URL) throws -> ScriptPack {
    let properties = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard properties.isDirectory == true, properties.isSymbolicLink != true else {
      throw MissionPackError("Choose a mission pack folder containing manifest.toml.")
    }
    let bytes = try readFile("manifest.toml", in: directory)
    let root = try TOMLTable(source: bytes)
    try keys(
      root,
      "schemaVersion missionAPI id version minimumEngine capabilities dependencies priority source license environments module mission handlers dialogs encounters passengerParties"
    )
    try keys(
      root.table(forKey: "mission"),
      "id title briefing destination reward milestones requiredDestructionEncounters requiredPassengerParties"
    )
    for (name, allowed) in ["handlers": "event function", "dialogs": "id text"]
    where root.contains(key: name) {
      let array = try root.array(forKey: name)
      for i in 0..<array.count { try keys(array.table(atIndex: i), allowed) }
    }
    if root.contains(key: "encounters") {
      let encounters = try root.array(forKey: "encounters")
      for index in 0..<encounters.count {
        let table = try encounters.table(atIndex: index)
        try keys(table, "id galaxy system profile actors")
        let actors = try table.array(forKey: "actors")
        for actor in 0..<actors.count {
          try keys(actors.table(atIndex: actor), "id hull x y z hostile")
        }
      }
    }
    if root.contains(key: "passengerParties") {
      let parties = try root.array(forKey: "passengerParties")
      for index in 0..<parties.count {
        try keys(
          parties.table(atIndex: index),
          "id names pickupGalaxy pickupSystem destinationGalaxy destinationSystem")
      }
    }
    let manifest = try TOMLDecoder().decode(ScriptManifest.self, from: bytes)
    try validate(manifest)
    let source = try readFile(manifest.module, in: directory)
    guard String(data: source, encoding: .utf8) != nil, !source.contains(0) else {
      throw MissionPackError("Mission Lua must be UTF-8 text without NUL bytes.")
    }
    try ScriptEvaluator.validate(source: source, handlers: manifest.handlers.map(\.function))
    var digestInput = Data()
    for (name, data) in [("manifest.toml", bytes), (manifest.module, source)] {
      digestInput.append(try ScriptWire.encode([.string(name), .integer(Int64(data.count))]))
      digestInput.append(data)
    }
    return ScriptPack(
      manifest: manifest, source: source, manifestBytes: bytes, digest: hash(digestInput))
  }
  static func hash(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
  static func keys(_ table: TOMLTable, _ allowed: String) throws {
    let unknown = Set(table.keys).subtracting(allowed.split(separator: " ").map(String.init))
    guard unknown.isEmpty else {
      throw MissionPackError(
        "Unknown script pack keys: " + unknown.sorted().joined(separator: ", "))
    }
  }
  static func validate(_ manifest: ScriptManifest) throws {
    guard manifest.schemaVersion == 2, manifest.missionAPI == 2, manifest.minimumEngine == "2.0.0",
      PackValidation.identifier(manifest.id), PackValidation.identifier(manifest.mission.id),
      PackValidation.version(manifest.version), (0...1000).contains(manifest.priority),
      (1...4096).contains(manifest.source.utf8.count),
      (1...4096).contains(manifest.license.utf8.count),
      manifest.environments.count <= 2, manifest.capabilities.count <= 64,
      manifest.mission.destination.utf8.count <= 2048, manifest.mission.reward.utf8.count <= 2048,
      !manifest.environments.isEmpty,
      Set(manifest.environments).isSubset(of: ["space", "orbital-station"]),
      (1...64).contains(manifest.mission.title.count),
      (1...12000).contains(manifest.mission.briefing.count),
      (1...64).contains(manifest.mission.milestones.count),
      manifest.mission.milestones.allSatisfy({ !$0.isEmpty && $0.count <= 256 }),
      manifest.capabilities.contains("script-lua-v1"),
      Set(manifest.capabilities).count == manifest.capabilities.count,
      manifest.capabilities.allSatisfy(PackValidation.identifier),
      (1...64).contains(manifest.handlers.count),
      Set(manifest.handlers.map(\.event)).count == manifest.handlers.count,
      manifest.handlers.allSatisfy({
        ScriptCapabilities.events.contains($0.event)
          && $0.function.range(of: "^[A-Za-z_][A-Za-z0-9_]{0,79}$", options: .regularExpression)
            != nil
      }),
      (manifest.dialogs?.count ?? 0) <= 64,
      Set((manifest.dialogs ?? []).map(\.id)).count == (manifest.dialogs?.count ?? 0),
      (manifest.dialogs ?? []).allSatisfy({
        PackValidation.identifier($0.id) && (1...12000).contains($0.text.count)
      }),
      (manifest.dependencies?.count ?? 0) <= 32,
      (manifest.dependencies ?? []).allSatisfy({ dependency in
        let parts = dependency.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && PackValidation.identifier(String(parts[0]))
          && PackValidation.version(String(parts[1]))
      })
    else {
      throw MissionPackError(
        "Invalid script manifest, scope, identity, handler or resource declarations.")
    }
    let nativeEvents = Set([
      "encounter.admitted", "encounter.pending", "actor.destroyed", "actor.removed",
    ])
    guard
      !manifest.handlers.contains(where: { nativeEvents.contains($0.event) })
        || manifest.capabilities.contains("classic-encounters-v2")
    else {
      throw MissionPackError(
        "Native actor events require the declared classic encounter capability.")
    }
    let encounters = manifest.encounters ?? []
    guard encounters.count <= 64, Set(encounters.map(\.id)).count == encounters.count,
      encounters.allSatisfy(\.valid), encounters.reduce(0, { $0 + $1.actors.count }) <= 128,
      Set(manifest.mission.requiredDestructionEncounters ?? []).isSubset(
        of: Set(encounters.map(\.id))),
      encounters.isEmpty || manifest.capabilities.contains("classic-encounters-v2")
    else {
      throw MissionPackError("Invalid encounter declarations or missing native classic capability.")
    }
    let parties = manifest.passengerParties ?? []
    guard parties.count <= 64, Set(parties.map(\.id)).count == parties.count,
      parties.allSatisfy(\.valid), parties.reduce(0, { $0 + $1.names.count }) <= 128,
      Set(manifest.mission.requiredPassengerParties ?? []).isSubset(of: Set(parties.map(\.id))),
      parties.isEmpty || manifest.capabilities.contains("charter-passengers-v2")
    else { throw MissionPackError("Invalid passenger parties or missing charter capability.") }
    try path(manifest.module)
    guard manifest.module.hasSuffix(".lua"), manifest.module != "manifest.toml" else {
      throw MissionPackError("Declare a pack-local .lua module.")
    }
  }
  static func path(_ path: String) throws {
    let parts = path.split(separator: "/", omittingEmptySubsequences: false)
    guard !path.hasPrefix("/"), !parts.isEmpty, parts.count <= 8,
      parts.allSatisfy({
        $0.range(of: "^[A-Za-z0-9_-][A-Za-z0-9_.-]{0,79}$", options: .regularExpression) != nil
      })
    else {
      throw MissionPackError("Pack resources must use canonical relative paths.")
    }
  }
  static func readFile(_ path: String, in directory: URL) throws -> Data {
    try Self.path(path)
    var location = directory
    for component in path.split(separator: "/") {
      location.appendPathComponent(String(component))
      let properties = try location.resourceValues(forKeys: [.isSymbolicLinkKey])
      guard properties.isSymbolicLink != true else {
        throw MissionPackError("Pack resource links are not allowed.")
      }
    }
    let properties = try location.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
    guard properties.isRegularFile == true, (properties.fileSize ?? Int.max) <= 262144 else {
      throw MissionPackError("Each mission resource must be a regular file no larger than 256 KiB.")
    }
    let data = try Data(contentsOf: location)
    guard data.count <= 262144 else {
      throw MissionPackError("Mission resource changed or exceeds 256 KiB.")
    }
    return data
  }
  public static func install(_ pack: ScriptPack, directory: URL) throws -> URL {
    let destination = directory.appendingPathComponent(
      pack.manifest.id + "@" + pack.manifest.version + "-" + pack.digest, isDirectory: true)
    if FileManager.default.fileExists(atPath: destination.path) {
      guard try read(destination).digest == pack.digest else {
        throw MissionPackError("Installed content has changed; restore its original bytes.")
      }
      return destination
    }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let installedNames = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter
    { !$0.hasPrefix(".") }
    guard installedNames.count < 128 else {
      throw MissionPackError(
        "The mission library is full. Keep versions that saved commanders need before installing another."
      )
    }
    let staging = directory.appendingPathComponent(".install-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: staging) }
    try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
    try pack.manifestBytes.write(to: staging.appendingPathComponent("manifest.toml"))
    let module = staging.appendingPathComponent(pack.manifest.module)
    try FileManager.default.createDirectory(
      at: module.deletingLastPathComponent(), withIntermediateDirectories: true)
    try pack.source.write(to: module)
    guard try read(staging).digest == pack.digest else {
      throw MissionPackError("Installed mission failed content verification.")
    }
    try FileManager.default.moveItem(at: staging, to: destination)
    return destination
  }
  static func installed(directory: URL) -> (packs: [ScriptPack], errors: [String]) {
    guard FileManager.default.fileExists(atPath: directory.path) else { return ([], []) }
    do {
      let urls = try FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: nil
      )
      .filter { !$0.lastPathComponent.hasPrefix(".") }.sorted {
        $0.lastPathComponent < $1.lastPathComponent
      }
      guard urls.count <= 128 else {
        throw MissionPackError("At most 128 script pack versions may be installed.")
      }
      var packs: [ScriptPack] = []
      var errors: [String] = []
      for url in urls {
        do {
          let pack = try read(url)
          if !packs.contains(where: { $0.digest == pack.digest }) { packs.append(pack) }
        } catch {
          errors.append(url.lastPathComponent + ": " + error.localizedDescription)
        }
      }
      return (packs, errors)
    } catch { return ([], [error.localizedDescription]) }
  }
}
