import Foundation
import Testing

@testable import EliteCore

@Test func courierMissionClockExcludesMenusWithoutChangingOldCalendar() async throws {
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  _ = try fixture.offer(&game)
  let runtime = GameRuntime(game: game)
  _ = await runtime.advance(delta: 0.1)
  let menu = await runtime.snapshot()
  #expect(menu.commander.scriptState.missionCalendar?.seconds == 0)
  #expect(menu.commander.scriptState.calendarSeconds == 0.1)
  await runtime.key("pause")
  _ = await runtime.advance(delta: 0.1)
  #expect(await runtime.snapshot().commander.scriptState.calendarSeconds == 0.1)
  #expect(await runtime.snapshot().commander.scriptState.missionCalendar?.seconds == 0)
}

@Test func courierInclusiveConfirmationAndStrictAfterExpiryAreDistinct() throws {
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  for late in [false, true] {
    var game = fixture.game()
    let id = try fixture.accept(&game)
    try fixture.travel(&game, id: id)
    let due = try #require(game.commander.scriptState.instances[id]?.contract?.deadline)
    game.commander.scriptState.calendarSeconds = due + (late ? 0.1 : 0)
    game.commander.scriptState.missionCalendar?.seconds = due + (late ? 0.1 : 0)
    if late {
      game.resolveCourierTerminals()
      #expect(game.commander.scriptState.instances[id]?.courier?.terminal?.cause == .expired)
      #expect(game.commander.scriptState.instances[id]?.contract?.settlementAmount == 0)
    } else {
      game.resolveCourierTerminals()
      #expect(game.commander.scriptState.instances[id]?.courier?.terminal == nil)
      try fixture.requestContact(&game, id: id)
      game.key("left")
      game.key("return")
      #expect(game.commander.scriptState.instances[id]?.outcome == .complete)
    }
    #expect(game.commander.valid)
  }
}

@Test(arguments: ["energy", "sun", "planet", "overheat"])
func courierEveryFatalRuntimePathReservesPendingLossUntilPublication(mode: String) async throws {
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let id = try fixture.accept(&game, variant: .package)
  game.launch()
  game.speed = 0
  game.bodies = []
  game.celestials = []
  switch mode {
  case "energy":
    game.energy = 0.01
    game.frontShield = 0
    game.bodies = [.init(id: 1, hull: .sidewinder, position: .init(0, 0, 100), hostile: true)]
  case "sun": game.celestials = [.init(kind: .sun, position: .init(0, 0, 900), radius: 1100)]
  case "planet": game.celestials = [.init(kind: .planet, position: .init(0, 0, 900), radius: 1100)]
  default:
    game.cabinTemperature = 0.99
    game.celestials = [.init(kind: .sun, position: .init(0, 0, 1500), radius: 1100)]
  }
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  let pointer = try Data(contentsOf: fixture.save)
  let backup = fixture.root.appendingPathComponent("fatal-backup")
  try FileManager.default.moveItem(at: fixture.save.appendingPathExtension("missions"), to: backup)
  try Data("blocked writer".utf8).write(to: fixture.save.appendingPathExtension("missions"))
  _ = await runtime.advance(delta: 0.1)
  let lost = await runtime.snapshot()
  #expect(lost.screen == .gameOver)
  #expect(lost.commander.scriptState.instances[id]?.courier?.pendingLoss != nil)
  #expect(lost.commander.scriptState.instances[id]?.courier?.terminal == nil)
  #expect(lost.commander.cargoTonnes == 1 && lost.commander.valid)
  #expect(
    lost.courierGallerySummary(lost.commander.scriptState.instances[id]).contains("Not deliverable")
  )
  #expect(try Data(contentsOf: fixture.save) == pointer)
  try FileManager.default.removeItem(at: fixture.save.appendingPathExtension("missions"))
  try FileManager.default.moveItem(at: backup, to: fixture.save.appendingPathExtension("missions"))
  _ = await runtime.advance(delta: 0.1)
  let settled = await runtime.snapshot()
  #expect(settled.screen == .gameOver && settled.commander.cargoTonnes == 0)
  #expect(settled.commander.scriptState.instances[id]?.courier?.terminal?.cause == .shipDestroyed)
  #expect(
    settled.commander.scriptState.instances[id]?.completionReceipt?.causeKind
      == "courier.terminated")
  #expect(settled.commander.valid)
  let receipt = settled.commander.scriptState.instances[id]?.completionReceipt
  _ = await runtime.advance(delta: 0.1)
  #expect(
    await runtime.snapshot().commander.scriptState.instances[id]?.completionReceipt == receipt)
}

