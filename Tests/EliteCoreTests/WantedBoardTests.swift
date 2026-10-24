import AppKit
import Foundation
import Testing

@testable import EliteCore
@testable import EliteMac

private func wantedGame(count: Int = 12, spacing: Double = 120) throws -> Game {
  var game = Game(executive: false)
  // This ownership/exchange fixture uses a conventional transferable 70-unit tank.
  game.commander.shipID = "SH023"
  game.commander.fuel = game.commander.fuelCapacity
  game.launch()
  try #require(!game.docked)
  let station = try #require(game.commander.flightSimulation.anchors?.station)
  NativePagedSalvageFixture.moveObserver(
    &game, to: .init(position: station.position + .init(0, 0, -5000)))
  game.speed = 0
  game.bodies = []
  game.celestials = []
  for index in 0..<count {
    let allocatedActor = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocatedActor)
    var npc = NPCState(role: .pirate, origin: game.systemIdentity, destination: game.systemIdentity)
    npc.legal = .init(value: 16, bountyTenths: (index + 1) * 10)
    npc.resources = .legacyEnergyOnly(maximumEnergy: 100)
    npc.intention = .engage(try #require(game.commander.flightSimulation.player))
    var body = SpaceBody(
      id: 100 + index, hull: .cobra, position: .init(Double(index) * spacing, 0, 1000),
      hostile: true)
    body.physical = .init(identity: actor, population: .pirate, npc: npc, catalogueShipID: "SH023")
    game.bodies.append(body)
  }
  game.nextBodyID = 200
  let refused = game.persistNPCStates()
  try #require(refused.isEmpty)
  return game
}

struct WantedBoardTests {
  @Test func emptyReportsAndTiesDoNotInventTargetsOrCloseOnReturn() throws {
    var empty = Game(executive: false)
    empty.commander.kills = 5000
    empty.screen = .rumour
    let before = empty.commander
    empty.key("return")
    #expect(empty.wantedBoard.isEmpty && empty.screen == .rumour)
    #expect(empty.commander == before)
    var game = try wantedGame(count: 2)
    for index in game.bodies.indices { game.bodies[index].physical?.npc?.legal.bountyTenths = 50 }
    _ = game.persistNPCStates()
    let order = game.wantedBoard.map(\.stableKey)
    game.bodies.reverse()
    _ = game.persistNPCStates()
    #expect(game.wantedBoard.map(\.stableKey) == order)
    #expect(game.wantedBoard.count == 2)
  }

