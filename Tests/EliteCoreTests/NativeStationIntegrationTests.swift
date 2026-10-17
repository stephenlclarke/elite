import Foundation
import Testing

@testable import EliteCore

struct NativeStationIntegrationTests {
  @Test func compiledStationBindingsMatchTheRetainedSourcePopulationAndSeparateHeadquarters() throws
  {
    let expected = [47, 47, 48, 32, 48, 47, 49, 46]
    #expect(NativeStationSource.bindings.count == 372)
    for galaxy in 0..<8 {
      let bindings = NativeStationSource.bindings.filter { $0.system.galaxy == galaxy }
      #expect(bindings.filter { $0.kind == .waystation }.count == expected[galaxy])
      let hq = try #require(bindings.first { $0.kind == .headquarters })
      #expect(hq.system.system == [237, 98, 5, 149, 35, 213, 66, 7][galaxy])
      let waystation = try #require(
        bindings.first { $0.system == hq.system && $0.kind == .waystation })
      #expect(waystation.key != hq.key)
      #expect(waystation.descriptor.boardOrigin == .source)
      #expect(hq.descriptor.boardOrigin == .projectExtension)
      #expect(waystation.rotationRate == 0.02 && hq.rotationRate == 0)
      #expect(waystation.technology == 7 && hq.technology == 0)
      #expect(!bindings.contains { $0.system.system == Plugh.systemID })
    }
  }

  @Test func nativeStationWorldRetainsChosenPosesWithoutMintingDockingAuthority() throws {
    let owner = UUID()
    let world = try NativeStationWorld(owner: owner)
    #expect(world.valid && world.ledger.world == owner && world.ledger.records.count == 372)
    #expect(world.ledger.currentDock == nil && world.ledger.nextDockSequence == 1)
    #expect(world.ledger.records.allSatisfy { $0.binding == nil && $0.tombstone == nil })
    let bytes = try JSONEncoder().encode(world)
    let loaded = try JSONDecoder().decode(NativeStationWorld.self, from: bytes)
    #expect(loaded == world)
    let hq = try #require(world.poses.first { $0.station.definition == "rrs_headquarters" })
    #expect(hq.orientation == loaded.pose(for: hq.station)?.orientation)
    #expect(hq.orientation(at: 0) == hq.orientation(at: 12_345))
    let waystation = try #require(world.poses.first { $0.station.definition == "rescue_station" })
    #expect(waystation.orientation == Basis3())
    #expect(waystation.orientation(at: 0) != waystation.orientation(at: 1))
    #expect(waystation.orientation(at: .nan) == nil)
  }

  @Test func savedDescriptorsAndAlteredPosesCannotReplaceTheCompiledSourceBinding() throws {
    let owner = UUID()
    let world = try NativeStationWorld(owner: owner)
    let record = try #require(world.ledger.records.first)
    #expect(NativeStationSource.authentic(record, owner: owner))
    #expect(!NativeStationSource.authentic(record, owner: UUID()))
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(world)) as? [String: Any])
    var poses = try #require(object["poses"] as? [[String: Any]])
    var position = try #require(poses[0]["position"] as? [String: Any])
    position["x"] = 0
    poses[0]["position"] = position
    object["poses"] = poses
    let forged = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: NativeStationRuntimeError.self) {
      _ = try JSONDecoder().decode(NativeStationWorld.self, from: forged)
    }
    object["poses"] = Array(repeating: poses[0], count: 373)
    let oversized = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: NativeStationRuntimeError.self) {
      _ = try JSONDecoder().decode(NativeStationWorld.self, from: oversized)
    }
  }

  @Test func stationBoardHourUsesOnlyTheExplicitNativePersistentCalendar() {
    #expect(NativeStationSource.boardHour(calendarSeconds: 0) == 0)
    #expect(NativeStationSource.boardHour(calendarSeconds: 3599.9) == 0)
    #expect(NativeStationSource.boardHour(calendarSeconds: 3600) == 1)
    #expect(NativeStationSource.boardHour(calendarSeconds: 7201) == 2)
    #expect(NativeStationSource.boardHour(calendarSeconds: -1) == nil)
    #expect(NativeStationSource.boardHour(calendarSeconds: .infinity) == nil)
    #expect(NativeStationSource.boardHour(calendarSeconds: .nan) == nil)
    #expect(NativeStationSource.boardHour(calendarSeconds: .greatestFiniteMagnitude) == nil)
  }
}
