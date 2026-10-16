import Foundation

/// Native gameplay counters must resume independently of UI clocks and script-local RNG.
struct ScriptSimulationSave: Codable, Sendable {
  let randomState: UInt64
  let fireCooldown: Double
  // Retained legacy metadata only; the native EncounterDirector owns spawning.
  let spawnClock: Double?
  let missionLoopCounter: UInt8
  let missionSpawnDelay: Int
  let ecmFrames: Int
  var ecmRemainingDuration: Double? = nil
  let enemyECMSource: Int?
  let missileCooldown: Double
  let cabinTemperature: Double
  let altitude: Double
  let solar: ScriptSolarSave?
  var valid: Bool {
    [fireCooldown, missileCooldown, cabinTemperature, altitude].allSatisfy {
      $0.isFinite && (0...1e12).contains($0)
    }
      && (spawnClock.map { $0.isFinite && (0...1e12).contains($0) } ?? true)
      && (ecmRemainingDuration.map {
        $0.isFinite && (0...(1024.0 / ECMControl.referenceFramesPerSecond)).contains($0)
          && ECMControl.legacyFrames(forRemainingDuration: $0) == ecmFrames
      } ?? true)
      && (solar?.valid ?? true)
      && (0...1_000_000).contains(missionSpawnDelay) && (0...1024).contains(ecmFrames)
      && (enemyECMSource.map { (0..<1_000_000_000).contains($0) } ?? true)
  }
}
