public enum WorkTargetFilter: Sendable, Equatable {
  case all, ships, mining, salvage
}

public enum WorkTargetSpecialty: Sendable, Equatable {
  case mining, salvage
}

public enum WorkTargetKind: Sendable, Equatable {
  case ship, activeStation
  case recoverable(SalvageTargetMetadata, payload: PayloadIdentity?)
}

/// Classification, scoop compatibility and live state are authoritative runtime facts.
public struct WorkTargetCandidate: Sendable, Equatable {
  public let identity: ActorIdentity
  public let kind: WorkTargetKind
  /// Physical presence; section depletion alone does not invalidate a large hold parent.
  public let isLive: Bool
  public let frontVisible: Bool
  public let distance: Double
  public let singleScoopCompatible: Bool
  public let nativePod: NativePodSelectionFacts?
  public let nativeCrewCapture: Bool

  public init(
    identity: ActorIdentity, kind: WorkTargetKind, isLive: Bool,
    frontVisible: Bool, distance: Double, singleScoopCompatible: Bool,
    nativePod: NativePodSelectionFacts? = nil, nativeCrewCapture: Bool = false
  ) {
    self.identity = identity
    self.kind = kind
    self.isLive = isLive
    self.frontVisible = frontVisible
    self.distance = distance
    self.singleScoopCompatible = singleScoopCompatible
    self.nativePod = nativePod
    self.nativeCrewCapture = nativeCrewCapture
  }
}

/// Installed add-ons remain independent of the core's inherited ordinary targeting functions.
public struct WorkTargetCapabilities: Sendable, Equatable {
  public let core: TargetingTier?
  public let miningModule: Bool
  public let salvageModule: Bool
  public let fuelScoops: Bool

  public init(core: TargetingTier?, miningModule: Bool, salvageModule: Bool, fuelScoops: Bool) {
    self.core = core
    self.miningModule = miningModule
    self.salvageModule = salvageModule
    self.fuelScoops = fuelScoops
  }
}

public enum WorkTargetMode: Sendable, Equatable {
  case ship, docking
  case hold(WorkTargetSpecialty)
  case autoScoop(WorkTargetSpecialty)
}

public enum WorkTargetRefusal: Sendable, Equatable {
  case notLive, wrongContext, invalidDistance, missingCore
  case frontVisibilityRequired, dockingCoreRequired
  case missingModule(WorkTargetSpecialty)
  case protectedTarget, occupiedPod, notScoopCompatible, missingFuelScoops
  case fullPeopleHold
}

public enum WorkTargetDecision: Sendable, Equatable {
  case eligible(WorkTargetMode)
  case refused(WorkTargetRefusal)

  public var mode: WorkTargetMode? {
    guard case .eligible(let mode) = self else { return nil }
    return mode
  }
}

public struct WorkTargetChoice: Sendable, Equatable {
  public let candidate: WorkTargetCandidate
  public let mode: WorkTargetMode

  public init(candidate: WorkTargetCandidate, mode: WorkTargetMode) {
    self.candidate = candidate
    self.mode = mode
  }
}

