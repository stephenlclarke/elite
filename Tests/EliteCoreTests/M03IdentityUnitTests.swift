import Foundation
import Testing

@testable import EliteCore

struct M03IdentityUnitTests {
  @Test func freshValuesRetainApprovedCommanderWorldShipMoneyAndFullFuel() throws {
    let commander = Commander()
    let world = try Universe.originalWorld(galaxy: commander.galaxy, system: commander.system)
    #expect(commander.name == "Rowan Calder" && commander.credits == 7200)
    #expect(world.key == "G01-S007" && world.name == "Avenor")
    #expect(commander.shipID == "SH025" && commander.ship.name == "Peregrine Mk V")
    #expect(commander.fuel == 130 && commander.fuel == commander.fuelCapacity)
    #expect(commander.missionProgress.isEmpty && commander.scriptState.instances.isEmpty)
  }

  @Test func approvedContactsKeepExactRolesAndGalaxySelectionWithoutInventedNames() {
    let expected = [
      "Captain Elara Venn", "Captain Orin Sorel", "Captain Tamsin Holt", "Agent Mara Vale",
    ]
    #expect(OriginalContactIdentity.allCases.map(\.displayName) == expected)
    #expect(OriginalContactIdentity.huntCaptain(galaxy: 0) == .huntCaptainFirstGalaxy)
    #expect(OriginalContactIdentity.huntCaptain(galaxy: 1) == .huntCaptainSecondGalaxy)
    // Preserve the existing nonzero-galaxy template selection; this adds no availability gate.
    for galaxy in 2..<8 {
      #expect(OriginalContactIdentity.huntCaptain(galaxy: galaxy) == .huntCaptainSecondGalaxy)
    }
  }

  @Test func noticeAndPackTemplatesUseSameApprovedContactsAndPreserveChosenCommander() throws {
    var game = Game(executive: false)
    game.commander.name = "Chosen Pilot"
    let before = game.commander
    for galaxy in 0..<2 {
      game.commander.galaxy = galaxy
      let retained = game.commander
      for message in [MissionMessage.constrictorBriefing, .ceerdiOrders, .plansCollection] {
        let notice = MissionNotice(message: message, commander: game.commander.name, galaxy: galaxy)
        let template = try #require(notice.dialog?.text)
        let text = notice.text
        #expect(game.packText(template) == text)
        #expect(text.contains("COMMANDER Chosen Pilot"))
        #expect(!text.contains("{") && !text.contains("}"))
        switch message {
        case .constrictorBriefing:
          #expect(text.contains(galaxy == 0 ? "CAPTAIN ELARA VENN" : "CAPTAIN ORIN SOREL"))
        case .ceerdiOrders:
          #expect(text.contains("CAPTAIN TAMSIN HOLT"))
        case .plansCollection:
          #expect(text.contains("AGENT MARA VALE"))
        default:
          Issue.record("Unexpected contact template")
        }
        #expect(
          !["CARRUTHERS", "FOSDYKE SMYTHE", "FORTESQUE", "AGENT BLAKE"].contains(
            where: text.contains))
      }
      #expect(game.commander == retained)
    }
    #expect(game.commander.name == before.name && game.commander.credits == before.credits)
    #expect(game.commander.missionProgress == before.missionProgress)
  }

  private func rows(_ frame: Frame, at y: Int) -> [UInt32] {
    Array(frame.pixels[(y * Frame.width)..<((y + 7) * Frame.width)])
  }
  @Test func bothStartupProjectionsUseCurrentTitleAndKeepTruthfulBuildAttribution() {
    var game = Game(executive: false)
    game.screen = .title
    let before = game.commander
    let responsive = Display.startupScreen(game, width: 768, height: 768)
    let labels = responsive.labels.map(\.text)
    #expect(labels.contains("L337"))
    #expect(labels.contains(BuildIdentity.repository))
    #expect(labels.contains(BuildIdentity.current.versionLine))
    #expect(labels.contains(BuildIdentity.current.revisionLine))
    let legacy = Display.render(game, rasterizeGraphics: false, dashboard: false)
    var expected = Frame()
    expected.centered("L337", 22)
    #expect(rows(legacy, at: 22) == rows(expected, at: 22))
    var attribution = Frame()
    attribution.centered(BuildIdentity.repository, 218)
    #expect(rows(legacy, at: 218) == rows(attribution, at: 218))
    game.screen = .demo
    game.time = 3
    let demo = Display.render(game, rasterizeGraphics: false, dashboard: false)
    let count = 7 + BuildIdentity.current.legacyRevisionLines.count
    let y = 274 - Int(game.time * Double(250 + count * 24) / 11)
    var demoTitle = Frame()
    demoTitle.centered("L337", y)
    #expect(rows(demo, at: y) == rows(demoTitle, at: y))
    #expect(game.commander == before)
  }

  @Test func homePortUsesOriginalWorldIdentityRatherThanPredecessorNameOrOtherGalaxy() {
    var game = Game(executive: true)
    game.screen = .system
    game.selectedSystem = 7
    let before = game.commander
    #expect(Display.systemRows(game).contains { $0.0 == "XYZZY HOME PORT" })
    #expect(game.currentSystem.name == "Avenor" && game.commander == before)
    game.selectedSystem = Plugh.systemID
    #expect(!Display.systemRows(game).contains { $0.0 == "XYZZY HOME PORT" })
    game.commander.galaxy = 1
    game.systems = Universe.systemsIncludingPlugh(number: 1)
    game.selectedSystem = 7
    #expect(!Display.systemRows(game).contains { $0.0 == "XYZZY HOME PORT" })
  }
}
