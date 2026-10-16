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

/// Immutable native fixture provenance discovered on 51615ee, origins 0...63, epoch zero.
struct CourierNativeFixture: Sendable {
  let origin: Int
  let row: Int
  let seed: UInt64
  let initialState: UInt32
  let path: [Int]
  let lowerBound: Double
  let offer: String
  static let digest = "65ff79fef1171fa0c0af8808754c075e93c0302a33fb3e0b04fa59f59585b369"
  func verify(_ board: ScriptContractBoard, _ actual: ScriptContractOffer) throws {
    #expect(board.digest == Self.digest && board.revision == 0 && board.station.system == origin)
    #expect(board.seed == seed && board.courierGeneration?.initialState == initialState)
    #expect(actual.id.uuidString == offer && actual.courier?.row == row)
    #expect(actual.courier?.path == path && actual.courier?.calendarLowerBoundSeconds == lowerBound)
  }
  static let rows: [Self] = [
    .init(
      origin: 3, row: 0, seed: 13_798_607_238_306_431_818, initialState: 3_529_737_034,
      path: [3, 228], lowerBound: 47256, offer: "8B296B28-BDE6-98B4-C9DA-E9C3B640F74C"),
    .init(
      origin: 0, row: 1, seed: 5_318_087_094_851_105_804, initialState: 1_295_021_068,
      path: [0, 71], lowerBound: 9816.000000000002, offer: "70307AE4-B576-E769-C614-CD429B7D7D2F"),
    .init(
      origin: 0, row: 2, seed: 5_318_087_094_851_105_804, initialState: 1_295_021_068,
      path: [0, 71], lowerBound: 9816.000000000002, offer: "3A038D95-1A17-D856-E13A-2BAEBD2A4DC7"),
    .init(
      origin: 10, row: 3, seed: 9_731_030_265_297_135_835, initialState: 362_571_995,
      path: [10, 177], lowerBound: 130200, offer: "65FD4594-5F50-2D23-F44B-3A2EFEBA63E6"),
    .init(
      origin: 0, row: 4, seed: 5_318_087_094_851_105_804, initialState: 1_295_021_068,
      path: [0, 75, 95, 24], lowerBound: 258696.00000000006,
      offer: "F0BFD021-444E-D681-20F3-98143485BA6C"),
    .init(
      origin: 1, row: 5, seed: 6_630_146_343_182_819_093, initialState: 2_588_172_053,
      path: [1, 40, 181], lowerBound: 181488.00000000006,
      offer: "3D6AA0E8-DE5D-5B5C-D86F-C9DACF601E1D"),
  ]
  static let boundary48Above: Self = .init(
    origin: 37, row: 3, seed: 5_834_218_365_605_885_184, initialState: 1_207_940_352,
    path: [37, 43, 226], lowerBound: 176880.00000000003,
    offer: "CD068A12-7667-3772-DD1A-591EE1D1E5E6")
  static let boundary48Below: Self = .init(
    origin: 56, row: 1, seed: 18_070_191_319_121_658_612, initialState: 3_348_628_212,
    path: [56, 36, 150], lowerBound: 171696.00000000003,
    offer: "AEB492B1-E40D-0630-F52E-A7A2DE55D5FA")
  static let boundary72Above: Self = .init(
    origin: 13, row: 4, seed: 2_402_018_277_323_895_990, initialState: 2_481_124_534,
    path: [13, 222, 29], lowerBound: 260400, offer: "FF5F1C70-F4D7-1931-66AD-10C59CE82CED")
  static let boundary72Below: Self = .init(
    origin: 0, row: 4, seed: 5_318_087_094_851_105_804, initialState: 1_295_021_068,
    path: [0, 75, 95, 24], lowerBound: 258696.00000000006,
    offer: "F0BFD021-444E-D681-20F3-98143485BA6C")
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

@Test func courierLayoutDiagnostic() throws {
  func layout<T>(_ type: T.Type) -> [String: Int] {
    [
      "size": MemoryLayout<T>.size, "stride": MemoryLayout<T>.stride,
      "alignment": MemoryLayout<T>.alignment,
    ]
  }
  let values = [
    "Game": layout(Game.self), "Admission": layout(ScriptCourierAdmission.self),
    "OptionalAdmission": layout(Optional<ScriptCourierAdmission>.self),
    "ContractJob": layout(ScriptContractJob.self),
    "CourierPreview": layout(ScriptCourierPreview.self),
    "AcceptanceQuote": layout(ContractAcceptanceQuote.self),
  ]
  let bytes = try JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])
  print("G02_LAYOUT " + String(decoding: bytes, as: UTF8.self))
}