/// Selection only: no controller engagement, tool activation, custody or resource mutation.
public enum WorkTargetSelection {
  public static func evaluate(
    _ candidate: WorkTargetCandidate, system: SystemIdentity, visit: UInt64,
    capabilities: WorkTargetCapabilities
  ) -> WorkTargetDecision {
    guard candidate.isLive else { return .refused(.notLive) }
    guard candidate.identity.system == system, candidate.identity.visit == visit else {
      return .refused(.wrongContext)
    }
    guard candidate.distance.isFinite, candidate.distance >= 0 else {
      return .refused(.invalidDistance)
    }
    guard let core = capabilities.core else { return .refused(.missingCore) }
    switch candidate.kind {
    case .ship:
      return core >= .advanced || candidate.frontVisible
        ? .eligible(.ship) : .refused(.frontVisibilityRequired)
    case .activeStation:
      return core >= .docking ? .eligible(.docking) : .refused(.dockingCoreRequired)
    case .recoverable(let metadata, let payload):
      if metadata.category == .occupiedPod {
        guard let pod = candidate.nativePod else { return .refused(.occupiedPod) }
        guard capabilities.salvageModule else { return .refused(.missingModule(.salvage)) }
        guard capabilities.fuelScoops else { return .refused(.missingFuelScoops) }
        guard candidate.singleScoopCompatible else { return .refused(.notScoopCompatible) }
        guard pod.fits else { return .refused(.fullPeopleHold) }
        return .eligible(.autoScoop(.salvage))
      }
      if candidate.nativeCrewCapture {
        guard capabilities.salvageModule else { return .refused(.missingModule(.salvage)) }
        guard capabilities.fuelScoops else { return .refused(.missingFuelScoops) }
        return .eligible(.hold(.salvage))
      }
      // Mission custody never becomes ordinary salvage, even if classification metadata disagrees.
      if case .mission = payload { return .refused(.protectedTarget) }
      guard metadata.ownership == .abandoned, metadata.claimant == nil else {
        return .refused(.protectedTarget)
      }
      let specialty: WorkTargetSpecialty
      switch metadata.category {
      case .rock: specialty = .mining
      case .cargo:
        if case .ore = payload { specialty = .mining } else { specialty = .salvage }
      default: specialty = .salvage
      }
      let installed = specialty == .mining ? capabilities.miningModule : capabilities.salvageModule
      guard installed else { return .refused(.missingModule(specialty)) }
      switch metadata.category {
      case .rock, .wreck, .section:
        // Hold eligibility does not promise an installed tool or collection capability.
        // A live depleted parent remains a valid hold; lifecycle decisions belong to runtime.
        return .eligible(.hold(specialty))
      default:
        guard candidate.singleScoopCompatible else { return .refused(.notScoopCompatible) }
        guard capabilities.fuelScoops else { return .refused(.missingFuelScoops) }
        return .eligible(.autoScoop(specialty))
      }
    }
  }

  public static func ordered(
    _ candidates: [WorkTargetCandidate], filter: WorkTargetFilter,
    system: SystemIdentity, visit: UInt64, capabilities: WorkTargetCapabilities
  ) -> [WorkTargetChoice] {
    var unique: [ActorIdentity: WorkTargetCandidate] = [:]
    var conflicting: Set<ActorIdentity> = []
    for candidate in candidates {
      if let previous = unique[candidate.identity], previous != candidate {
        conflicting.insert(candidate.identity)
      } else {
        unique[candidate.identity] = candidate
      }
    }
    return unique.values.compactMap { candidate -> WorkTargetChoice? in
      guard !conflicting.contains(candidate.identity),
        let mode = evaluate(candidate, system: system, visit: visit, capabilities: capabilities)
          .mode,
        includes(mode, filter: filter)
      else { return nil }
      return .init(candidate: candidate, mode: mode)
    }.sorted { left, right in
      // Preserve existing ordinary station docking priority after other selectable targets.
      if (left.mode == .docking) != (right.mode == .docking) { return right.mode == .docking }
      if left.candidate.frontVisible != right.candidate.frontVisible {
        return left.candidate.frontVisible
      }
      if left.candidate.distance != right.candidate.distance {
        return left.candidate.distance < right.candidate.distance
      }
      return left.candidate.identity.entity < right.candidate.identity.entity
    }
  }

  private static func includes(_ mode: WorkTargetMode, filter: WorkTargetFilter) -> Bool {
    switch (filter, mode) {
    case (.all, _), (.ships, .ship), (.ships, .docking),
      (.mining, .hold(.mining)), (.mining, .autoScoop(.mining)),
      (.salvage, .hold(.salvage)), (.salvage, .autoScoop(.salvage)):
      true
    default:
      false
    }
  }
}
