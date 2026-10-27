import Foundation
import Testing

@testable import EliteCore

private let oreMotionSystem = SystemIdentity(galaxy: 0, system: 7)
private let oreMotionActor = ActorIdentity(system: oreMotionSystem, visit: 1, entity: 99)
private let oreMotionRock = MiningRock(
  identity: .init(system: oreMotionSystem, field: 0, rock: 0),
  position: .init(100, 200, 300), radius: 40, energy: 150)
private let oreMotionFields = [
  MiningField(position: oreMotionRock.position, rocks: [oreMotionRock])
]

private func oreMotionFixture(acknowledge: Bool = true) throws -> (MiningLedger, TypedCargoPayload)
{
  var ledger = MiningLedger(seed: 42)
  let incident = CombatIncident(
    id: 1, physicalTime: 1,
    origin: .init(
      emissionID: 1, owner: oreMotionActor, ordnance: nil, emittedAt: 1,
      ownerLegalAtEmission: .init()),
    victim: nil, kind: .laser, outcome: .hit, position: oreMotionRock.position,
    victimLegalBeforeAttack: nil, firstAggressor: nil, victimRole: nil,
    victimIsStation: false, laser: .mining, mount: .front)
  let result = ledger.hit(rock: oreMotionRock, incident: incident, damage: 200)
  guard case .extracted(let pods) = result else {
    throw CocoaError(.coderInvalidValue)
  }
  let selected = try #require(pods.first)
  let requests = ledger.pendingSpawnRequests(
    context: ecologyContext(time: 1), fields: oreMotionFields)
  #expect(!requests.isEmpty)
  if acknowledge {
    ledger.acknowledge(
      receipts: requests.enumerated().map { index, request in
        .init(
          request: request.identity,
          actor: .init(system: oreMotionSystem, visit: 1, entity: 99 + UInt64(index)), refusal: nil)
      })
  }
  return (ledger, selected)
}

private func oreMove(
  _ ledger: inout MiningLedger, _ payload: TypedCargoPayload,
  actor: ActorIdentity = oreMotionActor, position: Vector3 = .init(400, 500, 600),
  velocity: Vector3 = .init(7, -8, 9), physicalTime: Double = 1
) -> Bool {
  ledger.updateOreMotion(
    payload: payload.identity, actor: actor, position: position, velocity: velocity,
    physicalTime: physicalTime)
}

