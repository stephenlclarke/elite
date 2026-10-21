import Foundation
import Testing

@testable import EliteCore

@Test func trafficPiratesPreferValuableNPCManifestThenPlayerWithoutAssumingHostility() throws {
  let pirate = ecologyActor(10, role: .pirate)
  let trader = ecologyActor(
    11, role: .trader, position: .init(500, 0, 6000),
    cargo: [.init(commodity: .luxuries, quantity: 12)])
  let context = ecologyContext(
    actors: [pirate, trader], playerCargo: [.init(commodity: .food, quantity: 1)])
  #expect(
    TrafficIntent.intents(context: context).first { $0.actor == pirate.identity }?.action
      == .engage(trader.identity))
  var empty = trader
  empty.ordinaryCargo = []
  let player = ecologyContext(
    actors: [pirate, empty], playerCargo: [.init(commodity: .food, quantity: 1)])
  #expect(
    TrafficIntent.intents(context: player).first { $0.actor == pirate.identity }?.action
      == .engage(player.player.identity))
}

@Test func trafficPiratesFleeWeakHullAndSuperiorPoliceInsteadOfDamagingDirectly() {
  let pirate = ecologyActor(10, role: .pirate)
  let police = [
    ecologyActor(20, role: .police), ecologyActor(21, role: .police, position: .init(10, 0, 6000)),
  ]
  let context = ecologyContext(
    actors: [pirate] + police, playerCargo: [.init(commodity: .gold, quantity: 20)])
  #expect(
    TrafficIntent.intents(context: context).first { $0.actor == pirate.identity }?.action
      == .flee(police[0].identity))
  let weak = ecologyActor(10, role: .pirate, energy: 24)
  let retreat = TrafficIntent.intents(context: ecologyContext(actors: [weak]))
  if case .navigate(let position, let speed) = retreat.first?.action {
    #expect((position - weak.position).length > 5000 && speed == weak.maximumSpeedUnitsPerSecond)
  } else {
    Issue.record("Weak unopposed pirate must physically retreat")
  }
}

@Test func trafficTradersNavigateRealDestinationDockAndFleeRecordedAggressor() {
  let destination = Vector3(0, 0, 12000)
  let outbound = ecologyActor(
    10, role: .trader, intention: .navigate(position: destination, speedUnitsPerSecond: 100))
  let inbound = ecologyActor(11, role: .trader)
  let threat = ecologyActor(20, role: .pirate)
  let victim = ecologyActor(12, role: .trader, aggressor: threat.identity)
  let context = ecologyContext(actors: [outbound, inbound, threat, victim])
  let intents = TrafficIntent.intents(context: context)
  #expect(
    intents.first { $0.actor == outbound.identity }?.action
      == .navigate(position: destination, speedUnitsPerSecond: 100))
  #expect(
    intents.first { $0.actor == inbound.identity }?.action
      == .dock(context.anchors.station.identity))
  #expect(intents.first { $0.actor == victim.identity }?.action == .flee(threat.identity))
}

@Test func trafficMinersNavigateActualFieldsThenApproachMineAndCollectOre() throws {
  let miner = ecologyActor(10, role: .miner)
  let context = ecologyContext(actors: [miner])
  let fields = MiningFields.generate(anchors: context.anchors, seed: context.seed)
  let field = try #require(
    fields.min { ($0.position - miner.position).length < ($1.position - miner.position).length })
  #expect(
    TrafficIntent.intents(context: context).first?.action
      == .navigate(position: field.position, speedUnitsPerSecond: 144))
  let rockID = RockIdentity(system: context.system, field: 0, rock: 0)
  let far = ecologyActor(30, position: .init(1000, 0, 6000), rock: rockID)
  #expect(
    TrafficIntent.intents(context: ecologyContext(actors: [miner, far])).first?.action
      == .navigate(position: far.position, speedUnitsPerSecond: 144))
  let rock = ecologyActor(30, position: .init(100, 0, 6000), rock: rockID)
  #expect(
    TrafficIntent.intents(context: ecologyContext(actors: [miner, rock])).first?.action
      == .mine(rockID))
  let payload = PayloadIdentity.ore(rockID, fragment: 0)
  let pod = ecologyActor(31, position: .init(100, 0, 6000), payload: payload)
  #expect(
    TrafficIntent.intents(context: ecologyContext(actors: [miner, rock, pod])).first?.action
      == .scoop(payload))
}

