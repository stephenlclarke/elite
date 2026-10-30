import Foundation

/// Historical NPC contact, not the player's docking receipt or reusable service authority.
struct NativeArkFuelContact: Codable, Sendable, Equatable {
  let mission: UUID
  let ark: UUID
  let station: NativeMainStationIdentity
  let stationActor: ActorIdentity
  let arkActor: ActorIdentity
  let sequence: UInt64
  let physicalTime: Double
  var valid: Bool {
    station.valid && stationActor.system == station.system && arkActor.system == station.system
      && stationActor.visit == arkActor.visit && stationActor.visit > 0
      && stationActor.visit < UInt64(Int64.max)
      && stationActor.entity == 1 && arkActor.entity > 1 && arkActor.entity < UInt64(Int64.max)
      && sequence > 0 && sequence < UInt64(Int64.max)
      && physicalTime.isFinite && (0...1e12).contains(physicalTime)
  }
}

/// The native supplier must provide its actual current available stock and price at the dock.
struct NativeArkFuelOffer: Codable, Sendable, Equatable {
  let contact: NativeArkFuelContact
  let supplierRevision: UInt64
  let availableTenthsLY: Int
  let pricePerTenth: Int
  let supplierActor: ActorIdentity
  let quotedAtPhysicalTime: Double
  init(
    contact: NativeArkFuelContact, supplierRevision: UInt64, availableTenthsLY: Int,
    pricePerTenth: Int, supplierActor: ActorIdentity? = nil, quotedAtPhysicalTime: Double? = nil
  ) {
    self.contact = contact
    self.supplierRevision = supplierRevision
    self.availableTenthsLY = availableTenthsLY
    self.pricePerTenth = pricePerTenth
    self.supplierActor = supplierActor ?? contact.stationActor
    self.quotedAtPhysicalTime = quotedAtPhysicalTime ?? contact.physicalTime
  }
  var valid: Bool {
    contact.valid && supplierRevision < UInt64(Int64.max)
      && supplierActor.system == contact.station.system && supplierActor.entity == 1
      && supplierActor.visit >= contact.stationActor.visit
      && supplierActor.visit < UInt64(Int64.max)
      && quotedAtPhysicalTime.isFinite && quotedAtPhysicalTime >= contact.physicalTime
      && quotedAtPhysicalTime <= 1e12
      && (0...10000).contains(availableTenthsLY)
      && pricePerTenth > 0 && pricePerTenth == Equipment.base[0].price
  }
}

enum NativeArkFuelRefusal: String, Codable, Sendable, Error {
  case invalidInput, foreignDock, noFuelNeeded, unavailableStock, insufficientEscrow, staleQuote
}

struct NativeArkFuelCalculation: Sendable, Equatable {
  let billedTenths: Int
  let cost: Int
  let after: Double
}

struct NativeArkFuelRequest: Codable, Sendable, Equatable {
  let offer: NativeArkFuelOffer
  let before: Double
  let nextHopLY: Double
}

struct NativeArkFuelRefusalRecord: Codable, Sendable, Equatable {
  let request: NativeArkFuelRequest
  let balance: Int
  let reason: NativeArkFuelRefusal
}

struct NativeArkFuelPurchase: Codable, Sendable, Equatable {
  let operation: UUID
  let request: NativeArkFuelRequest
  let revision: Int
  let balanceBefore: Int
  let balanceAfter: Int
  let billedTenths: Int
  let suppliedLY: Double
  let fuelAfter: Double
  let stockAfterTenths: Int
}

struct NativeArkFuelQuote: Sendable {
  fileprivate let purchase: NativeArkFuelPurchase
  fileprivate init(_ purchase: NativeArkFuelPurchase) { self.purchase = purchase }
  var operation: UUID { purchase.operation }
  var cost: Int { purchase.balanceBefore - purchase.balanceAfter }
  var suppliedLY: Double { purchase.suppliedLY }
  var fuelAfter: Double { purchase.fuelAfter }
  var supplierStockAfterTenths: Int { purchase.stockAfterTenths }
}

/// One opening custodian issue; no constructor or operation touches player cash or creates fuel.
final class NativeArkFuelEscrow: Codable, Sendable, Equatable {
  let owner: UUID
  let mission: UUID
  let ark: UUID
  let loanOperation: UUID
  let openingCredits: Int
  let remainingCredits: Int
  let purchases: [NativeArkFuelPurchase]
  let refusal: NativeArkFuelRefusalRecord?
  let closure: NativeArkFuelClosure?
  private let reserveFunding: UUID?
  var issue: NativeInductionArkIssue { reserveFunding == nil ? .original : .reserve }
  static let initialCredits = 10_000  // 1000 CR in native decicredits; explicit project funding.

