import Testing

@testable import EliteCore

private func cueFrame(_ game: Game) -> Frame {
  var frame = Frame()
  frame.rasterizeGraphics = false
  Display.flightObjects(game, projection: .legacy, into: &frame)
  return frame
}

private func glowLines(_ frame: Frame) -> [WireLine] {
  frame.graphics.compactMap { if case .glow(let line) = $0 { line } else { nil } }
}

struct TargetColourCueTests {
  @Test func disabledHostileStaysRedUntilActualEjectionThenSameHullTurnsOrangeInEveryStyle()
    throws
  {
    var game = try empFixture(hostile: true)
    try #require(game.fireEMPPirateBlaster())
    let source = try #require(game.bodies[0].physical?.empSource)
    for style in ShipDisplayStyle.allCases {
      game.commander.shipDisplayStyle = style
      for selected in [false, true] {
        game.weaponsTargetID = selected ? game.bodies[0].id : nil
        #expect(game.targetColourCue(for: game.bodies[0]) == .hostile)
        let frame = cueFrame(game)
        let lines = glowLines(frame)
        #expect(!lines.isEmpty && lines.allSatisfy { $0.ink == .red })
        #expect(lines.count <= 12)
        if style == .whiteWireframe {
          #expect(!frame.shipLines.isEmpty && frame.shipLines.allSatisfy { $0.ink == .white })
        }
      }
    }
    for _ in 0..<30 { game.tick(delta: 0.1) }
    let body = try #require(game.bodies.first { $0.physical?.empSource == source })
    #expect(game.commander.savedEMPState?.records[source]?.crewAboard == 0)
    #expect(game.targetColourCue(for: body) == .recoverable)
    #expect(game.empTargetStatus(body) == "ENGINES DISABLED - UNOCCUPIED SALVAGE")
    for style in ShipDisplayStyle.allCases {
      game.commander.shipDisplayStyle = style
      let lines = glowLines(cueFrame(game))
      #expect(!lines.isEmpty && lines.allSatisfy { $0.ink == .orange })
    }
    for pod in game.bodies where pod.physical?.empCrewPod != nil {
      #expect(game.targetColourCue(for: pod) == .ordinary)
      #expect(game.empTargetStatus(pod) == "OCCUPIED ESCAPE POD - PROTECTED")
    }
  }

  @Test func hiddenAndOffscreenSourcesNeverRevealTheirGlowInAnyStyle() throws {
    var game = try empFixture(hostile: true)
    let source = game.bodies[0]
    for style in ShipDisplayStyle.allCases {
      game.commander.shipDisplayStyle = style
      game.bodies = [source]
      game.celestials = []
      try #require(!glowLines(cueFrame(game)).isEmpty)
      game.bodies[0].position = .init(10000, 0, 1000)
      #expect(glowLines(cueFrame(game)).isEmpty)
      game.bodies[0] = source
      game.bodies[0].position.z = -1000
      #expect(glowLines(cueFrame(game)).isEmpty)
      game.bodies = [source, .init(id: 99, hull: .station, position: .init(0, 0, 350))]
      #expect(glowLines(cueFrame(game)).isEmpty)
      game.bodies = [source]
      game.celestials = [.init(kind: .planet, position: .init(0, 0, 350), radius: 100)]
      #expect(glowLines(cueFrame(game)).isEmpty)
    }
  }

  @Test func decorativeRockDoesNotBecomeMineableAndCuesDoNotRequireTheSelectedWorkTool()
    throws
  {
    var game = try empFixture()
    game.bodies = [.init(id: 43, hull: .asteroid, position: .init(0, 0, 1000))]
    game.ensurePhysicalActors()
    #expect(game.targetColourCue(for: game.bodies[0]) == .ordinary)
    game.bodies = []
    let anchors = try #require(game.commander.flightSimulation.anchors)
    let field = try #require(MiningFields.generate(anchors: anchors, seed: game.gameplaySeed).first)
    let sourceRock = try #require(field.rocks.first)
    game.miningFields = [.init(position: field.position, rocks: [sourceRock])]
    game.commander.flightSimulation.pose.position = sourceRock.position - .init(0, 0, 500)
    game.activateNearbyMiningFields()
    let rock = try #require(game.bodies.first { $0.physical?.rock != nil })
    for tool in FlightWorkTool.allCases {
      game.selectedFlightTool = tool
      game.weaponsTargetID = nil
      #expect(game.targetColourCue(for: rock) == .recoverable)
    }
  }
  @Test func salvageCategoriesUseSharedOwnershipAndHostilityPriorityWithoutToolGating() throws {
    var game = try empFixture()
    game.bodies = [.init(id: 43, hull: .cargo, position: .init(0, 0, 1000))]
    game.ensurePhysicalActors()
    // Classification uses authoritative ownership, not the player's fitted specialty tools.
    let module = try #require(game.commander.fittedEquipment(at: .targetingSalvage))
    try game.commander.storeEquipment(
      module, expectedRevision: #require(game.commander.equipmentInventory?.revision))
    for category in [SalvageTargetCategory.cargo, .technology, .module, .disabledDrone, .emptyPod] {
      for ownership in [SalvageOwnership.abandoned, .claimed, .occupied, .missionProtected] {
        game.bodies[0].physical?.salvage = .init(
          category: category, ownership: ownership, claimant: nil,
          wreck: nil, section: nil, lot: nil,
          bounds: .init(center: .init(0, 0, 0), radius: 32), workSurfaces: [])
        game.bodies[0].hostile = false
        #expect(
          game.targetColourCue(for: game.bodies[0])
            == (ownership == .abandoned
              ? .recoverable : .ordinary))
        game.bodies[0].hostile = true
        #expect(game.targetColourCue(for: game.bodies[0]) == .hostile)
      }
    }
    let profile = try #require(SalvageCatalogue.all.first)
    let wreck = WreckIdentity(system: game.systemIdentity, site: 51, lineage: 1)
    for category in [SalvageTargetCategory.wreck, .section] {
      game.bodies[0].physical?.catalogueShipID = profile.catalogueShipID
      game.bodies[0].hostile = false
      game.bodies[0].physical?.salvage = .init(
        category: category, ownership: .abandoned, claimant: nil, wreck: wreck,
        section: nil, lot: nil, bounds: profile.bounds, workSurfaces: profile.surfaces(wreck: wreck)
      )
      #expect(game.targetColourCue(for: game.bodies[0]) == .recoverable)
    }
    try #require(game.commander.salvageLedger.markWreckDestroyed(wreck))
    #expect(game.targetColourCue(for: game.bodies[0]) == .ordinary)
  }

}
