import Foundation
import Testing

@testable import EliteCore

private let courierURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
  .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
    "docs/mission-packs/courier.toml")
private func packFolder() throws -> URL {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  return url
}
private func courierGame() throws -> (Game, LoadedMissionPack) {
  let entry = try MissionPackLibrary.read(courierURL)
  var game = Game(executive: false)
  game.screen = .status
  game.missionPacks = try .checked(MissionPackLibrary.bundled.entries + [entry])
  return (game, entry)
}
private func modifiedPack(_ edits: [(String, String)], directory: URL) throws -> URL {
  var text = try String(contentsOf: courierURL, encoding: .utf8)
  for (old, new) in edits { text = text.replacingOccurrences(of: old, with: new) }
  let url = directory.appendingPathComponent("pack.toml")
  try text.write(to: url, atomically: true, encoding: .utf8)
  return url
}

@Test func externalCourierInstallsRunsAndPaysExactlyOnceAcrossSaves() async throws {
  let folder = try packFolder()
  defer { try? FileManager.default.removeItem(at: folder) }
  var game = Game(executive: false)
  game.screen = .status
  let runtime = GameRuntime(game: game)
  try await runtime.installMissionPack(from: courierURL, directory: folder)
  let entry = try MissionPackLibrary.read(courierURL)
  game = await runtime.snapshot()
  #expect(game.missionCatalogue.count == 4)
  game.key("b")
  #expect(game.screen == .handoff && game.offeredPack?.pack.id == entry.pack.id)
  game.key("escape")
  #expect(game.commander.missionProgress[entry.pack.stateID] == nil)
  game.key("b")
  game.key("return")
  #expect(game.commander.cargoTonnes == 1 && game.commander.cargo.allSatisfy { $0 == 0 })
  game.screen = .inventory
  #expect(game.informationRows.contains { $0.0.contains("Reserved Lave Courier: parcel 1t") })
  game.screen = .status
  #expect(game.commander.missionProgress[entry.pack.stateID]?.stage == "carrying")
  let save = folder.appendingPathComponent("commander.json")
  let accepted = GameRuntime(game: game)
  try await accepted.save(to: save)
  let restored = GameRuntime()
  await restored.loadMissionPacks(directory: folder)
  try await restored.load(from: save)
  game = await restored.snapshot()
  game.commander.system = 129
  game.dock()
  #expect(game.screen == .handoff)
  game.key("return")
  #expect(game.commander.credits == 1500 && game.commander.cargoTonnes == 0)
  #expect(game.commander.missionProgress[entry.pack.stateID]?.stage == "complete")
  game.dock()
  game.key("b")
  game.confirmPackOffer()
  #expect(game.commander.credits == 1500 && game.commander.valid)
  #expect(game.missionCatalogue.last?.status == .complete)
}

@Test func externalMissionTransfersRecheckLocationHoldAndAccountAtomically() throws {
  var (game, entry) = try courierGame()
  game.key("b")
  let before = game.commander
  game.commander.cargo[0] = 20
  game.key("return")
  #expect(
    game.commander.cargoTonnes == 20 && game.commander.missionProgress == before.missionProgress)
  game.commander.cargo[0] = 0
  game.commander.system = 129
  game.key("return")
  #expect(game.commander.missionProgress[entry.pack.stateID] == nil)
  game.commander.system = 7
  game.key("return")
  #expect(game.commander.missionProgress[entry.pack.stateID]?.stage == "carrying")
  game.commander.system = 129
  game.dock()
  game.commander.credits = 4_294_967_295
  let pending = game.commander
  game.key("return")
  #expect(game.commander == pending && game.screen == .handoff)
  game.commander.credits -= 500
  game.key("return")
  #expect(game.commander.credits == 4_294_967_295 && game.commander.cargoTonnes == 0)
}

@Test func missingOrChangedPacksSuspendWithoutDeletingCargoOrReplayingRewards() throws {
  var (game, entry) = try courierGame()
  game.key("b")
  game.key("return")
  let saved = game.commander
  game.missionPacks = .bundled
  game.dock()
  #expect(game.commander == saved && game.commander.cargoTonnes == 1)
  #expect(game.missingPackGallery.count == 1)
  let directory = try packFolder()
  defer { try? FileManager.default.removeItem(at: directory) }
  let file = try modifiedPack([("50 CR", "100 CR")], directory: directory)
  let changed = try MissionPackLibrary.read(file)
  game.missionPacks = try .checked(MissionPackLibrary.bundled.entries + [changed])
  game.commander.system = 129
  game.dock()
  #expect(game.screen != .handoff && game.commander.credits == saved.credits)
  #expect(game.missionCatalogue.last?.objective.contains("Suspended") == true)
  game.missionPacks = try .checked(MissionPackLibrary.bundled.entries + [entry])
  game.dock()
  game.key("return")
  #expect(game.commander.credits == saved.credits + 500)
}

