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
      "Installation and crew receipt only; payment and mission completion are not available yet.",
      "Four original one-tonne materials; zero passenger berths.",
      "Two finite regulator sockets at the actual RRS headquarters, galaxy 1/system 237.",
      "Each installed regulator adds 10 energy/second to native station recharge.",
      "Ordinary variant, hazard tier 0, no deadline. Later route legs assume refuelling.",
      "Crew receipts preserve evidence only. No payment, story completion or clue is granted.",
    ]
    if let quote = review.quote {
      if !quote.route.isEmpty {
        rows.append("Quoted route: " + quote.route.map(String.init).joined(separator: " -> "))
        rows.append(
          "Independent mission quote: \(quote.rewardTenths / 10) CR = 610 + 110 per reachable leg; native prerequisite does not pay."
        )
      }
      if let job = quote.expected.active {
        rows.append("Consignment: " + job.id.uuidString)
        rows.append(
          "Exact original materials: " + job.originalUnits.map(\.uuidString).joined(separator: ", ")
        )
      }
    }
    return rows + review.issues
  }
}
