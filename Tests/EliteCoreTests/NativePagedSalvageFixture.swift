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
  static func fullOrdinaryLedger() throws -> SalvageLedger {
    var ledger = SalvageLedger()
    let system = SystemIdentity(galaxy: 7, system: 255)
    var operation: UInt64 = 0
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
          #expect(ledger.commitSettlement(proposal) == .committed(proposal))
        }
      }
    }
    let firstPlan =
      SalvageLedger.maximumSettlements + SalvageLedger.maximumInventory
      + SalvageLedger.maximumPending
    let source = SalvageLootSource(
      roles: [.asteroid], legalValue: 0, economy: 0, technology: 0, ownership: .abandoned)
    for ordinal in firstPlan..<(firstPlan + SalvageLedger.maximumPlans) {
      #expect(ledger.inspectLoot(wreck: wreck(ordinal), section: section, source: source) != nil)
    }
    let firstPartial = firstPlan + SalvageLedger.maximumPlans
    for ordinal in firstPartial..<(firstPartial + SalvageLedger.maximumPartial) {
      operation += 1
      #expect(
        ledger.advance(
          wreck: wreck(ordinal), section: section, pose: .init(), velocity: .init(0, 0, 0),
          angularVelocity: .init(0, 0, 0), tool: .cutter, elapsed: 0.1,
          operation: operation, conditions: permitted) == .progress(seconds: 0.1, required: 1))
    }
    let firstMotion = firstPartial + SalvageLedger.maximumPartial
    for ordinal in firstMotion..<SalvageLedger.maximumWrecks {
      #expect(
        ledger.updateWreck(
          identity: wreck(ordinal),
          motion: .init(
            pose: .init(position: .init(Double(ordinal), 0, 0)), velocity: .init(0, 0, 0),
            angularVelocity: .init(0, 0, 0), energy: 10)))
    }
    #expect(ledger.validState)
    #expect(ledger.pendingLots.count == SalvageLedger.maximumPending)
    #expect(ledger.inventory.count == SalvageLedger.maximumInventory)
    #expect(
      !ledger.updateWreck(
        identity: wreck(SalvageLedger.maximumWrecks),
        motion: .init(
          pose: .init(), velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), energy: 10)))
    return ledger
  }

  /// A real deterministic Thargoid site is admitted by the production encounter path.
  /// Only the observer is positioned for a verified visible catalogue face.
  static func game(fullOrdinaryPools: Bool = false) throws -> (Game, SalvageSite) {
    for system in 0..<256 {
      var game = Game(executive: false)
      game.commander.system = system
      try game.commander.prepareEquipment(legacy: false)
      try game.commander.grantEquipment(
        "Salvage Cutter", at: .utility(.salvageCutter), provenance: .grant("native cutter test"))
      try game.commander.grantEquipment(
        "Fuel Scoops", at: .utility(.fuelScoops), provenance: .grant("native cutter test"))
      try game.commander.grantEquipment(
        "Targeting: Salvage Module", at: .targetingSalvage, provenance: .grant("native cutter test")
      )
      game.launch()
      game.speed = 0
      guard
        let site = game.salvageSites.first(where: {
          SalvageCatalogue.profile(catalogueShipID: $0.catalogueShipID)?.sourceRoles.contains(
            .thargoid) == true
        }), let profile = SalvageCatalogue.profile(catalogueShipID: site.catalogueShipID)
      else { continue }
      if fullOrdinaryPools { game.commander.salvageLedger = try fullOrdinaryLedger() }
      for section in profile.sections {
        let surface = site.position + site.orientation.apply(section.localPosition)
        let normal = site.orientation.apply(section.normal).unit
        var basis = Basis3()
        basis.z = normal * -1
        let up = abs(basis.z.y) < 0.8 ? Vector3(0, 1, 0) : .init(1, 0, 0)
        basis.x = up.cross(basis.z).unit
        basis.y = basis.z.cross(basis.x).unit
        moveObserver(&game, to: .init(position: surface + normal * 200, orientation: basis))
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

  static func folder() throws -> URL {
    let url = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
}
