import Foundation
import Testing

@testable import EliteCore

private func savedSolarMission() throws -> Game {
  let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("docs/mission-packs/scripted-courier")
  let pack = try ScriptPackLibrary.read(folder)
  var game = Game(executive: false)
  game.screen = .status
  game.scriptPacks = [pack]
  _ = try game.acceptScriptMission(pack)
  game.launch()
  game.bodies = []
  game.celestials = [
    .init(kind: .sun, position: .init(200, 100, 2500), radius: 1000),
    .init(kind: .planet, position: .init(5000, -2000, 10000), radius: 1500),
  ]
  try game.commander.grantEquipment(
    "Fuel Scoops", at: .utility(.fuelScoops), provenance: .grant("solar save fixture"))
  game.commander.fuel = 10
  game.speed = 8
  game.time = 19
  game.cabinTemperature = 0.12
  game.solarFuelRemainder = 0.37
  game.solarScoopState = .collecting
  return game
}
private func solarSaveFolder() throws -> URL {
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
    "solar-save-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  return folder
}
@Test func scriptSaveResumesActualSolarSceneHeatAndFractionalFuelIdentically() async throws {
  let runtime = GameRuntime(game: try savedSolarMission())
  for _ in 0..<15 { _ = await runtime.advance(delta: 0.05) }
  let before = await runtime.snapshot()
  let directory = try solarSaveFolder()
  defer { try? FileManager.default.removeItem(at: directory) }
  let url = directory.appendingPathComponent("commander.json")
  try await runtime.save(to: url)
  let loaded = GameRuntime()
  try await loaded.load(from: url)
  let restored = await loaded.snapshot()
  #expect(
    restored.celestials == before.celestials
      && restored.solarFuelRemainder == before.solarFuelRemainder)
  #expect(
    restored.cabinTemperature == before.cabinTemperature
      && restored.solarScoopState == before.solarScoopState)
  for _ in 0..<30 {
    let continuous = await runtime.advance(delta: 0.05)
    let resumed = await loaded.advance(delta: 0.05)
    #expect(continuous.commander.fuel == resumed.commander.fuel)
    #expect(continuous.celestials == resumed.celestials)
    #expect(abs(continuous.cabinTemperature - resumed.cabinTemperature) < 1e-12)
    #expect(abs(continuous.solarFuelRemainder - resumed.solarFuelRemainder) < 1e-12)
  }
}
@Test func scriptedStartupTitlePreservesPhysicalTimeAndSolarStateUntilContinue() async throws {
  let game = try savedSolarMission()
  let runtime = GameRuntime(game: game)
  let directory = try solarSaveFolder()
  defer { try? FileManager.default.removeItem(at: directory) }
  let url = directory.appendingPathComponent("commander.json")
  try await runtime.save(to: url)
  let loaded = GameRuntime()
  try await loaded.restoreStartup(from: url)
  var restored = await loaded.snapshot()
  #expect(restored.screen == .title && restored.time == 0)
  for _ in 0..<10 { restored = await loaded.advance(delta: 0.1) }
  #expect(restored.celestials == game.celestials && restored.commander.fuel == game.commander.fuel)
  #expect(
    restored.cabinTemperature == game.cabinTemperature
      && restored.solarFuelRemainder == game.solarFuelRemainder)
  try await loaded.save(to: url)
  let savedDuringTitle = GameRuntime()
  try await savedDuringTitle.load(from: url)
  #expect(await savedDuringTitle.snapshot().time == game.time)
  await loaded.key("return")
  restored = await loaded.snapshot()
  #expect(restored.screen == .status && restored.time == game.time)
}
@Test func solarSaveStatesRoundTripAndOldFormatDoesNotRegenerateCelestials() throws {
  var game = try savedSolarMission()
  for state in [SolarScoopState.inactive, .noScoops, .turnTowardSun, .collecting, .tankFull] {
    game.solarScoopState = state
    let data = try JSONEncoder().encode(game.scriptSimulationSave)
    let saved = try JSONDecoder().decode(ScriptSimulationSave.self, from: data)
    var restored = Game(executive: false)
    restored.restoreScriptSimulation(saved)
    #expect(restored.celestials == game.celestials && restored.solarScoopState == state)
  }
  var json = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(game.scriptSimulationSave))
      as? [String: Any])
  json.removeValue(forKey: "solar")
  let legacy = try JSONDecoder().decode(
    ScriptSimulationSave.self, from: JSONSerialization.data(withJSONObject: json))
  #expect(legacy.valid && legacy.solar == nil)
  game.restoreScriptSimulation(legacy)
  #expect(
    game.celestials.isEmpty && game.solarFuelRemainder == 0 && game.solarScoopState == .inactive)
  #expect(!ScriptCelestialSave(kind: "moon", position: .init(0, 0, 1), radius: 1).valid)
  #expect(!ScriptCelestialSave(kind: "sun", position: .init(0, 0, 1), radius: 0).valid)
  game.solarFuelRemainder = 2
  #expect(!game.scriptSimulationSave.valid)
}
