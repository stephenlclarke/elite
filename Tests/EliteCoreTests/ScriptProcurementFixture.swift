import Foundation
import Testing

@testable import EliteCore

typealias ScriptProcurementScenePreparation = @Sendable (GameRuntime) async throws -> Void

struct ScriptProcurementFixture {
  let root: URL
  let pack: ScriptPack
  var save: URL { root.appendingPathComponent("save/commander.json") }
  init(legacyV1: Bool = false) throws {
    root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent("procurement-" + UUID().uuidString)
    let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/generated-procurement")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    do {
      let folder = root.appendingPathComponent("pack")
      if legacyV1 {
        try ScriptProcurementLegacyV1Fixture.write(to: folder)
      } else {
        try FileManager.default.copyItem(at: source, to: folder)
      }
      pack = try ScriptPackLibrary.read(folder)
      if legacyV1 { try #require(pack.digest == ScriptProcurementLegacyV1Fixture.digest) }
    } catch {
      try? FileManager.default.removeItem(at: root)
      throw error
    }
  }
  func clean() { try? FileManager.default.removeItem(at: root) }

  /// Fresh controlled scene initialization at the declared trial shop, never a flown journey.
  static func freshG03FlightGame() throws -> Game {
    let origin = try Universe.originalWorlds.world(key: "G01-S007")
    var game = Game(executive: false)
    game.screen = .status
    game.commander.galaxy = origin.galaxy
    game.commander.system = origin.system
    game.systems = Universe.systemsIncludingPlugh(number: origin.galaxy)
    game.selectedSystem = origin.system
    game.market = MarketItem.at(game.currentSystem)
    game.commander.credits = 100000
    try #require(game.currentSystem.original == origin)
    return game
  }

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

