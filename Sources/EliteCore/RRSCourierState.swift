import Foundation

struct RRSCourierBoard: Codable, Sendable, Equatable {
  let station: NativeStationIdentity
  let hour: Int64
  let profile: String
  let seed: String
  var declined = false
  var accepted: UUID?
  var key: String { RRSCourierContent.boardKey(station, hour: hour) }
  var offer: UUID { RRSCourierContent.offerID(key) }
  init(station: NativeStationIdentity, hour: Int64) {
    self.station = station
    self.hour = hour
    profile = RRSCourierContent.profile
    seed = RRSCourierContent.seed(RRSCourierContent.boardKey(station, hour: hour))
  }
  var valid: Bool {
    station.valid && (0...277_777_777).contains(hour)
      && profile == RRSCourierContent.profile && seed == RRSCourierContent.seed(key)
      && !(declined && accepted != nil) && (accepted == nil || accepted == offer)
      && (accepted == nil || RRSCourierContent.draw(seed) < 0.5)
  }
}

enum RRSCourierOutcome: String, Codable, Sendable {
  case delivered, departedSystem, newGalaxy, abandoned, originalMainDestroyed
  var reward: Int { self == .delivered ? 300 : 0 }
  var reputation: Int { self == .delivered ? 2 : -10 }
}

struct RRSCourierTerminal: Codable, Sendable, Equatable {
  let outcome: RRSCourierOutcome
  let calendarSeconds: Double
  let runtimeEpoch: UUID
  let system: SystemIdentity
  let arrival: NativeMainStationDockReceipt?
  var valid: Bool {
    calendarSeconds.isFinite && (0...1e12).contains(calendarSeconds)
      && (0..<8).contains(system.galaxy) && (0...256).contains(system.system)
      && (outcome == .delivered ? arrival?.valid == true : arrival == nil)
  }
}

/// Packet custody exists only in this closed ledger, never in tradable cargo or equipment.
struct RRSCourierJob: Codable, Sendable, Equatable {
  let board: RRSCourierBoard
  let origin: NativeStationDockReceipt
  let descriptor: NativeStationDescriptor
  let destination: NativeMainStationIdentity
  let acceptedAt: Double
  let acceptedLegal: Int
  let acceptedReputation: Int
  let acceptedEpoch: UUID
  let boardProfile: String
  let adapterRevision: String
  let geometryRevision: String
  let sourceSHA256: String
  let packet: UUID
  var terminal: RRSCourierTerminal?
  var id: UUID { board.offer }
  var carriesPacket: Bool { terminal == nil }
  var valid: Bool {
    guard board.valid, board.accepted == id, !board.declined,
      origin.station == board.station, origin.commanderOwner == board.station.world,
      origin.dockingBinding.valid(for: origin.station),
      origin.sequence > 0, origin.sequence < UInt64(Int64.max),
      origin.lifecycleRevision > 0, origin.lifecycleRevision < UInt64(Int64.max),
      let source = NativeStationSource.binding(for: origin.station),
      descriptor == source.descriptor,
      destination.valid, destination.world == origin.station.world,
      destination.system == origin.station.system,
      acceptedAt.isFinite, (0...1e12).contains(acceptedAt),
      (0...50).contains(acceptedLegal), acceptedReputation >= -10,
      NativeStationSource.boardHour(calendarSeconds: acceptedAt) == board.hour,
      boardProfile == NativeStationSource.boardRevision,
      adapterRevision == NativeStationSource.adapterRevision,
      geometryRevision == NativeStationGeometry.adapterRevision,
      sourceSHA256 == RRSCourierContent.source,
      packet == RRSCourierContent.packetID(id)
    else { return false }
    guard let terminal else { return true }
    guard terminal.valid, terminal.calendarSeconds >= acceptedAt else { return false }
    switch terminal.outcome {
    case .delivered:
      return terminal.system == destination.system && terminal.arrival?.station == destination
        && terminal.arrival?.commanderOwner == origin.commanderOwner
        && terminal.arrival!.calendarSeconds >= acceptedAt
        && terminal.arrival!.calendarSeconds <= terminal.calendarSeconds
    case .newGalaxy: return terminal.system.galaxy != destination.system.galaxy
    case .departedSystem:
      return terminal.system.galaxy == destination.system.galaxy
        && terminal.system != destination.system
    case .originalMainDestroyed: return terminal.system == destination.system
    case .abandoned: return true
    }
  }
}

struct RRSCourierLedger: Codable, Sendable, Equatable {
  let owner: UUID
  var boards: [String: RRSCourierBoard] = [:]
  var jobs: [RRSCourierJob] = []
  var active: RRSCourierJob? { jobs.first { $0.terminal == nil } }
  var completed: Int { jobs.filter { $0.terminal?.outcome == .delivered }.count }
  var failed: Int { jobs.filter { $0.terminal != nil && $0.terminal?.outcome != .delivered }.count }
  var reputation: Int { jobs.compactMap(\.terminal).reduce(0) { $0 + $1.outcome.reputation } }
  var valid: Bool {
    guard
      boards.count <= 372 && jobs.count <= 1024
        && Set(jobs.map(\.id)).count == jobs.count && Set(jobs.map(\.packet)).count == jobs.count
        && jobs.filter { $0.terminal == nil }.count <= 1
        && boards.allSatisfy({ key, board in
          key == board.station.key && board.valid && board.station.world == owner
            && (board.accepted.map { id in jobs.contains { $0.id == id && $0.board == board } }
              ?? true)
        })
        && jobs.allSatisfy({ $0.valid && $0.origin.commanderOwner == owner })
    else { return false }
    var reputation = 0
    var lastTerminal = 0.0
    for (index, job) in jobs.enumerated() {
      guard job.acceptedReputation == reputation, job.acceptedAt >= lastTerminal else {
        return false
      }
      if let terminal = job.terminal {
        reputation += terminal.outcome.reputation
        lastTerminal = terminal.calendarSeconds
      } else if index != jobs.count - 1 {
        return false
      }
    }
    return true
  }
  func valid(for commander: Commander) -> Bool {
    guard valid, commander.equipmentOwnerID == owner,
      let world = commander.nativeStations, world.ledger.world == owner
    else { return false }
    return boards.values.allSatisfy { board in
      world.ledger.records.contains {
        $0.identity == board.station && NativeStationSource.authentic($0, owner: owner)
      }
    }
      && jobs.allSatisfy { job in
        world.ledger.records.contains {
          $0.identity == job.origin.station && NativeStationSource.authentic($0, owner: owner)
        } && world.mainStations.contains(job.destination)
      }
  }
}
