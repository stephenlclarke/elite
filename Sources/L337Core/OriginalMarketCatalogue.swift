import CryptoKit
import Foundation

public enum OriginalMarketCatalogueError: Error, Sendable, Equatable {
  case missingResource(String)
  case fingerprintMismatch(String)
  case invalidSchema(String)
  case unknownCommodity(Int)
}

/// Authored initial quote only. These quantities are not stock after live player/NPC trading.
public struct OriginalMarketInitialQuote: Decodable, Sendable, Equatable {
  public let system: Int
  public let index: Int
  public let name: String
  public let unit: String
  public let askTenthsCR: Int
  public let bidTenthsCR: Int
  public let stock: Int
  public let targetStock: Int
  public let epoch: Int
  public let worldVersion: String

  static let fields: Set<String> = [
    "system", "index", "name", "unit", "askTenthsCR", "bidTenthsCR", "stock",
    "targetStock", "epoch", "worldVersion",
  ]
}

public struct OriginalMarketInitialState: Decodable, Sendable, Equatable {
  public let key: String
  public let galaxy: Int
  public let system: Int
  public let quotes: [OriginalMarketInitialQuote]
}

/// A single immutable seed store over the existing validated original world authority.
/// OriginalLiveMarkets initializes commander-owned mutable stock from these authenticated quotes.
public struct OriginalMarketCatalogue: Sendable {
  public let version: String
  public let allInitialStates: [OriginalMarketInitialState]
  private let worlds: OriginalWorldCatalogue
  private let byKey: [String: OriginalMarketInitialState]

  static let expectedManifestSHA256 =
    "fcc9180da8b415bb2ac0666acae197dc30f5862dac79d613fb6c6e6dfdb8e5c3"

  private static let bundled: Result<OriginalMarketCatalogue, OriginalMarketCatalogueError> = {
    do {
      let worlds = try OriginalWorldCatalogue.loadBundled()
      return .success(try load(from: resourceDirectory(), worlds: worlds))
    } catch let error as OriginalMarketCatalogueError {
      return .failure(error)
    } catch {
      return .failure(.invalidSchema("Original world dependency: \(error)"))
    }
  }()

  public static func loadBundled() throws -> Self { try bundled.get() }

  public func initialState(worldKey: String) throws -> OriginalMarketInitialState {
    let world = try worlds.world(key: worldKey)
    return try initialState(world: world)
  }

  public func initialState(world: OriginalWorldRecord) throws -> OriginalMarketInitialState {
    let canonical = try worlds.world(key: world.key)
    guard world == canonical, let state = byKey[canonical.key] else {
      throw OriginalMarketCatalogueError.invalidSchema("Foreign or missing original world seed")
    }
    return state
  }

  public func initialState(galaxy: Int, system: Int) throws -> OriginalMarketInitialState {
    let world = try worlds.world(galaxy: galaxy, system: system)
    return try initialState(world: world)
  }

  public func initialQuote(worldKey: String, commodityIndex: Int) throws
    -> OriginalMarketInitialQuote
  {
    let state = try initialState(worldKey: worldKey)
    guard let quote = state.quotes.first(where: { $0.index == commodityIndex }) else {
      throw OriginalMarketCatalogueError.unknownCommodity(commodityIndex)
    }
    return quote
  }

  public func initialQuote(galaxy: Int, system: Int, commodityIndex: Int) throws
    -> OriginalMarketInitialQuote
  {
    let world = try worlds.world(galaxy: galaxy, system: system)
    return try initialQuote(worldKey: world.key, commodityIndex: commodityIndex)
  }

  private struct Manifest: Decodable {
    let version: Int
    let kind: String
    let worldVersion: String
    let file: String
    let bytes: Int
    let sha256: String
    let worldCount: Int
    let quoteCount: Int
  }

  private struct Document: Decodable {
    let version: String
    let markets: [OriginalMarketInitialState]
  }

  static func load(from directory: URL, worlds: OriginalWorldCatalogue) throws -> Self {
    let manifestData = try boundedData(
      directory.appendingPathComponent("manifest.json"), maximum: 131_072)
    guard fingerprint(manifestData) == expectedManifestSHA256 else {
      throw OriginalMarketCatalogueError.fingerprintMismatch("manifest.json")
    }
    let manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
    guard manifest.version == 1, manifest.kind == "original-market-initial-seeds",
      manifest.worldVersion == worlds.version, manifest.file == "markets.json",
      (1...16_777_216).contains(manifest.bytes), manifest.worldCount == 2048,
      manifest.quoteCount == 34816
    else { throw OriginalMarketCatalogueError.invalidSchema("Pinned initial-market manifest") }
    let data = try boundedData(
      directory.appendingPathComponent("markets.json"), maximum: 16_777_216)
    guard data.count == manifest.bytes, fingerprint(data) == manifest.sha256 else {
      throw OriginalMarketCatalogueError.fingerprintMismatch("markets.json")
    }
    return try decode(data: data, worlds: worlds)
  }

