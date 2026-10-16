import Foundation

extension Game {
  mutating func advanceNPCResources(delta: Double) {
    guard delta.isFinite, delta > 0 else { return }
    for index in bodies.indices where bodies[index].energy > 0 {
      guard var resources = bodies[index].physical?.npc?.resources, resources.valid else {
        continue
      }
      resources.advance(delta: delta)
      if resources.profile == .nativeHull {
        bodies[index].energy = min(
          resources.energyCapacity, bodies[index].energy + delta * resources.energyRecharge)
      }
      let position = bodies[index].position
      let velocity = bodies[index].physical?.velocity ?? .init(0, 0, 0)
      if bodies[index].physical?.npc?.hasFuelScoops == true,
        let sun = celestials.first(where: { $0.kind == .sun }), sun.radius > 0
      {
        let toward = sun.position - position
        let ratio = toward.length / sun.radius
        let forward = bodies[index].modelVector(.init(0, 0, 1)).unit
        if ratio > 1 && ratio <= 3 && velocity.length > 0,
          forward.dot(toward.unit) >= 0.8
        {
          resources.scoopFuel(delta: delta, rate: 7 * min(1, velocity.length / 144))
        } else {
          resources.scoopRemainder = 0
        }
      }
      bodies[index].physical?.npc?.resources = resources
    }
  }

  func telemetryFacts(for body: SpaceBody) -> TargetTelemetry.Facts {
    let npc = body.physical?.npc
    let route: TargetTelemetry.RouteProvenance? = npc?.routeProvenance.map {
      switch $0 {
      case .generated: .generated
      case .recorded: .recorded
      case .inferredLocal: .inferredLocal
      }
    }
    return .init(
      cargo: npc?.cargoProvenance == nil || npc?.cargoProvenance == .inferredLocal
        ? nil : npc?.ordinaryCargo,
      origin: route.flatMap { provenance in
        npc.map { .init(identity: $0.origin, provenance: provenance) }
      },
      destination: route.flatMap { provenance in
        npc.map { .init(identity: $0.destination, provenance: provenance) }
      },
      legal: npc?.legalProvenance == nil ? nil : npc?.legal,
      hostile: body.hostile,
      resources: npc?.resources?.valid == true ? npc?.resources?.telemetry : nil)
  }
}
