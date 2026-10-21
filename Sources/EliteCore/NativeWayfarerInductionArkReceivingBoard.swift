import Foundation

extension Game {
  func inductionArkReceivingIssues() -> [String] {
    guard let parent = wayfarerInductionMission, parent.suspension == nil,
      parent.outcome == .active, let leaf = parent.savedWayfarerInduction,
      let key = leaf.seedKey, leaf.seedKeyLoss == nil, leaf.seedReception == nil,
      let link = leaf.ark, let child = commander.scriptState.instances[link.job],
      child.suspension == nil, let state = child.savedNativeArk, state.loss == nil,
      state.reception == nil, state.fuel.closure == nil,
      leaf.payloads == [NativeWayfarerInduction.keyPayload: 1],
      key.unit == NativeWayfarerInduction.vaultKeyUnit(owner: leaf.permission.owner)
    else {
      return [
        "The same original ark, living crew, seed stock and unreturned original key are required."
      ]
    }
    guard let contact = state.dockedContact,
      contact.station.system == NativeWayfarerInduction.seedReceiver,
      contact.ark == link.registeredArk,
      NativeInductionArkSave.allHopsReceived(state, engine: commander.scriptState)
    else {
      return [
        "The original registered ark must complete every actual native hop and enter Lareria's real receiving berth."
      ]
    }
    guard NativeInductionArkSave.validateClaims(commander),
      let dock = commander.nativeStations?.currentMainDock,
      nativeMainStationDockEvidenceIsCurrent, dock.station == contact.station,
      case .living(let facility) = nativeOriginalMainStationDestination,
      facility.identity == contact.station, facility.observation.actor == dock.actor
    else {
      return [
        "Dock your actual key carrier at Lareria's same living main-orbital cradle and review again."
      ]
    }
    return []
  }

  mutating func confirmInductionArkReceiving(
    dock: NativeMainStationDockReceipt, carrier: UUID, revision: UInt64
  ) throws {
    guard inductionArkReceivingIssues().isEmpty, nativeMainStationDockEvidenceIsCurrent,
      commander.nativeStations?.currentMainDock == dock,
      commander.hullInstanceID == carrier, commander.equipmentInventory?.revision == revision,
      var parent = wayfarerInductionMission, let leaf = parent.savedWayfarerInduction,
      let key = leaf.seedKey, let link = leaf.ark,
      var child = commander.scriptState.instances[link.job], let state = child.savedNativeArk,
      let contact = state.dockedContact, parent.revision < UInt64(Int64.max) - 1,
      child.revision < UInt64(Int64.max) - 1,
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let time = commander.flightSimulation.physicalTime
    let sequence = commander.scriptState.nextEvent + 1
    let operation = try NativeInductionSeedReception.identity(
      link: link, arkDock: contact, playerDock: dock, carrier: carrier,
      revision: revision, physicalTime: time, seeds: state.authorization.seeds,
      crew: state.authorization.crew)
    let receipt = NativeInductionSeedReception(
      operation: operation, sequence: sequence, owner: state.authorization.owner,
      parent: parent.id, job: child.id, registeredArk: state.authorization.registeredArk,
      loanOperation: key.operation, keyUnit: key.unit, target: key.receivingTarget,
      arkDock: contact, playerDock: dock, carrier: carrier, inventoryRevision: revision,
      physicalTime: time, flightSeconds: commander.scriptState.flightSeconds,
      seeds: state.authorization.seeds, crew: state.authorization.crew)
    let nextParent = try leaf.receivingSeedArk(receipt)
    let bank = try state.fuel.closing(at: receipt)
    let nextArk = state.replacing(fuel: bank, clearsServiceWait: true, reception: receipt)
    guard let service = leaf.cassetteService,
      nextArk.shapeValid(
        source: try NativeInductionArkSource(
          loan: key, permission: leaf.permission, service: service), key: key)
    else { throw SaveError.invalidCommander }
    parent.savedWayfarerInduction = nextParent
    parent.payloads = nextParent.payloads
    parent.milestones = nextParent.milestones
    parent.revision += 1
    parent.acknowledge(sequence)
    parent.journal.append(
      "Lareria's actual cradle received all forty original custodian seed-tonne units with the six original crew alive and returned the original loaned vault key. Stage7 is recorded; no payment, clue or accreditation. Later recorder recovery remains unavailable."
    )
    child.savedNativeArk = nextArk
    child.milestones.insert(0)
    child.revision += 1
    child.acknowledge(sequence)
    child.journal.append(
      "Original seed consignment received at its actual Lareria berth. Original key returned; unused fuel escrow returned to its custodian. The original ark remains in facility custody; no player reward or replacement issue."
    )
    commander.scriptState.nextEvent = sequence
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.instances[child.id] = child
    notify("ORIGINAL SEED ARK RECEIVED - ORIGINAL VAULT KEY RETURNED")
  }
}
