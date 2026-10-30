/// A held, absolute trackpad direction. AppKit supplies positions in the 0...1 range.
public struct TrackpadInput: Sendable, Equatable {
  public private(set) var fingerCount = 0
  public private(set) var direction = SIMD2<Double>.zero
  private var waitingForLift = false
  private var spinMode = false
  private var spinOrigin = SIMD2<Double>.zero
  private var circle = SpinGesture()
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

  public var spinControls: Controls {
    var controls = Controls()
    controls.spinContacts = fingerCount
    controls.spinRecognition = circle.progress
    if fingerCount == 2 {
      controls.pitch = direction.y
      controls.yaw = direction.x
    }
    return controls
  }

  public mutating func reset() {
    fingerCount = 0
    direction = .zero
    waitingForLift = false
    spinMode = false
    spinOrigin = .zero
    circle.reset()
  }

  /// A control-mode transition clears outputs synchronously, but cannot re-arm
  /// contacts remaining from a rejected system gesture. Lifecycle reset is separate.
  public mutating func setSpinMode(_ enabled: Bool) {
    guard spinMode != enabled else { return }
    let requiresLift = waitingForLift
    reset()
    spinMode = enabled
    waitingForLift = requiresLift
  }

  @discardableResult
  public mutating func update(
    positions: [SIMD2<Double>], spinMode: Bool = false
  ) -> SpinDirection? {
    setSpinMode(spinMode)
    if positions.isEmpty {
      reset()
      return nil
    }
    guard !waitingForLift else { return nil }
    guard positions.count <= 3,
      positions.allSatisfy({ (0...1).contains($0.x) && (0...1).contains($0.y) })
    else {
      // Ignore a system gesture until it ends instead of treating its last fingers as thrust.
      reset()
      waitingForLift = true
      return nil
    }
    let changedCount = fingerCount != positions.count
    fingerCount = positions.count
    let center = positions.reduce(.zero, +) / Double(positions.count)
    if spinMode {
      if changedCount {
        spinOrigin = center
        circle.reset()
      }
      direction =
        fingerCount == 2
        ? .init(
          Self.relativeAxis(center.x - spinOrigin.x), Self.relativeAxis(center.y - spinOrigin.y))
        : .zero
      return fingerCount == 1 ? circle.update(center) : nil
    }
    direction = .init(Self.axis(center.x), Self.axis(center.y))
    return nil
  }

  private static func relativeAxis(_ distance: Double) -> Double {
    let magnitude = min(1, max(0, (abs(distance) - 0.02) / 0.23))
    return distance < 0 ? -magnitude : magnitude
  }

  private static func axis(_ position: Double) -> Double {
    let offset = position - 0.5
    let magnitude = max(0, (abs(offset) - 0.12) / 0.38)
    return offset < 0 ? -magnitude : magnitude
  }
}
