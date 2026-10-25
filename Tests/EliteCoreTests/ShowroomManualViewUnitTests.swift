import Foundation
import Testing

@testable import EliteCore

struct ShowroomManualViewUnitTests {
  private func game(width: Double = 768, height: Double = 900) -> Game {
    var game = Game(executive: false)
    game.screen = .showroom
    game.viewportWidth = width
    game.viewportHeight = height
    game.showroom.detail = true
    game.showroom.selection = game.commander.shipID
    return game
  }

  private func close(_ a: Basis3, _ b: Basis3) -> Bool {
    (a.x - b.x).length < 0.000001 && (a.y - b.y).length < 0.000001
      && (a.z - b.z).length < 0.000001
  }

  @Test func modelDragRotatesBothRenderedPreviewsTogetherAndPausesAutomaticMotion() throws {
    for width in [512.0, 768, 1000, 1512] {
      var game = game(width: width)
      let commander = game.commander
      let layout = ShowroomLayout(width: width, height: 900, detail: true)
      let initial = Display.showroomScreen(game, width: width, height: 900).shipPanels
      game.showroomDrag(
        fromX: layout.model.x + 10, fromY: layout.model.y + 40,
        toX: layout.model.x + 40, toY: layout.model.y + 60, roll: false)
      #expect(game.showroom.rotationPaused)
      let frame = Display.showroomScreen(game, width: width, height: 900)
      #expect(frame.shipPanels != initial)
      let left = frame.shipPanels.filter { $0.vertices.allSatisfy { $0.x < layout.selectedModelX } }
      let right = frame.shipPanels.filter {
        $0.vertices.allSatisfy { $0.x >= layout.selectedModelX }
      }
      try #require(!left.isEmpty && left.count == right.count)
      let offset = layout.selectedModelX - layout.model.x
      for (a, b) in zip(left, right) {
        try #require(a.vertices.count == b.vertices.count)
        #expect(a.colour == b.colour)
        for (p, q) in zip(a.vertices, b.vertices) {
          #expect(abs(p.x + offset - q.x) < 0.000001 && abs(p.y - q.y) < 0.000001)
        }
      }
      game.showroom.advance(delta: 1)
      #expect(
        Display.showroomScreen(game, width: width, height: 900).shipPanels == frame.shipPanels)
      #expect(game.commander == commander)
    }
  }

  @Test func everyAxisTurnsThroughAFullCircleAndViewResetPreservesPinnedBaseline() {
    var game = game()
    game.showroom.baseline = "SH002"
    game.showroom.baselineUsesCurrent = false
    let initial = game.showroom.viewOrientation
    let commander = game.commander
    for axis in ShowroomViewAxis.allCases {
      game.showroom.viewAxis = axis
      game.showroomKey("l")
      #expect(!close(initial, game.showroom.viewOrientation))
      game.showroomKey("j")
      #expect(close(initial, game.showroom.viewOrientation))
      for _ in 0..<24 { game.showroomKey("l") }
      #expect(close(initial, game.showroom.viewOrientation))
      game.showroomKey("l")
      game.showroomKey("0")
      #expect(close(initial, game.showroom.viewOrientation) && game.showroom.rotationPaused)
      #expect(game.showroom.baseline == "SH002" && !game.showroom.baselineUsesCurrent)
    }
    let layout = ShowroomLayout(width: 768, height: 900, detail: true)
    game.showroomDrag(
      fromX: layout.model.x + 20, fromY: layout.model.y + 40,
      toX: layout.model.x + 60, toY: layout.model.y + 80, roll: true)
    var rollOnly = initial
    rollOnly.rotate(pitch: 0, roll: 0.4, yaw: 0)
    #expect(close(rollOnly, game.showroom.viewOrientation))
    game.showroomKey("0")
    game.showroomKey("r")
    #expect(game.showroom.baselineUsesCurrent && game.showroom.baseline == commander.shipID)
    #expect(close(initial, game.showroom.viewOrientation) && game.commander == commander)
  }

  @Test func calibratedPairsUseOneMetreScaleInTheActualRenderedPreview() throws {
    let small = try #require(ShipCatalogue.ship("SH002"))
    let large = try #require(ShipCatalogue.ship("SH043"))
    let smallRadius = try #require(small.physicalSourceContract).physicalMesh.showroomRadius
    let largeRadius = try #require(large.physicalSourceContract).physicalMesh.showroomRadius
    try #require(largeRadius > smallRadius * 2)
    let scale = ShowroomPreviewScale(ship: small, comparedWith: large, physicalSource: false)
    #expect(abs(scale.factor - smallRadius / largeRadius) < 0.000001)
    #expect(
      ShowroomPreviewScale(ship: large, comparedWith: small, physicalSource: false).factor == 1)
    // Keep the same small baseline mesh and viewport, changing only the compared hull.
    var game = game(width: 1512)
    game.showroom.baselineUsesCurrent = false
    game.showroom.baseline = small.id
    game.showroom.selection = small.id
    let layout = ShowroomLayout(width: 1512, height: 900, detail: true)
    func baselineWidth(_ frame: Frame) throws -> Double {
      let vertices = frame.shipPanels.filter {
        $0.vertices.allSatisfy { $0.x < layout.selectedModelX }
      }.flatMap(\.vertices)
      return try #require(vertices.map(\.x).max()) - #require(vertices.map(\.x).min())
    }
    let alone = try baselineWidth(Display.showroomScreen(game, width: 1512, height: 900))
    game.showroom.selection = large.id
    let compared = Display.showroomScreen(game, width: 1512, height: 900)
    #expect(try baselineWidth(compared) < alone * 0.6)
    #expect(compared.labels.filter { $0.text == "Shared metre scale" }.count == 2)
    let starting = try #require(ShipCatalogue.ship("SH025"))
    #expect(
      ShowroomPreviewScale(ship: starting, comparedWith: large, physicalSource: false).factor < 1)
  }

  @Test func unknownScaleIsDisclosedAndViewChangesCannotUnlockOrPurchaseACapital() throws {
    var game = game(width: 1512)
    game.showroom.baseline = "SH001"
    game.showroom.baselineUsesCurrent = false
    game.showroom.selection = "SH043"
    game.commander.credits = 10_000_000
    let before = game.commander
    let quote = try #require(game.shipTradeQuote)
    try #require(!quote.allowed)
    let frame = Display.showroomScreen(game, width: 1512, height: 900)
    #expect(frame.labels.contains { $0.text == "Uncalibrated scale" })
    #expect(frame.labels.contains { $0.text == "Scale not comparable" })
    #expect(!frame.labels.contains { $0.text == "Shared metre scale" })
    game.showroomKey("a")
    game.showroomKey("l")
    game.showroomKey("0")
    #expect(game.shipTradeQuote?.rows == quote.rows && game.commander == before)
    game.showroomKey("return")
    game.showroom.confirmTrade = true
    game.showroomKey("return")
    #expect(game.commander == before && game.showroom.trading)
  }

  @Test func viewButtonsAndHelpKeepResetSeparateFromBaselineAndSearchAndTradeContexts() throws {
    for width in [512.0, 1512] {
      var game = game(width: width, height: 540)
      let layout = ShowroomLayout(width: width, height: 540, detail: true)
      for key in ["showroom-axis", "showroom-minus", "showroom-plus", "showroom-reset-view"] {
        let index = try #require(ShowroomLayout.actionKeys.firstIndex(of: key))
        let bounds = layout.buttons[index]
        #expect(bounds.maxY < layout.trade.y && bounds.maxX <= width - 16)
        game.showroomClick(x: bounds.x + 2, y: bounds.y + 2)
        if key == "showroom-axis" { #expect(game.showroom.viewAxis == .pitch) }
      }
      #expect(close(game.showroom.viewOrientation, self.game().showroom.viewOrientation))
      let rows = PlayerHelp.pages(for: game).filter { $0.title == "SHIP SHOWROOM" }.flatMap(\.rows)
      #expect(rows.contains("0 - RESET VIEW; R - YOUR SHIP BASELINE"))
      #expect(rows.contains("A - VIEW AXIS; J / L - ROTATE AXIS"))
      #expect(rows.contains("DRAG MODEL - PITCH / YAW; SHIFT - ROLL"))
      game.showroom.searching = true
      game.showroomKey("a")
      game.showroomKey("j")
      game.showroomKey("l")
      game.showroomKey("0")
      #expect(game.showroom.query == "ajl0" && game.showroom.viewAxis == .pitch)
    }
  }

  @Test func actorDragRefusesOtherScreensInvalidCoordinatesAndTradeWithoutMutatingCommander() async
  {
    let runtime = GameRuntime(game: game())
    let initial = await runtime.snapshot()
    let layout = ShowroomLayout(width: 768, height: 900, detail: true)
    await runtime.showroomDrag(
      fromX: layout.model.x + 10, fromY: layout.model.y + 40,
      toX: layout.model.x + 40, toY: layout.model.y + 50, roll: false)
    let changed = await runtime.snapshot()
    #expect(!close(changed.showroom.viewOrientation, initial.showroom.viewOrientation))
    #expect(changed.commander == initial.commander)
    for variant in 0..<5 {
      var refused = game()
      if variant == 0 { refused.screen = .status }
      if variant == 1 { refused.showroom.trading = true }
      if variant == 2 { refused.showroom.searching = true }
      if variant == 3 { refused.paused = true }
      let before = refused.showroom.viewOrientation
      refused.showroomDrag(fromX: 0, fromY: 0, toX: 10, toY: 20, roll: false)
      refused.showroomDrag(
        fromX: layout.model.x + 10, fromY: layout.model.y + 40,
        toX: variant == 4 ? .nan : layout.model.x + 40, toY: layout.model.y + 60, roll: false)
      #expect(close(before, refused.showroom.viewOrientation))
    }
  }
}
