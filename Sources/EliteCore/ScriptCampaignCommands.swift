import Foundation

private final class ScriptCampaignChildPlan: Sendable {
  let id: String
  let pack: ScriptPack
  let binding: ScriptChildBinding
  let seed: UInt64
  init(id: String, pack: ScriptPack, binding: ScriptChildBinding, seed: UInt64) {
    self.id = id
    self.pack = pack
    self.binding = binding
    self.seed = seed
  }
}

private final class ScriptCampaignChildInputs: Sendable {
  let id: String
  let pack: ScriptPack
  let definition: ScriptChildDefinition
  let key: String
  let childID: UUID
  let parent: UUID
  let root: UUID
  let depth: Int
  let sequence: UInt64
  let revision: UInt64
  let causeKind: String
  let cause: ScriptEventContext

  init(
    id: String, pack: ScriptPack, definition: ScriptChildDefinition, key: String, childID: UUID,
    parent: UUID, root: UUID, depth: Int, sequence: UInt64, revision: UInt64,
    causeKind: String, cause: ScriptEventContext
  ) {
    self.id = id
    self.pack = pack
    self.definition = definition
    self.key = key
    self.childID = childID
    self.parent = parent
    self.root = root
    self.depth = depth
    self.sequence = sequence
    self.revision = revision
    self.causeKind = causeKind
    self.cause = cause
  }
}

extension Game {
  mutating func ensureCampaignChild(
    _ command: ScriptValue, pack: ScriptPack, state: inout ScriptInstance, event: ScriptEvent
  ) throws -> (String, [String: ScriptValue])? {
    guard
      let plan = try Self.prepareCampaignChild(
        self, command: command, pack: pack, state: state, event: event)
    else {
      return nil
    }
    return try installCampaignChild(plan, state: &state)
  }

  @inline(never)
  private mutating func installCampaignChild(
    _ plan: ScriptCampaignChildPlan, state: inout ScriptInstance
  ) throws -> (String, [String: ScriptValue])? {
    state.campaignChildren[plan.id] = plan.binding
    // The entire parent proposal remains private. Its native child event cannot execute before publication.
    commander.scriptState.instances[state.id] = state
    _ = try acceptScriptMission(
      plan.pack, instanceID: plan.binding.child, randomSeed: plan.seed,
      campaignParent: plan.binding, drainAccepted: false)
    return (
      "campaign.child.started",
      ["child": .string(plan.id), "instance": .string(plan.binding.child.uuidString)]
    )
  }
  @inline(never)
  private static func prepareCampaignChild(
    _ game: borrowing Game, command: ScriptValue, pack: ScriptPack,
    state: borrowing ScriptInstance, event: ScriptEvent
  ) throws -> ScriptCampaignChildPlan? {
    guard
      let inputs = try campaignChildInputs(
        game, command: command, pack: pack, state: state, event: event)
    else { return nil }
    let committed = scriptEventContext(in: game, revision: inputs.revision)
    return finishCampaignChildPlan(inputs, committed: committed)
  }

  /// Return only validated plan fields before any anchor/context snapshot frame starts.
  @inline(never)
  private static func campaignChildInputs(
    _ game: borrowing Game, command: ScriptValue, pack: ScriptPack,
    state: borrowing ScriptInstance, event: ScriptEvent
  ) throws -> ScriptCampaignChildInputs? {
    guard command.object.map({ Set($0.keys) == ["op", "id"] }) == true,
      let id = command["id"]?.string, state.outcome == .active,
      pack.manifest.capabilities.contains("scoped-campaigns-basic-v2"),
      let definition = pack.manifest.children?.first(where: { $0.id == id })
    else { throw MissionPackError("Campaign children require their declared active parent.") }
    if let binding = state.campaignChildren[id] {
      guard binding.definition == definition,
        let child = game.commander.scriptState.instances[binding.child],
        child.campaignParent == binding, definition.matches(child)
      else { throw MissionPackError("Restore the original campaign child; migration is explicit.") }
      return nil
    }
    guard state.campaignChildren.count < 32, (state.campaignParent?.depth ?? 0) < 4,
      game.commander.scriptState.instances.count < 128,
      game.commander.scriptState.pendingEvents.count < 4096,
      game.commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      let childPack = game.scriptPacks.first(where: {
        $0.manifest.stateID == definition.definition && $0.manifest.version == definition.version
          && $0.digest == definition.digest
      }), childPack.manifest.board == nil, game.scriptUnavailable(childPack) == nil,
      let cause = event.context
    else {
      throw MissionPackError(
        "The exact child content, campaign depth or native capacity is unavailable.")
    }
    let key =
      "campaign-child-instance-v1\u{0}" + state.id.uuidString + "\u{0}" + id + "\u{0}"
      + childPack.digest
    let childID = ScriptIdentity.uuid(key)
    guard game.commander.scriptState.instances[childID] == nil else {
      throw MissionPackError("A different child already owns this stable campaign identity.")
    }
    let revision = state.revision + 1
    let parent = state.id
    return .init(
      id: id, pack: childPack, definition: definition, key: key, childID: childID,
      parent: parent, root: state.campaignParent?.root ?? parent,
      depth: (state.campaignParent?.depth ?? 0) + 1, sequence: event.sequence, revision: revision,
      causeKind: event.kind, cause: cause)
  }

  @inline(never)
  private static func finishCampaignChildPlan(
    _ inputs: ScriptCampaignChildInputs, committed: ScriptEventContext
  ) -> ScriptCampaignChildPlan {
    let binding = ScriptChildBinding(
      parent: inputs.parent, root: inputs.root, child: inputs.childID,
      depth: inputs.depth, definition: inputs.definition,
      sequence: inputs.sequence, revision: inputs.revision, causeKind: inputs.causeKind,
      cause: inputs.cause, committed: committed)
    let seed = UInt64(
      ScriptPackLibrary.hash(Data((inputs.key + "\u{0}seed").utf8)).prefix(16), radix: 16)!
    return .init(id: inputs.id, pack: inputs.pack, binding: binding, seed: seed)
  }
  mutating func suspendTerminalCampaignChildren(_ parent: ScriptInstance) {
    guard parent.outcome != .active else { return }
    // Call after the terminal parent revision/receipt is installed in the private candidate.
    for child in commander.scriptState.instances.values where child.outcome == .active {
      if let reason = campaignExecutionIssue(child) {
        commander.scriptState.instances[child.id]?.suspension = reason
      }
    }
  }
}
