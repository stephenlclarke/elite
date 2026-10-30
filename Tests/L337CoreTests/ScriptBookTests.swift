import Foundation
import Testing

@testable import L337Core

private struct BookFixture {
  let root: URL
  let pack: ScriptPack
  var save: URL { root.appendingPathComponent("save/commander.json") }
  init(source: String? = nil, edits: [(String, String)] = []) throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "native-book-" + UUID().uuidString)
    let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
        "docs/mission-packs/reference-book")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let folder = root.appendingPathComponent("pack")
    try FileManager.default.copyItem(at: example, to: folder)
    if let source {
      try source.write(
        to: folder.appendingPathComponent("scripts/main.lua"), atomically: true, encoding: .utf8)
    }
    if !edits.isEmpty {
      let file = folder.appendingPathComponent("manifest.toml")
      var text = try String(contentsOf: file, encoding: .utf8)
      for (old, new) in edits { text = text.replacingOccurrences(of: old, with: new) }
      try text.write(to: file, atomically: true, encoding: .utf8)
    }
    pack = try ScriptPackLibrary.read(folder)
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
  func game() -> Game {
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [pack]
    return game
  }
  func offer(_ runtime: GameRuntime) async throws -> UUID {
    await runtime.key("contacts-open")
    await runtime.key("return")
    let id = try #require(await runtime.snapshot().commander.scriptState.instances.keys.first)
    await runtime.key("contacts-open")
    #expect(await runtime.snapshot().scriptOffer == id)
    return id
  }
}

@Test func nativeBriefingGrantsARetainedBookAndReadingCannotInvokeContactsOrPay() async throws {
  let fixture = try BookFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
  let id = try await fixture.offer(runtime)
  let before = await runtime.snapshot()
  #expect(before.referenceBooks.isEmpty)
  await runtime.key("return")
  let granted = await runtime.snapshot()
  let book = try #require(granted.referenceBooks.first)
  #expect(
    book.instance == id && book.causeKind == "dialogue.confirmed" && book.committed.mainStation)
  #expect(book.source == fixture.pack.manifest.source && book.license == "MIT")
  #expect(granted.commander.scriptState.instances[id]?.outcome == .complete)
  #expect(
    granted.commander.credits == before.commander.credits
      && granted.commander.cargo == before.commander.cargo)
  await runtime.setViewport(width: 512, height: 518)
  await runtime.key("library-open")
  await runtime.key("return")
  await runtime.key("down")
  await runtime.key("return")
  await runtime.key("pagedown")
  await runtime.key("i")
  let source = await runtime.snapshot()
  #expect(source.library.mode == .source)
  #expect(source.libraryTextLines(width: 512).joined().contains("MIT"))
  await runtime.key("i")
  await runtime.key("right")
  await runtime.key("left")
  await runtime.key("k")
  #expect(PlayerHelp.pages(for: await runtime.snapshot()).first?.title == "MISSION LIBRARY")
  await runtime.key("escape")
  for _ in 0..<20 { _ = await runtime.advance(delta: 0.1) }
  let read = await runtime.snapshot()
  #expect(read.commander == granted.commander && read.time == granted.time)
  #expect(read.commander.scriptState.instances[id]?.data["contacts"] == .integer(1))
  #expect(read.referenceBooks.first == book && read.commander.valid)
}

@Test func referenceBookAndReadingCursorReloadWithoutTheOriginalProviderInstalled() async throws {
  let fixture = try BookFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game())
  _ = try await fixture.offer(runtime)
  await runtime.key("return")
  await runtime.setViewport(width: 512, height: 518)
  await runtime.key("library-open")
  await runtime.key("return")
  await runtime.key("down")
  await runtime.key("return")
  await runtime.key("pagedown")
  let before = await runtime.snapshot()
  #expect(before.library.chapter == 1 && before.library.scroll > 0)
  try #require(before.commander.scriptState.calendarLedger != nil)
  try #require(before.commander.scriptState.instances.count == 1)
  try #require(before.commander.scriptState.instances.values.allSatisfy { $0.outcome == .complete })
  let expected = try BodylessCurrentPublicationFixture.commander(before)
  try await runtime.save(to: fixture.save)
  #expect(await runtime.snapshot().commander == expected)
  try BodylessCurrentPublicationFixture.read(fixture.save, expecting: expected)
  let files = try ScriptFinanceTestFixture.files(fixture.root)
  let restored = GameRuntime(game: Game(executive: false))
  await restored.setViewport(width: 512, height: 518)
  try await restored.load(from: fixture.save, persistMigrations: false)
  let actual = await restored.snapshot()
  #expect(actual.scriptPacks.isEmpty && actual.screen == .library)
  #expect(actual.library == before.library && actual.commander == expected)
  #expect(actual.libraryTextLines(width: 512) == before.libraryTextLines(width: 512))
  #expect(actual.referenceBooks == before.referenceBooks && actual.commander.valid)
  #expect(try ScriptFinanceTestFixture.files(fixture.root) == files)
}

