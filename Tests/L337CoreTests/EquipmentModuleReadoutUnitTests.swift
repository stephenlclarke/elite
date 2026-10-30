import Foundation
import Testing

@testable import L337Core

struct EquipmentModuleReadoutUnitTests {
  @Test func authoredShieldEnergyAndNavigationOfferValuesUseTheirOwnBasicBaseline() throws {
    let shield = EquipmentModuleTemplates.shield
    #expect(
      EquipmentModuleReadout.summary(
        shield.grades[1].statistics,
        family: shield.family, baseline: shield.grades[0].statistics)
        == "cap F/R 150%/150%; regen F/R 100%/100%")
    let energy = EquipmentModuleTemplates.energy
    #expect(
      EquipmentModuleReadout.summary(
        energy.grades[3].statistics,
        family: energy.family, baseline: energy.grades[0].statistics)
        == "capacity 100%; recharge 400%")
    let navigation = EquipmentModuleTemplates.navigation
    #expect(
      EquipmentModuleReadout.summary(
        navigation.grades[2].statistics,
        family: navigation.family, baseline: navigation.grades[0].statistics)
        == "reach 300%; time 100%; fuel 100%")
    for node in EquipmentRuntimeCatalog.graph.nodes where EquipmentModuleReadout.supports(node.id) {
      let rows = EquipmentModuleReadout.lines(node: node.id, fitted: nil)
      #expect(rows.count == 2 && rows[0].hasPrefix("Offer % Basic: "))
      #expect(rows[1] == "Fitted % Basic: none")
      #expect(rows.allSatisfy { $0.count <= 72 && !$0.contains("?") })
    }
  }

  @Test func actualFittedUpgradesAndAsymmetricShieldsRemainVisibleWithoutChangingTheComponent()
    throws
  {
    let family = EquipmentModuleTemplates.shield
    let source = family.grades[0]
    var statistics = source.statistics
    statistics[.frontShieldCapacity] = 1.95
    statistics[.rearShieldCapacity] = 1.2
    statistics[.frontShieldRecharge] = 1.3
    statistics[.rearShieldRecharge] = 1.1
    let component = ComponentInstance(id: UUID(), origin: source, statistics: statistics)
    let node = try #require(
      EquipmentRuntimeCatalog.graph.nodes.first {
        $0.id.family == EquipmentPurchaseCatalog.shields
      }?.id)
    let before = component
    let rows = EquipmentModuleReadout.lines(node: node, fitted: component)
    #expect(rows[1] == "Fitted % Basic: cap F/R 195%/120%; regen F/R 130%/110%")
    #expect(component == before)
    let navigation = EquipmentModuleTemplates.navigation
    var cheaper = navigation.grades[2].statistics
    cheaper[.jumpFuelCost] = 0.7
    cheaper[.jumpSpool] = 0.85
    #expect(
      EquipmentModuleReadout.summary(
        cheaper, family: navigation.family,
        baseline: navigation.grades[0].statistics) == "reach 300%; time 85%; fuel 70%")
  }

  @Test func absentForeignAndUnsupportedComponentsNeverBorrowAnotherFamiliesPercentages() throws {
    let node = try #require(
      EquipmentRuntimeCatalog.graph.nodes.first {
        $0.id.family == EquipmentPurchaseCatalog.energy
      }?.id)
    let shield = ComponentInstance(id: UUID(), origin: EquipmentModuleTemplates.shield.grades[0])
    #expect(EquipmentModuleReadout.lines(node: node, fitted: shield)[1] == "Fitted % Basic: none")
    let scoops = try #require(EquipmentRuntimeCatalog.node(for: "Fuel Scoops"))
    #expect(!EquipmentModuleReadout.supports(scoops))
    #expect(EquipmentModuleReadout.lines(node: scoops, fitted: nil).isEmpty)
  }

  @Test func percentageFormattingRefusesUnknownNonFiniteOrZeroBaselinesWithoutInventedImprovements()
  {
    #expect(EquipmentModuleReadout.percentage(1.3, baseline: 1) == "130")
    #expect(EquipmentModuleReadout.percentage(1.333, baseline: 1) == "133.3")
    #expect(EquipmentModuleReadout.percentage(0, baseline: 1) == "0")
    for value in [Double.nan, .infinity, -.infinity, -1, .greatestFiniteMagnitude] {
      #expect(EquipmentModuleReadout.percentage(value, baseline: 1) == "?")
    }
    for baseline in [Double.nan, .infinity, 0, -1] {
      #expect(EquipmentModuleReadout.percentage(1, baseline: baseline) == "?")
    }
    #expect(EquipmentModuleReadout.percentage(nil, baseline: 1) == "?")
    #expect(EquipmentModuleReadout.percentage(1, baseline: nil) == "?")
  }
}
