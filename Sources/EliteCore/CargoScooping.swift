extension Game {
  /// The native cargo approach uses the scoop below the forward cockpit.
  mutating func scoopCargo() {
    guard !docked, commander.equipment.contains("Fuel Scoops") else { return }
    let candidates = bodies.filter { body in
      let scoopable = body.hull == .cargo || (body.hull == .thargon && !body.hostile)
      return !NativeInductionCrewLogPack.marker(body, commander: commander)
        && !WayfarerRecordRecovery.marker(body, commander: commander)
        && !NativeIdentifiedSalvage.marker(body, commander: commander)
        && !NativeOriginalRescueJourney.marker(body, commander: commander)
        && body.physical?.empCrewPod == nil && scoopable && body.energy > 0 && body.position.z > 0
        && body.position.y < 0
        && body.position.length < 85
    }
    for body in candidates {
      if workGuidance != nil || workBraking != nil {
        let aperture = commander.flightSimulation.pose.orientation.apply(Vector3(0, -45, 55))
        let omega = workGuidance?.angularVelocity ?? workBraking?.angularVelocity ?? .init(0, 0, 0)
        let apertureVelocity = flightWorldVelocity + omega.cross(aperture)
        guard let velocity = body.physical?.velocity, velocity.finite,
          (velocity - apertureVelocity).length <= ScoopApproachController.maximumRelativeSpeed,
          let context = gameplayContext(), automaticScoopShapeCompatible(body, context: context)
        else { continue }
        if let work = workGuidance, case .autoScoop = work.mode,
          work.parent == body.physical?.identity
        {
          guard
            let candidate = workTargetCandidate(for: body, context: context, frontVisible: true),
            WorkTargetSelection.evaluate(
              candidate, system: context.system, visit: context.visit,
              capabilities: workTargetCapabilities
            ).mode == work.mode
          else { continue }
        }
      }
      if let payload = body.physical?.payload, measuredPayloadIsAllocated(payload) {
        observeMeasuredIntake(body)
        continue
      }
      if let payload = body.physical?.payload {
        guard let context = gameplayContext() else { continue }
        var cargo = commander.cargo
        let freeTonnes = max(0, commander.capacity - commander.cargoTonnes)
        if case .salvage(let identity) = payload {
          if usesNativeSalvageCollection(body) {
            observeNativeSalvageCollection(body)
            continue
          }
          guard let actor = body.physical?.identity,
            actor.system == context.system, actor.visit == context.visit,
            identity.section.wreck.system == context.system,
            commander.salvageLedger.boundActor(for: identity) == actor
          else { continue }
          let receipt = commander.salvageLedger.collect(
            lot: identity, cargo: &cargo, freeTonnes: freeTonnes,
            apertureHalfExtents: .init(16, 16, 16), hasScoops: true,
            approachAllowed: true, protection: context.protection)
          switch receipt {
          case .collected(let lot):
            commander.cargo = cargo
            workTargetCollected(body)
            bodies.removeAll { $0.id == body.id }
            switch lot.content {
            case .commodity(let amount):
              notify("RECOVERED " + Commodity.all[amount.commodity.rawValue].name)
            case .technology(let definition, _, _):
              notify(
                "RECOVERED " + definition.replacingOccurrences(of: "-", with: " ").uppercased())
            }
          case .refused(let reason):
            let text = "SALVAGE: " + reason.rawValue.uppercased()
            if message != text || messageTime <= 0 { notify(text) }
          }
          continue
        }
        if case .ore(let rock, _) = payload {
          guard let actor = body.physical?.identity,
            actor.system == context.system, actor.visit == context.visit,
            rock.system == context.system,
            commander.miningLedger.boundActor(for: payload) == actor
          else { continue }
        }
        if case .wreck(let source, _) = payload {
          guard let actor = body.physical?.identity,
            actor.system == context.system, actor.visit == context.visit,
            source.system == context.system,
            commander.cargoDebrisLedger.boundActor(for: payload) == actor
          else { continue }
        }
        let receipt = collectOrdinaryPayload(
          payload: payload, into: &cargo,
          freeTonnes: freeTonnes,
          hasScoops: true, approachAllowed: true, protection: context.protection)
        switch receipt {
        case .collected(let amount):
          commander.cargo = cargo
          workTargetCollected(body)
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
      workTargetCollected(body)
      bodies.removeAll { $0.id == body.id }
      notify("SCOOPED " + Commodity.all[commodity].name)
    }
  }
}
