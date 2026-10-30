/// One synchronous shortest-path kernel. Callers own edge eligibility, fuel and scoring policy.
public enum NavigationRouteSearch {
  private static let maximumNodes = 4096
  private static let maximumEdges = 1_048_576

  public static func path(
    adjacency: [[Int]], from origin: Int, to destination: Int,
    edgeWeight: (Int, Int, Bool) -> Double?
  ) -> [Int]? {
    let count = adjacency.count
    guard (1...maximumNodes).contains(count), adjacency.indices.contains(origin),
      adjacency.indices.contains(destination)
    else { return nil }
    var edgeCount = 0
    for neighbours in adjacency {
      guard neighbours.count <= maximumEdges - edgeCount,
        neighbours.allSatisfy({ adjacency.indices.contains($0) })
      else { return nil }
      edgeCount += neighbours.count
    }
    // Validate all eligible weights before an early destination exit; a negative/NaN
    // edge behind a currently costlier node must not yield a falsely accepted route.
    var weights: [[Double?]] = []
    for (node, neighbours) in adjacency.enumerated() {
      var row: [Double?] = []
      for next in neighbours {
        let weight = edgeWeight(node, next, node == origin)
        if let weight, !weight.isFinite || weight <= 0 { return nil }
        row.append(weight)
      }
      weights.append(row)
    }
    var costs = [Double](repeating: .infinity, count: count)
    costs[origin] = 0
    var previous = [Int?](repeating: nil, count: count)
    var visited: Set<Int> = []
    for _ in 0..<count {
      guard
        let node = costs.indices.filter({ !visited.contains($0) && costs[$0].isFinite }).min(by: {
          costs[$0] == costs[$1] ? $0 < $1 : costs[$0] < costs[$1]
        })
      else { break }
      if node == destination { break }
      visited.insert(node)
      for (edgeIndex, next) in adjacency[node].enumerated() where !visited.contains(next) {
        guard let weight = weights[node][edgeIndex] else { continue }
        let cost = costs[node] + weight
        guard cost.isFinite else { return nil }
        if cost < costs[next] {
          costs[next] = cost
          previous[next] = node
        }
      }
    }
    guard costs[destination].isFinite else { return nil }
    var result: [Int] = []
    var current = destination
    for _ in 0..<count {
      result.append(current)
      if current == origin { return Array(result.reversed()) }
      guard let parent = previous[current], adjacency.indices.contains(parent) else { return nil }
      current = parent
    }
    return nil
  }
}
