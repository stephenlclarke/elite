import Foundation
import Testing

@testable import EliteCore

private struct CommanderQueryFixture {
  let root: URL
  let pack: ScriptPack
  init() throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "commander-query-" + UUID().uuidString)
    let original = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("docs/mission-packs/scripted-courier")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let directory = root.appendingPathComponent("pack")
    try FileManager.default.copyItem(at: original, to: directory)
    let manifest = directory.appendingPathComponent("manifest.toml")
    var text = try String(contentsOf: manifest, encoding: .utf8)
    text = text.replacingOccurrences(
      of: "capabilities = [", with: "capabilities = [\"commander-queries-v2\", ")
    try text.write(to: manifest, atomically: true, encoding: .utf8)
    try """
    return {
      accepted=function(e,w,d)
        assert(w.commander.kills>=256,'Earn the native score before accepting.')
        local observed={kills=w.commander.kills,rank=w.commander.rank,ship=w.commander.ship_id,
          missiles=w.commander.missiles,crew_status=w.commander.accommodation.crew_status}
        w.commander.kills=999;w.commander.fuel_units=999;w.commander.credits_decicredits=999999
        return {data=observed,commands={}}
      end,
      contact=function(e,w,d) return {data=d,commands={}} end,
      confirm=function(e,w,d) return {data=d,commands={}} end
    }
    """.write(
      to: directory.appendingPathComponent("scripts/main.lua"), atomically: true, encoding: .utf8)
    pack = try ScriptPackLibrary.read(directory)
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
}

@Test func authoredNativeRankEligibilityTracksAnActualLaserKillAndCannotEditTheRealCommander()
  throws
{
  let fixture = try CommanderQueryFixture()
  defer { fixture.clean() }
  var game = Game(executive: false)
  game.screen = .status
  game.scriptPacks = [fixture.pack]
  game.commander.kills = 255
  let before = game.commander
  #expect(throws: MissionPackError.self) { try game.acceptScriptMission(fixture.pack) }
  #expect(game.commander == before)
  game.launch()
  game.celestials = []
  var victim = SpaceBody(id: 3, hull: .sidewinder, position: .init(0, 0, 400), hostile: true)
  victim.energy = 1
  game.bodies = [victim]
  game.nextBodyID = 4
  var controls = Controls()
  controls.fire = true
  game.tick(delta: 0.1, controls: controls)
  #expect(game.commander.kills == 256 && !game.bodies.contains { $0.id == 3 })
  let resources = game.commander
  let id = try game.acceptScriptMission(fixture.pack)
  #expect(game.commander.scriptState.instances[id]?.data["kills"] == .integer(256))
  #expect(game.commander.scriptState.instances[id]?.data["rank"] == .string(resources.rank))
  #expect(game.commander.kills == resources.kills && game.commander.fuel == resources.fuel)
  #expect(game.commander.credits == resources.credits)
  #expect(game.commander.valid)
}

@Test func nativeStockAndMountedWeaponsQueriesFollowRealConsumptionWithoutMutatingInventory()
  throws
{
  var game = Game(executive: false)
  game.screen = .status
  game.commander.installLaser(.military, on: .front)
  game.launch()
  game.celestials = []
  let before = game.commander.missiles
  game.missileArmed = true
  let fired = game.fireMissile()
  #expect(fired)
  game.resolveDestroyed()
  let resources = game.commander
  let bodies = game.bodies
  let query = game.scriptCommanderQuery
  #expect(query["missiles"] == .integer(Int64(before - 1)))
  #expect(query["lasers"]?["front"]?["kind"] == .string("military"))
  #expect(query["fuel_units"] == .integer(Int64(resources.fuel)))
  #expect(game.commander == resources && game.bodies == bodies)
}

