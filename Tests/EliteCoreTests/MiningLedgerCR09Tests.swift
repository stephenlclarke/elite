import Foundation
import Testing

@testable import EliteCore

private let cr09System = SystemIdentity(galaxy: 0, system: 7)

private func cr09Ledger(damage: Double = 200) throws -> MiningLedger {
  var ledger = MiningLedger(seed: 42)
  let rock = MiningRock(
    identity: .init(system: cr09System, field: 0, rock: 0),
    position: .init(100, 200, 300), radius: 40, energy: 150)
  let actor = ActorIdentity(system: cr09System, visit: 1, entity: 1)
  let incident = CombatIncident(
    id: 1, physicalTime: 1,
    origin: .init(
      emissionID: 1, owner: actor, ordnance: nil, emittedAt: 1,
      ownerLegalAtEmission: .init()), victim: nil, kind: .laser, outcome: .hit,
    position: rock.position, victimLegalBeforeAttack: nil, firstAggressor: nil,
    victimRole: nil, victimIsStation: false, laser: .mining, mount: .front)
  _ = ledger.hit(rock: rock, incident: incident, damage: damage)
  return ledger
}

private func cr09Object(_ ledger: MiningLedger) throws -> [String: Any] {
  try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger)) as? [String: Any])
}

private func cr09Decode(_ object: [String: Any]) throws -> MiningLedger {
  try JSONDecoder().decode(MiningLedger.self, from: JSONSerialization.data(withJSONObject: object))
}

struct MiningLedgerCR09Tests {
  @Test func validEmptyPartialAndExtractedLedgersRoundTripUnchanged() throws {
    for ledger in [MiningLedger(), try cr09Ledger(damage: 50), try cr09Ledger()] {
      #expect(ledger.valid)
      let restored = try cr09Decode(cr09Object(ledger))
      #expect(restored == ledger && restored.valid)
    }
  }

