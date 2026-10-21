import Foundation

/// One atomic receiving/key-return record; arrays name the original units, never new stock.
struct NativeInductionSeedReception: Codable, Sendable, Equatable {
  let operation: UUID
  let sequence: UInt64
  let owner: UUID
  let parent: UUID
  let job: UUID
  let registeredArk: UUID
  let loanOperation: UUID
  let keyUnit: UUID
  let target: String
  let arkDock: NativeArkFuelContact
  let playerDock: NativeMainStationDockReceipt
  let carrier: UUID
  let inventoryRevision: UInt64
  let physicalTime: Double
  let flightSeconds: Double
  let seeds: [UUID]
  let crew: [UUID]

  func valid(key: NativeInductionVaultKeyLoan, link: NativeInductionArkLink) -> Bool {
    guard sequence > 0, sequence < UInt64(Int64.max), owner == key.dock.commanderOwner,
      parent == key.source.mission, job == link.job, registeredArk == link.registeredArk,
      loanOperation == key.operation, loanOperation == link.loanOperation, keyUnit == key.unit,
      target == key.receivingTarget, target == NativeWayfarerInduction.seedReceivingTarget,
      playerDock.valid, playerDock.commanderOwner == owner,
      playerDock.station.system == key.receiver, playerDock.station.world == owner,
      playerDock.sequence > key.dock.sequence, playerDock.actor.visit > key.dock.actor.visit,
      playerDock.calendarSeconds >= key.dock.calendarSeconds,
      arkDock.valid, arkDock.mission == parent, arkDock.ark == registeredArk,
      arkDock.station == playerDock.station, arkDock.stationActor.visit <= playerDock.actor.visit,
      inventoryRevision < UInt64(Int64.max), physicalTime.isFinite,
      physicalTime >= arkDock.physicalTime, physicalTime >= key.physicalTime, physicalTime <= 1e12,
      flightSeconds.isFinite, flightSeconds >= key.flightSeconds, flightSeconds <= 1e12,
      seeds.count == 40, Set(seeds).count == 40, crew.count == 6, Set(crew).count == 6,
      Set(seeds).isDisjoint(with: crew), !seeds.contains(keyUnit), !crew.contains(keyUnit)
    else { return false }
    return operation
      == (try? Self.identity(
        link: link, arkDock: arkDock, playerDock: playerDock, carrier: carrier,
        revision: inventoryRevision, physicalTime: physicalTime, seeds: seeds, crew: crew))
  }
  static func identity(
    link: NativeInductionArkLink, arkDock: NativeArkFuelContact,
    playerDock: NativeMainStationDockReceipt, carrier: UUID, revision: UInt64,
    physicalTime: Double, seeds: [UUID], crew: [UUID]
  ) throws -> UUID {
    ScriptIdentity.uuid(
      "native-ark-reception-v1:\(link.operation):\(try NativeFlightReception.hash(arkDock)):\(try NativeFlightReception.hash(playerDock)):\(carrier):\(revision):\(physicalTime.bitPattern):\(try NativeFlightReception.hash(seeds)):\(try NativeFlightReception.hash(crew))"
    )
  }
}

struct NativeArkFuelClosure: Codable, Sendable, Equatable {
  let operation: UUID
  let receivingOperation: UUID?
  let recoveryOperation: UUID?
  let recipient: UUID
  let balanceBefore: Int
  let returnedCredits: Int
  init(
    operation: UUID, receivingOperation: UUID? = nil, recoveryOperation: UUID? = nil,
    recipient: UUID, balanceBefore: Int, returnedCredits: Int
  ) {
    self.operation = operation
    self.receivingOperation = receivingOperation
    self.recoveryOperation = recoveryOperation
    self.recipient = recipient
    self.balanceBefore = balanceBefore
    self.returnedCredits = returnedCredits
  }
  static func recoveryIdentity(ark: UUID, recovery: UUID, credits: Int) -> UUID {
    ScriptIdentity.uuid("native-ark-escrow-retirement-v1:\(ark):\(recovery):\(credits)")
  }
  static func custodian(owner: UUID) -> UUID {
    ScriptIdentity.uuid("induction-seed-custodians-v1:\(owner):0:162")
  }
  static func identity(ark: UUID, receiving: UUID, credits: Int) -> UUID {
    ScriptIdentity.uuid("native-ark-escrow-return-v1:\(ark):\(receiving):\(credits)")
  }
}

extension NativeWayfarerInductionState {
  func receivingSeedArk(_ receipt: NativeInductionSeedReception) throws
    -> NativeWayfarerInductionState
  {
    guard valid, let key = seedKey, seedKeyLoss == nil, let ark,
      seedReception == nil, receipt.valid(key: key, link: ark)
    else { throw SaveError.invalidCommander }
    let next = NativeWayfarerInductionState(
      permission: permission, crate: crate, reception: reception, cassette: cassette,
      cassetteService: cassetteService, seedKey: key, ark: ark, seedReception: receipt)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }
}

extension NativeInductionArkSave {
  static func allHopsReceived(_ state: NativeInductionArkState, engine: borrowing ScriptEngineState)
    -> Bool
  {
    for hop in state.authorization.route.legDistancesLY.indices {
      guard let reference = state.legs.last(where: { $0.hop == hop }),
        let leg = engine.wormholeTransit?.legs[reference.leg], leg.valid, leg.phase == .arrived,
        leg.instance == state.authorization.job, leg.actor == state.authorization.actor,
        leg.encounter == NativeInductionArkPack.encounter,
        leg.alias == NativeInductionArkPack.alias,
        leg.arrival != nil, leg.request == reference.request,
        leg.route?.origin.worldID == state.authorization.route.worldKeys[hop],
        leg.route?.distanceLightYears == state.authorization.route.legDistancesLY[hop],
        leg.destinationWorld == state.authorization.route.worldKeys[hop + 1]
      else { return false }
    }
    return state.legs.last?.hop == state.authorization.route.legDistancesLY.count - 1
  }

  static func receivingClaimsValid(
    _ state: NativeInductionArkState,
    parent: borrowing ScriptInstance, child: borrowing ScriptInstance,
    engine: borrowing ScriptEngineState
  ) -> Bool {
    guard let receipt = state.reception else { return true }
    guard allHopsReceived(state, engine: engine), receipt.sequence <= engine.nextEvent,
      parent.hasAcknowledged(receipt.sequence), child.hasAcknowledged(receipt.sequence),
      receipt.physicalTime >= state.authorization.physicalTime,
      receipt.flightSeconds <= engine.flightSeconds,
      receipt.playerDock.station == state.dockedContact?.station
    else { return false }
    return true
  }
}
