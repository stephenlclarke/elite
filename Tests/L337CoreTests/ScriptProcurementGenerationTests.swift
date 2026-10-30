import Foundation
import Testing

@testable import L337Core

@Test func procurementNativeRowsRetainTermsAndSeparateWrappingDraws() throws {
  let fixture = try ScriptProcurementFixture()
  defer { fixture.clean() }
  let game = try fixture.policyGame()
  let plans = try fixture.plans(game)
  let repeated = try fixture.plans(game)
  #expect(plans == repeated && plans.count == 3)
  var state = plans[0].initialState
  var expectedDraws: [UInt32] = []
  for _ in 0..<6 {
    state ^= state << 13
    state ^= state >> 17
    state ^= state << 5
    expectedDraws.append(state)
  }
  for (row, plan) in plans.enumerated() {
    let offer = try fixture.offer(plan)
    let encoded = try ScriptWire.encode([try #require(plan.parameters)], limit: 4096)
    #expect(plan.valid && plan.matches(offer) && plan.row == row)
    #expect(plan.draws == expectedDraws && plan.finalState == state)
    #expect(plan.quantity == [1, 5, 10][row])
    #expect(plan.reward == ([750, 1500, 2500][row] + 300 * (plan.path.count - 1)) * 10)
    #expect(plan.duration == [172800.0, 172800, 259200][row])
    #expect(plan.path.first == 0 && (2...4).contains(plan.path.count) && encoded.count <= 4096)
    #expect(
      plan.collection?.items == [
        .init(commodity: plan.commodity!.rawValue, unit: "t", quantity: plan.quantity)
      ])
  }
}

@Test func procurementWireBoundaryUsesTheRealEncoderAndRejectsUndeclaredFields() throws {
  let fixture = try ScriptProcurementFixture()
  defer { fixture.clean() }
  let game = try fixture.policyGame()
  let plans = try fixture.plans(game)
  let parameters = try #require(plans[2].parameters)
  let original = try ScriptWire.encode([parameters], limit: 4096)
  let exact = try ScriptWire.encode([parameters], limit: original.count)
  #expect(exact == original)
  let fullBudget = try ScriptWire.encode(
    [.string(String(repeating: "x", count: 4091))], limit: 4096)
  #expect(fullBudget.count == 4096)
  #expect(throws: MissionPackError.self) {
    _ = try ScriptWire.encode([.string(String(repeating: "x", count: 4092))], limit: 4096)
  }
  #expect(throws: MissionPackError.self) {
    _ = try ScriptWire.encode([parameters], limit: original.count - 1)
  }
  var fields = try #require(parameters.object)
  fields["foreign"] = .string("reward authority")
  let unknown = ScriptProcurementPlan.read(.object(fields))
  #expect(unknown == nil)
  fields["foreign"] = .string(String(repeating: "x", count: 4096))
  #expect(throws: MissionPackError.self) {
    _ = try ScriptWire.encode([.object(fields)], limit: 4096)
  }
}

@Test func procurementGalleryDeclarationRequiresActualFlightInsteadOfSyntheticDock() throws {
  let fixture = try ScriptProcurementFixture()
  defer { fixture.clean() }
  var object = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(fixture.pack.manifest))
      as? [String: Any])
  var trial = try #require(object["trial"] as? [String: Any])
  trial["flight"] = false
  object["trial"] = trial
  let manifest = try JSONDecoder().decode(
    ScriptManifest.self, from: JSONSerialization.data(withJSONObject: object))
  #expect(throws: MissionPackError.self) { try ScriptPackLibrary.validateProcurement(manifest) }
}

@Test(arguments: ["draw", "route", "index", "reach", "profile", "commodity", "unknown"])
func procurementFrozenProofRejectsSubstitutions(field: String) throws {
  let fixture = try ScriptProcurementFixture()
  defer { fixture.clean() }
  let game = try fixture.policyGame()
  let plans = try fixture.plans(game)
  let original = try fixture.offer(plans[0])
  let changed = try ScriptProcurementFixture.changingParameters(original) { plan in
    switch field {
    case "draw": plan["draws"] = [UInt32](repeating: 1, count: 6)
    case "route": plan["path"] = [0, 0]
    case "index": plan["route_index"] = 255
    case "reach":
      var reach = plan["reach"] as! [String: Any]
      reach["revision"] = "elite-880d3a-native-reach-v1"
      plan["reach"] = reach
    case "profile": plan["profile"] = "PROJECT-SPACE-G02-1"
    case "commodity": plan["commodity_index"] = 3
    default: plan["unit"] = "kg"
    }
  }
  let parsed = ScriptProcurementPlan.read(changed.parameters)
  #expect(parsed?.matches(changed) != true)
  #expect(plans[0].matches(original))
}

