import Foundation
import Testing

@testable import EliteCore

private struct MissionPackInputFixture {
  let root: URL
  var folder: URL { root.appendingPathComponent("pack", isDirectory: true) }
  var manifest: URL { folder.appendingPathComponent("manifest.toml") }
  var legacy: URL { Self.examples.appendingPathComponent("courier.toml") }
  static var examples: URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("docs/mission-packs")
  }
  init() throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "pack-input-" + UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    do {
      try FileManager.default.copyItem(
        at: Self.examples.appendingPathComponent("scripted-courier"), to: folder)
    } catch {
      try? FileManager.default.removeItem(at: root)
      throw error
    }
  }
  func replaceManifest(_ old: String, with new: String) throws {
    let text = try String(contentsOf: manifest, encoding: .utf8)
    guard text.contains(old) else { throw MissionPackError("Missing test fixture declaration.") }
    try text.replacingOccurrences(of: old, with: new).write(
      to: manifest, atomically: true, encoding: .utf8)
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
}

@Test func missionPackInputValidationUsesLegacyAndProtectedModuleProviders() throws {
  let fixture = try MissionPackInputFixture()
  defer { fixture.clean() }
  let legacyInput = try MissionPackInput(at: fixture.legacy)
  let legacyLines = try legacyInput.validationLines()
  #expect(legacyLines == ["Valid mission pack: xyzzy.example.courier/lave-zaonce @ 1.0.0"])
  try fixture.replaceManifest("capabilities = [", with: "capabilities = [\"pack-modules-v2\", ")
  let declaration = "\n[[modules]]\nid=\"handlers\"\npath=\"scripts/handlers.lua\"\n"
  let manifest = try String(contentsOf: fixture.manifest, encoding: .utf8)
  try (manifest + declaration).write(to: fixture.manifest, atomically: true, encoding: .utf8)
  try "return require('handlers')".write(
    to: fixture.folder.appendingPathComponent("scripts/main.lua"), atomically: true, encoding: .utf8
  )
  let handlers = """
    local function empty(e,w,d) return {data=d,commands={}} end
    return {accepted=empty,contact=empty,confirm=empty}
    """
  try handlers.write(
    to: fixture.folder.appendingPathComponent("scripts/handlers.lua"), atomically: true,
    encoding: .utf8)
  let before = try FileManager.default.contentsOfDirectory(atPath: fixture.root.path).sorted()
  let input = try MissionPackInput(at: fixture.folder)
  let lines = try input.validationLines()
  let pack = try ScriptPackLibrary.read(fixture.folder)
  #expect(lines.first?.contains(pack.digest) == true)
  #expect(
    lines.last == "Runtime availability is checked against the commander and installed content.")
  let after = try FileManager.default.contentsOfDirectory(atPath: fixture.root.path).sorted()
  #expect(after == before)
  try fixture.replaceManifest("capabilities = [", with: "capabilities = [\"world-actors-v1\", ")
  try fixture.replaceManifest(
    "priority = 500", with: "priority = 500\ndependencies = ['absent.pack@1.0.0']")
  let referenceLines = try input.validationLines()
  #expect(referenceLines.contains("Unavailable in this build: world-actors-v1"))
  #expect(referenceLines.contains("Requires installed dependencies: absent.pack@1.0.0"))
}

@Test(arguments: [
  "bad-lua", "missing-module", "manifest-file", "folder-link", "file-link", "missing",
])
func missionPackInputRefusesInvalidSelectedContentWithoutFallback(_ kind: String) throws {
  let fixture = try MissionPackInputFixture()
  defer { fixture.clean() }
  var selected = fixture.folder
  switch kind {
  case "bad-lua":
    try "return {}".write(
      to: fixture.folder.appendingPathComponent("scripts/main.lua"), atomically: true,
      encoding: .utf8)
  case "missing-module":
    try fixture.replaceManifest(
      "module = \"scripts/main.lua\"", with: "module = 'scripts/absent.lua'")
  case "manifest-file": selected = fixture.manifest
  case "folder-link", "file-link":
    selected = fixture.root.appendingPathComponent(kind == "folder-link" ? "link" : "link.toml")
    try FileManager.default.createSymbolicLink(
      at: selected, withDestinationURL: kind == "folder-link" ? fixture.folder : fixture.legacy)
  default: selected = fixture.root.appendingPathComponent("absent")
  }
  #expect(throws: (any Error).self) {
    let input = try MissionPackInput(at: selected)
    _ = try input.validationLines()
  }
}

@Test func missionPackInputInstallationSeparatesLibrariesAndKeepsMissingDependenciesLocked()
  async throws
{
  let fixture = try MissionPackInputFixture()
  defer { fixture.clean() }
  let legacyDirectory = fixture.root.appendingPathComponent("legacy")
  let scriptDirectory = fixture.root.appendingPathComponent("scripts")
  let runtime = GameRuntime(game: Game(executive: false))
  try await runtime.installMissionPackInput(
    from: fixture.legacy, legacyDirectory: legacyDirectory, scriptDirectory: scriptDirectory)
  let scriptDirectoryExists = FileManager.default.fileExists(atPath: scriptDirectory.path)
  #expect(!scriptDirectoryExists)
  try fixture.replaceManifest(
    "priority = 500", with: "priority = 500\ndependencies = ['absent.pack@1.0.0']")
  let source = try ScriptPackLibrary.read(fixture.folder)
  for _ in 0..<2 {
    try await runtime.installMissionPackInput(
      from: fixture.folder, legacyDirectory: legacyDirectory, scriptDirectory: scriptDirectory)
  }
  var game = await runtime.snapshot()
  let installed = try #require(game.scriptPacks.first)
  #expect(game.scriptPacks.count == 1 && installed.digest == source.digest)
  #expect(game.message == "MISSION REFERENCE INSTALLED - SEE MISSION GALLERY")
  let unavailable = game.scriptUnavailable(installed)
  #expect(unavailable == "Requires: absent.pack@1.0.0")
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(installed) }
  let legacyNames = try FileManager.default.contentsOfDirectory(atPath: legacyDirectory.path)
  let scriptNames = try FileManager.default.contentsOfDirectory(atPath: scriptDirectory.path)
  #expect(legacyNames == ["xyzzy.example.courier.toml"])
  #expect(scriptNames == [source.manifest.id + "@" + source.manifest.version + "-" + source.digest])
}
