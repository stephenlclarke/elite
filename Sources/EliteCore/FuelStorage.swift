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
  public var maximumJumpDistance: Double { min(jumpCap, Double(availableJumpFuel) / 10) }
}
