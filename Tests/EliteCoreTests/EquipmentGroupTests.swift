import Foundation
import Testing

@testable import EliteCore

@Test func groupedEquipmentIncludesEveryItemOnceAndSelectionSkipsHeadings() throws {
  let order = EquipmentGroups.itemIndices
  #expect(order.count == Equipment.all.count && Set(order).count == order.count)
  #expect(!Equipment.all.contains { $0.name == Equipment.legacyDockingComputer })
  var game = Game(executive: false)
  game.screen = .equipment
  game.selection = order[0]
  for index in order {
    #expect(game.selection == index)
    for width in [512.0, 768, 1512] {
      game.viewportWidth = width
      game.viewportHeight = 518
      let layout = EquipmentLayout(game: game, width: width, height: 518)
      let frame = Display.equipmentScreen(game, width: width, height: 518)
      #expect(
        frame.labels.contains { $0.text == Equipment.all[index].name },
        "Item \(index) width \(width), selected \(game.selection), start \(layout.start), count \(layout.count)"
      )
      let selected = try #require(frame.labels.first { $0.text == ">" })
      #expect(selected.x == layout.left + 14)
      for label in frame.labels {
        #expect(label.bounds.x >= 0 && label.bounds.maxX <= width && label.bounds.maxY <= 518)
      }
      game.equipmentClick(y: selected.y)
      #expect(game.selection == index)
      if case .heading = EquipmentGroups.rows[layout.start] {
        game.equipmentClick(y: layout.listTop)
        #expect(game.selection == index)
      }
    }
    game.key("down")
  }
  #expect(game.selection == order.last)
  game.key("equipment-scroll:-1")
  #expect(game.selection == order[order.count - 2])
  game.key("up")
  #expect(game.selection == order[order.count - 3])
  game.equipmentClick(y: -1)
  game.equipmentClick(y: 10000)
  #expect(game.selection == order[order.count - 3])
}

@Test func groupedPurchasesUseItemIdentityAndRewardRowsCannotBeBought() throws {
  var game = Game(executive: false)
  game.screen = .equipment
  game.commander.credits = 1_000_000
  game.commander.system = try #require(game.systems.first { $0.technology >= 10 }?.id)
  game.selection = try #require(Equipment.all.firstIndex { $0.name == "Mining Laser" })
  game.key("return")
  #expect(game.commander.equipment.contains("Mining Laser") && game.commander.credits == 992_000)
  for name in [
    Equipment.navalLaser, Equipment.navalEnergyUnit, ShieldBooster.capital.equipmentName,
  ] {
    game.selection = try #require(Equipment.all.firstIndex { $0.name == name })
    game.key("return")
    #expect(!game.commander.equipment.contains(name) && game.commander.credits == 992_000)
    #expect(game.message.hasSuffix("NOT FOR SALE"))
  }
}

@Test func legacyDockingMigratesToTargetingWithoutDowngradingOrDuplicating() {
  for tier in TargetingTier.allCases {
    var saved = Commander()
    saved.equipment.insert(Equipment.legacyDockingComputer)
    saved.equipment.insert(tier.equipmentName)
    var game = Game(executive: false)
    #expect(game.load(saved) == true)
    #expect(game.commander.targetingTier == max(tier, .docking))
    #expect(!game.commander.equipment.contains(Equipment.legacyDockingComputer))
    game.launch()
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 1500))]
    game.key("r")
    #expect(game.dockingComputer)
  }
  for tier in [TargetingTier.basic, .advanced] {
    var game = Game(executive: false)
    game.commander.installTargetingComputer(tier)
    game.launch()
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 1500))]
    game.key("r")
    #expect(!game.dockingComputer)
  }
}

@Test func xyzzyCashStartsOnceAccountsNormallyAndMigratesOnlyLegacyXYZzy() throws {
  var game = Game(executive: false)
  game.launch()
  for key in "xyzzy" { game.key(String(key)) }
  #expect(
    game.commander.credits == 10_000_000 && !game.commander.unlimitedCash
      && game.commander.xyzzyCashGranted)
  game.commander.credits = 1234
  game.key("9")
  game.key("5")
  game.key("return")
  for key in "xyzzy" { game.key(String(key)) }
  #expect(
    game.commander.credits == 1234 && !game.commander.unlimitedCash
      && !game.commander.unlimitedJumps)
  game.key("return")
  var restored = Game(executive: false)
  #expect(restored.load(game.commander) == true)
  #expect(restored.commander.credits == 1234)
  var old = Commander()
  old.name = "CLARKE"
  old.unlimitedCash = true
  old.unlimitedCargo = true
  old.unlimitedJumps = true
  #expect(restored.load(old) == true)
  #expect(
    restored.commander.credits == 10_000_000 && !restored.commander.unlimitedCash
      && !restored.commander.unlimitedJumps)
  restored.commander.credits = 25
  #expect(restored.load(restored.commander) == true)
  #expect(restored.commander.credits == 25)
  old.unlimitedCash = false
  old.credits = 456
  #expect(restored.load(old) == true)
  #expect(restored.commander.credits == 456)
  old.name = "JAMESON"
  old.unlimitedCash = true
  old.credits = 789
  #expect(
    restored.load(old) && restored.commander.credits == 789 && restored.commander.unlimitedCash)
  var data = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(game.commander)) as? [String: Any])
  data.removeValue(forKey: "finiteXYZzyCash")
  data["unlimitedCash"] = false
  let finiteLegacy = try JSONDecoder().decode(
    Commander.self, from: JSONSerialization.data(withJSONObject: data))
  #expect(restored.load(finiteLegacy) == true)
  #expect(restored.commander.credits == 1234)
}

@Test func rEngagesFullStationDockingWhenXYZzyAssistanceIsOffAndCIsRemoved() {
  var game = Game(executive: false)
  game.launch()
  game.key("r")
  #expect(game.message == "FIT A TARGETING COMPUTER" && !game.dockingComputer)
  game.commander.installTargetingComputer(.military)
  game.commander.xyzzyActive = true
  game.commander.autoTarget = false
  game.bodies = []
  game.key("r")
  #expect(game.message == "NO ELIGIBLE TARGETS")
  game.bodies = [.init(id: 0, hull: .station, position: .init(300, 0, 1500))]
  game.screen = .rear
  game.key("c")
  #expect(!game.dockingComputer && game.autoPilot.targetID == nil)
  game.key("r")
  #expect(game.screen == .front && game.dockingComputer && game.autoPilot.targetID == 0)
  #expect(game.message == "AUTO DOCKING ENGAGED")
  game.tick(delta: 0.1)
  #expect(game.autoPilot.velocity.length > 0 && game.dockingComputer)
  #expect(game.autoHUDLines.contains { $0.contains("AUTO:") })
  game.key("p")
  #expect(!game.dockingComputer && game.autoPilot.targetID == nil)
  game.key("r")
  game.key("q")
  #expect(!game.dockingComputer && game.autoPilot.targetID == nil)
  game.key("r")
  game.key("5")
  #expect(!game.dockingComputer && game.autoPilot.targetID == nil)
  game.key("0")
  game.key("r")
  for _ in 0..<2500 where !game.docked { game.tick(delta: 0.1) }
  #expect(game.docked && !game.dockingComputer && game.screen == .status)
}