  @Test func offeredAndBoundMotionRoundTripsAndInvalidActorsAreRejected() throws {
    var ledger = try cr09Ledger()
    let rock = MiningRock(
      identity: .init(system: cr09System, field: 0, rock: 0),
      position: .init(100, 200, 300), radius: 40, energy: 150)
    let requests = ledger.pendingSpawnRequests(
      context: ecologyContext(time: 1),
      fields: [.init(position: rock.position, rocks: [rock])])
    #expect(!requests.isEmpty && ledger.valid)
    #expect(try cr09Decode(cr09Object(ledger)) == ledger)
    ledger.acknowledge(
      receipts: requests.enumerated().map { index, request in
        .init(
          request: request.identity,
          actor: .init(system: cr09System, visit: 1, entity: UInt64(index) + 2), refusal: nil)
      })
    #expect(ledger.valid)
    let item = try #require(ledger.pendingPayloads.first)
    let actor = try #require(ledger.boundActor(for: item.identity))
    let moved = ledger.updateOreMotion(
      payload: item.identity, actor: actor,
      position: .init(400, 500, 600), velocity: .init(1, 2, 3), physicalTime: 1)
    #expect(moved && ledger.valid)
    #expect(try cr09Decode(cr09Object(ledger)) == ledger)
    let valid = try cr09Object(ledger)
    let clocks = try #require(valid["regularPayloadTimes"] as? [Any])
    try #require(clocks.count >= 4)
    for mutation in 0..<6 {
      var object = valid
      var altered = clocks
      switch mutation {
      case 0: object.removeValue(forKey: "regularPayloadTimes")
      case 1: object["regularPayloadTimes"] = []
      case 2:
        altered[1] = -1.0
        object["regularPayloadTimes"] = altered
      case 3:
        altered[2] = altered[0]
        object["regularPayloadTimes"] = altered
      case 4:
        let orphan = PayloadIdentity.ore(.init(system: cr09System, field: 0, rock: 1), fragment: 0)
        altered[0] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(orphan))
        object["regularPayloadTimes"] = altered
      default:
        object["regularPayloadTimes"] = (0...MiningLedger.maximumPending).flatMap { _ in
          [clocks[0], clocks[1]]
        }
      }
      #expect(throws: (any Error).self) { try cr09Decode(object) }
    }
    let records = try #require(valid["bindings"] as? [Any])
    for visit in [UInt64(0), UInt64.max] {
      var object = valid
      var bindings = records
      var badActor = try #require(bindings[1] as? [String: Any])
      badActor["visit"] = NSNumber(value: visit)
      bindings[1] = badActor
      object["bindings"] = bindings
      #expect(throws: (any Error).self) { try cr09Decode(object) }
    }
    if records.count >= 4 {
      var object = valid
      var duplicate = records
      duplicate[3] = duplicate[1]
      object["bindings"] = duplicate
      #expect(throws: (any Error).self) { try cr09Decode(object) }
    }
    let original = Commander()
    let absent = try JSONDecoder().decode(Commander.self, from: JSONEncoder().encode(original))
    #expect(absent == original && absent.miningLedger.valid)
  }

  @Test func decoderRejectsNegativeEnergyInvalidRockAndPendingIdentityMismatch() throws {
    let partial = try cr09Object(cr09Ledger(damage: 50))
    for energy in [0.0, -1] {
      var object = partial
      var records = try #require(object["partial"] as? [Any])
      records[1] = energy
      object["partial"] = records
      #expect(throws: (any Error).self) { try cr09Decode(object) }
    }
    var badRock = partial
    var partialRecords = try #require(badRock["partial"] as? [Any])
    var key = try #require(partialRecords[0] as? [String: Any])
    key["rock"] = 12
    partialRecords[0] = key
    badRock["partial"] = partialRecords
    #expect(throws: (any Error).self) { try cr09Decode(badRock) }
    var mismatch = try cr09Object(cr09Ledger())
    var pending = try #require(mismatch["pending"] as? [Any])
    var item = try #require(pending[1] as? [String: Any])
    item["identity"] = [
      "wreck": [
        "_0": [
          "system": ["galaxy": 0, "system": 7],
          "visit": 1, "entity": 99,
        ], "lot": 0,
      ]
    ]
    pending[1] = item
    mismatch["pending"] = pending
    #expect(throws: (any Error).self) { try cr09Decode(mismatch) }
  }

  @Test func boundedDecoderRejectsDuplicateAndOversizedCollectionsBeforeAcceptingState() throws {
    let valid = try cr09Object(cr09Ledger())
    let pending = try #require(valid["pending"] as? [Any])
    var oversized: [Any] = []
    for fragment in 0...MiningLedger.maximumPending {
      var identity = try #require(pending[0] as? [String: Any])
      var ore = try #require(identity["ore"] as? [String: Any])
      ore["fragment"] = fragment
      identity["ore"] = ore
      oversized.append(identity)
      oversized.append(pending[1])
    }
    for records in [Array(pending.prefix(2)) + Array(pending.prefix(2)), oversized] {
      var object = valid
      object["pending"] = records
      #expect(throws: (any Error).self) { try cr09Decode(object) }
    }
    var partialObject = try cr09Object(cr09Ledger(damage: 50))
    let pair = try #require(partialObject["partial"] as? [Any])
    var manyPartial: [Any] = []
    for rock in 0...MiningLedger.maximumPartial {
      var identity = try #require(pair[0] as? [String: Any])
      identity["rock"] = rock
      manyPartial.append(identity)
      manyPartial.append(pair[1])
    }
    partialObject["partial"] = manyPartial
    #expect(throws: (any Error).self) { try cr09Decode(partialObject) }
    var missing = valid
    missing.removeValue(forKey: "lastIncident")
    #expect(throws: (any Error).self) { try cr09Decode(missing) }
  }

  @Test func noncanonicalOreAndIncoherentBindingsCannotEnterSavedCommander() throws {
    let valid = try cr09Object(cr09Ledger())
    for quantity in [0, 2, Int.max] {
      var object = valid
      var pending = try #require(object["pending"] as? [Any])
      var item = try #require(pending[1] as? [String: Any])
      var amount = try #require(item["amount"] as? [String: Any])
      amount["quantity"] = quantity
      item["amount"] = amount
      pending[1] = item
      object["pending"] = pending
      #expect(throws: (any Error).self) { try cr09Decode(object) }
    }
    var object = valid
    let pending = try #require(object["pending"] as? [Any])
    object["bindings"] = [
      pending[0],
      [
        "system": ["galaxy": 0, "system": 8],
        "visit": 1, "entity": 99,
      ],
    ]
    #expect(throws: (any Error).self) { try cr09Decode(object) }
    var commander = Commander()
    commander.miningLedger = try cr09Ledger()
    var save = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(commander)) as? [String: Any])
    save["savedMiningLedger"] = object
    let data = try JSONSerialization.data(withJSONObject: save)
    #expect(throws: (any Error).self) { try JSONDecoder().decode(Commander.self, from: data) }
  }
}
