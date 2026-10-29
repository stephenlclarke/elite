import Foundation
import Testing

@testable import EliteCore

private func shieldCobraGame() -> Game {
  var game = Game(executive: false)
  game.commander.shipID = "SH023"
  game.commander.fuel = game.commander.fuelCapacity
  game.energy = game.commander.performance.energy
  game.frontShield = game.commander.shieldCapacity
  game.rearShield = game.commander.rearShieldCapacity
  return game
}

@Test func shieldBoosterPricesTechAndMultipliersFollowTheSpecifiedLaserProgression() {
  let multipliers = [1.5, 5, 1.5, 2.3, 6.9]
  for (index, booster) in ShieldBooster.allCases.enumerated() {
    #expect(abs(booster.multiplier - multipliers[index]) < 1e-10)
    if let shop = booster.shopItem {
      let laser = Equipment.base.first { $0.name == booster.label + " Laser" }!
      #expect(shop.price == laser.price * 3 / 4 && shop.technology == laser.technology)
    } else {
      #expect(booster == .capital)
    }
  }
  #expect(
    Equipment.isReward(Equipment.navalLaser))
}
@Test func boostersIncreaseBothShieldCapacitiesWithoutStackingOrChangingRecharge() {
  for booster in ShieldBooster.allCases {
    var game = shieldCobraGame()
    game.commander.installShieldBooster(booster)
    game.dock()
    let capacity = 255 * booster.multiplier
    #expect(game.frontShield == capacity && game.rearShield == capacity)
    game.applyDamage(300, front: true)
    game.applyDamage(300, front: false)
    #expect(
      game.energy == 256 && game.frontShield == capacity - 300 && game.rearShield == capacity - 300)
    game.commander.installShieldBooster(.pulse)
    #expect(game.commander.shieldBooster == booster)
    #expect(game.commander.equipment.filter { ShieldBooster.from($0) != nil }.count == 1)
    game.launch()
    game.speed = 0
    game.bodies = []
    game.tick(delta: 0.1)
    #expect(abs(game.frontShield - (capacity - 299.9)) < 1e-8)
  }
}
@Test func buyingBoosterRespectsTechnologyCashAndPreventsWeakerTierCharges() throws {
  var game = Game(executive: false)
  game.commander.credits = 100_000
  let militaryItem = try #require(
    Equipment.all.first { $0.name == ShieldBooster.military.equipmentName })
  game.commander.system = try #require(
    game.systems.first { !$0.isPlugh && $0.technology < militaryItem.requiredTechnologyLevel }?.id)
  game.selectedSystem = game.commander.system
  try #require(!game.equipmentAvailable(militaryItem))
  game.selection = Equipment.all.firstIndex { $0.name == ShieldBooster.military.equipmentName }!
  let unavailable = game.commander
  game.purchase()
  #expect(game.commander.shieldBooster == nil)
  #expect(game.commander == unavailable)
  game.commander.system = try #require(
    game.systems.first { !$0.isPlugh && $0.technology >= militaryItem.requiredTechnologyLevel }?.id)
  game.selectedSystem = game.commander.system
  for booster in [ShieldBooster.pulse, .mining, .beam, .military] {
    game.selection = try #require(Equipment.all.firstIndex { $0.name == booster.equipmentName })
    try #require(game.equipmentAvailable(Equipment.all[game.selection]))
    game.purchase()
    #expect(game.commander.equipmentPurchaseHistory?.paid.last?.node.key == booster.equipmentName)
  }
  #expect(game.commander.shieldBooster == .military && game.commander.credits == 38_500)
  #expect(game.commander.equipmentPurchaseHistory?.paid.map(\.price) == [3000, 6000, 7500, 45000])
  #expect(game.frontShield == game.commander.shieldCapacity)
  game.selection = Equipment.all.firstIndex { $0.name == ShieldBooster.pulse.equipmentName }!
  let fitted = game.commander
  game.purchase()
  #expect(game.commander == fitted && game.commander.credits == 38_500)
  #expect(game.commander.shieldBooster == .military && game.commander.valid)
}
@Test func capitalRewardUsesEliteRankAndMigratesExistingSavesOnceWithoutCheatRankClaims()
  async throws
{
  var game = Game(executive: false)
  game.launch()
  game.speed = 0
  game.bodies = []
  game.commander.kills = Commander.eliteThreshold - 1
  game.tick(delta: 0.01)
  #expect(!game.commander.capitalRewardClaimed)
  game.commander.kills += 1
  game.tick(delta: 0.01)
  #expect(game.commander.shieldBooster == .capital && game.commander.capitalRewardClaimed)
  let events = game.ecmControl.events.filter { $0.announcement.text.hasPrefix("ELITE BONUS") }
  #expect(events.count == 1)
  #expect(events.first?.announcement.text == "ELITE BONUS: ADVANCED II SHIELD MODULE")
  game.tick(delta: 0.01)
  #expect(
    game.ecmControl.events.filter { $0.announcement.text.hasPrefix("ELITE BONUS") }.count == 1)
  var old = Commander()
  old.kills = Commander.eliteThreshold
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  try JSONEncoder().encode(old).write(to: url)
  let runtime = GameRuntime()
  try await runtime.load(from: url)
  #expect(await runtime.snapshot().commander.capitalRewardClaimed)
  try await runtime.load(from: url)
  #expect(await runtime.snapshot().ecmControl.events.isEmpty)
  var cheat = Game(executive: false)
  cheat.launch()
  for key in "xyzzy" { cheat.key(String(key)) }
  #expect(
    cheat.commander.kills == 0
      && cheat.commander.fittedEquipment(at: .shield)?.node.key == "Elite Shield Module"
      && cheat.commander.fittedEquipment(at: .shield)?.provenance == .xyzzy
      && !cheat.commander.capitalRewardClaimed)
}
@Test func xyzzyNavalLasersAndEliteShieldsAreEffectiveAcrossEverySupportedView() {
  for screen in [Screen.front, .rear, .left, .right] {
    var game = Game(executive: false)
    game.launch()
    game.speed = 0
    for key in "xyzzy" { game.key(String(key)) }
    game.key("return")
    game.screen = screen
    #expect(
      game.commander.effectiveLaser == Equipment.navalLaser
        && game.commander.laserDamage(against: .cobra) == 64)
    #expect(game.commander.laserDamage(against: .constrictor) == 16)
    #expect(
      game.commander.equipment.contains("Mining Laser")
        && !game.commander.equipment.contains("Military Laser"))
    let position: Vector3
    switch screen {
    case .rear: position = .init(0, 0, -1000)
    case .left: position = .init(-1000, 0, 0)
    case .right: position = .init(1000, 0, 0)
    default: position = .init(0, 0, 1000)
    }
    game.bodies = [.init(id: 1, hull: .cobra, position: position)]
    var controls = Controls()
    controls.fire = true
    game.tick(delta: 0.01, controls: controls)
    #expect(game.bodies[0].energy == 36)
    #expect(
      abs(game.commander.shieldCapacity - 2346) < 1e-8 && game.frontShield > 2300
        && game.rearShield > 2300)
    #expect(game.commander.fittedEquipment(at: .shield)?.node.key == "Elite Shield Module")
    #expect(!game.commander.capitalRewardClaimed && game.commander.kills == 0)
  }
}
@Test func equipmentRowsUseSmallFontWithRightAlignedCreditPricesAndVisibleSelection() {
  var game = Game(executive: false)
  game.screen = .equipment
  let indices =
    [0]
    + ShieldBooster.allCases.compactMap { booster in
      Equipment.all.firstIndex { $0.name == booster.equipmentName }
    }
  #expect(indices.count == 6)
  for width in [512.0, 768, 1512] {
    for index in indices {
      game.selection = index
      let frame = Display.equipmentScreen(game, width: width, height: 768)
      let item = Equipment.all[index]
      let node = EquipmentRuntimeCatalog.node(for: item.name)
      let name =
        EquipmentRuntimeCatalog.graph.nodes.first { $0.id == node }?.displayName ?? item.name
      #expect(frame.labels.contains { $0.text == name })
      let price = frame.labels.filter {
        $0.y >= 42
          && ($0.text.first?.isNumber == true || $0.text == "FITTED" || $0.text.hasSuffix("REWARD")
            || $0.text.hasSuffix("CR"))
      }
      #expect(
        !price.isEmpty
          && price.allSatisfy {
            abs(
              $0.bounds.maxX
                - (EquipmentLayout(game: game, width: width, height: 768).left
                  + EquipmentLayout(game: game, width: width, height: 768).contentWidth)) < 0.01
          })
      for label in frame.labels { #expect(label.bounds.maxX <= width && label.bounds.maxY <= 768) }
    }
  }
}

