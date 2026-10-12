import Foundation

public enum Screen: String, Codable, Sendable, CaseIterable {
  case demo, title, front, rear, left, right, chart, shortChart, system, market, status, inventory,
    equipment, buy, sell, secret, gameOver
  public var isFlight: Bool { [.front, .rear, .left, .right].contains(self) }
}

public struct Commander: Sendable, Equatable, Codable {
  public var name = "JAMESON"
  public var credits = 1000
  public var fuel = 70
  public var galaxy = 0
  public var system = 7
  public var cargo = Array(repeating: 0, count: 17)
  public var equipment: Set<String> = ["Pulse Laser"]
  public var missiles = 3
  public var kills = 0
  public var legal = 0
  public var unlimitedMissiles = false
  public var unlimitedCargo = false
  public var unlimitedCash = false
  public var unlimitedFuel = false
  public var unlimitedJumps = false
  public var autoTrade = false
  public var speech = false
  public var executive = false
  public init() {}
  public static var firebud: Commander {
    var value = Commander()
    value.name = "FIREBUD"
    value.credits = 1_000_000_000
    value.equipment = Set(Equipment.all.map(\.name))
    value.missiles = 4
    value.executive = true
    return value
  }
  public var availableCredits: Int { unlimitedCash ? Int.max : credits }
  public var capacity: Int {
    let standard = equipment.contains("Large Cargo Bay") ? 35 : 20
    return unlimitedCargo ? Int.max / 17 : standard
  }
  public var cargoTonnes: Int {
    zip(cargo, Commodity.all).reduce(0) { $0 + ($1.1.unit == "t" ? $1.0 : 0) }
  }
  public var rank: String {
    let thresholds = [8, 16, 32, 64, 128, 512, 2560, 6400]
    return [
      "Harmless", "Mostly Harmless", "Poor", "Average", "Above Average", "Competent", "Dangerous",
      "Deadly", "ELITE",
    ][thresholds.filter { kills >= $0 }.count]
  }
  public var valid: Bool {
    cargo.count == 17 && cargo.allSatisfy { $0 >= 0 && $0 <= Int.max / 17 } && credits >= 0
      && credits <= 4_294_967_295
      && (0..<256).contains(system) && (0..<8).contains(galaxy) && (0...70).contains(fuel)
      && (0...4).contains(missiles) && kills >= 0 && legal >= 0 && cargoTonnes <= capacity
      && equipment.isSubset(of: Set(Equipment.all.map(\.name))) && !name.isEmpty && name.count <= 16
  }
}

public struct Equipment: Sendable {
  public let name: String
  public let price: Int
  public let technology: Int
  public static let all: [Equipment] = [
    .init(name: "Fuel", price: 2, technology: 0),
    .init(name: "Missile", price: 300, technology: 0),
    .init(name: "Large Cargo Bay", price: 4000, technology: 0),
    .init(name: "E.C.M. System", price: 6000, technology: 2),
    .init(name: "Pulse Laser", price: 4000, technology: 3),
    .init(name: "Beam Laser", price: 10000, technology: 4),
    .init(name: "Fuel Scoops", price: 5250, technology: 5),
    .init(name: "Escape Pod", price: 10000, technology: 6),
    .init(name: "Energy Bomb", price: 9000, technology: 7),
    .init(name: "Extra Energy Unit", price: 15000, technology: 8),
    .init(name: "Docking Computers", price: 15000, technology: 9),
    .init(name: "Galactic Hyperdrive", price: 50000, technology: 10),
    .init(name: "Mining Laser", price: 8000, technology: 10),
    .init(name: "Military Laser", price: 60000, technology: 10),
  ]
}

public struct Controls: Sendable {
  public var pitch: Double = 0
  public var roll: Double = 0
  public var throttle: Double = 0
  public var fire = false
  public init() {}
}

