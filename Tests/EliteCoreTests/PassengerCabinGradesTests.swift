import Foundation
import Testing

@testable import EliteCore

private struct CabinPartyFixture {
  let directory: URL
  let pack: ScriptPack
  init(people: Int, mode: String? = "stasis") throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "cabin-party-" + UUID().uuidString)
    let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("docs/mission-packs/scripted-passengers")
    try FileManager.default.copyItem(at: source, to: directory)
    do {
      let manifest = directory.appendingPathComponent("manifest.toml")
      var text = try String(contentsOf: manifest, encoding: .utf8)
      let names = (1...people).map { "\"Person \($0)\"" }.joined(separator: ", ")
      text = text.replacingOccurrences(of: "names = [\"Ari\"]", with: "names = [" + names + "]")
      if let mode {
        text = text.replacingOccurrences(
          of: "pickupGalaxy = 0", with: "transportMode = \"" + mode + "\"\npickupGalaxy = 0")
      }
      try text.write(to: manifest, atomically: true, encoding: .utf8)
      pack = try ScriptPackLibrary.read(directory)
    } catch {
      try? FileManager.default.removeItem(at: directory)
      throw error
    }
  }
  func clean() { try? FileManager.default.removeItem(at: directory) }
  func game() -> Game {
    var result = Game(executive: false)
    result.screen = .status
    result.commander.credits = 1_000_000
    result.scriptPacks = [pack]
    return result
  }
}

@Test func packedStasisCabinCarriesTwentyDistinctPeopleInOneFiveTonneModuleAndDeliversEach() throws
{
  let fixture = try CabinPartyFixture(people: 20)
  defer { fixture.clean() }
  var game = fixture.game()
  let quote = game.passengerCabinQuote(.cryogenic)
  let cabin = try game.confirmPassengerBerth(quote)
  let mission = try game.acceptScriptMission(fixture.pack)
  let accommodation = game.commander.accommodation
  #expect(accommodation.fitted == [cabin] && accommodation.ownedCabins.count == 1)
  #expect(accommodation.ownedBerths.count == 20 && accommodation.people.count == 20)
  #expect(Set(accommodation.ownedBerths.map(\.id)).count == 20)
  #expect(
    accommodation.ownedBerths.allSatisfy {
      $0.cabinID == cabin && $0.id != cabin && $0.mode == .stasis
    })
  #expect(accommodation.people.values.allSatisfy { $0.transportMode == .stasis })
  #expect(game.commander.cargoTonnes == 5 && game.commander.passengerFit?.cabinCargo == 5)
  #expect(game.commander.credits == 1_000_000 - quote.price && game.commander.valid)
  for place in accommodation.ownedBerths {
    guard case .occupied(let person) = place.use else {
      Issue.record("Missing actual occupant")
      continue
    }
    #expect(accommodation.people[person]?.location == .cabin(place.id))
  }
  let beforeStorage = game.commander
  #expect(throws: MissionPackError.self) { try game.setPassengerBerthFitted(cabin, fitted: false) }
  let commanderPreserved1 = game.commander == beforeStorage
  #expect(commanderPreserved1)
  game.commander.system = 129
  game.emitScriptEvent("contact.requested")
  let dialogueShown = game.showScriptDialogue()
  try #require(dialogueShown)
  game.confirmScriptDialogue()
  #expect(game.commander.scriptState.instances[mission]?.outcome == .complete)
  #expect(game.commander.accommodation.people.count == 20)
  #expect(
    game.commander.accommodation.people.values.allSatisfy {
      $0.location == .delivered(galaxy: 0, system: 129)
    })
  #expect(game.commander.accommodation.ownedBerths.allSatisfy { !$0.use.used })
  #expect(game.commander.cargoTonnes == 5 && game.commander.credits == beforeStorage.credits + 1000)
  try game.setPassengerBerthFitted(cabin, fitted: false)
  #expect(game.commander.cargoTonnes == 0 && game.commander.accommodation.storedCabins.count == 1)
}

