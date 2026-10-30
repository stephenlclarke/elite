import Foundation

public enum SpinDirection: String, Sendable {
  case clockwise = "CW"
  case anticlockwise = "CCW"
  var sign: Double { self == .clockwise ? 1 : -1 }
  var arrow: String { self == .clockwise ? "->" : "<-" }
}

/// Prototype roll rates are degrees/second, clockwise from the forward cockpit.
public struct SpinControl: Sendable, Equatable {
  public static let initialRate = 12.0
  public static let maximumRate = 60.0
  public static let adjustmentRate = 6.0
  public static let responseRate = 24.0
  public static let contactDelay = 0.12
  public private(set) var mode = false
  public private(set) var direction: SpinDirection?
  public private(set) var commandedRate = 0.0
  public private(set) var actualRate = 0.0
  public private(set) var recognition = 0.0
  public private(set) var feedback = "HOLDING"
  private var candidateContacts = 0
  private var contactAge = 0.0
  private var waitForLift = false
  public init() {}

  public mutating func toggleMode() {
    if mode { stop() } else { mode = true }
  }

  public mutating func begin(_ direction: SpinDirection) {
    guard mode else { return }
    self.direction = direction
    commandedRate = direction.sign * Self.initialRate
    waitForLift = true
    candidateContacts = 0
    contactAge = 0
    feedback = "LIFT TO HOLD SPIN"
  }

  public mutating func stop(immediate: Bool = false) {
    mode = false
    direction = nil
    commandedRate = 0
    recognition = 0
    candidateContacts = 0
    contactAge = 0
    waitForLift = false
    feedback = "STOPPING"
    if immediate { actualRate = 0 }
  }

  mutating func advance(delta: Double, controls: Controls) {
    recognition = mode ? min(1, max(0, controls.spinRecognition)) : 0
    let contacts = (0...3).contains(controls.spinContacts) ? controls.spinContacts : 0
    if contacts == 0 { waitForLift = false }
    if mode, let direction, !waitForLift, recognition == 0 {
      adjustCommand(delta: delta, controls: controls, contacts: contacts, direction: direction)
    } else {
      candidateContacts = 0
      contactAge = 0
    }
    let difference = commandedRate - actualRate
    let step = Self.responseRate * delta
    actualRate += max(-step, min(step, difference))
    if abs(actualRate) < 1e-9 { actualRate = 0 }
  }

  private mutating func adjustCommand(
    delta: Double, controls: Controls, contacts: Int, direction: SpinDirection
  ) {
    var adjustmentTime = stableContactTime(contacts, delta: delta)
    var adjustment = 0.0
    if contacts == 1 { adjustment = -1 }
    if contacts == 3 { adjustment = 1 }
    if controls.spinSlower || controls.spinFaster {
      adjustment = (controls.spinFaster ? 1 : 0) - (controls.spinSlower ? 1 : 0)
      adjustmentTime = delta
    }
    let magnitude = min(
      Self.maximumRate,
      max(0, abs(commandedRate) + adjustment * Self.adjustmentRate * adjustmentTime))
    commandedRate = direction.sign * magnitude
    feedback = "HOLDING"
    if adjustmentTime > 0 && adjustment < 0 { feedback = "SLOWING" }
    if adjustmentTime > 0 && adjustment > 0 {
      feedback = magnitude == Self.maximumRate ? "MAXIMUM SPIN" : "SPEEDING UP"
    }
  }

  private mutating func stableContactTime(_ contacts: Int, delta: Double) -> Double {
    if candidateContacts != contacts {
      candidateContacts = contacts
      contactAge = 0
    }
    let oldAge = contactAge
    contactAge += delta
    return max(0, contactAge - Self.contactDelay) - max(0, oldAge - Self.contactDelay)
  }

  public var hudLines: [String] {
    guard mode || actualRate != 0 else { return [] }
    if mode && direction == nil && actualRate == 0 {
      return ["SPIN MODE: STOPPED", recognitionLine ?? "DRAW CIRCLE OR [ / ]; B:STOP"]
    }
    if actualRate == 0 {
      return [
        "SPIN HOLD: STOPPED",
        commandedRate == 0 ? "1:SLOW 2:HOLD 3:FASTER B:STOP" : targetLine,
      ]
    }
    let actualDirection: SpinDirection = actualRate < 0 ? .anticlockwise : .clockwise
    let label = mode ? "SPIN HOLD" : "SPIN STOPPING"
    let actual = String(format: "%.1f", abs(actualRate))
    let first = "\(label) \(actualDirection.rawValue) \(actualDirection.arrow) \(actual) DEG/S"
    if let recognitionLine { return [first, recognitionLine] }
    if abs(actualRate - commandedRate) > 0.1 {
      return [first, targetLine]
    }
    return [first, "\(feedback)  B:STOP V:EXIT"]
  }

  private var recognitionLine: String? {
    recognition > 0 ? "TRACING CIRCLE: \(Int(recognition * 100))%" : nil
  }

  private var targetLine: String {
    let target = String(format: "%.1f", abs(commandedRate))
    let targetDirection = commandedRate < 0 ? "CCW <-" : "CW ->"
    return "TARGET \(targetDirection) \(target) DEG/S"
  }
}
