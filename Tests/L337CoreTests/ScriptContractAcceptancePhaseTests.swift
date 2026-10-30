import Foundation
import Testing

@testable import L337Core

@Test func rejectedDirectAcceptanceStillSettlesAnAlreadyExpiredCourierExactlyOnce() throws {
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  let pinned = CourierNativeFixture.rows[1]
  var game = try pinned.game(using: fixture)
  game.commander.cargo[0] = 3
  let (key, offer) = try fixture.usable(&game, row: pinned.row)
  try pinned.verify(try #require(game.commander.contracts.boards[key]), offer)
  let terms = try #require(offer.courier)
  try #require(terms.variant == .package && terms.calendarLowerBoundSeconds < terms.duration)
  let id = try game.confirmContract(game.contractAcceptanceQuote(board: key, offer: offer.id))
  let accepted = try #require(game.commander.scriptState.instances[id])
  let job = try #require(accepted.contract)
  let custody = try #require(accepted.courier)
  let deadline = try #require(job.deadline)
  let cash = game.commander.credits
  let equipment = game.commander.equipmentInventory
  let boards = game.commander.contracts.boards
  let sequence = game.commander.scriptState.nextEvent
  game.commander.scriptState.calendarSeconds = deadline + 0.1
  game.commander.scriptState.missionCalendar?.seconds = deadline + 0.1

  // Direct value acceptance resolves existing terminal work before a later offer error.
  #expect(throws: MissionPackError.self) {
    try game.acceptContract(board: "absent-board", offer: job.offer.id)
  }
  let expired = try #require(game.commander.scriptState.instances[id])
  let terminal = try #require(expired.courier?.terminal)
  #expect(terminal.cause == .expired && terminal.item == custody.item && terminal.amount == 0)
  #expect(terminal.proof.sequence == sequence + 1 && expired.revision == accepted.revision + 1)
  #expect(expired.hasAcknowledged(terminal.proof.sequence))
  #expect(expired.completionReceipt?.sequence == terminal.proof.sequence)
  #expect(expired.contract?.settlementAmount == 0)
  #expect(expired.payloads[ScriptCourierCustody.payloadKey] == nil)
  #expect(game.commander.cargoTonnes == 3 && game.commander.cargo[0] == 3)
  #expect(game.commander.credits == cash && game.commander.equipmentInventory == equipment)
  #expect(game.commander.contracts.boards == boards)
  #expect(game.commander.scriptState.instances.count == 1 && game.commander.valid)

  let settled = game.commander
  #expect(throws: MissionPackError.self) {
    try game.acceptContract(board: "absent-board", offer: job.offer.id)
  }
  #expect(game.commander == settled)
}