@Test func packValidationRejectsUnknownMechanicsKeysIDsVersionsAndReferences() throws {
  let directory = try packFolder()
  defer { try? FileManager.default.removeItem(at: directory) }
  let edits: [(String, String)] = [
    ("schemaVersion = 1", "schemaVersion = 2"),
    ("minimumEngine = \"1.0.0\"", "minimumEngine = \"2.0.0\""),
    ("version = \"1.0.0\"", "version = \"latest\""),
    ("state-machine-v1", "passenger-cabins-v1"),
    ("priority = 500", "priority = 1001"),
    ("license = \"MIT\"", "license = \"\""),
    ("initialStage = \"available\"", "initialStage = \"missing\""),
    ("dialog = \"accept\"", "dialog = \"unknown\""),
    ("event = \"contact\"", "event = \"runShell\""),
    ("event = \"contact\"", "event = \"targetDestroyed\""),
    ("confirmation = true", "confirmation = true\nexecutable = \"oops\""),
    ("field = \"galaxy\"", "field = \"glaaxy\""),
    ("op = \"eq\"", "op = \"eval\""),
    ("kind = \"credits\"", "kind = \"creditsWrapped\""),
    ("kind = \"payloadAdd\"", "kind = \"exec\""),
    ("initialStage = \"available\"", "initialStage = \"available\"\nbinding = \"naval\""),
    ("kind = \"credits\", amount = 500", "kind = \"equipmentAdd\", key = \"Magic Engine\""),
    (
      "kind = \"payloadAdd\", key = \"parcel\", amount = 1",
      "kind = \"cargoAdd\", key = \"17\", amount = 1"
    ),
    ("kind = \"credits\", amount = 500", "kind = \"equipmentAdd\", key = \"Military Laser\""),
    ("kind = \"credits\", amount = 500", "kind = \"equipmentAdd\", key = \"Missile\""),
    (
      "kind = \"credits\", amount = 500",
      "kind = \"equipmentRemove\", key = \"Targeting: Military\""
    ),
    ("amount = 500", "amount = -1"),
  ]
  for edit in edits {
    let file = try modifiedPack([edit], directory: directory)
    #expect(throws: (any Error).self) { try MissionPackLibrary.read(file) }
  }
  let entry = try MissionPackLibrary.read(courierURL)
  #expect(throws: MissionPackError.self) { try MissionPackLibrary.checked([entry, entry]) }
  let dependency = try modifiedPack(
    [("priority = 500", "priority = 500\ndependencies = [\"missing.pack@1.0.0\"]")],
    directory: directory)
  let dependent = try MissionPackLibrary.read(dependency)
  #expect(throws: MissionPackError.self) { try MissionPackLibrary.checked([dependent]) }
}

@Test func missionLoaderRejectsSymlinksOversizeAndReportsInvalidInstalledFiles() throws {
  let directory = try packFolder()
  defer { try? FileManager.default.removeItem(at: directory) }
  let link = directory.appendingPathComponent("link.toml")
  try FileManager.default.createSymbolicLink(at: link, withDestinationURL: courierURL)
  #expect(throws: MissionPackError.self) { try MissionPackLibrary.read(link) }
  let oversized = directory.appendingPathComponent("large.toml")
  try Data(repeating: 32, count: 262145).write(to: oversized)
  #expect(throws: MissionPackError.self) { try MissionPackLibrary.read(oversized) }
  let result = MissionPackLibrary.installed(directory: directory)
  #expect(result.entries.count == 3 && result.errors.count == 2)
}

@Test func legacyMigrationPreservesEveryNavalAndBlackjackOutcomeWithoutReplayingActions() throws {
  for stage in NavalMissionStage.allCases {
    var commander = Commander()
    commander.missionStage = stage
    commander.credits = 70000
    var game = Game(executive: false)
    let loaded = game.load(commander)
    #expect(loaded)
    #expect(game.commander.missionStage == stage && game.commander.credits == 70000)
    for entry in game.missionPacks.entries where entry.pack.mission.binding == "naval" {
      #expect(
        entry.pack.stage(game.progress(for: entry).stage)?.legacyValues?.contains(stage.rawValue)
          == true)
    }
    let twice = game.commander
    let loadedTwice = game.load(twice)
    #expect(loadedTwice && game.commander == twice)
  }
  for stage in BlackjackStage.allCases {
    var commander = Commander()
    commander.blackjack.stage = stage
    let milestones: [(BlackjackTransfer, Int)] = [
      (.contact, 1), (.goldAward, 2), (.goldDelivery, 2), (.report, 3), (.firearmPickup, 4),
      (.robberyHandoff, 5), (.finalReward, 7),
    ]
    commander.blackjack.transfers = Set(milestones.filter { stage.progress >= $0.1 }.map(\.0))
    if stage == .deliverFirearm { commander.cargo[10] = 1 }
    var game = Game(executive: false)
    let loaded = game.load(commander)
    #expect(loaded)
    #expect(game.commander.blackjack == commander.blackjack)
    #expect(game.commander.credits == commander.credits && game.commander.cargo == commander.cargo)
  }
}

