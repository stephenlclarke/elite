import Testing

@testable import EliteMac

struct FrameCadenceTests {
  @Test func repeatedLateWakesKeepTheOriginalDeadlinePhase() {
    let origin = ContinuousClock.now
    var cadence = FrameCadence(start: origin, maximumFPS: 60)
    let interval = cadence.interval
    var deadline = cadence.nextDeadline(after: origin, maximumFPS: 60)
    #expect(deadline == origin.advanced(by: interval))
    for frame in 2...20 {
      let lateWake = deadline.advanced(by: .milliseconds(1))
      deadline = cadence.nextDeadline(after: lateWake, maximumFPS: 60)
      #expect(deadline == origin.advanced(by: interval * frame))
      let workEnd = lateWake.advanced(by: .milliseconds(8))
      let afterWork = cadence.nextDeadline(after: workEnd, maximumFPS: 60)
      #expect(afterWork == deadline)
    }
  }

  @Test func overdueWorkAndExactBoundariesSkipToOneFutureSlot() {
    let origin = ContinuousClock.now
    var cadence = FrameCadence(start: origin, maximumFPS: 60)
    let interval = cadence.interval
    let workEnd = origin.advanced(by: interval * 5 + .milliseconds(2))
    let deadline = cadence.nextDeadline(after: workEnd, maximumFPS: 60)
    #expect(deadline == origin.advanced(by: interval * 6))
    #expect(deadline > workEnd)
    let exactBoundary = cadence.nextDeadline(after: deadline, maximumFPS: 60)
    #expect(exactBoundary == origin.advanced(by: interval * 7))
    let longWorkEnd = origin.advanced(by: interval * 120 + .milliseconds(2))
    let afterLongWork = cadence.nextDeadline(after: longWorkEnd, maximumFPS: 60)
    #expect(afterLongWork == origin.advanced(by: interval * 121))
    #expect(afterLongWork > longWorkEnd)
  }

  @Test func refreshRateChangesReanchorWhileClampingTheSameRatePreservesPhase() {
    let origin = ContinuousClock.now
    var cadence = FrameCadence(start: origin, maximumFPS: 120)
    #expect(cadence.framesPerSecond == 60)
    let first = cadence.nextDeadline(after: origin, maximumFPS: 60)
    let changedAt = first.advanced(by: .milliseconds(3))
    let slower = cadence.nextDeadline(after: changedAt, maximumFPS: 30)
    #expect(cadence.framesPerSecond == 30)
    #expect(slower == changedAt.advanced(by: .seconds(1.0 / 30)))
    let normalAt = slower.advanced(by: .milliseconds(1))
    let normal = cadence.nextDeadline(after: normalAt, maximumFPS: 144)
    #expect(cadence.framesPerSecond == 60)
    #expect(normal == normalAt.advanced(by: .seconds(1.0 / 60)))
    let sameCappedRate = cadence.nextDeadline(after: normalAt, maximumFPS: 120)
    #expect(sameCappedRate == normal)
    let minimum = cadence.nextDeadline(after: normalAt, maximumFPS: 0)
    #expect(cadence.framesPerSecond == 1)
    #expect(minimum == normalAt.advanced(by: .seconds(1)))
    let sameMinimumRate = cadence.nextDeadline(after: normalAt, maximumFPS: -10)
    #expect(sameMinimumRate == minimum)
  }
}