  /// Buy the fixed docking and defensive fit, then use real launch/controls/station entry.
  func nativeRuntime(
    diagnostic: ScriptProcurementFlightDiagnostic? = nil,
    prepareScene: ScriptProcurementScenePreparation? = nil
  ) async throws
    -> GameRuntime
  {
    var game = try Self.freshG03FlightGame()
    try #require(pack.manifest.trial?.galaxy == game.commander.galaxy)
    try #require(pack.manifest.trial?.system == game.commander.system)
    game.scriptPacks = [pack]
    let cargo = game.commander.cargo
    try game.prepareG03FlightEquipment()
    try Self.requirePaidG03Preparation(game)
    try #require(game.commander.cargo == cargo)
    let runtime = GameRuntime(game: game, saveURL: save)
    try await runtime.save(to: save)
    await runtime.key("0")
    try await Self.dock(
      runtime, diagnostic: diagnostic, phase: "initial-dock", prepareScene: prepareScene)
    return runtime
  }
  /// Independently fixed paid chain: assert quotes, predecessor custody and all retained items.
  static func requirePaidG03Preparation(_ game: Game, escapeReady: Bool = false) throws {
    let inventory = try #require(game.commander.equipmentInventory)
    let history = try #require(game.commander.equipmentPurchaseHistory)
    var rows: [(String, Int, ComponentFittingSlot, EquipmentFamilyID, String?)] = [
      ("Targeting: Basic", 8000, .targetingCore, EquipmentPurchaseCatalog.targeting, nil),
      (
        "Targeting: Advanced", 20000, .targetingCore, EquipmentPurchaseCatalog.targeting,
        "Targeting: Basic"
      ),
      (
        "Targeting: Docking", 40000, .targetingCore, EquipmentPurchaseCatalog.targeting,
        "Targeting: Advanced"
      ),
      ("Pulse Shield Booster", 3000, .shield, EquipmentPurchaseCatalog.shields, "Basic Shield"),
      ("Extra Energy Unit", 15000, .energy, EquipmentPurchaseCatalog.energy, "Basic Energy System"),
    ]
    if escapeReady {
      rows.append(("Escape Pod", 10000, .utility(.escapePod), .init("utility-escapePod"), nil))
    }
    try #require(history.paid.count == rows.count && history.legacy.isEmpty)
    try #require(history.owner == inventory.owner && history.revision == UInt64(rows.count))
    try #require(Set(history.paid.map(\.transaction)).count == rows.count)
    let first = try #require(history.paid.first)
    var expectedItems = first.binding.snapshot.items
    let foundation = expectedItems
    var funds = 100000
    for (index, row) in rows.enumerated() {
      let (name, price, slot, family, predecessor) = row
      let receipt = history.paid[index]
      let node = EquipmentNodeID(family: family, key: name)
      let location = ComponentFittingLocation(hullInstanceID: inventory.activeHull, slot: slot)
      let purchaseLocation = EquipmentRuntimeCatalog.purchaseLocation(location)
      let policy = try #require(receipt.binding.lineage.first { $0.id == node })
      let required = predecessor.map { EquipmentNodeID(family: family, key: $0) }
      try #require(
        receipt.owner == inventory.owner && receipt.node == node && receipt.price == price)
      try #require(
        receipt.binding.snapshot.owner == inventory.owner
          && receipt.binding.snapshot.activeHull == inventory.activeHull
          && receipt.binding.snapshot.funds == funds
          && receipt.binding.historyRevision == UInt64(index))
      try #require(receipt.binding.snapshot.items == expectedItems)
      try #require(receipt.binding.request.location == purchaseLocation)
      try #require(
        receipt.binding.request.offer.shop == "galaxy:0/system:7"
          && receipt.binding.request.offer.node == node
          && receipt.binding.request.offer.revision == 1)
      let prerequisites = required.map { [$0] } ?? []
      try #require(policy.prerequisites == prerequisites)
      if let required {
        let prior = try #require(expectedItems.first { $0.node == required })
        try #require(prior.location == purchaseLocation)
        if index < 3 {
          try #require(history.paid.prefix(index).contains { $0.node == required })
        } else {
          try #require(prior.provenance == .standard)
        }
      }
      expectedItems = expectedItems.map {
        .init(
          id: $0.id, node: $0.node, location: $0.location == purchaseLocation ? nil : $0.location,
          provenance: $0.provenance)
      }
      expectedItems.append(
        .init(
          id: receipt.binding.request.newItem, node: node, location: purchaseLocation,
          provenance: .paid(owner: inventory.owner, transaction: receipt.transaction)))
      funds -= price
    }
    let actual = try game.commander.purchaseSnapshot()
    try #require(actual.items == expectedItems && game.commander.credits == funds)
    try #require(funds == (escapeReady ? 4000 : 14000))
    for old in foundation {
      let retained = try #require(inventory.items.first { $0.id == old.id })
      try #require(retained.node == old.node && retained.provenance == old.provenance)
    }
    for (name, _, slot, _, _) in rows.suffix(escapeReady ? 4 : 3) {
      let fitted = try #require(game.commander.fittedEquipment(at: slot))
      try #require(
        fitted.node.key == name && fitted.location?.hullInstanceID == inventory.activeHull)
    }
    try #require(game.commander.targetingTier == .docking && game.commander.equipmentStateValid)
    try #require(
      game.commander.fittedComponent(at: .shield)?.grade
        == EquipmentModuleTemplates.shield.grades[1].identity)
    try #require(
      game.commander.fittedComponent(at: .energy)?.grade
        == EquipmentModuleTemplates.energy.grades[1].identity)
    try #require(game.commander.shieldCapacity == game.commander.nativePerformance.shield * 1.5)
    try #require(game.commander.rearShieldCapacity == game.commander.nativePerformance.shield * 1.5)
    try #require(game.commander.energyRechargeMultiplier == 2)
    try #require(game.commander.performance.energy == game.commander.nativePerformance.energy)
  }
  static func dock(
    _ runtime: GameRuntime, diagnostic: ScriptProcurementFlightDiagnostic? = nil,
    phase: String = "dock", defensivePreflight: Bool = false,
    selectionDiagnostic: ScriptProcurementSelectionDiagnostic? = nil,
    prepareScene: ScriptProcurementScenePreparation? = nil
  ) async throws {
    if let prepareScene { try await prepareScene(runtime) }
    if defensivePreflight {
      try await defendedDock(runtime, diagnostic: diagnostic, phase: phase)
      return
    }
    var steps = 0
    var tabAttempts = 0
    for _ in 0..<32 {
      let main = await runtime.procurementTargetIsMain()
      if main { break }
      await runtime.key("tab")
      tabAttempts += 1
    }
    let targeted = await runtime.procurementTargetIsMain()
    if !targeted, let selectionDiagnostic {
      let detail = await runtime.procurementSelectionFailureDetail(
        selectionDiagnostic, tabAttempts: tabAttempts)
      try #require(targeted, "\(detail)")
    } else {
      try #require(targeted)
    }
    while steps < 3000 {
      let facts = await runtime.procurementFlightFacts()
      if facts.docked { break }
      var failureDetails = ""
      if !facts.live || facts.paused {
        let system = await runtime.procurementCurrentSystem()
        let detail = await runtime.procurementJumpRefusalDetail(destination: system)
        let label = String((selectionDiagnostic?.label ?? phase).prefix(80))
        failureDetails = "Dock stopped, phase=\(label), steps=\(steps): \(detail)"
      }
      try #require(facts.live && !facts.paused, Comment(rawValue: failureDetails))
      if let prepareScene { try await prepareScene(runtime) }
      if let diagnostic {
        await diagnosticAdvance(runtime, diagnostic: diagnostic, phase: phase, step: steps)
      } else {
        _ = await runtime.advance(delta: 0.1)
      }
      steps += 1
    }
    let docked = await runtime.procurementNativeDockIsCurrent()
    try #require(steps > 0 && steps < 3000 && docked)
  }
  static func travel(
    _ runtime: GameRuntime, path: [Int], diagnostic: ScriptProcurementFlightDiagnostic? = nil,
    defensivePreflight: Bool = false, verifyDeparture: Bool = false,
    selectionDiagnostic: ScriptProcurementSelectionDiagnostic? = nil,
    prepareScene: ScriptProcurementScenePreparation? = nil
  ) async throws {
    var origin = path.first
    for (legIndex, destination) in path.dropFirst().enumerated() {
      let leg = diagnostic == nil ? "" : "travel-leg-\(path.firstIndex(of: destination) ?? 0)"
      if verifyDeparture {
        let expected = try #require(origin)
        let ready = await runtime.procurementDepartureReadiness(
          origin: expected, destination: destination, atDock: true)
        try #require(ready.allowed, "\(ready.detail)")
      }
      await runtime.key("0")
      var controls = Controls()
      controls.throttle = 1
      await runtime.setControls(controls)
      var departure = 0
      while departure < 300 {
        if verifyDeparture {
          let flight = await runtime.procurementFlightFacts()
          try #require(flight.live && !flight.paused && !flight.docked)
        }
        let locked = await runtime.procurementMassLocked()
        if !locked { break }
        if let prepareScene { try await prepareScene(runtime) }
        if let diagnostic {
          await diagnosticAdvance(
            runtime, diagnostic: diagnostic, phase: leg + "-departure", step: departure)
        } else {
          _ = await runtime.advance(delta: 0.1)
        }
        departure += 1
      }
      await runtime.setControls(Controls())
      try #require(departure < 300)
      let coordinate = await runtime.procurementSystemCoordinate(destination)
      await runtime.selectSystem(x: coordinate.0, y: coordinate.1)
      if verifyDeparture {
        let expected = try #require(origin)
        let ready = await runtime.procurementDepartureReadiness(
          origin: expected, destination: destination, atDock: false)
        try #require(ready.allowed, "\(ready.detail)")
      }
      await runtime.key("h")
      let started = await runtime.procurementJumping()
      if verifyDeparture {
        let flight = await runtime.procurementFlightFacts()
        let detail = await runtime.procurementJumpRefusalDetail(destination: destination)
        try #require(
          started && flight.live && !flight.paused && !flight.docked,
          "Countdown start, steps=0: \(detail)")
      } else {
        try #require(started)
      }
      var steps = 0
      while steps < 500 {
        if verifyDeparture {
          let flight = await runtime.procurementFlightFacts()
          if !flight.live || flight.paused || flight.docked {
            let detail = await runtime.procurementJumpRefusalDetail(destination: destination)
            try #require(
              flight.live && !flight.paused && !flight.docked,
              "Countdown stopped, steps=\(steps): \(detail)")
          }
        }
        let jumping = await runtime.procurementJumping()
        if !jumping { break }
        if let prepareScene { try await prepareScene(runtime) }
        if let diagnostic {
          await diagnosticAdvance(
            runtime, diagnostic: diagnostic, phase: leg + "-jump", step: steps)
        } else {
          _ = await runtime.advance(delta: 0.1)
        }
        steps += 1
      }
      let system = await runtime.procurementCurrentSystem()
      if verifyDeparture {
        let detail = await runtime.procurementJumpRefusalDetail(destination: destination)
        try #require(
          steps > 0 && steps < 500 && system == destination,
          "Countdown arrival, steps=\(steps): \(detail)")
      } else {
        try #require(steps > 0 && steps < 500 && system == destination)
      }
      try await dock(
        runtime, diagnostic: diagnostic, phase: diagnostic == nil ? "" : leg + "-dock",
        defensivePreflight: defensivePreflight,
        selectionDiagnostic: selectionDiagnostic.map {
          .init(label: $0.label + "-leg-\(legIndex + 1)", instance: $0.instance)
        }, prepareScene: prepareScene)
      if destination != path.last { await runtime.procurementRefuel() }
      origin = destination
    }
  }
  private static func defendedDock(
    _ runtime: GameRuntime, diagnostic: ScriptProcurementFlightDiagnostic?, phase: String
  ) async throws {
    var budget = ScriptProcurementPilotBudget()
    let initial = await runtime.procurementPreflightFacts()
    try #require(initial.valid && initial.live && !initial.docked && !initial.paused)
    try #require(initial.legal == 0, "The defended fixture requires its actual clean commander.")
    while budget.steps < 3000 {
      var facts = await runtime.procurementPreflightFacts()
      let action = facts.requestedDockAction(defensive: true, steps: budget.steps)
      try #require(action != .refuse, "Defended docking facts or total advance budget refused.")
      if action == .react {
        let cancelled = await runtime.procurementCancelForThreat(
          expected: facts, steps: budget.steps)
        try #require(cancelled, "Fresh threat or genuine AUTO cancellation could not be rejoined.")
        try await preflight(runtime, budget: &budget, diagnostic: diagnostic, phase: phase)
      }
      while true {
        let main = await runtime.procurementDefensiveMainTargetIsCurrent()
        if main { break }
        let available = budget.reserveTab()
        try #require(available, "Defended docking exhausted the shared 32 TAB inputs.")
        await runtime.key("tab")
      }
      facts = await runtime.procurementPreflightFacts()
      let active = await diagnostic?.active ?? false
      let result = await runtime.procurementPilotStep(
        expected: facts, steps: budget.steps, automatic: true, diagnostic: active)
      if result.status == .react { continue }
      if let diagnostic, let before = result.before, let after = result.after {
        await diagnostic.record(before: before, after: after, phase: phase, step: budget.steps)
      }
      try #require(result.status == .automatic, "Fresh main-station AUTO step refused.")
      let recorded = budget.recordAdvance(automatic: true)
      try #require(recorded)
      try #require(
        result.legal == initial.legal, "Actual native flight recorded unlawful player fire.")
      if result.docked {
        try #require(budget.automaticAdvances > 0 && budget.steps < 3000)
        try #require(
          result.nativeDockIsCurrent && (result.dockSequence ?? 0) > 0,
          "The actual AUTO arrival receipt is not current.")
        return
      }
    }
    try #require(Bool(false), "Defended docking exhausted the original 3000 total advances.")
  }
  private static func preflight(
    _ runtime: GameRuntime, budget: inout ScriptProcurementPilotBudget,
    diagnostic: ScriptProcurementFlightDiagnostic?, phase: String
  ) async throws {
    var facts = await runtime.procurementPreflightFacts()
    // A clear native scene consumes no tool input, control change or physical advance.
    if facts.requestedAction(steps: budget.steps) == .clear { return }
    while !facts.combatLaser {
      if facts.requestedAction(steps: budget.steps) == .clear { return }
      let viable = facts.requestedAction(steps: budget.steps) != .refuse
      try #require(viable, "Preflight unavailable before tool selection")
      let available = budget.reserveTool()
      try #require(available, "Defended docking exhausted the shared four tool-selection inputs.")
      await runtime.key("w")
      facts = await runtime.procurementPreflightFacts()
    }
    while budget.steps < 3000 {
      let action = facts.requestedAction(steps: budget.steps)
      if action == .clear {
        budget.retreat = nil
        break
      }
      try #require(
        action != .refuse,
        Comment(
          rawValue: "Preflight refused at total step \(budget.steps). phase=\(phase)"
            + " valid=\(facts.valid) live=\(facts.live) docked=\(facts.docked)"
            + " paused=\(facts.paused) automatic=\(facts.automaticEngaged)"))
      // A re-engaging pilot may use the existing native fallback before heat starts a new turn.
      let wasReengaging = budget.updateRetreat(facts)
      if budget.retreat == nil || wasReengaging {
        budget = try await runtime.procurementMissileFallback(expected: facts, budget: budget)
      }
      facts = await runtime.procurementPreflightFacts()
      let active = await diagnostic?.active ?? false
      let result = await runtime.procurementPilotStep(
        expected: facts, steps: budget.steps, automatic: false, diagnostic: active,
        retreat: budget.retreat)
      if let diagnostic, let before = result.before, let after = result.after {
        await diagnostic.record(
          before: before, after: after, phase: phase + "-preflight", step: budget.steps)
      }
      try #require(result.status == .defensive, "Defensive step lost its fresh player/threat join.")
      let recorded = budget.recordAdvance(automatic: false)
      try #require(recorded)
      try #require(result.legal == 0, "Actual native defence recorded unlawful player fire.")
      try #require(!result.docked, "Manual defence cannot count as an AUTO arrival.")
      facts = await runtime.procurementPreflightFacts()
    }
    let cleared = facts.requestedAction(steps: budget.steps) == .clear
    try #require(cleared, "Preflight exhausted original total dock budget at \(budget.steps).")
    // The actor-owned step clears manual controls immediately after every admitted advance.
  }
  private static func diagnosticAdvance(
    _ runtime: GameRuntime, diagnostic: ScriptProcurementFlightDiagnostic, phase: String, step: Int
  ) async {
    guard await diagnostic.active else {
      _ = await runtime.advance(delta: 0.1)
      return
    }
    await runtime.enableStationDefenceDiagnostics()
    let before = await runtime.procurementFlightDiagnosticFacts()
    _ = await runtime.advance(delta: 0.1)
    let after = await runtime.procurementFlightDiagnosticFacts()
    await diagnostic.record(before: before, after: after, phase: phase, step: step)
  }
  static func contact(_ runtime: GameRuntime) async {
    await runtime.key("contacts-open")
    await runtime.key("left")
    await runtime.key("return")
  }
}

