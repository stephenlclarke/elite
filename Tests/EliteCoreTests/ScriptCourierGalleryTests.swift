import AppKit
import Foundation
import Testing

@testable import EliteCore
@testable import EliteMac

@Test func courierGalleryTrialReviewSaveLoadRestartReturnPreservesLiveCommander() async throws {
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  var game = fixture.game()
  game.commander.name = "LIVE"
  game.commander.cargo[0] = 3
  game.commander.credits = 32100
  game.openGallery()
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  let live = await runtime.snapshot()
  let pointer = try Data(contentsOf: fixture.save)
  try await runtime.startScriptGalleryTrial(packDigest: fixture.pack.digest, seed: 42)
  let namespace = try #require(await runtime.gallerySaveDirectory())
  defer { try? FileManager.default.removeItem(at: namespace) }
  let trial = await runtime.snapshot()
  #expect(trial.isMissionTrial && trial.commander.scriptState.instances.isEmpty)
  #expect(
    trial.screen == .contracts && trial.contractBoard.detail && trial.contractBoard.action == .back)
  #expect(trial.contractBoard.rows.count == 6 && trial.commander.cargoTonnes == 0)
  let terms = trial.commander.contracts
  _ = try await runtime.saveForInterface()
  _ = try await runtime.loadForInterface()
  #expect(await runtime.snapshot().commander.contracts == terms)
  try await runtime.restartScriptGalleryTrial()
  let restarted = await runtime.snapshot()
  #expect(
    restarted.commander.contracts == terms && restarted.commander.scriptState.instances.isEmpty)
  #expect(restarted.contractBoard.action == .back)
  try await runtime.returnFromScriptGalleryTrial()
  let restored = await runtime.snapshot()
  #expect(restored.commander == live.commander && !restored.isMissionTrial)
  #expect(try Data(contentsOf: fixture.save) == pointer)
}

@Test(arguments: [ScriptCourierVariant.data, .package])
func courierContactRendererUsesTypedActionsAndKeepsCompactWideBounds(variant: ScriptCourierVariant)
  throws
{
  let fixture = try CourierFixture()
  defer { fixture.clean() }
  let pinned = CourierNativeFixture.rows[variant == .data ? 0 : 1]
  var game = try pinned.game(using: fixture)
  let (key, offer) = try fixture.usable(&game, row: pinned.row)
  try pinned.verify(try #require(game.commander.contracts.boards[key]), offer)
  let terms = try #require(offer.courier)
  try #require(terms.variant == variant && terms.calendarLowerBoundSeconds < terms.duration)
  let id = try game.confirmContract(game.contractAcceptanceQuote(board: key, offer: offer.id))
  try fixture.requestContact(&game, id: id)
  for (width, height) in [(512.0, 518.0), (1512.0, 982.0)] {
    let frame = Display.blackjackHandoff(game, width: width, height: height)
    #expect(frame.labels.contains { $0.text.contains("Abandon") })
    #expect(frame.labels.contains { $0.text.contains("> Back") })
    #expect(
      frame.labels.allSatisfy {
        $0.x.isFinite && $0.y.isFinite && $0.x >= 0 && $0.y >= 0 && $0.y < height
      })
    #expect(game.packDialogLines(width: width).joined(separator: " ").contains("Consignment"))
  }
  game.key("escape")
  try fixture.travel(&game, id: id)
  try fixture.requestContact(&game, id: id)
  #expect(game.courierContactActionLabel == "Deliver")
  game.scriptPresentedDialogue?.token = "stale"
  #expect(game.courierContactActionLabel == nil && game.courierContactDetails.isEmpty)
  game.scriptPresentedDialogue = game.commander.scriptState.instances[id]?.dialogue
  game.scriptPacks = []
  #expect(game.courierContactActionLabel == nil)
  let fallback = Display.blackjackHandoff(game, width: 512, height: 518)
  #expect(fallback.labels.contains { $0.text.contains("Confirm / Continue") })
}

