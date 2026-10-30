import Foundation
import Testing

@testable import EliteCore

struct ShowroomComparisonUnitTests {
  private func game(width: Double = 768) -> Game {
    var game = Game(executive: false)
    game.commander.shipID = "SH023"
    game.commander.fuel = game.commander.fuelCapacity
    game.commander.credits = 10_000_000
    game.viewportWidth = width
    game.viewportHeight = 900
    game.screen = .showroom
    game.showroom.detail = true
    game.showroom.selection = "SH013"
    return game
  }

  @Test func compactAndWideSpecsShowBothCurrentAndPinnedModelsWithoutChangingBrowseMode() {
    for width in [512.0, 768, 1000, 1512] {
      var game = game(width: width)
      let layout = ShowroomLayout(width: width, height: 900, detail: true)
      for pinned in [false, true] {
        game.showroom.baselineUsesCurrent = !pinned
        game.showroom.baseline = "SH023"
        let frame = Display.showroomScreen(game, width: width, height: 900)
        #expect(frame.labels.contains { $0.text == (pinned ? "PINNED BASELINE" : "CURRENT SHIP") })
        #expect(
          frame.labels.contains { $0.text == "SELECTED SHIP" && $0.x == layout.selectedModelX })
        let modelLabels = frame.labels.filter {
          $0.y >= layout.model.y && $0.y < layout.model.maxY
        }
        #expect(modelLabels.allSatisfy { $0.bounds.maxX <= width - 16 })
        #expect(!frame.shipPanels.isEmpty)
      }
      game.showroom.compare = false
      #expect(
        !Display.showroomScreen(game, width: width, height: 900).labels.contains {
          $0.text == "SELECTED SHIP"
        })
      if width < 1000 {
        game.showroom.compare = true
        game.showroom.detail = false
        let browse = Display.showroomScreen(game, width: width, height: 900)
        #expect(!browse.labels.contains { $0.text == "SELECTED SHIP" })
        #expect(browse.labels.contains { $0.text.hasPrefix("Browsing:") })
      }
    }
  }

  @Test func bothRenderedPreviewsKeepTheSamePitchRollAndYawThroughRotationAndPause() throws {
    for width in [512.0, 768, 1000, 1512] {
      var game = game(width: width)
      // The same owned mesh makes a differing transform visible in the actual projected vertices.
      game.showroom.selection = game.commander.shipID
      let layout = ShowroomLayout(width: width, height: 900, detail: true)
      var previous: [ShipPanel] = []
      for angle in [0.0, 0.7, 2.1, 5.0] {
        game.showroom.angle = angle
        let frame = Display.showroomScreen(game, width: width, height: 900)
        let left = frame.shipPanels.filter {
          $0.vertices.allSatisfy { $0.x < layout.selectedModelX }
        }
        let right = frame.shipPanels.filter {
          $0.vertices.allSatisfy { $0.x >= layout.selectedModelX }
        }
        try #require(!left.isEmpty && left.count == right.count)
        let offset = layout.selectedModelX - layout.model.x
        for (a, b) in zip(left, right) {
          try #require(a.vertices.count == b.vertices.count)
          #expect(a.colour == b.colour)
          for (p, q) in zip(a.vertices, b.vertices) {
            #expect(abs(p.x + offset - q.x) < 0.000001)
            #expect(abs(p.y - q.y) < 0.000001)
          }
        }
        if !previous.isEmpty { #expect(left != previous) }
        previous = left
      }
      game.showroom.rotationPaused = true
      let paused = Display.showroomScreen(game, width: width, height: 900).shipPanels
      game.showroom.advance(delta: 1)
      #expect(Display.showroomScreen(game, width: width, height: 900).shipPanels == paused)
      game.showroom.rotationPaused = false
      game.showroom.advance(delta: 1)
      #expect(Display.showroomScreen(game, width: width, height: 900).shipPanels != paused)
    }
  }

  @Test func equalDisplayedSpeedsKeepSameRatingWithoutContradictoryTradeoffHints() throws {
    for (baseline, selected) in [("SH062", "SH025"), ("SH025", "SH062")] {
      var game = game()
      game.showroom.baselineUsesCurrent = false
      game.showroom.baseline = baseline
      game.showroom.selection = selected
      let before = game.commander
      let left = try #require(
        game.showroomBaselineProfile?.fields.first {
          $0.key == "maximum_speed_project_units"
        })
      let right = try #require(
        game.showroomProfile?.fields.first {
          $0.key == "maximum_speed_project_units"
        })
      #expect(left.number != right.number)
      #expect(left.text == "34.3 speed" && right.text == left.text)
      let row = try #require(game.showroomComparison.first { $0.label == "Top speed" })
      #expect(row.rating == .same)
      #expect(!game.showroomTradeoffs.contains("Higher maximum speed"))
      #expect(!game.showroomTradeoffs.contains("Lower maximum speed"))
      #expect(
        game.showroomTradeoffs.contains(
          selected == "SH025" ? "Less cargo capacity" : "More cargo capacity"))
      #expect(game.commander == before)
    }
  }

  @Test func visibleSpeedDifferencesRetainTheirHigherAndLowerTradeoffHints() throws {
    for (baseline, selected, rating, hint) in [
      ("SH023", "SH013", ComparisonRating.worse, "Lower maximum speed"),
      ("SH013", "SH023", .better, "Higher maximum speed"),
    ] {
      var game = game()
      game.showroom.baselineUsesCurrent = false
      game.showroom.baseline = baseline
      game.showroom.selection = selected
      let row = try #require(game.showroomComparison.first { $0.label == "Top speed" })
      #expect(row.baseline != row.selected && row.rating == rating)
      #expect(game.showroomTradeoffs.contains(hint))
      #expect(
        !game.showroomTradeoffs.contains(
          hint == "Higher maximum speed" ? "Lower maximum speed" : "Higher maximum speed"))
    }
  }

  @Test func sourceProfileTradeoffsKeepTheirOwnNumbersAndUnits() throws {
    var game = game()
    game.showroom.baselineUsesCurrent = false
    game.showroom.baseline = "SH062"
    game.showroom.selection = "SH025"
    game.showroom.sourceProfiles = true
    game.showroom.profileIndex = try #require(
      game.showroomProfiles.firstIndex {
        $0.group == "project-refit-v1"
      })
    let left = try #require(
      game.showroomBaselineProfile?.fields.first {
        $0.key == "maximum_speed_project_units"
      })
    let right = try #require(
      game.showroomProfile?.fields.first {
        $0.key == "maximum_speed_project_units"
      })
    #expect(left.number == 375 && right.number == 34.3)
    #expect(left.unit == "project units/s" && right.unit == left.unit)
    let row = try #require(game.showroomComparison.first { $0.label == right.label })
    #expect(row.difference == ShipComparisonRow.difference(left, right, comparable: true))
    #expect(!row.difference.isEmpty)
    #expect(game.showroomTradeoffs.contains("Lower maximum speed"))
    #expect(!game.showroomTradeoffs.contains("Higher maximum speed"))
  }

  @Test func comparisonMatchesQuotedPriceAndActualTransferredFitWithHonestRatings() throws {
    var game = game()
    try game.commander.prepareEquipment()
    let before = game.commander
    let quote = try #require(game.shipTradeQuote)
    try #require(quote.allowed)
    let selected = try #require(game.showroomProfile)
    let baseline = try #require(game.showroomBaselineProfile)
    var transferred = before
    try transferred.transferEquipment(to: quote.selected.id, hullID: UUID())
    let actual = transferred.gameShipProfile
    #expect(selected.fields.map(\.text) == actual.fields.map(\.text))
    #expect(selected.fields.map(\.number) == actual.fields.map(\.number))
    #expect(baseline.fields.map(\.text) == before.gameShipProfile.fields.map(\.text))
    #expect(selected.fields.first { $0.key == "price" }?.number == Double(quote.purchase) / 10)
    let rows = game.showroomComparison
    #expect(rows.first { $0.label == "Cargo" }?.rating == .better)
    #expect(rows.first { $0.label == "Hull price" }?.rating == .worse)
    #expect(rows.first { $0.label == "Loaded missiles" }?.rating == .same)
    #expect(rows.first { $0.label == "Fitted lasers" }?.rating == .same)
    #expect(game.commander == before)
  }
}

