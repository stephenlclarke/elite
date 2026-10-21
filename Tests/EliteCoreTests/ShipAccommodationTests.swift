import Foundation
import Testing

@testable import EliteCore

private func testAccommodationFit(
  profile: ShipAccommodationProfile, holdTonnes: Int, freightTonnes: Int,
  otherFittedCargoTonnes: Int, otherFittedEquipmentUnits: Int,
  berths: [PassengerBerth], requestedParty: Int = 0, humanoidParty: Bool = true
) -> AccommodationFit {
  let ids = Set(berths.map(\.cabinID))
  return AccommodationFitting.evaluate(
    profile: profile, holdTonnes: holdTonnes, freightTonnes: freightTonnes,
    otherFittedCargoTonnes: otherFittedCargoTonnes,
    otherFittedEquipmentUnits: otherFittedEquipmentUnits,
    cabins: ids.map { OwnedPassengerCabin(id: $0, grade: .stateroomSingle) },
    berths: berths, requestedParty: requestedParty, humanoidParty: humanoidParty)
}
private func cobraAccommodation() throws -> ShipAccommodationProfile {
  try ShipAccommodationProfile(ship: #require(ShipCatalogue.ship("SH023")))
}
@Test func commonCrewProfilesAreCompleteAndKeepOperatingQuartersOutsideCargo() throws {
  let ships = ShipCatalogue.all.filter {
    $0.game != nil && $0.profiles.contains(where: { $0.group == "project-refit-v1" })
  }
  #expect(ships.count == 161)
  for ship in ships {
    let profile = try ShipAccommodationProfile(ship: ship)
    #expect(profile.operatingCrew >= 1 && profile.intrinsicCrewQuarters >= profile.operatingCrew)
    let report = testAccommodationFit(
      profile: profile, holdTonnes: ship.game!.cargo,
      freightTonnes: 0, otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0, berths: [])
    #expect(report.allowed && report.usableCargo == ship.game!.cargo)
    #expect(report.freeCompatiblePlaces == 0)
    // The selected Sunray refit is the sole authored first-acquisition berth exception.
    #expect(profile.initialCharterBerths == (ship.id == "SH169" ? 1 : 0))
  }
}
@Test func aPassengerPartyNeedsActuallyFittedSparePlacesAndBothFitBudgets() throws {
  let profile = try cobraAccommodation()
  let cabin = PassengerBerth(cabinID: UUID())
  let noCabin = testAccommodationFit(
    profile: profile, holdTonnes: 20, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0, berths: [], requestedParty: 1)
  #expect(!noCabin.allowed)
  let fits = testAccommodationFit(
    profile: profile, holdTonnes: 20, freightTonnes: 15,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 11, berths: [cabin], requestedParty: 1)
  #expect(fits.allowed && fits.usableCargo == 0 && fits.freeEquipmentUnits == 0)
  let holdFull = testAccommodationFit(
    profile: profile, holdTonnes: 20, freightTonnes: 16,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 11, berths: [cabin], requestedParty: 1)
  #expect(!holdFull.allowed && holdFull.issues.contains { $0.contains("1 more tonne") })
  let equipmentFull = testAccommodationFit(
    profile: profile, holdTonnes: 20, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 12, berths: [cabin], requestedParty: 1)
  #expect(
    !equipmentFull.allowed && equipmentFull.issues.contains { $0.contains("1 more equipment") })
}
@Test func occupiedReservedAndExtraCrewPlacesCannotBeReusedOrStoredAsEmpty() throws {
  let profile = try cobraAccommodation()
  let person = UUID()
  let mission = UUID()
  let occupied = PassengerBerth(cabinID: UUID(), use: .occupied(person: person))
  let reserved = PassengerBerth(cabinID: UUID(), use: .reserved(mission: mission, person: nil))
  let extra = PassengerBerth(cabinID: UUID(), use: .extraCrew(person: UUID()))
  let report = testAccommodationFit(
    profile: profile, holdTonnes: 20, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0, berths: [occupied, reserved, extra],
    requestedParty: 1)
  #expect(!report.allowed && report.freeCompatiblePlaces == 0 && report.cabinCargo == 15)
  let duplicate = testAccommodationFit(
    profile: profile, holdTonnes: 20, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0,
    berths: [
      occupied, PassengerBerth(cabinID: UUID(), use: .reserved(mission: mission, person: person)),
    ])
  #expect(!duplicate.allowed)
  let badLife = testAccommodationFit(
    profile: profile, holdTonnes: 20, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0,
    berths: [
      PassengerBerth(cabinID: UUID(), lifeSupportWorking: false, use: .occupied(person: person))
    ])
  #expect(!badLife.allowed)
}
@Test func zeroPhysicalHoldAndAlienCompatibilityDoNotGainFreeAccommodation() throws {
  let ship = try #require(ShipCatalogue.ship("SH033"))
  let cabin = PassengerBerth(cabinID: UUID())
  let profile = try ShipAccommodationProfile(ship: ship)
  let zero = testAccommodationFit(
    profile: profile, holdTonnes: ship.game!.cargo, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0, berths: [cabin], requestedParty: 1)
  #expect(!zero.allowed && zero.cabinCargo == 5)
  let alien = testAccommodationFit(
    profile: try cobraAccommodation(), holdTonnes: 20, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0, berths: [cabin], requestedParty: 1,
    humanoidParty: false)
  #expect(!alien.allowed && alien.freeCompatiblePlaces == 0)
  let duplicate = testAccommodationFit(
    profile: try cobraAccommodation(), holdTonnes: 20, freightTonnes: 0,
    otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: 0, berths: [cabin, cabin])
  #expect(!duplicate.allowed)
}

