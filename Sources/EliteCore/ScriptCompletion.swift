import Foundation

public enum ScriptReceiptStage: String, Codable, Sendable { case acceptance, completion }

/// Content identities are exact; having a dependency installed is not completion proof.
public struct ScriptReceiptRequirement: Codable, Sendable {
  public let id: String
  public let stage: ScriptReceiptStage
  public let definition: String
  public let version: String
  public let digest: String
  public let outcome: ScriptOutcome?
  public let outcomes: [ScriptOutcome]?
  public var acceptedOutcomes: [ScriptOutcome] { outcome.map { [$0] } ?? outcomes ?? [] }
  public let minimumCount: Int
  public let choiceGroup: String?
  public let choice: String?
  var valid: Bool {
    let parts = definition.split(separator: "/", omittingEmptySubsequences: false)
    return PackValidation.localID(id) && parts.count == 2
      && parts.allSatisfy { PackValidation.identifier(String($0)) }
      && PackValidation.version(version) && ScriptCompletionReceipt.validDigest(digest)
      && ((outcome == nil) != (outcomes == nil))
      && (1...3).contains(acceptedOutcomes.count)
      && Set(acceptedOutcomes.map(\.rawValue)).count == acceptedOutcomes.count
      && !acceptedOutcomes.contains(.active) && (1...128).contains(minimumCount)
      && ((choiceGroup == nil && choice == nil)
        || (choiceGroup.map(PackValidation.localID) == true
          && choice.map(PackValidation.localID) == true))
  }
  func matches(_ receipt: ScriptCompletionReceipt) -> Bool {
    receipt.definition == definition && receipt.version == version && receipt.digest == digest
      && acceptedOutcomes.contains(receipt.outcome)
      && (choiceGroup.map { receipt.choices?[$0]?.choice == choice } ?? true)
  }
}

/// Created only at a validated terminal transition, published with its effects and never amended.
public struct ScriptCompletionReceipt: Codable, Sendable, Equatable {
  public let instance: UUID
  public let definition: String
  public let version: String
  public let digest: String
  public let outcome: ScriptOutcome
  public let sequence: UInt64
  public let causeKind: String
  public let cause: ScriptEventContext?
  public let committed: ScriptEventContext
  public let revision: UInt64
  public let milestones: [Int]
  public let destroyedEncounters: [String]
  public let deliveredParties: [String]
  public let returnedEquipment: [String]
  public let settlementAmount: Int?
  public let choices: [String: ScriptChoiceReceipt]?

  static func validDigest(_ digest: String) -> Bool {
    digest.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
  }
  func valid(for state: ScriptInstance, engine: ScriptEngineState) -> Bool {
    instance == state.id && definition == state.definition && version == state.version
      && digest == state.digest && outcome == state.outcome && outcome != .active
      && sequence > 0 && sequence <= engine.nextEvent && state.hasAcknowledged(sequence)
      && ScriptCapabilities.events.contains(causeKind) && committed.valid
      && revision > 0 && revision == state.revision && committed.revision == revision
      && (cause.map { $0.valid && $0.revision < revision } ?? true)
      && committed.localSeconds <= engine.localSeconds
      && committed.flightSeconds <= engine.flightSeconds
      && committed.calendarSeconds <= engine.calendarSeconds
      && committed.transitSeconds <= engine.transitSeconds
      && (cause.map {
        $0.localSeconds <= committed.localSeconds && $0.flightSeconds <= committed.flightSeconds
          && $0.calendarSeconds <= committed.calendarSeconds
          && $0.transitSeconds <= committed.transitSeconds
      } ?? true)
      && milestones == state.milestones.sorted()
      && destroyedEncounters == destroyedEncounters.sorted()
      && Set(destroyedEncounters).count == destroyedEncounters.count
      && destroyedEncounters.allSatisfy { state.ownedEncounters[$0]?.destroyed == true }
      && deliveredParties == deliveredParties.sorted()
      && Set(deliveredParties).count == deliveredParties.count
      && deliveredParties.count <= 64 && deliveredParties.allSatisfy(PackValidation.localID)
      && returnedEquipment
        == state.gearIssues.values.filter { $0.status == .returned }
        .map(\.resource).sorted()
      && settlementAmount == state.contract?.settlementAmount
      && (choices ?? [:]) == state.choiceReceipts
  }
}

