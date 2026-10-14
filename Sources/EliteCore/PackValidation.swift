import Foundation

enum PackValidation {
  static func identifier(_ value: String) -> Bool {
    value.range(of: "^[a-z][a-z0-9.-]{0,79}$", options: .regularExpression) != nil
  }
  static func version(_ value: String) -> Bool {
    value.range(
      of: "^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$", options: .regularExpression)
      != nil
  }
  static func localID(_ value: String) -> Bool {
    value.range(of: "^[A-Za-z][A-Za-z0-9.-]{0,79}$", options: .regularExpression) != nil
  }
  static func validate(_ pack: MissionPack, bundled: Bool) throws {
    try require(
      pack.schemaVersion == 1 && pack.minimumEngine == "1.0.0",
      "Unsupported schema or engine version.")
    try require(
      identifier(pack.id) && identifier(pack.mission.id) && version(pack.version),
      "Invalid stable ID/version.")
    try require((0...1000).contains(pack.priority), "Priority must be 0-1000.")
    try require(
      Set(pack.capabilities).isSubset(of: MissionPackLibrary.capabilities)
        && pack.capabilities.contains("state-machine-v1"), "Unsupported or missing capability.")
    try require(!pack.source.isEmpty && !pack.license.isEmpty, "Source and license are required.")
    try require(
      !pack.mission.title.isEmpty && pack.mission.title.count <= 32,
      "Mission title must be 1-32 characters.")
    try require(
      bundled || pack.mission.binding == nil, "Legacy bindings are reserved for bundled campaigns.")
    try require(
      pack.mission.binding == nil || ["naval", "blackjack"].contains(pack.mission.binding!),
      "Unknown legacy binding.")
    try require(
      bundled || pack.stages.allSatisfy { $0.legacyValues == nil && $0.legacyWrite == nil },
      "Legacy stage mappings are bundled-only.")
    try require(
      bundled || (pack.dialogs ?? []).allSatisfy { $0.ship != true },
      "Ship briefing displays are bundled-only.")
    try require(
      bundled || (pack.clues == nil && pack.encounters == nil),
      "External encounter/clue bindings are not supported yet.")
    try require(
      (1...64).contains(pack.stages.count) && (1...128).contains(pack.transitions.count)
        && (1...64).contains(pack.mission.milestones.count),
      "Too many or missing stages/transitions/milestones.")
    try validateStages(pack)
    for transition in pack.transitions { try validate(transition, pack: pack, bundled: bundled) }
    try validateBindings(pack)
  }
  private static func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw MissionPackError(message) }
  }
  private static func validateStages(_ pack: MissionPack) throws {
    let stages = Set(pack.stages.map(\.id))
    let dialogs = Set((pack.dialogs ?? []).map(\.id))
    try require(
      stages.count == pack.stages.count && stages.contains(pack.mission.initialStage)
        && pack.stages.allSatisfy {
          identifier($0.id) && (0...pack.mission.milestones.count).contains($0.completed)
        }, "Invalid/duplicate stage.")
    try require(
      dialogs.count == (pack.dialogs ?? []).count
        && (pack.dialogs ?? []).allSatisfy {
          identifier($0.id) && !$0.text.isEmpty && $0.text.count <= 12000
            && (0...10).contains($0.delaySeconds ?? 0)
        }, "Invalid/duplicate dialog.")
    try require(
      Set(pack.transitions.map(\.id)).count == pack.transitions.count, "Duplicate transition ID.")
  }
  private static func validate(_ transition: PackTransition, pack: MissionPack, bundled: Bool)
    throws
  {
    let stages = Set(pack.stages.map(\.id))
    let dialogs = Set((pack.dialogs ?? []).map(\.id))
    try require(
      identifier(transition.id) && stages.contains(transition.from)
        && stages.contains(transition.to), "Invalid transition reference: \(transition.id).")
    try require(
      transition.dialog == nil || dialogs.contains(transition.dialog!),
      "Unknown dialog: \(transition.id).")
    try require(
      transition.confirmation != true
        || (transition.dialog != nil && [.contact, .dock].contains(transition.event)),
      "Confirm requires a dock/contact dialog.")
    try require(
      (transition.conditions?.count ?? 0) <= 32 && (transition.actions?.count ?? 0) <= 32,
      "Transition exceeds 32 conditions/actions.")
    for condition in transition.conditions ?? [] { try validate(condition, bundled: bundled) }
    if (transition.conditions ?? []).contains(where: { $0.field == "stageSeconds" }) {
      try require(pack.capabilities.contains("clock-v1"), "stageSeconds requires clock-v1.")
    }
    for action in transition.actions ?? [] {
      try validate(action, bundled: bundled, capabilities: Set(pack.capabilities))
    }
    if transition.dialog != nil {
      try require(pack.capabilities.contains("dialog-v1"), "Declare dialog-v1.")
    }
    if transition.event == .clock {
      try require(pack.capabilities.contains("clock-v1"), "Declare clock-v1.")
    }
    if [.targetRemoved, .targetDestroyed].contains(transition.event) {
      try require(
        bundled,
        "External target events require encounter capabilities not implemented in schema 1.")
    }
  }
  private static func validateBindings(_ pack: MissionPack) throws {
    let stages = Set(pack.stages.map(\.id))
    for clue in pack.clues ?? [] {
      try require(
        (0..<8).contains(clue.galaxy) && !clue.texts.isEmpty && clue.texts.count <= 16
          && clue.systems.allSatisfy { (0..<256).contains($0) }, "Invalid clue.")
    }
    for encounter in pack.encounters ?? [] {
      try require(
        stages.contains(encounter.stage)
          && ["constrictor-hunt", "plans-ambush", "blackjack-target"].contains(encounter.kind)
          && (encounter.galaxy.map { (0..<8).contains($0) } ?? true)
          && (encounter.system.map { (0..<256).contains($0) } ?? true), "Invalid encounter binding."
      )
    }
  }

  static func validate(_ condition: PackCondition, bundled: Bool) throws {
    let numeric: Set<String> = [
      "galaxy", "system", "x", "y", "kills", "credits", "legal", "mainStation", "freeTonnes",
      "stageSeconds",
    ]
    let parts = condition.field.split(separator: ":", maxSplits: 1).map(String.init)
    let local =
      parts.count == 2
      && (["flag", "receipt", "payload"].contains(parts[0])
        ? localID(parts[1])
        : parts[0] == "cargo" && Int(parts[1]).map { (0..<17).contains($0) } == true)
    let target = condition.field == "target" && bundled
    guard ["eq", "ne", "lt", "le", "gt", "ge"].contains(condition.op),
      numeric.contains(condition.field) || local || target
        || (bundled && condition.field == "navalStage"),
      target
        ? condition.text != nil && ["eq", "ne"].contains(condition.op)
        : condition.value?.isFinite == true
    else { throw MissionPackError("Invalid condition: \(condition.field).") }
  }
  static func validate(_ action: PackAction, bundled: Bool, capabilities: Set<String>) throws {
    let economy: Set<String> = [
      "credits", "legalSet", "legalFloor", "equipmentAdd", "equipmentRemove",
    ]
    let cargo: Set<String> = ["cargoAdd", "cargoRemove", "payloadAdd", "payloadRemove"]
    let reserved: Set<String> = ["creditsWrapped", "killsWrapped", "cargoRewardOrPending"]
    guard
      economy.contains(action.kind) || cargo.contains(action.kind)
        || ["flagSet", "receipt"].contains(action.kind)
        || (bundled && reserved.contains(action.kind))
    else { throw MissionPackError("Unsupported action: \(action.kind).") }
    if economy.contains(action.kind) && !capabilities.contains("economy-v1") {
      throw MissionPackError("\(action.kind) requires economy-v1.")
    }
    if cargo.contains(action.kind) && !capabilities.contains("cargo-v1") {
      throw MissionPackError("\(action.kind) requires cargo-v1.")
    }
    if action.kind.hasPrefix("equipment") {
      guard let key = action.key, Equipment.validNames.contains(key) else {
        throw MissionPackError("Unknown equipment.")
      }
    } else if action.kind.hasPrefix("cargo") {
      guard let key = action.key, let index = Int(key), (0..<17).contains(index),
        (1...1_000_000).contains(action.amount ?? 0)
      else { throw MissionPackError("Invalid cargo action.") }
    } else if ["payloadAdd", "payloadRemove", "flagSet", "receipt"].contains(action.kind) {
      guard localID(action.key ?? ""), (0...1_000_000).contains(action.amount ?? 0) else {
        throw MissionPackError("Invalid local action key/amount.")
      }
    } else {
      guard (0...4_294_967_295).contains(action.amount ?? -1) else {
        throw MissionPackError("Invalid action amount.")
      }
    }
  }
}
