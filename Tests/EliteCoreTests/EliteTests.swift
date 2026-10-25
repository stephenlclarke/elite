import Foundation
import Testing

@testable import EliteCore

@Test func originalGalaxyFixtures() throws {
  let catalogue = try OriginalWorldCatalogue.loadBundled()
  for index in 0..<8 {
    let systems = Universe.galaxy(number: index)
    #expect(systems.count == 256 && Set(systems.map(\.id)).count == 256)
    for system in systems {
      let world = try catalogue.world(galaxy: index, system: system.id)
      #expect(system.original == world)
      #expect(system.name == world.name && system.x == world.xLY && system.y == world.yLY)
      #expect(
        system.technology == world.technology && system.hostileFraction == world.hostileFraction)
      #expect(system.economyName == world.economy && system.governmentName == world.government)
    }
  }
  let galaxy = Universe.galaxy()
  #expect(galaxy.contains { $0.x < 0 || $0.y < 0 })
  #expect(
    galaxy[7].distance(to: galaxy[129])
      == hypot(galaxy[7].x - galaxy[129].x, galaxy[7].y - galaxy[129].y))
  #expect(!galaxy[7].distance(to: Universe.galaxy(number: 1)[7]).isFinite)
}

@Test func marketFixturesAndBounds() throws {
  let catalogue = try OriginalMarketCatalogue.loadBundled()
  for galaxy in 0..<8 {
    for system in Universe.galaxy(number: galaxy) {
      let seed = try catalogue.initialState(galaxy: galaxy, system: system.id)
      let market = MarketItem.at(system)
      #expect(market.count == 17)
      for quote in seed.quotes {
        #expect(
          market[quote.index]
            == MarketItem(
              price: quote.askTenthsCR, quantity: quote.stock, bidPrice: quote.bidTenthsCR))
        #expect(market[quote.index].bidPrice <= market[quote.index].price)
      }
    }
  }
}

@Test func commanderIntegrityAndRanks() {
  var commander = Commander()
  let hold = commander.nativePerformance.cargo
  let expanded = hold + commander.nativePerformance.cargoExpansion
  #expect(commander.valid && commander.capacity == hold && commander.rank == "Harmless")
  for (kills, rank) in [
    (8, "Mostly Harmless"), (16, "Poor"), (32, "Average"), (64, "Above Average"),
    (128, "Competent"), (512, "Dangerous"), (2560, "Deadly"), (6400, "ELITE"),
  ] {
    commander.kills = kills
    #expect(commander.rank == rank)
  }
  commander.cargo[0] = hold + 1
  #expect(!commander.valid)
  commander.equipment.insert("Large Cargo Bay")
  #expect(commander.valid && commander.capacity == expanded)
  commander.cargo[13] = 1000
  #expect(commander.cargoTonnes == hold + 1)
  commander.system = 256
  #expect(!commander.valid)
  commander = Commander()
  commander.fuel = -1
  #expect(!commander.valid)
  commander = Commander()
  commander.cargo = []
  #expect(!commander.valid)
  commander = Commander()
  commander.name = ""
  #expect(!commander.valid)
  commander = Commander()
  commander.equipment.insert("Invalid")
  #expect(!commander.valid)
}

@Test func keyboardScreensAndSecretMenu() {
  var game = Game(executive: false)
  game.key("z")
  #expect(game.screen == .title)
  game.key(" ")
  #expect(game.screen == .status)
  // Retired docked market aliases do not navigate; zero is tested separately because it launches.
  for (number, expected) in [
    (3, Screen.equipment), (4, .chart), (5, .shortChart),
    (6, .showroom), (7, .buy), (8, .status), (9, .inventory),
  ] {
    game.key("\(number)")
    #expect(game.screen == expected)
  }
  game.key("99")
  #expect(game.screen == .inventory)
  game.key("0")
  #expect(!game.docked && game.screen == .front)
  for (key, screen) in [("1", Screen.rear), ("2", .left), ("3", .right), ("0", .front)] {
    game.key(key)
    #expect(game.screen == screen)
  }
  for key in "xyzzy" { game.key(String(key)) }
  #expect(game.screen == .secret)
  game.key("1")
  #expect(game.commander.hasAutomaticDocking)
  game.key("2")
  #expect(game.commander.equipment.contains(Equipment.navalLaser) && game.commander.fuel == 350)
  game.key("3")
  #expect(!game.commander.unlimitedMissiles)
  game.key("3")
  #expect(game.commander.unlimitedMissiles)
  game.key("ignored")
  game.key("return")
  #expect(game.screen == .front)
  game.screen = .gameOver
  game.key("q")
  #expect(game.screen == .gameOver)
  game.key("return")
  #expect(game.docked && game.commander.credits == 7200)
}

@Test func marketTransactionsRespectCashCapacityAndStock() {
  var game = Game(executive: false)
  game.screen = .buy
  let initial = game.commander
  let initialAsk = game.market[0].price
  let initialBid = game.market[0].bidPrice
  let initialStock = game.market[0].quantity
  game.key("return")
  #expect(game.commander.cargo[0] == 1 && game.commander.credits == initial.credits - initialAsk)
  #expect(game.market[0].quantity == initialStock - 1)
  game.key("left")
  #expect(
    game.commander.cargo[0] == 0
      && game.commander.credits == initial.credits - initialAsk + initialBid)
  game.key("left")
  #expect(game.message == "NO CARGO")
  game.commander.credits = 0
  game.trade(buy: true)
  #expect(game.commander.cargo[0] == 0)
  game.commander.credits = 10000
  let hold = game.commander.tradeCargoCapacity
  game.commander.cargo[1] = hold
  game.trade(buy: true)
  #expect(game.commander.cargo[0] == 0)
  game.selection = 13
  game.trade(buy: true)
  #expect(game.commander.cargo[13] == 1)
  game.selection = 7
  game.trade(buy: true)
  #expect(game.message == "CANNOT BUY")
  game.selection = 99
  game.trade(buy: true)
  game.selection = 0
  game.docked = false
  game.trade(buy: true)
  #expect(game.commander.cargo[0] == 0)
  game.docked = true
  game.screen = .sell
  game.selection = 1
  game.key("return")
  #expect(game.commander.cargo[1] == hold - 1)
  game.key("down")
  #expect(
    game.selection
      == MarketDisplayOrder.commodityIDs[MarketDisplayOrder.commodityIDs.firstIndex(of: 1)! + 1])
  game.key("up")
  #expect(game.selection == 1)
  game.key("right")
  #expect(game.commander.cargo[1] == hold)
}

