import Foundation

public enum Plugh {
  public static let systemID = 256
  public static let rumourStation = 7
  public static let name = "PLUGH"
  /// A documented balancing default, applied once to the transaction in tenths of CR.
  public static func discount(_ price: Int) -> Int { price == 0 ? 0 : max(1, (price * 3 + 2) / 4) }
  public static let rewardPrices: [String: Int] = [
    Equipment.navalLaser: 180000,
    ShieldBooster.capital.equipmentName: 135000,
  ]
  public static func system(galaxy: Int) -> StarSystem {
    let originals = Universe.galaxy(number: galaxy)
    let anchor = originals[rumourStation]
    let offsets: [Double] = [4, -4, 3, -3, 5, -5, 6, -6]
    var position = (x: anchor.x, y: anchor.y)
    search: for dx in offsets {
      for dy in [0.0, 2.0, -2.0, 4.0, -4.0] {
        let x = anchor.x + dx
        let y = anchor.y + dy
        if x.isFinite, y.isFinite,
          !originals.contains(where: { $0.x == x && $0.y == y })
        {
          position = (x, y)
          break search
        }
      }
    }
    return .init(
      id: systemID, name: name, x: position.x, y: position.y,
      economy: 0, government: 7, technology: 14, population: 64,
      productivity: 56320, radius: 6200 + (galaxy & 7) * 137, seed: anchor.seed,
      nativeGalaxy: galaxy)
  }
}
extension Universe {
  public static func systemsIncludingPlugh(number: Int = 0) -> [StarSystem] {
    galaxy(number: number) + [Plugh.system(galaxy: number)]
  }
}
extension StarSystem { public var isPlugh: Bool { id == Plugh.systemID } }
extension Commander {
  public func hasDiscoveredPlugh(in galaxy: Int) -> Bool {
    (plughDiscoveryMask & (1 << galaxy)) != 0
  }
  mutating func discoverPlugh(in galaxy: Int) { plughDiscoveryMask |= 1 << galaxy }
}
extension MarketItem {
  public static func at(_ system: StarSystem) -> [MarketItem] {
    OriginalLiveMarkets.initial(galaxy: system.galaxy, system: system)
  }
  static func minimumPrices(at system: StarSystem) -> [Int] {
    at(system).map(\.bidPrice)
  }
}
extension Game {
  public var knownSystems: [StarSystem] {
    systems.filter { !$0.isPlugh || commander.hasDiscoveredPlugh(in: commander.galaxy) }
  }
  public var atPlugh: Bool { currentSystem.isPlugh }
  public func equipmentAvailable(_ item: Equipment) -> Bool {
    if item.name == AlienMissileDefinition.name {
      return stationAllowsEquipmentServices && nativeAlienFittingAvailable
        && commander.hasAlienMissileResearch
    }
    return stationAllowsEquipmentServices
      && (atPlugh
        || (item.requiredTechnologyLevel <= currentSystem.technology
          && !Equipment.isReward(item.name)))
  }
  public func shopPrice(_ item: Equipment) -> Int {
    let price = Plugh.rewardPrices[item.name] ?? item.price
    if item.name == "Fuel" {
      let total = (commander.fuelCapacity - commander.fuel) * item.price
      return atPlugh ? Plugh.discount(total) : total
    }
    return atPlugh ? Plugh.discount(price) : item.price
  }
  public var refillCost: Int { shopPrice(Equipment.base[0]) }
  mutating func openStationRumour() {
    guard docked, dockedAtMainStation,
      ![
        Screen.help, .secret, .mission, .handoff, .gallery, .showroom, .demo, .title, .gameOver,
        .rumour,
      ].contains(screen)
    else { return }
    wantedDetail = false
    wantedRumourDetail = false
    wantedScroll = 0
    rumourReturn = screen
    if commander.system == Plugh.rumourStation { commander.discoverPlugh(in: commander.galaxy) }
    screen = .rumour
  }
  public var stationRumour: String {
    let anchor = Universe.galaxy(number: commander.galaxy)[Plugh.rumourStation]
    if !commander.hasDiscoveredPlugh(in: commander.galaxy) {
      return
        "A dockside trader mentions a hidden discount port. Ask for station rumours at \(anchor.name)'s main station in Galaxy \(commander.galaxy + 1). The location is not on public charts."
    }
    let secret = Plugh.system(galaxy: commander.galaxy)
    return
      "PLUGH is now marked on your Galaxy \(commander.galaxy + 1) chart at \(secret.x),\(secret.y), near \(anchor.name). All commodities are stocked. All supported equipment, including Naval and Capital rewards, can be bought here at secret-shop prices. Purchases cost money and normal fitting limits apply. Default discount: 25%, rounded to 0.1 CR. Fuel is discounted once on the full refill transaction. Discovery is saved for this galaxy."
  }
}
