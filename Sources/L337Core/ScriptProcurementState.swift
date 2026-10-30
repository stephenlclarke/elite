import Foundation

struct ScriptProcurementCollectionTemplate: Codable, Sendable, Equatable {
  let id: String
  let title: String
  var valid: Bool {
    id == "procurement-goods" && (1...96).contains(title.utf8.count)
  }
}

struct ScriptProcurementDefinition: Codable, Sendable, Equatable {
  let profile: String
  let generatorRevision: Int
  let variant: String
  let deliveryContact: String
  let abandonContact: String
  let collectionTemplate: ScriptProcurementCollectionTemplate
  var valid: Bool {
    profile == ScriptProcurementPlan.profileID && (generatorRevision == 1 || generatorRevision == 2)
      && variant == "procurement" && deliveryContact == "procurement-delivery"
      && abandonContact == "procurement-abandon" && collectionTemplate.valid
  }
  static let capabilities: Set<String> = [
    "script-lua-v1", "story-v2", "durable-commands-v2", "contracts-basic-v2",
    "local-flight-clocks-v2", "partial-collections-v2", "mission-calendar-v2",
    "procurement-contracts-basic-v2",
  ]
}

struct ScriptProcurementContent: Codable, Sendable, Equatable {
  let provider: String
  let version: String
  let digest: String
  let stateID: String
  let boardID: String
  enum CodingKeys: String, CodingKey {
    case provider, version, digest
    case stateID = "state_id"
    case boardID = "board_id"
  }
  var valid: Bool {
    PackValidation.identifier(provider) && provider.utf8.count <= 80
      && PackValidation.version(version) && version.utf8.count <= 32
      && ScriptCompletionReceipt.validDigest(digest) && PackValidation.localID(boardID)
      && boardID.utf8.count <= 80 && stateID.hasPrefix(provider + "/")
      && stateID.utf8.count <= 161
      && stateID.split(separator: "/").count == 2
      && stateID.split(separator: "/").allSatisfy { PackValidation.identifier(String($0)) }
  }
}

/// This transient view uses existing parameters; it is never a new save authority field.
struct ScriptProcurementPlan: Codable, Sendable, Equatable {
  static let profileID = "PROJECT-SPACE-G03-1"
  static let group = "g03-procurement"
  static let commodities: [CommodityIdentity] = [.food, .textiles, .machinery]
  let profile: String
  let generatorRevision: Int
  let variant: String
  let content: ScriptProcurementContent
  let owner: UUID
  let boardRevision: Int64
  let seedHex: String
  let origin: ContractStationIdentity
  let reach: ScriptCourierReach
  let row: Int
  let initialState: UInt32
  let draws: [UInt32]
  let finalState: UInt32
  let routeIndex: Int
  let commodityIndex: Int
  let path: [Int]
  let calendarLowerBoundSeconds: Double
  let template: ScriptProcurementCollectionTemplate
  let deliveryContact: String
  let abandonContact: String
  let capabilities: [String]

