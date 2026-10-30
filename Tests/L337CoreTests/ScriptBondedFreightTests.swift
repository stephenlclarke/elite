import Foundation
import Testing

@testable import L337Core

/// Content mutation is confined to a temporary fixture, never the packaged legacy profile.
private struct BondedFreightFixture {
  let legacy: ScriptFreightFixture
  let pack: ScriptPack
  init(manifestEdit: ((String) -> String)? = nil) throws {
    let original = try ScriptFreightFixture()
    legacy = original
    var ready = false
    defer { if !ready { original.clean() } }
    let folder = original.root.appendingPathComponent("pack")
    let manifestURL = folder.appendingPathComponent("manifest.toml")
    var manifest = try String(contentsOf: manifestURL, encoding: .utf8)
    manifest = manifest.replacingOccurrences(
      of: "id = \"project.generated-supplied-freight\"",
      with: "id = \"l337.contract\"")
    manifest = manifest.replacingOccurrences(
      of: "[mission]\nid = \"freight\"", with: "[mission]\nid = \"bonded-freight\"")
    manifest = manifest.replacingOccurrences(
      of: "profile = \"PROJECT-SPACE-G03-1\"",
      with: "profile = \"l337.contract/bonded-freight\"\nbondedHazardTiers = [0, 1, 2]")
    if let manifestEdit { manifest = manifestEdit(manifest) }
    try manifest.write(to: manifestURL, atomically: true, encoding: .utf8)
    let scriptURL = folder.appendingPathComponent("scripts/main.lua")
    let script = try String(contentsOf: scriptURL, encoding: .utf8)
      .replacingOccurrences(of: "deposit = 0", with: "deposit = plan.deposit")
    try script.write(to: scriptURL, atomically: true, encoding: .utf8)
    pack = try ScriptPackLibrary.read(folder)
    ready = true
  }

  func nativeRuntime() async throws -> GameRuntime {
    var game = try ScriptProcurementFixture.freshG03FlightGame()
    game.scriptPacks = [pack]
    try game.prepareG03FlightEquipment()
    let runtime = GameRuntime(game: game, saveURL: legacy.save)
    try await runtime.save(to: legacy.save)
    await runtime.key("0")
    try await ScriptProcurementFixture.dock(runtime)
    return runtime
  }

