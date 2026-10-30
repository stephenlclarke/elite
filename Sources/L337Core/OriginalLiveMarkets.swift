import Foundation

/// Current stock in actual visited markets. Pristine worlds are resolved from authenticated seeds;
/// only owned mutable state is saved, never a second world registry or a procedural price oracle.
public struct OriginalLiveMarkets: Codable, Sendable, Equatable {
  private let worldVersion: String
  private var changed: [String: [MarketItem]] = [:]
  public init() { worldVersion = Universe.originalWorlds.version }

  private static func key(galaxy: Int, system: Int) -> String {
    String(format: "G%02d-S%03d", galaxy + 1, system)
  }

  /// Validated quotes carry stable commodity IDs independently of their authored array order.
  static func initialItems(from state: OriginalMarketInitialState) -> [MarketItem] {
    state.quotes.sorted { $0.index < $1.index }.map {
      MarketItem(price: $0.askTenthsCR, quantity: $0.stock, bidPrice: $0.bidTenthsCR)
    }
  }

  private static let seeds: [String: [MarketItem]] = {
    let catalogue: OriginalMarketCatalogue
    do { catalogue = try OriginalMarketCatalogue.loadBundled() } catch {
      preconditionFailure("Invalid bundled original market seeds: \(error)")
    }
    var values = Dictionary(
      uniqueKeysWithValues: catalogue.allInitialStates.map { state in
        (state.key, initialItems(from: state))
      })
    for galaxy in 0..<8 {
      let anchor = values[key(galaxy: galaxy, system: Plugh.rumourStation)]!
      values[key(galaxy: galaxy, system: Plugh.systemID)] = anchor.map {
        .init(price: Plugh.discount($0.price), quantity: 63, bidPrice: Plugh.discount($0.bidPrice))
      }
    }
    return values
  }()

  /// Immutable prices also authenticate historical native commerce receipts.
  static func initialQuote(galaxy: Int, system: Int, commodity: Int) -> MarketItem? {
    guard let items = seeds[key(galaxy: galaxy, system: system)],
      items.indices.contains(commodity)
    else { return nil }
    return items[commodity]
  }

  static func initial(galaxy: Int, system: StarSystem) -> [MarketItem] {
    guard let items = seeds[key(galaxy: galaxy, system: system.id)] else {
      preconditionFailure("Original market has no world identity")
    }
    return items
  }

  func items(galaxy: Int, system: StarSystem) -> [MarketItem] {
    changed[Self.key(galaxy: galaxy, system: system.id)]
      ?? Self.initial(galaxy: galaxy, system: system)
  }

  mutating func set(_ items: [MarketItem], galaxy: Int, system: StarSystem) {
    changed[Self.key(galaxy: galaxy, system: system.id)] = items
  }

  public var valid: Bool {
    guard worldVersion == Universe.originalWorlds.version, changed.count <= 2056 else {
      return false
    }
    for (key, items) in changed {
      guard let initial = Self.seeds[key], items.count == 17 else { return false }
      guard
        zip(items, initial).allSatisfy({ item, seed in
          item.price == seed.price && item.bidPrice == seed.bidPrice
            && (0...Int.max / 17).contains(item.quantity)
        })
      else { return false }
    }
    return true
  }

  private enum CodingKeys: String, CodingKey { case worldVersion, changed }
  public init(from decoder: Decoder) throws {
    let keys = try decoder.container(keyedBy: WorldKey.self)
    guard Set(keys.allKeys.map(\.stringValue)) == ["worldVersion", "changed"] else {
      throw SaveError.invalidCommander
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    worldVersion = try container.decode(String.self, forKey: .worldVersion)
    let worlds = try container.nestedContainer(keyedBy: WorldKey.self, forKey: .changed)
    guard worlds.allKeys.count <= 2056 else { throw SaveError.invalidCommander }
    for key in worlds.allKeys {
      var quotes = try worlds.nestedUnkeyedContainer(forKey: key)
      guard quotes.count == 17 else { throw SaveError.invalidCommander }
      var items: [MarketItem] = []
      while !quotes.isAtEnd { items.append(try quotes.decode(MarketItem.self)) }
      changed[key.stringValue] = items
    }
    guard valid else { throw SaveError.invalidCommander }
  }

  private struct WorldKey: CodingKey {
    let stringValue: String
    init?(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int? { nil }
    init?(intValue: Int) { return nil }
  }
}