@MainActor private final class CourierInputHarness {
  let fixture: CourierFixture
  let delegate: AppDelegate
  let preferences: UserDefaults
  var view: GameView
  var window: NSWindow?
  let originalMenu: NSMenu?
  init(origin: Int = 7, physicalDocking: Bool = false) async throws {
    fixture = try CourierFixture()
    preferences = try #require(UserDefaults(suiteName: fixture.root.lastPathComponent))
    delegate = AppDelegate(
      restoreOnLaunch: false,
      saves: CommanderSaveSession(preferences: preferences, defaultURL: fixture.save),
      windowSize: .init(width: 512, height: 518))
    view = GameView(frame: NSRect(x: 0, y: 0, width: 512, height: 518))
    originalMenu = NSApp?.mainMenu
    var initial = fixture.game(system: origin)
    initial.commander.shipID = "SH023"
    initial.commander.fuel = initial.commander.fuelCapacity
    initial.energy = initial.commander.performance.energy
    initial.frontShield = initial.commander.shieldCapacity
    initial.rearShield = initial.commander.rearShieldCapacity
    if physicalDocking { initial.commander.installTargetingComputer(.docking) }
    initial.ensureScriptCalendar(origin: .newCommander)
    initial.viewportWidth = 512
    initial.viewportHeight = 518
    let scene = initial
    await delegate.runtime.nativeCommand { @Sendable game in game = scene }
    try await delegate.runtime.save(to: fixture.save)
  }
  func paint() async throws {
    view.game = await delegate.runtime.snapshot()
    try paintCampaignGalleryView(view)
  }
  func press(_ key: String) throws {
    let codes: [String: UInt16] = [
      "return": 36, "escape": 53, "left": 123, "right": 124,
      "up": 126, "down": 125, "pagedown": 121, "t": 17,
    ]
    let code = try #require(codes[key])
    let text = key == "return" ? "\r" : key == "escape" ? "\u{1b}" : key.count == 1 ? key : ""
    let event = try #require(
      NSEvent.keyEvent(
        with: .keyDown, location: .zero,
        modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: text,
        charactersIgnoringModifiers: text, isARepeat: false, keyCode: code))
    view.keyDown(with: event)
  }
  func drain() async { await delegate.processPendingCommands(in: view) }
  func review(row: Int) async throws {
    await delegate.runtime.key("contracts-open")
    let board = await delegate.runtime.snapshot()
    let index = try #require(board.contractBoard.rows.firstIndex { $0.offer?.courier?.row == row })
    // A newly opened board may retain its selection; navigate relative to the actual row.
    let difference = index - board.contractBoard.selection
    for _ in 0..<abs(difference) { await delegate.runtime.key(difference < 0 ? "up" : "down") }
    await delegate.runtime.key("return")
  }
  func launchMenus() async throws {
    _ = NSApplication.shared
    let before = await delegate.runtime.snapshot()
    delegate.applicationDidFinishLaunching(
      Notification(name: NSApplication.didFinishLaunchingNotification))
    let loop = try #require(delegate.loop)
    loop.cancel()
    await loop.value
    window = delegate.window
    view = try #require(window?.contentView as? GameView)
    await delegate.runtime.nativeCommand { @Sendable game in game = before }
  }
  func menu(_ command: String) throws {
    let menu = try #require(NSApp.mainMenu?.item(withTitle: "Game")?.submenu)
    let index = try #require(menu.items.firstIndex { ($0.representedObject as? String) == command })
    let target = try #require(menu.items[index].target as? NativeMissionMenu)
    #expect(target.validateMenuItem(menu.items[index]))
    menu.performActionForItem(at: index)
  }
  func clean() {
    delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification))
    window?.orderOut(nil)
    if let originalMenu { NSApp.mainMenu = originalMenu }
    preferences.removePersistentDomain(forName: fixture.root.lastPathComponent)
    fixture.clean()
  }
}

