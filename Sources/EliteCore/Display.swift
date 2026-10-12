import Foundation

public enum Ink: UInt32, Sendable {
  case black = 0x0000_00ff
  case white = 0xffff_ffff
  case yellow = 0xffff_00ff
  case red = 0xff00_00ff
  case green = 0x00ff_00ff
  case cyan = 0x00ff_ffff
}

public struct WireLine: Sendable, Equatable {
  public let x0: Double
  public let y0: Double
  public let x1: Double
  public let y1: Double
}

public struct Frame: Sendable, Equatable {
  public var rasterizeShips = true
  public var shipLines: [WireLine] = []
  public static let width = 256
  public static let height = 256
  public var pixels = [UInt32](repeating: Ink.black.rawValue, count: width * height)
  public init() {}
  public mutating func pixel(_ x: Int, _ y: Int, _ ink: Ink = .white) {
    guard (0..<Self.width).contains(x), (0..<Self.height).contains(y) else { return }
    pixels[y * Self.width + x] = ink.rawValue
  }
  public mutating func line(
    _ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ ink: Ink = .white, clipTop: Int = 0,
    clipBottom: Int = 255
  ) {
    // Clip first, keeping enormous projected coordinates out of the raster loop.
    guard
      let ends = clipped(
        Double(x0), Double(y0), Double(x1), Double(y1), Double(clipTop), Double(clipBottom))
    else { return }
    var x = Int(ends.0.rounded())
    var y = Int(ends.1.rounded())
    let tx = Int(ends.2.rounded())
    let ty = Int(ends.3.rounded())
    let dx = abs(tx - x)
    let dy = -abs(ty - y)
    let sx = x < tx ? 1 : -1
    let sy = y < ty ? 1 : -1
    var error = dx + dy
    while true {
      pixel(x, y, ink)
      if x == tx && y == ty { break }
      let twice = error * 2
      if twice >= dy {
        error += dy
        x += sx
      }
      if twice <= dx {
        error += dx
        y += sy
      }
    }
  }
  private func clipped(
    _ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ top: Double, _ bottom: Double
  ) -> (Double, Double, Double, Double)? {
    var start = 0.0
    var end = 1.0
    let dx = x1 - x0
    let dy = y1 - y0
    for (p, q) in [(-dx, x0), (dx, 255 - x0), (-dy, y0 - top), (dy, bottom - y0)] {
      if p == 0 {
        if q < 0 { return nil }
        continue
      }
      let fraction = q / p
      if p < 0 { start = max(start, fraction) } else { end = min(end, fraction) }
      if start > end { return nil }
    }
    return (x0 + start * dx, y0 + start * dy, x0 + end * dx, y0 + end * dy)
  }
  public mutating func wire(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) {
    guard let ends = clipped(x0, y0, x1, y1, 12, 175) else { return }
    shipLines.append(WireLine(x0: ends.0, y0: ends.1, x1: ends.2, y1: ends.3))
    if rasterizeShips {
      line(
        Int(ends.0.rounded()), Int(ends.1.rounded()), Int(ends.2.rounded()), Int(ends.3.rounded()),
        clipTop: 12, clipBottom: 175)
    }
  }
  public mutating func box(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ ink: Ink = .white) {
    line(x, y, x + w, y, ink)
    line(x + w, y, x + w, y + h, ink)
    line(x + w, y + h, x, y + h, ink)
    line(x, y + h, x, y, ink)
  }
  public mutating func ellipse(_ x: Int, _ y: Int, _ rx: Int, _ ry: Int, _ ink: Ink = .white) {
    var previous = (x + rx, y)
    for step in 1...96 {
      let angle = Double(step) * .pi / 48
      let next = (x + Int(Double(rx) * cos(angle)), y + Int(Double(ry) * sin(angle)))
      line(previous.0, previous.1, next.0, next.1, ink)
      previous = next
    }
  }
  public mutating func text(_ text: String, _ x: Int, _ y: Int, _ ink: Ink = .white) {
    for (index, character) in text.uppercased().enumerated() {
      let rows = Glyph.rows(character)
      for row in 0..<7 {
        for col in 0..<5 where rows[row] & (1 << (4 - col)) != 0 {
          pixel(x + index * 6 + col, y + row, ink)
        }
      }
    }
  }
  public mutating func centered(_ text: String, _ y: Int, _ ink: Ink = .white) {
    self.text(text, (256 - text.count * 6) / 2, y, ink)
  }
}

