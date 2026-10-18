import Foundation

struct ScriptFreightCollectionTemplate: Codable, Sendable, Equatable {
  let id: String
  let title: String
  var valid: Bool {
    id == "freight-goods" && (1...96).contains(title.utf8.count)
  }
}

struct ScriptFreightDefinition: Codable, Sendable, Equatable {
  let profile: String
  let generatorRevision: Int
  let variant: String
  let deliveryContact: String
  let abandonContact: String
  let collectionTemplate: ScriptFreightCollectionTemplate
  var valid: Bool {
    profile == ScriptFreightPlan.profileID && generatorRevision == 1
      && variant == "supplied" && deliveryContact == "freight-delivery"
      && abandonContact == "freight-abandon" && collectionTemplate.valid
  }
  static let capabilities: Set<String> = [
    "script-lua-v1", "story-v2", "durable-commands-v2", "contracts-basic-v2",
    "local-flight-clocks-v2", "partial-collections-v2", "mission-calendar-v2",
    "freight-contracts-basic-v2", "dialogue-choices-v2",
  ]
}

struct ScriptFreightContent: Codable, Sendable, Equatable {
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

/// Closed descriptive terms match bounded presentation parameters; issue authority is unencoded.
struct ScriptFreightPlan: Codable, Sendable, Equatable {
  static let profileID = "PROJECT-SPACE-G03-1"
  static let group = "g03-freight"
  static let commodities: [CommodityIdentity] = [.food, .textiles, .machinery]
  let profile: String
  let generatorRevision: Int
  let variant: String
  let content: ScriptFreightContent
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
  let template: ScriptFreightCollectionTemplate
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
  var declaration: ScriptFreightDefinition {
    .init(
      profile: profile, generatorRevision: generatorRevision, variant: variant,
      deliveryContact: deliveryContact, abandonContact: abandonContact, collectionTemplate: template
    )
  }
  var difficulty: Int { row + 1 }
  var key: String { "freight-" + String(difficulty) }
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
  /// Freeze the original sorted reach pool before the six freight draws.
  static func candidatePaths(
    _ paths: [[Int]], galaxy: Int, row: Int, generatorRevision: Int
  ) -> [[Int]] {
    guard generatorRevision == 1, (0..<3).contains(row) else { return [] }
    return paths.filter { feasible(calendarCost: calendarCost($0, galaxy: galaxy), row: row) }
  }
  func capacityFits(_ commander: Commander) -> Bool {
    guard commodity != nil, commander.cargo.count == CommodityIdentity.allCases.count,
      commander.cargo.allSatisfy({ (0...Int.max / 17).contains($0) }),
      ShipCatalogue.ship(commander.shipID)?.game != nil
    else { return false }
    guard let occupied = commander.checkedCargoTonnes else { return false }
    return occupied <= commander.standardCargoCapacity
      && quantity <= commander.standardCargoCapacity - occupied
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
    return .object(["freight": value])
  }
  static func read(_ parameters: ScriptValue) -> Self? {
    guard (try? ScriptWire.encode([parameters], limit: 4096)) != nil,
      let fields = parameters.object, Set(fields.keys) == ["freight"],
      let value = fields["freight"], let bytes = try? JSONEncoder().encode(value),
      let plan = try? JSONDecoder().decode(Self.self, from: bytes),
      plan.parameters == parameters, plan.structurallyValid
    else { return nil }
    return plan
  }
  static func isMarked(_ parameters: ScriptValue) -> Bool {
    parameters["freight"]?["profile"]?.string == profileID
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
      && (capabilities == ScriptFreightDefinition.capabilities.sorted()
        || capabilities
          == ScriptFreightDefinition.capabilities.union(["gallery-basic-v2"]).sorted())
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
    valid && offer.courier == nil && offer.freightPlan == self && offer.key == key
      && offer.parameters == parameters
      && offer.destinationGalaxy == origin.galaxy && offer.destinationSystem == path.last
      && offer.reward == reward && offer.deposit == 0 && offer.failureReward == 0
      && !offer.refundOnFailure && offer.duration == duration
  }
  func matches(_ pack: ScriptPack) -> Bool {
    content.provider == pack.manifest.id && content.version == pack.manifest.version
      && content.digest == pack.digest && content.stateID == pack.manifest.stateID
      && content.boardID == pack.manifest.board?.id && declaration == pack.manifest.freight
      && capabilities == pack.manifest.capabilities.sorted()
  }
}

struct ScriptFreightGeneration: Codable, Sendable, Equatable {
  let plans: [ScriptFreightPlan]
  let holdCapacity: Int

