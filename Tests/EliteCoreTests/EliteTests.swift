import Foundation
import Testing

@testable import EliteCore

@Test func originalGalaxyFixtures() {
  let galaxy = Universe.galaxy()
  #expect(galaxy.count == 256)
  #expect(galaxy[7].name == "LAVE")
  #expect(galaxy[7].x == 20 && galaxy[7].y == 173)
  #expect(galaxy[7].economy == 5 && galaxy[7].government == 3)
  #expect(galaxy[7].technology == 4)
  #expect(galaxy[129].name == "ZAONCE")
  #expect(galaxy[147].name == "DISo".uppercased())
  #expect(galaxy[7].distance(to: galaxy[7]) == 0)
  #expect(galaxy[7].distance(to: galaxy[129]) == 5.6)
  #expect(galaxy[7].economyName == "Rich Agricultural")
  #expect(galaxy[7].governmentName == "Dictatorship")
  for index in 0..<8 {
    let systems = Universe.galaxy(number: index)
    #expect(systems.allSatisfy { !$0.name.isEmpty && (0..<8).contains($0.economy) })
    #expect(Set(systems.map(\.id)).count == 256)
    #expect(systems == Universe.galaxy(number: index + 8))
  }
  #expect(Universe.galaxy(number: 1) != galaxy)
}

@Test func marketFixturesAndBounds() {
  let market = MarketItem.generate(economy: 5, fluctuation: 0)
  #expect(market[0] == MarketItem(price: 36, quantity: 16))
  #expect(market[7] == MarketItem(price: 896, quantity: 0))
  for economy in 0..<8 {
    for fluctuation in 0..<256 {
      let items = MarketItem.generate(economy: economy, fluctuation: fluctuation)
      #expect(items.allSatisfy { (0...1020).contains($0.price) && (0...63).contains($0.quantity) })
      #expect(items[16].quantity == 0)
    }
  }
}

@Test func commanderIntegrityAndRanks() {
  var commander = Commander()
  #expect(commander.valid && commander.capacity == 20 && commander.rank == "Harmless")
  for (kills, rank) in [
    (8, "Mostly Harmless"), (16, "Poor"), (32, "Average"), (64, "Above Average"),
    (128, "Competent"), (512, "Dangerous"), (2560, "Deadly"), (6400, "ELITE"),
  ] {
    commander.kills = kills
    #expect(commander.rank == rank)
  }
  commander.cargo[0] = 21
  #expect(!commander.valid)
  commander.equipment.insert("Large Cargo Bay")
  #expect(commander.valid && commander.capacity == 35)
  commander.cargo[13] = 1000
  #expect(commander.cargoTonnes == 21)
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
  let docked: [Screen] = [
    .front, .buy, .sell, .equipment, .chart, .shortChart, .system, .market, .status, .inventory,
  ]
  // Screen zero launches, so verify docked screens before it.
  for i in 1..<10 {
    game.key("f\(i)")
    #expect(game.screen == docked[i])
  }
  game.key("f99")
  #expect(game.screen == .inventory)
  game.key("f10")
  #expect(!game.docked && game.screen == .front)
  for (key, screen) in [("f1", Screen.rear), ("f2", .left), ("f3", .right), ("f0", .front)] {
    game.key(key)
    #expect(game.screen == screen)
  }
  for key in "xyzzy" { game.key(String(key)) }
  #expect(game.screen == .secret)
  game.key("1")
  #expect(game.commander.equipment.contains("Docking Computers"))
  game.key("2")
  #expect(game.commander.equipment.contains("Military Laser") && game.commander.fuel == 70)
  game.key("3")
  #expect(game.commander.unlimitedMissiles)
  game.key("3")
  #expect(!game.commander.unlimitedMissiles)
  game.key("ignored")
  game.key("return")
  #expect(game.screen == .front)
  game.screen = .gameOver
  game.key("q")
  #expect(game.screen == .gameOver)
  game.key("return")
  #expect(game.docked && game.commander.credits == 1000)
}

@Test func marketTransactionsRespectCashCapacityAndStock() {
  var game = Game(executive: false)
  game.screen = .buy
  let initial = game.commander
  game.key("return")
  #expect(game.commander.cargo[0] == 1 && game.commander.credits == initial.credits - 36)
  #expect(game.market[0].quantity == 15)
  game.key("left")
  #expect(game.commander.cargo[0] == 0 && game.commander.credits == initial.credits)
  game.key("left")
  #expect(game.message == "NO CARGO")
  game.commander.credits = 0
  game.trade(buy: true)
  #expect(game.commander.cargo[0] == 0)
  game.commander.credits = 10000
  game.commander.cargo[1] = 20
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
  #expect(game.commander.cargo[1] == 19)
  game.key("down")
  #expect(game.selection == 2)
  game.key("up")
  #expect(game.selection == 1)
  game.key("right")
  #expect(game.commander.cargo[1] == 20)
}

