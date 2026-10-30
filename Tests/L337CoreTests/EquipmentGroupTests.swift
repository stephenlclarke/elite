import Foundation
import Testing

@testable import L337Core

@Test func groupedEquipmentIncludesEveryItemOnceAndSelectionSkipsHeadings() throws {
  #expect(
    EquipmentGroups.rows.contains {
      if case .heading("Shield Modules") = $0 { true } else { false }
    })
  #expect(
    !EquipmentGroups.rows.contains {
      if case .heading("Shield Boosters") = $0 { true } else { false }
    })
  let order = EquipmentGroups.itemIndices
  #expect(order.count == Equipment.all.count && Set(order).count == order.count)
  #expect(!Equipment.all.contains { $0.name == Equipment.legacyDockingComputer })
  var game = Game(executive: false)
  game.screen = .equipment
  game.selection = order[0]
  for index in order {
    #expect(game.selection == index)
    for width in [512.0, 768, 1512] {
      game.viewportWidth = width
      game.viewportHeight = 518
      let layout = EquipmentLayout(game: game, width: width, height: 518)
      let frame = Display.equipmentScreen(game, width: width, height: 518)
      let item = Equipment.all[index]
      let node = EquipmentRuntimeCatalog.node(for: item.name)
      let displayName =
        EquipmentRuntimeCatalog.graph.nodes.first { $0.id == node }?.displayName
        ?? item.name
      #expect(
        frame.labels.contains { $0.text == displayName },
        "Item \(index) width \(width), selected \(game.selection), start \(layout.start), count \(layout.count)"
      )
      let selected = try #require(frame.labels.first { $0.text == ">" })
      #expect(selected.x == layout.left + 14)
      for label in frame.labels {
        #expect(label.bounds.x >= 0 && label.bounds.maxX <= width && label.bounds.maxY <= 518)
      }
      game.equipmentClick(y: selected.y)
      #expect(game.selection == index)
      if case .heading = EquipmentGroups.rows[layout.start] {
        game.equipmentClick(y: layout.listTop)
        #expect(game.selection == index)
      }
    }
    game.key("down")
  }
  #expect(game.selection == order.last)
  game.key("equipment-scroll:-1")
  #expect(game.selection == order[order.count - 2])
  game.key("up")
  #expect(game.selection == order[order.count - 3])
  game.equipmentClick(y: -1)
  game.equipmentClick(y: 10000)
  #expect(game.selection == order[order.count - 3])
}

@Test func groupedPurchasesUseItemIdentityAndRewardRowsCannotBeBought() throws {
  var game = Game(executive: false)
  game.screen = .equipment
  game.commander.credits = 1_000_000
  game.selection = try #require(Equipment.all.firstIndex { $0.name == "Mining Laser" })
  let miningLaser = Equipment.all[game.selection]
  game.commander.system = try #require(
    game.systems.first { $0.technology >= miningLaser.requiredTechnologyLevel }?.id)
  try #require(!game.atPlugh && game.equipmentAvailable(miningLaser))
  try #require(game.shopPrice(miningLaser) == 33000 && game.commander.valid)
  game.key("return")
  #expect(game.commander.equipment.contains("Mining Laser") && game.commander.credits == 967_000)
  for name in [
    Equipment.navalLaser, ShieldBooster.capital.equipmentName,
  ] {
    game.selection = try #require(Equipment.all.firstIndex { $0.name == name })
    let beforeRefusal = game.commander
    game.key("return")
    #expect(!game.commander.equipment.contains(name) && game.commander.credits == 967_000)
    #expect(game.message.hasSuffix("NOT FOR SALE"))
    #expect(game.commander == beforeRefusal && game.commander.valid)
  }
}

@Test func legacyDockingMigratesToTargetingWithoutDowngradingOrDuplicating() {
  for tier in TargetingTier.allCases {
    var saved = Commander()
    saved.equipment.insert(Equipment.legacyDockingComputer)
    saved.equipment.insert(tier.equipmentName)
    var game = Game(executive: false)
    #expect(game.load(saved) == true)
    #expect(game.commander.targetingTier == max(tier, .docking))
    #expect(!game.commander.equipment.contains(Equipment.legacyDockingComputer))
    game.launch()
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 1500))]
    game.key("tab")
    #expect(game.dockingComputer)
  }
  for tier in [TargetingTier.basic, .advanced] {
    var game = Game(executive: false)
    game.commander.installTargetingComputer(tier)
    game.launch()
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 1500))]
    game.key("tab")
    #expect(!game.dockingComputer)
  }
}

