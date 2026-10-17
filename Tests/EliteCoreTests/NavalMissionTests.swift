import Foundation
import Testing

@testable import EliteCore

private func navalGame(galaxy: Int = 0, score: Int = 256, stage: NavalMissionStage = .notStarted)
  -> Game
{
  var game = Game(executive: true)
  game.commander.galaxy = galaxy
  game.systems = Universe.galaxy(number: galaxy)
  game.commander.kills = score
  game.commander.missionStage = stage
  game.screen = .status
  return game
}

private func moveCommander(_ game: inout Game, galaxy: Int, system: Int) {
  game.commander.galaxy = galaxy
  game.systems = Universe.galaxy(number: galaxy)
  game.commander.system = system
  game.selectedSystem = system
}

private func finishMessage(_ game: inout Game) {
  for _ in 0..<21 { game.tick(delta: 0.1) }
  for _ in 0..<20 where game.screen == .mission { game.key("return") }
}

@Test func navalOffersUseOriginalDockingThresholdsAndOnlyOneTransitionPerDock() {
  for galaxy in 0..<8 {
    for score in [255, 256, 1279, 1280] {
      var game = navalGame(galaxy: galaxy, score: score)
      game.dock()
      #expect((game.commander.missionStage == .huntingConstrictor) == (galaxy < 2 && score >= 256))
      if game.screen == .mission {
        #expect(
          game.missionNotice?.text.contains(galaxy == 0 ? "CARRUTHERS" : "FOSDYKE SMYTHE") == true)
      }
      game = navalGame(galaxy: galaxy, score: score, stage: .constrictorComplete)
      game.dock()
      #expect((game.commander.missionStage == .reportToCeerdi) == (galaxy == 2 && score >= 1280))
    }
  }
  var game = navalGame(galaxy: 2, score: 1280, stage: .constrictorComplete)
  moveCommander(&game, galaxy: 2, system: 83)
  #expect(
    game.currentSystem.name == "CEERDI" && game.currentSystem.x == 215 && game.currentSystem.y == 84
  )
  game.dock()
  #expect(game.commander.missionStage == .reportToCeerdi)
  finishMessage(&game)
  game.dock()
  #expect(game.commander.missionStage == .carryingPlans)
}

@Test func constrictorKillDebriefsOnceAtAnyStationWithOriginalBonus() {
  var game = navalGame(galaxy: 1)
  game.dock()
  finishMessage(&game)
  game.commander.equipment.insert("Military Laser")
  game.launch()
  game.speed = 0
  #expect(game.commander.laser(on: .front) == .military)
  #expect(game.commander.fittedEquipment(at: .laser(.front)) != nil)
  var target = SpaceBody(id: 99, hull: .constrictor, position: .init(0, 0, 500), hostile: true)
  target.navalTarget = true
  target.energy = 5
  game.bodies = [target]
  var controls = Controls()
  controls.fire = true
  game.tick(delta: 0.1, controls: controls)
  #expect(game.commander.missionStage == .constrictorDestroyed)
  #expect(game.commander.kills == 257 && game.commander.credits == 1000)
  moveCommander(&game, galaxy: 7, system: 7)
  game.dock()
  #expect(game.commander.missionStage == .constrictorComplete)
  #expect(game.commander.kills == 513 && game.commander.credits == 51000)
  #expect(game.missionNotice?.message == .constrictorDebriefing)
  finishMessage(&game)
  game.dock()
  #expect(game.commander.kills == 513 && game.commander.credits == 51000)
}

