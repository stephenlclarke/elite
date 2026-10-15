import Foundation
import Testing

@testable import EliteCore

private var passengerPackURL: URL {
  URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("docs/mission-packs/scripted-passengers")
}
private func passengerGame() throws -> (Game, ScriptPack) {
  let pack = try ScriptPackLibrary.read(passengerPackURL)
  var game = Game(executive: false)
  game.screen = .status
  game.scriptPacks = [pack]
  game.commander.credits = 100000
  try game.confirmPassengerBerth(game.passengerBerthQuote)
  return (game, pack)
}
@Test func cabinPurchaseQuoteIsStaleAfterFitCashLocationOrConfirmationChanges() throws {
  var game = Game(executive: false)
  game.screen = .equipment
  #expect(!game.passengerBerthQuote.allowed)
  game.commander.credits = 100000
  let quote = game.passengerBerthQuote
  #expect(quote.allowed)
  game.commander.cargo[0] = 1
  #expect(throws: MissionPackError.self) { try game.confirmPassengerBerth(quote) }
  game.commander.cargo[0] = 0
  game.docked = false
  #expect(throws: MissionPackError.self) { try game.confirmPassengerBerth(quote) }
  game.docked = true
  try game.confirmPassengerBerth(quote)
  #expect(game.commander.credits == 90000 && game.commander.cargoTonnes == 5)
  #expect(throws: MissionPackError.self) { try game.confirmPassengerBerth(quote) }
  #expect(game.commander.accommodation.ownedBerths.count == 1)
  let next = game.passengerBerthQuote
  game.commander.cargo[0] = 16
  #expect(throws: MissionPackError.self) { try game.confirmPassengerBerth(next) }
}
@Test func nativeCabinShopCountsBothEquipmentAndPhysicalCargoAndComparison() throws {
  var (game, _) = try passengerGame()
  game.selection = try #require(
    Equipment.all.firstIndex { $0.name == PassengerCabin.equipmentName })
  game.purchase()
  #expect(game.commander.accommodation.fitted.count == 2 && game.commander.cargoTonnes == 10)
  #expect(EquipmentGroups.itemIndices.contains(game.selection))
  let labels = Display.equipmentScreen(game, width: 1200, height: 900).labels.map(\.text).joined(
    separator: " ")
  #expect(labels.contains("Price: project estimate") && labels.contains("2 FIT"))
  let fields = game.commander.gameShipProfile.fields
  #expect(fields.first { $0.key == "fitted_passenger_berths" }?.number == 2)
  #expect(fields.first { $0.key == "required_crew_including_commander" }?.number == 1)
  game.commander.fuelStorageUnits = 4
  game.commander.equipment.formUnion([
    "Fuel Scoops", "E.C.M. System", "Extra Energy Unit", Equipment.navalEnergyUnit,
  ])
  let before = game.commander
  #expect(!game.passengerBerthQuote.allowed)
  game.purchase()
  #expect(game.commander == before)
}
@Test func actualPassengerBoardingDeliveryAndRewardRetainIdentityAndCare() throws {
  var (game, pack) = try passengerGame()
  let mission = try game.acceptScriptMission(pack)
  let person = try #require(game.commander.accommodation.people.values.first)
  let berth = try #require(game.commander.accommodation.fittedBerths.first)
  #expect(person.name == "Ari" && person.mission == mission && person.location == .cabin(berth.id))
  #expect(game.commander.passengerFit?.freeCompatiblePlaces == 0)
  #expect(throws: MissionPackError.self) {
    try game.setPassengerBerthFitted(berth.id, fitted: false)
  }
  var smaller = game.commander
  smaller.shipID = "SH033"
  #expect(!smaller.valid && smaller.accommodation.people == game.commander.accommodation.people)
  game.commander.system = 129
  game.emitScriptEvent("contact.requested")
  #expect({ game.showScriptDialogue() }())
  let before = game.commander
  game.closeBlackjackHandoff()
  #expect(game.commander == before)
  #expect({ game.showScriptDialogue() }())
  game.confirmScriptDialogue()
  #expect(game.commander.credits == before.credits + 1000)
  #expect(
    game.commander.accommodation.people[person.id]?.location == .delivered(galaxy: 0, system: 129))
  #expect(game.commander.accommodation.fittedBerths.first?.use == .empty)
  #expect(game.commander.scriptState.instances[mission]?.outcome == .complete)
  game.emitScriptEvent("contact.requested")
  #expect(game.commander.credits == before.credits + 1000)
  try game.setPassengerBerthFitted(berth.id, fitted: false)
  #expect(
    game.commander.cargoTonnes == 0
      && game.commander.accommodation.storedBerths.map(\.id) == [berth.id])
  try game.setPassengerBerthFitted(berth.id, fitted: true)
  #expect(game.commander.cargoTonnes == 5 && game.commander.accommodation.ownedBerths.count == 1)
}
@Test func missingCabinsWrongPickupAndInvalidLaterCommandRollbackPassengerBirth() throws {
  let pack = try ScriptPackLibrary.read(passengerPackURL)
  var empty = Game(executive: false)
  empty.scriptPacks = [pack]
  let before = empty.commander
  #expect(throws: MissionPackError.self) { try empty.acceptScriptMission(pack) }
  #expect(empty.commander == before && empty.commander.accommodation.people.isEmpty)
  var (game, _) = try passengerGame()
  game.commander.system = 129
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(pack) }
  #expect(game.commander.accommodation.people.isEmpty)
  game.commander.system = 7
  let original = game.commander
  var manifest = pack.manifestBytes
  manifest.append(Data("\n".utf8))
  let broken = ScriptPack(
    manifest: pack.manifest,
    source: Data(
      "return {accepted=function(e,w,d) return {data=d,commands={{op='passengers.board',id='board',party='charter'},{op='credits',id='bad',amount=-99999999}}} end}"
        .utf8),
    manifestBytes: manifest, digest: ScriptPackLibrary.hash(manifest))
  game.scriptPacks = [broken]
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(broken) }
  #expect(game.commander == original)
}
@Test func requiredPassengerReceiptCannotBeReplacedWithMilestonesOrForeignCustody() throws {
  var (game, pack) = try passengerGame()
  let mission = try game.acceptScriptMission(pack)
  let person = try #require(game.commander.accommodation.people.values.first)
  var state = try #require(game.commander.scriptState.instances[mission])
  state.milestones = [0, 1]
  var candidate = game.commander
  let event = ScriptEvent(sequence: 100, kind: "contact.requested", instance: mission, values: [:])
  #expect(throws: MissionPackError.self) {
    try game.applyScriptCommand(
      .object(["op": .string("mission.finish"), "outcome": .string("complete")]), event: event,
      pack: pack, state: &state, candidate: &candidate)
  }
  game.docked = false
  #expect(throws: MissionPackError.self) {
    try game.applyPassengerCommand(
      .object([
        "op": .string("passengers.deliver"), "id": .string("deliver"), "party": .string("charter"),
      ]), pack: pack, state: &state, candidate: &candidate)
  }
  #expect(candidate.accommodation.people[person.id]?.location == person.location)
}
@Test func savedPassengersAndStoredCabinsSurviveMissingPackWithoutReplay() async throws {
  var (game, pack) = try passengerGame()
  try game.confirmPassengerBerth(game.passengerBerthQuote)
  let empty = game.commander.accommodation.ownedBerths[1].id
  try game.setPassengerBerthFitted(empty, fitted: false)
  _ = try game.acceptScriptMission(pack)
  let runtime = GameRuntime(game: game)
  let commander = await runtime.snapshot().commander
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
    "passenger-save-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: folder) }
  let url = folder.appendingPathComponent("commander.json")
  try await runtime.save(to: url)
  let restored = GameRuntime(game: Game(executive: false))
  try await restored.load(from: url)
  let loaded = await restored.snapshot()
  var preserved = loaded.commander
  for (id, instance) in commander.scriptState.instances {
    #expect(loaded.commander.scriptState.instances[id]?.suspension != nil)
    preserved.scriptState.instances[id]?.suspension = instance.suspension
  }
  #expect(preserved == commander && loaded.commander.valid)
  #expect(loaded.commander.accommodation.people.count == 1)
  await restored.key("b")
  let suspended = await restored.snapshot()
  #expect(suspended.commander.accommodation == commander.accommodation)
}
@Test func duplicateCabinAndPersonLocationsAndBadDeclarationsAreRejected() throws {
  var (game, pack) = try passengerGame()
  _ = try game.acceptScriptMission(pack)
  let berth = try #require(game.commander.accommodation.ownedBerths.first)
  game.commander.accommodation.ownedBerths.append(berth)
  #expect(!game.commander.valid)
  game.commander.accommodation.ownedBerths.removeLast()
  game.commander.accommodation.people.removeAll()
  #expect(!game.commander.valid)
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
    "passenger-pack-" + UUID().uuidString)
  try FileManager.default.copyItem(at: passengerPackURL, to: folder)
  defer { try? FileManager.default.removeItem(at: folder) }
  let manifest = folder.appendingPathComponent("manifest.toml")
  let original = try String(contentsOf: manifest, encoding: .utf8)
  for (old, new) in [
    ("pickupGalaxy = 0", "pickupGalaxy = 8"), ("names = [\"Ari\"]", "names = []"),
    ("requiredPassengerParties = [\"charter\"]", "requiredPassengerParties = [\"unknown\"]"),
    (", \"charter-passengers-v2\"", ""),
  ] {
    try original.replacingOccurrences(of: old, with: new).write(
      to: manifest, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ScriptPackLibrary.read(folder) }
  }
}