@Test func missionClockFreezesInPanelsAndSurvivesSaveLoadWithBoundedOneStepTransitions()
  async throws
{
  let directory = try packFolder()
  defer { try? FileManager.default.removeItem(at: directory) }
  let clockFile = try modifiedPack(
    [
      ("\"cargo-v1\"]", "\"cargo-v1\", \"clock-v1\"]"),
      (
        "event = \"contact\"\nto = \"complete\"\nconfirmation = true\ndialog = \"delivery\"",
        "event = \"clock\"\nto = \"complete\""
      ),
      (
        "conditions = [{ field = \"galaxy\", op = \"eq\", value = 0 }, { field = \"system\", op = \"eq\", value = 129 }, { field = \"mainStation\", op = \"eq\", value = 1 }, { field = \"payload:parcel\", op = \"eq\", value = 1 }]",
        "conditions = [{ field = \"stageSeconds\", op = \"ge\", value = 0.2 }]"
      ),
    ], directory: directory)
  let entry = try MissionPackLibrary.read(clockFile)
  var game = Game(executive: false)
  game.missionPacks = try .checked(MissionPackLibrary.bundled.entries + [entry])
  game.screen = .status
  game.key("b")
  game.key("return")
  game.launch()
  game.bodies = []
  game.tick(delta: 0.1)
  #expect(game.commander.missionProgress[entry.pack.stateID]?.seconds == 0.1)
  for screen in [Screen.help, .gallery, .navigation, .showroom, .handoff, .rumour, .secret] {
    game.screen = screen
    game.tick(delta: 0.1)
    #expect(game.commander.missionProgress[entry.pack.stateID]?.seconds == 0.1)
  }
  game.screen = .front
  game.paused = true
  game.tick(delta: 0.1)
  #expect(game.commander.missionProgress[entry.pack.stateID]?.seconds == 0.1)
  let runtime = GameRuntime(game: game)
  let save = directory.appendingPathComponent("save.json")
  try await runtime.save(to: save)
  try await runtime.load(from: save)
  game = await runtime.snapshot()
  #expect(game.commander.missionProgress[entry.pack.stateID]?.seconds == 0.1)
  game.launch()
  game.bodies = []
  game.tick(delta: 0.1)
  #expect(game.commander.missionProgress[entry.pack.stateID]?.stage == "complete")
  #expect(game.commander.credits == 1500)
}

@Test func contactsHaveDeterministicPriorityAndDoNotCascadeWithinOneEvent() throws {
  var (game, entry) = try courierGame()
  game.commander.kills = 256
  game.dock()
  #expect(game.screen == .mission && game.packOffer == nil)
  for _ in 0..<21 { game.tick(delta: 0.1) }
  game.key("escape")
  #expect(game.screen == .handoff && game.offeredPack?.pack.id == entry.pack.id)
  #expect(game.commander.missionProgress[entry.pack.stateID] == nil)
  game.key("return")
  #expect(game.commander.missionProgress[entry.pack.stateID]?.stage == "carrying")
  #expect(game.screen == .status)
}

@Test func installationDetectsDiskConflictsAndSavedVersionMismatchesWithoutReplacingFiles()
  async throws
{
  let folder = try packFolder()
  let drafts = try packFolder()
  defer {
    try? FileManager.default.removeItem(at: folder)
    try? FileManager.default.removeItem(at: drafts)
  }
  let runtime = GameRuntime()
  try await runtime.installMissionPack(from: courierURL, directory: folder)
  try await runtime.installMissionPack(from: courierURL, directory: folder)
  let destination = folder.appendingPathComponent("xyzzy.example.courier.toml")
  let original = try Data(contentsOf: destination)
  let changed = try modifiedPack([("50 CR", "75 CR")], directory: drafts)
  await #expect(throws: MissionPackError.self) {
    try await runtime.installMissionPack(from: changed, directory: folder)
  }
  #expect(try Data(contentsOf: destination) == original)
  var (game, _) = try courierGame()
  game.key("b")
  game.key("return")
  let active = GameRuntime(game: game)
  await #expect(throws: MissionPackError.self) {
    try await active.installMissionPack(from: changed, directory: folder)
  }
  #expect(try Data(contentsOf: destination) == original)
  try Data("bad TOML".utf8).write(to: folder.appendingPathComponent("broken.toml"))
  await #expect(throws: MissionPackError.self) {
    try await runtime.installMissionPack(from: courierURL, directory: folder)
  }
  #expect(try Data(contentsOf: destination) == original)
}