@Test func constrictorRemovalKeepsTheExecutiveFarofQuirkAndRejectsLookalikes() {
  var game = navalGame(stage: .huntingConstrictor)
  var target = SpaceBody(id: 10, hull: .cobra, position: .init(0, 0, 60000))
  target.navalTarget = true
  game.missionTargetRemoved(target)
  #expect(game.commander.missionStage == .huntingConstrictor)
  target.hull = .constrictor
  target.navalTarget = false
  game.missionTargetRemoved(target)
  #expect(game.commander.missionStage == .huntingConstrictor)
  target.navalTarget = true
  target.position = .init(40000, 40000, 40000)
  #expect(!target.leavesLocalBubble)
  target.position = .init(57599, 0, 0)
  #expect(!target.leavesLocalBubble)
  target.position.x = 57600
  #expect(target.leavesLocalBubble)
  game.launch()
  game.speed = 0
  game.bodies = [target]
  game.tick(delta: 0.1)
  #expect(game.commander.missionStage == .constrictorDestroyed && game.commander.kills == 256)
  game.dock()
  #expect(game.commander.kills == 512 && game.commander.credits == 51000)
}

@Test func plansMustBeCollectedBeforeDeliveryAndRewardReplacesStandardUnit() {
  var game = navalGame(galaxy: 2, score: 1280, stage: .reportToCeerdi)
  game.commander.cargo[0] = 20
  moveCommander(&game, galaxy: 2, system: 36)
  #expect(
    game.currentSystem.name == "BIRERA" && game.currentSystem.x == 63 && game.currentSystem.y == 72)
  game.dock()
  #expect(game.commander.missionStage == .reportToCeerdi)
  moveCommander(&game, galaxy: 2, system: 83)
  game.dock()
  #expect(game.commander.missionStage == .carryingPlans && game.commander.cargoTonnes == 20)
  #expect(game.missionNotice?.message == .plansCollection)
  finishMessage(&game)
  moveCommander(&game, galaxy: 1, system: 36)
  game.dock()
  #expect(game.commander.missionStage == .carryingPlans)
  moveCommander(&game, galaxy: 2, system: 36)
  game.commander.equipment.insert("Extra Energy Unit")
  game.dock()
  #expect(game.commander.missionStage == .plansDelivered && game.commander.kills == 1536)
  #expect(game.commander.credits == 1000 && game.commander.cargoTonnes == 20)
  #expect(game.commander.equipment.contains(Equipment.navalEnergyUnit))
  #expect(!game.commander.equipment.contains("Extra Energy Unit") && game.commander.valid)
  finishMessage(&game)
  game.dock()
  #expect(game.commander.kills == 1536 && game.commander.credits == 1000)
}

@Test func missionRewardsKeepOriginalRegisterWrappingAndEnergyRatios() {
  var game = navalGame(score: 65535, stage: .constrictorDestroyed)
  game.commander.credits = 4_294_967_295
  game.dock()
  #expect(game.commander.kills == 255 && game.commander.credits == 49999)
  var invalid = Commander()
  invalid.kills = 65536
  #expect(!invalid.valid)
  var commander = Commander()
  #expect(commander.energyRechargeMultiplier == 1)
  commander.equipment.insert("Extra Energy Unit")
  #expect(commander.energyRechargeMultiplier == 2)
  commander.equipment.insert(Equipment.navalEnergyUnit)
  #expect(commander.energyRechargeMultiplier == 3)
  #expect(Equipment.isReward(Equipment.navalEnergyUnit))
}

@Test func missionFlagsSurviveOldAndNewCommanderSavesAndCannotPayTwice() async throws {
  let legacy = try JSONEncoder().encode(Commander())
  #expect(try JSONDecoder().decode(Commander.self, from: legacy).missionStage == .notStarted)
  var invalid = try #require(JSONSerialization.jsonObject(with: legacy) as? [String: Any])
  invalid["navalMission"] = 4
  #expect(throws: DecodingError.self) {
    try JSONDecoder().decode(Commander.self, from: JSONSerialization.data(withJSONObject: invalid))
  }
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  for stage in NavalMissionStage.allCases {
    let game = navalGame(galaxy: 2, score: 1536, stage: stage)
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: url)
    let restored = GameRuntime()
    try await restored.load(from: url)
    #expect(await restored.snapshot().commander.missionStage == stage)
  }
  var complete = navalGame(galaxy: 2, score: 1536, stage: .plansDelivered)
  complete.commander.system = 36
  let runtime = GameRuntime(game: complete)
  try await runtime.save(to: url)
  let restored = GameRuntime()
  try await restored.load(from: url)
  var loaded = await restored.snapshot()
  loaded.dock()
  #expect(loaded.commander.kills == 1536 && loaded.commander.credits == 1000)
}