@Test func equipmentPurchases() throws {
  var game = Game(executive: false)
  // This purchase sequence has a 70-unit tank, four pylons and an explicit 300 CR budget.
  game.commander.shipID = "SH023"
  game.commander.fuel = game.commander.fuelCapacity
  game.energy = game.commander.performance.energy
  game.frontShield = game.commander.shieldCapacity
  game.rearShield = game.commander.rearShieldCapacity
  game.commander.credits = 3000
  let unavailableItem = try #require(Equipment.all.first { $0.name == "Extra Energy Unit" })
  game.commander.system = try #require(
    game.systems.first {
      !$0.isPlugh && $0.technology >= Equipment.base[2].requiredTechnologyLevel
        && $0.technology < unavailableItem.requiredTechnologyLevel
    }?.id)
  game.selectedSystem = game.commander.system
  try #require(!game.equipmentAvailable(unavailableItem))
  game.screen = .equipment
  game.commander.fuel = 60
  game.purchase()
  #expect(game.commander.fuel == 70 && game.commander.credits == 2820)
  game.selection = 1
  game.key("return")
  #expect(game.commander.missiles == 4 && game.commander.credits == 1020)
  game.purchase()
  #expect(game.message == "MISSILE RACK FULL")
  game.selection = try #require(Equipment.all.firstIndex { $0.name == "Extra Energy Unit" })
  let unavailable = game.commander
  game.purchase()
  #expect(game.message == "NOT AVAILABLE" && game.commander == unavailable)
  game.commander.credits = 100000
  game.selection = try #require(Equipment.all.firstIndex { $0.name == "Large Cargo Bay" })
  game.purchase()
  #expect(
    game.commander.capacity == game.commander.nativePerformance.cargo
      + game.commander.nativePerformance.cargoExpansion && game.commander.credits == 72000)
  let owned = game.commander
  game.purchase()
  #expect(game.message == "ALREADY OWNED" && game.commander == owned)
  game.selection = 99
  game.purchase()
  game.docked = false
  game.selection = 3
  game.purchase()
  #expect(!game.commander.equipment.contains("E.C.M. System"))
}

@Test func chartSelectionAndHyperspace() throws {
  var game = Game(executive: false)
  // This controlled unit fixture exercises the stock Cobra, independently of the fresh starter.
  game.commander.shipID = "SH023"
  game.commander.fuel = game.commander.fuelCapacity
  game.energy = game.commander.performance.energy
  game.frontShield = game.commander.shieldCapacity
  game.rearShield = game.commander.rearShieldCapacity
  game.key(" ")
  game.key("4")
  game.key("right")
  #expect(game.viewedSystemID == 8 && game.selectedSystem == 7)
  game.key("left")
  #expect(game.selectedSystem == 7)
  game.selectedSystem = 0
  game.selectNeighbour(direction: -1)
  #expect(game.selectedSystem == 255)
  // Authenticated original-world coordinates, rather than the predecessor chart location.
  game.selectSystem(x: 52.4955, y: 51.0662)
  #expect(game.selectedSystem == 7)
  game.key("d")
  #expect(game.message.contains("DISTANCE"))
  game.key("o")
  #expect(game.selectedSystem == 7)
  game.beginHyperspace()
  #expect(game.jumpCountdown == nil)
  game.launch()
  // Avenor to Renas is 3.364975176728651 LY: the native rounded debit is 34 units.
  // Beliven (129) is 23.533908197534895 LY away and cannot exercise a stock seven-LY drive.
  try #require(abs(game.systems[7].distance(to: game.systems[185]) - 3.364975176728651) < 1e-12)
  game.selectedSystem = 185
  game.beginHyperspace()
  #expect(game.message == "MASS LOCKED")
  game.bodies = []
  game.commander.fuel = 0
  game.beginHyperspace()
  #expect(game.message == "FUEL TOO LOW")
  game.commander.fuel = 70
  game.key("h")
  #expect(
    game.commander.fittedEquipment(at: .drive)?.node == HyperspaceDriveDefinition.node(for: .basic))
  #expect(game.commander.fittedEquipment(at: .drive)?.provenance == .standard)
  #expect(game.commander.fittedComponent(at: .drive)?.statistics[.jumpSpool] == 10)
  #expect(game.commander.hyperspaceDrivePolicy?.activation == .timed(seconds: 10))
  #expect(game.jumpCountdown == 10)
  game.jumpCountdown = 0.01
  game.tick(delta: 0.02)
  #expect(game.commander.system == 185 && game.commander.fuel == 36 && game.jumpCountdown == nil)
  #expect(game.market == MarketItem.at(game.currentSystem))
}

