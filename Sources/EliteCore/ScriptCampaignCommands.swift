import Foundation

extension Game {
  mutating func ensureCampaignChild(
    _ command: ScriptValue, pack: ScriptPack, state: inout ScriptInstance, event: ScriptEvent
  ) throws -> (String, [String: ScriptValue])? {
    guard command.object.map({ Set($0.keys) == ["op", "id"] }) == true,
      let id = command["id"]?.string, state.outcome == .active,
      pack.manifest.capabilities.contains("scoped-campaigns-basic-v2"),
      let definition = pack.manifest.children?.first(where: { $0.id == id })
    else { throw MissionPackError("Campaign children require their declared active parent.") }
    if let binding = state.campaignChildren[id] {
      guard binding.definition == definition,
        let child = commander.scriptState.instances[binding.child],
        child.campaignParent == binding, definition.matches(child)
      else { throw MissionPackError("Restore the original campaign child; migration is explicit.") }
      return nil
    }
    guard state.campaignChildren.count < 32, (state.campaignParent?.depth ?? 0) < 4,
      commander.scriptState.instances.count < 128,
      commander.scriptState.pendingEvents.count < 4096,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      let childPack = scriptPacks.first(where: {
        $0.manifest.stateID == definition.definition && $0.manifest.version == definition.version
          && $0.digest == definition.digest
      }), childPack.manifest.board == nil, scriptUnavailable(childPack) == nil,
      let cause = event.context
    else {
      throw MissionPackError(
        "The exact child content, campaign depth or native capacity is unavailable.")
    }
    let key =
      "campaign-child-instance-v1\u{0}" + state.id.uuidString + "\u{0}" + id + "\u{0}"
      + childPack.digest
    let childID = ScriptIdentity.uuid(key)
    guard commander.scriptState.instances[childID] == nil else {
      throw MissionPackError("A different child already owns this stable campaign identity.")
    }
    var projected = state
    projected.revision += 1
    let binding = ScriptChildBinding(
      parent: state.id,
      root: state.campaignParent?.root ?? state.id, child: childID,
      depth: (state.campaignParent?.depth ?? 0) + 1, definition: definition,
      sequence: event.sequence, revision: projected.revision, causeKind: event.kind,
      cause: cause, committed: scriptEventContext(projected))
    let seed = UInt64(ScriptPackLibrary.hash(Data((key + "\u{0}seed").utf8)).prefix(16), radix: 16)!
    state.campaignChildren[id] = binding
    // The entire parent proposal remains private. Its native child event cannot execute before publication.
    commander.scriptState.instances[state.id] = state
    _ = try acceptScriptMission(
      childPack, instanceID: childID, randomSeed: seed,
      campaignParent: binding, drainAccepted: false)
    return (
      "campaign.child.started", ["child": .string(id), "instance": .string(childID.uuidString)]
    )
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
