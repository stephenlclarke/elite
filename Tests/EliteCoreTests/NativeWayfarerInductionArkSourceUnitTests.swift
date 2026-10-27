import Foundation
import Testing

@testable import EliteCore

struct NativeWayfarerInductionArkSourceUnitTests {
  @Test func sourceUsesOnlyTheAuthenticatedCalibratedHaflingerAndExistingFlightUnitConversions()
    throws
  {
    let f = try InductionVaultKeyFixture()
    let source = try NativeInductionArkSource(
      loan: f.key(), permission: f.serviced.permission,
      service: #require(f.serviced.cassetteService))
    let performance = try #require(
      OriginalFleetDefinitionData.definition(for: "SH061")?.nativePerformance)
    #expect(source.valid && source.physical.id == "SH061")
    #expect(source.definition.valid && source.definition.scale == 20)
    #expect(source.definition.model == "asset:induction-original-haflinger")
    #expect(source.definition.speed == performance.speed * 18)
    #expect(source.definition.acceleration == performance.acceleration * 18)
    #expect(source.definition.fuel == Double(performance.fuel) / 10)
    #expect(source.definition.drive?.rangeLightYears == performance.jump)
    #expect(source.definition.drive?.activationSeconds == performance.spool)
    #expect(source.definition.drive?.fuelUnit == "native-light-years")
    #expect(
      source.definition.pitch == performance.pitch && source.definition.yaw == performance.yaw)
    #expect(
      source.definition.roll == performance.roll
        && source.definition.missiles == performance.missiles)
    #expect(
      source.definition.energy == performance.energy
        && source.definition.recharge == performance.recharge)
    #expect(source.seeds.count == 40 && source.crew.count == 6 && performance.cargo == 78)
    #expect(source.source == SystemIdentity(galaxy: 0, system: 162))
    #expect(source.destination == SystemIdentity(galaxy: 0, system: 91))
  }

  @Test
  func oneKeyBoundManifestKeepsOriginalUnitAndCrewIdentitiesWithoutGrantingAdmissionOrArrival()
    throws
  {
    let f = try InductionVaultKeyFixture()
    let key = try f.key()
    let state = try f.serviced.borrowingVaultKey(key, freeTonnes: 1)
    let before = try JSONEncoder().encode(state)
    let source = try NativeInductionArkSource(
      loan: key, permission: state.permission, service: #require(state.cassetteService))
    let reopened = try NativeInductionArkSource(
      loan: key, permission: state.permission, service: #require(state.cassetteService))
    #expect(
      source.actor == reopened.actor && source.seeds == reopened.seeds
        && source.crew == reopened.crew)
    #expect(Set(source.seeds).count == 40 && Set(source.crew).count == 6)
    #expect(Set(source.seeds).isDisjoint(with: source.crew))
    #expect(!source.seeds.contains(key.unit) && !source.crew.contains(key.unit))
    #expect(state.milestones == [0, 1, 2, 3, 4, 5] && !state.milestones.contains(6))
    #expect(state.payloads == [NativeWayfarerInduction.keyPayload: 1])
    let loaded = try JSONDecoder().decode(NativeWayfarerInductionState.self, from: before)
    #expect(loaded == state)
    let other = try InductionVaultKeyFixture()
    let foreign = try NativeInductionArkSource(
      loan: other.key(), permission: other.serviced.permission,
      service: #require(other.serviced.cassetteService))
    #expect(foreign.actor != source.actor && Set(foreign.crew).isDisjoint(with: source.crew))
    #expect(Set(foreign.seeds).isDisjoint(with: source.seeds))
  }

  @Test func mismatchedConsentServiceAndProfileModelsCannotBindAnArkSource() throws {
    let f = try InductionVaultKeyFixture()
    let service = try #require(f.serviced.cassetteService)
    let source = try NativeInductionArkSource(
      loan: f.key(), permission: f.serviced.permission, service: service)
    for invalid in [try f.key(owner: UUID()), try f.key(system: 185), try f.key(loan: false)] {
      #expect(throws: (any Error).self) {
        try NativeInductionArkSource(
          loan: invalid, permission: f.serviced.permission, service: service)
      }
    }
    let other = try InductionVaultKeyFixture()
    #expect(throws: (any Error).self) {
      try NativeInductionArkSource(
        loan: f.key(), permission: f.serviced.permission,
        service: #require(other.serviced.cassetteService))
    }
    let hash = ScriptPackLibrary.hash(
      try ScriptPackLibrary.canonicalGeometry(source.physical.model.nativeDesign))
    let fit = ScriptNPCFit(
      definition: source.definition, models: [NativeInductionArkSource.model: hash])
    #expect(fit.valid && source.matchesFit(fit))
    var changed = source.definition
    changed.drive = nil
    #expect(!source.matchesFit(.init(definition: changed, models: fit.models)))
    #expect(
      !source.matchesFit(
        .init(
          definition: source.definition,
          models: [NativeInductionArkSource.model: String(repeating: "0", count: 64)])))
    #expect(!source.matchesFit(.init(definition: source.definition, models: [:])))
  }
}
