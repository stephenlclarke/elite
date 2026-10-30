import Foundation
import Testing

@testable import L337Core

struct NativeMainStationReceiptProjectionTests {
  @Test(arguments: [
    "valid", "stale", "wrong-epoch", "missing-world", "missing-receipt", "missing-evidence",
    "not-main", "undocked",
  ])
  func ownedReceiptPreservesDockEvidenceGuardsAndRetainedState(scenario: String) async throws {
    let runtime = GameRuntime(game: Game(executive: false))
    try await runtime.startNewCommander()
    var game = await runtime.snapshot()
    #expect(game.nativeMainStationDockEvidenceIsCurrent)
    let original = try #require(game.commander.nativeStations?.currentMainDock)
    switch scenario {
    case "valid": break
    case "stale":
      game.commander.nativeStations?.currentMainDock = .init(
        station: original.station, actor: original.actor, commanderOwner: original.commanderOwner,
        sequence: original.sequence + 1, calendarSeconds: original.calendarSeconds)
    case "wrong-epoch": game.nativeStationRuntimeEpoch = UUID()
    case "missing-world": game.commander.nativeStations = nil
    case "missing-receipt": game.commander.nativeStations?.currentMainDock = nil
    case "missing-evidence": game.nativeMainStationDockEvidence = nil
    case "not-main": game.dockedAtMainStation = false
    case "undocked": game.docked = false
    default:
      Issue.record(Comment(rawValue: "Unrecognised dock receipt fixture: " + scenario))
      return
    }
    let retained = game
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let bytes = try encoder.encode(game.commander)
    let receipt = game.retainedNativeMainStationDockReceipt
    #expect(receipt == game.commander.nativeStations?.currentMainDock)
    #expect(game.nativeMainStationDockEvidenceIsCurrent == (scenario == "valid"))
    #expect(game.commander == retained.commander)
    #expect(try encoder.encode(game.commander) == bytes)
    #expect(
      try JSONDecoder().decode(
        NativeMainStationDockReceipt?.self, from: encoder.encode(receipt)) == receipt)
    game.commander.nativeStations = nil
    #expect(game.retainedNativeMainStationDockReceipt == nil)
    #expect(retained.retainedNativeMainStationDockReceipt == receipt)
    #expect(try encoder.encode(retained.commander) == bytes)
  }
}