@Test func legacyMiningStrengthSurvivesPaidWeakerPurchasesStoredWithOriginalIdentity() throws {
  var game = shieldCobraGame()
  let militaryItem = try #require(
    Equipment.all.first { $0.name == ShieldBooster.military.equipmentName })
  game.commander.system = try #require(
    game.systems.first { $0.technology >= militaryItem.requiredTechnologyLevel }?.id)
  game.selectedSystem = game.commander.system
  try #require(game.equipmentAvailable(militaryItem))
  game.commander.credits = 100_000
  game.commander.installShieldBooster(.mining)
  try game.commander.prepareEquipment()
  let original = try #require(game.commander.fittedEquipment(at: .shield))
  #expect(original.component?.statistics[.frontShieldCapacity] == 5)
  for booster in [ShieldBooster.pulse, .mining, .beam] {
    game.selection = try #require(Equipment.all.firstIndex { $0.name == booster.equipmentName })
    game.purchase()
    #expect(game.commander.fittedEquipment(at: .shield)?.id == original.id)
  }
  game.dock()
  game.selection = try #require(
    Equipment.all.firstIndex { $0.name == ShieldBooster.military.equipmentName })
  let cash = game.commander.credits
  game.purchase()
  #expect(game.message == "EQUIPMENT STORED - CURRENT FIT RETAINED")
  #expect(game.commander.credits == cash - 45_000 && game.commander.credits == 38_500)
  #expect(game.commander.fittedEquipment(at: .shield) == original)
  #expect(game.commander.shieldBooster == .mining && game.commander.shieldCapacity == 1275)
  let military = try #require(
    game.commander.equipmentInventory?.items.first {
      $0.node.key == ShieldBooster.military.equipmentName
    })
  let receipt = try #require(game.commander.equipmentPurchaseHistory?.paid.last)
  #expect(military.location == nil && receipt.node == military.node && receipt.price == 45_000)
  #expect(military.provenance == .paid(owner: receipt.owner, transaction: receipt.transaction))
  #expect(game.commander.equipmentPurchaseHistory?.paid.map(\.price) == [3000, 6000, 7500, 45000])
  try game.commander.grantEquipment(
    ShieldBooster.capital.equipmentName, at: .shield, provenance: .grant("shield-test"))
  #expect(game.commander.shieldBooster == .capital)
  #expect(abs(game.commander.shieldCapacity - 1759.5) < 1e-8 && game.commander.valid)
}
@Test func actualLaserResolutionKeepsDamageAndFiringRateFromTheSameSpecification() {
  var commander = Commander()
  commander.equipment = ["Pulse Laser", "Mining Laser", "Beam Laser"]
  #expect(commander.activeLaser == .beam && commander.laserDamage(against: .cobra) == 15)
  #expect(commander.activeLaser?.firingInterval == 0.1)
  commander.equipment = ["Mining Laser"]
  #expect(
    commander.laserDamage(against: .cobra) == 50 && commander.activeLaser?.firingInterval == 0.3)
  commander.equipment.insert(Equipment.navalLaser)
  #expect(commander.activeLaser == .naval && commander.laserDamage(against: .cobra) == 64)
}

