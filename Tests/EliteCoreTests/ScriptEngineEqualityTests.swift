import Foundation
import Testing

@testable import EliteCore

struct ScriptEngineEqualityTests {
  @Test(arguments: [
    "savedBooks", "savedWorldJobs", "savedStationResources", "savedProjectiles", "savedGeometry",
    "missionCalendar", "instances", "pendingEvents", "nextEvent", "flightSeconds", "localSeconds",
    "calendarSeconds", "transitSeconds",
  ])
  func equalityPreservesOptionalPresenceInstancesEventsAndEachClock(field: String) throws {
    let original = ScriptEngineState()
    var changed = original
    switch field {
    case "savedBooks": changed.savedBooks = [:]
    case "savedWorldJobs": changed.savedWorldJobs = [:]
    case "savedStationResources": changed.savedStationResources = [:]
    case "savedProjectiles": changed.savedProjectiles = [:]
    case "savedGeometry": changed.savedGeometry = [:]
    case "missionCalendar":
      changed.missionCalendar = .init(origin: 0, seconds: 1, lastNativeOperation: 0)
    case "instances":
      let id = UUID()
      changed.instances[id] = .init(
        id: id, definition: "test.equality", version: "1.0.0",
        digest: String(repeating: "a", count: 64))
    case "pendingEvents":
      changed.pendingEvents = [
        .init(sequence: 1, kind: "test.equality", instance: UUID(), values: [:])
      ]
    case "nextEvent": changed.nextEvent = 1
    case "flightSeconds": changed.flightSeconds = 1
    case "localSeconds": changed.localSeconds = 1
    case "calendarSeconds": changed.calendarSeconds = 1
    case "transitSeconds": changed.transitSeconds = 1
    default: Issue.record(Comment(rawValue: "Unrecognised engine equality fixture: " + field))
    }
    #expect(original != changed && changed != original)
    let retained = changed
    let decoded = try JSONDecoder().decode(
      ScriptEngineState.self, from: JSONEncoder().encode(changed))
    #expect(changed == retained && retained == decoded)
    #expect(original.worldJobs.isEmpty && original.projectiles.isEmpty && original.geometry.isEmpty)
  }

  @Test func clockEqualityPreservesNaNAndSignedZeroMemberSemantics() {
    var left = ScriptEngineState()
    var right = ScriptEngineState()
    left.flightSeconds = .nan
    right.flightSeconds = .nan
    #expect(left != right)
    left.flightSeconds = -0.0
    right.flightSeconds = 0.0
    #expect(left == right && right == left)
  }
}
