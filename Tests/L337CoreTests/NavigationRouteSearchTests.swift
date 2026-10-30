import Testing

@testable import L337Core

struct NavigationRouteSearchTests {
  @Test func fuelEligibilityAffectsOnlyDepartureAndLaterEdgesUseDeclaredTank() {
    let adjacency = [[1, 2], [2], []]
    func route(firstReach: Double) -> [Int]? {
      NavigationRouteSearch.path(adjacency: adjacency, from: 0, to: 2) { a, b, first in
        let distance = a == 0 ? (b == 1 ? 3.0 : 9.0) : 6.0
        return distance <= (first ? firstReach : 7) ? 1 : nil
      }
    }
    let feasible = route(firstReach: 4)
    let emptyFirstLeg = route(firstReach: 2)
    #expect(feasible == [0, 1, 2])
    #expect(emptyFirstLeg == nil)
  }

  @Test func callerFewestSafetyAndTradeScoresRemainDistinct() {
    let adjacency = [[1, 2], [3], [3], []]
    func route(score: Int) -> [Int]? {
      NavigationRouteSearch.path(adjacency: adjacency, from: 0, to: 3) { a, b, _ in
        let distance = (a == 1 || b == 1) ? 1.0 : 2.0
        let risk = b == 1 ? 1.05 : 0.0
        switch score {
        case 1: return 1 + risk
        case 2: return max(0.25, 1 + risk * 0.2 - (b == 2 ? 1.0 : 0))
        default: return 1 + distance * 0.0001
        }
      }
    }
    let fewest = route(score: 0)
    let safety = route(score: 1)
    let trade = route(score: 2)
    #expect(fewest == [0, 1, 3])
    #expect(safety == [0, 2, 3])
    #expect(trade == [0, 2, 3])
  }

  @Test func equalCostsKeepLowerNodeTieOrderAndUnreachableReturnsNoPartialPath() {
    let tied = NavigationRouteSearch.path(adjacency: [[2, 1], [3], [3], []], from: 0, to: 3) {
      _, _, _ in 1
    }
    let disconnected = NavigationRouteSearch.path(adjacency: [[1], [], []], from: 0, to: 2) {
      _, _, _ in 1
    }
    let same = NavigationRouteSearch.path(adjacency: [[]], from: 0, to: 0) { _, _, _ in 1 }
    #expect(tied == [0, 1, 3])
    #expect(disconnected == nil)
    #expect(same == [0])
  }

  @Test func invalidIndicesWeightsOverflowAndBoundsRefuseWithoutTraps() {
    let badEdge = NavigationRouteSearch.path(adjacency: [[2], []], from: 0, to: 1) { _, _, _ in 1 }
    let badOrigin = NavigationRouteSearch.path(adjacency: [[]], from: -1, to: 0) { _, _, _ in 1 }
    let tooLarge = NavigationRouteSearch.path(
      adjacency: Array(repeating: [], count: 4097), from: 0, to: 1
    ) { _, _, _ in 1 }
    #expect(badEdge == nil && badOrigin == nil && tooLarge == nil)
    for weight in [Double.nan, .infinity, 0, -1] {
      let result = NavigationRouteSearch.path(adjacency: [[1], []], from: 0, to: 1) {
        _, _, _ in weight
      }
      #expect(result == nil)
    }
    let overflow = NavigationRouteSearch.path(adjacency: [[1], [2], []], from: 0, to: 2) {
      _, _, _ in Double.greatestFiniteMagnitude
    }
    #expect(overflow == nil)
    let hiddenNegative = NavigationRouteSearch.path(
      adjacency: [[1, 2], [], [1]], from: 0, to: 1
    ) { a, b, _ in
      a == 2 ? -5 : b == 1 ? 1 : 2
    }
    #expect(hiddenNegative == nil)
  }
}
