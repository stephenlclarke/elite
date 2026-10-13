import Foundation

public enum TargetingTier: Int, Sendable, Codable, CaseIterable, Comparable {
  case basic = 1
  case advanced, docking, identification, pirate, military
  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
  public var label: String {
    switch self {
    case .basic: "Basic"
    case .advanced: "Advanced"
    case .docking: "Docking"
    case .identification: "Identification"
    case .pirate: "Pirate"
    case .military: "Military"
    }
  }
  /// Prices are tenths of a credit; endpoint prices are twice Pulse/Military lasers.
  public var price: Int { [8000, 20000, 40000, 60000, 100000, 120000][rawValue - 1] }
  public var technology: Int { [3, 4, 6, 8, 9, 10][rawValue - 1] }
  public var equipmentName: String { "Targeting: " + label }
  static func from(_ name: String) -> Self? { allCases.first { $0.equipmentName == name } }
}
extension Commander {
  public var targetingTier: TargetingTier? {
    (equipment.compactMap(TargetingTier.from)
      + (equipment.contains(Equipment.legacyDockingComputer) ? [.docking] : [])).max()
  }
  public var hasAutomaticDocking: Bool { targetingTier.map { $0 >= .docking } ?? false }
  public mutating func installTargetingComputer(_ tier: TargetingTier) {
    let effective = max(tier, targetingTier ?? tier)
    equipment.remove(Equipment.legacyDockingComputer)
    equipment.subtract(TargetingTier.allCases.map(\.equipmentName))
    equipment.insert(effective.equipmentName)
  }
}
extension Hull {
  public var isTargetShip: Bool { ![Hull.station, .cargo, .asteroid, .missile].contains(self) }
  public var modelName: String {
    switch self {
    case .cobra: "Cobra Mk III"
    case .viper: "Viper"
    case .sidewinder: "Sidewinder"
    case .constrictor: "Constrictor"
    case .thargoid: "Thargoid"
    case .thargon: "Thargon"
    case .station: "Space station"
    case .cargo: "Cargo canister"
    case .asteroid: "Asteroid"
    case .missile: "Missile"
    }
  }
}

extension Display {
  /// Use the identical projection, hidden-face and clipping path as front-view rendering.
  static func visibleInFront(_ body: SpaceBody, game: Game, layout: CockpitLayout) -> Bool {
    var front = game
    front.screen = .front
    var frame = Frame()
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: layout.width, height: layout.height)
    frame.flightClip = layout.flightClip
    draw(body, game: front, into: &frame, projection: layout.projection)
    return !frame.shipLines.isEmpty || !frame.shipPanels.isEmpty
  }
}

public struct TargetField: Sendable, Equatable {
  public let label: String
  public let value: String
  public var text: String { label + ": " + value }
}
public struct TargetInformation: Sendable, Equatable {
  public let id: Int
  public let model: String?
  public let status: String?
  public let fields: [TargetField]
  public var identifier: String { (model ?? "Target") + " #\(id)" }
}

extension Game {
  public var targetingEnabled: Bool {
    commander.targetingTier != nil && (!commander.xyzzyActive || commander.autoTarget)
  }
  public var informationTargetBody: SpaceBody? {
    guard commander.targetingTier != nil else { return nil }
    if let id = weaponsTargetID, let body = bodies.first(where: { $0.id == id && $0.energy > 0 }) {
      return body
    }
    return autoTargetBody
  }
  public var targetInformation: TargetInformation? {
    guard let body = informationTargetBody else { return nil }
    return information(for: body)
  }
  func information(for body: SpaceBody) -> TargetInformation? {
    guard let tier = commander.targetingTier else { return nil }
    guard body.hull != .station || tier >= .docking else { return nil }
    guard tier >= .identification else {
      return .init(id: body.id, model: nil, status: nil, fields: [])
    }
    let shipStatus = body.hostile ? "Hostile" : "Neutral"
    let status = body.hull == .station ? autoPilot.status : shipStatus
    var fields: [TargetField] = []
    if body.hull == .station {
      fields = [
        .init(label: "Entrance", value: autoPilot.ready ? "Ready" : "Aligning"),
        .init(
          label: "Rotation", value: String(format: "%.1f deg/s", body.rotationRate * 180 / .pi)),
        .init(label: "Range", value: String(format: "%.0f units", body.position.length)),
      ]
    } else {
      if tier >= .pirate {
        fields += [
          .init(label: "Cargo", value: "Unavailable"), .init(label: "Origin", value: "Unknown"),
          .init(label: "Destination", value: "Unknown"),
        ]
      }
      if tier >= .military {
        fields += [
          .init(label: "Shields", value: "Unavailable"),
          .init(label: "Laser heat", value: "Unavailable"),
          .init(label: "Fuel", value: "Unavailable"),
          .init(label: "Missiles", value: String(body.missiles)),
          .init(label: "ECM equipped", value: body.ecmEnabled ? "Yes" : "No"),
          .init(
            label: "ECM active", value: ecmFrames > 0 && enemyECMSource == body.id ? "Yes" : "No"),
        ]
      }
    }
    return .init(id: body.id, model: body.hull.modelName, status: status, fields: fields)
  }
}
