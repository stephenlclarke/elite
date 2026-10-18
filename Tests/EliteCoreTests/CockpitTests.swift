import Testing

@testable import EliteCore

@Test func cockpitKeepsLabelsReadableWithinWindowAndUsesFullWidth() {
  var game = Game(executive: false)
  game.commander.shipDisplayStyle = .whiteWireframe
  game.launch()
  game.bodies[1].position = .init(0, 0, 500)
  for width in [512.0, 768, 1024, 1512, 2560] {
    for height in [518.0, 768, 982] {
      let frame = Display.cockpit(game, width: width, height: height)
      #expect(frame.canvas.width == width && frame.flightClip.width == width)
      #expect(
        frame.flightClip.maxY < CockpitLayout(game: game, width: width, height: height).dashboardTop
      )
      #expect(!frame.shipLines.isEmpty)
      for label in frame.labels {
        #expect(label.bounds.x >= 0 && label.bounds.maxX <= width)
        #expect(label.bounds.y >= 0 && label.bounds.maxY <= height)
      }
      let required = [
        "Front shield", "Rear shield", "Fuel", "Cabin temp", "Laser heat", "Altitude", "Speed",
        "Roll neutral", "Pitch neutral", "Energy", "Scanner", "Status: Safe",
      ]
      #expect(required.allSatisfy { value in frame.labels.contains { $0.text == value } })
      for (index, label) in frame.labels.enumerated() {
        for other in frame.labels.dropFirst(index + 1) {
          let a = label.bounds
          let b = other.bounds
          #expect(a.maxX <= b.x || b.maxX <= a.x || a.maxY <= b.y || b.maxY <= a.y)
        }
      }
    }
  }
}

@Test func missileIconsExpressZeroFiniteUnlimitedAndArmedWithoutOnlyColour() throws {
  var game = Game(executive: false)
  game.commander.missiles = 0
  game.launch()
  for count in 0...4 {
    if count > 0 {
      try game.commander.grantEquipment(
        "Missile", at: .missilePylon(count - 1), provenance: .grant("missile icon fixture"))
      #expect(
        game.commander.fittedEquipment(at: .missilePylon(count - 1))?.node
          == EquipmentRuntimeCatalog.standardMissile)
    }
    #expect(game.commander.missiles == count)
    #expect(game.missileIconCount == count)
    let frame = Display.cockpit(game, width: 1024, height: 768)
    #expect(frame.labels.contains { $0.text == "Unarmed" })
    #expect(frame.labels.contains { $0.text == "None" } == (count == 0))
    #expect(!frame.labels.contains { $0.text == "~" })
  }
  for pylon in 0..<4 {
    let round = try #require(game.commander.fittedEquipment(at: .missilePylon(pylon)))
    let revision = try #require(game.commander.equipmentInventory?.revision)
    try game.commander.storeEquipment(round, expectedRevision: revision)
  }
  #expect(game.commander.missiles == 0)
  game.commander.unlimitedMissiles = true
  game.key("t")
  #expect(game.missileArmed && game.missileIconCount == 1)
  let frame = Display.cockpit(game, width: 512, height: 518)
  #expect(frame.labels.contains { $0.text == "~" } && frame.labels.contains { $0.text == "Armed" })
  game.commander.flightSimulation.pose.position = .init(0, 0, -3000)
  game.bodies = [.init(id: 70, hull: .cobra, position: .init(0, 0, 1800))]
  game.ensurePhysicalActors()
  let target = try #require(game.bodies[0].physical?.identity)
  let inventory = try #require(game.commander.equipmentInventory)
  let launched = game.fireMissile()
  #expect(launched)
  let origin = try #require(
    game.bodies.first { $0.physical?.ordnance != nil }?.physical?.attackOrigin)
  let flight = try #require(game.bodies.first { $0.physical?.ordnance != nil }?.physical?.ordnance)
  #expect(origin.playerAmmunition == .virtualUnlimited && flight.target == target)
  #expect(game.commander.equipmentInventory == inventory)
  #expect(!game.missileArmed && game.commander.missiles == 0)
}

@Test func xyzzyDefaultsAllSwitchesAndRetainsIndividualChoicesOnReentry() {
  var game = Game(executive: false)
  game.key("return")
  let system = game.commander.system
  for key in "xyzzy" { game.key(String(key)) }
  #expect(game.commander.xyzzyActive && game.commander.name == "CLARKE")
  #expect(
    game.commander.unlimitedMissiles && game.commander.unlimitedFuel
      && !game.commander.unlimitedJumps)
  #expect(
    !game.commander.unlimitedCash && game.commander.unlimitedCargo && game.commander.autoTrade)
  #expect(game.commander.speech && game.commander.autoECM && game.commander.autoTarget)
  #expect(game.commander.equipment.contains("E.C.M. System") && game.commander.cargoTonnes > 0)
  #expect(game.commander.system == system && game.commander.shipDisplayStyle == .shadedPanels)
  for key in ["3", "4", "5", "6", "7", "9", "e", "a"] { game.key(key) }
  game.commander.cargo = Array(repeating: 0, count: 17)
  game.key("8")
  game.key("return")
  for key in "xyzzy" { game.key(String(key)) }
  #expect(!game.commander.autoECM && !game.commander.autoTarget && !game.commander.autoTrade)
  #expect(!game.commander.unlimitedCargo && !game.commander.unlimitedMissiles)
}