/// One budget is retained through every initial/manual/AUTO/reaction cycle of a dock.
struct ScriptProcurementPilotBudget: Sendable {
  private(set) var steps = 0
  private(set) var tabs = 0
  private(set) var tools = 0
  private(set) var automaticAdvances = 0
  var missileDefence = ScriptProcurementMissileBudget()
  var retreat: ScriptProcurementRetreat?

  mutating func reserveTab() -> Bool {
    guard tabs < 32 else { return false }
    tabs += 1
    return true
  }
  mutating func reserveTool() -> Bool {
    guard tools < 4 else { return false }
    tools += 1
    return true
  }
  mutating func recordAdvance(automatic: Bool) -> Bool {
    guard steps < 3000 else { return false }
    steps += 1
    if automatic { automaticAdvances += 1 }
    return true
  }
}

enum ScriptProcurementDockAction: Equatable { case refuse, react, acquire, automatic }
enum ScriptProcurementPilotStepStatus: Equatable, Sendable {
  case refused, react, defensive, automatic
}

struct ScriptProcurementPreflightIdentity: Equatable, Sendable {
  let player: ActorIdentity
  let epoch: UUID
  let stationEpoch: UUID
  let owner: UUID
  let revision: UInt64
  let physicalTime: Double
}

struct ScriptProcurementPilotStepResult: Sendable {
  let status: ScriptProcurementPilotStepStatus
  var legal = 0
  var docked = false
  var nativeDockIsCurrent = false
  var dockSequence: UInt64?
  var before: ScriptProcurementFlightDiagnosticFacts?
  var after: ScriptProcurementFlightDiagnosticFacts?
}

enum ScriptProcurementPreflightAction: Equatable {
  case refuse, clear, track, requestFire
}

struct ScriptProcurementPreflightThreat: Sendable, Equatable {
  let identity: ActorIdentity
  let position: Vector3
  let wanted: Bool
  var pulseOnly = false
  var closingMargin = 0.0

  var immediate: Bool { !pulseOnly || position.length <= 1500 + closingMargin }
}

/// Test policy values are never accepted by a native hit, law, source or receipt producer.
struct ScriptProcurementPreflightFacts: Sendable, Equatable {
  var identity: ScriptProcurementPreflightIdentity?
  var legal = 0
  var mainTargetCurrent = false
  var valid = false
  var docked = false
  var live = false
  var paused = false
  var automaticEngaged = false
  var threat: ScriptProcurementPreflightThreat?
  var threats: [ScriptProcurementPreflightThreat] = []
  var pulseHeatBlocked = false
  var frontShieldLow = false
  var rearShieldLow = false

  var immediateThreats: [ScriptProcurementPreflightThreat] {
    (threats.isEmpty ? threat.map { [$0] } ?? [] : threats).filter(\.immediate)
  }
  var needsDefence: Bool { incoming || !immediateThreats.isEmpty }
  var incoming = false
  var outsideNoFireZones = false
  var lawfulForwardDefence = false
  var exactForwardHit = false
  var combatLaser = false
  var frontLaser = false
  var speed = 0.0
  var pitchRate = 0.0
  var yawRate = 0.0

  static func clearsEveryNoFireZone(_ ranges: [Double]) -> Bool {
    !ranges.isEmpty && ranges.allSatisfy { $0.isFinite && $0 > 1200 }
  }

  func requestedDockAction(defensive: Bool, steps: Int) -> ScriptProcurementDockAction {
    guard valid, live, !docked, !paused, steps >= 0, steps < 3000 else { return .refuse }
    if defensive, needsDefence { return .react }
    return mainTargetCurrent ? .automatic : .acquire
  }

  func rejoins(_ expected: Self) -> Bool {
    identity != nil && self == expected
  }

  func requestedAction(steps: Int) -> ScriptProcurementPreflightAction {
    guard valid, live, !docked, !paused, !automaticEngaged,
      steps >= 0, steps < 3000
    else { return .refuse }
    guard needsDefence else { return .clear }
    guard threat?.wanted == true, outsideNoFireZones || lawfulForwardDefence, exactForwardHit,
      combatLaser, frontLaser
    else { return .track }
    return .requestFire
  }
}

struct ScriptProcurementFlightDiagnosticFacts: Sendable {
  let docked: Bool
  let live: Bool
  let paused: Bool
  let scalars: [String: String]
  var defence: StationDefenceDiagnosticSnapshot? = nil
}

/// Opt-in expiry failure text; fixed scalar ceilings include the assertion's newline budget.
struct ScriptProcurementSelectionDiagnostic: Sendable {
  let label: String
  var instance: UUID? = nil

  static func actor(_ identity: ActorIdentity?) -> String {
    guard let identity else { return "nil" }
    return
      "\(identity.system.galaxy)/\(identity.system.system)/\(identity.visit)/\(identity.entity)"
  }

