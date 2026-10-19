import Foundation
import Testing

@testable import EliteCore

private func wantedGame(count: Int = 12) throws -> Game {
  var game = Game(executive: false)
  game.launch()
  try #require(!game.docked)
  let station = try #require(game.commander.flightSimulation.anchors?.station)
  NativePagedSalvageFixture.moveObserver(
    &game, to: .init(position: station.position + .init(0, 0, -5000)))
  game.speed = 0
  game.bodies = []
  game.celestials = []
  for index in 0..<count {
    let actor = try #require(game.commander.flightSimulation.allocateActor())
    var npc = NPCState(role: .pirate, origin: game.systemIdentity, destination: game.systemIdentity)
    npc.legal = .init(value: 16, bountyTenths: (index + 1) * 10)
    npc.resources = .legacyEnergyOnly(maximumEnergy: 100)
    npc.intention = .engage(try #require(game.commander.flightSimulation.player))
    var body = SpaceBody(
      id: 100 + index, hull: .cobra, position: .init(Double(index * 120), 0, 1000), hostile: true)
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
    #expect(!game.wantedBoard.contains(where: \.isPlayer))
    game.commander.legal = 255
    let player = try #require(game.wantedBoard.first(where: \.isPlayer))
    #expect(player.legal.bountyTenths == 50 && player.recordedKills == 0)
    #expect(game.wantedBoard.count == 10)
    let history = game.commander.wantedCareers
    game.commander.legal = 0
    #expect(!game.wantedBoard.contains(where: \.isPlayer))
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
    var game = try wantedGame(count: 2)
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
    let origin = try #require(game.makeAttackOrigin(owner: player))
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

  @Test func onlyAcceptedShipDeathsCountNeverSelfProjectilesOrDuplicateSettlements() throws {
    var game = try wantedGame(count: 2)
    let player = try #require(game.commander.flightSimulation.player)
    let victim = try #require(game.bodies[0].physical?.identity)
    let npc = try #require(game.bodies[1].physical?.identity)
    var ledger = game.commander.wantedCareers
    #expect(
      !ledger.record(
        .init(victim: player, owner: player, lawful: false, bountyTenths: 0), player: player,
        shipDeath: true))
    #expect(
      !ledger.record(
        .init(victim: victim, owner: player, lawful: true, bountyTenths: 10), player: player,
        shipDeath: false))
    #expect(
      ledger.record(
        .init(victim: victim, owner: npc, lawful: true, bountyTenths: 10), player: player,
        shipDeath: true))
    #expect(
      !ledger.record(
        .init(victim: victim, owner: npc, lawful: true, bountyTenths: 10), player: player,
        shipDeath: true))
    #expect(ledger.playerRecordedKills == 0)
    let key = try #require(game.commander.npcPersistence.logicalIdentity(for: npc))
    #expect(ledger.careers[key]?.recordedKills == 1)
    game.commander.wantedCareers = ledger
    #expect(
      !game.wantedBoard.contains {
        $0.identity == game.commander.npcPersistence.logicalIdentity(for: victim)
      })
  }
}
