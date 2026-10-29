import Foundation

/// Explicit namespace for a ledger entry, rather than a scene actor masquerading as a target.
/// The first admitted actor is the existing ledger key; no new identity bits or alias history exist.
public struct NPCLogicalIdentity: Hashable, Codable, Sendable {
  public let firstActor: ActorIdentity
}

/// At most two bindings accompany a snapshot: aggressor and intended actor target.
/// Scene evidence remains separate from the stable ordinary-NPC relationship.
public struct NPCReferenceBinding: Equatable, Codable, Sendable {
  public let sceneActor: ActorIdentity
  public let logicalNPC: NPCLogicalIdentity

  func valid(for scene: ActorIdentity?, system: SystemIdentity) -> Bool {
    sceneActor == scene && sceneActor.system == system && sceneActor.entity >= 2
      && logicalNPC.firstActor.system == system && logicalNPC.firstActor.entity >= 2
      && sceneActor.visit > 0 && logicalNPC.firstActor.visit > 0
  }
}

extension NPCAction {
  var referencedActor: ActorIdentity? {
    switch self {
    case .engage(let actor), .flee(let actor), .dock(let actor): actor
    case .navigate, .mine, .scoop: nil
    }
  }

  func replacingReferencedActor(with actor: ActorIdentity) -> Self {
    switch self {
    case .engage: .engage(actor)
    case .flee: .flee(actor)
    case .dock: .dock(actor)
    case .navigate, .mine, .scoop: self
    }
  }
}
