import Foundation
import Testing

@testable import EliteCore

@Test func shipExchangeTransfersFitCargoMissionsAndCashAndCanTradeAgain() throws {
  var game = Game(executive: false)
  game.screen = .status
  game.commander.credits = 10_000_000
  game.commander.cargo[0] = 2
  game.commander.cargo[10] = 1
  game.commander.blackjack.stage = .deliverFirearm
  game.commander.blackjack.transfers = [
    .contact, .goldAward, .goldDelivery, .report, .firearmPickup,
  ]
  game.commander.missionStage = .huntingConstrictor
  game.commander.installLaser(.beam, on: .rear)
  game.commander.navigationPlan = nil
  game.key("6")
  game.showroom.selection = "SH013"
  let old = game.commander
  let quote = try #require(game.shipTradeQuote)
  #expect(quote.allowed && quote.purchase == game.showroomShip!.game!.price * 10)
  #expect(quote.allowance == old.performance.price * 10 * 3 / 4)
  game.key("showroom-trade")
  game.key("return")
  #expect(!game.showroom.trading && game.commander == old)
  game.key("showroom-trade")
  game.key("right")
  game.key("return")
  #expect(game.commander.shipID == "SH013" && game.commander.credits == quote.balance)
  #expect(game.commander.cargo == old.cargo && game.commander.equipment == old.equipment)
  #expect(game.commander.fuel == old.fuel && game.commander.missiles == old.missiles)
  #expect(
    game.commander.blackjack == old.blackjack && game.commander.missionStage == old.missionStage)
  #expect(game.energy == game.commander.performance.energy && game.commander.valid)
  game.showroom.selection = "SH023"
  let second = try #require(game.shipTradeQuote)
  #expect(second.allowed && second.allowance == game.commander.performance.price * 10 * 3 / 4)
  game.key("showroom-trade")
  game.key("right")
  game.key("return")
  #expect(game.commander.shipID == "SH023" && game.commander.credits == second.balance)
}

@Test func exchangesBlockFundsCargoPaidFitFuelAndRouteConflictsWithoutAnyLoss() throws {
  var game = Game(executive: false)
  game.screen = .status
  game.key("6")
  game.showroom.selection = "SH013"
  #expect(game.shipTradeQuote!.issues.contains { $0.contains("cash") })
  game.commander.credits = 100_000_000
  game.showroom.selection = "SH001"
  game.commander.cargo[10] = 3
  game.commander.installLaser(.naval, on: .rear)
  game.commander.equipment.insert("Large Cargo Bay")
  let quote = try #require(game.shipTradeQuote)
  #expect(quote.issues.contains { $0.contains("Sell cargo") })
  #expect(quote.issues.contains { $0.contains("Cargo expansion") })
  #expect(quote.issues.contains { $0.contains("Rear laser") })
  #expect(quote.issues.contains { $0.contains("missiles") })
  let old = game.commander
  game.key("showroom-trade")
  game.key("right")
  game.key("return")
  #expect(game.showroom.trading && game.commander == old)
  game.key("8")
  #expect(game.screen == .showroom)
  game.key("escape")
  #expect(!game.showroom.trading && game.commander == old)
  game.showroom.selection = "SH023"
  #expect(game.shipTradeQuote!.issues.contains { $0.contains("already own") })
  game.dockedAtMainStation = false
  #expect(game.shipTradeQuote!.issues.contains { $0.contains("main station") })
  game.showroom.selection = "SH141"
  #expect(game.shipTradeQuote == nil)
  game.key("showroom-trade")
  #expect(!game.showroom.trading)
}

