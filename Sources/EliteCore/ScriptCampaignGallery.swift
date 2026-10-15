import Foundation

public struct CampaignGalleryAssignment: Sendable {
  public let alias: String
  public let title: String
  public let status: String
  public let objective: String
  public let unavailableReason: String?
  public let instance: UUID?
  let definition: ScriptChildDefinition
}

public enum ScriptGalleryPageKind: String, Codable, Sendable, Equatable {
  case list, detail, links, review
}

/// Compact proof of the exact painted controls, independent of focus within one visible review.
public struct ScriptGalleryPageIdentity: Codable, Sendable, Equatable {
  public let generation: UUID
  public let mode: ScriptGalleryPageKind
  public let entry: String
  public let targets: String
  public let layout: String
  var valid: Bool {
    [entry, targets, layout].allSatisfy(ScriptCompletionReceipt.validDigest)
  }
  var allowedKeys: Set<String> {
    if mode == .review { return ScriptPagePresentation.controlKeys.union(["l"]) }
    var keys = ScriptPagePresentation.controlKeys.union(["tab", "l", "t", "gallery-trial"])
    if mode != .links { keys.formUnion(["r", "mission-resume"]) }
    return keys
  }
}

extension Display {
  static func campaignGalleryDetail(
    _ frame: inout Frame, game: Game, layout: GalleryLayout, x: Double, width: Double
  ) -> Bool {
    let columns = max(10, Int(min(700, width) / (6 * layout.font)))
    if let review = game.gallery.campaignReview {
      let text = [
        "Try campaign", game.campaignTitle(review.root), "",
        "This assignment starts through its campaign.",
        "Start a fresh isolated root campaign, including its owned assignments.",
        "Trial - live commander unchanged",
        "The live campaign's progress, commander, calendar and save remain unchanged.",
        game.campaignTrialUnavailableReason
          ?? "Choose Try campaign to start, or Back to keep browsing.",
      ].flatMap { MissionNotice.wrap($0, width: columns) }
      let visible = max(1, Int((layout.contentBottom - layout.listTop) / layout.row))
      for (index, line) in text.prefix(visible).enumerated() {
        frame.label(line, x, layout.listTop + Double(index) * layout.row, scale: layout.font)
      }
      frame.label(
        game.gallery.campaignStartSelected ? "  Back" : "> Back", x, layout.actionTop,
        scale: layout.font, ink: .cyan)
      frame.label(
        game.gallery.campaignStartSelected ? "> Try campaign" : "  Try campaign",
        x + width / 2, layout.actionTop, scale: layout.font, ink: .cyan)
      return true
    }
    guard game.gallery.campaignLinks else { return false }
    let links = game.campaignGalleryLinks
    let first = max(0, game.gallery.campaignLinkSelection - layout.visibleLinks + 1)
    for (index, link) in links.enumerated().dropFirst(first).prefix(layout.visibleLinks) {
      let y = layout.listTop + Double(index - first) * layout.linkHeight
      let selected = index == game.gallery.campaignLinkSelection
      let title = MissionNotice.wrap((selected ? "> " : "  ") + link.title, width: columns)
      let detail = MissionNotice.wrap(link.detail, width: columns)
      for (row, line) in Array(title.prefix(2)).enumerated() {
        frame.label(
          line, x, y + Double(row) * layout.row, scale: layout.font,
          ink: selected ? .cyan : .yellow)
      }
      for (row, line) in Array(detail.prefix(2)).enumerated() {
        frame.label(line, x, y + Double(row + 2) * layout.row, scale: layout.font)
      }
    }
    frame.label(
      "Links \(min(first + 1, links.count))-\(min(first + layout.visibleLinks, links.count)) of \(links.count)",
      x, layout.actionTop, scale: layout.font, ink: .yellow)
    return true
  }
}

struct CampaignGalleryLocation: Sendable {
  let selection: Int
  let instance: UUID?
  let scroll: Int
  let links: Bool
  let linkSelection: Int
  let preview: GalleryMission?
  let previewOwner: UUID?
  let previewIdentity: String?
}

struct CampaignGallerySelection: Sendable {
  let instance: UUID?
  let digest: String?
  func matches(_ mission: GalleryMission) -> Bool {
    if let instance { return mission.savedInstance == instance }
    return mission.savedInstance == nil && mission.trialDigest == digest
  }
}

