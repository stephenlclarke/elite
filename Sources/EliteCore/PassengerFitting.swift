import Foundation

public struct PassengerBerthQuote: Sendable {
  public let grade: PassengerCabinGrade
  public let price: Int
  public let issues: [String]
  public var allowed: Bool { issues.isEmpty }
  let commander: Commander
  let galaxy: Int
  let system: Int
}
public enum PassengerCabin {
  public static let equipmentName = PassengerCabinGrade.stateroomSingle.equipmentName
  /// Labelled project price estimate, in tenths of a credit; not a historical source price.
  public static let price = PassengerCabinGrade.stateroomSingle.price
}
extension Game {
  public var passengerBerthQuote: PassengerBerthQuote { passengerCabinQuote(.stateroomSingle) }
  public func passengerCabinQuote(_ grade: PassengerCabinGrade) -> PassengerBerthQuote {
    let price = shopPrice(
      Equipment(name: grade.equipmentName, price: grade.price, technology: 0))
    let fit = commander.passengerFit
    var issues = fit?.issues ?? ["This hull has no common accommodation adapter."]
    if let fit {
      if fit.usableCargo < AccommodationFitting.tonnesPerCabin {
        issues.append("A complete cabin needs five tonnes of free physical hold.")
      }
      if fit.freeEquipmentUnits < AccommodationFitting.equipmentUnitsPerCabin {
        issues.append("A complete cabin needs one free equipment unit.")
      }
    }
    if !commander.accommodation.valid { issues.append("Current cabin custody is invalid.") }
    if !docked || !dockedAtMainStation {
      issues.append("Cabin fitting requires a main orbital station.")
    }
    if commander.availableCredits < price {
      issues.append("Insufficient cash for a passenger cabin.")
    }
    if commander.accommodation.ownedCabins.count >= 10000
      || commander.accommodation.ownedBerths.count > 10000 - grade.places
    {
      issues.append("Owned cabin capacity reached.")
    }
    return PassengerBerthQuote(
      grade: grade, price: price, issues: issues, commander: commander,
      galaxy: commander.galaxy, system: commander.system)
  }
  @discardableResult
  mutating func confirmPassengerBerth(_ quote: PassengerBerthQuote) throws -> UUID {
    let current = passengerCabinQuote(quote.grade)
    guard !paused, quote.allowed, commander == quote.commander,
      commander.galaxy == quote.galaxy, commander.system == quote.system,
      current.allowed, current.price == quote.price
    else {
      throw MissionPackError("The cabin quote has changed; review the current fit and price.")
    }
    var candidate = commander
    let cabin = candidate.accommodation.addCabin(quote.grade)
    if !candidate.unlimitedCash { candidate.credits -= quote.price }
    guard candidate.valid else { throw MissionPackError("The cabin cannot fit the current ship.") }
    commander = candidate
    notify("CABIN FITTED - 5T / 1 EQUIPMENT UNIT")
    return cabin
  }
  mutating func setPassengerBerthFitted(_ id: UUID, fitted: Bool) throws {
    guard docked, dockedAtMainStation, !paused,
      commander.accommodation.ownedCabins.contains(where: { $0.id == id }),
      commander.accommodation.cabinIsEmpty(id)
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
  public func passengerCabinQuote(_ grade: PassengerCabinGrade) -> PassengerBerthQuote {
    game.passengerCabinQuote(grade)
  }
  public func confirmPassengerBerth(_ quote: PassengerBerthQuote) throws {
    _ = try passengerBerthCommand { try $0.confirmPassengerBerth(quote) }
  }
  public func setPassengerBerthFitted(_ id: UUID, fitted: Bool) throws {
    try passengerBerthCommand { try $0.setPassengerBerthFitted(id, fitted: fitted) }
  }
  private func passengerBerthCommand<T>(_ action: (inout Game) throws -> T) throws -> T {
    let writerAvailable = scriptSaveURL != nil
    let result = try scriptCommand { candidate in
      let requiredBefore = candidate.requiresScriptDurability
      let result = try action(&candidate)
      guard writerAvailable || !(requiredBefore || candidate.requiresScriptDurability) else {
        throw SaveError.invalidCommander
      }
      return result
    }
    game.inventoryContextEpoch = .init()
    return result
  }
}
