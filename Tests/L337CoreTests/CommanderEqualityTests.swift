import Foundation
import Testing

@testable import L337Core

struct CommanderEqualityTests {
  @Test(arguments: [
    "name", "credits", "fuel", "galaxy", "system", "cargo", "equipment", "missiles", "kills",
    "legal",
    "unlimitedMissiles", "unlimitedCargo", "unlimitedCash", "unlimitedFuel", "unlimitedJumps",
    "autoTrade", "speech", "executive", "accommodation", "flightSimulation", "crimeLedger",
    "stationSecurity", "wantedCareers", "npcPersistence", "cargoDebrisLedger", "miningLedger",
    "missionProgress", "xyzzyWantedAmnesty", "profitScanEnabled", "plughDiscoveryMask", "blackjack",
    "xyzzyCashGranted", "fuelStorageUnits", "capitalRewardClaimed", "retaliationEnabled",
  ])
  func equalityDistinguishesChangedResourcesAndPresentDefaultSavedValues(field: String) throws {
    let original = Commander()
    var changed = original
    switch field {
    case "name": changed.name = "Different Commander"
    case "credits": changed.credits += 1
    case "fuel": changed.fuel -= 1
    case "galaxy": changed.galaxy = 1
    case "system": changed.system += 1
    case "cargo": changed.cargo[0] = 1
    case "equipment": changed.equipment.insert("E.C.M. System")
    case "missiles": changed.missiles += 1
    case "kills": changed.kills = 1
    case "legal": changed.legal = 1
    case "unlimitedMissiles": changed.unlimitedMissiles.toggle()
    case "unlimitedCargo": changed.unlimitedCargo.toggle()
    case "unlimitedCash": changed.unlimitedCash.toggle()
    case "unlimitedFuel": changed.unlimitedFuel.toggle()
    case "unlimitedJumps": changed.unlimitedJumps.toggle()
    case "autoTrade": changed.autoTrade.toggle()
    case "speech": changed.speech.toggle()
    case "executive": changed.executive.toggle()
    case "accommodation": changed.accommodation = ShipAccommodation()
    case "flightSimulation": changed.flightSimulation = FlightSimulationState()
    case "crimeLedger": changed.crimeLedger = CrimeLedger()
    case "stationSecurity": changed.stationSecurity = StationSecurity()
    case "wantedCareers": changed.wantedCareers = WantedCareerLedger()
    case "npcPersistence": changed.npcPersistence = NPCPersistenceLedger()
    case "cargoDebrisLedger": changed.cargoDebrisLedger = CargoDebrisLedger()
    case "miningLedger": changed.miningLedger = MiningLedger()
    case "missionProgress": changed.missionProgress = [:]
    case "xyzzyWantedAmnesty": changed.xyzzyWantedAmnesty = false
    case "profitScanEnabled": changed.profitScanEnabled = false
    case "plughDiscoveryMask": changed.plughDiscoveryMask = 0
    case "blackjack": changed.blackjack = BlackjackMission()
    case "xyzzyCashGranted": changed.xyzzyCashGranted = false
    case "fuelStorageUnits": changed.fuelStorageUnits = 0
    case "capitalRewardClaimed": changed.capitalRewardClaimed = false
    case "retaliationEnabled": changed.retaliationEnabled = true
    default: Issue.record(Comment(rawValue: "Unrecognised commander equality fixture: " + field))
    }
    #expect(original != changed && changed != original)
    let retained = changed
    let reloaded = try JSONDecoder().decode(
      Commander.self, from: JSONEncoder().encode(changed))
    #expect(changed == retained && retained == reloaded)
    #expect(original == Commander())
  }

  @Test func nestedClockEqualityPreservesNaNAndSignedZeroMemberSemantics() {
    var left = Commander()
    var right = Commander()
    left.scriptState.nextEvent = 1
    right.scriptState.nextEvent = 1
    left.scriptState.flightSeconds = .nan
    right.scriptState.flightSeconds = .nan
    #expect(left != right)
    left.scriptState.flightSeconds = -0.0
    right.scriptState.flightSeconds = 0.0
    #expect(left == right && right == left)
  }
}
