import Foundation
import Testing

@testable import EliteCore

private func terminalWreck(_ site: UInt32 = 1) -> WreckIdentity {
  .init(system: .init(galaxy: 0, system: 7), site: site, lineage: 2)
}

private func terminalSection(_ index: UInt16 = 0, seconds: Double = 1) -> SalvageSectionProfile {
  .init(
    index: index, kind: .computer, localPosition: .init(0, 0, 0), normal: .init(0, 0, 1),
    radius: 10, workSeconds: seconds, structural: false,
    technologyDefinitionIDs: ["computer-core"], sourceFaceIndex: 0)
}

private func terminalAdvance(
  _ ledger: inout SalvageLedger, wreck: WreckIdentity = terminalWreck(),
  section: SalvageSectionProfile = terminalSection(), operation: UInt64,
  tool: SalvageTool = .cutter
) -> SalvageWorkResult {
  ledger.advance(
    wreck: wreck, section: section, pose: .init(), velocity: .init(0, 0, 0),
    angularVelocity: .init(0, 0, 0), tool: tool, elapsed: 1, operation: operation,
    conditions: .init(
      toolInstalled: true, inRange: true, aligned: true, lineOfSight: true,
      resourcesAvailable: true, ownershipAuthorized: true))
}

private func terminalObject(_ ledger: SalvageLedger) throws -> [String: Any] {
  try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger)) as? [String: Any])
}

private func terminalDecode(_ object: [String: Any]) throws -> SalvageLedger {
  try JSONDecoder().decode(
    SalvageLedger.self, from: JSONSerialization.data(withJSONObject: object))
}

struct SalvageWreckTerminalTests {
  @Test func terminalityMigratesAbsentAndNullAndRoundTripsWithoutRepeatedRevision() throws {
    var ledger = SalvageLedger(seed: 42)
    let legacy = try terminalObject(ledger)
    for null in [false, true] {
      var object = legacy
      object.removeValue(forKey: "destroyedWrecks")
      if null { object["destroyedWrecks"] = NSNull() }
      let restored = try terminalDecode(object)
      #expect(!restored.isWreckDestroyed(terminalWreck()) && restored == ledger)
    }
    let before = ledger.revision
    let marked = ledger.markWreckDestroyed(terminalWreck())
    #expect(marked && ledger.revision == before + 1)
    let saved = ledger
    let repeated = ledger.markWreckDestroyed(terminalWreck())
    #expect(repeated && ledger == saved)
    var restored = try JSONDecoder().decode(SalvageLedger.self, from: JSONEncoder().encode(ledger))
    #expect(restored == ledger && restored.isWreckDestroyed(terminalWreck()))
    restored.resetPhysicalBindings(system: terminalWreck().system)
    restored.cull(actor: .init(system: terminalWreck().system, visit: 1, entity: 99))
    #expect(restored == ledger && restored.isWreckDestroyed(terminalWreck()))
  }

