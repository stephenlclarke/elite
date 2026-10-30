import Testing

@testable import L337Core

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
  @Test func disabledHostileTurnsOrangeImmediatelyWhileCrewStillAboardInEveryStyle()
    throws
  {
    var game = try empFixture(hostile: true)
    let empResult = try releaseDamagedEMPBoundary(&game)
    try #require(empResult)
    let source = try #require(game.bodies[0].physical?.empSource)
    let occupied = try #require(game.commander.savedEMPState?.records[source])
    try #require(occupied.crewAboard == occupied.crewTotal && occupied.pods.isEmpty)
    #expect(game.bodies[0].hostile)
    #expect(
      game.empTargetStatus(game.bodies[0])?.contains("CREW ABOARD / CUTTER CAPTURE") == true)
    #expect(game.flightStatus == "Safe")
    for style in ShipDisplayStyle.allCases {
      game.commander.shipDisplayStyle = style
      for selected in [false, true] {
        game.weaponsTargetID = selected ? game.bodies[0].id : nil
        #expect(game.targetColourCue(for: game.bodies[0]) == .recoverable)
        let frame = cueFrame(game)
        let lines = glowLines(frame)
        #expect(!lines.isEmpty && lines.allSatisfy { $0.ink == .orange })
        #expect(lines.count <= 12)
        let hud = Display.cockpit(game, width: 768, height: 768)
        #expect(
          hud.graphics.contains {
            if case .line(let line) = $0 {
              line.ink == .orange && line.y0 > hud.flightClip.maxY
            } else {
              false
            }
          })
        if selected {
          #expect(
            hud.labels.contains {
              $0.ink == .orange && $0.text.contains("#" + String(game.bodies[0].id))
            })
          #expect(game.targetInformation?.status?.contains("CREW ABOARD / CUTTER CAPTURE") == true)
        }
        if style == .whiteWireframe {
          #expect(!frame.shipLines.isEmpty && frame.shipLines.allSatisfy { $0.ink == .white })
        }
      }
    }
    try ejectScheduledEMPCrewBoundary(&game, source: source)
    let body = try #require(game.bodies.first { $0.physical?.empSource == source })
    #expect(game.commander.savedEMPState?.records[source]?.crewAboard == 0)
    #expect(game.targetColourCue(for: body) == .recoverable)
    #expect(game.empTargetStatus(body) == "ENGINES AND WEAPONS DISABLED - UNOCCUPIED SALVAGE")
    for style in ShipDisplayStyle.allCases {
      game.commander.shipDisplayStyle = style
      let lines = glowLines(cueFrame(game))
      #expect(!lines.isEmpty && lines.allSatisfy { $0.ink == .orange })
    }
    let context = try #require(game.gameplayContext())
    try #require(game.hasNativeRescueTools)
    let pods = game.bodies.filter { $0.physical?.empCrewPod != nil }
    try #require(!pods.isEmpty)
    for pod in pods {
      let person = try #require(pod.physical?.empCrewPod)
      let actor = try #require(pod.physical?.identity)
      let facts = try #require(game.nativePodFacts(pod, context: context))
      #expect(person.source == source && facts.person == person && facts.fits)
      #expect(pod.gameplayProtectionReasons == .empCrewPod)
      #expect(context.protection.protectedActors.contains(actor))
      for style in ShipDisplayStyle.allCases {
        game.commander.shipDisplayStyle = style
        #expect(game.targetColourCue(for: pod) == .recoverable)
        #expect(game.empTargetStatus(pod) == "OCCUPIED POD - SINGLE 1T RESCUE UNIT")
      }
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
        #expect(game.wantedRank(for: game.bodies[0]) == nil)
        #expect(
          game.targetColourCue(for: game.bodies[0])
            == (ownership == .abandoned ? .recoverable : .hostile))
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
    let wreckDestructionResult = game.commander.salvageLedger.markWreckDestroyed(wreck)
    try #require(wreckDestructionResult)
    #expect(game.targetColourCue(for: game.bodies[0]) == .ordinary)
  }

  @Test func ordinaryHostileAndActuallyLaunchedMissileAreRedOnScannerTargetAndWorldWithoutModules()
    throws
  {
    var game = try empFixture(hostile: true)
    let module = try #require(game.commander.fittedEquipment(at: .targetingSalvage))
    try game.commander.storeEquipment(
      module, expectedRevision: #require(game.commander.equipmentInventory?.revision))
    #expect(!game.workTargetCapabilities.salvageModule && !game.workTargetCapabilities.miningModule)
    game.commander.autoECM = false
    let shipID = game.bodies[0].id
    func verify(_ original: Game, id: Int) throws {
      var scene = original
      for style in ShipDisplayStyle.allCases {
        scene.commander.shipDisplayStyle = style
        for selected in [false, true] {
          scene.weaponsTargetID = selected ? id : nil
          let body = try #require(scene.bodies.first { $0.id == id })
          #expect(scene.targetColourCue(for: body) == .hostile)
          let frame = Display.cockpit(scene, width: 768, height: 768)
          let layout = CockpitLayout(game: scene, width: 768, height: 768)
          var attributable = Frame()
          attributable.rasterizeGraphics = false
          attributable.canvas = frame.canvas
          attributable.flightClip = frame.flightClip
          Display.targetWorldGlow(
            body, game: scene, projection: layout.projection,
            scene: GameplayRaycast.prepareOcclusionScene(scene, projection: layout.projection),
            context: scene.gameplayContext(), into: &attributable)
          #expect(!glowLines(attributable).isEmpty)
          #expect(glowLines(attributable).allSatisfy { $0.ink == .red })
          let rx = (layout.radarWidth - 12) / 2
          let ry = 32.0
          let cy = layout.instrumentsTop + 16 + ry
          let sx = layout.width / 2 + max(-rx + 2, min(rx - 2, body.position.x / 4400 * rx))
          let sy = cy + max(-ry + 2, min(ry - 2, -body.position.z / 8500 * ry))
          let lift = max(-ry / 2, min(ry / 2, body.position.y / 3000 * ry))
          #expect(
            frame.graphics.contains {
              if case .line(let line) = $0 {
                line.ink == .red && line.x0 == sx - 2 && line.x1 == sx + 2
                  && line.y0 == sy - lift && line.y1 == sy - lift
              } else {
                false
              }
            })
          if selected {
            #expect(frame.labels.contains { $0.ink == .red && $0.text.contains("#" + String(id)) })
            #expect(
              frame.graphics.contains {
                if case .line(let line) = $0 {
                  line.ink == .red && line.y0 < frame.flightClip.maxY
                } else {
                  false
                }
              })
          }
          if style == .whiteWireframe {
            #expect(!frame.shipLines.isEmpty && frame.shipLines.allSatisfy { $0.ink == .white })
          }
        }
      }
    }
    try verify(game, id: shipID)
    // Keep the real emitter outside the legacy close-range laser path, which
    // would otherwise intercept its own newly launched missile on this tick.
    game.bodies[0].position = .init(0, 0, 2000)
    game.bodies[0].missiles = 1
    let missileLaunchResult = game.launchGameplayNPCMissile(bodyID: shipID)
    try #require(missileLaunchResult)
    game.tick(delta: 0.1)
    let missile = try #require(
      game.bodies.first { $0.enemyMissile && $0.physical?.ordnance != nil })
    #expect(
      missile.hostile && missile.physical?.attackOrigin?.owner == game.bodies[0].physical?.identity)
    try verify(game, id: missile.id)
  }

  @Test func actualHollowImperialCourierGetsAVisibleSurfaceCueEvenWhenItsCentreRayMisses()
    throws
  {
    var game = try empFixture(catalogue: "SH063", hostile: true)
    game.bodies[0].position = .init(0, 0, 1000)
    game.bodies[0].orientation = Basis3()
    game.bodies[0].rotation = 0
    #expect(
      GameplayRaycast.nearest(
        origin: .init(0, 0, 0), direction: .init(0, 0, 1), maxDistance: 2000,
        bodies: game.bodies, meshOverrides: game.gameplayMeshOverrides) == nil)
    for style in ShipDisplayStyle.allCases {
      game.commander.shipDisplayStyle = style
      for selected in [false, true] {
        game.weaponsTargetID = selected ? game.bodies[0].id : nil
        let lines = glowLines(cueFrame(game))
        #expect(!lines.isEmpty && lines.allSatisfy { $0.ink == .red })
        #expect(lines.count <= 12)
      }
      game.celestials = [.init(kind: .planet, position: .init(0, 0, 350), radius: 300)]
      #expect(glowLines(cueFrame(game)).isEmpty)
      game.celestials = []
    }
  }

}