@MainActor private func captureCourierView(_ game: Game, name: String) throws {
  for (width, height, scale) in [(512, 518, 1), (1512, 982, 2)] {
    var shown = game
    shown.viewportWidth = Double(width)
    shown.viewportHeight = Double(height)
    let frame = Display.presentation(shown, width: Double(width), height: Double(height))
    #expect(
      frame.labels.allSatisfy {
        $0.bounds.x >= 0 && $0.bounds.maxX <= Double(width)
          && $0.bounds.y >= 0 && $0.bounds.maxY <= Double(height)
      })
    let image = try #require(imageForGame(shown, width: width, height: height, scale: scale))
    #expect(image.width == width * scale && image.height == height * scale)
    if let path = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"] {
      let root = URL(fileURLWithPath: path)
      try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
      let bytes = try #require(
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
      try bytes.write(to: root.appendingPathComponent("courier-\(name)-\(width).png"))
    }
  }
}

private struct CourierApproachVoiceEvidence: Encodable {
  let id: Int
  let text: String
}

private struct CourierApproachShotEvidence: Encodable {
  let id: Int
  let actor: ActorIdentity?
  let hull: String
  let position: Vector3
  let origin: String
}

/// Primitive observations from existing consecutive snapshots; no simulation or extra actor read.
private struct CourierApproachFrameEvidence: Encodable {
  let time: Double
  let physicalTime: Double
  let energy: Double
  let frontShield: Double
  let rearShield: Double
  let cabinTemperature: Double
  let pose: ShipPose
  let speed: Double
  let velocity: Vector3
  let autopilotStatus: String
  let targetDistance: Double?
  let gameplayRevision: UInt64
  let stationImpactRevision: UInt64?
  let message: String
  let voiceEpoch: UUID
  let voices: [CourierApproachVoiceEvidence]
  let ecmRemainingDuration: Double
  let nearbyShots: [CourierApproachShotEvidence]

  init(_ state: borrowing Game) {
    time = state.time
    physicalTime = state.commander.flightSimulation.physicalTime
    energy = state.energy
    frontShield = state.frontShield
    rearShield = state.rearShield
    cabinTemperature = state.cabinTemperature
    pose = state.commander.flightSimulation.pose
    speed = state.speed
    velocity = state.flightWorldVelocity
    autopilotStatus = state.autoPilot.status
    targetDistance = state.autoTargetBody?.position.length
    gameplayRevision = state.gameplayRevision
    stationImpactRevision = state.stationImpactRevision
    message = state.message
    voiceEpoch = state.ecmControl.epoch
    voices = state.ecmControl.events.map { .init(id: $0.id, text: $0.announcement.text) }
    ecmRemainingDuration = state.ecmControl.remainingDuration
    var shots: [CourierApproachShotEvidence] = []
    for body in state.bodies {
      if body.hull == .missile || body.scriptShot != nil || body.physical?.ordnance != nil {
        shots.append(
          .init(
            id: body.id, actor: body.physical?.identity,
            hull: String(describing: body.hull), position: body.position,
            origin: String(describing: body.physical?.attackOrigin)))
      }
    }
    nearbyShots = Array(shots.sorted { $0.position.length < $1.position.length }.prefix(16))
  }
}

private struct CourierApproachDamageEvidence: Encodable {
  let frame: Int
  let before: CourierApproachFrameEvidence
  let after: CourierApproachFrameEvidence
}

/// Failure-only observer; these bytes are diagnostics, never a commander save or a restore source.
private struct CourierApproachFailureEvidence: Encodable {
  let source: String?
  let row: Int
  let launchFrames: Int
  let jumpFrames: Int
  let selections: Int
  let approachFrames: Int
  let collisionObserved: Bool
  let lastDamageTransitions: [CourierApproachDamageEvidence]
  let commander: Commander
  let world: ScriptWorldSave
  let message: String
  let messageTime: Double
  let autopilotStatus: String
  let autopilotTargetID: Int?
  let autopilotVelocity: Vector3
  let target: SpaceBody?
  let dockingComputer: Bool
  let playerVelocity: Vector3
  let paused: Bool
}

