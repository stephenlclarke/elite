import Foundation

extension Commander {
  var fittedMiningWorkTool: OwnedEquipmentItem? {
    guard performance.workTools?.contains(.miningLaser) == true,
      let inventory = equipmentInventory
    else { return nil }
    return inventory.items.first {
      $0.node
        == EquipmentNodeID(
          family: EquipmentRuntimeCatalog.laserFamily,
          key: LaserKind.mining.equipmentName)
        && $0.location
          == ComponentFittingLocation(
            hullInstanceID: inventory.activeHull,
            slot: .utility(.miningLaser))
    }
  }
  var hasMiningWorkTool: Bool { fittedMiningWorkTool != nil }
}

extension Game {
  /// A separate forward work tool is not a fifth combat facing. It can emit only at a
  /// verified rock with a clear physical ray; ships/stations occlude it without taking damage.
  @discardableResult
  mutating func fireMiningWorkTool() -> Bool {
    guard !docked, screen == .front, let tool = commander.fittedMiningWorkTool,
      energy.isFinite, laserHeat.isFinite, fireCooldown.isFinite,
      fireCooldown <= 0, laserHeat <= 230, energy > 1
    else { return false }
    ensurePhysicalActors()
    guard
      let hit = GameplayRaycast.nearest(
        origin: .init(0, 0, 0), direction: .init(0, 0, 1), maxDistance: 6000,
        bodies: bodies.filter { $0.energy > 0 }, celestials: celestials,
        meshOverrides: gameplayMeshOverrides),
      case .body(let bodyID) = hit.target,
      let body = bodies.first(where: { $0.id == bodyID && $0.hull == .asteroid }),
      let physical = body.physical, let rockID = physical.rock,
      physical.identity.system == systemIdentity,
      physical.identity.visit == commander.flightSimulation.visit,
      rockID.system == systemIdentity,
      let rock = miningFields.lazy.flatMap(\.rocks).first(where: { $0.identity == rockID }),
      rock.energy.isFinite, rock.energy > 0,
      commander.miningLedger.remainingEnergy(for: rock).isFinite,
      commander.miningLedger.remainingEnergy(for: rock) > 0,
      let player = commander.flightSimulation.player,
      let origin = makeAttackOrigin(owner: player, sourcePart: "work-tool:" + tool.id.uuidString)
    else { return false }
    guard
      applyCombatHit(
        hit, origin: origin, kind: .laser, damage: LaserKind.mining.damage,
        laser: .mining, emissionPosition: commander.flightSimulation.pose.position) != nil
    else {
      commander.crimeLedger.finishEmission(origin.emissionID)
      return false
    }
    fireCooldown = LaserKind.mining.firingInterval
    laserHeat += 10
    energy -= 1
    laserFlash = 0.08
    commander.crimeLedger.finishEmission(origin.emissionID)
    return true
  }
}
