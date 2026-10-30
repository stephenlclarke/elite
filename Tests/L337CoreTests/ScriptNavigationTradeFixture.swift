import Darwin
import Foundation
import Testing

@testable import L337Core

/// Native engine acceptance fixture using actual installed original worlds and authored quotes.
/// Real flight, paid stock mutations and station entry produce the mission evidence.
struct ScriptNavigationTradeFixture: Sendable {
  let root: URL
  let pack: ScriptPack
  let binding: ScriptNavigationTradeBinding
  let commodity: Int
  let initial: Game
  var save: URL { root.appendingPathComponent("save/commander.json") }

  init(alien: Bool = false) throws {
    let path = FileManager.default.temporaryDirectory.path
    let resolved = path.withCString { realpath($0, nil) }
    let physical = try #require(resolved)
    defer { free(physical) }
    root = URL(fileURLWithPath: String(cString: physical), isDirectory: true)
      .appendingPathComponent("navigation-trade-" + UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let content = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/l337-navigation-trade")
    pack = try ScriptPackLibrary.read(content)
    try #require(ScriptNavigationTradeContent.matches(pack))
    var game = Game(executive: false)
    game.screen = .status
    game.commander.system = 237
    game.commander.credits = 50_000  // Initial fixture funds, never a tutorial reward.
    if alien {
      try game.commander.initializeEquipment(
        owner: AlienStorageTestFixture.owner, hull: AlienStorageTestFixture.hull,
        legacy: false, allocatingItemIDs: { UUID() })
      var storage = AlienStorageTestFixture()
      _ = try storage.acquire(kind: .energyCapacity)
      try game.commander.replaceAlienStorage(with: storage.snapshot)
    } else {
      try game.commander.prepareEquipment(legacy: false)
    }
    try game.commander.grantEquipment(
      "Escape Pod", at: .utility(.escapePod),
      provenance: .grant("navigation fixture safety equipment"))
    game.scriptPacks = [pack]
    game.market = MarketItem.at(game.currentSystem)
    game.launch()
    try #require(!game.docked && game.commander.valid)
    // Pick a real stocked legal tonne and reachable world whose real bid is lower.
    // This checks a genuine loss using the actual authored buy/sell spread.
    let choices = game.knownSystems.filter {
      $0.id != game.commander.system && game.currentSystem.distance(to: $0) > 0
        && game.currentSystem.distance(to: $0) <= min(6, game.commander.maximumJumpDistance)
    }.flatMap { destination in
      Commodity.all.indices.compactMap { index -> (StarSystem, Int)? in
        guard Commodity.all[index].unit == "t", ![3, 6, 10, 16].contains(index),
          game.market[index].quantity > 0,
          MarketItem.at(destination)[index].bidPrice < game.market[index].price
        else { return nil }
        return (destination, index)
      }
    }
    let selected = try #require(choices.first)
    binding = .init(
      training: .init(
        worldID: try #require(game.currentSystem.original?.key), galaxy: game.commander.galaxy,
        system: game.currentSystem),
      destination: .init(
        worldID: try #require(selected.0.original?.key), galaxy: game.commander.galaxy,
        system: selected.0
      ))
    commodity = selected.1
    initial = game
  }

  func clean() { try? FileManager.default.removeItem(at: root) }

  /// Same near-door setup as the existing native station fixture; only real swept entry mints proof.
  func dock(_ runtime: GameRuntime) async throws {
    try await runtime.navigationTradeCommand(binding: binding) { game in
      let station = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
      let old = game.commander.flightSimulation.pose
      var pose = ShipPose()
      pose.position = old.systemPoint(station.entrancePosition + station.entranceNormal * 2)
      pose.orientation.y = old.orientation.apply(station.entranceUp)
      pose.orientation.z = old.orientation.apply(station.entranceNormal) * -1
      pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
      NativeStationTestFixture.reframe(&game, to: pose)
      game.speed = 3
      for _ in 0..<100 where !game.docked { game.tick(delta: 0.1) }
      try #require(game.docked && game.nativeMainStationDockEvidenceIsCurrent)
    }
  }

  func accept(_ runtime: GameRuntime, selectedCommodity: Int? = nil) async throws -> UUID {
    try await runtime.navigationTradeCommand(binding: binding) { game in
      game.selectedSystem = binding.destination.system.id
      game.selection = selectedCommodity ?? commodity
      try #require(ScriptNavigationTradeBinding.production(in: game) == binding)
      let id = try game.acceptScriptMission(pack, drainAccepted: false)
      game.drainScriptEvents()
      return id
    }
  }

  func acceptAndConfirm(_ runtime: GameRuntime, selectedCommodity: Int? = nil) async throws -> UUID
  {
    let id = try await accept(runtime, selectedCommodity: selectedCommodity)
    try await confirm(runtime, id: id)
    let confirmed = await runtime.snapshot()
    try #require(
      confirmed.commander.scriptState.instances[id]?.savedNavigationTrade?.stage == .awaitingBuy)
    return id
  }