@Test func constrictorTrailUsesOriginalSystemsAndDoesNotRequireClueVisits() {
  let expected: [(Int, Int, String)] = [
    (0, 150, "REESDICE"), (0, 36, "AREXE"), (0, 28, "GALACTIC HYPERDRIVE"),
    (1, 253, "INBIBE"), (1, 79, "AUSAR"), (1, 53, "USLERI"), (1, 118, "ORARRA"),
    (1, 193, "PIRATE"), (2, 101, "WRONG GALAXY"),
  ]
  for (galaxy, system, text) in expected {
    #expect(
      MissionRules.clue(stage: .huntingConstrictor, galaxy: galaxy, system: system, variation: 0)?
        .contains(text) == true)
    #expect(
      MissionRules.clue(stage: .constrictorComplete, galaxy: galaxy, system: system, variation: 0)
        == nil)
  }
  for id in [32, 68, 164, 220, 106, 16, 162, 3, 107, 26, 192, 184, 5] {
    for variation in 0..<5 {
      #expect(
        MissionRules.clue(stage: .huntingConstrictor, galaxy: 1, system: id, variation: variation)?
          .contains("ERRIUS") == true)
    }
  }
  #expect(MissionRules.clue(stage: .huntingConstrictor, galaxy: 7, system: 7, variation: 0) == nil)
  #expect(MissionRules.clue(stage: .huntingConstrictor, galaxy: 1, system: 7, variation: 0) == nil)
  var game = navalGame(galaxy: 1, stage: .huntingConstrictor)
  game.selectedSystem = 118
  game.key("5")
  #expect(Display.systemRows(game).contains { $0.0.contains("ORARRA") })
  #expect(!Display.render(game).pixels.isEmpty)
}

@Test func missionEncounterPredicatesMatchOriginalByteBoundariesAndSingleTarget() {
  #expect((0..<256).filter { MissionRules.plansAmbush(randomByte: $0) }.count == 56)
  #expect(MissionRules.bountyHunterCheck(government: 0, roll: 255, hunterRoll: 99))
  #expect(!MissionRules.bountyHunterCheck(government: 0, roll: 255, hunterRoll: 100))
  #expect(!MissionRules.bountyHunterCheck(government: 3, roll: 90, hunterRoll: 0))
  #expect(!MissionRules.bountyHunterCheck(government: 3, roll: 2, hunterRoll: 0))
  #expect(MissionRules.bountyHunterCheck(government: 3, roll: 3, hunterRoll: 0))
  var game = navalGame(galaxy: 1, stage: .huntingConstrictor)
  moveCommander(&game, galaxy: 1, system: 193)
  #expect(
    game.currentSystem.name == "ORARRA" && game.currentSystem.x == 144 && game.currentSystem.y == 33
  )
  for _ in 0..<128 { game.spawnNavalEncounter() }
  let target = game.bodies.filter { $0.hull == .constrictor }
  #expect(target.count == 1 && target.first?.navalTarget == true && target.first?.energy == 252)
  game.bodies = []
  moveCommander(&game, galaxy: 0, system: 193)
  for _ in 0..<128 { game.spawnNavalEncounter() }
  #expect(game.bodies.isEmpty)
  game = navalGame(stage: .carryingPlans)
  for _ in 0..<128 { game.spawnNavalEncounter() }
  #expect(game.bodies.count == 18)
  #expect(game.bodies.filter { $0.hull == .thargoid }.count == 9)
  #expect(game.bodies.filter { $0.hull == .thargon }.count == 9)
  game.bodies = [SpaceBody(id: 0, hull: .viper, position: .init(0, 0, 1000))]
  game.spawnNavalEncounter()
  #expect(game.bodies.count == 1)
}

