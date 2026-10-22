import Foundation

/// Actual fitted-scoop ingress. Serialized facts are joined to both owning records and the retained unit.
struct NativeCrewLogCapture: Codable, Sendable, Equatable {
  let issue: UUID
  let original: UUID
  let job: UUID
  let operation: UUID
  let sequence: UInt64
  let actor: ActorIdentity
  let collector: ActorIdentity
  let carrier: UUID
  let inventoryRevision: UInt64
  let scoop: EquipmentPurchaseItem
  let marker: ScriptOwnedActor
  let capturePoint: Vector3
  let relativeSpeed: Double
  let radius: Double
  let startTime: Double
  let physicalTime: Double
  let flightSeconds: Double
  let epoch: UUID

  static func identity(issue: UUID, original: UUID) -> UUID {
    ScriptIdentity.uuid("induction-original-crew-log-pickup-v1:\(issue):\(original)")
  }

  func sequenced(_ sequence: UInt64) -> Self {
    .init(
      issue: issue, original: original, job: job, operation: operation, sequence: sequence,
      actor: actor, collector: collector, carrier: carrier, inventoryRevision: inventoryRevision,
      scoop: scoop, marker: marker, capturePoint: capturePoint, relativeSpeed: relativeSpeed,
      radius: radius, startTime: startTime, physicalTime: physicalTime,
      flightSeconds: flightSeconds, epoch: epoch)
  }

  static func approachAllowed(point: Vector3, radius: Double, speed: Double) -> Bool {
    let offset = point - Vector3(0, -45, 55)
    return point.finite && point.z > 0 && point.y < 0 && point.length < 85
      && radius.isFinite && radius > 0 && radius <= 16
      && abs(offset.x) + radius <= 16 && abs(offset.y) + radius <= 16
      && abs(offset.z) + radius <= 16 && speed.isFinite
      && speed >= 0 && speed <= ScoopApproachController.maximumRelativeSpeed
  }

  func valid(permission: NativeInductionPermission, reception: NativeInductionSeedReception) -> Bool
  {
    let manifest = NativeInductionCrewLogManifest(permission: permission)
    let logical = NativeInductionCrewLogPack.actor(job: job, role: .recorder)
    guard original == manifest.recorder,
      job == NativeInductionCrewLogPack.instance(recorder: original),
      operation == Self.identity(issue: issue, original: original),
      sequence > reception.sequence, sequence < UInt64(Int64.max),
      actor.system == NativeInductionCrewLogSource.location, actor.entity > 1,
      actor.visit > reception.playerDock.actor.visit,
      collector.system == actor.system, collector.visit == actor.visit, collector.entity == 0,
      inventoryRevision < UInt64(Int64.max),
      scoop.node
        == EquipmentNodeID(
          family: EquipmentRuntimeCatalog.utilityFamily(.fuelScoops), key: "Fuel Scoops"),
      scoop.location
        == EquipmentRuntimeCatalog.purchaseLocation(
          .init(hullInstanceID: carrier, slot: .utility(.fuelScoops))),
      marker.valid, marker.identity == logical, marker.alias == "recorder",
      marker.presence == .present,
      marker.body.missionActorID == logical, marker.body.missionInstanceID == job,
      marker.body.physical?.identity == actor, marker.body.id >= 0,
      marker.body.hull == .cobra, marker.body.energy > 0, !marker.body.hostile,
      marker.body.physical?.population == .mission, marker.body.physical?.npc?.role == .mission,
      marker.body.physical?.empSource == nil, marker.body.physical?.empCrewPod == nil,
      marker.body.physical?.payload == nil, marker.body.physical?.salvage == nil,
      marker.body.physical?.ordnance == nil, marker.body.physical?.rock == nil,
      marker.body.position == capturePoint, marker.body.orientation.validRotation,
      marker.body.scriptNPC?.fit.definition == NativeInductionCrewLogSource.recorderProfile(),
      marker.body.scriptNPC?.fit.models == [
        NativeInductionCrewLogSource.recorderModel: NativeInductionCrewLogSource.recorderGeometry
      ],
      Self.approachAllowed(point: capturePoint, radius: radius, speed: relativeSpeed),
      radius == (try? NativeInductionCrewLogSource.recorderRadius.get()),
      startTime.isFinite, startTime >= reception.physicalTime,
      physicalTime.isFinite, physicalTime > startTime, physicalTime - startTime <= 0.1 + 1e-9,
      physicalTime <= 1e12,
      flightSeconds.isFinite, (reception.flightSeconds...1e12).contains(flightSeconds)
    else { return false }
    return true
  }
}

extension NativeWayfarerInductionState {
  func collectingCrewLog(_ capture: NativeCrewLogCapture, freeTonnes: Int) throws -> Self {
    guard valid, let seedReception, crewLog == nil, crewLogLoss == nil,
      freeTonnes >= 1, capture.valid(permission: permission, reception: seedReception)
    else { throw SaveError.invalidCommander }
    let next = Self(
      permission: permission, crate: crate, loss: loss, reception: reception,
      cassette: cassette, cassetteLoss: cassetteLoss, cassetteService: cassetteService,
      seedKey: seedKey, seedKeyLoss: seedKeyLoss, ark: ark, seedReception: seedReception,
      crewLog: capture)
    guard next.valid else { throw SaveError.invalidCommander }
    return next
  }
}