public struct Game: Sendable {
  public var commander = Commander()
  public var systems = Universe.galaxy()
  public var screen: Screen = .title
  public var paused = false
  public var docked = true
  public var selectedSystem = 7
  public var selection = 0
  public var market = MarketItem.generate(economy: 5, fluctuation: 0)
  public var bodies: [SpaceBody] = []
  public var speed = 0.0
  public var pitch = 0.0
  public var roll = 0.0
  public var energy = 256.0
  public var frontShield = 255.0
  public var rearShield = 255.0
  public var laserHeat = 0.0
  public var laserFlash = 0.0
  public var altitude = 1.0
  public var cabinTemperature = 0.0
  public var dockingComputer = false
  public var missileArmed = false
  public var message = ""
  public var messageTime = 0.0
  public var jumpCountdown: Double? = nil
  public var time = 0.0
  public var secretBuffer = ""
  public var secretReturn: Screen = .status
  private var fireCooldown = 0.0
  private var spawnClock = 0.0
  private var nextBodyID = 10
  private var randomState: UInt64 = 0x45_4c49_5445
  public init(executive: Bool = true) {
    if executive {
      commander = .firebud
      screen = .demo
    }
  }
  public var currentSystem: StarSystem { systems[commander.system] }
  public var targetSystem: StarSystem { systems[selectedSystem] }