private func captureCourierApproachFailure(
  _ state: borrowing Game, row: Int, launchFrames: Int, jumpFrames: Int,
  selections: Int, approachFrames: Int, collision: Bool,
  damageTransitions: [CourierApproachDamageEvidence]
) throws {
  let evidence = CourierApproachFailureEvidence(
    source: ProcessInfo.processInfo.environment["ELITE_VALIDATION_SOURCE_SHA"],
    row: row, launchFrames: launchFrames, jumpFrames: jumpFrames, selections: selections,
    approachFrames: approachFrames, collisionObserved: collision,
    lastDamageTransitions: damageTransitions, commander: state.commander,
    world: state.scriptWorldSave,
    message: state.message, messageTime: state.messageTime,
    autopilotStatus: state.autoPilot.status, autopilotTargetID: state.autoPilot.targetID,
    autopilotVelocity: state.autoPilot.velocity, target: state.autoTargetBody,
    dockingComputer: state.dockingComputer, playerVelocity: state.flightWorldVelocity,
    paused: state.paused)
  print(
    "Courier physical arrival failed: row=\(row), frames=\(approachFrames), "
      + "collisionObserved=\(collision), energy=\(state.energy), "
      + "frontShield=\(state.frontShield), rearShield=\(state.rearShield), "
      + "physicalTime=\(state.commander.flightSimulation.physicalTime), "
      + "targetDistance=\(String(describing: state.autoTargetBody?.position.length)), "
      + "autopilot=\(state.autoPilot.status), message=\(state.message)")
  guard let path = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"] else {
    return
  }
  let root = URL(fileURLWithPath: path)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  let bytes = try encoder.encode(evidence)
  try bytes.write(
    to: root.appendingPathComponent("courier-row-\(row)-failed-physical-approach.json"),
    options: .withoutOverwriting)
}

// These two pinned one-hop cases retain the real launch/arrival traffic, station pose and
// celestials. Only public flight controls and actor frames can reach the receiving station.
@MainActor private func physicallyDeliverCourier(
  _ harness: CourierInputHarness, id: UUID, row: Int
) async throws {
  let runtime = harness.delegate.runtime
  let accepted = await runtime.snapshot()
  let job = try #require(accepted.commander.scriptState.instances[id]?.contract)
  let terms = try #require(job.offer.courier)
  try #require(terms.path.count == 2 && accepted.commander.hasAutomaticDocking)
  await runtime.key("escape")
  await runtime.key("0")
  var state = await runtime.snapshot()
  try #require(!state.docked && state.screen.isFlight)
  var launchFrames = 0
  while state.massLocked, launchFrames < 2000 {
    _ = await runtime.advance(delta: 0.05)
    state = await runtime.snapshot()
    launchFrames += 1
  }
  try #require(!state.massLocked && state.screen != .gameOver)
  let destination = try #require(state.knownSystems.first { $0.id == terms.destination })
  await runtime.selectSystem(x: destination.x, y: destination.y)
  try #require(await runtime.snapshot().selectedSystem == terms.destination)
  await runtime.key("h")
  state = await runtime.snapshot()
  try #require(
    state.commander.scriptState.calendarLedger?.pendingJourney?.destination == terms.destination)
  var jumpFrames = 0
  while state.jumpCountdown != nil, jumpFrames < 10000 {
    _ = await runtime.advance(delta: 0.1)
    state = await runtime.snapshot()
    jumpFrames += 1
  }
  try #require(jumpFrames > 0 && jumpFrames < 10000 && state.commander.system == terms.destination)
  try #require(!state.docked && state.bodies.contains { $0.id == 0 && $0.hull == .station })
  var selections = 0
  while state.autoTargetBody?.id != 0, selections < 32 {
    await runtime.key("tab")
    state = await runtime.snapshot()
    selections += 1
  }
  try #require(state.autoTargetBody?.hull == .station && state.dockingComputer)
  try captureCourierView(state, name: "row-\(row)-physical-approach")
  var approachFrames = 0
  var collision = false
  var damageTransitions: [CourierApproachDamageEvidence] = []
  while !state.docked && state.screen != .gameOver, approachFrames < 20000 {
    let beforeFrame = CourierApproachFrameEvidence(state)
    _ = await runtime.advance(delta: 0.05)
    state = await runtime.snapshot()
    let afterFrame = CourierApproachFrameEvidence(state)
    collision = collision || state.message == "DOCKING COLLISION"
    approachFrames += 1
    if afterFrame.energy < beforeFrame.energy
      || afterFrame.frontShield < beforeFrame.frontShield
      || afterFrame.rearShield < beforeFrame.rearShield
      || afterFrame.stationImpactRevision != beforeFrame.stationImpactRevision
    {
      damageTransitions.append(.init(frame: approachFrames, before: beforeFrame, after: afterFrame))
      if damageTransitions.count > 32 {
        damageTransitions.removeFirst(damageTransitions.count - 32)
      }
    }
  }
  if !state.docked || state.screen != .status {
    do {
      try captureCourierApproachFailure(
        state, row: row, launchFrames: launchFrames, jumpFrames: jumpFrames,
        selections: selections, approachFrames: approachFrames, collision: collision,
        damageTransitions: damageTransitions)
    } catch {
      print("Courier physical arrival diagnostic capture failed: \(error)")
    }
  }
  try #require(
    state.docked && state.screen == .status,
    "Physical arrival: \(state.autoPilot.status), frames \(approachFrames), \(state.message)")
  #expect(!collision && approachFrames > 100)
  #expect(state.commander.system == terms.destination)
  #expect(
    state.commander.scriptState.clock(.missionCalendar) - job.acceptedAt
      > terms.calendarLowerBoundSeconds)
  #expect(state.commander.scriptState.instances[id]?.courier?.terminal == nil)
}

