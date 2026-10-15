import EliteCore

/// Opt-in diagnostic input only; normal startup never constructs this scene.
struct FlightPerformanceScenario: Sendable {
  enum Variant: String, CaseIterable, Sendable { case planet, sun, combined, offscreen }
  static let tickCount = 480
  static let delta = 1.0 / 60
  let variant: Variant

  func makeGame() -> Game {
    var game = Game(executive: false)
    game.launch()
    game.commander.shipDisplayStyle = .shadedPanels
    let planet = CelestialBody(kind: .planet, position: .init(2100, -600, 4500), radius: 1500)
    let sun = CelestialBody(kind: .sun, position: .init(-6000, 2200, 9500), radius: 1100)
    switch variant {
    case .planet: game.celestials = [planet]
    case .sun: game.celestials = [sun]
    case .combined: game.celestials = [planet, sun]
    case .offscreen:
      game.celestials = [
        .init(kind: .planet, position: .init(20000, -600, 4500), radius: 1500),
        .init(kind: .sun, position: .init(-25000, 2200, 9500), radius: 1100),
      ]
    }
    game.bodies = [
      .init(id: 100, hull: .cobra, position: .init(700, 120, 2500)),
      .init(id: 101, hull: .sidewinder, position: .init(-900, -180, 3400)),
      .init(id: 102, hull: .cobra, position: .init(1200, -240, 4700)),
      .init(id: 103, hull: .asteroid, position: .init(-1500, 300, 6000)),
    ]
    return game
  }

  /// Mirrors native held S/X pitch mapping, including neutral release and immediate reversal.
  func controls(forTick tick: Int) -> Controls {
    var controls = Controls()
    switch tick {
    case 120..<180, 300..<360: controls.pitch = -1
    case 240..<300: controls.pitch = 1
    default: break
    }
    return controls
  }
}
