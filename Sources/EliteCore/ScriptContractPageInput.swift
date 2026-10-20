import Foundation

public struct ScriptContractPageIdentity: Codable, Sendable, Equatable {
  public let generation: UUID
  public let detail: Bool
  public let review: UUID?
  public let selection: String
  public let targets: String
  public let layout: String
  var valid: Bool {
    [selection, targets, layout].allSatisfy(ScriptCompletionReceipt.validDigest)
      && (detail == (review != nil))
  }
  var allowedKeys: Set<String> {
    [
      "return", "escape", "left", "right", "up", "down", "pageup", "pagedown",
      "tab", "contract-refresh", "contracts-open",
    ]
  }
}

extension Game {
  private func contractProofDigest(_ fields: [String]) -> String {
    ScriptPackLibrary.hash(Data(fields.map { "\($0.utf8.count):\($0)" }.joined().utf8))
  }
  var scriptContractPageIdentity: ScriptContractPageIdentity {
    let layout = ContractBoardLayout(width: viewportWidth, height: viewportHeight)
    let first = max(0, contractBoard.selection - layout.listCount + 1)
    let selected = contractBoard.selected
    var fields = [
      screen.rawValue, String(docked), String(dockedAtMainStation), String(paused),
      contractStation.key, String(commander.credits),
      String(commander.sellableCargo(Self.pledgeFood)),
      commander.cargo.map(String.init).joined(separator: ","), commander.shipID,
      String(commander.scriptState.pledgeLedger?.receipts.count ?? 0),
      String(commander.scriptState.instances.count),
      contractBoard.quote?.issues.joined(separator: "\n") ?? "",
    ]
    fields += scriptPacks.filter { $0.manifest.board != nil }.map(\.digest).sorted()
    fields += rrsCourierPageFacts
    fields += financePageFacts
    fields += nativePeoplePageFacts
    fields += providerContractPageFacts
    fields += freightPageFacts
    let visible =
      contractBoard.detail
      ? selected.map { [$0] } ?? []
      : Array(contractBoard.rows.dropFirst(first).prefix(layout.listCount))
    for row in visible {
      fields += [row.key, row.title, row.reason ?? ""]
      if let board = commander.contracts.boards[row.board] {
        fields += [
          String(board.revision),
          (try? contractRevision(board)).map(String.init) ?? "unavailable-generation",
        ]
      }
      if let offer = row.offer {
        fields += [offer.briefing, String(describing: offer.status)]
        if let plan = offer.freightPlan {
          let encoder = JSONEncoder()
          encoder.outputFormatting = [.sortedKeys]
          let bytes = try? encoder.encode(plan)
          fields += [
            bytes?.base64EncodedString() ?? "invalid-freight-plan",
            String(commander.contracts.boards[row.board]?.freightGeneration?.holdCapacity ?? -1),
          ]
        }
        if let terms = offer.courier {
          fields += ScriptCourierPreview(terms: terms).review
        }
      }
    }
    return .init(
      generation: contractBoard.presentationGeneration, detail: contractBoard.detail,
      review: contractBoard.detail
        ? (contractBoard.providerQuote?.reviewToken ?? contractBoard.peopleQuote?.reviewToken
          ?? contractBoard.financeQuote?.reviewToken
          ?? contractBoard.rrsQuote?.reviewToken
          ?? contractBoard.quote?.reviewToken
          ?? contractBoard.reviewToken) : nil,
      selection: contractProofDigest([selected?.key ?? "unavailable"]),
      targets: contractProofDigest(fields),
      layout: contractProofDigest([
        String(viewportWidth), String(viewportHeight),
        String(first), String(contractBoard.scroll), String(layout.listRow),
        String(layout.detailCount),
      ]))
  }
  mutating func finishContractNavigation(from previous: ScriptContractPageIdentity) {
    if previous != scriptContractPageIdentity { contractBoard.presentationGeneration = UUID() }
  }
}

extension GameRuntime {
  public func contractPageClick(x: Double, y: Double) {
    nativeCommand { game in
      let previous = game.scriptContractPageIdentity
      game.contractClick(x: x, y: y)
      game.finishContractNavigation(from: previous)
    }
  }
}
