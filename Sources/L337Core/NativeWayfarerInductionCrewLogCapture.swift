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

  /// Keep large marker/physical/NPC optionals in separate borrowed validation frames.
  @inline(never)
  func valid(
    permission: borrowing NativeInductionPermission,
    reception: borrowing NativeInductionSeedReception
  ) -> Bool {
    guard Self.identityValid(self, permission: permission, reception: reception) else {
      return false
    }
    guard Self.markerValid(self) else { return false }
    guard Self.nativeMarkerValid(marker, actor: actor) else { return false }
    guard Self.fittedMarkerValid(marker) else { return false }
    return Self.ingressValid(self, reception: reception)
  }

  @inline(never)
  private static func identityValid(
    _ capture: borrowing NativeCrewLogCapture,
    permission: borrowing NativeInductionPermission,
    reception: borrowing NativeInductionSeedReception
  ) -> Bool {
    let manifest = NativeInductionCrewLogManifest(permission: copy permission)
    guard capture.original == manifest.recorder,
      capture.job == NativeInductionCrewLogPack.instance(recorder: capture.original),
      capture.operation == Self.identity(issue: capture.issue, original: capture.original),
      capture.sequence > reception.sequence, capture.sequence < UInt64(Int64.max),
      capture.actor.system == NativeInductionCrewLogSource.location, capture.actor.entity > 1,
      capture.actor.visit > reception.playerDock.actor.visit,
      capture.collector.system == capture.actor.system,
      capture.collector.visit == capture.actor.visit,
      capture.collector.entity == 0, capture.inventoryRevision < UInt64(Int64.max),
      capture.scoop.node
        == EquipmentNodeID(
          family: EquipmentRuntimeCatalog.utilityFamily(.fuelScoops), key: "Fuel Scoops"),
      capture.scoop.location
        == EquipmentRuntimeCatalog.purchaseLocation(
          .init(hullInstanceID: capture.carrier, slot: .utility(.fuelScoops)))
    else { return false }
    return true
  }

  @inline(never)
  private static func markerValid(_ capture: borrowing NativeCrewLogCapture) -> Bool {
    let logical = NativeInductionCrewLogPack.actor(job: capture.job, role: .recorder)
    guard capture.marker.valid, capture.marker.identity == logical,
      capture.marker.alias == "recorder",
      capture.marker.presence == .present, capture.marker.body.missionActorID == logical,
      capture.marker.body.missionInstanceID == capture.job, capture.marker.body.id >= 0,
      capture.marker.body.hull == .cobra, capture.marker.body.energy > 0,
      !capture.marker.body.hostile,
      capture.marker.body.position == capture.capturePoint,
      capture.marker.body.orientation.validRotation
    else { return false }
    return true
  }

  @inline(never)
  private static func nativeMarkerValid(_ marker: borrowing ScriptOwnedActor, actor: ActorIdentity)
    -> Bool
  {
    guard let native = marker.body.physical, native.identity == actor,
      native.population == .mission, native.npc?.role == .mission,
      native.empSource == nil, native.empCrewPod == nil, native.payload == nil,
      native.salvage == nil, native.ordnance == nil, native.rock == nil
    else { return false }
    return true
  }

  @inline(never)
  private static func fittedMarkerValid(_ marker: borrowing ScriptOwnedActor) -> Bool {
    guard let npc = marker.body.scriptNPC,
      npc.fit.definition == NativeInductionCrewLogSource.recorderProfile(),
      npc.fit.models == [
        NativeInductionCrewLogSource.recorderModel: NativeInductionCrewLogSource.recorderGeometry
      ]
    else { return false }
    return true
  }

  @inline(never)
  private static func ingressValid(
    _ capture: borrowing NativeCrewLogCapture,
    reception: borrowing NativeInductionSeedReception
  ) -> Bool {
    guard
      Self.approachAllowed(
        point: capture.capturePoint, radius: capture.radius, speed: capture.relativeSpeed),
      capture.radius == (try? NativeInductionCrewLogSource.recorderRadius.get()),
      capture.startTime.isFinite, capture.startTime >= reception.physicalTime,
      capture.physicalTime.isFinite, capture.physicalTime > capture.startTime,
      capture.physicalTime - capture.startTime <= 0.1 + 1e-9, capture.physicalTime <= 1e12,
      capture.flightSeconds.isFinite,
      (reception.flightSeconds...1e12).contains(capture.flightSeconds)
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
