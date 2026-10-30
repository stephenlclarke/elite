import Foundation
import Testing

@testable import L337Core

private struct NativeColdChainFixture {
  let files: ScriptFreightFixture
  let pack: ScriptPack
  let route: [Int]
  var save: URL { files.save }

  init(
    units: Int = 2, allowance: Double = 3600, quietReceiverRoute: Bool = false,
    manifestEdit: ((String) -> String)? = nil
  ) throws {
    let original = try ScriptFreightFixture()
    files = original
    var ready = false
    defer { if !ready { original.clean() } }
    var game = try ScriptProcurementFixture.freshG03FlightGame()
    try game.commander.prepareEquipment(legacy: false)
    game.commander.mirrorFittedEquipment()
    let paths = ScriptCourierGeneration.routes(
      origin: game.contractStation, reach: ScriptCourierReach(game.commander))
    if quietReceiverRoute {
      let governments = game.systems.map(\.government)
      let outbound = try #require(paths.first { $0 == [7, 185] })
      let reach = ScriptCourierReach(game.commander)
      let fullTankReach = try #require(reach.fullTankReach)
      try #require(reach.firstReach == fullTankReach)
      try #require(governments[outbound[1]] == 5 && governments[outbound[0]] == 7)
      let returnOrigin = ContractStationIdentity(
        galaxy: game.commander.galaxy, system: outbound[1], stationClass: "main-orbital")
      let returns = ScriptCourierGeneration.routes(origin: returnOrigin, reach: reach)
      try #require(returns.contains([outbound[1], outbound[0]]))
      // Declare both independently admitted native legs before writing or loading this pack.
      route = outbound + [outbound[0]]
    } else {
      route = try #require(paths.first { $0.count == 3 })
    }
    let folder = original.root.appendingPathComponent("native-cold-chain")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    var manifest = """
      schemaVersion = 2
      missionAPI = 2
      id = "l337.wayfarer-service"
      version = "1.0.0"
      minimumEngine = "2.0.0"
      capabilities = ["script-lua-v1", "story-v2", "durable-commands-v2", "local-flight-clocks-v2"]
      priority = 1
      source = "Explicit unit fixture native stock and quotation; not production tuning."
      license = "MIT"
      environments = ["space", "orbital-station"]
      module = "main.lua"
      [mission]
      id = "cold-chain"
      title = "Native sealed medical sample"
      briefing = "Original stock, actual objective and actual receiver."
      destination = "Declared actual native receiver"
      reward = "320 CR + 85 CR per full quoted leg + 90 CR per declared hazard tier."
      milestones = ["Original viable sample received"]
      [coldChain]
      batch = "fixture-original-batch"
      stockUnits = \(units)
      tonnes = 1
      maximumActive = 3
      route = [\(route.map(String.init).joined(separator: ", "))]
      hazardTier = 1
      flightAllowance = \(allowance)
      rewardNative = \(3200 + 850 * (route.count - 1) + 900)
      [coldChain.source]
      galaxy = 0
      system = \(route[0])
      resourceKey = "main-orbital:0:\(route[0])"
      [coldChain.objective]
      galaxy = 0
      system = \(route[1])
      resourceKey = "main-orbital:0:\(route[1])"
      [coldChain.receiver]
      galaxy = 0
      system = \(route[2])
      resourceKey = "main-orbital:0:\(route[2])"
      [[handlers]]
      event = "timer.fired"
      function = "expire"
      """
    if let manifestEdit { manifest = manifestEdit(manifest) }
    try manifest.write(
      to: folder.appendingPathComponent("manifest.toml"), atomically: true, encoding: .utf8)
    let script = """
      return {
        expire = function(e, w, d)
          return {data = d, commands = {{op = "cold-chain.expire"}}}
        end
      }
      """
    try script.write(
      to: folder.appendingPathComponent("main.lua"), atomically: true, encoding: .utf8)
    pack = try ScriptPackLibrary.read(folder)
    ready = true
  }

