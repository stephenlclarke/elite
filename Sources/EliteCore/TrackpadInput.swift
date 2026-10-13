/// A held, absolute trackpad direction. AppKit supplies positions in the 0...1 range.
public struct TrackpadInput: Sendable, Equatable {
  public private(set) var fingerCount = 0
  public private(set) var direction = SIMD2<Double>.zero
  private var waitingForLift = false
  public init() {}

  public var controls: Controls {
    var controls = Controls()
    switch fingerCount {
    case 1: controls.throttle = -1
    case 2:
      controls.pitch = direction.y
      controls.roll = -direction.x
    case 3: controls.throttle = 1
    default: break
    }
    return controls
  }

  public mutating func reset() {
    fingerCount = 0
    direction = .zero
    waitingForLift = false
  }

  public mutating func update(positions: [SIMD2<Double>]) {
    if positions.isEmpty {
      reset()
      return
    }
    guard !waitingForLift else { return }
    guard positions.count <= 3,
      positions.allSatisfy({ (0...1).contains($0.x) && (0...1).contains($0.y) })
    else {
      // Ignore a system gesture until it ends instead of treating its last fingers as thrust.
      reset()
      waitingForLift = true
      return
    }
    fingerCount = positions.count
    let center = positions.reduce(.zero, +) / Double(positions.count)
    direction = .init(Self.axis(center.x), Self.axis(center.y))
  }

  private static func axis(_ position: Double) -> Double {
    let offset = position - 0.5
    let magnitude = max(0, (abs(offset) - 0.12) / 0.38)
    return offset < 0 ? -magnitude : magnitude
  }
}