@Test func trafficProtectionMissionPayloadsAndActorOrderingCannotRedirectOrdinaryAI() {
  let pirate = ecologyActor(10, role: .pirate)
  let target = ecologyActor(11, role: .trader, cargo: [.init(commodity: .gold, quantity: 20)])
  let mission = ecologyActor(20, role: .mission)
  let missionPod = ecologyActor(21, payload: .mission(instance: UUID(), payload: "Plans"))
  var protection = MissionProtection()
  protection.protectedActors = [target.identity]
  let actors = [pirate, target, mission, missionPod]
  let context = ecologyContext(actors: actors, protection: protection)
  let intents = TrafficIntent.intents(context: context)
  #expect(!intents.contains { $0.actor == target.identity || $0.actor == mission.identity })
  #expect(
    !intents.contains {
      $0.action == .engage(target.identity) || $0.action == .scoop(missionPod.payload!)
    })
  #expect(
    intents
      == TrafficIntent.intents(
        context: ecologyContext(actors: Array(actors.reversed()), protection: protection)))
}

@Test func trafficCivilianDefenceRecognizesActualPlayerAggressorAndProtectedOreRemainsUntouched() {
  let player = ecologyContext().player
  let trader = ecologyActor(10, role: .trader, aggressor: player.identity)
  #expect(
    TrafficIntent.intents(context: ecologyContext(actors: [trader])).first?.action
      == .flee(player.identity))
  let pirate = ecologyActor(11, role: .pirate, energy: 20, aggressor: player.identity)
  #expect(
    TrafficIntent.intents(context: ecologyContext(actors: [pirate])).first?.action
      == .flee(player.identity))
  let payload = PayloadIdentity.ore(
    .init(system: player.identity.system, field: 0, rock: 0), fragment: 0)
  let pod = ecologyActor(12, payload: payload)
  var protection = MissionProtection()
  protection.protectedPayloads = [payload]
  let healthy = ecologyActor(11, role: .pirate)
  #expect(
    !TrafficIntent.intents(context: ecologyContext(actors: [healthy, pod], protection: protection))
      .contains { $0.action == .scoop(payload) })
}

@Test func trafficMinersSkipExhaustedFieldsAndStaleRocksButRecoverAlreadyReleasedOre() throws {
  let miner = ecologyActor(10, role: .miner)
  var context = ecologyContext(actors: [miner])
  let fields = MiningFields.generate(anchors: context.anchors, seed: context.seed).sorted {
    ($0.position - miner.position).length < ($1.position - miner.position).length
  }
  let nearest = try #require(fields.first)
  context.depletedRocks = Set(nearest.rocks.map(\.identity))
  let next = try #require(fields.dropFirst().first)
  #expect(
    TrafficIntent.intents(context: context).first?.action
      == .navigate(position: next.position, speedUnitsPerSecond: 144))
  let terminal = try #require(nearest.rocks.first)
  let staleRock = ecologyActor(
    30, position: miner.position + .init(100, 0, 0), rock: terminal.identity)
  var stale = ecologyContext(actors: [miner, staleRock])
  stale.depletedRocks = Set(fields.flatMap(\.rocks).map(\.identity))
  #expect(
    TrafficIntent.intents(context: stale).first?.action
      == .navigate(position: miner.position, speedUnitsPerSecond: 0))
  let payload = PayloadIdentity.ore(terminal.identity, fragment: 0)
  let pod = ecologyActor(31, position: miner.position + .init(100, 0, 0), payload: payload)
  var released = ecologyContext(actors: [miner, staleRock, pod])
  released.depletedRocks = stale.depletedRocks
  #expect(TrafficIntent.intents(context: released).first?.action == .scoop(payload))
}