@Test func jumpTravelDockingAndGalacticDrive() throws {
  var game = Game(executive: false)
  game.inSystemJump()
  #expect(game.message == "MASS LOCKED")
  game.launch()
  game.inSystemJump()
  #expect(game.message == "MASS LOCKED")
  let departure = try #require(
    game.currentNativeMainStationAnchor(at: game.commander.flightSimulation.physicalTime))
  NativeStationTestFixture.reframe(
    &game,
    to: .init(
      position: departure.position - departure.orientation.apply(.init(0, 0, 10000)),
      orientation: departure.orientation))
  game.key("j")
  let jumpedStation = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
  #expect(jumpedStation.position.z == 7000)
  #expect(jumpedStation.physical?.identity == departure.identity)
  game.key("g")
  #expect(game.commander.galaxy == 0)
  try game.commander.grantEquipment(
    "Galactic Hyperdrive", at: .utility(.galacticHyperdrive),
    provenance: .grant("galactic travel fixture"))
  #expect(game.commander.fittedEquipment(at: .utility(.galacticHyperdrive)) != nil)
  game.key("g")
  #expect(
    game.commander.galaxy == 1 && game.commander.fuel == game.commander.fuelCapacity
      && !game.commander.equipment.contains("Galactic Hyperdrive"))
  try game.commander.grantEquipment(
    TargetingTier.docking.equipmentName, at: .targetingCore,
    provenance: .grant("jump-docking-fixture"))
  let arrival = try #require(
    game.currentNativeMainStationAnchor(at: game.commander.flightSimulation.physicalTime))
  NativeStationTestFixture.reframe(
    &game,
    to: .init(
      position: arrival.position - arrival.orientation.apply(.init(0, 0, 1500)),
      orientation: arrival.orientation))
  for _ in 0..<(game.bodies.count * 2) {
    game.key("tab")
    if game.autoPilot.targetActor == arrival.identity { break }
  }
  try #require(game.autoPilot.targetID == 0 && game.autoPilot.targetActor == arrival.identity)
  #expect(game.dockingComputer)
  game.key("p")
  #expect(!game.dockingComputer)
  game.key("tab")
  let anchors = try #require(game.commander.flightSimulation.anchors)
  for _ in 0..<(game.bodies.count * 2) {
    if let selected = game.autoTargetBody, selected.id == 0,
      selected.nativeStationIdentity == nil, selected.physical?.identity == anchors.station.identity
    {
      break
    }
    game.key("tab")
  }
  let station = try #require(game.autoTargetBody)
  try #require(
    station.id == 0 && station.nativeStationIdentity == nil
      && station.physical?.identity == anchors.station.identity && game.dockingComputer)
  for _ in 0..<2000 where !game.docked { game.tick(delta: 0.1) }
  #expect(
    game.docked && game.screen == .status && game.speed == 0,
    Comment(
      rawValue:
        "target=\(String(describing: game.autoPilot.targetID)), actor=\(String(describing: game.autoPilot.targetActor)), status=\(game.autoPilot.status), distance=\(String(describing: game.autoTargetBody?.position.length)), energy=\(game.energy), pendingRRS=\(game.pendingNativeStationDock != nil)"
    ))
  #expect(game.nativeMainStationDockEvidenceIsCurrent)
  game.launch()
  let manual = try #require(
    game.currentNativeMainStationAnchor(at: game.commander.flightSimulation.physicalTime))
  let port = MainStationGeometry.docking
  // Cross the original half-unit doorway boundary; stationary overlap cannot mint arrival.
  NativeStationTestFixture.reframe(
    &game,
    to: .init(
      position: manual.position + manual.orientation.apply(port.center + port.outward * 0.5),
      orientation: manual.orientation))
  game.speed = 2
  game.tick(delta: 0.02)
  #expect(game.docked)
  #expect(game.nativeMainStationDockEvidenceIsCurrent)
  game.launch()
  let impact = try #require(
    game.currentNativeMainStationAnchor(at: game.commander.flightSimulation.physicalTime))
  NativeStationTestFixture.reframe(
    &game,
    to: .init(
      position: impact.position - impact.orientation.apply(.init(50, 0, 50)),
      orientation: impact.orientation))
  game.speed = 20
  game.tick(delta: 0.02)
  #expect(!game.docked && game.message == "DOCKING COLLISION")
}

@Test func combatLasersMissilesAndBomb() throws {
  // Native combat in an authored unit cohort before ordinary station/traffic admission.
  var game = Game(executive: false)
  game.commander.shipID = "SH023"
  game.commander.fuel = game.commander.fuelCapacity
  game.commander.credits = 1000
  game.commander.equipment.insert("Military Laser")
  try game.commander.prepareEquipment()
  game.commander.mirrorFittedEquipment()
  game.energy = game.commander.performance.energy
  game.frontShield = game.commander.shieldCapacity
  game.rearShield = game.commander.rearShieldCapacity
  game.docked = false
  game.screen = .front
  try #require(game.commander.valid && game.commander.nativeStations == nil)
  game.ensurePhysicalActors()
  #expect(game.commander.fittedEquipment(at: .laser(.front))?.node.key == "Military Laser")
  game.speed = 0
  game.commander.flightSimulation.pose.position = .init(0, 0, -3000)
  game.bodies = [SpaceBody(id: 1, hull: .sidewinder, position: .init(0, 0, 500), hostile: true)]
  game.ensurePhysicalActors()
  // Hostility does not establish a bounty; this fixture supplies its known criminal record.
  game.bodies[0].physical?.npc?.legal = .init(value: 64, bountyTenths: 50)
  game.bodies[0].physical?.npc?.legalProvenance = .recorded
  var controls = Controls()
  controls.fire = true
  for _ in 0..<6 { game.tick(delta: 0.1, controls: controls) }
  #expect(game.commander.kills == 1 && game.commander.credits == 1050 && game.bodies.isEmpty)
  game.fireMissile()
  #expect(game.commander.missiles == 3)
  // Keep this damage/bounty fixture outside immediate NPC beam-interception range.
  game.bodies = [SpaceBody(id: 2, hull: .cobra, position: .init(0, 0, 1800))]
  game.key("t")
  game.key("m")
  #expect(game.commander.missiles == 2 && !game.missileArmed)
  for _ in 0..<150 where game.commander.kills < 2 { game.tick(delta: 0.02) }
  #expect(game.commander.kills == 2 && game.commander.legal == 40)
  game.commander.unlimitedMissiles = true
  game.bodies = [SpaceBody(id: 3, hull: .cobra, position: .init(0, 0, 1000))]
  game.key("t")
  game.key("m")
  #expect(game.commander.missiles == 2)
  game.key("t")
  game.key("u")
  #expect(!game.missileArmed)
  try game.commander.grantEquipment(
    "Energy Bomb", at: .utility(.energyBomb), provenance: .grant("fixture"))
  let bomb = try #require(game.commander.fittedEquipment(at: .utility(.energyBomb))?.id)
  game.bodies = [
    SpaceBody(id: 0, hull: .station, position: .init(0, 0, 1000)),
    SpaceBody(id: 4, hull: .thargoid, position: .init(0, 0, 2000)),
  ]
  game.key("energy-bomb")
  game.tick(delta: 0.02)
  #expect(game.bodies.count == 1 && game.bodies[0].hull == .station)
  #expect(!game.commander.equipment.contains("Energy Bomb"))
  #expect(game.commander.equipmentInventory?.items.contains { $0.id == bomb } == false)
}

