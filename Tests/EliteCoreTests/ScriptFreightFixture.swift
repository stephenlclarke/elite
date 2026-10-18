import Foundation
import Testing

@testable import EliteCore

struct ScriptFreightFixture {
  let root: URL
  let pack: ScriptPack
  var save: URL { root.appendingPathComponent("save/commander.json") }
  init() throws {
    root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent("freight-" + UUID().uuidString)
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
    let budget = game.commander.credits
    var paid = 0
    for tier in [TargetingTier.basic, .advanced, .docking] {
      let index = try #require(Equipment.all.firstIndex { $0.name == tier.equipmentName })
      let price = game.shopPrice(Equipment.all[index])
      let creditsBefore = game.commander.credits
      let previousReceipts = game.commander.equipmentPurchaseHistory?.paid ?? []
      let previousLegacy = game.commander.equipmentPurchaseHistory?.legacy
      let previousItems = game.commander.equipmentInventory?.items ?? []
      game.selection = index
      game.purchase()
      let inventory = try #require(game.commander.equipmentInventory)
      let history = try #require(game.commander.equipmentPurchaseHistory)
      let receipt = try #require(history.paid.last)
      let fitted = try #require(game.commander.fittedEquipment(at: .targetingCore))
      try #require(price > 0 && game.commander.credits == creditsBefore - price)
      try #require(game.commander.targetingTier == tier && game.commander.equipmentStateValid)
      try #require(history.paid.count == previousReceipts.count + 1)
      try #require(Array(history.paid.prefix(previousReceipts.count)) == previousReceipts)
      if let previousLegacy { try #require(history.legacy == previousLegacy) }
      try #require(
        history.legacy.allSatisfy {
          !$0.lineage.contains { $0.family == EquipmentPurchaseCatalog.targeting }
        })
      try #require(
        receipt.owner == inventory.owner && receipt.node.key == tier.equipmentName
          && receipt.node.family == EquipmentPurchaseCatalog.targeting
          && receipt.node == fitted.node
          && receipt.price == price && receipt.binding.request.newItem == fitted.id
          && fitted.provenance == .paid(owner: inventory.owner, transaction: receipt.transaction)
          && fitted.location?.hullInstanceID == inventory.activeHull)
      for item in previousItems {
        let retained = item.location?.slot == .targetingCore ? item.moved(to: nil) : item
        try #require(inventory.items.contains(retained))
      }
      paid += price
    }
    try #require(game.commander.credits == budget - paid)
    try #require(game.commander.targetingTier == .docking)
    if escapeReady {
      let index = try #require(Equipment.all.firstIndex { $0.name == "Escape Pod" })
      game.selection = index
      game.purchase()
      try #require(game.commander.equipment.contains("Escape Pod"))
    }
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