extension NativeViewTests {
  @MainActor @Test func nativeCourierAllSixPaintedAcceptTravelAndDeliverOnce() async throws {
    for row in 0..<6 {
      let pinned =
        row == 0 ? CourierNativeFixture.paintedRow0OneHop : CourierNativeFixture.rows[row]
      let harness = try await CourierInputHarness(origin: pinned.origin, physicalDocking: row < 2)
      defer { harness.clean() }
      try await harness.review(row: row)
      try await harness.paint()
      let quote = try #require(harness.view.game.contractBoard.quote)
      let offer = try #require(harness.view.game.contractBoard.selected?.offer)
      let board = try #require(harness.view.game.commander.contracts.boards[quote.board])
      try pinned.verify(board, offer)
      #expect(quote.allowed && harness.view.game.contractBoard.action == .back)
      let prose = Display.contractDetailRows(harness.view.game, width: 512).joined(separator: " ")
      #expect(prose.contains("PROJECT ESTIMATES") && prose.contains("Courier Receiving Officer"))
      #expect(!prose.contains("decicredits") && !prose.contains(harness.fixture.pack.manifest.id))
      try captureCourierView(harness.view.game, name: "row-\(row)-review")
      let before = harness.view.game.commander
      try harness.press("return")
      await harness.drain()
      #expect(await harness.delegate.runtime.snapshot().commander == before)
      try await harness.review(row: row)
      try await harness.paint()
      if row % 2 == 0 {
        try harness.press("right")
        try harness.press("return")
        try harness.press("return")
      } else {
        let bounds = try #require(
          ContractBoardLayout(width: 512, height: 518).actions.first { $0.0 == .accept }?.1)
        try clickPledgeView(harness.view, x: bounds.x + 8, y: bounds.y + 8)
        try clickPledgeView(harness.view, x: bounds.x + 8, y: bounds.y + 8)
      }
      await harness.drain()
      let id = Game.contractJobIdentity(offer.id)
      let accepted = await harness.delegate.runtime.snapshot()
      #expect(accepted.commander.scriptState.instances.count == 1)
      #expect(accepted.commander.scriptState.instances[id]?.courier?.terminal == nil)
      #expect(accepted.commander.cargoTonnes == offer.courier?.variant.tonnes)
      if row < 2 {
        try await physicallyDeliverCourier(harness, id: id, row: row)
      } else {
        try await harness.fixture.travel(harness.delegate.runtime, id: id)
      }
      await harness.delegate.runtime.key("contacts-open")
      try await harness.paint()
      #expect(
        !harness.view.game.scriptConfirmSelected
          && harness.view.game.courierContactActionLabel == "Deliver")
      try captureCourierView(harness.view.game, name: "row-\(row)-receiving-contact")
      let cash = harness.view.game.commander.credits
      if row % 2 == 0 {
        try harness.press("left")
        try harness.press("return")
        try harness.press("return")
      } else {
        try clickPledgeView(harness.view, x: 40, y: 478)
        try clickPledgeView(harness.view, x: 40, y: 478)
      }
      await harness.drain()
      let delivered = await harness.delegate.runtime.snapshot()
      #expect(
        delivered.commander.credits == cash + offer.reward && delivered.commander.cargoTonnes == 0)
      #expect(delivered.commander.scriptState.instances[id]?.courier?.terminal?.cause == .delivered)
      try await harness.delegate.runtime.load(from: harness.fixture.save)
      #expect(await harness.delegate.runtime.snapshot().commander == delivered.commander)
      await harness.delegate.runtime.key("gallery-open")
      let gallery = await harness.delegate.runtime.snapshot()
      let selected = try #require(gallery.missionCatalogue.firstIndex { $0.savedInstance == id })
      await harness.delegate.runtime.nativeCommand { @Sendable game in
        game.gallery.selection = selected
        game.gallery.detail = true
        game.pinGallerySelection()
      }
      try await harness.paint()
      #expect(harness.view.game.selectedGalleryMission?.briefing.contains("Paid:") == true)
      try captureCourierView(harness.view.game, name: "row-\(row)-delivered")
    }
  }

  @MainActor @Test func nativeCourierStalePaintResourceAndViewportCannotAccept() async throws {
    let harness = try await CourierInputHarness()
    defer { harness.clean() }
    try await harness.review(row: 0)
    try await harness.paint()
    let before = harness.view.game.commander
    await harness.delegate.runtime.nativeCommand { @Sendable game in game.commander.fuel -= 1 }
    harness.view.game = await harness.delegate.runtime.snapshot()
    try harness.press("right")
    try harness.press("return")
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().commander.scriptState.instances.isEmpty)
    #expect(await harness.delegate.runtime.snapshot().commander.credits == before.credits)
    await harness.delegate.runtime.nativeCommand { @Sendable game in game.commander.fuel += 1 }
    try await harness.review(row: 0)
    try await harness.paint()
    let proof = harness.view.game.scriptPagePresentation
    harness.view.setFrameSize(NSSize(width: 1512, height: 982))
    try clickPledgeView(harness.view, x: 40, y: 932)
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().commander.scriptState.instances.isEmpty)
    await harness.delegate.runtime.scriptPageKey("right", expected: proof)
    await harness.delegate.runtime.nativeCommand { @Sendable game in game.scriptPacks = [] }
    await harness.delegate.runtime.scriptPageKey("return", expected: proof)
    #expect(await harness.delegate.runtime.snapshot().commander.scriptState.instances.isEmpty)
  }

  @MainActor @Test func nativeCourierTrialPaintSaveLoadMenuRestartAndReturnKeepLiveState()
    async throws
  {
    let harness = try await CourierInputHarness()
    defer { harness.clean() }
    try await harness.launchMenus()
    await harness.delegate.runtime.key("gallery-open")
    let gallery = await harness.delegate.runtime.snapshot()
    let selection = try #require(
      gallery.missionCatalogue.firstIndex { $0.trialDigest == harness.fixture.pack.digest })
    await harness.delegate.runtime.nativeCommand { @Sendable game in
      game.gallery.selection = selection
      game.gallery.detail = true
      game.pinGallerySelection()
    }
    try await harness.paint()
    let live = await harness.delegate.runtime.snapshot()
    let pointer = try Data(contentsOf: harness.fixture.save)
    let preferences =
      harness.preferences.persistentDomain(forName: harness.fixture.root.lastPathComponent) ?? [:]
    let activeURL = harness.delegate.saves.activeURL
    try harness.press("t")
    await harness.drain()
    let namespace = try #require(await harness.delegate.runtime.gallerySaveDirectory())
    defer { try? FileManager.default.removeItem(at: namespace) }
    let trial = await harness.delegate.runtime.snapshot()
    #expect(trial.isMissionTrial && trial.commander.scriptState.instances.isEmpty)
    #expect(
      trial.contractBoard.detail && trial.contractBoard.action == .back
        && trial.contractBoard.rows.count == 6)
    try captureCourierView(trial, name: "trial-review")
    #expect(trial.contractBoard.quote?.resources == trial.commander.contractQuoteResources)
    try await harness.paint()
    try harness.press("right")
    await harness.drain()
    try #require(await harness.delegate.runtime.snapshot().contractBoard.action == .accept)
    try await harness.paint()
    let confirm = await harness.delegate.runtime.snapshot()
    try #require(harness.view.paintedMissionMenuPresentation == confirm.scriptPagePresentation)
    try harness.press("return")
    await harness.drain()
    let held = await harness.delegate.runtime.snapshot()
    #expect(held.commander.scriptState.instances.values.first?.courier?.terminal == nil)
    #expect(held.commander.scriptState.instances.count == 1)
    harness.delegate.queueCommanderFile(.saveActive)
    await harness.drain()
    _ = try await harness.delegate.runtime.loadForInterface()
    #expect(await harness.delegate.runtime.snapshot().commander == held.commander)
    try await harness.paint()
    try captureCourierView(harness.view.game, name: "trial-held-reload")
    try harness.menu("trial-restart")
    await harness.drain()
    let restarted = await harness.delegate.runtime.snapshot()
    #expect(restarted.isMissionTrial && restarted.commander.scriptState.instances.isEmpty)
    #expect(
      restarted.contractBoard.action == .back && restarted.ecmControl.epoch != held.ecmControl.epoch
    )
    try await harness.paint()
    try captureCourierView(harness.view.game, name: "trial-restart")
    #expect(restarted.contractBoard.quote?.resources == restarted.commander.contractQuoteResources)
    try harness.menu("trial-return")
    await harness.drain()
    let restored = await harness.delegate.runtime.snapshot()
    #expect(restored.commander == live.commander && !restored.isMissionTrial)
    #expect(try Data(contentsOf: harness.fixture.save) == pointer)
    #expect(harness.delegate.saves.activeURL == activeURL)
    #expect(
      NSDictionary(
        dictionary: harness.preferences.persistentDomain(
          forName: harness.fixture.root.lastPathComponent) ?? [:]
      ).isEqual(to: preferences))
    try captureCourierView(restored, name: "trial-return")
  }
}