@Test func constrictorResistsWeakLasersAndBombButNearMissileCanBeatECM() {
  var commander = Commander()
  #expect(commander.laserDamage(against: .constrictor) == 0)
  commander.equipment.insert("Beam Laser")
  commander.equipment.insert("Mining Laser")
  #expect(commander.laserDamage(against: .constrictor) == 0)
  #expect(commander.laserDamage(against: .cobra) == 15)
  commander.equipment.insert("Military Laser")
  #expect(commander.laserDamage(against: .constrictor) == 5)
  #expect(commander.laserDamage(against: .cobra) == 23)
  var game = navalGame(stage: .huntingConstrictor)
  game.launch()
  game.speed = 0
  var target = SpaceBody(id: 99, hull: .constrictor, position: .init(0, 0, 100), hostile: true)
  target.navalTarget = true
  game.bodies = [target]
  game.commander.equipment.insert("Energy Bomb")
  game.energyBomb()
  #expect(game.bodies[0].energy == 252)
  game.missileArmed = true
  game.fireMissile()
  #expect(game.commander.missiles == 2 && game.bodies[0].energy == 252)
  game.tick(delta: 0.1)
  #expect(game.commander.missionStage == .constrictorDestroyed)
}

@Test func navalOrdnanceIsFiniteAndThargonsLoseTheirMothership() {
  var game = navalGame(stage: .huntingConstrictor)
  game.bodies = [SpaceBody(id: 99, hull: .constrictor, position: .init(0, 0, 6000), hostile: true)]
  var fired = 0
  for _ in 0..<512 {
    game.bodies[0].energy = 100
    game.navalTactics()
    fired += game.bodies.filter(\.enemyMissile).count
    game.bodies.removeAll(where: \.enemyMissile)
  }
  #expect(fired == 4 && game.bodies[0].missiles == 0)
  game = navalGame(stage: .carryingPlans)
  game.bodies = [SpaceBody(id: 99, hull: .thargoid, position: .init(0, 0, 6000), hostile: true)]
  for _ in 0..<512 {
    game.bodies[0].energy = 80
    game.navalTactics()
  }
  #expect(game.bodies[0].missiles == 0 && game.bodies.filter { $0.hull == .thargon }.count == 6)
  game.docked = false
  game.bodies[0].energy = 0
  game.tick(delta: 0.1)
  #expect(game.bodies.allSatisfy { $0.hull == .thargon && !$0.hostile })
}

@Test func navalMessagesPageSafelyAndPauseWorksWithoutEndKey() {
  var game = navalGame()
  game.commander.shipDisplayStyle = .whiteWireframe
  game.dock()
  #expect(game.screen == .mission)
  game.key("return")
  #expect(game.screen == .mission && game.missionPage == 0)
  for _ in 0..<21 { game.tick(delta: 0.1) }
  let first = Display.render(game, rasterizeGraphics: false)
  #expect(!first.shipLines.isEmpty)
  let notice = game.missionNotice
  #expect(notice?.pages.flatMap { $0 }.allSatisfy { $0.count <= 40 } == true)
  game.key("k")
  #expect(PlayerHelp.pages(for: game)[0].title == "MISSION MESSAGE")
  game.key("k")
  #expect(game.screen == .mission && game.missionNotice == notice)
  game.key("pause")
  let time = game.time
  game.tick(delta: 0.1)
  #expect(game.paused && game.time == time)
  game.key("pause")
  #expect(!game.paused)
  game.key("right")
  game.key("left")
  #expect(game.missionPage == 0)
  game.key("0")
  #expect(game.screen == .mission && game.docked)
  finishMessage(&game)
  #expect(game.screen == .status)
  for message in [
    MissionMessage.ceerdiOrders, .plansCollection, .plansDebriefing, .constrictorDebriefing,
  ] {
    game.missionNotice = MissionNotice(message: message, commander: "JAMESON", galaxy: 2)
    game.screen = .mission
    for page in 0..<game.missionNotice!.pages.count {
      game.missionPage = page
      #expect(!Display.render(game).pixels.isEmpty)
    }
  }
}

