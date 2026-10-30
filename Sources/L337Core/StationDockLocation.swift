enum StationDockLocation {
  static func row(docked: Bool, atMainStation: Bool, nativeStationName: String?) -> String {
    guard docked else { return "Station: Not docked" }
    if let nativeStationName { return "Station: " + nativeStationName }
    return atMainStation ? "Station: Main orbital station" : "Station: Dock location unavailable"
  }
}