@Test func emptyCabinStorageUsesNativeEquipmentKeysAndVersionedSaves() async throws {
  var (game, _) = try passengerGame()
  game.screen = .equipment
  game.selection = try #require(
    Equipment.all.firstIndex { $0.name == PassengerCabin.equipmentName })
  let id = try #require(game.commander.accommodation.ownedBerths.first?.id)
  let cash = game.commander.credits
  game.key("s")
  #expect(
    game.commander.accommodation.storedBerths.map(\.id) == [id] && game.commander.cargoTonnes == 0)
  game.key("r")
  #expect(
    game.commander.accommodation.fittedBerths.map(\.id) == [id] && game.commander.credits == cash)
  game.key("r")
  #expect(game.commander.accommodation.ownedBerths.count == 1)
  let runtime = GameRuntime(game: game)
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
    "cabin-save-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: folder) }
  let url = folder.appendingPathComponent("save.json")
  try await runtime.save(to: url)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: url))
  #expect(pointer.schemaVersion == 19)
  let restored = GameRuntime()
  try await restored.load(from: url)
  #expect(await restored.snapshot().commander.accommodation == game.commander.accommodation)
}
@Test func nativeEquipmentPurchaseCannotOverspendCabinEquipmentCapacity() throws {
  var (game, _) = try passengerGame()
  game.commander.fuelStorageUnits = 4
  game.commander.equipment.formUnion([
    "Fuel Scoops", "E.C.M. System", Equipment.navalEnergyUnit, "Energy Bomb",
  ])
  #expect(game.commander.commonEquipmentUnits == 10 && game.commander.valid)
  game.selection = try #require(Equipment.all.firstIndex { $0.name == "Galactic Hyperdrive" })
  game.purchase()
  #expect(game.commander.commonEquipmentUnits == 10)
  // Lave's low technology denies this item. Fit the last unit through a native fuel-storage purchase instead.
  game.commander.fuelStorageUnits = 3
  game.commander.equipment.insert("Galactic Hyperdrive")
  game.selection = try #require(Equipment.all.firstIndex { $0.name == FuelStorage.equipmentName })
  game.purchase()
  #expect(game.commander.commonEquipmentUnits == 11 && game.commander.valid)
  game.commander.equipment.insert("Escape Pod")
  game.commander.fuelStorageUnits = 3
  let original = game.commander
  game.purchase()
  #expect(game.commander == original && game.message.contains("CANNOT FIT"))
}

