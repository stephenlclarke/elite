import Foundation
import Testing

@testable import L337Core

private func driveComponent(_ tier: HyperspaceDriveTier) -> ComponentInstance {
  .init(id: UUID(), origin: HyperspaceDriveDefinition.template(for: tier))
}

struct HyperspaceDrivePolicyTests {
  @Test func ordinaryGradesHaveExactSecondsMassLockFactorsAndExplicitShopBalance() throws {
    for tier in HyperspaceDriveTier.allCases {
      let component = driveComponent(tier)
      try ComponentProgression.validateLoaded(
        component, definition: HyperspaceDriveDefinition.componentDefinition)
      let policy = try HyperspaceDrivePolicy.normal(
        component: component, navigationSpoolMultiplier: 1)
      #expect(policy.activation == .timed(seconds: tier.activationSeconds))
      #expect(policy.massLockScale == tier.massLockScale)
      #expect(try policy.massLockDistance(base: 600) == [600.0, 480, 360][tier.order])
      #expect(try policy.massLockDistance(base: 4000) == [4000.0, 3200, 2400][tier.order])
    }
    #expect(HyperspaceDriveTier.allCases.map(\.activationSeconds) == [10, 5, 1])
    #expect(HyperspaceDriveTier.allCases.map(\.massLockScale) == [1, 0.8, 0.6])
    #expect(HyperspaceDriveTier.basic.priceTenths == nil)
    #expect(
      HyperspaceDriveTier.intermediate.priceTenths == 50000
        && HyperspaceDriveTier.intermediate.technology == 9)
    #expect(
      HyperspaceDriveTier.advanced.priceTenths == 150000
        && HyperspaceDriveTier.advanced.technology == 12)
  }

  @Test func earnedDriveAndNavigationEffectsAreAppliedOnceWithoutMutatingEitherSource() throws {
    let component = driveComponent(.advanced)
    func upgraded(
      _ source: ComponentInstance, definition: ComponentFamilyDefinition, section: UInt16
    ) throws -> ComponentInstance {
      var current = source
      for index in 0..<2 {
        let item = ComponentUpgrade(
          identity: .salvage(
            .init(
              section: .init(
                wreck: .init(system: .init(galaxy: 0, system: 7), site: 2, lineage: 1),
                section: section), lot: UInt16(index))),
          boundComponent: source.id, origin: source.origin.identity, basisPoints: [.jumpSpool: 1500]
        )
        let revision = UInt64(index + 1)
        let quote = try ComponentProgression.quote(
          component: current, item: item, definition: definition, inventoryRevision: revision)
        current = try ComponentProgression.apply(
          quote, component: current, item: item, definition: definition, inventoryRevision: revision
        ).component
      }
      return current
    }
    let earned = try upgraded(
      component, definition: HyperspaceDriveDefinition.componentDefinition, section: 1)
    #expect(earned.statistics[.jumpSpool] == 0.7)
    let navigation = try upgraded(
      .init(id: UUID(), origin: EquipmentModuleTemplates.navigation.grades[0]),
      definition: EquipmentModuleTemplates.navigation, section: 2)
    let savedEarned = earned
    let savedNavigation = navigation
    let ratio = try #require(navigation.statistics[.jumpSpool])
    let policy = try HyperspaceDrivePolicy.normal(
      component: earned, navigationSpoolMultiplier: ratio)
    #expect(policy.activation == .timed(seconds: 0.7 * 0.7) && policy.massLockScale == 0.6)
    #expect(earned == savedEarned && navigation == savedNavigation)
    #expect(
      component.statistics[.jumpSpool] == 1 && earned.receipts.count == 2
        && navigation.receipts.count == 2)
    let restored = try JSONDecoder().decode(
      ComponentInstance.self, from: JSONEncoder().encode(earned))
    #expect(
      try HyperspaceDrivePolicy.normal(component: restored, navigationSpoolMultiplier: ratio)
        == policy)
  }

  @Test func immediateAlienFoundationDoesNotRequireZeroOrEpsilonPerformance() throws {
    #expect(HyperspaceDrivePolicy.alienFoundation.activation == .immediate)
    #expect(HyperspaceDrivePolicy.alienFoundation.massLockScale == 0)
    #expect(try HyperspaceDrivePolicy.alienFoundation.massLockDistance(base: 600) == 0)
    let stock = try HyperspaceDrivePolicy.normal(component: nil, navigationSpoolMultiplier: 1)
    #expect(stock.activation == .timed(seconds: 10) && stock.massLockScale == 1)
    #expect(Game().commander.nativePerformance.valid)
  }

  @Test func invalidRatiosForeignFamiliesAndImpossibleTimedValuesFailClosed() throws {
    for ratio in [0.0, -1, Double.nan, .infinity] {
      #expect(throws: HyperspaceDrivePolicyError.invalidNavigationMultiplier) {
        _ = try HyperspaceDrivePolicy.normal(
          component: driveComponent(.basic), navigationSpoolMultiplier: ratio)
      }
    }
    #expect(throws: HyperspaceDrivePolicyError.invalidActivationSeconds) {
      _ = try HyperspaceDrivePolicy.normal(
        component: driveComponent(.basic), navigationSpoolMultiplier: .greatestFiniteMagnitude)
    }
    let navigation = ComponentInstance(
      id: UUID(), origin: EquipmentModuleTemplates.navigation.grades[0])
    #expect(throws: ComponentProgressionError.incompatibleFamily) {
      _ = try HyperspaceDrivePolicy.normal(component: navigation, navigationSpoolMultiplier: 1)
    }
    let invalid = ComponentInstance(
      id: UUID(), origin: HyperspaceDriveDefinition.template(for: .advanced),
      statistics: [.jumpSpool: 0])
    #expect(throws: ComponentProgressionError.invalidInstance) {
      _ = try HyperspaceDrivePolicy.normal(component: invalid, navigationSpoolMultiplier: 1)
    }
    for distance in [-1.0, Double.nan, .infinity] {
      #expect(throws: HyperspaceDrivePolicyError.invalidMassLockDistance) {
        _ = try HyperspaceDrivePolicy.alienFoundation.massLockDistance(base: distance)
      }
    }
  }

  @Test func sequentialPurchaseRequiresBothPaidPredecessorAndActualFittedCore() throws {
    let graph = HyperspaceDriveDefinition.purchaseGraph
    try EquipmentPurchaseProgression.validate(graph)
    let owner = UUID()
    let hull = UUID()
    let basic = HyperspaceDriveDefinition.node(for: .basic)
    let intermediate = HyperspaceDriveDefinition.node(for: .intermediate)
    let advanced = HyperspaceDriveDefinition.node(for: .advanced)
    let location = EquipmentFittingLocation(hull: hull, slot: "drive")
    let standard = EquipmentPurchaseItem(
      id: UUID(), node: basic, location: location, provenance: .standard)
    let history = EquipmentPurchaseHistory(owner: owner)
    let snapshot = EquipmentPurchaseSnapshot(
      owner: owner, activeHull: hull, revision: 1, funds: 200000, items: [standard])
    func request(_ node: EquipmentNodeID) -> EquipmentPurchaseRequest {
      .init(
        transaction: UUID(), newItem: UUID(),
        offer: .init(node: node, price: 50000, shop: "station", revision: 1))
    }
    #expect(throws: EquipmentPurchaseError.notForSale(basic)) {
      _ = try EquipmentPurchaseProgression.quote(
        request: request(basic), snapshot: snapshot, history: history, graph: graph)
    }
    #expect(throws: EquipmentPurchaseError.missingPrerequisite(intermediate)) {
      _ = try EquipmentPurchaseProgression.quote(
        request: request(advanced), snapshot: snapshot, history: history, graph: graph)
    }
    let purchase = request(intermediate)
    let quote = try EquipmentPurchaseProgression.quote(
      request: purchase, snapshot: snapshot, history: history, graph: graph)
    let bought = try EquipmentPurchaseProgression.apply(
      quote, request: purchase, snapshot: snapshot, history: history, graph: graph)
    #expect(
      bought.requiredDebit == 50000 && bought.history.paid.count == 1
        && bought.item.node == intermediate)
    let missingFit = EquipmentPurchaseSnapshot(
      owner: owner, activeHull: hull, revision: 2, funds: 150000, items: [standard, bought.item])
    #expect(throws: EquipmentPurchaseError.missingFittedPrerequisite(intermediate)) {
      _ = try EquipmentPurchaseProgression.quote(
        request: request(advanced), snapshot: missingFit, history: bought.history, graph: graph)
    }
    let installed = EquipmentPurchaseItem(
      id: bought.item.id, node: intermediate, location: location, provenance: bought.item.provenance
    )
    let ready = EquipmentPurchaseSnapshot(
      owner: owner, activeHull: hull, revision: 3, funds: 150000, items: [installed])
    let final = try EquipmentPurchaseProgression.quote(
      request: request(advanced), snapshot: ready, history: bought.history, graph: graph)
    #expect(
      final.node == advanced && final.binding.lineage.map(\.id) == [basic, intermediate, advanced])
    let granted = EquipmentPurchaseItem(
      id: UUID(), node: intermediate, location: location, provenance: .xyzzy)
    let noPaid = EquipmentPurchaseSnapshot(
      owner: owner, activeHull: hull, revision: 4, funds: 150000, items: [granted])
    #expect(throws: EquipmentPurchaseError.missingPrerequisite(intermediate)) {
      _ = try EquipmentPurchaseProgression.quote(
        request: request(advanced), snapshot: noPaid, history: history, graph: graph)
    }
  }
}
