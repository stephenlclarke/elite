import Foundation

extension ScriptPackLibrary {
  static func validateProviderContract(_ manifest: ScriptManifest) throws {
    guard let definition = manifest.providerContract else {
      guard !manifest.handlers.contains(where: { $0.event.hasPrefix("provider.") }) else {
        throw MissionPackError("Provider events require a provider contract.")
      }
      return
    }
    guard definition.valid, manifest.capabilities.contains("ordinary-provider-dispatch-v1"),
      manifest.capabilities.contains("story-v2"),
      manifest.capabilities.contains("durable-commands-v2"),
      manifest.capabilities.contains("cargo-v2"), manifest.mission.milestones.count == 1,
      manifest.board == nil, manifest.courier == nil, manifest.pledge == nil,
      manifest.trial == nil, manifest.mission.parentOnly != true,
      [
        manifest.encounters?.count, manifest.npcs?.count, manifest.equipment?.count,
        manifest.children?.count, manifest.worldJobs?.count, manifest.loans?.count,
        manifest.collections?.count, manifest.books?.count,
        manifest.mission.requiredDestructionEncounters?.count,
        manifest.mission.requiredPassengerParties?.count,
        manifest.mission.requiredEquipmentReturns?.count,
        manifest.mission.requiredChoiceGroups?.count, manifest.mission.requiredBooks?.count,
        manifest.mission.requiredCollections?.count, manifest.answerRequirements?.count,
        manifest.receiptRequirements?.count, manifest.passengerParties?.count,
      ].allSatisfy({ ($0 ?? 0) == 0 }),
      manifest.handlers.allSatisfy({
        ["mission.accepted", "provider.transition", "provider.closed"].contains($0.event)
      })
    else {
      throw MissionPackError("Provider contracts use native custody and presentation-only scripts.")
    }
  }
}

extension Game {
  func providerMissionQuery(_ instance: ScriptInstance) -> ScriptValue {
    guard let state = instance.savedProviderContract else { return .null }
    return .object([
      "stage": .string(state.stage.rawValue),
      "branch": state.branch.map { .string($0.rawValue) } ?? .null,
      "manifest": .bool(state.manifest != nil),
      "checkpoints": .integer(Int64(state.progress.checkpointBits)),
      "core": .bool(state.core != nil), "crew": .bool(state.crew != nil),
      "crew_paid": .bool(state.crew?.disposition == .paid),
      "crew_eligible_pending": .bool(state.owedCrewReward > 0),
      "betrayed": .bool(state.betrayal != nil),
      "custody": .string(state.custody.rawValue), "base_paid": .integer(Int64(state.basePaid)),
    ])
  }

  func providerGalleryPageFacts(_ instance: ScriptInstance?) -> [String] {
    guard let instance, let state = instance.savedProviderContract else { return [] }
    return [
      state.provider.incarnation.uuidString, state.subject.uuidString,
      state.stage.rawValue, state.branch?.rawValue ?? "", state.custody.rawValue,
      String(state.progress.checkpointBits), state.manifest?.identity.uuidString ?? "",
      state.pending?.token.uuidString ?? "", state.pending?.runtimeEpoch.uuidString ?? "",
      state.crew?.disposition.rawValue ?? "", String(state.basePaid), String(state.crewPaid),
    ]
  }