  static func message(_ fields: [String: String]) -> String {
    var bounded: [String: String] = [:]
    for (key, value) in fields {
      let limit = key == "message" ? 128 : 64
      bounded[key] = String(
        decoding: value.utf8.prefix(limit).map {
          (32...126).contains($0) && $0 != 34 && $0 != 92 ? $0 : 63
        }, as: UTF8.self)
    }
    guard
      let data = try? JSONSerialization.data(
        withJSONObject: bounded, options: [.sortedKeys, .withoutEscapingSlashes]),
      data.count < 4096
    else { return "EXPIRY_TARGET_SELECTION_DIAGNOSTIC_REFUSED limit=4096" }
    return String(decoding: data, as: UTF8.self)
  }
}

/// Test-only, opt-in state. It retains no Game, Commander, actor inventory or authority.
actor ScriptProcurementFlightDiagnostic {
  private let label: String
  private var emitted = false
  private var lastLive: [String: String]?
  private var defenceSamples: [[String: String]] = []
  private var defenceSamplesDropped = 0
  private var defenceIntervalSkipped = 0
  private var defenceValuesTruncated = 0
  private var lastDefenceSampleTime: Double?
  private var lastDefenceStamp: String?
  private var lastDefencePlayer: String?
  private var lastDefencePhase: String?
  private var lastDefenceActor: String?
  private var defencePhaseChanges = 0
  private var defenceActorChanges = 0
  private var latestCombatTrace: GameplayCombatTrace?
  private var firstEntryCourse: [String: String]?
  private var firstEntryCourseFieldsDropped = 0
  private var firstEntryCourseValuesTruncated = 0
  private var firstEntryCourseRefusal: [String: String]?
  private var firstEntryCourseRefusalFieldsDropped = 0
  private var firstEntryCourseRefusalValuesTruncated = 0
  private var combatEpoch: UUID?
  private var lastCombatIncident: UInt64 = 0
  private var acceptedCounts: [String: Int] = [:]
  private var audioEpoch: UUID?
  private var lastAudioID: UInt64 = 0
  private var laserDischarges = 0
  private var audioEventsDropped = 0
  var active: Bool { !emitted }

  init(label: String = "procurement-partial") {
    self.label = Self.ascii(label, limit: 48)
  }

  private static func ascii(_ value: String, limit: Int) -> String {
    String(
      decoding: value.utf8.prefix(limit).map {
        (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
          || [43, 44, 45, 46, 47, 58, 63, 95].contains($0) ? $0 : 63
      }, as: UTF8.self)
  }

  // Fixed ASCII ceilings retain causal manual facts even if verbose before/after text grows.
  private static let compactLimits: [String: Int] = [
    "docked": 32, "live": 32, "paused": 32, "screen": 32, "energy": 32,
    "energyFinite": 32, "frontShield": 32, "rearShield": 32,
    "altitude": 32, "cabinTemperature": 32, "mainStationContainsPlayer": 32,
    "finalApproach": 32, "system": 32, "visit": 32, "physicalTime": 32,
    "missionSeconds": 32, "fuel": 32, "credits": 32, "legal": 32, "speed": 32,
    "missilesRemaining": 32, "playerActiveMissiles": 32,
    "gameplayRevisionFrameStamp": 32, "stationImpactRevisionFrameStamp": 32,
    "targetID": 32, "phase": 64, "step": 32,
    "pilotAction": 32, "pilotThreat": 96, "pilotPosition": 96, "pilotWanted": 32,
    "pilotIncoming": 32, "pilotZoneClear": 32, "pilotExactRay": 32,
    "pilotCombatTool": 32, "pilotFrontLaser": 32, "pilotPitch": 32, "pilotYaw": 32,
    "pilotFire": 32, "pilotCooldown": 32, "pilotHeat": 32, "pilotEMPDisabled": 32,
    "pilotWorkSuspended": 32,
  ]

  private static func compact(_ fields: [String: String]) -> [String: String] {
    var result: [String: String] = [:]
    for (key, limit) in compactLimits {
      if let value = fields[key] { result[key] = ascii(value, limit: limit) }
    }
    return result
  }

  func record(
    before: ScriptProcurementFlightDiagnosticFacts,
    after: ScriptProcurementFlightDiagnosticFacts, phase: String, step: Int
  ) {
    guard !emitted else { return }
    observeDefence(before.defence, phase: phase, step: step)
    let failed = !after.docked && (!after.live || after.paused)
    observeDefence(after.defence, phase: phase, step: step + 1, force: failed)
    if before.live && !before.paused {
      var scalars = before.scalars
      scalars["phase"] = phase
      scalars["step"] = String(step)
      lastLive = scalars
    }
    guard !after.docked, !after.live || after.paused else { return }
    defer { emitDefenceTrace() }
    emitted = true
    var failure = after.scalars
    failure["phase"] = phase
    failure["step"] = String(step + 1)
    var payload: [String: Any] = [
      "kind": "procurement-flight-first-failure", "fixture": label,
      "lastLivePreAdvance": lastLive ?? [:],
      "firstFailurePostAdvance": failure,
      "immediatePreAdvanceWasLive": before.live && !before.paused,
    ]
    do {
      var data = try JSONSerialization.data(
        withJSONObject: payload, options: [.sortedKeys, .withoutEscapingSlashes])
      if data.count >= 4096 {
        payload["lastLivePreAdvance"] = Self.compact(lastLive ?? [:])
        payload["firstFailurePostAdvance"] = Self.compact(failure)
        payload["compact"] = true
        data = try JSONSerialization.data(
          withJSONObject: payload, options: [.sortedKeys, .withoutEscapingSlashes])
      }
      // The budget includes print's single trailing newline. Refusal never dumps the payload.
      guard data.count < 4096, let text = String(data: data, encoding: .utf8) else {
        print("PROCUREMENT_FLIGHT_DIAGNOSTIC_REFUSED limit=4096")
        return
      }
      print(text)
    } catch {
      print("PROCUREMENT_FLIGHT_DIAGNOSTIC_REFUSED encoding")
    }
  }

  private func observeDefence(
    _ snapshot: StationDefenceDiagnosticSnapshot?, phase: String, step: Int, force: Bool = false
  ) {
    guard let snapshot else { return }
    let player = snapshot.scalars["player"] ?? "nil"
    if player != lastDefencePlayer {
      defenceSamplesDropped += defenceSamples.count
      defenceSamples.removeAll(keepingCapacity: true)
      lastDefenceSampleTime = nil
      lastDefenceStamp = nil
      lastDefencePhase = nil
      lastDefenceActor = nil
      defencePhaseChanges = 0
      defenceActorChanges = 0
      acceptedCounts = [:]
      laserDischarges = 0
      audioEventsDropped = 0
      lastDefencePlayer = player
      firstEntryCourse = nil
      firstEntryCourseFieldsDropped = 0
      firstEntryCourseValuesTruncated = 0
      firstEntryCourseRefusal = nil
      firstEntryCourseRefusalFieldsDropped = 0
      firstEntryCourseRefusalValuesTruncated = 0
    }
    // Retain this actual first decision before sample interval or output-budget removal.
    if let first = snapshot.firstEntryCourse, firstEntryCourse?["target"] != first["target"] {
      var bounded: [String: String] = [:]
      firstEntryCourseFieldsDropped = max(0, first.count - 48)
      firstEntryCourseValuesTruncated = 0
      for (key, value) in first.sorted(by: { $0.key < $1.key }).prefix(48) {
        if value.utf8.count > 256 { firstEntryCourseValuesTruncated += 1 }
        bounded[key] = String(
          decoding: value.utf8.prefix(256).map { (32...126).contains($0) ? $0 : 63 }, as: UTF8.self)
      }
      firstEntryCourse = bounded
    }
    if let first = snapshot.firstEntryCourseRefusal,
      firstEntryCourseRefusal?["target"] != first["target"]
    {
      var bounded: [String: String] = [:]
      firstEntryCourseRefusalFieldsDropped = max(0, first.count - 48)
      firstEntryCourseRefusalValuesTruncated = 0
      for (key, value) in first.sorted(by: { $0.key < $1.key }).prefix(48) {
        if value.utf8.count > 256 { firstEntryCourseRefusalValuesTruncated += 1 }
        bounded[key] = String(
          decoding: value.utf8.prefix(256).map { (32...126).contains($0) ? $0 : 63 }, as: UTF8.self)
      }
      firstEntryCourseRefusal = bounded
    }
    if combatEpoch != snapshot.combat.epoch {
      combatEpoch = snapshot.combat.epoch
      lastCombatIncident = 0
    }
    for incident in snapshot.combat.incidents where incident.id > lastCombatIncident {
      let owner = ScriptProcurementSelectionDiagnostic.actor(incident.origin.owner)
      let victim = ScriptProcurementSelectionDiagnostic.actor(incident.victim)
      let relation = owner == player ? "playerOwned" : (victim == player ? "playerVictim" : "other")
      let key = relation + "/" + incident.kind.rawValue + "/" + incident.outcome.rawValue
      acceptedCounts[key, default: 0] += 1
    }
    lastCombatIncident = max(lastCombatIncident, snapshot.combat.incidents.last?.id ?? 0)
    latestCombatTrace = snapshot.combat
    if audioEpoch == nil {
      audioEpoch = snapshot.audioEpoch
      lastAudioID = snapshot.audio.last?.id ?? 0
    } else {
      if audioEpoch != snapshot.audioEpoch {
        audioEpoch = snapshot.audioEpoch
        lastAudioID = 0
      }
      if let first = snapshot.audio.first, first.id > lastAudioID,
        first.id - lastAudioID > 1
      {
        audioEventsDropped += Int(clamping: first.id - lastAudioID - 1)
      }
      laserDischarges +=
        snapshot.audio.filter { $0.id > lastAudioID && $0.tool == .combatLaser }.count
      lastAudioID = max(lastAudioID, snapshot.audio.last?.id ?? 0)
    }
    let stamp = (snapshot.scalars["revision"] ?? "nil") + "/" + String(snapshot.physicalTime)
    if stamp == lastDefenceStamp && !force { return }
    lastDefenceStamp = stamp
    let currentPhase = snapshot.scalars["phase"]
    let currentActor = snapshot.scalars["combatActor"]
    if let previous = lastDefencePhase, previous != currentPhase { defencePhaseChanges += 1 }
    if let previous = lastDefenceActor, previous != currentActor { defenceActorChanges += 1 }
    lastDefencePhase = currentPhase
    lastDefenceActor = currentActor
    if !force, let time = lastDefenceSampleTime, snapshot.physicalTime >= time,
      snapshot.physicalTime - time < 0.5 - 1e-8
    {
      defenceIntervalSkipped += 1
      return
    }
    lastDefenceSampleTime = snapshot.physicalTime
    var values = snapshot.scalars
    values["journeyPhase"] = phase
    values["journeyStep"] = String(step)
    for (key, value) in values {
      if value.utf8.count > 256 { defenceValuesTruncated += 1 }
      values[key] = String(
        decoding: value.utf8.prefix(256).map { (32...126).contains($0) ? $0 : 63 }, as: UTF8.self)
    }
    defenceSamples.append(values)
    if defenceSamples.count > 64 {
      defenceSamplesDropped += defenceSamples.count - 64
      defenceSamples.removeFirst(defenceSamples.count - 64)
    }
  }

  private func emitDefenceTrace() {
    guard let trace = latestCombatTrace else { return }
    let columns = defenceSamples.first.map { $0.keys.sorted() } ?? []
    var samples = defenceSamples.map { sample in columns.map { sample[$0] ?? "nil" } }
    let incidentColumns = [
      "incident", "time", "emission", "emittedAt", "owner", "victim", "kind", "outcome", "laser",
      "mount", "ordnance", "ownerLegal", "victimLegal", "positionWorld",
    ]
    var incidents = trace.incidents.map { incident -> [String] in
      [
        String(incident.id), String(incident.physicalTime), String(incident.origin.emissionID),
        String(incident.origin.emittedAt),
        ScriptProcurementSelectionDiagnostic.actor(incident.origin.owner),
        ScriptProcurementSelectionDiagnostic.actor(incident.victim), incident.kind.rawValue,
        incident.outcome.rawValue, incident.laser.map { String(describing: $0) } ?? "nil",
        incident.mount?.rawValue ?? "nil",
        ScriptProcurementSelectionDiagnostic.actor(incident.origin.ordnance),
        String(incident.origin.ownerLegalAtEmission.value),
        incident.victimLegalBeforeAttack.map { String($0.value) } ?? "nil",
        "\(incident.position.x),\(incident.position.y),\(incident.position.z)",
      ]
    }
    var outputSamplesDropped = 0
    var outputIncidentsDropped = 0
    while true {
      let payload: [String: Any] = [
        "kind": "station-defence-observational-trace", "fixture": label,
        "coverage":
          "common GameplayCombat accepted incidents only; mount/law and current combat-position/bearing observations are prospective, not accepted shots, hits or cached steering aim",
        "combatEpoch": trace.epoch.uuidString, "player": lastDefencePlayer ?? "nil",
        "firstEntryCourse": firstEntryCourse ?? [:],
        "firstEntryCourseFieldsDropped": firstEntryCourseFieldsDropped,
        "firstEntryCourseValuesTruncated": firstEntryCourseValuesTruncated,
        "firstEntryCourseRefusal": firstEntryCourseRefusal ?? [:],
        "firstEntryCourseRefusalFieldsDropped": firstEntryCourseRefusalFieldsDropped,
        "firstEntryCourseRefusalValuesTruncated": firstEntryCourseRefusalValuesTruncated,
        "columns": columns, "samples": samples, "incidentColumns": incidentColumns,
        "acceptedIncidents": incidents, "acceptedCountsObservedCurrentPlayerVisit": acceptedCounts,
        "nativeLaserDischargesCurrentPlayerVisit": laserDischarges,
        "phaseChangesCurrentPlayerVisit": defencePhaseChanges,
        "combatActorChangesCurrentPlayerVisit": defenceActorChanges,
        "sampleIntervalSeconds": 0.5, "sampleCapacity": 64, "incidentCapacity": 128,
        "samplesDropped": defenceSamplesDropped, "sampleIntervalSkipped": defenceIntervalSkipped,
        "valuesTruncated": defenceValuesTruncated, "recorderIncidentsDropped": trace.dropped,
        "audioEventsDropped": audioEventsDropped, "outputSamplesDropped": outputSamplesDropped,
        "outputIncidentsDropped": outputIncidentsDropped,
      ]
      guard
        let data = try? JSONSerialization.data(
          withJSONObject: payload, options: [.sortedKeys, .withoutEscapingSlashes])
      else {
        print("STATION_DEFENCE_TRACE_REFUSED encoding")
        return
      }
      if data.count < 65536 {
        print(String(decoding: data, as: UTF8.self))
        return
      }
      // Keep the newest causal window and explicitly count every output-budget omission.
      if !samples.isEmpty {
        samples.removeFirst()
        outputSamplesDropped += 1
      } else if !incidents.isEmpty {
        incidents.removeFirst()
        outputIncidentsDropped += 1
      } else {
        print("STATION_DEFENCE_TRACE_REFUSED limit=65536")
        return
      }
    }
  }
}

/// Read-only borrowed access keeps actor field materialization out of the deep
/// exact native geometry/validation query. This owner retains no Game or authority.
private enum ScriptProcurementPreflightObservation {
  @inline(never)
  static func facts(_ game: borrowing Game) -> ScriptProcurementPreflightFacts {
    var facts = ScriptProcurementPreflightFacts()
    guard let context = game.gameplayContext(),
      let player = game.commander.flightSimulation.player,
      let owner = game.commander.equipmentOwnerID,
      context.player.identity == player, player.system == context.system,
      player.visit == context.visit, context.revision == game.gameplayRevision,
      context.system == game.systemIdentity, context.visit == game.commander.flightSimulation.visit,
      context.physicalTime.isFinite, context.physicalTime >= 0,
      context.physicalTime == game.commander.flightSimulation.physicalTime,
      game.energy.isFinite, game.speed.isFinite,
      game.commander.performance.pitch.isFinite, game.commander.performance.pitch > 0,
      game.commander.performance.yaw.isFinite, game.commander.performance.yaw > 0
    else { return facts }
    facts.identity = .init(
      player: player, epoch: game.ecmControl.epoch, stationEpoch: game.nativeStationRuntimeEpoch,
      owner: owner, revision: game.gameplayRevision, physicalTime: context.physicalTime)
    facts.legal = game.commander.legal
    facts.mainTargetCurrent = mainTargetIsCurrent(game)
    facts.docked = game.docked
    if game.screen.isFlight {
      facts.live = game.energy > 0
    } else {
      facts.live = false
    }
    facts.paused = game.paused
    if game.autoPilot.targetID != nil {
      facts.automaticEngaged = true
    } else if game.workGuidance != nil {
      facts.automaticEngaged = true
    } else {
      facts.automaticEngaged = game.workBraking != nil
    }
    facts.combatLaser = game.selectedFlightTool == .combatLaser
    if game.screen == .front {
      facts.frontLaser = game.commander.laser(on: .front) != nil
    } else {
      facts.frontLaser = false
    }
    facts.speed = game.speed
    facts.pitchRate = game.commander.performance.pitch
    facts.yawRate = game.commander.performance.yaw
    if game.frontShield.isFinite, game.commander.shieldCapacity.isFinite,
      game.commander.shieldCapacity > 0
    {
      facts.frontShieldLow = game.frontShield <= game.commander.shieldCapacity * 0.5
    } else {
      facts.frontShieldLow = false
    }
    if game.rearShield.isFinite, game.commander.rearShieldCapacity.isFinite,
      game.commander.rearShieldCapacity > 0
    {
      facts.rearShieldLow = game.rearShield <= game.commander.rearShieldCapacity * 0.5
    } else {
      facts.rearShieldLow = false
    }
    if game.commander.laser(on: .front) == .pulse, game.laserHeat.isFinite {
      facts.pulseHeatBlocked = max(0, game.laserHeat - 0.1 * 12) >= 240
    } else {
      facts.pulseHeatBlocked = false
    }
    var threats: [ScriptProcurementPreflightThreat] = []
    for body in game.bodies where body.hull.isTargetShip {
      if !body.energy.isFinite && body.hostile { return facts }
      guard body.energy > 0 else { continue }
      guard let physical = body.physical else {
        if body.hostile { return facts }
        continue
      }
      if body.hostile && physical.npc?.intention != .engage(player) { return facts }
      guard physical.npc?.intention == .engage(player) else { continue }
      guard physical.identity != player, physical.identity.system == context.system,
        physical.identity.visit == context.visit, body.energy.isFinite,
        body.position.finite, body.position.length.isFinite,
        game.bodies.filter({ $0.physical?.identity == physical.identity }).count == 1,
        context.actors.filter({ $0.identity == physical.identity && $0.energy > 0 }).count == 1
      else { return facts }
      threats.append(
        .init(
          identity: physical.identity, position: body.position,
          wanted: physical.npc?.legal.wanted == true
            && !context.protection.protectedActors.contains(physical.identity),
          pulseOnly: ScriptProcurementRangePolicy.pulseOnly(body, context: context),
          closingMargin: ScriptProcurementRangePolicy.closingMargin(body, context: context) ?? 0))
    }
    facts.threats = threats
    let immediate = threats.filter(\.immediate)
    facts.threat = (immediate.isEmpty ? threats : immediate).min {
      $0.position.length == $1.position.length
        ? $0.identity.entity < $1.identity.entity : $0.position.length < $1.position.length
    }
    for body in game.bodies where body.energy > 0 {
      if body.enemyMissile || body.scriptShot != nil
        || (body.hull == .missile && body.playerMissileTarget == nil
          && body.physical?.ordnance == nil)
      {
        facts.incoming = true
      }
      guard let physical = body.physical, let ordnance = physical.ordnance,
        ordnance.target == player, ordnance.termination == nil
      else { continue }
      guard ordnance.valid, physical.identity == ordnance.origin.ordnance,
        physical.identity.system == context.system, physical.identity.visit == context.visit,
        physical.attackOrigin == ordnance.origin,
        ordnance.origin.emittedAt <= context.physicalTime
      else { return facts }
      facts.incoming = true
    }
    if facts.threat == nil && !facts.incoming {
      facts.valid = true
      return facts
    }
    // CrimeLedger's current 1200-unit rule, conservatively applied to every current station.
    let anchorRange = (context.player.position - context.anchors.station.position).length
    guard anchorRange.isFinite else { return facts }
    var stationRanges = [anchorRange]
    for body in game.bodies where body.hull == .station && body.energy > 0 {
      guard let physical = body.physical,
        physical.identity.system == context.system, physical.identity.visit == context.visit,
        body.position.finite, body.position.length.isFinite
      else { return facts }
      if body.nativeStationIdentity != nil {
        guard game.nativeStationBodyIsCurrent(body) else { return facts }
      } else {
        guard body.id == 0, physical.identity == context.anchors.station.identity else {
          return facts
        }
      }
      stationRanges.append(body.position.length)
    }
    facts.outsideNoFireZones = ScriptProcurementPreflightFacts.clearsEveryNoFireZone(stationRanges)
    if let threat = facts.threat, threat.wanted,
      facts.combatLaser, facts.frontLaser,
      let contact = try? game.nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000, radius: 0,
        excludingBodyIDs: [], includePlayer: false),
      case .body(let id) = contact.hit.target,
      let body = game.bodies.first(where: { $0.id == id })
    {
      facts.exactForwardHit = body.physical?.identity == threat.identity
      if facts.exactForwardHit {
        if game.commander.crimeLedger.hasCurrentUnlawfulAttack(
          from: threat.identity, against: player, context: context)
        {
          facts.lawfulForwardDefence = game.commander.crimeLedger.permitsAutonomousDefence(
            owner: player, victim: threat.identity, context: context)
        } else {
          facts.lawfulForwardDefence = false
        }
      }
    }
    facts.valid = true
    return facts
  }
  @inline(never)
  static func mainTargetIsCurrent(_ game: borrowing Game) -> Bool {
    guard let target = game.autoTargetBody, target.id == 0, target.hull == .station,
      let actor = target.physical?.identity,
      let flightPlayer = game.commander.flightSimulation.player,
      actor == game.commander.flightSimulation.anchors?.station.identity,
      actor.system == flightPlayer.system, actor.visit == flightPlayer.visit,
      game.autoPilot.targetActor == actor
    else { return false }
    return true
  }
}