  /// Internal unpinned decoding exists only for focused malformed-schema tests. Bundled entry
  /// points always authenticate the manifest and exact payload first, with no fallback.
  static func decode(data: Data, worlds: OriginalWorldCatalogue) throws -> Self {
    guard data.count <= 16_777_216 else {
      throw OriginalMarketCatalogueError.invalidSchema("Oversized initial-market payload")
    }
    try validateFields(data)
    let document = try JSONDecoder().decode(Document.self, from: data)
    guard document.version == worlds.version, document.version == "l337-world-1",
      document.markets.count == worlds.worlds.count, document.markets.count == 2048
    else { throw OriginalMarketCatalogueError.invalidSchema("World version/count") }
    var byKey: [String: OriginalMarketInitialState] = [:]
    for state in document.markets {
      guard byKey[state.key] == nil else {
        throw OriginalMarketCatalogueError.invalidSchema("Duplicate market world")
      }
      try validateInitialState(state, worlds: worlds)
      byKey[state.key] = state
    }
    guard Set(byKey.keys) == Set(worlds.worlds.map(\.key)) else {
      throw OriginalMarketCatalogueError.invalidSchema("Missing/foreign initial market")
    }
    return .init(
      version: document.version, allInitialStates: document.markets, worlds: worlds, byKey: byKey)
  }

  static func validateInitialState(
    _ state: OriginalMarketInitialState, worlds: OriginalWorldCatalogue
  ) throws {
    let world = try worlds.world(key: state.key)
    guard state.galaxy == world.galaxy, state.system == world.system, state.quotes.count == 17
    else {
      throw OriginalMarketCatalogueError.invalidSchema("Foreign/incomplete market world")
    }
    var indices = Set<Int>()
    for quote in state.quotes {
      try validateQuote(quote, world: world, authoring: worlds.authoring)
      guard indices.insert(quote.index).inserted else {
        throw OriginalMarketCatalogueError.invalidSchema("Duplicate initial commodity")
      }
    }
    guard indices == Set(0..<17) else {
      throw OriginalMarketCatalogueError.invalidSchema("Incomplete initial commodity set")
    }
  }

  static func validateQuote(
    _ quote: OriginalMarketInitialQuote, world: OriginalWorldRecord,
    authoring: OriginalWorldAuthoring
  ) throws {
    guard quote.system == world.system, quote.worldVersion == authoring.version,
      let commodity = authoring.commodities.first(where: { $0.index == quote.index }),
      quote.name == commodity.name, quote.unit == commodity.unit,
      quote.askTenthsCR >= 0, quote.bidTenthsCR >= 0,
      quote.bidTenthsCR <= quote.askTenthsCR,
      quote.stock >= 0, quote.targetStock >= 0, quote.epoch >= 0
    else {
      throw OriginalMarketCatalogueError.invalidSchema("Initial quote identity/units/quantities")
    }
  }

  private static func validateFields(_ data: Data) throws {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      Set(root.keys) == ["version", "markets"], root["version"] is String,
      let states = root["markets"] as? [[String: Any]]
    else { throw OriginalMarketCatalogueError.invalidSchema("Exact initial-market root fields") }
    for state in states {
      guard Set(state.keys) == ["key", "galaxy", "system", "quotes"], state["key"] is String,
        integral(state["galaxy"]), integral(state["system"]),
        let quotes = state["quotes"] as? [[String: Any]]
      else { throw OriginalMarketCatalogueError.invalidSchema("Exact initial-state fields/types") }
      for quote in quotes {
        guard Set(quote.keys) == OriginalMarketInitialQuote.fields,
          quote["name"] is String, quote["unit"] is String, quote["worldVersion"] is String,
          ["system", "index", "askTenthsCR", "bidTenthsCR", "stock", "targetStock", "epoch"]
            .allSatisfy({ integral(quote[$0]) })
        else {
          throw OriginalMarketCatalogueError.invalidSchema("Exact initial-quote fields/types")
        }
      }
    }
  }

  private static func integral(_ value: Any?) -> Bool {
    guard let number = value as? NSNumber,
      String(cString: number.objCType) != "c", let integer = Int(number.stringValue)
    else { return false }
    return integer >= 0
  }

  private static func resourceDirectory() throws -> URL {
    let resources =
      Bundle.main.resourceURL.flatMap {
        Bundle(url: $0.appendingPathComponent("L337_L337Core.bundle"))
      } ?? Bundle.module
    guard let root = resources.resourceURL else {
      throw OriginalMarketCatalogueError.missingResource("OriginalMarkets")
    }
    return root.appendingPathComponent("OriginalMarkets", isDirectory: true)
  }

  private static func boundedData(_ url: URL, maximum: Int) throws -> Data {
    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
    guard values.isRegularFile == true, values.isSymbolicLink != true else {
      throw OriginalMarketCatalogueError.missingResource(url.lastPathComponent)
    }
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    guard let data = try handle.read(upToCount: maximum + 1), data.count <= maximum else {
      throw OriginalMarketCatalogueError.invalidSchema("Bounded resource: " + url.lastPathComponent)
    }
    return data
  }

  private static func fingerprint(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}
