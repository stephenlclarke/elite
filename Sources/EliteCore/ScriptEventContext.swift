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
  var nativeStation: NativeStationEventFacts? = nil
  var nativeMainDock: NativeMainStationDockReceipt? = nil
  var valid: Bool {
    (0..<8).contains(galaxy) && (0...256).contains(system)
      && (!mainStation || docked) && revision < UInt64(Int64.max)
      && [frameSeconds, localSeconds, flightSeconds, calendarSeconds, transitSeconds].allSatisfy {
        $0.isFinite && (0...1e12).contains($0)
      }
      && (playerPosition.map { $0.finite && $0.length <= 1e12 } ?? true)
      && (nativeStation.map {
        $0.valid && docked && !mainStation
          && $0.receipt.station.system == SystemIdentity(galaxy: galaxy, system: system)
      } ?? true)
      && (nativeMainDock.map {
        $0.valid && docked && mainStation
          && $0.station.system == SystemIdentity(galaxy: galaxy, system: system)
      } ?? true)
  }
  var value: ScriptValue {
    var fields: [String: ScriptValue] = [
      "galaxy": .integer(Int64(galaxy)), "system": .integer(Int64(system)),
      "docked": .bool(docked), "main_station": .bool(mainStation),
      "revision": .integer(Int64(revision)), "frame_seconds": .number(frameSeconds),
      "local_seconds": .number(localSeconds), "flight_seconds": .number(flightSeconds),
      "calendar_seconds": .number(calendarSeconds),
      "calendar_day": .integer(Int64(floor(calendarSeconds / 86400))),
      "transit_seconds": .number(transitSeconds),
      "player_position": playerPosition?.scriptVector ?? .null,
    ]
    if let nativeStation { fields["native_station"] = nativeStation.value }
    if let nativeMainDock {
      fields["native_main_arrival"] = .object([
        "world": .string(nativeMainDock.station.world.uuidString),
        "resource": .string(nativeMainDock.station.resource.uuidString),
        "station_key": .string(nativeMainDock.station.key),
        "docking_sequence": .integer(Int64(nativeMainDock.sequence)),
        "calendar_seconds": .number(nativeMainDock.calendarSeconds),
      ])
    }
    return .object(fields)
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

private struct ScriptEventContextScalars: Sendable {
  let galaxy: Int
  let system: Int
  let docked: Bool
  let mainStation: Bool
  let revision: UInt64
  let frameSeconds: Double
  let localSeconds: Double
  let flightSeconds: Double
  let calendarSeconds: Double
  let transitSeconds: Double
}

extension Game {
  func scriptEventContext(_ instance: borrowing ScriptInstance) -> ScriptEventContext {
    Self.scriptEventContext(in: self, revision: instance.revision)
  }

  @inline(never)
  static func scriptEventContext(in game: borrowing Game, revision: UInt64) -> ScriptEventContext {
    let scalars = scriptEventContextScalars(game, revision: revision)
    let playerPosition = scriptEventPlayerPosition(game)
    return finishScriptEventContext(game, scalars: scalars, playerPosition: playerPosition)
  }

  /// Scalar borrows return before anchor selection starts.
  @inline(never)
  private static func scriptEventContextScalars(
    _ game: borrowing Game, revision: UInt64
  ) -> ScriptEventContextScalars {
    let mainStation = game.dockedAtMainStation
    let frameTime = game.time
    return game.withReadOnlyCommander { commander in
      let galaxy = commander.galaxy
      let system = commander.system
      let docked = game.docked
      let atMainStation = game.docked && mainStation
      let frameSeconds = game.scriptStartupTime ?? frameTime
      return commander.withReadOnlyScriptState { state in
        .init(
          galaxy: galaxy, system: system, docked: docked,
          mainStation: atMainStation, revision: revision, frameSeconds: frameSeconds,
          localSeconds: state.localSeconds, flightSeconds: state.flightSeconds,
          calendarSeconds: state.calendarSeconds, transitSeconds: state.transitSeconds)
      }
    }
  }

  @inline(never)
  private static func scriptEventPlayerPosition(_ game: borrowing Game) -> Vector3? {
    game.scriptAnchor.map { $0.orientation.inverse($0.position * -1) }
  }

  /// Later native receipt buffers start only after the exact anchor transform returns.
  @inline(never)
  private static func finishScriptEventContext(
    _ game: borrowing Game, scalars: ScriptEventContextScalars, playerPosition: Vector3?
  ) -> ScriptEventContext {
    let nativeStation = game.nativeStationEventFacts
    let docked = game.docked
    let mainStation = game.dockedAtMainStation
    return .init(
      galaxy: scalars.galaxy, system: scalars.system, docked: scalars.docked,
      mainStation: scalars.mainStation, revision: scalars.revision,
      frameSeconds: scalars.frameSeconds, localSeconds: scalars.localSeconds,
      flightSeconds: scalars.flightSeconds, calendarSeconds: scalars.calendarSeconds,
      transitSeconds: scalars.transitSeconds, playerPosition: playerPosition,
      nativeStation: nativeStation,
      nativeMainDock: docked && mainStation
        ? game.withReadOnlyCommander { $0.nativeStations?.currentMainDock } : nil)
  }
}
