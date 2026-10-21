import Foundation

/// Native gameplay counters must resume independently of UI clocks and script-local RNG.
struct ScriptSimulationSave: Codable, Sendable {
  private enum CodingKeys: String, CodingKey {
    case randomState, fireCooldown, spawnClock, missionLoopCounter, missionSpawnDelay, ecmFrames
    case ecmRemainingDuration, enemyECMSource, missileCooldown, cabinTemperature, altitude, solar
  }
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

extension ScriptSimulationSave {
  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    randomState = try values.decode(UInt64.self, forKey: .randomState)
    fireCooldown = try values.decode(Double.self, forKey: .fireCooldown)
    spawnClock =
      values.contains(.spawnClock) ? try values.decode(Double.self, forKey: .spawnClock) : nil
    missionLoopCounter = try values.decode(UInt8.self, forKey: .missionLoopCounter)
    missionSpawnDelay = try values.decode(Int.self, forKey: .missionSpawnDelay)
    ecmFrames = try values.decode(Int.self, forKey: .ecmFrames)
    // Only historical absence authorizes the legacy frame fallback.
    ecmRemainingDuration =
      values.contains(.ecmRemainingDuration)
      ? try values.decode(Double.self, forKey: .ecmRemainingDuration) : nil
    enemyECMSource = try values.decodeIfPresent(Int.self, forKey: .enemyECMSource)
    missileCooldown = try values.decode(Double.self, forKey: .missileCooldown)
    cabinTemperature = try values.decode(Double.self, forKey: .cabinTemperature)
    altitude = try values.decode(Double.self, forKey: .altitude)
    solar = try values.decodeIfPresent(ScriptSolarSave.self, forKey: .solar)
  }
}