@Test func failedReferenceGrantPublicationKeepsTheOfferAndCreatesNoBookOrOutcome() async throws {
  let fixture = try BookFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
  let id = try await fixture.offer(runtime)
  let before = await runtime.snapshot()
  let pointer = try Data(contentsOf: fixture.save)
  let container = fixture.save.deletingLastPathComponent()
  let backup = fixture.root.appendingPathComponent("backup")
  try FileManager.default.moveItem(at: container, to: backup)
  try Data("blocked".utf8).write(to: container)
  await runtime.key("return")
  let denied = await runtime.snapshot()
  #expect(denied.commander == before.commander && denied.referenceBooks.isEmpty)
  #expect(
    denied.scriptOffer == id && denied.scriptPresentedDialogue == before.scriptPresentedDialogue)
  try FileManager.default.removeItem(at: container)
  try FileManager.default.moveItem(at: backup, to: container)
  #expect(try Data(contentsOf: fixture.save) == pointer)
  await runtime.key("return")
  #expect(await runtime.snapshot().referenceBooks.count == 1)
  let (disk, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.save), from: fixture.save)
  #expect(disk.scriptState.books.count == 1 && disk.scriptState.instances[id]?.outcome == .complete)
}

@Test func nativeRequiredBookGateRejectsAStoryFlagWithoutARegisteredBook() throws {
  let fixture = try BookFixture(
    source: """
      return {
        accepted=function(e,w,d) return {data={book=true},commands={
          {op='milestone.ensure',index=0},{op='mission.finish',outcome='complete'}}} end,
        contact=function(e,w,d) return {data=d,commands={}} end,
        confirm=function(e,w,d) return {data=d,commands={}} end
      }
      """)
  defer { fixture.clean() }
  var game = fixture.game()
  let before = game.commander
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(fixture.pack) }
  #expect(game.commander == before && game.referenceBooks.isEmpty)
}

@Test func duplicateNativeUnlockKeepsTheFirstProvenanceAfterTheParentFails() async throws {
  let fixture = try BookFixture(
    source: """
      return {
        accepted=function(e,w,d) return {data=d,commands={{op='book.unlock',id='field-notes'}}} end,
        contact=function(e,w,d) return {data=d,commands={{op='book.unlock',id='field-notes'},
          {op='mission.finish',outcome='failed'}}} end,
        confirm=function(e,w,d) return {data=d,commands={}} end
      }
      """)
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
  await runtime.key("contacts-open")
  await runtime.key("return")
  let original = try #require(await runtime.snapshot().referenceBooks.first)
  await runtime.key("contacts-open")
  let failed = await runtime.snapshot()
  #expect(failed.commander.scriptState.instances[original.instance]?.outcome == .failed)
  #expect(failed.referenceBooks == [original] && original.causeKind == "mission.accepted")
  await runtime.key("library-open")
  #expect(await runtime.snapshot().selectedReferenceBook == original)
  #expect(await runtime.snapshot().commander.valid)
}

@Test func referenceLibraryFreezesNativeFlightAndCalendarAndReturnsToTheSamePhysicalState()
  async throws
{
  let fixture = try BookFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game())
  _ = try await fixture.offer(runtime)
  await runtime.key("return")
  await runtime.key("0")
  await runtime.key("library-open")
  let before = await runtime.snapshot()
  for _ in 0..<100 { _ = await runtime.advance(delta: 0.1) }
  let actual = await runtime.snapshot()
  #expect(actual.commander == before.commander && actual.bodies == before.bodies)
  #expect(actual.time == before.time && actual.celestials == before.celestials)
  #expect(actual.energy == before.energy && actual.speed == before.speed)
  await runtime.key("escape")
  #expect(await runtime.snapshot().screen == .front)
  #expect(await runtime.snapshot().bodies == before.bodies)
}

