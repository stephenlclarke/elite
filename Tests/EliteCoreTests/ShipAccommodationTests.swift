import Foundation
import Testing

@testable import EliteCore

private func cobraAccommodation() throws -> ShipAccommodationProfile {
  try ShipAccommodationProfile(ship: #require(ShipCatalogue.ship("SH023")))
}
@Test func commonCrewProfilesAreCompleteAndKeepOperatingQuartersOutsideCargo() throws {
  let ships = ShipCatalogue.all.filter {
    $0.game != nil && $0.profiles.contains(where: { $0.group == "project-refit-v1" })
  }
  #expect(ships.count == 158)
  for ship in ships {
    let profile = try ShipAccommodationProfile(ship: ship)
    #expect(profile.operatingCrew >= 1 && profile.intrinsicCrewQuarters >= profile.operatingCrew)
    let report = AccommodationFitting.evaluate(
      profile: profile, holdTonnes: ship.game!.cargo,
      freightTonnes: 0, otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0, berths: [])
    #expect(report.allowed && report.usableCargo == ship.game!.cargo)
    #expect(report.freeCompatiblePlaces == 0 && profile.initialCharterBerths == 0)
  }
}
@Test func aPassengerPartyNeedsActuallyFittedSparePlacesAndBothFitBudgets() throws {
  let profile = try cobraAccommodation()
  let cabin = PassengerBerth()
  let noCabin = AccommodationFitting.evaluate(
    profile: profile, holdTonnes: 20, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0, berths: [], requestedParty: 1)
  #expect(!noCabin.allowed)
  let fits = AccommodationFitting.evaluate(
    profile: profile, holdTonnes: 20, freightTonnes: 15,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 11, berths: [cabin], requestedParty: 1)
  #expect(fits.allowed && fits.usableCargo == 0 && fits.freeEquipmentUnits == 0)
  let holdFull = AccommodationFitting.evaluate(
    profile: profile, holdTonnes: 20, freightTonnes: 16,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 11, berths: [cabin], requestedParty: 1)
  #expect(!holdFull.allowed && holdFull.issues.contains { $0.contains("1 more tonne") })
  let equipmentFull = AccommodationFitting.evaluate(
    profile: profile, holdTonnes: 20, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 12, berths: [cabin], requestedParty: 1)
  #expect(
    !equipmentFull.allowed && equipmentFull.issues.contains { $0.contains("1 more equipment") })
}
@Test func occupiedReservedAndExtraCrewPlacesCannotBeReusedOrStoredAsEmpty() throws {
  let profile = try cobraAccommodation()
  let person = UUID()
  let mission = UUID()
  let occupied = PassengerBerth(use: .occupied(person: person))
  let reserved = PassengerBerth(use: .reserved(mission: mission, person: nil))
  let extra = PassengerBerth(use: .extraCrew(person: UUID()))
  let report = AccommodationFitting.evaluate(
    profile: profile, holdTonnes: 20, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0, berths: [occupied, reserved, extra],
    requestedParty: 1)
  #expect(!report.allowed && report.freeCompatiblePlaces == 0 && report.cabinCargo == 15)
  let duplicate = AccommodationFitting.evaluate(
    profile: profile, holdTonnes: 20, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0,
    berths: [occupied, PassengerBerth(use: .reserved(mission: mission, person: person))])
  #expect(!duplicate.allowed)
  let badLife = AccommodationFitting.evaluate(
    profile: profile, holdTonnes: 20, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0,
    berths: [PassengerBerth(lifeSupportWorking: false, use: .occupied(person: person))])
  #expect(!badLife.allowed)
}
@Test func zeroPhysicalHoldAndAlienCompatibilityDoNotGainFreeAccommodation() throws {
  let ship = try #require(ShipCatalogue.ship("SH033"))
  let cabin = PassengerBerth()
  let profile = try ShipAccommodationProfile(ship: ship)
  let zero = AccommodationFitting.evaluate(
    profile: profile, holdTonnes: ship.game!.cargo, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0, berths: [cabin], requestedParty: 1)
  #expect(!zero.allowed && zero.cabinCargo == 5)
  let alien = AccommodationFitting.evaluate(
    profile: try cobraAccommodation(), holdTonnes: 20, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0, berths: [cabin], requestedParty: 1,
    humanoidParty: false)
  #expect(!alien.allowed && alien.freeCompatiblePlaces == 0)
  let duplicate = AccommodationFitting.evaluate(
    profile: try cobraAccommodation(), holdTonnes: 20, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0, berths: [cabin, cabin])
  #expect(!duplicate.allowed)
}
