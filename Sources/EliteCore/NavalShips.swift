/// Numerical blueprint data from the pinned BBC Second Processor source.
extension Hull {
  public var navalEnergy: Double? {
    switch self {
    case .constrictor: 252
    case .thargoid: 240
    case .thargon: 20
    default: nil
    }
  }
  public var navalBounty: Int? {
    switch self {
    case .constrictor: 0
    case .thargoid: 500
    case .thargon: 50
    default: nil
    }
  }
  public var hasECM: Bool { [.constrictor, .thargoid, .thargon].contains(self) }
  public var bombImmune: Bool { self == .station || self == .constrictor }
  public var navalSpeed: Double? {
    switch self {
    case .constrictor: 36
    case .thargoid: 39
    case .thargon: 30
    default: nil
    }
  }
  public var navalLaserDamage: Double? {
    switch self {
    case .constrictor: 26
    case .thargoid: 11
    case .thargon: 8
    default: nil
    }
  }
  public var navalMissiles: Int {
    switch self {
    case .constrictor: 4
    case .thargoid: 6
    default: 0
    }
  }
}

extension SpaceBody {
  var leavesLocalBubble: Bool {
    if hull == .constrictor {
      return max(abs(position.x), abs(position.y), abs(position.z)) >= 57600
    }
    return position.length > 40000
  }
}

enum NavalShips {
  static let constrictor = Mesh(
    vertices: [
      .init(20, -7, 80), .init(-20, -7, 80), .init(-54, -7, 40), .init(-54, -7, -40),
      .init(-20, 13, -40), .init(20, 13, -40), .init(54, -7, -40), .init(54, -7, 40),
      .init(20, 13, 5), .init(-20, 13, 5), .init(20, -7, 62), .init(-20, -7, 62),
      .init(25, -7, -25), .init(-25, -7, -25), .init(15, -7, -15), .init(-15, -7, -15),
      .init(0, -7, 0),
    ],
    faces: [
      [0, 1, 9, 8], [1, 2, 9], [0, 8, 7], [7, 8, 6], [2, 3, 9], [3, 4, 9],
      [4, 5, 8, 9], [5, 6, 8], [3, 6, 5, 4], [0, 7, 6, 3, 2, 1],
    ],
    details: [
      .init(start: 10, end: 12, face: 9), .init(start: 12, end: 14, face: 9),
      .init(start: 14, end: 10, face: 9), .init(start: 11, end: 15, face: 9),
      .init(start: 13, end: 15, face: 9), .init(start: 11, end: 13, face: 9),
    ])

  static let thargon = Mesh(
    vertices: [
      .init(-9, 0, 40), .init(-9, -38, 12), .init(-9, -24, -32), .init(-9, 24, -32),
      .init(-9, 38, 12), .init(9, 0, -8), .init(9, -10, -15), .init(9, -6, -26),
      .init(9, 6, -26), .init(9, 10, -15),
    ],
    faces: [
      [0, 4, 3, 2, 1], [5, 6, 7, 8, 9],
      [0, 1, 6], [0, 6, 5], [1, 2, 6], [2, 7, 6], [2, 3, 8, 7],
      [3, 4, 9], [3, 9, 8], [4, 0, 9], [0, 5, 9],
    ])
}