@Test func equipmentPurchases() {
  var game = Game(executive: false)
  game.screen = .equipment
  game.commander.fuel = 60
  game.purchase()
  #expect(game.commander.fuel == 70 && game.commander.credits == 980)
  game.selection = 1
  game.key("return")
  #expect(game.commander.missiles == 4 && game.commander.credits == 680)
  game.purchase()
  #expect(game.message == "MISSILE RACK FULL")
  game.selection = 9
  game.purchase()
  #expect(game.message == "NOT AVAILABLE")
  game.commander.credits = 100000
  game.selection = 2
  game.purchase()
  #expect(game.commander.capacity == 35 && game.commander.credits == 96000)
  game.purchase()
  #expect(game.message == "ALREADY FITTED")
  game.selection = 99
  game.purchase()
  game.docked = false
  game.selection = 3
  game.purchase()
  #expect(!game.commander.equipment.contains("E.C.M. System"))
}

@Test func chartSelectionAndHyperspace() {
  var game = Game(executive: false)
  game.key(" ")
  game.key("f4")
  game.key("right")
  #expect(game.selectedSystem == 8)
  game.key("left")
  #expect(game.selectedSystem == 7)
  game.selectedSystem = 0
  game.selectNeighbour(direction: -1)
  #expect(game.selectedSystem == 255)
  game.selectSystem(x: 20, y: 173)
  #expect(game.selectedSystem == 7)
  game.key("d")
  #expect(game.message.contains("DISTANCE"))
  game.key("o")
  #expect(game.selectedSystem == 7)
  game.beginHyperspace()
  #expect(game.jumpCountdown == nil)
  game.launch()
  game.selectedSystem = 129
  game.beginHyperspace()
  #expect(game.message == "MASS LOCKED")
  game.bodies = []
  game.commander.fuel = 0
  game.beginHyperspace()
  #expect(game.message == "FUEL TOO LOW")
  game.commander.fuel = 70
  game.key("h")
  #expect(game.jumpCountdown == 15)
  game.jumpCountdown = 0.01
  game.tick(delta: 0.02)
  #expect(game.commander.system == 129 && game.commander.fuel == 14 && game.jumpCountdown == nil)
  #expect(game.market == MarketItem.generate(economy: game.currentSystem.economy, fluctuation: 218))
}

@Test func jumpTravelDockingAndGalacticDrive() {
  var game = Game(executive: false)
  game.inSystemJump()
  #expect(game.message == "MASS LOCKED")
  game.launch()
  game.inSystemJump()
  #expect(game.message == "MASS LOCKED")
  game.bodies = [SpaceBody(id: 0, hull: .station, position: .init(0, 0, 10000))]
  game.key("j")
  #expect(game.bodies[0].position.z == 7000)
  game.key("g")
  #expect(game.commander.galaxy == 0)
  game.commander.equipment.insert("Galactic Hyperdrive")
  game.key("g")
  #expect(
    game.commander.galaxy == 1 && game.commander.fuel == 70
      && !game.commander.equipment.contains("Galactic Hyperdrive"))
  game.commander.equipment.insert("Docking Computers")
  game.key("c")
  #expect(game.dockingComputer)
  game.key("p")
  #expect(!game.dockingComputer)
  game.key("c")
  game.bodies = [SpaceBody(id: 0, hull: .station, position: .init(0, 0, 200))]
  game.tick(delta: 0.02)
  #expect(game.docked && game.screen == .status && game.speed == 0)
  game.launch()
  game.speed = 0
  game.bodies = [SpaceBody(id: 0, hull: .station, position: .init(0, 0, 50))]
  game.tick(delta: 0.02)
  #expect(game.docked)
  game.launch()
  game.speed = 20
  game.bodies = [SpaceBody(id: 0, hull: .station, position: .init(50, 0, 50))]
  game.tick(delta: 0.02)
  #expect(!game.docked && game.message == "DOCKING COLLISION")
}

