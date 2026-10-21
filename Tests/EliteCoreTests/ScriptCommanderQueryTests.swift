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
  #expect(query["accommodation"]?["free_compatible_places"] == .integer(0))
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