  func runtime(escapeReady: Bool = false, scoopsReady: Bool = false) async throws -> GameRuntime {
    var game = try ScriptProcurementFixture.freshG03FlightGame(escapeReady: escapeReady)
    if scoopsReady { game.commander.credits = 178_625 }
    game.scriptPacks = [pack]
    try game.prepareG03FlightEquipment()
    if escapeReady {
      let pod = try #require(Equipment.all.first { $0.name == "Escape Pod" })
      let quote = try game.quoteEquipmentPurchase(pod)
      let fitted = try game.applyEquipmentPurchase(quote)
      try #require(fitted)
    }
    if scoopsReady {
      let scoops = try #require(Equipment.all.first { $0.name == "Fuel Scoops" })
      let quote = try game.quoteEquipmentPurchase(scoops)
      let fitted = try game.applyEquipmentPurchase(quote)
      try #require(fitted)
      try #require(
        game.commander.fittedEquipment(at: .utility(.fuelScoops))?.id == quote.request.newItem)
    }
    let runtime = GameRuntime(game: game, saveURL: save)
    try await runtime.save(to: save)
    await runtime.key("0")
    try await ScriptProcurementFixture.dock(runtime)
    return runtime
  }

  func pickup(_ runtime: GameRuntime) async throws -> (String, UUID) {
    let source = try await runtime.initializeWayfarerColdChainStock(packDigest: pack.digest)
    let quote = try await runtime.wayfarerColdChainQuote(sourceID: source)
    let id = try await runtime.pickUpWayfarerColdChain(sourceID: source, quotedOfferID: quote.id)
    return (source, id)
  }

  func atObjective(_ runtime: GameRuntime, id: UUID) async throws {
    try await ScriptProcurementFixture.travel(
      runtime, path: Array(route.prefix(2)), verifyDeparture: true)
    try await runtime.confirmWayfarerColdChainObjective(instance: id)
  }

  func atReceiver(_ runtime: GameRuntime) async throws {
    // Separate two-stop travel calls require the actual paid refuel at their turnaround dock.
    try await runtime.procurementRefuelForTurnaround(expectedSystem: route[1])
    try await ScriptProcurementFixture.travel(
      runtime, path: Array(route.suffix(2)), defensivePreflight: true, verifyDeparture: true)
  }

  /// Alter a rehashed real missions chunk, then restore the exact original files.
  func rejectCorruption(_ change: (inout [String: Any]) throws -> Void) throws {
    let pointerBytes = try Data(contentsOf: save)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    let folder = try ScriptSaveStore.generationDirectory(pointer.generation, from: save)
    let file = folder.appendingPathComponent("missions.json")
    let original = try Data(contentsOf: file)
    defer {
      try? original.write(to: file)
      try? pointerBytes.write(to: save)
    }
    var root = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
    try change(&root)
    let bytes = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
    try bytes.write(to: file)
    var hashes = pointer.hashes
    hashes["missions.json"] = ScriptPackLibrary.hash(bytes)
    let changed = ScriptSavePointer(
      format: pointer.format, schemaVersion: pointer.schemaVersion, generation: pointer.generation,
      hashes: hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
    try JSONEncoder().encode(changed).write(to: save)
    #expect(throws: (any Error).self) {
      _ = try ScriptSaveStore.read(Data(contentsOf: save), from: save)
    }
  }

  static func mutateInstance(
    _ id: UUID, root: inout [String: Any], change: (inout [String: Any]) throws -> Void
  ) throws {
    if var instances = root["instances"] as? [String: Any] {
      let key = try #require(instances.keys.first { UUID(uuidString: $0) == id })
      var instance = try #require(instances[key] as? [String: Any])
      try change(&instance)
      instances[key] = instance
      root["instances"] = instances
    } else {
      var pairs = try #require(root["instances"] as? [Any])
      let index = try #require(
        stride(from: 0, to: pairs.count, by: 2).first {
          (pairs[$0] as? String).flatMap(UUID.init(uuidString:)) == id
        })
      var instance = try #require(pairs[index + 1] as? [String: Any])
      try change(&instance)
      pairs[index + 1] = instance
      root["instances"] = pairs
    }
  }

  static func checkTerminalAnchors(_ state: ScriptInstance) throws {
    let custody = try #require(state.savedWayfarerColdChain)
    let terminal = try #require(custody.integrity.terminal)
    let context: ScriptEventContext
    switch terminal {
    case .received: context = try #require(state.completionReceipt?.cause)
    case .spoiled(let receipt): context = receipt.context
    }
    func matches(
      timer: ScriptTimer, allowance: Double, sequence: UInt64, issued: Double,
      context: ScriptEventContext
    ) -> Bool {
      custody.integrity.matchesNativeState(
        timer: timer, allowance: allowance, issueSequence: sequence,
        issuedFlightSeconds: issued, lastContext: context)
    }
    let original = custody.timer
    let allowance = custody.definition.flightAllowance
    let sequence = custody.issue.sequence
    let issued = custody.issue.context.flightSeconds
    #expect(
      matches(
        timer: original, allowance: allowance, sequence: sequence, issued: issued, context: context)
    )
    var foreign = original
    foreign.id = "foreign-original-timer"
    #expect(
      !matches(
        timer: foreign, allowance: allowance, sequence: sequence, issued: issued, context: context))
    foreign = original
    foreign.due += 1
    #expect(
      !matches(
        timer: foreign, allowance: allowance, sequence: sequence, issued: issued, context: context))
    #expect(
      !matches(
        timer: original, allowance: allowance + 1, sequence: sequence, issued: issued,
        context: context))
    #expect(
      !matches(
        timer: original, allowance: allowance, sequence: sequence + 1, issued: issued,
        context: context))
    #expect(
      !matches(
        timer: original, allowance: allowance, sequence: sequence, issued: issued + 1,
        context: context))
    #expect(
      !matches(
        timer: original, allowance: allowance, sequence: sequence, issued: issued,
        context: custody.issue.context))
  }
}

@Test func nativeColdChainRealLoaderRejectsInventedOrIncompleteTerms() throws {
  let edits: [(String) -> String] = [
    { $0.replacingOccurrences(of: "tonnes = 1", with: "tonnes = 0") },
    { $0.replacingOccurrences(of: "main-orbital:0:7", with: "main-orbital:0:8") },
    { $0.replacingOccurrences(of: "hazardTier = 1", with: "hazardTier = 9223372036854775807") },
    { $0.replacingOccurrences(of: "maximumActive = 3", with: "maximumActive = 4") },
    { $0.replacingOccurrences(of: "hazardTier = 1", with: "hazardTier = -1") },
    { $0.replacingOccurrences(of: "flightAllowance = 3600.0", with: "flightAllowance = 0.0") },
    { $0.replacingOccurrences(of: "batch = \"fixture-original-batch\"", with: "unknown = 1") },
    { $0.replacingOccurrences(of: "rewardNative = 5800", with: "rewardNative = 5801") },
  ]
  for edit in edits {
    #expect(throws: (any Error).self) { try NativeColdChainFixture(manifestEdit: edit) }
  }
}

