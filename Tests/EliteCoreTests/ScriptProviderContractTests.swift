import Foundation
import Testing

@testable import EliteCore

/// Pure contract fixtures; these are not claims of physical provider or station admission.
enum ProviderContractFixture {
  static func id(_ number: Int) -> UUID { ScriptIdentity.uuid("provider-test-\(number)") }
  static let epoch = id(1)
  static let scene = id(2)
  static let owner = id(3)
  static let origin = SystemIdentity(galaxy: 7, system: 8)
  static let destination = SystemIdentity(galaxy: 7, system: 202)
  static var terms: ScriptProviderContractDefinition {
    .init(
      provider: "crimbo-convoy", origin: origin, destination: destination,
      payload: "navigation-relay",
      observation: .init(
        contactRange: 5000, contactSpeed: 100, contactSeconds: 5,
        escortRange: 8000, escortSeconds: 60, checkpoints: [6000, 12000, 18000]),
      fullReward: 30000, urgentReward: 15000, recoveryReward: 20000, crewReward: 5000)
  }
  static func station(_ system: SystemIdentity) -> NativeMainStationIdentity {
    .init(
      world: owner, system: system,
      resource: Game.worldResourceIdentity(
        "main-station-v1:main-orbital:\(system.galaxy):\(system.system)"))
  }
  static func dock(_ system: SystemIdentity, owner: UUID = ProviderContractFixture.owner)
    -> NativeMainStationDockReceipt
  {
    .init(
      station: station(system), actor: .init(system: system, visit: 1, entity: 1),
      commanderOwner: owner, sequence: 1, calendarSeconds: 0)
  }
  static func state() -> ScriptProviderContractState {
    let provider = NativeProviderIdentity(
      definition: terms.provider, system: origin, incarnation: id(4))
    return .init(
      instance: id(5), terms: terms, owner: owner, provider: provider, subject: id(6),
      expectedManifest: .init(identity: id(7), revision: 1, provider: provider, subject: id(6)),
      origin: station(origin), destination: station(destination),
      item: ScriptProviderContractState.itemID(instance: id(5), payload: terms.payload),
      acceptedOrder: 10)
  }
  static func crew(_ state: ScriptProviderContractState) -> ProviderCrewClaim {
    .init(
      operation: id(8),
      person: .emp(.init(source: .init(system: origin, visit: 1, entity: 20), ordinal: 0)),
      dock: dock(origin), order: 11, disposition: .pending)
  }
  static func core(_ state: ScriptProviderContractState) -> NativeProviderCoreClaim {
    .init(
      operation: id(9), provider: state.provider, subject: state.subject,
      manifest: state.expectedManifest,
      lot: .init(
        section: .init(wreck: .init(system: origin, site: 1, lineage: 2), section: 1), lot: 1),
      settlement: nil, owner: owner, order: 11)
  }
  static func pack() throws -> ScriptPack {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    return try ScriptPackLibrary.read(
      root.appendingPathComponent("Sources/EliteCore/Resources/ScriptPacks/guiding-light"))
  }
}

struct ScriptProviderContractTests {
  @Test(arguments: [ProviderDispatchBranch.full, .urgent, .recovery])
  func eachExclusiveBranchPaysOnceWithAtMostOneCrewBonus(_ branch: ProviderDispatchBranch) throws {
    var state = ProviderContractFixture.state()
    ProviderContractEffects.authorizeManifest(&state)
    state.crew = ProviderContractFixture.crew(state)
    state.receipts.insert(.care)
    if branch == .full {
      state.progress.distanceMeters = 18000
      state.progress.checkpointBits = 7
      state.progress.escortSeconds = 60
    }
    try ProviderContractEffects.choose(branch, state: &state)
    var cash = 0
    try ProviderContractEffects.close(
      &state, delivery: true,
      dock: ProviderContractFixture.dock(ProviderContractFixture.destination), order: 12,
      credits: &cash)
    #expect(cash == state.terms.reward(branch) + 5000 && cash <= 35000 && state.valid)
    let paid = cash
    try ProviderContractEffects.settleCrew(&state, credits: &cash)
    #expect(cash == paid && state.crewPaid == 5000)
  }
  @Test func urgentRequiresManifestAndIsExclusive() throws {
    var state = ProviderContractFixture.state()
    #expect(state.valid)
    #expect(throws: (any Error).self) { try ProviderContractEffects.choose(.urgent, state: &state) }
    ProviderContractEffects.authorizeManifest(&state)
    try ProviderContractEffects.choose(.urgent, state: &state)
    let frozen = state
    try ProviderContractEffects.choose(.urgent, state: &state)
    #expect(state == frozen)
    #expect(throws: (any Error).self) {
      try ProviderContractEffects.choose(.recovery, state: &state)
    }
    #expect(state.valid)
  }

  @Test func fullRequiresDistanceAndTimeAndSurvivesSourceLoss() throws {
    var state = ProviderContractFixture.state()
    ProviderContractEffects.authorizeManifest(&state)
    state.progress.distanceMeters = 18000
    state.progress.checkpointBits = 7
    #expect(throws: (any Error).self) { try ProviderContractEffects.choose(.full, state: &state) }
    state.progress.escortSeconds = 60
    try ProviderContractEffects.choose(.full, state: &state)
    // No live source is needed by the immutable ready branch at the actual handoff boundary.
    var cash = 100
    try ProviderContractEffects.close(
      &state, delivery: true,
      dock: ProviderContractFixture.dock(ProviderContractFixture.destination), order: 12,
      credits: &cash)
    #expect(cash == 30100 && state.basePaid == 30000 && state.valid)
    #expect(throws: (any Error).self) {
      try ProviderContractEffects.close(
        &state, delivery: true,
        dock: ProviderContractFixture.dock(ProviderContractFixture.destination), order: 13,
        credits: &cash)
    }
    #expect(cash == 30100)
  }

  @Test func wrongStationAndOverflowLeaveWholeHandoffUnchanged() throws {
    var state = ProviderContractFixture.state()
    ProviderContractEffects.authorizeManifest(&state)
    try ProviderContractEffects.choose(.urgent, state: &state)
    let before = state
    var cash = 4_294_967_295
    #expect(throws: (any Error).self) {
      try ProviderContractEffects.close(
        &state, delivery: true,
        dock: ProviderContractFixture.dock(ProviderContractFixture.destination), order: 12,
        credits: &cash)
    }
    #expect(state == before && cash == 4_294_967_295)
    cash = 0
    #expect(throws: (any Error).self) {
      try ProviderContractEffects.close(
        &state, delivery: true, dock: ProviderContractFixture.dock(ProviderContractFixture.origin),
        order: 12, credits: &cash)
    }
    #expect(state == before && cash == 0)
  }

  @Test func returnPaysNoBaseAndOnlySettlesActualEarnedCrewClaim() throws {
    var state = ProviderContractFixture.state()
    state.crew = ProviderContractFixture.crew(state)
    state.receipts.insert(.care)
    var cash = 20
    try ProviderContractEffects.close(
      &state, delivery: false, dock: ProviderContractFixture.dock(ProviderContractFixture.origin),
      order: 12, credits: &cash)
    #expect(state.stage == .cancelled && state.custody == .returned)
    #expect(cash == 5020 && state.basePaid == 0 && state.crewPaid == 5000 && state.valid)
  }
}
