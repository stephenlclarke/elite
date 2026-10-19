import Foundation
import Testing

@testable import EliteCore

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
  game.commander.system = try #require(game.systems.first { $0.technology >= 10 }?.id)
  game.selection = try #require(Equipment.all.firstIndex { $0.name == "Mining Laser" })
  game.key("return")
  #expect(game.commander.equipment.contains("Mining Laser") && game.commander.credits == 992_000)
  for name in [
    Equipment.navalLaser, ShieldBooster.capital.equipmentName,
  ] {
    game.selection = try #require(Equipment.all.firstIndex { $0.name == name })
    game.key("return")
    #expect(!game.commander.equipment.contains(name) && game.commander.credits == 992_000)
    #expect(game.message.hasSuffix("NOT FOR SALE"))
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
    let saved = await writer.snapshot()
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
    #expect(stored == expectedStored)
    let reader = GameRuntime(game: Game(executive: false))
    // Binding restoration is transient; retain the actual writer bytes for this current save.
    try await reader.load(from: url, persistMigrations: false)
    let loaded = await reader.snapshot()
    let reloadedBytes = try Data(contentsOf: url)
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
  var selections: [Int?] = []
  // Each real candidate can be visited once before wrapping; no traffic is removed.
  let limit = game.bodies.count
  for _ in 0..<limit {
    game.key("tab")
    selections.append(game.autoPilot.targetID)
    if game.autoPilot.targetID == 0 { break }
  }
  let selectedMainStation = game.autoPilot.targetID == 0
  let dockingEngaged = game.dockingComputer
  let selectionFailure =
    "\(stage): selections \(selections), screen \(game.screen), paused \(game.paused), message \(game.message)"
  try #require(selectedMainStation && dockingEngaged, Comment(rawValue: selectionFailure))
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
