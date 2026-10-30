public enum FuelStorage {
  public static let equipmentName = "Fuel Storage Unit"
  public static let maximumCount = 4
  public static let unitCapacity = 70
  public static let price = 20000
}
extension Commander {
  public var fuelCapacity: Int { performance.fuel + FuelStorage.unitCapacity * fuelStorageUnits }
  public var availableJumpFuel: Int { fuel }
  public var jumpCap: Double {
    max(
      nativePerformance.jump,
      fittedComponent(at: .navigation)?.statistics[.jumpReach] ?? navigationTier?.jumpCap ?? 0)
  }
  public var jumpFuelMultiplier: Double {
    fittedComponent(at: .navigation)?.statistics[.jumpFuelCost] ?? 1
  }
  public func fuelDistance(for units: Int) -> Double {
    jumpFuelMultiplier > 0 ? Double(units) / (10 * jumpFuelMultiplier) : jumpCap
  }
  public func jumpFuelCost(distance: Double) -> Int {
    Int((distance * 10 * jumpFuelMultiplier).rounded())
  }
  public var fullTankJumpDistance: Double { min(jumpCap, fuelDistance(for: fuelCapacity)) }
  public var maximumJumpDistance: Double { min(jumpCap, fuelDistance(for: availableJumpFuel)) }
}
