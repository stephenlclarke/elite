import Foundation
import Testing

@testable import EliteCore

/// Pure source facts only: these fixtures do not admit actors, move people or scoop a recorder.
struct NativeWayfarerInductionCrewLogSourceUnitTests {
  private func parent() throws -> NativeWayfarerInductionState {
    let f = try ArkReceivingFixture()
    return try f.f.parent.registeringArk(f.f.link).receivingSeedArk(f.receipt())
  }

  @Test func exactBurroMetreSourceKeepsOriginalPerformanceAndSeparateMechanicalFailure() throws {
    let source = try NativeInductionCrewLogSource(parent: parent())
    let original = try #require(
      OriginalFleetDefinitionData.definition(for: "SH029")?.nativePerformance)
    #expect(source.physical.id == "SH029" && source.physical.name == "Burro")
    #expect(source.physical.metresPerSourceUnit == 1 && source.ship.scale == 1)
    #expect(source.physical.physicalMesh.vertices == source.physical.model.displayMesh.vertices)
    #expect((source.physical.envelope.dimensions - Vector3(20, 10.04, 34.09)).length < 1e-9)
    #expect(source.ship.speed == original.speed * 18)
    #expect(source.ship.acceleration == original.acceleration * 18)
    #expect(source.ship.energy == original.energy && source.ship.recharge == original.recharge)
    #expect(source.ship.pitch == original.pitch && source.ship.yaw == original.yaw)
    #expect(source.ship.roll == original.roll && source.ship.missiles == original.missiles)
    #expect(source.ship.fuel == Double(original.fuel) / 10)
    #expect(source.ship.drive?.rangeLightYears == original.jump)
    #expect(source.ship.drive?.activationSeconds == original.spool)
    #expect(!NativeInductionCrewLogRole.tender.propulsionAvailable)
    #expect(NativeInductionCrewLogRole.launch.propulsionAvailable)
    #expect(NativeInductionCrewLogRole.allCases.allSatisfy { !$0.weaponsAvailable })
    #expect(source.ship.bounty == 0 && source.ship.ecm == false)
    #expect(source.ship.lasers == [] && source.ship.components?.count == 1)
  }

  @Test func oneOriginalRecorderNamesExactlyTwoDistinctLaunchOccupantsAndEnmadanShelter() throws {
    let parent = try parent()
    let source = try NativeInductionCrewLogSource(parent: parent)
    let reopened = try NativeInductionCrewLogSource(parent: parent)
    let manifest = source.manifest
    #expect(manifest == reopened.manifest && manifest.valid(permission: parent.permission))
    #expect(manifest.crew.count == 2 && Set(manifest.crew).count == 2)
    #expect(
      Set(
        [manifest.custodian, manifest.tender, manifest.launch, manifest.recorder] + manifest.crew
      ).count == 6)
    #expect(manifest.occupants(of: manifest.launch) == manifest.crew)
    #expect(manifest.occupants(of: manifest.tender).isEmpty)
    #expect(manifest.occupants(of: manifest.recorder).isEmpty)
    #expect(manifest.occupants(of: UUID()).isEmpty)
    #expect(manifest.massTonnes == 1)
    #expect(manifest.receivingShelter == SystemIdentity(galaxy: 0, system: 0))
    #expect(NativeInductionCrewLogSource.location == SystemIdentity(galaxy: 0, system: 211))
    #expect(Set(manifest.crew).isDisjoint(with: try #require(parent.seedReception).crew))
    let restored = try JSONDecoder().decode(
      NativeInductionCrewLogManifest.self, from: JSONEncoder().encode(manifest))
    #expect(restored == manifest && restored.valid(permission: parent.permission))
    let foreign = try self.parent()
    #expect(!restored.valid(permission: foreign.permission))
    let foreignSource = try NativeInductionCrewLogSource(parent: foreign)
    #expect(restored != foreignSource.manifest)
    var altered = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(manifest)) as? [String: Any])
    altered["crew"] = [manifest.crew[0].uuidString, manifest.crew[0].uuidString]
    let duplicate = try JSONDecoder().decode(
      NativeInductionCrewLogManifest.self, from: JSONSerialization.data(withJSONObject: altered))
    #expect(!duplicate.valid(permission: parent.permission))
  }

  @Test func preparationNeedsOriginalStageSevenHistoryAndCannotIssuePickupOrRescueProgress() throws
  {
    let f = try ArkReceivingFixture()
    #expect(throws: (any Error).self) { try NativeInductionCrewLogSource(parent: f.f.parent) }
    let registered = try f.f.parent.registeringArk(f.f.link)
    #expect(throws: (any Error).self) { try NativeInductionCrewLogSource(parent: registered) }
    let received = try registered.receivingSeedArk(f.receipt())
    let before = try JSONEncoder().encode(received)
    _ = try NativeInductionCrewLogSource(parent: received)
    #expect(received.milestones == [0, 1, 2, 3, 4, 5, 6] && !received.milestones.contains(7))
    #expect(received.payloads.isEmpty)
    let after = try JSONDecoder().decode(NativeWayfarerInductionState.self, from: before)
    #expect(after == received && after.seedReception == received.seedReception)
    #expect(after.permission == received.permission && after.seedKey == received.seedKey)
  }

  @Test func referenceTransformUsesPhysicalMetresAndRejectsForeignInvalidOrMirroredAnchors() throws
  {
    let source = try NativeInductionCrewLogSource(parent: parent())
    var orientation = Basis3()
    orientation.rotate(pitch: 0.3, roll: 0.8, yaw: -0.4)
    func reference(
      system: SystemIdentity = NativeInductionCrewLogSource.location,
      visit: UInt64 = 5, entity: UInt64 = 1, position: Vector3 = .init(300, -50, 800),
      basis: Basis3? = nil
    ) -> StationAnchor {
      .init(
        identity: .init(system: system, visit: visit, entity: entity), position: position,
        orientation: basis ?? orientation, exitPosition: .init(0, 0, -500),
        exitDirection: .init(0, 0, -1))
    }
    let anchor = reference()
    let tender = try source.initialPose(for: .tender, reference: anchor)
    let launch = try source.initialPose(for: .launch, reference: anchor)
    let recorder = try source.initialPose(for: .recorder, reference: anchor)
    #expect(tender.position == anchor.position + orientation.apply(.init(60000, 20000, 0)))
    #expect(tender.orientation == orientation && launch.orientation == orientation)
    #expect(recorder.orientation == orientation)
    #expect(abs((launch.position - tender.position).length - 300) < 1e-8)
    #expect(abs((recorder.position - tender.position).length - 100) < 1e-8)
    #expect(
      (launch.position - tender.position).length > source.physical.envelope.clearanceRadius * 2)
    var mirrored = orientation
    mirrored.x = mirrored.x * -1
    for invalid in [
      reference(system: .init(galaxy: 0, system: 241)), reference(visit: 0),
      reference(entity: 2), reference(position: .init(.nan, 0, 0)), reference(basis: mirrored),
    ] {
      #expect(throws: (any Error).self) {
        try source.initialPose(for: .recorder, reference: invalid)
      }
    }
  }

  @Test func authenticatedPackageShellAndBothFitsRefuseChangedModelsOrProfiles() throws {
    let source = try NativeInductionCrewLogSource(parent: parent())
    let hash = ScriptPackLibrary.hash(
      try ScriptPackLibrary.canonicalGeometry(source.recorderDesign))
    #expect(hash == NativeInductionCrewLogSource.recorderGeometry)
    #expect(source.recorder.scale == 0.2 && source.recorder.model == "catalogue:SH058")
    #expect(source.recorderDesign.rawMesh.vertices.allSatisfy { ($0 * 0.2).length <= 16 })
    #expect(source.recorder.speed == 0 && source.recorder.drive == nil)
    #expect(source.recorder.lasers == [] && source.recorder.components == [])
    let shipHash = ScriptPackLibrary.hash(
      try ScriptPackLibrary.canonicalGeometry(source.physical.model.nativeDesign))
    let shipFit = ScriptNPCFit(definition: source.ship, models: [source.ship.model: shipHash])
    let recorderFit = ScriptNPCFit(
      definition: source.recorder, models: [source.recorder.model: hash])
    #expect(source.matchesFit(shipFit, recorder: false))
    #expect(source.matchesFit(recorderFit, recorder: true))
    #expect(!source.matchesFit(shipFit, recorder: true))
    #expect(!source.matchesFit(recorderFit, recorder: false))
    #expect(
      !source.matchesFit(
        .init(
          definition: source.recorder,
          models: [source.recorder.model: String(repeating: "0", count: 64)]), recorder: true))
    var changed = source.ship
    changed.drive = nil
    #expect(!source.matchesFit(.init(definition: changed, models: shipFit.models), recorder: false))
  }
}
