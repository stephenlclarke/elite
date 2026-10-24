import Foundation

struct NativeArkDockGuidance {
  let desired: Vector3
  let orientation: Basis3
}

extension Game {
  /// Guidance selects a course. Only the separate attained native sweep can record docking.
  func inductionArkDockGuidance(
    _ body: SpaceBody, profile: ScriptNPCDefinition, delta: Double
  ) -> NativeArkDockGuidance? {
    guard let job = body.missionInstanceID, let identity = body.missionActorID,
      let state = commander.scriptState.instances[job]?.savedNativeArk,
      state.authorization.actor == identity, state.admission != nil, state.loss == nil,
      state.dockedContact == nil,
      let station = bodies.first(where: { $0.id == 0 && $0.hull == .station && $0.energy > 0 }),
      case .living = nativeOriginalMainStationDestination,
      needsInductionArkDock(state, body: body), delta.isFinite, delta > 0, delta <= 0.1,
      let physical = try? OriginalHullPhysicalContract.haflinger.get()
    else { return nil }
    return nativeCustodianDockGuidance(
      body, profile: profile, delta: delta, station: station, physical: physical)
  }

  /// Geometry/steering only; each known custodian source retains its own dock eligibility.
  func nativeCustodianDockGuidance(
    _ body: SpaceBody, profile: ScriptNPCDefinition,
    delta: Double, station: SpaceBody,
    physical: OriginalHullPhysicalContract
  ) -> NativeArkDockGuidance {
    let port = MainStationGeometry.docking
    let normal = station.modelVector(port.outward).unit
    let up = station.modelVector(port.up).unit
    let entrance = station.entrancePosition
    let centerOffset = (physical.envelope.minimum.y + physical.envelope.maximum.y) / 2
    let centered = entrance - up * centerOffset
    let relative = body.position - centered
    let depth = relative.dot(normal)
    let lateral = relative - normal * depth
    let inward = normal * -1
    let near = depth <= 1100 && depth > -port.tunnelDepth && lateral.length < 80
    var target = centered + normal * 1000
    // A far-side approach first goes around the solid cube, never straight through it.
    if depth < 300 && lateral.length > 200 { target = centered + normal * 1200 + up * 600 }
    let basis: Basis3
    let desired: Vector3
    if near {
      var aligned = body.orientation
      aligned = Self.steerInductionArk(
        aligned, forward: inward, up: up, profile: profile, delta: delta)
      basis = aligned
      let corrected = centered + normal * max(-10, min(depth, 900))
      let correction = (corrected - body.position) * 0.8
      let alignedEnough = aligned.z.dot(inward) > 0.999 && aligned.y.dot(up) > 0.999
      let entrySpeed = alignedEnough && lateral.length < 3 ? 30.0 : 0
      desired = (correction + inward * entrySpeed).limited(to: min(profile.speed, 80))
    } else {
      let offset = target - body.position
      basis = Self.steerInductionArk(
        body.orientation, forward: offset.unit,
        up: up, profile: profile, delta: delta)
      let speed = min(
        profile.speed, sqrt(max(0, 2 * profile.acceleration * max(0, offset.length - 10))))
      desired = basis.z * speed
    }
    let stationVelocity = commander.flightSimulation.pose.shipVector(
      station.physical?.velocity ?? .init(0, 0, 0))
    return .init(
      desired: (desired + stationVelocity).limited(to: profile.speed), orientation: basis)
  }

  private func needsInductionArkDock(_ state: NativeInductionArkState, body: SpaceBody) -> Bool {
    if let hop = nextInductionArkHop(state), let fuel = body.scriptNPC?.fuel {
      return fuel < state.authorization.route.legDistancesLY[hop.hop]
    }
    guard let last = state.legs.last,
      commander.scriptState.wormholeTransit?.legs[last.leg]?.phase == .arrived
    else { return false }
    return last.hop == state.authorization.route.legDistancesLY.count - 1
      && systemIdentity == NativeWayfarerInduction.seedReceiver
  }

  private static func steerInductionArk(
    _ basis: Basis3, forward: Vector3, up: Vector3,
    profile: ScriptNPCDefinition, delta: Double
  ) -> Basis3 {
    let local = basis.inverse(forward)
    let pitch = max(
      -profile.pitch * delta,
      min(profile.pitch * delta, -atan2(local.y, hypot(local.x, local.z))))
    let yaw = max(-profile.yaw * delta, min(profile.yaw * delta, -atan2(local.x, local.z)))
    var step = Basis3()
    step.rotate(pitch: pitch, roll: 0, yaw: yaw)
    var next = step.transformed(by: basis)
    let localUp = next.inverse(up)
    let roll = max(-profile.roll * delta, min(profile.roll * delta, -atan2(localUp.x, localUp.y)))
    step = Basis3()
    step.rotate(pitch: 0, roll: roll, yaw: 0)
    next = step.transformed(by: next)
    return next
  }
}

extension Game {
  /// Retain the native motion refusal policy; an unsafe proposed sweep cannot pass a solid wall.
  mutating func resolveInductionArkDockMotion(before: [SpaceBody], delta: Double) {
    guard let station = bodies.first(where: { $0.id == 0 && $0.hull == .station })
    else { return }
    let current = modelPose(of: station)
    var previous = current
    var unspin = Basis3()
    unspin.rotate(pitch: 0, roll: -station.rotationRate * delta, yaw: 0)
    previous.orientation = unspin.transformed(by: current.orientation)
    if let motion = commander.nativeStations?.stationInertia.first(where: {
      if case .main(let identity) = $0.station { return identity.system == systemIdentity }
      return false
    }) {
      previous.position = previous.position - motion.velocity * delta
    }
    let sample = NativeWormholeMotionSample.profiledMotion(in: self, before: before, delta: delta)
    for index in bodies.indices {
      let body = bodies[index]
      guard let profile = body.scriptNPC?.fit.definition,
        let old = before.first(where: { $0.physical?.identity == body.physical?.identity })
      else { continue }
      let physical: OriginalHullPhysicalContract
      if inductionArkDockGuidance(body, profile: profile, delta: delta) != nil,
        let source = try? OriginalHullPhysicalContract.haflinger.get()
      {
        physical = source
      } else if inductionRescueDockGuidance(body, profile: profile, delta: delta) != nil,
        let source = try? OriginalHullPhysicalContract.burro.get()
      {
        physical = source
      } else {
        continue
      }
      if !nativeInductionArkHullSweepIsClear(
        physical.physicalMesh,
        from: modelPose(of: old), to: modelPose(of: body),
        stationFrom: previous, stationTo: current, delta: delta, requireAperture: false)
        || !inductionArkOtherMotionIsClear(
          body: body,
          from: modelPose(of: old).position, to: modelPose(of: body).position,
          sample: sample, radius: physical.envelope.clearanceRadius)
      {
        bodies[index].position = old.position
        bodies[index].orientation = old.orientation
        bodies[index].scriptNPC?.velocity = .init(0, 0, 0)
      }
    }
  }
}