@Test func ecmEscapeEnemiesAndSimulationBounds() throws {
  var game = Game(executive: false)
  // Preserve this controlled Cobra unit's original energy and speed boundaries.
  game.commander.shipID = "SH023"
  game.commander.fuel = game.commander.fuelCapacity
  game.energy = game.commander.performance.energy
  game.frontShield = game.commander.shieldCapacity
  game.rearShield = game.commander.rearShieldCapacity
  game.launch()
  try #require(!game.docked && game.commander.valid)
  game.speed = 0
  let missileID = game.nextBodyID
  game.nextBodyID += 1
  game.bodies.append(SpaceBody(id: missileID, hull: .missile, position: .init(0, 0, 1000)))
  game.ensurePhysicalActors()
  let beforeECM = game.bodies
  let survivors = beforeECM.filter { $0.hull != .missile }
  try #require(beforeECM.filter { $0.hull == .missile }.map(\.id) == [missileID])
  try #require(survivors.contains { $0.nativeStationIdentity != nil })
  game.key("e")
  #expect(game.bodies == beforeECM && game.energy == 256)
  try game.commander.grantEquipment(
    "E.C.M. System", at: .utility(.ecm), provenance: .grant("ECM simulation fixture"))
  try #require(game.commander.fittedEquipment(at: .utility(.ecm)) != nil)
  game.key("e")
  #expect(game.bodies == survivors && game.energy == 246)
  game.bodies = [SpaceBody(id: 2, hull: .viper, position: .init(0, 0, 500), hostile: true)]
  game.frontShield = 0
  game.energy = 0.01
  game.tick(delta: 0.1)
  #expect(game.screen == .gameOver)
  game = Game(executive: false)
  // Preserve this controlled Cobra unit's original energy and speed boundaries.
  game.commander.shipID = "SH023"
  game.commander.fuel = game.commander.fuelCapacity
  game.energy = game.commander.performance.energy
  game.frontShield = game.commander.shieldCapacity
  game.rearShield = game.commander.rearShieldCapacity
  game.launch()
  game.key("escape-pod")
  #expect(!game.docked)
  try game.commander.grantEquipment(
    "Escape Pod", at: .utility(.escapePod), provenance: .grant("escape simulation fixture"))
  #expect(game.commander.fittedEquipment(at: .utility(.escapePod)) != nil)
  game.commander.cargo[0] = 10
  game.commander.legal = 30
  game.key("escape-pod")
  #expect(game.docked && game.commander.cargoTonnes == 0 && game.commander.legal == 0)
  game.launch()
  game.bodies = []
  try game.commander.grantEquipment(
    "Extra Energy Unit", at: .energy, provenance: .grant("energy simulation fixture"))
  #expect(game.commander.fittedEquipment(at: .energy)?.node.key == "Extra Energy Unit")
  var controls = Controls()
  controls.throttle = 1
  controls.pitch = 0.2
  controls.roll = -0.3
  for _ in 0..<200 { game.tick(delta: 1, controls: controls) }
  #expect(game.speed == 32 && game.bodies.count >= 1)
  controls.throttle = -1
  for _ in 0..<40 { game.tick(delta: 0.1, controls: controls) }
  #expect(game.speed == 0)
  let time = game.time
  game.tick(delta: -.infinity)
  game.tick(delta: .nan)
  game.tick(delta: 0)
  #expect(game.time == time)
  game.bodies = [SpaceBody(id: 3, hull: .cargo, position: .init(0, 0, 50000))]
  game.tick(delta: 0.02)
  #expect(!game.bodies.contains { $0.id == 3 })
  #expect(game.bodies.allSatisfy { $0.physical?.spawnIdentity != nil })
}

@Test func viewTransformsAndGeometry() {
  let p = Vector3(1, 2, 3)
  #expect((p + p) == Vector3(2, 4, 6))
  #expect((p - p).length == 0)
  #expect(p.dot(p) == 14)
  #expect(Vector3(1, 0, 0).cross(Vector3(0, 1, 0)) == Vector3(0, 0, 1))
  #expect(p.rotated(pitch: 0, roll: 0) == p)
  var game = Game(executive: false)
  for (view, expected) in [
    (Screen.front, p), (.rear, Vector3(-1, 2, -3)), (.left, Vector3(3, 2, -1)),
    (.right, Vector3(-3, 2, 1)),
  ] {
    game.screen = view
    #expect(game.viewPosition(p) == expected)
  }
  for hull in Hull.allCases {
    let mesh = Mesh.hull(hull)
    #expect(
      mesh.faces.allSatisfy {
        $0.count >= 3 && $0.allSatisfy { mesh.vertices.indices.contains($0) }
      })
  }
  #expect(Display.project(.init(0, 0, -1), .init(1, 1, -1)) == nil)
  #expect(Display.project(.init(0, 0, -1), .init(1, 1, 10)) != nil)
  #expect(Display.project(.init(0, 0, 10), .init(1, 1, -1)) != nil)
  #expect(Display.project(.init(.infinity, 0, 1), .init(0, 0, 1)) == nil)
}

