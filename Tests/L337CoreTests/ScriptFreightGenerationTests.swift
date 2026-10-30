import Foundation
import Testing

@testable import L337Core

/// Existing independent unsigned goldens are inputs to the new supplied generator,
/// not claims that a procurement board can authorize freight.
@Test(arguments: ProcurementDrawFixture.cases)
func freightFrozenDrawsCoverAllTiersAndCommodities(_ frozen: ProcurementDrawFixture) throws {
  let fixture = try ScriptFreightFixture()
  defer { fixture.clean() }
  let game = try fixture.policyGame()
  let seed = try #require(UInt64(frozen.seed, radix: 16))
  let plans = try ScriptFreightGeneration.plans(
    pack: fixture.pack, commander: game.commander,
    origin: game.contractStation, revision: frozen.revision, seed: seed)
  try #require(plans.count == 3)
  let plan = plans[frozen.row]
  let nativePool = ScriptCourierGeneration.routes(origin: plan.origin, reach: plan.reach)
  let referencePool = ScriptProcurementPlan.candidatePaths(
    nativePool, galaxy: plan.origin.galaxy,
    row: frozen.row, generatorRevision: 2)
  try #require(!referencePool.isEmpty)
  let routeIndex = Int((UInt64(frozen.draws[frozen.row * 2]) * UInt64(referencePool.count)) >> 32)
  #expect(plan.routeIndex == routeIndex && plan.path == referencePool[routeIndex])
  #expect(plan.valid && plan.variant == "supplied" && plan.generatorRevision == 1)
  #expect(plan.initialState == frozen.initial && plan.draws == frozen.draws)
  #expect(plan.commodityIndex == frozen.commodity && plan.finalState == frozen.draws.last)
  #expect(plan.quantity == [1, 5, 10][frozen.row])
  #expect(plan.reward == ([750, 1500, 2500][frozen.row] + 300 * (plan.path.count - 1)) * 10)
  #expect(plan.duration == [172800.0, 172800, 259200][frozen.row])
  #expect(plan.calendarLowerBoundSeconds < plan.duration && (2...4).contains(plan.path.count))
  let parameters = try #require(plan.parameters)
  let bytes = try ScriptWire.encode([parameters], limit: 4096)
  #expect(bytes.count <= 4096 && ScriptFreightPlan.read(parameters) == plan)
  #expect(ScriptFreightPlan.commodities == [.food, .textiles, .machinery])
}

@Test(arguments: [0, 1, 2])
func freightRequiresFullRealHoldWithoutCreditForOrdinaryMatchingGoods(row: Int) throws {
  let fixture = try ScriptFreightFixture()
  defer { fixture.clean() }
  let game = try fixture.policyGame()
  let plans = try fixture.plans(game)
  let plan = plans[row]
  var commander = game.commander
  let commodity = try #require(plan.commodity)
  let capacity = commander.standardCargoCapacity
  commander.cargo[commodity.rawValue] = capacity - plan.quantity
  #expect(plan.capacityFits(commander))
  commander.cargo[commodity.rawValue] += 1
  commander.unlimitedCargo = true
  #expect(!plan.capacityFits(commander))
}

@Test func freightCannotUseSyntheticGalleryDockOrAuthoredAmounts() throws {
  let fixture = try ScriptFreightFixture()
  defer { fixture.clean() }
  let encoded = try JSONEncoder().encode(fixture.pack.manifest)
  let decodedObject = try JSONSerialization.jsonObject(with: encoded)
  var object = try #require(decodedObject as? [String: Any])
  var trial = try #require(object["trial"] as? [String: Any])
  trial["flight"] = false
  object["trial"] = trial
  let bytes = try JSONSerialization.data(withJSONObject: object)
  let manifest = try JSONDecoder().decode(ScriptManifest.self, from: bytes)
  #expect(throws: MissionPackError.self) { try ScriptPackLibrary.validateFreight(manifest) }
  let game = try fixture.policyGame()
  let plans = try fixture.plans(game)
  var parameters = try #require(plans[0].parameters?.object)
  parameters["quantity"] = .integer(100)
  #expect(ScriptFreightPlan.read(.object(parameters)) == nil)
}
