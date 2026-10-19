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

extension AsteroidDebrisContactTests {
  @Test(arguments: [Vector3(0, 0, 0), .init(13, -7, -30)])
  func pointedTargetCanSupplyTheFirstEdgeWitnessInEitherSourceRole(commonVelocity: Vector3) throws {
    let broad = try PreparedHull(mesh: contactBox(5, 5, 1))
    let pointed = try PreparedHull(
      mesh: .init(
        vertices: [
          .init(0, 0, -2), .init(-1, -1, 1), .init(1, -1, 1), .init(0, 1, 1),
        ], faces: [[0, 2, 1], [0, 3, 2], [0, 1, 3], [1, 2, 3]]))
    let start = Vector3(0, 0, -10)
    let a = contactMotion(
      start, start + (Vector3(0, 0, 200) + commonVelocity) * 0.1,
      radius: broad.radius)
    let b = contactMotion(.init(0, 0, 0), commonVelocity * 0.1, radius: pointed.radius)
    // Only the pointed vertex/edges reach the broad face near entry. Neither a
    // broad-box edge nor a pointed face centroid can witness that first interval.
    let forward = HullSweepSafety.firstNativeContact(
      source: a, hull: broad,
      target: b, targetHull: pointed)
    guard case .contact(let entry) = forward else {
      Issue.record("Target-owned native edge witness missing: \(String(describing: forward))")
      return
    }
    #expect((0.0349...0.0351).contains(entry.upperTime))
    #expect(entry.normal.z > 0.99)
    let reversed = HullSweepSafety.firstNativeContact(
      source: b, hull: pointed,
      target: a, targetHull: broad)
    guard case .contact(let opposite) = reversed else {
      Issue.record("Source-owned native edge witness missing: \(String(describing: reversed))")
      return
    }
    #expect((0.0349...0.0351).contains(opposite.upperTime))
    #expect(opposite.normal.z < -0.99)
    #expect(abs(entry.upperTime - opposite.upperTime) <= 0.1 / 4096)
    let offset = Vector3(8, 0, 0)
    let miss = contactMotion(offset, offset + commonVelocity * 0.1, radius: pointed.radius)
    let separated = HullSweepSafety.firstNativeContact(
      source: a, hull: broad,
      target: miss, targetHull: pointed)
    guard case .clear = separated else {
      Issue.record(
        "Disjoint pointed hull was not continuously clear: \(String(describing: separated))")
      return
    }
  }
}

extension AsteroidDebrisContactTests {
  @Test(arguments: [Vector3(0, 0, 0), .init(13, -7, -30)])
  func tangentSideFacesUseTheActualMaterialEntryFace(commonVelocity: Vector3) throws {
    let small = try PreparedHull(mesh: contactBox(0.5, 0.5, 0.5))
    let long = try PreparedHull(mesh: contactBox(2, 0.01, 10))
    let start = Vector3(0, 0, -20)
    let a = contactMotion(
      start, start + (Vector3(0, 0, 400) + commonVelocity) * 0.1,
      radius: small.radius)
    let b = contactMotion(.init(0, 0, 0), commonVelocity * 0.1, radius: long.radius)
    // At the midpoint the intersecting side faces have X/Y normals and zero
    // closing speed. Source edge midpoints entered through the actual Z face.
    for reversed in [false, true] {
      let source = reversed ? b : a
      let target = reversed ? a : b
      let result = HullSweepSafety.firstNativeContact(
        source: source, hull: reversed ? long : small,
        target: target, targetHull: reversed ? small : long)
      guard case .contact(let contact) = result else {
        Issue.record("Actual entry face was not resolved: \(String(describing: result))")
        continue
      }
      let firstEntry = 9.5 / 400.0
      #expect(contact.lowerTime <= firstEntry && contact.upperTime >= firstEntry)
      #expect(contact.upperTime - contact.lowerTime <= 0.1 / 4096)
      #expect(reversed ? contact.normal.z < -0.99 : contact.normal.z > 0.99)
      let response = try #require(
        AsteroidImpactPolicy.impulse(
          sourceMass: 25_000, targetMass: 100_000,
          sourceVelocity: source.initialVelocity, targetVelocity: target.initialVelocity,
          normal: contact.normal))
      #expect(response.damage > 0)
    }
  }

  @Test func closedHullContainmentWithUnresolvedEntryDoesNotInventANormal() throws {
    let small = try PreparedHull(mesh: contactBox(0.5, 0.5, 0.5))
    let large = try PreparedHull(mesh: contactBox(2, 2, 2))
    let a = contactMotion(.init(0, 0, 0), .init(4, 0, 0), radius: small.radius)
    let b = contactMotion(.init(0, 0, 0), .init(0, 0, 0), radius: large.radius)
    let result = HullSweepSafety.firstNativeContact(
      source: a, hull: small, target: b, targetHull: large)
    guard case .refused = result else {
      Issue.record("Pre-existing containment must not invent an entry contact")
      return
    }
  }
}