  @discardableResult
  func confirm(_ runtime: GameRuntime, id: UUID, choice: String? = nil) async throws -> ScriptEvent?
  {
    try await runtime.navigationTradeCommand(binding: binding) { game in
      game.emitScriptEvent("contact.requested", only: id, drain: false)
      game.drainScriptEvents()
      let shown = game.showScriptDialogue(only: id)
      try #require(shown)
      if let choice {
        let selected = try #require(game.offeredScriptChoices.firstIndex { $0.id == choice })
        game.scriptChoiceSelection = selected
      }
      game.scriptEventsDeferred = true
      game.confirmScriptDialogue()
      game.scriptEventsDeferred = false
      let cause = game.commander.scriptState.pendingEvents.last {
        $0.instance == id && $0.kind == "dialogue.confirmed"
      }
      game.drainScriptEvents()
      return cause
    }
  }

  func buy(_ runtime: GameRuntime) async throws {
    try await runtime.navigationTradeCommand(binding: binding) { game in
      game.screen = .buy
      game.selection = commodity
      game.key("return")
    }
  }

  func travel(_ runtime: GameRuntime, to destination: Int) async throws {
    try await runtime.navigationTradeCommand(binding: binding) { game in
      game.launch()
      try #require(!game.docked)
      // Fixture positioning changes no world, fuel, calendar, visit or journey evidence.
      // Actual H input and countdown below must admit and settle the native journey.
      var pose = game.commander.flightSimulation.pose
      pose.position = pose.position + pose.orientation.x * 20_000
      NativeStationTestFixture.reframe(&game, to: pose)
      game.selectedSystem = destination
      game.key("h")
      try #require(game.jumpCountdown != nil)
      let admitted = try #require(game.commander.scriptState.calendarLedger?.pendingJourney)
      try #require(admitted.destination == destination)
      let fuelBefore = game.commander.fuel
      for _ in 0..<200 where game.jumpCountdown != nil { game.tick(delta: 0.1) }
      try #require(game.commander.system == destination && game.jumpCountdown == nil)
      #expect(game.commander.fuel == fuelBefore - admitted.nativeFuelDebit)
    }
    try await dock(runtime)
  }

  func sell(_ runtime: GameRuntime) async throws {
    try await runtime.navigationTradeCommand(binding: binding) { game in
      game.screen = .sell
      game.selection = commodity
      game.key("return")
    }
  }

  func refuel(_ runtime: GameRuntime) async throws {
    try await runtime.navigationTradeCommand(binding: binding) { game in
      let fuel = try #require(Equipment.all.firstIndex { $0.name == "Fuel" })
      game.selection = fuel
      game.purchase()
    }
  }

  func ready(_ runtime: GameRuntime) async throws -> UUID {
    try await dock(runtime)
    let id = try await acceptAndConfirm(runtime)
    try await buy(runtime)
    return id
  }

}