@Test func xyzzyFuelScoopsAreFittedAndCollectCargoOnlyThroughTheLowerScoop() throws {
  var game = Game(executive: false)
  game.launch()
  game.speed = 0
  game.bodies = [.init(id: 1, hull: .cargo, position: .init(0, -20, 40))]
  game.tick(delta: 0.01)
  #expect(game.commander.cargo[0] == 0 && game.bodies.count == 1)
  for key in "xyzzy" { game.key(String(key)) }
  game.key("return")
  #expect(game.commander.equipment.contains("Fuel Scoops"))
  game.tick(delta: 0.01)
  #expect(game.commander.cargo[0] == 1 && game.bodies.isEmpty)
  game.tick(delta: 0.01)
  #expect(game.commander.cargo[0] == 1)
  game.commander.unlimitedCargo = false
  let bay = try #require(game.commander.fittedEquipment(at: .utility(.cargoExpansion)))
  try #require(bay.node.key == "Large Cargo Bay")
  try #require(game.commander.nativePerformance.cargo == 30)
  try #require(game.commander.nativePerformance.cargoExpansion == 15)
  try #require(game.commander.cargo.dropFirst().allSatisfy { $0 == 0 })
  try #require(game.commander.accommodation.fittedBerths.isEmpty)
  try #require(game.commander.missionPayloadTonnes == 0)
  try #require(game.commander.nativePeople?.held.isEmpty ?? true)
  let finiteCapacity = game.commander.standardCargoCapacity
  try #require(finiteCapacity == 45 && game.commander.capacity == finiteCapacity)
  game.commander.cargo[0] = finiteCapacity
  try #require(game.commander.cargoTonnes == finiteCapacity && game.commander.valid)
  let fullCargo = game.commander.cargo
  let fullCash = game.commander.credits
  game.bodies = [.init(id: 2, hull: .cargo, position: .init(0, -20, 40))]
  game.tick(delta: 0.01)
  #expect(game.message == "CARGO HOLD FULL" && game.bodies.count == 1)
  #expect(game.commander.cargo == fullCargo && game.commander.credits == fullCash)
  try #require(game.bodies.count == 1)
  let remaining = try #require(game.bodies.firstIndex { $0.id == 2 && $0.hull == .cargo })
  game.commander.unlimitedCargo = true
  game.bodies[remaining].position.y = 20
  game.tick(delta: 0.01)
  #expect(game.bodies.count == 1 && game.bodies.first?.id == 2)
  #expect(game.commander.cargo == fullCargo && game.commander.credits == fullCash)
  game.bodies = [.init(id: 3, hull: .thargon, position: .init(0, -20, 40))]
  game.tick(delta: 0.01)
  #expect(game.commander.cargo[16] == 1 && game.bodies.isEmpty)
  for key in "xyzzy" { game.key(String(key)) }
  let scoops = try #require(game.commander.fittedEquipment(at: .utility(.fuelScoops)))
  let revision = try #require(game.commander.equipmentInventory?.revision)
  try game.commander.storeEquipment(scoops, expectedRevision: revision)
  #expect(game.commander.fittedEquipment(at: .utility(.fuelScoops)) == nil)
  #expect(!game.commander.equipment.contains("Fuel Scoops"))
  let cash = game.commander.credits
  game.key("f")
  #expect(game.commander.fittedEquipment(at: .utility(.fuelScoops))?.id == scoops.id)
  #expect(game.commander.equipment.contains("Fuel Scoops") && game.commander.credits == cash)
  #expect(game.commander.valid)
}

@Test func assistanceHUDKeepsTargetAndFlightWarningsVisibleWithinTheViewport() {
  var game = Game(executive: false)
  game.commander.installTargetingComputer(.military)
  game.launch()
  game.commander.xyzzyActive = true
  game.commander.autoTarget = true
  #expect(game.commander.equipmentInventory != nil && game.commander.targetingTier == .military)
  game.bodies = [.init(id: 1, hull: .cobra, position: .init(0, 0, 1000), hostile: true)]
  game.key("tab")
  game.key("v")
  game.key("]")
  game.tick(delta: 0.1)
  game.paused = true
  game.jumpCountdown = 12
  game.dockingComputer = true
  for width in [512.0, 1512] {
    let frame = Display.cockpit(game, width: width, height: 768)
    #expect(frame.labels.contains { $0.text == "Status: Hostile" })
    #expect(frame.labels.contains { $0.text.hasPrefix("Hyperspace:") })
    #expect(frame.labels.contains { $0.text == "Docking computer engaged" })
    #expect(frame.labels.contains { $0.text.hasPrefix("PAUSED") })
    #expect(frame.labels.contains { $0.text.hasPrefix("AUTO:") })
    #expect(frame.labels.contains { $0.text.hasPrefix("SPIN") })
    #expect(!frame.labels.contains { $0.text == "AUTO TARGET OFFSCREEN" })
    for label in frame.labels { #expect(label.bounds.maxX <= width && label.bounds.maxY <= 768) }
    game.bodies[0].position.z = -1000
    let behind = Display.cockpit(game, width: width, height: 768)
    #expect(behind.labels.contains { $0.text == "AUTO TARGET OFFSCREEN" })
    game.bodies[0].position.z = 1000
  }
  game.energy = 0
  #expect(game.flightStatus == "Destroyed")
  game.dock()
  #expect(game.flightStatus == "Docked")
  let docked = Display.cockpit(game, width: 512, height: 518)
  #expect(docked.worldGraphics.isEmpty && docked.labels.contains { $0.text == "Status: Docked" })
}
