import Foundation
import Testing

@testable import EliteCore

private func contactBox(_ x: Double, _ y: Double, _ z: Double) -> Mesh {
  .init(
    vertices: [
      .init(-x, -y, -z), .init(x, -y, -z), .init(x, y, -z), .init(-x, y, -z),
      .init(-x, -y, z), .init(x, -y, z), .init(x, y, z), .init(-x, y, z),
    ],
    faces: [
      [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2],
      [0, 4, 7, 3], [1, 2, 6, 5],
    ])
}

private func contactMotion(
  _ from: Vector3, _ to: Vector3, radius: Double,
  duration: Double = 0.1
) -> HullSceneMotion {
  .init(
    start: .init(position: from), end: .init(position: to),
    initialVelocity: (to - from) * (1 / duration), acceleration: .init(0, 0, 0),
    worldAngularVelocity: .init(0, 0, 0), duration: duration, playerRadius: radius)
}

struct AsteroidDebrisContactTests {
  @Test func fastThinCrossingRequiresARealMeshWitnessDespiteClearEndpoints() throws {
    let source = try PreparedHull(mesh: contactBox(0.5, 0.5, 0.5))
    let target = try PreparedHull(mesh: contactBox(0.01, 2, 2))
    let a = contactMotion(.init(-20, 0.3, 0.2), .init(20, 0.3, 0.2), radius: source.radius)
    let b = contactMotion(.init(0, 0, 0), .init(0, 0, 0), radius: target.radius)
    let result = HullSweepSafety.firstNativeContact(
      source: a, hull: source,
      target: b, targetHull: target)
    guard case .contact(let contact) = result else {
      Issue.record("Native swept crossing did not produce a certified contact")
      return
    }
    #expect(contact.lowerTime > 0 && contact.upperTime < 0.1)
    #expect(contact.lowerTime <= contact.upperTime)
    #expect(contact.point.finite && abs(contact.normal.length - 1) < 1e-6)
    #expect(abs(contact.point.x) < 0.02)
  }

  @Test func nearMissIsContinuouslyClearAndExhaustedWorkNeverMeansContactOrAbsence() throws {
    let source = try PreparedHull(mesh: contactBox(0.5, 0.5, 0.5))
    let target = try PreparedHull(mesh: contactBox(0.01, 2, 2))
    let miss = contactMotion(.init(-20, 4, 0), .init(20, 4, 0), radius: source.radius)
    let b = contactMotion(.init(0, 0, 0), .init(0, 0, 0), radius: target.radius)
    let clear = HullSweepSafety.firstNativeContact(
      source: miss, hull: source,
      target: b, targetHull: target)
    guard case .clear = clear else {
      Issue.record("Separated sweep was not proved clear")
      return
    }
    let hit = contactMotion(.init(-20, 0.3, 0.2), .init(20, 0.3, 0.2), radius: source.radius)
    let refused = HullSweepSafety.firstNativeContact(
      source: hit, hull: source,
      target: b, targetHull: target,
      budget: .init(distanceQueries: 1, triangleTests: 1, nodeVisits: 1, subdivisionDepth: 1))
    guard case .refused = refused else {
      Issue.record("Exhausted geometry must refuse without an impact receipt")
      return
    }
  }

  @Test func impulseConservesBothMassesAndLinearMomentumWithExplicitDissipation() throws {
    let a = Vector3(20, 3, 4)
    let b = Vector3(-2, -1, 0)
    let sourceKg = 25_000.0
    let targetKg = 100_000.0
    let response = try #require(
      AsteroidImpactPolicy.impulse(
        sourceMass: sourceKg,
        targetMass: targetKg, sourceVelocity: a, targetVelocity: b, normal: .init(1, 0, 0)))
    let before = a * sourceKg + b * targetKg
    let after = response.source * sourceKg + response.target * targetKg
    #expect((before - after).length < 1e-8)
    #expect(response.source.y == a.y && response.source.z == a.z)
    #expect(response.target.y == b.y && response.target.z == b.z)
    let oldEnergy = 0.5 * (sourceKg * a.dot(a) + targetKg * b.dot(b))
    let newEnergy =
      0.5
      * (sourceKg * response.source.dot(response.source)
        + targetKg * response.target.dot(response.target))
    #expect(newEnergy <= oldEnergy && response.damage > 0)
    #expect(
      abs(oldEnergy - newEnergy - response.damage * AsteroidImpactPolicy.joulesPerEnergy) < 1e-6)
    #expect(
      AsteroidImpactPolicy.impulse(
        sourceMass: sourceKg, targetMass: targetKg,
        sourceVelocity: b, targetVelocity: a, normal: .init(1, 0, 0)) == nil)
    #expect(
      AsteroidImpactPolicy.impulse(
        sourceMass: .infinity, targetMass: targetKg,
        sourceVelocity: a, targetVelocity: b, normal: .init(1, 0, 0)) == nil)
  }
}
