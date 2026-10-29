import Foundation

extension Game {
  /// Return is contextual maintenance Confirm only for an explicitly selected authorized handoff.
  mutating func handleInductionUtilityWorkKey(_ key: String) -> Bool {
    let hasAction =
      inductionUtilityWorkRuntime.review != nil || inductionUtilityWorkRuntime.arm != nil
    if hasAction && ["escape", "k", "pause", "pause-toggle"].contains(key) {
      interruptInductionUtilityWork()
      if key == "escape" { return true }
    }
    guard key == "return", inductionUtilityUsesReturn else { return false }
    if let review = inductionUtilityWorkRuntime.review {
      do { try confirmInductionUtilityWork(review) } catch {
        inductionUtilityWorkRuntime.review = nil
        notify("ENRON CONTACT OR TERMS CHANGED - SELECT AND REVIEW AGAIN")
      }
      return true
    }
    guard let body = inductionUtilityContactBody, let role = inductionUtilityRole(body),
      let actor = body.physical?.identity, let child = inductionUtilityChild,
      let module = child.savedNativeInductionUtility?.modules.first(where: { $0.role == role }),
      module.work?.repair == nil,
      let carrier = commander.hullInstanceID, let revision = commander.equipmentInventory?.revision,
      scriptDurabilityAvailable
    else {
      notify("HANDOFF WORKING OR UNAVAILABLE - ENRON RECEIVES ALL THREE REPAIRS")
      return true
    }
    interruptFlightTool()
    inductionUtilityWorkRuntime.contact = actor
    inductionUtilityWorkRuntime.review = .init(
      nonce: UUID(), job: child.id,
      revision: child.revision, role: role, actor: actor, carrier: carrier,
      inventoryRevision: revision, epoch: nativeStationRuntimeEpoch)
    inductionUtilityWorkRuntime.reason =
      "RETURN CONFIRMS ARMING / ESC CANCELS. 20s measured work; one local crew kit only on actual repair."
    return true
  }

  private mutating func confirmInductionUtilityWork(_ quote: NativeInductionUtilityWorkReview)
    throws
  {
    guard !paused, !docked, screen == .front, scriptDurabilityAvailable, energy > 0,
      !playerEMPDisabled,
      quote.epoch == nativeStationRuntimeEpoch, quote.carrier == commander.hullInstanceID,
      quote.inventoryRevision == commander.equipmentInventory?.revision,
      let body = inductionUtilityContactBody, inductionUtilityRole(body) == quote.role,
      body.physical?.identity == quote.actor,
      let binding = inductionUtilityBinding(for: body, role: quote.role),
      let player = commander.flightSimulation.player, var child = inductionUtilityChild,
      child.id == quote.job, child.revision == quote.revision,
      var state = child.savedNativeInductionUtility,
      let index = state.modules.firstIndex(where: { $0.role == quote.role }),
      state.modules[index].availableKits == 1, state.modules[index].work?.repair == nil,
      var parent = wayfarerInductionMission, let leaf = parent.savedWayfarerInduction,
      child.revision < UInt64(Int64.max) - 1, parent.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let source = try NativeInductionUtilitySource(parent: leaf)
    let sequence = commander.scriptState.nextEvent + 1
    let time = commander.flightSimulation.physicalTime
    let clock = commander.scriptState.flightSeconds
    let operation = try NativeInductionUtilityArm.identity(
      authorization: state.authorization.operation,
      role: quote.role, actor: quote.actor, player: player, carrier: quote.carrier,
      revision: quote.inventoryRevision, epoch: quote.epoch, time: time, flightSeconds: clock,
      sequence: sequence, binding: binding)
    let arm = NativeInductionUtilityArm(
      operation: operation, sequence: sequence,
      authorization: state.authorization.operation, owner: source.owner, job: child.id,
      role: quote.role, module: source.module(quote.role), kit: source.kit(quote.role),
      actor: quote.actor, player: player, carrier: quote.carrier,
      inventoryRevision: quote.inventoryRevision, epoch: quote.epoch,
      physicalTime: time, flightSeconds: clock, binding: binding)
    var work = state.modules[index].work ?? .init()
    // Empty arm/review attempts consume no bounded work-history slot or kit.
    if work.segments.last?.intervals == 0 { work.segments.removeLast() }
    guard work.segments.count < NativeInductionUtilityWork.maximumSegments else {
      throw SaveError.invalidCommander
    }
    work.segments.append(.init(arm: arm))
    state.modules[index].work = work
    guard state.shapeValid(parent: leaf) else { throw SaveError.invalidCommander }
    child.savedNativeInductionUtility = state
    child.revision += 1
    child.acknowledge(sequence)
    parent.revision += 1
    parent.acknowledge(sequence)
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.instances[child.id] = child
    cancelAutoTarget()
    interruptFlightTool()
    inductionUtilityWorkRuntime.contact = quote.actor
    inductionUtilityWorkRuntime.arm = arm
    inductionUtilityWorkRuntime.reason =
      "ARMED: front surface50-150m / relative speed<=1m/s / aim<=2deg. Return is maintenance, Q/ESC stops."
    notify("ENRON " + quote.role.rawValue.uppercased() + " MAINTENANCE ARMED - NO KIT SPENT")
  }
}
