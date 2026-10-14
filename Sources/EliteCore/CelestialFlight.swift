import Foundation

public enum CelestialKind: String, Sendable, Equatable { case planet, sun }

/// Local flight-space spheres use the same camera-relative units and motion as ships.
public struct CelestialBody: Sendable, Equatable {
  public let kind: CelestialKind
  public var position: Vector3
  public let radius: Double
  public init(kind: CelestialKind, position: Vector3, radius: Double) {
    self.kind = kind
    self.position = position
    self.radius = radius
  }
}

public enum SolarScoopState: Sendable, Equatable {
  case inactive, noScoops, turnTowardSun, collecting, tankFull
}

extension Game {
  /// Every launch/arrival creates a reachable local scene; commander saves still reload docked.
  mutating func resetCelestialFlight() {
    celestials = [
      .init(kind: .planet, position: .init(2600, -700, 7000), radius: 1500),
      .init(kind: .sun, position: .init(-5000, 1500, 12000), radius: 1100),
    ]
    cabinTemperature = 0
    solarFuelRemainder = 0
    solarScoopState = .inactive
  }

  mutating func clearCelestialFlight() {
    celestials = []
    cabinTemperature = 0
    solarFuelRemainder = 0
    solarScoopState = .inactive
    altitude = 1
  }

  mutating func moveCelestials(delta: Double) {
    for index in celestials.indices {
      celestials[index].position =
        celestials[index].position.rotated(
          pitch: pitch * delta, roll: roll * delta, yaw: yaw * delta)
        - autoPilot.velocity * delta - Vector3(0, 0, speed * delta * 18)
    }
  }

  /// Thermal exposure is independent of view, equipment, shields and unlimited-fuel policy.
  mutating func advanceSolarFlight(delta: Double) {
    solarScoopState = .inactive
    guard !docked, screen != .gameOver else { return }
    let sun = celestials.first { $0.kind == .sun }
    let ratio = sun.map { $0.position.length / max(1, $0.radius) } ?? Double.infinity
    let radiation = ratio <= 4 ? min(2, 0.04 * pow(3.2 / max(0.2, ratio), 4)) : 0
    cabinTemperature = max(
      0, min(1, cabinTemperature + delta * (radiation - 0.14 * cabinTemperature)))
    let planet = celestials.first { $0.kind == .planet }
    altitude =
      planet.map { max(0, min(1, ($0.position.length - $0.radius) / ($0.radius * 3))) } ?? 1
    if celestials.contains(where: { $0.position.length <= $0.radius }) {
      energy = 0
      screen = .gameOver
      spin.stop(immediate: true)
      cancelAutoTarget()
      notify(ratio <= 1 ? "DESTROYED IN THE SUN" : "PLANET IMPACT")
      return
    }
    if cabinTemperature >= 1 {
      energy = 0
      screen = .gameOver
      spin.stop(immediate: true)
      cancelAutoTarget()
      notify("CABIN OVERHEATED - SHIP DESTROYED")
      return
    }
    guard let sun, ratio <= 3 else {
      solarFuelRemainder = 0
      return
    }
    if !commander.equipment.contains("Fuel Scoops") {
      solarScoopState = .noScoops
      solarFuelRemainder = 0
    } else if commander.fuel >= commander.fuelCapacity {
      solarScoopState = .tankFull
      solarFuelRemainder = 0
    } else if speed <= 0 || sun.position.z / max(1, sun.position.length) < 0.8 {
      solarScoopState = .turnTowardSun
      solarFuelRemainder = 0
    } else {
      solarScoopState = .collecting
      // Seven tenths of a light-year per second at launch cruise or faster.
      solarFuelRemainder += delta * 7 * min(1, speed / 8)
      // Avoid losing a whole unit to accumulated binary rounding at an integer boundary.
      let gained = Int(solarFuelRemainder + 1e-9)
      if gained > 0 {
        commander.fuel = min(commander.fuelCapacity, commander.fuel + gained)
        solarFuelRemainder = max(0, solarFuelRemainder - Double(gained))
      }
      if commander.fuel == commander.fuelCapacity {
        solarFuelRemainder = 0
        solarScoopState = .tankFull
      }
    }
  }

  public var solarHUDLines: [String] {
    guard !docked, !celestials.isEmpty else { return [] }
    var lines = celestials.map { body -> String in
      let p = viewPosition(body.position)
      let horizontal = abs(p.x) < max(1, abs(p.z)) * 0.12 ? "" : (p.x < 0 ? " PORT" : " STARBOARD")
      let vertical = abs(p.y) < max(1, abs(p.z)) * 0.12 ? "" : (p.y > 0 ? " UP" : " DOWN")
      let ahead = p.z >= 0 ? " AHEAD" : " ASTERN"
      return (body.kind == .sun ? "SUN" : currentSystem.name + " PLANET")
        + ahead + horizontal + vertical + String(format: " %.1fK", p.length / 1000)
    }
    switch solarScoopState {
    case .collecting:
      lines.append(
        String(
          format: "SOLAR SCOOP ACTIVE - FUEL %.1f / %.1f LY", Double(commander.fuel) / 10,
          Double(commander.fuelCapacity) / 10))
    case .noScoops: lines.append("SOLAR CORONA - FUEL SCOOPS NOT FITTED")
    case .turnTowardSun: lines.append("SOLAR SCOOP - FACE SUN AND CRUISE")
    case .tankFull: lines.append("SOLAR SCOOP - TANK FULL")
    case .inactive: break
    }
    if cabinTemperature >= 0.9 {
      lines.append("CABIN TEMPERATURE CRITICAL - TURN AWAY NOW")
    } else if cabinTemperature >= 0.75 {
      lines.append("CABIN TEMPERATURE DANGER - LEAVE CORONA")
    }
    return lines
  }
}
