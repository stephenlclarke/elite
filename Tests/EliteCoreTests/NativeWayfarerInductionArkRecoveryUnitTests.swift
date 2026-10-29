import Foundation
import Testing

@testable import EliteCore

/// Transaction records only. No test here admits, destroys or replaces an actual native actor.
private struct ArkRecoveryFixture {
  let f: InductionArkProducerFixture
  let reserve: NativeInductionArkReserve
  let source: NativeInductionArkSource
  let authorization: NativeArkLaunchAuthorization
  let receipt: NativeArkRecoveryReceipt
  init(legacy: Bool = false) throws {
    let f = try InductionArkProducerFixture()
    self.f = f
    let dock = try InductionVaultKeyFixture().helpers.helpers.helpers.dock(
      owner: f.source.owner, system: 162, visit: 8, sequence: 8)
    let reserve = NativeInductionArkReserve(
      permission: f.parent.permission,
      legacyRebriefDock: legacy ? dock : nil)
    self.reserve = reserve
    let source = try NativeInductionArkSource(
      loan: f.key, permission: f.parent.permission,
      service: #require(f.parent.cassetteService), reserve: reserve)
    self.source = source
    let route = try NativeArkRoutePlan(source: source, escortReachLY: 7)
    authorization = try .preparing(
      source: source, dock: dock, carrier: f.key.carrier,
      revision: 1, physicalTime: 600, flightSeconds: 600, route: route, sequence: 20)
    let replacement = NativeInductionArkLink(
      job: authorization.job, registeredArk: source.actor,
      operation: authorization.operation, loanOperation: f.key.operation)
    let loss = NativeArkHullLoss(
      actor: .init(
        system: NativeWayfarerInduction.seedSource,
        visit: 6, entity: 2), observedPhysicalTime: 500)
    receipt = .init(
      operation: try NativeArkRecoveryReceipt.identity(
        reserve: reserve,
        retired: f.link, loss: loss, dock: dock, carrier: f.key.carrier, revision: 1,
        physicalTime: 600),
      sequence: 20, reserveIssue: reserve.issue, retired: f.link, replacement: replacement,
      priorLoss: loss, dock: dock, carrier: f.key.carrier, inventoryRevision: 1,
      physicalTime: 600, flightSeconds: 600)
  }
  func parent() throws -> ScriptInstance {
    var parent = ScriptInstance(
      id: f.source.mission, definition: NativeWayfarerInduction.stateID,
      version: NativeWayfarerInduction.version, digest: NativeWayfarerInduction.digest)
    let registered = try f.parent.registeringArk(f.link)
    parent.savedWayfarerInduction = try registered.replacingDestroyedArk(receipt, reserve: reserve)
    parent.savedArkReserve = reserve
    parent.savedArkRecovery = receipt
    parent.payloads = parent.savedWayfarerInduction!.payloads
    parent.milestones = parent.savedWayfarerInduction!.milestones
    parent.acknowledge(receipt.sequence)
    return parent
  }
  func engine() throws -> ScriptEngineState {
    let initial = try f.state().replacing(
      admission: .init(actor: receipt.priorLoss.actor, physicalTime: 401))
    let lost = initial.replacing(loss: receipt.priorLoss)
    var retired = f.child(lost.replacing(fuel: try lost.fuel.retiring(at: receipt)))
    retired.acknowledge(receipt.sequence)
    var replacement = ScriptInstance(
      id: authorization.job, definition: NativeInductionArkPack.stateID,
      version: NativeInductionArkPack.version, digest: NativeInductionArkPack.digest)
    replacement.savedNativeArk = .init(
      authorization: authorization, fuel: try .init(source: source))
    replacement.acknowledge(receipt.sequence)
    let parent = try parent()
    var engine = ScriptEngineState()
    engine.nextEvent = receipt.sequence
    engine.flightSeconds = 600
    engine.instances = [parent.id: parent, retired.id: retired, replacement.id: replacement]
    return engine
  }
}

struct NativeWayfarerInductionArkRecoveryUnitTests {
  @Test func oneInitialReserveHasDistinctFiniteHullSeedCrewAndFuelFundingIdentities() throws {
    let f = try ArkRecoveryFixture()
    #expect(f.reserve.valid(permission: f.f.parent.permission))
    #expect(
      f.reserve.fuelCredits == 10_000 && f.reserve.seeds.count == 40 && f.reserve.crew.count == 6)
    #expect(f.source.issue == .reserve && f.source.actor != f.f.source.actor)
    #expect(Set(f.source.seeds).isDisjoint(with: f.f.source.seeds))
    #expect(Set(f.source.crew).isDisjoint(with: f.f.source.crew))
    #expect(f.source.seeds == f.reserve.seeds && f.source.crew == f.reserve.crew)
    #expect(f.source.definition == f.f.source.definition && f.source.physical.id == "SH061")
    #expect(f.authorization.valid(source: f.source, key: f.f.key))
    let reopened = NativeInductionArkReserve(permission: f.f.parent.permission)
    #expect(reopened == f.reserve)
    let foreign = try ArkRecoveryFixture()
    #expect(!f.reserve.valid(permission: foreign.f.parent.permission))
  }

