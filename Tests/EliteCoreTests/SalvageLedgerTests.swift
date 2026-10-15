import Foundation
import Testing

@testable import EliteCore

struct SalvageLedgerTests {
  private let wreck = WreckIdentity(system: .init(galaxy: 0, system: 7), site: 1, lineage: 2)
  private let permitted = SalvageWorkConditions(
    toolInstalled: true, inRange: true, aligned: true,
    lineOfSight: true, resourcesAvailable: true, ownershipAuthorized: true)
  private func section(
    _ index: UInt16 = 0, structural: Bool = false,
    technology: [String] = ["computer-core"], seconds: Double = 2
  ) -> SalvageSectionProfile {
    .init(
      index: index, kind: .computer, localPosition: .init(10, 0, 0), normal: .init(0, 0, 2),
      radius: 10, workSeconds: seconds, structural: structural, technologyDefinitionIDs: technology,
      sourceFaceIndex: 0)
  }
  private func advance(
    _ ledger: inout SalvageLedger, section: SalvageSectionProfile,
    operation: UInt64, tool: SalvageTool = .cutter, elapsed: Double = 1,
    conditions: SalvageWorkConditions? = nil
  ) -> SalvageWorkResult {
    ledger.advance(
      wreck: wreck, section: section, pose: .init(position: .init(100, 200, 300)),
      velocity: .init(1, 0, 0), angularVelocity: .init(0, 0, 0.1), tool: tool, elapsed: elapsed,
      operation: operation, conditions: conditions ?? permitted)
  }
  private func collect(
    _ ledger: inout SalvageLedger, _ lot: SalvageLot,
    cargo: inout [Int], free: Int = 10, scoops: Bool = true, approach: Bool = true,
    aperture: Vector3 = .init(100, 100, 100), protection: MissionProtection = .init()
  )
    -> SalvageCollectionReceipt
  {
    ledger.collect(
      lot: lot.identity, cargo: &cargo, freeTonnes: free,
      apertureHalfExtents: aperture, hasScoops: scoops, approachAllowed: approach,
      protection: protection)
  }