struct MiningOreMotionTests {
  @Test func exactWriterChangesOnlySelectedPoseAndKeepsSiblingCargoAndDepletion() throws {
    var (ledger, selected) = try oreMotionFixture()
    let snapshot = ledger
    let siblings = ledger.pendingPayloads.filter { $0.identity != selected.identity }
    let moved = oreMove(&ledger, selected)
    #expect(moved)
    let updated = try #require(ledger.pendingPayloads.first { $0.identity == selected.identity })
    #expect(updated.amount == selected.amount)
    #expect(updated.position == Vector3(400, 500, 600) && updated.velocity == Vector3(7, -8, 9))
    #expect(ledger.pendingPayloads.filter { $0.identity != selected.identity } == siblings)
    #expect(ledger.isDepleted(oreMotionRock.identity))
    #expect(
      ledger.pendingSpawnRequests(context: ecologyContext(time: 1), fields: oreMotionFields).isEmpty
    )
    let restored = oreMove(
      &ledger, selected, position: selected.position, velocity: selected.velocity)
    #expect(restored)
    #expect(ledger == snapshot)
  }

  @Test func unacknowledgedFailedAndWrongActorOrPayloadCannotWrite() throws {
    var (unbound, selected) = try oreMotionFixture(acknowledge: false)
    let before = unbound
    let preack = oreMove(&unbound, selected)
    #expect(!preack && unbound == before)
    var (ledger, payload) = try oreMotionFixture()
    for actor in [
      ActorIdentity(system: oreMotionSystem, visit: 2, entity: 99),
      ActorIdentity(system: oreMotionSystem, visit: 1, entity: 98),
      ActorIdentity(system: .init(galaxy: 0, system: 8), visit: 1, entity: 99),
    ] {
      let snapshot = ledger
      let moved = oreMove(&ledger, payload, actor: actor)
      #expect(!moved && ledger == snapshot)
    }
    if let sibling = ledger.pendingPayloads.first(where: { $0.identity != payload.identity }) {
      let before = ledger
      let siblingMoved = oreMove(&ledger, sibling)
      #expect(!siblingMoved && ledger == before)
    }
    let unknown = ledger
    let unknownMoved = ledger.updateOreMotion(
      payload: .ore(oreMotionRock.identity, fragment: UInt16.max), actor: oreMotionActor,
      position: .init(1, 2, 3), velocity: .init(0, 0, 0), physicalTime: 1)
    #expect(!unknownMoved)
    #expect(ledger == unknown)
    let snapshot = ledger
    let wrong = ledger.updateOreMotion(
      payload: .wreck(oreMotionActor, lot: 0), actor: oreMotionActor,
      position: .init(1, 2, 3), velocity: .init(0, 0, 0), physicalTime: 1)
    #expect(!wrong && ledger == snapshot)
    unbound.resetPhysicalBindings(system: oreMotionSystem)
    let requests = unbound.pendingSpawnRequests(
      context: ecologyContext(time: 1), fields: oreMotionFields)
    unbound.acknowledge(
      receipts: requests.map {
        .init(request: $0.identity, actor: nil, refusal: .populationLimit)
      })
    let failedBefore = unbound
    let failed = oreMove(&unbound, selected)
    #expect(!failed && unbound == failedBefore)
  }

  @Test func nonfiniteCoordinatesOverflowLengthsAndIdenticalMotionAreAtomicNoops() throws {
    var (ledger, selected) = try oreMotionFixture()
    let snapshot = ledger
    for value in [Double.nan, .infinity, -.infinity, .greatestFiniteMagnitude] {
      for coordinate in 0..<6 {
        var p = selected.position
        var v = selected.velocity
        switch coordinate {
        case 0: p.x = value
        case 1: p.y = value
        case 2: p.z = value
        case 3: v.x = value
        case 4: v.y = value
        default: v.z = value
        }
        let moved = oreMove(&ledger, selected, position: p, velocity: v)
        #expect(!moved && ledger == snapshot)
      }
    }
    let identical = oreMove(
      &ledger, selected, position: selected.position, velocity: selected.velocity)
    #expect(!identical && ledger == snapshot)
  }

  @Test func cullReofferAndNewAcknowledgementRetainLatestMotionAndRejectOldWriter() throws {
    var (ledger, selected) = try oreMotionFixture()
    _ = oreMove(&ledger, selected)
    ledger.cull(actor: oreMotionActor)
    let culled = ledger
    let culledMoved = oreMove(&ledger, selected)
    #expect(!culledMoved && ledger == culled)
    let requests = ledger.pendingSpawnRequests(
      context: ecologyContext(time: 1), fields: oreMotionFields)
    let request = try #require(requests.first { $0.payload == selected.identity })
    #expect(request.position == Vector3(400, 500, 600) && request.velocity == Vector3(7, -8, 9))
    let next = ActorIdentity(system: oreMotionSystem, visit: 1, entity: 999)
    ledger.acknowledge(receipts: [.init(request: request.identity, actor: next, refusal: nil)])
    let before = ledger
    let stale = oreMove(&ledger, selected)
    #expect(!stale && ledger == before)
    let current = oreMove(&ledger, selected, actor: next, position: .init(700, 800, 900))
    #expect(current)
  }

  @Test func savedMotionReoffersAndCollectsOnceAndTerminalPayloadsNeverRevive() throws {
    var (ledger, selected) = try oreMotionFixture()
    _ = oreMove(&ledger, selected)
    ledger = try JSONDecoder().decode(MiningLedger.self, from: JSONEncoder().encode(ledger))
    ledger.resetPhysicalBindings(system: oreMotionSystem)
    let reset = ledger
    let resetMoved = oreMove(&ledger, selected)
    #expect(!resetMoved && ledger == reset)
    let requests = ledger.pendingSpawnRequests(
      context: ecologyContext(time: 1), fields: oreMotionFields)
    let request = try #require(requests.first { $0.payload == selected.identity })
    #expect(request.position == Vector3(400, 500, 600) && request.velocity == Vector3(7, -8, 9))
    ledger.acknowledge(receipts: [
      .init(request: request.identity, actor: oreMotionActor, refusal: nil)
    ])
    var cargo = Array(repeating: 0, count: 17)
    let receipt = ledger.collect(
      payload: selected.identity, into: &cargo, freeTonnes: 100,
      hasScoops: true, approachAllowed: true, protection: .init())
    #expect(receipt == .collected(selected.amount))
    #expect(cargo[selected.amount.commodity.rawValue] == selected.amount.quantity)
    let cargoBefore = cargo
    let duplicate = ledger.collect(
      payload: selected.identity, into: &cargo, freeTonnes: 100,
      hasScoops: true, approachAllowed: true, protection: .init())
    #expect(duplicate == .refused(.unavailable) && cargo == cargoBefore)
    let collectedBefore = ledger
    let revived = oreMove(&ledger, selected)
    #expect(!revived && ledger == collectedBefore)
    for departed in [false, true] {
      var (terminal, item) = try oreMotionFixture()
      if departed {
        terminal.depart(system: oreMotionSystem)
      } else {
        _ = terminal.destroy(payload: item.identity)
      }
      let before = terminal
      let moved = oreMove(&terminal, item)
      #expect(!moved && terminal == before)
    }
  }

  @Test func regularOreRefusedReoffersAdvanceByPhysicalTimeAndSurviveColdLoad() throws {
    let identity = RockIdentity(system: oreMotionSystem, field: 5, rock: 0)
    let chunk = try #require(AsteroidBeltDefinition.chunk(for: identity))
    try #require(chunk.units == 20)
    let rock = MiningRock(
      identity: identity, position: .init(100, 200, 300), radius: chunk.radius, energy: chunk.energy
    )
    let incident = CombatIncident(
      id: 1, physicalTime: 10,
      origin: .init(
        emissionID: 1, owner: oreMotionActor, ordnance: nil, emittedAt: 10,
        ownerLegalAtEmission: .init()),
      victim: nil, kind: .laser, outcome: .hit, position: rock.position,
      victimLegalBeforeAttack: nil, firstAggressor: nil, victimRole: nil,
      victimIsStation: false, laser: .mining, mount: .front)
    var ledger = MiningLedger(seed: 42)
    let result = ledger.hit(
      rock: rock, incident: incident, damage: chunk.energy,
      motion: .init(position: rock.position, velocity: .init(0, 0, 0), physicalTime: 10))
    guard case .extracted(let issued) = result else {
      Issue.record("Missing regular twenty-unit release")
      return
    }
    try #require(issued.count == 20)
    let fields = [MiningField(position: rock.position, rocks: [rock])]
    var direct = ledger
    var coldLoaded = false
    // Typed refusals exercise the ledger protocol; these are not measured G12 refusal reasons.
    for time in [10.0, 11, 11, 12] {
      let requests = ledger.pendingSpawnRequests(
        context: ecologyContext(time: time), fields: fields)
      #expect(requests.count == 20 && ledger.valid)
      for request in requests {
        let birth = try #require(issued.first { $0.identity == request.payload })
        #expect(request.position == birth.position + birth.velocity * (time - 10))
        #expect(request.velocity == birth.velocity && request.rock == nil && request.hull == .cargo)
        #expect(ledger.boundActor(for: birth.identity) == nil)
        let pending = try #require(ledger.pendingPayloads.first { $0.identity == birth.identity })
        #expect(pending.amount == birth.amount && pending.velocity == birth.velocity)
      }
      ledger.acknowledge(
        receipts: requests.map {
          .init(request: $0.identity, actor: nil, refusal: .unsafePosition)
        })
      #expect(
        ledger.pendingPayloads.count == 20
          && ledger.pendingPayloads.reduce(0) { $0 + $1.amount.quantity } == 20)
      if time == 11 && !coldLoaded {
        ledger = try JSONDecoder().decode(MiningLedger.self, from: JSONEncoder().encode(ledger))
        coldLoaded = true
      }
    }
    let beforeBackwards = ledger
    let backwards = ledger.pendingSpawnRequests(context: ecologyContext(time: 11), fields: fields)
    #expect(backwards.isEmpty && ledger == beforeBackwards)
    let oneInterval = direct.pendingSpawnRequests(context: ecologyContext(time: 12), fields: fields)
    #expect(oneInterval.count == 20 && ledger.pendingPayloads == direct.pendingPayloads)
    #expect(ledger.isDepleted(identity) && ledger.valid && coldLoaded)
  }

  @Test func regularOreCullResumesLatestTimedPoseAndRejectsStaleOrBackdatedWriter() throws {
    var (ledger, selected) = try oreMotionFixture()
    let position13 = selected.position + selected.velocity * 12
    let sampled = oreMove(
      &ledger, selected, position: position13, velocity: selected.velocity, physicalTime: 13)
    #expect(sampled)
    let before = ledger
    let stale = oreMove(
      &ledger, selected, actor: .init(system: oreMotionSystem, visit: 1, entity: 98),
      physicalTime: 14)
    #expect(!stale && ledger == before)
    for time in [12.0, -1, .nan, .infinity, -.infinity] {
      let changed = oreMove(
        &ledger, selected, position: position13, velocity: selected.velocity, physicalTime: time)
      #expect(!changed && ledger == before)
    }
    var stationary = ledger
    let stopped = oreMove(
      &stationary, selected, position: position13, velocity: .init(0, 0, 0), physicalTime: 13)
    #expect(stopped)
    let clockOnly = oreMove(
      &stationary, selected, position: position13, velocity: .init(0, 0, 0), physicalTime: 14)
    #expect(clockOnly && stationary.valid)
    ledger.cull(actor: oreMotionActor)
    let unbound = ledger
    let unboundWrite = oreMove(&ledger, selected, physicalTime: 14)
    #expect(!unboundWrite && ledger == unbound)
    let requests = ledger.pendingSpawnRequests(
      context: ecologyContext(time: 14), fields: oreMotionFields)
    let request = try #require(requests.first { $0.payload == selected.identity })
    #expect(
      request.position == position13 + selected.velocity && request.velocity == selected.velocity)
    let replacement = ActorIdentity(system: oreMotionSystem, visit: 1, entity: 999)
    ledger.acknowledge(receipts: [
      .init(request: request.identity, actor: replacement, refusal: nil)
    ])
    var cargo = Array(repeating: 0, count: Commodity.all.count)
    let collected = ledger.collect(
      payload: selected.identity, into: &cargo, freeTonnes: 100,
      hasScoops: true, approachAllowed: true, protection: .init())
    #expect(collected == .collected(selected.amount))
    #expect(!ledger.pendingPayloads.contains { $0.identity == selected.identity })
    if let sibling = ledger.pendingPayloads.first {
      let destroyed = ledger.destroy(payload: sibling.identity)
      #expect(destroyed && ledger.valid)
    }
    ledger = try JSONDecoder().decode(MiningLedger.self, from: JSONEncoder().encode(ledger))
    ledger.depart(system: oreMotionSystem)
    #expect(
      ledger.pendingPayloads.isEmpty && ledger.isDepleted(oreMotionRock.identity) && ledger.valid)
    #expect(
      try JSONDecoder().decode(MiningLedger.self, from: JSONEncoder().encode(ledger)) == ledger)
  }

}
