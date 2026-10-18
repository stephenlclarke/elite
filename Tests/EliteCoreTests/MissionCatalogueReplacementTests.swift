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
    let commander = game.commander
    let nativeName = "Native crew capture and escape-pod rescue"
    game.replaceMissionPacks(try .checked([first, selected]))
    let initial = game.missionCatalogue
    try #require(initial.count == 3)
    #expect(
      game.missionPacks.entries.map { $0.pack.stateID } == [
        first.pack.stateID, selected.pack.stateID,
      ])
    #expect(
      initial.map(\.name) == [first.pack.mission.title, selected.pack.mission.title, nativeName])
    game.screen = .gallery
    game.gallery.selection = 1
    game.gallery.detail = true
    game.replaceMissionPacks(try .checked([earlier, first, selected]))
    let inserted = game.missionCatalogue
    try #require(inserted.count == 4)
    #expect(
      game.missionPacks.entries.map { $0.pack.stateID } == [
        earlier.pack.stateID, first.pack.stateID, selected.pack.stateID,
      ])
    #expect(
      inserted.map(\.name) == [
        earlier.pack.mission.title, first.pack.mission.title, selected.pack.mission.title,
        nativeName,
      ])
    #expect(game.gallery.selection == 2 && game.gallery.detail)
    #expect(game.missionPacks.entries[game.gallery.selection].pack.stateID == selected.pack.stateID)
    game.gallery.scroll = 8
    game.replaceMissionPacks(try .checked([first]))
    let removed = game.missionCatalogue
    try #require(removed.count == 2)
    #expect(game.missionPacks.entries.map { $0.pack.stateID } == [first.pack.stateID])
    #expect(removed.map(\.name) == [first.pack.mission.title, nativeName])
    #expect(game.gallery.selection == 1 && game.gallery.scroll == 0 && game.gallery.detail)
    #expect(game.selectedGalleryMission?.trialDigest == NativePeopleGallery.digest)
    #expect(!game.galleryDetailLines(width: 480, font: GameTypography.scale).isEmpty)
    // Both surviving rows remain reachable through ordinary Gallery controls.
    game.galleryKey("tab")
    game.galleryKey("up")
    #expect(game.gallery.selection == 0 && !game.gallery.detail)
    #expect(game.selectedGalleryMission?.name == first.pack.mission.title)
    #expect(game.selectedGalleryMission?.trialDigest == nil)
    game.galleryKey("down")
    game.galleryKey("return")
    #expect(game.gallery.selection == 1 && game.gallery.detail)
    #expect(game.selectedGalleryMission?.trialDigest == NativePeopleGallery.digest)
    game.gallery.selection = 99
    #expect(game.selectedGalleryMission == nil)
    #expect(game.galleryDetailLines(width: 480, font: GameTypography.scale).isEmpty)
    game.galleryKey("pagedown")
    #expect(game.gallery.selection == 1)
    #expect(game.selectedGalleryMission?.name == nativeName)
    #expect(game.selectedGalleryMission?.trialDigest == NativePeopleGallery.digest)
    #expect(!game.galleryDetailLines(width: 480, font: GameTypography.scale).isEmpty)
    let nativeScroll = game.gallery.scroll
    game.replaceMissionPacks(try .checked([]))
    let emptyPacks = game.missionCatalogue
    try #require(emptyPacks.count == 1 && game.missionPacks.entries.isEmpty)
    #expect(game.gallery.selection == 0)
    #expect(game.gallery.scroll == nativeScroll && game.gallery.detail)
    #expect(emptyPacks.map(\.name) == [nativeName])
    #expect(game.selectedGalleryMission?.trialDigest == NativePeopleGallery.digest)
    #expect(!game.galleryDetailLines(width: 480, font: GameTypography.scale).isEmpty)
    game.galleryKey("return")
    #expect(game.gallery.selection == 0 && game.gallery.detail && game.gallery.scroll == 0)
    #expect(game.selectedGalleryMission?.trialDigest == NativePeopleGallery.digest)
    #expect(!game.galleryDetailLines(width: 480, font: GameTypography.scale).isEmpty)
    for catalogue in [initial, inserted, removed, emptyPacks] {
      for entry in catalogue.dropLast() {
        #expect(entry.status == .locked && entry.completed == 0)
        #expect(entry.trialDigest == nil && entry.savedInstance == nil)
        #expect(entry.milestones.map(\.title) == ["Finish"])
        #expect(entry.milestones.map(\.state) == ["Locked"])
      }
      let native = try #require(catalogue.last)
      #expect(native.trialDigest == NativePeopleGallery.digest && native.savedInstance == nil)
      #expect(native.name == nativeName && native.status == .available && native.completed == 0)
      #expect(
        native.milestones.map(\.title) == [
          "Actually disable an admitted ordinary crewed craft",
          "Track and collect a real occupied capsule",
          "Capture original crew still aboard before recovery",
          "Confirm care or an original-person sale",
        ])
      #expect(native.milestones.map(\.state) == Array(repeating: "Trial", count: 4))
    }
    #expect(game.commander == commander)
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
