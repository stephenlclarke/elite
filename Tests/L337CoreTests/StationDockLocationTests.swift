import Testing

@testable import L337Core

struct StationDockLocationTests {
  @Test(arguments: ["", "RRS Waystation", "RRS Headquarters"])
  func undockedStatusNeverClaimsAStationFromRetainedDockMetadata(station: String) {
    let name = station.isEmpty ? nil : station
    for main in [false, true] {
      #expect(
        StationDockLocation.row(docked: false, atMainStation: main, nativeStationName: name)
          == "Station: Not docked")
    }
  }

  @Test(arguments: ["Main orbital station", "RRS Waystation", "RRS Headquarters"])
  func dockedStatusNamesTheActualMainOrNativeStation(station: String) {
    let main = station == "Main orbital station"
    let row = StationDockLocation.row(
      docked: true, atMainStation: main, nativeStationName: main ? nil : station)
    #expect(row == "Station: " + station)
    #expect(!row.contains("Not docked") && !row.contains("unavailable"))
  }

  @Test func unknownDockDoesNotInventAMainStationOrClaimTheShipIsInSpace() {
    let row = StationDockLocation.row(
      docked: true, atMainStation: false, nativeStationName: nil)
    #expect(row == "Station: Dock location unavailable")
    #expect(!row.contains("Main orbital") && !row.contains("Not docked"))
  }
}
