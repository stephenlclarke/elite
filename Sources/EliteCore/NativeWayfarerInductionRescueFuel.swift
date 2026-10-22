import Foundation

struct NativeRescueFuelQuote: Sendable {
  fileprivate let purchase: NativeArkFuelPurchase
  fileprivate init(_ purchase: NativeArkFuelPurchase) { self.purchase = purchase }
  var cost: Int { purchase.balanceBefore - purchase.balanceAfter }
  var fuelAfter: Double { purchase.fuelAfter }
}

/// Rescue-owned credits. Shared fuel receipts never turn this into an ark/key or player account.
final class NativeRescueFuelEscrow: Codable, Sendable, Equatable {
  static let initialCredits = 10_000
  let funding: NativeRescueFuelFunding
  let remainingCredits: Int
  let purchases: [NativeArkFuelPurchase]
  let refusal: NativeArkFuelRefusalRecord?

  init(funding: NativeRescueFuelFunding) throws {
    self.funding = funding
    remainingCredits = Self.initialCredits
    purchases = []
    refusal = nil
    guard valid else { throw SaveError.invalidCommander }
  }
  private init(
    _ previous: NativeRescueFuelEscrow, purchases: [NativeArkFuelPurchase],
    balance: Int, refusal: NativeArkFuelRefusalRecord? = nil
  ) {
    funding = previous.funding
    remainingCredits = balance
    self.purchases = purchases
    self.refusal = refusal
  }

  private func calculate(_ request: NativeArkFuelRequest, balance: Int) throws
    -> NativeArkFuelCalculation
  {
    guard let profile = try? NativeInductionCrewLogSource.flightProfile.get() else {
      throw NativeArkFuelRefusal.invalidInput
    }
    return try NativeCustodianFuelMath.calculate(
      request, balance: balance, owner: funding.owner,
      mission: funding.parent, vessel: funding.launch,
      galaxy: NativeInductionCrewLogSource.location.galaxy,
      profile: profile)
  }
  private func purchase(_ request: NativeArkFuelRequest, balance: Int, revision: Int) throws
    -> NativeArkFuelPurchase
  {
    let result = try calculate(request, balance: balance)
    let operation = ScriptIdentity.uuid(
      "native-rescue-fuel-v1:\(funding.issue):\(revision):\(try NativeFlightReception.hash(request))"
    )
    return .init(
      operation: operation, request: request, revision: revision,
      balanceBefore: balance, balanceAfter: balance - result.cost,
      billedTenths: result.billedTenths,
      suppliedLY: result.after - request.before, fuelAfter: result.after,
      stockAfterTenths: request.offer.availableTenthsLY - result.billedTenths)
  }
  func quote(_ request: NativeArkFuelRequest) throws -> NativeRescueFuelQuote {
    guard valid, purchases.count < 128,
      NativeCustodianFuelMath.later(
        request.offer.contact, than: purchases.last?.request.offer.contact)
    else { throw NativeArkFuelRefusal.staleQuote }
    return try .init(purchase(request, balance: remainingCredits, revision: purchases.count))
  }
  func purchasing(_ quote: NativeRescueFuelQuote, current: NativeArkFuelRequest) throws
    -> NativeRescueFuelEscrow
  {
    let expected = try self.quote(current).purchase
    guard quote.purchase == expected else { throw NativeArkFuelRefusal.staleQuote }
    let next = Self(self, purchases: purchases + [expected], balance: expected.balanceAfter)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }
  func recordingRefusal(_ request: NativeArkFuelRequest) throws -> NativeRescueFuelEscrow {
    guard valid else { throw SaveError.invalidCommander }
    do {
      _ = try quote(request)
      throw SaveError.invalidCommander
    } catch let reason as NativeArkFuelRefusal {
      let next = Self(
        self, purchases: purchases, balance: remainingCredits,
        refusal: .init(request: request, balance: remainingCredits, reason: reason))
      guard next.valid else { throw SaveError.invalidCommander }
      return next
    }
  }
  var valid: Bool {
    guard funding.shapeValid,
      funding.credits == Self.initialCredits, (0...Self.initialCredits).contains(remainingCredits),
      purchases.count <= 128, Set(purchases.map(\.operation)).count == purchases.count
    else { return false }
    var balance = Self.initialCredits
    var previous: NativeArkFuelContact?
    for (index, receipt) in purchases.enumerated() {
      guard NativeCustodianFuelMath.later(receipt.request.offer.contact, than: previous),
        let expected = try? purchase(receipt.request, balance: balance, revision: index),
        expected == receipt
      else { return false }
      previous = receipt.request.offer.contact
      balance = receipt.balanceAfter
    }
    guard remainingCredits == balance else { return false }
    if let refusal {
      guard refusal.balance == balance else { return false }
      do {
        _ = try quoteWithoutValidation(refusal.request)
        return false
      } catch let reason as NativeArkFuelRefusal { return reason == refusal.reason } catch {
        return false
      }
    }
    return true
  }
  private func quoteWithoutValidation(_ request: NativeArkFuelRequest) throws
    -> NativeArkFuelCalculation
  {
    guard purchases.count < 128,
      NativeCustodianFuelMath.later(
        request.offer.contact, than: purchases.last?.request.offer.contact)
    else { throw NativeArkFuelRefusal.staleQuote }
    return try calculate(request, balance: remainingCredits)
  }
  static func == (lhs: NativeRescueFuelEscrow, rhs: NativeRescueFuelEscrow) -> Bool {
    lhs.funding == rhs.funding && lhs.remainingCredits == rhs.remainingCredits
      && lhs.purchases == rhs.purchases && lhs.refusal == rhs.refusal
  }
  private enum CodingKeys: String, CodingKey { case funding, remainingCredits, purchases, refusal }
  init(from decoder: any Decoder) throws {
    try NativeUtilityCoding.require(
      decoder, ["funding", "remainingCredits", "purchases"], optional: ["refusal"])
    let c = try decoder.container(keyedBy: CodingKeys.self)
    funding = try c.decode(NativeRescueFuelFunding.self, forKey: .funding)
    remainingCredits = try c.decode(Int.self, forKey: .remainingCredits)
    purchases = try NativeUtilityCoding.array(
      NativeArkFuelPurchase.self, key: .purchases, container: c, limit: 128)
    refusal = try c.decodeIfPresent(NativeArkFuelRefusalRecord.self, forKey: .refusal)
    guard valid else { throw SaveError.invalidCommander }
  }
  static func decodeClosed(_ data: Data) throws -> NativeRescueFuelEscrow {
    guard data.count <= 262_144 else { throw SaveError.invalidCommander }
    try ScriptSaveJSONPreflight.validate(data)
    let state = try JSONDecoder().decode(Self.self, from: data)
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      (root as NSDictionary).isEqual(
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)))
    else { throw SaveError.invalidCommander }
    return state
  }
}