@Test(arguments: ["text", "owner", "sequence", "digest"])
func retainedBookHashTamperingRefusesLoadBeforeReplacingTheLiveCommander(field: String) async throws
{
  let fixture = try BookFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game(), saveURL: fixture.save)
  _ = try await fixture.offer(runtime)
  await runtime.key("return")
  let before = await runtime.snapshot()
  let bytes = try Data(contentsOf: fixture.save)
  var pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
  let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: fixture.save)
  let chunk = directory.appendingPathComponent("missions.json")
  var state = try #require(
    JSONSerialization.jsonObject(with: Data(contentsOf: chunk)) as? [String: Any])
  var books = try #require(state["savedBooks"] as? [String: Any])
  let key = try #require(before.referenceBooks.first?.key)
  var record = try #require(books[key] as? [String: Any])
  var book = try #require(record["book"] as? [String: Any])
  var chapters = try #require(book["chapters"] as? [[String: Any]])
  if field == "text" { chapters[0]["text"] = "Unverified replacement text." }
  if field == "owner" { record["instance"] = UUID().uuidString }
  if field == "sequence" { record["sequence"] = before.commander.scriptState.nextEvent + 1 }
  if field == "digest" { record["digest"] = String(repeating: "a", count: 64) }
  book["chapters"] = chapters
  record["book"] = book
  books[key] = record
  state["savedBooks"] = books
  let changed = try JSONSerialization.data(withJSONObject: state)
  try changed.write(to: chunk)
  var hashes = pointer.hashes
  hashes["missions.json"] = ScriptPackLibrary.hash(changed)
  pointer = ScriptSavePointer(
    format: pointer.format, schemaVersion: pointer.schemaVersion,
    generation: pointer.generation, hashes: hashes, scope: pointer.scope,
    valueCodec: pointer.valueCodec)
  try JSONEncoder().encode(pointer).write(to: fixture.save)
  await #expect(throws: (any Error).self) { try await runtime.load(from: fixture.save) }
  #expect(await runtime.snapshot().commander == before.commander)
}

@Test func referenceLibraryClickTargetsStayAlignedAtLargeWidthsAndIgnoreInvalidPoints() async throws
{
  let fixture = try BookFixture()
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game())
  _ = try await fixture.offer(runtime)
  await runtime.key("return")
  await runtime.setViewport(width: 1512, height: 982)
  await runtime.key("library-open")
  let before = await runtime.snapshot().commander
  let left = (1512.0 - 700) / 2
  await runtime.libraryClick(x: .nan, y: 100)
  await runtime.libraryClick(x: left + 1, y: .infinity)
  await runtime.libraryClick(x: 0, y: 100)
  #expect(await runtime.snapshot().library.mode == .books)
  await runtime.libraryClick(x: left + 1, y: 100)
  #expect(await runtime.snapshot().library.mode == .contents)
  await runtime.libraryClick(x: left + 1, y: 84 + 44 + 1)
  #expect(await runtime.snapshot().library.mode == .reading)
  #expect(await runtime.snapshot().library.chapter == 1)
  await runtime.libraryClick(x: left + 700 / 2, y: 982 - 60)
  #expect(await runtime.snapshot().library.mode == .source)
  await runtime.libraryClick(x: left + 1, y: 982 - 60)
  #expect(await runtime.snapshot().library.mode == .reading)
  await runtime.libraryClick(x: left + 700 * 0.9, y: 982 - 60)
  #expect(await runtime.snapshot().library.mode == .contents)
  await runtime.key("escape")
  await runtime.key("i")
  await runtime.key("i")
  #expect(await runtime.snapshot().library.mode == .books)
  #expect(await runtime.snapshot().commander == before)
}

