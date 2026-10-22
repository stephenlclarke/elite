import Foundation

/// Resolve native tokens from the generated authority rather than a second binding table.
public enum FlightControlInput: Sendable {
  public static func token(for action: FlightControlAuthority.ActionID) -> String {
    action.binding.key.lowercased()
  }
  public static func action(for token: String) -> FlightControlAuthority.ActionID? {
    FlightControlAuthority.ActionID.allCases.first { Self.token(for: $0) == token.lowercased() }
  }
  static func interruptsHeldTool(_ action: FlightControlAuthority.ActionID) -> Bool {
    switch action {
    case .changeWeapon, .releaseHold, .nextTarget, .targetFilter: true
    case .fire, .ecm: false
    }
  }
  static func helpRow(for action: FlightControlAuthority.ActionID) -> String {
    let binding = action.binding
    return binding.key.uppercased() + " - " + binding.label.uppercased()
      + (action == .fire ? " (HOLD)" : "")
  }
  public static func fireIsHeld(_ tokens: Set<String>) -> Bool {
    tokens.contains(token(for: .fire))
  }
}

struct FlightTriggerState: Sendable {
  var held = false
  var pressPending = false
}

struct FlightToolActivity: Sendable {
  let tool: FlightWorkTool
  let physicalTime: Double
}

extension Game {
  var acceptsSharedFlightControls: Bool { !docked && screen.isFlight && !paused }

  /// A stopped work session must publish before clocks, actor restoration or physics can advance.
  /// Physical Return may remain held after a safety interruption without admitting more work.
  mutating func admitFlightWorkAdvance(controls: Controls) -> Bool {
    if !controls.fire || workFireSuspended || paused || !screen.isFlight
      || selectedFlightTool != .salvageCutter
    {
      return flushNativeSalvageWork()
    }
    return true
  }

  func flightKeyStopsTool(_ token: String) -> Bool {
    guard acceptsSharedFlightControls, let action = FlightControlInput.action(for: token) else {
      return false
    }
    return FlightControlInput.interruptsHeldTool(action)
  }

  /// This transient stop may precede a refused native command; it grants no persistent action.
  mutating func interruptFlightTool() {
    interruptInductionUtilityWork()
    interruptIsolationWork()
    // Only a held trigger needs a release/repress latch. Idle selection and launch
    // must not invent a stop, and an existing damage/impact stop must survive.
    if flightTrigger.held { workFireSuspended = true }
    flightTrigger.pressPending = false
    selectedToolActivity = nil
  }

  /// Q releases the controller independently of hot work publication, retaining its pending state.
  @discardableResult
  mutating func prepareFlightControlKey(_ token: String) -> Bool {
    guard flightKeyStopsTool(token) else { return false }
    interruptFlightTool()
    guard FlightControlInput.action(for: token) == .releaseHold else { return false }
    inductionUtilityWorkRuntime.contact = nil
    isolationWorkRuntime.contact = nil
    let engaged = autoPilot.targetID != nil || workGuidance != nil || workBraking != nil
    cancelAutoTarget()
    if engaged {
      notify(
        "MANUAL CONTROL - " + FlightControlAuthority.ActionID.releaseHold.binding.label.uppercased()
      )
    }
    return true
  }

  mutating func observeFlightFire(held: Bool, explicitPress: Bool = false) {
    if held && (!flightTrigger.held || explicitPress) { flightTrigger.pressPending = true }
    flightTrigger.held = held
    if !held {
      flightTrigger.pressPending = false
      workFireSuspended = false
      selectedToolActivity = nil
    }
  }

  mutating func admitFlightFire(held: Bool) -> Bool {
    observeFlightFire(held: held)
    if held && (inductionUtilityUsesReturn || isolationWorkUsesReturn) {
      workFireSuspended = true
      flightTrigger.pressPending = false
      return false
    }
    if flightTrigger.pressPending { workFireSuspended = false }
    flightTrigger.pressPending = false
    return held && !workFireSuspended
  }

  mutating func sharedFlightKey(_ token: String) -> Bool {
    guard acceptsSharedFlightControls, let action = FlightControlInput.action(for: token) else {
      return false
    }
    switch action {
    case .changeWeapon: cycleFlightTool()
    case .fire: observeFlightFire(held: true, explicitPress: true)
    case .ecm: ecm()
    case .releaseHold: _ = prepareFlightControlKey(token)
    case .nextTarget: cycleAutoTarget()
    case .targetFilter: cycleWorkTargetFilter()
    }
    return true
  }

  var fittedFlightTools: [FlightWorkTool] {
    FlightWorkTool.allCases.filter(flightToolIsFitted)
  }

  func flightToolIsFitted(_ tool: FlightWorkTool) -> Bool {
    switch tool {
    case .combatLaser:
      LaserMount.allCases.contains { commander.laser(on: $0).map { $0 != .mining } == true }
    case .miningLaser: commander.hasMiningWorkTool || commander.laser(on: .front) == .mining
    case .salvageCutter:
      commander.performance.workTools?.contains(.salvageCutter) == true
        && commander.fittedEquipment(at: .utility(.salvageCutter)) != nil
    case .empPirateBlaster: commander.fittedEquipment(at: .utility(.empPirateBlaster)) != nil
    }
  }

  /// One default per acquisition; hold transitions and repainting never select a weapon.
  mutating func selectAcquiredWorkTool(_ mode: WorkTargetMode) {
    switch mode {
    case .hold(.mining): selectedFlightTool = .miningLaser
    case .hold(.salvage): selectedFlightTool = .salvageCutter
    default: return
    }
    interruptFlightTool()
    if !flightToolIsFitted(selectedFlightTool) {
      notify(selectedFlightTool.label.uppercased() + " NOT FITTED")
    }
  }
}
