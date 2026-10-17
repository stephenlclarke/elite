import Foundation

public enum Ink: UInt32, Sendable {
  case black = 0x0000_00ff
  case white = 0xffff_ffff
  case yellow = 0xffff_00ff
  case red = 0xff00_00ff
  case green = 0x00ff_00ff
  case cyan = 0x00ff_ffff
  case blue = 0x4488_ffff
  case redOrange = 0xff66_22ff
  case gold = 0xffcc_22ff
  case lime = 0xccee_22ff
  case leaf = 0x66ee_44ff
  case orange = 0xffaa_44ff
}

public struct WireLine: Sendable, Equatable {
  public let x0: Double
  public let y0: Double
  public let x1: Double
  public let y1: Double
  public let ink: Ink
}

public struct Frame: Sendable, Equatable {
  public var inventoryInteraction: InventoryInteraction?
  public var rasterizeGraphics = true
  public var graphics: [Graphic] = []
  public var worldGraphics: [Graphic] = []
  public var labels: [BitmapLabel] = []
  public var canvas = CanvasRect(x: 0, y: 0, width: 256, height: 256)
  public var flightClip = CanvasRect(x: 0, y: 12, width: 256, height: 164)
  public var responsive = false
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
    clipBottom: Int? = nil
  ) {
    // Clip first, keeping enormous projected coordinates out of the raster loop.
    guard
      let ends = clipped(
        Double(x0), Double(y0), Double(x1), Double(y1), Double(clipTop),
        Double(clipBottom ?? Int(canvas.maxY - 1)), horizontal: canvas.x...(canvas.maxX - 1))
    else { return }
    graphics.append(.line(WireLine(x0: ends.0, y0: ends.1, x1: ends.2, y1: ends.3, ink: ink)))
    if rasterizeGraphics { rasterLine(ends, ink) }
  }
  private mutating func rasterLine(_ ends: (Double, Double, Double, Double), _ ink: Ink) {
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
    _ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ top: Double, _ bottom: Double,
    horizontal: ClosedRange<Double> = 0...255
  ) -> (Double, Double, Double, Double)? {
    var start = 0.0
    var end = 1.0
    let dx = x1 - x0
    let dy = y1 - y0
    for (p, q) in [
      (-dx, x0 - horizontal.lowerBound), (dx, horizontal.upperBound - x0), (-dy, y0 - top),
      (dy, bottom - y0),
    ] {
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
  public mutating func wire(
    _ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ ink: Ink = .white
  ) {
    guard
      let ends = clipped(
        x0, y0, x1, y1, flightClip.y, flightClip.maxY - 1,
        horizontal: flightClip.x...(flightClip.maxX - 1))
    else { return }
    graphics.append(.wire(WireLine(x0: ends.0, y0: ends.1, x1: ends.2, y1: ends.3, ink: ink)))
    if rasterizeGraphics { rasterLine(ends, ink) }
  }
  public mutating func box(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ ink: Ink = .white) {
    line(x, y, x + w, y, ink)
    line(x + w, y, x + w, y + h, ink)
    line(x + w, y + h, x, y + h, ink)
    line(x, y + h, x, y, ink)
  }
  public mutating func ellipse(
    _ x: Double, _ y: Double, _ rx: Double, _ ry: Double, _ ink: Ink = .white
  ) {
    graphics.append(
      .ellipse(center: ScreenPoint(x, y), radiusX: rx, radiusY: ry, ink: ink))
    guard rasterizeGraphics else { return }
    var previous = (x + rx, y)
    for step in 1...96 {
      let angle = Double(step) * .pi / 48
      let next = (x + rx * cos(angle), y + ry * sin(angle))
      if let ends = clipped(previous.0, previous.1, next.0, next.1, 0, 255) {
        rasterLine(ends, ink)
      }
      previous = next
    }
  }
  public mutating func text(_ text: String, _ x: Int, _ y: Int, _ ink: Ink = .white) {
    for (index, character) in text.uppercased().enumerated() {
      let rows = BitmapFont.rows(character)
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

public enum BitmapFont {
  private static let table: [Character: String] = [
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
    "~": "00000D12000000", "[": "0E08080808080E", "]": "0E02020202020E", "%": "11120408120911",
    "<": "01020408040201", ">": "10080402040810", "*": "00150E1F0E1500", "'": "04040800000000",
  ]
  private static let decoded: [Character: [UInt8]] = table.mapValues { string in
    let chars = Array(string)
    return stride(from: 0, to: 14, by: 2).map {
      UInt8(String(chars[$0...($0 + 1)]), radix: 16) ?? 0
    }
  }
  public static func rows(_ char: Character) -> [UInt8] {
    decoded[char] ?? Array(repeating: 0, count: 7)
  }
}

public enum Display {
  public static func render(_ game: Game, rasterizeGraphics: Bool = true, dashboard: Bool = true)
    -> Frame
  {
    var frame = Frame()
    frame.rasterizeGraphics = rasterizeGraphics
    switch game.screen {
    case .demo: demo(game, into: &frame)
    case .title: title(game, into: &frame)
    case .front, .rear, .left, .right: flight(game, into: &frame)
    case .chart, .shortChart: chart(game, into: &frame)
    case .system: return systemScreen(game, width: 768, height: 768)
    case .market, .buy, .sell: market(game, into: &frame)
    case .rumour: return compactScreen(game, width: 768, height: 768)
    case .showroom: return showroomScreen(game, width: 768, height: 768)
    case .equipment: equipment(game, into: &frame)
    case .status: status(game, into: &frame)
    case .inventory: inventory(game, into: &frame)
    case .handoff: return blackjackHandoff(game, width: 768, height: 768)
    case .secret: secret(game, into: &frame)
    case .help: help(game, into: &frame)
    case .library: return referenceLibrary(game, width: 768, height: 768)
    case .gallery: return gallery(game, width: 768, height: 768)
    case .contracts: return contractBoard(game, width: 768, height: 768)
    case .navigation: return navigation(game, width: 768, height: 768)
    case .mission: mission(game, into: &frame)
    case .gameOver:
      frame.centered("GAME OVER", 85)
      frame.centered("PRESS SPACE COMMANDER", 130)
    }
    if dashboard && ![Screen.title, .demo, .help].contains(game.screen) {
      Self.dashboard(game, into: &frame)
    }
    if game.messageTime > 0 && ![Screen.secret, .help, .mission].contains(game.screen) {
      frame.centered(game.message, 178)
    }
    if game.paused && ![Screen.help, .mission, .secret].contains(game.screen) {
      frame.centered("PAUSED: COMMAND-P TO RESUME", game.screen == .title ? 208 : 168)
    }
    if dashboard && game.screen != .help { frame.text("K:HELP", 216, 184, .cyan) }
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
    frame.centered("RIGHT-ON COMMANDER VERSION", 163)
    frame.centered("PRESS SPACE COMMANDER", 190)
    frame.centered(BuildIdentity.current.versionLine, 208)
    frame.centered(BuildIdentity.repository, 218)
    for (index, line) in BuildIdentity.current.legacyRevisionLines.enumerated() {
      frame.centered(line, 230 + index * 10)
    }
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
    let lines =
      [
        "XYZZY PRESENTS", "RIGHT-ON COMMANDER VERSION", "WELCOME COMMANDER " + game.commander.name,
        "THE GALAXY AWAITS", "FLY. TRADE. SURVIVE.",
        BuildIdentity.current.versionLine, BuildIdentity.repository,
      ] + BuildIdentity.current.legacyRevisionLines

    let speed = Double(250 + lines.count * 24) / 11
    for (index, line) in lines.enumerated() {
      let y = 250 + index * 24 - Int(game.time * speed)
      if (0..<250).contains(y) { frame.centered(line, y) }
    }
  }
  private static func flight(_ game: Game, into frame: inout Frame) {
    frame.centered(game.screen.rawValue + " VIEW", 4)
    spaceScene(game, projection: .legacy, into: &frame)
    if let countdown = game.jumpCountdown {
      frame.centered("HYPERSPACE " + String(Int(ceil(countdown))), 156)
    }
    if game.dockingComputer { frame.centered("DOCKING COMPUTERS ON", 164) }
    for (index, line) in game.spin.hudLines.enumerated() {
      frame.text(line, 8, 138 + index * 8, .cyan)
    }
  }
  static func spaceScene(_ game: Game, projection: FlightProjection, into frame: inout Frame) {
    for star in game.starfield.positions {
      let position = game.viewPosition(star)
      guard position.z > 100 else { continue }
      let point = projection.point(position)
      guard frame.flightClip.contains(point), frame.responsive || (point.y >= 13 && point.y <= 174)
      else { continue }
      let proximity = max(0, 1 - position.length / 9000)
      let fade = min(1, (position.length - 300) / 300)
      let radius = frame.responsive ? 0.65 + proximity * 0.45 : 0.18 + proximity * 0.14
      frame.point(point.x, point.y, radius: radius, opacity: (0.5 + proximity * 0.45) * fade)
    }
    flightObjects(game, projection: projection, into: &frame)
    let x = projection.center.x
    let y = projection.center.y
    let size = frame.responsive ? 1.5 : 1.0
    for (a, b, c, d) in [
      (x - 7 * size, y, x - 3 * size, y), (x + 3 * size, y, x + 7 * size, y),
      (x, y - 7 * size, x, y - 3 * size), (x, y + 3 * size, x, y + 7 * size),
    ] {
      frame.graphics.append(.line(WireLine(x0: a, y0: b, x1: c, y1: d, ink: .white)))
    }
    if game.laserFlash > 0 {
      frame.graphics.append(
        .line(WireLine(x0: 0, y0: frame.flightClip.maxY, x1: x - 2, y1: y, ink: .white)))
      frame.graphics.append(
        .line(
          WireLine(x0: frame.canvas.width, y0: frame.flightClip.maxY, x1: x + 2, y1: y, ink: .white)
        ))
    }
    if game.jumpCountdown != nil {
      for ring in 0..<6 {
        let radius =
          (game.time * 90 + Double(ring * 20)).truncatingRemainder(dividingBy: 128)
          * projection.focal / 256
        frame.ellipse(x, y, radius, max(1, radius / 2))
      }
    }
  }
  static func draw(
    _ body: SpaceBody, game: Game, into frame: inout Frame, projection: FlightProjection = .legacy,
    mesh: Mesh? = nil
  ) {
    var game = game
    if game.screen == .demo || game.screen == .title {
      game.commander.shipDisplayStyle = .shadedPanels
    }
    let center = game.viewPosition(body.position)
    let mesh = mesh ?? game.scriptNPCMesh(body) ?? game.gameplayMesh(for: body)
    let vertices = mesh.vertices.map { vertex -> Vector3 in
      let rotated = game.viewPosition(body.modelVector(vertex))
      return rotated + center
    }
    guard vertices.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }),
      vertices.contains(where: { $0.z >= 1 })
    else { return }
    var drawn: Set<String> = []
    var visibleFaces: Set<Int> = []
    let depths = mesh.faces.enumerated().map { index, face -> (index: Int, distance: Double) in
      let sum = face.reduce(0.0) { total, index in total + vertices[index].z }
      return (index, sum / Double(face.count))
    }
    for entry in depths.sorted(by: { $0.distance > $1.distance }) {
      let face = mesh.faces[entry.index]
      let a = vertices[face[0]]
      let b = vertices[face[1]]
      let c = vertices[face[2]]
      let normal = (b - a).cross(c - a)
      guard normal.dot(a) < 0 else { continue }
      visibleFaces.insert(entry.index)
      if game.commander.shipDisplayStyle == .shadedPanels {
        let material =
          mesh.faceMaterials.isEmpty ? nil : mesh.materials[mesh.faceMaterials[entry.index]]
        frame.panel(
          ShipProjection.polygon(face.map { vertices[$0] }, projection: projection),
          colour: material.map {
            ShipProjection.shade($0.colour, normal: normal, emissive: $0.emissive)
          }
            ?? ShipProjection.shade(body.blackjackRole?.ink ?? body.hull.ink, normal: normal))
        continue
      }
      let ink: Ink =
        game.commander.shipDisplayStyle == .whiteWireframe
        ? .white : (body.blackjackRole?.ink ?? body.hull.ink)
      for edge in face.indices {
        let i = face[edge]
        let j = face[(edge + 1) % face.count]
        let token = "\(min(i,j)):\(max(i,j))"
        guard drawn.insert(token).inserted,
          let points = project(vertices[i], vertices[j], projection: projection)
        else {
          continue
        }
        // The viewport ends above the colour dashboard.
        frame.wire(points.0, points.1, points.2, points.3, ink)
      }
    }
    if game.commander.shipDisplayStyle != .shadedPanels {
      let ink: Ink =
        game.commander.shipDisplayStyle == .whiteWireframe
        ? .white : (body.blackjackRole?.ink ?? body.hull.ink)
      for detail in mesh.details where visibleFaces.contains(detail.face) {
        if let line = project(vertices[detail.start], vertices[detail.end], projection: projection)
        {
          frame.wire(line.0, line.1, line.2, line.3, ink)
        }
      }
    }
    drawScriptBeams(body, game: game, into: &frame, projection: projection)
    if body.hull == .station {
      let hatch = [
        Vector3(-30, -10, -90), Vector3(30, -10, -90), Vector3(30, 10, -90),
        Vector3(-30, 10, -90),
      ].map { game.viewPosition(body.modelVector($0)) + center }
      let normal = game.viewPosition(body.entranceNormal)
      guard normal.dot(hatch[0]) < 0 else { return }
      if game.commander.shipDisplayStyle == .shadedPanels {
        frame.panel(
          ShipProjection.polygon(hatch, projection: projection), colour: Ink.black.rawValue)
      } else {
        let ink: Ink =
          game.commander.shipDisplayStyle == .whiteWireframe
          ? .white : (body.blackjackRole?.ink ?? body.hull.ink)
        for index in hatch.indices {
          if let line = project(
            hatch[index], hatch[(index + 1) % hatch.count], projection: projection)
          {
            frame.wire(line.0, line.1, line.2, line.3, ink)
          }
        }
      }
    }
  }

  public static func project(
    _ start: Vector3, _ end: Vector3, projection: FlightProjection = .legacy
  ) -> (Double, Double, Double, Double)? {
    var a = start
    var b = end
    guard a.z >= 1 || b.z >= 1 else { return nil }
    if a.z < 1 { a = a + (b - a) * ((1 - a.z) / (b.z - a.z)) }
    if b.z < 1 { b = b + (a - b) * ((1 - b.z) / (a.z - b.z)) }
    let coordinates = [
      projection.point(a).x, projection.point(a).y, projection.point(b).x, projection.point(b).y,
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
      frame.point(Double(x), Double(y))
      if local { frame.text(star.name, x + 3, y - 7) }
      if star.id == game.selectedSystem {
        frame.line(x - 4, y, x + 4, y)
        frame.line(x, y - 4, x, y + 4)
      }
    }
    let x = local ? 128 : current.x
    let y = local ? 90 : 30 + current.y / 2
    let radius = local ? game.commander.fuel : game.commander.fuel / 4
    frame.ellipse(Double(x), Double(y), Double(radius), Double(max(1, radius / 2)))
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
    if let clue = game.missionClue {
      // Mission hints replace the description, as in PDESC; the normal data stays above.
      for (index, line) in MissionNotice.wrap(clue, width: 40).enumerated() {
        frame.text(line, 8, 130 + index * 8)
      }
    }
    if game.commander.executive && game.docked {
      if star.name == "LAVE" { frame.text("XYZZY HOME PORT", 8, 150) }
      if star.name == "RIEDQUAT" { frame.text("XYZZY: INFINITE RANGE", 8, 150) }
    }
  }
  private static func market(_ game: Game, into frame: inout Frame) {
    let marketTitle = game.screen == .sell ? "SELL CARGO" : "MARKET PRICES"
    header(game.screen == .buy ? "BUY CARGO" : marketTitle, into: &frame)
    frame.text("PRODUCT       PRICE STOCK HOLD", 4, 24)
    for (i, item) in Commodity.all.enumerated() {
      let y = 34 + i * 8
      if i == game.selection { frame.text(">", 0, y) }
      frame.text(item.name, 8, y, CommodityCategory.at(i).ink)
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
    let start = max(0, min(game.selection - 13, Equipment.all.count - 14))
    for i in start..<min(start + 14, Equipment.all.count) {
      let item = Equipment.all[i]
      let y = 30 + (i - start) * 10
      if i == game.selection { frame.text(">", 0, y) }
      let available = item.technology <= game.currentSystem.technology
      frame.text(item.name, 8, y, available ? .white : .red)
      let fitted =
        game.commander.equipment.contains(item.name)
        || (item.name == "Extra Energy Unit"
          && game.commander.equipment.contains(Equipment.navalEnergyUnit))
      let price =
        Equipment.isReward(item.name) ? "REWARD" : String(format: "%.1f", Double(item.price) / 10)
      frame.text(fitted ? "FITTED" : price, 194, y)
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
        "RATING: " + game.commander.rank,
        "TARGETING: " + (game.commander.targetingTier?.label ?? "NONE"),
        "NAVIGATION: " + (game.commander.navigationTier?.label ?? "NONE"),
        "FRONT LASER: " + (game.commander.laser(on: .front)?.equipmentName ?? "EMPTY"),
        "SHIELDS: " + (game.commander.shieldBooster?.label ?? "STANDARD"), "EQUIPMENT:",
      ]
      + game.commander.laserMountSummary.dropFirst().map { $0.uppercased() }
      + (game.commander.equipment.contains(Equipment.navalEnergyUnit)
        ? [Equipment.navalEnergyUnit] : [])
      + game.commander.equipment.sorted().filter {
        !["Fuel", "Missile", Equipment.navalEnergyUnit].contains($0) && LaserKind.from($0) == nil
      }
    for (i, line) in lines.prefix(16).enumerated() { frame.text(line, 8, 30 + i * 9) }
    if game.commander.missionStage != .notStarted && game.messageTime <= 0 {
      frame.text(game.commander.missionStage.status, 8, 177, .cyan)
    }
  }
  private static func inventory(_ game: Game, into frame: inout Frame) {
    header("INVENTORY", into: &frame)
    frame.text(
      game.commander.unlimitedCargo
        ? "CARGO: UNLIMITED CAPACITY"
        : "CARGO \(game.commander.cargoTonnes)/\(game.commander.capacity) TONNES", 8, 30)
    var row = 0
    for (i, quantity) in game.commander.cargo.enumerated() where quantity > 0 {
      frame.text(Commodity.all[i].name, 8, 48 + row * 8, CommodityCategory.at(i).ink)
      frame.text("\(quantity) \(Commodity.all[i].unit)", 180, 48 + row * 8)
      row += 1
    }
  }
  private static func secret(_ game: Game, into frame: inout Frame) {
    header("XYZZY", into: &frame)
    frame.centered("A HOLLOW VOICE SAYS...", 28)
    let choices = game.secretChoices
    for (index, choice) in choices.enumerated() { frame.text(choice, 10, 46 + index * 9) }
    frame.text(game.paused ? "RETURN THEN COMMAND-P TO RESUME" : "RETURN TO RESUME", 10, 177)
  }
  private static func help(_ game: Game, into frame: inout Frame) {
    header("PLAYER KEY GUIDE", into: &frame)
    let pages = PlayerHelp.pages(for: game)
    let index = max(0, min(game.helpPage, pages.count - 1))
    let page = pages[index]
    frame.centered(page.title, 30, .yellow)
    for (row, text) in page.rows.enumerated() { frame.text(text, 8, 48 + row * 10) }
    frame.centered("PAGE \(index + 1) OF \(pages.count)", 220, .yellow)
    frame.centered("ARROWS: MORE   K/ESC: BACK", 238, .cyan)
  }
  private static func mission(_ game: Game, into frame: inout Frame) {
    guard let notice = game.missionNotice else { return }
    if game.missionElapsed < 2 {
      frame.centered("INCOMING MESSAGE", 85)
      return
    }
    header("INCOMING MESSAGE", into: &frame)
    if notice.showsShip {
      var ship = SpaceBody(id: 0, hull: .constrictor, position: .init(0, 80, 600))
      ship.rotation = game.time * 0.6
      draw(ship, game: game, into: &frame)
    }
    let pages = notice.pages
    let page = min(game.missionPage, pages.count - 1)
    for (index, line) in pages[page].enumerated() {
      frame.text(line, 8, (notice.showsShip ? 103 : 30) + index * 8)
    }
    frame.text(game.paused ? "COMMAND-P: RESUME" : "SPACE/RETURN: CONTINUE", 8, 177, .cyan)
    frame.text("\(page + 1)/\(pages.count)", 8, 185, .yellow)
  }
  private static func dashboard(_ game: Game, into frame: inout Frame) {
    frame.box(0, 191, 255, 64, .yellow)
    frame.line(76, 192, 76, 255, .yellow)
    frame.line(180, 192, 180, 255, .yellow)
    let left: [(String, Double, Ink)] = [
      ("FS", game.frontShield / 255, .green), ("AS", game.rearShield / 255, .green),
      ("FU", Double(game.commander.fuel) / Double(game.commander.fuelCapacity), .green),
      ("CT", game.cabinTemperature, .red),
      ("LT", game.laserHeat / 255, .red), ("AL", game.altitude, .yellow),
    ]
    for (i, item) in left.enumerated() {
      let y = 196 + i * 9
      frame.text(item.0, 3, y, .yellow)
      bar(&frame, 24, y, item.1, item.2, 46)
    }
    let right: [(String, Double)] = [
      ("SP", game.cockpitSpeed / game.commander.performance.speed), ("RL", (game.roll + 1) / 2),
      ("DC", (game.pitch + 1) / 2),
    ]
    for (i, item) in right.enumerated() {
      frame.text(item.0, 184, 196 + i * 9, .yellow)
      bar(&frame, 201, 196 + i * 9, item.1, .green, 48)
    }
    for i in 0..<4 {
      bar(
        &frame, 201, 225 + i * 7,
        (game.energy - Double(i) * game.commander.performance.energy / 4)
          / (game.commander.performance.energy / 4), .yellow, 48)
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
