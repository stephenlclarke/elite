import Foundation

extension Game {
  func applyScriptCommand(
    _ command: ScriptValue, event: ScriptEvent, pack: ScriptPack,
    state: inout ScriptInstance, candidate: inout Commander
  ) throws {
    guard let fields = command.object, let op = fields["op"]?.string else {
      throw MissionPackError("Invalid script command.")
    }
    let fieldsByOp: [String: Set<String>] = [
      "credits": ["op", "id", "amount"], "payload.add": ["op", "id", "key", "amount"],
      "payload.remove": ["op", "id", "key", "amount"], "milestone.ensure": ["op", "index"],
      "journal.append": ["op", "text"], "mission.finish": ["op", "outcome"],
      "dialogue.offer": ["op", "id"], "dialogue.commit": ["op", "id", "token", "choice_id"],
      "timer.ensure": ["op", "id", "domain", "after", "interval", "policy"],
      "timer.cancel": ["op", "id"],
      "timer.counter.ensure": ["op", "id", "name", "enabled"],
      "timer.counter.reset": ["op", "id", "name"],
      "timer.counter.enable": ["op", "id", "name", "enabled"],
    ]
    guard let allowed = fieldsByOp[op], Set(fields.keys).isSubset(of: allowed) else {
      throw MissionPackError("Unsupported script command or field: " + op)
    }
    let capability: String
    switch op {
    case "credits": capability = "economy-v2"
    case "payload.add", "payload.remove": capability = "cargo-v2"
    case "timer.ensure", "timer.cancel": capability = "local-flight-clocks-v2"
    case "timer.counter.ensure", "timer.counter.reset", "timer.counter.enable":
      capability = "pulse-counters-v2"
    default: capability = "story-v2"
    }
    guard pack.manifest.capabilities.contains(capability) else {
      throw MissionPackError("Command requires declared " + capability)
    }
    // Terminal outcomes cannot be revived or paid in a later handler. A source-authorized failed payment may be in this same atomic batch.
    guard state.outcome == .active else {
      throw MissionPackError("Terminal mission cannot issue more actions.")
    }
    func text(_ key: String) throws -> String {
      guard let value = fields[key]?.string else {
        throw MissionPackError("Missing script command field: " + key)
      }
      return value
    }
    func identifier(_ key: String) throws -> String {
      let value = try text(key)
      guard PackValidation.localID(value) else {
        throw MissionPackError("Invalid action identifier.")
      }
      return value
    }
    switch op {
    case "credits", "payload.add", "payload.remove":
      let id = try identifier("id")
      if state.receipts.contains(id) { return }
      guard let amount = fields["amount"]?.integer,
        (-4_294_967_295...4_294_967_295).contains(amount)
      else {
        throw MissionPackError("Action amount is missing or out of range.")
      }
      if op == "credits" {
        let (balance, overflow) = Int64(candidate.credits).addingReportingOverflow(amount)
        guard !overflow, (0...4_294_967_295).contains(balance) else {
          throw MissionPackError("Insufficient credits or reward exceeds balance limit.")
        }
        candidate.credits = Int(balance)
      } else {
        let key = try identifier("key")
        guard (1...1_000_000).contains(amount) else {
          throw MissionPackError("Payload amount must be positive.")
        }
        let held = state.payloads[key, default: 0]
        if op == "payload.add" {
          guard held <= 1_000_000 - Int(amount) else {
            throw MissionPackError("Payload quantity exceeded.")
          }
          state.payloads[key] = held + Int(amount)
        } else {
          guard held >= Int(amount) else {
            throw MissionPackError("Owned mission payload required.")
          }
          state.payloads[key] = held - Int(amount)
        }
      }
      state.receipts.insert(id)
    case "milestone.ensure":
      guard let index = fields["index"]?.integer,
        (0..<Int64(pack.manifest.mission.milestones.count)).contains(index)
      else {
        throw MissionPackError("Invalid story milestone index.")
      }
      state.milestones.insert(Int(index))
    case "journal.append":
      let message = try text("text")
      guard (1...12000).contains(message.utf8.count), state.journal.count < 512 else {
        throw MissionPackError("Journal budget exceeded.")
      }
      state.journal.append(message)
    case "mission.finish":
      guard let outcome = ScriptOutcome(rawValue: try text("outcome")), outcome != .active,
        outcome != .complete
          || (state.milestones.count == pack.manifest.mission.milestones.count
            && (pack.manifest.mission.requiredDestructionEncounters ?? []).allSatisfy {
              state.ownedEncounters[$0]?.destroyed == true
            }
            && (pack.manifest.mission.requiredPassengerParties ?? []).allSatisfy {
              passengersDelivered($0, pack: pack, instance: state, commander: candidate)
            }
            && (pack.manifest.mission.requiredChoiceGroups ?? []).allSatisfy {
              state.choiceReceipts[$0] != nil
            }
            && (pack.manifest.mission.requiredBooks ?? []).allSatisfy {
              let book = candidate.scriptState.books[pack.manifest.id + "/" + $0]
              return book?.version == pack.manifest.version && book?.digest == pack.digest
            }
            && scriptAnswersSatisfied(pack, state: state)
            && state.gearIssues.values.allSatisfy { !$0.loan || $0.status != .issued }
            && (pack.manifest.mission.requiredEquipmentReturns ?? []).allSatisfy {
              state.gearIssues[$0]?.status == .returned
            })
      else {
        throw MissionPackError("Complete every required objective before reporting.")
      }
      if outcome == .complete, let job = state.contract, let due = job.deadline,
        candidate.scriptState.clock(job.clock) >= due
      {
        throw MissionPackError(
          "This contract's deadline has passed; use its declared failure handoff.")
      }
      if outcome == .complete {
        state.receiptJoins = try scriptReceiptJoins(
          pack, stage: .acceptance, existing: state.receiptJoins ?? [:])
        state.receiptJoins = try scriptReceiptJoins(
          pack, stage: .completion, existing: state.receiptJoins ?? [:])
      }
      try settleContract(outcome, state: &state, candidate: &candidate)
      state.outcome = outcome
      state.dialogue = nil
      state.timers = [:]
    case "dialogue.offer":
      let id = try identifier("id")
      guard pack.manifest.dialogs?.contains(where: { $0.id == id }) == true,
        docked, dockedAtMainStation
      else {
        throw MissionPackError("Dialogue requires a declared contact at the orbital station.")
      }
      if let choices = pack.manifest.dialogs?.first(where: { $0.id == id })?.choices,
        choices.contains(where: { $0.group.map { state.choiceReceipts[$0] != nil } ?? false })
      {
        throw MissionPackError("This exclusive station branch has already been chosen.")
      }
      state.dialogue = ScriptDialogue(
        id: id, token: state.id.uuidString + ":" + String(event.sequence) + ":" + id,
        galaxy: candidate.galaxy, system: candidate.system, revision: state.revision + 1)
    case "dialogue.commit":
      let id = try identifier("id")
      let token = try text("token")
      guard event.kind == "dialogue.confirmed", event.values["token"]?.string == token,
        event.values["dialogue_id"]?.string == id, state.dialogue?.id == id,
        state.dialogue?.token == token, state.dialogue?.revision == state.revision,
        state.dialogue?.galaxy == candidate.galaxy, state.dialogue?.system == candidate.system,
        docked, dockedAtMainStation
      else { throw MissionPackError("Stale or invalid dialogue confirmation.") }
      guard let dialogue = pack.manifest.dialogs?.first(where: { $0.id == id }) else {
        throw MissionPackError("The confirmed dialogue is not declared.")
      }
      try commitScriptChoice(fields, event: event, dialogue: dialogue, pack: pack, state: &state)
      state.dialogue = nil
    case "timer.ensure":
      let id = try identifier("id")
      if state.timers[id] != nil { return }
      guard let domain = ScriptClockDomain(rawValue: try text("domain")),
        [.flight, .local].contains(domain)
          || domain == .calendar && pack.manifest.capabilities.contains("calendar-clocks-v2"),
        let policy = ScriptTimerPolicy(rawValue: try text("policy")),
        let after = fields["after"]?.double, (0...1e9).contains(after),
        let interval = fields["interval"]?.double, (0...1e9).contains(interval),
        policy == .once || interval >= 0.001
      else { throw MissionPackError("Invalid timer or unavailable clock domain.") }
      state.timers[id] = ScriptTimer(
        id: id, domain: domain, due: candidate.scriptState.clock(domain) + after,
        interval: interval, policy: policy)
    case "timer.cancel": state.timers.removeValue(forKey: try identifier("id"))
    case "timer.counter.ensure", "timer.counter.reset", "timer.counter.enable":
      let id = try identifier("id")
      let name = try identifier("name")
      guard var timer = state.timers[id] else {
        throw MissionPackError("A named pulse counter requires its existing timer.")
      }
      if op == "timer.counter.ensure" {
        if timer.counters[name] != nil { return }
        guard timer.counters.count < 16 else {
          throw MissionPackError("Pulse counter limit reached.")
        }
        var counter = ScriptPulseCounter()
        if let value = fields["enabled"] {
          guard case .bool(let enabled) = value else {
            throw MissionPackError("Pulse counter enabled must be Boolean.")
          }
          counter.enabled = enabled
        }
        timer.counters[name] = counter
      } else {
        guard var counter = timer.counters[name] else {
          throw MissionPackError("Declare the named pulse counter before changing it.")
        }
        if op == "timer.counter.reset" {
          counter.enabled = true
          counter.resetOnNextPulse = true
        } else {
          guard case .bool(let enabled) = fields["enabled"] else {
            throw MissionPackError("Pulse counter enabled must be Boolean.")
          }
          counter.enabled = enabled
        }
        timer.counters[name] = counter
      }
      state.timers[id] = timer
    default: throw MissionPackError("Unsupported script command.")
    }
  }
}