@Test func xyzzyCashStartsOnceAccountsNormallyAndMigratesOnlyLegacyXYZzy() async throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  func roundTrip(_ value: Game, name: String) async throws -> Game {
    let url = directory.appendingPathComponent(name)
    let writer = GameRuntime(game: value)
    try await writer.save(to: url)
    var saved = await writer.snapshot()
    #expect(saved.commander.credits == value.commander.credits)
    #expect(saved.commander.cargo == value.commander.cargo)
    #expect(saved.commander.shipID == value.commander.shipID)
    #expect(saved.commander.name == value.commander.name)
    #expect(saved.commander.fuel == value.commander.fuel)
    #expect(saved.commander.missiles == value.commander.missiles)
    #expect(saved.commander.equipmentInventory == value.commander.equipmentInventory)
    #expect(saved.commander.equipmentPurchaseHistory == value.commander.equipmentPurchaseHistory)
    #expect(saved.commander.laserMounts == value.commander.laserMounts)
    #expect(saved.commander.contracts == value.commander.contracts)
    #expect(saved.commander.accommodation == value.commander.accommodation)
    let bytes = try Data(contentsOf: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == 26 && pointer.scope == "commander")
    let (stored, _) = try ScriptSaveStore.read(bytes, from: url)
    var expectedStored = saved.commander
    if expectedStored.npcPersistence.count > 0 {
      expectedStored.npcPersistence.resetPhysicalBindings(system: saved.systemIdentity)
    }
    expectedStored.resetWantedCareerBindings(system: saved.systemIdentity)
    #expect(stored == expectedStored)
    let reader = GameRuntime(game: Game(executive: false))
    // Binding restoration is transient; retain the actual writer bytes for this current save.
    try await reader.load(from: url, persistMigrations: false)
    let loaded = await reader.snapshot()
    let reloadedBytes = try Data(contentsOf: url)
    // Loading gives registered RRS stations fresh runtime bindings and allocation counters.
    // Apply only that existing boundary to the expected snapshot; retain full identity checks.
    try saved.rebindNativeStationsAfterLoad()
    #expect(loaded.commander == saved.commander)
    #expect(reloadedBytes == bytes)
    return loaded
  }
  var game = Game(executive: false)
  game.launch()
  for key in "xyzzy" { game.key(String(key)) }
  #expect(
    game.commander.credits == 10_000_000 && !game.commander.unlimitedCash
      && game.commander.xyzzyCashGranted)
  game.commander.credits = 1234
  game.key("9")
  game.key("5")
  game.key("return")
  for key in "xyzzy" { game.key(String(key)) }
  #expect(
    game.commander.credits == 1234 && !game.commander.unlimitedCash
      && !game.commander.unlimitedJumps)
  game.key("return")
  var rawProbe = Game(executive: false)
  let rawBefore = rawProbe.commander
  let rawLoaded = rawProbe.load(game.commander)
  #expect(!rawLoaded && rawProbe.commander == rawBefore)
  var restored = try await roundTrip(game, name: "current.json")
  #expect(restored.commander.credits == 1234)
  var old = Commander()
  old.name = "CLARKE"
  old.unlimitedCash = true
  old.unlimitedCargo = true
  old.unlimitedJumps = true
  let loadedOld = restored.load(old)
  try #require(loadedOld)
  #expect(
    restored.commander.credits == 10_000_000 && !restored.commander.unlimitedCash
      && !restored.commander.unlimitedJumps && restored.commander.xyzzyCashGranted)
  restored.commander.credits = 25
  restored = try await roundTrip(restored, name: "accounted.json")
  #expect(restored.commander.credits == 25)
  restored.commander.startXYZzyCash()
  #expect(restored.commander.credits == 25 && restored.commander.xyzzyCashGranted)
  old.unlimitedCash = false
  old.credits = 456
  let loadedFiniteOld = restored.load(old)
  try #require(loadedFiniteOld)
  #expect(restored.commander.credits == 456)
  old.name = "JAMESON"
  old.unlimitedCash = true
  old.credits = 789
  let loadedOrdinary = restored.load(old)
  try #require(loadedOrdinary)
  #expect(restored.commander.credits == 789 && restored.commander.unlimitedCash)
  var finiteSeed = Commander()
  finiteSeed.name = "CLARKE"
  finiteSeed.unlimitedCargo = true
  finiteSeed.unlimitedJumps = true
  finiteSeed.unlimitedCash = false
  finiteSeed.credits = 1234
  let encoded = try JSONEncoder().encode(finiteSeed)
  let object = try JSONSerialization.jsonObject(with: encoded)
  var data = try #require(object as? [String: Any])
  data.removeValue(forKey: "finiteXYZzyCash")
  let finiteBytes = try JSONSerialization.data(withJSONObject: data)
  let finiteLegacy = try JSONDecoder().decode(Commander.self, from: finiteBytes)
  #expect(finiteLegacy.equipmentInventory == nil && finiteLegacy.savedEquipmentVersion == nil)
  let loadedFiniteLegacy = restored.load(finiteLegacy)
  try #require(loadedFiniteLegacy)
  #expect(restored.commander.credits == 1234 && restored.commander.xyzzyCashGranted)
}

