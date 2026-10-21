import Darwin
import Foundation
import Testing

@testable import EliteCore

enum NativePagedSalvageFixture {
  static var firingControls: Controls {
    var controls = Controls()
    controls.fire = true
    return controls
  }

  static let permitted = SalvageWorkConditions(
    toolInstalled: true, inRange: true, aligned: true, lineOfSight: true,
    resourcesAvailable: true, ownershipAuthorized: true)

  /// Foreign ordinary history is created through its actual original producer,
  /// collector and settlement APIs. It confers no new native source or property.
  static func fullOrdinaryLedger(
    starting: SalvageLedger = .init(), initialOperation: UInt64 = 0,
    retainedWrecks: Int = 0, retainedPlans: Int = 0, retainedPartial: Int = 0
  ) throws -> SalvageLedger {
    var ledger = starting
    let system = SystemIdentity(galaxy: 7, system: 255)
    var operation = initialOperation
    var cargo = Array(repeating: 0, count: 17)
    func wreck(_ ordinal: Int) -> WreckIdentity {
      .init(system: system, site: UInt32(ordinal + 10000), lineage: 991)
    }
    let section = SalvageSectionProfile(
      index: 1, kind: .computer, localPosition: .init(0, 0, 0), normal: .init(0, 0, 1),
      radius: 10, workSeconds: 1, structural: false,
      technologyDefinitionIDs: ["computer-core"], sourceFaceIndex: 0)
    for ordinal
      in 0..<(SalvageLedger.maximumSettlements + SalvageLedger.maximumInventory
      + SalvageLedger.maximumPending)
    {
      operation += 1
      let result = ledger.advance(
        wreck: wreck(ordinal), section: section, pose: .init(), velocity: .init(0, 0, 0),
        angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: 1,
        operation: operation, conditions: permitted)
      guard case .released(let lots) = result, lots.count == 1 else {
        throw SaveError.invalidCommander
      }
      if ordinal < SalvageLedger.maximumSettlements + SalvageLedger.maximumInventory {
        let receipt = ledger.collect(
          lot: lots[0].identity, cargo: &cargo, freeTonnes: 100,
          apertureHalfExtents: .init(16, 16, 16), hasScoops: true,
          approachAllowed: true, protection: .init())
        #expect(receipt == .collected(lots[0]))
        if ordinal < SalvageLedger.maximumSettlements {
          let proposal = try #require(
            ledger.prepareSettlement(
              command: UUID(), items: [lots[0].identity], action: .sell))
          let observedSettlement = ledger.commitSettlement(proposal)
          #expect(observedSettlement == .committed(proposal))
        }
      }
    }
    let firstPlan =
      SalvageLedger.maximumSettlements + SalvageLedger.maximumInventory
      + SalvageLedger.maximumPending
    let source = SalvageLootSource(
      roles: [.asteroid], legalValue: 0, economy: 0, technology: 0, ownership: .abandoned)
    for ordinal in firstPlan..<(firstPlan + SalvageLedger.maximumPlans - retainedPlans) {
      let observedInspection = ledger.inspectLoot(
        wreck: wreck(ordinal), section: section, source: source)
      #expect(observedInspection != nil)
    }
    let firstPartial = firstPlan + SalvageLedger.maximumPlans - retainedPlans
    for ordinal in firstPartial..<(firstPartial + SalvageLedger.maximumPartial - retainedPartial) {
      operation += 1
      let observedWorkResult = ledger.advance(
        wreck: wreck(ordinal), section: section, pose: .init(), velocity: .init(0, 0, 0),
        angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: 0.1,
        operation: operation, conditions: permitted)
      #expect(
        observedWorkResult == .progress(seconds: 0.1, required: 1))
    }
    let firstMotion = firstPartial + SalvageLedger.maximumPartial - retainedPartial
    for ordinal in firstMotion..<(SalvageLedger.maximumWrecks - retainedWrecks) {
      let observedWreckUpdate = ledger.updateWreck(
        identity: wreck(ordinal),
        motion: .init(
          pose: .init(position: .init(Double(ordinal), 0, 0)), velocity: .init(0, 0, 0),
          angularVelocity: .init(0, 0, 0), energy: 10))
      #expect(
        observedWreckUpdate)
    }
    let encodedLedger = try JSONEncoder().encode(ledger)
    let decodedLedger = try JSONDecoder().decode(SalvageLedger.self, from: encodedLedger)
    #expect(decodedLedger == ledger)
    #expect(ledger.pendingLots.count == SalvageLedger.maximumPending)
    #expect(ledger.inventory.count == SalvageLedger.maximumInventory)
    let observedWreckUpdate2 = ledger.updateWreck(
      identity: wreck(SalvageLedger.maximumWrecks),
      motion: .init(
        pose: .init(), velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), energy: 10))
    #expect(
      !observedWreckUpdate2)
    return ledger
  }

  /// A real deterministic site is admitted by the production encounter path.
  /// Human compatibility fixtures omit scoops and use the original manifest section.
  /// Only the observer is positioned for a verified visible catalogue face.
  static func game(
    fullOrdinaryPools: Bool = false, humanCargo: Bool = false, requireReserved: Bool = false
  ) throws -> (Game, SalvageSite) {
    for system in 0..<256 {
      var game = Game(executive: false)
      game.commander.system = system
      try game.commander.prepareEquipment(legacy: false)
      try game.commander.grantEquipment(
        "Salvage Cutter", at: .utility(.salvageCutter), provenance: .grant("native cutter test"))
      if !humanCargo {
        try game.commander.grantEquipment(
          "Fuel Scoops", at: .utility(.fuelScoops), provenance: .grant("native cutter test"))
      }
      try game.commander.grantEquipment(
        "Targeting: Basic", at: .targetingCore, provenance: .grant("native cutter test"))
      try game.commander.grantEquipment(
        "Targeting: Salvage Module", at: .targetingSalvage, provenance: .grant("native cutter test")
      )
      game.launch()
      game.speed = 0
      guard
        let site = game.salvageSites.first(where: {
          guard let profile = SalvageCatalogue.profile(catalogueShipID: $0.catalogueShipID)
          else { return false }
          if humanCargo {
            return !profile.sourceRoles.contains(.thargoid)
              && (profile.sourceRoles.contains(.commercialTrader)
                || profile.sourceRoles.contains(.militaryCapital))
              && !game.salvageSites.contains {
                SalvageCatalogue.profile(catalogueShipID: $0.catalogueShipID)?.sourceRoles.contains(
                  .thargoid) == true
              }
          }
          return profile.sourceRoles.contains(.thargoid)
        }), let profile = SalvageCatalogue.profile(catalogueShipID: site.catalogueShipID)
      else { continue }
      if fullOrdinaryPools { game.commander.salvageLedger = try fullOrdinaryLedger() }
      for section in profile.sections where !humanCargo || section.index == 1 {
        if requireReserved {
          let source = SalvageLootSource(
            roles: profile.sourceRoles, legalValue: 0, economy: game.currentSystem.economy,
            technology: game.currentSystem.technology, ownership: .abandoned)
          let plan = SalvageLootProfiles.plan(
            section: .init(wreck: site.identity, section: section.index),
            seed: game.commander.salvageLedger.nativeInspectionSeed, source: source)
          guard
            plan.items.contains(where: {
              if case .technology(let id, _, _, _) = $0.content {
                return AlienModuleDefinition.isAttachmentDefinition(id)
              }
              return false
            })
          else { continue }
        }
        let surface = site.position + site.orientation.apply(section.localPosition)
        let normal = site.orientation.apply(section.normal).unit
        var basis = Basis3()
        basis.z = normal * -1
        let up = abs(basis.z.y) < 0.8 ? Vector3(0, 1, 0) : .init(1, 0, 0)
        basis.x = up.cross(basis.z).unit
        basis.y = basis.z.cross(basis.x).unit
        if humanCargo {
          moveObserver(
            &game,
            to: cargoObserverPose(
              .init(position: site.position, orientation: site.orientation), section: section))
        } else {
          moveObserver(&game, to: .init(position: surface + normal * 200, orientation: basis))
        }
        game.activateNearbySalvageSites()
        guard let body = game.bodies.first(where: { $0.physical?.salvage?.wreck == site.identity }),
          let hit = try game.nearestMissionCollision(
            from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 300, radius: 0,
            includePlayer: false),
          hit.hit.target == .body(body.id),
          (game.commander.flightSimulation.pose.systemPoint(hit.hit.point) - surface).length < 0.001
        else { continue }
        try NativeSaveTestFixture.prepareCurrentPolicy(&game)
        return (game, site)
      }
    }
    throw SaveError.invalidCommander
  }

  static func originalRelease(
    ledger: inout SalvageLedger, section: SalvageSectionProfile, identity: WreckSectionIdentity,
    source: SalvageLootSource, remaining: Double, operation: inout UInt64
  ) throws -> [SalvageLot] {
    var left = remaining
    while left > 0 {
      let elapsed = min(1, left)
      operation += 1
      let result = ledger.advance(
        wreck: identity.wreck, section: section, pose: .init(), velocity: .init(0, 0, 0),
        angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: elapsed,
        operation: operation, conditions: permitted, source: source)
      left -= elapsed
      if case .released(let lots) = result { return lots }
      guard case .progress = result else { throw SaveError.invalidCommander }
    }
    throw SaveError.invalidCommander
  }

  static func moveObserver(_ game: inout Game, to pose: ShipPose) {
    let old = game.commander.flightSimulation.pose
    for index in game.bodies.indices {
      let model = game.modelPose(of: game.bodies[index])
      game.bodies[index].position = pose.shipPoint(model.position)
      game.bodies[index].orientation = model.orientation.relative(to: pose.orientation)
      game.bodies[index].rotation = 0
    }
    for index in game.celestials.indices {
      game.celestials[index].position = pose.shipPoint(
        old.systemPoint(game.celestials[index].position))
    }
    game.commander.flightSimulation.pose = pose
  }

  /// Unit observer setup for the unchanged Cargo 1 face, along local -Y toward +Y.
  /// The parent and independent fragments keep their actual canonical world motion.
  static func cargoObserverPose(_ model: ShipPose, section: SalvageSectionProfile) -> ShipPose {
    var basis = Basis3()
    basis.x = model.orientation.x
    basis.y = model.orientation.z * -1
    basis.z = model.orientation.y
    return .init(
      position: model.systemPoint(section.localPosition) - basis.z * 200, orientation: basis)
  }

  /// Enter through the same Tab selection path that seals the real autopilot target.
  /// Approach and cutting time remain in each caller's original finite frame loops.
  static func engageSalvageTarget(
    _ game: inout Game, body: SpaceBody, section: WreckSectionIdentity
  ) throws {
    let actor = try #require(body.physical?.identity)
    game.workTargetFilter = .salvage
    let wasHeld = game.flightTrigger.held
    let wasSuspended = game.workFireSuspended
    game.key("tab")
    try #require(game.autoPilot.targetID == body.id && game.autoPilot.targetActor == actor)
    try #require(game.autoTargetBody?.physical?.identity == actor)
    try #require(game.workGuidance?.parent == actor)
    try #require(game.workGuidance?.mode == .hold(.salvage))
    try #require(game.workGuidance?.surface.section == section)
    try #require(game.workFireSuspended == (wasSuspended || wasHeld))
    try #require(!game.flightTrigger.pressPending && game.selectedToolActivity == nil)
  }

  /// Release and press Return at real readiness inside the caller's existing frame budget.
  /// This sends input only; there are no setup ticks or forced controller transitions.
  static func advanceHeldWork(_ runtime: GameRuntime, delta: Double) async -> Game {
    let before = await runtime.snapshot()
    if before.workGuidance?.holding == true && before.workFireSuspended {
      await runtime.setControls(.init())
      await runtime.key("return")
      await runtime.setControls(firingControls)
    }
    return await runtime.advance(delta: delta)
  }

  static func folder() throws -> URL {
    let path = FileManager.default.temporaryDirectory.path
    let resolved = path.withCString { realpath($0, nil) }
    let physical = try #require(resolved)
    defer { free(physical) }
    let url = URL(fileURLWithPath: String(cString: physical), isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
}