@Test func rasterClippingAndRenderingEveryScreen() {
  var frame = Frame()
  frame.pixel(-1, 0)
  frame.pixel(256, 0)
  #expect(frame.pixels.allSatisfy { $0 == Ink.black.rawValue })
  frame.line(-100, 20, 1000, 20)
  #expect(frame.pixels[20 * 256] == Ink.white.rawValue)
  frame.line(20, -100, 20, 1000)
  #expect(frame.pixels[20] == Ink.white.rawValue)
  frame.line(-20, -20, -10, -10)
  frame.line(-5, 0, -5, 255)
  frame.line(0, -5, 255, -5)
  frame.line(0, 0, 0, 0)
  frame.line(255, 255, 0, 0)
  frame.line(0, 255, 255, 0)
  frame.text("ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789.,:;-/?!()+='<>*", -8, 252)
  #expect(frame.pixels[0] == Ink.white.rawValue)
  var game = Game(executive: false)
  game.launch()
  game.commander.cargo[0] = 2
  for screen in Screen.allCases {
    game.screen = screen
    if screen == .mission {
      game.missionNotice = MissionNotice(
        message: .constrictorBriefing, commander: "JAMESON", galaxy: 0)
      game.missionElapsed = 2
    }
    let image = Display.render(game)
    #expect(
      image.pixels.count == 65536
        && (image.pixels.contains(Ink.white.rawValue) || !image.labels.isEmpty))
    #expect(image == Display.render(game))
  }
  game.commander.legal = 70
  game.screen = .status
  _ = Display.render(game)
  game.commander.legal = 1
  _ = Display.render(game)
  game.screen = .front
  game.speed = 32
  game.laserFlash = 0.1
  game.jumpCountdown = 3
  game.dockingComputer = true
  game.bodies[1].hostile = true
  game.missileArmed = true
  _ = Display.render(game)
  game.screen = .secret
  game.commander.unlimitedMissiles = true
  _ = Display.render(game)
}

@Test func actorPersistenceAndConcurrentCommands() async throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  let url = directory.appendingPathComponent("commander.json")
  let runtime = GameRuntime(game: Game(executive: false))
  await runtime.key(" ")
  for key in "xyzzy" { await runtime.key(String(key)) }
  await runtime.key("2")
  await runtime.key("return")
  try await runtime.save(to: url)
  let restored = GameRuntime(game: Game(executive: false))
  try await restored.load(from: url)
  let before = await runtime.snapshot()
  let after = await restored.snapshot()
  #expect(before.commander == after.commander && after.commander.unlimitedMissiles)
  await withTaskGroup(of: Void.self) { group in
    for _ in 0..<100 { group.addTask { _ = await restored.advance(delta: 0.02) } }
  }
  let final = await restored.snapshot()
  #expect(abs(final.time - 2) < 0.00001)
  await restored.key("0")
  await restored.setControls(Controls())
  let target = try #require(await restored.snapshot().systems.first { $0.id == 7 })
  await restored.selectSystem(x: Double(target.x), y: Double(target.y))
  #expect(await restored.snapshot().selectedSystem == 7)
  var invalid = Commander()
  invalid.system = -1
  try JSONEncoder().encode(invalid).write(to: url)
  await #expect(throws: SaveError.self) { try await restored.load(from: url) }
  try Data(repeating: 0, count: 4_194_305).write(to: url)
  await #expect(throws: SaveError.self) { try await restored.load(from: url) }
  var game = Game(executive: false)
  let loaded = game.load(invalid)
  #expect(!loaded)
  game.commander = invalid
  let bad = GameRuntime(game: game)
  await #expect(throws: SaveError.self) { try await bad.save(to: url) }
}

@Test func executiveDefaultsDemoAndPauseOptions() {
  var game = Game()
  #expect(game.screen == .demo && game.commander.name == "Rowan Calder")
  #expect(
    game.commander.credits == 7200
      && game.commander.capacity == game.commander.nativePerformance.cargo)
  #expect(game.commander.shipID == "SH025" && game.commander.fuel == 130)
  #expect(game.commander.galaxy == 0 && game.commander.system == 7)
  #expect(game.commander.equipment == ["Pulse Laser"])
  #expect(game.commander.valid)
  game.key(" ")
  #expect(game.screen == .demo)
  for _ in 0..<121 { game.tick(delta: 0.1) }
  #expect(game.screen == .title)
  game.key(" ")
  #expect(game.screen == .status)
  game.key("copy")
  let time = game.time
  game.tick(delta: 0.1)
  #expect(game.time == time)
  game.key("@")
  #expect(!game.commander.unlimitedJumps && !game.commander.unlimitedFuel)
  game.key(":")
  #expect(game.commander.speech)
  _ = Display.render(game)
  game.key("escape")
  #expect(!game.paused)
  game.screen = .gameOver
  game.key("return")
  #expect(game.commander.name == "Rowan Calder")
  #expect(game.commander.credits == 7200 && game.commander.shipID == "SH025")
  #expect(game.commander.fuel == 130 && game.commander.galaxy == 0 && game.commander.system == 7)
}

