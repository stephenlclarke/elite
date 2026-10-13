import Foundation

extension Game {
  var currentShowroomProfile: ShipProfile {
    let commander = commander
    var fields = [
      fittedSpec("cargo_tonnes", "Cargo capacity", commander.capacity, "t"),
      fittedSpec("hull_energy", "Energy capacity", 256, "native units"),
      fittedSpec("maximum_speed_project_units", "Maximum speed", 32 * 18, "native units/s"),
      fittedSpec(
        "acceleration_project_units_per_second_squared", "Acceleration", 12 * 18, "native units/s2"),
      fittedSpec(
        "energy_recharge_per_second", "Energy recharge", 2 * commander.energyRechargeMultiplier,
        "native units/s"),
      fittedSpec("fore_shield_recharge_per_second", "Front recharge", 1, "native units/s"),
      fittedSpec("aft_shield_recharge_per_second", "Rear recharge", 1, "native units/s"),
      fittedSpec("roll_radians_per_second", "Normal roll authority", 1, "rad/s"),
      fittedSpec("pitch_radians_per_second", "Pitch authority", 1, "rad/s"),
      fittedSpec("yaw_radians_per_second", "Yaw authority", 1, "rad/s"),
      fittedSpec("fore_shield_max", "Front shield", commander.shieldCapacity, "native units"),
      fittedSpec("aft_shield_max", "Rear shield", commander.shieldCapacity, "native units"),
      fittedSpec("fuel_capacity_tenths_ly", "Fuel capacity", commander.fuelCapacity, "0.1 LY"),
      ShipSpec(
        key: "hyperspace_range_ly", label: "Jump range",
        text: String(format: "%.1f LY", commander.maximumJumpDistance),
        number: commander.maximumJumpDistance, unit: "LY", status: "actual fitted",
        basis: "Fuel, tank and navigation limits"),
      fittedSpec("missile_capacity", "Missile capacity", 4, "pylons"),
      fittedSpec("laser_facing_mask", "Laser facings", 15, "bit mask"),
      fittedSpec("jump_spool_seconds", "Jump spool", 15, "s"),
      fittedSpec(
        "cargo_expansion_tonnes", "Cargo expansion",
        commander.equipment.contains("Large Cargo Bay") ? 15 : 0, "t"),
      ShipSpec(
        key: "docking_computer", label: "Docking computer",
        text: commander.hasAutomaticDocking ? "Yes" : "No", number: nil, unit: "",
        status: "actual fitted", basis: "Effective targeting tier"),
      ShipSpec(
        key: "hyperspace_drive", label: "Hyperspace drive", text: "Yes", number: nil, unit: "",
        status: "actual fitted", basis: "Native Cobra drive"),
      ShipSpec(
        key: "equipment_capacity_units", label: "Equipment capacity",
        text: "Capability-based fitting; no native slot pool", number: nil,
        unit: "native constraints", status: "actual fitted",
        basis: "Hardware has individual fitting limits rather than a slot counter"),
      fittedSpec("new_refit_initial_missiles", "Missile stock", commander.missiles, "missiles"),
      fittedSpec("required_crew_including_commander", "Required crew", 1, "people"),
      fittedSpec("reserved_crew_accommodation", "Reserved crew quarters", 1, "people"),
      fittedSpec("fitted_passenger_berths", "Fitted passenger berths", 0, "berths"),
      fittedSpec("passengers_aboard", "Passengers aboard", 0, "people"),
      fittedSpec("free_passenger_places", "Free passenger places", 0, "people"),
      fittedSpec("hold_used_by_cabins", "Hold used by cabins", 0, "t"),
      fittedSpec(
        "usable_cargo_after_fit", "Usable cargo after fit",
        commander.capacity - commander.cargoTonnes, "t"),
    ]
    if commander.unlimitedCargo {
      for key in ["cargo_tonnes", "usable_cargo_after_fit"] {
        if let index = fields.firstIndex(where: { $0.key == key }) {
          fields[index] = .init(
            key: key, label: fields[index].label, text: "Unlimited (XYZZY)",
            number: nil, unit: "t", status: "actual fitted",
            basis: "Unlimited cargo policy; internal integer ceiling is not a physical bay size")
        }
      }
    }
    fields += LaserMount.allCases.map { mount in
      .init(
        key: mount == .front ? "forward_laser" : mount.rawValue + "_laser",
        label: mount.label + " laser",
        text: commander.laser(on: mount)?.equipmentName ?? "Empty", number: nil, unit: "",
        status: "actual fitted", basis: "Current independent laser mount")
    }
    return .init(
      id: "native-current-cobra", title: "Current fitted Cobra Mk III", group: "native-current",
      context:
        "Actual commander fit and native normal-flight authority; Spin Hold has separate roll limits. No charter cabins fitted. Operating quarters are separate from usable cargo.",
      fields: fields)
  }
  private func fittedSpec(_ key: String, _ label: String, _ value: Int, _ unit: String) -> ShipSpec
  {
    .init(
      key: key, label: label, text: "\(value) \(unit)", number: Double(value), unit: unit,
      status: "actual fitted", basis: "Current native Cobra Mk III configuration")
  }
  private func fittedSpec(_ key: String, _ label: String, _ value: Double, _ unit: String)
    -> ShipSpec
  {
    .init(
      key: key, label: label, text: String(format: "%.1f %@", value, unit), number: value,
      unit: unit, status: "actual fitted", basis: "Current native Cobra Mk III configuration")
  }
  func comparableShowroomField(
    _ left: ShipSpec?, _ right: ShipSpec?,
    baseline: ShipProfile?, selected: ShipProfile?
  ) -> Bool {
    if baseline?.group == selected?.group { return true }
    guard baseline?.group == "native-current", let left, let right, left.unit == right.unit else {
      return false
    }
    // Physical capacities/counts share units; engine-specific performance pools do not.
    return ["t", "LY", "0.1 LY", "people", "berths", "missiles", "pylons"].contains(left.unit)
  }
}
