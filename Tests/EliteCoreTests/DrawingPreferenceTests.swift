import Foundation
import Testing

@testable import EliteCore

struct DrawingPreferenceTests {
  @Test func newAndPreferenceLessCommandersUseShadedPanelsWithoutChangingExplicitChoices() throws {
    #expect(Game(executive: false).commander.shipDisplayStyle == .shadedPanels)
    #expect(Game(executive: true).commander.shipDisplayStyle == .shadedPanels)
    for style in ShipDisplayStyle.allCases {
      var commander = Commander()
      commander.shipDisplayStyle = style
      let data = try JSONEncoder().encode(commander)
      #expect(try JSONDecoder().decode(Commander.self, from: data).shipDisplayStyle == style)
      var old = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
      old.removeValue(forKey: "displayStyle")
      let migrated = try JSONDecoder().decode(
        Commander.self, from: JSONSerialization.data(withJSONObject: old))
      #expect(migrated.shipDisplayStyle == .shadedPanels)
      #expect(migrated.credits == commander.credits && migrated.equipment == commander.equipment)
    }
  }

  @Test func dataPlanetPreviewUsesSelectedDrawingModeAndKeepsMapColours() {
    var game = Game(executive: false)
    game.screen = .system
    for style in ShipDisplayStyle.allCases {
      game.commander.shipDisplayStyle = style
      let frame = Display.systemScreen(game, width: 1000, height: 1000)
      let textures = frame.graphics.filter { if case .planet = $0 { true } else { false } }
      #expect(textures.isEmpty == (style != .shadedPanels))
      #expect(frame.labels.contains { $0.ink == .yellow })
      #expect(frame.labels.contains { $0.text == "Generated planet view" })
    }
  }

  @Test func fittingLocationsPinWholeHullAndExactVacantSlot() throws {
    let hull = UUID()
    let first = ComponentFittingLocation(hullInstanceID: hull, slot: .missilePylon(0))
    let second = ComponentFittingLocation(hullInstanceID: hull, slot: .missilePylon(1))
    #expect(first != second)
    #expect(first != .init(hullInstanceID: UUID(), slot: .missilePylon(0)))
    #expect(ComponentFittingSlot.missilePylon(31).valid)
    #expect(!ComponentFittingSlot.missilePylon(32).valid)
    #expect(!ComponentFittingSlot.spareEscapePod(2).valid)
    #expect(!ComponentFittingSlot.fuelStorage(-1).valid)
    let restored = try JSONDecoder().decode(
      ComponentFittingLocation.self, from: JSONEncoder().encode(first))
    #expect(restored == first)
  }
}
