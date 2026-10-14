import Foundation

/// Native gameplay counters must resume independently of UI clocks and script-local RNG.
struct ScriptSimulationSave: Codable, Sendable {
  let randomState: UInt64
  let fireCooldown: Double
  let spawnClock: Double
  let missionLoopCounter: UInt8
  let missionSpawnDelay: Int
  let ecmFrames: Int
  let enemyECMSource: Int?
  let missileCooldown: Double
  let cabinTemperature: Double
  let altitude: Double
  var valid: Bool {
    [fireCooldown, spawnClock, missileCooldown, cabinTemperature, altitude].allSatisfy {
      $0.isFinite && (0...1e12).contains($0)
    }
      && (0...1_000_000).contains(missionSpawnDelay) && (0...1024).contains(ecmFrames)
      && (enemyECMSource.map { (0..<1_000_000_000).contains($0) } ?? true)
  }
}