@Test func showroomPrimaryTradeWorksWithClickOrKeyboardAndNeverBuysOnOpening() throws {
  for width in [512.0, 768, 1000, 1512] {
    var game = Game(executive: false)
    // This confirmation flow trades a compatible carried fit from Cobra to Boa.
    game.commander.shipID = "SH023"
    game.commander.fuel = game.commander.fuelCapacity
    game.energy = game.commander.performance.energy
    game.frontShield = game.commander.shieldCapacity
    game.rearShield = game.commander.rearShieldCapacity
    game.viewportWidth = width
    game.viewportHeight = 518
    game.commander.credits = 10_000_000
    game.screen = .status
    game.key("6")
    game.showroom.selection = "SH013"
    let quote = try #require(game.shipTradeQuote)
    try #require(quote.allowed)
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
    #expect(game.commander.credits == quote.balance)
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
  game.commander.cargo = Array(repeating: 0, count: 17)
  let owner = game.commander.equipmentOwnerID
  for slot in [ComponentFittingSlot.utility(.miningLaser), .utility(.salvageCutter)] {
    let item = try #require(game.commander.fittedEquipment(at: slot))
    let revision = try #require(game.commander.equipmentInventory?.revision)
    try game.commander.storeEquipment(item, expectedRevision: revision)
  }
  try game.commander.transferEquipment(to: "SH013", hullID: UUID())
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
  let inventory = try #require(game.commander.equipmentInventory)
  let portable = Set(inventory.items.filter { $0.boundHull == nil }.map(\.id))
  #expect(game.commander.valid && game.commander.shipID == "SH013")
  game.key("c")
  #expect(game.commander.shipID == "SH023" && game.commander.credits == 12345)
  #expect(game.commander.equipmentOwnerID == owner)
  #expect(game.commander.hullInstanceID != inventory.activeHull)
  #expect(portable.isSubset(of: Set(game.commander.equipmentInventory?.items.map(\.id) ?? [])))
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
