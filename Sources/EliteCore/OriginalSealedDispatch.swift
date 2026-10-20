import Foundation

/// Closed Original G01 terms reuse native courier generation, custody and settlement.
enum OriginalSealedDispatch {
  static let stateID = "l337.contract/sealed-dispatch"
  static let provider = "l337.contract"
  static let boardID = "sealed-dispatch"
  static let group = "sealed-dispatch"
  static let definition = ScriptCourierDefinition(
    profile: "original-sealed-dispatch", generatorRevision: 1,
    deliveryContact: "sealed-dispatch-receiver", abandonContact: "sealed-dispatch-sender")

  static func matches(_ declaration: ScriptCourierDefinition) -> Bool {
    declaration == definition
  }

  static func rows(_ declaration: ScriptCourierDefinition) -> [Int] {
    matches(declaration) ? [1, 3, 5] : Array(0..<6)
  }

  static func group(_ declaration: ScriptCourierDefinition) -> String {
    matches(declaration) ? group : "g02-courier"
  }

  static func validManifest(_ manifest: ScriptManifest) -> Bool {
    manifest.stateID == stateID && manifest.courier == definition
      && manifest.board?.id == boardID && manifest.board?.exclusiveGroup == group
  }

  static func validBoard(_ board: ScriptContractBoard) -> Bool {
    guard let declaration = board.offers.first?.courier?.declaration else { return false }
    let rows = rows(declaration)
    return board.offers.count == rows.count
      && (!matches(declaration) || (board.provider == provider && board.id == boardID))
      && board.group == board.provider + "/" + group(declaration)
      && zip(rows, board.offers).allSatisfy { row, offer in
        offer.courier?.row == row && offer.courier?.declaration == declaration
      }
  }

  static func validJob(_ job: ScriptContractJob) -> Bool {
    guard let terms = job.offer.courier else { return false }
    return job.group == job.provider + "/" + group(terms.declaration)
      && (!matches(terms.declaration)
        || (job.provider == provider
          && job.boardKey.split(separator: "/").dropFirst().first.map(String.init) == boardID))
      && hasHeadroom(terms)
  }

  static func hasHeadroom(_ terms: ScriptCourierTerms) -> Bool {
    matches(terms.declaration) || terms.calendarLowerBoundSeconds < terms.duration
  }

  static func validDeadline(_ job: ScriptContractJob) -> Bool {
    guard let terms = job.offer.courier else { return false }
    return matches(terms.declaration)
      ? job.deadline == nil && job.offer.duration == 0 : job.deadline != nil
  }

  static func deliveryAllowed(_ job: ScriptContractJob, at clock: Double) -> Bool {
    validDeadline(job) && (job.deadline.map { clock <= $0 } ?? true)
  }
}