@Test(arguments: [ScriptCourierVariant.data, .package])
func courierEscapeUsesActualNativeActionAndCommandPublicationRollsBackControls(
  variant: ScriptCourierVariant
) async throws {
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  let id = try fixture.accept(&game, variant: variant)
  game.commander.equipment.insert("Escape Pod")
  game.commander.synchronizeEquipmentInventory(force: true)
  game.launch()
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  var held = Controls()
  held.pitch = 0.5
  held.roll = -0.25
  await runtime.setControls(held)
  try await runtime.save(to: fixture.save)
  let before = await runtime.snapshot()
  let backup = fixture.root.appendingPathComponent("escape-backup")
  try FileManager.default.moveItem(at: fixture.save.appendingPathExtension("missions"), to: backup)
  try Data("blocked writer".utf8).write(to: fixture.save.appendingPathExtension("missions"))
  await runtime.key("escape-pod")
  let rejected = await runtime.snapshot()
  let controls = await runtime.courierControlsFixture()
  #expect(rejected.commander == before.commander && rejected.docked == before.docked)
  #expect(controls.pitch == held.pitch && controls.roll == held.roll)
  try FileManager.default.removeItem(at: fixture.save.appendingPathExtension("missions"))
  try FileManager.default.moveItem(at: backup, to: fixture.save.appendingPathExtension("missions"))
  await runtime.key("escape-pod")
  let escaped = await runtime.snapshot()
  #expect(escaped.docked && !escaped.commander.equipment.contains("Escape Pod"))
  if variant == .package {
    #expect(escaped.commander.scriptState.instances[id]?.courier?.terminal?.cause == .escapePod)
    #expect(escaped.commander.cargoTonnes == 0)
    #expect(escaped.commander.scriptState.instances[id]?.completionReceipt != nil)
  } else {
    #expect(escaped.commander.scriptState.instances[id]?.courier?.terminal == nil)
    #expect(escaped.commander.scriptState.instances[id]?.outcome == .active)
  }
  #expect(escaped.commander.valid)
}

struct CourierBoundaryCase: Sendable {
  let fixture: CourierNativeFixture
  let late: Bool
  let available: Bool
  static let cases: [Self] = [
    .init(fixture: .boundary48Below, late: false, available: true),
    .init(fixture: .boundary48Below, late: true, available: true),
    .init(fixture: .boundary72Below, late: false, available: true),
    .init(fixture: .boundary72Below, late: true, available: true),
    .init(fixture: .boundary48Above, late: false, available: false),
    .init(fixture: .boundary72Above, late: false, available: false),
  ]
}

@Test(arguments: CourierBoundaryCase.cases)
func courierPinnedMultihopDeadlinesUseActualRuntimeTravelAndFlight(boundary: CourierBoundaryCase)
  async throws
{
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  let pinned = boundary.fixture
  var game = fixture.game(system: pinned.origin)
  let (key, offer) = try fixture.offer(&game, row: pinned.row)
  try pinned.verify(try #require(game.commander.contracts.boards[key]), offer)
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
  #expect(quote.allowed == boundary.available && pinned.path.count >= 3)
  if !boundary.available {
    let before = await runtime.snapshot()
    await #expect(throws: MissionPackError.self) { try await runtime.confirmContract(quote) }
    #expect(await runtime.snapshot().commander == before.commander)
    try await fixture.travel(runtime, path: pinned.path)
    let travelled = await runtime.snapshot()
    #expect(travelled.commander.scriptState.clock(.missionCalendar) > pinned.lowerBound)
    #expect(travelled.commander.scriptState.clock(.missionCalendar) > offer.duration)
    #expect(travelled.commander.scriptState.instances.isEmpty)
    return
  }
  let id = try await runtime.confirmContract(quote)
  let job = try #require(await runtime.snapshot().commander.scriptState.instances[id]?.contract)
  try await fixture.travel(runtime, path: pinned.path, dockFinal: false)
  let arrived = await runtime.snapshot()
  #expect(!arrived.docked && arrived.commander.system == pinned.path.last)
  #expect(
    arrived.commander.scriptState.clock(.missionCalendar) > job.acceptedAt + pinned.lowerBound)
  let due = try #require(job.deadline)
  // Quiet controlled scenery keeps unrelated encounters from dominating this clock boundary fixture.
  // Every second still comes from real clamped Runtime.advance flight, never an edited mission clock.
  var steps = 0
  while steps < 20000 {
    let now = await runtime.snapshot().commander.scriptState.clock(.missionCalendar)
    if now >= due { break }
    if steps % 100 == 0 { await runtime.prepareCourierJumpFixture(destination: pinned.path.last!) }
    _ = await runtime.advance(delta: min(0.1, due - now))
    steps += 1
  }
  #expect(steps > 0 && steps < 20000)
  #expect(await runtime.snapshot().commander.scriptState.clock(.missionCalendar) == due)
  if boundary.late { _ = await runtime.advance(delta: 0.1) }
  await runtime.dockCourierFixture(refuel: false)
  if boundary.late {
    let expired = await runtime.snapshot()
    #expect(expired.commander.scriptState.instances[id]?.courier?.terminal?.cause == .expired)
    #expect(expired.commander.scriptState.instances[id]?.contract?.settlementAmount == 0)
  } else {
    await runtime.key("contacts-open")
    #expect(await runtime.snapshot().courierContactActionLabel == "Deliver")
    await runtime.key("left")
    await runtime.key("return")
    let delivered = await runtime.snapshot()
    #expect(delivered.commander.scriptState.instances[id]?.outcome == .complete)
    #expect(delivered.commander.scriptState.instances[id]?.courier?.terminal?.proof.clock == due)
    #expect(delivered.commander.valid)
  }
}
