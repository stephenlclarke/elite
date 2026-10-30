import Foundation
import Testing

@testable import EliteCore

struct ShowroomUnitCompatibilityUnitTests {
  private func profile(_ group: String) -> ShipProfile {
    .init(id: group, title: group, group: group, context: "unit compatibility fixture", fields: [])
  }

  private func field(_ value: Double, unit: String) -> ShipSpec {
    .init(
      key: "capacity", label: "Capacity", text: NativeShipValueFormat.tenths(value) + " " + unit,
      number: value, unit: unit, status: "game", basis: "unit compatibility fixture")
  }

  private func sourceComparison(baseline: String, selected: String) throws -> Game {
    var game = Game(executive: false)
    game.showroom.baselineUsesCurrent = false
    game.showroom.baseline = baseline
    game.showroom.selection = selected
    game.showroom.sourceProfiles = true
    game.showroom.profileIndex = try #require(
      game.showroomProfiles.firstIndex {
        $0.group == "project-refit-v1"
      })
    return game
  }

  @Test func differentCharterUnitsNeverGainBenefitsFromTheirSharedProfileGroup() throws {
    for (baseline, selected) in [("SH023", "SH169"), ("SH169", "SH023")] {
      let game = try sourceComparison(baseline: baseline, selected: selected)
      let before = game.commander
      let a = try #require(
        game.showroomBaselineProfile?.fields.first {
          $0.key == "initial_charter_passenger_berths"
        })
      let b = try #require(
        game.showroomProfile?.fields.first {
          $0.key == "initial_charter_passenger_berths"
        })
      #expect(a.unit != b.unit && a.number != b.number)
      #expect(game.showroomBaselineProfile?.group == game.showroomProfile?.group)
      #expect(
        !game.comparableShowroomField(
          a, b, baseline: game.showroomBaselineProfile, selected: game.showroomProfile))
      let row = try #require(game.showroomComparison.first { $0.label == b.label })
      #expect(row.rating == .unavailable && row.difference.isEmpty)
      #expect(row.baseline.hasPrefix(a.text) && row.selected.hasPrefix(b.text))
      #expect(game.commander == before)
    }
  }

  @Test func matchingBlankAndExplicitSourceUnitsKeepTheirExistingComparisons() throws {
    for (baseline, selected, unit, rating, difference) in [
      ("SH023", "SH013", "", ComparisonRating.same, "Diff +0"),
      ("SH170", "SH169", "berths", .better, "Diff +1 berths"),
      ("SH169", "SH170", "berths", .worse, "Diff -1 berths"),
    ] {
      let game = try sourceComparison(baseline: baseline, selected: selected)
      let a = try #require(
        game.showroomBaselineProfile?.fields.first {
          $0.key == "initial_charter_passenger_berths"
        })
      let b = try #require(
        game.showroomProfile?.fields.first {
          $0.key == "initial_charter_passenger_berths"
        })
      #expect(a.unit == unit && b.unit == unit)
      #expect(
        game.comparableShowroomField(
          a, b, baseline: game.showroomBaselineProfile, selected: game.showroomProfile))
      let row = try #require(game.showroomComparison.first { $0.label == b.label })
      #expect(row.rating == rating && row.difference == difference)
    }
  }

  @Test func nativePrecisionAndCrossProfileCapacityPolicyRemainUnchanged() {
    let game = Game(executive: false)
    let native = profile("native-game")
    let source = profile("project-refit-v1")
    let current = profile("native-current")
    let a = field(1.24, unit: "speed")
    let b = field(1.25, unit: "speed")
    let compatible = game.comparableShowroomField(a, b, baseline: native, selected: native)
    #expect(compatible && ComparisonRating.compare(a, b, compatible: compatible) == .same)
    #expect(
      !game.comparableShowroomField(
        a, field(1.25, unit: "km/s"), baseline: native, selected: native))
    #expect(!game.comparableShowroomField(nil, b, baseline: native, selected: native))
    #expect(!game.comparableShowroomField(a, nil, baseline: native, selected: native))
    for unit in ["t", "LY", "0.1 LY", "people", "berths", "missiles", "pylons"] {
      let left = field(1, unit: unit)
      let right = field(2, unit: unit)
      #expect(game.comparableShowroomField(left, right, baseline: current, selected: source))
      #expect(!game.comparableShowroomField(right, left, baseline: source, selected: current))
      #expect(!game.comparableShowroomField(left, right, baseline: native, selected: source))
    }
    #expect(
      !game.comparableShowroomField(
        field(1, unit: "t"), field(2, unit: "kg"), baseline: current, selected: source))
    #expect(!game.comparableShowroomField(a, b, baseline: current, selected: source))
    let infinite = field(.infinity, unit: "speed")
    #expect(
      ComparisonRating.compare(
        infinite, b,
        compatible: game.comparableShowroomField(infinite, b, baseline: native, selected: native))
        == .unavailable)
  }
}
