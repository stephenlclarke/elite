import Foundation

enum ProviderMissionRequest: Equatable, Sendable {
  case accept
  case action(ProviderMissionAction)
}
enum ProviderMissionPage: Equatable, Sendable {
  case contract(ScriptContractPageIdentity)
  case gallery(ScriptGalleryPageIdentity)
}
struct ProviderMissionIntent: Equatable, Sendable {
  let presentationEpoch: UUID
  let digest: String
  let instance: UUID?
  let request: ProviderMissionRequest
  let reviewToken: UUID?
  let page: ProviderMissionPage
}

/// Labels and progress only. This deliberately contains no source, fact stamp, seal or commander.
struct ProviderMissionPresentation: Equatable, Sendable {
  let definition: String
  let available: Bool
  let reason: String?
  let provider: NativeProviderIdentity
  let subject: UUID
  let status: String
}

struct ProviderContractRow: Equatable, Sendable {
  let definition: String
  let digest: String
  let instance: UUID?
  let request: ProviderMissionRequest
  let label: String
  var key: String { "provider/" + digest + "/" + (instance?.uuidString ?? "offer") + "/" + label }
}

struct ProviderContractQuote: Sendable {
  let row: ProviderContractRow
  let reviewToken = UUID()
  let issues: [String]
  var allowed: Bool { issues.isEmpty }
}

extension Game {
  /// G1 refreshes this bounded projection from its native owner; it never authorizes a commit.
  mutating func presentProviderMission(_ presentation: ProviderMissionPresentation) throws {
    guard presentation.definition.utf8.count <= 256,
      presentation.status.utf8.count <= 512, (presentation.reason?.utf8.count ?? 0) <= 512,
      presentation.provider.valid
    else { throw MissionPackError("Invalid provider presentation.") }
    if let index = gallery.providerPresentations.firstIndex(where: {
      $0.definition == presentation.definition
    }) {
      gallery.providerPresentations[index] = presentation
    } else {
      guard gallery.providerPresentations.count < 32 else {
        throw MissionPackError("Provider presentation capacity reached.")
      }
      gallery.providerPresentations.append(presentation)
    }
  }

  var providerContractRows: [ContractBoardRow] {
    guard docked, dockedAtMainStation else { return [] }
    return scriptPacks.filter { $0.manifest.providerContract != nil }.flatMap { pack in
      guard let terms = pack.manifest.providerContract,
        commander.galaxy == terms.origin.galaxy
      else { return [ContractBoardRow]() }
      let states = commander.scriptState.instances.values.filter {
        $0.definition == pack.manifest.stateID
      }
      if let instance = states.first, let state = instance.savedProviderContract {
        guard !state.stage.terminal, state.custody == .aboard else { return [] }
        var rows: [ContractBoardRow] = []
        if commander.system == terms.destination.system, state.eligible, state.branch != nil {
          rows.append(
            providerBoardRow(
              pack, instance: instance.id, request: .action(.deliver), label: "Deliver relay"))
        }
        if commander.system == terms.origin.system {
          rows.append(
            providerBoardRow(
              pack, instance: instance.id, request: .action(.returnRelay),
              label: "Return relay - zero base payment"))
        }
        return rows
      }
      guard states.isEmpty, commander.system == terms.origin.system else { return [] }
      return [providerBoardRow(pack, instance: nil, request: .accept, label: "Accept relay")]
    }
  }
  private func providerBoardRow(
    _ pack: ScriptPack, instance: UUID?, request: ProviderMissionRequest,
    label: String
  ) -> ContractBoardRow {
    let reason = scriptUnavailable(pack) ?? providerPresentationReason(pack.manifest.stateID)
    let row = ProviderContractRow(
      definition: pack.manifest.stateID, digest: pack.digest,
      instance: instance, request: request, label: label)
    return .init(
      board: row.key, offer: nil, title: pack.manifest.mission.title + " / " + label,
      reason: reason, provider: row)
  }
  func providerPresentationReason(_ definition: String) -> String? {
    guard
      let presentation = gallery.providerPresentations.first(where: { $0.definition == definition }
      ),
      presentation.available
    else {
      return gallery.providerPresentations.first(where: { $0.definition == definition })?.reason
        ?? "Complete native provider support is unavailable."
    }
    return nil
  }
  var providerContractDetail: [String] {
    guard let row = contractBoard.selected?.provider,
      let pack = scriptPacks.first(where: { $0.digest == row.digest })
    else { return [] }
    return [
      pack.manifest.mission.title, pack.manifest.mission.briefing,
      pack.manifest.mission.reward, "One protected 1t relay. No deposit, advance or deadline.",
      "Confirm performs the named action only. Back or Decline issues nothing.", row.label,
    ]
      + (contractBoard.providerQuote?.issues ?? [])
  }
  var providerContractPageFacts: [String] {
    providerContractRows.flatMap { [$0.key, $0.reason ?? ""] }
      + [contractBoard.providerQuote?.reviewToken.uuidString ?? ""]
  }

