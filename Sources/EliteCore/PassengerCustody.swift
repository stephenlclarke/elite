import CryptoKit
import Foundation

/// Deliberately limited to common-project humanoid charter cabins. Native pods and
/// edition-specific environmental adapters need their own verified physical rules.
public struct ScriptPassengerParty: Codable, Sendable {
  public let id: String
  public let names: [String]
  public let pickupGalaxy: Int
  public let pickupSystem: Int
  public let destinationGalaxy: Int
  public let destinationSystem: Int
  /// An explicit declaration is required before this party may be frozen for transport.
  public let transportMode: PassengerTransportMode?
  var valid: Bool {
    PackValidation.localID(id) && (1...32).contains(names.count)
      && names.allSatisfy { (1...80).contains($0.count) }
      && [pickupGalaxy, destinationGalaxy].allSatisfy { (0..<8).contains($0) }
      && [pickupSystem, destinationSystem].allSatisfy { (0...255).contains($0) }
  }
}
public enum PassengerLocation: Codable, Sendable, Equatable {
  case cabin(UUID)
  case delivered(galaxy: Int, system: Int)
}
public struct ScriptPassenger: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let mission: UUID
  public let party: String
  public let name: String
  public let transportMode: PassengerTransportMode
  public var location: PassengerLocation
}
public struct ShipAccommodation: Codable, Sendable, Equatable {
  public var ownedCabins: [OwnedPassengerCabin] = []
  public var ownedBerths: [PassengerBerth] = []
  public var fitted: Set<UUID> = []
  public var people: [UUID: ScriptPassenger] = [:]
  public init() {}
  private enum CodingKeys: String, CodingKey { case ownedCabins, ownedBerths, fitted, people }
  public init(from decoder: any Decoder) throws {
    try validateCabinRecordKeys(decoder, ["ownedCabins", "ownedBerths", "fitted", "people"])
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    func records<T: Decodable>(_ type: T.Type, key: CodingKeys, limit: Int) throws -> [T] {
      var input = try fields.nestedUnkeyedContainer(forKey: key)
      if let count = input.count, count > limit { throw SaveError.invalidCommander }
      var result: [T] = []
      while !input.isAtEnd {
        guard result.count < limit else { throw SaveError.invalidCommander }
        result.append(try input.decode(T.self))
      }
      return result
    }
    ownedCabins = try records(OwnedPassengerCabin.self, key: .ownedCabins, limit: 10000)
    ownedBerths = try records(PassengerBerth.self, key: .ownedBerths, limit: 10000)
    let fittedIDs = try records(UUID.self, key: .fitted, limit: 10000)
    fitted = Set(fittedIDs)
    guard fitted.count == fittedIDs.count else { throw SaveError.invalidCommander }
    // The current cabin format stores bounded alternating person-ID/person records.
    var input = try fields.nestedUnkeyedContainer(forKey: .people)
    if let count = input.count, count > 8192 { throw SaveError.invalidCommander }
    people = [:]
    while !input.isAtEnd {
      guard people.count < 4096 else { throw SaveError.invalidCommander }
      let id = try input.decode(UUID.self)
      guard people[id] == nil else { throw SaveError.invalidCommander }
      people[id] = try input.decode(ScriptPassenger.self)
    }
    guard valid else { throw SaveError.invalidCommander }
  }
  public func encode(to encoder: any Encoder) throws {
    var fields = encoder.container(keyedBy: CodingKeys.self)
    try fields.encode(ownedCabins, forKey: .ownedCabins)
    try fields.encode(ownedBerths, forKey: .ownedBerths)
    try fields.encode(fitted.sorted { $0.uuidString < $1.uuidString }, forKey: .fitted)
    var records = fields.nestedUnkeyedContainer(forKey: .people)
    for (id, person) in people.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
      try records.encode(id)
      try records.encode(person)
    }
  }
  public var fittedBerths: [PassengerBerth] { ownedBerths.filter { fitted.contains($0.cabinID) } }
  public var storedBerths: [PassengerBerth] { ownedBerths.filter { !fitted.contains($0.cabinID) } }
  var layoutValid: Bool {
    let cabinIDs = Set(ownedCabins.map(\.id))
    let placeIDs = Set(ownedBerths.map(\.id))
    guard ownedCabins.count <= 10000, ownedBerths.count <= 10000,
      cabinIDs.count == ownedCabins.count, placeIDs.count == ownedBerths.count,
      cabinIDs.isDisjoint(with: placeIDs), fitted.isSubset(of: cabinIDs),
      ownedBerths.allSatisfy({ cabinIDs.contains($0.cabinID) })
    else { return false }
    let places = Dictionary(grouping: ownedBerths, by: \.cabinID)
    for cabin in ownedCabins {
      let members = places[cabin.id] ?? []
      guard members.count == cabin.grade.places,
        members.allSatisfy({ $0.cabinGrade == cabin.grade }),
        Set(members.map(\.ordinal)) == Set(0..<cabin.grade.places),
        members.filter({ $0.use.used && $0.privateCabin }).isEmpty
          || members.filter({ $0.use.used }).count == 1
      else { return false }
    }
    return true
  }
  public var valid: Bool {
    guard layoutValid, people.count <= 4096, storedBerths.allSatisfy({ !$0.use.used })
    else { return false }
    let cabins = Dictionary(uniqueKeysWithValues: ownedCabins.map { ($0.id, $0) })
    for place in ownedBerths where place.use.used {
      guard let cabin = cabins[place.cabinID], fitted.contains(cabin.id), cabin.lifeSupportWorking,
        place.lifeSupportWorking, place.humanoidCompatible,
        place.mode == .stasis ? cabin.stasisWorking : cabin.grade.supportsAwake
      else { return false }
    }
    let placesByID = Dictionary(uniqueKeysWithValues: ownedBerths.map { ($0.id, $0) })
    let physicalIDs = Set(cabins.keys).union(placesByID.keys)
    var cabinPeople: Set<UUID> = []
    for berth in ownedBerths {
      if let person = berth.use.personID {
        guard !physicalIDs.contains(person), cabinPeople.insert(person).inserted else {
          return false
        }
      }
      if case .nativePerson(let person) = berth.use {
        guard let id = person.nativeID,
          person.station?.valid == true || person.rescue?.valid == true
            || person.evacuation?.valid == true,
          fitted.contains(berth.cabinID), berth.lifeSupportWorking,
          berth.humanoidCompatible, berth.privateCabin, berth.mode == .awake, people[id] == nil
        else { return false }
      }
      if case .extraCrew = berth.use, berth.mode != .awake { return false }
      if case .occupied(let person) = berth.use {
        guard fitted.contains(berth.cabinID), berth.lifeSupportWorking, berth.humanoidCompatible,
          people[person]?.location == .cabin(berth.id), people[person]?.transportMode == berth.mode
        else { return false }
      }
    }
    return people.allSatisfy { id, person in
      guard id == person.id, PackValidation.localID(person.party),
        (1...80).contains(person.name.count)
      else { return false }
      switch person.location {
      case .cabin(let berth):
        return placesByID[berth]?.use == .occupied(person: id)
      case .delivered(let galaxy, let system):
        return !cabinPeople.contains(id) && (0..<8).contains(galaxy) && (0...255).contains(system)
      }
    }
  }
  static func personID(mission: UUID, party: String, index: Int) -> UUID {
    let bytes = Array(SHA256.hash(data: Data("passenger:\(mission):\(party):\(index)".utf8)))
    return UUID(
      uuid: (
        bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
        bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
      ))
  }
}
extension Commander {
  /// An early prototype included this virtual hardware flag in maximum equipment.
  /// Actual cabin/person ownership is stored separately and must remain untouched.
  mutating func migrateLegacyPassengerMarker() { equipment.remove(PassengerCabin.equipmentName) }
  /// Charter fitting uses the real hold even when legacy unlimited-cargo policy is enabled.
  public var tradeCargoCapacity: Int {
    accommodation.fitted.isEmpty && !requiresContractFit && (nativePeople?.held.isEmpty ?? true)
      && (nativeUtility?.heldTonnes ?? 0) == 0
      && (scriptState.calendarLedger == nil || xyzzyActive)
      ? capacity : standardCargoCapacity
  }
  var requiresContractFit: Bool {
    for state in scriptState.instances.values {
      if state.contract != nil
        && (state.outcome == .active || state.payloads.values.contains { $0 > 0 })
      {
        if fieldReliefInstallationNeedsNoHold(state) { continue }
        return true
      }
    }
    return false
  }
  public var passengerFit: AccommodationFit? {
    guard let hull = ShipCatalogue.ship(shipID),
      let profile = try? ShipAccommodationProfile(ship: hull)
    else { return nil }
    return AccommodationFitting.evaluate(
      profile: profile, holdTonnes: standardCargoCapacity,
      freightTonnes: cargoTonnes - accommodation.fittedCabins.count
        * AccommodationFitting.tonnesPerCabin,
      otherFittedCargoTonnes: 0, otherFittedEquipmentUnits: commonEquipmentUnits,
      cabins: accommodation.fittedCabins, berths: accommodation.fittedBerths)
  }
  /// Explicit common-project costs; lasers/pylons and intrinsic docking are separate.
  /// Hardware without a more specific common adapter uses the documented one-unit estimate.
  public var commonEquipmentUnits: Int {
    if let inventory = equipmentInventory {
      return inventory.items.filter { $0.location != nil }.reduce(0) {
        $0 + Self.commonEquipmentUnitCost(for: $1)
      }
    }
    return equipment.reduce(fuelStorageUnits) { total, name in
      if LaserKind.from(name) != nil || name == Equipment.legacyDockingComputer { return total }
      switch name {
      case "Extra Energy Unit": return total + 2
      case Equipment.navalEnergyUnit: return total + 3
      case Equipment.eliteEnergyUnit: return total + 4
      default: return total + (ShieldBooster.from(name) == nil ? 1 : 2)
      }
    }
  }
  var accommodationValid: Bool {
    guard accommodation.valid, NativeStationPassengerJourney.berthsValid(self),
      accommodation.people.values.allSatisfy({ scriptState.instances[$0.mission] != nil })
    else { return false }
    // Legacy commanders without fitted cabins retain their established hardware behavior.
    let legacyOutfit =
      accommodation.fitted.isEmpty && !requiresContractFit && (nativePeople?.held.isEmpty ?? true)
      && (scriptState.calendarLedger == nil || xyzzyActive)
    return legacyOutfit || passengerFit?.allowed == true
  }
}
extension Game {
  func applyPassengerCommand(
    _ command: ScriptValue, pack: ScriptPack, state: inout ScriptInstance,
    candidate: inout Commander
  ) throws {
    guard let fields = command.object, Set(fields.keys) == ["op", "id", "party"],
      let op = fields["op"]?.string, let receipt = fields["id"]?.string,
      PackValidation.localID(receipt), let partyID = fields["party"]?.string,
      let party = pack.manifest.passengerParties?.first(where: { $0.id == partyID }),
      pack.manifest.capabilities.contains("charter-passengers-v2"), state.outcome == .active
    else { throw MissionPackError("Passenger transfer requires a declared party and capability.") }
    if state.receipts.contains(receipt) { return }
    guard docked, dockedAtMainStation else {
      throw MissionPackError("Passenger transfers require the actual main orbital station.")
    }
    var accommodation = candidate.accommodation
    let ids = party.names.indices.map {
      ShipAccommodation.personID(mission: state.id, party: partyID, index: $0)
    }
    if op == "passengers.board" {
      guard candidate.galaxy == party.pickupGalaxy, candidate.system == party.pickupSystem,
        ids.allSatisfy({ accommodation.people[$0] == nil })
      else {
        throw MissionPackError(
          "This party is not waiting at this station or is already in custody.")
      }
      let mode = party.transportMode ?? .awake
      let available = Set(accommodation.availablePlaces(mode: mode).map(\.id))
      let places = accommodation.ownedBerths.indices.filter {
        available.contains(accommodation.ownedBerths[$0].id)
      }.sorted {
        accommodation.ownedBerths[$0].id.uuidString < accommodation.ownedBerths[$1].id.uuidString
      }
      guard candidate.passengerFit?.allowed == true, places.count >= ids.count else {
        throw MissionPackError(
          "Fit enough empty compatible passenger berths before accepting this party.")
      }
      for (index, place) in zip(ids.indices, places) {
        let berth = accommodation.ownedBerths[place].id
        accommodation.ownedBerths[place].privateCabin = false
        accommodation.ownedBerths[place].mode = mode
        accommodation.ownedBerths[place].use = .occupied(person: ids[index])
        accommodation.people[ids[index]] = ScriptPassenger(
          id: ids[index], mission: state.id, party: partyID, name: party.names[index],
          transportMode: mode,
          location: .cabin(berth))
      }
    } else if op == "passengers.deliver" {
      guard candidate.galaxy == party.destinationGalaxy, candidate.system == party.destinationSystem
      else {
        throw MissionPackError("The party must reach its declared destination station.")
      }
      for id in ids {
        guard let person = accommodation.people[id], person.mission == state.id,
          person.party == partyID, case .cabin(let berth) = person.location,
          let index = accommodation.ownedBerths.firstIndex(where: { $0.id == berth }),
          accommodation.placeIsFitted(berth),
          accommodation.ownedBerths[index].use == .occupied(person: id)
        else { throw MissionPackError("Actual owned passengers aboard are required for delivery.") }
        accommodation.ownedBerths[index].use = .empty
        accommodation.people[id]?.location = .delivered(
          galaxy: candidate.galaxy, system: candidate.system)
      }
    } else {
      throw MissionPackError("Unsupported passenger transfer.")
    }
    candidate.accommodation = accommodation
    state.receipts.insert(receipt)
  }
  func passengersDelivered(
    _ partyID: String, pack: ScriptPack, instance: ScriptInstance, commander: Commander
  ) -> Bool {
    guard let party = pack.manifest.passengerParties?.first(where: { $0.id == partyID }) else {
      return false
    }
    return party.names.indices.allSatisfy { index in
      let id = ShipAccommodation.personID(mission: instance.id, party: partyID, index: index)
      guard let person = commander.accommodation.people[id], person.id == id,
        person.mission == instance.id, person.party == partyID
      else { return false }
      return person.location
        == .delivered(galaxy: party.destinationGalaxy, system: party.destinationSystem)
    }
  }
  func scriptPassengerSnapshot(_ instance: ScriptInstance) -> ScriptValue {
    .array(
      commander.accommodation.people.values.filter { $0.mission == instance.id }.sorted {
        $0.id.uuidString < $1.id.uuidString
      }.map { person in
        var fields: [String: ScriptValue] = [
          "id": .string(person.id.uuidString), "party": .string(person.party),
          "name": .string(person.name),
        ]
        switch person.location {
        case .cabin(let berth):
          fields["location"] = .string("aboard")
          fields["berth"] = .string(berth.uuidString)
        case .delivered(let galaxy, let system):
          fields["location"] = .string("delivered")
          fields["galaxy"] = .integer(Int64(galaxy))
          fields["system"] = .integer(Int64(system))
        }
        return .object(fields)
      })
  }
}
