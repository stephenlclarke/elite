import Foundation
import Testing

@testable import EliteCore

@Test func showroomPrimaryTradeWorksWithClickOrKeyboardAndNeverBuysOnOpening() throws {
  for width in [512.0, 768, 1000, 1512] {
    var game = Game(executive: false)
    game.viewportWidth = width
    game.viewportHeight = 518
    game.commander.credits = 10_000_000
    game.screen = .status
    game.key("6")
    game.showroom.selection = "SH013"
    let before = game.commander
    let layout = ShowroomLayout(width: width, height: 518, detail: false)
    let frame = Display.presentation(game, width: width, height: 518)
    let action = try #require(frame.labels.first { $0.text == "Switch ship - review trade" })
    #expect(layout.trade.contains(.init(action.x, action.y)))
    #expect(frame.labels.contains { $0.text.contains("Trade-in") })
    #expect(frame.labels.contains { $0.text.contains("Balance") })
    game.showroomClick(x: layout.trade.x + 10, y: layout.trade.y + 10)
    #expect(game.showroom.trading && !game.showroom.confirmTrade && game.commander == before)
    game.key("escape")
    game.key("return")
    #expect(game.showroom.detail && !game.showroom.trading)
    game.key("return")
    #expect(game.showroom.trading && game.commander == before)
    game.key("right")
    game.key("return")
    #expect(game.commander.shipID == "SH013" && game.showroomBaseline?.id == "SH013")
    let owned = Display.presentation(game, width: width, height: 518)
    #expect(owned.labels.contains { $0.text == "Currently flying" })
    game.showroomClick(x: layout.trade.x + 10, y: layout.trade.y + 10)
    #expect(!game.showroom.trading)
  }
}

@Test func blockedTradeStaysDiscoverableAndComparisonLegendFollowsTradeoffs() throws {
  var game = Game(executive: false)
  game.screen = .status
  game.key("6")
  game.showroom.selection = "SH013"
  game.showroom.detail = true
  for width in [512.0, 768, 1000, 1512] {
    game.viewportWidth = width
    game.viewportHeight = 900
    let layout = ShowroomLayout(width: width, height: 900, detail: true)
    let frame = Display.presentation(game, width: width, height: 900)
    #expect(frame.labels.contains { $0.text == "Trade blocked - open review for reasons" })
    let legend = try #require(frame.labels.first { $0.text == "Comparison: same carried fit" })
    let tradeoff = try #require(frame.labels.first { $0.text == "Tradeoff: More cargo capacity" })
    #expect(legend.y > tradeoff.y)
    #expect(frame.labels.contains { $0.text == "BETTER" && $0.ink == .green && $0.y > legend.y })
    #expect(frame.labels.allSatisfy { $0.bounds.maxX <= width - 16 && $0.bounds.maxY < 900 })
    game.showroomClick(x: layout.trade.x + 10, y: layout.trade.y + 10)
    #expect(game.showroom.trading && game.shipTradeQuote?.allowed == false)
    #expect(game.shipTradeQuote!.issues.contains { $0.contains("cash") })
    game.key("escape")
  }
}

@Test func xyzzyCobraRestorePreservesPropertyProgressAndUniqueShipsWithoutMintingCash() throws {
  var game = Game(executive: false)
  game.screen = .status
  game.commander.shipID = "SH013"
  for key in "xyzzy" { game.key(String(key)) }
  #expect(game.commander.name == "CLARKE" && game.commander.shipID == "SH023")
  #expect(game.secretChoices.contains { $0.hasPrefix("C SWITCH TO COBRA MK III") })
  game.commander.autoTrade = false
  game.commander.shipID = "SH013"
  game.commander.unlimitedCargo = false
  game.commander.cargo[0] = 40
  game.commander.credits = 12345
  game.commander.legal = 17
  game.commander.kills = 42
  game.commander.missionStage = .huntingConstrictor
  game.commander.missionProgress["test.courier/delivery"] = .init(
    version: "1.0.0", digest: String(repeating: "a", count: 64), stage: "carrying",
    receipts: ["transition.accept"], payloads: ["parcel": 1])
  game.bodies = [.init(id: 987, hull: .constrictor, position: .init(1, 2, 500), hostile: true)]
  let cargo = game.commander.cargo
  let bodies = game.bodies
  let progress = game.commander.missionProgress
  game.key("c")
  #expect(game.commander.shipID == "SH023" && game.commander.credits == 12345)
  #expect(game.commander.cargo == cargo && game.commander.unlimitedCargo)
  #expect(game.commander.legal == 17 && game.commander.kills == 42)
  #expect(game.commander.missionStage == .huntingConstrictor && game.bodies == bodies)
  #expect(game.commander.missionProgress == progress)
  #expect(game.commander.navigationTier == .military && game.commander.targetingTier == .military)
  #expect(game.commander.fuelStorageUnits == FuelStorage.maximumCount)
  #expect(LaserMount.allCases.allSatisfy { game.commander.laser(on: $0) == .naval })
  #expect(game.energy == game.commander.performance.energy && game.commander.valid)
  let restored = game.commander
  game.key("c")
  #expect(game.commander == restored)
  game.key("escape")
  for key in "xyzzy" { game.key(String(key)) }
  #expect(game.commander == restored && game.bodies == bodies)
  let loaded = try JSONDecoder().decode(Commander.self, from: JSONEncoder().encode(restored))
  #expect(loaded == restored && loaded.shipID == "SH023" && loaded.valid)
}