  enum CodingKeys: String, CodingKey {
    case profile, variant, content, owner, origin, reach, row, draws, path, template, capabilities
    case generatorRevision = "generator_revision"
    case boardRevision = "board_revision"
    case seedHex = "seed_hex"
    case initialState = "initial_state"
    case finalState = "final_state"
    case routeIndex = "route_index"
    case commodityIndex = "commodity_index"
    case calendarLowerBoundSeconds = "calendar_lower_bound_seconds"
    case deliveryContact = "delivery_contact"
    case abandonContact = "abandon_contact"
  }
  var declaration: ScriptProcurementDefinition {
    .init(
      profile: profile, generatorRevision: generatorRevision, variant: variant,
      deliveryContact: deliveryContact, abandonContact: abandonContact, collectionTemplate: template
    )
  }
  var difficulty: Int { row + 1 }
  var key: String { "procurement-" + String(difficulty) }
  var quantity: Int { (0..<3).contains(row) ? [1, 5, 10][row] : 0 }
  var commodity: CommodityIdentity? {
    Self.commodities.indices.contains(commodityIndex) ? Self.commodities[commodityIndex] : nil
  }
  var reward: Int {
    guard (0..<3).contains(row), (2...4).contains(path.count) else { return 0 }
    return ([750, 1500, 2500][row] + 300 * (path.count - 1)) * 10
  }
  var duration: Double { Self.duration(row: row) }
  static func duration(row: Int) -> Double { row == 2 ? 259200 : 172800 }
  static func feasible(calendarCost: Double, row: Int) -> Bool {
    calendarCost.isFinite && calendarCost >= 0 && calendarCost < duration(row: row)
  }
  /// Revision 1 keeps its original pool even for unavailable deadline rows.
  /// Revision 2 filters before selection; saved plans always replay their own revision.
  static func candidatePaths(
    _ paths: [[Int]], galaxy: Int, row: Int, generatorRevision: Int
  ) -> [[Int]] {
    if generatorRevision == 1 { return paths }
    guard generatorRevision == 2, (0..<3).contains(row) else { return [] }
    let systems = Universe.systemsIncludingPlugh(number: galaxy)
    return paths.filter { feasible(calendarCost: calendarCost($0, systems: systems), row: row) }
  }
  func capacityFits(_ commander: Commander) -> Bool {
    guard let commodity, commander.cargo.count == CommodityIdentity.allCases.count,
      commander.cargo.allSatisfy({ (0...Int.max / 17).contains($0) }),
      ShipCatalogue.ship(commander.shipID)?.game != nil
    else { return false }
    let free = commander.standardCargoCapacity - commander.cargoTonnes
    let eligible = min(commander.sellableCargo(commodity.rawValue), quantity)
    let capacity = free.addingReportingOverflow(eligible)
    return free >= 0 && eligible >= 0 && !capacity.overflow && capacity.partialValue >= quantity
  }
  var collection: ScriptCollectionDefinition? {
    guard let commodity, let destination = path.last, quantity > 0 else { return nil }
    return .init(
      id: template.id, title: template.title, galaxy: origin.galaxy, system: destination,
      items: [.init(commodity: commodity.rawValue, unit: "t", quantity: quantity)])
  }
  var parameters: ScriptValue? {
    guard let bytes = try? JSONEncoder().encode(self),
      let value = try? JSONDecoder().decode(ScriptValue.self, from: bytes)
    else { return nil }
    return .object(["procurement": value])
  }
  static func read(_ parameters: ScriptValue) -> Self? {
    guard (try? ScriptWire.encode([parameters], limit: 4096)) != nil,
      let fields = parameters.object, Set(fields.keys) == ["procurement"],
      let value = fields["procurement"], let bytes = try? JSONEncoder().encode(value),
      let plan = try? JSONDecoder().decode(Self.self, from: bytes),
      plan.parameters == parameters, plan.structurallyValid
    else { return nil }
    return plan
  }
  static func isMarked(_ parameters: ScriptValue) -> Bool {
    parameters["procurement"]?["profile"]?.string == profileID
  }
  var structurallyValid: Bool {
    declaration.valid && content.valid && (0..<3).contains(row)
      && boardRevision >= 0 && boardRevision <= 1_000_000_000_000
      && seedHex.range(of: "^[0-9a-f]{16}$", options: .regularExpression) != nil
      && origin.valid && origin.system < 256
      && reach.revision == "elite-canonical-native-reach-v2" && reach.valid
      && initialState != 0 && draws.count == 6 && routeIndex >= 0 && routeIndex < 255
      && commodity != nil && (2...4).contains(path.count) && path.first == origin.system
      && path.allSatisfy { (0..<256).contains($0) } && Set(path).count == path.count
      && calendarLowerBoundSeconds.isFinite && calendarLowerBoundSeconds >= 0
      && (capabilities == ScriptProcurementDefinition.capabilities.sorted()
        || capabilities
          == ScriptProcurementDefinition.capabilities.union(["gallery-basic-v2"]).sorted())
  }
  /// Cold validation is also required by direct Commander/container validation.
  var valid: Bool {
    guard structurallyValid, let seed = UInt64(seedHex, radix: 16),
      initialState == Game.pledgeProfileSeed(seed)
    else { return false }
    var state = initialState
    for draw in draws where ScriptCourierGeneration.next(&state) != draw { return false }
    let routes = Self.candidatePaths(
      ScriptCourierGeneration.routes(origin: origin, reach: reach), galaxy: origin.galaxy,
      row: row, generatorRevision: generatorRevision)
    guard state == finalState, routes.indices.contains(routeIndex),
      routeIndex == Self.index(draws[row * 2], count: routes.count), path == routes[routeIndex],
      commodityIndex == Self.index(draws[row * 2 + 1], count: Self.commodities.count),
      calendarLowerBoundSeconds == Self.calendarCost(path, galaxy: origin.galaxy)
    else { return false }
    return true
  }
  static func index(_ draw: UInt32, count: Int) -> Int {
    Int(floor(Double(draw) / 4294967296.0 * Double(count)))
  }
  static func calendarCost(_ path: [Int], galaxy: Int) -> Double {
    calendarCost(path, systems: Universe.systemsIncludingPlugh(number: galaxy))
  }
  private static func calendarCost(_ path: [Int], systems: [StarSystem]) -> Double {
    return zip(path, path.dropFirst()).reduce(0) { value, edge in
      let distance = systems[edge.0].scriptCalendarDistance(to: systems[edge.1])
      return value + 600 + distance * distance * 3600
    }
  }
  func matches(_ offer: ScriptContractOffer) -> Bool {
    valid && offer.courier == nil && offer.key == key && offer.parameters == parameters
      && offer.destinationGalaxy == origin.galaxy && offer.destinationSystem == path.last
      && offer.reward == reward && offer.deposit == 0 && offer.failureReward == 0
      && !offer.refundOnFailure && offer.duration == duration
  }
  func matches(_ pack: ScriptPack) -> Bool {
    content.provider == pack.manifest.id && content.version == pack.manifest.version
      && content.digest == pack.digest && content.stateID == pack.manifest.stateID
      && content.boardID == pack.manifest.board?.id && declaration == pack.manifest.procurement
      && capabilities == pack.manifest.capabilities.sorted()
  }
}

