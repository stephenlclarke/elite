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