@Test func nativeColdChainSourceInitializationPersistsBeforeAnyMissionAndNeverRefills() async throws
{
  let fixture = try NativeColdChainFixture()
  defer { fixture.files.clean() }
  let runtime = try await fixture.runtime()
  let before = await runtime.snapshot()
  #expect(before.commander.scriptState.instances.isEmpty)
  let parent = fixture.save.deletingLastPathComponent()
  let files = try ScriptFinanceTestFixture.files(parent)
  let preserved = try fixture.files.blockWrites("stock-init")
  await #expect(throws: (any Error).self) {
    try await runtime.initializeWayfarerColdChainStock(packDigest: fixture.pack.digest)
  }
  let refused = await runtime.snapshot()
  #expect(refused.commander == before.commander)
  try fixture.files.restoreWrites(preserved, files: files)
  let source = try await runtime.initializeWayfarerColdChainStock(packDigest: fixture.pack.digest)
  let initialized = await runtime.snapshot()
  #expect(initialized.commander.scriptState.instances.isEmpty)
  #expect(
    initialized.commander.scriptState.savedWayfarerColdChainStock?.sources[source]?.units.count == 2
  )
  let bytes = try Data(contentsOf: fixture.save)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
  #expect(pointer.schemaVersion == 35)
  let (cold, world) = try ScriptSaveStore.read(bytes, from: fixture.save)
  #expect(
    cold.scriptState.savedWayfarerColdChainStock
      == initialized.commander.scriptState.savedWayfarerColdChainStock)
  #expect(world.consistent(with: cold))
  let repeated = try await runtime.initializeWayfarerColdChainStock(packDigest: fixture.pack.digest)
  let after = await runtime.snapshot()
  #expect(repeated == source && after.commander == initialized.commander)
}

@Test func nativeColdChainPickupCountsRealMassAndCannotSellRemoveOrDoublePledge() async throws {
  let fixture = try NativeColdChainFixture(units: 1)
  defer { fixture.files.clean() }
  let runtime = try await fixture.runtime()
  let source = try await runtime.initializeWayfarerColdChainStock(packDigest: fixture.pack.digest)
  let quote = try await runtime.wayfarerColdChainQuote(sourceID: source)
  let before = await runtime.snapshot()
  let files = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
  let preserved = try fixture.files.blockWrites("pickup")
  await #expect(throws: (any Error).self) {
    try await runtime.pickUpWayfarerColdChain(sourceID: source, quotedOfferID: quote.id)
  }
  let refused = await runtime.snapshot()
  #expect(refused.commander == before.commander)
  try fixture.files.restoreWrites(preserved, files: files)
  let id = try await runtime.pickUpWayfarerColdChain(sourceID: source, quotedOfferID: quote.id)
  let held = await runtime.snapshot()
  #expect(held.commander.cargo == before.commander.cargo)
  let beforeMass = try #require(before.commander.checkedCargoTonnes)
  #expect(held.commander.checkedCargoTonnes == beforeMass + 1)
  await #expect(throws: (any Error).self) {
    try await runtime.pickUpWayfarerColdChain(sourceID: source, quotedOfferID: quote.id)
  }
  let duplicate = await runtime.snapshot()
  #expect(duplicate.commander == held.commander)
  var traded = held
  let stock = held.commander.scriptState.savedWayfarerColdChainStock
  let state = try #require(held.commander.scriptState.instances[id])
  for index in traded.commander.cargo.indices {
    traded.selection = index
    traded.trade(buy: false)
    #expect(traded.commander.cargo[index] == held.commander.cargo[index])
  }
  #expect(traded.commander.scriptState.savedWayfarerColdChainStock == stock)
  #expect(traded.commander.scriptState.instances[id] == state)
  var changed = state
  var commander = held.commander
  let event = ScriptEvent(
    sequence: custodySequence(state), kind: "dialogue.confirmed", instance: id, values: [:])
  let commands: [ScriptValue] = [
    .object([
      "op": .string("payload.remove"), "id": .string("attempt-remove"),
      "key": .string(WayfarerColdChainDefinition.payloadKey), "amount": .integer(1),
    ]),
    .object([
      "op": .string("payload.add"), "id": .string("attempt-add"),
      "key": .string(WayfarerColdChainDefinition.payloadKey), "amount": .integer(1),
    ]),
    .object(["op": .string("credits"), "id": .string("attempt-pay"), "amount": .integer(1)]),
    .object(["op": .string("mission.finish"), "outcome": .string("complete")]),
    .object(["op": .string("timer.cancel"), "id": .string(WayfarerColdChainDefinition.timerID)]),
  ]
  for command in commands {
    #expect(throws: MissionPackError.self) {
      try held.applyScriptCommand(
        command, event: event, pack: fixture.pack, state: &changed, candidate: &commander)
    }
    #expect(changed == state && commander == held.commander)
  }
  var auto = held
  auto.autoTrade()
  #expect(auto.commander.scriptState.instances[id] == state)
  #expect(auto.commander.scriptState.savedWayfarerColdChainStock == stock)
  var other = ScriptInstance(
    id: ScriptIdentity.uuid("native-cold-chain-test-other-job"), definition: "fixture/other-job",
    version: "1.0.0", digest: fixture.pack.digest)
  let collection = ScriptCollectionDefinition(
    id: "ordinary-other-job", title: "Other job commodity demand",
    galaxy: held.commander.galaxy, system: held.commander.system,
    items: [.init(commodity: 0, unit: "t", quantity: 1)])
  other.collections[collection.id] = .init(definition: collection)
  let otherQuote = try #require(held.collectionQuote(collection.id, state: other))
  #expect(otherQuote.items.first?.aboard == 0 && otherQuote.items.first?.available == 0)
}

