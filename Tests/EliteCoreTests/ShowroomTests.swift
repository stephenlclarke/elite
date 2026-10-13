import Foundation
import Testing

@testable import EliteCore

private func showroomGame() -> Game {
  var game = Game(executive: false)
  game.screen = .equipment
  game.selection = Equipment.all.count - 1
  game.key("w")
  return game
}

@Test func showroomCataloguePreservesEveryCanonicalShipRefitAndSourceUnit() throws {
  #expect(ShipCatalogue.all.count == 167)
  #expect(Set(ShipCatalogue.all.map(\.id)).count == 167)
  #expect(ShipCatalogue.all.filter(\.refit).count == 158)
  #expect(ShipCatalogue.modelCount == 74)
  #expect(ShipCatalogue.all.contains { $0.name == "Eagle Mk I" && $0.appearances.contains("FE2") })
  #expect(
    ShipCatalogue.all.contains { $0.id == "SH165" && $0.modelSource?.contains("Vector") == true })
  let cobra = try #require(ShipCatalogue.ship("SH023"))
  let project = try #require(cobra.profiles.first { $0.group == "project-refit-v1" })
  #expect(project.fields.contains { $0.key == "cargo_tonnes" && $0.number == 20 && $0.unit == "t" })
  #expect(
    project.fields.contains {
      $0.key == "maximum_speed_project_units" && $0.unit == "project units/s"
    })
  #expect(
    project.fields.contains { $0.key == "required_crew_including_commander" && !$0.status.isEmpty })
  #expect(cobra.profiles.contains { $0.group.hasPrefix("crew-") })
  for ship in ShipCatalogue.all {
    if let mesh = ship.previewMesh {
      #expect(mesh.vertices.allSatisfy { $0.finite && $0.length <= 100.0001 })
      #expect(!mesh.faces.isEmpty)
      #expect(
        mesh.faces.allSatisfy {
          $0.count >= 3 && $0.allSatisfy { mesh.vertices.indices.contains($0) }
        })
      #expect(ship.modelSource != nil)
    } else {
      #expect(ship.model == nil)
    }
  }
}

@Test func showroomEntryIsDockedOnlyAndBackRestoresStationSelectionAndCommander() {
  var game = Game(executive: false)
  game.launch()
  let commander = game.commander
  game.key("w")
  #expect(game.screen == .front && game.message == "DOCK TO VISIT THE SHIP SHOWROOM")
  #expect(game.commander == commander)
  game.dock()
  game.screen = .equipment
  game.selection = 12
  game.equipmentMount = .rear
  game.key("w")
  #expect(game.screen == .showroom)
  game.key("return")
  #expect(game.showroom.detail)
  game.key("escape")
  #expect(game.screen == .showroom && !game.showroom.detail)
  game.key("k")
  #expect(game.screen == .help && game.helpReturn == .showroom)
  game.key("k")
  game.key("w")
  #expect(game.screen == .equipment && game.selection == 12 && game.equipmentMount == .rear)
  for screen in [Screen.secret, .mission, .handoff, .gallery, .help, .demo, .title, .gameOver] {
    game.screen = screen
    game.openShowroom()
    #expect(game.screen == screen)
  }
}

@Test func showroomSearchFindsEveryShipAndSupportsNamesSourcesClassesAndNoResults() {
  var game = showroomGame()
  for ship in ShipCatalogue.all {
    game.showroom.query = ship.id
    #expect(game.showroomShips.map(\.id) == [ship.id])
    game.showroom.searching = true
    game.key("return")
    #expect(game.showroomShip?.id == ship.id)
  }
  game.showroom.query = "FE2"
  #expect(
    !game.showroomShips.isEmpty && game.showroomShips.allSatisfy { $0.appearances.contains("FE2") })
  game.showroom.query = "alien"
  #expect(game.showroomShips.allSatisfy { $0.shipClass.localizedCaseInsensitiveContains("alien") })
  game.showroom.query = ""
  game.key("/")
  for key in "vector" { game.key(String(key)) }
  #expect(game.showroomShip?.id == "SH165")
  game.key("backspace")
  #expect(game.showroom.query == "vecto")
  game.key("escape")
  game.showroom.query = "no such vessel"
  #expect(game.showroomShips.isEmpty)
  game.key("down")
  let frame = Display.presentation(game, width: 512, height: 518)
  #expect(frame.labels.contains { $0.text == "No matching ships" })
}