@Test func everyFlyableHullHasAnExplicitAccommodationAdapterIncludingEstimatedLiberator() throws {
  let ships = ShipCatalogue.all.filter { $0.game != nil }
  #expect(ships.count == 162)
  for ship in ships { _ = try ShipAccommodationProfile(ship: ship) }
  let liberator = try #require(ShipCatalogue.ship("SH171"))
  let profile = try ShipAccommodationProfile(ship: liberator)
  #expect(
    profile.operatingCrew == 4 && profile.intrinsicCrewQuarters == 4 && profile.equipmentUnits == 32
  )
  #expect(profile.crewStatus == "estimated" && profile.crewBasis.contains("not TV canon"))
  var commander = Commander()
  commander.shipID = liberator.id
  #expect(
    commander.passengerFit?.usableCargo == 120 && commander.passengerFit?.freeCompatiblePlaces == 0)
  #expect(
    commander.gameShipProfile.fields.first { $0.key == "required_crew_including_commander" }?.status
      == "estimated")
  let crew = try #require(
    commander.gameShipProfile.fields.first { $0.key == "required_crew_including_commander" })
  #expect(crew.number == 4 && crew.basis == profile.crewBasis)
  let cabin = PassengerBerth(cabinID: UUID())
  commander.accommodation.ownedCabins = [.init(id: cabin.cabinID, grade: .stateroomSingle)]
  commander.accommodation.ownedBerths = [cabin]
  commander.accommodation.fitted = [cabin.cabinID]
  #expect(commander.valid && commander.passengerFit?.usableCargo == 115)
  #expect(
    commander.gameShipProfile.fields.first { $0.key == "fitted_passenger_berths" }?.number == 1)
  #expect(
    commander.gameShipProfile.fields.first { $0.key == "usable_cargo_after_fit" }?.number == 115)
}

@Test func invalidCabinCustodyDoesNotInventShowroomAccommodationFacts() {
  var commander = Commander()
  commander.accommodation.fitted = [UUID()]
  #expect(!commander.accommodation.valid)
  #expect(
    commander.nativeAccommodationFields.allSatisfy {
      $0.number == nil && $0.text == "Unavailable" && $0.status == "unavailable"
    })
}
