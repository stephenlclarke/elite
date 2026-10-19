import Foundation
import Testing

@testable import EliteCore

@Test func courierXorshiftUsesWrappingOrderAndZeroNormalization() {
  var state: UInt32 = 1
  #expect(ScriptCourierGeneration.next(&state) == 270369)
  #expect(ScriptCourierGeneration.next(&state) == 67_634_689)
  #expect(ScriptCourierGeneration.next(&state) == 2_647_435_461)
  var zero: UInt32 = 0
  var normalized: UInt32 = 0x6D2B_79F5
  #expect(ScriptCourierGeneration.next(&zero) == ScriptCourierGeneration.next(&normalized))
  #expect(zero != 0)
}

@Test func courierGenerationProofRejectsDrawRouteAndNativeReachSubstitution() throws {
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let (key, _) = try fixture.offer(&game)
  let original = try #require(game.commander.contracts.boards[key]?.courierGeneration)
  #expect(original.valid)
  var object = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
  object["draws"] = [UInt32](repeating: 1, count: 6)
  let substituted = try JSONDecoder().decode(
    ScriptCourierGeneration.self, from: JSONSerialization.data(withJSONObject: object))
  #expect(!substituted.valid)
  game.commander.fuel = 0
  #expect(throws: MissionPackError.self) {
    try ScriptCourierGeneration(origin: game.contractStation, commander: game.commander, seed: 0)
  }
  #expect(game.commander.contracts.boards[key]?.courierGeneration == original)
}

@Test func courierNoRouteLeavesBoardAndRandomStateUnchanged() throws {
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  game.commander.fuel = 0
  game.ensureMissionCalendar()
  let before = game.commander
  let random = game.scriptSimulationSave.randomState
  #expect(throws: MissionPackError.self) { try game.ensureContractBoard(fixture.pack) }
  #expect(game.commander == before && game.scriptSimulationSave.randomState == random)
}

@Test func courierAllDisabledLongRangeRowsKeepAllSixDrawsAndNeverReroll() throws {
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  game.commander.fuelStorageUnits = 2
  game.commander.fuel = game.commander.fuelCapacity
  game.commander.installNavigationComputer(.military)
  let (key, _) = try fixture.offer(&game)
  let frozen = try #require(game.commander.contracts.boards[key])
  #expect(frozen.offers.count == 6 && frozen.courierGeneration?.draws.count == 6)
  #expect(frozen.offers.allSatisfy { $0.courier!.calendarLowerBoundSeconds >= $0.duration })
  for offer in frozen.offers {
    #expect(!game.contractAcceptanceQuote(board: key, offer: offer.id).allowed)
  }
  let reopened = try game.ensureContractBoard(fixture.pack)
  #expect(reopened == key && game.commander.contracts.boards[key] == frozen)
  game.commander.fuel = 0
  let again = try game.ensureContractBoard(fixture.pack)
  #expect(again == key && game.commander.contracts.boards[key] == frozen)
}

@Test func courierActiveAndSuspendedProviderJobBlocksOtherStationsAndQuotedProgressIsRechecked()
  throws
{
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let (key, offer) = try fixture.usable(&game)
  let quote = game.contractAcceptanceQuote(board: key, offer: offer.id)
  game.commander.scriptState.calendarSeconds += 0.1
  game.commander.scriptState.missionCalendar?.seconds += 0.1
  let id = try game.confirmContract(quote)
  #expect(game.commander.scriptState.instances[id]?.contract?.acceptedAt == 0.1)
  let sameBoard = try #require(game.commander.contracts.boards[key])
  let other = try #require(sameBoard.offers.first { $0.id != offer.id })
  #expect(!game.contractAcceptanceQuote(board: key, offer: other.id).allowed)
  // Native travel to the frozen destination establishes another real station, not a rewritten origin.
  try fixture.travel(&game, id: id)
  game.selection = try #require(Equipment.all.firstIndex { $0.name == "Fuel" })
  game.purchase()
  let secondKey = try game.ensureContractBoard(fixture.pack)
  let second = try #require(game.commander.contracts.boards[secondKey]?.offers.first)
  #expect(!game.contractAcceptanceQuote(board: secondKey, offer: second.id).allowed)
  game.commander.scriptState.instances[id]?.suspension = "Content temporarily unavailable"
  #expect(!game.contractAcceptanceQuote(board: secondKey, offer: second.id).allowed)
  #expect(game.commander.scriptState.instances[id]?.courier?.terminal == nil)
}

