import Foundation

enum FleetDiscoveryKind: String, Codable, Sendable {
  case encounter, identification, playerDestruction, stationDocking
}

/// Historical native facts, not catalogue unlock requests or render/model observations.
struct FleetDiscoveryEvidence: Codable, Sendable, Equatable {
  let owner: UUID
  let ship: String
  let kind: FleetDiscoveryKind
  let actor: ActorIdentity
  let player: ActorIdentity
  let physicalTime: Double
  let death: DeathSettlement?
  let mainDock: NativeMainStationDockReceipt?
  let secondaryDock: NativeStationDockReceipt?

  var valid: Bool {
    guard let metadata = ShipCatalogue.ship(ship)?.catalogue,
      OriginalFleetDefinitionData.definition(for: ship) != nil, metadata.discoveryEligible,
      actor.system == player.system, actor.visit == player.visit,
      actor.entity > 0, actor.entity < UInt64(Int64.max), player.entity == 0,
      actor.visit > 0, actor.visit < UInt64(Int64.max),
      (0..<8).contains(actor.system.galaxy), (0...256).contains(actor.system.system),
      physicalTime.isFinite, (0...1e12).contains(physicalTime)
    else { return false }
    switch kind {
    case .encounter, .identification:
      return death == nil && mainDock == nil && secondaryDock == nil
    case .playerDestruction:
      return death?.victim == actor && death?.owner == player
        && (death?.bountyTenths ?? -1) >= 0
        && mainDock == nil && secondaryDock == nil
        && metadata.objectKind != .station && metadata.capitalSubtype != .station
    case .stationDocking:
      guard death == nil, metadata.objectKind == .station || metadata.capitalSubtype == .station
      else { return false }
      if let mainDock {
        return secondaryDock == nil && mainDock.valid && mainDock.commanderOwner == owner
          && mainDock.actor == actor && mainDock.station.world == owner
      }
      if let secondaryDock {
        return secondaryDock.station.valid && secondaryDock.sequence > 0
          && secondaryDock.sequence < UInt64(Int64.max)
          && secondaryDock.lifecycleRevision > 0
          && secondaryDock.dockingBinding.valid(for: secondaryDock.station)
          && secondaryDock.commanderOwner == owner
          && secondaryDock.dockingBinding.actor == actor && secondaryDock.station.world == owner
      }
      return false
    }
  }
}

struct FleetDiscoveryEntry: Codable, Sendable, Equatable {
  let ship: String
  var encounter: FleetDiscoveryEvidence
  var identification: FleetDiscoveryEvidence?
  var milestone: FleetDiscoveryEvidence?

  var valid: Bool {
    guard encounter.valid, encounter.ship == ship,
      let metadata = ShipCatalogue.ship(ship)?.catalogue
    else { return false }
    for proof in [identification, milestone].compactMap({ $0 }) {
      guard proof.valid, proof.ship == ship, proof.owner == encounter.owner,
        proof.physicalTime >= encounter.physicalTime
      else { return false }
    }
    guard identification == nil || identification?.kind == .identification else { return false }
    if let milestone {
      switch metadata.collectionMilestone {
      case .none: return false
      case .docking: return milestone.kind == .stationDocking
      case .destruction, .blueprintAndFabrication: return milestone.kind == .playerDestruction
      }
    }
    return true
  }
  var blueprintEarned: Bool {
    guard valid, milestone?.kind == .playerDestruction,
      let metadata = ShipCatalogue.ship(ship)?.catalogue
    else { return false }
    guard let original = OriginalFleetDefinitionData.definition(for: ship),
      original.playerFlyable, original.purchasePolicy == "blueprintFabrication"
    else { return false }
    return metadata.collectionMilestone == .blueprintAndFabrication
      && metadata.purchasePolicy == .blueprintFabrication && metadata.playerFlyable
      && metadata.access == .normal
  }
  var status: String {
    if blueprintEarned { return "Blueprint earned" }
    if milestone != nil { return "Collection milestone recorded" }
    return identification == nil ? "Encountered" : "Identified"
  }
}

struct NativeFleetDiscovery: Codable, Sendable, Equatable {
  let owner: UUID
  private(set) var entries: [String: FleetDiscoveryEntry] = [:]

  var valid: Bool {
    !entries.isEmpty && entries.count <= 171
      && entries.allSatisfy {
        $0.key == $0.value.ship && $0.value.encounter.owner == owner && $0.value.valid
      }
  }
  var identifiedTypes: Int { entries.values.filter { $0.identification != nil }.count }

  func readout(for ship: String) -> [String] {
    guard let entry = entries[ship] else {
      return ["Collection: unknown; no native encounter recorded"]
    }
    let place = entry.encounter.actor.system
    return [
      "Collection: " + entry.status,
      "First encounter: galaxy " + String(place.galaxy + 1) + ", system " + String(place.system),
    ]
  }