@Test(arguments: [PassengerTransportMode.awake, .stasis])
func doubleStateroomBoardsTwoDistinctPeopleInTheirAgreedMode(mode: PassengerTransportMode) throws {
  let fixture = try CabinPartyFixture(people: 2, mode: mode.rawValue)
  defer { fixture.clean() }
  var game = fixture.game()
  let cabin = try game.confirmPassengerBerth(game.passengerCabinQuote(.stateroomDouble))
  _ = try game.acceptScriptMission(fixture.pack)
  let accommodation = game.commander.accommodation
  #expect(accommodation.people.count == 2 && accommodation.ownedBerths.count == 2)
  #expect(
    accommodation.ownedBerths.allSatisfy {
      $0.cabinID == cabin && $0.mode == mode && !$0.privateCabin && $0.use.used
    })
  #expect(Set(accommodation.ownedBerths.map(\.id)).count == 2)
  #expect(accommodation.ownedCabins[0].stasisWorking && game.commander.cargoTonnes == 5)
  #expect(game.commander.valid)
}

@Test func twentyFirstPersonAndAwakeOnlyConsentCannotEnterPackedStasisAndRollbackBirth() throws {
  for (count, mode) in [(21, Optional("stasis")), (1, nil)] {
    let fixture = try CabinPartyFixture(people: count, mode: mode)
    defer { fixture.clean() }
    var game = fixture.game()
    try game.confirmPassengerBerth(game.passengerCabinQuote(.cryogenic))
    let before = game.commander
    #expect(throws: MissionPackError.self) { try game.acceptScriptMission(fixture.pack) }
    let commanderPreserved2 =
      game.commander == before && game.commander.accommodation.people.isEmpty
    #expect(commanderPreserved2)
  }
  #expect(throws: (any Error).self) { _ = try CabinPartyFixture(people: 1, mode: "unconsented") }
}

@Test func everyCabinGradeChargesFiveTonnesAndOneUnitForItsCompleteFixedLayout() throws {
  let profile = try ShipAccommodationProfile(ship: #require(ShipCatalogue.ship("SH023")))
  for grade in PassengerCabinGrade.allCases {
    var accommodation = ShipAccommodation()
    accommodation.addCabin(grade)
    let empty = AccommodationFitting.evaluate(
      profile: profile, holdTonnes: 5, freightTonnes: 0, otherFittedCargoTonnes: 0,
      otherFittedEquipmentUnits: profile.equipmentUnits - 1,
      cabins: accommodation.fittedCabins, berths: accommodation.fittedBerths)
    #expect(empty.allowed && empty.cabinCargo == 5 && empty.freeEquipmentUnits == 0)
    #expect(accommodation.ownedBerths.count == grade.places && accommodation.valid)
    for index in accommodation.ownedBerths.indices {
      accommodation.ownedBerths[index].mode = .stasis
      accommodation.ownedBerths[index].use = .reserved(mission: UUID(), person: UUID())
    }
    let full = AccommodationFitting.evaluate(
      profile: profile, holdTonnes: 5, freightTonnes: 0, otherFittedCargoTonnes: 0,
      otherFittedEquipmentUnits: profile.equipmentUnits - 1,
      cabins: accommodation.fittedCabins, berths: accommodation.fittedBerths)
    #expect(full.allowed && full.cabinCargo == 5 && full.freeEquipmentUnits == 0)
    #expect(full.freeCompatiblePlaces == 0 && accommodation.valid)
    #expect(!Equipment.validNames.contains(grade.equipmentName))
    #expect(!Equipment.maximumHardware.contains(grade.equipmentName))
  }
}

@Test func privateCabinReservationExcludesOtherPlacesButDoubleStateroomCanShareWhenAgreed() throws {
  var accommodation = ShipAccommodation()
  let cabin = accommodation.addCabin(.stateroomDouble)
  #expect(accommodation.availablePlaces().count == 2)
  #expect(accommodation.availablePlaces(privateCabin: true).count == 1)
  accommodation.ownedBerths[0].use = .reserved(mission: UUID(), person: UUID())
  accommodation.ownedBerths[0].privateCabin = true
  #expect(accommodation.valid && accommodation.availablePlaces().isEmpty)
  accommodation.ownedBerths[1].use = .reserved(mission: UUID(), person: UUID())
  #expect(!accommodation.valid)
  accommodation.ownedBerths[0].privateCabin = false
  #expect(accommodation.valid && accommodation.fitted == [cabin])
  var game = Game(executive: false)
  game.commander.accommodation = accommodation
  let before = game.commander
  #expect(throws: MissionPackError.self) { try game.setPassengerBerthFitted(cabin, fitted: false) }
  let commanderPreserved3 = game.commander == before
  #expect(commanderPreserved3)
}

@Test func cryogenicHardwareAndSavedPassengerModeCannotBeBypassed() throws {
  let fixture = try CabinPartyFixture(people: 1)
  defer { fixture.clean() }
  var game = fixture.game()
  try game.confirmPassengerBerth(game.passengerCabinQuote(.cryogenic))
  game.commander.accommodation.ownedCabins[0].stasisWorking = false
  let before = game.commander
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(fixture.pack) }
  let commanderPreserved4 = game.commander == before
  #expect(commanderPreserved4)
  game.commander.accommodation.ownedCabins[0].stasisWorking = true
  _ = try game.acceptScriptMission(fixture.pack)
  let good = game.commander.accommodation
  #expect(
    try JSONDecoder().decode(ShipAccommodation.self, from: JSONEncoder().encode(good)) == good)
  for mutation in 0..<3 {
    var bad = good
    if mutation == 0 { bad.ownedCabins[0].stasisWorking = false }
    if mutation == 1 { bad.ownedCabins[0].lifeSupportWorking = false }
    if mutation == 2 {
      let index = try #require(bad.ownedBerths.firstIndex { $0.use.used })
      bad.ownedBerths[index].mode = .awake
    }
    #expect(!bad.valid)
    let data = try JSONEncoder().encode(bad)
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(ShipAccommodation.self, from: data)
    }
  }
}

