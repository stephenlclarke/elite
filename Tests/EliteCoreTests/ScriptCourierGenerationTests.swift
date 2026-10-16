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

@Test func courierFixtureProvenanceProbe() throws {
  // Temporary bounded offline fixture discovery. Each origin starts a separate native Game;
  // no published board is refreshed, accepted, rewritten or rerolled by this diagnostic.
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  var rows: [String: [String: Any]] = [:]
  var boundaries: [String: [String: Any]] = [:]
  for origin in 0..<64 {
    let epoch = 0
    var game = fixture.game(system: origin)
    if ScriptCourierGeneration.routes(origin: game.contractStation, reach: .init(game.commander))
      .isEmpty
    {
      continue
    }
    let (key, _) = try fixture.offer(&game)
    let board = try #require(game.commander.contracts.boards[key])
    for offer in board.offers {
      let terms = try #require(offer.courier)
      let record: [String: Any] = [
        "origin": origin, "epoch": epoch, "row": terms.row, "path": terms.path,
        "lowerBound": terms.calendarLowerBoundSeconds, "duration": terms.duration,
        "seed": board.seed, "initialState": terms.generation.initialState,
        "offer": offer.id.uuidString, "digest": fixture.pack.digest,
      ]
      if terms.calendarLowerBoundSeconds < terms.duration, rows[String(terms.row)] == nil {
        rows[String(terms.row)] = record
      }
      guard terms.path.count >= 3 else { continue }
      for duration in [172800.0, 259200.0] {
        let side = terms.calendarLowerBoundSeconds < duration ? "below" : "above"
        let label = String(Int(duration / 3600)) + "-" + side
        let distance = abs(terms.calendarLowerBoundSeconds - duration)
        let previous =
          (boundaries[label]?["lowerBound"] as? Double).map { abs($0 - duration) } ?? .infinity
        if distance < previous { boundaries[label] = record }
      }
    }
  }
  let output: [String: Any] = ["rows": rows, "boundaries": boundaries]
  let path = URL(fileURLWithPath: "/tmp/elite-g02-checkpoint/fixture-provenance.json")
  try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]).write(
    to: path)
  #expect(rows.count == 6 && boundaries.count == 4)
  print("Native fixture provenance saved at " + path.path)
}