  static func plans(
    pack: ScriptPack, commander: Commander, origin: ContractStationIdentity,
    revision: Int64, seed: UInt64
  ) throws -> [ScriptFreightPlan] {
    try ScriptPackLibrary.validateFreight(pack.manifest)
    guard let declaration = pack.manifest.freight, let owner = commander.equipmentOwnerID,
      let board = pack.manifest.board
    else { throw MissionPackError("Freight requires a current native owner and provider.") }
    let reach = ScriptCourierReach(commander)
    let paths = ScriptCourierGeneration.routes(origin: origin, reach: reach)
    let candidates = (0..<3).map { row in
      ScriptFreightPlan.candidatePaths(
        paths, galaxy: origin.galaxy, row: row, generatorRevision: declaration.generatorRevision)
    }
    guard candidates.allSatisfy({ !$0.isEmpty }) else {
      throw MissionPackError("No native freight route fits every required tier's deadline.")
    }
    let initial = Game.pledgeProfileSeed(seed)
    var state = initial
    let draws = (0..<6).map { _ in ScriptCourierGeneration.next(&state) }
    return (0..<3).map { row in
      let paths = candidates[row]
      let index = ScriptFreightPlan.index(draws[row * 2], count: paths.count)
      return .init(
        profile: declaration.profile, generatorRevision: declaration.generatorRevision,
        variant: declaration.variant,
        content: .init(
          provider: pack.manifest.id, version: pack.manifest.version, digest: pack.digest,
          stateID: pack.manifest.stateID, boardID: board.id), owner: owner,
        boardRevision: revision, seedHex: String(format: "%016llx", seed), origin: origin,
        reach: reach, row: row, initialState: initial, draws: draws, finalState: state,
        routeIndex: index,
        commodityIndex: ScriptFreightPlan.index(draws[row * 2 + 1], count: 3),
        path: paths[index],
        calendarLowerBoundSeconds: ScriptFreightPlan.calendarCost(
          paths[index], galaxy: origin.galaxy),
        template: declaration.collectionTemplate, deliveryContact: declaration.deliveryContact,
        abandonContact: declaration.abandonContact,
        capabilities: pack.manifest.capabilities.sorted())
    }
  }
  static func value(_ plans: [ScriptFreightPlan]) throws -> ScriptValue {
    .array(
      try plans.map { plan in
        guard let parameters = plan.parameters else { throw SaveError.invalidCommander }
        _ = try ScriptWire.encode([parameters], limit: 4096)
        return .object([
          "key": .string(plan.key), "difficulty": .integer(Int64(plan.difficulty)),
          "commodity": .integer(Int64(plan.commodity!.rawValue)),
          "quantity": .integer(Int64(plan.quantity)),
          "destination": .integer(Int64(plan.path.last!)),
          "reward": .integer(Int64(plan.reward)), "duration": .number(plan.duration),
          "parameters": parameters,
        ])
      })
  }
  static func valid(_ board: ScriptContractBoard) -> Bool {
    guard let generation = board.freightGeneration, generation.plans.count == 3,
      (0...Int.max / 17).contains(generation.holdCapacity),
      board.offers.count
        == generation.plans.filter({ $0.quantity <= generation.holdCapacity }).count,
      board.courierGeneration == nil, board.clock == .missionCalendar, board.period == 3600,
      board.group == board.provider + "/" + ScriptFreightPlan.group,
      !board.offers.isEmpty,
      (1...160).contains(board.title.count), board.offers.allSatisfy(\.valid),
      Set(board.offers.map(\.id)).count == board.offers.count,
      Set(board.offers.map(\.key)).count == board.offers.count,
      let seed = Game.pledgeBoardSeed(board.cacheKey, revision: board.revision),
      seed == board.seed
    else { return false }
    guard
      generation.plans.enumerated().allSatisfy({ index, plan in
        plan.valid && plan.row == index && plan.origin == board.station
          && plan.boardRevision == board.revision && plan.seedHex == String(format: "%016llx", seed)
          && plan.content.provider == board.provider && plan.content.version == board.version
          && plan.content.digest == board.digest && plan.content.boardID == board.id
          && plan.owner == generation.plans[0].owner && plan.reach == generation.plans[0].reach
          && plan.draws == generation.plans[0].draws && plan.content == generation.plans[0].content
          && plan.declaration == generation.plans[0].declaration
          && plan.capabilities == generation.plans[0].capabilities
      })
    else { return false }
    var first: ScriptFreightPlan?
    for (row, offer) in board.offers.enumerated() {
      guard let plan = offer.freightPlan, ScriptFreightPlan.read(offer.parameters) == plan,
        plan.matches(offer),
        plan.row == row, generation.plans[row] == plan, plan.origin == board.station,
        plan.boardRevision == board.revision,
        plan.content.provider == board.provider, plan.content.version == board.version,
        plan.content.digest == board.digest, plan.content.boardID == board.id,
        plan.seedHex == String(format: "%016llx", seed),
        offer.id
          == ScriptIdentity.uuid(
            "contract-offer-v1:\(board.cacheKey):\(board.revision):\(offer.key)")
      else { return false }
      if let first {
        guard first.owner == plan.owner, first.reach == plan.reach, first.draws == plan.draws,
          first.content == plan.content, first.declaration == plan.declaration,
          first.capabilities == plan.capabilities
        else { return false }
      } else {
        first = plan
      }
    }
    return true
  }
  static func valid(_ job: ScriptContractJob) -> Bool {
    guard job.offer.valid, let plan = job.offer.freightPlan,
      ScriptFreightPlan.read(job.offer.parameters) == plan,
      plan.matches(job.offer),
      job.clock == .missionCalendar, job.deadlinePolicy == .inclusiveConfirmation,
      job.station == plan.origin, job.boardRevision == plan.boardRevision,
      job.provider == plan.content.provider, job.version == plan.content.version,
      job.digest == plan.content.digest,
      job.boardKey == plan.content.digest + "/" + plan.content.boardID + "/" + plan.origin.key,
      job.group == job.provider + "/" + ScriptFreightPlan.group,
      let seed = Game.pledgeBoardSeed(job.boardKey, revision: job.boardRevision),
      plan.seedHex == String(format: "%016llx", seed),
      plan.calendarLowerBoundSeconds < plan.duration,
      job.offer.id
        == ScriptIdentity.uuid(
          "contract-offer-v1:\(job.boardKey):\(job.boardRevision):\(job.offer.key)")
    else { return false }
    guard job.offer.status == .available, job.acceptedAt.isFinite,
      (0...1e12).contains(job.acceptedAt), job.acceptedAt <= 1e12 - plan.duration,
      job.deadline == job.acceptedAt + plan.duration,
      job.settlementOutcome != .active
    else { return false }
    if !job.settled {
      return job.settlementOutcome == nil && job.settlementAmount == nil && job.settledAt == nil
    }
    guard let outcome = job.settlementOutcome, let amount = job.settlementAmount,
      let at = job.settledAt, at.isFinite, at >= job.acceptedAt, at <= 1e12,
      amount == (outcome == .complete ? plan.reward : 0),
      outcome != .complete || at <= job.deadline!
    else { return false }
    return true
  }
}

extension ScriptPackLibrary {
  static func validateFreight(_ manifest: ScriptManifest) throws {
    guard let definition = manifest.freight else {
      guard !manifest.capabilities.contains("freight-contracts-basic-v2") else {
        throw MissionPackError("Freight requires its closed native declaration.")
      }
      return
    }
    let expected = ScriptFreightDefinition.capabilities.union(
      manifest.trial == nil ? [] : ["gallery-basic-v2"])
    guard definition.valid, Set(manifest.capabilities) == expected,
      manifest.trial == nil || manifest.trial?.flight == true,
      manifest.courier == nil, manifest.procurement == nil, manifest.pledge == nil,
      manifest.providerContract == nil,
      manifest.board?.clock == .missionCalendar, manifest.board?.period == 3600,
      manifest.board?.exclusiveGroup == ScriptFreightPlan.group,
      manifest.mission.parentOnly != true, manifest.mission.milestones.count == 1,
      manifest.mission.requiredCollections == [definition.collectionTemplate.id],
      (manifest.collections ?? []).isEmpty, (manifest.children ?? []).isEmpty,
      (manifest.encounters ?? []).isEmpty, (manifest.equipment ?? []).isEmpty,
      (manifest.passengerParties ?? []).isEmpty, (manifest.loans ?? []).isEmpty,
      (manifest.worldJobs ?? []).isEmpty,
      (manifest.npcs ?? []).isEmpty, (manifest.models ?? []).isEmpty,
      (manifest.modules ?? []).isEmpty, (manifest.books ?? []).isEmpty,
      (manifest.receiptRequirements ?? []).isEmpty, (manifest.answerRequirements ?? []).isEmpty,
      (manifest.mission.requiredChoiceGroups ?? []).isEmpty,
      (manifest.mission.requiredBooks ?? []).isEmpty,
      (manifest.mission.requiredDestructionEncounters ?? []).isEmpty,
      (manifest.mission.requiredPassengerParties ?? []).isEmpty,
      (manifest.mission.requiredEquipmentReturns ?? []).isEmpty,
      manifest.dialogs?.count == 2,
      manifest.dialogs?.contains(where: {
        $0.id == definition.deliveryContact && $0.collection == definition.collectionTemplate.id
          && ($0.choices ?? []).map(\.id) == ["freight-one", "freight-all"]
          && ($0.choices ?? []).allSatisfy { $0.group == nil }
      }) == true,
      manifest.dialogs?.contains(where: {
        $0.id == definition.abandonContact && $0.collection == nil && ($0.choices ?? []).isEmpty
      }) == true
    else {
      throw MissionPackError("Invalid closed freight declaration or collection template.")
    }
  }
}