@Test func currentCabinSaveRejectsDuplicateOrOrphanPlacesAndWrongLayoutsWithoutMigration() throws {
  var good = ShipAccommodation()
  good.addCabin(.cryogenic)
  let bytes = try JSONEncoder().encode(good)
  #expect(try JSONDecoder().decode(ShipAccommodation.self, from: bytes) == good)
  for mutation in 0..<8 {
    var bad = good
    switch mutation {
    case 0: bad.ownedBerths.append(bad.ownedBerths[0])
    case 1: bad.ownedBerths.removeLast()
    case 2: bad.ownedCabins.removeAll()
    case 3: bad.ownedCabins.append(bad.ownedCabins[0])
    case 4: bad.fitted.insert(UUID())
    case 5:
      bad.ownedBerths[0] = PassengerBerth(
        cabinID: bad.ownedCabins[0].id, cabinGrade: .cryogenic, ordinal: 20)
    case 6:
      bad.ownedBerths[0] = PassengerBerth(cabinID: bad.ownedCabins[0].id, cabinGrade: .economy)
    default:
      bad.ownedBerths[0] = PassengerBerth(
        id: bad.ownedCabins[0].id, cabinID: bad.ownedCabins[0].id, cabinGrade: .cryogenic)
    }
    let data = try JSONEncoder().encode(bad)
    #expect(!bad.valid)
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(ShipAccommodation.self, from: data)
    }
  }
  var hidden = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
  var hiddenCabins = try #require(hidden["ownedCabins"] as? [[String: Any]])
  hiddenCabins[0]["stationJourney"] = ["invented": true]
  hidden["ownedCabins"] = hiddenCabins
  let hiddenData = try JSONSerialization.data(withJSONObject: hidden)
  #expect(throws: (any Error).self) {
    try JSONDecoder().decode(ShipAccommodation.self, from: hiddenData)
  }
  var oversized = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
  let places = try #require(oversized["ownedBerths"] as? [[String: Any]])
  oversized["ownedBerths"] = Array(repeating: places[0], count: 10001)
  let oversizedData = try JSONSerialization.data(withJSONObject: oversized)
  #expect(throws: (any Error).self) {
    try JSONDecoder().decode(ShipAccommodation.self, from: oversizedData)
  }
  var object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
  var cabins = try #require(object["ownedCabins"] as? [[String: Any]])
  cabins[0]["grade"] = "unknown"
  object["ownedCabins"] = cabins
  let unknown = try JSONSerialization.data(withJSONObject: object)
  #expect(throws: (any Error).self) {
    try JSONDecoder().decode(ShipAccommodation.self, from: unknown)
  }
}

