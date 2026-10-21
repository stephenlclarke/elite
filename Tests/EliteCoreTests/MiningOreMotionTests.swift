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
  let requests = ledger.pendingSpawnRequests(context: ecologyContext(), fields: oreMotionFields)
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
  velocity: Vector3 = .init(7, -8, 9)
) -> Bool {
  ledger.updateOreMotion(
    payload: payload.identity, actor: actor, position: position, velocity: velocity)
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
    #expect(ledger.pendingSpawnRequests(context: ecologyContext(), fields: oreMotionFields).isEmpty)
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
      position: .init(1, 2, 3), velocity: .init(0, 0, 0))
    #expect(!unknownMoved)
    #expect(ledger == unknown)
    let snapshot = ledger
    let wrong = ledger.updateOreMotion(
      payload: .wreck(oreMotionActor, lot: 0), actor: oreMotionActor,
      position: .init(1, 2, 3), velocity: .init(0, 0, 0))
    #expect(!wrong && ledger == snapshot)
    unbound.resetPhysicalBindings(system: oreMotionSystem)
    let requests = unbound.pendingSpawnRequests(context: ecologyContext(), fields: oreMotionFields)
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
    let requests = ledger.pendingSpawnRequests(context: ecologyContext(), fields: oreMotionFields)
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
    let requests = ledger.pendingSpawnRequests(context: ecologyContext(), fields: oreMotionFields)
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
}