private func selectActualMainStationWithTab(_ game: inout Game, stage: String) throws {
  let inFlight = !game.docked
  try #require(inFlight, "\(stage): selection requires flight")
  let unpaused = !game.paused
  let pauseFailure = "\(stage): paused; \(game.message)"
  try #require(unpaused, Comment(rawValue: pauseFailure))
  let flightScreen = game.screen.isFlight
  let screenFailure = "\(stage): screen \(game.screen)"
  try #require(flightScreen, Comment(rawValue: screenFailure))
  let shipsFilter = game.workTargetFilter == .ships
  let filterFailure = "\(stage): filter \(game.workTargetFilter)"
  try #require(shipsFilter, Comment(rawValue: filterFailure))
  let militaryCore = game.commander.targetingTier == .military
  try #require(militaryCore, "\(stage): military core must remain fitted")
  game.ensurePhysicalActors()
  let mainStation = game.bodies.first { $0.id == 0 && $0.hull == .station && $0.energy > 0 }
  let station = try #require(mainStation, "\(stage): actual main station must remain present")
  let actor = try #require(station.physical?.identity, "\(stage): main station must be adopted")
  let matchesAnchor = actor == game.commander.flightSimulation.anchors?.station.identity
  try #require(matchesAnchor)
  let validOrientation = game.modelPose(of: station).orientation.validRotation
  try #require(validOrientation)
  let finiteEnergy = station.energy.isFinite
  try #require(finiteEnergy, "\(stage): main station energy must be finite")
  let finitePosition = station.position.finite && station.position.length.isFinite
  try #require(finitePosition, "\(stage): main station position and distance must be finite")
  let currentActor =
    actor.system == game.systemIdentity && actor.visit == game.commander.flightSimulation.visit
  try #require(currentActor, "\(stage): main station actor must belong to the current visit")
  let matchingActors = game.bodies.filter { $0.physical?.identity == actor }.map(\.id)
  try #require(matchingActors == [0], "\(stage): main station actor must be unique")
  var selections: [Int?] = []
  // Reconciliation preserves visited targets while new traffic can precede them.
  // If zero was already visited, finish at most N-1 pending targets, then scan
  // one fresh cycle of at most N. No simulation advances during these Tabs.
  let candidateUpperBound = game.bodies.count
  let pendingTailBudget = candidateUpperBound - 1
  let freshCycleBudget = candidateUpperBound
  let limit = pendingTailBudget + freshCycleBudget
  for _ in 0..<limit {
    game.key("tab")
    selections.append(game.autoPilot.targetID)
    if game.autoPilot.targetID == 0 { break }
  }
  let selectedMainStation = game.autoPilot.targetID == 0
  let dockingEngaged = game.dockingComputer
  var selectionFailure =
    "\(stage): selections \(selections), screen \(game.screen), paused \(game.paused), message \(game.message)"
  if !selectedMainStation || !dockingEngaged {
    selectionFailure += stationTabEligibilityFailureFacts(game, mainActor: actor)
  }
  try #require(selectedMainStation && dockingEngaged, Comment(rawValue: selectionFailure))
}

// Keep large eligibility observations out of the successful Tab helper's frame.
@inline(never)
private func stationTabEligibilityFailureFacts(_ game: borrowing Game, mainActor: ActorIdentity)
  -> String
{
  guard let context = game.gameplayContext() else { return "; no gameplay context" }
  let layout = CockpitLayout(game: game, width: game.viewportWidth, height: game.viewportHeight)
  var candidates: [WorkTargetCandidate] = []
  for body in game.bodies {
    let front = Display.visibleInFront(body, game: game, layout: layout)
    if let candidate = game.workTargetCandidate(for: body, context: context, frontVisible: front) {
      candidates.append(candidate)
    }
  }
  let capabilities = game.workTargetCapabilities
  let choices = WorkTargetSelection.ordered(
    candidates, filter: game.workTargetFilter, system: context.system, visit: context.visit,
    capabilities: capabilities)
  let mainCandidates = candidates.filter { $0.identity == mainActor }
  let mainDecisions = mainCandidates.map {
    WorkTargetSelection.evaluate(
      $0, system: context.system, visit: context.visit, capabilities: capabilities)
  }
  let choiceActors = Set(choices.map { $0.candidate.identity })
  let eligibleIDs = game.bodies.filter {
    $0.physical.map { choiceActors.contains($0.identity) } == true
  }.map(\.id)
  return
    "; context \(context.system)/\(context.visit), player \(context.player.identity), eligible IDs \(eligibleIDs), main candidates \(mainCandidates), main decisions \(mainDecisions)"
}