private func custodySequence(_ state: ScriptInstance) -> UInt64 {
  state.savedWayfarerColdChain?.issue.sequence ?? 0
}

@Test func nativeColdChainCapacityAndThreeServiceLimitUseOriginalStock() async throws {
  let fixture = try NativeColdChainFixture(units: 4)
  defer { fixture.files.clean() }
  let runtime = try await fixture.runtime()
  let source = try await runtime.initializeWayfarerColdChainStock(packDigest: fixture.pack.digest)
  var full = await runtime.snapshot()
  let originalStock = try #require(
    full.commander.scriptState.savedWayfarerColdChainStock?.sources[source])
  try #require(originalStock.units.count == 4)
  try #require(
    originalStock.units.values.allSatisfy { $0.status == .available && $0.instance == nil })
  full.commander.cargo[0] = full.commander.standardCargoCapacity
  let fullBefore = full.commander
  let fullQuote = try full.wayfarerColdChainQuote(sourceID: source)
  #expect(throws: MissionPackError.self) {
    try full.pickUpWayfarerColdChain(sourceID: source, quotedOfferID: fullQuote.id)
  }
  #expect(full.commander == fullBefore)
  var previousQuote: UUID?
  for _ in 0..<3 {
    let quote = try await runtime.wayfarerColdChainQuote(sourceID: source)
    previousQuote = quote.id
    _ = try await runtime.pickUpWayfarerColdChain(sourceID: source, quotedOfferID: quote.id)
  }
  let three = await runtime.snapshot()
  let heldStock = try #require(
    three.commander.scriptState.savedWayfarerColdChainStock?.sources[source])
  #expect(Set(heldStock.units.keys) == Set(originalStock.units.keys))
  #expect(heldStock.units.values.filter { $0.status == .held }.count == 3)
  #expect(
    heldStock.units.values.filter { $0.status == .available && $0.instance == nil }.count == 1)
  // Quotation itself enforces the shared three-service cap, even with original stock remaining.
  await #expect(throws: MissionPackError.self) {
    _ = try await runtime.wayfarerColdChainQuote(sourceID: source)
  }
  let quoteRefused = await runtime.snapshot()
  #expect(quoteRefused.commander == three.commander)
  // A previously issued real quote cannot bypass the same cap at pickup.
  let previous = try #require(previousQuote)
  await #expect(throws: (any Error).self) {
    try await runtime.pickUpWayfarerColdChain(sourceID: source, quotedOfferID: previous)
  }
  let refused = await runtime.snapshot()
  #expect(refused.commander == three.commander)
  #expect(
    three.commander.scriptState.instances.values.filter { $0.savedWayfarerColdChain != nil }.count
      == 3)
}

@Test func nativeColdChainActualObjectiveReceptionAndWriterFailureAreAtomic() async throws {
  let fixture = try NativeColdChainFixture(quietReceiverRoute: true)
  defer { fixture.files.clean() }
  let runtime = try await fixture.runtime()
  let (_, id) = try await fixture.pickup(runtime)
  try await ScriptProcurementFixture.travel(
    runtime, path: Array(fixture.route.prefix(2)), verifyDeparture: true)
  let arrived = await runtime.snapshot()
  let files = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
  let preserved = try fixture.files.blockWrites("objective")
  await #expect(throws: (any Error).self) {
    try await runtime.confirmWayfarerColdChainObjective(instance: id)
  }
  let refused = await runtime.snapshot()
  #expect(refused.commander == arrived.commander)
  try fixture.files.restoreWrites(preserved, files: files)
  try await runtime.confirmWayfarerColdChainObjective(instance: id)
  let objective = await runtime.snapshot()
  await #expect(throws: (any Error).self) {
    try await runtime.receiveWayfarerColdChain(instance: id)
  }
  let foreignReceiver = await runtime.snapshot()
  #expect(foreignReceiver.commander == objective.commander)
  try await fixture.atReceiver(runtime)
  let receiver = await runtime.snapshot()
  var boundary = receiver
  let held = try #require(boundary.commander.scriptState.instances[id]?.savedWayfarerColdChain)
  boundary.commander.scriptState.flightSeconds = held.timer.due
  let expiredBefore = boundary.commander
  #expect(throws: MissionPackError.self) { try boundary.receiveWayfarerColdChain(id) }
  #expect(boundary.commander == expiredBefore)
  let receptionFiles = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
  let receptionPreserved = try fixture.files.blockWrites("reception")
  await #expect(throws: (any Error).self) {
    try await runtime.receiveWayfarerColdChain(instance: id)
  }
  let receptionRefused = await runtime.snapshot()
  #expect(receptionRefused.commander == receiver.commander)
  try fixture.files.restoreWrites(receptionPreserved, files: receptionFiles)
  try await runtime.receiveWayfarerColdChain(instance: id)
  let complete = await runtime.snapshot()
  let terms = try #require(fixture.pack.manifest.coldChain)
  #expect(complete.commander.credits == receiver.commander.credits + terms.rewardNative)
  #expect(complete.commander.scriptState.instances[id]?.outcome == .complete)
  #expect(complete.commander.scriptState.instances[id]?.payloads.isEmpty == true)
  await #expect(throws: (any Error).self) {
    try await runtime.receiveWayfarerColdChain(instance: id)
  }
  let repeated = await runtime.snapshot()
  #expect(repeated.commander == complete.commander)
  let (cold, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.save), from: fixture.save)
  try NativeColdChainFixture.checkTerminalAnchors(try #require(cold.scriptState.instances[id]))
}

