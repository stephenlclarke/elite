import Foundation
import Testing

@testable import EliteCore

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
  let fixture = try ScriptProcurementFixture()
  defer { fixture.clean() }
  let game = try fixture.policyGame()
  let plans = try fixture.plans(game, revision: frozen.revision)
  let plan = plans[frozen.row]
  #expect(fixture.pack.digest == "b5417a83aecf3f2c2b87b78c4c360719165330acdec4d05c0b5a47da831a4e59")
  #expect(plan.seedHex == frozen.seed && plan.initialState == frozen.initial)
  #expect(plan.draws == frozen.draws && plan.finalState == frozen.draws.last)
  #expect(plan.commodityIndex == frozen.commodity && plan.quantity == [1, 5, 10][frozen.row])
}