@Test func courierRejectedTrialPreparationKeepsParentNamespaceWriterAndControls() async throws {
  let fixture = try CourierFixture(scriptEdit: {
    $0.replacingOccurrences(of: "reward = plan.reward,", with: "reward = plan.reward + 1,")
  })
  defer { fixture.clean() }
  var game = fixture.game()
  game.openGallery()
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  var controls = Controls()
  controls.pitch = 0.4
  await runtime.setControls(controls)
  try await runtime.save(to: fixture.save)
  let before = await runtime.snapshot()
  let pointer = try Data(contentsOf: fixture.save)
  await #expect(throws: MissionPackError.self) {
    try await runtime.startScriptGalleryTrial(packDigest: fixture.pack.digest)
  }
  #expect(await runtime.snapshot().commander == before.commander)
  #expect(await runtime.snapshot().ecmControl.epoch == before.ecmControl.epoch)
  #expect(await runtime.gallerySaveDirectory() == nil)
  #expect(await runtime.courierControlsFixture().pitch == controls.pitch)
  #expect(try Data(contentsOf: fixture.save) == pointer)
}

extension NativeViewTests {
  @MainActor @Test func nativeCourierOriginAbandonBackAndPointerConsumeOnlyOwnedItem() async throws
  {
    let harness = try await CourierInputHarness()
    defer { harness.clean() }
    await harness.delegate.runtime.nativeCommand { @Sendable game in game.commander.cargo[0] = 2 }
    try await harness.review(row: 1)
    try await harness.paint()
    try harness.press("right")
    try harness.press("return")
    await harness.drain()
    let accepted = await harness.delegate.runtime.snapshot()
    let id = try #require(accepted.commander.scriptState.instances.keys.first)
    await harness.delegate.runtime.key("contacts-open")
    try await harness.paint()
    #expect(
      harness.view.game.courierContactActionLabel == "Abandon"
        && !harness.view.game.scriptConfirmSelected)
    let reviewed = harness.view.game.commander
    try captureCourierView(harness.view.game, name: "origin-abandon-review")
    try clickPledgeView(harness.view, x: 400, y: 478)
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().commander == reviewed)
    await harness.delegate.runtime.key("contacts-open")
    try await harness.paint()
    try clickPledgeView(harness.view, x: 40, y: 478)
    try clickPledgeView(harness.view, x: 40, y: 478)
    await harness.drain()
    let abandoned = await harness.delegate.runtime.snapshot()
    #expect(abandoned.commander.scriptState.instances[id]?.outcome == .abandoned)
    #expect(abandoned.commander.scriptState.instances[id]?.courier?.terminal?.amount == 0)
    #expect(
      abandoned.commander.credits == accepted.commander.credits && abandoned.commander.cargo[0] == 2
    )
    #expect(abandoned.commander.cargoTonnes == 2 && abandoned.commander.valid)
  }

  @MainActor @Test func nativeCourierUnavailablePackageTermsStayReadableAndCannotAccept()
    async throws
  {
    let harness = try await CourierInputHarness()
    defer { harness.clean() }
    await harness.delegate.runtime.nativeCommand { @Sendable game in
      game.commander.cargo[0] = game.commander.standardCargoCapacity
    }
    try await harness.review(row: 1)
    try await harness.paint()
    let before = harness.view.game.commander
    #expect(harness.view.game.contractBoard.quote?.allowed == false)
    #expect(harness.view.game.contractBoard.quote?.courier?.terms.variant == .package)
    try captureCourierView(harness.view.game, name: "package-no-hold")
    try harness.press("pagedown")
    await harness.drain()
    try await harness.paint()
    #expect(harness.view.game.contractBoard.scroll > 0)
    try captureCourierView(harness.view.game, name: "package-no-hold-scrolled")
    let bounds = try #require(
      ContractBoardLayout(width: 512, height: 518).actions.first { $0.0 == .accept }?.1)
    try clickPledgeView(harness.view, x: bounds.x + 8, y: bounds.y + 8)
    await harness.drain()
    #expect(await harness.delegate.runtime.snapshot().commander == before)
    #expect(await harness.delegate.runtime.snapshot().commander.scriptState.instances.isEmpty)
  }
}

