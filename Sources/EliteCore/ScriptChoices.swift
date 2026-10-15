import Foundation

public struct ScriptDialogChoice: Codable, Sendable {
  public let id: String
  public let label: String
  public let group: String?
  var valid: Bool {
    PackValidation.localID(id) && (group.map(PackValidation.localID) ?? true)
      && (1...80).contains(label.count)
  }
}

/// A genuine station confirmation, independent of mutable narrative data and later callbacks.
public struct ScriptChoiceReceipt: Codable, Sendable, Equatable {
  public let instance: UUID
  public let group: String?
  public let choice: String
  public let label: String
  public let dialogue: String
  public let sequence: UInt64
  public let revision: UInt64
  public let cause: ScriptEventContext?
  public let committed: ScriptEventContext
  func valid(for state: ScriptInstance, engine: ScriptEngineState) -> Bool {
    instance == state.id && (group.map(PackValidation.localID) ?? true)
      && PackValidation.localID(choice)
      && PackValidation.localID(dialogue) && (1...80).contains(label.count)
      && sequence > 0 && sequence <= engine.nextEvent && state.hasAcknowledged(sequence)
      && revision > 0 && revision <= state.revision && committed.revision == revision
      && committed.valid && committed.mainStation
      && committed.localSeconds <= engine.localSeconds
      && committed.flightSeconds <= engine.flightSeconds
      && committed.calendarSeconds <= engine.calendarSeconds
      && committed.transitSeconds <= engine.transitSeconds
      && (cause.map {
        $0.valid && $0.mainStation && $0.revision < revision
          && $0.localSeconds <= committed.localSeconds
          && $0.flightSeconds <= committed.flightSeconds
          && $0.calendarSeconds <= committed.calendarSeconds
          && $0.transitSeconds <= committed.transitSeconds
      } ?? false)
  }
  var value: ScriptValue {
    .object([
      "group": group.map(ScriptValue.string) ?? .null, "exclusive": .bool(group != nil),
      "choice_id": .string(choice), "label": .string(label),
      "dialogue_id": .string(dialogue), "sequence": .integer(Int64(sequence)),
      "cause": cause?.value ?? .null, "committed": committed.value,
    ])
  }
}

extension Game {
  var offeredScriptChoices: [ScriptDialogChoice] {
    guard let id = scriptOffer, let state = commander.scriptState.instances[id],
      let dialogue = scriptPresentedDialogue, let pack = scriptPack(for: state)
    else { return [] }
    return pack.manifest.dialogs?.first { $0.id == dialogue.id }?.choices ?? []
  }
  var selectedScriptChoice: ScriptDialogChoice? {
    let choices = offeredScriptChoices
    return choices.isEmpty
      ? nil : choices[choices.indices.contains(scriptChoiceSelection) ? scriptChoiceSelection : 0]
  }
  var scriptChoiceHeight: Double { offeredScriptChoices.isEmpty ? 0 : 90 }
  var scriptDialogueStale: Bool {
    guard let id = scriptOffer, let shown = scriptPresentedDialogue,
      let state = commander.scriptState.instances[id]
    else { return false }
    return state.dialogue != shown || state.revision != shown.revision
      || state.suspension != nil || state.outcome != .active
  }
  mutating func moveScriptChoice(_ step: Int) {
    let count = offeredScriptChoices.count
    guard count > 0 else { return }
    let current = (0..<count).contains(scriptChoiceSelection) ? scriptChoiceSelection : 0
    scriptChoiceSelection = (current + (step < 0 ? count - 1 : 1)) % count
  }
  func commitScriptChoice(
    _ fields: [String: ScriptValue], event: ScriptEvent, dialogue: ScriptDialog,
    pack: ScriptPack, state: inout ScriptInstance
  ) throws {
    let choices = dialogue.choices ?? []
    guard !choices.isEmpty else {
      guard fields["choice_id"] == nil, event.values["choice_id"] == nil else {
        throw MissionPackError("This dialogue has no declared choice.")
      }
      return
    }
    guard event.context != nil,
      let id = event.values["choice_id"]?.string, fields["choice_id"]?.string == id,
      let choice = choices.first(where: { $0.id == id })
    else { throw MissionPackError("Select and confirm a declared choice at the station.") }
    var committed = state
    committed.revision += 1
    let receipt = ScriptChoiceReceipt(
      instance: state.id, group: choice.group, choice: choice.id, label: choice.label,
      dialogue: dialogue.id, sequence: event.sequence, revision: committed.revision,
      cause: event.context, committed: scriptEventContext(committed))
    if let group = choice.group {
      guard pack.manifest.capabilities.contains("exclusive-choices-v2"),
        state.choiceReceipts[group] == nil
      else { throw MissionPackError("This station branch has already been chosen.") }
      state.choiceReceipts[group] = receipt
    } else {
      guard pack.manifest.capabilities.contains("dialogue-choices-v2"),
        state.conversationReceipts.count < 1024,
        state.conversationReceipts[event.sequence] == nil
      else { throw MissionPackError("The saved conversation receipt capacity is unavailable.") }
      state.conversationReceipts[event.sequence] = receipt
    }
  }
}

extension ScriptPackLibrary {
  static func validateChoices(_ manifest: ScriptManifest) throws {
    let dialogs = manifest.dialogs ?? []
    let choices = dialogs.flatMap { $0.choices ?? [] }
    let groups = Set(choices.compactMap(\.group))
    let requirements = manifest.mission.requiredChoiceGroups ?? []
    guard groups.count <= 64,
      dialogs.allSatisfy({ dialog in
        let items = dialog.choices ?? []
        return items.count <= 8 && items.allSatisfy(\.valid)
          && Set(items.map(\.id)).count == items.count && Set(items.map(\.group)).count <= 1
      }),
      !choices.contains(where: { $0.group != nil })
        || manifest.capabilities.contains("exclusive-choices-v2"),
      !choices.contains(where: { $0.group == nil })
        || manifest.capabilities.contains("dialogue-choices-v2"),
      Set(requirements).count == requirements.count && Set(requirements).isSubset(of: groups),
      !(manifest.receiptRequirements ?? []).contains(where: { $0.choiceGroup != nil })
        || manifest.capabilities.contains("exclusive-choices-v2")
    else { throw MissionPackError("Invalid, unscoped or unsupported station choice declarations.") }
  }
}

extension Display {
  static func stationChoices(
    _ game: Game, frame: inout Frame, left: Double, width: Double, height: Double
  ) {
    guard let choice = game.selectedScriptChoice else { return }
    let font = GameTypography.scale
    let choices = game.offeredScriptChoices
    let index = choices.firstIndex { $0.id == choice.id } ?? 0
    frame.label("CHOICE \(index + 1)/\(choices.count)", left, height - 188, scale: font, ink: .cyan)
    let lines = MissionNotice.wrap(choice.label, width: max(10, Int(width / (6 * font))))
    for (offset, line) in lines.prefix(2).enumerated() {
      frame.label(line, left, height - 164 + Double(offset) * 19, scale: font, ink: .yellow)
    }
    frame.label("< Previous choice", left, height - 122, scale: font, ink: .cyan)
    frame.label("Next choice >", left + width / 2, height - 122, scale: font, ink: .cyan)
  }
}
