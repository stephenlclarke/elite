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
  fileprivate func matches(_ state: CampaignMemberValidationValues) -> Bool {
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
  fileprivate func valid(
    parent state: CampaignMemberValidationValues, child member: CampaignMemberValidationValues,
    engine: CampaignEngineValidationValues
  ) -> Bool {
    let parentDepth = state.campaignDepth ?? 0
    guard (0...3).contains(parentDepth) else { return false }
    return parent == state.id && child == member.id && parent != child && definition.valid
      && definition.matches(member) && (1...4).contains(depth)
      && depth == parentDepth + 1
      && root == (state.campaignRoot ?? state.id)
      && engine.rootHasNoCampaignParent(root) && engine.containsInstance(root)
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

/// Fresh immutable projections, never encoded, cached or accepted as external authority.
private final class CampaignMemberValidationValues: Sendable {
  let id: UUID
  let definition: String
  let version: String
  let digest: String
  let campaignParent: ScriptChildBinding?
  let campaignDepth: Int?
  let campaignRoot: UUID?
  let campaignChildren: [String: ScriptChildBinding]
  let savedCampaignReceiptScopes: [String: String]?
  let receiptJoins: [String: [UUID]]?
  let revision: UInt64
  let acknowledgedThrough: UInt64?
  let acknowledgedEvents: Set<UInt64>

  init(_ state: borrowing ScriptInstance) {
    id = state.id
    definition = state.definition
    version = state.version
    digest = state.digest
    campaignParent = state.campaignParent
    campaignDepth = state.campaignParent?.depth
    campaignRoot = state.campaignParent?.root
    campaignChildren = state.campaignChildren
    savedCampaignReceiptScopes = state.savedCampaignReceiptScopes
    receiptJoins = state.receiptJoins
    revision = state.revision
    acknowledgedThrough = state.acknowledgedThrough
    acknowledgedEvents = state.acknowledgedEvents
  }

  func hasAcknowledged(_ sequence: UInt64) -> Bool {
    sequence <= (acknowledgedThrough ?? 0) || acknowledgedEvents.contains(sequence)
  }
}

private struct CampaignEngineValidationValues: Sendable {
  let instances: [UUID: ScriptInstance]
  let nextEvent: UInt64
  let localSeconds: Double
  let flightSeconds: Double
  let calendarSeconds: Double
  let transitSeconds: Double

  init(_ state: borrowing ScriptEngineState) {
    instances = state.instances
    nextEvent = state.nextEvent
    localSeconds = state.localSeconds
    flightSeconds = state.flightSeconds
    calendarSeconds = state.calendarSeconds
    transitSeconds = state.transitSeconds
  }

  @inline(never)
  func member(at index: [UUID: ScriptInstance].Index) -> CampaignMemberValidationValues {
    CampaignMemberValidationValues(instances[index].value)
  }

  @inline(never)
  private func member(_ id: UUID) -> CampaignMemberValidationValues? {
    guard let state = instances[id] else { return nil }
    return CampaignMemberValidationValues(state)
  }

  @inline(never)
  func rootHasNoCampaignParent(_ id: UUID) -> Bool {
    instances[id]?.campaignParent == nil
  }

  @inline(never)
  func containsInstance(_ id: UUID) -> Bool {
    instances[id] != nil
  }

  func valid(_ parent: CampaignMemberValidationValues, childIDs: inout Set<UUID>) -> Bool {
    guard Self.campaignReceiptScopesAreValid(parent),
      campaignChildBindingsAreValid(parent, childIDs: &childIDs),
      campaignParentBindingIsValid(parent)
    else { return false }
    return true
  }

  // The full original scope, child and owner checks share only campaign-specific inputs.
  @inline(never)
  private static func campaignReceiptScopesAreValid(_ parent: CampaignMemberValidationValues)
    -> Bool
  {
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
    _ parent: CampaignMemberValidationValues, childIDs: inout Set<UUID>
  ) -> Bool {
    for (alias, binding) in parent.campaignChildren {
      guard alias == binding.definition.id, let child = member(binding.child),
        child.campaignParent == binding,
        binding.valid(parent: parent, child: child, engine: self),
        childIDs.insert(child.id).inserted
      else { return false }
    }
    return true
  }

  @inline(never)
  private func campaignParentBindingIsValid(_ parent: CampaignMemberValidationValues) -> Bool {
    if let binding = parent.campaignParent {
      guard let owner = member(binding.parent),
        owner.campaignChildren[binding.definition.id] == binding
      else { return false }
    }
    return true
  }
}

extension ScriptEngineState {
  var campaignsValid: Bool {
    let engine = CampaignEngineValidationValues(self)
    var childIDs = Set<UUID>()
    // Dictionary indices and values traverse the same immutable element order.
    for index in engine.instances.indices {
      let parent = engine.member(at: index)
      guard engine.valid(parent, childIDs: &childIDs) else { return false }
    }
    return true
  }
}

/// Fresh scalar/relationship projection for synchronous ancestor walks.
struct CampaignReadMember {
  let key: UUID
  let id: UUID
  let definition: String
  let version: String
  let digest: String
  let campaignParent: ScriptChildBinding?

  init(_ state: borrowing ScriptInstance, key: UUID? = nil) {
    let id = state.id
    self.id = id
    self.key = key ?? id
    definition = state.definition
    version = state.version
    digest = state.digest
    campaignParent = state.campaignParent
  }
}

extension ScriptChildDefinition {
  func matches(_ state: CampaignReadMember) -> Bool {
    state.definition == definition && state.version == version && state.digest == digest
  }
}

private struct CampaignExecutionParent {
  let member: CampaignReadMember
  let pack: ScriptPack?
  let outcome: ScriptOutcome
}

extension Game {
  func campaignExecutionIssue(_ state: borrowing ScriptInstance) -> String? {
    var member = CampaignReadMember(state)
    var visited = Set<UUID>()
    while let binding = member.campaignParent {
      guard visited.insert(member.id).inserted, visited.count <= 4,
        let parent = campaignExecutionParent(binding)
      else { return "Restore the original parent campaign relationship." }
      guard let pack = parent.pack, scriptUnavailable(pack) == nil else {
        return "Restore the exact owning campaign content and its requirements."
      }
      if binding.definition.terminalPolicy == .suspend && parent.outcome != .active {
        return "An owning campaign has ended; this child's actual property remains protected."
      }
      member = parent.member
    }
    return nil
  }
  @inline(never)
  func campaignReadMember(_ id: UUID) -> CampaignReadMember? {
    guard let state = commander.scriptState.instances[id] else { return nil }
    return CampaignReadMember(state, key: id)
  }

  // Release the full parent read before checking pack availability or walking the next ancestor.
  @inline(never)
  private func campaignExecutionParent(_ binding: ScriptChildBinding) -> CampaignExecutionParent? {
    guard let parent = commander.scriptState.instances[binding.parent],
      parent.campaignChildren[binding.definition.id] == binding
    else { return nil }
    return .init(
      member: CampaignReadMember(parent, key: binding.parent), pack: scriptPack(for: parent),
      outcome: parent.outcome)
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