@Test func combatLasersMissilesAndBomb() {
  var game = Game(executive: false)
  game.launch()
  game.speed = 0
  game.bodies = [SpaceBody(id: 1, hull: .sidewinder, position: .init(0, 0, 500), hostile: true)]
  game.commander.equipment.insert("Military Laser")
  var controls = Controls()
  controls.fire = true
  for _ in 0..<6 { game.tick(delta: 0.1, controls: controls) }
  #expect(game.commander.kills == 1 && game.commander.credits == 1050 && game.bodies.isEmpty)
  game.fireMissile()
  #expect(game.commander.missiles == 3)
  game.bodies = [SpaceBody(id: 2, hull: .cobra, position: .init(0, 0, 1000))]
  game.key("t")
  game.key("m")
  #expect(game.commander.missiles == 2 && !game.missileArmed)
  game.tick(delta: 0.02)
  #expect(game.commander.kills == 2 && game.commander.legal == 8)
  game.commander.unlimitedMissiles = true
  game.bodies = [SpaceBody(id: 3, hull: .cobra, position: .init(0, 0, 1000))]
  game.key("t")
  game.key("m")
  #expect(game.commander.missiles == 2)
  game.key("t")
  game.key("u")
  #expect(!game.missileArmed)
  game.commander.equipment.insert("Energy Bomb")
  game.bodies = [
    SpaceBody(id: 0, hull: .station, position: .init(0, 0, 1000)),
    SpaceBody(id: 4, hull: .thargoid, position: .init(0, 0, 2000)),
  ]
  game.key("tab")
  game.tick(delta: 0.02)
  #expect(game.bodies.count == 1 && game.bodies[0].hull == .station)
  #expect(!game.commander.equipment.contains("Energy Bomb"))
}

@Test func ecmEscapeEnemiesAndSimulationBounds() {
  var game = Game(executive: false)
  game.launch()
  game.speed = 0
  game.bodies = [SpaceBody(id: 1, hull: .missile, position: .init(0, 0, 1000))]
  game.key("e")
  #expect(game.bodies.count == 1)
  game.commander.equipment.insert("E.C.M. System")
  game.key("e")
  #expect(game.bodies.isEmpty && game.energy == 246)
  game.bodies = [SpaceBody(id: 2, hull: .viper, position: .init(0, 0, 500), hostile: true)]
  game.frontShield = 0
  game.energy = 0.01
  game.tick(delta: 0.1)
  #expect(game.screen == .gameOver)
  game = Game(executive: false)
  game.launch()
  game.key("escape")
  #expect(!game.docked)
  game.commander.equipment.insert("Escape Pod")
  game.commander.cargo[0] = 10
  game.commander.legal = 30
  game.key("escape")
  #expect(game.docked && game.commander.cargoTonnes == 0 && game.commander.legal == 0)
  game.launch()
  game.bodies = []
  game.commander.equipment.insert("Extra Energy Unit")
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
  #expect(game.bodies.isEmpty)
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
    let image = Display.render(game)
    #expect(image.pixels.count == 65536 && image.pixels.contains(Ink.white.rawValue))
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
  await runtime.key("3")
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
  await restored.key("f10")
  await restored.setControls(Controls())
  await restored.selectSystem(x: 20, y: 173)
  #expect(await restored.snapshot().selectedSystem == 7)
  var invalid = Commander()
  invalid.system = -1
  try JSONEncoder().encode(invalid).write(to: url)
  await #expect(throws: SaveError.self) { try await restored.load(from: url) }
  try Data(repeating: 0, count: 65537).write(to: url)
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
  #expect(game.screen == .demo && game.commander.name == "FIREBUD")
  #expect(game.commander.credits == 1_000_000_000 && game.commander.capacity == 35)
  #expect(game.commander.equipment.contains("Docking Computers"))
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
  #expect(game.commander.unlimitedJumps && game.commander.unlimitedFuel)
  game.key(":")
  #expect(game.commander.speech)
  _ = Display.render(game)
  game.key("escape")
  #expect(!game.paused)
  game.screen = .gameOver
  game.key("return")
  #expect(game.commander.name == "FIREBUD")
}

