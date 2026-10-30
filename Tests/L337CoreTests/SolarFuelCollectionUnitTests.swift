import Foundation
import Testing

@testable import L337Core

struct SolarFuelCollectionUnitTests {
  private let sun = CelestialBody(kind: .sun, position: .init(0, 0, 2970), radius: 1100)

  @Test func onlyActualFuelScoopsFittedToTheActiveHullSupplyCollection() throws {
    let owner = UUID()
    let hull = UUID()
    let node = try #require(EquipmentRuntimeCatalog.node(for: "Fuel Scoops"))
    let id = UUID()
    let stored = OwnedEquipmentItem(id: id, node: node, provenance: .grant("unit"))
    let inventory = try OwnedEquipmentInventory(owner: owner, activeHull: hull, items: [stored])
    #expect(!SolarFuelCollection.hasFittedScoops(nil))
    #expect(!SolarFuelCollection.hasFittedScoops(inventory))
    let installed = OwnedEquipmentItem(
      id: id, node: node, provenance: stored.provenance,
      location: .init(hullInstanceID: hull, slot: .utility(.fuelScoops)))
    #expect(
      SolarFuelCollection.hasFittedScoops(
        try .init(owner: owner, activeHull: hull, items: [installed])))
    let wrongSlot = OwnedEquipmentItem(
      id: id, node: node, provenance: stored.provenance,
      location: .init(hullInstanceID: hull, slot: .utility(.ecm)))
    #expect(
      !SolarFuelCollection.hasFittedScoops(
        try .init(owner: owner, activeHull: hull, items: [wrongSlot])))
    #expect(throws: (any Error).self) {
      try OwnedEquipmentInventory(owner: owner, activeHull: UUID(), items: [installed])
    }
    #expect(inventory.items == [stored])
  }

  @Test func fractionalCollectionSurvivesFrameBoundariesAndStopsAtActualCapacity() {
    var fuel = 0
    var remainder = 0.0
    for _ in 0..<10 {
      let next = SolarFuelCollection.step(
        delta: 0.1, sun: sun, forwardSpeed: 8,
        fitted: true, fuel: fuel, capacity: 70, remainder: remainder)
      #expect(next.state == .collecting)
      fuel = next.fuel
      remainder = next.remainder
    }
    #expect(fuel == 7 && remainder < 1e-8)
    let halfSpeed = SolarFuelCollection.step(
      delta: 1, sun: sun, forwardSpeed: 4,
      fitted: true, fuel: 0, capacity: 70, remainder: 0)
    #expect(halfSpeed.fuel == 3 && abs(halfSpeed.remainder - 0.5) < 1e-9)
    let full = SolarFuelCollection.step(
      delta: 0.1, sun: sun, forwardSpeed: 8,
      fitted: true, fuel: 69, capacity: 70, remainder: 0.8)
    #expect(full.state == .tankFull && full.fuel == 70 && full.remainder == 0)
    let savedBoundary = SolarFuelCollection.step(
      delta: 0.1, sun: sun, forwardSpeed: 8,
      fitted: true, fuel: 0, capacity: 70, remainder: 1)
    #expect(savedBoundary.fuel == 1 && abs(savedBoundary.remainder - 0.7) < 1e-9)
  }

  @Test func collectionRefusesMissingScoopsReverseLateralOutOfRangeAndSurfacePositions() {
    let missing = SolarFuelCollection.step(
      delta: 0.1, sun: sun, forwardSpeed: 8,
      fitted: false, fuel: 0, capacity: 70, remainder: 0.8)
    #expect(missing.state == .noScoops && missing.fuel == 0 && missing.remainder == 0)
    for speed in [0.0, -8.0] {
      let result = SolarFuelCollection.step(
        delta: 0.1, sun: sun, forwardSpeed: speed,
        fitted: true, fuel: 0, capacity: 70, remainder: 0.8)
      #expect(result.state == .turnTowardSun && result.fuel == 0 && result.remainder == 0)
    }
    for position in [Vector3(2970, 0, 0), .init(0, 0, -2970)] {
      let result = SolarFuelCollection.step(
        delta: 0.1,
        sun: .init(kind: .sun, position: position, radius: 1100), forwardSpeed: 8,
        fitted: true, fuel: 0, capacity: 70, remainder: 0)
      #expect(result.state == .turnTowardSun && result.fuel == 0)
    }
    for position in [Vector3(0, 0, 3301), .init(0, 0, 1000)] {
      let result = SolarFuelCollection.step(
        delta: 0.1,
        sun: .init(kind: .sun, position: position, radius: 1100), forwardSpeed: 8,
        fitted: true, fuel: 0, capacity: 70, remainder: 0.8)
      #expect(result.state == .inactive && result.fuel == 0 && result.remainder == 0)
    }
  }

  @Test func nonFiniteInputsAndHugeGainsCannotTrapOrOverflowTheTank() {
    for remainder in [Double.nan, .infinity, -.infinity, -1, 1.1] {
      let result = SolarFuelCollection.step(
        delta: 0.1, sun: sun, forwardSpeed: 8,
        fitted: true, fuel: 12, capacity: 70, remainder: remainder)
      #expect(result.state == .inactive && result.fuel == 12 && result.remainder == 0)
    }
    for delta in [Double.nan, .infinity, -.infinity, -1, 0, .greatestFiniteMagnitude] {
      let result = SolarFuelCollection.step(
        delta: delta, sun: sun, forwardSpeed: 8,
        fitted: true, fuel: 12, capacity: 70, remainder: 0)
      #expect(result.state == .inactive && result.fuel == 12 && result.remainder == 0)
    }
    let huge = SolarFuelCollection.step(
      delta: 1e18, sun: sun, forwardSpeed: 8,
      fitted: true, fuel: Int.max - 1, capacity: Int.max, remainder: 0.8)
    #expect(huge.state == .tankFull && huge.fuel == Int.max && huge.remainder == 0)
    let noSun = SolarFuelCollection.step(
      delta: 0.1, sun: nil, forwardSpeed: 8,
      fitted: true, fuel: 12, capacity: 70, remainder: 0.8)
    #expect(noSun.state == .inactive && noSun.fuel == 12 && noSun.remainder == 0)
  }
}