@Test func nativeColdChainActualExpiryKeepsOriginalTombstoneAndRetryNeedsNewStock() async throws {
  let fixture = try NativeColdChainFixture(allowance: 0.2)
  defer { fixture.files.clean() }
  let runtime = try await fixture.runtime()
  let (source, id) = try await fixture.pickup(runtime)
  let picked = await runtime.snapshot()
  let original = try #require(picked.commander.scriptState.instances[id]?.savedWayfarerColdChain)
  await runtime.key("0")
  for _ in 0..<8 { _ = await runtime.advance(delta: 0.1) }
  let expired = await runtime.snapshot()
  #expect(expired.commander.scriptState.instances[id]?.outcome == .failed)
  #expect(expired.commander.scriptState.instances[id]?.payloads.isEmpty == true)
  #expect(expired.commander.credits == picked.commander.credits)
  let (cold, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.save), from: fixture.save)
  try NativeColdChainFixture.checkTerminalAnchors(try #require(cold.scriptState.instances[id]))
  try await ScriptProcurementFixture.dock(runtime)
  _ = try await runtime.initializeWayfarerColdChainStock(packDigest: fixture.pack.digest)
  let next = try await runtime.wayfarerColdChainQuote(sourceID: source)
  #expect(next.stockUnit != original.unit)
  let now = await runtime.snapshot()
  #expect(
    now.commander.scriptState.savedWayfarerColdChainStock?.sources[source]?.units[
      original.unit.uuidString]?.status == .failed)
  #expect(now.commander.scriptState.savedWayfarerColdChainStock?.sources[source]?.units.count == 2)
}

@Test func nativeColdChainBlockedExpirySavesPendingAndRequiresExplicitOnceOnlyRetry() async throws {
  let fixture = try NativeColdChainFixture(allowance: 0.2)
  defer { fixture.files.clean() }
  let runtime = try await fixture.runtime()
  let (source, id) = try await fixture.pickup(runtime)
  await runtime.key("0")
  let before = await runtime.snapshot()
  let original = try #require(before.commander.scriptState.instances[id]?.savedWayfarerColdChain)
  let files = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
  let preserved = try fixture.files.blockWrites("native-expiry")
  for _ in 0..<8 { _ = await runtime.advance(delta: 0.1) }
  let refused = await runtime.snapshot()
  let held = try #require(refused.commander.scriptState.instances[id])
  let event = try #require(
    WayfarerColdChainSave.pendingExpiry(held, engine: refused.commander.scriptState))
  let firedContext = try #require(event.context)
  #expect(held.outcome == .active && held.suspension != nil && held.timers.isEmpty)
  #expect(held.savedWayfarerColdChain == original)
  #expect(held.payloads == [WayfarerColdChainDefinition.payloadKey: 1])
  #expect(WayfarerColdChainSave.validateClaims(refused.commander))
  #expect(refused.commander.checkedCargoTonnes == before.commander.checkedCargoTonnes)
  #expect(refused.commander.credits == before.commander.credits)
  #expect(
    refused.commander.scriptState.savedWayfarerColdChainStock
      == before.commander.scriptState.savedWayfarerColdChainStock)
  let notices = refused.ecmControl.events.filter {
    $0.announcement == .gameplay("MISSION SUSPENDED - SEE MISSION GALLERY")
  }
  #expect(notices.count == 1)
  // Every rejected callback unconditionally emits this notice. Suspension must prevent
  // another callback/publication attempt while actual flight clocks continue advancing.
  for _ in 0..<8 { _ = await runtime.advance(delta: 0.1) }
  let later = await runtime.snapshot()
  #expect(later.commander.scriptState.flightSeconds > refused.commander.scriptState.flightSeconds)
  #expect(later.commander.scriptState.instances[id] == held)
  #expect(
    later.ecmControl.events.filter {
      $0.announcement == .gameplay("MISSION SUSPENDED - SEE MISSION GALLERY")
    } == notices)
  #expect(
    WayfarerColdChainSave.pendingExpiry(held, engine: later.commander.scriptState) == event)
  try fixture.files.restoreWrites(preserved, files: files)
  try await runtime.save(to: fixture.save)
  let (pending, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.save), from: fixture.save)
  #expect(pending.scriptState.instances[id] == held)
  #expect(pending.scriptState.flightSeconds > firedContext.flightSeconds)
  try fixture.rejectCorruption { $0["pendingEvents"] = [] }
  try fixture.rejectCorruption { root in
    var events = try #require(root["pendingEvents"] as? [[String: Any]])
    let index = try #require(events.firstIndex { ($0["kind"] as? String) == "timer.fired" })
    events.append(events[index])
    root["pendingEvents"] = events
  }
  try await runtime.load(from: fixture.save, persistMigrations: false)
  let loaded = await runtime.snapshot()
  #expect(loaded.commander.scriptState.instances[id] == held)
  if loaded.paused { await runtime.key("pause") }
  if !loaded.screen.isFlight { await runtime.key("1") }
  _ = await runtime.advance(delta: 0.1)
  let retryBefore = await runtime.snapshot()
  #expect(retryBefore.commander.scriptState.instances[id] == held)
  let retryFiles = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
  let retryPreserved = try fixture.files.blockWrites("native-expiry-retry")
  await #expect(throws: (any Error).self) {
    try await runtime.retryWayfarerColdChainExpiry(instance: id)
  }
  let retryRefused = await runtime.snapshot()
  #expect(retryRefused.commander == retryBefore.commander)
  try fixture.files.restoreWrites(retryPreserved, files: retryFiles)
  try await runtime.retryWayfarerColdChainExpiry(instance: id)
  let expired = await runtime.snapshot()
  let failed = try #require(expired.commander.scriptState.instances[id])
  #expect(failed.outcome == .failed && failed.suspension == nil)
  #expect(failed.payloads.isEmpty && failed.timers.isEmpty)
  #expect(failed.completionReceipt?.sequence == event.sequence)
  #expect(failed.completionReceipt?.cause == event.context)
  #expect(expired.commander.credits == before.commander.credits)
  #expect(
    expired.commander.checkedCargoTonnes == before.commander.checkedCargoTonnes.map { $0 - 1 })
  #expect(
    expired.commander.scriptState.savedWayfarerColdChainStock?.sources[source]?.units[
      original.unit.uuidString]?.status == .failed)
  try NativeColdChainFixture.checkTerminalAnchors(failed)
  let (cold, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.save), from: fixture.save)
  #expect(cold.scriptState.instances[id] == failed)
  try await runtime.load(from: fixture.save, persistMigrations: false)
  await #expect(throws: (any Error).self) {
    try await runtime.retryWayfarerColdChainExpiry(instance: id)
  }
  let repeated = await runtime.snapshot()
  #expect(repeated.commander.scriptState.instances[id] == failed)
  #expect(repeated.commander.credits == before.commander.credits)
}

