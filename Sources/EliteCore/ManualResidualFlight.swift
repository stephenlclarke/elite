import Foundation

extension Game {
  /// Released work momentum stays entirely in the camera-relative residual so steering
  /// cannot rotate a forward-speed component without applying thrust.
  mutating func applyManualResidualThrottle(delta: Double, throttle: Double) {
    guard !playerEMPDisabled, manualResidualFlight, workGuidance == nil, workBraking == nil,
      autoPilot.targetID == nil, !dockingComputer, !docked,
      delta.isFinite, delta > 0, delta <= 0.1, throttle.isFinite
    else { return }
    let velocity = autoPilot.velocity + Vector3(0, 0, speed * 18)
    let magnitude = velocity.length
    let acceleration = commander.performance.acceleration * 18
    let maximum = commander.performance.speed * 18
    guard velocity.finite, magnitude.isFinite,
      acceleration.isFinite, acceleration > 0, maximum.isFinite, maximum > 0
    else { return }
    let amount = acceleration * min(1, abs(throttle)) * delta
    var next = velocity
    if throttle < 0 {
      next = amount >= magnitude ? .init(0, 0, 0) : velocity * ((magnitude - amount) / magnitude)
    } else if throttle > 0 {
      let requested = velocity + Vector3(0, 0, amount)
      let capped = requested.limited(to: maximum)
      // External overspeed cannot justify a speed projection beyond the thrust budget.
      if (capped - velocity).length <= amount + 1e-9 { next = capped }
    }
    speed = 0
    autoPilot.setApproachVelocity(next)
    if next == .init(0, 0, 0) { manualResidualFlight = false }
  }

  /// Successful scene boundaries own their new cruise state; failed transitions never call this.
  mutating func clearManualResidualFlight() {
    manualResidualFlight = false
    autoPilot.setApproachVelocity(.init(0, 0, 0))
  }

  var cockpitSpeed: Double {
    if manualResidualFlight || workGuidance != nil || workBraking != nil {
      return flightWorldVelocity.length / 18
    }
    return autoTargetBody?.hull == .station ? autoPilot.velocity.length / 18 : speed
  }
}