@Test func xyzzyJumpLimitsPersistAndObeyCurrentFuelAndNavigationComputer() async throws {
  var game = Game(executive: false)
  game.launch()
  for key in "xyzzy" { game.key(String(key)) }
  #expect(game.commander.unlimitedFuel && !game.commander.unlimitedJumps)
  #expect(game.commander.fuelStorageUnits == 4 && game.commander.navigationTier == .military)
  game.key("return")
  game.bodies = []
  game.selectedSystem = try #require(
    game.systems.first { game.currentSystem.distance(to: $0) > 21 }?.id)
  game.beginHyperspace()
  #expect(game.jumpCountdown == nil && !game.targetReachable)
  game.selectedSystem = try #require(
    game.systems.first {
      game.currentSystem.distance(to: $0) > 7 && game.currentSystem.distance(to: $0) < 21
    }?.id)
  game.commander.fuel = 0
  game.beginHyperspace()
  #expect(game.jumpCountdown == nil && !game.targetReachable)
  game.commander.unlimitedFuel = false
  game.commander.fuel = 350
  let destination = game.selectedSystem
  let cost = Int((game.currentSystem.distance(to: game.targetSystem) * 10).rounded())
  let drive = try #require(game.commander.fittedEquipment(at: .drive))
  let component = try #require(drive.component)
  let navigationDevice = try #require(game.commander.fittedEquipment(at: .navigation))
  let navigation = try #require(navigationDevice.component)
  try #require(navigationDevice.node.key == NavigationTier.military.equipmentName)
  try #require(drive.node == HyperspaceDriveDefinition.node(for: .advanced))
  try #require(component.grade == HyperspaceDriveDefinition.template(for: .advanced).identity)
  try #require(component.statistics[.jumpSpool] == 1 && navigation.statistics[.jumpSpool] == 1)
  let policy = try #require(game.commander.hyperspaceDrivePolicy)
  try #require(policy.activation == .timed(seconds: 1))
  game.beginHyperspace()
  #expect(game.jumpCountdown == 1 && game.targetReachable)
  game.arrive()
  #expect(game.commander.system == destination && game.commander.fuel == 350 - cost)
  let runtime = GameRuntime(game: game)
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  try await runtime.save(to: url)
  let restored = GameRuntime()
  try await restored.load(from: url)
  let bytes = try Data(contentsOf: url)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
  #expect(pointer.schemaVersion == 26)
  let (strictSaved, strictWorld) = try ScriptSaveStore.read(bytes, from: url)
  #expect(strictSaved.valid && strictWorld.valid && strictWorld.consistent(with: strictSaved))
  // Versioned loading restores ordinary NPC bindings from the retained physical scene.
  var expected = game.commander
  var restoredGame = await restored.snapshot()
  let savedWorld = try #require(expected.nativeStations)
  expected.nativeStations = try reboundJumpLimitWorldAfterLoad(savedWorld, restored: &restoredGame)
  let differences = try jumpLimitSaveDifferences(expected, actual: restoredGame.commander)
  let restoredCommander = await restored.snapshot().commander
  #expect(restoredCommander == expected, Comment(rawValue: differences))
}

private func jumpLimitSaveDifferences(_ expected: Commander, actual: Commander) throws -> String {
  var left = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(expected)) as? [String: Any])
  var right = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(actual)) as? [String: Any])
  left["equipment"] = expected.equipment.sorted()
  right["equipment"] = actual.equipment.sorted()
  func differences(_ left: Any, _ right: Any, path: String) -> [String] {
    if let value = left as? NSObject, value.isEqual(right) { return [] }
    if let left = left as? [String: Any], let right = right as? [String: Any] {
      return Set(left.keys).union(right.keys).sorted().flatMap { key in
        differences(left[key] ?? NSNull(), right[key] ?? NSNull(), path: path + "." + key)
      }
    }
    if let left = left as? [Any], let right = right as? [Any] {
      guard left.count == right.count else { return [path + ".count"] }
      return left.indices.flatMap { differences(left[$0], right[$0], path: path + "[\($0)]") }
    }
    return ["\(path): expected \(left), actual \(right)"]
  }
  return Set(left.keys).union(right.keys).sorted().flatMap { key in
    differences(left[key] ?? NSNull(), right[key] ?? NSNull(), path: key).prefix(2)
  }.joined(separator: "; ")
}

private func reboundJumpLimitWorldAfterLoad(
  _ saved: NativeStationWorld, restored: inout Game
) throws -> NativeStationWorld {
  var expected = saved
  for record in saved.ledger.records
  where record.identity.system == restored.systemIdentity && record.tombstone == nil {
    let originalBinding = try #require(record.binding)
    let body = try #require(
      restored.bodies.first { $0.nativeStationIdentity == record.identity })
    let actor = try #require(body.physical?.identity)
    #expect(
      actor.system == restored.systemIdentity
        && actor.visit == restored.commander.flightSimulation.visit)
    #expect(actor.visit == originalBinding.actor.visit && originalBinding.actor != actor)
    try expected.ledger.rebind(record.identity, to: .init(actor: actor, bodyID: body.id))
  }
  #expect(expected.valid)
  return expected
}

