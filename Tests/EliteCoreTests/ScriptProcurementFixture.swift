import Foundation
import Testing

@testable import EliteCore

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
  func nativeRuntime(diagnostic: ScriptProcurementFlightDiagnostic? = nil) async throws
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
    let runtime = GameRuntime(game: game, saveURL: save)
    try await runtime.save(to: save)
    await runtime.key("0")
    try await Self.dock(runtime, diagnostic: diagnostic, phase: "initial-dock")
    return runtime
  }
  static func dock(
    _ runtime: GameRuntime, diagnostic: ScriptProcurementFlightDiagnostic? = nil,
    phase: String = "dock", defensivePreflight: Bool = false
  ) async throws {
    var steps = 0
    if defensivePreflight {
      try await preflight(runtime, steps: &steps, diagnostic: diagnostic, phase: phase)
    }
    for _ in 0..<32 {
      let main = await runtime.procurementTargetIsMain()
      if main { break }
      await runtime.key("tab")
    }
    let targeted = await runtime.procurementTargetIsMain()
    try #require(targeted)
    let automaticStart = steps
    while steps < 3000 {
      let facts = await runtime.procurementFlightFacts()
      if facts.docked { break }
      try #require(facts.live && !facts.paused)
      if let diagnostic {
        await diagnosticAdvance(runtime, diagnostic: diagnostic, phase: phase, step: steps)
      } else {
        _ = await runtime.advance(delta: 0.1)
      }
      steps += 1
    }
    let docked = await runtime.procurementNativeDockIsCurrent()
    try #require(steps > 0 && steps < 3000 && docked)
    if defensivePreflight { try #require(steps > automaticStart) }
  }
  static func travel(
    _ runtime: GameRuntime, path: [Int], diagnostic: ScriptProcurementFlightDiagnostic? = nil,
    defensivePreflight: Bool = false
  ) async throws {
    for destination in path.dropFirst() {
      let leg = diagnostic == nil ? "" : "travel-leg-\(path.firstIndex(of: destination) ?? 0)"
      await runtime.key("0")
      var controls = Controls()
      controls.throttle = 1
      await runtime.setControls(controls)
      var departure = 0
      while departure < 300 {
        let locked = await runtime.procurementMassLocked()
        if !locked { break }
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
      await runtime.key("h")
      let started = await runtime.procurementJumping()
      try #require(started)
      var steps = 0
      while steps < 500 {
        let jumping = await runtime.procurementJumping()
        if !jumping { break }
        if let diagnostic {
          await diagnosticAdvance(
            runtime, diagnostic: diagnostic, phase: leg + "-jump", step: steps)
        } else {
          _ = await runtime.advance(delta: 0.1)
        }
        steps += 1
      }
      let system = await runtime.procurementCurrentSystem()
      try #require(steps > 0 && steps < 500 && system == destination)
      try await dock(
        runtime, diagnostic: diagnostic, phase: diagnostic == nil ? "" : leg + "-dock",
        defensivePreflight: defensivePreflight)
      if destination != path.last { await runtime.procurementRefuel() }
    }
  }
  private static func preflight(
    _ runtime: GameRuntime, steps: inout Int,
    diagnostic: ScriptProcurementFlightDiagnostic?, phase: String
  ) async throws {
    var facts = await runtime.procurementPreflightFacts()
    // No threat means no additional input or physical advance before the original AUTO path.
    if facts.requestedAction(steps: steps) == .clear { return }
    for _ in 0..<4 {
      if facts.combatLaser { break }
      let viable = facts.requestedAction(steps: steps) != .refuse
      try #require(viable, "Preflight unavailable before tool selection")
      await runtime.key("w")
      facts = await runtime.procurementPreflightFacts()
    }
    while steps < 3000 {
      let action = facts.requestedAction(steps: steps)
      if action == .clear { break }
      let viable = action != .refuse
      try #require(viable, "Preflight refused at step \(steps); no AUTO engagement")
      var controls = Controls()
      controls.throttle = facts.speed > 0 ? -1 : 0
      if let threat = facts.threat {
        let p = threat.position
        controls.pitch = max(-1, min(1, atan2(p.y, hypot(p.x, p.z)) * 1.8 / facts.pitchRate))
        controls.yaw = max(-1, min(1, atan2(p.x, p.z) * 1.8 / facts.yawRate))
      }
      controls.fire = action == .requestFire
      await runtime.setControls(controls)
      if let diagnostic {
        await diagnosticAdvance(
          runtime, diagnostic: diagnostic, phase: phase + "-preflight", step: steps)
      } else {
        _ = await runtime.advance(delta: 0.1)
      }
      steps += 1
      facts = await runtime.procurementPreflightFacts()
    }
    let cleared = facts.requestedAction(steps: steps) == .clear
    try #require(cleared, "Preflight exhausted original dock budget at step \(steps)")
    // All manual input ends before the bounded Tab selection and desired main-station lock.
    await runtime.setControls(Controls())
  }
  private static func diagnosticAdvance(
    _ runtime: GameRuntime, diagnostic: ScriptProcurementFlightDiagnostic, phase: String, step: Int
  ) async {
    guard await diagnostic.active else {
      _ = await runtime.advance(delta: 0.1)
      return
    }
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

enum ScriptProcurementPreflightAction: Equatable {
  case refuse, clear, track, requestFire
}

struct ScriptProcurementPreflightThreat: Sendable {
  let identity: ActorIdentity
  let position: Vector3
  let wanted: Bool
}

/// Test policy values are never accepted by a native hit, law, source or receipt producer.
struct ScriptProcurementPreflightFacts: Sendable {
  var valid = false
  var docked = false
  var live = false
  var paused = false
  var automaticEngaged = false
  var threat: ScriptProcurementPreflightThreat?
  var incoming = false
  var outsideNoFireZones = false
  var exactForwardHit = false
  var combatLaser = false
  var frontLaser = false
  var speed = 0.0
  var pitchRate = 0.0
  var yawRate = 0.0

  static func clearsEveryNoFireZone(_ ranges: [Double]) -> Bool {
    !ranges.isEmpty && ranges.allSatisfy { $0.isFinite && $0 > 1200 }
  }

  func requestedAction(steps: Int) -> ScriptProcurementPreflightAction {
    guard valid, live, !docked, !paused, !automaticEngaged,
      steps >= 0, steps < 3000
    else { return .refuse }
    guard threat != nil || incoming else { return .clear }
    guard threat?.wanted == true, outsideNoFireZones, exactForwardHit,
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
}

/// Test-only, opt-in state. It retains no Game, Commander, actor inventory or authority.
actor ScriptProcurementFlightDiagnostic {
  private var emitted = false
  private var lastLive: [String: String]?
  var active: Bool { !emitted }

  func record(
    before: ScriptProcurementFlightDiagnosticFacts,
    after: ScriptProcurementFlightDiagnosticFacts, phase: String, step: Int
  ) {
    guard !emitted else { return }
    if before.live && !before.paused {
      var scalars = before.scalars
      scalars["phase"] = phase
      scalars["step"] = String(step)
      lastLive = scalars
    }
    guard !after.docked, !after.live || after.paused else { return }
    emitted = true
    var failure = after.scalars
    failure["phase"] = phase
    failure["step"] = String(step + 1)
    let payload: [String: Any] = [
      "kind": "procurement-flight-first-failure",
      "lastLivePreAdvance": lastLive ?? [:],
      "firstFailurePostAdvance": failure,
      "immediatePreAdvanceWasLive": before.live && !before.paused,
    ]
    do {
      let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
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
}

extension GameRuntime {
  /// Rejoin living current actors on every step; neither intent nor this query grants law authority.
  func procurementPreflightFacts() -> ScriptProcurementPreflightFacts {
    var facts = ScriptProcurementPreflightFacts()
    guard let context = game.gameplayContext(),
      let player = game.commander.flightSimulation.player,
      context.player.identity == player, player.system == context.system,
      player.visit == context.visit, context.revision == game.gameplayRevision,
      game.energy.isFinite, game.speed.isFinite,
      game.commander.performance.pitch.isFinite, game.commander.performance.pitch > 0,
      game.commander.performance.yaw.isFinite, game.commander.performance.yaw > 0
    else { return facts }
    facts.docked = game.docked
    facts.live = game.screen.isFlight && game.energy > 0
    facts.paused = game.paused
    facts.automaticEngaged = game.autoTargetBody?.hull == .station
    facts.combatLaser = game.selectedFlightTool == .combatLaser
    facts.frontLaser = game.commander.laser(on: .front) != nil
    facts.speed = game.speed
    facts.pitchRate = game.commander.performance.pitch
    facts.yawRate = game.commander.performance.yaw
    var threats: [ScriptProcurementPreflightThreat] = []
    for body in game.bodies where body.energy > 0 && body.hull.isTargetShip {
      guard let physical = body.physical,
        physical.npc?.intention == .engage(player),
        !context.protection.protectedActors.contains(physical.identity)
      else { continue }
      guard physical.identity != player, physical.identity.system == context.system,
        physical.identity.visit == context.visit, body.energy.isFinite,
        body.position.finite, body.position.length.isFinite,
        game.bodies.filter({ $0.physical?.identity == physical.identity }).count == 1,
        context.actors.contains(where: { $0.identity == physical.identity && $0.energy > 0 })
      else { return facts }
      threats.append(
        .init(
          identity: physical.identity, position: body.position,
          wanted: physical.npc?.legal.wanted == true))
    }
    facts.threat = threats.min {
      $0.position.length == $1.position.length
        ? $0.identity.entity < $1.identity.entity : $0.position.length < $1.position.length
    }
    for body in game.bodies where body.energy > 0 {
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
    if let threat = facts.threat, threat.wanted, facts.outsideNoFireZones,
      facts.combatLaser, facts.frontLaser,
      let contact = try? game.nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000, radius: 0,
        excludingBodyIDs: [], includePlayer: false),
      case .body(let id) = contact.hit.target,
      let body = game.bodies.first(where: { $0.id == id })
    {
      facts.exactForwardHit = body.physical?.identity == threat.identity
    }
    facts.valid = true
    return facts
  }
  /// Scalar reads only; numeric strings preserve nonfinite values without JSON NaN failures.
  func procurementFlightDiagnosticFacts() -> ScriptProcurementFlightDiagnosticFacts {
    let facts = procurementFlightFacts()
    let stationContainsPlayer =
      game.bodies.first { $0.id == 0 && $0.hull == .station }
      .map { String($0.containsPlayer) } ?? "unavailable"
    return .init(
      docked: facts.docked, live: facts.live, paused: facts.paused,
      scalars: [
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
      ])
  }
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
