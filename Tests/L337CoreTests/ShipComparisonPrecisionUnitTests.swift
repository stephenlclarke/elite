import Foundation
import Testing

@testable import L337Core

struct ShipComparisonPrecisionUnitTests {
  private func field(
    _ value: Double?, key: String = "maximum_speed_project_units",
    text: String? = nil
  ) -> ShipSpec {
    .init(
      key: key, label: key,
      text: text ?? value.map(NativeShipValueFormat.tenths) ?? "Unavailable",
      number: value, unit: "", status: "game", basis: "comparison fixture")
  }

  @Test func equalDisplayedTenthsIncludingHalfwayValuesAlwaysReceiveSameRating() {
    #expect(NativeShipValueFormat.tenths(1.24) == "1.2")
    #expect(NativeShipValueFormat.tenths(1.25) == "1.2")
    #expect(
      ComparisonRating.compare(field(1.24), field(1.25), compatible: true) == .same)
    #expect(
      ComparisonRating.compare(field(1.25), field(1.24), compatible: true) == .same)
    #expect(
      ComparisonRating.compare(field(-0.0), field(0.0), compatible: true) == .same)
    #expect(
      ComparisonRating.compare(field(12.21), field(12.24), compatible: true) == .same)
  }

  @Test func visibleDifferencesKeepTheCorrectBenefitDirectionWithoutSubtractionOverflow() {
    for key in ["price", "jump_spool_seconds", "required_crew_including_commander"] {
      #expect(
        ComparisonRating.compare(field(1.2, key: key), field(1.3, key: key), compatible: true)
          == .worse)
      #expect(
        ComparisonRating.compare(field(1.3, key: key), field(1.2, key: key), compatible: true)
          == .better)
    }
    #expect(ComparisonRating.compare(field(1.2), field(1.3), compatible: true) == .better)
    #expect(ComparisonRating.compare(field(1.3), field(1.2), compatible: true) == .worse)
    #expect(
      ComparisonRating.compare(
        field(-Double.greatestFiniteMagnitude), field(Double.greatestFiniteMagnitude),
        compatible: true) == .better)
  }

  @Test func unknownNonFiniteAndIncompatibleValuesNeverGetInventedEqualityOrBenefits() {
    for value in [Double.nan, .infinity, -.infinity] {
      #expect(ComparisonRating.compare(field(value), field(1), compatible: true) == .unavailable)
      #expect(ComparisonRating.compare(field(1), field(value), compatible: true) == .unavailable)
    }
    #expect(ComparisonRating.compare(nil, field(1), compatible: true) == .unavailable)
    #expect(ComparisonRating.compare(field(nil), field(nil), compatible: true) == .unavailable)
    #expect(ComparisonRating.compare(field(1), field(1), compatible: false) == .unavailable)
    #expect(
      ComparisonRating.compare(
        field(nil, text: "Military"), field(nil, text: "Military"), compatible: true) == .same)
    #expect(
      ComparisonRating.compare(
        field(nil, text: "source A"), field(nil, text: "source B"), compatible: true) == .different)
    #expect(
      ComparisonRating.compare(
        field(1), field(nil, text: "Unlimited (XYZZY)"), compatible: true) == .better)
  }
}
