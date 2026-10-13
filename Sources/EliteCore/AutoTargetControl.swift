import Foundation

public struct Basis3: Sendable, Equatable, Codable {
  public var x = Vector3(1, 0, 0)
  public var y = Vector3(0, 1, 0)
  public var z = Vector3(0, 0, 1)
  public init() {}
  public func apply(_ v: Vector3) -> Vector3 { x * v.x + y * v.y + z * v.z }
  mutating func rotate(pitch: Double, roll: Double, yaw: Double) {
    x = x.rotated(pitch: pitch, roll: roll, yaw: yaw)
    y = y.rotated(pitch: pitch, roll: roll, yaw: yaw)
    z = z.rotated(pitch: pitch, roll: roll, yaw: yaw)
  }
}

extension Vector3 {
  var unit: Vector3 { length > 1e-9 ? self * (1 / length) : .init(0, 0, 0) }
  func limited(to maximum: Double) -> Vector3 { length > maximum ? unit * maximum : self }
}

extension SpaceBody {
  public func modelVector(_ v: Vector3) -> Vector3 {
    orientation.apply(v.rotated(pitch: hull == .station ? 0 : rotation * 0.4, roll: rotation))
  }
  public var entrancePosition: Vector3 { position + modelVector(.init(0, 0, -90)) }
  public var entranceNormal: Vector3 { modelVector(.init(0, 0, -1)) }
  public var entranceUp: Vector3 { modelVector(.init(0, 1, 0)) }
}

public struct AutoTargetControl: Sendable {
  public private(set) var targetID: Int?
  public private(set) var status = "OFF"
  public private(set) var ready = false
  public private(set) var finalApproach = false
  public private(set) var velocity = Vector3(0, 0, 0)
  public private(set) var rollRate = 0.0
  public private(set) var positionError = 0.0
  public private(set) var facingError = 0.0
  public private(set) var phaseError = 0.0
  public private(set) var rateError = 0.0
  private var visited: Set<Int> = []
  private var membership: Set<Int> = []
  private var cycleSignature = ""
  private var remaining: [Int] = []
  public init() {}
  public mutating func disengage() {
    targetID = nil
    ready = false
    finalApproach = false
    velocity = .init(0, 0, 0)
    rollRate = 0
    status = "OFF"
  }
  mutating func cycle(_ eligible: [SpaceBody], frontIDs: Set<Int>, signature: String) {
    let ids = Set(eligible.map(\.id))
    let ordered = eligible.sorted { a, b in
      func group(_ body: SpaceBody) -> Int {
        body.hull == .station ? 2 : (frontIDs.contains(body.id) ? 0 : 1)
      }
      if group(a) != group(b) { return group(a) < group(b) }
      if a.position.length != b.position.length { return a.position.length < b.position.length }
      return a.id < b.id
    }.map(\.id)
    // Positions can move throughout a cycle. Membership/tier/viewport changes reconcile
    // only unvisited targets; a completed cycle takes a fresh visibility snapshot.
    visited.formIntersection(ids)
    if membership != ids || cycleSignature != signature {
      membership = ids
      cycleSignature = signature
      remaining = ordered.filter { !visited.contains($0) }
    }
    if remaining.isEmpty {
      visited = []
      remaining = ordered
    }
    guard !remaining.isEmpty else {
      disengage()
      status = "NO TARGETS"
      return
    }
    targetID = remaining.removeFirst()
    if let targetID { visited.insert(targetID) }
    ready = false
    finalApproach = false
    velocity = .init(0, 0, 0)
    status = "FACING TARGET"
  }

  mutating func steer(target: SpaceBody, delta: Double) -> (
    pitch: Double, yaw: Double, roll: Double?
  ) {
    let station = target.hull == .station
    let aim = station ? target.entranceNormal * -1 : target.position
    let pitchAngle = atan2(aim.y, hypot(aim.x, aim.z))
    let yawAngle = atan2(aim.x, aim.z)
    facingError = hypot(pitchAngle, yawAngle)
    let pitch = max(-0.8, min(0.8, pitchAngle * 1.8))
    let yaw = max(-0.8, min(0.8, yawAngle * 1.8))
    guard station else {
      status = facingError < 0.02 ? "TRACKING TARGET" : "FACING TARGET"
      return (pitch, yaw, nil)
    }
    let previousRate = rollRate
    alignStation(target, delta: delta)
    return (pitch, yaw, (previousRate + rollRate) / 2)
  }

  mutating func setApproachVelocity(_ value: Vector3) { velocity = value }

