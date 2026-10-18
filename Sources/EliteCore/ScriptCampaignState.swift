import Foundation

public enum ScriptChildTerminalPolicy: String, Codable, Sendable { case suspend, preserve }
public struct ScriptChildDefinition: Codable, Sendable, Equatable {
  public let id: String
  public let definition: String
  public let version: String
  public let digest: String
  public let terminalPolicy: ScriptChildTerminalPolicy
  var valid: Bool {
    let parts = definition.split(separator: "/", omittingEmptySubsequences: false)
    return PackValidation.localID(id) && parts.count == 2
      && PackValidation.identifier(String(parts[0])) && PackValidation.localID(String(parts[1]))
      && PackValidation.version(version) && ScriptCompletionReceipt.validDigest(digest)
  }
  func matches(_ state: ScriptInstance) -> Bool {
    state.definition == definition && state.version == version && state.digest == digest
  }
}

/// Native authorization to create this child, retained by both ends of the relationship.
public struct ScriptChildBinding: Codable, Sendable, Equatable {
  public let parent: UUID
  public let root: UUID
  public let child: UUID
  public let depth: Int
  public let definition: ScriptChildDefinition
  public let sequence: UInt64
  public let revision: UInt64
  public let causeKind: String
  public let cause: ScriptEventContext
  public let committed: ScriptEventContext
  func valid(parent state: ScriptInstance, child member: ScriptInstance, engine: ScriptEngineState)
    -> Bool
  {
    let parentDepth = state.campaignParent?.depth ?? 0
    guard (0...3).contains(parentDepth) else { return false }
    return parent == state.id && child == member.id && parent != child && definition.valid
      && definition.matches(member) && (1...4).contains(depth)
      && depth == parentDepth + 1
      && root == (state.campaignParent?.root ?? state.id)
      && engine.instances[root]?.campaignParent == nil && engine.instances[root] != nil
      && sequence > 0 && sequence <= engine.nextEvent && state.hasAcknowledged(sequence)
      && revision > 0 && revision <= state.revision && committed.revision == revision
      && ScriptCapabilities.events.contains(causeKind) && cause.valid && committed.valid
      && cause.revision < revision && cause.localSeconds <= committed.localSeconds
      && cause.flightSeconds <= committed.flightSeconds
      && cause.calendarSeconds <= committed.calendarSeconds
      && cause.transitSeconds <= committed.transitSeconds
      && committed.localSeconds <= engine.localSeconds
      && committed.flightSeconds <= engine.flightSeconds
      && committed.calendarSeconds <= engine.calendarSeconds
      && committed.transitSeconds <= engine.transitSeconds
  }
}

extension ScriptInstance {
  public var campaignChildren: [String: ScriptChildBinding] {
    get { savedCampaignChildren ?? [:] }
    set { savedCampaignChildren = newValue.isEmpty ? nil : newValue }
  }
}

extension ScriptEngineState {
  var campaignsValid: Bool {
    var childIDs = Set<UUID>()
    for parent in instances.values {
      guard Self.campaignReceiptScopesAreValid(parent),
        campaignChildBindingsAreValid(parent, childIDs: &childIDs),
        campaignParentBindingIsValid(parent)
      else { return false }
    }
    return true
  }

  // Scope closure captures finish before child/owner lookup storage becomes active.
  @inline(never)
  private static func campaignReceiptScopesAreValid(_ parent: ScriptInstance) -> Bool {
    let scopes = parent.savedCampaignReceiptScopes ?? [:]
    guard parent.campaignChildren.count <= 32, scopes.count <= 32,
      scopes.allSatisfy({ PackValidation.localID($0.key) && PackValidation.localID($0.value) }),
      scopes.allSatisfy({ key, alias in
        guard let joins = parent.receiptJoins?[key] else { return true }
        return parent.campaignChildren[alias].map { joins == [$0.child] } ?? false
      })
    else { return false }
    return true
  }

  @inline(never)
  private func campaignChildBindingsAreValid(
    _ parent: ScriptInstance, childIDs: inout Set<UUID>
  ) -> Bool {
    for (alias, binding) in parent.campaignChildren {
      guard alias == binding.definition.id, let child = instances[binding.child],
        child.campaignParent == binding,
        binding.valid(parent: parent, child: child, engine: self),
        childIDs.insert(child.id).inserted
      else { return false }
    }
    return true
  }

  @inline(never)
  private func campaignParentBindingIsValid(_ parent: ScriptInstance) -> Bool {
    if let binding = parent.campaignParent {
      guard let owner = instances[binding.parent],
        owner.campaignChildren[binding.definition.id] == binding
      else { return false }
    }
    return true
  }
}