extension GameRuntime {
  /// Rejoin living current actors on every step; observations grant no law authority.
  @inline(never)
  func procurementPreflightFacts() -> ScriptProcurementPreflightFacts {
    ScriptProcurementPreflightObservation.facts(game)
  }

  @inline(never)
  func procurementDefensiveMainTargetIsCurrent() -> Bool {
    ScriptProcurementPreflightObservation.mainTargetIsCurrent(game)
  }

  /// Recheck raw current facts and cancel through the genuine key path in this actor turn.
  func procurementCancelForThreat(expected: ScriptProcurementPreflightFacts, steps: Int) -> Bool {
    let current = procurementPreflightFacts()
    guard current.rejoins(expected),
      current.requestedDockAction(defensive: true, steps: steps) == .react
    else { return false }
    key("q")
    setControls(Controls())
    let cancelled = procurementPreflightFacts()
    return cancelled.valid && cancelled.live && !cancelled.paused && !cancelled.docked
      && !cancelled.automaticEngaged && cancelled.identity?.player == current.identity?.player
  }

  /// A policy request is not native emission permission. Rejoin immediately before normal advance.
  /// No await, source/hit factory or observer callback occurs between controls and that advance.
  func procurementPilotStep(
    expected: ScriptProcurementPreflightFacts, steps: Int, automatic: Bool, diagnostic: Bool,
    retreat: ScriptProcurementRetreat? = nil
  ) -> ScriptProcurementPilotStepResult {
    let facts = procurementPreflightFacts()
    guard facts.rejoins(expected) else { return .init(status: .refused) }
    if automatic {
      let action = facts.requestedDockAction(defensive: true, steps: steps)
      if action == .react { return .init(status: .react) }
      guard action == .automatic, facts.automaticEngaged,
        !controls.fire, controls.pitch == 0, controls.yaw == 0, controls.roll == 0,
        controls.throttle == 0
      else { return .init(status: .refused) }
    } else {
      let action = facts.requestedAction(steps: steps)
      guard action == .track || action == .requestFire else { return .init(status: .refused) }
      var input = Controls()
      let steeringThreat: ScriptProcurementPreflightThreat?
      if let retreat {
        guard let target = facts.threats.first(where: { $0.identity == retreat.target }),
          target.pulseOnly, facts.threats.allSatisfy(\.pulseOnly),
          retreat.turnSign == -1 || retreat.turnSign == 1
        else { return .init(status: .refused) }
        steeringThreat = target
      } else {
        steeringThreat = facts.threat
      }
      let breakingAway = retreat?.mode == .breakAway
      input.throttle = 1
      if let threat = steeringThreat {
        let p = breakingAway ? threat.position * -1 : threat.position
        let angle = atan2(p.x, p.z)
        // Keep the chosen break-turn side across the +/-pi seam until facing away.
        let yaw =
          breakingAway && p.z < 0 ? retreat.map { abs(angle) * $0.turnSign } ?? angle : angle
        input.pitch = max(-1, min(1, atan2(p.y, hypot(p.x, p.z)) * 1.8 / facts.pitchRate))
        input.yaw = max(-1, min(1, yaw * 1.8 / facts.yawRate))
      }
      // The selected ray/law facts can authorize only that same steering actor.
      let combatMatches = retreat.map { $0.permitsCombat(facts) } ?? true
      input.fire = combatMatches && action == .requestFire
      setControls(input)
    }
    let before =
      diagnostic
      ? procurementFlightDiagnosticFacts(manual: automatic ? nil : facts, steps: steps) : nil
    let startTime = game.commander.flightSimulation.physicalTime
    _ = advance(delta: 0.1)
    if !automatic { setControls(Controls()) }
    let endTime = game.commander.flightSimulation.physicalTime
    let tolerance = min(1e-8, 2 * max(startTime.ulp, endTime.ulp))
    let advanced = endTime > startTime && abs(endTime - startTime - 0.1) <= tolerance
    return .init(
      status: advanced ? (automatic ? .automatic : .defensive) : .refused,
      legal: game.commander.legal, docked: game.docked,
      nativeDockIsCurrent: game.nativeMainStationDockEvidenceIsCurrent,
      dockSequence: game.commander.nativeStations?.currentMainDock?.sequence,
      before: before, after: diagnostic ? procurementFlightDiagnosticFacts() : nil)
  }