@Test func externalDockEventCommitsOnceAndLongDialogsStayBoundedAtCompactSizes() throws {
  let folder = try packFolder()
  defer { try? FileManager.default.removeItem(at: folder) }
  let file = try modifiedPack([("event = \"contact\"", "event = \"dock\"")], directory: folder)
  let entry = try MissionPackLibrary.read(file)
  var game = Game(executive: false)
  game.missionPacks = try .checked(MissionPackLibrary.bundled.entries + [entry])
  game.screen = .status
  game.dock()
  game.key("return")
  #expect(game.commander.cargoTonnes == 1)
  game.commander.system = 129
  game.dock()
  game.key("return")
  #expect(game.commander.credits == 1500 && game.commander.cargoTonnes == 0)
  game.dock()
  #expect(game.commander.credits == 1500)
  let longFile = try modifiedPack(
    [
      (
        "Carry this one-tonne sealed parcel to Zaonce for 50 CR? Confirm accepts; Back leaves it here.",
        String(repeating: "A long message still needs readable pages. ", count: 100)
      )
    ], directory: folder)
  let long = try MissionPackLibrary.read(longFile)
  game = Game(executive: false)
  game.screen = .status
  game.missionPacks = try .checked(MissionPackLibrary.bundled.entries + [long])
  game.viewportWidth = 512
  game.viewportHeight = 518
  game.key("b")
  #expect(game.packDialogWindow.last > 0)
  game.key("pagedown")
  #expect(game.packDialogWindow.offset == 8)
  game.key("pageup")
  #expect(game.packDialogWindow.offset == 0)
  let frame = Display.blackjackHandoff(game, width: 512, height: 518)
  #expect(frame.labels.allSatisfy { $0.bounds.maxX <= 512 && $0.bounds.maxY <= 518 })
  game.openGallery()
}

@Test func loadingAnotherCommanderResetsGallerySelectionAndKeepsCommonFootersContextual() throws {
  var (game, _) = try courierGame()
  game.openGallery()
  game.gallery.selection = 3
  game.gallery.detail = true
  let loaded = game.load(Commander())
  #expect(loaded && game.gallery.selection == 0 && !game.gallery.detail)
  game.missionPacks = .bundled
  game.openGallery()
  #expect(!Display.render(game).labels.isEmpty)
  for screen in [Screen.status, .inventory] {
    game.screen = screen
    let labels = Display.presentation(game, width: 512, height: 518).labels.map(\.text)
    #expect(!labels.contains { $0.contains("6: showroom") || $0.contains("6: system data") })
    #expect(labels.contains { $0.contains("Esc: back") && $0.contains("K: help") })
  }
}

@Test func timedMissionFailureStaysFailedAfterDockAndReloadWithoutPayingAReward() async throws {
  let folder = try packFolder()
  defer { try? FileManager.default.removeItem(at: folder) }
  let file = try modifiedPack([("\"cargo-v1\"]", "\"cargo-v1\", \"clock-v1\"]")], directory: folder)
  let failure = """

    [[stages]]
    id = "failed"
    objective = "The parcel deadline expired."
    completed = 1
    terminal = true
    outcome = "failed"
    [[transitions]]
    id = "expiry"
    from = "carrying"
    event = "clock"
    to = "failed"
    conditions = [{ field = "stageSeconds", op = "ge", value = 0.1 }]
    actions = [{ kind = "payloadRemove", key = "parcel", amount = 1 }]
    """
  let original = try String(contentsOf: file, encoding: .utf8)
  try (original + failure).write(to: file, atomically: true, encoding: .utf8)
  let entry = try MissionPackLibrary.read(file)
  var game = Game(executive: false)
  game.missionPacks = try .checked(MissionPackLibrary.bundled.entries + [entry])
  game.screen = .status
  game.key("b")
  game.key("return")
  game.launch()
  game.bodies = []
  game.tick(delta: 0.1)
  #expect(game.commander.credits == 1000 && game.commander.cargoTonnes == 0)
  #expect(game.missionCatalogue.last?.status == .failed)
  #expect(game.missionCatalogue.last?.completed == 1)
  game.commander.system = 129
  game.dock()
  game.key("b")
  #expect(game.commander.credits == 1000 && game.screen != .handoff)
  let runtime = GameRuntime(game: game)
  let save = folder.appendingPathComponent("failed.json")
  try await runtime.save(to: save)
  try await runtime.load(from: save)
  #expect(await runtime.snapshot().missionCatalogue.last?.status == .failed)
  let outgoing = """

    [[transitions]]
    id = "retry"
    from = "failed"
    event = "contact"
    to = "available"
    """
  try (original + failure + outgoing).write(to: file, atomically: true, encoding: .utf8)
  #expect(throws: MissionPackError.self) { try MissionPackLibrary.read(file) }
}
