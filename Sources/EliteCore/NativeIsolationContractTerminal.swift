import Foundation

enum NativeIsolationContractFailure: Codable, Equatable, Sendable {
  case programmer(UUID)
  case module(NativeIsolationWorkRole, sequence: UInt64)
  case station(NativeMainStationIdentity, sequence: UInt64)
}

struct NativeIsolationContractTerminalFacts: Codable, Equatable, Sendable {
  let parent: UUID
  let authorization: UUID
  let issueOperation: UUID
  let owner: UUID
  let source: UUID
  let outcome: ScriptOutcome
  let sequence: UInt64
  let physicalTime: Double
  let cause: ScriptEventContext
  let dock: NativeMainStationDockReceipt?
  let returnedCommand: UUID?
  let verifications: [UUID]
  let failure: NativeIsolationContractFailure?
}

/// Joins the existing loan, source and settlement; it owns neither cargo nor another cash ledger.
struct NativeIsolationContractTerminal: Codable, Equatable, Sendable {
  let operation: UUID
  let facts: NativeIsolationContractTerminalFacts
  static func identity(_ facts: NativeIsolationContractTerminalFacts) throws -> UUID {
    ScriptIdentity.uuid("g11-isolation-terminal-v1:\(try NativeFlightReception.hash(facts))")
  }
  func shapeValid(proof: NativeIsolationWorkParentState) -> Bool {
    let f = facts
    guard operation == (try? Self.identity(f)), f.parent == proof.parent,
      f.authorization == proof.authorization, f.issueOperation == proof.issue.operation,
      f.owner == proof.owner, f.source == proof.source,
      f.sequence > proof.sequence, f.sequence < UInt64(Int64.max),
      f.physicalTime.isFinite, (proof.physicalTime...1e12).contains(f.physicalTime),
      f.cause.valid, f.cause.calendarSeconds >= proof.acceptance.calendarSeconds,
      [.complete, .abandoned, .failed].contains(f.outcome)
    else { return false }
    switch f.outcome {
    case .complete:
      return f.failure == nil && f.returnedCommand != nil && f.dock != nil
        && f.verifications.count == 2 && Set(f.verifications).count == 2
    case .abandoned:
      return f.failure == nil && f.verifications.isEmpty
        && (f.returnedCommand == nil) == (f.dock == nil)
    case .failed:
      return f.failure != nil && f.verifications.isEmpty && f.returnedCommand == nil
        && f.dock == nil
    case .active: return false
    }
  }
}

enum NativeIsolationContractSave {
  /// Called after historical provider validation. This join never feeds back into its primitive.
  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    let engine = commander.scriptState
    let time = commander.flightSimulation.physicalTime
    for parent in engine.instances.values where NativeIsolationWorkParent.marked(parent) {
      guard let proof = parent.savedIsolationWorkParent else { return false }
      guard let terminal = proof.terminal else {
        guard parent.outcome == .active, parent.completionReceipt == nil,
          parent.contract?.settled == false
        else { return false }
        continue
      }
      let f = terminal.facts
      guard terminal.shapeValid(proof: proof), parent.outcome == f.outcome,
        f.sequence <= engine.nextEvent, parent.hasAcknowledged(f.sequence), f.physicalTime <= time,
        let child = engine.instances[NativeIsolationWorkPack.instance(source: proof.source)],
        let source = child.savedIsolationWork, source.permission.parent == parent.id,
        let job = parent.contract, job.settled, job.settlementOutcome == f.outcome,
        job.settlementAmount == (f.outcome == .complete ? 9700 : 0),
        let receipt = parent.completionReceipt, receipt.valid(for: parent, engine: engine),
        receipt.sequence == f.sequence, receipt.cause == f.cause,
        receipt.causeKind == "mission.receipted", receipt.destroyedEncounters.isEmpty,
        receipt.deliveredParties.isEmpty,
        parent.milestones == (f.outcome == .complete ? [0, 1, 2] : [0])
      else { return false }
      if let dock = f.dock {
        guard dock.station == proof.acceptance.station,
          NativeStationPassengerJourney.historicalDock(dock, commander: commander),
          f.cause.nativeMainDock == dock
        else { return false }
      }
      if let returned = f.returnedCommand {
        guard case .returned(let cutoff)? = proof.cutoff,
          returned == cutoff.operation, cutoff.dock == f.dock,
          cutoff.sequence < f.sequence, cutoff.physicalTime <= f.physicalTime
        else { return false }
      }
      if f.outcome == .complete {
        guard
          source.stationLoss.map({ $0.sequence > f.sequence && $0.physicalTime >= f.physicalTime })
            ?? true,
          source.modules.allSatisfy({
            $0.loss.map { $0.sequence > f.sequence && $0.physicalTime >= f.physicalTime } ?? true
          }),
          let dock = f.dock, dock.sequence > proof.acceptance.sequence,
          dock.actor.visit > proof.acceptance.actor.visit,
          f.verifications == source.modules.compactMap({ $0.verification?.operation }),
          source.modules.allSatisfy({
            guard let verification = $0.verification else { return false }
            return verification.sequence < f.sequence && verification.last.end <= f.physicalTime
              && verification.authority.parent == parent.id
              && verification.authority.issueOperation == proof.issue.operation
          })
        else { return false }
      } else if let failure = f.failure {
        switch failure {
        case .programmer(let operation):
          guard case .lost(let loss)? = proof.cutoff,
            loss.operation == operation, loss.facts.sequence < f.sequence,
            loss.facts.physicalTime <= f.physicalTime
          else { return false }
        case .module(let role, let sequence):
          guard let loss = source.modules.first(where: { $0.role == role })?.loss,
            loss.sequence == sequence, sequence < f.sequence, loss.physicalTime <= f.physicalTime
          else { return false }
        case .station(let station, let sequence):
          guard let loss = source.stationLoss, loss.station == station,
            loss.sequence == sequence, sequence < f.sequence, loss.physicalTime <= f.physicalTime
          else { return false }
        }
      }
    }
    return true
  }
}
