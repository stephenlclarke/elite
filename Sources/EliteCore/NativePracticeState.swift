import Foundation

enum NativePracticeError: Error, Equatable, Sendable {
  case invalidSource, staleContext, invalidTarget, duplicateHit, unsafePosition, capacity
}

struct NativePracticePermission: Codable, Sendable, Equatable {
  let mission: UUID
  let owner: UUID
  let carrier: UUID
  let lesson: NativePracticeLesson
  let digest: String
  let consent: ScriptChoiceReceipt
  let player: ActorIdentity
  let frame: ShipPose
  let begunAt: Double

  var operation: UUID {
    ScriptIdentity.uuid(
      "\(NativePracticeSource.profile):\(mission):\(digest):\(consent.sequence):\(player.system.galaxy):\(player.system.system):\(player.visit)"
    )
  }

  var valid: Bool {
    digest.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
      && consent.instance == mission && consent.choice == NativePracticeSource.consentChoice
      && consent.group == NativePracticeSource.consentGroup && consent.sequence > 0
      && player.entity == 0 && player.visit > 0 && player.visit < UInt64.max
      && (0..<8).contains(player.system.galaxy) && (0..<256).contains(player.system.system)
      && frame.position.finite && frame.position.length <= 1e9
      && NativePracticeSource.properRotation(frame.orientation)
      && begunAt.isFinite && (0...1e12).contains(begunAt)
      && consent.committed.galaxy == player.system.galaxy
      && consent.committed.system == player.system.system
  }

  func position(_ ordinal: Int) -> Vector3 {
    frame.systemPoint(NativePracticeSource.offsets[ordinal])
  }

  var volume: SphereAnchor {
    .init(
      position: frame.systemPoint(NativePracticeSource.volumeOffset),
      radius: NativePracticeSource.volumeRadius)
  }
}

struct NativePracticeBeacon: Codable, Sendable, Equatable {
  let ordinal: Int
  let identity: UUID
  let actor: ActorIdentity
  let spawn: SpawnIdentity
}

/// Three originals and at most one first-hit receipt per original. No tutorial terminal state.
struct NativePracticeState: Codable, Sendable, Equatable {
  let permission: NativePracticePermission
  let beacons: [NativePracticeBeacon]
  private(set) var hits: [NativePracticeHitReceipt] = []
  var endedAt: Double?

  static func prepare(permission: NativePracticePermission, flight: inout FlightSimulationState)
    throws -> Self
  {
    guard permission.valid, flight.valid, flight.player == permission.player,
      flight.pose == permission.frame, flight.physicalTime == permission.begunAt
    else { throw NativePracticeError.staleContext }
    var staged = flight
    guard let sequence = staged.allocateSpawn() else { throw NativePracticeError.capacity }
    var beacons: [NativePracticeBeacon] = []
    for ordinal in NativePracticeSource.offsets.indices {
      guard let actor = staged.allocateActor() else { throw NativePracticeError.capacity }
      beacons.append(
        .init(
          ordinal: ordinal,
          identity: NativePracticeSource.targetIdentity(
            operation: permission.operation, ordinal: ordinal),
          actor: actor,
          spawn: .init(
            system: actor.system, visit: actor.visit, sequence: sequence, member: UInt16(ordinal),
            producer: .provider)))
    }
    let result = Self(permission: permission, beacons: beacons)
    guard result.valid else { throw NativePracticeError.invalidSource }
    flight = staged
    return result
  }

  var valid: Bool {
    guard permission.valid, beacons.count == 3, hits.count <= 3,
      endedAt.map({ $0.isFinite && $0 >= permission.begunAt && $0 <= 1e12 }) ?? true,
      Set(beacons.map(\.identity)).count == 3, Set(beacons.map(\.actor)).count == 3,
      Set(beacons.map(\.spawn)).count == 3,
      Set(hits.map(\.target)).count == hits.count,
      Set(hits.map { $0.origin.emissionID }).count == hits.count
    else { return false }
    for ordinal in beacons.indices {
      let beacon = beacons[ordinal]
      guard beacon.ordinal == ordinal,
        beacon.identity
          == NativePracticeSource.targetIdentity(
            operation: permission.operation, ordinal: ordinal),
        beacon.actor.system == permission.player.system,
        beacon.actor.visit == permission.player.visit, beacon.actor.entity >= 2,
        beacon.actor.entity < UInt64.max, beacon.spawn.producer == .provider,
        beacon.spawn.system == beacon.actor.system, beacon.spawn.visit == beacon.actor.visit,
        beacon.spawn.sequence > 0, beacon.spawn.sequence < UInt64.max,
        beacon.spawn.sequence == beacons[0].spawn.sequence,
        beacon.spawn.member == UInt16(ordinal)
      else { return false }
    }
    return hits.allSatisfy { hit in
      hit.valid(in: self) && (endedAt.map { hit.time <= $0 } ?? true)
    }
  }

  func body(for beacon: NativePracticeBeacon, id: Int, pose: ShipPose) -> SpaceBody {
    var body = SpaceBody(
      id: id, hull: .cargo, position: pose.shipPoint(permission.position(beacon.ordinal)))
    body.orientation = permission.frame.orientation.transformed(by: pose.orientation.transposed)
    body.rotationRate = 0
    body.energy = NativePracticeSource.energy
    body.missiles = 0
    body.ecmEnabled = false
    body.missionInstanceID = permission.mission
    body.missionActorID = beacon.identity
    body.physical = .init(
      identity: beacon.actor, population: .mission, spawnIdentity: beacon.spawn,
      canonicalSpin: true)
    return body
  }

  /// Compare the complete native body with a factory original. Adding NPC/cargo/crew invalidates it.
  func beacon(for body: SpaceBody, pose: ShipPose) -> NativePracticeBeacon? {
    guard valid, let beacon = beacons.first(where: { $0.identity == body.missionActorID }),
      reserves(body), body.position.finite, body.orientation.validRotation
    else { return nil }
    var expected = self.body(for: beacon, id: body.id, pose: pose)
    guard (expected.position - body.position).length <= 1e-5,
      (expected.orientation.x - body.orientation.x).length <= 1e-6,
      (expected.orientation.y - body.orientation.y).length <= 1e-6,
      (expected.orientation.z - body.orientation.z).length <= 1e-6
    else { return nil }
    expected.position = body.position
    expected.orientation = body.orientation
    guard body == expected else { return nil }
    return beacon
  }

  /// Only an original native allocation can reserve the harmless route. Mission labels alone
  /// never exempt an ordinary ship or goods, including an NPC added to a copied beacon.
  func reserves(_ body: SpaceBody) -> Bool {
    guard body.hull == .cargo, body.scriptNPC == nil, body.scriptShot == nil,
      body.missionInstanceID == permission.mission,
      let beacon = beacons.first(where: { $0.identity == body.missionActorID }),
      let physical = body.physical, physical.identity == beacon.actor,
      physical.spawnIdentity == beacon.spawn, physical.population == .mission,
      physical.npc == nil, physical.rock == nil, physical.payload == nil,
      physical.salvage == nil, physical.empCrewPod == nil, physical.empSource == nil,
      physical.ordnance == nil, physical.catalogueShipID == nil
    else { return false }
    return true
  }

  mutating func record(_ receipt: NativePracticeHitReceipt) throws {
    guard valid, endedAt == nil, receipt.valid(in: self) else {
      throw NativePracticeError.invalidTarget
    }
    guard
      !hits.contains(where: {
        $0.target == receipt.target || $0.origin.emissionID == receipt.origin.emissionID
      })
    else { throw NativePracticeError.duplicateHit }
    hits.append(receipt)
  }
}