@Test func showroomRotationHasIndependentClockAndPausesWithoutAdvancingSimulation() {
  var game = showroomGame()
  game.bodies = [.init(id: 9, hull: .thargoid, position: .init(0, 0, 500), hostile: true)]
  let commander = game.commander
  let bodies = game.bodies
  let stars = game.starfield.positions
  let time = game.time
  for _ in 0..<10 { game.tick(delta: 0.1, controls: .init()) }
  #expect(abs(game.showroom.angle - 0.4) < 0.0001)
  #expect(game.commander == commander && game.bodies == bodies && game.starfield.positions == stars)
  #expect(game.time == time)
  game.key(" ")
  let angle = game.showroom.angle
  for _ in 0..<10 { game.tick(delta: 0.1) }
  #expect(game.showroom.angle == angle)
  game.key(" ")
  game.tick(delta: 0.1)
  #expect(game.showroom.angle > angle)
  var second = showroomGame()
  for _ in 0..<50 { second.tick(delta: 0.02) }
  #expect(abs(second.showroom.angle - 0.4) < 0.0001)
}

@Test func showroomPinComparisonRetainsBaselineAndOnlySubtractsCompatibleMetrics() throws {
  var game = showroomGame()
  game.showroom.selection = "SH001"
  let row = try #require(game.showroomComparison.first { $0.label == "Cargo" })
  #expect(row.difference == "Diff -18 t")
  game.key("b")
  game.key("down")
  #expect(game.showroom.baseline == "SH001" && game.showroom.selection != "SH001")
  game.key("r")
  #expect(game.showroom.baseline == "SH023")
  game.key("v")
  #expect(game.showroom.sourceProfiles)
  game.key(".")
  game.key(",")
  game.key("c")
  #expect(!game.showroom.compare)
  game.key("pagedown")
  #expect(game.showroom.scroll == 8)
  game.key("pageup")
  #expect(game.showroom.scroll == 0)
  let a = ShipSpec(
    key: "speed", label: "Speed", text: "0", number: 0, unit: "m/s", status: "source", basis: "")
  let b = ShipSpec(
    key: "speed", label: "Speed", text: "2", number: 2, unit: "raw", status: "source", basis: "")
  #expect(ShipComparisonRow.difference(a, b, comparable: true).isEmpty)
  #expect(ShipComparisonRow.difference(nil, a, comparable: true).isEmpty)
  #expect(ShipComparisonRow.difference(a, a, comparable: false).isEmpty)
  #expect(ShipComparisonRow.difference(a, a, comparable: true) == "Diff +0 m/s")
}

@Test func showroomMouseAndScrollUseResponsiveRegionsAndDoNotChangeEquipment() {
  var game = showroomGame()
  let commander = game.commander
  for width in [512.0, 768, 1000, 1512] {
    game.viewportWidth = width
    game.viewportHeight = 768
    game.showroom.detail = false
    game.showroom.query = ""
    let layout = ShowroomLayout(width: width, height: 768, detail: false)
    game.showroomClick(x: layout.list.x + 20, y: layout.list.y + 5)
    let first = game.showroom.selection
    game.key("showroom-list:1")
    #expect(game.showroom.selection != first)
    game.key("showroom-list:-1")
    #expect(game.showroom.selection == first)
    for bounds in layout.buttons {
      game.showroomClick(x: bounds.x + 2, y: bounds.y + 2)
    }
    game.showroom.detail = true
    game.key("showroom-scroll:1")
    #expect(game.showroom.scroll == 1)
    game.key("up")
    #expect(game.showroom.scroll == 0)
    game.key("down")
    #expect(game.showroom.scroll == 1)
    game.showroom.detail = false
    game.showroomClick(x: layout.search.x + 2, y: layout.search.y + 2)
    #expect(game.showroom.searching)
    game.key("return")
    game.showroomClick(x: -1, y: -1)
    #expect(game.commander == commander)
  }
  let layout = ShowroomLayout(width: game.viewportWidth, height: 768, detail: false)
  game.showroomClick(x: layout.close.x + 2, y: layout.close.y + 2)
  #expect(game.screen == .equipment && game.commander == commander)
}

@Test func showroomSourceModelsAreShadedAndMissingModelsNeverUseSurrogates() throws {
  var game = showroomGame()
  for ship in ShipCatalogue.all where ship.previewMesh != nil {
    game.showroom.selection = ship.id
    game.showroom.compare = false
    game.showroom.detail = true
    let frame = Display.presentation(game, width: 1512, height: 982)
    #expect(!frame.shipPanels.isEmpty, "\(ship.name)")
    #expect(frame.shipLines.isEmpty)
  }
  game.showroom.selection = "SH002"
  game.showroom.compare = false
  let missing = Display.presentation(game, width: 512, height: 518)
  #expect(missing.shipPanels.isEmpty)
  #expect(missing.labels.contains { $0.text == "Model unavailable" })
  game.showroom.selection = "SH023"
  let before = Display.presentation(game, width: 1512, height: 982).shipPanels
  game.tick(delta: 0.1)
  #expect(Display.presentation(game, width: 1512, height: 982).shipPanels != before)
  game.commander.installLaser(.naval, on: .rear)
  game.showroom.scroll = 10000
  let current = Display.presentation(game, width: 1512, height: 982)
  #expect(current.labels.contains { $0.text.contains("Rear: Naval Laser") })
}