struct CampaignGalleryTrialReview: Sendable, Equatable {
  let source: UUID
  let root: UUID
  let digest: String
  let epoch: UUID
}

enum CampaignGalleryAction: Sendable {
  case assignment(CampaignGalleryAssignment)
  case owner(UUID)
  case trial
}

struct CampaignGalleryLink: Sendable {
  let title: String
  let detail: String
  let action: CampaignGalleryAction
}

extension Game {
  func galleryIdentityDigest(_ fields: [String]) -> String {
    // Length prefixes avoid ambiguous identities even when authored text contains separators.
    ScriptPackLibrary.hash(Data(fields.map { "\($0.utf8.count):\($0)" }.joined().utf8))
  }

  func galleryEntryIdentity(_ mission: GalleryMission, index: Int) -> String {
    if let id = mission.savedInstance, let state = commander.scriptState.instances[id] {
      return galleryIdentityDigest([
        "saved", id.uuidString, state.definition, state.version, state.digest,
      ])
    }
    if let digest = mission.trialDigest { return galleryIdentityDigest(["template", digest]) }
    return galleryIdentityDigest([
      "catalogue", String(index), mission.name, mission.briefing, mission.destination,
      mission.reward,
    ])
  }

  var gallerySelectedEntryIdentity: String {
    if let preview = gallery.campaignPreviewIdentity { return preview }
    guard let mission = selectedGalleryMission else {
      return galleryIdentityDigest(["unavailable"])
    }
    return galleryEntryIdentity(mission, index: resolvedGallerySelection)
  }

  var scriptGalleryPageIdentity: ScriptGalleryPageIdentity {
    let layout = GalleryLayout(width: viewportWidth, height: viewportHeight)
    let mode: ScriptGalleryPageKind =
      gallery.campaignReview != nil
      ? .review
      : gallery.campaignLinks ? .links : gallery.detail ? .detail : .list
    let listFirst = galleryListWindow.offset
    let linkFirst = max(0, gallery.campaignLinkSelection - layout.visibleLinks + 1)
    let geometry = galleryIdentityDigest([
      String(viewportWidth), String(viewportHeight), String(gallery.scroll), String(listFirst),
      String(linkFirst), String(layout.divider), String(layout.actionTop), String(layout.listTop),
      String(layout.linkHeight), String(layout.itemHeight), String(layout.row),
    ])
    return .init(
      generation: gallery.presentationGeneration, mode: mode, entry: gallerySelectedEntryIdentity,
      targets: galleryControlTargets(mode: mode, listFirst: listFirst, linkFirst: linkFirst),
      layout: geometry)
  }

  private func galleryControlTargets(mode: ScriptGalleryPageKind, listFirst: Int, linkFirst: Int)
    -> String
  {
    let state = selectedCampaignState
    var fields = [
      String(canTrialSelectedMission), String(campaignTrialReview != nil),
      campaignTrialUnavailableReason ?? "", String(canRetrySelectedMission),
      state.map { String($0.revision) } ?? "", state?.outcome.rawValue ?? "",
      state?.suspension ?? "", state.map { worldJobGallerySummary(origin: $0.id) } ?? "",
      campaignImmediateOwner?.uuidString ?? "", gallery.campaignPreviewIdentity ?? "",
    ]
    if let review = gallery.campaignReview {
      fields += [review.source.uuidString, review.root.uuidString, review.digest]
    }
    let layout = GalleryLayout(width: viewportWidth, height: viewportHeight)
    if mode == .list || layout.wide {
      let visible = galleryListWindow.visible
      for (index, mission) in missionCatalogue.enumerated().dropFirst(listFirst).prefix(visible) {
        fields += [
          galleryEntryIdentity(mission, index: index), mission.status.rawValue, mission.objective,
        ]
      }
    }
    let links = campaignGalleryLinks
    let visibleLinks =
      mode == .links
      ? Array(links.dropFirst(linkFirst).prefix(layout.visibleLinks)) : links
    for link in visibleLinks {
      fields += [link.title, link.detail]
      switch link.action {
      case .owner(let id): fields += ["owner", id.uuidString]
      case .trial: fields.append("trial")
      case .assignment(let assignment):
        fields += [
          assignment.alias, assignment.instance?.uuidString ?? "", assignment.definition.definition,
          assignment.definition.version, assignment.definition.digest,
          assignment.definition.terminalPolicy.rawValue, assignment.unavailableReason ?? "",
        ]
      }
    }
    return galleryIdentityDigest(fields)
  }

