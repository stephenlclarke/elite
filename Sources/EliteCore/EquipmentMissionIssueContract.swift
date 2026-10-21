import Foundation

public struct EquipmentIssueSource: Equatable, Codable, Sendable {
  public let mission: UUID
  public let resource: String
  public let packDigest: String
  public init(mission: UUID, resource: String, packDigest: String) {
    self.mission = mission
    self.resource = resource
    self.packDigest = packDigest
  }
  var valid: Bool {
    PackValidation.localID(resource)
      && packDigest.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
  }
}

public struct LegacyEquipmentState: Equatable, Codable, Sendable {
  public let conditionBasisPoints: Int
  public let modifications: [String: Int]
  public let originalEquipmentName: String?
  public init(
    conditionBasisPoints: Int, modifications: [String: Int], originalEquipmentName: String? = nil
  ) {
    self.conditionBasisPoints = conditionBasisPoints
    self.modifications = modifications
    self.originalEquipmentName = originalEquipmentName
  }
  var valid: Bool {
    (0...10000).contains(conditionBasisPoints) && modifications.count <= 32
      && modifications.keys.allSatisfy(PackValidation.localID)
      && modifications.values.allSatisfy { (-100000...100000).contains($0) }
      && (originalEquipmentName == nil || originalEquipmentName == Equipment.legacyDockingComputer)
  }
  var pristine: Bool { conditionBasisPoints == 10000 && modifications.isEmpty }
}

/// A historical address reference, never a second physical item or current fitting.
public struct EquipmentIssueDisplacement: Equatable, Codable, Sendable {
  public let item: UUID
  public let location: ComponentFittingLocation
  public init(item: UUID, location: ComponentFittingLocation) {
    self.item = item
    self.location = location
  }
}

public enum EquipmentIssueStatus: String, Codable, Sendable { case issued, returned, released }
public enum EquipmentIssueOperation: String, Sendable {
  case issued, returned, released, stored, refitted
}
public enum EquipmentIssueSettlement: Equatable, Sendable { case returnOriginals, releaseLoan }

public struct IssuedDeviceRequest: Equatable, Sendable {
  public let id: UUID
  public let node: EquipmentNodeID
  public let index: Int
  public let preferredSlot: ComponentFittingSlot?
  public let originalEquipmentName: String?
  public init(
    id: UUID, node: EquipmentNodeID, index: Int, preferredSlot: ComponentFittingSlot?,
    originalEquipmentName: String? = nil
  ) {
    self.id = id
    self.node = node
    self.index = index
    self.preferredSlot = preferredSlot
    self.originalEquipmentName = originalEquipmentName
  }
}

public struct IssueFitting: Equatable, Sendable {
  public let item: UUID
  public let location: ComponentFittingLocation
  public let replacing: OwnedEquipmentItem?
  public init(item: UUID, location: ComponentFittingLocation, replacing: OwnedEquipmentItem?) {
    self.item = item
    self.location = location
    self.replacing = replacing
  }
}

public enum IssueFittingPlan: Equatable, Sendable {
  case held
  case fitAll([IssueFitting])
}

public struct EquipmentIssueRequest: Equatable, Sendable {
  public let command: UUID
  public let source: EquipmentIssueSource
  public let devices: [IssuedDeviceRequest]
  public let fitting: IssueFittingPlan
  public init(
    command: UUID, source: EquipmentIssueSource, devices: [IssuedDeviceRequest],
    fitting: IssueFittingPlan
  ) {
    self.command = command
    self.source = source
    self.devices = devices
    self.fitting = fitting
  }
}

/// Derived from retained Script records, including missing content. It owns no items.
public struct EquipmentIssueObligationSnapshot: Equatable, Sendable {
  public let source: EquipmentIssueSource
  public let node: EquipmentNodeID
  public let items: [UUID]
  public let consumed: Set<UUID>
  public let status: EquipmentIssueStatus
  public let loan: Bool
  public let returnRemaining: Bool
  public let displacements: [EquipmentIssueDisplacement]
  public let legacyMissingItems: Set<UUID>
  public init(
    source: EquipmentIssueSource, node: EquipmentNodeID, items: [UUID], consumed: Set<UUID>,
    status: EquipmentIssueStatus, loan: Bool, returnRemaining: Bool,
    displacements: [EquipmentIssueDisplacement], legacyMissingItems: Set<UUID> = []
  ) {
    self.source = source
    self.node = node
    self.items = items
    self.consumed = consumed
    self.status = status
    self.loan = loan
    self.returnRemaining = returnRemaining
    self.displacements = displacements
    self.legacyMissingItems = legacyMissingItems
  }
  var valid: Bool {
    let originals = Set(items)
    return source.valid && (1...32).contains(items.count) && originals.count == items.count
      && consumed.isSubset(of: originals) && legacyMissingItems.isSubset(of: originals)
      && legacyMissingItems.isDisjoint(with: consumed) && (!loan || legacyMissingItems.isEmpty)
      && displacements.count <= 32 && Set(displacements.map(\.item)).count == displacements.count
      && displacements.allSatisfy { !originals.contains($0.item) && $0.location.slot.valid }
  }
}

/// Trusted current/projected accommodation facts, re-derived and pinned at application.
/// The pure provider does not invent prices, cabin rules or a second budget owner.
public struct EquipmentFitBudgetSnapshot: Equatable, Sendable {
  public let equipmentCapacity: Int
  public let reservedEquipmentUnits: Int
  public let nodeEquipmentUnits: [EquipmentNodeID: Int]
  public let projectedCargoCapacity: Int
  public let occupiedCargoTonnes: Int
  public let accommodationAllowed: Bool
  public init(
    equipmentCapacity: Int, reservedEquipmentUnits: Int, nodeEquipmentUnits: [EquipmentNodeID: Int],
    projectedCargoCapacity: Int, occupiedCargoTonnes: Int, accommodationAllowed: Bool
  ) {
    self.equipmentCapacity = equipmentCapacity
    self.reservedEquipmentUnits = reservedEquipmentUnits
    self.nodeEquipmentUnits = nodeEquipmentUnits
    self.projectedCargoCapacity = projectedCargoCapacity
    self.occupiedCargoTonnes = occupiedCargoTonnes
    self.accommodationAllowed = accommodationAllowed
  }
  var valid: Bool {
    equipmentCapacity >= 0 && reservedEquipmentUnits >= 0 && projectedCargoCapacity >= 0
      && occupiedCargoTonnes >= 0 && nodeEquipmentUnits.values.allSatisfy { $0 >= 0 }
  }
}

public enum EquipmentIssueError: Error, Equatable, Sendable {
  case invalidRequest, identityMismatch, sourceMismatch, staleObligation, invalidBudget
  case missingOriginal(UUID)
  case consumedOriginalRequired(UUID)
  case foreignLoan(UUID)
  case loanModificationRefused(UUID)
  case unsupportedReplacement
}

public enum StandardAmmunitionError: Error, Equatable, Sendable {
  case noFiniteRound, staleRound, unsupportedProfile, invalidVirtualUse
}

public enum EquipmentMigrationError: Error, Equatable, Sendable {
  case unsupportedVersion, incompleteVersionedState, mixedRepresentations
  case invalidLegacyCount, invalidCrosswalk, unsupportedLegacyState, obligationMismatch
}
