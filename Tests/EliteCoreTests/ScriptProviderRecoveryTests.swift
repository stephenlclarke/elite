import Foundation
import Testing

@testable import EliteCore

struct ScriptProviderRecoveryTests {
  @Test func originalRecoveryCannotReplaceAnAlreadyFixedUrgentBranch() throws {
    var state = ProviderContractFixture.state()
    ProviderContractEffects.authorizeManifest(&state)
    try ProviderContractEffects.choose(.urgent, state: &state)
    state.core = ProviderContractFixture.core(state)
    state.receipts.insert(.core)
    #expect(throws: (any Error).self) {
      try ProviderContractEffects.choose(.recovery, state: &state)
    }
    #expect(state.branch == .urgent && state.terms.reward(state.branch!) == 15000 && state.valid)
  }
  @Test func unpaidCrewEarnedBeforeBetrayalIsVoidedAndZeroPayReturnWorks() throws {
    var state = ProviderContractFixture.state()
    state.crew = ProviderContractFixture.crew(state)
    state.receipts.insert(.care)
    var cash = 4_294_967_295
    try ProviderContractEffects.settleCrew(&state, credits: &cash)
    #expect(state.crew?.disposition == .pending)
    try ProviderContractEffects.betray(
      .init(
        provider: state.provider, member: state.subject,
        incident: nil, personSale: ProviderContractFixture.id(30), order: 12), state: &state)
    #expect(state.crew?.disposition == .voided && state.owedCrewReward == 0)
    try ProviderContractEffects.close(
      &state, delivery: false, dock: ProviderContractFixture.dock(ProviderContractFixture.origin),
      order: 13, credits: &cash)
    #expect(state.valid && state.stage == .cancelled && cash == 4_294_967_295)
  }
  @Test func paymentAlreadyMadeRemainsHistoricalAfterBetrayal() throws {
    var state = ProviderContractFixture.state()
    state.crew = ProviderContractFixture.crew(state)
    state.receipts.insert(.care)
    var cash = 0
    try ProviderContractEffects.settleCrew(&state, credits: &cash)
    try ProviderContractEffects.settleCrew(&state, credits: &cash)
    try ProviderContractEffects.betray(
      .init(
        provider: state.provider, member: state.subject,
        incident: nil, personSale: ProviderContractFixture.id(31), order: 12), state: &state)
    #expect(state.valid && state.crewPaid == 5000 && cash == 5000)
    #expect(state.crew?.disposition == .paid && !state.receipts.contains(.crewVoided))
  }
  @Test func actualLostCustodyKeepsInnocentOverflowClaimPending() throws {
    var state = ProviderContractFixture.state()
    state.crew = ProviderContractFixture.crew(state)
    state.receipts.insert(.care)
    state.custody = .lost
    state.cargoLossOrder = 12
    state.stage = .cargoLossPending
    var cash = 4_294_967_295
    try ProviderContractEffects.settleCrew(&state, credits: &cash)
    #expect(state.valid && state.eligible && state.owedCrewReward == 5000 && !state.stage.terminal)
    #expect(state.custody == .lost)
    cash -= 5000
    try ProviderContractEffects.settleCrew(&state, credits: &cash)
    state.stage = .failedCargo
    state.terminalOrder = state.cargoLossOrder
    state.receipts.insert(.terminal)
    #expect(state.valid && state.crewPaid == 5000 && cash == 4_294_967_295)
  }
  @Test func aComputerMarketItemOrForeignSourceCannotProveOriginalCore() throws {
    let game = Game(executive: false)
    let state = ProviderContractFixture.state()
    #expect(!game.providerCoreClaimIsAuthentic(ProviderContractFixture.core(state), state: state))
    let foreign = NativeProviderCoreClaim(
      operation: ProviderContractFixture.id(50),
      provider: .init(
        definition: state.provider.definition, system: state.provider.system,
        incarnation: ProviderContractFixture.id(51)),
      subject: state.subject, manifest: state.expectedManifest,
      lot: ProviderContractFixture.core(state).lot,
      settlement: nil, owner: state.owner, order: 11)
    #expect(!game.providerCoreClaimIsAuthentic(foreign, state: state))
  }

  @Test(arguments: [UInt64(0), 2, 4])
  func oneSnapshotOrdersActualCareAndProjectedCombatBetrayal(_ betrayalOrder: UInt64) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await NativePeopleTestFixture.capturedRuntime(storage: storage)
    try await NativePeopleTestFixture.confirm(runtime, row: .care(.capturedCrew))
    var game = await runtime.snapshot()
    let receipt = try #require(game.commander.nativePeople?.transfers.last)
    let dock = try #require(receipt.dock)
    let source = try #require(receipt.members.first?.emp.source)
    let provider = NativeProviderIdentity(
      definition: "test-convoy", system: dock.station.system,
      incarnation: ProviderContractFixture.id(60))
    let subject = ProviderContractFixture.id(61)
    let manifest = NativeProviderManifest(
      identity: ProviderContractFixture.id(62), revision: 1, provider: provider, subject: subject)
    let destinationSystem = SystemIdentity(
      galaxy: dock.station.system.galaxy, system: (dock.station.system.system + 1) % 256)
    let destination = NativeMainStationIdentity(
      world: dock.commanderOwner, system: destinationSystem,
      resource: Game.worldResourceIdentity(
        "main-station-v1:main-orbital:\(destinationSystem.galaxy):\(destinationSystem.system)"))
    let terms = ScriptProviderContractDefinition(
      provider: provider.definition, origin: provider.system,
      destination: destinationSystem, payload: "test-relay",
      observation: ProviderContractFixture.terms.observation,
      fullReward: 30000, urgentReward: 15000, recoveryReward: 20000, crewReward: 5000)
    let id = ProviderContractFixture.id(63)
    var state = ScriptProviderContractState(
      instance: id, terms: terms, owner: dock.commanderOwner,
      provider: provider, subject: subject, expectedManifest: manifest, origin: dock.station,
      destination: destination,
      item: ScriptProviderContractState.itemID(instance: id, payload: terms.payload),
      acceptedOrder: 1)
    var instance = ScriptInstance(
      id: id, definition: "project.test/provider", version: "1.0.0",
      digest: String(repeating: "a", count: 64))
    instance.payloads[terms.payload] = 1
    let incident = try #require(game.commander.savedEMPState?.records[source]?.disableIncident)
    // Common orders and betrayal adjudication are supplied boundary inputs, not G1 authentication.
    let facts = try game.resolveProviderMissionFacts(
      .init(
        provider: provider, subject: subject,
        currentBinding: nil, manifest: manifest, origin: dock.station, destination: destination,
        available: .unloaded, operationsReady: ScriptProviderContractDefinition.requiredOperations,
        routeAvailable: false, playerThreat: false,
        currentOrder: 5,
        interval: nil, core: nil,
        personOperations: [.init(operation: receipt.operation, source: source, order: 3)],
        betrayal: betrayalOrder == 0
          ? nil
          : .init(
            provider: provider, member: subject,
            incident: incident, personSale: nil, order: betrayalOrder), relay: nil))
    let cash = game.commander.credits
    try game.reconcileProviderEvidence(facts, instance: &instance, state: &state)
    try game.reconcileProviderEvidence(facts, instance: &instance, state: &state)
    #expect(game.commander.nativePeople?.transfers.last == receipt)
    #expect(state.valid)
    if betrayalOrder == 0 {
      #expect(state.crew?.operation == receipt.operation && state.crew?.dock == dock)
      #expect(state.branch == .recovery && state.manifest == manifest && state.crewPaid == 5000)
      #expect(game.commander.credits == cash + 5000)
    } else if betrayalOrder < 3 {
      #expect(state.crew == nil && state.manifest == nil && state.branch == nil)
      #expect(state.receipts == [.accepted, .betrayed])
      #expect(game.commander.credits == cash && state.crewPaid == 0)
    } else {
      #expect(
        state.crew?.disposition == .voided && state.manifest == manifest
          && state.branch == .recovery)
      #expect(state.receipts.contains(.care) && state.receipts.contains(.crewVoided))
      #expect(game.commander.credits == cash && state.crewPaid == 0)
    }
  }
}
