import Foundation

/// Mission NPC fits use explicit source units. They never inherit player minimum equipment.
public struct ScriptNPCDefinition: Codable, Sendable, Equatable {
  public let id: String
  public let name: String
  public let source: String
  public let basis: String
  public let model: String
  public let scale: Double
  public let energy: Double
  public let recharge: Double
  public let speed: Double
  public let acceleration: Double
  public let pitch: Double
  public let yaw: Double
  public let roll: Double
  public let missiles: Int
  public let fuel: Double
  public let ecm: Bool
  public let bounty: Int
  public let lasers: [ScriptNPCWeapon]?
  public let components: [ScriptNPCComponent]?
  var valid: Bool {
    PackValidation.localID(id) && (1...80).contains(name.utf8.count)
      && (1...4096).contains(source.utf8.count) && (1...4096).contains(basis.utf8.count)
      && ScriptNPCModel.referenceValid(model) && scale.isFinite && (0.001...1000).contains(scale)
      && energy.isFinite && (0.001...1_000_000).contains(energy)
      && [recharge, speed, acceleration, pitch, yaw, roll, fuel].allSatisfy {
        $0.isFinite && (0...100_000).contains($0)
      }
      && (0...32).contains(missiles) && (0...1_000_000).contains(bounty)
      && (lasers?.count ?? 0) <= 16 && (lasers ?? []).allSatisfy(\.valid)
      && Set((lasers ?? []).map(\.id)).count == (lasers?.count ?? 0)
      && (components?.count ?? 0) <= 32 && (components ?? []).allSatisfy(\.valid)
      && Set((components ?? []).map(\.id)).count == (components?.count ?? 0)
  }
}

public struct ScriptNPCWeapon: Codable, Sendable, Equatable {
  public let id: String
  public let kind: ScriptNPCWeaponKind
  public let muzzle: Vector3
  public let direction: Vector3
  public let arc: Double
  public let damage: Double
  public let range: Double
  public let interval: Double
  public let energy: Double
  public let heat: Double
  public let cooling: Double
  public let maximumHeat: Double
  public let colour: UInt32?
  public let trackingRate: Double?
  public let projectileSpeed: Double?
  public let lifetime: Double?
  public let collisionRadius: Double?
  public let collisionDelay: Double?
  var valid: Bool {
    PackValidation.localID(id) && muzzle.finite && muzzle.length <= 100_000
      && direction.finite && abs(direction.length - 1) < 1e-6
      && arc.isFinite && (0...Double.pi).contains(arc)
      && [damage, range, interval, maximumHeat].allSatisfy {
        $0.isFinite && (0.001...100_000).contains($0)
      }
      && interval >= 0.01
      && (colour.map { $0 & 255 == 255 } ?? true)
      && (trackingRate.map { $0.isFinite && (0...32).contains($0) } ?? true)
      && [energy, heat, cooling].allSatisfy { $0.isFinite && (0...100_000).contains($0) }
      && (kind == .laser
        ? [projectileSpeed, lifetime, collisionRadius, collisionDelay].allSatisfy { $0 == nil }
        : projectileSpeed.map { $0.isFinite && (1...100_000).contains($0) } == true
          && lifetime.map { $0.isFinite && (0.01...60).contains($0) } == true
          && collisionRadius.map { $0.isFinite && (0.01...100).contains($0) } == true
          && collisionDelay.map { $0.isFinite && (0...10).contains($0) } == true
          && collisionDelay! < lifetime!)
  }
}
public enum ScriptNPCWeaponKind: String, Codable, Sendable { case laser, plasma }

public struct ScriptNPCComponent: Codable, Sendable, Equatable {
  public let id: String
  public let model: String
  public let scale: Double
  public let position: Vector3
  public let orientation: Basis3
  public let energy: Double
  public let solid: Bool
  public let weapons: [ScriptNPCWeapon]?
  var valid: Bool {
    PackValidation.localID(id) && ScriptNPCModel.referenceValid(model)
      && scale.isFinite && (0.001...1000).contains(scale)
      && position.finite && position.length <= 100_000 && orientation.validRotation
      && orientation.x.cross(orientation.y).dot(orientation.z) > 0.9999
      && energy.isFinite && (0.001...1_000_000).contains(energy)
      && (weapons?.count ?? 0) <= 8 && (weapons ?? []).allSatisfy(\.valid)
      && Set((weapons ?? []).map(\.id)).count == (weapons?.count ?? 0)
  }
}

