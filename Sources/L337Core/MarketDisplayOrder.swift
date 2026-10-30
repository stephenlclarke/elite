/// Display positions follow authoring order; cargo, quotes and selection retain commodity IDs.
enum MarketDisplayOrder {
  static let commodityIDs = Universe.originalWorlds.authoring.commodities.map(\.index)

  static func start(selection: Int, visible: Int) -> Int {
    let position = commodityIDs.firstIndex(of: selection) ?? 0
    let count = max(1, visible)
    return max(0, min(position - count + 1, commodityIDs.count - count))
  }

  static func moved(selection: Int, direction: Int) -> Int {
    let position = commodityIDs.firstIndex(of: selection) ?? 0
    return commodityIDs[max(0, min(commodityIDs.count - 1, position + direction))]
  }
}
