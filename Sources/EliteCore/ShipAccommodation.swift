import Foundation

/// Common project fitting, kept separate from native edition-specific cabin/crew rules.
public struct ShipAccommodationProfile: Sendable, Equatable {
  public let shipID: String
  public let operatingCrew: Int
  public let intrinsicCrewQuarters: Int
  public let equipmentUnits: Int
  public let initialCharterBerths: Int
  public let crewBasis: String
  public let crewStatus: String
  public init(ship: CatalogueShip) throws {
    guard ship.game != nil,
      let profile = ship.profiles.first(where: { $0.group == "project-refit-v1" })
    else {
      throw MissionPackError("This hull has no selected common accommodation profile.")
    }
    func field(_ name: String) throws -> ShipSpec {
      guard let value = profile.fields.first(where: { $0.key == name }) else {
        throw MissionPackError("The selected accommodation profile is incomplete.")
      }
      return value
    }
    func integer(_ name: String) throws -> Int {
      guard let value = try field(name).number, value.isFinite, (0...100000).contains(value),
        value.rounded() == value
      else {
        throw MissionPackError("Accommodation counts must be finite nonnegative integers.")
      }
      return Int(value)
    }
    shipID = ship.id
    operatingCrew = try integer("required_crew_including_commander")
    intrinsicCrewQuarters = try integer("reserved_crew_accommodation")
    equipmentUnits = try integer("equipment_capacity_units")
    initialCharterBerths = try integer("initial_charter_passenger_berths")
    crewBasis = try field("required_crew_including_commander").basis
    crewStatus = try field("required_crew_including_commander").status
    guard operatingCrew >= 1, intrinsicCrewQuarters >= operatingCrew else {
      throw MissionPackError("The required operating complement needs its intrinsic quarters.")
    }
  }
}
public enum PassengerPlaceUse: Sendable, Equatable, Codable {
  case empty
  case occupied(person: UUID)
  case reserved(mission: UUID, person: UUID?)
  case extraCrew(person: UUID)
  var personID: UUID? {
    switch self {
    case .empty: nil
    case .occupied(let id), .extraCrew(let id): id
    case .reserved(_, let id): id
    }
  }
  var used: Bool { self != .empty }
}
public struct PassengerBerth: Sendable, Equatable, Codable, Identifiable {
  public let id: UUID
  public var lifeSupportWorking: Bool
  public var humanoidCompatible: Bool
  public var use: PassengerPlaceUse
  public init(
    id: UUID = UUID(), lifeSupportWorking: Bool = true, humanoidCompatible: Bool = true,
    use: PassengerPlaceUse = .empty
  ) {
    self.id = id
    self.lifeSupportWorking = lifeSupportWorking
    self.humanoidCompatible = humanoidCompatible
    self.use = use
  }
}
public struct AccommodationFit: Sendable, Equatable {
  public let usableCargo: Int
  public let freeEquipmentUnits: Int
  public let freeCompatiblePlaces: Int
  public let cabinCargo: Int
  public let issues: [String]
  public var allowed: Bool { issues.isEmpty }
}
public enum AccommodationFitting {
  public static let tonnesPerCommonBerth = 5
  public static let equipmentUnitsPerCommonBerth = 1

  /// Callers supply actual fitted equipment costs; theoretical expansion/storage are excluded.
  public static func evaluate(
    profile: ShipAccommodationProfile, holdTonnes: Int,
    freightTonnes: Int, otherFittedCargoTonnes: Int, otherFittedEquipmentUnits: Int,
    berths: [PassengerBerth], requestedParty: Int = 0, humanoidParty: Bool = true
  ) -> AccommodationFit {
    let quantities = [
      holdTonnes, freightTonnes, otherFittedCargoTonnes, otherFittedEquipmentUnits, requestedParty,
    ]
    guard quantities.allSatisfy({ (0...100000).contains($0) }), berths.count <= 10000 else {
      return .init(
        usableCargo: 0, freeEquipmentUnits: 0, freeCompatiblePlaces: 0, cabinCargo: 0,
        issues: ["Invalid accommodation quantities."])
    }
    let cabinCargo = berths.count * tonnesPerCommonBerth
    let usable = holdTonnes - freightTonnes - otherFittedCargoTonnes - cabinCargo
    let equipment =
      profile.equipmentUnits - otherFittedEquipmentUnits - berths.count
      * equipmentUnitsPerCommonBerth
    var issues: [String] = []
    if Set(berths.map(\.id)).count != berths.count {
      issues.append("A berth module cannot be fitted more than once.")
    }
    let people = berths.compactMap { $0.use.personID }
    if Set(people).count != people.count {
      issues.append("A person cannot occupy or reserve multiple places.")
    }
    if usable < 0 {
      issues.append(
        "Accommodation needs \(-usable) more tonne\(-usable == 1 ? "" : "s") of physical hold.")
    }
    if equipment < 0 { issues.append("Accommodation needs \(-equipment) more equipment units.") }
    if berths.contains(where: { $0.use.used && (!$0.lifeSupportWorking || !$0.humanoidCompatible) })
    {
      issues.append("Occupied or reserved accommodation needs compatible working life support.")
    }
    let free = berths.filter {
      !$0.use.used && $0.lifeSupportWorking && (humanoidParty ? $0.humanoidCompatible : false)
    }.count
    if requestedParty > 0 && !humanoidParty {
      issues.append("This party needs a separately supported environmental accommodation adapter.")
    }
    if requestedParty > free {
      issues.append("The party needs \(requestedParty-free) more compatible fitted berths.")
    }
    // Operating crew already has intrinsic quarters; it is not subtracted from hold or charter berths again.
    return .init(
      usableCargo: max(0, usable), freeEquipmentUnits: max(0, equipment),
      freeCompatiblePlaces: free, cabinCargo: cabinCargo, issues: issues)
  }
}