  /// Scalar reads only; numeric strings preserve nonfinite values without JSON NaN failures.
  func procurementFlightDiagnosticFacts(
    manual: ScriptProcurementPreflightFacts? = nil, steps: Int = 0
  ) -> ScriptProcurementFlightDiagnosticFacts {
    let facts = procurementFlightFacts()
    let stationContainsPlayer =
      game.bodies.first { $0.id == 0 && $0.hull == .station }
      .map { String($0.containsPlayer) } ?? "unavailable"
    let player = game.commander.flightSimulation.player
    let playerActiveMissiles = game.bodies.reduce(into: 0) { count, body in
      guard let player, body.hull == .missile, body.energy > 0,
        let ordnance = body.physical?.ordnance, ordnance.profile.attackKind == .missile,
        ordnance.origin.owner == player, ordnance.termination == nil
      else { return }
      count += 1
    }
    var scalars: [String: String] = [
      "docked": String(facts.docked), "live": String(facts.live),
      "paused": String(facts.paused), "screen": String(describing: game.screen),
      "energy": String(game.energy), "energyFinite": String(game.energy.isFinite),
      "frontShield": String(game.frontShield), "rearShield": String(game.rearShield),
      "cabinTemperature": String(game.cabinTemperature), "altitude": String(game.altitude),
      "system": String(game.commander.system),
      "visit": String(game.commander.flightSimulation.visit),
      "physicalTime": String(game.commander.flightSimulation.physicalTime),
      "calendarSeconds": String(game.commander.scriptState.calendarSeconds),
      "missionSeconds": game.commander.scriptState.missionCalendar.map { String($0.seconds) }
        ?? "unavailable",
      "fuel": String(game.commander.fuel), "credits": String(game.commander.credits),
      "missilesRemaining": String(game.commander.missiles),
      "playerActiveMissiles": String(playerActiveMissiles),
      "legal": String(game.commander.legal),
      "cargoTonnes": String(game.commander.cargoTonnes),
      "speed": String(game.speed), "roll": String(game.roll),
      "autoPilotStatus": String(game.autoPilot.status.prefix(80)),
      "finalApproach": String(game.autoPilot.finalApproach),
      "positionError": String(game.autoPilot.positionError),
      "phaseError": String(game.autoPilot.phaseError),
      "rateError": String(game.autoPilot.rateError),
      "targetID": game.autoPilot.targetID.map { String($0) } ?? "nil",
      "mainStationContainsPlayer": stationContainsPlayer,
      "gameplayRevisionFrameStamp": String(game.gameplayRevision),
      "stationImpactRevisionFrameStamp": game.stationImpactRevision.map { String($0) } ?? "nil",
      "message": String(game.message.prefix(160)),
    ]
    if let manual {
      let threat =
        manual.threat.map {
          "\($0.identity.system.galaxy)/\($0.identity.system.system)/\($0.identity.visit)/\($0.identity.entity)"
        } ?? "nil"
      let position =
        manual.threat.map {
          "\($0.position.x),\($0.position.y),\($0.position.z)"
        } ?? "nil"
      let pilotScalars: [String: String] = [
        "pilotAction": String(describing: manual.requestedAction(steps: steps)),
        "pilotThreat": threat, "pilotPosition": position,
        "pilotWanted": manual.threat.map { String($0.wanted) } ?? "nil",
        "pilotIncoming": String(manual.incoming),
        "pilotZoneClear": String(manual.outsideNoFireZones),
        "pilotExactRay": String(manual.exactForwardHit),
        "pilotCombatTool": String(manual.combatLaser),
        "pilotFrontLaser": String(manual.frontLaser), "pilotPitch": String(controls.pitch),
        "pilotYaw": String(controls.yaw), "pilotFire": String(controls.fire),
        "pilotCooldown": String(game.fireCooldown), "pilotHeat": String(game.laserHeat),
        "pilotEMPDisabled": String(game.playerEMPDisabled),
        "pilotWorkSuspended": String(game.workFireSuspended),
      ]
      scalars.merge(pilotScalars) { _, new in new }
    }
    return .init(
      docked: facts.docked, live: facts.live, paused: facts.paused, scalars: scalars,
      defence: game.stationDefenceDiagnosticSnapshot())
  }
  /// At-failure reads only: no actor adoption, key, advance, publication or forced target.
  func procurementSelectionFailureDetail(
    _ diagnostic: ScriptProcurementSelectionDiagnostic, tabAttempts: Int
  ) -> String {
    let flight = game.commander.flightSimulation
    let main = game.bodies.first { $0.id == 0 }
    let mainActor = main?.physical?.identity
    let selected = game.autoTargetBody
    let instance = diagnostic.instance.flatMap { game.commander.scriptState.instances[$0] }
    let deadline = instance?.contract?.deadline
    var fields: [String: String] = [
      "fixture": diagnostic.label, "tabAttempts": String(tabAttempts),
      "live": String(procurementFlightFacts().live), "paused": String(game.paused),
      "docked": String(game.docked), "screen": String(describing: game.screen),
      "EMP": String(game.playerEMPDisabled), "message": String(game.message.prefix(128)),
      "galaxy": String(game.commander.galaxy), "system": String(game.commander.system),
      "visit": String(flight.visit),
      "player": ScriptProcurementSelectionDiagnostic.actor(flight.player),
      "anchor": ScriptProcurementSelectionDiagnostic.actor(flight.anchors?.station.identity),
      "tier": game.commander.targetingTier.map { String($0.rawValue) } ?? "nil",
      "filter": game.workTargetFilter.label,
      "targetID": game.autoPilot.targetID.map { String($0) } ?? "nil",
      "targetActor": ScriptProcurementSelectionDiagnostic.actor(game.autoPilot.targetActor),
      "resolvedID": selected.map { String($0.id) } ?? "nil",
      "resolvedActor": ScriptProcurementSelectionDiagnostic.actor(selected?.physical?.identity),
      "mainPresent": String(main != nil),
      "mainHull": main.map { String(describing: $0.hull) } ?? "nil",
      "mainEnergy": main.map { String($0.energy) } ?? "nil",
      "mainDistance": main.map { String($0.position.length) } ?? "nil",
      "mainPoseValid": String(
        main.map { $0.position.finite && game.modelPose(of: $0).orientation.validRotation } ?? false
      ),
      "mainActor": ScriptProcurementSelectionDiagnostic.actor(mainActor),
      "mainCurrentJoin": String(
        mainActor.map { $0.system == game.systemIdentity && $0.visit == flight.visit } ?? false),
      "mainAnchorJoin": String(mainActor != nil && mainActor == flight.anchors?.station.identity),
      "mainActorBodies": mainActor.map { actor in
        String(game.bodies.filter { $0.physical?.identity == actor }.count)
      } ?? "nil",
      "revision": String(game.gameplayRevision), "physicalTime": String(flight.physicalTime),
      "missionClock": game.commander.scriptState.missionCalendar.map { String($0.seconds) }
        ?? "nil",
      "missionInstance": diagnostic.instance?.uuidString ?? "nil",
      "missionDeadline": deadline.map { String($0) } ?? "nil",
      "missionOutcome": instance.map { String(describing: $0.outcome) } ?? "nil",
      "context": "false", "mainDecision": "no-context", "eligibleCount": "unavailable",
      "freshMainChoiceRank": "unavailable",
      "rankBasis": "fresh-WorkTargetSelection-not-visited-TAB-cycle",
    ]
    if let context = game.gameplayContext() {
      fields["context"] = "true"
      let layout = CockpitLayout(game: game, width: game.viewportWidth, height: game.viewportHeight)
      let frontIDs = Set(
        game.bodies.filter { Display.visibleInFront($0, game: game, layout: layout) }.map(\.id))
      let candidates: [WorkTargetCandidate] = game.bodies.compactMap {
        game.workTargetCandidate(for: $0, context: context, frontVisible: frontIDs.contains($0.id))
      }
      let capabilities = game.workTargetCapabilities
      let choices = WorkTargetSelection.ordered(
        candidates, filter: game.workTargetFilter, system: context.system, visit: context.visit,
        capabilities: capabilities)
      let identities = Set(choices.map { $0.candidate.identity })
      fields["eligibleCount"] = String(
        game.bodies.filter { $0.physical.map { identities.contains($0.identity) } == true }.count)
      if let candidate = candidates.first(where: { $0.identity == mainActor }) {
        fields["mainDecision"] = String(
          describing: WorkTargetSelection.evaluate(
            candidate, system: context.system, visit: context.visit, capabilities: capabilities))
      } else {
        fields["mainDecision"] = "no-candidate"
      }
      // Fresh policy rank only; TAB also retains its private visited cycle and uses scene-ID ties.
      if let rank = choices.firstIndex(where: { $0.candidate.identity == mainActor }) {
        fields["freshMainChoiceRank"] = String(rank + 1)
      }
    }
    return ScriptProcurementSelectionDiagnostic.message(fields)
  }