@Test func nativeCommanderQueriesDescribeActualCharterOccupancyAndLabelCrewEstimates() async throws
{
  let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("docs/mission-packs/scripted-passengers")
  let pack = try ScriptPackLibrary.read(example)
  var game = Game(executive: false)
  game.scriptPacks = [pack]
  let runtime = try await GameRuntime(game: game).scriptGalleryTrial(packDigest: pack.digest)
  let directory = try #require(await runtime.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: directory) }
  let actual = await runtime.snapshot()
  let before = actual.commander
  let query = actual.scriptCommanderQuery
  #expect(query["accommodation"]?["occupied_berths"] == .integer(1))
  try #require(before.accommodation.fittedCabins.count == 1)
  try #require(before.accommodation.fittedCabins[0].grade == .economy)
  #expect(
    query["accommodation"]?["free_compatible_places"]
      == .integer(Int64(PassengerCabinGrade.economy.places - 1)))
  let profile = try ShipAccommodationProfile(ship: actual.commander.ship)
  #expect(
    query["accommodation"]?["required_operating_crew"] == .integer(Int64(profile.operatingCrew)))
  #expect(query["accommodation"]?["crew_status"] == .string(profile.crewStatus))
  #expect(query["accommodation"]?["crew_basis"] == .string(profile.crewBasis))
  #expect(actual.commander == before)
}

@Test func nativeCommanderQueriesFollowAnActualHullExchangeAndPreserveCommodityUnits() throws {
  var game = Game(executive: false)
  game.screen = .status
  game.commander.credits = 10_000_000
  game.commander.fuel = try #require(ShipCatalogue.ship("SH013")?.game?.fuel)
  game.commander.cargo[0] = 2
  game.commander.cargo[10] = 1
  game.commander.installLaser(.beam, on: .rear)
  game.key("6")
  game.showroom.selection = "SH013"
  let quote = try #require(game.shipTradeQuote)
  #expect(quote.allowed)
  game.key("showroom-trade")
  game.key("right")
  game.key("return")
  let query = game.scriptCommanderQuery
  #expect(query["ship_id"] == .string("SH013"))
  #expect(query["credits_decicredits"] == .integer(Int64(quote.balance)))
  #expect(query["lasers"]?["rear"]?["kind"] == .string("beam"))
  let commodities = try #require(query["hold"]?["commodities"]?.array)
  #expect(commodities[0]["quantity"] == .integer(2))
  #expect(commodities[10]["quantity"] == .integer(1))
  #expect(commodities.map { $0["unit"] } == Commodity.all.map { .string($0.unit) })
  #expect(game.commander.valid)
}

@Test func baseScriptSnapshotRetainsAllReadSectionsAndIndependentNativeValues() throws {
  var game = try missionGearGame()
  game.commander.credits = 123456
  game.commander.cargo[0] = 5
  game.commander.scriptState.flightSeconds = 12
  game.commander.scriptState.localSeconds = 34
  game.commander.scriptState.transitSeconds = 78
  let before = game.commander
  let snapshot = game.scriptSnapshot
  let fields = try #require(snapshot.object)
  #expect(
    Set(fields.keys) == [
      "galaxy", "system", "docked", "main_station", "station_id", "durable_commands",
      "jump_range_ly", "fitted_equipment", "stored_equipment", "free_equipment_units",
      "credits", "commander", "library", "free_tonnes", "flight_seconds", "local_seconds",
      "calendar_seconds", "calendar_day", "calendar_profile", "transit_seconds",
    ])
  #expect(fields["galaxy"] == .integer(0) && fields["system"] == .integer(7))
  #expect(fields["docked"] == .bool(true) && fields["main_station"] == .bool(true))
  #expect(fields["station_id"] == .string(game.contractStation.key))
  #expect(fields["durable_commands"] == .bool(false))
  #expect(fields["jump_range_ly"] == .number(7))
  #expect(fields["credits"] == .integer(123456) && fields["free_tonnes"] == .integer(25))
  #expect(fields["flight_seconds"] == .number(12) && fields["local_seconds"] == .number(34))
  #expect(fields["calendar_seconds"] == .number(0) && fields["transit_seconds"] == .number(78))
  #expect(fields["calendar_profile"] == .null && fields["calendar_day"] == .integer(0))
  #expect(fields["fitted_equipment"] == before.ownedGearCounts(fitted: true))
  #expect(fields["stored_equipment"] == before.ownedGearCounts(fitted: false))
  #expect(
    fields["free_equipment_units"] == .integer(Int64(before.passengerFit?.freeEquipmentUnits ?? 0)))
  #expect(fields["commander"] == game.scriptCommanderQuery)
  #expect(fields["library"] == .array(game.referenceBooks.map(\.header)))
  #expect(game.commander == before)
}
