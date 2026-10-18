import Foundation
import Testing

@testable import EliteCore

struct ScriptProcurementFixture {
  let root: URL
  let pack: ScriptPack
  var save: URL { root.appendingPathComponent("save/commander.json") }
  init() throws {
    root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent("procurement-" + UUID().uuidString)
    let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/generated-procurement")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    do {
      let folder = root.appendingPathComponent("pack")
      try FileManager.default.copyItem(at: source, to: folder)
      pack = try ScriptPackLibrary.read(folder)
    } catch {
      try? FileManager.default.removeItem(at: root)
      throw error
    }
  }
  func clean() { try? FileManager.default.removeItem(at: root) }

  /// Policy/codec inputs are not native acceptance or docking evidence.
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
  func plans(_ game: Game, revision: Int64 = 0) throws -> [ScriptProcurementPlan] {
    let key = pack.digest + "/" + pack.manifest.board!.id + "/" + game.contractStation.key
    let seed = try #require(Game.pledgeBoardSeed(key, revision: revision))
    return try ScriptProcurementGeneration.plans(
      pack: pack, commander: game.commander, origin: game.contractStation, revision: revision,
      seed: seed)
  }
  func offer(_ plan: ScriptProcurementPlan) throws -> ScriptContractOffer {
    let key = plan.content.digest + "/" + plan.content.boardID + "/" + plan.origin.key
    return .init(
      id: ScriptIdentity.uuid("contract-offer-v1:\(key):\(plan.boardRevision):\(plan.key)"),
      key: plan.key, title: "Procurement", briefing: "Policy fixture, not native acceptance.",
      destinationGalaxy: plan.origin.galaxy, destinationSystem: plan.path.last!,
      reward: plan.reward,
      deposit: 0, failureReward: 0, refundOnFailure: false, duration: plan.duration,
      parameters: try #require(plan.parameters))
  }
  func job(_ plan: ScriptProcurementPlan) throws -> ScriptContractJob {
    .init(
      boardKey: plan.content.digest + "/" + plan.content.boardID + "/" + plan.origin.key,
      provider: plan.content.provider, version: plan.content.version, digest: plan.content.digest,
      station: plan.origin, boardRevision: plan.boardRevision,
      group: plan.content.provider + "/g03-procurement", offer: try offer(plan),
      clock: .missionCalendar,
      acceptedAt: 0, deadline: plan.duration, deadlinePolicy: .inclusiveConfirmation)
  }

  /// A container fixture supplies no unencoded contact or reward authority.
  func policyContainer() throws -> (Game, UUID) {
    var game = try policyGame()
    let plans = try self.plans(game)
    var offers = try plans.map { try offer($0) }
    let plan = try #require(plans.first { $0.calendarLowerBoundSeconds < $0.duration })
    let job = try self.job(plan)
    let id = Game.contractJobIdentity(job.offer.id)
    var state = ScriptInstance(
      id: id, definition: pack.manifest.stateID, version: pack.manifest.version, digest: pack.digest
    )
    state.contract = job
    state.collections[plan.template.id] = .init(definition: try #require(plan.collection))
    offers[plan.row].status = .accepted(id)
    let board = ScriptContractBoard(
      id: plan.content.boardID, provider: plan.content.provider, version: plan.content.version,
      digest: plan.content.digest, title: "Policy container fixture", station: plan.origin,
      revision: 0, seed: try #require(UInt64(plan.seedHex, radix: 16)), clock: .missionCalendar,
      period: 3600, group: plan.content.provider + "/g03-procurement", offers: offers)
    game.commander.contracts.boards[board.cacheKey] = board
    game.commander.scriptState.instances[id] = state
    try game.migrateMiningPresence(legacyMissing: false, persistCurrentPolicy: true)
    return (game, id)
  }
  static func changingParameters(
    _ offer: ScriptContractOffer, change: (inout [String: Any]) -> Void
  ) throws -> ScriptContractOffer {
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(offer)) as? [String: Any])
    var parameters = try #require(object["parameters"] as? [String: Any])
    var plan = try #require(parameters["procurement"] as? [String: Any])
    change(&plan)
    parameters["procurement"] = plan
    object["parameters"] = parameters
    return try JSONDecoder().decode(
      ScriptContractOffer.self, from: JSONSerialization.data(withJSONObject: object))
  }

  /// Buy the canonical docking equipment, then use real launch/controls/station entry.
  func nativeRuntime() async throws -> GameRuntime {
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
    let runtime = GameRuntime(game: game, saveURL: save)
    try await runtime.save(to: save)
    await runtime.key("0")
    try await Self.dock(runtime)
    return runtime
  }
  static func dock(_ runtime: GameRuntime) async throws {
    for _ in 0..<32 {
      let main = await runtime.procurementTargetIsMain()
      if main { break }
      await runtime.key("tab")
    }
    let targeted = await runtime.procurementTargetIsMain()
    try #require(targeted)
    var steps = 0
    while steps < 3000 {
      let facts = await runtime.procurementFlightFacts()
      if facts.docked { break }
      try #require(facts.live && !facts.paused)
      _ = await runtime.advance(delta: 0.1)
      steps += 1
    }
    let docked = await runtime.procurementNativeDockIsCurrent()
    try #require(steps > 0 && steps < 3000 && docked)
  }
  static func travel(_ runtime: GameRuntime, path: [Int]) async throws {
    for destination in path.dropFirst() {
      await runtime.key("0")
      var controls = Controls()
      controls.throttle = 1
      await runtime.setControls(controls)
      var departure = 0
      while departure < 300 {
        let locked = await runtime.procurementMassLocked()
        if !locked { break }
        _ = await runtime.advance(delta: 0.1)
        departure += 1
      }
      await runtime.setControls(Controls())
      try #require(departure < 300)
      let coordinate = await runtime.procurementSystemCoordinate(destination)
      await runtime.selectSystem(x: coordinate.0, y: coordinate.1)
      await runtime.key("h")
      let started = await runtime.procurementJumping()
      try #require(started)
      var steps = 0
      while steps < 500 {
        let jumping = await runtime.procurementJumping()
        if !jumping { break }
        _ = await runtime.advance(delta: 0.1)
        steps += 1
      }
      let system = await runtime.procurementCurrentSystem()
      try #require(steps > 0 && steps < 500 && system == destination)
      try await dock(runtime)
      if destination != path.last { await runtime.procurementRefuel() }
    }
  }
  static func contact(_ runtime: GameRuntime) async {
    await runtime.key("contacts-open")
    await runtime.key("left")
    await runtime.key("return")
  }
}

extension GameRuntime {
  func procurementTargetIsMain() -> Bool { game.autoTargetBody?.id == 0 }
  func procurementFlightFacts() -> (docked: Bool, live: Bool, paused: Bool) {
    (game.docked, game.screen != .gameOver && game.energy > 0, game.paused)
  }
  func procurementNativeDockIsCurrent() -> Bool { game.nativeMainStationDockEvidenceIsCurrent }
  func procurementMassLocked() -> Bool { game.massLocked }
  func procurementJumping() -> Bool { game.jumpCountdown != nil }
  func procurementCurrentSystem() -> Int { game.commander.system }
  func procurementSystemCoordinate(_ id: Int) -> (Int, Int) {
    (game.systems[id].x, game.systems[id].y)
  }
  func procurementRefuel() {
    nativeCommand { game in
      guard let index = Equipment.all.firstIndex(where: { $0.name == "Fuel" }) else { return }
      game.selection = index
      game.purchase()
    }
  }
  func procurementBuy(_ commodity: Int) {
    nativeCommand { game in
      game.selection = commodity
      game.trade(buy: true)
    }
  }
}
