import Foundation
import Testing

@testable import L337Core

@Test func heldBeamDischargesSoundOnConsecutivePositiveFlashSnapshots() async throws {
  var game = Game(executive: false)
  try game.commander.prepareEquipment()
  let pulse = try #require(game.commander.fittedEquipment(at: .laser(.front)))
  try game.commander.storeEquipment(
    pulse, expectedRevision: game.commander.equipmentInventory!.revision)
  try game.commander.grantEquipment(
    LaserKind.beam.equipmentName, at: .laser(.front), provenance: .grant("audio regression"))
  game.launch()
  game.speed = 0
  game.bodies = []
  game.celestials = []
  var feed = DischargeAudioFeed()
  #expect(feed.update(game.dischargeAudio).isEmpty)
  var controls = Controls()
  controls.fire = true
  var first: DischargeAudioState?
  for _ in 0..<3 {
    game.tick(delta: 0.1, controls: controls)
    #expect(game.laserFlash > 0)
    #expect(feed.update(game.dischargeAudio) == [.combatLaser])
    #expect(feed.update(game.dischargeAudio).isEmpty)
    if first == nil { first = game.dischargeAudio }
  }
  #expect(feed.update(try #require(first)).isEmpty)
  controls.fire = false
  game.tick(delta: 0.1, controls: controls)
  #expect(feed.update(game.dischargeAudio).isEmpty)
  let epoch = game.dischargeAudio.epoch
  let events = game.dischargeAudio.events
  var invalid = game.commander
  invalid.credits = -1
  let refused = game.load(invalid)
  #expect(!refused)
  #expect(game.dischargeAudio.epoch == epoch && game.dischargeAudio.events == events)
  #expect(feed.update(game.dischargeAudio).isEmpty)
  game = try await CurrentNativeSaveTestFixture.restore(game)
  #expect(game.dischargeAudio.epoch != epoch && game.dischargeAudio.events.isEmpty)
  #expect(feed.update(game.dischargeAudio).isEmpty)
}

@Test func dischargeAudioFeedBoundsPendingEventsAndResetsAcrossSessions() {
  var state = DischargeAudioState()
  for _ in 0..<40 { state.record(.combatLaser) }
  #expect(state.events.count == 32)
  var feed = DischargeAudioFeed()
  #expect(feed.update(state).count == 32)
  #expect(feed.update(state).isEmpty)
  state = DischargeAudioState()
  #expect(feed.update(state).isEmpty)
  state.record(.miningLaser)
  state.record(.salvageCutter)
  #expect(feed.update(state) == [.miningLaser, .salvageCutter])
  #expect(feed.update(state).isEmpty)
}