@Test(arguments: [0, 1, 2])
func procurementCapacityCountsOwnedRequestedGoodsWithoutIssuingCargo(row: Int) throws {
  let fixture = try ScriptProcurementFixture()
  defer { fixture.clean() }
  let game = try fixture.policyGame()
  let plans = try fixture.plans(game)
  let plan = plans[row]
  var commander = game.commander
  let commodity = try #require(plan.commodity).rawValue
  let unrelated = CommodityIdentity.alloys.rawValue
  let capacity = commander.standardCargoCapacity
  commander.cargo[unrelated] = capacity - plan.quantity
  #expect(plan.capacityFits(commander))
  commander.cargo[unrelated] += 1
  #expect(!plan.capacityFits(commander))
  commander.cargo[unrelated] = capacity - plan.quantity
  commander.cargo[commodity] = plan.quantity
  let before = commander
  #expect(plan.capacityFits(commander))
  #expect(commander == before && commander.cargoTonnes == capacity)
  commander.cargo[unrelated] += 1
  commander.unlimitedCargo = true
  #expect(!plan.capacityFits(commander))
}

/// Pure deadline policy; this does not claim a native flight or handoff receipt.
@Test(arguments: [-0.1, 0.0, 0.1])
func procurementNumericSettlementBoundaryIsInclusive(offset: Double) throws {
  let fixture = try ScriptProcurementFixture()
  defer { fixture.clean() }
  let game = try fixture.policyGame()
  let plans = try fixture.plans(game)
  let plan = try #require(plans.first { $0.calendarLowerBoundSeconds < $0.duration })
  var job = try fixture.job(plan)
  job.settled = true
  job.settlementOutcome = .complete
  job.settlementAmount = plan.reward
  job.settledAt = plan.duration + offset
  #expect(job.valid == (offset <= 0))
}

/// Frozen by independent source-only SHA256/unsigned arithmetic expansion; native tests were not run.
struct ProcurementDrawFixture: Sendable {
  let row: Int
  let commodity: Int
  let revision: Int64
  let seed: String
  let initial: UInt32
  let draws: [UInt32]
  static let cases: [Self] = [
    .init(
      row: 0, commodity: 0, revision: 1, seed: "14a562f229f99040", initial: 704_221_248,
      draws: [1_707_223_736, 842_163_378, 2_854_709_216, 2_645_808_429, 97_964_646, 752_208_075]),
    .init(
      row: 0, commodity: 1, revision: 0, seed: "99ed17da39e41cd8", initial: 971_250_904,
      draws: [
        4_120_345_863, 1_556_452_252, 947_584_039, 2_554_057_944, 3_065_255_048, 2_961_497_562,
      ]),
    .init(
      row: 0, commodity: 2, revision: 2, seed: "544fbf81598c7a49", initial: 1_502_378_569,
      draws: [
        241_374_283, 4_053_927_422, 2_460_889_968, 3_435_346_704, 3_750_540_992, 1_673_977_642,
      ]),
    .init(
      row: 1, commodity: 0, revision: 9, seed: "f6ebab8387466906", initial: 2_269_538_566,
      draws: [112_659_093, 459_208_071, 2_015_402_352, 182_137_367, 4_289_031_995, 436_659_546]),
    .init(
      row: 1, commodity: 1, revision: 0, seed: "99ed17da39e41cd8", initial: 971_250_904,
      draws: [
        4_120_345_863, 1_556_452_252, 947_584_039, 2_554_057_944, 3_065_255_048, 2_961_497_562,
      ]),
    .init(
      row: 1, commodity: 2, revision: 2, seed: "544fbf81598c7a49", initial: 1_502_378_569,
      draws: [
        241_374_283, 4_053_927_422, 2_460_889_968, 3_435_346_704, 3_750_540_992, 1_673_977_642,
      ]),
    .init(
      row: 2, commodity: 0, revision: 1, seed: "14a562f229f99040", initial: 704_221_248,
      draws: [1_707_223_736, 842_163_378, 2_854_709_216, 2_645_808_429, 97_964_646, 752_208_075]),
    .init(
      row: 2, commodity: 1, revision: 2, seed: "544fbf81598c7a49", initial: 1_502_378_569,
      draws: [
        241_374_283, 4_053_927_422, 2_460_889_968, 3_435_346_704, 3_750_540_992, 1_673_977_642,
      ]),
    .init(
      row: 2, commodity: 2, revision: 0, seed: "99ed17da39e41cd8", initial: 971_250_904,
      draws: [
        4_120_345_863, 1_556_452_252, 947_584_039, 2_554_057_944, 3_065_255_048, 2_961_497_562,
      ]),
  ]
}