extension Game {
  func matchingScriptReceipts(_ requirement: ScriptReceiptRequirement) -> [UUID] {
    commander.scriptState.instances.values.compactMap { state in
      state.completionReceipt.flatMap {
        $0.valid(for: state, engine: commander.scriptState) ? $0 : nil
      }
    }
    .filter { requirement.matches($0) }
    .sorted { ($0.sequence, $0.instance.uuidString) < ($1.sequence, $1.instance.uuidString) }
    .map(\.instance)
  }
  func scriptAcceptanceIssue(_ pack: ScriptPack) -> String? {
    for requirement in pack.manifest.receiptRequirements ?? []
    where requirement.stage == .acceptance {
      if matchingScriptReceipts(requirement).count < requirement.minimumCount {
        return
          "Requires \(requirement.minimumCount) verified \(requirement.acceptedOutcomes.map(\.rawValue).sorted().joined(separator: "/")) receipt(s): "
          + requirement.definition + "@" + requirement.version
          + (requirement.choiceGroup.map { " with branch " + $0 + "/" + (requirement.choice ?? "") }
            ?? "")
      }
    }
    return nil
  }
  func scriptReceiptJoins(
    _ pack: ScriptPack, stage: ScriptReceiptStage, existing: [String: [UUID]]
  ) throws -> [String: [UUID]] {
    var joins = existing
    for requirement in pack.manifest.receiptRequirements ?? [] where requirement.stage == stage {
      let matches = matchingScriptReceipts(requirement)
      if let pinned = joins[requirement.id] {
        guard pinned.count == requirement.minimumCount, pinned.allSatisfy(matches.contains) else {
          throw MissionPackError("The pinned child mission receipts are unavailable.")
        }
      } else {
        guard matches.count >= requirement.minimumCount else {
          throw MissionPackError("Missing verified child mission receipts: " + requirement.id)
        }
        joins[requirement.id] = Array(matches.prefix(requirement.minimumCount))
      }
    }
    return joins
  }
  func scriptReceiptQuery(_ pack: ScriptPack, state: ScriptInstance) -> ScriptValue {
    .object(
      Dictionary(
        uniqueKeysWithValues: (pack.manifest.receiptRequirements ?? []).map {
          requirement in
          let matches = matchingScriptReceipts(requirement)
          return (
            requirement.id,
            .object([
              "stage": .string(requirement.stage.rawValue),
              "required_count": .integer(Int64(requirement.minimumCount)),
              "matched_count": .integer(Int64(matches.count)),
              "satisfied": .bool(matches.count >= requirement.minimumCount),
              "joined_instances": .array(
                (state.receiptJoins?[requirement.id] ?? []).map {
                  .string($0.uuidString)
                }),
            ])
          )
        }))
  }
  func completionReceipt(_ state: ScriptInstance, event: ScriptEvent, pack: ScriptPack)
    -> ScriptCompletionReceipt
  {
    .init(
      instance: state.id, definition: state.definition, version: state.version,
      digest: state.digest,
      outcome: state.outcome, sequence: event.sequence, causeKind: event.kind, cause: event.context,
      committed: scriptEventContext(state), revision: state.revision,
      milestones: state.milestones.sorted(),
      destroyedEncounters: state.ownedEncounters.values.filter(\.destroyed).map(\.id).sorted(),
      deliveredParties: (pack.manifest.passengerParties ?? []).filter {
        passengersDelivered($0.id, pack: pack, instance: state, commander: commander)
      }.map(\.id).sorted(),
      returnedEquipment: state.gearIssues.values.filter { $0.status == .returned }.map(\.resource)
        .sorted(), settlementAmount: state.contract?.settlementAmount,
      choices: state.choiceReceipts.isEmpty ? nil : state.choiceReceipts)
  }
  mutating func enqueueScriptCompletion(_ receipt: ScriptCompletionReceipt) throws {
    let dependents = orderedScriptInstances.filter { id in
      guard let state = commander.scriptState.instances[id], state.outcome == .active,
        let pack = scriptPack(for: state)
      else { return false }
      return (pack.manifest.receiptRequirements ?? []).contains { $0.matches(receipt) }
        && pack.manifest.handlers.contains { $0.event == "mission.receipted" }
    }
    guard commander.scriptState.pendingEvents.count + dependents.count <= 4096,
      commander.scriptState.nextEvent < UInt64(Int64.max) - UInt64(dependents.count)
    else { throw MissionPackError("The child completion notification queue is full.") }
    for id in dependents {
      emitScriptEvent(
        "mission.receipted",
        values: [
          "receipt_instance_id": .string(receipt.instance.uuidString),
          "definition": .string(receipt.definition), "version": .string(receipt.version),
          "digest": .string(receipt.digest), "outcome": .string(receipt.outcome.rawValue),
        ], only: id, drain: false)
    }
  }
}
