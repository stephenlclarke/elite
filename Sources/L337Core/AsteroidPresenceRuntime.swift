import Foundation

public struct MiningScenePresence: Equatable, Codable, Sendable {
  public let ringPresent: Bool
  public let includingLegacy: Bool
}

extension Game {
  var resolvedMiningPresence: MiningScenePresence {
    let ledger = commander.miningLedger
    return .init(
      ringPresent: ledger.ringPresence(system: currentSystem, galaxy: commander.galaxy),
      includingLegacy: ledger.retainsLegacyFields)
  }

  /// Resolve original current/history facts before publishing any new presence policy.
  /// This never clears, normalizes or replays partial mining or physical cargo records.
  mutating func migrateMiningPresence(
    legacyMissing: Bool, persistCurrentPolicy: Bool = false
  ) throws {
    var ledger = commander.miningLedgerForMigration(legacyMissing: legacyMissing)
    if ledger.usesEconomyWeightedPresence {
      if persistCurrentPolicy { commander.miningLedger = ledger }
      return
    }
    guard systems.indices.contains(commander.system), currentSystem.id == commander.system else {
      throw SaveError.invalidCommander
    }
    let current = AsteroidPresencePin(system: currentSystem, galaxy: commander.galaxy)
    var galaxies: [Int: [StarSystem]] = [:]
    let historical = try ledger.requiredPresencePinSystems.subtracting([current.system])
      .sorted { ($0.galaxy, $0.system) < ($1.galaxy, $1.system) }
      .map { identity -> AsteroidPresencePin in
        guard (0..<8).contains(identity.galaxy), (0...256).contains(identity.system) else {
          throw SaveError.invalidCommander
        }
        if galaxies[identity.galaxy] == nil {
          galaxies[identity.galaxy] = Universe.systemsIncludingPlugh(number: identity.galaxy)
        }
        guard let system = galaxies[identity.galaxy]?.first(where: { $0.id == identity.system })
        else { throw SaveError.invalidCommander }
        return .init(system: system, galaxy: identity.galaxy)
      }
    try ledger.migratePresence(current: current, historical: historical)
    commander.miningLedger = ledger
  }

  /// Loading rebuilds derived field geometry from saved anchors without entering a new visit.
  mutating func rebuildMiningFields() {
    guard let anchors = commander.flightSimulation.anchors else {
      miningFields = []
      return
    }
    let presence = resolvedMiningPresence
    miningFields = MiningFields.generate(
      anchors: anchors, seed: gameplaySeed,
      ringPresent: presence.ringPresent, includingLegacy: presence.includingLegacy)
  }
}
