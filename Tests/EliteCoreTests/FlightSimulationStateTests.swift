import Foundation
import Testing

@testable import EliteCore

@Test func canonicalFlightAnchorsSurviveVisitsAndMatchLaunchAndArrival() throws {
  let system = SystemIdentity(galaxy: 0, system: 7)
  var state = FlightSimulationState()
  state.enter(system, arriving: false)
  let launch = try #require(state.anchors)
  #expect(state.pose.shipPoint(launch.station.position) == .init(0, 0, -500))
  #expect(state.pose.shipPoint(launch.planet.position) == .init(2600, -700, 7000))
  let allocatedFirst = state.allocateActor()
  let firstActor = try #require(allocatedFirst)
  state.enter(system, arriving: true)
  let arrival = try #require(state.anchors)
  #expect(state.pose.shipPoint(arrival.station.position) == .init(0, 0, 16000))
  #expect(arrival.planet == launch.planet && arrival.sun == launch.sun)
  #expect(arrival.arrival == launch.arrival)
  let allocatedNext = state.allocateActor()
  let nextActor = try #require(allocatedNext)
  #expect(nextActor != firstActor && nextActor.entity > firstActor.entity)
  #expect(arrival.station.identity != launch.station.identity)
}

@Test func flightPoseMatchesExistingRotationAndTranslationForLongSequences() {
  var pose = ShipPose(position: .init(0, 0, 500))
  let world = Vector3(-5000, 1500, 12500)
  var relative = pose.shipPoint(world)
  for index in 0..<10000 {
    let sign = index.isMultiple(of: 2) ? 1.0 : -1.0
    let translation = Vector3(0.4, -0.1, 1.8)
    relative = relative.rotated(pitch: 0.004 * sign, roll: 0.007, yaw: -0.003) - translation
    pose.advanceView(pitch: 0.004 * sign, roll: 0.007, yaw: -0.003, translation: translation)
  }
  #expect((pose.shipPoint(world) - relative).length < 1e-6)
  #expect((pose.systemPoint(relative) - world).length < 1e-6)
}

@Test func flightClockAndAttributionAllocatorsPersistWithoutReusingIDs() throws {
  var state = FlightSimulationState()
  state.enter(.init(galaxy: 1, system: 39), arriving: true)
  state.advancePhysicalTime(0.1)
  state.advancePhysicalTime(0.2)
  state.advancePhysicalTime(.nan)
  state.advancePhysicalTime(-2)
  let allocatedEmission = state.allocateEmission()
  let allocatedIncident = state.allocateIncident()
  let allocatedActor = state.allocateActor()
  let emission = try #require(allocatedEmission)
  let incident = try #require(allocatedIncident)
  let actor = try #require(allocatedActor)
  let data = try JSONEncoder().encode(state)
  var restored = try JSONDecoder().decode(FlightSimulationState.self, from: data)
  #expect(restored == state && restored.valid)
  #expect(abs(restored.physicalTime - 0.3) < 1e-12)
  let nextEmission = restored.allocateEmission()
  let nextIncident = restored.allocateIncident()
  let nextActor = restored.allocateActor()
  #expect(try #require(nextEmission) > emission)
  #expect(try #require(nextIncident) > incident)
  #expect(try #require(nextActor).entity > actor.entity)
}
