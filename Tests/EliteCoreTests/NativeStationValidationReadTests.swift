import Foundation
import Testing

@testable import EliteCore

/// Read-only policy components; these values confer no live station-entry authority.
struct NativeStationValidationReadTests {
  @Test(arguments: ["absent-world", "invalid-world", "wrong-owner", "missing-calendar", "valid"])
  func fullPolicyPreservesEarlyRefusalAndLazyReaderOrder(scenario: String) throws {
    let owner = UUID()
    let system = SystemIdentity(galaxy: 0, system: 7)
    let main = NativeMainStationIdentity(
      world: owner, system: system,
      resource: Game.worldResourceIdentity("main-station-v1:main-orbital:0:7"))
    var world = try NativeStationWorld(owner: owner)
    world.mainStations = [main]
    try #require(world.valid)
    if scenario == "invalid-world" { world.poses.removeLast() }
    let queryWorld: NativeStationWorld? = scenario == "absent-world" ? nil : world
    let currentOwner: UUID? = scenario == "wrong-owner" ? UUID() : owner
    let calendar: ScriptCalendarLedger? =
      scenario == "missing-calendar" ? nil : .init(origin: .newCommander)
    let resources = [
      main.key: ScriptStationResource(identity: main.resource, galaxy: 0, system: 7)
    ]
    var reads: [String] = []
    let allowed = NativeStationStateValidation.check(
      readWorld: {
        reads.append("world")
        return queryWorld
      },
      readResources: {
        reads.append("resources")
        return resources
      },
      readSystem: {
        reads.append("system")
        return system
      },
      readOwner: {
        reads.append("owner")
        return currentOwner
      },
      readPhysicalTime: {
        reads.append("time")
        return 0
      },
      readStationPosition: {
        reads.append("position")
        return .init(0, 0, 0)
      },
      readCalendar: {
        reads.append("calendar")
        return calendar
      })
    let expected: [String]
    switch scenario {
    case "absent-world": expected = ["world"]
    case "invalid-world": expected = ["world", "resources", "system"]
    case "wrong-owner": expected = ["world", "resources", "system", "owner"]
    default: expected = ["world", "resources", "system", "owner", "time", "calendar"]
    }
    #expect(reads == expected)
    #expect(allowed == ["absent-world", "valid"].contains(scenario))
  }

  @Test(arguments: [
    "valid", "absent-world", "default-flight", "missing-owner", "missing-script-state",
  ])
  func storageHeaderMatchesFullCommanderPolicyAndPreservesRetainedBytes(scenario: String) throws {
    var game =
      scenario == "default-flight"
      ? Game(executive: false) : try NativeStationTestFixture.launched()
    switch scenario {
    case "absent-world": game.commander.nativeStations = nil
    case "missing-owner": game.commander.savedEquipmentInventory = nil
    case "missing-script-state": game.commander.scriptState = .init()
    default: break
    }
    let before = game
    let commander = before.commander
    let system = SystemIdentity(galaxy: commander.galaxy, system: commander.system)
    let anchors = commander.flightSimulation.anchors
    let expected = commander.nativeStationStateValid && anchors?.system == system
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let bytes = try encoder.encode(commander)
    if expected {
      let header = try game.nativeStationPopulationHeader()
      #expect(header.system == system && header.anchors == anchors)
    } else {
      #expect(throws: NativeStationRuntimeError.invalidState) {
        try game.nativeStationPopulationHeader()
      }
    }
    #expect(expected == ["valid", "absent-world"].contains(scenario))
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(game.nextBodyID == before.nextBodyID && game.docked == before.docked)
    #expect(try encoder.encode(game.commander) == bytes)
    #expect(try encoder.encode(before.commander) == bytes)
  }
}