@Test func showroomActorSavingAndConcurrentBrowsingKeepCommanderUnchanged() async throws {
  let game = showroomGame()
  let runtime = GameRuntime(game: game)
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  await withTaskGroup(of: Void.self) { tasks in
    for _ in 0..<10 { tasks.addTask { _ = await runtime.advance(delta: 0.02) } }
  }
  try await runtime.save(to: url)
  let saved = try JSONDecoder().decode(Commander.self, from: Data(contentsOf: url))
  #expect(saved == game.commander)
  #expect(await runtime.snapshot().time == game.time)
  try await runtime.load(from: url)
  #expect(await runtime.snapshot().screen == .status)
}

@Test func showroomComparisonMeasuresCompleteLabelsAndKeepsValueGuttersAtEverySize() throws {
  var game = showroomGame()
  game.showroom.detail = true
  for width in [512.0, 768, 1000, 1512, 1800, 2560] {
    let outer = ShowroomLayout(width: width, height: 1160, detail: true)
    let labels = ["Comparison"] + game.showroomComparison.map(\.label)
    let layout = ShipComparisonLayout(width: outer.details.width, labels: labels)
    if width >= 1000 {
      #expect(
        labels.allSatisfy {
          Double($0.count) * 6 * GameTypography.scale <= layout.labelWidth
        })
    }
    var found = Set<String>()
    for scroll in stride(from: 0, to: 200, by: 8) {
      game.showroom.scroll = scroll
      let frame = Display.presentation(game, width: width, height: 1160)
      let cells = frame.labels.filter { $0.y >= outer.details.y && $0.y < outer.details.maxY }
      for label in cells where label.ink == .yellow && labels.contains(label.text) {
        found.insert(label.text)
        let baseline = cells.first { $0.y == label.y && $0.x == outer.details.x + layout.baselineX }
        let selected = cells.first { $0.y == label.y && $0.x == outer.details.x + layout.selectedX }
        let left = try #require(baseline)
        let right = try #require(selected)
        #expect(label.bounds.maxX + 16 <= left.x)
        #expect(left.bounds.maxX + 16 <= right.x)
      }
      #expect(cells.allSatisfy { $0.scale == GameTypography.scale && $0.bounds.maxX <= width - 16 })
    }
    if width >= 1000 { #expect(found.isSuperset(of: labels)) }
  }
  game.showroom.selection = "SH001"
  #expect(game.showroomTradeoffs.contains("Less cargo capacity"))
  #expect(!game.showroomTradeoffs.contains { $0.contains("speed") })
}

@Test func showroomLongSourceTokensWrapWithoutOverlappingAdjacentComparisonValues() {
  for text in [
    "EQ_SOME_SOURCE_EQUIPMENT_WITH_A_LONG_IDENTIFIER",
    "[borrowed source-specific operating crew complement]", "", "A short description",
  ] {
    for width in [8, 16, 40, 100] {
      let lines = ShowroomText.wrap(text, width: width)
      #expect(lines.allSatisfy { $0.count <= width })
      #expect(lines.joined().filter { !$0.isWhitespace } == text.filter { !$0.isWhitespace })
    }
  }
}

@Test func catalogueDefaultsEstimatesAndActualNativeFitKeepTheirProvenanceDistinct() throws {
  let adder = try #require(ShipCatalogue.ship("SH001"))
  let oolite = try #require(adder.profiles.first { $0.id == "O08-adder" })
  let yaw = try #require(oolite.fields.first { $0.key == "max_flight_yaw" })
  let pitch = try #require(oolite.fields.first { $0.key == "max_flight_pitch" })
  #expect(yaw.number == pitch.number && yaw.status == "source engine default")
  let gba = try #require(adder.profiles.first { $0.group == "gba-npc" })
  #expect(
    gba.fields.contains {
      $0.key == "player_cargo_capacity_tonnes" && $0.number == 2
        && $0.status.contains("low confidence") && !$0.basis.isEmpty
    })
  let missingModel = try #require(ShipCatalogue.ship("SH002"))
  #expect(missingModel.previewMesh == nil && missingModel.dimensions != nil)
  #expect(missingModel.geometryContext.contains("low confidence"))
  let transporter = try #require(ShipCatalogue.ship("SH128"))
  let passengerFact = try #require(
    transporter.profiles.first { $0.group.contains("passengeruppercapacity") })
  #expect(
    passengerFact.fields.count == 1
      && passengerFact.fields[0].label == "Documented passenger capacity")
  var game = showroomGame()
  game.commander.equipment.insert(Equipment.navalEnergyUnit)
  #expect(
    game.currentShowroomProfile.fields.contains {
      $0.key == "maximum_speed_project_units" && $0.number == 576 && $0.unit == "native units/s"
    })
  #expect(
    game.currentShowroomProfile.fields.contains {
      $0.key == "energy_recharge_per_second" && $0.number == 6
    })
  game.commander.unlimitedCargo = true
  let unlimited = try #require(
    game.currentShowroomProfile.fields.first { $0.key == "cargo_tonnes" })
  #expect(unlimited.text == "Unlimited (XYZZY)" && unlimited.number == nil)
  let fact = ShipSpec(
    key: "cargo", label: "Cargo", text: "2 t", number: 2, unit: "t", status: "source", basis: "")
  let estimated = ShipSpec(
    key: "cargo", label: "Cargo", text: "4 t", number: 4, unit: "t",
    status: "estimated - low confidence", basis: "Same canonical project refit")
  #expect(
    ShipComparisonRow.difference(fact, estimated, comparable: true) == "Diff +2 t (estimated)")
  #expect(
    ShipCatalogue.all.flatMap(\.profiles).flatMap(\.fields).filter {
      $0.status.contains("estimated")
    }.allSatisfy { !$0.basis.isEmpty })
}

