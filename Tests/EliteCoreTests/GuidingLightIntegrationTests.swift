import Foundation
import Testing

@testable import EliteCore

struct GuidingLightIntegrationTests {
  @Test(arguments: [ProviderCrewClaimDisposition.paid, .pending, .voided])
  func careTransitionWordingMatchesActualRewardDisposition(
    _ disposition: ProviderCrewClaimDisposition
  ) throws {
    let pack = try ProviderContractFixture.pack()
    let game = Game(executive: false)
    var state = ProviderContractFixture.state()
    state.crew = ProviderContractFixture.crew(state)
    state.receipts.insert(.care)
    ProviderContractEffects.authorizeManifest(&state)
    try ProviderContractEffects.choose(.recovery, state: &state)
    if disposition == .paid {
      var cash = 0
      try ProviderContractEffects.settleCrew(&state, credits: &cash)
    } else if disposition == .voided {
      try ProviderContractEffects.betray(
        .init(
          provider: state.provider, member: state.subject,
          incident: nil, personSale: ProviderContractFixture.id(91), order: 12), state: &state)
    }
    var instance = ScriptInstance(
      id: state.instance, definition: pack.manifest.stateID,
      version: pack.manifest.version, digest: pack.digest)
    instance.savedProviderContract = state
    instance.payloads[state.terms.payload] = 1
    #expect(state.valid(instance: instance))
    var receipts = ["care"]
    if disposition == .paid { receipts.append("crewPaid") }
    if disposition == .voided { receipts += ["betrayed", "manifest", "ready"] }
    let presentation = try ScriptEvaluator.evaluate(
      source: pack.source, handler: "transition",
      event: .object(["receipts": .array(receipts.map(ScriptValue.string))]),
      snapshot: game.scopedScriptSnapshot(instance), state: .object([:]))
    let texts = presentation.commands.compactMap { $0["text"]?.string }
    #expect(texts.count == 1)
    #expect(presentation.commands.allSatisfy { $0["op"]?.string == "journal.append" })
    if disposition == .paid {
      #expect(
        texts.first?.contains("500-credit") == true && texts.first?.contains("transferred") == true)
    } else if disposition == .pending {
      #expect(texts.first?.contains("pending payment") == true)
      #expect(texts.allSatisfy { !$0.contains("transferred") })
    } else {
      #expect(
        texts.allSatisfy {
          !$0.contains("500") && !$0.contains("unlawful attack") && !$0.contains("authenticated")
        })
      #expect(texts.first?.contains("All unpaid rewards are void") == true)
    }
  }
  @Test func unsupportedCapabilityKeepsWholeOfferLockedWithoutRegistryBypass() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    let source = root.appendingPathComponent(
      "Sources/EliteCore/Resources/ScriptPacks/guiding-light")
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "provider-unsupported-" + UUID().uuidString)
    try FileManager.default.copyItem(at: source, to: directory)
    defer { try? FileManager.default.removeItem(at: directory) }
    let manifest = directory.appendingPathComponent("manifest.toml")
    let text = try String(contentsOf: manifest, encoding: .utf8)
      .replacingOccurrences(
        of: "capabilities = [", with: "capabilities = [\"provider-test-unsupported-v1\", ")
    try text.write(to: manifest, atomically: true, encoding: .utf8)
    let pack = try ScriptPackLibrary.read(directory)
    #expect(pack.missingCapabilities.contains("provider-test-unsupported-v1"))
    var game = Game(executive: false)
    game.scriptPacks = [pack]
    game.scriptDurabilityAvailable = true
    let before = game.commander
    #expect(game.scriptUnavailable(pack) != nil)
    #expect(game.providerGalleryEntry(pack, state: nil).status == .locked)
    #expect(throws: (any Error).self) { try game.acceptScriptMission(pack) }
    #expect(game.commander == before && game.commander.scriptState.instances.isEmpty)
  }
  @Test func completePackDeclaresEveryBranchWithoutScriptedActorsOrTrial() throws {
    let pack = try ProviderContractFixture.pack()
    let terms = try #require(pack.manifest.providerContract)
    #expect(pack.manifest.stateID == "project.crimbo/guiding-light" && terms.valid)
    #expect(terms.observation.checkpoints == [6000, 12000, 18000])
    #expect(terms.observation.escortSeconds == 60 && terms.observation.contactSeconds == 5)
    #expect(
      [terms.fullReward, terms.urgentReward, terms.recoveryReward, terms.crewReward] == [
        30000, 15000, 20000, 5000,
      ])
    #expect(pack.manifest.mission.milestones.count == 1)
    #expect(
      pack.manifest.encounters == nil && pack.manifest.npcs == nil && pack.manifest.trial == nil)
    #expect(pack.manifest.dialogs?.count == 19)
  }
  @Test func genericAcceptanceAndUnavailableNativeOfferCannotIssueRelay() throws {
    let pack = try ProviderContractFixture.pack()
    var game = Game(executive: false)
    game.scriptPacks = [pack]
    game.scriptDurabilityAvailable = true
    let before = game.commander
    #expect(throws: (any Error).self) { try game.acceptScriptMission(pack) }
    #expect(game.commander == before)
    let entry = game.providerGalleryEntry(pack, state: nil)
    #expect(entry.status == .locked && entry.trialDigest == nil && entry.completed == 0)
  }
  @Test func presentationIsNeverAcceptanceAuthorityAndStaleIntentIsRefused() throws {
    let pack = try ProviderContractFixture.pack()
    var game = Game(executive: false)
    game.scriptPacks = [pack]
    game.scriptDurabilityAvailable = true
    let state = ProviderContractFixture.state()
    try game.presentProviderMission(
      .init(
        definition: pack.manifest.stateID, available: true,
        reason: nil, provider: state.provider, subject: state.subject,
        status: "Native bridge reports ready"))
    let before = game.commander
    #expect(throws: (any Error).self) { try game.acceptScriptMission(pack) }
    #expect(game.commander == before)
    let proof = game.scriptGalleryPageIdentity
    let intent = ProviderMissionIntent(
      presentationEpoch: game.ecmControl.epoch, digest: pack.digest, instance: state.instance,
      request: .action(.confirmUrgent), reviewToken: ProviderContractFixture.id(80),
      page: .gallery(proof))
    game.gallery.providerIntent = intent
    game.gallery.presentationGeneration = UUID()
    #expect(!game.acceptsProviderIntent(intent))
  }
  @Test func alternativeMilestonesStayOptionalAndTerminalNativePresentationPaysNothing() throws {
    let pack = try ProviderContractFixture.pack()
    var game = Game(executive: false)
    game.scriptPacks = [pack]
    var state = ProviderContractFixture.state()
    ProviderContractEffects.authorizeManifest(&state)
    try ProviderContractEffects.choose(.urgent, state: &state)
    var instance = ScriptInstance(
      id: state.instance, definition: pack.manifest.stateID, version: pack.manifest.version,
      digest: pack.digest)
    instance.savedProviderContract = state
    instance.payloads[state.terms.payload] = 1
    let entry = game.providerGalleryEntry(pack, state: instance)
    #expect(
      entry.milestones.filter { $0.title.contains("calibration") }.allSatisfy {
        $0.state == "Optional"
      })
    #expect(
      entry.milestones.filter { $0.title.contains("computer") || $0.title.contains("crew") }
        .allSatisfy { $0.state == "Optional" })
    var cash = 0
    try ProviderContractEffects.close(
      &state, delivery: true,
      dock: ProviderContractFixture.dock(ProviderContractFixture.destination), order: 12,
      credits: &cash)
    instance.savedProviderContract = state
    instance.payloads.removeValue(forKey: state.terms.payload)
    let presentation = try ScriptEvaluator.evaluate(
      source: pack.source, handler: "closed",
      event: .object([:]), snapshot: game.scopedScriptSnapshot(instance), state: .object([:]))
    #expect(presentation.commands.count == 1)
    #expect(presentation.commands.allSatisfy { $0["op"]?.string == "journal.append" })
  }
}