@Test func capitalBoosterAppearsInTheFullOrderedEquipmentListWithoutBecomingPurchasable() throws {
  var game = Game(executive: false)
  game.screen = .equipment
  let shieldNames = ShieldBooster.allCases.map(\.equipmentName)
  let shieldIndices = shieldNames.compactMap { name in
    Equipment.all.firstIndex { $0.name == name }
  }
  try #require(shieldIndices.count == shieldNames.count)
  let firstShield = try #require(shieldIndices.first)
  #expect(shieldIndices == Array(firstShield..<(firstShield + shieldNames.count)))
  #expect(shieldIndices.map { Equipment.all[$0].name } == shieldNames)
  game.selection = try #require(
    Equipment.all.firstIndex { $0.name == ShieldBooster.capital.equipmentName })
  let original = game.commander
  let cash = game.commander.credits
  game.purchase()
  #expect(game.commander.shieldBooster == nil && game.commander.credits == cash)
  #expect(game.commander == original)
  for width in [512.0, 1512] {
    let frame = Display.equipmentScreen(game, width: width, height: 518)
    #expect(frame.labels.contains { $0.text == "Advanced II Shield Module" })
    #expect(frame.labels.contains { $0.text == "ELITE REWARD" })
  }
  try game.commander.grantEquipment(
    ShieldBooster.capital.equipmentName, at: .shield, provenance: .grant("shield-display-test"))
  #expect(
    Display.equipmentScreen(game, width: 512, height: 518).labels.contains { $0.text == "FITTED" })
  game.viewportWidth = 512
  game.viewportHeight = 518
  game.key("equipment-scroll:-1")
  #expect(Equipment.all[game.selection].name == ShieldBooster.military.equipmentName)
  let before = game.selection
  game.equipmentClick(y: 42)
  #expect(EquipmentGroups.itemIndices.contains(game.selection))
  #expect(before >= 0)
}
