import Foundation

public struct ScriptAnswerRequirement: Codable, Sendable {
  public let dialogue: String
  public let choice: String
  public let minimumCount: Int
  var key: String { dialogue + "/" + choice }
  var valid: Bool {
    PackValidation.localID(dialogue) && PackValidation.localID(choice)
      && (1...1024).contains(minimumCount)
  }
}

extension ScriptInstance {
  public var conversationReceipts: [UInt64: ScriptChoiceReceipt] {
    get { savedConversationReceipts ?? [:] }
    set { savedConversationReceipts = newValue.isEmpty ? nil : newValue }
  }
}

extension Game {
  func scriptAnswersSatisfied(_ pack: ScriptPack, state: ScriptInstance) -> Bool {
    (pack.manifest.answerRequirements ?? []).allSatisfy { requirement in
      state.conversationReceipts.values.filter {
        $0.dialogue == requirement.dialogue && $0.choice == requirement.choice
      }.count >= requirement.minimumCount
    }
  }
  /// Keep the query compact; original immutable envelopes remain in the saved receipt ledger.
  func scriptAnswersSnapshot(_ state: ScriptInstance) -> ScriptValue {
    struct Summary {
      var count: Int
      let first: UInt64
      var last: UInt64
      var label: String
      var value: ScriptValue {
        .object([
          "count": .integer(Int64(count)), "first_sequence": .integer(Int64(first)),
          "last_sequence": .integer(Int64(last)), "label": .string(label),
        ])
      }
    }
    var answers: [String: [String: Summary]] = [:]
    for receipt in state.conversationReceipts.values.sorted(by: { $0.sequence < $1.sequence }) {
      var summary =
        answers[receipt.dialogue]?[receipt.choice]
        ?? Summary(count: 0, first: receipt.sequence, last: receipt.sequence, label: receipt.label)
      summary.count += 1
      summary.last = receipt.sequence
      summary.label = receipt.label
      answers[receipt.dialogue, default: [:]][receipt.choice] = summary
    }
    return .object(answers.mapValues { .object($0.mapValues(\.value)) })
  }
}

extension ScriptPackLibrary {
  static func validateAnswers(_ manifest: ScriptManifest) throws {
    let requirements = manifest.answerRequirements ?? []
    guard requirements.count <= 64,
      Set(requirements.map(\.key)).count == requirements.count,
      requirements.allSatisfy(\.valid),
      requirements.reduce(0, { $0 + $1.minimumCount }) <= 1024,
      requirements.isEmpty || manifest.capabilities.contains("dialogue-choices-v2"),
      requirements.allSatisfy({ requirement in
        manifest.dialogs?.first { $0.id == requirement.dialogue }?.choices?.contains {
          $0.id == requirement.choice && $0.group == nil
        } == true
      })
    else { throw MissionPackError("Invalid native conversation answer requirements.") }
  }
}