@Test(arguments: ProcurementDrawFixture.cases)
func procurementAllNineTierCommodityGoldensRetainTheirOriginalSeed(frozen: ProcurementDrawFixture)
  throws
{
  let fixture = try ScriptProcurementFixture(legacyV1: true)
  defer { fixture.clean() }
  let game = try fixture.policyGame()
  let plans = try fixture.plans(game, revision: frozen.revision)
  let plan = plans[frozen.row]
  #expect(fixture.pack.digest == "b5417a83aecf3f2c2b87b78c4c360719165330acdec4d05c0b5a47da831a4e59")
  #expect(plan.seedHex == frozen.seed && plan.initialState == frozen.initial)
  #expect(plan.draws == frozen.draws && plan.finalState == frozen.draws.last)
  #expect(plan.commodityIndex == frozen.commodity && plan.quantity == [1, 5, 10][frozen.row])
}

@Test(arguments: [0, 1, 2])
func procurementV2SelectsFromStableFeasibleCandidatesBeforeItsFrozenDraw(row: Int) throws {
  let fixture = try ScriptProcurementFixture()
  defer { fixture.clean() }
  let game = try fixture.policyGame()
  let plans = try fixture.plans(game)
  let repeated = try fixture.plans(game)
  let plan = plans[row]
  let routes = ScriptCourierGeneration.routes(origin: plan.origin, reach: plan.reach)
  let systems = Universe.systemsIncludingPlugh(number: plan.origin.galaxy)
  // Independent calendar sum over the original ordered native BFS, before selection.
  let eligible = routes.filter { path in
    let cost = zip(path, path.dropFirst()).reduce(0.0) { value, edge in
      let distance = systems[edge.0].scriptCalendarDistance(to: systems[edge.1])
      return value + 600 + distance * distance * 3600
    }
    return cost < plan.duration
  }
  try #require(!eligible.isEmpty)
  // Current native routes include over-deadline paths even without paid extended reach.
  // Independent filtering must remove them without reordering the surviving BFS candidates.
  #expect(eligible.count < routes.count)
  #expect(routes.filter { eligible.contains($0) } == eligible)
  let index = Int(floor(Double(plan.draws[row * 2]) / 4294967296.0 * Double(eligible.count)))
  #expect(plan.generatorRevision == 2 && plan.valid && plans == repeated)
  #expect(plan.routeIndex == index && plan.path == eligible[index])
  #expect(plan.calendarLowerBoundSeconds < plan.duration)
  #expect(
    fixture.pack.manifest.version == "1.1.0"
      && fixture.pack.digest == "7c005213865792314f9966db54c7acfddadd614260219a2b39d66e41906103b7")
  // Exact current content includes the Avenor trial declaration; this policy origin stays zero.
  #expect(plan.seedHex == "c46e085a42493b29" && plan.initialState == 1_112_095_529)
  #expect(
    plan.draws == [
      3_232_308_831, 2_402_513_454, 3_484_323_893, 2_830_099_137, 3_389_718_522, 726_357_248,
    ] && plan.finalState == 726_357_248)
}

