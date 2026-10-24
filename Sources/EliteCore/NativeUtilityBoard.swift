import Foundation

struct NativeUtilityBoardReview: Sendable {
  let action: NativeUtilityAction
  let quote: NativeUtilityQuote?
  let issues: [String]
  var allowed: Bool { quote != nil && issues.isEmpty }
}
extension NativeUtilityAction {
  var utilityKey: String { "l337.wayfarer-service/field-relief/native/" + rawValue }
  var utilityLabel: String {
    switch self {
    case .collect: "Collect four original tonnes"
    case .install: "Install original regulator materials"
    case .receive: "Receive current engineer's inspection"
    case .returnMaterials: "Return and retire original materials"
    }
  }
}
extension Game {
  var nativeUtilityRows: [ContractBoardRow] {
    guard let utility = commander.nativeUtility else { return [] }
    var actions: [NativeUtilityAction] = []
    if nativeMainStationArrivalContext(for: utility.source) != nil {
      if utility.active?.phase == .held {
        actions.append(.returnMaterials)
      } else if utility.active == nil, utility.consignments.count < 2 {
        actions.append(.collect)
      }
    }
    if nativeUtilityServiceContext != nil {
      if utility.active?.phase == .held { actions.append(.install) }
      if utility.active?.phase == .installed { actions.append(.receive) }
    }
    return actions.map { action in
      .init(
        board: "l337.wayfarer-service/field-relief", offer: nil,
        title: "Field relief: " + action.utilityLabel,
        reason: nativeUtilityReview(action).issues.first, utility: action)
    }
  }
  func nativeUtilityReview(_ action: NativeUtilityAction) -> NativeUtilityBoardReview {
    do { return .init(action: action, quote: try nativeUtilityQuote(action), issues: []) } catch {
      return .init(
        action: action, quote: nil, issues: [String(error.localizedDescription.prefix(512))])
    }
  }
  var nativeUtilityDetail: [String] {
    guard let review = contractBoard.utilityQuote else {
      return ["Review the current utility operation."]
    }
    var rows = [
      "Field relief: " + review.action.utilityLabel,
      "Collect, install, then separately Confirm the current engineer reception for the frozen payment.",
      "Four original one-tonne materials; zero passenger berths.",
      "Two finite regulator sockets at the actual RRS headquarters, galaxy 1/system 237.",
      "Each installed regulator adds 10 energy/second to native station recharge.",
      "Ordinary variant, hazard tier 0, no deadline. Later route legs assume refuelling.",
      "Only verified engineer reception pays once and retains the existing field relief clue. Three shared active services maximum.",
    ]
    if let quote = review.quote {
      if !quote.route.isEmpty {
        rows.append("Quoted route: " + quote.route.map(String.init).joined(separator: " -> "))
        rows.append(
          "Frozen mission quote: \(quote.rewardTenths / 10) CR = 610 + 110 per reachable leg, payable only at verified reception."
        )
      }
      if let job = quote.expected.active {
        rows.append("Consignment: " + job.id.uuidString)
        rows.append("Frozen reception payment: \(job.rewardTenths / 10) CR.")
        if let mission = commander.scriptState.instances[WayfarerFieldRelief.instance(job.id)] {
          rows.append("Mission: " + mission.outcome.rawValue)
        }
        rows.append(
          "Exact original materials: " + job.originalUnits.map(\.uuidString).joined(separator: ", ")
        )
      }
    }
    return rows + review.issues
  }
}
