import Foundation

public enum PassengerTransportMode: String, Codable, Sendable {
  case awake, stasis
}

/// Initial project balance defaults; every layout is one 5t, one-unit physical module.
public enum PassengerCabinGrade: String, CaseIterable, Codable, Sendable {
  case cryogenic, economy, standard, luxury, stateroomSingle, stateroomDouble

  public var places: Int {
    switch self {
    case .cryogenic: 20
    case .economy: 8
    case .standard: 4
    case .luxury, .stateroomDouble: 2
    case .stateroomSingle: 1
    }
  }
  public var price: Int {
    switch self {
    case .cryogenic: 10000
    case .economy: 25000
    case .standard: 50000
    case .luxury: 100000
    case .stateroomSingle, .stateroomDouble: 200000
    }
  }
  public var equipmentName: String {
    switch self {
    case .cryogenic: "Packed Stasis Cabin"
    case .economy: "Economy Cabin"
    case .standard: "Standard Cabin"
    case .luxury: "Luxury Cabin"
    case .stateroomSingle: "Single Stateroom"
    case .stateroomDouble: "Double Stateroom"
    }
  }
  public var description: String {
    switch self {
    case .cryogenic: "20 packed stasis pods in a cargo module; no walk-around quarters."
    case .economy: "8 shared economy places with cryopods."
    case .standard: "4 shared standard places with cryopods."
    case .luxury: "2 shared luxury places with cryopods."
    case .stateroomSingle: "1-person stateroom; long-journey cryopod."
    case .stateroomDouble: "2-person stateroom; long-journey cryopods."
    }
  }
  public var supportsAwake: Bool { self != .cryogenic }
  public static func equipment(_ name: String) -> Self? {
    allCases.first { $0.equipmentName == name }
  }
}

public struct OwnedPassengerCabin: Sendable, Equatable, Codable, Identifiable {
  public let id: UUID
  public let grade: PassengerCabinGrade
  public var lifeSupportWorking: Bool
  public var stasisWorking: Bool
  private enum CodingKeys: String, CodingKey { case id, grade, lifeSupportWorking, stasisWorking }
  public init(from decoder: any Decoder) throws {
    try validateCabinRecordKeys(decoder, ["id", "grade", "lifeSupportWorking", "stasisWorking"])
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    id = try fields.decode(UUID.self, forKey: .id)
    grade = try fields.decode(PassengerCabinGrade.self, forKey: .grade)
    lifeSupportWorking = try fields.decode(Bool.self, forKey: .lifeSupportWorking)
    stasisWorking = try fields.decode(Bool.self, forKey: .stasisWorking)
  }
  public init(
    id: UUID = UUID(), grade: PassengerCabinGrade,
    lifeSupportWorking: Bool = true, stasisWorking: Bool = true
  ) {
    self.id = id
    self.grade = grade
    self.lifeSupportWorking = lifeSupportWorking
    self.stasisWorking = stasisWorking
  }
}

extension ShipAccommodation {
  public var fittedCabins: [OwnedPassengerCabin] { ownedCabins.filter { fitted.contains($0.id) } }
  public var storedCabins: [OwnedPassengerCabin] { ownedCabins.filter { !fitted.contains($0.id) } }
  public func cabin(for place: PassengerBerth) -> OwnedPassengerCabin? {
    ownedCabins.first { $0.id == place.cabinID }
  }
  public func placeIsFitted(_ id: UUID) -> Bool {
    ownedBerths.contains { $0.id == id && fitted.contains($0.cabinID) }
  }
  public func cabinIsEmpty(_ id: UUID) -> Bool {
    ownedBerths.allSatisfy { $0.cabinID != id || !$0.use.used }
  }
  public func supports(_ place: PassengerBerth, mode: PassengerTransportMode) -> Bool {
    guard fitted.contains(place.cabinID), let cabin = cabin(for: place),
      cabin.lifeSupportWorking, place.lifeSupportWorking, place.humanoidCompatible
    else { return false }
    return mode == .stasis ? cabin.stasisWorking : cabin.grade.supportsAwake
  }
  /// Private bookings reserve the whole physical module, even if it has several places.
  public func availablePlaces(
    mode: PassengerTransportMode = .awake, privateCabin: Bool = false
  ) -> [PassengerBerth] {
    let cabins = Dictionary(
      ownedCabins.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let used = ownedBerths.filter { $0.use.used }
    let occupied = Set(used.map(\.cabinID))
    let exclusive = Set(used.filter(\.privateCabin).map(\.cabinID))
    var selected: Set<UUID> = []
    return ownedBerths.sorted { $0.id.uuidString < $1.id.uuidString }.filter { place in
      guard !place.use.used, fitted.contains(place.cabinID), let cabin = cabins[place.cabinID],
        cabin.lifeSupportWorking, place.lifeSupportWorking, place.humanoidCompatible,
        mode == .stasis ? cabin.stasisWorking : cabin.grade.supportsAwake,
        !exclusive.contains(place.cabinID), !privateCabin || !occupied.contains(place.cabinID)
      else { return false }
      return !privateCabin || selected.insert(place.cabinID).inserted
    }.map { place in
      var offered = place
      offered.mode = mode
      offered.privateCabin = privateCabin
      return offered
    }
  }
  /// Historical offers survive genuine hull loss. Their immutable grade/layout facts
  /// are snapshots, while any still-owned cabin/place must agree with them.
  func validPrivateOffer(_ places: [PassengerBerth]) -> Bool {
    Set(places.map(\.cabinID)).count == places.count
      && Set(places.map(\.id)).count == places.count
      && places.allSatisfy { place in
        guard place.cabinGrade.supportsAwake, place.mode == .awake, place.privateCabin,
          place.id != place.cabinID, (0..<place.cabinGrade.places).contains(place.ordinal)
        else { return false }
        if let cabin = cabin(for: place), cabin.grade != place.cabinGrade { return false }
        if let owned = ownedBerths.first(where: { $0.id == place.id }) {
          return owned.cabinID == place.cabinID && owned.ordinal == place.ordinal
            && owned.cabinGrade == place.cabinGrade
        }
        return true
      }
  }
  /// Creates the complete fixed layout once; callers publish only a validated candidate.
  @discardableResult
  public mutating func addCabin(
    _ grade: PassengerCabinGrade, id: UUID = UUID(), fitted shouldFit: Bool = true
  ) -> UUID {
    ownedCabins.append(.init(id: id, grade: grade))
    ownedBerths += (0..<grade.places).map {
      PassengerBerth(cabinID: id, cabinGrade: grade, ordinal: $0)
    }
    if shouldFit { fitted.insert(id) }
    return id
  }
  public var cabinFacts: [String] {
    fittedCabins.map {
      "\($0.id):\($0.grade.rawValue):\($0.lifeSupportWorking):\($0.stasisWorking)"
    }
      + fittedBerths.map {
        "\($0.id):\($0.cabinID):\($0.ordinal):\($0.mode.rawValue):\($0.privateCabin):\($0.use):\($0.lifeSupportWorking):\($0.humanoidCompatible)"
      }
  }
}

/// Current cabin records are exact shapes; hidden native metadata is not ignored.
func validateCabinRecordKeys(_ decoder: any Decoder, _ expected: Set<String>) throws {
  let fields = try decoder.container(keyedBy: CabinRecordKey.self)
  guard Set(fields.allKeys.map(\.stringValue)) == expected else { throw SaveError.invalidCommander }
}
private struct CabinRecordKey: CodingKey {
  let stringValue: String
  var intValue: Int? { nil }
  init?(stringValue: String) { self.stringValue = stringValue }
  init?(intValue: Int) { return nil }
}
