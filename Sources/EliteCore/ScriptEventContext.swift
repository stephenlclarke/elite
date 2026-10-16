import Foundation

/// Native facts captured when an envelope is emitted, distinct from the current query snapshot.
public struct ScriptEventContext: Codable, Sendable, Equatable {
  public let galaxy: Int
  public let system: Int
  public let docked: Bool
  public let mainStation: Bool
  public let revision: UInt64
  public let frameSeconds: Double
  public let localSeconds: Double
  public let flightSeconds: Double
  public let calendarSeconds: Double
  public let transitSeconds: Double
  public let playerPosition: Vector3?
  var valid: Bool {
    (0..<8).contains(galaxy) && (0...256).contains(system)
      && (!mainStation || docked) && revision < UInt64(Int64.max)
      && [frameSeconds, localSeconds, flightSeconds, calendarSeconds, transitSeconds].allSatisfy {
        $0.isFinite && (0...1e12).contains($0)
      }
      && (playerPosition.map { $0.finite && $0.length <= 1e12 } ?? true)
  }
  var value: ScriptValue {
    .object([
      "galaxy": .integer(Int64(galaxy)), "system": .integer(Int64(system)),
      "docked": .bool(docked), "main_station": .bool(mainStation),
      "revision": .integer(Int64(revision)), "frame_seconds": .number(frameSeconds),
      "local_seconds": .number(localSeconds), "flight_seconds": .number(flightSeconds),
      "calendar_seconds": .number(calendarSeconds),
      "calendar_day": .integer(Int64(floor(calendarSeconds / 86400))),
      "transit_seconds": .number(transitSeconds),
      "player_position": playerPosition?.scriptVector ?? .null,
    ])
  }
}

extension ScriptInstance {
  func hasAcknowledged(_ sequence: UInt64) -> Bool {
    sequence <= (acknowledgedThrough ?? 0) || acknowledgedEvents.contains(sequence)
  }
  mutating func acknowledge(_ sequence: UInt64) {
    acknowledgedThrough = max(
      sequence, max(acknowledgedThrough ?? 0, acknowledgedEvents.max() ?? 0))
    acknowledgedEvents.removeAll(keepingCapacity: false)
  }
}

extension Game {
  func scriptEventContext(_ instance: ScriptInstance) -> ScriptEventContext {
    .init(
      galaxy: commander.galaxy, system: commander.system, docked: docked,
      mainStation: docked && dockedAtMainStation, revision: instance.revision,
      frameSeconds: scriptStartupTime ?? time, localSeconds: commander.scriptState.localSeconds,
      flightSeconds: commander.scriptState.flightSeconds,
      calendarSeconds: commander.scriptState.calendarSeconds,
      transitSeconds: commander.scriptState.transitSeconds,
      playerPosition: scriptAnchor.map { $0.orientation.inverse($0.position * -1) })
  }
}
