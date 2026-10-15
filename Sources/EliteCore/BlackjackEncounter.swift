import Foundation

public struct BlackjackEncounter: Sendable, Codable, Equatable {
  public let identity: UUID
  public let role: BlackjackTarget
  public var body: SpaceBody
  public init(role: BlackjackTarget, id: Int) {
    identity = UUID()
    self.role = role
    body = SpaceBody(id: id, hull: .cobra, position: .init(0, 0, 0), hostile: true)
    body.blackjackIdentity = identity
    body.blackjackRole = role
    body.energy = BlackjackTarget.energy
    body.missiles = 3
    body.ecmEnabled = true
  }
  public var valid: Bool {
    body.blackjackIdentity == identity && body.blackjackRole == role && body.hull == .cobra
      && body.energy.isFinite && body.energy <= BlackjackTarget.energy && body.energy >= 0
      && (0...3).contains(body.missiles) && body.position.finite
      && body.position.length <= 1_000_000 && body.orientation.validRotation
      && body.rotation.isFinite && body.rotationRate.isFinite
      && (body.blackjackLaserCooldown ?? 0).isFinite
      && (body.blackjackLaserCooldown ?? 0) >= 0
  }
}
extension Vector3 { var finite: Bool { x.isFinite && y.isFinite && z.isFinite } }
extension Basis3 {
  var finite: Bool { x.finite && y.finite && z.finite }
  var validRotation: Bool {
    finite && [x, y, z].allSatisfy { abs($0.length - 1) < 0.0001 }
      && abs(x.dot(y)) < 0.0001 && abs(x.dot(z)) < 0.0001 && abs(y.dot(z)) < 0.0001
  }
  func inverse(_ value: Vector3) -> Vector3 { .init(value.dot(x), value.dot(y), value.dot(z)) }
  func relative(to anchor: Basis3) -> Self {
    var result = Self()
    result.x = anchor.inverse(x)
    result.y = anchor.inverse(y)
    result.z = anchor.inverse(z)
    return result
  }
  func transformed(by anchor: Basis3) -> Self {
    var result = Self()
    result.x = anchor.apply(x)
    result.y = anchor.apply(y)
    result.z = anchor.apply(z)
    return result
  }
}
extension Game {
  mutating func persistBlackjackTargets() {
    guard commander.galaxy == 1, let anchor = bodies.first(where: { $0.hull == .station }) else {
      return
    }
    var mission = commander.blackjack
    for body in bodies where body.blackjackIdentity != nil {
      guard let role = body.blackjackRole, role.system == commander.system else { continue }
      var encounter = role == .bolts ? mission.bolts : mission.witness
      guard encounter?.identity == body.blackjackIdentity else { continue }
      encounter?.body = body
      encounter?.body.energy = max(0, body.energy)
      encounter?.body.position = anchor.orientation.inverse(body.position - anchor.position)
      encounter?.body.orientation = body.orientation.relative(to: anchor.orientation)
      if role == .bolts { mission.bolts = encounter } else { mission.witness = encounter }
    }
    commander.blackjack = mission
  }
  mutating func restoreBlackjackEncounter() {
    guard !docked, commander.galaxy == 1, let anchor = bodies.first(where: { $0.hull == .station })
    else { return }
    let mission = commander.blackjack
    let role: BlackjackTarget
    switch mission.stage {
    case .huntBolts: role = .bolts
    case .huntWitness: role = .witness
    default: return
    }
    guard commander.system == role.system else { return }
    var encounter = role == .bolts ? mission.bolts : mission.witness
    if encounter == nil {
      encounter = BlackjackEncounter(role: role, id: nextBodyID)
      // Lane fraction 0.1 is mapped to the native station/witchpoint lane.
      encounter?.body.position = anchor.orientation.inverse(anchor.position * -0.9)
    }
    guard let saved = encounter, saved.body.energy > 0,
      !bodies.contains(where: { $0.blackjackIdentity == saved.identity })
    else { return }
    var body = saved.body
    body = body.withID(nextBodyID)
    nextBodyID += 1
    body.position = anchor.position + anchor.orientation.apply(saved.body.position)
    body.orientation = saved.body.orientation.transformed(by: anchor.orientation)
    if body.leavesLocalBubble { body.position = anchor.position * 0.1 }
    bodies.append(body)
    if role == .bolts {
      commander.blackjack.bolts = saved
    } else {
      commander.blackjack.witness = saved
    }
    persistBlackjackTargets()
    notify(role.name.uppercased() + " ENCOUNTER")
  }
  mutating func blackjackTargetDestroyed(_ body: SpaceBody) {
    guard body.energy <= 0, commander.galaxy == 1, let role = body.blackjackRole,
      commander.system == role.system, commander.blackjack.stage == role.requiredStage
    else { return }
    let saved = role == .bolts ? commander.blackjack.bolts : commander.blackjack.witness
    guard saved?.identity == body.blackjackIdentity else { return }
    _ = dispatchMission(.targetDestroyed, target: role.rawValue)
    persistBlackjackTargets()
  }
  mutating func advanceBlackjackNPC(index: Int, delta: Double) {
    bodies[index].energy = min(
      BlackjackTarget.energy, bodies[index].energy + BlackjackTarget.recharge * delta)
    let distance = bodies[index].position.length
    if distance > 0 {
      bodies[index].position =
        bodies[index].position * max(0, 1 - BlackjackTarget.speed * delta / distance)
    }
    let cooldown = max(0, (bodies[index].blackjackLaserCooldown ?? 0) - delta)
    bodies[index].blackjackLaserCooldown = cooldown
    if distance < 1500 && cooldown == 0 {
      emitLegacyNPCBeam(bodyID: bodies[index].id, damage: BlackjackTarget.weaponEnergy)
      bodies[index].blackjackLaserCooldown = LaserKind.pulse.firingInterval
    }
  }
}
extension SpaceBody {
  /// Numeric slots are scene-local; the mission UUID remains stable across scenes.
  func withID(_ id: Int) -> Self {
    var copy = self
    copy.id = id
    return copy
  }
}
