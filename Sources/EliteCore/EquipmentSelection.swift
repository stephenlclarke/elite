extension Game {
  /// The utility is a distinct purchase destination, never another combat facing.
  mutating func cycleEquipmentFitting(_ step: Int) {
    let hasWorkTool = commander.nativePerformance.workTools?.contains(.miningLaser) == true
    let mounts = LaserMount.allCases
    let count = mounts.count + (hasWorkTool ? 1 : 0)
    let current =
      equipmentWorkTool && hasWorkTool
      ? mounts.count : mounts.firstIndex(of: equipmentMount) ?? 0
    let next = (current + (step < 0 ? count - 1 : 1)) % count
    equipmentWorkTool = next == mounts.count
    if !equipmentWorkTool { equipmentMount = mounts[next] }
  }
}