@Test func cabinActorPurchasePublishesTwentyPlacesOnceAndFailedWriterOrStaleGradeDebitsNothing()
  async throws
{
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "cabin-actor-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  let url = directory.appendingPathComponent("commander.json")
  var game = Game(executive: false)
  game.commander.credits = 1_000_000
  let runtime = GameRuntime(game: game, saveURL: url)
  try await runtime.save(to: url)
  let quote = await runtime.passengerCabinQuote(.cryogenic)
  let before = await runtime.snapshot().commander
  let backup = directory.appendingPathExtension("writer-backup")
  defer { try? FileManager.default.removeItem(at: backup) }
  try FileManager.default.moveItem(at: directory, to: backup)
  try Data().write(to: directory)
  await #expect(throws: (any Error).self) { try await runtime.confirmPassengerBerth(quote) }
  let commanderPreserved5 = await runtime.snapshot().commander == before
  #expect(commanderPreserved5)
  try FileManager.default.removeItem(at: directory)
  try FileManager.default.moveItem(at: backup, to: directory)
  try await runtime.confirmPassengerBerth(quote)
  let after = await runtime.snapshot().commander
  #expect(after.accommodation.ownedCabins.count == 1 && after.accommodation.ownedBerths.count == 20)
  #expect(after.credits == before.credits - quote.price && after.cargoTonnes == 5)
  await #expect(throws: MissionPackError.self) { try await runtime.confirmPassengerBerth(quote) }
  let commanderPreserved6 = await runtime.snapshot().commander == after
  #expect(commanderPreserved6)
  let (saved, _) = try ScriptSaveStore.read(Data(contentsOf: url), from: url)
  let commanderPreserved7 = saved == after
  #expect(commanderPreserved7)
}

@Test func hullTransferPreservesCabinPlaceAndPersonIDsOrRefusesWholeModuleAtomically() throws {
  let fixture = try CabinPartyFixture(people: 20)
  defer { fixture.clean() }
  var game = fixture.game()
  try game.confirmPassengerBerth(game.passengerCabinQuote(.cryogenic))
  _ = try game.acceptScriptMission(fixture.pack)
  let original = game.commander
  let projected = try original.projectedEquipmentTransfer(to: "SH171")
  #expect(projected.accommodation == original.accommodation && projected.cargoTonnes == 5)
  try game.commander.transferEquipment(to: "SH171", hullID: UUID())
  #expect(game.commander.accommodation == original.accommodation && game.commander.valid)
  let before = game.commander
  #expect(throws: (any Error).self) {
    try game.commander.transferEquipment(to: "SH033", hullID: UUID())
  }
  let commanderPreserved8 = game.commander == before
  #expect(commanderPreserved8)
}

@Test func cabinShopPinsTheSelectedGradeAndExplainsPackedTransportHardwareAndFootprint() throws {
  var game = Game(executive: false)
  game.screen = .equipment
  game.commander.credits = 1_000_000
  game.selection = try #require(
    Equipment.all.firstIndex { $0.name == PassengerCabinGrade.cryogenic.equipmentName })
  let context = try #require(game.equipmentPurchaseContext)
  let labels = Display.equipmentScreen(game, width: 1200, height: 900).labels.map(\.text).joined(
    separator: " ")
  #expect(labels.contains("20 packed stasis pods") && labels.contains("5t/1 unit"))
  game.selection = try #require(
    Equipment.all.firstIndex { $0.name == PassengerCabinGrade.stateroomDouble.equipmentName })
  let before = game.commander
  #expect(game.performEquipmentMutation(.purchase(context)) == .refused(.staleContext))
  let preserved = game.commander == before
  #expect(preserved)
}

@Test func historicalPrivateCabinOffersKeepTheirLayoutAfterRealPropertyIsLost() {
  var accommodation = ShipAccommodation()
  accommodation.addCabin(.stateroomDouble)
  accommodation.addCabin(.economy)
  let offer = accommodation.availablePlaces(privateCabin: true)
  #expect(offer.count == 2 && accommodation.validPrivateOffer(offer))
  let lost = ShipAccommodation()
  #expect(lost.validPrivateOffer(offer))
  let impossible = PassengerBerth(cabinID: UUID(), ordinal: 20, privateCabin: true)
  #expect(!lost.validPrivateOffer([impossible]))
}
