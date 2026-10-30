import Foundation
import Testing

@testable import L337Core

/// Raw custody component values only; these fixtures do not claim valid admissions or a journey.
struct NativePeopleCargoProjectionTests {
  @Test(arguments: [
    "absent", "nil-inout", "empty", "reserved", "pod", "two-pods", "captive", "terminal",
  ])
  func scalarCargoQueriesPreserveReservationPodsNilAndRetainedState(scenario: String) throws {
    var commander = Commander()
    var state = fixture()
    switch scenario {
    case "absent": commander.savedNativePeopleCustody = nil
    case "nil-inout":
      func retainNil(_ value: inout NativePeopleCustodyState?) { value = nil }
      retainNil(&commander.savedNativePeopleCustody)
    case "empty":
      state.originalRescue = nil
      commander.savedNativePeopleCustody = state
    case "reserved": commander.savedNativePeopleCustody = state
    case "pod", "two-pods", "captive":
      let count = scenario == "two-pods" ? 2 : 1
      state.admissions = (0..<count).map { ordinal in
        .init(
          person: .rescue(
            .init(
              owner: state.owner, batch: NativeOriginalRescueJourney.batch,
              ordinal: ordinal)),
          origin: scenario == "captive" ? .capturedCrew : .originalRescuedPod,
          operation: UUID(),
          actor: .init(system: .init(galaxy: 0, system: 85), visit: 1, entity: 2),
          collector: .init(system: .init(galaxy: 0, system: 85), visit: 1, entity: 0),
          owner: state.owner, hull: UUID(), tool: UUID(), inventoryRevision: 1,
          physicalTime: 0, epoch: UUID(), revision: 1)
      }
      commander.savedNativePeopleCustody = state
    case "terminal":
      state.originalRescue?.terminalOperation = UUID()
      commander.savedNativePeopleCustody = state
    default:
      Issue.record(Comment(rawValue: "Unrecognised custody cargo fixture: " + scenario))
      return
    }
    let expectedReservation = scenario == "reserved" || scenario == "captive"
    let expectedPods = scenario == "two-pods" ? 2 : scenario == "pod" ? 1 : 0
    let retained = commander
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let bytes = try encoder.encode(commander)
    #expect(commander.checkedCargoTonnes == expectedPods + (expectedReservation ? 1 : 0))
    #expect(commander.rescuedPodTonnes == expectedPods)
    #expect(commander == retained)
    #expect(try encoder.encode(commander) == bytes)
    let decoded = try JSONDecoder().decode(
      NativePeopleCustodyState?.self, from: encoder.encode(commander.savedNativePeopleCustody))
    #expect(decoded == commander.savedNativePeopleCustody)
    var restored = Commander()
    restored.savedNativePeopleCustody = decoded
    #expect(restored.checkedCargoTonnes == expectedPods + (expectedReservation ? 1 : 0))
    #expect(restored.rescuedPodTonnes == expectedPods)
    commander.savedNativePeopleCustody = nil
    #expect(commander.checkedCargoTonnes == 0 && commander.rescuedPodTonnes == 0)
    #expect(retained.checkedCargoTonnes == expectedPods + (expectedReservation ? 1 : 0))
    #expect(retained.rescuedPodTonnes == expectedPods)
    #expect(try encoder.encode(retained) == bytes)
  }

  private func fixture() -> NativePeopleCustodyState {
    let owner = UUID()
    var state = NativePeopleCustodyState(owner: owner)
    let dock = NativeWayfarerInductionUnitTests().dock(
      owner: owner, system: 85, visit: 1, sequence: 1)
    state.originalRescue = .init(
      owner: owner,
      definition: .init(
        batch: NativeOriginalRescueJourney.batch, sourceGalaxy: 0, sourceSystem: 85,
        destinationGalaxy: 0, destinationSystem: 241, people: []),
      version: "1", digest: NativeOriginalRescueJourney.digest, registration: dock,
      registeredAt: 0, inventoryRevision: 1, operation: UUID(), mission: UUID(), carrier: UUID(),
      reservedBerths: [])
    return state
  }
}
