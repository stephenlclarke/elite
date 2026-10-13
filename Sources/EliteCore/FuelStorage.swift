public enum FuelStorage {
  public static let equipmentName = "Fuel Storage Unit"
  public static let maximumCount = 4
  public static let unitCapacity = 70
  public static let price = 20000
}
extension Commander {
  public var fuelCapacity: Int { FuelStorage.unitCapacity * (1 + fuelStorageUnits) }
  public var availableJumpFuel: Int { fuel }
  public var jumpCap: Double { navigationTier?.jumpCap ?? 7 }
  public var maximumJumpDistance: Double { min(jumpCap, Double(availableJumpFuel) / 10) }
}