public struct ScriptNPCModel: Codable, Sendable {
  public let id: String
  public let path: String
  public let sha256: String
  public let source: String
  public let license: String
  var valid: Bool {
    PackValidation.localID(id) && path.hasSuffix(".json")
      && (try? ScriptPackLibrary.path(path)) != nil
      && sha256.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil
      && (1...4096).contains(source.utf8.count) && (1...4096).contains(license.utf8.count)
  }
  static func referenceValid(_ model: String) -> Bool {
    if model.hasPrefix("catalogue:") {
      let id = String(model.dropFirst(10))
      return id.range(of: "^SH[0-9]{3}$", options: .regularExpression) != nil
        && ShipCatalogue.ship(id) != nil
    }
    return model.hasPrefix("asset:") && PackValidation.localID(String(model.dropFirst(6)))
  }
}

/// Geometry is stored once by content hash; individual bodies retain immutable model references.
public struct ScriptNPCFit: Codable, Sendable, Equatable {
  public let definition: ScriptNPCDefinition
  public let models: [String: String]
  var valid: Bool {
    let references = Set([definition.model] + (definition.components ?? []).map(\.model))
    return definition.valid && Set(models.keys) == references
      && models.values.allSatisfy {
        $0.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil
      }
  }
}

public struct ScriptNPCGunState: Codable, Sendable, Equatable {
  public var cooldown = 0.0
  public var heat = 0.0
  public var aim: Vector3?
  public var beamRange: Double?
  var valid: Bool {
    [cooldown, heat].allSatisfy { $0.isFinite && (0...100_000).contains($0) }
      && (aim.map { $0.finite && abs($0.length - 1) < 1e-6 } ?? true)
      && (beamRange.map { $0.isFinite && (0...100_000).contains($0) } ?? true)
  }
}

public struct ScriptNPCShot: Codable, Sendable, Equatable {
  public let identity: UUID
  public let owner: UUID
  public let instance: UUID
  public let weapon: String
  public let component: UUID?
  public var velocity: Vector3
  public var age: Double
  public let lifetime: Double
  public let damage: Double
  public let radius: Double
  public let collisionDelay: Double
  var valid: Bool {
    PackValidation.localID(weapon) && velocity.finite && (1...100_000).contains(velocity.length)
      && age.isFinite && (0...60).contains(age) && lifetime.isFinite
      && (0.01...60).contains(lifetime) && damage.isFinite && (0.001...100_000).contains(damage)
      && radius.isFinite && (0.01...100).contains(radius) && collisionDelay.isFinite
      && (0...lifetime).contains(collisionDelay)
  }
}
public struct ScriptNPCComponentState: Codable, Sendable, Equatable {
  public let identity: UUID
  public var energy: Double
  public var guns: [String: ScriptNPCGunState]
}
public enum ScriptNPCIntentMode: String, Codable, Sendable {
  case hold, approach, follow, attack, flee
}
public enum ScriptNPCIntentStatus: String, Codable, Sendable { case requested, reached, lost }
public struct ScriptNPCIntent: Codable, Sendable, Equatable {
  public let request: String
  public let mode: ScriptNPCIntentMode
  public let target: UUID?
  public let player: Bool
  /// Canonical station coordinates for approach; leader model coordinates for follow.
  public let offset: Vector3
  public let speed: Double
  public let tolerance: Double
  public var status = ScriptNPCIntentStatus.requested
  var valid: Bool {
    PackValidation.localID(request) && offset.finite && offset.length <= 1_000_000
      && speed.isFinite && (0...1).contains(speed)
      && tolerance.isFinite && (1...100_000).contains(tolerance)
      && !(player && target != nil)
      && ([.hold, .approach].contains(mode) ? !player && target == nil : player || target != nil)
  }
}
public struct ScriptNPCState: Codable, Sendable, Equatable {
  public let fit: ScriptNPCFit
  public var velocity = Vector3(0, 0, 0)
  public var fuel: Double
  public var guns: [String: ScriptNPCGunState]
  public var components: [String: ScriptNPCComponentState]
  public var intent: ScriptNPCIntent?
  public var shots: UInt64 = 0
  var valid: Bool {
    guard fit.valid, shots < UInt64(Int64.max), velocity.finite,
      velocity.length <= fit.definition.speed + 1e-6,
      fuel.isFinite, (0...fit.definition.fuel).contains(fuel), intent?.valid ?? true,
      Set(guns.keys) == Set((fit.definition.lasers ?? []).map(\.id)),
      guns.values.allSatisfy(\.valid),
      Set(components.keys) == Set((fit.definition.components ?? []).map(\.id)),
      Set(components.values.map(\.identity)).count == components.count
    else { return false }
    return (fit.definition.components ?? []).allSatisfy { spec in
      guard let actual = components[spec.id] else { return false }
      return actual.energy.isFinite && (0...spec.energy).contains(actual.energy)
        && Set(actual.guns.keys) == Set((spec.weapons ?? []).map(\.id))
        && actual.guns.values.allSatisfy(\.valid)
    }
  }
}