  func procurementTargetIsMain() -> Bool { game.autoTargetBody?.id == 0 }
  func procurementFlightFacts() -> (docked: Bool, live: Bool, paused: Bool) {
    (game.docked, game.screen != .gameOver && game.energy > 0, game.paused)
  }
  func procurementNativeDockIsCurrent() -> Bool { game.nativeMainStationDockEvidenceIsCurrent }
  func procurementMassLocked() -> Bool { game.massLocked }
  func procurementJumping() -> Bool { game.jumpCountdown != nil }
  func procurementCurrentSystem() -> Int { game.commander.system }
  func procurementSystemCoordinate(_ id: Int) -> (Double, Double) {
    (game.systems[id].x, game.systems[id].y)
  }
  /// Actual paid Fuel transaction at the repeated-trip caller's genuine turnaround dock.
  func procurementRefuelForTurnaround(expectedSystem: Int) throws {
    guard game.commander.system == expectedSystem, game.docked, !game.paused,
      game.nativeMainStationDockEvidenceIsCurrent, game.commander.valid,
      let index = Equipment.all.firstIndex(where: { $0.name == "Fuel" })
    else { throw SaveError.invalidCommander }
    let item = Equipment.all[index]
    let price = game.shopPrice(item)
    let before = game.commander
    guard game.equipmentAvailable(item), !before.unlimitedCash, !before.unlimitedFuel,
      price >= 0, before.availableCredits >= price,
      before.fuel == before.fuelCapacity || price > 0
    else { throw EquipmentRuntimeError.unavailable }
    try scriptCommand { candidate in
      candidate.selection = index
      let result = candidate.purchaseImmediately()
      guard result == .applied(.purchase(item: "Fuel", physicalItem: nil, fitted: true)),
        candidate.commander.fuel == before.fuelCapacity,
        candidate.commander.credits == before.credits - price,
        candidate.commander.cargo == before.cargo,
        candidate.commander.scriptState == before.scriptState,
        candidate.commander.contracts == before.contracts,
        candidate.commander.nativePeople == before.nativePeople,
        candidate.commander.equipmentInventory == before.equipmentInventory,
        candidate.commander.equipmentPurchaseHistory == before.equipmentPurchaseHistory,
        candidate.nativeMainStationDockEvidenceIsCurrent, candidate.commander.valid
      else { throw SaveError.invalidCommander }
    }
    guard game.commander.fuel == before.fuelCapacity,
      game.commander.credits == before.credits - price,
      game.commander.cargo == before.cargo, game.commander.scriptState == before.scriptState,
      game.nativeMainStationDockEvidenceIsCurrent
    else { throw SaveError.invalidCommander }
  }