@Test func nativeColdChainSaveRejectsNullMissingUnknownDowngradedAndForeignClaims() async throws {
  let fixture = try NativeColdChainFixture()
  defer { fixture.files.clean() }
  let runtime = try await fixture.runtime()
  let (_, id) = try await fixture.pickup(runtime)
  for field in ["savedWayfarerColdChainStock"] {
    try fixture.rejectCorruption { $0[field] = NSNull() }
    try fixture.rejectCorruption { $0.removeValue(forKey: field) }
  }
  try fixture.rejectCorruption {
    var ledger = try #require($0["savedWayfarerColdChainStock"] as? [String: Any])
    ledger["unknown"] = 1
    $0["savedWayfarerColdChainStock"] = ledger
  }
  try fixture.rejectCorruption {
    try NativeColdChainFixture.mutateInstance(id, root: &$0) {
      var custody = try #require($0["savedWayfarerColdChain"] as? [String: Any])
      custody["unit"] = UUID().uuidString
      $0["savedWayfarerColdChain"] = custody
    }
  }
  let original = try Data(contentsOf: fixture.save)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: original)
  for schema in [29, 31, 33, 36] {
    let downgraded = ScriptSavePointer(
      format: pointer.format, schemaVersion: schema, generation: pointer.generation,
      hashes: pointer.hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
    #expect(throws: (any Error).self) {
      _ = try ScriptSaveStore.read(JSONEncoder().encode(downgraded), from: fixture.save)
    }
  }
}

@Test func nativeColdChainReceptionUsesExistingPinnedClueAndActualSaveStore() async throws {
  let fixture = try NativeColdChainFixture(quietReceiverRoute: true)
  defer { fixture.files.clean() }
  let runtime = try await fixture.runtime()
  let (_, id) = try await fixture.pickup(runtime)
  try await fixture.atObjective(runtime, id: id)
  try await fixture.atReceiver(runtime)
  var received = await runtime.snapshot()
  let pin = ScriptClueExecutionPin(
    sourceID: WayfarerColdChainDefinition.stateID, definition: fixture.pack.manifest.stateID,
    version: fixture.pack.manifest.version, digest: fixture.pack.digest,
    terminalEvents: ["dialogue.confirmed"])
  let trust = try ScriptClueTrustCatalog(pins: [pin])
  try received.receiveWayfarerColdChain(id, clueTrust: trust)
  let award = try #require(received.commander.scriptState.savedClueJournal?.awards[pin.sourceID])
  #expect(award.completion.instance == id)
  #expect(received.commander.scriptState.savedClueJournal?.awards.count == 1)
  let prepared = try GameRuntime.prepareNativeSaveState(received)
  let save = fixture.files.root.appendingPathComponent("pinned/commander.json")
  try ScriptSaveStore.write(
    commander: prepared.commander, world: prepared.game.scriptWorldSave, to: save, clueTrust: trust)
  let (cold, _) = try ScriptSaveStore.read(Data(contentsOf: save), from: save, clueTrust: trust)
  #expect(cold.scriptState.savedClueJournal?.awards[pin.sourceID] == award)
  #expect(throws: MissionPackError.self) {
    try received.receiveWayfarerColdChain(id, clueTrust: trust)
  }
  #expect(received.commander.scriptState.savedClueJournal?.awards.count == 1)
}

