import Foundation

/// Routes a selected input to its existing provider; neither parsing nor installation is duplicated.
public enum MissionPackInput: Sendable {
  case legacyFile(URL)
  case scriptFolder(URL)

  public init(at url: URL) throws {
    let properties = try url.resourceValues(forKeys: [.isDirectoryKey])
    self = properties.isDirectory == true ? .scriptFolder(url) : .legacyFile(url)
  }

  /// Read-only content validation. Runtime dependencies, saves and acceptance remain separate gates.
  public func validationLines() throws -> [String] {
    switch self {
    case .legacyFile(let url):
      let entry = try MissionPackLibrary.read(url)
      _ = try MissionPackLibrary.checked(MissionPackLibrary.bundled.entries + [entry])
      return ["Valid mission pack: \(entry.pack.stateID) @ \(entry.pack.version)"]
    case .scriptFolder(let url):
      let pack = try ScriptPackLibrary.read(url)
      var lines: [String] = [
        "Valid schema 2 mission content: \(pack.manifest.stateID) @ \(pack.manifest.version) (digest \(pack.digest))"
      ]
      if !pack.missingCapabilities.isEmpty {
        lines.append(
          "Unavailable in this build: " + pack.missingCapabilities.joined(separator: ", "))
      }
      let dependencies = Set(pack.manifest.dependencies ?? []).sorted()
      if !dependencies.isEmpty {
        lines.append("Requires installed dependencies: " + dependencies.joined(separator: ", "))
      }
      lines.append("Runtime availability is checked against the commander and installed content.")
      return lines
    }
  }
}

extension GameRuntime {
  public func installMissionPackInput(
    from url: URL, legacyDirectory: URL = MissionPackLibrary.userDirectory,
    scriptDirectory: URL = ScriptPackLibrary.userDirectory
  ) throws {
    switch try MissionPackInput(at: url) {
    case .legacyFile(let file): try installMissionPack(from: file, directory: legacyDirectory)
    case .scriptFolder(let folder):
      try installScriptPack(from: folder, destination: scriptDirectory)
    }
  }
}