@Test func autoTraderUsesEconomyCapitalAndCargo() {
  var game = Game(executive: false)
  game.commander.credits = 20000
  game.selectedSystem = 129
  let exports = game.profitableExports(to: game.targetSystem)
  #expect(!exports.isEmpty)
  #expect(exports.allSatisfy { $0.index != 16 && $0.profit > 0 })
  game.autoTrade()
  #expect(
    game.commander.cargoTonnes > 0
      && game.commander.cargoTonnes <= game.commander.tradeCargoCapacity)
  #expect(game.commander.credits >= 0 && game.commander.credits < 20000)
  let cargo = game.commander.cargo
  let initialFreightCost = 20000 - game.commander.credits
  game.launch()
  game.autoTrade()
  #expect(game.commander.cargo == cargo)
  game.arrive()
  game.commander.autoTrade = true
  let cash = game.commander.credits
  let arrivalPrices = game.market.map(\.price)
  let arrivalBids = game.market.map(\.bidPrice)
  let saleRevenue = cargo.indices.reduce(0) { $0 + cargo[$1] * arrivalBids[$1] }
  let refuelCost = game.refillCost
  game.dock()
  let nextFreightCost = game.commander.cargo.indices.reduce(0) {
    $0 + game.commander.cargo[$1] * arrivalPrices[$1]
  }
  #expect(saleRevenue > initialFreightCost)
  #expect(game.commander.credits == cash + saleRevenue - refuelCost - nextFreightCost)
  #expect(game.commander.cargoTonnes > 0 && game.selectedSystem != game.commander.system)
  #expect(game.commander.valid)
  var stranded = Game(executive: false)
  stranded.commander.fuel = 0
  stranded.commander.credits = 0
  stranded.autoTrade()
  #expect(stranded.message == "INSUFFICIENT FUNDS FOR FULL FUEL")
  var secret = Game(executive: false)
  secret.key(" ")
  for key in "xyzzy" { secret.key(String(key)) }
  #expect(secret.commander.autoTrade && secret.commander.cargoTonnes > 0)
  _ = Display.render(secret)
  secret.key("6")
  #expect(!secret.commander.autoTrade)
}

@Test func soundSynthesisProducesDeterministicWaveFiles() {
  for effect in SoundEffect.allCases {
    let wave = effect.wav()
    #expect(String(data: wave.prefix(4), encoding: .utf8) == "RIFF")
    #expect(String(data: wave[8..<12], encoding: .utf8) == "WAVE")
    #expect(wave.count == 44 + Int(effect.duration * 22050) * 2)
    #expect(wave == effect.wav())
    #expect(effect.frequency(0) > 0 && effect.frequency(1) > 0)
  }
}

@Test func autoTraderIncludesIllegalProfitableExports() throws {
  var game = Game(executive: false)
  // The first catalogue-ordered, seven-LY route profitable for all three restricted goods.
  // Preserve authenticated ask/bid quotes: invented prices make the current Commander invalid.
  game.commander.system = 12
  game.selectedSystem = 225
  game.commander.credits = 200000
  try #require(game.currentSystem.original?.key == "G01-S012")
  try #require(game.targetSystem.original?.key == "G01-S225")
  try #require(game.currentSystem.distance(to: game.targetSystem) <= 7)
  let destination = MarketItem.at(game.targetSystem)
  let illegal = [3, 6, 10]
  for index in illegal {
    try #require(destination[index].bidPrice > game.market[index].price)
  }
  let purchaseCost = illegal.reduce(0) { $0 + 4 * game.market[$1].price }
  let cashBefore = game.commander.credits
  for index in game.market.indices { game.market[index].quantity = 0 }
  for index in illegal { game.market[index].quantity = 4 }
  try #require(game.commander.valid)
  game.autoTrade()
  #expect(
    game.commander.cargo[3] == 4 && game.commander.cargo[6] == 4 && game.commander.cargo[10] == 4)
  #expect(game.commander.cargoTonnes == 12)
  #expect(game.commander.credits == cashBefore - purchaseCost)
  #expect(illegal.allSatisfy { game.market[$0].quantity == 0 })
  try #require(game.commander.valid)
  game.launch()
  #expect(!game.docked && game.screen == .front && game.commander.legal == 16)
  #expect(game.commander.valid)
}