@Test func nativeColdChainPauseAndActualReloadPreserveTheAbsoluteFlightBudget() async throws {
  let fixture = try NativeColdChainFixture(allowance: 20)
  defer { fixture.files.clean() }
  let runtime = try await fixture.runtime()
  let (_, id) = try await fixture.pickup(runtime)
  await runtime.key("0")
  _ = await runtime.advance(delta: 0.1)
  let remaining = try await runtime.wayfarerColdChainRemaining(instance: id)
  #expect(remaining < 20 && remaining > 0)
  await runtime.key("pause")
  for _ in 0..<4 { _ = await runtime.advance(delta: 0.1) }
  let paused = try await runtime.wayfarerColdChainRemaining(instance: id)
  #expect(paused == remaining)
  try await runtime.save(to: fixture.save)
  try await runtime.load(from: fixture.save, persistMigrations: false)
  let reloaded = try await runtime.wayfarerColdChainRemaining(instance: id)
  #expect(reloaded == remaining)
  let snapshot = await runtime.snapshot()
  if snapshot.paused { await runtime.key("pause") }
  if !snapshot.screen.isFlight { await runtime.key("1") }
  _ = await runtime.advance(delta: 0.1)
  let resumed = try await runtime.wayfarerColdChainRemaining(instance: id)
  #expect(resumed < remaining)
}

@Test func nativeColdChainActualEscapeAndFailedWriterNeverResurrectTheOriginalSample() async throws
{
  let fixture = try NativeColdChainFixture()
  defer { fixture.files.clean() }
  let runtime = try await fixture.runtime(escapeReady: true)
  let (source, id) = try await fixture.pickup(runtime)
  await runtime.key("0")
  let before = await runtime.snapshot()
  let remaining = try await runtime.wayfarerColdChainRemaining(instance: id)
  let files = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
  let preserved = try fixture.files.blockWrites("native-escape")
  await runtime.key("escape-pod")
  let refused = await runtime.snapshot()
  #expect(refused.commander == before.commander && refused.docked == before.docked)
  try fixture.files.restoreWrites(preserved, files: files)
  await runtime.key("escape-pod")
  let escaped = await runtime.snapshot()
  let state = try #require(escaped.commander.scriptState.instances[id])
  let custody = try #require(state.savedWayfarerColdChain)
  #expect(state.outcome == .failed && state.payloads.isEmpty)
  #expect(custody.loss?.cause == .escapePod && custody.integrity.terminal == nil)
  #expect(custody.integrity.remaining == remaining)
  #expect(escaped.commander.credits == before.commander.credits)
  #expect(
    escaped.commander.scriptState.savedWayfarerColdChainStock?.sources[source]?.units[
      custody.unit.uuidString]?.status == .failed)
  let (cold, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.save), from: fixture.save)
  #expect(cold.scriptState.instances[id]?.savedWayfarerColdChain == custody)
  await #expect(throws: (any Error).self) {
    try await runtime.receiveWayfarerColdChain(instance: id)
  }
  // Escape's forced dock clears nativeMainDock. Only a subsequent real arrival can quote stock.
  #expect(!escaped.nativeMainStationDockEvidenceIsCurrent)
  await #expect(throws: (any Error).self) {
    _ = try await runtime.initializeWayfarerColdChainStock(packDigest: fixture.pack.digest)
  }
  await runtime.key("0")
  try await ScriptProcurementFixture.dock(runtime)
  _ = try await runtime.initializeWayfarerColdChainStock(packDigest: fixture.pack.digest)
  let quote = try await runtime.wayfarerColdChainQuote(sourceID: source)
  #expect(quote.stockUnit != custody.unit)
}

@Test func nativeColdChainActualFatalHitAndWriterRefusalPreserveStockUntilPublication() async throws
{
  let fixture = try NativeColdChainFixture()
  defer { fixture.files.clean() }
  let runtime = try await fixture.runtime()
  let (source, id) = try await fixture.pickup(runtime)
  await runtime.key("0")
  let before = await runtime.snapshot()
  let original = try #require(before.commander.scriptState.instances[id]?.savedWayfarerColdChain)
  let files = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
  let preserved = try fixture.files.blockWrites("native-fatal")
  // Existing controlled combat fixture allocates a real hostile actor, actual collision hit
  // and native attack origin; it does not assign gameOver or construct loss receipts.
  try await runtime.freightFatalHit()
  _ = await runtime.advance(delta: 0.1)
  let refused = await runtime.snapshot()
  #expect(refused.screen == .gameOver)
  #expect(
    refused.commander.scriptState.savedWayfarerColdChainStock
      == before.commander.scriptState.savedWayfarerColdChainStock)
  #expect(
    refused.commander.scriptState.instances[id]?.payloads[WayfarerColdChainDefinition.payloadKey]
      == 1)
  #expect(refused.commander.scriptState.instances[id]?.savedWayfarerColdChain == original)
  try fixture.files.restoreWrites(preserved, files: files)
  _ = await runtime.advance(delta: 0.1)
  let failed = await runtime.snapshot()
  let state = try #require(failed.commander.scriptState.instances[id])
  let custody = try #require(state.savedWayfarerColdChain)
  #expect(state.outcome == .failed && state.payloads.isEmpty)
  #expect(custody.loss?.cause == .shipDestroyed && custody.loss?.energy == 0)
  #expect(custody.integrity.terminal == nil)
  #expect(failed.commander.credits == before.commander.credits)
  #expect(
    failed.commander.scriptState.savedWayfarerColdChainStock?.sources[source]?.units[
      custody.unit.uuidString]?.status == .failed)
  let (cold, _) = try ScriptSaveStore.read(Data(contentsOf: fixture.save), from: fixture.save)
  #expect(cold.scriptState.instances[id]?.savedWayfarerColdChain == custody)
  await #expect(throws: (any Error).self) {
    try await runtime.receiveWayfarerColdChain(instance: id)
  }
}

