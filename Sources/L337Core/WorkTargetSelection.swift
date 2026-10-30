public enum WorkTargetFilter: Sendable, Equatable {
  case all, ships, mining, salvage
}

public enum WorkTargetSpecialty: Sendable, Equatable {
  case mining, salvage
}

public enum WorkTargetKind: Sendable, Equatable {
  case ship, capitalShip, activeStation
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
  public let originalRescue: NativeOriginalRescueSelectionFacts?
  public let measuredExtraction: NativeMeasuredExtractionSelectionFacts?
  public let recordRecovery: WayfarerRecordRecoverySelectionFacts?
  public let inductionCrewLog: NativeInductionCrewLogSelectionFacts?
  public let identifiedSalvage: NativeIdentifiedSalvageSelectionFacts?

  public init(
    identity: ActorIdentity, kind: WorkTargetKind, isLive: Bool,
    frontVisible: Bool, distance: Double, singleScoopCompatible: Bool,
    nativePod: NativePodSelectionFacts? = nil, nativeCrewCapture: Bool = false,
    originalRescue: NativeOriginalRescueSelectionFacts? = nil,
    measuredExtraction: NativeMeasuredExtractionSelectionFacts? = nil,
    recordRecovery: WayfarerRecordRecoverySelectionFacts? = nil,
    inductionCrewLog: NativeInductionCrewLogSelectionFacts? = nil,
    identifiedSalvage: NativeIdentifiedSalvageSelectionFacts? = nil
  ) {
    self.identity = identity
    self.kind = kind
    self.isLive = isLive
    self.frontVisible = frontVisible
    self.distance = distance
    self.singleScoopCompatible = singleScoopCompatible
    self.nativePod = nativePod
    self.nativeCrewCapture = nativeCrewCapture
    self.originalRescue = originalRescue
    self.measuredExtraction = measuredExtraction
    self.recordRecovery = recordRecovery
    self.inductionCrewLog = inductionCrewLog
    self.identifiedSalvage = identifiedSalvage
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
  case tracking(WorkTargetSpecialty)
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
    if let original = candidate.measuredExtraction {
      guard capabilities.miningModule else { return .refused(.missingModule(.mining)) }
      guard capabilities.fuelScoops else { return .refused(.missingFuelScoops) }
      guard candidate.singleScoopCompatible else { return .refused(.notScoopCompatible) }
      guard original.fits else { return .refused(.protectedTarget) }
      return .eligible(.autoScoop(.mining))
    }
    if let original = candidate.inductionCrewLog {
      guard capabilities.salvageModule else { return .refused(.missingModule(.salvage)) }
      guard capabilities.fuelScoops else { return .refused(.missingFuelScoops) }
      guard candidate.singleScoopCompatible else { return .refused(.notScoopCompatible) }
      guard original.fits else { return .refused(.protectedTarget) }
      return .eligible(.autoScoop(.salvage))
    }
    if let original = candidate.recordRecovery {
      guard capabilities.salvageModule else { return .refused(.missingModule(.salvage)) }
      guard capabilities.fuelScoops else { return .refused(.missingFuelScoops) }
      guard candidate.singleScoopCompatible else { return .refused(.notScoopCompatible) }
      guard original.fits else { return .refused(.protectedTarget) }
      return .eligible(.autoScoop(.salvage))
    }
    if let original = candidate.identifiedSalvage {
      guard capabilities.salvageModule else { return .refused(.missingModule(.salvage)) }
      guard capabilities.fuelScoops else { return .refused(.missingFuelScoops) }
      guard candidate.singleScoopCompatible else { return .refused(.notScoopCompatible) }
      guard original.fits else { return .refused(.protectedTarget) }
      return .eligible(.autoScoop(.salvage))
    }
    if let original = candidate.originalRescue {
      guard capabilities.salvageModule else { return .refused(.missingModule(.salvage)) }
      guard capabilities.fuelScoops else { return .refused(.missingFuelScoops) }
      guard candidate.singleScoopCompatible else { return .refused(.notScoopCompatible) }
      guard original.fits else {
        return .refused(original.isPerson ? .fullPeopleHold : .protectedTarget)
      }
      return .eligible(.autoScoop(.salvage))
    }
    switch candidate.kind {
    case .ship:
      return core >= .advanced || candidate.frontVisible
        ? .eligible(.ship) : .refused(.frontVisibilityRequired)
    case .capitalShip:
      if capabilities.salvageModule { return .eligible(.hold(.salvage)) }
      return ordinaryTracking(candidate, core: core, specialty: .salvage)
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
      // A physical hold does not authorize cutting, capture, transfer or collection.
      // Loose items still require their complete custody and scoop checks below.
      if [.rock, .wreck, .section].contains(metadata.category) {
        let specialty: WorkTargetSpecialty = metadata.category == .rock ? .mining : .salvage
        let installed =
          specialty == .mining ? capabilities.miningModule : capabilities.salvageModule
        return installed
          ? .eligible(.hold(specialty))
          : ordinaryTracking(candidate, core: core, specialty: specialty)
      }
      if candidate.nativeCrewCapture {
        guard capabilities.salvageModule else { return .refused(.missingModule(.salvage)) }
        guard capabilities.fuelScoops else { return .refused(.missingFuelScoops) }
        return .eligible(.hold(.salvage))
      }
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
      guard candidate.singleScoopCompatible else { return .refused(.notScoopCompatible) }
      guard capabilities.fuelScoops else { return .refused(.missingFuelScoops) }
      return .eligible(.autoScoop(specialty))
    }
  }

  private static func ordinaryTracking(
    _ candidate: WorkTargetCandidate, core: TargetingTier, specialty: WorkTargetSpecialty
  ) -> WorkTargetDecision {
    core >= .advanced || candidate.frontVisible
      ? .eligible(.tracking(specialty)) : .refused(.frontVisibilityRequired)
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
        includes(candidate, mode: mode, filter: filter)
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

  private static func includes(
    _ candidate: WorkTargetCandidate, mode: WorkTargetMode, filter: WorkTargetFilter
  ) -> Bool {
    if filter == .ships, candidate.kind == .capitalShip { return true }
    return switch (filter, mode) {
    case (.all, _), (.ships, .ship), (.ships, .docking),
      (.mining, .hold(.mining)), (.mining, .autoScoop(.mining)), (.mining, .tracking(.mining)),
      (.salvage, .hold(.salvage)), (.salvage, .autoScoop(.salvage)),
      (.salvage, .tracking(.salvage)):
      true
    default:
      false
    }
  }
}
