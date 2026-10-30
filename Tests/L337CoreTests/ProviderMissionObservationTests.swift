import Foundation
import Testing

@testable import L337Core

struct ProviderMissionObservationTests {
  private func interval(
    _ frame: UInt64, distance: Double = 30, contact: Bool = true,
    tracking: Bool = true, generation: UUID = ProviderContractFixture.scene
  ) -> ProviderMissionInterval {
    let state = ProviderContractFixture.state()
    return .init(
      provider: state.provider, subject: state.subject, sceneGeneration: generation,
      startFrame: frame, endFrame: frame + 1, startTime: Double(frame) / 10,
      endTime: Double(frame + 1) / 10, forwardMeters: distance, rangeMeters: 4000,
      relativeMetersPerSecond: 50, actualSensorContact: contact, communications: contact,
      unpausedFreeFlight: contact, trackingThroughout: tracking, continuous: true)
  }
  private func fold(
    _ progress: ProviderMissionProgress, _ interval: ProviderMissionInterval,
    epoch: UUID = ProviderContractFixture.epoch, manifest: Bool = true
  ) throws -> ProviderMissionObservation.Result {
    try ProviderMissionObservation.fold(
      progress, interval: interval, runtimeEpoch: epoch,
      terms: ProviderContractFixture.terms.observation, manifestReceived: manifest,
      calibrationOpen: true)
  }
  @Test func handshakeRequiresExplicitRequestAndFiveContinuousPhysicalSeconds() throws {
    var progress = ProviderMissionProgress()
    for frame in UInt64(1)...60 {
      progress = try fold(progress, interval(frame), manifest: false).progress
    }
    #expect(progress.handshakeSeconds == 0)
    progress.requested = true
    for frame in UInt64(61)...80 {
      progress = try fold(progress, interval(frame), manifest: false).progress
    }
    #expect(progress.handshakeSeconds > 1.9 && progress.handshakeSeconds < 2.1)
    progress = try fold(progress, interval(81, contact: false), manifest: false).progress
    #expect(progress.handshakeSeconds == 0)
    var complete = false
    for frame in UInt64(82)...133 {
      let result = try fold(progress, interval(frame), manifest: false)
      progress = result.progress
      complete = result.contactCompleted
    }
    #expect(complete && progress.handshakeSeconds == 5)
    #expect(progress.distanceMeters == 0 && progress.escortSeconds == 0)
  }
  @Test func nativeMotionCapsProgressAndProducesOnlyThreeCheckpointBits() throws {
    var progress = ProviderMissionProgress()
    var transitions = 0
    var ready = false
    for frame in UInt64(1)...1200 {
      let result = try fold(progress, interval(frame))
      progress = result.progress
      transitions += result.newCheckpoints.nonzeroBitCount
      ready = result.fullReady
    }
    #expect(ready && transitions == 3)
    #expect(
      progress.distanceMeters == 18000 && progress.escortSeconds == 60
        && progress.checkpointBits == 7)
    #expect(progress.valid(terms: ProviderContractFixture.terms.observation))
  }
  @Test func reloadRebindPauseReverseAndDefenceCannotBridgeProgress() throws {
    var progress = try fold(.init(), interval(1)).progress
    progress = try fold(progress, interval(2)).progress
    let distance = progress.distanceMeters
    progress = try fold(progress, interval(3), epoch: ProviderContractFixture.id(90)).progress
    #expect(progress.distanceMeters == distance)
    progress = try fold(progress, interval(4, generation: ProviderContractFixture.id(91))).progress
    #expect(progress.distanceMeters == distance)
    progress = try fold(
      progress, interval(5, distance: -50, generation: ProviderContractFixture.id(91))
    ).progress
    progress = try fold(
      progress, interval(6, contact: false, generation: ProviderContractFixture.id(91))
    ).progress
    progress = try fold(
      progress, interval(7, tracking: false, generation: ProviderContractFixture.id(91))
    ).progress
    #expect(progress.distanceMeters == distance)
  }
  @Test func repeatedIntervalsAndMalformedTermsAreRejected() throws {
    let current = interval(1)
    let progress = try fold(.init(), current).progress
    #expect(throws: (any Error).self) { try fold(progress, current) }
    let terms = ProviderMissionObservationTerms(
      contactRange: 5000, contactSpeed: 100,
      contactSeconds: 5, escortRange: 8000, escortSeconds: 60, checkpoints: [12000, 6000])
    #expect(!terms.valid)
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(
        ProviderMissionObservationTerms.self, from: JSONEncoder().encode(terms))
    }
  }
}