@Test func courierStandaloneTrialHandlerFailurePreservesOriginalGame() throws {
  let fixture = try CampaignGalleryFixture()
  defer { fixture.clean() }
  let folder = fixture.directory.appendingPathComponent("parent0")
  let module = folder.appendingPathComponent("scripts/main.lua")
  let source = try String(contentsOf: module, encoding: .utf8)
  let entry = "function M.accepted(e,w,d)"
  try #require(source.contains(entry))
  try source.replacingOccurrences(
    of: entry, with: entry + "\n  error('Standalone trial rejected')"
  ).write(to: module, atomically: true, encoding: .utf8)
  let rejected = try ScriptPackLibrary.read(folder)
  var game = fixture.game()
  game.scriptPacks = [fixture.child, rejected]
  game.commander.name = "KEEP TRIAL SETUP"
  game.commander.credits = 12345
  game.commander.cargo[0] = 3
  let before = game
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys]
  let world = try encoder.encode(before.scriptWorldSave)
  do {
    try game.prepareScriptTrial(packDigest: rejected.digest, seed: 42)
    Issue.record("The real standalone accepted handler must reject preparation.")
  } catch let error as MissionPackError {
    #expect(error.localizedDescription.contains("Standalone trial rejected"))
  }
  #expect(game.commander == before.commander)
  #expect(try encoder.encode(game.scriptWorldSave) == world)
  #expect(game.screen == before.screen && game.message == before.message)
  #expect(game.ecmControl.epoch == before.ecmControl.epoch)
}
