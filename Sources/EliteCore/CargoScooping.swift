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
      if let payload = body.physical?.payload {
        guard let context = gameplayContext() else { continue }
        var cargo = commander.cargo
        let freeTonnes = max(0, commander.capacity - commander.cargoTonnes)
        let receipt = commander.miningLedger.collect(
          payload: payload, into: &cargo,
          freeTonnes: freeTonnes,
          hasScoops: true, approachAllowed: true, protection: context.protection)
        switch receipt {
        case .collected(let amount):
          commander.cargo = cargo
          bodies.removeAll { $0.id == body.id }
          notify(
            "SCOOPED \(amount.quantity) \(amount.commodity.unit) "
              + Commodity.all[amount.commodity.rawValue].name)
        case .refused(.fullHold):
          if message != "CARGO HOLD FULL" || messageTime <= 0 { notify("CARGO HOLD FULL") }
        case .refused: break
        }
        continue
      }
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
