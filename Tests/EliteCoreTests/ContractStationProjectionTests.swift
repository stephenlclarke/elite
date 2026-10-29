import Foundation
import Testing

@testable import EliteCore

struct ContractStationProjectionTests {
  @Test(arguments: ["starting", "upper", "negative", "extreme"])
  func ownedStationIdentityPreservesExactCoordinatesAndRetainedState(scenario: String) throws {
    let coordinates: (Int, Int)
    switch scenario {
    case "starting": coordinates = (0, 7)
    case "upper": coordinates = (7, 256)
    case "negative": coordinates = (-1, -2)
    case "extreme": coordinates = (Int.max, Int.min)
    default:
      Issue.record(Comment(rawValue: "Unrecognised station projection fixture: " + scenario))
      return
    }
    var game = Game(executive: false)
    game.commander.galaxy = coordinates.0
    game.commander.system = coordinates.1
    let retained = game
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let bytes = try encoder.encode(game.commander)
    let identity = game.contractStation
    let expected = ContractStationIdentity(
      galaxy: coordinates.0, system: coordinates.1, stationClass: "main-orbital")
    #expect(identity == expected && identity.key == expected.key)
    #expect(game.commander == retained.commander)
    #expect(try encoder.encode(game.commander) == bytes)
    #expect(
      try JSONDecoder().decode(ContractStationIdentity.self, from: encoder.encode(identity))
        == identity)
    game.commander.galaxy = 2
    game.commander.system = 3
    #expect(game.contractStation == .init(galaxy: 2, system: 3, stationClass: "main-orbital"))
    #expect(identity == expected && retained.contractStation == expected)
    #expect(try encoder.encode(retained.commander) == bytes)
  }
}