private enum Glyph {
  static let table: [Character: String] = [
    "A": "0E11111F111111", "B": "1E11111E11111E", "C": "0E11101010110E", "D": "1E11111111111E",
    "E": "1F10101E10101F", "F": "1F10101E101010", "G": "0E11101711110F", "H": "1111111F111111",
    "I": "0E04040404040E", "J": "0702020212120C", "K": "11121418141211", "L": "1010101010101F",
    "M": "111B1515111111", "N": "11191513111111", "O": "0E11111111110E", "P": "1E11111E101010",
    "Q": "0E11111115120D", "R": "1E11111E141211", "S": "0F10100E01011E", "T": "1F040404040404",
    "U": "1111111111110E", "V": "11111111110A04", "W": "11111115151B11", "X": "11110A040A1111",
    "Y": "11110A04040404", "Z": "1F01020408101F", "0": "0E11131519110E", "1": "040C040404040E",
    "2": "0E11010204081F", "3": "1F01020601110E", "4": "02060A121F0202", "5": "1F10101E01011E",
    "6": "0E10101E11110E", "7": "1F010204080808", "8": "0E11110E11110E", "9": "0E11110F01010E",
    ".": "00000000000C0C", ",": "00000000000408", ":": "000C0C000C0C00", ";": "000C0C00040408",
    "-": "0000001F000000", "/": "01010204081010", "?": "0E110102040004", "!": "04040404040004",
    "(": "02040808080402", ")": "08040202020408", "+": "0004041F040400", "=": "00001F001F0000",
    "<": "01020408040201", ">": "10080402040810", "*": "00150E1F0E1500", "'": "04040800000000",
  ]
  static let decoded: [Character: [UInt8]] = table.mapValues { string in
    let chars = Array(string)
    return stride(from: 0, to: 14, by: 2).map {
      UInt8(String(chars[$0...($0 + 1)]), radix: 16) ?? 0
    }
  }
  static func rows(_ char: Character) -> [UInt8] { decoded[char] ?? Array(repeating: 0, count: 7) }
}

