import Foundation

public struct ScriptQuestionIdentity: Codable, Sendable, Equatable {
  public let instance: UUID
  public let dialogue: String
  public let token: String
  public let revision: UInt64
  var valid: Bool {
    PackValidation.localID(dialogue) && (1...256).contains(token.utf8.count)
      && revision < UInt64(Int64.max)
  }
}

public struct ScriptLegacyPageIdentity: Codable, Sendable, Equatable {
  public let stateID: String
  public let transitionID: String
  public let digest: String
  public let galaxy: Int
  public let system: Int
  public let committed: Bool
  var valid: Bool {
    let parts = stateID.split(separator: "/", omittingEmptySubsequences: false)
    return parts.count == 2 && PackValidation.identifier(String(parts[0]))
      && PackValidation.localID(String(parts[1])) && PackValidation.localID(transitionID)
      && ScriptCompletionReceipt.validDigest(digest) && (0..<8).contains(galaxy)
      && (0...256).contains(system)
  }
}

public enum ScriptPageIdentity: Codable, Sendable, Equatable {
  case legacy(ScriptLegacyPageIdentity)
  case offer(String)
  case question(ScriptQuestionIdentity)
  case gallery(ScriptGalleryPageIdentity)
  case contract(ScriptContractPageIdentity)
  var valid: Bool {
    switch self {
    case .legacy(let page): page.valid
    case .offer(let digest): ScriptCompletionReceipt.validDigest(digest)
    case .question(let question): question.valid
    case .gallery(let page): page.valid
    case .contract(let page): page.valid
    }
  }
}

/// Captures absence too: old non-offer input cannot confirm an unseen new offer or question.
public struct ScriptPagePresentation: Codable, Sendable, Equatable {
  public let epoch: UUID
  public let page: ScriptPageIdentity?
  public init(epoch: UUID, page: ScriptPageIdentity?) {
    self.epoch = epoch
    self.page = page
  }
  public static let controlKeys: Set<String> = [
    "return", "escape", "left", "right", "up", "down", "pageup", "pagedown", "k",
  ]
  /// Preserve ordinary controls while capturing absence before a queued Gallery opening.
  public static let galleryContextKeys: Set<String> = ["t", "r", "tab", "l"]
  public static let contractContextKeys: Set<String> = ["contracts-open", "contract-refresh"]
  var valid: Bool { page?.valid ?? true }
}

extension Game {
  public var scriptPagePresentation: ScriptPagePresentation {
    let page: ScriptPageIdentity?
    if screen == .handoff, let digest = scriptAvailablePackDigest {
      page = .offer(digest)
    } else if screen == .handoff, let instance = scriptOffer, let shown = scriptPresentedDialogue {
      page = .question(
        .init(
          instance: instance, dialogue: shown.id,
          token: shown.token, revision: shown.revision))
    } else if screen == .handoff, let offer = packOffer, let pack = offeredPack {
      page = .legacy(
        .init(
          stateID: offer.stateID, transitionID: offer.transitionID,
          digest: pack.digest, galaxy: offer.galaxy, system: offer.system,
          committed: offer.committed))
    } else if screen == .gallery {
      page = .gallery(scriptGalleryPageIdentity)
    } else if screen == .contracts {
      page = .contract(scriptContractPageIdentity)
    } else {
      page = nil
    }
    return .init(epoch: ecmControl.epoch, page: page)
  }
}

extension GameRuntime {
  public func scriptPageKey(_ key: String, expected: ScriptPagePresentation) {
    let allowed: Bool
    if case .gallery(let page)? = expected.page {
      allowed = page.allowedKeys.contains(key) || key == "contracts-open"
    } else if case .contract(let page)? = expected.page {
      allowed = page.allowedKeys.contains(key)
    } else if expected.page == nil {
      allowed =
        ScriptPagePresentation.controlKeys.contains(key)
        || ScriptPagePresentation.galleryContextKeys.contains(key)
        || ScriptPagePresentation.contractContextKeys.contains(key)
    } else {
      allowed = ScriptPagePresentation.controlKeys.contains(key)
    }
    guard allowed, expected.valid,
      game.scriptPagePresentation == expected
    else {
      game.notify("CONTACT CHANGED - REVIEW THE CURRENT PAGE")
      return
    }
    self.key(key)
  }
  public func scriptPageClick(x: Double, y: Double, expected: ScriptPagePresentation) {
    guard x.isFinite, y.isFinite, expected.valid,
      game.scriptPagePresentation == expected
    else {
      game.notify("CONTACT CHANGED - REVIEW THE CURRENT PAGE")
      return
    }
    if case .gallery? = expected.page {
      galleryClick(x: x, y: y)
    } else if case .contract? = expected.page {
      contractPageClick(x: x, y: y)
    } else {
      blackjackHandoffClick(x: x, y: y)
    }
  }
}
