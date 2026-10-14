import CryptoKit
import Foundation
import TOMLDecoder

public enum PackEvent: String, Codable, Sendable {
  case dock, contact, targetRemoved, targetDestroyed, clock
}
public struct PackCondition: Codable, Sendable {
  public let field: String
  public let op: String
  public let value: Double?
  public let text: String?
}
public struct PackAction: Codable, Sendable {
  public let kind: String
  public let key: String?
  public let amount: Int?
}
public enum PackOutcome: String, Codable, Sendable { case complete, failed }
public struct PackStage: Codable, Sendable {
  public let id: String
  public let objective: String
  public let completed: Int
  public let terminal: Bool?
  public let outcome: PackOutcome?
  public let legacyValues: [Int]?
  public let legacyWrite: Int?
}
public struct PackDialog: Codable, Sendable {
  public let id: String
  public let text: String
  public let ship: Bool?
  public let delaySeconds: Double?
}
public struct PackTransition: Codable, Sendable {
  public let id: String
  public let from: String
  public let event: PackEvent
  public let to: String
  public let conditions: [PackCondition]?
  public let actions: [PackAction]?
  public let dialog: String?
  public let confirmation: Bool?
  public let notification: String?
}
public struct PackMission: Codable, Sendable {
  public let id: String
  public let title: String
  public let initialStage: String
  public let briefing: String
  public let destination: String
  public let reward: String
  public let prerequisites: [String]
  public let milestones: [String]
  public let binding: String?
}
public struct PackClue: Codable, Sendable {
  public let galaxy: Int
  public let systems: [Int]
  public let texts: [String]
}
public struct PackEncounter: Codable, Sendable {
  public let id: String
  public let stage: String
  public let galaxy: Int?
  public let system: Int?
  public let kind: String
}
public struct MissionPack: Codable, Sendable {
  public let schemaVersion: Int
  public let id: String
  public let version: String
  public let minimumEngine: String
  public let capabilities: [String]
  public let dependencies: [String]?
  public let priority: Int
  public let source: String
  public let license: String
  public let mission: PackMission
  public let stages: [PackStage]
  public let transitions: [PackTransition]
  public let dialogs: [PackDialog]?
  public let clues: [PackClue]?
  public let encounters: [PackEncounter]?
  public var stateID: String { id + "/" + mission.id }
  public func stage(_ id: String) -> PackStage? { stages.first { $0.id == id } }
  public func dialog(_ id: String) -> PackDialog? { dialogs?.first { $0.id == id } }
}
public struct LoadedMissionPack: Sendable {
  public let pack: MissionPack
  public let digest: String
}
public struct MissionProgress: Codable, Sendable, Equatable {
  public var version: String
  public var digest: String
  public var stage: String
  public var seconds = 0.0
  public var flags: [String: Int] = [:]
  public var receipts: Set<String> = []
  public var payloads: [String: Int] = [:]
  public var valid: Bool {
    PackValidation.version(version)
      && digest.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
      && PackValidation.identifier(stage) && seconds.isFinite
      && (0...1_000_000_000).contains(seconds)
      && flags.count <= 128 && receipts.count <= 512 && payloads.count <= 128
      && flags.keys.allSatisfy(PackValidation.localID)
      && receipts.allSatisfy(PackValidation.localID)
      && payloads.keys.allSatisfy(PackValidation.localID)
      && payloads.values.allSatisfy { (0...1_000_000).contains($0) }
  }
}
public struct MissionPackError: LocalizedError, Sendable {
  public let reason: String
  public var errorDescription: String? { reason }
  init(_ reason: String) { self.reason = reason }
}
public struct MissionPackLibrary: Sendable {
  public var entries: [LoadedMissionPack]
  public var errors: [String]
  public static let capabilities: Set<String> = [
    "state-machine-v1", "dialog-v1", "economy-v1", "cargo-v1", "clock-v1",
  ]
  public static let bundled: MissionPackLibrary = {
    let resources =
      Bundle.main.resourceURL.flatMap {
        Bundle(url: $0.appendingPathComponent("Elite_EliteCore.bundle"))
      } ?? Bundle.module
    do {
      return try load(
        directory: resources.resourceURL!.appendingPathComponent("MissionPacks"),
        bundled: true)
    } catch { preconditionFailure("Invalid bundled missions: \(error)") }
  }()
  public static var userDirectory: URL {
    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
      ".xyzzy/elite/mission-packs")
  }
  public static func read(_ url: URL, bundled: Bool = false) throws -> LoadedMissionPack {
    let properties = try url.resourceValues(forKeys: [
      .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
    ])
    guard url.pathExtension == "toml", properties.isRegularFile == true,
      properties.isSymbolicLink != true, (properties.fileSize ?? Int.max) <= 262144
    else { throw MissionPackError("Choose a regular .toml file no larger than 256 KiB.") }
    let data = try Data(contentsOf: url)
    return try decode(data, bundled: bundled)
  }
  static func decode(_ data: Data, bundled: Bool = false) throws -> LoadedMissionPack {
    guard data.count <= 262144 else { throw MissionPackError("Pack exceeds 256 KiB.") }
    try PackKeys.validate(data)
    let pack = try TOMLDecoder().decode(MissionPack.self, from: data)
    try PackValidation.validate(pack, bundled: bundled)
    return LoadedMissionPack(
      pack: pack, digest: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
  }
  public static func load(directory: URL, bundled: Bool = false) throws -> Self {
    let urls = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil
    )
    .filter { $0.pathExtension == "toml" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    guard urls.count <= 64 else { throw MissionPackError("At most 64 packs may be installed.") }
    return try checked(urls.map { try read($0, bundled: bundled) })
  }
  public static func checked(_ entries: [LoadedMissionPack]) throws -> Self {
    var ids = Set<String>()
    for entry in entries {
      guard ids.insert(entry.pack.id).inserted else {
        throw MissionPackError("Duplicate pack ID: \(entry.pack.id)")
      }
    }
    let versions = Set(entries.map { $0.pack.id + "@" + $0.pack.version })
    for entry in entries {
      for dependency in entry.pack.dependencies ?? [] where !versions.contains(dependency) {
        throw MissionPackError("\(entry.pack.id) requires installed \(dependency).")
      }
    }
    return Self(
      entries: entries.sorted {
        ($0.pack.priority, $0.pack.id) < ($1.pack.priority, $1.pack.id)
      }, errors: [])
  }
  public static func installed(directory: URL = userDirectory) -> Self {
    var result = bundled
    guard FileManager.default.fileExists(atPath: directory.path) else { return result }
    do {
      let urls = try FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: nil
      )
      .filter { $0.pathExtension == "toml" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
      guard urls.count <= 64 else {
        throw MissionPackError("At most 64 external packs may be installed.")
      }
      var candidates = result.entries
      for url in urls {
        do { candidates.append(try read(url)) } catch {
          result.errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
        }
      }
      // A conflicting/dependent set is disabled together; never choose an arbitrary winner.
      do { result.entries = try checked(candidates).entries } catch {
        result.errors.append(error.localizedDescription)
      }
    } catch { result.errors.append(error.localizedDescription) }
    return result
  }
}