extension Game {
  func campaignExecutionIssue(_ state: ScriptInstance) -> String? {
    var member = state
    var visited = Set<UUID>()
    while let binding = member.campaignParent {
      guard visited.insert(member.id).inserted, visited.count <= 4,
        let parent = commander.scriptState.instances[binding.parent],
        parent.campaignChildren[binding.definition.id] == binding
      else { return "Restore the original parent campaign relationship." }
      guard let pack = scriptPack(for: parent), scriptUnavailable(pack) == nil else {
        return "Restore the exact owning campaign content and its requirements."
      }
      if binding.definition.terminalPolicy == .suspend && parent.outcome != .active {
        return "An owning campaign has ended; this child's actual property remains protected."
      }
      member = parent
    }
    return nil
  }
  func campaignContentIssue(_ state: ScriptInstance, pack: ScriptPack) -> String? {
    let scopes = Dictionary(
      uniqueKeysWithValues: (pack.manifest.receiptRequirements ?? []).compactMap { requirement in
        requirement.child.map { (requirement.id, $0) }
      })
    guard scopes == (state.savedCampaignReceiptScopes ?? [:]),
      state.campaignChildren.allSatisfy({ alias, binding in
        pack.manifest.children?.first(where: { $0.id == alias }) == binding.definition
      })
    else { return "Restore the original declared campaign children and receipt scopes." }
    return nil
  }
  func campaignGallerySummary(_ state: ScriptInstance?) -> String {
    guard let state else { return "" }
    var lines: [String] = []
    if let binding = state.campaignParent {
      let parent = commander.scriptState.instances[binding.parent].flatMap { scriptPack(for: $0) }
      lines.append(
        "Owning campaign: "
          + (parent?.manifest.mission.title ?? "Saved campaign (content unavailable)"))
    }
    if !state.campaignChildren.isEmpty {
      lines.append("Campaign assignments:")
      for alias in state.campaignChildren.keys.sorted() {
        let binding = state.campaignChildren[alias]!
        let child = commander.scriptState.instances[binding.child]
        let title =
          child.flatMap { scriptPack(for: $0)?.manifest.mission.title }
          ?? "Saved assignment (content unavailable)"
        let status =
          child.map { $0.suspension == nil ? $0.outcome.rawValue.capitalized : "Suspended" }
          ?? "Unavailable"
        lines.append(title + ": " + status)
      }
    }
    return lines.isEmpty ? "" : "\n\n" + lines.joined(separator: "\n")
  }
  func campaignChildrenQuery(_ state: ScriptInstance) -> ScriptValue {
    .object(
      state.campaignChildren.mapValues { binding in
        let child = commander.scriptState.instances[binding.child]
        return .object([
          "instance": .string(binding.child.uuidString), "root": .string(binding.root.uuidString),
          "definition": .string(binding.definition.definition),
          "version": .string(binding.definition.version),
          "digest": .string(binding.definition.digest),
          "outcome": child.map { .string($0.outcome.rawValue) } ?? .null,
          "suspension": child?.suspension.map(ScriptValue.string) ?? .null,
          "receipted": .bool(child?.completionReceipt != nil),
        ])
      })
  }
}

extension ScriptPackLibrary {
  static func validateCampaignChildren(_ manifest: ScriptManifest) throws {
    let children = manifest.children ?? []
    let ids = Set(children.map(\.id))
    guard children.count <= 32, ids.count == children.count, children.allSatisfy(\.valid),
      children.isEmpty || manifest.capabilities.contains("scoped-campaigns-basic-v2"),
      manifest.mission.parentOnly != true
        || (manifest.capabilities.contains("scoped-campaigns-basic-v2") && manifest.board == nil),
      !manifest.handlers.contains(where: { $0.event == "campaign.child.started" })
        || manifest.capabilities.contains("scoped-campaigns-basic-v2"),
      (manifest.receiptRequirements ?? []).allSatisfy({ requirement in
        guard let alias = requirement.child else { return true }
        guard manifest.capabilities.contains("scoped-campaigns-basic-v2"),
          requirement.stage == .completion, requirement.minimumCount == 1,
          let child = children.first(where: { $0.id == alias })
        else { return false }
        return child.definition == requirement.definition && child.version == requirement.version
          && child.digest == requirement.digest
      })
    else { throw MissionPackError("Invalid or unsupported scoped campaign child declarations.") }
  }
}