  public mutating func notify(_ text: String) {
    message = text
    messageTime = 4
  }
  public mutating func load(_ value: Commander) -> Bool {
    guard value.valid else { return false }
    commander = value
    systems = Universe.galaxy(number: value.galaxy)
    selectedSystem = value.system
    market = MarketItem.generate(economy: currentSystem.economy, fluctuation: 0)
    docked = true
    bodies = []
    screen = .status
    return true
  }
  public mutating func key(_ raw: String) {
    let key = raw.lowercased()
    if key.count == 1 {
      secretBuffer = String((secretBuffer + key).suffix(5))
      if secretBuffer == "xyzzy" {
        secretReturn = screen
        screen = .secret
        selection = 0
        secretBuffer = ""
        return
      }
    }
    if screen == .secret {
      secretKey(key)
      return
    }
    if key == "copy" {
      paused.toggle()
      return
    }
    if paused {
      if key == "@" {
        commander.unlimitedJumps.toggle()
        commander.unlimitedFuel = commander.unlimitedJumps
      }
      if key == ":" { commander.speech.toggle() }
      if key == "escape" { paused = false }
      return
    }
    if screen == .demo { return }
    if screen == .title || screen == .gameOver {
      if key == " " || key == "return" {
        if screen == .gameOver { self = Game(executive: commander.executive) }
        screen = .status
      }
      return
    }
    if key.count == 1, let number = Int(key), (0...9).contains(number) {
      functionKey(number)
      return
    }
    switch key {
    case "up": selection = max(0, selection - 1)
    case "down":
      selection = min(
        (screen == .equipment ? Equipment.all.count : Commodity.all.count) - 1, selection + 1)
    case "left", "right":
      if screen == .chart || screen == .shortChart {
        selectNeighbour(direction: key == "left" ? -1 : 1)
      } else if screen == .buy || screen == .sell {
        trade(buy: key == "right")
      }
    case "return":
      if screen == .buy || screen == .sell { trade(buy: screen == .buy) }
      if screen == .equipment { purchase() }
    case "o": if screen == .chart || screen == .shortChart { selectedSystem = commander.system }
    case "d":
      if screen == .chart || screen == .shortChart {
        notify(
          String(format: "DISTANCE %.1f LIGHT YEARS", currentSystem.distance(to: targetSystem)))
      }
    case "h": beginHyperspace()
    case "g": galacticJump()
    case "j": inSystemJump()
    case "t": missileArmed = !docked && commander.missiles > 0
    case "u": missileArmed = false
    case "m": fireMissile()
    case "e": ecm()
    case "c":
      if !docked && commander.equipment.contains("Docking Computers") {
        dockingComputer = true
        screen = .front
      }
    case "p": dockingComputer = false
    case "tab": energyBomb()
    case "escape": escapePod()
    default: break
    }
  }
  private mutating func secretKey(_ key: String) {
    switch key {
    case "1":
      commander.equipment.insert("Docking Computers")
      notify("DOCKING COMPUTER FITTED")
    case "2":
      commander.equipment = Set(Equipment.all.map(\.name))
      commander.fuel = 70
      commander.missiles = 4
      energy = 256
      frontShield = 255
      rearShield = 255
      notify("MAXIMUM HARDWARE FITTED")
    case "3":
      commander.unlimitedMissiles.toggle()
      commander.missiles = 4
      notify("MISSILE SUPPLY UPDATED")
    case "4":
      commander.unlimitedFuel.toggle()
      if commander.unlimitedFuel { commander.fuel = 70 }
      notify("FUEL SUPPLY UPDATED")
    case "5":
      commander.unlimitedJumps.toggle()
      notify("HYPERSPACE RANGE UPDATED")
    case "6":
      commander.autoTrade.toggle()
      if commander.autoTrade { autoTrade() }
      notify("AUTO TRADE UPDATED")
    case "7":
      commander.speech.toggle()
      notify("SPEECH UPDATED")
    case "8":
      if commander.unlimitedCargo
        && commander.cargoTonnes > (commander.equipment.contains("Large Cargo Bay") ? 35 : 20)
      {
        notify("SELL EXCESS CARGO FIRST")
      } else {
        commander.unlimitedCargo.toggle()
        notify("CARGO CAPACITY UPDATED")
      }
    case "9":
      commander.unlimitedCash.toggle()
      notify("CASH UPDATED")
    case "escape", "return": screen = secretReturn
    default: break
    }
  }
  private mutating func functionKey(_ number: Int) {
    selection = 0
    switch number {
    case 0, 10: if docked { launch() } else { screen = .front }
    case 1: screen = docked ? .buy : .rear
    case 2: screen = docked ? .sell : .left
    case 3: screen = docked ? .equipment : .right
    case 4: screen = .chart
    case 5: screen = .shortChart
    case 6: screen = .system
    case 7: screen = .market
    case 8: screen = .status
    case 9: screen = .inventory
    default: break
    }
  }
  public mutating func selectNeighbour(direction: Int) {
    selectedSystem = (selectedSystem + direction + systems.count) % systems.count
  }
  public mutating func selectSystem(x: Int, y: Int) {
    selectedSystem =
      systems.min { left, right in
        let ld = pow(Double(left.x - x), 2) + pow(Double(left.y - y), 2)
        let rd = pow(Double(right.x - x), 2) + pow(Double(right.y - y), 2)
        return ld < rd
      }?.id ?? selectedSystem
  }
  public mutating func trade(buy: Bool) {
    guard docked, market.indices.contains(selection) else { return }
    let index = selection
    let item = market[index]
    if buy {
      guard item.quantity > 0, commander.availableCredits >= item.price,
        Commodity.all[index].unit != "t" || commander.cargoTonnes < commander.capacity
      else {
        notify("CANNOT BUY")
        return
      }
      if !commander.unlimitedCash { commander.credits -= item.price }
      commander.cargo[index] += 1
      market[index].quantity -= 1
    } else {
      guard commander.cargo[index] > 0 else {
        notify("NO CARGO")
        return
      }
      commander.credits = min(4_294_967_295, commander.credits + item.price)
      commander.cargo[index] -= 1
      market[index].quantity += 1
    }
  }
  public mutating func purchase() {
    guard docked, Equipment.all.indices.contains(selection) else { return }
    let item = Equipment.all[selection]
    let cost = item.name == "Fuel" ? (70 - commander.fuel) * item.price : item.price
    guard currentSystem.technology >= item.technology, commander.availableCredits >= cost else {
      notify("NOT AVAILABLE")
      return
    }
    if item.name == "Fuel" {
      commander.fuel = 70
    } else if item.name == "Missile" {
      guard commander.missiles < 4 else {
        notify("MISSILE RACK FULL")
        return
      }
      commander.missiles += 1
    } else {
      guard !commander.equipment.contains(item.name) else {
        notify("ALREADY FITTED")
        return
      }
      commander.equipment.insert(item.name)
    }
    if !commander.unlimitedCash { commander.credits -= cost }
    notify("EQUIPMENT FITTED")
  }
  /// Sells the hold, then buys the most profitable exports for a destination.
  /// Government changes route risk, while commodity prices follow Elite's economy rules.
  public mutating func autoTrade() {
    guard docked else { return }
    let oldSelection = selection
    for index in commander.cargo.indices where commander.cargo[index] > 0 {
      let (revenue, overflow) = commander.cargo[index].multipliedReportingOverflow(
        by: market[index].price)
      commander.credits =
        overflow
        ? 4_294_967_295 : min(4_294_967_295, commander.credits + min(revenue, 4_294_967_295))
      market[index].quantity += commander.cargo[index]
      commander.cargo[index] = 0
    }
    let refuelCost = (70 - commander.fuel) * Equipment.all[0].price
    if commander.unlimitedFuel {
      commander.fuel = 70
    } else if commander.availableCredits >= refuelCost {
      if !commander.unlimitedCash { commander.credits -= refuelCost }
      commander.fuel = 70
    }
    if selectedSystem == commander.system {
      let candidates = systems.filter {
        $0.id != commander.system
          && (commander.unlimitedJumps
            || currentSystem.distance(to: $0) <= Double(commander.fuel) / 10)
      }
      selectedSystem = candidates.max { routeScore($0) < routeScore($1) }?.id ?? commander.system
    }
    guard selectedSystem != commander.system else {
      notify("NO TRADE ROUTE")
      return
    }
    let exports = profitableExports(to: targetSystem)
    for item in exports {
      selection = item.index
      let unit = Commodity.all[item.index].unit
      let room = unit == "t" ? commander.capacity - commander.cargoTonnes : 63
      let affordable =
        market[item.index].price > 0 ? commander.availableCredits / market[item.index].price : 63
      let count = max(0, min(room, min(affordable, market[item.index].quantity)))
      if !commander.unlimitedCash { commander.credits -= count * market[item.index].price }
      commander.cargo[item.index] += count
      market[item.index].quantity -= count
    }
    selection = oldSelection
    notify("AUTO TRADE TO " + targetSystem.name)
  }
  public func profitableExports(to destination: StarSystem) -> [(index: Int, profit: Int)] {
    Commodity.all.indices.filter { $0 != 16 }.compactMap { index in
      let lowestSale = TradePlanner.minimumPrices[destination.economy][index]
      let profit = lowestSale - market[index].price
      return profit > 0 && market[index].quantity > 0 ? (index, profit) : nil
    }.sorted { $0.profit == $1.profit ? $0.index < $1.index : $0.profit > $1.profit }
  }
  private func routeScore(_ destination: StarSystem) -> Double {
    let exports = profitableExports(to: destination)
    let gross = exports.reduce(0) {
      $0 + $1.profit * min(commander.capacity, market[$1.index].quantity)
    }
    let risk = Double(7 - destination.government) * 0.15
    return Double(gross) / (1 + risk + currentSystem.distance(to: destination) * 0.05)
  }
  public mutating func launch() {
    docked = false
    screen = .front
    speed = 8
    dockingComputer = false
    bodies = [
      SpaceBody(id: 0, hull: .station, position: .init(0, 0, -500)),
      SpaceBody(id: 1, hull: .cobra, position: .init(90, 20, 1400)),
      SpaceBody(id: 2, hull: .asteroid, position: .init(-280, 100, 2200)),
    ]
    commander.legal |= commander.cargo[3] + 2 * commander.cargo[6] + commander.cargo[10]
    notify("LAUNCHING FROM " + currentSystem.name)
  }
  public mutating func dock() {
    docked = true
    screen = .status
    speed = 0
    dockingComputer = false
    bodies = []
    energy = 256
    frontShield = 255
    rearShield = 255
    laserHeat = 0
    jumpCountdown = nil
    missileArmed = false
    notify("DOCKED")
    if commander.autoTrade { autoTrade() }
  }
  public mutating func beginHyperspace() {
    guard !docked, jumpCountdown == nil, selectedSystem != commander.system else { return }
    let distance = currentSystem.distance(to: targetSystem)
    guard
      commander.unlimitedJumps
        || (distance <= 7
          && (commander.unlimitedFuel || Int((distance * 10).rounded()) <= commander.fuel))
    else {
      notify("FUEL TOO LOW")
      return
    }
    guard !massLocked else {
      notify("MASS LOCKED")
      return
    }
    jumpCountdown = 15
    notify("HYPERSPACE")
  }
  public var massLocked: Bool { bodies.contains { $0.hull != .cargo && $0.position.length < 600 } }
  public mutating func arrive() {
    let cost = Int((currentSystem.distance(to: targetSystem) * 10).rounded())
    if !commander.unlimitedFuel && !commander.unlimitedJumps {
      commander.fuel = max(0, commander.fuel - cost)
    }
    commander.system = selectedSystem
    market = MarketItem.generate(economy: currentSystem.economy, fluctuation: randomByte())
    jumpCountdown = nil
    screen = .front
    dockingComputer = false
    bodies = [
      SpaceBody(id: 0, hull: .station, position: .init(0, 0, 16000)),
      SpaceBody(
        id: 1, hull: .sidewinder, position: .init(80, 0, 2600),
        hostile: currentSystem.government < 4),
    ]
    altitude = 1
    notify(currentSystem.name)
  }
  public mutating func galacticJump() {
    guard !docked, commander.equipment.remove("Galactic Hyperdrive") != nil else { return }
    commander.galaxy = (commander.galaxy + 1) & 7
    systems = Universe.galaxy(number: commander.galaxy)
    selectedSystem = commander.system
    arrive()
    commander.fuel = 70
  }
  public mutating func inSystemJump() {
    guard !docked, !massLocked else {
      notify("MASS LOCKED")
      return
    }
    for index in bodies.indices { bodies[index].position.z -= 3000 }
  }
  public mutating func fireMissile() {
    guard !docked, missileArmed, commander.missiles > 0,
      let target = bodies.firstIndex(where: { $0.hull != .station && $0.position.z > 0 })
    else { return }
    if !commander.unlimitedMissiles { commander.missiles -= 1 }
    bodies[target].energy = 0
    missileArmed = false
    notify("MISSILE AWAY")
  }
  public mutating func ecm() {
    guard !docked, commander.equipment.contains("E.C.M. System"), energy > 10 else { return }
    bodies.removeAll { $0.hull == .missile }
    energy -= 10
    notify("E.C.M.")
  }
  public mutating func energyBomb() {
    guard !docked, commander.equipment.remove("Energy Bomb") != nil else { return }
    for index in bodies.indices where bodies[index].hull != .station { bodies[index].energy = 0 }
    notify("ENERGY BOMB")
  }
  public mutating func escapePod() {
    guard !docked, commander.equipment.remove("Escape Pod") != nil else { return }
    commander.cargo = Array(repeating: 0, count: 17)
    commander.legal = 0
    commander.fuel = 70
    dock()
  }
  private mutating func randomByte() -> Int {
    randomState = randomState &* 6_364_136_223_846_793_005 &+ 1
    return Int((randomState >> 32) & 255)
  }
  public mutating func tick(delta: Double, controls: Controls = Controls()) {
    guard delta.isFinite, delta > 0 else { return }
    let dt = min(delta, 0.1)
    if paused { return }
    time += dt
    if screen == .demo && time >= 12 {
      screen = .title
      time = 0
    }
    if commander.unlimitedFuel { commander.fuel = 70 }
    messageTime = max(0, messageTime - dt)
    laserFlash = max(0, laserFlash - dt)
    guard !docked, screen != .gameOver, screen != .secret else { return }
    speed = min(32, max(0, speed + controls.throttle * dt * 12))
    pitch = controls.pitch
    roll = controls.roll
    laserHeat = max(0, laserHeat - dt * 12)
    fireCooldown = max(0, fireCooldown - dt)
    energy = min(256, energy + dt * (commander.equipment.contains("Extra Energy Unit") ? 8 : 2))
    frontShield = min(255, frontShield + dt)
    rearShield = min(255, rearShield + dt)
    if controls.fire && screen.isFlight { fireLaser() }
    if let remaining = jumpCountdown {
      jumpCountdown = remaining - dt
      if remaining <= dt { arrive() }
    }
    moveBodies(dt: dt)
    resolveDestroyed()
    spawnClock += dt
    if spawnClock > 18 && bodies.count < (commander.executive ? 18 : 10) {
      spawnClock = 0
      spawn()
    }
    if energy <= 0 {
      screen = .gameOver
      notify("GAME OVER")
    } else if energy < 64 && messageTime <= 0 {
      notify("ENERGY LOW,SIR")
    }
  }
  private mutating func fireLaser() {
    guard fireCooldown <= 0, laserHeat < 240, energy > 1 else { return }
    fireCooldown =
      commander.equipment.contains("Beam Laser") || commander.equipment.contains("Military Laser")
      ? 0.1 : 0.3
    laserHeat += 10
    energy -= 1
    laserFlash = 0.08
    if let index = bodies.firstIndex(where: {
      let p = viewPosition($0.position)
      return $0.hull != .station && p.z > 0 && abs(p.x / p.z) < 0.06 && abs(p.y / p.z) < 0.06
    }) {
      bodies[index].energy -= commander.equipment.contains("Military Laser") ? 40 : 20
      bodies[index].hostile = true
    }
  }
  public func viewPosition(_ p: Vector3) -> Vector3 {
    switch screen {
    case .rear: return .init(-p.x, p.y, -p.z)
    case .left: return .init(p.z, p.y, -p.x)
    case .right: return .init(-p.z, p.y, p.x)
    default: return p
    }
  }
  private mutating func moveBodies(dt: Double) {
    for index in bodies.indices {
      bodies[index].position = bodies[index].position.rotated(pitch: pitch * dt, roll: roll * dt)
      bodies[index].position.z -= speed * dt * 18
      bodies[index].rotation += dt * (bodies[index].hull == .station ? 0.3 : 0.5)
      if bodies[index].hostile { enemyAction(index: index, dt: dt) }
    }
    if dockingComputer, let station = bodies.first(where: { $0.hull == .station }) {
      let step = station.position * min(1, dt * 0.5)
      for index in bodies.indices { bodies[index].position = bodies[index].position - step }
      if station.position.length < 220 {
        dock()
        return
      }
    }
    if let station = bodies.first(where: { $0.hull == .station }), station.position.length < 100 {
      if abs(station.position.x) < 25 && abs(station.position.y) < 20 && speed < 8
        && abs(roll) < 0.15
      {
        dock()
      } else {
        energy -= dt * 100
        notify("DOCKING COLLISION")
      }
    }
    bodies.removeAll { $0.position.length > 40000 }
  }
  private mutating func enemyAction(index: Int, dt: Double) {
    bodies[index].position.x *= 1 - dt * 0.25
    bodies[index].position.y *= 1 - dt * 0.25
    if bodies[index].position.z > 300 { bodies[index].position.z -= dt * 60 }
    if bodies[index].position.length < 1500 {
      let damage = dt * 12
      let unshielded = max(0, damage - frontShield)
      frontShield = max(0, frontShield - damage)
      energy -= unshielded * 2
    }
  }
  private mutating func resolveDestroyed() {
    let destroyed = bodies.filter { $0.energy <= 0 }
    for body in destroyed where body.hull != .cargo && body.hull != .asteroid {
      commander.kills += 1
      commander.credits += body.hostile ? 50 : 0
      if !body.hostile { commander.legal += 8 }
    }
    bodies.removeAll { $0.energy <= 0 }
  }
  private mutating func spawn() {
    let hostile = randomByte() & 7 > currentSystem.government
    let kind: Hull = hostile ? .sidewinder : .cobra
    bodies.append(
      SpaceBody(
        id: nextBodyID, hull: kind,
        position: .init(Double(randomByte() - 128) * 4, Double(randomByte() - 128) * 2, 5000),
        hostile: hostile))
    nextBodyID += 1
  }
}