public enum Display {
  public static func render(_ game: Game, rasterizeShips: Bool = true) -> Frame {
    var frame = Frame()
    frame.rasterizeShips = rasterizeShips
    switch game.screen {
    case .demo: demo(game, into: &frame)
    case .title: title(game, into: &frame)
    case .front, .rear, .left, .right: flight(game, into: &frame)
    case .chart, .shortChart: chart(game, into: &frame)
    case .system: system(game, into: &frame)
    case .market, .buy, .sell: market(game, into: &frame)
    case .equipment: equipment(game, into: &frame)
    case .status: status(game, into: &frame)
    case .inventory: inventory(game, into: &frame)
    case .secret: secret(game, into: &frame)
    case .gameOver:
      frame.centered("GAME OVER", 85)
      frame.centered("PRESS SPACE COMMANDER", 130)
    }
    if game.screen != .title && game.screen != .demo { dashboard(game, into: &frame) }
    if game.messageTime > 0 && game.screen != .secret { frame.centered(game.message, 178) }
    if game.paused { frame.centered("PAUSED", 168) }
    return frame
  }
  private static func header(_ title: String, into frame: inout Frame) {
    frame.centered(title, 8)
    frame.line(0, 20, 255, 20)
  }
  private static func title(_ game: Game, into frame: inout Frame) {
    frame.centered("E L I T E", 22)
    // Keep the complete rotating hull between the title and version text.
    var ship = SpaceBody(id: 0, hull: .cobra, position: .init(0, 0, 280))
    ship.rotation = game.time * 0.6
    draw(ship, game: game, into: &frame)
    frame.centered(
      game.commander.executive ? "THE EXECUTIVE VERSION" : "BBC MICRO DISC EDITION", 163)
    frame.centered("PRESS SPACE COMMANDER", 190)
    frame.centered("SWIFT MACOS REIMPLEMENTATION", 224)
  }
  private static func demo(_ game: Game, into frame: inout Frame) {
    var demonstration = game
    demonstration.bodies = [
      SpaceBody(id: 0, hull: .cobra, position: .init(-70, 20, 450)),
      SpaceBody(id: 1, hull: .thargoid, position: .init(80, -15, 600)),
    ]
    for index in demonstration.bodies.indices {
      demonstration.bodies[index].rotation = game.time * 0.7
    }
    for body in demonstration.bodies { draw(body, game: demonstration, into: &frame) }
    let lines = [
      "PIZZASOFT PRESENTS", "THE EXECUTIVE VERSION", "WELCOME COMMANDER FIREBUD",
      "THE GALAXY AWAITS", "FLY. TRADE. SURVIVE.",
    ]
    for (index, line) in lines.enumerated() {
      let y = 250 + index * 24 - Int(game.time * 22)
      if (0..<250).contains(y) { frame.centered(line, y) }
    }
  }
  private static func flight(_ game: Game, into frame: inout Frame) {
    frame.centered(game.screen.rawValue + " VIEW", 4)
    for index in 0..<40 {
      let z = Double((index * 137) % 3000 + 100)
      let motion = Int(game.time * game.speed * 10 / z * 80)
      let x = ((index * 73 + motion) % 254) + 1
      let y = ((index * 47 + motion) % 162) + 14
      frame.pixel(x, y)
      if game.speed > 20 { frame.line(x, y, x + 1, y + 2) }
    }
    if game.screen == .front {
      frame.ellipse(192, 55, 35, 35)
      frame.ellipse(192, 55, 12, 34)
      frame.line(157, 55, 227, 55)
    }
    for body in game.bodies.sorted(by: { $0.position.length > $1.position.length }) {
      draw(body, game: game, into: &frame)
    }
    frame.line(121, 96, 125, 96)
    frame.line(131, 96, 135, 96)
    frame.line(128, 89, 128, 93)
    frame.line(128, 99, 128, 103)
    if game.laserFlash > 0 {
      frame.line(0, 190, 126, 98)
      frame.line(255, 190, 130, 98)
    }
    if let countdown = game.jumpCountdown {
      frame.centered("HYPERSPACE " + String(Int(ceil(countdown))), 156)
      for ring in 0..<6 {
        let radius = (Int(game.time * 90) + ring * 20) % 128
        frame.ellipse(128, 96, radius, max(1, radius / 2))
      }
    }
    if game.dockingComputer { frame.centered("DOCKING COMPUTERS ON", 164) }
  }
  private static func draw(_ body: SpaceBody, game: Game, into frame: inout Frame) {
    let center = game.viewPosition(body.position)
    guard center.z > 10 else { return }
    let mesh = Mesh.hull(body.hull)
    let vertices = mesh.vertices.map { vertex -> Vector3 in
      let rotated = vertex.rotated(pitch: body.rotation * 0.4, roll: body.rotation)
      return rotated + center
    }
    var drawn: Set<String> = []
    for face in mesh.faces {
      let a = vertices[face[0]]
      let b = vertices[face[1]]
      let c = vertices[face[2]]
      guard (b - a).cross(c - a).dot(a) < 0 else { continue }
      for edge in face.indices {
        let i = face[edge]
        let j = face[(edge + 1) % face.count]
        let token = "\(min(i,j)):\(max(i,j))"
        guard drawn.insert(token).inserted, let points = project(vertices[i], vertices[j]) else {
          continue
        }
        // The viewport ends above the colour dashboard.
        frame.wire(points.0, points.1, points.2, points.3)
      }
    }
    if body.hull == .station {
      let size = Int(256 * 30 / center.z)
      let x = Int(128 + center.x * 256 / center.z)
      let y = Int(96 - center.y * 256 / center.z)
      if (12..<170).contains(y), size < 100 {
        frame.box(x - size, y - size / 3, size * 2, max(2, size * 2 / 3))
      }
    }
  }
  public static func project(_ start: Vector3, _ end: Vector3) -> (Double, Double, Double, Double)?
  {
    var a = start
    var b = end
    guard a.z >= 1 || b.z >= 1 else { return nil }
    if a.z < 1 { a = a + (b - a) * ((1 - a.z) / (b.z - a.z)) }
    if b.z < 1 { b = b + (a - b) * ((1 - b.z) / (a.z - b.z)) }
    let coordinates = [
      128 + a.x * 256 / a.z, 96 - a.y * 256 / a.z, 128 + b.x * 256 / b.z, 96 - b.y * 256 / b.z,
    ]
    guard coordinates.allSatisfy({ $0.isFinite && abs($0) < 1_000_000 }) else { return nil }
    return (coordinates[0], coordinates[1], coordinates[2], coordinates[3])
  }
  private static func chart(_ game: Game, into frame: inout Frame) {
    let local = game.screen == .shortChart
    header(local ? "SHORT RANGE CHART" : "GALACTIC CHART \(game.commander.galaxy+1)", into: &frame)
    let current = game.currentSystem
    for star in game.systems {
      let x = local ? 128 + (star.x - current.x) * 4 : star.x
      let y = local ? 90 + (star.y - current.y) * 2 : 30 + star.y / 2
      guard (22..<160).contains(y), (1..<255).contains(x) else { continue }
      frame.pixel(x, y)
      if local { frame.text(star.name, x + 3, y - 7) }
      if star.id == game.selectedSystem {
        frame.line(x - 4, y, x + 4, y)
        frame.line(x, y - 4, x, y + 4)
      }
    }
    let x = local ? 128 : current.x
    let y = local ? 90 : 30 + current.y / 2
    let radius = local ? game.commander.fuel : game.commander.fuel / 4
    frame.ellipse(x, y, radius, max(1, radius / 2))
    frame.text(game.targetSystem.name, 4, 162)
    frame.text(
      String(format: "DISTANCE %.1f LIGHT YEARS", current.distance(to: game.targetSystem)), 4, 172)
  }
  private static func system(_ game: Game, into frame: inout Frame) {
    let star = game.targetSystem
    header("DATA ON " + star.name, into: &frame)
    let lines = [
      star.economyName, star.governmentName, "TECH.LEVEL \(star.technology+1)",
      String(format: "POPULATION %.1f BILLION", Double(star.population) / 10),
      "GROSS PRODUCTIVITY \(star.productivity) MCR", "AVERAGE RADIUS \(star.radius) KM",
    ]
    for (i, line) in lines.enumerated() { frame.text(line, 8, 30 + i * 16) }
    if game.commander.executive && game.docked {
      if star.name == "LAVE" { frame.text("EXECUTIVE EDITION HOME PORT", 8, 150) }
      if star.name == "RIEDQUAT" { frame.text("PAUSE AND @: INFINITE RANGE", 8, 150) }
    }
  }
  private static func market(_ game: Game, into frame: inout Frame) {
    let marketTitle = game.screen == .sell ? "SELL CARGO" : "MARKET PRICES"
    header(game.screen == .buy ? "BUY CARGO" : marketTitle, into: &frame)
    frame.text("PRODUCT       PRICE STOCK HOLD", 4, 24)
    for (i, item) in Commodity.all.enumerated() {
      let y = 34 + i * 8
      if i == game.selection { frame.text(">", 0, y) }
      frame.text(item.name, 8, y)
      frame.text(String(format: "%5.1f", Double(game.market[i].price) / 10), 100, y)
      frame.text("\(game.market[i].quantity)\(item.unit)", 154, y)
      frame.text("\(game.commander.cargo[i])\(item.unit)", 205, y)
    }
    frame.text(
      game.commander.unlimitedCash
        ? "CASH UNLIMITED" : String(format: "CASH %.1f CR", Double(game.commander.credits) / 10), 8,
      174)
  }
  private static func equipment(_ game: Game, into frame: inout Frame) {
    header("EQUIP SHIP", into: &frame)
    for (i, item) in Equipment.all.enumerated() {
      let y = 30 + i * 10
      if i == game.selection { frame.text(">", 0, y) }
      let available = item.technology <= game.currentSystem.technology
      frame.text(item.name, 8, y, available ? .white : .red)
      frame.text(
        game.commander.equipment.contains(item.name)
          ? "FITTED" : String(format: "%.1f", Double(item.price) / 10), 194, y)
    }
    frame.text(
      game.commander.unlimitedCash
        ? "CASH UNLIMITED" : String(format: "CASH %.1f CR", Double(game.commander.credits) / 10), 8,
      176)
  }
  private static func status(_ game: Game, into frame: inout Frame) {
    header("COMMANDER " + game.commander.name, into: &frame)
    let criminalStatus = game.commander.legal < 50 ? "OFFENDER" : "FUGITIVE"
    let legal = game.commander.legal == 0 ? "CLEAN" : criminalStatus
    let lines =
      [
        "PRESENT SYSTEM: " + game.currentSystem.name, "HYPERSPACE: " + game.targetSystem.name,
        "CONDITION: " + (game.docked ? "DOCKED" : "GREEN"),
        String(format: "FUEL: %.1f LIGHT YEARS", Double(game.commander.fuel) / 10),
        game.commander.unlimitedCash
          ? "CASH: UNLIMITED"
          : String(format: "CASH: %.1f CR", Double(game.commander.credits) / 10),
        "LEGAL STATUS: " + legal,
        "RATING: " + game.commander.rank, "EQUIPMENT:",
      ] + game.commander.equipment.sorted().filter { !["Fuel", "Missile"].contains($0) }
    for (i, line) in lines.prefix(16).enumerated() { frame.text(line, 8, 30 + i * 9) }
  }
  private static func inventory(_ game: Game, into frame: inout Frame) {
    header("INVENTORY", into: &frame)
    frame.text(
      game.commander.unlimitedCargo
        ? "CARGO: UNLIMITED CAPACITY"
        : "CARGO \(game.commander.cargoTonnes)/\(game.commander.capacity) TONNES", 8, 30)
    var row = 0
    for (i, quantity) in game.commander.cargo.enumerated() where quantity > 0 {
      frame.text(Commodity.all[i].name, 8, 48 + row * 8)
      frame.text("\(quantity) \(Commodity.all[i].unit)", 180, 48 + row * 8)
      row += 1
    }
  }
  private static func secret(_ game: Game, into frame: inout Frame) {
    header("XYZZY", into: &frame)
    frame.centered("A HOLLOW VOICE SAYS...", 28)
    let choices = [
      "1 DOCKING COMPUTER",
      "2 MAXIMUM HARDWARE",
      "3 MISSILES: " + (game.commander.unlimitedMissiles ? "UNLIMITED" : "NORMAL"),
      "4 FUEL: " + (game.commander.unlimitedFuel ? "UNLIMITED" : "NORMAL"),
      "5 JUMPS: " + (game.commander.unlimitedJumps ? "UNLIMITED" : "NORMAL"),
      "6 AUTO TRADE: " + (game.commander.autoTrade ? "ON" : "OFF"),
      "7 SPEECH: " + (game.commander.speech ? "ON" : "OFF"),
      "8 CARGO: " + (game.commander.unlimitedCargo ? "UNLIMITED" : "NORMAL"),
      "9 CASH: " + (game.commander.unlimitedCash ? "UNLIMITED" : "NORMAL"),
    ]
    for (index, choice) in choices.enumerated() { frame.text(choice, 10, 46 + index * 13) }
    frame.text("RETURN TO RESUME", 10, 177)
  }
  private static func dashboard(_ game: Game, into frame: inout Frame) {
    frame.box(0, 191, 255, 64, .yellow)
    frame.line(76, 192, 76, 255, .yellow)
    frame.line(180, 192, 180, 255, .yellow)
    let left: [(String, Double, Ink)] = [
      ("FS", game.frontShield / 255, .green), ("AS", game.rearShield / 255, .green),
      ("FU", Double(game.commander.fuel) / 70, .green), ("CT", game.cabinTemperature, .red),
      ("LT", game.laserHeat / 255, .red), ("AL", game.altitude, .yellow),
    ]
    for (i, item) in left.enumerated() {
      let y = 196 + i * 9
      frame.text(item.0, 3, y, .yellow)
      bar(&frame, 24, y, item.1, item.2, 46)
    }
    let right: [(String, Double)] = [
      ("SP", game.speed / 32), ("RL", (game.roll + 1) / 2), ("DC", (game.pitch + 1) / 2),
    ]
    for (i, item) in right.enumerated() {
      frame.text(item.0, 184, 196 + i * 9, .yellow)
      bar(&frame, 201, 196 + i * 9, item.1, .green, 48)
    }
    for i in 0..<4 {
      bar(&frame, 201, 225 + i * 7, (game.energy - Double(i * 64)) / 64, .yellow, 48)
    }
    frame.ellipse(128, 220, 46, 20, .green)
    frame.line(82, 220, 174, 220, .green)
    frame.line(128, 200, 128, 240, .green)
    for body in game.bodies {
      let sx = 128 + Int(max(-44, min(44, body.position.x / 100)))
      let sy = 220 + Int(max(-17, min(17, -body.position.z / 500)))
      let height = Int(max(-15, min(15, body.position.y / 100)))
      frame.line(sx, sy, sx, sy - height, body.hostile ? .red : .green)
      frame.line(sx - 1, sy - height, sx + 1, sy - height, body.hostile ? .red : .green)
    }
    let flightCondition = game.bodies.contains(where: \.hostile) ? "RED" : "GREEN"
    frame.text(game.docked ? "S" : flightCondition, 82, 246, .yellow)
    frame.text(
      String(repeating: "M", count: game.commander.missiles), 134, 246,
      game.missileArmed ? .red : .green)
    frame.ellipse(166, 201, 6, 6, .yellow)
  }
  private static func bar(
    _ frame: inout Frame, _ x: Int, _ y: Int, _ value: Double, _ ink: Ink, _ width: Int
  ) {
    let count = Int(max(0, min(1, value)) * Double(width))
    if count > 0 { for row in 0..<4 { frame.line(x, y + row, x + count - 1, y + row, ink) } }
  }
}