@Test func finiteXYZzyCashAndUnlimitedCargoKeepTransactionsAndSavesValid() async throws {
  var game = Game(executive: false)
  game.key(" ")
  for key in "xyzzy" { game.key(String(key)) }
  game.key("return")
  #expect(game.commander.unlimitedCargo && !game.commander.unlimitedCash)
  game.commander.credits = 0
  game.commander.cargo = Array(repeating: 0, count: 17)
  game.commander.cargo[0] = 100
  game.selection = 1
  // Current markets own immutable authored bid/ask quotes; only stock is mutable.
  game.market[1].quantity = 10
  game.trade(buy: true)
  #expect(game.commander.cargo[1] == 0 && game.commander.credits == 0)
  game.selection = 2
  game.purchase()
  #expect(game.commander.equipment.contains("Large Cargo Bay"))
  #expect(game.commander.valid)
  for key in "xyzzy" { game.key(String(key)) }
  game.key("8")
  #expect(game.commander.unlimitedCargo && game.message == "SELL EXCESS CARGO FIRST")
  let runtime = GameRuntime(game: game)
  let ready = await runtime.snapshot()
  #expect(ready.commander.valid && ready.commander.equipmentInventory != nil)
  #expect(
    ready.commander.credits == game.commander.credits
      && ready.commander.cargo == game.commander.cargo)
  #expect(
    ready.commander.unlimitedCargo == game.commander.unlimitedCargo
      && ready.commander.unlimitedCash == game.commander.unlimitedCash
      && ready.commander.fuel == game.commander.fuel
      && ready.commander.shipID == game.commander.shipID)
  // This docked, non-legacy fixture has no journey or live body poses to publish.
  try #require(ready.docked && ready.bodies.isEmpty)
  try #require(ready.commander.legacyOwnedEquipment == nil && ready.jumpCountdown == nil)
  try #require(ready.commander.miningLedger.usesEconomyWeightedPresence)
  var migrated = ready
  try migrated.migrateMiningPresence(legacyMissing: false, persistCurrentPolicy: true)
  migrated.ensureScriptCalendar(origin: .newCommander)
  // Independently whitelist only persisted current-policy metadata and a missing calendar.
  var canonical = ready.commander
  canonical.miningLedger = ready.commander.miningLedger
  if canonical.scriptState.calendarLedger == nil {
    canonical.scriptState.calendarLedger = .init(origin: .newCommander)
  }
  #expect(migrated.commander == canonical)
  #expect(migrated.commander.usesEconomyMiningSaveVersion)
  #expect(migrated.commander.miningLedger == ready.commander.miningLedger)
  #expect(
    migrated.commander.scriptState.calendarSeconds == ready.commander.scriptState.calendarSeconds)
  #expect(
    migrated.commander.scriptState.calendarLedger
      == (ready.commander.scriptState.calendarLedger ?? ScriptCalendarLedger(origin: .newCommander))
  )
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let url = directory.appendingPathComponent("commander.json")
  defer { try? FileManager.default.removeItem(at: directory) }
  try await runtime.save(to: url)
  let published = await runtime.snapshot()
  // The expected value comes only from the two authorized migrations above: every
  // other Commander property must survive publication exactly, including all custody.
  #expect(published.commander == canonical && published.market == ready.market)
  var expected = canonical
  if expected.npcPersistence.count > 0 {
    expected.npcPersistence.resetPhysicalBindings(system: published.systemIdentity)
  }
  let bytes = try Data(contentsOf: url)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
  #expect(pointer.schemaVersion == 26 && pointer.scope == "commander")
  let (persisted, world) = try ScriptSaveStore.read(bytes, from: url)
  #expect(persisted == expected && world.market == ready.market)
  let restored = GameRuntime()
  try await restored.load(from: url)
  let loaded = await restored.snapshot()
  #expect(loaded.commander == expected && loaded.market == ready.market)
  game.commander.cargo = Array(repeating: 0, count: 17)
  game.key("8")
  game.key("9")
  #expect(!game.commander.unlimitedCargo && !game.commander.unlimitedCash)
  game.commander.unlimitedCargo = true
  game.commander.unlimitedCash = false
  game.commander.credits = 100000
  game.selectedSystem = 129
  game.market = MarketItem.at(game.currentSystem)
  // Seeded stock need not exceed the fitted hold; supply one real profitable tonne export.
  let bulkExport = try #require(
    game.profitableExports(to: game.targetSystem).first { Commodity.all[$0.index].unit == "t" })
  let bulkQuantity = game.commander.standardCargoCapacity + 1
  try #require(
    bulkQuantity * game.market[bulkExport.index].price <= game.commander.credits - game.refillCost)
  for index in game.market.indices { game.market[index].quantity = 0 }
  game.market[bulkExport.index].quantity = bulkQuantity
  try #require(game.commander.valid)
  game.autoTrade()
  #expect(game.commander.cargo[bulkExport.index] == bulkQuantity)
  #expect(
    game.commander.credits < 100000
      && game.commander.cargoTonnes > game.commander.standardCargoCapacity)
  game.commander.cargo[0] = Int.max / 17
  // The real authored bid still exercises finite cash overflow without changing prices.
  let saleQuantity = min(game.commander.cargo[0], Int.max / 17 - game.market[0].quantity)
  let cashOverflow = saleQuantity.multipliedReportingOverflow(by: game.market[0].bidPrice).overflow
  #expect(cashOverflow)
  game.autoTrade()
  #expect(
    game.commander.credits <= 4_294_967_295 && game.commander.credits > 4_294_000_000
      && game.commander.valid)
  game.screen = .status
  _ = Display.render(game)
  game.screen = .inventory
  _ = Display.render(game)
  game.screen = .equipment
  _ = Display.render(game)
  game.screen = .market
  _ = Display.render(game)
}

@Test func primitiveHullFacesHaveOutwardNormalsAndClosedEdges() {
  // The detailed, non-convex source Cobra has a welded-boundary rotation oracle.
  for hull in Hull.allCases where hull != .cobra {
    let mesh = Mesh.hull(hull)
    let center = mesh.vertices.reduce(Vector3(0, 0, 0), +) * (1 / Double(mesh.vertices.count))
    var adjacency: [String: Int] = [:]
    for face in mesh.faces {
      let a = mesh.vertices[face[0]]
      let b = mesh.vertices[face[1]]
      let c = mesh.vertices[face[2]]
      let midpoint =
        face.reduce(Vector3(0, 0, 0)) { $0 + mesh.vertices[$1] } * (1 / Double(face.count))
      let normal = (b - a).cross(c - a)
      #expect(normal.dot(midpoint - center) > 0)
      // Culling a warped polygon as one plane can remove a visible outline edge.
      for index in face {
        #expect(abs(normal.dot(mesh.vertices[index] - a)) / normal.length < 1e-8)
      }
      #expect(mesh.vertices.allSatisfy { normal.dot($0 - a) / normal.length < 1e-8 })
      for index in face.indices {
        let i = face[index]
        let j = face[(index + 1) % face.count]
        adjacency["\(min(i,j)):\(max(i,j))", default: 0] += 1
      }
    }
    if hull == .station {
      let aperture = MainStationGeometry.docking.aperture.map {
        MainStationGeometry.docking.center + $0
      }
      let indices = aperture.compactMap { point in mesh.vertices.firstIndex(of: point) }
      #expect(indices.count == aperture.count)
      let doorway = Set(indices.indices.map { index in
        let i = indices[index]
        let j = indices[(index + 1) % indices.count]
        return "\(min(i,j)):\(max(i,j))"
      })
      let boundary = Set(adjacency.filter { $0.value == 1 }.keys)
      #expect(doorway.count == 4 && boundary == doorway)
      #expect(adjacency.allSatisfy { doorway.contains($0.key) ? $0.value == 1 : $0.value == 2 })
    } else {
      #expect(adjacency.values.allSatisfy { $0 == 2 })
    }
  }
}
