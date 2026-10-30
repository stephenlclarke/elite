import Foundation
import Testing

@testable import L337Core

struct NativeStationValidationMemoTests {
  @Test func changedPosesAndOwnerCannotReuseWarmWorldProof() throws {
    let original = try NativeStationWorld(owner: UUID())
    #expect(original.valid)
    var changed = original
    changed.poses[0] = .init(
      station: original.poses[0].station,
      position: original.poses[0].position + .init(1, 0, 0),
      orientation: original.poses[0].orientation, energy: original.poses[0].energy)
    #expect(!changed.valid && original.valid && changed != original)
    changed = original
    changed.ledger = try NativeStationWorld(owner: UUID()).ledger
    #expect(!changed.valid && original.valid)
    changed = original
    let pose = changed.poses[0]
    let station = NativeStationIdentity(
      world: UUID(), system: pose.station.system, definition: pose.station.definition,
      version: pose.station.version, key: pose.station.key)
    changed.poses[0] = .init(
      station: station, position: pose.position, orientation: pose.orientation, energy: pose.energy)
    #expect(!changed.valid && original.valid)
  }

  @Test func bindingTombstoneAndEnergyChangesKeepTheOriginalLifecycleChecks() throws {
    var world = try NativeStationWorld(owner: UUID())
    let identity = try #require(world.ledger.records.first?.identity)
    let index = try #require(world.poses.firstIndex { $0.station == identity })
    let binding = NativeStationBinding(
      actor: .init(system: identity.system, visit: 1, entity: 10), bodyID: 10)
    let original = world
    #expect(world.valid)
    try world.ledger.rebind(identity, to: binding)
    #expect(world.valid && world != original && original.valid)
    let live = world
    try world.ledger.destroy(identity, binding: binding)
    #expect(!world.valid, "A cached living-world proof cannot hide an unjoined death")
    world.poses[index].energy = 0
    #expect(world.valid && live.valid)
    world.poses[index].energy = 1
    #expect(!world.valid && live.valid)
    var forgedDock = live
    try forgedDock.ledger.recordDock(at: identity, binding: binding, commanderOwner: UUID())
    #expect(!forgedDock.valid && live.valid, "Dock ownership is part of the complete predicate")
    var damaged = live
    damaged.poses[index].energy *= 0.5
    #expect(damaged.valid && damaged != live && live.valid)
  }

  @Test func mainObservationsReceiptsAndHighwaterRemainPartOfSemanticProof() throws {
    let owner = UUID()
    var world = try NativeStationWorld(owner: owner)
    let system = SystemIdentity(galaxy: 0, system: 7)
    let station = NativeMainStationIdentity(
      world: owner, system: system,
      resource: Game.worldResourceIdentity("main-station-v1:main-orbital:0:7"))
    let actor = ActorIdentity(system: system, visit: 1, entity: 1)
    world.mainStations = [station]
    world.mainObservations = [.init(station: station, actor: actor, calendarSeconds: 0)]
    world.currentMainDock = .init(
      station: station, actor: actor, commanderOwner: owner, sequence: 1, calendarSeconds: 0)
    world.nextMainDockSequence = 2
    #expect(world.valid)
    var changed = world
    changed.nextMainDockSequence = 3
    #expect(!changed.valid && world.valid)
    changed = world
    changed.mainObservations += changed.mainObservations
    #expect(!changed.valid && world.valid)
    changed = world
    changed.mainStations = []
    #expect(!changed.valid && world.valid)
    changed = world
    changed.currentMainDock = .init(
      station: station, actor: actor, commanderOwner: UUID(), sequence: 1, calendarSeconds: 0)
    #expect(!changed.valid && world.valid)
  }

  @Test func decodingCannotSupplyWitnessAndWorldEqualityStillMatchesWholeValue() throws {
    let world = try NativeStationWorld(owner: UUID())
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let bytes = try encoder.encode(world)
    #expect(world.valid)
    #expect(try encoder.encode(world) == bytes)
    let decoded = try JSONDecoder().decode(NativeStationWorld.self, from: bytes)
    #expect(decoded == world && decoded.valid)
    var object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    #expect(object["validationMemo"] == nil)
    object["validationMemo"] = ["valid": true]
    var poses = try #require(object["poses"] as? [[String: Any]])
    var point = try #require(poses[0]["position"] as? [String: Any])
    point["x"] = (try #require(point["x"] as? Double)) + 1
    poses[0]["position"] = point
    object["poses"] = poses
    let forged = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(NativeStationWorld.self, from: forged)
    }
    #expect(world.valid)
  }

  @Test func concurrentCopiedWorldsNeverShareAuthorityForDifferentValues() async throws {
    let original = try NativeStationWorld(owner: UUID())
    var damaged = original
    damaged.poses[0].energy *= 0.5
    var invalid = original
    invalid.poses[0].energy = 0
    let worlds = [original, damaged, invalid]
    let results = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
      for index in 0..<6 {
        let world = worlds[index % worlds.count]
        let expected = index % worlds.count != 2
        group.addTask {
          (0..<8).allSatisfy { _ in world.valid == expected }
        }
      }
      var results: [Bool] = []
      for await result in group { results.append(result) }
      return results
    }
    #expect(results.count == 6 && results.allSatisfy { $0 })
    #expect(original.valid && damaged.valid && !invalid.valid)
  }
}
