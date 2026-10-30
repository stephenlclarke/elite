import Darwin
import Foundation
import Testing

@testable import L337Core

/// The catalog is held only by this fixture and passed to internal native transactions.
/// Its executable digest is never registered globally or trusted by a production loader.
struct ScriptClueFixture {
  let root: URL
  let pack: ScriptPack
  let trust: ScriptClueTrustCatalog
  var save: URL { root.appendingPathComponent("save/commander.json") }

  init(
    outcome: String = "complete", edition: String = "1.0.0", acceptanceFinish: Bool = false,
    packID: String = "l337.glass-meridian", settlement: Int = 7, finish: Bool = true
  )
    throws
  {
    let path = FileManager.default.temporaryDirectory.path
    let resolved = path.withCString { realpath($0, nil) }
    let physical = try #require(resolved)
    defer { free(physical) }
    root = URL(fileURLWithPath: String(cString: physical), isDirectory: true)
      .appendingPathComponent("native-clue-" + UUID().uuidString, isDirectory: true)
    let folder = root.appendingPathComponent("pack")
    try FileManager.default.createDirectory(
      at: folder.appendingPathComponent("scripts"), withIntermediateDirectories: true)
    try """
    schemaVersion = 2
    missionAPI = 2
    id = "\(packID)"
    version = "\(edition)"
    minimumEngine = "2.0.0"
    capabilities = ["script-lua-v1", "story-v2", "economy-v2", "gallery-basic-v2"]
    priority = 460
    source = "Original minimal native clue regression fixture, not campaign content."
    license = "MIT"
    environments = ["space", "orbital-station"]
    module = "scripts/main.lua"
    [mission]
    id = "fixture"
    title = "Native clue fixture"
    briefing = "Reopen contacts and confirm."
    destination = "Main orbital station"
    reward = "One native fixture settlement"
    milestones = ["Confirm"]
    [[handlers]]
    event = "mission.accepted"
    function = "accepted"
    [[handlers]]
    event = "contact.requested"
    function = "contact"
    [[handlers]]
    event = "dialogue.confirmed"
    function = "confirm"
    [[dialogs]]
    id = "settle"
    text = "Confirm the fixture settlement."
    """.write(to: folder.appendingPathComponent("manifest.toml"), atomically: true, encoding: .utf8)
    let accepted =
      acceptanceFinish
      ? "{{op='milestone.ensure',index=0},{op='mission.finish',outcome='complete'}}" : "{}"
    let terminal = finish ? ",{op='mission.finish',outcome='\(outcome)'}" : ""
    try """
    return {
      accepted=function(e,w,d) return {data=d,commands=\(accepted)} end,
      contact=function(e,w,d) return {data=d,commands={{op='dialogue.offer',id='settle'}}} end,
      confirm=function(e,w,d)
        return {data=d,commands={{op='dialogue.commit',id='settle',token=e.token},
          {op='credits',amount=\(settlement),id='settlement'},
          {op='milestone.ensure',index=0}\(terminal)}}
      end
    }
    """.write(
      to: folder.appendingPathComponent("scripts/main.lua"), atomically: true, encoding: .utf8)
    pack = try ScriptPackLibrary.read(folder)
    trust = try ScriptClueTrustCatalog(pins: [
      .init(
        sourceID: "l337.glass-meridian", definition: pack.manifest.stateID,
        version: pack.manifest.version, digest: pack.digest,
        terminalEvents: ["dialogue.confirmed"])
    ])
  }

  func clean() { try? FileManager.default.removeItem(at: root) }

  func game(alien: Bool = false) throws -> Game {
    var game = Game(executive: false)
    game.screen = .status
    if alien {
      try game.commander.initializeEquipment(
        owner: AlienStorageTestFixture.owner, hull: AlienStorageTestFixture.hull,
        legacy: false, allocatingItemIDs: { UUID() })
      var storage = AlienStorageTestFixture()
      _ = try storage.acquire(kind: .energyCapacity)
      try game.commander.replaceAlienStorage(with: storage.snapshot)
    } else {
      try game.commander.prepareEquipment(legacy: false)
    }
    game.scriptPacks = [pack]
    return game
  }

  /// Normal contact and confirmation guards create the event and its native context/token.
  /// Defer only dispatch so the test can supply its immutable native trust value/publisher.
  func queueSettlement(_ game: inout Game) throws -> UUID {
    let id = try game.acceptScriptMission(pack)
    game.emitScriptEvent("contact.requested", only: id)
    let shown = game.showScriptDialogue(only: id)
    try #require(shown && game.scriptOffer == id)
    let dialogue = try #require(game.scriptPresentedDialogue)
    game.scriptEventsDeferred = true
    game.confirmScriptDialogue()
    game.scriptEventsDeferred = false
    try #require(
      game.commander.scriptState.pendingEvents.contains {
        $0.instance == id && $0.kind == "dialogue.confirmed"
          && $0.values["token"] == .string(dialogue.token) && $0.context != nil
      })
    return id
  }

  func completed() throws -> (Game, UUID) {
    var game = try game()
    let id = try queueSettlement(&game)
    game.drainScriptEvents(clueTrust: trust)
    try #require(game.commander.scriptState.instances[id]?.outcome == .complete)
    try #require(game.commander.scriptState.savedClueJournal?.awards.count == 1)
    return (game, id)
  }
}