  @Test func workPausesResumesAndMovingSurfaceHasStableParent() throws {
    var ledger = SalvageLedger(seed: 3)
    let profile = section()
    #expect(advance(&ledger, section: profile, operation: 1) == .progress(seconds: 1, required: 2))
    let paused = ledger
    #expect(advance(&ledger, section: profile, operation: 2, elapsed: 0) == .blocked)
    #expect(ledger == paused)
    let blocked = SalvageWorkConditions(
      toolInstalled: true, inRange: false, aligned: true,
      lineOfSight: true, resourcesAvailable: true, ownershipAuthorized: true)
    #expect(advance(&ledger, section: profile, operation: 2, conditions: blocked) == .blocked)
    ledger = try JSONDecoder().decode(SalvageLedger.self, from: JSONEncoder().encode(ledger))
    #expect(ledger == paused)
    guard case .released(let lots) = advance(&ledger, section: profile, operation: 2)
    else {
      Issue.record("No released technology")
      return
    }
    let lot = try #require(lots.first)
    #expect(lot.identity.section.wreck == wreck)
    #expect(lot.position == Vector3(110, 200, 300 + lot.halfExtents.length + 10))
    #expect(lot.velocity == Vector3(1, 1, 3))
    #expect(ledger.isDepleted(lot.identity.section))
    #expect(advance(&ledger, section: profile, operation: 3) == .alreadyDepleted)
    #expect(ledger.destroy(section: lot.identity.section, operation: 3) == .alreadyDepleted)
    #expect(
      try JSONDecoder().decode(SalvageLedger.self, from: JSONEncoder().encode(ledger)) == ledger)
  }

  @Test func miningDamagesDelicateTechnologyAcrossToolSwitchAndSave() throws {
    var ledger = SalvageLedger(seed: 3)
    let profile = section(structural: true)
    _ = advance(&ledger, section: profile, operation: 1, tool: .miningLaser)
    ledger = try JSONDecoder().decode(SalvageLedger.self, from: JSONEncoder().encode(ledger))
    guard case .released(let lots) = advance(&ledger, section: profile, operation: 2)
    else {
      Issue.record("Structural minerals were not released")
      return
    }
    #expect(
      lots.allSatisfy {
        if case .commodity = $0.content { return true }
        return false
      })
    var delicate = SalvageLedger()
    _ = advance(&delicate, section: section(), operation: 1, tool: .miningLaser)
    #expect(advance(&delicate, section: section(), operation: 2) == .destroyed)
    #expect(delicate.pendingLots.isEmpty)
    var combat = SalvageLedger()
    #expect(combat.destroy(section: .init(wreck: wreck, section: 0), operation: 1) == .destroyed)
    #expect(combat.pendingLots.isEmpty)
    #expect(advance(&combat, section: profile, operation: 2) == .alreadyDepleted)
  }

  @Test func physicalCollectionRefusalsKeepLotAndMassAggregatesWithoutPerItemRounding() throws {
    var ledger = SalvageLedger()
    let profile = section(technology: ["computer-core", "computer-core"], seconds: 1)
    _ = advance(&ledger, section: profile, operation: 1)
    let lot = try #require(ledger.pendingLots.first)
    var cargo = Array(repeating: 0, count: 17)
    let unchanged = ledger
    #expect(collect(&ledger, lot, cargo: &cargo, scoops: false) == .refused(.noScoops))
    #expect(collect(&ledger, lot, cargo: &cargo, approach: false) == .refused(.unsafeApproach))
    #expect(collect(&ledger, lot, cargo: &cargo, free: 0) == .refused(.fullHold))
    #expect(collect(&ledger, lot, cargo: &cargo, aperture: .init(1, 1, 1)) == .refused(.oversized))
    var protection = MissionProtection()
    protection.protectedPayloads.insert(.salvage(lot.identity))
    #expect(
      collect(&ledger, lot, cargo: &cargo, protection: protection) == .refused(.protectedPayload))
    var invalid: [Int] = []
    #expect(collect(&ledger, lot, cargo: &invalid) == .refused(.invalidCargo))
    #expect(ledger == unchanged)
    #expect(collect(&ledger, lot, cargo: &cargo, free: 1) == .collected(lot))
    #expect(ledger.reservedTonnes == 1 && ledger.inventoryMassKg == 50)
    let second = try #require(ledger.pendingLots.first)
    #expect(collect(&ledger, second, cargo: &cargo, free: 0) == .collected(second))
    #expect(ledger.reservedTonnes == 1 && ledger.inventoryMassKg == 100)
    #expect(cargo.allSatisfy { $0 == 0 })
    #expect(collect(&ledger, second, cargo: &cargo) == .refused(.unavailable))
  }

  @Test func settlementIsAtomicStaleAndForgedQuotesRefuseAndReplayNeverConsumesTwice() throws {
    var ledger = SalvageLedger(seed: 42)
    var cargo = Array(repeating: 0, count: 17)
    _ = advance(
      &ledger, section: section(technology: ["computer-core", "drive-technology"], seconds: 1),
      operation: 1)
    let lots = ledger.pendingLots
    for lot in lots { _ = collect(&ledger, lot, cargo: &cargo) }
    let command = UUID()
    let quote = try #require(
      ledger.prepareSettlement(
        command: command,
        items: [lots[0].identity], action: .sell))
    let stale = try #require(
      ledger.prepareSettlement(
        command: UUID(),
        items: [lots[1].identity], action: .research))
    #expect(quote.saleValueTenths > 0)
    #expect(ledger.settlementReceipt(for: command) == nil)
    let receipt = ledger.commitSettlement(quote)
    #expect(receipt == .committed(quote))
    #expect(ledger.settlementReceipt(for: command) == receipt)
    let saved = ledger
    #expect(ledger.commitSettlement(quote) == receipt)
    #expect(ledger == saved)
    #expect(ledger.commitSettlement(stale) == .refused)
    #expect(
      ledger.prepareSettlement(command: UUID(), items: [lots[0].identity], action: .sell) == nil)
    #expect(
      ledger.prepareSettlement(command: command, items: [lots[0].identity], action: .research)
        == nil)
    #expect(
      ledger.prepareSettlement(command: command, items: [lots[1].identity], action: .sell) == nil)
    #expect(
      ledger.prepareSettlement(
        command: UUID(), items: [lots[1].identity, lots[1].identity], action: .sell) == nil)
    let forged = SalvageSettlementProposal(
      command: command, revision: quote.revision,
      items: quote.items, action: .research, saleValueTenths: 0)
    #expect(ledger.commitSettlement(forged) == .refused)
    #expect(
      try JSONDecoder().decode(SalvageLedger.self, from: JSONEncoder().encode(ledger)) == ledger)
    #expect(ledger.inventory.count == 1)
  }

  @Test func malformedSavedStateAndNonfiniteWorkAreRejectedBeforeMutation() throws {
    var ledger = SalvageLedger()
    _ = advance(&ledger, section: section(seconds: 1), operation: 1)
    let data = try JSONEncoder().encode(ledger)
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    object["settledItemCount"] = -1
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(
        SalvageLedger.self, from: JSONSerialization.data(withJSONObject: object))
    }
    object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    object["depleted"] = (0...SalvageLedger.maximumWrecks).flatMap { index -> [Any] in
      [["system": ["galaxy": 0, "system": 7], "site": index, "lineage": 0], 1]
    }
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(
        SalvageLedger.self, from: JSONSerialization.data(withJSONObject: object))
    }
    let empty = SalvageLedger()
    ledger = empty
    #expect(
      ledger.advance(
        wreck: wreck, section: section(),
        pose: .init(position: .init(.nan, 0, 0)), velocity: .init(0, 0, 0),
        angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: 1,
        operation: 1, conditions: permitted) == .blocked)
    #expect(ledger == empty)
    #expect(advance(&ledger, section: section(technology: ["unknown"]), operation: 1) == .blocked)
    #expect(ledger == empty)
  }
  @Test func spawnRefusalRetryCullAndSavedIdentityNeverRerollContents() throws {
    var ledger = SalvageLedger(seed: 42)
    _ = advance(&ledger, section: section(seconds: 1), operation: 1)
    let original = ledger.pendingLots
    let context = ecologyContext()
    let requests = ledger.spawnRequests(context: context)
    #expect(requests.count == original.count)
    #expect(requests.allSatisfy { $0.salvage?.wreck == wreck && $0.identity.producer == .salvage })
    #expect(ledger.spawnRequests(context: context).isEmpty)
    ledger.acknowledge(
      receipts: requests.map {
        SpawnReceipt(request: $0.identity, actor: nil, refusal: .reservedCapacity)
      })
    let retry = ledger.spawnRequests(context: context)
    #expect(retry.map(\.payload) == requests.map(\.payload))
    let actor = ActorIdentity(system: wreck.system, visit: context.visit, entity: 99)
    ledger.acknowledge(
      receipts: retry.map { .init(request: $0.identity, actor: actor, refusal: nil) })
    #expect(ledger.spawnRequests(context: context).isEmpty)
    ledger.cull(actor: actor)
    #expect(ledger.spawnRequests(context: context).count == original.count)
    ledger = try JSONDecoder().decode(SalvageLedger.self, from: JSONEncoder().encode(ledger))
    ledger.resetPhysicalBindings(system: wreck.system)
    #expect(ledger.spawnRequests(context: context).count == original.count)
    #expect(ledger.pendingLots == original)
    let lot = try #require(original.first)
    ledger.updateLot(lot.identity, position: .init(1, 2, 3), velocity: .init(4, 5, 6))
    #expect(ledger.pendingLots.first?.position == Vector3(1, 2, 3))
    ledger.updateLot(lot.identity, position: .init(.nan, 0, 0), velocity: .init(0, 0, 0))
    #expect(ledger.pendingLots.first?.position == Vector3(1, 2, 3))
  }

  @Test func largeWorkPatchDoesNotEjectLootBeyondCollectionEnvelope() {
    var ledger = SalvageLedger()
    let profile = SalvageSectionProfile(
      index: 0, kind: .computer, localPosition: .init(10, 0, 0),
      normal: .init(0, 0, 1), radius: 10000, workSeconds: 1, structural: false,
      technologyDefinitionIDs: Array(repeating: "spare-escape-pod", count: 12), sourceFaceIndex: 0)
    guard case .released(let lots) = advance(&ledger, section: profile, operation: 1)
    else {
      Issue.record("No released lots")
      return
    }
    #expect(lots.count == 12)
    #expect(lots.allSatisfy { ($0.position - Vector3(110, 200, 300)).length < 80 })
    #expect(lots.allSatisfy { $0.identity.section.wreck == wreck })
  }

  @Test func pendingBoundRefusesBeforeCommittingDepletion() {
    var ledger = SalvageLedger()
    for index in 0..<SalvageLedger.maximumPending {
      let target = WreckIdentity(system: wreck.system, site: UInt32(index), lineage: 2)
      guard
        case .released = ledger.advance(
          wreck: target, section: section(seconds: 1),
          pose: .init(), velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0),
          tool: .cutter, elapsed: 1, operation: UInt64(index + 1), conditions: permitted)
      else {
        Issue.record("Admission failed below pending cap")
        return
      }
    }
    let unchanged = ledger
    #expect(advance(&ledger, section: section(1, seconds: 1), operation: 1000) == .capacityRefused)
    #expect(ledger == unchanged)
    #expect(!ledger.isDepleted(.init(wreck: wreck, section: 1)))
  }

  @Test func corruptedPhysicalMassCannotReachIntegerCapacityConversion() throws {
    var ledger = SalvageLedger()
    var cargo = Array(repeating: 0, count: 17)
    _ = advance(&ledger, section: section(seconds: 1), operation: 1)
    let lot = try #require(ledger.pendingLots.first)
    _ = collect(&ledger, lot, cargo: &cargo)
    func corruptMass(_ value: Any) -> Any {
      if var object = value as? [String: Any] {
        for (key, child) in object {
          object[key] = key == "massKg" ? Double.greatestFiniteMagnitude : corruptMass(child)
        }
        return object
      }
      if let array = value as? [Any] { return array.map(corruptMass) }
      return value
    }
    let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger))
    let data = try JSONSerialization.data(withJSONObject: corruptMass(object))
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(SalvageLedger.self, from: data) }
  }

  @Test func canonicalWreckMotionSurvivesCullSaveAndReentryWithoutOffscreenAdvance() throws {
    var ledger = SalvageLedger()
    var orientation = Basis3()
    orientation.rotate(pitch: 0.3, roll: 0.4, yaw: -0.2)
    let motion = SalvageWreckMotion(
      pose: .init(position: .init(100, 200, 300), orientation: orientation),
      velocity: .init(4, 5, 6), angularVelocity: .init(0.1, 0.2, 0.3))
    let accepted = ledger.updateWreck(identity: wreck, motion: motion)
    #expect(accepted)
    ledger.cull(actor: .init(system: wreck.system, visit: 1, entity: 99))
    ledger = try JSONDecoder().decode(SalvageLedger.self, from: JSONEncoder().encode(ledger))
    ledger.resetPhysicalBindings(system: wreck.system)
    #expect(ledger.wreckMotion(for: wreck) == motion)
    let unchanged = ledger
    var skewed = Basis3()
    skewed.x = .init(2, 0, 0)
    let rejectedSkew = ledger.updateWreck(
      identity: wreck,
      motion: .init(
        pose: .init(orientation: skewed), velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0))
    )
    #expect(!rejectedSkew)
    let rejectedVelocity = ledger.updateWreck(
      identity: wreck,
      motion: .init(
        pose: .init(), velocity: .init(.infinity, 0, 0), angularVelocity: .init(0, 0, 0)))
    #expect(!rejectedVelocity)
    #expect(ledger == unchanged)
    #expect(ledger.wreckMotion(for: .init(system: wreck.system, site: 999, lineage: 0)) == nil)
  }

}