  func procurementDepartureReadiness(origin: Int, destination: Int, atDock: Bool)
    -> (allowed: Bool, detail: String)
  {
    guard game.systems.indices.contains(destination) else {
      return (false, "Expiry travel destination is outside the actual galaxy.")
    }
    let distance = game.currentSystem.distance(to: game.systems[destination])
    let flight = procurementFlightFacts()
    let allowed =
      flight.live && !flight.paused && game.commander.system == origin
      && distance <= game.commander.maximumJumpDistance && game.jumpCountdown == nil
      && !game.playerEMPDisabled
      && (atDock
        ? game.docked && game.nativeMainStationDockEvidenceIsCurrent
        : !game.docked && game.screen.isFlight && game.selectedSystem == destination
          && !game.hyperspaceMassLocked)
    return (allowed, procurementJumpRefusalDetail(destination: destination))
  }

  /// A bounded observation of the actual guard inputs/message, never a guessed refusal cause.
  func procurementJumpRefusalDetail(destination: Int) -> String {
    let distance =
      game.systems.indices.contains(destination)
      ? String(game.currentSystem.distance(to: game.systems[destination])) : "invalid"
    let detail =
      "Expiry jump: sys=\(game.commander.system) selected=\(game.selectedSystem)"
      + " wanted=\(destination) fuel=\(game.commander.fuel) distance=\(distance)"
      + " reach=\(game.commander.maximumJumpDistance) docked=\(game.docked)"
      + " live=\(procurementFlightFacts().live) paused=\(game.paused)"
      + " screen=\(game.screen) energy=\(game.energy) countdown=\(String(describing: game.jumpCountdown))"
      + " physicalTime=\(game.commander.flightSimulation.physicalTime)"
      + " EMP=\(game.playerEMPDisabled) lock=\(game.hyperspaceMassLocked)"
      + " message=\(game.message.prefix(120))"
    return String(
      decoding: detail.utf8.prefix(1024).map { (32...126).contains($0) ? $0 : 63 }, as: UTF8.self)
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