  mutating func stageProviderContractIntent() throws {
    guard screen == .contracts, contractBoard.detail, contractBoard.action == .accept,
      let row = contractBoard.selected?.provider, let quote = contractBoard.providerQuote,
      quote.row == row, quote.allowed
    else { throw MissionPackError("Review this provider action first.") }
    gallery.providerIntent = .init(
      presentationEpoch: ecmControl.epoch, digest: row.digest, instance: row.instance,
      request: row.request, reviewToken: quote.reviewToken,
      page: .contract(scriptContractPageIdentity))
  }

  @discardableResult
  mutating func stageProviderGalleryIntent(_ key: String) -> Bool {
    guard screen == .gallery, gallery.detail, let intent = providerGalleryIntent(key) else {
      return false
    }
    gallery.providerIntent = intent
    return true
  }

  // Complete page construction before reading the full saved provider instance.
  private func providerGalleryIntent(_ key: String) -> ProviderMissionIntent? {
    let query = galleryReadQuery()
    let page = scriptGalleryPageIdentity(query)
    guard page.mode == .detail, let instance = query.selected?.savedInstance else { return nil }
    return providerGalleryIntent(key, instance: instance, page: page)
  }

  @inline(never)
  private func providerGalleryIntent(
    _ key: String, instance: UUID, page: ScriptGalleryPageIdentity
  ) -> ProviderMissionIntent? {
    guard let saved = commander.scriptState.instances[instance],
      let state = saved.savedProviderContract,
      !state.stage.terminal
    else { return nil }
    let action: ProviderMissionAction?
    switch key {
    case "m": action = .requestManifest
    case "u": action = .reviewUrgent
    case "c": action = .confirmUrgent
    case "k": action = .recoverCore
    case "d": action = .deliver
    case "x": action = .returnRelay
    case "b": action = .back
    default: return nil
    }
    guard let action else { return nil }
    return .init(
      presentationEpoch: ecmControl.epoch, digest: saved.digest, instance: instance,
      request: .action(action), reviewToken: state.pending?.token,
      page: .gallery(page))
  }

  func acceptsProviderIntent(_ intent: ProviderMissionIntent) -> Bool {
    guard gallery.providerIntent == intent, intent.presentationEpoch == ecmControl.epoch, !paused
    else { return false }
    switch intent.page {
    case .contract(let proof): return screen == .contracts && proof == scriptContractPageIdentity
    case .gallery(let proof): return screen == .gallery && proof == scriptGalleryPageIdentity
    }
  }

  /// Internal same-turn seam. G1 checks current page/context before resolving fresh native facts.
  mutating func executeProviderIntent(
    _ intent: ProviderMissionIntent, facts: NativeProviderMissionFacts
  ) throws {
    guard acceptsProviderIntent(intent), acceptsProviderMissionFacts(facts),
      let pack = scriptPacks.first(where: { $0.digest == intent.digest }),
      pack.manifest.providerContract != nil
    else { throw MissionPackError("Provider page changed; review again.") }
    switch intent.request {
    case .accept:
      guard intent.instance == nil else { throw MissionPackError("Foreign acceptance intent.") }
      _ = try acceptProviderMission(pack, facts: facts)
    case .action(let action):
      guard let id = intent.instance, commander.scriptState.instances[id]?.digest == pack.digest
      else {
        throw MissionPackError("Foreign contract action.")
      }
      try applyProviderMissionAction(
        action, instance: id, facts: facts, reviewToken: intent.reviewToken)
    }
    gallery.providerIntent = nil
    gallery.presentationGeneration = UUID()
    if screen == .contracts {
      contractBoard.detail = false
      contractBoard.providerQuote = nil
      refreshContractRows()
      contractBoard.presentationGeneration = UUID()
    }
  }
}

extension GameRuntime {
  /// G1's actual input bridge calls this after current-page checks and fresh native resolution.
  func performProviderMissionIntent(
    _ intent: ProviderMissionIntent, facts: NativeProviderMissionFacts
  ) throws {
    guard game.acceptsProviderIntent(intent) else {
      throw MissionPackError("Provider review is stale.")
    }
    try scriptCommand { candidate in try candidate.executeProviderIntent(intent, facts: facts) }
  }
}