@Test func nativeColdChainAlienEnvelopeComposesWithoutInventingAcquisitionAuthority() async throws {
  let fixture = try NativeColdChainFixture()
  defer { fixture.files.clean() }
  let runtime = try await fixture.runtime()
  _ = try await runtime.initializeWayfarerColdChainStock(packDigest: fixture.pack.digest)
  var game = await runtime.snapshot()
  let owner = try #require(game.commander.equipmentOwnerID)
  // Storage composition only, identical to existing empty-Alien envelope tests.
  try game.commander.replaceAlienStorage(
    with: .init(
      owner: owner, revision: 0, worldRevision: 0, world: [], sources: [],
      attachments: [], upgrades: [], receipts: [], commands: []))
  let prepared = try GameRuntime.prepareNativeSaveState(game)
  let save = fixture.files.root.appendingPathComponent("alien/commander.json")
  try ScriptSaveStore.write(
    commander: prepared.commander, world: prepared.game.scriptWorldSave, to: save)
  let bytes = try Data(contentsOf: save)
  let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
  #expect(pointer.schemaVersion == 36)
  let (cold, world) = try ScriptSaveStore.read(bytes, from: save)
  #expect(
    cold.scriptState.savedWayfarerColdChainStock
      == prepared.commander.scriptState.savedWayfarerColdChainStock)
  #expect(cold.usesAlienStorageSaveVersion && world.consistent(with: cold))
}

@Test func nativeColdChainProtectedTonneBlocksTheActualOrdinaryScoopAtCapacity() async throws {
  let fixture = try NativeColdChainFixture()
  defer { fixture.files.clean() }
  let runtime = try await fixture.runtime(scoopsReady: true)
  let (_, id) = try await fixture.pickup(runtime)
  await runtime.key("0")
  var game = await runtime.snapshot()
  try #require(
    !game.docked && game.commander.equipment.contains("Fuel Scoops")
      && game.commander.fittedEquipment(at: .utility(.fuelScoops)) != nil)
  game.commander.cargo[0] = game.commander.capacity - 1
  try #require(game.commander.cargoTonnes == game.commander.capacity)
  let sample = try #require(game.commander.scriptState.instances[id]?.savedWayfarerColdChain)
  let stock = game.commander.scriptState.savedWayfarerColdChainStock
  let ordinary = game.commander.cargo
  let body = game.nextBodyID
  game.nextBodyID += 1
  game.bodies.append(.init(id: body, hull: .cargo, position: .init(0, -25, 30)))
  game.ensurePhysicalActors()
  game.message = ""
  game.scoopCargo()
  #expect(game.message == "CARGO HOLD FULL")
  #expect(game.commander.cargo == ordinary)
  #expect(game.commander.scriptState.instances[id]?.savedWayfarerColdChain == sample)
  #expect(game.commander.scriptState.savedWayfarerColdChainStock == stock)
}

@Test func nativeColdChainAbsentAndForeignPathsKeepOrdinaryCommandsAndFullSaveWorking() async throws
{
  let fixture = try ScriptFreightFixture()
  defer { fixture.clean() }
  var game = try ScriptProcurementFixture.freshG03FlightGame()
  game.scriptPacks = []
  try game.prepareG03FlightEquipment()
  let runtime = GameRuntime(game: game, saveURL: fixture.save)
  try await runtime.save(to: fixture.save)
  await runtime.key("0")
  _ = await runtime.advance(delta: 0.1)
  try await ScriptProcurementFixture.dock(runtime)
  await runtime.key("5")
  try await runtime.save(to: fixture.save)
  let before = await runtime.snapshot()
  #expect(before.commander.scriptState.savedWayfarerColdChainStock == nil)
  let foreign = ScriptIdentity.uuid("native-cold-chain-test-foreign-instance")
  await #expect(throws: MissionPackError.self) {
    try await runtime.receiveWayfarerColdChain(instance: foreign)
  }
  let after = await runtime.snapshot()
  #expect(after.commander == before.commander)
  let (cold, world) = try ScriptSaveStore.read(Data(contentsOf: fixture.save), from: fixture.save)
  #expect(cold.scriptState.savedWayfarerColdChainStock == nil)
  #expect(world.consistent(with: cold))
}

@Test func nativeColdChainStaleSourceQuoteCannotClaimStockAfterActualRedocking() async throws {
  let fixture = try NativeColdChainFixture()
  defer { fixture.files.clean() }
  let runtime = try await fixture.runtime()
  let source = try await runtime.initializeWayfarerColdChainStock(packDigest: fixture.pack.digest)
  let old = try await runtime.wayfarerColdChainQuote(sourceID: source)
  await runtime.key("0")
  try await ScriptProcurementFixture.dock(runtime)
  let current = try await runtime.wayfarerColdChainQuote(sourceID: source)
  #expect(current.stockUnit == old.stockUnit && current.id != old.id)
  let before = await runtime.snapshot()
  await #expect(throws: MissionPackError.self) {
    try await runtime.pickUpWayfarerColdChain(sourceID: source, quotedOfferID: old.id)
  }
  let after = await runtime.snapshot()
  #expect(after.commander == before.commander)
}
