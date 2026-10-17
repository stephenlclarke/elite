import Foundation

struct NativeProviderIdentity: Hashable, Codable, Sendable {
  let definition: String
  let system: SystemIdentity
  let incarnation: UUID
  var valid: Bool {
    PackValidation.localID(definition) && (0..<8).contains(system.galaxy)
      && (0...256).contains(system.system)
  }
}

struct NativeProviderManifest: Equatable, Codable, Sendable {
  let identity: UUID
  let revision: UInt64
  let provider: NativeProviderIdentity
  let subject: UUID
  var valid: Bool { provider.valid && revision > 0 && revision < UInt64(Int64.max) }
}

enum NativeProviderAvailability: String, Codable, Sendable {
  case tracking, defending, disabled, uncrewed, unloaded, destroyed, ended
}

/// Causal native order is supplied by the native owner, never synthesized from unrelated ledgers.
struct NativeProviderCoreClaim: Equatable, Codable, Sendable {
  let operation: UUID
  let provider: NativeProviderIdentity
  let subject: UUID
  let manifest: NativeProviderManifest
  let lot: SalvageLotIdentity
  let settlement: UUID?
  let owner: UUID
  let order: UInt64
}

struct NativeProviderPersonOperation: Equatable, Codable, Sendable {
  let operation: UUID
  let source: ActorIdentity
  let order: UInt64
}

struct NativeProviderBetrayal: Equatable, Codable, Sendable {
  let provider: NativeProviderIdentity
  let member: UUID
  let incident: CombatIncident?
  let personSale: UUID?
  let order: UInt64
  var valid: Bool {
    provider.valid && order > 0 && order < UInt64(Int64.max)
      && ((incident == nil) != (personSale == nil))
      && (incident.map {
        $0.id > 0 && $0.origin.owner.entity == 0 && $0.origin.emissionID > 0
          && $0.position.finite && $0.physicalTime.isFinite && !$0.victimIsStation
      } ?? true)
  }
}

enum ProviderRelayCustody: String, Codable, Sendable {
  case aboard, world, unavailable, delivered, returned, lost
}

struct NativeProviderRelayObservation: Equatable, Sendable {
  let instance: UUID
  let item: UUID
  let custody: ProviderRelayCustody
  let worldPayload: PayloadIdentity?
  let order: UInt64
}

/// Non-Codable producer input. G1 must resolve these facts from its actual provider and ledgers.
struct NativeProviderMissionSource: Sendable {
  let provider: NativeProviderIdentity
  let subject: UUID
  let currentBinding: ActorIdentity?
  let manifest: NativeProviderManifest
  let origin: NativeMainStationIdentity
  let destination: NativeMainStationIdentity
  let available: NativeProviderAvailability
  let operationsReady: Set<String>
  let routeAvailable: Bool
  let playerThreat: Bool
  let currentOrder: UInt64
  let interval: ProviderMissionInterval?
  let core: NativeProviderCoreClaim?
  let personOperations: [NativeProviderPersonOperation]
  let betrayal: NativeProviderBetrayal?
  let relay: NativeProviderRelayObservation?
}

/// Live actor-scoped proof. Neither decoded mission data nor Lua can construct this authority.
struct NativeProviderMissionFacts: Sendable {
  let source: NativeProviderMissionSource
  let commanderOwner: UUID
  let player: ActorIdentity
  let runtimeEpoch: UUID
  let gameplayRevision: UInt64
  let physicalTime: Double

  fileprivate init(
    source: NativeProviderMissionSource, owner: UUID, player: ActorIdentity,
    epoch: UUID, revision: UInt64, time: Double
  ) {
    self.source = source
    commanderOwner = owner
    self.player = player
    runtimeEpoch = epoch
    gameplayRevision = revision
    physicalTime = time
  }
}

extension Game {
  /// Native integration calls this only with an actually resolved ordinary-provider source.
  /// This factory checks the current physical binding; it does not create a provider or its IDs.
  func resolveProviderMissionFacts(_ source: NativeProviderMissionSource) throws
    -> NativeProviderMissionFacts
  {
    guard source.provider.valid, source.manifest.valid,
      source.manifest.provider == source.provider, source.manifest.subject == source.subject,
      source.origin.valid, source.destination.valid,
      source.origin.system == source.provider.system,
      source.currentOrder > 0, source.currentOrder < UInt64(Int64.max),
      source.operationsReady.count <= 16, source.personOperations.count <= EMPState.maximumPeople,
      Set(source.personOperations.map(\.operation)).count == source.personOperations.count,
      source.personOperations.allSatisfy({ $0.order > 0 && $0.order <= source.currentOrder }),
      source.core.map({ $0.order > 0 && $0.order <= source.currentOrder }) ?? true,
      source.betrayal.map({ $0.valid && $0.order <= source.currentOrder }) ?? true,
      let owner = commander.equipmentOwnerID, let player = commander.flightSimulation.player,
      source.origin.world == owner, source.destination.world == owner,
      commander.flightSimulation.physicalTime.isFinite
    else { throw MissionPackError("Unresolved ordinary provider mission facts.") }
    if [.tracking, .defending, .disabled, .uncrewed].contains(source.available) {
      guard let actor = source.currentBinding,
        actor.system == source.provider.system, actor.system == player.system,
        actor.visit == player.visit, actor.entity > 1,
        bodies.filter({ $0.physical?.identity == actor }).count == 1,
        let body = bodies.first(where: { $0.physical?.identity == actor }), body.energy > 0,
        body.missionActorID == nil, body.missionInstanceID == nil, body.scriptNPC == nil,
        body.physical?.npc != nil, body.physical?.npc?.role != .mission,
        ![.tracking, .defending].contains(source.available) || !isEMPDisabled(body),
        source.available != .disabled || isEMPDisabled(body)
      else { throw MissionPackError("The provider's current ordinary actor is unavailable.") }
    }
    return .init(
      source: source, owner: owner, player: player, epoch: nativeStationRuntimeEpoch,
      revision: gameplayRevision, time: commander.flightSimulation.physicalTime)
  }

  func acceptsProviderMissionFacts(_ facts: NativeProviderMissionFacts) -> Bool {
    facts.commanderOwner == commander.equipmentOwnerID
      && facts.player == commander.flightSimulation.player
      && facts.runtimeEpoch == nativeStationRuntimeEpoch
      && facts.gameplayRevision == gameplayRevision
      && facts.physicalTime == commander.flightSimulation.physicalTime
      && (try? resolveProviderMissionFacts(facts.source)) != nil
  }
}