@Test func malformedBookContentAndRequiredBookReferencesFailBeforeInstallation() throws {
  let fixture = try BookFixture()
  defer { fixture.clean() }
  let folder = fixture.root.appendingPathComponent("pack")
  let file = folder.appendingPathComponent("manifest.toml")
  let original = try String(contentsOf: file, encoding: .utf8)
  for (before, after) in [
    ("\"library-books-basic-v2\", ", ""),
    ("requiredBooks = [\"field-notes\"]", "requiredBooks = [\"invented\"]"),
    ("requiredBooks = [\"field-notes\"]", "requiredBooks = [\"field-notes\",\"field-notes\"]"),
    ("level=0", "level=5"), ("level=0", "level=-1"),
    ("id=\"preparation\"", "id=\"welcome\""),
    ("id=\"welcome\"", "id=\"welcome\",invented=1"),
    ("title=\"Welcome to the station\"", "title=\"\""),
  ] {
    try original.replacingOccurrences(of: before, with: after).write(
      to: file, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ScriptPackLibrary.read(folder) }
  }
}

@Test func nativeLibraryCapacityRejectsAWholeFurtherGrantWithoutReplacingExistingBooks()
  async throws
{
  let fixture = try BookFixture()
  defer { fixture.clean() }
  var packs: [ScriptPack] = []
  for deck in 0..<3 {
    let folder = fixture.root.appendingPathComponent("deck\(deck)")
    try FileManager.default.createDirectory(
      at: folder.appendingPathComponent("scripts"), withIntermediateDirectories: true)
    let books = (1...32).map { index in
      """
      [[books]]
      id="b\(index)"
      title="Book \(index)"
      chapters=[{id="page",title="Reference",text="Reference text.",level=0}]
      """
    }.joined(separator: "\n")
    try """
    schemaVersion=2
    missionAPI=2
    id="test.book-deck\(deck)"
    version="1.0.0"
    minimumEngine="2.0.0"
    capabilities=["script-lua-v1","story-v2","library-books-basic-v2"]
    priority=460
    source="Original native capacity fixture."
    license="MIT"
    environments=["space","orbital-station"]
    module="scripts/main.lua"
    [mission]
    id="briefing"
    title="Reference deck"
    briefing="Native reference grant capacity fixture."
    destination="Lave"
    reward="Reference books"
    milestones=["Briefing"]
    [[handlers]]
    event="mission.accepted"
    function="accepted"
    \(books)
    """.write(to: folder.appendingPathComponent("manifest.toml"), atomically: true, encoding: .utf8)
    try """
    return {accepted=function(e,w,d)
      local commands={}
      for i=1,32 do commands[i]={op='book.unlock',id='b'..tostring(i)} end
      return {data=d,commands=commands}
    end}
    """.write(
      to: folder.appendingPathComponent("scripts/main.lua"), atomically: true, encoding: .utf8)
    packs.append(try ScriptPackLibrary.read(folder))
  }
  var game = fixture.game()
  game.scriptPacks = packs
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  for _ in 0..<2 {
    await runtime.key("contacts-open")
    await runtime.key("return")
  }
  #expect(await runtime.snapshot().referenceBooks.count == 64)
  await runtime.key("contacts-open")
  let before = await runtime.snapshot()
  await runtime.key("return")
  let denied = await runtime.snapshot()
  #expect(denied.commander == before.commander && denied.referenceBooks == before.referenceBooks)
  #expect(denied.commander.scriptState.instances.count == 2 && denied.commander.valid)
  let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.save), from: fixture.save)
  #expect(saved.scriptState.books == denied.commander.scriptState.books)
}

@Test func longBookTitlesProvidersAndContentHashesStayInsideTheNativeReadingPane() async throws {
  let title = String(repeating: "W", count: 96)
  let provider = "p" + String(repeating: "a", count: 79)
  let fixture = try BookFixture(edits: [
    ("title = \"Station field notes\"", "title = \"\(title)\""),
    ("id = \"example.reference-book\"", "id = \"\(provider)\""),
  ])
  defer { fixture.clean() }
  let runtime = GameRuntime(game: fixture.game())
  _ = try await fixture.offer(runtime)
  await runtime.key("return")
  await runtime.key("library-open")
  await runtime.key("i")
  let game = await runtime.snapshot()
  let frame = Display.referenceLibrary(game, width: 512, height: 518)
  #expect(frame.labels.allSatisfy { $0.bounds.x >= 24 && $0.bounds.maxX <= 488 })
  let lines = game.libraryTextLines(width: 512)
  #expect(lines.allSatisfy { $0.count <= 61 })
  #expect(lines.joined().contains(provider.uppercased()))
  let digest = try #require(game.referenceBooks.first?.digest).uppercased()
  #expect(lines.joined().contains(digest))
  #expect(game.referenceBooks.first?.book.title == title && game.commander.valid)
}