  func providerGalleryEntry(_ pack: ScriptPack, state instance: ScriptInstance?) -> GalleryMission {
    let state = instance?.savedProviderContract
    let unavailable =
      instance?.suspension ?? scriptUnavailable(pack)
      ?? (state == nil ? providerPresentationReason(pack.manifest.stateID) : nil)
    let status: GalleryStatus
    switch instance?.outcome {
    case .complete: status = .complete
    case .failed, .abandoned: status = .failed
    case .active: status = .active
    case nil: status = unavailable == nil ? .available : .locked
    }
    var milestones = [
      MissionMilestone(
        title: "Accepted the identified 1t relay", state: state == nil ? "Upcoming" : "Complete"),
      .init(
        title: "Authenticated original dispatch manifest",
        state: state?.manifest == nil ? "Upcoming" : "Complete"),
    ]
    let indices =
      pack.manifest.providerContract.map { Array($0.observation.checkpoints.indices) } ?? []
    for index in indices {
      let done = state.map { $0.progress.checkpointBits & (1 << index) != 0 } ?? false
      milestones.append(
        .init(
          title: "Optional calibration check \(index + 1)", state: done ? "Complete" : "Optional"))
    }
    milestones += [
      .init(
        title: "One dispatch branch authorized",
        state: state?.branch.map { "Complete (" + $0.rawValue + ")" } ?? "Upcoming"),
      .init(
        title: "Optional original computer core recovery",
        state: state?.core == nil ? "Optional" : "Complete"),
      .init(
        title: "Optional original crew safely transferred",
        state: state?.crew == nil ? "Optional" : "Complete"),
      .init(
        title: "Actual receiving station handoff",
        state: state?.stage == .completed ? "Complete" : "Upcoming"),
    ]
    var summary = providerGallerySummary(state)
    if let presentation = gallery.providerPresentations.first(where: {
      $0.definition == pack.manifest.stateID
    }) {
      summary.append(presentation.status)
    }
    return .init(
      name: pack.manifest.mission.title, status: status,
      objective: unavailable ?? summary.first ?? pack.manifest.mission.briefing,
      briefing: pack.manifest.mission.briefing + "\n\n" + summary.joined(separator: "\n"),
      destination: pack.manifest.mission.destination, reward: pack.manifest.mission.reward,
      prerequisites: unavailable.map { [$0] } ?? [],
      completed: milestones.filter { $0.state.hasPrefix("Complete") }.count,
      milestones: milestones, trialDigest: nil, savedInstance: instance?.id)
  }

  private func providerGallerySummary(_ state: ScriptProviderContractState?) -> [String] {
    guard let state else {
      return ["Accept at the origin station after reviewing the complete contract."]
    }
    var rows = [
      "Relay: \(state.custody.rawValue). Dispatch: \(state.branch?.rawValue ?? "pending")."
    ]
    if state.betrayal != nil {
      rows.append(
        "Convoy betrayal: all unpaid rewards void. Return the held relay for zero base payment.")
    } else if state.custody == .lost {
      rows.append(
        state.stage.terminal
          ? "The original relay was genuinely lost. Contract failed."
          : "The relay is genuinely lost. An earned crew payment or content restoration keeps closure pending."
      )
    } else if state.manifest == nil {
      rows.append(
        String(
          format: "Request manifest, then maintain actual contact for %.1f seconds.",
          state.terms.observation.contactSeconds))
    } else if state.branch == nil {
      rows.append(
        String(
          format: "Actual calibration: %.0f / %.0f metres; %.1f / %.1f qualified seconds.",
          state.progress.distanceMeters, state.terms.observation.maximumDistance,
          state.progress.escortSeconds, state.terms.observation.escortSeconds))
      rows.append(
        "Urgent dispatch is an explicit irreversible alternative. Original core or original crew care can recover dispatch."
      )
    }
    if state.stage == .crisis {
      rows.append(
        "Original provider unavailable for calibration. Wait for the same incarnation to recover, review urgent dispatch if a manifest is held, recover authentic source evidence, or return the held relay."
      )
    }
    if state.pending?.action == .confirmUrgent {
      if state.pending?.runtimeEpoch == nativeStationRuntimeEpoch {
        rows.append(
          String(
            format: "URGENT REVIEW: fix the base reward at %.1f CR. C: confirm; B: back.",
            Double(state.terms.urgentReward) / 10))
      } else {
        rows.append("Urgent review expired. U: review again; B: back.")
      }
    }
    if let crew = state.crew { rows.append("Crew commendation: \(crew.disposition.rawValue).") }
    rows.append(
      String(
        format: "Paid: %.1f CR base; %.1f CR crew. No deadline.", Double(state.basePaid) / 10,
        Double(state.crewPaid) / 10))
    rows.append("Trial unavailable until actual native provider isolation is verified.")
    return rows
  }
}
