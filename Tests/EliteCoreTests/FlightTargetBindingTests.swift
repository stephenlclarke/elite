import Testing

@testable import EliteCore

private func tabTargetGame() throws -> Game {
  var game = Game(executive: false)
  try game.commander.prepareEquipment(legacy: false)
  try game.commander.grantEquipment(
    TargetingTier.military.equipmentName, at: .targetingCore,
    provenance: .grant("flight target binding regression"))
  game.launch()
  game.speed = 0
  return game
}

struct FlightTargetBindingTests {
  @Test func tabUsesTheExistingShipThenStationCycleAndRHasNoActionInAnyFlightView() throws {
    for screen in [Screen.front, .rear, .left, .right] {
      var game = try tabTargetGame()
      game.screen = screen
      let before = game.commander
      let message = game.message
      game.key("r")
      #expect(game.screen == screen && game.commander == before && game.message == message)
      #expect(
        game.autoPilot.targetID == nil && game.weaponsTargetID == nil && !game.dockingComputer)
      game.key("tab")
      let ship = try #require(game.autoTargetBody)
      #expect(game.screen == .front && ship.id == 1 && ship.hull == .cobra)
      let target = game.autoPilot.targetID
      let status = game.autoPilot.status
      game.key("r")
      #expect(game.autoPilot.targetID == target && game.autoPilot.status == status)
      game.key("tab")
      #expect(game.autoTargetBody?.id == 0 && game.dockingComputer)
    }
  }

  @Test func actorTabSelectsTargetsAndRDoesNotClearExistingSteeringControls() async throws {
    let runtime = GameRuntime(game: try tabTargetGame())
    await runtime.key("tab")
    let selected = await runtime.snapshot()
    try #require(selected.autoTargetBody?.hull == .cobra)
    var controls = Controls()
    controls.pitch = 0.5
    controls.yaw = -0.25
    controls.roll = 0.75
    controls.throttle = 1
    await runtime.setControls(controls)
    await runtime.key("r")
    let unchanged = await runtime.snapshot()
    let retained = await runtime.controls
    #expect(unchanged.commander == selected.commander)
    #expect(unchanged.autoPilot.targetID == selected.autoPilot.targetID)
    #expect(retained.pitch == controls.pitch && retained.yaw == controls.yaw)
    #expect(retained.roll == controls.roll && retained.throttle == controls.throttle)
    await runtime.key("tab")
    let station = await runtime.snapshot()
    let dockControls = await runtime.controls
    #expect(station.autoTargetBody?.id == 0 && station.dockingComputer)
    #expect(dockControls.pitch == 0 && dockControls.yaw == 0 && dockControls.roll == 0)
    #expect(dockControls.throttle == 0 && !dockControls.fire)
  }

  @Test func rRemainsOrdinaryChartAndShowroomSearchText() {
    var game = Game(executive: false)
    game.screen = .status
    game.key("4")
    game.key("/")
    game.key("r")
    #expect(game.acceptsTextInput && game.mapSearch.query == "r" && game.screen == .chart)
    game.key("screen:6")
    game.key("/")
    game.key("r")
    #expect(game.acceptsTextInput && game.showroom.query == "r" && game.screen == .showroom)
    #expect(game.autoPilot.targetID == nil && !game.dockingComputer)
  }
}
