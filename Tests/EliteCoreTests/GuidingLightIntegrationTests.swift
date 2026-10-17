import Foundation
import Testing

@testable import EliteCore

struct GuidingLightIntegrationTests {
  /// Pure native-consumer/presentation boundary; it does not authenticate an ordinary provider.
  private func guidanceTexts(
    _ state: ScriptProviderContractState, since before: ScriptProviderContractState,
    pack: ScriptPack, game: Game
  ) throws -> [String] {
    var instance = ScriptInstance(
      id: state.instance, definition: pack.manifest.stateID,
      version: pack.manifest.version, digest: pack.digest)
    instance.savedProviderContract = state
    instance.payloads[state.terms.payload] = state.custody == .aboard ? 1 : nil
    let result = try ScriptEvaluator.evaluate(
      source: pack.source, handler: "transition",
      event: .object(state.transitionValues(since: before)),
      snapshot: game.scopedScriptSnapshot(instance), state: .object([:]))
    #expect(result.commands.allSatisfy { $0["op"]?.string == "journal.append" })
    return result.commands.compactMap { $0["text"]?.string }
  }

  @Test(arguments: [NativeProviderAvailability.disabled, .destroyed, .uncrewed, .ended])
  func firstNativeCrisisPublishesGuidanceButRepeatedObservationReopenAndReloadDoNot(
    _ availability: NativeProviderAvailability
  ) throws {
    let pack = try ProviderContractFixture.pack()
    var game = Game(executive: false)
    var state = ProviderContractFixture.state()
    let before = state
    ProviderMissionGuidance.observe(
      availability, interval: nil, destinationContactAvailable: nil,
      destinationDocked: false, state: &state)
    #expect(state.stage == .crisis && state.valid && state.hasFiniteTransition(since: before))
    let texts = try guidanceTexts(state, since: before, pack: pack, game: game)
    #expect(texts.count == 1)
    let text = try #require(texts.first)
    if availability == .disabled {
      #expect(text.contains("drive is offline") && !text.contains("lost Santa's ship"))
    } else if availability == .destroyed {
      #expect(text.contains("lost Santa's ship") && !text.contains("drive is offline"))
      #expect(text.contains("authenticated manifest still permits urgent"))
    } else {
      #expect(text.contains("cannot authorize radio contact"))
      #expect(!text.contains("drive is offline") && !text.contains("lost Santa's ship"))
    }
    let first = state
    ProviderMissionGuidance.observe(
      availability, interval: nil, destinationContactAvailable: nil,
      destinationDocked: false, state: &state)
    #expect(!state.hasFiniteTransition(since: first))
    #expect(try guidanceTexts(state, since: first, pack: pack, game: game).isEmpty)
    var instance = ScriptInstance(
      id: state.instance, definition: pack.manifest.stateID,
      version: pack.manifest.version, digest: pack.digest)
    instance.savedProviderContract = state
    instance.payloads[state.terms.payload] = 1
    game.scriptPacks = [pack]
    game.commander.scriptState.instances[instance.id] = instance
    game.screen = .status
    game.gallery.selection = try #require(
      game.missionCatalogue.firstIndex { $0.savedInstance == instance.id })
    game.gallery.detail = true
    let commander = game.commander
    let speech = game.ecmControl.events
    for _ in 0..<3 {
      game.openGallery()
      game.closeGallery()
    }
    #expect(game.commander == commander && game.ecmControl.events == speech)
    state = try JSONDecoder().decode(
      ScriptProviderContractState.self, from: JSONEncoder().encode(first))
    ProviderMissionGuidance.observe(
      availability, interval: nil, destinationContactAvailable: nil,
      destinationDocked: false, state: &state)
    #expect(
      state.presentationBits == first.presentationBits && !state.hasFiniteTransition(since: first))
    #expect(try guidanceTexts(state, since: first, pack: pack, game: game).isEmpty)
  }

  @Test func manifestGreetingRequiresRequestAndActualContactAndDoesNotRepeatAfterReload() throws {
    let pack = try ProviderContractFixture.pack()
    let game = Game(executive: false)
    var state = ProviderContractFixture.state()
    let interval = ProviderMissionInterval(
      provider: state.provider, subject: state.subject,
      sceneGeneration: ProviderContractFixture.scene, startFrame: 1, endFrame: 2,
      startTime: 0.1, endTime: 0.2, forwardMeters: 0, rangeMeters: 4000,
      relativeMetersPerSecond: 50, actualSensorContact: true, communications: true,
      unpausedFreeFlight: true, trackingThroughout: true, continuous: true)
    let unrequested = state
    ProviderMissionGuidance.observe(
      .tracking, interval: interval, destinationContactAvailable: nil,
      destinationDocked: false, state: &state)
    #expect(!state.hasFiniteTransition(since: unrequested))
    state.progress.requested = true
    let requested = state
    ProviderMissionGuidance.observe(
      .tracking, interval: nil, destinationContactAvailable: nil,
      destinationDocked: false, state: &state)
    #expect(!state.hasFiniteTransition(since: requested))
    ProviderMissionGuidance.observe(
      .tracking, interval: interval, destinationContactAvailable: nil,
      destinationDocked: false, state: &state)
    #expect(state.newCues(since: requested) == [.hello])
    #expect(state.manifest == nil && state.progress.handshakeSeconds == 0)
    let texts = try guidanceTexts(state, since: requested, pack: pack, game: game)
    #expect(texts.count == 1 && texts[0].contains("Hold within five kilometres"))
    let first = state
    state = try JSONDecoder().decode(
      ScriptProviderContractState.self, from: JSONEncoder().encode(first))
    ProviderMissionGuidance.observe(
      .tracking, interval: interval, destinationContactAvailable: nil,
      destinationDocked: false, state: &state)
    #expect(!state.hasFiniteTransition(since: first))
    #expect(try guidanceTexts(state, since: first, pack: pack, game: game).isEmpty)
  }

  @Test func recoveredTemporarySourceDoesNotRepeatGuidanceAndReadyDispatchSurvivesLoss() throws {
    var state = ProviderContractFixture.state()
    ProviderMissionGuidance.observe(
      .disabled, interval: nil, destinationContactAvailable: nil,
      destinationDocked: false, state: &state)
    let first = state
    for _ in 0..<20 {
      ProviderMissionGuidance.observe(
        .tracking, interval: nil, destinationContactAvailable: nil,
        destinationDocked: false, state: &state)
      ProviderMissionGuidance.observe(
        .disabled, interval: nil, destinationContactAvailable: nil,
        destinationDocked: false, state: &state)
    }
    #expect(!state.hasFiniteTransition(since: first))
    ProviderContractEffects.authorizeManifest(&state)
    state.progress.distanceMeters = 18000
    state.progress.checkpointBits = 7
    state.progress.escortSeconds = 60
    try ProviderContractEffects.choose(.full, state: &state)
    let ready = state
    ProviderMissionGuidance.observe(
      .destroyed, interval: nil, destinationContactAvailable: nil,
      destinationDocked: false, state: &state)
    #expect(state == ready && state.branch == .full && state.valid)
  }

  @Test func urgentReviewGuidanceIsFiniteAcrossBackRearmAndReload() throws {
    let pack = try ProviderContractFixture.pack()
    let game = Game(executive: false)
    var state = ProviderContractFixture.state()
    ProviderContractEffects.authorizeManifest(&state)
    let before = state
    try ProviderMissionGuidance.reviewUrgent(&state, runtimeEpoch: game.nativeStationRuntimeEpoch)
    #expect(state.newCues(since: before) == [.urgentChoice] && state.branch == nil)
    let texts = try guidanceTexts(state, since: before, pack: pack, game: game)
    #expect(texts.count == 1 && texts[0].contains("1,500 credits"))
    let first = state
    for _ in 0..<20 {
      state.pending = nil
      try ProviderMissionGuidance.reviewUrgent(&state, runtimeEpoch: game.nativeStationRuntimeEpoch)
    }
    #expect(state.receipts == first.receipts && !state.hasFiniteTransition(since: first))
    #expect(try guidanceTexts(state, since: first, pack: pack, game: game).isEmpty)
    state = try JSONDecoder().decode(
      ScriptProviderContractState.self, from: JSONEncoder().encode(state))
    try ProviderMissionGuidance.reviewUrgent(&state, runtimeEpoch: UUID())
    #expect(!state.hasFiniteTransition(since: first) && state.branch == nil)
  }

  @Test func unavailableDestinationCueRequiresResolvedFailureAndGenuineDockProjectionAndIsFinite()
    throws
  {
    let pack = try ProviderContractFixture.pack()
    let game = Game(executive: false)
    var state = ProviderContractFixture.state()
    ProviderContractEffects.authorizeManifest(&state)
    try ProviderContractEffects.choose(.urgent, state: &state)
    let before = state
    #expect(throws: (any Error).self) {
      try ProviderMissionGuidance.deliveryContactIsAvailable(nil, state: &state)
    }
    #expect(state == before)
    #expect(try ProviderMissionGuidance.deliveryContactIsAvailable(true, state: &state))
    #expect(state == before)
    ProviderMissionGuidance.observe(
      .unloaded, interval: nil, destinationContactAvailable: false,
      destinationDocked: false, state: &state)
    ProviderMissionGuidance.observe(
      .unloaded, interval: nil, destinationContactAvailable: nil,
      destinationDocked: true, state: &state)
    #expect(!state.hasFiniteTransition(since: before))
    ProviderMissionGuidance.observe(
      .unloaded, interval: nil, destinationContactAvailable: false,
      destinationDocked: true, state: &state)
    #expect(state.newCues(since: before) == [.unavailable])
    #expect(state.custody == .aboard && state.basePaid == 0 && state.branch == .urgent)
    var explicitFailure = before
    #expect(
      try ProviderMissionGuidance.deliveryContactIsAvailable(false, state: &explicitFailure)
        == false)
    #expect(explicitFailure == state && explicitFailure.hasFiniteTransition(since: before))
    let texts = try guidanceTexts(state, since: before, pack: pack, game: game)
    #expect(texts.count == 1 && texts[0].contains("dispatch contact is unavailable"))
    let first = state
    #expect(try ProviderMissionGuidance.deliveryContactIsAvailable(false, state: &state) == false)
    #expect(state == first)
    state = try JSONDecoder().decode(
      ScriptProviderContractState.self, from: JSONEncoder().encode(first))
    for _ in 0..<20 {
      ProviderMissionGuidance.observe(
        .unloaded, interval: nil, destinationContactAvailable: false,
        destinationDocked: true, state: &state)
    }
    #expect(!state.hasFiniteTransition(since: first))
    #expect(try guidanceTexts(state, since: first, pack: pack, game: game).isEmpty)
  }
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
