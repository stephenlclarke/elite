/// Deadline arithmetic only; the MainActor loop owns sleeping, cancellation and simulation time.
struct FrameCadence: Sendable {
  /// Bound timer coalescing to a small fraction of the foreground 60 Hz frame interval.
  static let sleepTolerance: Duration = .microseconds(100)
  private(set) var framesPerSecond: Int
  private(set) var interval: Duration
  private var deadline: ContinuousClock.Instant

  init(start: ContinuousClock.Instant, maximumFPS: Int) {
    framesPerSecond = Self.capped(maximumFPS)
    interval = .seconds(1.0 / Double(framesPerSecond))
    deadline = start.advanced(by: interval)
  }

  /// Preserve phase across late wakes. Overdue work skips slots, never returns a past deadline.
  mutating func nextDeadline(after now: ContinuousClock.Instant, maximumFPS: Int)
    -> ContinuousClock.Instant
  {
    let rate = Self.capped(maximumFPS)
    if rate != framesPerSecond {
      framesPerSecond = rate
      interval = .seconds(1.0 / Double(rate))
      deadline = now.advanced(by: interval)
    } else if deadline <= now {
      let missed = Int(deadline.duration(to: now) / interval) + 1
      deadline = deadline.advanced(by: interval * missed)
      // Duration division uses Double; keep the strict future boundary despite ratio rounding.
      if deadline <= now { deadline = deadline.advanced(by: interval) }
    }
    return deadline
  }

  private static func capped(_ rate: Int) -> Int { max(1, min(60, rate)) }
}