@Test func navalMissileECMImpactAndEnergyUpgradePaths() throws {
  var game = navalGame(stage: .huntingConstrictor)
  game.docked = false
  game.bodies = [SpaceBody(id: 99, hull: .constrictor, position: .init(0, 0, 6000), hostile: true)]
  game.missileArmed = true
  game.fireMissile()
  for _ in 0..<256 {
    game.commander.flightSimulation.advancePhysicalTime(0.001)
    game.advanceNavalMissiles(delta: 0.001)
  }
  #expect(game.bodies[0].energy == 252 && game.ecmFrames == 32)
  #expect(game.bodies.last?.energy == 0)
  game.ecmFrames = 0
  game.bodies[0].energy = 0
  game.bodies[1].energy = 100
  game.advanceNavalMissiles(delta: 0.1)
  #expect(game.bodies[1].energy == 0)
  var missile = SpaceBody(id: 100, hull: .missile, position: .init(0, 0, 500))
  missile.enemyMissile = true
  game.bodies = [missile]
  game.advanceNavalMissiles(delta: 0.1)
  #expect(game.bodies[0].position.z < 500)
  game.bodies[0].position = .init(0, 0, 30)
  game.frontShield = 100
  game.advanceNavalMissiles(delta: 0.1)
  #expect(game.frontShield == 0 && game.energy == 106)
  game.bodies[0] = missile
  game.bodies[0].position = .init(0, 0, -30)
  game.rearShield = 200
  game.advanceNavalMissiles(delta: 0.1)
  #expect(game.rearShield == 0 && game.energy == 56)
  let upgrades: [(Set<String>, Double)] = [
    ([], 0.2), (["Extra Energy Unit"], 0.4), ([Equipment.navalEnergyUnit], 0.6),
  ]
  for (equipment, recharge) in upgrades {
    game = navalGame(score: 0)
    game.commander.equipment = equipment
    game.launch()
    game.bodies = []
    game.energy = 100
    let expectedEnergy = equipment.first ?? "Basic Energy System"
    #expect(game.commander.fittedEquipment(at: .energy)?.node.key == expectedEnergy)
    game.tick(delta: 0.1)
    #expect(abs(game.energy - 100 - recharge) < 1e-9)
  }
  game.dock()
  game.selection = try #require(Equipment.all.firstIndex { $0.name == "Extra Energy Unit" })
  let item = Equipment.all[game.selection]
  game.commander.system = try #require(game.systems.first { $0.technology >= item.technology }?.id)
  try game.commander.prepareEquipment()
  let naval = try #require(game.commander.fittedEquipment(at: .energy))
  let cost = game.shopPrice(item)
  game.commander.credits = cost + 1000
  let cash = game.commander.credits
  game.purchase()
  // Paid predecessors can be held while the stronger migrated reward stays fitted.
  #expect(game.commander.credits == cash - cost && game.commander.energyRechargeMultiplier == 3)
  #expect(game.commander.fittedEquipment(at: .energy)?.id == naval.id)
  let node = try #require(EquipmentRuntimeCatalog.node(for: item.name))
  #expect(
    game.commander.equipmentInventory?.items.contains { $0.node == node && $0.location == nil }
      == true)
  #expect(game.commander.equipmentPurchaseHistory?.paid.count == 1)
  game.screen = .equipment
  _ = Display.render(game)
}