// Direct controller inputs isolate cycle reconciliation; these bodies assert no native custody.
@Test func stationTabReengagementCompletesThePreservedTailBeforeAFreshCycle() {
  let origin = ActorIdentity(system: .init(galaxy: 0, system: 7), visit: 1, entity: 0)
  let signature = "military:ships:station-cycle-fixture"
  let original: [SpaceBody] = [
    .init(id: 1, hull: .cobra, position: .init(0, 0, 100)),
    .init(id: 0, hull: .station, position: .init(0, 0, 200)),
    .init(id: 10, hull: .station, position: .init(0, 0, 300)),
  ]
  var control = AutoTargetControl()
  for expected in [1, 0] {
    control.cycle(original, frontIDs: [1], signature: signature, origin: origin)
    #expect(control.targetID == expected)
  }
  control.disengage()
  #expect(control.targetID == nil)

  // A flight frame admits two ships around the previously visited ship's distance.
  // Ship-first ordering becomes [11,1,12,0,10]; the visited {1,0} still belongs
  // to the old cycle, so its reconciled pending tail must be [11,12,10].
  let current =
    original + [
      SpaceBody(id: 11, hull: .viper, position: .init(0, 0, 50)),
      SpaceBody(id: 12, hull: .sidewinder, position: .init(0, 0, 150)),
    ]
  let scene = current + [SpaceBody(id: 2, hull: .asteroid, position: .init(0, 0, 400))]
  var selections: [Int?] = []
  for expected in [11, 12, 10, 11, 1, 12, 0] {
    control.cycle(current, frontIDs: [1, 11, 12], signature: signature, origin: origin)
    selections.append(control.targetID)
    #expect(control.targetID == expected)
  }
  let oldBoundSelections = Array(selections.prefix(scene.count))
  #expect(oldBoundSelections == [11, 12, 10, 11, 1, 12])
  #expect(!oldBoundSelections.contains(0))
  #expect(control.targetID == 0)
  #expect(selections.count > scene.count)
  #expect(selections.count <= (scene.count - 1) + scene.count)
}

@Test func tabEngagesFullStationDockingWhenXYZzyAssistanceIsOffAndCIsRemoved() throws {
  var game = Game(executive: false)
  game.launch()
  try #require(!game.docked && game.commander.valid)
  game.key("tab")
  #expect(game.message == "FIT A TARGETING COMPUTER" && !game.dockingComputer)
  try game.commander.grantEquipment(
    TargetingTier.military.equipmentName, at: .targetingCore,
    provenance: .grant("station targeting fixture"))
  #expect(game.commander.targetingTier == .military)
  game.commander.xyzzyActive = true
  game.commander.autoTarget = false
  // The fresh scene has no salvage targets. Ordinary ships, intact rocks and
  // authentic stations remain present but cannot satisfy the salvage filter.
  try #require(
    game.bodies.allSatisfy { body in
      [Hull.cobra, .viper, .sidewinder, .station, .asteroid, .missile].contains(body.hull)
        && body.physical?.salvage == nil && body.physical?.payload == nil
        && body.physical?.empCrewPod == nil
    })
  game.workTargetFilter = .salvage
  game.key("tab")
  #expect(game.message == "NO ELIGIBLE TARGETS" && game.autoPilot.targetID == nil)
  #expect(!game.dockingComputer)
  game.workTargetFilter = .ships
  let anchor = try #require(game.commander.flightSimulation.anchors?.station)
  NativePagedSalvageFixture.moveObserver(
    &game, to: .init(position: anchor.position + .init(-300, 0, -1500)))
  game.screen = .rear
  game.key("c")
  #expect(!game.dockingComputer && game.autoPilot.targetID == nil)
  try selectActualMainStationWithTab(&game, stage: "initial engagement after removed C")
  #expect(game.screen == .front && game.dockingComputer && game.autoPilot.targetID == 0)
  #expect(game.message == "AUTO DOCKING ENGAGED")
  game.tick(delta: 0.1)
  #expect(game.autoPilot.velocity.length > 0 && game.dockingComputer)
  #expect(game.autoHUDLines.contains { $0.contains("AUTO:") })
  game.key("p")
  #expect(!game.dockingComputer && game.autoPilot.targetID == nil)
  try selectActualMainStationWithTab(&game, stage: "reengagement after P")
  game.key("q")
  #expect(!game.dockingComputer && game.autoPilot.targetID == nil)
  try selectActualMainStationWithTab(&game, stage: "reengagement after Q")
  game.key("5")
  #expect(!game.dockingComputer && game.autoPilot.targetID == nil)
  game.key("0")
  try selectActualMainStationWithTab(&game, stage: "reengagement after chart return")
  for _ in 0..<2500 where !game.docked { game.tick(delta: 0.1) }
  #expect(game.docked && !game.dockingComputer && game.screen == .status)
}
