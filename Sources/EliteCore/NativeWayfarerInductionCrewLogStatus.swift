import Foundation

public struct NativeInductionCrewLogSelectionFacts: Sendable, Equatable {
  let original: UUID
  let fits: Bool
}

extension Game {
  func inductionCrewLogFacts(_ body: SpaceBody) -> NativeInductionCrewLogSelectionFacts? {
    guard inductionCrewLogRecorder(body) != nil,
      let state = inductionCrewLogChild?.savedNativeCrewLog
    else { return nil }
    return .init(
      original: state.authorization.manifest.recorder,
      fits: commander.tradeCargoCapacity - commander.cargoTonnes >= 1)
  }

  func inductionCrewLogMetadata(_ body: SpaceBody) -> SalvageTargetMetadata? {
    guard inductionCrewLogFacts(body) != nil,
      let mesh = inductionCrewLogCompatibleMesh(body)
    else { return nil }
    return .init(
      category: .cargo, ownership: .missionProtected, claimant: nil,
      wreck: nil, section: nil, lot: nil,
      bounds: .init(center: .init(0, 0, 0), radius: mesh.vertices.map(\.length).max() ?? 0),
      workSurfaces: [])
  }

  var inductionCrewLogStatus: String? {
    guard let parent = wayfarerInductionMission?.savedWayfarerInduction,
      parent.seedReception != nil
    else { return nil }
    if parent.crewLogLoss != nil {
      return
        "Original custody recorder lost with its carrier. Its pickup history remains; no replacement or rescue receiving is invented."
    }
    if let state = inductionCrewLogChild?.savedNativeCrewLog, let flight = state.flight {
      if state.livingCrew.isEmpty {
        return
          "Original rescue launch destroyed; original crew are lost without actual supported surviving-person custody. No replacement people, receiving or stage9 credit is granted."
      }
      if let contact = flight.dockedContact {
        return
          "Original rescue launch berthed at G\(contact.station.system.galaxy + 1)-S\(contact.station.system.system) / two original crew aboard / "
          + (flight.serviceWait?.rawValue
            ?? (nextInductionRescueHop(flight) == nil
              ? "Enmadan original survivor/recorder receiving remains next"
              : "needed-hop paid fuel and native berth exit"))
      }
      if let last = flight.legs.last,
        let leg = commander.scriptState.wormholeTransit?.legs[last.leg]
      {
        if leg.phase == .inTransit || leg.phase == .arrivalPending {
          return
            "Original marked launch in actual native transit / two original crew aboard. Follow its recorded destination; arrival needs real destination admission."
        }
        if leg.phase != .arrived && leg.phase != .cancelled {
          return
            "Original marked launch requesting its own powered12s spool/aperture; native fuel and mass lock still apply. Keep clear of the ship."
        }
        if last.hop == flight.authorization.route.distancesLY.count - 1 && leg.phase == .arrived {
          return
            "Original marked launch actually admitted at Enmadan and approaching its real station berth. Survivor/recorder receiving remains next; no stage9 credit granted."
        }
      }
      if let hop = nextInductionRescueHop(flight),
        let npc = inductionCrewLogChild?.ownedEncounters[NativeInductionCrewLogPack.encounter]?
          .actors["launch"]?.body.scriptNPC,
        npc.fuel < flight.authorization.route.distancesLY[hop.hop]
      {
        return
          "Original marked launch approaching the real main-orbital berth for needed-hop fuel. Its own finite escrow and the station's shared finite stock govern paid service; no arrival-time refill."
      }
      return
        "Original marked-launch escort registered with the same two crew and retained fuel. Depart Cevilis and approach its real source; it clears the work area through ordinary flight before native hops."
    }
    if parent.crewLog != nil, let state = inductionCrewLogChild?.savedNativeCrewLog,
      state.rescueFuel == nil
    {
      return
        "Original crew recorder protected aboard / 1t. At Cevilis main orbital, review the still-unissued original rescue fuel allocation. Loading/reopening grants no funds. Stage9 actual travel/receiving remains unavailable."
    }
    if parent.crewLog != nil {
      return
        "Stage8: original crew custody recorder protected aboard / 1t. Its two original crew remain in the marked launch; stage9 actual launch escort and Enmadan receiving are not yet available."
    }
    guard let state = inductionCrewLogChild?.savedNativeCrewLog else {
      return
        "Fly to Cevilis G01-S211 for the disabled Burro tender and marked two-person launch. Fit Fuel Scoops and keep one free tonne for their original custody recorder."
    }
    if state.losses.contains(where: { $0.role == "recorder" }) {
      return
        "Original Cevilis recorder physically destroyed before pickup. No substitute or stage8 credit is available."
    }
    if state.admission == nil {
      return
        "Cevilis original source registered; native admission is pending clearance/local range. Main-station non-spinning reference: tender X+60km/Y+20km/Z0; recorder Z+100m from tender; marked launch X+300m from tender."
    }
    return
      "Original Cevilis recorder available: Fuel Scoops, one free tonne, safe approach to the lower forward scoop. Original living launch crew: \(state.livingCrew.count)/2. Recovering the log does not board people or award rescue receiving."
  }
}