@Test func unlimitedFuelAndRangePersistAndAllowDistantJumps() async throws {
  var game = Game(executive: false)
  game.key(" ")
  for key in "xyzzy" { game.key(String(key)) }
  game.key("4")
  game.key("5")
  game.key("7")
  #expect(game.commander.unlimitedFuel && game.commander.unlimitedJumps && game.commander.speech)
  game.key("return")
  game.launch()
  game.bodies = []
  game.selectedSystem = 0
  #expect(game.currentSystem.distance(to: game.targetSystem) > 7)
  game.commander.fuel = 0
  game.beginHyperspace()
  #expect(game.jumpCountdown == 15)
  game.jumpCountdown = 0.01
  game.tick(delta: 0.02)
  #expect(game.commander.system == 0 && game.commander.fuel == 70)
  game.commander.unlimitedFuel = false
  game.commander.fuel = 10
  game.selectedSystem = 7
  game.beginHyperspace()
  game.jumpCountdown = 0.01
  game.tick(delta: 0.02)
  #expect(game.commander.fuel == 10)
  let runtime = GameRuntime(game: game)
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  try await runtime.save(to: url)
  let restored = GameRuntime()
  try await restored.load(from: url)
  #expect(await restored.snapshot().commander == game.commander)
}

@Test func autoTraderUsesEconomyCapitalAndCargo() {
  var game = Game(executive: false)
  game.commander.credits = 20000
  game.selectedSystem = 129
  let exports = game.profitableExports(to: game.targetSystem)
  #expect(!exports.isEmpty)
  #expect(exports.allSatisfy { $0.index != 16 && $0.profit > 0 })
  game.autoTrade()
  #expect(game.commander.cargoTonnes > 0 && game.commander.cargoTonnes <= 20)
  #expect(game.commander.credits >= 0 && game.commander.credits < 20000)
  let cargo = game.commander.cargo
  game.launch()
  game.autoTrade()
  #expect(game.commander.cargo == cargo)
  game.arrive()
  game.commander.autoTrade = true
  let cash = game.commander.credits
  game.dock()
  #expect(game.commander.credits > cash && game.selectedSystem != game.commander.system)
  #expect(game.commander.valid)
  var stranded = Game(executive: false)
  stranded.commander.fuel = 0
  stranded.commander.credits = 0
  stranded.autoTrade()
  #expect(stranded.message == "NO TRADE ROUTE")
  var secret = Game(executive: false)
  secret.key(" ")
  for key in "xyzzy" { secret.key(String(key)) }
  secret.key("6")
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

@Test func autoTraderIncludesIllegalProfitableExports() {
  var game = Game(executive: false)
  game.selectedSystem = 129
  game.commander.credits = 20000
  for index in game.market.indices { game.market[index].quantity = 0 }
  for index in [3, 6, 10] { game.market[index] = MarketItem(price: 1, quantity: 4) }
  game.autoTrade()
  #expect(
    game.commander.cargo[3] == 4 && game.commander.cargo[6] == 4 && game.commander.cargo[10] == 4)
  game.launch()
  #expect(game.commander.legal == 16)
}

@Test func unlimitedCashAndCargoKeepTransactionsAndSavesValid() async throws {
  var game = Game(executive: false)
  game.key(" ")
  for key in "xyzzy" { game.key(String(key)) }
  game.key("8")
  game.key("9")
  game.key("return")
  #expect(game.commander.unlimitedCargo && game.commander.unlimitedCash)
  game.commander.credits = 0
  game.commander.cargo[0] = 100
  game.selection = 1
  game.trade(buy: true)
  #expect(game.commander.cargo[1] == 1 && game.commander.credits == 0)
  game.selection = 2
  game.purchase()
  #expect(game.commander.equipment.contains("Large Cargo Bay"))
  #expect(game.commander.valid)
  for key in "xyzzy" { game.key(String(key)) }
  game.key("8")
  #expect(game.commander.unlimitedCargo && game.message == "SELL EXCESS CARGO FIRST")
  let runtime = GameRuntime(game: game)
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  try await runtime.save(to: url)
  let restored = GameRuntime()
  try await restored.load(from: url)
  #expect(await restored.snapshot().commander == game.commander)
  game.commander.cargo = Array(repeating: 0, count: 17)
  game.key("8")
  game.key("9")
  #expect(!game.commander.unlimitedCargo && !game.commander.unlimitedCash)
  game.commander.unlimitedCargo = true
  game.commander.unlimitedCash = true
  game.selectedSystem = 129
  game.autoTrade()
  #expect(game.commander.credits == 0 && game.commander.cargoTonnes > 20)
  game.commander.cargo[0] = Int.max / 17
  game.market[0].price = 1020
  game.autoTrade()
  #expect(game.commander.credits == 4_294_967_295 && game.commander.valid)
  game.screen = .status
  _ = Display.render(game)
  game.screen = .inventory
  _ = Display.render(game)
  game.screen = .equipment
  _ = Display.render(game)
  game.screen = .market
  _ = Display.render(game)
}