@Test func purchasedHullControlsRealFlightPoolsMountsAndSaveMigration() throws {
  var game = Game(executive: false)
  game.commander.shipID = "SH001"
  game.commander.missiles = 1
  game.launch()
  game.bodies = []
  game.speed = 0
  let p = game.commander.performance
  var controls = Controls()
  controls.throttle = 1
  controls.pitch = 1
  controls.roll = 1
  controls.yaw = 1
  game.tick(delta: 0.1, controls: controls)
  #expect(abs(game.speed - p.acceleration * 0.1) < 0.00001)
  #expect(game.pitch == p.pitch && game.yaw == p.yaw && game.roll == p.roll)
  controls.pitch = 0
  controls.roll = 0
  controls.yaw = 0
  for _ in 0..<100 { game.tick(delta: 0.1, controls: controls) }
  #expect(game.speed == p.speed && game.energy == p.energy)
  game.dock()
  #expect(game.energy == p.energy && game.frontShield == p.shield)
  let data = try JSONEncoder().encode(game.commander)
  let loaded = try JSONDecoder().decode(Commander.self, from: data)
  #expect(loaded == game.commander && loaded.shipID == "SH001" && loaded.valid)
  var legacy = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  legacy.removeValue(forKey: "ownedShipID")
  let migrated = try JSONDecoder().decode(
    Commander.self, from: JSONSerialization.data(withJSONObject: legacy))
  #expect(migrated.shipID == "SH023" && migrated.performance.speed == 32)
  game.commander.shipID = "SH999"
  #expect(!game.commander.valid)
}

@Test func normalizedComparisonsSortAndTOMLLoaderAreConsistent() throws {
  let loaded = try ShipCatalogue.load(from: ShipCatalogue.folder)
  #expect(loaded.count == 168 && loaded.allSatisfy { $0.design.valid })
  #expect(loaded.filter { $0.game != nil }.count == 159)
  #expect(loaded.allSatisfy { $0.previewMesh != nil })
  var game = Game(executive: false)
  game.screen = .status
  game.key("6")
  game.showroom.selection = "SH013"
  let rows = game.showroomComparison
  #expect(rows.first { $0.label == "Cargo" }?.rating == .better)
  #expect(rows.first { $0.label == "Top speed" }?.rating == .worse)
  #expect(rows.first { $0.label == "Shields (each)" }?.rating == .same)
  let before = game.showroom.selection
  game.showroom.query = "boa"
  game.key("showroom-sort")
  #expect(game.showroom.selection == before && game.showroom.query == "boa")
  let powers = game.showroomShips.map { $0.game?.power ?? -1 }
  #expect(powers == powers.sorted(by: >))
  game.key("showroom-sort")
  let names = game.showroomShips.map(\.name)
  #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
  game.commander.unlimitedCargo = true
  #expect(game.showroomComparison.first { $0.label == "Cargo" }?.rating == .same)
  game.key("v")
  #expect(
    game.showroom.sourceProfiles && !game.showroom.compare
      && game.showroomProfiles.count == game.showroomShip?.profiles.count)
  for width in [512.0, 1512] {
    game.viewportWidth = width
    game.viewportHeight = 518
    game.key("showroom-trade")
    let frame = Display.presentation(game, width: width, height: 518)
    #expect(frame.labels.allSatisfy { $0.bounds.maxX <= width && $0.bounds.maxY < 518 })
    game.key("escape")
  }
}

@Test func informationScrollHintsShareViewportAndStopAtBothBoundaries() {
  for screen in [Screen.status, .inventory] {
    var game = Game(executive: false)
    game.screen = screen
    game.fitMaximumHardware()
    for i in game.commander.cargo.indices { game.commander.cargo[i] = 1 }
    game.viewportWidth = 768
    game.viewportHeight = 1400
    #expect(game.informationWindow.hint == nil)
    game.key("down")
    #expect(game.informationScroll == 0)
    let tall = Display.presentation(game, width: 768, height: 1400)
    #expect(
      !tall.labels.contains { $0.text.contains("scroll") || $0.text.contains("Arrows: more") })
    game.viewportHeight = 518
    if screen == .status {
      // The summary now fits; only the detailed inventory needs scrolling.
      #expect(game.informationWindow.hint == nil && game.informationWindow.last == 0)
      game.key("pagedown")
      game.key("up")
      #expect(game.informationScroll == 0)
    } else {
      #expect(game.informationWindow.hint?.hasPrefix("Down:") == true)
      for _ in 0..<100 { game.key("pagedown") }
      #expect(game.informationScroll == game.informationWindow.last)
      #expect(game.informationWindow.hint?.hasPrefix("Up:") == true)
      game.key("up")
      #expect(game.informationScroll == game.informationWindow.last - 1)
    }
    game.docked = false
    #expect(
      Display.presentation(game, width: 768, height: 518).labels.contains {
        $0.text.contains("Esc: back") && $0.text.contains("K: help")
      })
  }
}

