import Foundation

public struct SystemSeed: Sendable, Equatable, Codable {
  public var a: UInt16
  public var b: UInt16
  public var c: UInt16
  public mutating func twist() {
    let next = a &+ b &+ c
    a = b
    b = c
    c = next
  }
}

public struct StarSystem: Sendable, Equatable, Codable {
  public let id: Int
  public let name: String
  public let x: Int
  public let y: Int
  public let economy: Int
  public let government: Int
  public let technology: Int
  public let population: Int
  public let productivity: Int
  public let radius: Int
  public let seed: SystemSeed
  public var economyName: String {
    [
      "Rich Industrial", "Average Industrial", "Poor Industrial", "Mainly Industrial",
      "Mainly Agricultural", "Rich Agricultural", "Average Agricultural", "Poor Agricultural",
    ][economy]
  }
  public var governmentName: String {
    [
      "Anarchy", "Feudal", "Multi-government", "Dictatorship", "Communist", "Confederacy",
      "Democracy", "Corporate State",
    ][government]
  }
  public func distance(to other: StarSystem) -> Double {
    let dx = Double(x - other.x)
    let dy = Double(y - other.y) / 2
    return floor(sqrt(dx * dx + dy * dy)) * 4 / 10
  }
}

public enum Universe {
  public static func galaxy(number: Int = 0) -> [StarSystem] {
    var seed = SystemSeed(a: 0x5a4a, b: 0x0248, c: 0xb753)
    for _ in 0..<(number & 7) {
      seed = SystemSeed(a: rotate(seed.a), b: rotate(seed.b), c: rotate(seed.c))
    }
    return (0..<256).map { index in
      let initial = seed
      let x = Int(seed.b >> 8)
      let y = Int(seed.a >> 8)
      let government = Int((seed.b >> 3) & 7)
      var economy = Int((seed.a >> 8) & 7)
      if government < 2 { economy |= 2 }
      let technology = (x & 3) + (economy ^ 7) + government / 2 + (government & 1)
      let population = 4 * technology + economy + government + 1
      let pairs = Array("..LEXEGEZACEBISOUSESARMAINDIREA.ERATENBERALAVETIEDORQUANTEISRION")
      let longName = seed.a & 64 != 0
      var name = ""
      for part in 0..<4 {
        let offset = Int((seed.c >> 8) & 31) * 2
        if part < 3 || longName {
          name.append(pairs[offset])
          name.append(pairs[offset + 1])
        }
        seed.twist()
      }
      return StarSystem(
        id: index, name: name.replacingOccurrences(of: ".", with: ""), x: x, y: y,
        economy: economy, government: government, technology: technology,
        population: population,
        productivity: ((economy ^ 7) + 3) * (government + 4) * population * 8,
        radius: 256 * Int((initial.c >> 8) & 15) + x + 2816, seed: initial)
    }
  }
  private static func rotate(_ word: UInt16) -> UInt16 {
    let low = UInt8(truncatingIfNeeded: word)
    let high = UInt8(truncatingIfNeeded: word >> 8)
    return UInt16((low &<< 1) | (low >> 7)) | (UInt16((high &<< 1) | (high >> 7)) << 8)
  }
}

public struct Commodity: Sendable, Equatable {
  public let name: String
  public let unit: String
  public let basePrice: Int
  public let gradient: Int
  public let baseQuantity: Int
  public let mask: Int
  public static let all: [Commodity] = [
    .init(name: "Food", unit: "t", basePrice: 19, gradient: -2, baseQuantity: 6, mask: 1),
    .init(name: "Textiles", unit: "t", basePrice: 20, gradient: -1, baseQuantity: 10, mask: 3),
    .init(name: "Radioactives", unit: "t", basePrice: 65, gradient: -3, baseQuantity: 2, mask: 7),
    .init(name: "Slaves", unit: "t", basePrice: 40, gradient: -5, baseQuantity: 226, mask: 31),
    .init(
      name: "Liquor/Wines", unit: "t", basePrice: 83, gradient: -5, baseQuantity: 251, mask: 15),
    .init(name: "Luxuries", unit: "t", basePrice: 196, gradient: 8, baseQuantity: 54, mask: 3),
    .init(name: "Narcotics", unit: "t", basePrice: 235, gradient: 29, baseQuantity: 8, mask: 120),
    .init(name: "Computers", unit: "t", basePrice: 154, gradient: 14, baseQuantity: 56, mask: 3),
    .init(name: "Machinery", unit: "t", basePrice: 117, gradient: 6, baseQuantity: 40, mask: 7),
    .init(name: "Alloys", unit: "t", basePrice: 78, gradient: 1, baseQuantity: 17, mask: 31),
    .init(name: "Firearms", unit: "t", basePrice: 124, gradient: 13, baseQuantity: 29, mask: 7),
    .init(name: "Furs", unit: "t", basePrice: 176, gradient: -9, baseQuantity: 220, mask: 63),
    .init(name: "Minerals", unit: "t", basePrice: 32, gradient: -1, baseQuantity: 53, mask: 3),
    .init(name: "Gold", unit: "kg", basePrice: 97, gradient: -1, baseQuantity: 66, mask: 7),
    .init(name: "Platinum", unit: "kg", basePrice: 171, gradient: -2, baseQuantity: 55, mask: 31),
    .init(name: "Gem-Stones", unit: "g", basePrice: 45, gradient: -1, baseQuantity: 250, mask: 15),
    .init(name: "Alien Items", unit: "t", basePrice: 53, gradient: 15, baseQuantity: 192, mask: 7),
  ]
}

public struct MarketItem: Sendable, Equatable, Codable {
  public var price: Int  // Tenths of a credit, avoiding floating point accounting.
  public var quantity: Int
  public static func generate(economy: Int, fluctuation: Int) -> [MarketItem] {
    Commodity.all.enumerated().map { index, item in
      let product = economy * item.gradient
      let changing = fluctuation & item.mask
      let rawQuantity = (item.baseQuantity + changing - product) & 255
      let quantity = index == 16 || rawQuantity & 128 != 0 ? 0 : rawQuantity & 63
      return MarketItem(
        price: ((item.basePrice + changing + product) & 255) * 4, quantity: quantity)
    }
  }
}