  mutating func finishGalleryNavigation(from previous: ScriptGalleryPageIdentity) {
    pinGallerySelection()
    if previous != scriptGalleryPageIdentity { gallery.presentationGeneration = UUID() }
  }

  var resolvedGallerySelection: Int {
    guard let pinned = gallery.campaignSelection else { return gallery.selection }
    return missionCatalogue.firstIndex(where: { pinned.matches($0) }) ?? gallery.selection
  }

  mutating func pinGallerySelection() {
    // Keep the actual saved entry stable when missing content moves catalogue rows.
    guard gallery.campaignSelection == nil else { return }
    let missions = missionCatalogue
    guard missions.indices.contains(gallery.selection) else { return }
    let mission = missions[gallery.selection]
    if mission.savedInstance != nil || mission.trialDigest != nil {
      gallery.campaignSelection = .init(
        instance: mission.savedInstance, digest: mission.trialDigest)
    }
  }

  var selectedCampaignState: ScriptInstance? {
    selectedGalleryMission?.savedInstance.flatMap { commander.scriptState.instances[$0] }
  }

  /// Declarations and inverse bindings are queried without accepting or ensuring a child.
  public var selectedCampaignAssignments: [CampaignGalleryAssignment] {
    let state = selectedCampaignState
    let pack =
      state.flatMap { scriptPack(for: $0) }
      ?? selectedGalleryMission?.trialDigest.flatMap { digest in
        scriptPacks.first { $0.digest == digest }
      }
    let declarations = pack?.manifest.children ?? []
    let aliases = Set(declarations.map(\.id)).union(state?.campaignChildren.keys.map { $0 } ?? [])
    return aliases.sorted().compactMap { alias in
      guard
        let definition = declarations.first(where: { $0.id == alias })
          ?? state?.campaignChildren[alias]?.definition
      else { return nil }
      let binding = state?.campaignChildren[alias]
      let child = binding.flatMap { commander.scriptState.instances[$0.child] }
      let content = scriptPacks.first {
        $0.manifest.stateID == definition.definition && $0.manifest.version == definition.version
          && $0.digest == definition.digest
      }
      let reason: String?
      if content == nil {
        reason = "Restore the exact assignment content."
      } else if let child {
        reason =
          child.suspension ?? campaignExecutionIssue(child)
          ?? content.flatMap { scriptUnavailable($0) }
      } else {
        reason = "This assignment starts through its campaign."
      }
      let status: String
      if let child {
        // Terminal outcomes remain truthful even when their content is unavailable.
        status =
          child.outcome == .active && reason != nil
          ? "Suspended" : child.outcome.rawValue.capitalized
      } else {
        status = "Not started"
      }
      return CampaignGalleryAssignment(
        alias: alias,
        title: content?.manifest.mission.title
          ?? alias.replacingOccurrences(of: "-", with: " ").capitalized + " (content unavailable)",
        status: status,
        objective: child?.journal.last ?? content?.manifest.mission.briefing
          ?? "Saved assignment content is unavailable; its state remains intact.",
        unavailableReason: reason, instance: child?.id, definition: definition)
    }
  }

  var campaignImmediateOwner: UUID? {
    gallery.campaignPreviewOwner ?? selectedCampaignState?.campaignParent?.parent
  }

  func campaignTitle(_ id: UUID) -> String {
    commander.scriptState.instances[id].flatMap { scriptPack(for: $0)?.manifest.mission.title }
      ?? "Saved campaign (content unavailable)"
  }