  /// Corrupt and rehash a real versioned chunk, then restore all bytes after the refusal.
  func rejectSavedPlan(
    chunk: String, change: (inout [String: Any]) -> Void
  ) throws {
    let pointerBytes = try Data(contentsOf: legacy.save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    let directory = try ScriptSaveStore.generationDirectory(pointer.generation, from: legacy.save)
    let file = directory.appendingPathComponent(chunk)
    let original = try Data(contentsOf: file)
    defer {
      try? original.write(to: file)
      try? pointerBytes.write(to: legacy.save)
    }
    var object = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
    if chunk == "contracts.json" {
      var boards = try #require(object["boards"] as? [String: Any])
      let key = try #require(boards.keys.first)
      var board = try #require(boards[key] as? [String: Any])
      var generation = try #require(board["freightGeneration"] as? [String: Any])
      var plans = try #require(generation["plans"] as? [[String: Any]])
      change(&plans[0])
      generation["plans"] = plans
      board["freightGeneration"] = generation
      boards[key] = board
      object["boards"] = boards
    } else {
      func mutate(_ instance: inout [String: Any]) throws {
        var job = try #require(instance["contract"] as? [String: Any])
        var offer = try #require(job["offer"] as? [String: Any])
        var plan = try #require(offer["freightPlan"] as? [String: Any])
        change(&plan)
        offer["freightPlan"] = plan
        job["offer"] = offer
        instance["contract"] = job
      }
      if var instances = object["instances"] as? [String: Any] {
        let key = try #require(instances.keys.first)
        var instance = try #require(instances[key] as? [String: Any])
        try mutate(&instance)
        instances[key] = instance
        object["instances"] = instances
      } else {
        var pairs = try #require(object["instances"] as? [Any])
        try #require(pairs.count == 2)
        var instance = try #require(pairs[1] as? [String: Any])
        try mutate(&instance)
        pairs[1] = instance
        object["instances"] = pairs
      }
    }
    let bytes = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    try bytes.write(to: file)
    var hashes = pointer.hashes
    hashes[chunk] = ScriptPackLibrary.hash(bytes)
    let changed = ScriptSavePointer(
      format: pointer.format, schemaVersion: pointer.schemaVersion, generation: pointer.generation,
      hashes: hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
    try JSONEncoder().encode(changed).write(to: legacy.save)
    #expect(throws: (any Error).self) {
      _ = try ScriptSaveStore.read(Data(contentsOf: legacy.save), from: legacy.save)
    }
  }

  func plans() throws -> [ScriptFreightPlan] {
    let game = try legacy.policyGame()
    let key = pack.digest + "/" + pack.manifest.board!.id + "/" + game.contractStation.key
    return try ScriptFreightGeneration.plans(
      pack: pack, commander: game.commander, origin: game.contractStation,
      revision: 0, seed: try #require(Game.pledgeBoardSeed(key, revision: 0)))
  }

  func job(_ plan: ScriptFreightPlan, at: Double = 100) throws -> ScriptContractJob {
    let boardKey = plan.content.digest + "/" + plan.content.boardID + "/" + plan.origin.key
    let offer = ScriptContractOffer(
      id: ScriptIdentity.uuid("contract-offer-v1:" + boardKey + ":0:" + plan.key),
      key: plan.key, title: "Bonded freight", briefing: "Three supplied machinery tonnes.",
      destinationGalaxy: plan.origin.galaxy, destinationSystem: try #require(plan.path.last),
      reward: plan.reward, deposit: plan.deposit, failureReward: 0, refundOnFailure: false,
      duration: plan.duration, parameters: try #require(plan.parameters), freightPlan: plan)
    return ScriptContractJob(
      boardKey: boardKey, provider: plan.content.provider, version: plan.content.version,
      digest: plan.content.digest, station: plan.origin, boardRevision: plan.boardRevision,
      group: plan.content.provider + "/" + ScriptFreightPlan.group, offer: offer,
      clock: .missionCalendar, acceptedAt: at, deadline: nil,
      deadlinePolicy: .inclusiveConfirmation)
  }
}

@Test func bondedQuoteUsesEveryQuotedRouteLegAndDeclaredHazard() {
  for legs in 1...3 {
    for hazard in [0, 1, 2, 9] {
      let quote = ScriptBondedFreightQuote(routeLegs: legs, hazardTier: hazard)
      #expect(quote.reward == 4800 + 950 * legs + 800 * hazard)
    }
  }
  #expect(ScriptBondedFreightQuote(routeLegs: 0, hazardTier: 0).reward == nil)
  #expect(ScriptBondedFreightQuote(routeLegs: 4, hazardTier: 0).reward == nil)
  #expect(ScriptBondedFreightQuote(routeLegs: 1, hazardTier: -1).reward == nil)
  #expect(ScriptBondedFreightQuote(routeLegs: 1, hazardTier: Int.max).reward == nil)
}

@Test func bondedGeneratedPlansFreezeExactGoodsDepositQuoteAndUntimedTerms() throws {
  let fixture = try BondedFreightFixture()
  defer { fixture.legacy.clean() }
  let plans = try fixture.plans()
  #expect(plans.count == 3)
  for (row, plan) in plans.enumerated() {
    #expect(plan.valid && plan.matches(fixture.pack))
    #expect(plan.quantity == 3 && plan.commodity == .machinery)
    #expect(plan.deposit == 750 && plan.duration == 0)
    #expect(plan.bondedQuote?.routeLegs == plan.path.count - 1)
    #expect(plan.bondedQuote?.hazardTier == row)
    #expect(plan.reward == 4800 + 950 * (plan.path.count - 1) + 800 * row)
    #expect(plan.successPayment == plan.reward + 750)
    #expect(ScriptFreightPlan.read(try #require(plan.parameters)) == plan)
    let job = try fixture.job(plan)
    #expect(job.valid && job.deadline == nil)
    #expect(plan.permitsDelivery(at: 1e12, deadline: nil))
    #expect(!plan.permitsExpiry(at: 1e12, deadline: nil))
  }
}

@Test func bondedQuoteAndHazardCannotBeRewrittenOrUsedByLegacyProfile() throws {
  let fixture = try BondedFreightFixture()
  defer { fixture.legacy.clean() }
  let original = try #require(fixture.plans().first)
  var changed = original
  changed.bondedQuote = .init(routeLegs: original.path.count - 1, hazardTier: 99)
  #expect(!changed.valid)
  changed = original
  changed.bondedQuote = .init(routeLegs: original.path.count, hazardTier: 0)
  #expect(!changed.valid)
  changed = original
  changed.bondedHazardTiers = nil
  #expect(!changed.valid)
  let legacy = try ScriptFreightFixture()
  defer { legacy.clean() }
  let legacyPlans = try legacy.plans(legacy.policyGame())
  for plan in legacyPlans {
    #expect(plan.valid && !plan.isBonded && plan.deposit == 0)
    #expect(plan.quantity == [1, 5, 10][plan.row])
    #expect(plan.duration == (plan.row == 2 ? 259200 : 172800))
    #expect(plan.bondedQuote == nil && plan.bondedHazardTiers == nil)
  }
}

@Test func bondedSettlementUsesExistingRewardPlusDepositAndRejectsDuplicate() throws {
  let fixture = try BondedFreightFixture()
  defer { fixture.legacy.clean() }
  let plan = try #require(fixture.plans().first)
  let game = try fixture.legacy.policyGame()
  var commander = game.commander
  let before = commander.credits
  var state = ScriptInstance(
    id: UUID(), definition: plan.content.stateID, version: plan.content.version,
    digest: plan.content.digest)
  state.contract = try fixture.job(plan)
  commander.scriptState.missionCalendar?.seconds = 200
  try game.settleContract(.complete, state: &state, candidate: &commander)
  #expect(commander.credits == before + plan.reward + 750)
  #expect(state.contract?.settlementAmount == plan.successPayment)
  #expect(state.contract?.valid == true)
  #expect(throws: MissionPackError.self) {
    try game.settleContract(.complete, state: &state, candidate: &commander)
  }
  #expect(commander.credits == before + plan.successPayment)
}

@Test func bondedLossAndAbandonmentForfeitDepositWithoutRefund() throws {
  let fixture = try BondedFreightFixture()
  defer { fixture.legacy.clean() }
  let plan = try #require(fixture.plans().first)
  let game = try fixture.legacy.policyGame()
  for outcome in [ScriptOutcome.failed, .abandoned] {
    var commander = game.commander
    let before = commander.credits
    commander.scriptState.missionCalendar?.seconds = 200
    var state = ScriptInstance(
      id: UUID(), definition: plan.content.stateID, version: plan.content.version,
      digest: plan.content.digest)
    state.contract = try fixture.job(plan)
    try game.settleContract(outcome, state: &state, candidate: &commander)
    #expect(commander.credits == before && state.contract?.settlementAmount == 0)
    #expect(state.contract?.valid == true)
  }
}

@Test func bondedJobRejectsHiddenDeadlineAndPreservesQuoteOnReload() throws {
  let fixture = try BondedFreightFixture()
  defer { fixture.legacy.clean() }
  let plan = try #require(fixture.plans().first)
  let job = try fixture.job(plan)
  let data = try JSONEncoder().encode(job)
  let reloaded = try JSONDecoder().decode(ScriptContractJob.self, from: data)
  #expect(reloaded == job && reloaded.valid)
  var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  object["deadline"] = 500
  let hidden = try JSONDecoder().decode(
    ScriptContractJob.self, from: JSONSerialization.data(withJSONObject: object))
  #expect(!hidden.valid)
}

@Test func bondedRealLoaderRejectsMissingInvalidLegacyAndUnknownHazards() throws {
  let edits: [(String) -> String] = [
    { $0.replacingOccurrences(of: "bondedHazardTiers = [0, 1, 2]", with: "") },
    {
      $0.replacingOccurrences(
        of: "bondedHazardTiers = [0, 1, 2]",
        with: "bondedHazardTiers = [0, -1, 2]")
    },
    {
      $0.replacingOccurrences(
        of: "bondedHazardTiers = [0, 1, 2]",
        with: "bondedHazardTiers = [0, 1]")
    },
    {
      $0.replacingOccurrences(
        of: "bondedHazardTiers = [0, 1, 2]",
        with: "bondedHazardTiers = [0, 1, 2]\nbondedUnknown = 1")
    },
    {
      $0.replacingOccurrences(
        of: "l337.contract/bonded-freight",
        with: "PROJECT-SPACE-G03-1")
    },
    {
      $0.replacingOccurrences(
        of: "bondedHazardTiers = [0, 1, 2]",
        with: "bondedHazardTiers = \"null\"")
    },
  ]
  for edit in edits {
    #expect(throws: (any Error).self) { try BondedFreightFixture(manifestEdit: edit) }
  }
}

@Test func bondedActualVersionedSaveBoardAndIssuedJobRoundtripAndCorruption() async throws {
  let fixture = try BondedFreightFixture()
  defer { fixture.legacy.clean() }
  let runtime = try await fixture.nativeRuntime()
  let key = try await runtime.generateContractBoard(packDigest: fixture.pack.digest)
  try await runtime.save(to: fixture.legacy.save)
  let boardSnapshot = await runtime.snapshot()
  let board = try #require(boardSnapshot.commander.contracts.boards[key])
  let (boardReload, boardWorld) = try ScriptSaveStore.read(
    Data(contentsOf: fixture.legacy.save), from: fixture.legacy.save)
  #expect(boardReload.contracts.boards[key] == board)
  #expect(boardWorld.consistent(with: boardReload))
  let quote = await runtime.contractAcceptanceQuote(board: key, offer: board.offers[0].id)
  let allowed = quote.allowed
  try #require(allowed)
  let id = try await runtime.confirmContract(quote)
  let accepted = await runtime.snapshot()
  #expect(accepted.commander.credits == boardSnapshot.commander.credits - 750)
  let repeated = try await runtime.confirmContract(quote)
  #expect(repeated == id)
  let repeatedSnapshot = await runtime.snapshot()
  #expect(repeatedSnapshot.commander == accepted.commander)
  try await runtime.save(to: fixture.legacy.save)
  let (commander, world) = try ScriptSaveStore.read(
    Data(contentsOf: fixture.legacy.save), from: fixture.legacy.save)
  #expect(commander.scriptState.instances[id] == accepted.commander.scriptState.instances[id])
  #expect(world.consistent(with: commander))
  #expect(commander.scriptState.instances[id]?.contract?.deadline == nil)
  #expect(commander.scriptState.instances[id]?.savedOwnedCargo?.held.count == 3)
  let corruptions: [(inout [String: Any]) -> Void] = [
    { $0.removeValue(forKey: "bondedHazardTiers") },
    { $0["bondedHazardTiers"] = NSNull() },
    { $0["bondedHazardTiers"] = [0, 1] },
    { $0.removeValue(forKey: "bondedQuote") },
    { $0["bondedQuote"] = NSNull() },
    { $0["bondedUnknown"] = 1 },
    { $0["bondedQuote"] = ["routeLegs": 1, "hazardTier": 0, "unknown": 1] },
    { $0["bondedQuote"] = ["routeLegs": NSNull(), "hazardTier": 0] },
    { $0["profile"] = ScriptFreightPlan.profileID },
  ]
  for chunk in ["contracts.json", "missions.json"] {
    for corrupt in corruptions {
      try fixture.rejectSavedPlan(chunk: chunk, change: corrupt)
    }
  }
  let (restored, _) = try ScriptSaveStore.read(
    Data(contentsOf: fixture.legacy.save), from: fixture.legacy.save)
  #expect(restored.scriptState.instances[id] == commander.scriptState.instances[id])
}