@Test(arguments: [0, 1, 2])
func procurementV2FiltersOverDeadlineRoutesFromPaidExtendedReachBeforeDrawing(row: Int) throws {
  let fixture = try ScriptProcurementFixture()
  defer { fixture.clean() }
  // Controlled fresh shop initialization, not a travelled route or awarded fit.
  var game = try ScriptProcurementFixture.freshG03FlightGame()
  // This controlled unit fixture exercises the stock Cobra, independently of the fresh starter.
  game.commander.shipID = "SH023"
  game.commander.fuel = game.commander.fuelCapacity
  game.energy = game.commander.performance.energy
  game.frontShield = game.commander.shieldCapacity
  game.rearShield = game.commander.rearShieldCapacity
  game.commander.credits = 1_000_000
  try game.commander.prepareEquipment(legacy: false)
  game.scriptPacks = [fixture.pack]
  game.scriptDurabilityAvailable = true
  game.ensureMissionCalendar()
  let owner = game.commander.equipmentOwnerID
  let hull = game.commander.hullInstanceID
  let fuel = game.commander.fuel
  let cash = game.commander.credits
  let purchases = [
    NavigationTier.advanced.equipmentName, NavigationTier.military.equipmentName,
    FuelStorage.equipmentName, FuelStorage.equipmentName,
  ]
  for name in purchases {
    game.selection = try #require(Equipment.all.firstIndex { $0.name == name })
    let item = Equipment.all[game.selection]
    let before = game.commander.credits
    let receipts = game.commander.equipmentPurchaseHistory?.paid.count ?? 0
    try #require(game.equipmentAvailable(item))
    game.purchase()
    try #require(game.commander.credits == before - item.price)
    try #require(game.commander.equipmentPurchaseHistory?.paid.count == receipts + 1)
    try #require(game.commander.equipmentPurchaseHistory?.paid.last?.node.key == name)
  }
  try #require(game.commander.credits == cash - 160000)
  try #require(game.commander.equipmentPurchaseHistory?.paid.count == purchases.count)
  try #require(game.commander.navigationTier == .military && game.commander.fuelStorageUnits == 2)
  try #require(game.commander.fuel == fuel && game.commander.fuelCapacity == 210)
  try #require(game.commander.maximumJumpDistance == 7 && game.commander.fullTankJumpDistance == 21)
  try #require(game.commander.equipmentOwnerID == owner && game.commander.hullInstanceID == hull)
  try #require(game.commander.valid && game.commander.cargo.allSatisfy { $0 == 0 })
  let plans = try fixture.plans(game)
  let repeated = try fixture.plans(game)
  let plan = plans[row]
  let routes = ScriptCourierGeneration.routes(origin: plan.origin, reach: plan.reach)
  let systems = Universe.systemsIncludingPlugh(number: plan.origin.galaxy)
  // Independent sum over actual native BFS paths, before any route draw is applied.
  let eligible = routes.filter { path in
    let cost = zip(path, path.dropFirst()).reduce(0.0) { value, edge in
      let distance = systems[edge.0].scriptCalendarDistance(to: systems[edge.1])
      return value + 600 + distance * distance * 3600
    }
    return cost < plan.duration
  }
  try #require(!eligible.isEmpty && eligible.count < routes.count)
  let index = Int(floor(Double(plan.draws[row * 2]) / 4294967296.0 * Double(eligible.count)))
  #expect(plan.generatorRevision == 2 && plan.valid && plans == repeated)
  #expect(plan.routeIndex == index && plan.path == eligible[index])
  #expect(plan.calendarLowerBoundSeconds < plan.duration)
}

/// Numeric feasibility is strict; actual handoff at the deadline remains inclusive.
@Test(arguments: [-0.1, 0.0, 0.1])
func procurementV2TravelFeasibilityExcludesTheDeadlineBoundary(offset: Double) {
  for row in 0..<3 {
    let allowed = ScriptProcurementPlan.feasible(
      calendarCost: ScriptProcurementPlan.duration(row: row) + offset, row: row)
    #expect(allowed == (offset < 0))
  }
}

@Test func procurementV2EmptyFeasiblePoolNeverFallsBackToTheLegacyRoute() throws {
  let fixture = try ScriptProcurementFixture(legacyV1: true)
  defer { fixture.clean() }
  let game = try fixture.policyGame()
  let plans = try fixture.plans(game)
  let old = plans[0]
  try #require(old.valid && old.calendarLowerBoundSeconds >= old.duration)
  let legacy = ScriptProcurementPlan.candidatePaths(
    [old.path], galaxy: old.origin.galaxy, row: 0, generatorRevision: 1)
  let current = ScriptProcurementPlan.candidatePaths(
    [old.path], galaxy: old.origin.galaxy, row: 0, generatorRevision: 2)
  let unsupported = ScriptProcurementPlan.candidatePaths(
    [old.path], galaxy: old.origin.galaxy, row: 0, generatorRevision: 3)
  #expect(legacy == [old.path] && current.isEmpty && unsupported.isEmpty)
}
