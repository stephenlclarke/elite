import Foundation
import Testing

@testable import EliteCore

struct OriginalFleetCatalogueUnitTests {
  @Test func exactCatalogueJoinsPreserveAllOriginalIdentitiesRolesAndAccessRules() throws {
    let expected = (1...171).map { String(format: "SH%03d", $0) }
    #expect(OriginalFleetDefinitionData.staged.map(\.id) == expected)
    #expect(ShipCatalogue.all.map(\.id).sorted() == expected)
    for record in OriginalFleetDefinitionData.staged {
      let lookup = try #require(ShipCatalogue.originalDefinition(for: record.id))
      let ship = try #require(ShipCatalogue.ship(record.id))
      #expect(ship.originalDefinition?.id == record.id)
      #expect(lookup.authored == record.authored && lookup.sourceSHA256 == record.sourceSHA256)
      #expect(
        lookup.name == record.name && lookup.role == record.role && lookup.family == record.family)
      #expect(
        lookup.playerFlyable == record.playerFlyable
          && lookup.purchasePolicy == record.purchasePolicy)
      #expect(
        lookup.integrationBlockers == record.integrationBlockers
          && lookup.runtimeReady
            == [
              "SH002", "SH003", "SH004", "SH007", "SH012", "SH018", "SH019", "SH027", "SH029",
              "SH030", "SH031", "SH032", "SH033", "SH035", "SH036", "SH041", "SH042", "SH043",
              "SH044", "SH045", "SH046", "SH047", "SH054", "SH061",
            ]
            .contains(
              record.id)
      )
    }
    #expect(ShipCatalogue.originalDefinition(for: "SH001")?.name == "Mule")
    #expect(
      ShipCatalogue.originalDefinition(for: "SH171")?.purchasePolicy == "plughQuestFabrication")
    for alias in ["Mule", "sh001", "SH1", "SH000", "SH172", "../SH001"] {
      #expect(ShipCatalogue.originalDefinition(for: alias) == nil)
    }
  }

  @Test func sourceProfilesRetainEveryAuthoredFieldAndDoNotReplaceExistingProfiles() throws {
    for ship in ShipCatalogue.all {
      let original = try #require(ship.originalDefinition)
      let profiles = ship.sourceProfilesIncludingOriginal
      #expect(Array(profiles.dropLast()) == ship.profiles)
      let profile = try #require(profiles.last)
      #expect(profile.group == OriginalFleetDefinition.sourceProfileGroup)
      #expect(profile.fields.count == original.authored.count + 3)
      #expect(Set(profile.fields.map(\.key)).count == profile.fields.count)
      for key in original.authored.keys {
        #expect(
          profile.fields.first { $0.key == "original." + key }?.text
            == original.authored[key]?.sourceText)
      }
      #expect(profile.fields.allSatisfy { $0.number == nil && $0.status == "source" })
      #expect(profile.context.contains("current game fittings and hull activation are separate"))
      #expect(ship.searchText.contains(original.name) && ship.searchText.contains(original.role))
    }
  }

  @Test func sourceDisplayKeepsLargeIntegersAndNestedValuesWithoutFloatingConversion() {
    #expect(OriginalFleetValue.integer(9_007_199_254_740_993).sourceText == "9007199254740993")
    #expect(OriginalFleetValue.integer(.max).sourceText == "9223372036854775807")
    #expect(
      OriginalFleetValue.largeInteger("18446744073709551616").sourceText == "18446744073709551616")
    #expect(OriginalFleetValue.number(1.25).sourceText == "1.25")
    let nested = OriginalFleetValue.object([
      "z": .integer(.max), "a": .array([.boolean(true), .string("two\nlines")]),
    ])
    #expect(nested.sourceText == #"{"a": [true, "two\nlines"], "z": 9223372036854775807}"#)
  }

  @Test func sourceRangeConflictsAndQuestRestrictionsRemainExplicitAfterJoining() throws {
    let conflicts = OriginalFleetDefinitionData.staged.filter {
      $0.nativePerformance?.valid == false
    }.map(\.id)
    #expect(conflicts == ["SH040", "SH043", "SH081", "SH123"])
    for id in conflicts {
      let original = try #require(ShipCatalogue.originalDefinition(for: id))
      #expect(original.nativePerformance?.valid == false && !original.integrationBlockers.isEmpty)
      #expect(original.runtimeReady == (id == "SH043"))
      if id == "SH043" {
        #expect(original.purchasePolicy == "never")
        #expect(original.nativePerformance?.valid(purchasePolicy: .never) == true)
      }
    }
    let final = try #require(ShipCatalogue.originalDefinition(for: "SH171"))
    #expect(
      final.sourceProfile.fields.contains {
        $0.key == "original.purchasePolicy" && $0.text.contains("plughQuestFabrication")
      })
  }
}