@Test func everyModelRemainsVisibleFiniteAndFramedThroughoutFullRotation() {
  for ship in ShipCatalogue.all {
    for step in 0..<24 {
      let frame = Display.shipPortrait(ship, angle: Double(step) * 2 * .pi / 24)
      #expect(!frame.shipPanels.isEmpty, "\(ship.id) angle \(step)")
      #expect(
        frame.shipPanels.allSatisfy {
          $0.vertices.allSatisfy { $0.x.isFinite && $0.y.isFinite && frame.flightClip.contains($0) }
        })
    }
  }
}

@Test func fuelAndRouteConstraintsFollowActualHullTanksAndDoNotDiscardFuel() throws {
  let longRange = try #require(
    ShipCatalogue.all.first { ($0.game?.fuel ?? 0) > 70 && ($0.game?.jump ?? 0) > 7 })
  var game = Game(executive: false)
  game.commander.shipID = longRange.id
  game.commander.fuel = longRange.game!.fuel
  game.commander.credits = 100_000_000
  game.screen = .status
  game.key("6")
  game.showroom.selection = "SH023"
  #expect(game.shipTradeQuote!.issues.contains { $0.contains("fuel") })
  game.commander.fuel = 70
  let destination = try #require(
    game.systems.first {
      let distance = game.currentSystem.distance(to: $0)
      return distance > 7 && distance <= 11
    })
  game.commander.navigationPlan = .init(
    galaxy: 0, path: [game.commander.system, destination.id], tier: .basic,
    originFuel: longRange.game!.fuel, originCapacity: longRange.game!.fuel)
  #expect(game.commander.navigationPlan!.valid)
  #expect(game.shipTradeQuote!.issues.contains { $0.contains("route") })
  game.commander.navigationPlan = nil
  #expect(game.shipTradeQuote!.allowed)
}

@Test func shipFilesRejectInvalidSyntaxRangesGeometryAndMismatchedIDs() throws {
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: folder) }
  #expect(throws: ShipFileError.self) { try ShipCatalogue.load(from: folder) }
  let file = folder.appendingPathComponent("SH023.toml")
  let source = try String(
    contentsOf: ShipCatalogue.folder.appendingPathComponent("SH023.toml"), encoding: .utf8)
  try Data("name = [".utf8).write(to: file)
  #expect(throws: (any Error).self) { try ShipCatalogue.load(from: folder) }
  try Data(source.replacingOccurrences(of: "speed = 32.0", with: "speed = -1.0").utf8).write(
    to: file)
  #expect(throws: ShipFileError.self) { try ShipCatalogue.load(from: folder) }
  try Data(
    source.replacingOccurrences(of: "faces = [\n", with: "faces = [\n  [99999, 1, 2],\n").utf8
  ).write(to: file)
  #expect(throws: ShipFileError.self) { try ShipCatalogue.load(from: folder) }
  try Data(source.utf8).write(to: file)
  #expect(try ShipCatalogue.load(from: folder).first?.id == "SH023")
  try FileManager.default.moveItem(at: file, to: folder.appendingPathComponent("SH001.toml"))
  #expect(throws: ShipFileError.self) { try ShipCatalogue.load(from: folder) }
}
