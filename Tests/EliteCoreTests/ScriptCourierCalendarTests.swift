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