  var campaignRelationshipLines: [String] {
    var lines: [String] = []
    if gallery.campaignPreview != nil { lines += ["Assignment status: Not started", ""] }
    if let owner = campaignImmediateOwner {
      lines += [
        "Part of " + campaignTitle(owner), "This assignment starts through its campaign.", "",
      ]
      if let state = selectedCampaignState {
        let reason = state.suspension ?? campaignExecutionIssue(state)
        let status =
          state.outcome == .active && reason != nil
          ? "Suspended" : state.outcome.rawValue.capitalized
        lines.append("Assignment status: " + status)
        if let reason { lines.append(reason) }
        lines.append("")
      }
    }
    let assignments = selectedCampaignAssignments
    if !assignments.isEmpty {
      lines += ["Assignments"]
      for assignment in assignments {
        lines += [assignment.title + ": " + assignment.status, assignment.objective]
        if let reason = assignment.unavailableReason { lines.append(reason) }
        lines.append("")
      }
    }
    if campaignImmediateOwner != nil, let reason = campaignTrialUnavailableReason {
      lines += ["Try campaign unavailable: " + reason, ""]
    }
    return lines
  }

  var campaignGalleryLinks: [CampaignGalleryLink] {
    var links: [CampaignGalleryLink] = []
    if let owner = campaignImmediateOwner {
      links.append(
        .init(title: "View campaign", detail: campaignTitle(owner), action: .owner(owner)))
    }
    links += selectedCampaignAssignments.map {
      .init(title: $0.title + " - " + $0.status, detail: $0.objective, action: .assignment($0))
    }
    if campaignImmediateOwner != nil {
      links.append(
        .init(
          title: "Try campaign",
          detail: campaignTrialUnavailableReason
            ?? "Review the owning root campaign's isolated trial.",
          action: .trial))
    }
    return links
  }

  var campaignTrialRoot: ScriptInstance? {
    guard
      var member = gallery.campaignPreviewOwner.flatMap({ commander.scriptState.instances[$0] })
        ?? selectedCampaignState
    else { return nil }
    let expectedRoot = member.campaignParent?.root ?? member.id
    var visited = Set<UUID>()
    while let binding = member.campaignParent {
      guard visited.insert(member.id).inserted, visited.count <= 4,
        let parent = commander.scriptState.instances[binding.parent],
        parent.campaignChildren[binding.definition.id] == binding,
        binding.child == member.id, binding.definition.matches(member)
      else { return nil }
      member = parent
    }
    return member.id == expectedRoot ? member : nil
  }

  var campaignTrialUnavailableReason: String? {
    if isMissionTrial { return "Return to your commander before starting another trial." }
    guard let root = campaignTrialRoot else {
      return "Restore the original owning campaign relationship."
    }
    guard root.contract == nil else {
      return "Trials of saved contract assignments are not supported."
    }
    guard let pack = scriptPack(for: root) else {
      return "Restore the exact root campaign content."
    }
    guard pack.manifest.mission.parentOnly != true else {
      return "This content can only start through its owning campaign."
    }
    var isolated = self
    isolated.scriptDurabilityAvailable = true
    isolated.commander.scriptState = ScriptEngineState()
    return isolated.scriptUnavailable(pack) ?? isolated.scriptAcceptanceIssue(pack)
      ?? isolated.campaignTrialContentIssue(pack, depth: 0, visited: [])
  }

  private func campaignTrialContentIssue(_ pack: ScriptPack, depth: Int, visited: Set<String>)
    -> String?
  {
    guard depth <= 4, !visited.contains(pack.digest) else {
      return "The campaign assignment graph exceeds the supported trial depth."
    }
    let visited = visited.union([pack.digest])
    for definition in pack.manifest.children ?? [] {
      guard
        let child = scriptPacks.first(where: {
          $0.manifest.stateID == definition.definition && $0.manifest.version == definition.version
            && $0.digest == definition.digest
        })
      else { return "Restore the exact campaign assignment content." }
      if let reason = scriptUnavailable(child)
        ?? campaignTrialContentIssue(child, depth: depth + 1, visited: visited)
      {
        return reason
      }
    }
    return nil
  }

  var campaignTrialReview: CampaignGalleryTrialReview? {
    guard campaignImmediateOwner != nil, campaignTrialUnavailableReason == nil,
      let source = gallery.campaignPreviewOwner ?? selectedCampaignState?.id,
      let root = campaignTrialRoot, let pack = scriptPack(for: root)
    else { return nil }
    return .init(source: source, root: root.id, digest: pack.digest, epoch: ecmControl.epoch)
  }

