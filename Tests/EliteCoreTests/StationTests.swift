import Foundation
import Testing

@testable import EliteCore

@Test func fourMountsStartWithOnlyFrontPulseAndPurchasesReplaceOnlyChosenMount() throws {
  var game = Game(executive: false)
  #expect(game.commander.laser(on: .front) == .pulse)
  #expect([LaserMount.left, .right, .rear].allSatisfy { game.commander.laser(on: $0) == nil })
  game.screen = .equipment
  game.commander.system = try #require(game.systems.first { $0.technology >= 10 }?.id)
  game.commander.credits = 100_000
  game.selection = try #require(Equipment.all.firstIndex { $0.name == "Beam Laser" })
  game.key("right")
  #expect(game.equipmentMount == .left)
  game.key("return")
  #expect(game.commander.laser(on: .left) == .beam && game.commander.laser(on: .front) == .pulse)
  #expect(game.commander.credits == 90_000 && game.message == "EQUIPMENT FITTED")
  let fitted = game.commander
  game.key("return")
  #expect(game.commander == fitted && game.message == "ALREADY OWNED")
  game.selection = try #require(Equipment.all.firstIndex { $0.name == "Mining Laser" })
  game.key("return")
  #expect(game.commander.laser(on: .left) == .mining && game.commander.credits == 82_000)
  #expect(game.commander.laser(on: .right) == nil && game.commander.laser(on: .rear) == nil)
  game.key("left")
  #expect(game.equipmentMount == .front)
  let layout = EquipmentLayout(game: game, width: game.viewportWidth, height: game.viewportHeight)
  game.equipmentClick(y: 40, x: layout.left + layout.contentWidth * 0.9)
  #expect(game.equipmentMount == .rear)
  game.commander.credits = 0
  let poor = game.commander
  game.key("return")
  #expect(game.commander.laser(on: .rear) == nil && game.message == "NOT ENOUGH CASH")
  #expect(game.commander == poor)
}
@Test func laserMountDamageRateAndEmptyViewsUseTheirOwnAuthoritativeEquipment() {
  let kinds: [LaserKind?] = [.pulse, .mining, .beam, nil]
  for (index, mount) in LaserMount.allCases.enumerated() {
    var game = Game(executive: false)
    game.commander.laserMounts = LaserMounts(front: .pulse, left: .mining, right: .beam)
    game.launch()
    game.speed = 0
    #expect(game.commander.laser(on: mount) == kinds[index])
    #expect(
      game.commander.fittedEquipment(at: .laser(mount))?.node.key == kinds[index]?.equipmentName)
    game.screen = Screen(rawValue: mount.rawValue)!
    let position: Vector3
    switch mount {
    case .front: position = .init(0, 0, 1000)
    case .left: position = .init(-1000, 0, 0)
    case .right: position = .init(1000, 0, 0)
    case .rear: position = .init(0, 0, -1000)
    }
    game.bodies = [.init(id: 1, hull: .cobra, position: position)]
    var controls = Controls()
    controls.fire = true
    game.tick(delta: 0.01, controls: controls)
    #expect(game.bodies[0].energy == 100 - (kinds[index]?.damage ?? 0))
    game.tick(delta: 0.1, controls: controls)
    let shots = (kinds[index]?.firingInterval ?? 1) <= 0.1 ? 2.0 : 1.0
    #expect(game.bodies[0].energy == 100 - (kinds[index]?.damage ?? 0) * shots)
    #expect((game.laserHeat > 0) == (kinds[index] != nil))
    #expect(
      game.commander.laserDamage(against: .cobra, mount: mount) == (kinds[index]?.damage ?? 0))
  }
}
@Test func explicitAndLegacyMountSavesPreserveSingleFrontLaserWithoutInventingSideWeapons()
  async throws
{
  var legacy = Commander()
  legacy.equipment = ["Pulse Laser", "Military Laser", "Fuel Scoops"]
  let data = try JSONEncoder().encode(legacy)
  let decoded = try JSONDecoder().decode(Commander.self, from: data)
  #expect(decoded.laser(on: .front) == .military && decoded.laser(on: .left) == nil)
  var game = Game(executive: false)
  #expect(game.load(decoded) == true)
  #expect(game.commander.equipment == ["Military Laser", "Fuel Scoops"])
  let migrated = try #require(game.commander.equipmentInventory)
  let oldPulse = try #require(migrated.items.first { $0.node.key == "Pulse Laser" })
  #expect(oldPulse.location == nil && oldPulse.provenance == .legacyUnknown)
  #expect([LaserMount.left, .right, .rear].allSatisfy { game.commander.laser(on: $0) == nil })
  try game.commander.grantEquipment(
    "Beam Laser", at: .laser(.rear), provenance: .grant("mount save fixture"))
  try game.commander.grantEquipment(
    "Mining Laser", at: .laser(.front), provenance: .grant("mount save fixture"))
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: url)
  try await runtime.load(from: url)
  #expect(await runtime.snapshot().commander.laserMounts == game.commander.laserMounts)
  let restored = await runtime.snapshot()
  #expect(restored.commander.equipmentInventory == game.commander.equipmentInventory)
  #expect(restored.commander.equipmentPurchaseHistory == game.commander.equipmentPurchaseHistory)
  #expect(restored.commander.equipmentInventory?.items.contains(oldPulse) == true)
  #expect(game.commander.laser(on: .rear) == .beam && game.commander.laser(on: .front) == .mining)
  #expect(game.commander.laser(on: .right) == nil)
  legacy.xyzzyActive = true
  #expect(game.load(legacy) == true)
  #expect(LaserMount.allCases.allSatisfy { game.commander.laser(on: $0) == .naval })
  var corrupt = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(game.commander)) as? [String: Any])
  corrupt["mountedLasers"] = ["front": "invalid"]
  #expect(throws: DecodingError.self) {
    try JSONDecoder().decode(Commander.self, from: JSONSerialization.data(withJSONObject: corrupt))
  }
}
@Test func statusEquipmentAndInventoryShowAllMountsAndCanBrowseEveryEquipmentRow() throws {
  var game = Game(executive: false)
  game.launch()
  for key in "xyzzy" { game.key(String(key)) }
  game.key("return")
  game.dock()
  #expect(LaserMount.allCases.allSatisfy { game.commander.laser(on: $0) == .naval })
  try game.commander.grantEquipment(
    "Pulse Laser", at: .laser(.left), provenance: .grant("mount display fixture"))
  for mount in LaserMount.allCases {
    #expect(game.commander.fittedEquipment(at: .laser(mount)) != nil)
  }
  for screen in [Screen.status, .inventory] {
    game.screen = screen
    let initialRows = game.informationRows.map(\.0)
    #expect(initialRows.contains("Equipment - fitted and held") == (screen == .inventory))
    for mount in LaserMount.allCases {
      #expect(
        initialRows.contains { $0.hasPrefix("Fitted " + mount.label + " combat mount - ") }
          == (screen == .inventory))
    }
    for width in [512.0, 768, 3600] {
      game.viewportWidth = width
      game.viewportHeight = 518
      game.informationScroll = 0
      let rows = game.informationRows.map(\.0)
      var seen: Set<String> = []
      for _ in 0..<rows.count {
        let frame = Display.information(game, width: width, height: 518)
        seen.formUnion(frame.labels.map(\.text))
        for label in frame.labels {
          #expect(label.bounds.maxX <= width && label.bounds.maxY <= 518)
        }
        game.key("down")
      }
      #expect(rows.allSatisfy { seen.contains($0) })
      game.informationScroll = 0
      game.key("pagedown")
      #expect(game.informationScroll == min(8, game.informationWindow.last))
      game.key("pageup")
      #expect(game.informationScroll == 0)
    }
  }
  game.screen = .equipment
  for width in [512.0, 768, 3600] {
    let layout = EquipmentLayout(game: game, width: width, height: 518)
    #expect(layout.contentWidth <= 680)
    let frame = Display.equipmentScreen(game, width: width, height: 518)
    #expect(
      LaserMount.allCases.allSatisfy { mount in frame.labels.contains { $0.text == mount.label } })
    #expect(frame.labels.contains { $0.text == "Pulse Laser" })
    for label in frame.labels { #expect(label.bounds.maxX <= width) }
  }
}
@Test func marketColoursAreConsistentAndAvailabilityIsIndependentFromCategory() {
  var game = Game(executive: false)
  for screen in [Screen.buy, .sell, .market] {
    game.screen = screen
    game.commander.cargo = Array(repeating: 1, count: 17)
    game.commander.credits = 100_000
    for index in Commodity.all.indices {
      game.selection = index
      for width in [512.0, 768, 3600] {
        let frame = Display.marketScreen(game, width: width, height: 518)
        #expect(
          frame.labels.contains {
            $0.text == Commodity.all[index].name && $0.ink == CommodityCategory.at(index).ink
          })
        #expect(
          CommodityCategory.allCases.allSatisfy { category in
            frame.labels.contains { $0.text == category.rawValue }
          })
        for label in frame.labels {
          #expect(label.bounds.x >= 0 && label.bounds.maxX <= width && label.bounds.maxY <= 518)
        }
      }
    }
  }
  game.screen = .buy
  game.market[0] = .init(price: 10, quantity: 0)
  #expect(game.marketAvailability(0) == "NO STOCK")
  game.market[0].quantity = 1
  game.commander.credits = 0
  #expect(game.marketAvailability(0) == "NO CASH")
  game.commander.credits = 10
  game.commander.cargo[0] = 20
  #expect(game.marketAvailability(0) == "HOLD FULL")
  game.commander.unlimitedCargo = true
  #expect(game.marketAvailability(0) == "BUY")
  game.screen = .sell
  game.commander.cargo[0] = 0
  #expect(game.marketAvailability(0) == "NONE HELD")
  game.docked = false
  #expect(game.marketAvailability(0) == "DOCK TO TRADE")
  #expect([3, 6, 10].allSatisfy { CommodityCategory.at($0) == .restricted })
}
@Test func startupShadingOverridesPresentationWithoutChangingFlightPreferences() {
  var game = Game(executive: false)
  for screen in [Screen.demo, .title] {
    game.screen = screen
    for style in ShipDisplayStyle.allCases {
      game.commander.shipDisplayStyle = style
      let frame = Display.render(game, rasterizeGraphics: false)
      #expect(!frame.shipPanels.isEmpty && frame.shipLines.isEmpty)
      #expect(game.commander.shipDisplayStyle == style)
    }
  }
}