public enum SaveError: Error { case invalidCommander }

/// Owns all mutable simulation state. Rendering consumes value snapshots only.
public actor GameRuntime {
  private var game: Game
  private var controls = Controls()
  public init(game: Game = Game()) { self.game = game }
  public func snapshot() -> Game { game }
  public func key(_ key: String) { game.key(key) }
  public func setControls(_ value: Controls) { controls = value }
  public func selectSystem(x: Int, y: Int) { game.selectSystem(x: x, y: y) }
  public func advance(delta: Double) -> Game {
    game.tick(delta: delta, controls: controls)
    return game
  }
  public func save(to url: URL) throws {
    guard game.commander.valid else { throw SaveError.invalidCommander }
    let data = try JSONEncoder().encode(game.commander)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
  }
  public func load(from url: URL) throws {
    let data = try Data(contentsOf: url)
    guard data.count < 65536 else { throw SaveError.invalidCommander }
    let commander = try JSONDecoder().decode(Commander.self, from: data)
    guard game.load(commander) else { throw SaveError.invalidCommander }
  }
}

public enum TradePlanner {
  /// Conservative selling prices account for every possible market fluctuation.
  public static let minimumPrices: [[Int]] = (0..<8).map { economy in
    var prices = Array(repeating: Int.max, count: Commodity.all.count)
    for fluctuation in 0..<256 {
      let market = MarketItem.generate(economy: economy, fluctuation: fluctuation)
      for index in prices.indices { prices[index] = min(prices[index], market[index].price) }
    }
    return prices
  }
}