  @Test func markingClearsOnlyOwnMotionAndPartialWorkAndBlocksAllParentReactivation() throws {
    var ledger = SalvageLedger()
    let motion = SalvageWreckMotion(
      pose: .init(), velocity: .init(1, 2, 3), angularVelocity: .init(0, 0, 0.1))
    _ = ledger.updateWreck(identity: terminalWreck(), motion: motion)
    _ = ledger.updateWreck(identity: terminalWreck(2), motion: motion)
    _ = terminalAdvance(
      &ledger, section: terminalSection(seconds: 3), operation: 1, tool: .miningLaser)
    _ = terminalAdvance(
      &ledger, wreck: terminalWreck(2), section: terminalSection(seconds: 3), operation: 2)
    let marked = ledger.markWreckDestroyed(terminalWreck())
    #expect(marked)
    #expect(ledger.wreckMotion(for: terminalWreck()) == nil)
    #expect(ledger.wreckMotion(for: terminalWreck(2)) == motion)
    let own = WreckSectionIdentity(wreck: terminalWreck(), section: 0)
    #expect(ledger.progress(own) == 0 && ledger.remainingStructuralMaterial(for: own) == 0)
    #expect(ledger.progress(.init(wreck: terminalWreck(2), section: 0)) == 1)
    let snapshot = ledger
    let moved = ledger.updateWreck(identity: terminalWreck(), motion: motion)
    let work = terminalAdvance(&ledger, operation: 3)
    let destroyed = ledger.destroy(section: own, operation: 4)
    #expect(!moved && work == .blocked && destroyed == .blocked)
    #expect(ledger == snapshot)
    #expect(
      try JSONDecoder().decode(SalvageLedger.self, from: JSONEncoder().encode(ledger)) == ledger)
  }

  @Test func everySectionDepletedStillDoesNotMeanParentDestroyed() {
    var ledger = SalvageLedger()
    for index in UInt16(0)..<64 {
      let result = ledger.destroy(
        section: .init(wreck: terminalWreck(), section: index), operation: UInt64(index) + 1)
      #expect(result == .destroyed)
    }
    #expect(!ledger.isWreckDestroyed(terminalWreck()))
    #expect(ledger.isDepleted(.init(wreck: terminalWreck(), section: 63)))
  }

  @Test func releasedCustodyBindingsOffersAndStoredSettlementSurviveParentDeath() throws {
    var ledger = SalvageLedger(seed: 42)
    _ = terminalAdvance(&ledger, operation: 1)
    _ = terminalAdvance(&ledger, section: terminalSection(1), operation: 2)
    _ = terminalAdvance(&ledger, section: terminalSection(2), operation: 3)
    let context = ecologyContext()
    let requests = ledger.spawnRequests(context: context)
    let first = try #require(requests.first)
    let actor = ActorIdentity(system: terminalWreck().system, visit: context.visit, entity: 99)
    ledger.acknowledge(receipts: [.init(request: first.identity, actor: actor, refusal: nil)])
    let bound = try #require(
      ledger.pendingLots.first { ledger.boundActor(for: $0.identity) == actor })
    let stored = try #require(ledger.pendingLots.first { $0.identity != bound.identity })
    var cargo = Array(repeating: 0, count: 17)
    let collected = ledger.collect(
      lot: stored.identity, cargo: &cargo, freeTonnes: 20,
      apertureHalfExtents: .init(100, 100, 100), hasScoops: true,
      approachAllowed: true, protection: .init())
    #expect(collected == .collected(stored))
    let source = SalvageLootSource(
      roles: [.commercialTrader], legalValue: 0, economy: 3, technology: 5,
      ownership: .abandoned, manifest: [])
    let plan = ledger.inspectLoot(
      wreck: terminalWreck(), section: terminalSection(3), source: source)
    #expect(plan != nil)
    let plansBefore = try terminalObject(ledger)["plans"] as? NSArray
    let pending = ledger.pendingLots
    let inventory = ledger.inventory
    let stale = try #require(
      ledger.prepareSettlement(
        command: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        items: [stored.identity], action: .sell))
    let marked = ledger.markWreckDestroyed(terminalWreck())
    #expect(marked && ledger.pendingLots == pending && ledger.inventory == inventory)
    #expect(ledger.boundActor(for: bound.identity) == actor)
    let plansAfter = try terminalObject(ledger)["plans"] as? NSArray
    #expect(plansBefore == plansAfter)
    #expect(ledger.spawnRequests(context: context).isEmpty)
    let afterMark = ledger
    let cachedPlan = ledger.inspectLoot(
      wreck: terminalWreck(), section: terminalSection(3), source: source)
    let newPlan = ledger.inspectLoot(
      wreck: terminalWreck(), section: terminalSection(4), source: source)
    #expect(cachedPlan == plan && newPlan == nil && ledger == afterMark)
    let staleReceipt = ledger.commitSettlement(stale)
    #expect(staleReceipt == .refused && ledger == afterMark)
    let proposal = try #require(
      ledger.prepareSettlement(
        command: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        items: [stored.identity], action: .sell))
    let receipt = ledger.commitSettlement(proposal)
    #expect(receipt == .committed(proposal))
    var restored = try JSONDecoder().decode(SalvageLedger.self, from: JSONEncoder().encode(ledger))
    #expect(restored.isWreckDestroyed(terminalWreck()))
    let replay = restored.commitSettlement(proposal)
    #expect(replay == receipt)
    #expect(restored.pendingLots == pending)
    let afterDeathCollection = restored.collect(
      lot: bound.identity, cargo: &cargo, freeTonnes: 20,
      apertureHalfExtents: .init(100, 100, 100), hasScoops: true,
      approachAllowed: true, protection: .init())
    #expect(afterDeathCollection == .collected(bound))
    #expect(restored.inventory.contains(bound) && restored.boundActor(for: bound.identity) == nil)
    #expect(restored.isWreckDestroyed(terminalWreck()))
  }

  @Test func invalidDuplicateOversizedAndUnionCapacityTombstonesAreRejectedAtomically() throws {
    let empty = SalvageLedger()
    let valid = try JSONSerialization.jsonObject(with: JSONEncoder().encode(terminalWreck()))
    let invalid = WreckIdentity(system: .init(galaxy: 8, system: 7), site: 1, lineage: 2)
    var rejected = empty
    let invalidMark = rejected.markWreckDestroyed(invalid)
    #expect(!invalidMark && rejected == empty)
    let bad = try JSONSerialization.jsonObject(with: JSONEncoder().encode(invalid))
    let identities = try (0...SalvageLedger.maximumWrecks).map { site in
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(terminalWreck(UInt32(site))))
    }
    for entries in [[bad], [valid, valid], identities] {
      var object = try terminalObject(empty)
      object["destroyedWrecks"] = entries
      #expect(throws: DecodingError.self) { try terminalDecode(object) }
    }
    var object = try terminalObject(empty)
    object["revision"] = NSNumber(value: UInt64.max)
    var exhausted = try terminalDecode(object)
    let exhaustedBefore = exhausted
    let accepted = exhausted.markWreckDestroyed(terminalWreck())
    #expect(!accepted && exhausted == exhaustedBefore)
    var fullObject = try terminalObject(empty)
    fullObject["destroyedWrecks"] = Array(identities.prefix(SalvageLedger.maximumWrecks - 1))
    var full = try terminalDecode(fullObject)
    let motion = SalvageWreckMotion(
      pose: .init(), velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0))
    let trackedIdentity = terminalWreck(UInt32(SalvageLedger.maximumWrecks - 1))
    let moved = full.updateWreck(identity: trackedIdentity, motion: motion)
    #expect(moved)
    let fullBefore = full
    let overflow = full.markWreckDestroyed(terminalWreck(UInt32(SalvageLedger.maximumWrecks)))
    #expect(!overflow && full == fullBefore)
    let tracked = full.markWreckDestroyed(trackedIdentity)
    #expect(tracked && full.isWreckDestroyed(trackedIdentity))
    let newMotion = full.updateWreck(
      identity: terminalWreck(UInt32(SalvageLedger.maximumWrecks)), motion: motion)
    #expect(!newMotion)
  }
}