  @Test func nativeCareersRankTenActualRewardsAndPlayerAmnestyPreservesUnknownHistory() throws {
    var game = try wantedGame()
    let original = game.commander
    #expect(game.wantedBoard.count == 10)
    #expect(
      game.wantedBoard.map(\.legal.bountyTenths) == Array(stride(from: 120, through: 30, by: -10)))
    #expect(game.wantedBoard.allSatisfy { $0.sighting != nil && !$0.isPlayer })
    #expect(game.commander == original)
    game.commander.kills = 6000  // Rank points are deliberately not observed literal deaths.
    #expect(game.commander.wantedCareers.playerRecordedKills == 0)
    #expect(game.commander.wantedCareers.earlierHistoryUnknown)
    let cleanHasPlayer = game.wantedBoard.contains { $0.isPlayer }
    #expect(!cleanHasPlayer)
    game.commander.legal = 255
    let wantedPlayer = game.wantedBoard.first { $0.isPlayer }
    let player = try #require(wantedPlayer)
    #expect(player.legal.bountyTenths == 50 && player.recordedKills == 0)
    #expect(game.wantedBoard.count == 10)
    let history = game.commander.wantedCareers
    game.commander.legal = 0
    let amnestiedHasPlayer = game.wantedBoard.contains { $0.isPlayer }
    #expect(!amnestiedHasPlayer)
    #expect(game.commander.wantedCareers == history)
    // The exchange adapter runs at its ordinary docked unit boundary; this is
    // not a claim of a completed flight or physical docking journey.
    game.docked = true
    game.screen = .showroom
    game.commander.credits = 10_000_000
    game.showroom.selection = "SH013"
    game.showroom.trading = true
    let quote = try #require(game.shipTradeQuote)
    try #require(quote.allowed)
    game.confirmShipTrade()
    #expect(game.commander.shipID == "SH013")
    #expect(game.commander.wantedCareers == history)
  }

  @Test func tiedCareersKeepIdentityAcrossCullRebindAndCrossSystemParking() throws {
    // Initial geometry must satisfy ordinary re-admission, not just direct unit adoption.
    // Native Cobra envelopes have radius69, requiring separation greater than146.
    var game = try wantedGame(count: 2, spacing: 200)
    let radius = try #require(Mesh.hull(.cobra).vertices.map(\.length).max())
    try #require((game.bodies[1].position - game.bodies[0].position).length > 2 * radius + 8)
    let first = try #require(game.bodies.first?.physical?.identity)
    let logical = try #require(game.commander.npcPersistence.logicalIdentity(for: first))
    let career = try #require(game.commander.wantedCareers.careers[logical])
    let resources = try #require(career.parked)
    game.commander.npcPersistence.cull(actor: first)
    game.bodies.removeAll { $0.physical?.identity == first }
    #expect(game.commander.wantedCareers.careers[logical]?.callsign == career.callsign)
    game.admitPersistentNPCs()
    let rebound = try #require(game.commander.npcPersistence.binding(for: logical))
    #expect(rebound != first)
    _ = game.persistNPCStates()
    #expect(game.commander.wantedCareers.careers[logical]?.binding == rebound)
    #expect(game.commander.wantedCareers.careers[logical]?.callsign == career.callsign)
    let store = game.commander.wantedCareers
    game.commander.npcPersistence.depart(system: game.systemIdentity)
    var parked = game.commander.npcPersistence
    parked.restoreWantedCareers(store, system: .init(galaxy: game.commander.galaxy, system: 1))
    #expect(parked.count == 0)  // Reports cannot move the ship to a convenient different system.
    parked.restoreWantedCareers(store, system: game.systemIdentity)
    #expect(parked.valid && parked.count == 2)
    #expect(parked.unboundSnapshots[logical]?.energy == resources.energy)
    #expect(parked.unboundSnapshots[logical]?.missiles == resources.missiles)
    #expect(parked.unboundSnapshots[logical]?.npc.resources == resources.npc.resources)
  }

  @Test func careerStateRoundTripsAndOldCommanderStartsWithUnknownLiteralHistory() throws {
    let game = try wantedGame(count: 2)
    let data = try JSONEncoder().encode(game.commander)
    let restored = try JSONDecoder().decode(Commander.self, from: data)
    #expect(restored.wantedCareers == game.commander.wantedCareers)
    #expect(restored.wantedCareers.valid)
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    object.removeValue(forKey: "savedWantedCareers")
    let legacy = try JSONDecoder().decode(
      Commander.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(legacy.wantedCareers.careers.isEmpty)
    #expect(
      legacy.wantedCareers.playerRecordedKills == 0 && legacy.wantedCareers.earlierHistoryUnknown)
  }

  @Test func nativeDeathPaysDisplayedBountyOnceAndPromotesEleventhWithoutABoardBonus() throws {
    var game = try wantedGame(count: 11)
    game.bodies[10].position = .init(0, 0, 800)
    _ = game.persistNPCStates()
    let previouslyEleventh = try #require(game.bodies[0].physical?.identity)
    let promoted = try #require(
      game.commander.npcPersistence.logicalIdentity(for: previouslyEleventh))
    #expect(!game.wantedBoard.contains { $0.identity == promoted })
    let victim = game.bodies[10]
    let identity = try #require(victim.physical?.identity)
    let logical = try #require(game.commander.npcPersistence.logicalIdentity(for: identity))
    let player = try #require(game.commander.flightSimulation.player)
    let emittedPlayerOrigin = game.makeAttackOrigin(owner: player)
    let origin = try #require(emittedPlayerOrigin)
    let hit = try #require(
      try game.nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000, radius: 0,
        includePlayer: false))
    try #require(hit.selectedTargetBody?.id == victim.id)
    let cash = game.commander.credits
    let reward = try #require(victim.physical?.npc?.legal.bountyTenths)
    let incident = game.applyCombatHit(hit.hit, origin: origin, kind: .laser, damage: 100)
    try #require(incident != nil)
    #expect(game.commander.credits == cash + reward)
    #expect(game.commander.wantedCareers.playerRecordedKills == 1)
    #expect(game.commander.wantedCareers.careers[logical]?.retired == true)
    let after = game.commander.credits
    _ = game.recordCombat(
      origin: origin, kind: .laser, outcome: .destruction, target: .body(victim.id),
      worldPosition: game.commander.flightSimulation.pose.systemPoint(victim.position))
    #expect(
      game.commander.credits == after && game.commander.wantedCareers.playerRecordedKills == 1)
    #expect(game.wantedBoard.count == 10)
    #expect(game.wantedBoard.contains { $0.identity == promoted })
  }

  @Test func cuesRequireCurrentListedCraftAndRetainHostileDangerAndMissileRed() throws {
    var game = try wantedGame(count: 11)
    let listed = game.bodies[10]
    #expect(game.targetColourCue(for: listed) == .wanted)
    #expect(game.wantedNotice(for: listed)?.contains("WANTED #1") == true)
    #expect(game.flightStatus == "Hostile")
    #expect(game.targetColourCue(for: game.bodies[0]) == .hostile)
    var stale = listed
    stale.physical?.catalogueShipID = "SH001"
    #expect(game.wantedRank(for: stale) == nil)
    var missile = listed
    missile.hull = .missile
    missile.enemyMissile = true
    #expect(game.targetColourCue(for: missile) == .hostile)
    var debris = listed
    debris.hull = .cargo
    #expect(game.wantedRank(for: debris) == nil)
    for style in ShipDisplayStyle.allCases {
      game.commander.shipDisplayStyle = style
      #expect(game.targetColourCue(for: listed).ink == .purple)
    }
  }

  @Test func purpleWorldScannerAndPanelWorkInAllViewsAndPlanetOcclusionStillWins() throws {
    var game = try wantedGame(count: 1)
    try game.commander.grantEquipment(
      TargetingTier.identification.equipmentName, at: .targetingCore,
      provenance: .grant("wanted presentation fixture"))
    game.weaponsTargetID = game.bodies[0].id
    for (view, position) in [
      (Screen.front, Vector3(0, 0, 1000)), (.rear, .init(0, 0, -1000)),
      (.left, .init(-1000, 0, 0)), (.right, .init(1000, 0, 0)),
    ] {
      game.screen = view
      game.bodies[0].position = position
      game.celestials = []
      _ = game.persistNPCStates()
      for style in ShipDisplayStyle.allCases {
        game.commander.shipDisplayStyle = style
        let frame = Display.cockpit(game, width: 768, height: 768)
        #expect(
          frame.worldGraphics.contains {
            if case .glow(let line) = $0 { return line.ink == .purple }
            return false
          })
        #expect(frame.labels.contains { $0.text.contains("WANTED #1") && $0.ink == .purple })
        #expect(game.flightStatus == "Hostile")
      }
      game.celestials = [.init(kind: .planet, position: position * 0.5, radius: 150)]
      let hidden = Display.cockpit(game, width: 768, height: 768)
      #expect(
        !hidden.worldGraphics.contains {
          if case .glow(let line) = $0 { return line.ink == .purple }
          return false
        })
    }
  }

  @Test func explicitHistoricalPlotUsesExistingPreviewWithoutCommittingARoute() throws {
    var game = try wantedGame(count: 1)
    let reported = game.commander.system
    let origin = game.currentSystem
    let neighbour = try #require(
      game.systems.first {
        $0.id != reported && origin.distance(to: $0) > 0 && origin.distance(to: $0) < 6
      })
    game.commander.system = neighbour.id
    game.docked = true
    game.screen = .rumour
    game.wantedKey("return")
    let plan = game.commander.navigationPlan
    let cash = game.commander.credits
    game.plotWantedSighting()
    #expect(game.screen == .navigation && game.selectedSystem == reported)
    #expect(game.commander.navigationPlan == plan && game.commander.credits == cash)
    #expect(game.navigationReturn == .rumour)
  }

  @Test func gossipKeyboardPointerDossierAndStalePlotAreReadOnlyAcrossWindowSizes() throws {
    var game = try wantedGame(count: 2)
    game.docked = true
    game.screen = .rumour
    game.rumourReturn = .status
    let commander = game.commander
    let bodies = game.bodies
    for (width, height) in [(512.0, 518.0), (768, 768), (1512, 982), (2560, 1440)] {
      game.viewportWidth = width
      game.viewportHeight = height
      let frame = Display.presentation(game, width: width, height: height)
      #expect(frame.labels.contains { $0.text.contains("MOST WANTED") })
      #expect(
        frame.labels.allSatisfy {
          $0.scale == GameTypography.scale && $0.bounds.x >= 0 && $0.bounds.maxX <= width
            && $0.bounds.maxY <= height
        })
      let layout = WantedBoardLayout(width: width, height: height)
      game.wantedBoardClick(x: layout.cell(1).x + 10, y: layout.cell(1).y + 5)
      let selected = try #require(game.selectedWantedEntry)
      game.wantedKey("return")
      #expect(game.wantedDetail && game.screen == .rumour)
      #expect(game.wantedDossier(selected).contains { $0.contains("earlier history Unknown") })
      #expect(game.wantedDossier(selected).contains { $0 == "Next reported destination: Unknown" })
      game.wantedKey("escape")
      #expect(!game.wantedDetail && game.screen == .rumour)
      game.wantedKey("g")
      #expect(game.wantedRumourDetail)
      game.wantedKey("escape")
    }
    #expect(game.commander == commander && game.bodies == bodies)
    game.wantedKey("return")
    let selectedSystem = game.selectedSystem
    game.commander.system = game.commander.system == 1 ? 2 : 1
    game.plotWantedSighting()
    #expect(game.screen == .rumour && game.selectedSystem == selectedSystem)
    #expect(game.commander.credits == commander.credits)
    game.wantedKey("escape")
    game.wantedKey("escape")
    #expect(game.screen == .status)
  }

  @Test func nativeCapacityRefusedKillerCannotCreateAParkedCareerOrRevisitAdmission() throws {
    var game = try wantedGame(count: 2)
    let context = try #require(game.gameplayContext())
    let template = try #require(game.commander.wantedCareers.careers.values.first?.parked)
    // Fill the real finite native ledger with independently allocated, valid snapshots.
    // This unit capacity setup does not add a second scene or fictional board dossiers.
    while game.commander.npcPersistence.count < NPCPersistenceLedger.maximumEntries {
      var snapshot = template
      let allocatedSnapshotActor = game.commander.flightSimulation.allocateActor()
      snapshot.actor = try #require(allocatedSnapshotActor)
      snapshot.position = .init(20000 + Double(snapshot.actor.entity), 0, 0)
      snapshot.firstAggressorBinding = nil
      snapshot.intentionTargetBinding = nil
      let captured = game.commander.npcPersistence.capture(snapshot, protection: context.protection)
      try #require(captured == .registered(snapshot.actor))
    }
    let allocatedRefusedActor = game.commander.flightSimulation.allocateActor()
    let refusedActor = try #require(allocatedRefusedActor)
    var npc = NPCState(role: .pirate, origin: game.systemIdentity, destination: game.systemIdentity)
    npc.legal = .init(value: 16, bountyTenths: 50)
    npc.resources = .legacyEnergyOnly(maximumEnergy: 100)
    npc.intention = .engage(try #require(game.commander.flightSimulation.player))
    var refusedBody = SpaceBody(
      id: game.nextBodyID, hull: .cobra, position: .init(0, 0, 2000), hostile: true)
    game.nextBodyID += 1
    refusedBody.physical = .init(
      identity: refusedActor, population: .pirate, npc: npc, catalogueShipID: "SH023")
    game.bodies.append(refusedBody)
    let refusedSnapshot = try #require(
      NPCPersistenceSnapshot.capture(
        body: refusedBody, pose: game.commander.flightSimulation.pose,
        physicalTime: context.physicalTime, protection: context.protection))
    let refused = game.commander.npcPersistence.capture(
      refusedSnapshot, protection: context.protection)
    try #require(refused == .refused(.capacity))
    try #require(game.commander.npcPersistence.logicalIdentity(for: refusedActor) == nil)
    let victim = game.bodies[0]
    let emittedRefusedOrigin = game.makeAttackOrigin(owner: refusedActor)
    let origin = try #require(emittedRefusedOrigin)
    let direction = (victim.position - refusedBody.position).unit
    let contact = try #require(
      try game.nearestMissionCollision(
        from: refusedBody.position, direction: direction, range: 1200, radius: 0,
        excludingBodyIDs: [refusedBody.id], includePlayer: false))
    try #require(contact.selectedTargetBody?.id == victim.id)
    let hit = game.applyCombatHit(
      contact.hit, origin: origin, kind: .laser, damage: 100,
      emissionPosition: game.commander.flightSimulation.pose.systemPoint(refusedBody.position))
    try #require(hit != nil && game.bodies.first(where: { $0.id == victim.id })?.energy == 0)
    #expect(game.commander.wantedCareers.careers[refusedActor] == nil)
    #expect(
      !game.commander.wantedCareers.careers.values.contains {
        $0.binding == refusedActor || $0.parked?.actor == refusedActor
      })
    #expect(game.commander.wantedCareers.playerRecordedKills == 0)
    let saved = game.commander.wantedCareers
    var revisit = game.commander.npcPersistence
    revisit.depart(system: game.systemIdentity)
    revisit.restoreWantedCareers(saved, system: game.systemIdentity)
    #expect(revisit.valid)
    #expect(revisit.snapshot(for: refusedActor) == nil)
    #expect(!revisit.unboundSnapshots.values.contains { $0.actor == refusedActor })
  }

  @Test func onlyAcceptedShipDeathsCountNeverSelfProjectilesOrDuplicateSettlements() throws {
    var game = try wantedGame(count: 2)
    let player = try #require(game.commander.flightSimulation.player)
    let victim = try #require(game.bodies[0].physical?.identity)
    let npc = try #require(game.bodies[1].physical?.identity)
    var ledger = game.commander.wantedCareers
    let selfDeathRecorded = ledger.record(
      .init(victim: player, owner: player, lawful: false, bountyTenths: 0), player: player,
      shipDeath: true)
    #expect(!selfDeathRecorded)
    let projectileDeathRecorded = ledger.record(
      .init(victim: victim, owner: player, lawful: true, bountyTenths: 10), player: player,
      shipDeath: false)
    #expect(!projectileDeathRecorded)
    let npcDeathRecorded = ledger.record(
      .init(victim: victim, owner: npc, lawful: true, bountyTenths: 10), player: player,
      shipDeath: true)
    #expect(npcDeathRecorded)
    let duplicateDeathRecorded = ledger.record(
      .init(victim: victim, owner: npc, lawful: true, bountyTenths: 10), player: player,
      shipDeath: true)
    #expect(!duplicateDeathRecorded)
    #expect(ledger.playerRecordedKills == 0)
    let key = try #require(game.commander.npcPersistence.logicalIdentity(for: npc))
    #expect(ledger.careers[key]?.recordedKills == 1)
    ledger.retire(key)
    let allocatedLaterVictim = game.commander.flightSimulation.allocateActor()
    let laterVictim = try #require(allocatedLaterVictim)
    // Accepted historical alias attribution survives the source leaving the scene.
    let aliasDeathRecorded = ledger.record(
      .init(victim: laterVictim, owner: npc, lawful: true, bountyTenths: 10),
      player: player, shipDeath: true)
    #expect(aliasDeathRecorded)
    #expect(ledger.careers[key]?.binding == nil && ledger.careers[key]?.parked == nil)
    #expect(ledger.careers[key]?.recordedKills == 2 && ledger.playerRecordedKills == 0)
    game.commander.wantedCareers = ledger
    #expect(
      !game.wantedBoard.contains {
        $0.identity == game.commander.npcPersistence.logicalIdentity(for: victim)
      })
  }
}