extension ScriptPackLibrary {
  static func validateProcurement(_ manifest: ScriptManifest) throws {
    guard let definition = manifest.procurement else {
      guard !manifest.capabilities.contains("procurement-contracts-basic-v2") else {
        throw MissionPackError("Procurement requires its closed native declaration.")
      }
      return
    }
    let expected = ScriptProcurementDefinition.capabilities.union(
      manifest.trial == nil ? [] : ["gallery-basic-v2"])
    guard definition.valid, Set(manifest.capabilities) == expected,
      manifest.trial == nil || manifest.trial?.flight == true,
      manifest.courier == nil, manifest.freight == nil, manifest.pledge == nil,
      manifest.providerContract == nil,
      manifest.board?.clock == .missionCalendar, manifest.board?.period == 3600,
      manifest.board?.exclusiveGroup == ScriptProcurementPlan.group,
      manifest.mission.parentOnly != true, manifest.mission.milestones.count == 1,
      manifest.mission.requiredCollections == [definition.collectionTemplate.id],
      (manifest.collections ?? []).isEmpty, (manifest.children ?? []).isEmpty,
      (manifest.encounters ?? []).isEmpty, (manifest.equipment ?? []).isEmpty,
      (manifest.passengerParties ?? []).isEmpty, (manifest.loans ?? []).isEmpty,
      (manifest.worldJobs ?? []).isEmpty,
      manifest.dialogs?.count == 2,
      manifest.dialogs?.contains(where: {
        $0.id == definition.deliveryContact && $0.collection == definition.collectionTemplate.id
          && ($0.choices ?? []).isEmpty
      }) == true,
      manifest.dialogs?.contains(where: {
        $0.id == definition.abandonContact && $0.collection == nil && ($0.choices ?? []).isEmpty
      }) == true
    else {
      throw MissionPackError("Invalid closed procurement declaration or collection template.")
    }
  }
}