@Test func wrongStationRepeatedBoardingAndEscapePodCannotManufacturePassengerTravel() throws {
  var (game, pack) = try passengerGame()
  let mission = try game.acceptScriptMission(pack)
  var state = try #require(game.commander.scriptState.instances[mission])
  var candidate = game.commander
  #expect(throws: MissionPackError.self) {
    try game.applyPassengerCommand(
      .object([
        "op": .string("passengers.board"), "id": .string("second-board"),
        "party": .string("charter"),
      ]), pack: pack, state: &state, candidate: &candidate)
  }
  #expect(throws: MissionPackError.self) {
    try game.applyPassengerCommand(
      .object([
        "op": .string("passengers.deliver"), "id": .string("wrong-port"),
        "party": .string("charter"),
      ]), pack: pack, state: &state, candidate: &candidate)
  }
  #expect(candidate == game.commander)
  game.commander.equipment.insert("Escape Pod")
  game.docked = false
  let original = game.commander
  game.escapePod()
  #expect(!game.docked && game.commander == original && game.message.contains("CANNOT FIT"))
}

@Test func publicActorCabinTransactionsPreserveUniqueOwnershipAndRejectStaleQuotes() async throws {
  var game = Game(executive: false)
  game.screen = .equipment
  game.commander.credits = 100000
  let runtime = GameRuntime(game: game)
  let quote = await runtime.passengerBerthQuote()
  try await runtime.confirmPassengerBerth(quote)
  await #expect(throws: MissionPackError.self) { try await runtime.confirmPassengerBerth(quote) }
  var current = await runtime.snapshot()
  let id = try #require(current.commander.accommodation.ownedBerths.first?.id)
  try await runtime.setPassengerBerthFitted(id, fitted: false)
  try await runtime.setPassengerBerthFitted(id, fitted: true)
  current = await runtime.snapshot()
  #expect(
    current.commander.accommodation.fitted == [id]
      && current.commander.accommodation.ownedBerths.count == 1)
  #expect(!Equipment.maximumHardware.contains(PassengerCabin.equipmentName))
}
@Test func anotherMissionCannotSupplyTheRequiredPassengerDeliveryReceipt() throws {
  var (game, pack) = try passengerGame()
  let mission = try game.acceptScriptMission(pack)
  let state = try #require(game.commander.scriptState.instances[mission])
  let person = try #require(game.commander.accommodation.people.values.first)
  game.commander.accommodation.people[person.id] = ScriptPassenger(
    id: person.id, mission: UUID(), party: person.party, name: person.name,
    location: .delivered(galaxy: 0, system: 129))
  #expect(
    !game.passengersDelivered("charter", pack: pack, instance: state, commander: game.commander))
}

@Test func manualAndAutomaticTradingRespectActualCabinHoldEvenWithUnlimitedCargo() throws {
  var (game, _) = try passengerGame()
  game.commander.unlimitedCargo = true
  game.commander.autoTrade = true
  game.commander.credits = 1_000_000
  game.autoTrade()
  #expect(
    game.commander.cargoTonnes <= game.commander.standardCargoCapacity && game.commander.valid)
  game.selection = 0
  for _ in 0..<64 { game.trade(buy: true) }
  #expect(
    game.commander.cargoTonnes <= game.commander.standardCargoCapacity && game.commander.valid)
  game.launch()
  game.dock()
  #expect(
    game.commander.cargoTonnes <= game.commander.standardCargoCapacity && game.commander.valid)
  #expect(game.commander.accommodation.ownedBerths.count == 1)
}
