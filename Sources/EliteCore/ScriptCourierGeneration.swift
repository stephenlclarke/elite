import Foundation

public struct ScriptCourierReach: Codable, Sendable, Equatable {
  public let revision: String
  public let hull: String
  public let navigation: NavigationTier?
  public let storage: Int
  public let fuel: Int
  public let jumpCap: Double
  public let capacity: Int
  public let firstReach: Double
  public let jumpFuelMultiplier: Double?
  public let fullTankReach: Double?
  init(_ commander: Commander) {
    revision = "elite-canonical-native-reach-v2"
    hull = commander.shipID
    navigation = commander.navigationTier
    storage = commander.fuelStorageUnits
    fuel = commander.availableJumpFuel
    jumpCap = commander.jumpCap
    capacity = commander.fuelCapacity
    firstReach = commander.maximumJumpDistance
    jumpFuelMultiplier = commander.jumpFuelMultiplier
    fullTankReach = commander.fullTankJumpDistance
  }
  var laterReach: Double {
    fullTankReach ?? min(jumpCap, Double(capacity) / 10)
  }
  var valid: Bool {
    guard let ship = ShipCatalogue.ship(hull),
      let performance = ship.game, (0...FuelStorage.maximumCount).contains(storage),
      fuel >= 0, fuel <= capacity,
      capacity == performance.fuel + storage * FuelStorage.unitCapacity
    else { return false }
    switch revision {
    case "elite-880d3a-native-reach-v1":
      return jumpFuelMultiplier == nil && fullTankReach == nil
        && jumpCap == max(performance.jump, navigation?.jumpCap ?? 0)
        && firstReach == min(jumpCap, Double(fuel) / 10)
    case "elite-canonical-native-reach-v2":
      guard let multiplier = jumpFuelMultiplier, let fullTankReach,
        multiplier.isFinite, multiplier >= 0, jumpCap.isFinite, jumpCap >= performance.jump,
        firstReach.isFinite, fullTankReach.isFinite, fullTankReach > 0
      else { return false }
      let first = multiplier > 0 ? Double(fuel) / (10 * multiplier) : jumpCap
      let full = multiplier > 0 ? Double(capacity) / (10 * multiplier) : jumpCap
      return firstReach == min(jumpCap, first) && fullTankReach == min(jumpCap, full)
    default:
      return false
    }
  }
}

public struct ScriptCourierGeneration: Codable, Sendable, Equatable {
  public let revision: Int
  public let origin: ContractStationIdentity
  public let reach: ScriptCourierReach
  public let initialState: UInt32
  public let finalState: UInt32
  public let paths: [[Int]]
  public let draws: [UInt32]
  public let indices: [Int]
  static func next(_ state: inout UInt32) -> UInt32 {
    if state == 0 { state = 0x6D2B_79F5 }
    state ^= state << 13
    state ^= state >> 17
    state ^= state << 5
    return state
  }
  static func routes(origin: ContractStationIdentity, reach: ScriptCourierReach) -> [[Int]] {
    guard origin.valid, origin.system < 256, reach.valid else { return [] }
    let systems = Universe.systemsIncludingPlugh(number: origin.galaxy)
    var queue = [[origin.system]]
    var cursor = 0
    var visited: Set<Int> = [origin.system]
    while cursor < queue.count {
      let path = queue[cursor]
      cursor += 1
      guard path.count < 4 else { continue }
      let cap = path.count == 1 ? reach.firstReach : reach.laterReach
      for id in 0..<256 where !visited.contains(id) {
        if systems[path.last!].distance(to: systems[id]) <= cap {
          visited.insert(id)
          queue.append(path + [id])
        }
      }
    }
    return queue.dropFirst().sorted { $0.last! < $1.last! }
  }
  init(origin: ContractStationIdentity, commander: Commander, seed: UInt64) throws {
    revision = 1
    self.origin = origin
    reach = .init(commander)
    paths = Self.routes(origin: origin, reach: reach)
    guard !paths.isEmpty else {
      throw MissionPackError("No ordinary destination within three native jumps. Refuel or refit.")
    }
    initialState = Game.pledgeProfileSeed(seed)
    var state = initialState
    var values: [UInt32] = []
    var selected: [Int] = []
    for _ in 0..<6 {
      let draw = Self.next(&state)
      values.append(draw)
      selected.append(Int(floor(Double(draw) / 4294967296.0 * Double(paths.count))))
    }
    draws = values
    indices = selected
    finalState = state
  }
  func path(for row: Int) -> [Int]? {
    guard indices.indices.contains(row), paths.indices.contains(indices[row]) else { return nil }
    return paths[indices[row]]
  }
  func calendarCost(_ path: [Int]) -> Double {
    guard (2...4).contains(path.count), path.allSatisfy({ (0..<256).contains($0) }),
      origin.valid
    else { return .infinity }
    let systems = Universe.systemsIncludingPlugh(number: origin.galaxy)
    return zip(path, path.dropFirst()).reduce(0) { total, edge in
      let distance = systems[edge.0].scriptCalendarDistance(to: systems[edge.1])
      return total + 600 + distance * distance * 3600
    }
  }
  var valid: Bool {
    guard revision == 1, origin.valid, origin.system < 256, reach.valid,
      initialState != 0, draws.count == 6, indices.count == 6,
      (1...255).contains(paths.count),
      paths.allSatisfy({
        (2...4).contains($0.count) && $0.first == origin.system
          && $0.allSatisfy { (0..<256).contains($0) } && Set($0).count == $0.count
      }), paths == Self.routes(origin: origin, reach: reach)
    else { return false }
    var state = initialState
    for row in 0..<6 {
      guard draws[row] == Self.next(&state),
        indices[row] == Int(floor(Double(draws[row]) / 4294967296.0 * Double(paths.count)))
      else { return false }
    }
    return finalState == state
  }
  func terms(_ declaration: ScriptCourierDefinition, row: Int) -> ScriptCourierTerms {
    .init(
      declaration: declaration, capabilities: ScriptCourierTerms.requiredCapabilities.sorted(),
      generation: self, row: row, calendarLowerBoundSeconds: calendarCost(path(for: row) ?? []))
  }
  func plan(_ declaration: ScriptCourierDefinition) -> ScriptValue {
    let systems = Universe.systemsIncludingPlugh(number: origin.galaxy)
    return .array(
      OriginalSealedDispatch.rows(declaration).map { row in
        let terms = terms(declaration, row: row)
        return .object([
          "key": .string(terms.key), "difficulty": .integer(Int64(terms.difficulty)),
          "variant": .string(terms.variant.rawValue),
          "name": .string(systems[terms.destination].name),
          "destination": .integer(Int64(terms.destination)),
          "reward": .integer(Int64(terms.reward)),
          "duration": .number(terms.duration),
        ])
      })
  }
}
