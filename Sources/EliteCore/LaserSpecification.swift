import Foundation

public enum LaserKind: String, Sendable, Codable, CaseIterable {
  case pulse, mining, beam, military, naval
  public var equipmentName: String {
    switch self {
    case .pulse: "Pulse Laser"
    case .mining: "Mining Laser"
    case .beam: "Beam Laser"
    case .military: "Military Laser"
    case .naval: "Naval Laser"
    }
  }
  public var damage: Double {
    switch self {
    case .pulse, .beam: 15
    case .mining: 50
    case .military: 23
    case .naval: 64
    }
  }
  public var firingInterval: Double {
    switch self {
    case .pulse, .mining: 0.3
    case .beam, .military, .naval: 0.1
    }
  }
}
extension Commander {
  public var activeLaser: LaserKind? { laser(on: .front) }
  var legacyLaser: LaserKind? {
    [LaserKind.naval, .military, .beam, .mining, .pulse].first {
      equipment.contains($0.equipmentName)
    }
  }
}

public enum LaserMount: String, Sendable, Codable, CaseIterable {
  case front, left, right, rear
  public var label: String { rawValue.capitalized }
  public var next: Self { Self.allCases[(Self.allCases.firstIndex(of: self)! + 1) % 4] }
  public var previous: Self { Self.allCases[(Self.allCases.firstIndex(of: self)! + 3) % 4] }
  public static func from(_ screen: Screen) -> Self? {
    Self(rawValue: screen.rawValue)
  }
}
public struct LaserMounts: Sendable, Equatable, Codable {
  public var front: LaserKind?
  public var left: LaserKind?
  public var right: LaserKind?
  public var rear: LaserKind?
  public init(
    front: LaserKind? = nil, left: LaserKind? = nil, right: LaserKind? = nil, rear: LaserKind? = nil
  ) {
    self.front = front
    self.left = left
    self.right = right
    self.rear = rear
  }
  public subscript(_ mount: LaserMount) -> LaserKind? {
    get {
      switch mount {
      case .front: front
      case .left: left
      case .right: right
      case .rear: rear
      }
    }
    set {
      switch mount {
      case .front: front = newValue
      case .left: left = newValue
      case .right: right = newValue
      case .rear: rear = newValue
      }
    }
  }
}
extension LaserKind {
  public static func from(_ name: String) -> Self? { allCases.first { $0.equipmentName == name } }
}
extension Commander {
  public func laser(on mount: LaserMount) -> LaserKind? { laserMounts[mount] }
  public mutating func installLaser(_ kind: LaserKind, on mount: LaserMount) {
    var mounts = laserMounts
    mounts[mount] = kind
    laserMounts = mounts
    equipment.insert(kind.equipmentName)
  }
  public var laserMountSummary: [String] {
    LaserMount.allCases.map { $0.label + ": " + (laser(on: $0)?.equipmentName ?? "Empty") }
  }
}
extension Game {
  mutating func purchaseLaser(_ kind: LaserKind, item: Equipment) {
    guard commander.performance.supports(equipmentMount) else {
      notify("THIS HULL HAS NO " + equipmentMount.label.uppercased() + " LASER MOUNT")
      return
    }
    guard commander.laser(on: equipmentMount) != kind else {
      notify(equipmentMount.label.uppercased() + " " + item.name.uppercased() + " ALREADY FITTED")
      return
    }
    guard equipmentAvailable(item), commander.availableCredits >= item.price
    else {
      notify("NOT AVAILABLE")
      return
    }
    commander.installLaser(kind, on: equipmentMount)
    if !commander.unlimitedCash { commander.credits -= item.price }
    notify(item.name.uppercased() + " FITTED " + equipmentMount.label.uppercased())
  }
}
