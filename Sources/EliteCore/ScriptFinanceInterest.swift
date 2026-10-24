import Foundation

/// Original generic period-end simple interest, not a historical campaign's settlement profile.
public struct ScriptFinanceInterest: Codable, Sendable, Equatable {
  static let capability = "finance-interest-simple-v2"
  public enum Rounding: String, Codable, Sendable { case down, up }
  public let rateBasisPoints: Int
  public let periodSeconds: Int
  public let rounding: Rounding
  public let maximumInterest: Int

  func valid(principal: Int) -> Bool {
    (1...10000).contains(rateBasisPoints) && (1...31_536_000).contains(periodSeconds)
      && (1...4_294_967_295).contains(principal)
      && maximumInterest > 0 && maximumInterest <= 4_294_967_295 - principal
  }
}

/// A pure projection. Only explicit confirmation persists assessment or transfers cash.
struct ScriptFinanceBalance: Sendable, Equatable {
  let principal: Int
  let interest: Int
  let assessedInterest: Int
  let completedPeriods: Int
  var total: Int {
    let (value, overflow) = principal.addingReportingOverflow(interest)
    // Malformed decoded components must fail validation rather than trap during a row projection.
    return overflow ? Int.max : value
  }
  static let zero = Self(principal: 0, interest: 0, assessedInterest: 0, completedPeriods: 0)

  func accruing(
    terms: ScriptFinanceDefinition, borrowedAt: Double, at time: Double
  ) -> Self? {
    guard terms.valid, borrowedAt.isFinite, time.isFinite,
      borrowedAt >= 0, time >= borrowedAt, time <= 1e12,
      principal >= 0, (0...4_294_967_295).contains(interest),
      (interest...4_294_967_295).contains(assessedInterest), completedPeriods >= 0,
      principal <= terms.principal, total <= 4_294_967_295
    else { return nil }
    guard let rate = terms.interest else {
      return interest == 0 && assessedInterest == 0 && completedPeriods == 0 ? self : nil
    }
    guard assessedInterest <= rate.maximumInterest else { return nil }
    // Paid loans never accrue again, even when queried at a later calendar date.
    guard total > 0 else { return self }
    let periods = Int(floor((time - borrowedAt) / Double(rate.periodSeconds)))
    guard periods >= completedPeriods else { return nil }
    // Native money/rate limits bound this product below 2^46 on the supported 64-bit host.
    let numerator = principal * rate.rateBasisPoints
    let perPeriod = numerator / 10000 + (rate.rounding == .up && numerator % 10000 != 0 ? 1 : 0)
    let available = rate.maximumInterest - assessedInterest
    let missed = periods - completedPeriods
    let added: Int
    if available == 0 || perPeriod == 0 {
      added = 0
    } else {
      // Saturate before multiplication: a trillion missed periods cannot overflow or loop.
      let untilCap = available / perPeriod + (available % perPeriod == 0 ? 0 : 1)
      added = missed >= untilCap ? available : missed * perPeriod
    }
    return .init(
      principal: principal, interest: interest + added,
      assessedInterest: assessedInterest + added, completedPeriods: periods)
  }
}

extension ScriptFinanceReceipt {
  var balanceAfter: ScriptFinanceBalance {
    .init(
      principal: afterPrincipal, interest: afterInterest,
      assessedInterest: assessedInterest, completedPeriods: completedPeriods)
  }
}

extension ScriptFinanceRecord {
  func balance(at time: Double) -> ScriptFinanceBalance? {
    guard terms.valid, time.isFinite, (0...1e12).contains(time),
      time >= source.cause.calendarSeconds
    else {
      return nil
    }
    guard let first = receipts.first, let last = receipts.last else { return .zero }
    guard time >= last.calendarSeconds else { return nil }
    if first.operation == .decline { return .zero }
    return last.balanceAfter.accruing(terms: terms, borrowedAt: first.calendarSeconds, at: time)
  }
}