extension WantedBoardTests {
  @MainActor @Test func nativeWantedBoardPointerDetailsBackAndHistoricalRouteUsePrivatePreferences()
    async throws
  {
    _ = NSApplication.shared
    let originalMenu = NSApp.mainMenu
    let identifier = "elite-native-wanted-" + UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: identifier))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(identifier)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
      NSApp.mainMenu = originalMenu
      preferences.removePersistentDomain(forName: identifier)
      try? FileManager.default.removeItem(at: directory)
    }
    let file = directory.appendingPathComponent("commander.json")
    // Controlled presentation seed: actual captured careers from a previous system,
    // not a claim that this UI test flew or docked the intervening journey.
    var source = try wantedGame(count: 2)
    let reported = source.commander.system
    let origin = source.currentSystem
    let neighbour = try #require(
      source.systems.first {
        $0.id != reported && origin.distance(to: $0) > 0 && origin.distance(to: $0) < 6
      })
    try source.departOrdinarySimulation()
    source.commander.system = neighbour.id
    source.selectedSystem = neighbour.id
    source.commander.flightSimulation.enter(source.systemIdentity, arriving: false)
    source.bodies = []
    source.celestials = []
    source.docked = true
    source.screen = .status
    let seed = GameRuntime(game: source, saveURL: file)
    try await seed.save(to: file)
    let saves = CommanderSaveSession(preferences: preferences, defaultURL: file)
    let delegate = AppDelegate(
      restoreOnLaunch: false, saves: saves,
      windowSize: .init(width: 768, height: 768))
    defer {
      delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification))
      delegate.window?.orderOut(nil)
      delegate.window?.delegate = nil
      delegate.window?.close()
    }
    delegate.applicationDidFinishLaunching(
      Notification(name: NSApplication.didFinishLaunchingNotification))
    let window = try #require(delegate.window)
    let view = try #require(window.contentView as? GameView)
    let loop = try #require(delegate.loop)
    loop.cancel()
    await loop.value
    try await delegate.runtime.load(from: file, persistMigrations: false)
    await delegate.runtime.key("8")
    view.game = await delegate.runtime.snapshot()
    view.pending.removeAll()
    let originalCommander = view.game.commander

    func press(_ code: UInt16, _ text: String) async throws {
      for type in [NSEvent.EventType.keyDown, .keyUp] {
        let event = try #require(
          NSEvent.keyEvent(
            with: type, location: .zero,
            modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil,
            characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code))
        if type == .keyDown { view.keyDown(with: event) } else { view.keyUp(with: event) }
      }
      await delegate.processPendingCommands(in: view)
    }
    func click(_ point: NSPoint) async throws {
      let location = view.convert(point, to: nil)
      let event = try #require(
        NSEvent.mouseEvent(
          with: .leftMouseDown, location: location,
          modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil,
          eventNumber: 1, clickCount: 1, pressure: 1))
      view.mouseDown(with: event)
      await delegate.processPendingCommands(in: view)
    }
    func paint(_ stage: String) throws {
      let width = Int(view.bounds.width)
      let height = Int(view.bounds.height)
      let frame = Display.presentation(view.game, width: Double(width), height: Double(height))
      #expect(
        frame.labels.allSatisfy {
          $0.scale == GameTypography.scale && $0.bounds.x >= 0 && $0.bounds.y >= 0
            && $0.bounds.maxX <= Double(width) && $0.bounds.maxY <= Double(height)
        })
      let context = try #require(
        CGContext(
          data: nil, width: width, height: height,
          bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
      context.translateBy(x: 0, y: Double(height))
      context.scaleBy(x: 1, y: -1)
      NSGraphicsContext.saveGraphicsState()
      defer { NSGraphicsContext.restoreGraphicsState() }
      NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
      view.draw(view.bounds)
      let image = try #require(context.makeImage())
      if let path = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"] {
        let output = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let data = try #require(
          NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        let name = "wanted-\(stage)-\(width)x\(height)"
        try data.write(to: output.appendingPathComponent(name + ".png"))
        let receipt: [String: Any] = [
          "source": ProcessInfo.processInfo.environment["ELITE_VALIDATION_SOURCE_SHA"] ?? "local",
          "stage": stage, "width": width, "height": height,
          "logicalFontScale": GameTypography.scale, "screen": view.game.screen.rawValue,
          "pngSHA256": ScriptPackLibrary.hash(data),
        ]
        try JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys])
          .write(to: output.appendingPathComponent(name + ".json"))
      }
    }
    for (width, height) in [(512.0, 518.0), (1512, 982)] {
      // Real window/view resizing at compact and full-screen logical dimensions;
      // no macOS Space switch or human window/default preference is changed.
      window.setContentSize(.init(width: width, height: height))
      view.setFrameSize(.init(width: width, height: height))
      await delegate.runtime.setViewport(width: width, height: height)
      view.game = await delegate.runtime.snapshot()
      try await press(32, "u")
      #expect(view.game.screen == .rumour && view.game.wantedBoard.count >= 2)
      try paint("board")
      let layout = WantedBoardLayout(width: width, height: height)
      try await click(.init(x: layout.cell(0).x + 8, y: layout.cell(0).y + 8))
      #expect(view.game.selectedWantedEntry != nil)
      try await press(36, "\r")
      #expect(view.game.wantedDetail && view.game.screen == .rumour)
      try paint("detail")
      try await press(53, "\u{1b}")
      #expect(!view.game.wantedDetail && view.game.screen == .rumour)
      try await click(.init(x: layout.details.x + 8, y: layout.details.y + 8))
      #expect(view.game.wantedDetail)
      try await press(35, "p")
      #expect(view.game.screen == .navigation && view.game.selectedSystem == reported)
      #expect(view.game.commander.navigationPlan == originalCommander.navigationPlan)
      try paint("route-preview")
      try await press(53, "\u{1b}")
      #expect(view.game.screen == .rumour)
      try await press(53, "\u{1b}")
      #expect(!view.game.wantedDetail && view.game.screen == .rumour)
      try await press(53, "\u{1b}")
      #expect(view.game.screen == .status)
      #expect(view.game.commander == originalCommander)
      #expect(view.pending.isEmpty)
    }
  }
}