/// Current original-world witnesses independently expanded from authenticated catalogue bytes.
/// Epoch zero, board-seed derivation and all six draws are frozen; no runtime discovery or reroll.
struct CourierNativeFixture: Sendable {
  let origin: Int
  let row: Int
  let seed: UInt64
  let initialState: UInt32
  let draws: [UInt32]
  let path: [Int]
  let lowerBound: Double
  let offer: String
  static let digest = "65ff79fef1171fa0c0af8808754c075e93c0302a33fb3e0b04fa59f59585b369"
  func verify(_ board: ScriptContractBoard, _ actual: ScriptContractOffer) throws {
    #expect(Universe.originalWorlds.version == "l337-world-1")
    #expect(board.digest == Self.digest && board.revision == 0 && board.station.system == origin)
    #expect(board.seed == seed && board.courierGeneration?.initialState == initialState)
    #expect(board.courierGeneration?.draws == draws)
    #expect(actual.id.uuidString == offer && actual.courier?.row == row)
    let terms = try #require(actual.courier)
    #expect(board.valid && terms.valid && terms.path == path)
    // Independent Python and native libm may round the final Double differently.
    // Native proof validation still requires its own exact cost and unchanged deadline comparisons.
    #expect(abs(terms.calendarLowerBoundSeconds - lowerBound) < 0.000001)
  }
  static let rows: [Self] = [
    .init(
      origin: 4, row: 0, seed: 7_416_280_517_231_489_484, initialState: 1_480_307_148,
      draws: [3_997_630_317, 79_933_624, 675_656_594, 1_488_989_609, 4_090_577_267, 2_752_961_804],
      path: [4, 84, 241], lowerBound: 171049.27346400009,
      offer: "C75EA5D5-5C1F-2C60-20B3-87A44E547A0A"),
    .init(
      origin: 0, row: 1, seed: 5_318_087_094_851_105_804, initialState: 1_295_021_068,
      draws: [
        898_330_452, 1_415_163_876, 1_426_520_566, 3_442_991_530, 290_823_243, 4_182_313_349,
      ],
      path: [0, 91], lowerBound: 35798.30051999994,
      offer: "70307AE4-B576-E769-C614-CD429B7D7D2F"),
    .init(
      origin: 0, row: 2, seed: 5_318_087_094_851_105_804, initialState: 1_295_021_068,
      draws: [
        898_330_452, 1_415_163_876, 1_426_520_566, 3_442_991_530, 290_823_243, 4_182_313_349,
      ],
      path: [0, 91], lowerBound: 35798.30051999994,
      offer: "3A038D95-1A17-D856-E13A-2BAEBD2A4DC7"),
    .init(
      origin: 3, row: 3, seed: 13_798_607_238_306_431_818, initialState: 3_529_737_034,
      draws: [
        3_814_251_439, 4_253_397_145, 960_503_570, 1_860_831_779, 3_663_840_116, 2_749_987_859,
      ],
      path: [3, 122], lowerBound: 38304.34242000006,
      offer: "F626B1F8-E32F-A55C-30DD-55068196C52B"),
    .init(
      origin: 0, row: 4, seed: 5_318_087_094_851_105_804, initialState: 1_295_021_068,
      draws: [
        898_330_452, 1_415_163_876, 1_426_520_566, 3_442_991_530, 290_823_243, 4_182_313_349,
      ],
      path: [0, 20], lowerBound: 79423.07427599988,
      offer: "F0BFD021-444E-D681-20F3-98143485BA6C"),
    .init(
      origin: 7, row: 5, seed: 16_713_386_715_846_582_478, initialState: 2_948_899_022,
      draws: [
        1_081_268_512, 1_905_018_347, 3_743_053_587, 2_935_202_319, 2_365_048_214, 4_242_721_076,
      ],
      path: [7, 185, 0, 198], lowerBound: 242732.15521199995,
      offer: "03F43AD7-B027-A298-4660-E9DBB048673C"),
  ]
  // Dedicated one-hop input for the native-painted helper; runtime rows retain their routes.
  static let paintedRow0OneHop: Self = .init(
    origin: 13, row: 0, seed: 2_402_018_277_323_895_990, initialState: 2_481_124_534,
    draws: [
      1_677_595_532, 2_423_761_451, 3_278_761_714, 2_831_262_923, 390_714_887, 2_628_597_923,
    ],
    path: [13, 105], lowerBound: 17392.822800000024,
    offer: "BC3CB061-BDC3-256E-3F74-789A175FE350")
  static let boundary48Above: Self = .init(
    origin: 98, row: 1, seed: 237_134_580_724_460_434, initialState: 269_151_122,
    draws: [3_798_542_574, 702_931_412, 775_572_571, 2_442_325_987, 1_102_304_084, 1_089_509_816],
    path: [98, 57, 39], lowerBound: 173758.9431360001,
    offer: "5FF8F384-9D08-D0EB-ECCE-B2D196B38DCE")
  static let boundary48Below: Self = .init(
    origin: 44, row: 3, seed: 9_069_973_204_358_578_451, initialState: 404_406_547,
    draws: [1_193_844_975, 899_172_309, 2_436_748_772, 1_537_819_812, 344_087_162, 2_792_064_540],
    path: [44, 189, 77], lowerBound: 171549.466824,
    offer: "086D072A-E898-54E6-54E8-CF83810E1069")
  static let boundary72Above: Self = .init(
    origin: 226, row: 5, seed: 2_856_789_962_849_034_778, initialState: 3_582_239_258,
    draws: [
      2_034_212_313, 3_659_262_971, 1_275_056_489, 2_340_919_680, 1_849_892_539, 3_206_248_017,
    ],
    path: [226, 95, 214], lowerBound: 259780.52636399996,
    offer: "C63A7880-4653-5B02-1512-391F624E58A8")
  static let boundary72Below: Self = .init(
    origin: 92, row: 5, seed: 13_811_688_890_081_468_573, initialState: 964_944_029,
    draws: [4_154_206_453, 584_353_588, 4_101_610_381, 637_753_641, 3_924_666_618, 3_265_926_883],
    path: [92, 56, 35, 172], lowerBound: 258384.766932,
    offer: "310DD44B-00E5-15F3-0557-E10401388FE9")
  // Preserve old origin/seed/draw inputs as refused current-world offers, without rerolls.
  static let priorUnavailableRows: [Self] = [
    .init(
      origin: 3, row: 0, seed: 13_798_607_238_306_431_818, initialState: 3_529_737_034,
      draws: [
        3_814_251_439, 4_253_397_145, 960_503_570, 1_860_831_779, 3_663_840_116, 2_749_987_859,
      ],
      path: [3, 4, 84, 224], lowerBound: 318247.5776399999,
      offer: "8B296B28-BDE6-98B4-C9DA-E9C3B640F74C"),
    .init(
      origin: 10, row: 3, seed: 9_731_030_265_297_135_835, initialState: 362_571_995,
      draws: [
        2_289_031_064, 553_726_998, 4_160_556_343, 2_636_318_042, 1_284_458_590, 354_388_252,
      ],
      path: [10, 170, 87, 163], lowerBound: 386136.44604,
      offer: "65FD4594-5F50-2D23-F44B-3A2EFEBA63E6"),
    .init(
      origin: 1, row: 5, seed: 6_630_146_343_182_819_093, initialState: 2_588_172_053,
      draws: [
        628_625_158, 3_078_845_450, 4_182_329_835, 3_741_088_753, 1_640_764_720, 2_384_917_541,
      ],
      path: [1, 147, 54, 150], lowerBound: 400434.73549199983,
      offer: "3D6AA0E8-DE5D-5B5C-D86F-C9DACF601E1D"),
  ]
}

@Test func courierSortedBreadthFirstRoutesChooseLowestStableTieWithoutWeightedDistance() throws {
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  let game = fixture.game()
  let reach = ScriptCourierReach(game.commander)
  let routes = ScriptCourierGeneration.routes(origin: game.contractStation, reach: reach)
  let systems = game.systems
  let origin = game.commander.system
  let first = (0..<256).filter {
    $0 != origin && systems[origin].distance(to: systems[$0]) <= reach.firstReach
  }
  let full = min(reach.jumpCap, Double(reach.capacity) / 10)
  var checked = 0
  for destination in 0..<256 where destination != origin && !first.contains(destination) {
    let alternatives = first.filter { systems[$0].distance(to: systems[destination]) <= full }
    guard alternatives.count > 1 else { continue }
    let actual = try #require(routes.first { $0.last == destination })
    #expect(actual == [origin, alternatives.min()!, destination])
    checked += 1
  }
  #expect(checked > 0)
}
