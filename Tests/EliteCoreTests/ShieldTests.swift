import Foundation
import Testing

@testable import EliteCore

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
    var game = Game(executive: false)
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
  game.selection = Equipment.all.firstIndex { $0.name == ShieldBooster.military.equipmentName }!
  game.purchase()
  #expect(game.commander.shieldBooster == nil)
  game.commander.system = try #require(game.systems.firstIndex { $0.technology >= 10 })
  game.purchase()
  #expect(game.commander.shieldBooster == .military && game.commander.credits == 55_000)
  #expect(game.frontShield == game.commander.shieldCapacity)
  game.selection = Equipment.all.firstIndex { $0.name == ShieldBooster.pulse.equipmentName }!
  game.purchase()
  #expect(game.commander.credits == 55_000 && game.commander.shieldBooster == .military)
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
    cheat.commander.kills == 0 && cheat.commander.shieldBooster == .capital
      && !cheat.commander.capitalRewardClaimed)
}
@Test func xyzzyNavalLasersAndCapitalShieldsAreEffectiveAcrossEverySupportedView() {
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
      abs(game.commander.shieldCapacity - 1759.5) < 1e-8 && game.frontShield > 1700
        && game.rearShield > 1700)
  }
}
@Test func equipmentRowsUseSmallFontWithRightAlignedCreditPricesAndVisibleSelection() {
  var game = Game(executive: false)
  game.screen = .equipment
  for width in [512.0, 768, 1512] {
    for index in [0, Equipment.all.count - 1] {
      game.selection = index
      let frame = Display.equipmentScreen(game, width: width, height: 768)
      #expect(frame.labels.contains { $0.text == Equipment.all[index].name })
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

@Test func damageRatiosKeepMiningStrongerThanMilitaryAndPurchasesCannotSilentlyWeakenIt() throws {
  var game = Game(executive: false)
  game.commander.system = try #require(game.systems.firstIndex { $0.technology >= 10 })
  game.commander.credits = 100_000
  game.commander.installShieldBooster(.mining)
  game.dock()
  game.selection = Equipment.all.firstIndex { $0.name == ShieldBooster.military.equipmentName }!
  game.purchase()
  #expect(game.message == "WOULD REDUCE SHIELD CAPACITY" && game.commander.credits == 100_000)
  #expect(game.commander.shieldBooster == .mining && game.commander.shieldCapacity == 1275)
  game.commander.equipment.insert(ShieldBooster.military.equipmentName)
  #expect(game.commander.shieldBooster == .mining)
  game.commander.installShieldBooster(.capital)
  #expect(
    game.commander.shieldBooster == .capital && abs(game.commander.shieldCapacity - 1759.5) < 1e-8)
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

@Test func capitalBoosterAppearsInTheFullOrderedEquipmentListWithoutBecomingPurchasable() {
  var game = Game(executive: false)
  game.screen = .equipment
  #expect(Equipment.all.suffix(5).map(\.name) == ShieldBooster.allCases.map(\.equipmentName))
  game.selection = Equipment.all.count - 1
  let cash = game.commander.credits
  game.purchase()
  #expect(game.commander.shieldBooster == nil && game.commander.credits == cash)
  for width in [512.0, 1512] {
    let frame = Display.equipmentScreen(game, width: width, height: 518)
    #expect(frame.labels.contains { $0.text == ShieldBooster.capital.equipmentName })
    #expect(frame.labels.contains { $0.text == "ELITE REWARD" })
  }
  game.commander.installShieldBooster(.capital)
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
