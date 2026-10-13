import Foundation

public struct GalaxyBrowseState: Sendable {
  public var galaxy: Int?
  public var targets: [Int?] = Array(repeating: nil, count: 8)
  public init() {}
}
public struct SystemInspection: Sendable {
  public let galaxy: Int
  public let system: Int
}
private enum ChartUniverses {
  static let all = (0..<8).map { Universe.systemsIncludingPlugh(number: $0) }
}
extension Game {
  public var viewedGalaxy: Int {
    screen == .chart ? (galacticBrowse.galaxy ?? commander.galaxy) : commander.galaxy
  }
  public var mapIsCurrentGalaxy: Bool { viewedGalaxy == commander.galaxy }
  public var mapSystems: [StarSystem] {
    screen == .chart
      ? ChartUniverses.all[viewedGalaxy].filter {
        !$0.isPlugh || commander.hasDiscoveredPlugh(in: viewedGalaxy)
      } : knownSystems
  }
  public var viewedSystemID: Int {
    if screen != .chart { return selectedSystem }
    return galacticBrowse.targets[viewedGalaxy] ?? (mapIsCurrentGalaxy ? selectedSystem : 0)
  }
  public var mapTargetSystem: StarSystem {
    mapSystems.first { $0.id == viewedSystemID } ?? mapSystems[0]
  }
  public var inspectedGalaxy: Int {
    (screen == .chart || screen == .shortChart)
      ? viewedGalaxy
      : (systemInspection?.galaxy ?? commander.galaxy)
  }
  public var inspectedSystem: StarSystem {
    if screen == .chart || screen == .shortChart { return mapTargetSystem }
    guard let inspection = systemInspection else { return targetSystem }
    return ChartUniverses.all[inspection.galaxy][inspection.system]
  }
  public mutating func viewGalaxy(_ galaxy: Int) {
    chartInformationScroll = 0
    galacticBrowse.galaxy = max(0, min(7, galaxy))
    mapSearch.query = ""
    mapSearch.highlight = 0
    mapSearch.offset = 0
  }
  public mutating func returnChartToCurrentLocation() {
    chartInformationScroll = 0
    galacticBrowse.galaxy = commander.galaxy
    galacticBrowse.targets[commander.galaxy] = commander.system
    mapSearch = PlanetSearchState()
  }
  mutating func selectChartSystem(_ id: Int) {
    guard mapSystems.contains(where: { $0.id == id }) else { return }
    chartInformationScroll = 0
    if screen == .chart {
      galacticBrowse.targets[viewedGalaxy] = id
    } else {
      manuallySelectSystem(id)
    }
  }
  mutating func selectChartNeighbour(_ direction: Int) {
    let systems = mapSystems
    let old = systems.firstIndex { $0.id == viewedSystemID } ?? 0
    let index = (old + direction + systems.count) % systems.count
    selectChartSystem(systems[index].id)
  }
  mutating func prepareChartTravel() -> Bool {
    guard screen == .chart else { return true }
    guard mapIsCurrentGalaxy else {
      notify("TRAVEL / ROUTES REQUIRE THE CURRENT GALAXY")
      return false
    }
    manuallySelectSystem(viewedSystemID)
    return true
  }
}
extension ChartLayout {
  public var galaxyButtons: [CanvasRect] {
    let cell = min(600, width - 112) / 8
    return (0..<8).map { .init(x: 80 + Double($0) * cell, y: 58, width: cell - 4, height: 26) }
  }
  public var currentLocationButton: CanvasRect {
    .init(x: width - 126, y: 28, width: 110, height: 24)
  }
}