  private mutating func alignStation(_ target: SpaceBody, delta: Double) {
    phaseError = atan2(target.entranceUp.x, target.entranceUp.y)
    let matchRate = -target.rotationRate * target.orientation.z.z
    let command = max(-1, min(1, matchRate + phaseError * 1.8))
    rollRate += max(-0.8 * delta, min(0.8 * delta, command - rollRate))
    rateError = abs(rollRate - matchRate)
    let goal = target.entrancePosition + target.entranceNormal * 1000
    positionError = goal.length
    ready =
      positionError < 40 && facingError < 0.02 && abs(phaseError) < 0.03
      && rateError < 0.02 && velocity.length < 1
    if ready { finalApproach = true }
    let desired: Vector3
    if finalApproach {
      desired = finalVelocity(target)
    } else {
      desired = approachWaypoint(target, goal: goal) * 0.8
      status =
        positionError > 40 ? "APPROACHING" : (facingError > 0.02 ? "ALIGNING" : "MATCHING SPIN")
    }
    velocity = velocity + (desired.limited(to: 144) - velocity).limited(to: 240 * delta)
    if !finalApproach { keepOutsideStation(target, delta: delta) }
  }
  private mutating func finalVelocity(_ target: SpaceBody) -> Vector3 {
    let door = target.entrancePosition
    let normal = target.entranceNormal
    let distance = -door.dot(normal)
    let lateral = door - normal * door.dot(normal)
    let aligned =
      facingError < 0.03 && abs(phaseError) < 0.08 && rateError < 0.06 && lateral.length < 15
    if !aligned {
      status = "HOLDING FOR ALIGNMENT"
      return lateral * 1.8 + normal * (distance < 200 ? 40 : 0)
    }
    status = "FINAL APPROACH"
    let speed = min(distance < 200 ? 48.0 : 96.0, sqrt(max(0, distance + 20) * 240))
    return lateral * 1.8 - normal * speed
  }
  private func approachWaypoint(_ target: SpaceBody, goal: Vector3) -> Vector3 {
    let closest =
      target.position - goal * max(0, min(1, target.position.dot(goal) / max(1, goal.dot(goal))))
    guard closest.length < 400 && positionError > 40 else { return goal }
    let radial = target.position.unit * -1
    var tangent = target.modelVector(.init(1, 0, 0))
    if abs(tangent.dot(radial)) > 0.8 { tangent = target.entranceUp }
    return target.position + (radial + tangent * 0.8).unit * 600
  }
  private mutating func keepOutsideStation(_ target: SpaceBody, delta: Double) {
    if (target.position - velocity * delta).length < 400 {
      let outward = target.position.unit * -1
      let inward = velocity.dot(outward)
      if inward < 0 { velocity = velocity - outward * inward }
      if target.position.length < 400 { velocity = outward * 80 }
    }
  }

  mutating func rotateVelocity(pitch: Double, roll: Double, yaw: Double) {
    velocity = velocity.rotated(pitch: pitch, roll: roll, yaw: yaw)
  }
}

extension Game {
  public var autoTargetBody: SpaceBody? {
    bodies.first { $0.id == autoPilot.targetID && $0.energy > 0 }
  }
  public var autoHUDLines: [String] {
    guard targetingEnabled || dockingComputer else { return [] }
    guard let target = autoTargetBody else { return ["AUTO: R SELECT TARGET / Q OFF"] }
    return [
      "AUTO: \(information(for: target)?.identifier ?? "Target #\(target.id)") - \(autoPilot.status)"
    ]
  }
  mutating func cancelAutoTarget() {
    if autoTargetBody?.hull == .station {
      speed = max(speed, min(32, max(0, autoPilot.velocity.z / 18)))
    }
    autoPilot.disengage()
    dockingComputer = false
  }
  mutating func cycleAutoTarget() {
    guard !docked, screen.isFlight, targetingEnabled, let tier = commander.targetingTier else {
      return
    }
    let layout = CockpitLayout(game: self, width: viewportWidth, height: viewportHeight)
    let frontIDs = Set(
      bodies.filter {
        $0.hull.isTargetShip && Display.visibleInFront($0, game: self, layout: layout)
      }.map(\.id))
    let eligible = bodies.filter { body in
      guard body.energy > 0 else { return false }
      if body.hull == .station { return tier >= .docking }
      return body.hull.isTargetShip && (tier >= .advanced || frontIDs.contains(body.id))
    }
    let signature = "\(tier.rawValue):\(Int(viewportWidth)):\(Int(viewportHeight))"
    autoPilot.cycle(eligible, frontIDs: frontIDs, signature: signature)
    weaponsTargetID = autoPilot.targetID
    dockingComputer = false
    if autoTargetBody?.hull == .station { beginStationGuidance() }
  }
  mutating func engageDockingComputer() {
    guard !docked else {
      notify("LAUNCH BEFORE AUTO DOCKING")
      return
    }
    guard commander.hasAutomaticDocking else {
      notify("FIT DOCKING TARGETING COMPUTER OR HIGHER")
      return
    }
    guard
      let station = bodies.filter({ $0.hull == .station && $0.energy > 0 }).min(by: {
        $0.position.length < $1.position.length
      })
    else {
      notify("NO STATION IN LOCAL SPACE")
      return
    }
    cancelAutoTarget()
    autoPilot.cycle([station], frontIDs: [], signature: "docking")
    weaponsTargetID = station.id
    dockingComputer = true
    screen = .front
    beginStationGuidance()
    notify("AUTO DOCKING ENGAGED")
  }
  private mutating func beginStationGuidance() {
    spin.stop(immediate: true)
    autoPilot.setApproachVelocity(.init(0, 0, speed * 18))
    speed = 0
  }
  mutating func applyAutoTarget(delta: Double, controls: Controls) {
    guard autoPilot.targetID != nil else { return }
    let station = autoTargetBody?.hull == .station
    let enabled =
      station
      ? commander.hasAutomaticDocking && (targetingEnabled || dockingComputer) : targetingEnabled
    if !enabled
      || controls.pitch != 0 || controls.yaw != 0
      || controls.roll != 0 || (station && controls.throttle != 0)
    {
      cancelAutoTarget()
      return
    }
    guard let target = autoTargetBody else {
      if let body = bodies.first(where: { $0.id == autoPilot.targetID }) {
        clearRemovedTarget(body)
      } else {
        cancelAutoTarget()
        weaponsTargetID = nil
        notify("TARGET LOST")
      }
      return
    }
    let previousPhase = autoPilot.status
    let steering = autoPilot.steer(target: target, delta: delta)
    if station && previousPhase != autoPilot.status { notify("AUTO DOCKING: " + autoPilot.status) }
    pitch = steering.pitch
    yaw = steering.yaw
    if let ownedRoll = steering.roll {
      roll = ownedRoll
      speed = 0
    }
  }
}
