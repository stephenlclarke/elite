import Foundation
import Testing

@testable import L337Core

@Test func nativeTextUsesOneFixedLogicalSizeAcrossEveryScreenAndWindowSize() {
  var game = Game(executive: false)
  game.time = 5
  game.missionElapsed = 3
  game.missionNotice = .init(message: .constrictorBriefing, commander: "JAMESON", galaxy: 0)
  game.blackjackOffer = .init(action: .introduction, galaxy: 1, system: 241)
  for screen in Screen.allCases {
    game.screen = screen
    for (width, height) in [(512.0, 518.0), (768, 768), (1512, 982), (2560, 1440)] {
      let frame = Display.presentation(game, width: width, height: height)
      #expect(frame.responsive && frame.canvas.width == width && frame.canvas.height == height)
      for label in frame.labels {
        #expect(label.scale == GameTypography.scale, "\(screen): \(label.text)")
        #expect(
          label.bounds.x >= 0 && label.bounds.maxX <= width,
          "\(screen) \(width): \(label.text) \(label.bounds)")
        #expect(
          label.bounds.y >= 0 && label.bounds.maxY <= height,
          "\(screen) \(width): \(label.text) \(label.bounds)")
      }
    }
  }
  game.screen = .chart
  game.mapSearch.active = true
  game.mapSearch.query = "a"
  #expect(
    Display.presentation(game, width: 512, height: 518).labels.allSatisfy {
      $0.scale == GameTypography.scale
    })
}

@Test func equipmentMountHeadingsWeaponsAndClickTargetsStayPairedAfterReflow() throws {
  var game = Game(executive: false)
  // This layout unit requires the Cobra's declared mining work-tool destination.
  game.commander.shipID = "SH023"
  game.commander.fuel = game.commander.fuelCapacity
  game.screen = .equipment
  game.commander.installLaser(.military, on: .front)
  game.commander.installLaser(.naval, on: .right)
  game.commander.installLaser(.mining, on: .rear)
  for width in [512.0, 699, 700, 768, 1512, 2560] {
    game.viewportWidth = width
    game.viewportHeight = 518
    let layout = EquipmentLayout(game: game, width: width, height: 518)
    #expect((layout.mounts[2].bounds.y > layout.mounts[0].bounds.y) == (width < 700))
    let item = game.selection
    for cell in layout.mounts {
      game.equipmentClick(y: cell.bounds.y + 27, x: cell.bounds.x + 15)
      #expect(game.equipmentMount == cell.mount && game.selection == item)
      let frame = Display.presentation(game, width: width, height: 518)
      let heading = try #require(frame.labels.first { $0.text == cell.mount.label })
      let weapon = try #require(
        frame.labels.first {
          $0.text == (game.commander.laser(on: cell.mount)?.equipmentName ?? "Empty")
            && $0.y == cell.bounds.y + 24 && $0.x == heading.x
        })
      #expect(cell.bounds.contains(.init(heading.x, heading.y)))
      #expect(weapon.bounds.maxX < cell.bounds.maxX && weapon.bounds.maxY < cell.bounds.maxY)
      #expect(heading.ink == .cyan)
      #expect(frame.labels.contains { $0.text == "Buying for: " + cell.mount.label })
      #expect(frame.labels.contains { $0.text == ">" && $0.y >= layout.listTop })
      let price = try #require(frame.labels.first { $0.text == "PRICE / STATUS" })
      #expect(
        price.y == layout.listTop - 22 && price.bounds.maxX == layout.left + layout.contentWidth)
      game.key("right")
      if cell.mount == .rear {
        #expect(game.equipmentWorkTool && game.equipmentMount == .rear)
      } else {
        #expect(!game.equipmentWorkTool && game.equipmentMount == cell.mount.next)
      }
      game.key("left")
      #expect(!game.equipmentWorkTool && game.equipmentMount == cell.mount)
    }
    game.equipmentClick(y: layout.mounts[0].bounds.maxY + 2, x: layout.left + 10)
    #expect(game.selection == item && game.equipmentMount == .rear)
  }
}

@Test func compactSystemDataHelpSecretAndNavalPagesKeepAllContentReachable() {
  var game = Game(executive: true)
  game.screen = .system
  game.missionClue =
    "A CLUE WITH THE ORIGINAL NAVAL MISSION DESTINATION AND OPTIONAL ROUTE DETAILS."
  let data = Display.presentation(game, width: 512, height: 518)
  for name in [
    "Economy:", "Government:", "Tech level:", "Population:", "Gross productivity:",
    "Average radius:",
  ] {
    #expect(data.labels.contains { $0.text.hasPrefix(name) })
  }
  #expect(data.labels.contains { $0.text.contains("A CLUE") })
  game.screen = .secret
  game.viewportWidth = 512
  game.viewportHeight = 518
  var visible = Set<String>()
  for _ in 0..<game.secretChoices.count {
    let secret = Display.presentation(game, width: 512, height: 518)
    visible.formUnion(secret.labels.map(\.text))
    game.key("down")
  }
  #expect(game.secretChoices.allSatisfy { visible.contains($0) })
  game.screen = .help
  for screen in Screen.allCases {
    game.helpReturn = screen
    for page in PlayerHelp.pages(for: game).indices {
      game.helpPage = page
      let frame = Display.presentation(game, width: 512, height: 518)
      #expect(frame.labels.allSatisfy { $0.bounds.maxY <= 518 && $0.bounds.maxX <= 512 })
    }
  }
  game.screen = .mission
  game.missionElapsed = 3
  for message in [
    MissionMessage.constrictorBriefing, .constrictorDebriefing, .ceerdiOrders,
    .plansCollection, .plansDebriefing,
  ] {
    game.missionNotice = .init(message: message, commander: "JAMESON", galaxy: 0)
    for page in game.missionNotice!.pages.indices {
      game.missionPage = page
      let frame = Display.presentation(game, width: 512, height: 518)
      let bottom = CockpitLayout(game: game, width: 512, height: 518).dashboardTop
      for line in game.missionNotice!.pages[page] where !line.isEmpty {
        #expect(frame.labels.contains { $0.text == line && $0.bounds.maxY < bottom - 26 })
      }
    }
  }
}
