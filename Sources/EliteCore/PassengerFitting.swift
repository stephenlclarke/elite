import Foundation

public struct PassengerBerthQuote: Sendable {
  public let price: Int
  public let issues: [String]
  public var allowed: Bool { issues.isEmpty }
  let commander: Commander
  let galaxy: Int
  let system: Int
}
public enum PassengerCabin {
  public static let equipmentName = "Passenger Berth"
  /// Labelled project price estimate, in tenths of a credit; not a historical source price.
  public static let price = 10000
}
extension Game {
  public var passengerBerthQuote: PassengerBerthQuote {
    let price = shopPrice(
      Equipment(name: PassengerCabin.equipmentName, price: PassengerCabin.price, technology: 0))
    var projected = commander
    let berth = PassengerBerth()
    projected.accommodation.ownedBerths.append(berth)
    projected.accommodation.fitted.insert(berth.id)
    var issues =
      projected.passengerFit?.issues ?? ["This hull has no common accommodation adapter."]
    if !docked || !dockedAtMainStation {
      issues.append("Cabin fitting requires a main orbital station.")
    }
    if commander.availableCredits < price {
      issues.append("Insufficient cash for a passenger berth.")
    }
    if projected.accommodation.ownedBerths.count > 10000 {
      issues.append("Owned cabin capacity reached.")
    }
    return PassengerBerthQuote(
      price: price, issues: issues, commander: commander,
      galaxy: commander.galaxy, system: commander.system)
  }
  mutating func confirmPassengerBerth(_ quote: PassengerBerthQuote) throws {
    guard !paused, quote.allowed, commander == quote.commander,
      commander.galaxy == quote.galaxy, commander.system == quote.system,
      passengerBerthQuote.allowed
    else {
      throw MissionPackError("The cabin quote has changed; review the current fit and price.")
    }
    var candidate = commander
    let berth = PassengerBerth()
    candidate.accommodation.ownedBerths.append(berth)
    candidate.accommodation.fitted.insert(berth.id)
    if !candidate.unlimitedCash { candidate.credits -= quote.price }
    guard candidate.valid else { throw MissionPackError("The cabin cannot fit the current ship.") }
    commander = candidate
    notify("PASSENGER BERTH FITTED - 5T / 1 EQUIPMENT UNIT")
  }
  mutating func setPassengerBerthFitted(_ id: UUID, fitted: Bool) throws {
    guard docked, dockedAtMainStation, !paused,
      let berth = commander.accommodation.ownedBerths.first(where: { $0.id == id }), !berth.use.used
    else {
      throw MissionPackError("Only an empty owned cabin can be refitted or stored at a station.")
    }
    var candidate = commander
    if fitted {
      candidate.accommodation.fitted.insert(id)
    } else {
      candidate.accommodation.fitted.remove(id)
    }
    guard candidate.valid else { throw MissionPackError("The owned cabin cannot fit this ship.") }
    commander = candidate
  }
}
extension GameRuntime {
  public func passengerBerthQuote() -> PassengerBerthQuote { game.passengerBerthQuote }
  public func confirmPassengerBerth(_ quote: PassengerBerthQuote) throws {
    try scriptCommand { try $0.confirmPassengerBerth(quote) }
  }
  public func setPassengerBerthFitted(_ id: UUID, fitted: Bool) throws {
    try scriptCommand { try $0.setPassengerBerthFitted(id, fitted: fitted) }
  }
}
