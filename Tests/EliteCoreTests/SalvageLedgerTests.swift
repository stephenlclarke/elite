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

  private func source(
    roles: Set<SalvageSourceRole> = [.commercialCarrier],
    manifest: [CommodityAmount]? = nil
  ) -> SalvageLootSource {
    .init(
      roles: roles, legalValue: 0, economy: 3, technology: 10,
      ownership: .abandoned, manifest: manifest)
  }

  private func plannedAdvance(
    _ ledger: inout SalvageLedger, profile: SalvageSectionProfile,
    source: SalvageLootSource, operation: UInt64, tool: SalvageTool = .cutter
  ) -> SalvageWorkResult {
    ledger.advance(
      wreck: wreck, section: profile, pose: .init(), velocity: .init(0, 0, 0),
      angularVelocity: .init(0, 0, 0), tool: tool, elapsed: 1, operation: operation,
      conditions: permitted, source: source)
  }

  @Test func fullCapitalManifestIsIssuedInFiniteManageableBatchesWithoutTruncation() throws {
    let snapshot = source(manifest: [.init(commodity: .food, quantity: 6000)])
    let identity = WreckSectionIdentity(wreck: wreck, section: 1)
    let seed = try #require(
      (0..<100).first {
        SalvageLootProfiles.plan(section: identity, seed: UInt64($0), source: snapshot).items.count
          == 1
      })
    var ledger = SalvageLedger(seed: UInt64(seed))
    let profile = section(1, technology: [], seconds: 1)
    let inspected = ledger.inspectLoot(wreck: wreck, section: profile, source: snapshot)
    let plan = try #require(inspected)
    #expect(plan.originalManifest == snapshot.manifest)
    var cargo = Array(repeating: 0, count: 17)
    var issued = Set<SalvageLotIdentity>()
    for operation in 1...150 {
      guard
        case .released(let lots) = plannedAdvance(
          &ledger, profile: profile,
          source: snapshot, operation: UInt64(operation))
      else {
        Issue.record("Missing batch")
        return
      }
      #expect(lots.count == 8)
      for lot in lots {
        #expect(issued.insert(lot.identity).inserted)
        guard case .commodity(let amount) = lot.content else {
          Issue.record("Unexpected cargo")
          return
        }
        #expect(amount.commodity == .food && amount.quantity == 5)
        #expect(lot.loot?.identity == lot.identity)
        #expect(collect(&ledger, lot, cargo: &cargo, free: 6000) == .collected(lot))
      }
      #expect(ledger.isDepleted(identity) == (operation == 150))
      if operation == 75 {
        let decoded = try JSONDecoder().decode(
          SalvageLedger.self, from: JSONEncoder().encode(ledger))
        #expect(decoded == ledger)
        ledger = decoded
      }
    }
    #expect(cargo[CommodityIdentity.food.rawValue] == 6000)
    #expect(issued.count == 1200 && ledger.pendingLots.isEmpty)
    #expect(
      plannedAdvance(&ledger, profile: profile, source: snapshot, operation: 151)
        == .alreadyDepleted)
    #expect(
      ledger.inspectLoot(wreck: wreck, section: profile, source: source(manifest: [])) == plan)
  }

  @Test func emptyInspectionAndAsteroidOwnershipNeverRerollOrGrantSalvageOre() throws {
    var ledger = SalvageLedger()
    let profile = section(structural: true, technology: [], seconds: 1)
    let asteroid = source(roles: [.asteroid])
    let inspected = ledger.inspectLoot(wreck: wreck, section: profile, source: asteroid)
    let original = try #require(inspected)
    #expect(original.emptyReason == .miningLedgerOwnsOre)
    #expect(ledger.remainingStructuralMaterial(for: original.section) == 0)
    ledger = try JSONDecoder().decode(SalvageLedger.self, from: JSONEncoder().encode(ledger))
    #expect(
      ledger.inspectLoot(
        wreck: wreck, section: profile,
        source: source(roles: [.militaryCapital])) == original)
    #expect(plannedAdvance(&ledger, profile: profile, source: asteroid, operation: 1) == .destroyed)
    #expect(ledger.pendingLots.isEmpty)
  }

  @Test func miningDiscardsUnissuedTechnologyButPlatingHasOneSharedFiniteYield() throws {
    var ledger = SalvageLedger(seed: 3)
    let snapshot = source(roles: [.thargoid])
    let profile = section(structural: true, seconds: 2)
    let inspected = ledger.inspectLoot(wreck: wreck, section: profile, source: snapshot)
    let plan = try #require(inspected)
    #expect(plan.items.count == 1)
    let initial = ledger.remainingStructuralMaterial(for: plan.section)
    #expect((1...5).contains(initial))
    _ = plannedAdvance(
      &ledger, profile: profile, source: snapshot, operation: 1, tool: .miningLaser)
    ledger = try JSONDecoder().decode(SalvageLedger.self, from: JSONEncoder().encode(ledger))
    guard
      case .released(let lots) = plannedAdvance(
        &ledger, profile: profile,
        source: snapshot, operation: 2)
    else {
      Issue.record("No plating yield")
      return
    }
    #expect(lots.count == 1)
    #expect(lots[0].content == .commodity(.init(commodity: .minerals, quantity: initial)))
    #expect(ledger.remainingStructuralMaterial(for: plan.section) == 0)
    #expect(ledger.isDepleted(plan.section))
    #expect(ledger.inventory.isEmpty)
  }

  @Test func pendingLotDestructionIsTerminalWhileCullNeverDestroysAndProtectionRefuses() throws {
    var ledger = SalvageLedger()
    let snapshot = source(roles: [.thargoid])
    _ = plannedAdvance(&ledger, profile: section(seconds: 1), source: snapshot, operation: 1)
    let lot = try #require(ledger.pendingLots.first)
    #expect(lot.loot?.provenance == .alien)
    var protection = MissionProtection()
    protection.protectedPayloads.insert(.salvage(lot.identity))
    let refused = ledger.destroy(lot: lot.identity, protection: protection)
    #expect(!refused && ledger.pendingLots.contains(lot))
    let destroyed = ledger.destroy(lot: lot.identity, protection: .init())
    #expect(destroyed)
    ledger.resetPhysicalBindings(system: wreck.system)
    ledger = try JSONDecoder().decode(SalvageLedger.self, from: JSONEncoder().encode(ledger))
    #expect(ledger.pendingLots.isEmpty && ledger.spawnRequests(context: ecologyContext()).isEmpty)
    let retry = ledger.destroy(lot: lot.identity, protection: .init())
    #expect(!retry)
  }

  @Test func sparePodStorageLimitRetainsThirdUntilAtomicFitFreesOneSlot() throws {
    var ledger = SalvageLedger()
    _ = advance(
      &ledger,
      section: section(
        technology: Array(repeating: "spare-escape-pod", count: 3),
        seconds: 1), operation: 1)
    let lots = ledger.pendingLots
    var cargo = Array(repeating: 0, count: 17)
    _ = collect(&ledger, lots[0], cargo: &cargo)
    _ = collect(&ledger, lots[1], cargo: &cargo)
    #expect(collect(&ledger, lots[2], cargo: &cargo) == .refused(.sparePodLimit))
    #expect(ledger.inventory.count == 2 && ledger.pendingLots.contains(lots[2]))
    let proposal = try #require(
      ledger.prepareSettlement(
        command: UUID(),
        items: [lots[0].identity], action: .fit(axis: nil, mount: nil)))
    #expect(ledger.commitSettlement(proposal) == .committed(proposal))
    #expect(collect(&ledger, lots[2], cargo: &cargo) == .collected(lots[2]))
    #expect(ledger.inventory.count == 2)
  }

  @Test func nativeKilogramsAndGramsKeepExactQuantitiesWithZeroTradeTonneReservation() throws {
    let snapshot = source(manifest: [
      .init(commodity: .gold, quantity: 2501),
      .init(commodity: .gemstones, quantity: 2_000_001),
    ])
    let identity = WreckSectionIdentity(wreck: wreck, section: 1)
    let seed = try #require(
      (0..<100).first {
        SalvageLootProfiles.plan(section: identity, seed: UInt64($0), source: snapshot).items.count
          == 2
      })
    var ledger = SalvageLedger(seed: UInt64(seed))
    guard
      case .released(let lots) = plannedAdvance(
        &ledger,
        profile: section(1, technology: [], seconds: 1), source: snapshot, operation: 1)
    else {
      Issue.record("No native-unit fragments")
      return
    }
    #expect(lots.count == 6)
    var cargo = Array(repeating: 0, count: 17)
    for lot in lots { #expect(collect(&ledger, lot, cargo: &cargo, free: 0) == .collected(lot)) }
    #expect(cargo[CommodityIdentity.gold.rawValue] == 2501)
    #expect(cargo[CommodityIdentity.gemstones.rawValue] == 2_000_001)
    #expect(ledger.reservedTonnes == 0 && ledger.inventory.isEmpty)
    #expect(
      try JSONDecoder().decode(SalvageLedger.self, from: JSONEncoder().encode(ledger)) == ledger)
  }

  @Test func immutablePlanCapacityRefusesWithoutEvictingEarlierEmptyRolls() throws {
    var ledger = SalvageLedger()
    let snapshot = source(roles: [.asteroid])
    for index in 0..<SalvageLedger.maximumPlans {
      let target = WreckIdentity(system: wreck.system, site: UInt32(index), lineage: 9)
      #expect(ledger.inspectLoot(wreck: target, section: section(), source: snapshot) != nil)
    }
    let unchanged = ledger
    let refused = ledger.inspectLoot(
      wreck: .init(system: wreck.system, site: 999, lineage: 9),
      section: section(), source: snapshot)
    #expect(refused == nil && ledger == unchanged)
    #expect(
      try JSONDecoder().decode(SalvageLedger.self, from: JSONEncoder().encode(ledger)) == ledger)
  }

  @Test func fixedLootEffectsAndLegalityRejectCorruptionOnReload() throws {
    let snapshot = source(roles: [.militaryCapital])
    let identity = WreckSectionIdentity(wreck: wreck, section: 0)
    let seed = try #require(
      (0..<100).first {
        SalvageLootProfiles.plan(section: identity, seed: UInt64($0), source: snapshot).items
          .contains {
            if case .scalar = $0.effect { return true }
            return false
          }
      })
    var ledger = SalvageLedger(seed: UInt64(seed))
    _ = plannedAdvance(&ledger, profile: section(seconds: 1), source: snapshot, operation: 1)
    func corruptBonus(_ value: Any) -> Any {
      if var object = value as? [String: Any] {
        for (key, child) in object {
          object[key] = key == "bonusBasisPoints" ? 4000 : corruptBonus(child)
        }
        return object
      }
      if let array = value as? [Any] { return array.map(corruptBonus) }
      return value
    }
    let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger))
    let data = try JSONSerialization.data(withJSONObject: corruptBonus(object))
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(SalvageLedger.self, from: data) }
  }

  @Test func boundEquipmentReplayPinsHullComponentVersionAndExactEffect() throws {
    var ledger = SalvageLedger()
    _ = advance(&ledger, section: section(seconds: 1), operation: 1)
    let lot = try #require(ledger.pendingLots.first)
    var cargo = Array(repeating: 0, count: 17)
    _ = collect(&ledger, lot, cargo: &cargo)
    let command = UUID()
    let hull = UUID()
    let component = UUID()
    let action = SalvageDefinitionAction.fit(axis: .scanningRange, mount: nil)
    func binding(_ targetHull: UUID, _ expected: UUID?, _ version: UInt32)
      -> SalvageTransactionBinding
    {
      .equipment(
        target: .hull(instance: targetHull), expectedComponentInstanceID: expected,
        templateVersion: version, axis: .scanningRange, feature: nil)
    }
    let pinned = binding(hull, component, 1)
    let quote = try #require(
      ledger.prepareSettlement(
        command: command,
        items: [lot.identity], action: action, binding: pinned))
    #expect(ledger.commitSettlement(quote) == .committed(quote))
    for changed in [
      binding(UUID(), component, 1), binding(hull, UUID(), 1),
      binding(hull, nil, 1), binding(hull, component, 2),
    ] {
      #expect(
        ledger.prepareSettlement(
          command: command, items: [lot.identity],
          action: action, binding: changed) == nil)
      let forged = SalvageSettlementProposal(
        command: command, revision: quote.revision,
        items: quote.items, action: action, saleValueTenths: 0, binding: changed)
      #expect(ledger.commitSettlement(forged) == .refused)
    }
    #expect(
      ledger.prepareSettlement(
        command: command, items: [lot.identity],
        action: action, binding: pinned) == quote)
    let decoded = try JSONDecoder().decode(SalvageLedger.self, from: JSONEncoder().encode(ledger))
    #expect(decoded == ledger)
    #expect(decoded.settlementReceipt(for: command) == .committed(quote))
  }

  @Test func researchBindingsRequireKnownRecipeAndPositiveTemplateVersion() throws {
    var ledger = SalvageLedger()
    _ = advance(
      &ledger, section: section(technology: ["computer-core", "computer-core"], seconds: 1),
      operation: 1)
    var cargo = Array(repeating: 0, count: 17)
    let lots = ledger.pendingLots
    for lot in lots { _ = collect(&ledger, lot, cargo: &cargo) }
    let identities = lots.map(\.identity)
    #expect(
      ledger.prepareSettlement(
        command: UUID(), items: identities, action: .research,
        binding: .research(
          recipeID: "unknown", expectedComponentInstanceID: nil,
          templateVersion: 1)) == nil)
    #expect(
      ledger.prepareSettlement(
        command: UUID(), items: identities, action: .research,
        binding: .research(
          recipeID: "navigation-2", expectedComponentInstanceID: nil,
          templateVersion: 0)) == nil)
    let quote = try #require(
      ledger.prepareSettlement(
        command: UUID(), items: identities,
        action: .research,
        binding: .research(
          recipeID: "navigation-2",
          expectedComponentInstanceID: nil, templateVersion: 1)))
    #expect(ledger.commitSettlement(quote) == .committed(quote))
    func corruptVersion(_ value: Any) -> Any {
      if var object = value as? [String: Any] {
        for (key, child) in object {
          object[key] = key == "templateVersion" ? 0 : corruptVersion(child)
        }
        return object
      }
      if let array = value as? [Any] { return array.map(corruptVersion) }
      return value
    }
    let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger))
    let data = try JSONSerialization.data(withJSONObject: corruptVersion(object))
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(SalvageLedger.self, from: data) }
  }

  @Test func boundAlienConversionPinsRecipeHullPylonAndComponentOnRetry() throws {
    var ledger = SalvageLedger()
    _ = advance(&ledger, section: section(technology: ["alien-artefact"], seconds: 1), operation: 1)
    let lot = try #require(ledger.pendingLots.first)
    var cargo = Array(repeating: 0, count: 17)
    _ = collect(&ledger, lot, cargo: &cargo)
    let command = UUID()
    let hull = UUID()
    let pinned = SalvageTransactionBinding.alien(
      recipe: .seekerMissile,
      target: .missilePylon(hull: hull, index: 0), expectedComponentInstanceID: nil,
      templateVersion: 1)
    let quote = try #require(
      ledger.prepareSettlement(
        command: command, items: [lot.identity],
        action: .fit(axis: nil, mount: nil), binding: pinned))
    #expect(ledger.commitSettlement(quote) == .committed(quote))
    let changed = SalvageTransactionBinding.alien(
      recipe: .seekerMissile,
      target: .missilePylon(hull: hull, index: 1), expectedComponentInstanceID: nil,
      templateVersion: 1)
    #expect(
      ledger.prepareSettlement(
        command: command, items: [lot.identity],
        action: .fit(axis: nil, mount: nil), binding: changed) == nil)
    #expect(
      ledger.prepareSettlement(
        command: command, items: [lot.identity],
        action: .fit(axis: .frontShieldRecharge, mount: nil),
        binding: .alien(
          recipe: .shieldRegenerator,
          target: .shield(hull: hull, axis: .frontShieldRecharge), expectedComponentInstanceID: nil,
          templateVersion: 1)) == nil)
    #expect(
      try JSONDecoder().decode(SalvageLedger.self, from: JSONEncoder().encode(ledger)) == ledger)
  }

  @Test func exactVacantPylonLocationPreventsSlotSubstitutionAndReplay() throws {
    var ledger = SalvageLedger()
    _ = advance(
      &ledger, section: section(technology: ["missile-standard"], seconds: 1), operation: 1)
    let lot = try #require(ledger.pendingLots.first)
    var cargo = Array(repeating: 0, count: 17)
    _ = collect(&ledger, lot, cargo: &cargo)
    let hull = UUID()
    let command = UUID()
    func binding(_ location: ComponentFittingLocation) -> SalvageTransactionBinding {
      .equipment(
        target: .hull(instance: hull), expectedComponentInstanceID: nil,
        templateVersion: 1, axis: nil, feature: nil, location: location)
    }
    let pinned = binding(.init(hullInstanceID: hull, slot: .missilePylon(0)))
    #expect(pinned.location?.slot == .missilePylon(0))
    for invalid in [
      ComponentFittingLocation(hullInstanceID: UUID(), slot: .missilePylon(0)),
      .init(hullInstanceID: hull, slot: .missilePylon(32)),
      .init(hullInstanceID: hull, slot: .drive),
    ] {
      #expect(
        ledger.prepareSettlement(
          command: UUID(), items: [lot.identity],
          action: .fit(axis: nil, mount: nil), binding: binding(invalid)) == nil)
    }
    let quote = try #require(
      ledger.prepareSettlement(
        command: command, items: [lot.identity],
        action: .fit(axis: nil, mount: nil), binding: pinned))
    #expect(ledger.commitSettlement(quote) == .committed(quote))
    let substituted = binding(.init(hullInstanceID: hull, slot: .missilePylon(1)))
    #expect(
      ledger.prepareSettlement(
        command: command, items: [lot.identity],
        action: .fit(axis: nil, mount: nil), binding: substituted) == nil)
    let forged = SalvageSettlementProposal(
      command: command, revision: quote.revision,
      items: quote.items, action: quote.action, saleValueTenths: 0, binding: substituted)
    #expect(ledger.commitSettlement(forged) == .refused)
    #expect(
      try JSONDecoder().decode(SalvageLedger.self, from: JSONEncoder().encode(ledger)) == ledger)
  }

  @Test func locationMustMatchLaserFacingFeatureSlotAndAlienTargetIndex() throws {
    var ledger = SalvageLedger()
    _ = advance(
      &ledger,
      section: section(
        technology: [
          "laser-technology", "feature-mining-targeting",
          "alien-artefact",
        ], seconds: 1), operation: 1)
    let lots = ledger.pendingLots
    var cargo = Array(repeating: 0, count: 17)
    for lot in lots { _ = collect(&ledger, lot, cargo: &cargo) }
    let hull = UUID()
    let laser = lots[0]
    let wrongLaser = SalvageTransactionBinding.equipment(
      target: .laser(hull: hull, mount: .front, kind: .naval),
      expectedComponentInstanceID: UUID(), templateVersion: 1, axis: .laserDamage, feature: nil,
      location: .init(hullInstanceID: hull, slot: .laser(.left)))
    #expect(
      ledger.prepareSettlement(
        command: UUID(), items: [laser.identity],
        action: .fit(axis: .laserDamage, mount: .front), binding: wrongLaser) == nil)
    let module = lots[1]
    let wrongModule = SalvageTransactionBinding.equipment(
      target: .hull(instance: hull),
      expectedComponentInstanceID: nil, templateVersion: 1, axis: nil,
      feature: .miningTargetingModule,
      location: .init(hullInstanceID: hull, slot: .targetingSalvage))
    #expect(
      ledger.prepareSettlement(
        command: UUID(), items: [module.identity],
        action: .fit(axis: nil, mount: nil), binding: wrongModule) == nil)
    let artefact = lots[2]
    let wrongAlien = SalvageTransactionBinding.alien(
      recipe: .seekerMissile,
      target: .missilePylon(hull: hull, index: 0), expectedComponentInstanceID: nil,
      templateVersion: 1,
      location: .init(hullInstanceID: hull, slot: .missilePylon(1)))
    #expect(
      ledger.prepareSettlement(
        command: UUID(), items: [artefact.identity],
        action: .fit(axis: nil, mount: nil), binding: wrongAlien) == nil)
    let correctAlien = SalvageTransactionBinding.alien(
      recipe: .seekerMissile,
      target: .missilePylon(hull: hull, index: 0), expectedComponentInstanceID: nil,
      templateVersion: 1,
      location: .init(hullInstanceID: hull, slot: .missilePylon(0)))
    #expect(
      ledger.prepareSettlement(
        command: UUID(), items: [artefact.identity],
        action: .fit(axis: nil, mount: nil), binding: correctAlien) != nil)
  }

  @Test func oldCommittedReceiptWithoutLocationRemainsDecodableAndReplayable() throws {
    var ledger = SalvageLedger()
    _ = advance(
      &ledger, section: section(technology: ["computer-core", "computer-core"], seconds: 1),
      operation: 1)
    var cargo = Array(repeating: 0, count: 17)
    let lots = ledger.pendingLots
    for lot in lots { _ = collect(&ledger, lot, cargo: &cargo) }
    let binding = SalvageTransactionBinding.research(
      recipeID: "navigation-2",
      expectedComponentInstanceID: nil, templateVersion: 1)
    let quote = try #require(
      ledger.prepareSettlement(
        command: UUID(), items: lots.map(\.identity),
        action: .research, binding: binding))
    #expect(ledger.commitSettlement(quote) == .committed(quote))
    func removeLocation(_ value: Any) -> Any {
      if var object = value as? [String: Any] {
        object.removeValue(forKey: "location")
        for (key, child) in object { object[key] = removeLocation(child) }
        return object
      }
      if let array = value as? [Any] { return array.map(removeLocation) }
      return value
    }
    let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger))
    let data = try JSONSerialization.data(withJSONObject: removeLocation(object))
    var restored = try JSONDecoder().decode(SalvageLedger.self, from: data)
    #expect(restored == ledger)
    #expect(restored.settlementReceipt(for: quote.command) == .committed(quote))
    #expect(restored.commitSettlement(quote) == .committed(quote))
    let changed = SalvageTransactionBinding.research(
      recipeID: "navigation-2",
      expectedComponentInstanceID: nil, templateVersion: 1,
      location: .init(hullInstanceID: UUID(), slot: .navigation))
    #expect(
      restored.prepareSettlement(
        command: quote.command, items: lots.map(\.identity),
        action: .research, binding: changed) == nil)
  }

  @Test func energyAndNavigationEffectsBindTheirActualDeviceSlots() throws {
    var ledger = SalvageLedger()
    _ = advance(
      &ledger, section: section(technology: ["energy-technology", "drive-technology"], seconds: 1),
      operation: 1)
    var cargo = Array(repeating: 0, count: 17)
    let lots = ledger.pendingLots
    for lot in lots { _ = collect(&ledger, lot, cargo: &cargo) }
    let hull = UUID()
    for (lot, axis, correct, wrong) in [
      (
        lots[0], SalvageUpgradeAxis.energyRecharge, ComponentFittingSlot.energy,
        ComponentFittingSlot.drive
      ),
      (lots[1], .jumpReach, .navigation, .drive),
      (lots[1], .spoolDuration, .navigation, .drive),
      (lots[1], .maximumSpeed, .drive, .navigation),
    ] {
      func binding(_ slot: ComponentFittingSlot) -> SalvageTransactionBinding {
        .equipment(
          target: .hull(instance: hull), expectedComponentInstanceID: UUID(),
          templateVersion: 1, axis: axis, feature: nil,
          location: .init(hullInstanceID: hull, slot: slot))
      }
      #expect(
        ledger.prepareSettlement(
          command: UUID(), items: [lot.identity],
          action: .fit(axis: axis, mount: nil), binding: binding(correct)) != nil)
      #expect(
        ledger.prepareSettlement(
          command: UUID(), items: [lot.identity],
          action: .fit(axis: axis, mount: nil), binding: binding(wrong)) == nil)
    }
  }

  @Test func commanderResearchBindingsRemainSoftwareOnlyAndCannotPreparePhysicalFits() throws {
    var ledger = SalvageLedger()
    _ = advance(
      &ledger,
      section: section(
        technology: [
          "energy-technology", "drive-technology",
          "shield-technology", "computer-core",
        ], seconds: 1), operation: 1)
    var cargo = Array(repeating: 0, count: 17)
    let lots = ledger.pendingLots
    for lot in lots { _ = collect(&ledger, lot, cargo: &cargo) }
    let hull = UUID()
    for (lot, axis, slot) in [
      (lots[0], SalvageUpgradeAxis.energyRecharge, ComponentFittingSlot.energy),
      (lots[1], .jumpReach, .navigation), (lots[2], .frontShieldCapacity, .shield),
    ] {
      for location in [
        ComponentFittingLocation?.none, .some(.init(hullInstanceID: hull, slot: slot)),
      ] {
        let binding = SalvageTransactionBinding.equipment(
          target: .commanderResearch,
          expectedComponentInstanceID: UUID(), templateVersion: 1, axis: axis, feature: nil,
          location: location)
        #expect(
          ledger.prepareSettlement(
            command: UUID(), items: [lot.identity],
            action: .fit(axis: axis, mount: nil), binding: binding) == nil)
      }
    }
    let software = SalvageTransactionBinding.equipment(
      target: .commanderResearch,
      expectedComponentInstanceID: UUID(), templateVersion: 1, axis: .scanningRange, feature: nil,
      location: .init(hullInstanceID: hull, slot: .targetingCore))
    #expect(
      ledger.prepareSettlement(
        command: UUID(), items: [lots[3].identity],
        action: .fit(axis: .scanningRange, mount: nil), binding: software) != nil)
  }

}
