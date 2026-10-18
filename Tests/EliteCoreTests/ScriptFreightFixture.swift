import Darwin
import Foundation
import Testing

@testable import EliteCore

struct ScriptFreightFixture {
  let root: URL
  let pack: ScriptPack
  var save: URL { root.appendingPathComponent("save/commander.json") }
  init() throws {
    let path = FileManager.default.temporaryDirectory.path
    let resolved = path.withCString { realpath($0, nil) }
    let physical = try #require(resolved)
    defer { free(physical) }
    root = URL(fileURLWithPath: String(cString: physical), isDirectory: true)
      .appendingPathComponent("freight-" + UUID().uuidString, isDirectory: true)
    let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/generated-supplied-freight")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    do {
      let destination = root.appendingPathComponent("pack")
      try FileManager.default.copyItem(at: source, to: destination)
      pack = try ScriptPackLibrary.read(destination)
    } catch {
      try? FileManager.default.removeItem(at: root)
      throw error
    }
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
  func policyGame() throws -> Game {
    var game = Game(executive: false)
    game.screen = .status
    game.commander.system = 0
    game.selectedSystem = 0
    try game.commander.prepareEquipment(legacy: false)
    game.commander.mirrorFittedEquipment()
    game.scriptPacks = [pack]
    game.scriptDurabilityAvailable = true
    game.ensureMissionCalendar()
    return game
  }
  func plans(_ game: Game) throws -> [ScriptFreightPlan] {
    let key = pack.digest + "/" + pack.manifest.board!.id + "/" + game.contractStation.key
    let seed = try #require(Game.pledgeBoardSeed(key, revision: 0))
    return try ScriptFreightGeneration.plans(
      pack: pack, commander: game.commander,
      origin: game.contractStation, revision: 0, seed: seed)
  }
  func nativeRuntime(escapeReady: Bool = false) async throws
    -> GameRuntime
  {
    var game = Game(executive: false)
    game.screen = .status
    game.commander.system = 0
    game.selectedSystem = 0
    game.commander.credits = 100000
    game.market = MarketItem.at(game.currentSystem, fluctuation: 0)
    game.scriptPacks = [pack]
    let cargo = game.commander.cargo
    try game.prepareG03FlightEquipment()
    if escapeReady {
      let item = try #require(Equipment.all.first { $0.name == "Escape Pod" })
      let quote = try game.quoteEquipmentPurchase(item)
      let debit = quote.purchase.requiredDebit
      try #require(debit == 10000)
      let fitted = try game.applyEquipmentPurchase(quote)
      try #require(fitted)
    }
    try ScriptProcurementFixture.requirePaidG03Preparation(game, escapeReady: escapeReady)
    try #require(game.commander.cargo == cargo)
    let runtime = GameRuntime(game: game, saveURL: save)
    try await runtime.save(to: save)
    await runtime.key("0")
    try await ScriptProcurementFixture.dock(runtime)
    return runtime
  }
  func accepted(row: Int = 0, escapeReady: Bool = false) async throws -> (
    GameRuntime, UUID, ScriptFreightPlan
  ) {
    let runtime = try await nativeRuntime(escapeReady: escapeReady)
    let key = try await runtime.generateContractBoard(packDigest: pack.digest)
    let before = await runtime.snapshot()
    let offer = try #require(before.commander.contracts.boards[key]?.offers[row])
    let plan = try #require(offer.freightPlan)
    let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
    let allowed = quote.allowed
    try #require(allowed, "Freight quote: \(quote.issues.prefix(3).joined(separator: "; "))")
    let id = try await runtime.confirmContract(quote)
    return (runtime, id, plan)
  }
  static func confirm(_ runtime: GameRuntime, all: Bool = false) async throws {
    let shown = await runtime.snapshot()
    if all { await runtime.key("down") }
    if !shown.scriptConfirmSelected { await runtime.key("left") }
    await runtime.key("return")
  }
  func blockWrites(_ label: String, destination: URL? = nil) throws -> URL {
    let parent = (destination ?? save).deletingLastPathComponent()
    let preserved = root.appendingPathComponent("preserved-" + label)
    try FileManager.default.moveItem(at: parent, to: preserved)
    try Data([1]).write(to: parent)
    return preserved
  }
  func restoreWrites(_ preserved: URL, files: [String: Data], destination: URL? = nil) throws {
    let parent = (destination ?? save).deletingLastPathComponent()
    let blocker = try Data(contentsOf: parent)
    let retained = try ScriptFinanceTestFixture.files(preserved)
    #expect(blocker == Data([1]) && retained == files)
    try FileManager.default.removeItem(at: parent)
    try FileManager.default.moveItem(at: preserved, to: parent)
  }
  /// Controlled calendar semantics on a genuine partial snapshot, not elapsed-flight evidence.
  func checkDeadlineAndExpiryBoundaries(_ partial: Game, id: UUID) throws {
    let state = try #require(partial.commander.scriptState.instances[id])
    let due = try #require(state.contract?.deadline)
    let plan = try #require(state.contract?.offer.freightPlan)
    let cargo = try #require(state.savedOwnedCargo)
    let dialogue = try #require(partial.scriptPresentedDialogue)
    try #require(!cargo.transfers.isEmpty && !cargo.held.isEmpty)
    var boundary = partial
    boundary.commander.scriptState.missionCalendar?.seconds = due
    boundary.commander.scriptState.calendarSeconds = max(
      boundary.commander.scriptState.calendarSeconds, due)
    try #require(boundary.commander.valid)
    let atDeadline = boundary.commander
    boundary.resolveFreightTerminals()
    #expect(boundary.commander == atDeadline)
    boundary.key("down")
    try #require(boundary.selectedScriptChoice?.id == "freight-all")
    try boundary.confirmFreightDialogue(id, dialogue: dialogue, choice: "freight-all")
    let delivered = try #require(boundary.commander.scriptState.instances[id])
    #expect(delivered.outcome == .complete && delivered.contract?.settledAt == due)
    #expect(
      delivered.savedOwnedCargo?.terminal?.clock == due && boundary.commander.freightCargoValid)
    #expect(boundary.commander.credits == partial.commander.credits + plan.reward)
    // Expiry publishes a separate copy so the genuine runtime and its travel clocks stay intact.
    var expired = partial
    expired.commander.scriptState.missionCalendar?.seconds = due + 1
    expired.commander.scriptState.calendarSeconds = max(
      expired.commander.scriptState.calendarSeconds, due + 1)
    try #require(
      expired.commander.valid && expired.scriptWorldSave.consistent(with: expired.commander))
    let before = expired.commander
    var control = expired
    control.resolveFreightTerminals()
    let terminal = try #require(control.commander.scriptState.instances[id])
    try #require(terminal.savedOwnedCargo?.terminal?.cause == .expired && control.commander.valid)
    let destination = root.appendingPathComponent("expiry-boundary/commander.json")
    _ = try ScriptSaveStore.write(
      commander: before, world: expired.scriptWorldSave, to: destination)
    let files = try ScriptFinanceTestFixture.files(destination.deletingLastPathComponent())
    let preserved = try blockWrites("expiry", destination: destination)
    let publish: ScriptPublisher = { candidate in
      _ = try ScriptSaveStore.write(
        commander: candidate.commander, world: candidate.scriptWorldSave, to: destination)
    }
    expired.resolveFreightTerminals(publish: publish)
    #expect(expired.commander == before)
    try restoreWrites(preserved, files: files, destination: destination)
    expired.resolveFreightTerminals(publish: publish)
    let retried = try #require(expired.commander.scriptState.instances[id])
    #expect(retried == terminal && retried.savedOwnedCargo?.terminal?.removed == cargo.held)
    #expect(retried.collections == state.collections && expired.commander.credits == before.credits)
    let bytes = try Data(contentsOf: destination)
    let (cold, world) = try ScriptSaveStore.read(bytes, from: destination)
    #expect(cold.scriptState.instances[id] == retried && world.consistent(with: cold))
  }
  func rejectContactChanges(_ genuine: Game, id: UUID) throws {
    let dialogue = try #require(genuine.scriptPresentedDialogue)
    let state = try #require(genuine.commander.scriptState.instances[id])
    let plan = try #require(state.contract?.offer.freightPlan)
    let files = try ScriptFinanceTestFixture.files(save.deletingLastPathComponent())
    for field in ["stale", "destination", "source", "owner", "choice", "missing-pack"] {
      var changed = genuine
      var choice = "freight-one"
      switch field {
      case "stale": changed.commander.scriptState.instances[id]?.revision += 1
      case "destination": changed.commander.system = plan.origin.system
      case "source": changed.commander.nativeStations?.currentMainDock = nil
      case "owner":
        changed.commander = try Self.forgedCargo(genuine, id: id) {
          $0["owner"] = UUID().uuidString
        }
      case "choice": choice = "freight-all"
      default: changed.scriptPacks = []
      }
      let before = changed.commander
      #expect(throws: MissionPackError.self) {
        try changed.confirmFreightDialogue(id, dialogue: dialogue, choice: choice)
      }
      let afterFiles = try ScriptFinanceTestFixture.files(save.deletingLastPathComponent())
      #expect(changed.commander == before && afterFiles == files, "Contact guard: \(field)")
    }
  }
  static func forgedState(_ game: Game, id: UUID, change: (inout [String: Any]) -> Void) throws
    -> Commander
  {
    let state = try #require(game.commander.scriptState.instances[id])
    let encoded = try ScriptValueStorage.encoder().encode(state)
    let decoded = try JSONSerialization.jsonObject(with: encoded)
    var object = try #require(decoded as? [String: Any])
    change(&object)
    let bytes = try JSONSerialization.data(withJSONObject: object)
    var changed = game.commander
    changed.scriptState.instances[id] = try ScriptValueStorage.decoder(typed: true).decode(
      ScriptInstance.self, from: bytes)
    return changed
  }
  func rejectForgedState(_ changed: Commander, genuine game: Game, runtime: GameRuntime)
    async throws
  {
    #expect(!changed.freightCargoValid && !changed.valid)
    let originalFiles = try ScriptFinanceTestFixture.files(save.deletingLastPathComponent())
    #expect(throws: SaveError.self) {
      _ = try ScriptSaveStore.write(commander: changed, world: game.scriptWorldSave, to: save)
    }
    let unchangedFiles = try ScriptFinanceTestFixture.files(save.deletingLastPathComponent())
    #expect(unchangedFiles == originalFiles)
    // Resign the genuine generation: rejection must authenticate history, not just its checksum.
    let pointerBytes = try Data(contentsOf: save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: save)
    let missions = try ScriptValueStorage.encoder().encode(changed.scriptState)
    try missions.write(to: directory.appendingPathComponent("missions.json"))
    var hashes = pointer.hashes
    hashes["missions.json"] = ScriptPackLibrary.hash(missions)
    let forgedPointer = ScriptSavePointer(
      format: pointer.format, schemaVersion: pointer.schemaVersion,
      generation: pointer.generation, hashes: hashes, scope: pointer.scope,
      valueCodec: pointer.valueCodec)
    let forgedBytes = try JSONEncoder().encode(forgedPointer)
    #expect(throws: (any Error).self) {
      _ = try ScriptSaveStore.read(forgedBytes, from: save)
    }
    try forgedBytes.write(to: save)
    let badFiles = try ScriptFinanceTestFixture.files(save.deletingLastPathComponent())
    await #expect(throws: (any Error).self) {
      try await runtime.load(from: save, persistMigrations: false)
    }
    let afterReadFiles = try ScriptFinanceTestFixture.files(save.deletingLastPathComponent())
    let retained = await runtime.snapshot()
    #expect(badFiles == afterReadFiles && retained.commander == game.commander)
  }
  static func forgedCargo(_ game: Game, id: UUID, change: (inout [String: Any]) -> Void) throws
    -> Commander
  {
    let cargo = try #require(game.commander.scriptState.instances[id]?.savedOwnedCargo)
    let encoded = try JSONEncoder().encode(cargo)
    let decodedObject = try JSONSerialization.jsonObject(with: encoded)
    var object = try #require(decodedObject as? [String: Any])
    change(&object)
    let bytes = try JSONSerialization.data(withJSONObject: object)
    var changed = game.commander
    changed.scriptState.instances[id]?.savedOwnedCargo = try JSONDecoder().decode(
      ScriptOwnedCargoState.self, from: bytes)
    return changed
  }
}

extension GameRuntime {
  /// Controlled combat boundary on genuine issued custody, not a flight-survival oracle.
  func freightFatalHit() throws {
    let id = game.nextBodyID
    game.nextBodyID += 1
    game.bodies.append(.init(id: id, hull: .cobra, position: .init(0, 0, 500), hostile: true))
    game.ensurePhysicalActors()
    let source = try #require(game.bodies.first { $0.id == id })
    let owner = try #require(source.physical?.identity)
    let contact = try game.nearestMissionCollision(
      from: source.position,
      direction: source.position.unit * -1, range: source.position.length + 1,
      radius: 0, excludingBodyIDs: [id], includePlayer: true)
    let hit = try #require(contact?.hit)
    try #require(hit.target == .player)
    let allocated = game.makeAttackOrigin(owner: owner)
    let origin = try #require(allocated)
    let damage = game.energy + game.frontShield + game.rearShield + 1
    let recorded = game.applyCombatHit(hit, origin: origin, kind: .laser, damage: damage)
    try #require(recorded != nil)
  }
}