  mutating func record(_ evidence: FleetDiscoveryEvidence) throws {
    guard evidence.valid, evidence.owner == owner else { throw SaveError.invalidCommander }
    var entry = entries[evidence.ship] ?? .init(ship: evidence.ship, encounter: evidence)
    guard evidence.physicalTime >= entry.encounter.physicalTime else {
      throw SaveError.invalidCommander
    }
    if evidence.kind == .identification, entry.identification == nil {
      entry.identification = evidence
    }
    let metadata = ShipCatalogue.ship(evidence.ship)!.catalogue
    let expected = metadata.collectionMilestone
    if entry.milestone == nil,
      (evidence.kind == .stationDocking && expected == .docking)
        || (evidence.kind == .playerDestruction
          && [.destruction, .blueprintAndFabrication].contains(expected))
    {
      entry.milestone = evidence
    }
    var candidate = self
    candidate.entries[evidence.ship] = entry
    guard candidate.valid else { throw SaveError.invalidCommander }
    self = candidate
  }
}

extension Game {
  /// Native catalogue identity is mandatory. A Lua profile that merely borrows its mesh is not it.
  private func fleetShip(_ body: SpaceBody, context: EncounterContext) -> String? {
    guard body.scriptNPC == nil, body.scriptShot == nil,
      let physical = body.physical, let id = physical.catalogueShipID,
      let ship = ShipCatalogue.ship(id), ship.originalDefinition != nil,
      ship.catalogue.discoveryEligible == true, ship.game != nil,
      physical.identity.system == context.system, physical.identity.visit == context.visit,
      context.actors.contains(where: { $0.identity == physical.identity }),
      bodies.filter({ $0.physical?.identity == physical.identity }).count == 1
    else { return nil }
    return id
  }

  private mutating func recordFleetEvidence(_ proof: FleetDiscoveryEvidence) {
    var value = commander.scriptState.savedFleetDiscovery ?? .init(owner: proof.owner)
    do {
      try value.record(proof)
      if value != commander.scriptState.savedFleetDiscovery {
        commander.scriptState.savedFleetDiscovery = value
      }
    } catch { /* A refused observation grants no collection or fabrication entitlement. */  }
  }

  mutating func observeSelectedFleetDiscovery() {
    guard !docked, !paused, screen.isFlight, !playerEMPDisabled,
      let body = autoTargetBody, body.energy > 0,
      let context = gameplayContext(), let id = fleetShip(body, context: context),
      let owner = commander.equipmentOwnerID, let physical = body.physical,
      let tier = commander.targetingTier
    else { return }
    let kind: FleetDiscoveryKind = tier >= .identification ? .identification : .encounter
    let old = commander.scriptState.savedFleetDiscovery?.entries[id]
    if kind == .identification ? old?.identification != nil : old != nil { return }
    let layout = CockpitLayout(game: self, width: viewportWidth, height: viewportHeight)
    guard Display.visibleInFront(body, game: self, layout: layout),
      body.position.length <= context.perceptionRadius
    else { return }
    do {
      guard
        let hit = try nearestMissionCollision(
          from: .init(0, 0, 0), direction: body.position.unit,
          range: body.position.length + (gameplayMesh(for: body).vertices.map(\.length).max() ?? 0),
          radius: 0, includePlayer: false), hit.hit.target == .body(body.id)
      else { return }
    } catch { return }
    recordFleetEvidence(
      .init(
        owner: owner, ship: id, kind: kind,
        actor: physical.identity, player: context.player.identity,
        physicalTime: commander.flightSimulation.physicalTime,
        death: nil, mainDock: nil, secondaryDock: nil))
  }

  mutating func observeFleetDestruction(
    _ death: DeathSettlement?, target: GameplayHitTarget?, context: EncounterContext
  ) {
    guard let death, death.owner == context.player.identity, case .body(let bodyID) = target,
      let body = bodies.first(where: { $0.id == bodyID }),
      body.energy <= 0, body.physical?.identity == death.victim,
      let id = fleetShip(body, context: context), let owner = commander.equipmentOwnerID
    else { return }
    recordFleetEvidence(
      .init(
        owner: owner, ship: id, kind: .playerDestruction,
        actor: death.victim, player: context.player.identity,
        physicalTime: commander.flightSimulation.physicalTime,
        death: death, mainDock: nil, secondaryDock: nil))
  }

  mutating func observeFleetDocking(
    body: SpaceBody, main: NativeMainStationDockReceipt? = nil,
    secondary: NativeStationDockReceipt? = nil
  ) {
    guard let id = body.physical?.catalogueShipID, body.scriptNPC == nil,
      body.energy > 0, let actor = body.physical?.identity,
      let player = commander.flightSimulation.player,
      let owner = commander.equipmentOwnerID,
      (main != nil && main == commander.nativeStations?.currentMainDock
        && nativeMainStationDockEvidenceIsCurrent)
        || (secondary != nil && secondary == commander.nativeStations?.ledger.currentDock
          && nativeStationDockEvidenceIsCurrent)
    else { return }
    recordFleetEvidence(
      .init(
        owner: owner, ship: id, kind: .stationDocking,
        actor: actor, player: player, physicalTime: commander.flightSimulation.physicalTime,
        death: nil, mainDock: main, secondaryDock: secondary))
  }
}
