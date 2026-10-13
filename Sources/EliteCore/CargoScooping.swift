extension Game {
  /// The native cargo approach uses the scoop below the forward cockpit.
  mutating func scoopCargo() {
    guard !docked, commander.equipment.contains("Fuel Scoops") else { return }
    let candidates = bodies.filter { body in
      let scoopable = body.hull == .cargo || (body.hull == .thargon && !body.hostile)
      return scoopable && body.energy > 0 && body.position.z > 0 && body.position.y < 0
        && body.position.length < 85
    }
    for body in candidates {
      let commodity = body.hull == .thargon ? 16 : 0
      guard commander.cargo[commodity] < Int.max / 17,
        commander.cargoTonnes < commander.capacity
      else {
        notify("CARGO HOLD FULL")
        continue
      }
      commander.cargo[commodity] += 1
      bodies.removeAll { $0.id == body.id }
      notify("SCOOPED " + Commodity.all[commodity].name)
    }
  }
}
