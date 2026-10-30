import Testing

@testable import L337Core

struct WantedDossierNameUnitTests {
  private func entry(system: SystemIdentity, destination: SystemIdentity?) -> WantedBoardEntry {
    // Supplied historical projection facts only: no target spawn, registry entry or route receipt.
    .init(
      identity: .init(system: system, visit: 1, entity: 2), name: "Reported pilot",
      ship: "SH023", legal: .init(value: 16, bountyTenths: 50), recordedKills: 0,
      sighting: .init(
        system: system, position: .init(0, 0, 0), heading: .init(0, 0, 1),
        destination: destination, time: 0))
  }

  @Test func recordedPlughLocationsAndDestinationsKeepTheirGalaxyAndName() {
    let game = Game(executive: false)
    let before = game.commander
    for galaxy in 0..<8 {
      let ordinary = SystemIdentity(galaxy: galaxy, system: 7)
      let plugh = SystemIdentity(galaxy: galaxy, system: Plugh.systemID)
      let name = Universe.galaxy(number: galaxy)[7].name
      let fromPlugh = entry(system: plugh, destination: ordinary)
      let toPlugh = entry(system: ordinary, destination: plugh)
      #expect(fromPlugh.sighting?.valid == true && toPlugh.sighting?.valid == true)
      let originRows = game.wantedDossier(fromPlugh)
      let destinationRows = game.wantedDossier(toPlugh)
      #expect(originRows.contains("Last report: Galaxy \(galaxy + 1) / PLUGH"))
      #expect(originRows.contains("Next reported destination: Galaxy \(galaxy + 1) / " + name))
      #expect(destinationRows.contains("Last report: Galaxy \(galaxy + 1) / " + name))
      #expect(destinationRows.contains("Next reported destination: Galaxy \(galaxy + 1) / PLUGH"))
    }
    #expect(game.commander == before && game.wantedBoard.isEmpty)
  }

  @Test func ordinaryAndUnknownReportsRetainHistoricalWordingWithoutChangingProperty() {
    let game = Game(executive: false)
    let before = game.commander
    let target = game.selectedSystem
    for galaxy in 0..<8 {
      let ordinary = SystemIdentity(galaxy: galaxy, system: 7)
      let reported = entry(system: ordinary, destination: nil)
      let lines = game.wantedDossier(reported)
      #expect(
        lines.contains(
          "Last report: Galaxy \(galaxy + 1) / " + Universe.galaxy(number: galaxy)[7].name))
      #expect(lines.contains("Next reported destination: Unknown"))
      #expect(lines.contains("Reports are historical, not a live position or intercept."))
      #expect(lines.contains("Paid only by native lawful death settlement. No board bonus."))
      let unknown = WantedBoardEntry(
        identity: reported.identity, name: reported.name, ship: nil, legal: reported.legal,
        recordedKills: reported.recordedKills, sighting: nil)
      #expect(
        game.wantedDossier(unknown).contains(
          "Last location / heading / next destination / time: Unknown"))
    }
    #expect(game.commander == before && game.selectedSystem == target)
    #expect(game.wantedBoard.isEmpty)
  }
}
