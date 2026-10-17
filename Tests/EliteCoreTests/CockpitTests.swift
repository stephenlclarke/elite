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

@Test func missileIconsExpressZeroFiniteUnlimitedAndArmedWithoutOnlyColour() {
  var game = Game(executive: false)
  game.launch()
  for count in 0...4 {
    game.commander.missiles = count
    #expect(game.missileIconCount == count)
    let frame = Display.cockpit(game, width: 1024, height: 768)
    #expect(frame.labels.contains { $0.text == "Unarmed" })
    #expect(frame.labels.contains { $0.text == "None" } == (count == 0))
    #expect(!frame.labels.contains { $0.text == "~" })
  }
  game.commander.missiles = 0
  game.commander.unlimitedMissiles = true
  game.key("t")
  #expect(game.missileArmed && game.missileIconCount == 1)
  let frame = Display.cockpit(game, width: 512, height: 518)
  #expect(frame.labels.contains { $0.text == "~" } && frame.labels.contains { $0.text == "Armed" })
  game.fireMissile()
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
  game.commander.cargo[0] = 35
  game.bodies = [.init(id: 2, hull: .cargo, position: .init(0, -20, 40))]
  game.tick(delta: 0.01)
  #expect(game.message == "CARGO HOLD FULL" && game.bodies.count == 1)
  game.commander.unlimitedCargo = true
  game.bodies[0].position.y = 20
  game.tick(delta: 0.01)
  #expect(game.bodies.count == 1)
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
  game.key("r")
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