  init(source: NativeInductionArkSource) throws {
    guard source.valid else { throw SaveError.invalidCommander }
    owner = source.owner
    mission = source.mission
    ark = source.actor
    loanOperation = source.loanOperation
    reserveFunding = source.reserve?.fuelFunding
    openingCredits = Self.initialCredits
    remainingCredits = openingCredits
    purchases = []
    refusal = nil
    closure = nil
  }
  private init(
    _ previous: NativeArkFuelEscrow, purchases: [NativeArkFuelPurchase],
    balance: Int, refusal: NativeArkFuelRefusalRecord? = nil, closure: NativeArkFuelClosure? = nil
  ) {
    owner = previous.owner
    mission = previous.mission
    ark = previous.ark
    loanOperation = previous.loanOperation
    reserveFunding = previous.reserveFunding
    openingCredits = previous.openingCredits
    remainingCredits = balance
    self.purchases = purchases
    self.refusal = refusal
    self.closure = closure
  }
  private enum CodingKeys: String, CodingKey {
    case owner, mission, ark, loanOperation, openingCredits, remainingCredits, purchases, refusal,
      closure, reserveFunding
  }
  init(from decoder: any Decoder) throws {
    try NativeUtilityCoding.require(
      decoder,
      [
        "owner", "mission", "ark", "loanOperation", "openingCredits", "remainingCredits",
        "purchases",
      ],
      optional: ["refusal", "closure", "reserveFunding"])
    let values = try decoder.container(keyedBy: CodingKeys.self)
    owner = try values.decode(UUID.self, forKey: .owner)
    mission = try values.decode(UUID.self, forKey: .mission)
    ark = try values.decode(UUID.self, forKey: .ark)
    loanOperation = try values.decode(UUID.self, forKey: .loanOperation)
    openingCredits = try values.decode(Int.self, forKey: .openingCredits)
    remainingCredits = try values.decode(Int.self, forKey: .remainingCredits)
    purchases = try NativeUtilityCoding.array(
      NativeArkFuelPurchase.self, key: .purchases,
      container: values, limit: 128)
    refusal = try values.decodeIfPresent(NativeArkFuelRefusalRecord.self, forKey: .refusal)
    closure = try values.decodeIfPresent(NativeArkFuelClosure.self, forKey: .closure)
    reserveFunding = try values.decodeIfPresent(UUID.self, forKey: .reserveFunding)
    guard valid else { throw SaveError.invalidCommander }
  }

