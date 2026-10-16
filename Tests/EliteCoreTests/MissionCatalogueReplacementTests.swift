import Foundation
import Testing

@testable import EliteCore

private func cataloguePack(_ id: String, priority: Int = 20) throws -> Data {
  Data(
    """
    schemaVersion = 1
    id = "\(id)"
    version = "1.0.0"
    minimumEngine = "1.0.0"
    capabilities = ["state-machine-v1"]
    priority = \(priority)
    source = "Review regression fixture"
    license = "Project test fixture"
    [mission]
    id = "assignment"
    title = "Catalogue fixture"
    initialStage = "start"
    briefing = "Read-only catalogue fixture."
    destination = "None"
    reward = "None"
    prerequisites = []
    milestones = ["Finish"]
    [[stages]]
    id = "start"
    objective = "Wait for orders."
    completed = 0
    [[stages]]
    id = "done"
    objective = "Finished."
    completed = 1
    terminal = true
    [[transitions]]
    id = "finish"
    from = "start"
    event = "contact"
    to = "done"
    conditions = [{ field = "kills", op = "ge", value = 65535 }]
    """.utf8)
}

private func catalogueFolder() throws -> URL {
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  return folder
}

private func catalogueFiles(_ folder: URL) throws -> [String: Data] {
  try Dictionary(
    uniqueKeysWithValues: FileManager.default.contentsOfDirectory(
      at: folder, includingPropertiesForKeys: nil
    ).map { ($0.lastPathComponent, try Data(contentsOf: $0)) })
}

struct MissionCatalogueReplacementTests {
  @Test func installLimitPreservesDiskRuntimeAndReloadIncludingNoncanonicalReinstallName()
    async throws
  {
    let folder = try catalogueFolder()
    let drafts = try catalogueFolder()
    defer {
      try? FileManager.default.removeItem(at: folder)
      try? FileManager.default.removeItem(at: drafts)
    }
    for index in 0..<63 {
      try cataloguePack("review.pack\(index)").write(
        to: folder.appendingPathComponent("external-\(index).toml"))
    }
    let runtime = GameRuntime()
    await runtime.loadMissionPacks(directory: folder)
    let last = drafts.appendingPathComponent("last.toml")
    try cataloguePack("review.last").write(to: last)
    try await runtime.installMissionPack(from: last, directory: folder)
    let original = try catalogueFiles(folder)
    #expect(original.count == 64)
    let full = await runtime.snapshot()
    #expect(full.missionPacks.entries.count == MissionPackLibrary.bundled.entries.count + 64)
    let alias = folder.appendingPathComponent("external-0.toml")
    try await runtime.installMissionPack(from: alias, directory: folder)
    #expect(try catalogueFiles(folder) == original)
    let overflow = drafts.appendingPathComponent("overflow.toml")
    try cataloguePack("review.overflow").write(to: overflow)
    await #expect(throws: MissionPackError.self) {
      try await runtime.installMissionPack(from: overflow, directory: folder)
    }
    let refused = await runtime.snapshot()
    #expect(refused.commander == full.commander)
    #expect(refused.missionPacks.entries.map(\.digest) == full.missionPacks.entries.map(\.digest))
    #expect(try catalogueFiles(folder) == original)
    await runtime.loadMissionPacks(directory: folder)
    let reloaded = await runtime.snapshot()
    #expect(reloaded.missionPacks.errors.isEmpty)
    #expect(reloaded.missionPacks.entries.map(\.digest) == full.missionPacks.entries.map(\.digest))
  }

  @Test func installationRefusesAnUnrelatedPackFilenameCollision() async throws {
    let folder = try catalogueFolder()
    let drafts = try catalogueFolder()
    defer {
      try? FileManager.default.removeItem(at: folder)
      try? FileManager.default.removeItem(at: drafts)
    }
    try cataloguePack("review.original").write(
      to: folder.appendingPathComponent("review.new.toml"))
    let source = drafts.appendingPathComponent("new.toml")
    try cataloguePack("review.new").write(to: source)
    let runtime = GameRuntime()
    await runtime.loadMissionPacks(directory: folder)
    let original = try catalogueFiles(folder)
    let before = await runtime.snapshot()
    await #expect(throws: MissionPackError.self) {
      try await runtime.installMissionPack(from: source, directory: folder)
    }
    #expect(try catalogueFiles(folder) == original)
    let after = await runtime.snapshot()
    #expect(after.missionPacks.entries.map(\.digest) == before.missionPacks.entries.map(\.digest))
  }

  @Test func replacementRetainsStableMissionSelectionAndSafelyClampsRemovedEntries() throws {
    let first = try MissionPackLibrary.decode(cataloguePack("review.first", priority: 30))
    let selected = try MissionPackLibrary.decode(cataloguePack("review.selected", priority: 40))
    let earlier = try MissionPackLibrary.decode(cataloguePack("review.earlier", priority: 20))
    var game = Game(executive: false)
    game.replaceMissionPacks(try .checked([first, selected]))
    game.screen = .gallery
    game.gallery.selection = 1
    game.gallery.detail = true
    game.replaceMissionPacks(try .checked([earlier, first, selected]))
    #expect(game.gallery.selection == 2 && game.gallery.detail)
    #expect(game.missionPacks.entries[game.gallery.selection].pack.stateID == selected.pack.stateID)
    game.gallery.scroll = 8
    game.replaceMissionPacks(try .checked([first]))
    #expect(game.gallery.selection == 0 && game.gallery.scroll == 0)
    #expect(!game.galleryDetailLines(width: 480, font: GameTypography.scale).isEmpty)
    game.gallery.selection = 99
    #expect(!game.galleryDetailLines(width: 480, font: GameTypography.scale).isEmpty)
    game.galleryKey("pagedown")
    #expect(game.gallery.selection == 0)
    game.replaceMissionPacks(try .checked([]))
    #expect(game.gallery.selection == 0)
    #expect(
      game.galleryDetailLines(width: 480, font: GameTypography.scale) == ["No missions available."])
  }

  @Test func nativeInstallationAfterDiskShrinkReconcilesAnOpenGallery() async throws {
    let folder = try catalogueFolder()
    let drafts = try catalogueFolder()
    defer {
      try? FileManager.default.removeItem(at: folder)
      try? FileManager.default.removeItem(at: drafts)
    }
    var removed: [URL] = []
    for index in 0..<4 {
      let file = folder.appendingPathComponent("external-\(index).toml")
      try cataloguePack("review.pack\(index)").write(to: file)
      removed.append(file)
    }
    var game = Game(executive: false)
    game.replaceMissionPacks(.installed(directory: folder))
    game.screen = .gallery
    game.gallery.detail = true
    game.gallery.selection = game.missionCatalogue.count - 1
    let runtime = GameRuntime(game: game)
    for file in removed { try FileManager.default.removeItem(at: file) }
    let replacement = drafts.appendingPathComponent("replacement.toml")
    try cataloguePack("review.replacement").write(to: replacement)
    try await runtime.installMissionPack(from: replacement, directory: folder)
    let after = await runtime.snapshot()
    #expect(after.screen == .gallery && after.gallery.detail)
    #expect(after.missionCatalogue.indices.contains(after.gallery.selection))
    #expect(!after.galleryDetailLines(width: 480, font: GameTypography.scale).isEmpty)
  }
}