  public var canReviewSelectedCampaignTrial: Bool {
    gallery.campaignReview == nil && campaignTrialReview != nil
  }

  public var selectedGalleryMissionIsOwnedAssignment: Bool { campaignImmediateOwner != nil }

  public var canRetrySelectedGalleryEntry: Bool {
    gallery.campaignReview == nil && !gallery.campaignLinks && canRetrySelectedMission
  }

  mutating func openCampaignTrialReview() {
    guard let review = campaignTrialReview else {
      notify(campaignTrialUnavailableReason ?? "This entry has no owning campaign trial.")
      return
    }
    gallery.campaignReview = review
    gallery.presentationGeneration = UUID()
    gallery.detail = true
    gallery.campaignStartSelected = false
    gallery.campaignTrialRequested = false
    gallery.scroll = 0
  }

  mutating func rememberCampaignGalleryLocation() {
    gallery.campaignHistory.append(
      .init(
        selection: resolvedGallerySelection, instance: selectedGalleryMission?.savedInstance,
        scroll: gallery.scroll, links: gallery.campaignLinks,
        linkSelection: gallery.campaignLinkSelection, preview: gallery.campaignPreview,
        previewOwner: gallery.campaignPreviewOwner, previewIdentity: gallery.campaignPreviewIdentity
      ))
    // A bounded presentation stack is independent of saved campaign depth.
    if gallery.campaignHistory.count > 32 { gallery.campaignHistory.removeFirst() }
  }

  mutating func openCampaignGalleryInstance(_ id: UUID) {
    guard let index = missionCatalogue.firstIndex(where: { $0.savedInstance == id }) else {
      notify("The exact saved campaign entry is unavailable.")
      return
    }
    rememberCampaignGalleryLocation()
    gallery.selection = index
    gallery.detail = true
    gallery.scroll = 0
    gallery.campaignLinks = false
    gallery.campaignPreview = nil
    gallery.campaignPreviewOwner = nil
    gallery.campaignPreviewIdentity = nil
  }

  mutating func followCampaignGalleryLink(_ index: Int) {
    let links = campaignGalleryLinks
    guard links.indices.contains(index) else { return }
    switch links[index].action {
    case .owner(let id): openCampaignGalleryInstance(id)
    case .trial: openCampaignTrialReview()
    case .assignment(let assignment):
      if let id = assignment.instance {
        openCampaignGalleryInstance(id)
      } else {
        let owner = selectedCampaignState?.id
        let previewIdentity = galleryIdentityDigest([
          gallerySelectedEntryIdentity, assignment.alias, assignment.definition.definition,
          assignment.definition.version, assignment.definition.digest,
          assignment.definition.terminalPolicy.rawValue,
        ])
        rememberCampaignGalleryLocation()
        gallery.campaignPreview = GalleryMission(
          name: assignment.title, status: .locked, objective: assignment.objective,
          briefing: assignment.unavailableReason ?? "This assignment starts through its campaign.",
          destination: "Not started", reward: "No transaction on this page", prerequisites: [],
          completed: 0, milestones: [])
        gallery.campaignPreviewOwner = owner
        gallery.campaignPreviewIdentity = previewIdentity
        gallery.campaignLinks = false
        gallery.scroll = 0
      }
    }
  }

  mutating func backInCampaignGallery() -> Bool {
    gallery.presentationGeneration = UUID()
    if gallery.campaignReview != nil {
      gallery.campaignReview = nil
      gallery.campaignStartSelected = false
      gallery.campaignTrialRequested = false
      return true
    }
    if let previous = gallery.campaignHistory.popLast() {
      gallery.campaignPreview = previous.preview
      gallery.campaignPreviewOwner = previous.previewOwner
      gallery.campaignPreviewIdentity = previous.previewIdentity
      if let id = previous.instance,
        let index = missionCatalogue.firstIndex(where: { $0.savedInstance == id })
      {
        gallery.selection = index
      } else {
        gallery.selection = min(previous.selection, max(0, missionCatalogue.count - 1))
      }
      gallery.scroll = previous.scroll
      gallery.campaignLinks = previous.links
      gallery.campaignLinkSelection = previous.linkSelection
      return true
    }
    if gallery.campaignLinks {
      gallery.campaignLinks = false
      return true
    }
    return false
  }
}
