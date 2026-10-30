import Foundation
import Testing

@testable import L337Core

struct CR05ECMElapsedTimeTests {
  @Test func oneClockExpiresAtMatchedPhysicalTimeAndEmitsOutcomeOnce() {
    for step in [1.0 / 60, 1.0 / 30, 0.1] {
      var control = ECMControl()
      control.activate(destroyed: 2)
      let activation = control.activation
      var elapsed = 0.0
      while elapsed + step < ECMControl.fieldDuration - 1e-10 {
        control.advance(delta: step)
        elapsed += step
        #expect(control.fieldActive && control.ownFieldActive)
        #expect(control.activation == activation)
      }
      control.advance(delta: ECMControl.fieldDuration - elapsed)
      #expect(!control.fieldActive && !control.ownFieldActive && control.legacyFrames == 0)
      control.advance(delta: 10)
      let events = control.events.map(\.announcement)
      #expect(events.filter { $0 == .ecmActivated }.count == 1)
      #expect(events.filter { $0 == .missilesDestroyed(2) }.count == 1)
    }
  }

  @Test func externalAndLegacyFieldsShareClockWithoutClaimingPlayerDestruction() {
    var control = ECMControl()
    control.setLegacyFrames(32)
    #expect(control.legacyFrames == 32 && control.fieldActive && !control.ownFieldActive)
    control.recordDestruction()
    control.advance(delta: ECMControl.fieldDuration)
    #expect(control.events.isEmpty && !control.fieldActive)
    control.activate(destroyed: 1)
    control.setLegacyFrames(32)
    #expect(control.ownFieldActive && control.activation == 1)
    control.advance(delta: ECMControl.fieldDuration)
    #expect(control.events.map(\.announcement) == [.ecmActivated, .missilesDestroyed(1)])
    control.activateExternalField()
    #expect(control.fieldActive && !control.ownFieldActive)
    control.advance(delta: ECMControl.fieldDuration)
    #expect(control.events.count == 2)
    control.setLegacyFrames(Int.max)
    #expect(control.legacyFrames == Int.max)
    control.setLegacyFrames(0)
    #expect(!control.fieldActive)
  }

  @Test func malformedDeltasLeaveClockActivationAndEventsUnchanged() {
    for delta in [Double.nan, .infinity, -.infinity, -1, 0] {
      var control = ECMControl()
      control.activate(destroyed: 1)
      let duration = control.remainingDuration
      let events = control.events
      control.advance(delta: delta)
      #expect(control.remainingDuration == duration && control.events == events)
      #expect(control.activation == 1 && control.ownFieldActive)
    }
  }

  @Test func actualMilitaryRetaliationFiresOnceAcrossPhysicalTickPartitions() {
    for step in [1.0 / 60, 1.0 / 30, 0.1] {
      var game = Game(executive: false)
      game.commander.installTargetingComputer(.military)
      game.launch()
      game.speed = 0
      game.celestials = []
      #expect(game.commander.equipmentInventory != nil && game.commander.targetingTier == .military)
      game.commander.equipment.insert("E.C.M. System")
      var source = SpaceBody(id: 1, hull: .constrictor, position: .init(20, 0, 1400))
      source.ecmEnabled = false
      var missile = SpaceBody(id: 100, hull: .missile, position: .init(0, 0, 1000))
      missile.enemyMissile = true
      missile.missileSourceID = 1
      game.bodies = [source, missile]
      game.ecm()
      let activation = game.activeECMActivation
      #expect(activation != nil && game.ecmFrames == 32)
      var elapsed = 0.0
      while elapsed < 2 - 1e-10 {
        game.tick(delta: step)
        elapsed += step
        if game.ecmControl.fieldActive { #expect(game.activeECMActivation == activation) }
      }
      #expect(game.ecmFrames == 0 && !game.ecmControl.ownFieldActive)
      #expect(game.commander.missiles == 2)
      let events = game.ecmControl.events.map(\.announcement)
      #expect(events.filter { $0 == .missilesDestroyed(1) }.count == 1)
      #expect(
        events.filter {
          if case .missileLaunched = $0 { return true }
          return false
        }.count == 1)
      for _ in 0..<20 { game.tick(delta: step) }
      #expect(game.commander.missiles == 2)
    }
  }
}