@Test func sourceAssembliesRetainDistinctHydrasAndCourierNacellesWithoutGrantingHulls() throws {
  let courier = try #require(ShipCatalogue.ship("SH063"))
  #expect(courier.previewMesh?.vertices.count == 136)
  #expect(courier.modelSource?.contains("Oolite rendition") == true)
  #expect(ShipCatalogue.ship("SH158")?.previewMesh?.vertices.count == 78)
  #expect(ShipCatalogue.ship("SH159")?.previewMesh?.vertices.count == 98)
  #expect(ShipCatalogue.ship("SH156")?.previewMesh?.vertices.count == 358)
  #expect(ShipCatalogue.ship("SH155")?.previewMesh?.faces.count == 680)
  let unresolved = ["SH017", "SH036"]
  #expect(unresolved.allSatisfy { ShipCatalogue.ship($0)?.previewMesh == nil })
  #expect(ShipCatalogue.all.allSatisfy { !$0.profiles.isEmpty })
  for ship in ShipCatalogue.all.filter({ $0.model?.hasPrefix("xyzzy-showroom-") == true }) {
    var game = showroomGame()
    game.showroom.selection = ship.id
    game.showroom.detail = true
    for width in [512.0, 1000, 1512] {
      let frame = Display.presentation(game, width: width, height: 768)
      #expect(!frame.shipPanels.isEmpty)
      #expect(frame.labels.allSatisfy { $0.bounds.x >= 0 && $0.bounds.maxX <= width })
    }
    #expect(game.commander.name == "JAMESON")
  }
}

@Test func showroomFiltersAreVisibleClearableAndNeverChangeTheOwnedCobra() throws {
  var game = showroomGame()
  let commander = game.commander
  game.showroom.query = "SH063"
  for width in [512.0, 768, 1512] {
    let frame = Display.presentation(game, width: width, height: 768)
    #expect(
      frame.labels.contains {
        $0.text.contains("FILTER ACTIVE: 1/167 ships") && $0.text.contains("You own: Cobra Mk III")
      })
    #expect(frame.labels.contains { $0.text == "X: Clear filter" })
  }
  game.key("x")
  #expect(game.showroomShips.count == 167)
  game.key("/")
  for key in "SH063" { game.key(String(key)) }
  game.key("delete")
  #expect(game.showroom.query.isEmpty && game.showroomShips.count == 167)
  game.showroom.query = "SH063"
  game.showroom.selection = "SH063"
  game.viewportWidth = 1512
  game.viewportHeight = 982
  let layout = ShowroomLayout(width: 1512, height: 982, detail: false)
  game.showroomClick(x: layout.clearSearch.x + 5, y: layout.clearSearch.y + 5)
  #expect(game.showroomShips.count == 167 && game.showroom.selection == "SH063")
  game.showroom.query = "SH063"
  game.key("w")
  game.key("w")
  #expect(game.showroom.query.isEmpty && game.showroom.selection == "SH023")
  let frame = Display.presentation(game, width: 1512, height: 982)
  #expect(frame.labels.contains { $0.text == "Your Cobra Mk III" })
  #expect(frame.labels.contains { $0.text.contains("Your fitted Cobra / Oolite model") })
  #expect(!frame.labels.contains { $0.text.contains("Current native model") })
  #expect(game.commander == commander)
  game.showroom.selection = "SH001"
  game.key("b")
  let pinned = Display.presentation(game, width: 1512, height: 982)
  #expect(pinned.labels.contains { $0.text == "PINNED BASELINE" })
  game.key("r")
  #expect(game.showroom.baselineUsesCurrent && game.commander == commander)
}