  static func decodeClosed(_ data: Data) throws -> NativeArkFuelEscrow {
    guard data.count <= 262_144 else { throw SaveError.invalidCommander }
    try ScriptSaveJSONPreflight.validate(data)
    let state = try JSONDecoder().decode(Self.self, from: data)
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      (root as NSDictionary).isEqual(
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)))
    else { throw SaveError.invalidCommander }
    return state
  }

  static func == (a: NativeArkFuelEscrow, b: NativeArkFuelEscrow) -> Bool {
    a.owner == b.owner && a.mission == b.mission && a.ark == b.ark
      && a.loanOperation == b.loanOperation && a.openingCredits == b.openingCredits
      && a.remainingCredits == b.remainingCredits && a.purchases == b.purchases
      && a.refusal == b.refusal && a.closure == b.closure && a.reserveFunding == b.reserveFunding
  }

  private func calculate(_ request: NativeArkFuelRequest, balance: Int)
    throws -> NativeArkFuelCalculation
  {
    guard let profile = try? NativeInductionArkSource.profile() else {
      throw NativeArkFuelRefusal.invalidInput
    }
    return try NativeCustodianFuelMath.calculate(
      request, balance: balance, owner: owner, mission: mission, vessel: ark,
      galaxy: NativeWayfarerInduction.seedSource.galaxy, profile: profile)
  }

  private func purchase(_ request: NativeArkFuelRequest, balance: Int, revision: Int)
    throws -> NativeArkFuelPurchase
  {
    let result = try calculate(request, balance: balance)
    let operation = ScriptIdentity.uuid(
      "native-ark-fuel-v1:\(ark):\(revision):\(try NativeFlightReception.hash(request))")
    return .init(
      operation: operation, request: request, revision: revision,
      balanceBefore: balance, balanceAfter: balance - result.cost,
      billedTenths: result.billedTenths, suppliedLY: result.after - request.before,
      fuelAfter: result.after,
      stockAfterTenths: request.offer.availableTenthsLY - result.billedTenths)
  }

  func quote(_ request: NativeArkFuelRequest) throws -> NativeArkFuelQuote {
    guard valid, closure == nil, purchases.count < 128,
      Self.later(request.offer.contact, than: purchases.last?.request.offer.contact)
    else { throw NativeArkFuelRefusal.staleQuote }
    return try .init(purchase(request, balance: remainingCredits, revision: purchases.count))
  }

  /// Caller must publish this escrow, the same ship's fuel and supplier stock atomically.
  func purchasing(_ quote: NativeArkFuelQuote, current: NativeArkFuelRequest) throws -> Self {
    let expected = try self.quote(current).purchase
    guard quote.purchase == expected else { throw NativeArkFuelRefusal.staleQuote }
    let next = Self(self, purchases: purchases + [expected], balance: expected.balanceAfter)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }

  func recordingRefusal(_ request: NativeArkFuelRequest) throws -> Self {
    guard closure == nil, valid else { throw SaveError.invalidCommander }
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

  private static func later(_ contact: NativeArkFuelContact, than previous: NativeArkFuelContact?)
    -> Bool
  {
    guard let previous else { return true }
    return contact.sequence > previous.sequence && contact.physicalTime >= previous.physicalTime
      && contact.arkActor.visit >= previous.arkActor.visit
  }

  func closing(at receipt: NativeInductionSeedReception) throws -> NativeArkFuelEscrow {
    guard valid, closure == nil, receipt.owner == owner, receipt.parent == mission,
      receipt.registeredArk == ark, receipt.loanOperation == loanOperation
    else { throw SaveError.invalidCommander }
    let closure = NativeArkFuelClosure(
      operation: NativeArkFuelClosure.identity(
        ark: ark, receiving: receipt.operation, credits: remainingCredits),
      receivingOperation: receipt.operation,
      recipient: NativeArkFuelClosure.custodian(owner: owner),
      balanceBefore: remainingCredits, returnedCredits: remainingCredits)
    let next = NativeArkFuelEscrow(self, purchases: purchases, balance: 0, closure: closure)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }

  func retiring(at receipt: NativeArkRecoveryReceipt) throws -> NativeArkFuelEscrow {
    guard valid, closure == nil, issue == .original, receipt.retired.registeredArk == ark,
      receipt.retired.loanOperation == loanOperation
    else { throw SaveError.invalidCommander }
    let closure = NativeArkFuelClosure(
      operation: NativeArkFuelClosure.recoveryIdentity(
        ark: ark, recovery: receipt.operation, credits: remainingCredits),
      recoveryOperation: receipt.operation, recipient: NativeArkFuelClosure.custodian(owner: owner),
      balanceBefore: remainingCredits, returnedCredits: remainingCredits)
    let next = NativeArkFuelEscrow(self, purchases: purchases, balance: 0, closure: closure)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }

  var valid: Bool {
    guard mission == NativeWayfarerInduction.mission(owner: owner),
      ark
        == NativeInductionArkSource.actorIdentity(
          mission: mission, loan: loanOperation, issue: issue),
      reserveFunding == nil
        || reserveFunding == NativeInductionArkReserve.funding(owner: owner, mission: mission),
      openingCredits == Self.initialCredits, (0...openingCredits).contains(remainingCredits),
      purchases.count <= 128, Set(purchases.map(\.operation)).count == purchases.count
    else { return false }
    var balance = openingCredits
    var previous: NativeArkFuelContact?
    for (index, receipt) in purchases.enumerated() {
      guard Self.later(receipt.request.offer.contact, than: previous),
        let expected = try? purchase(receipt.request, balance: balance, revision: index),
        expected == receipt
      else { return false }
      previous = receipt.request.offer.contact
      balance = receipt.balanceAfter
    }
    if let closure {
      guard remainingCredits == 0, refusal == nil, closure.balanceBefore == balance,
        closure.returnedCredits == balance,
        closure.recipient == NativeArkFuelClosure.custodian(owner: owner)
      else { return false }
      if let receiving = closure.receivingOperation, closure.recoveryOperation == nil {
        return closure.operation
          == NativeArkFuelClosure.identity(ark: ark, receiving: receiving, credits: balance)
      }
      if let recovery = closure.recoveryOperation, closure.receivingOperation == nil {
        return closure.operation
          == NativeArkFuelClosure.recoveryIdentity(ark: ark, recovery: recovery, credits: balance)
      }
      return false
    }
    guard balance == remainingCredits else { return false }
    if let refusal {
      guard refusal.balance == balance else { return false }
      do {
        if purchases.count >= 128 || !Self.later(refusal.request.offer.contact, than: previous) {
          throw NativeArkFuelRefusal.staleQuote
        }
        _ = try calculate(refusal.request, balance: balance)
        return false
      } catch let reason as NativeArkFuelRefusal {
        return reason == refusal.reason
      } catch { return false }
    }
    return true
  }
}