  @Test func replacingTheLostArkKeepsOriginalKeyAndHistoryWithoutPaymentOrMilestoneProgress() throws
  {
    let f = try ArkRecoveryFixture()
    let registered = try f.f.parent.registeringArk(f.f.link)
    let next = try registered.replacingDestroyedArk(f.receipt, reserve: f.reserve)
    #expect(next.valid && next.ark == f.receipt.replacement && next.seedKey == registered.seedKey)
    #expect(next.payloads == registered.payloads && next.milestones == registered.milestones)
    #expect(next.permission == registered.permission && next.reception == registered.reception)
    #expect(next.cassetteService == registered.cassetteService && next.seedReception == nil)
    #expect(throws: (any Error).self) {
      try next.replacingDestroyedArk(f.receipt, reserve: f.reserve)
    }
    let foreign = try ArkRecoveryFixture()
    #expect(throws: (any Error).self) {
      try registered.replacingDestroyedArk(foreign.receipt, reserve: foreign.reserve)
    }
    let restored = try JSONDecoder().decode(
      NativeWayfarerInductionState.self, from: JSONEncoder().encode(next))
    #expect(restored == next && restored.valid)
  }

  @Test func originalKeyLossCannotBeHiddenByReserveConsentOrMintAReplacementKey() throws {
    let f = try ArkRecoveryFixture()
    let registered = try f.f.parent.registeringArk(f.f.link)
    let context = ScriptEventContext(
      galaxy: 0, system: 162, docked: false, mainStation: false,
      revision: 7, frameSeconds: 0, localSeconds: 600, flightSeconds: 600,
      calendarSeconds: 600, transitSeconds: 0, playerPosition: nil)
    let loss = NativeInductionCrateLoss(
      carrier: f.f.key.carrier, physicalTime: 550,
      facts: .init(cause: .shipDestroyed, sequence: 30, context: context, energy: 0, visit: 8))
    let lost = try registered.losing(loss)
    #expect(lost.valid && lost.payloads.isEmpty && lost.seedKey == registered.seedKey)
    #expect(throws: (any Error).self) {
      try lost.replacingDestroyedArk(f.receipt, reserve: f.reserve)
    }
    #expect(lost.seedKeyLoss == loss && lost.ark == f.f.link)
  }

  @Test func retiringOldEscrowAndIssuingReserveFundingConservesBothSeparateFiniteAccounts() throws {
    let f = try ArkRecoveryFixture()
    let original = try NativeArkFuelEscrow(source: f.f.source)
    let retired = try original.retiring(at: f.receipt)
    let replacement = try NativeArkFuelEscrow(source: f.source)
    #expect(
      retired.valid && retired.remainingCredits == 0 && retired.closure?.returnedCredits == 10_000)
    #expect(
      retired.closure?.recoveryOperation == f.receipt.operation
        && retired.closure?.receivingOperation == nil)
    #expect(retired.closure?.recipient == NativeArkFuelClosure.custodian(owner: original.owner))
    #expect(
      replacement.valid && replacement.issue == .reserve && replacement.remainingCredits == 10_000)
    #expect(replacement.ark != retired.ark && replacement.closure == nil)
    #expect(throws: (any Error).self) { try retired.retiring(at: f.receipt) }
    #expect(throws: (any Error).self) { try replacement.retiring(at: f.receipt) }
    #expect(try NativeArkFuelEscrow.decodeClosed(JSONEncoder().encode(retired)) == retired)
    #expect(try NativeArkFuelEscrow.decodeClosed(JSONEncoder().encode(replacement)) == replacement)
  }

  @Test
  func recoveryJoinRequiresRetainedActualLossBothOwnedJobsAndTheSameAcknowledgedSourceTransaction()
    throws
  {
    let f = try ArkRecoveryFixture()
    let parent = try f.parent()
    let engine = try f.engine()
    #expect(NativeInductionArkSave.recoveryFactsValid(parent, engine: engine))
    var missing = engine
    missing.instances[f.receipt.retired.job] = nil
    #expect(!NativeInductionArkSave.recoveryFactsValid(parent, engine: missing))
    var notDestroyed = engine
    notDestroyed.instances[f.receipt.retired.job]?.savedNativeArk = try f.f.state()
    #expect(!NativeInductionArkSave.recoveryFactsValid(parent, engine: notDestroyed))
    var unacknowledged = engine
    unacknowledged.instances[f.receipt.replacement.job]?.acknowledgedThrough = nil
    #expect(!NativeInductionArkSave.recoveryFactsValid(parent, engine: unacknowledged))
    #expect(
      engine.instances.count == 3
        && engine.instances[f.receipt.retired.job]?.savedNativeArk?.loss == f.receipt.priorLoss)
  }

  @Test
  func closedRecoverySchemaRejectsOldForeignOrReplenishedReserveAndRetainsLegacyRebriefOrigin()
    throws
  {
    let f = try ArkRecoveryFixture(legacy: true)
    #expect(
      f.reserve.legacyRebriefDock == f.receipt.dock
        && f.receipt.valid(
          reserve: f.reserve,
          key: f.f.key, permission: f.f.parent.permission)
    )
    let engine = try f.engine()
    let data = try JSONEncoder().encode(engine)
    try ScriptSaveJSONPreflight.validateRepairLoopFields(data, part: .missions, schema: 81)
    try ScriptSaveJSONPreflight.validateRepairLoopFields(data, part: .missions, schema: 82)
    for schema in [73, 75, 77, 79, 80] {
      #expect(throws: (any Error).self) {
        try NativeInductionArkSave.validateFields(data, part: .missions, schema: schema)
      }
    }
    var reserve = try #require(
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(f.reserve)) as? [String: Any])
    reserve["fuelCredits"] = 20_000
    var parent = try #require(
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(f.parent())) as? [String: Any])
    parent["savedArkReserve"] = reserve
    let rewritten = try JSONSerialization.data(withJSONObject: [
      "instances": [f.f.source.mission.uuidString: parent]
    ])
    #expect(throws: (any Error).self) {
      try NativeInductionArkSave.validateFields(rewritten, part: .missions, schema: 81)
    }
    #expect([76, 78, 80, 82].allSatisfy { NativeInductionArkSave.isAlien($0) })
    #expect([75, 77, 79, 81].allSatisfy { !NativeInductionArkSave.isAlien($0) })
    #expect(
      NativeInductionArkSave.lowerSchema(80) == 74 && NativeInductionArkSave.lowerSchema(82) == 74)
  }
}
