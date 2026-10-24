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

extension AsteroidDebrisContactTests {
  @Test(arguments: [Vector3(0, 0, 0), .init(13, -7, -30)])
  func thinFirstFeatureCannotBeLostBetweenBoundedLeafSamples(commonVelocity: Vector3) throws {
    let source = try PreparedHull(mesh: contactBox(0.05, 0.05, 0.00001))
    let small = contactBox(0.2, 0.2, 0.00001)
    let body = contactBox(2, 2, 0.5)
    let featureZ = -10.249943
    let target = try PreparedHull(
      mesh: .init(
        vertices: small.vertices.map { $0 + .init(0, 0, featureZ) } + body.vertices,
        faces: small.faces + body.faces.map { $0.map { $0 + small.vertices.count } },
        preserveWinding: true))
    // The first feature is much thinner in time than a standard depth-12 leaf.
    // Its entry and exit both precede the later large-body midpoint witness.
    let worldOffset = Vector3(100000, -200000, 300000)
    let from = worldOffset + .init(0, 0, -20)
    let a = contactMotion(
      from, from + (.init(0, 0, 400) + commonVelocity) * 0.1, radius: source.radius)
    let b = contactMotion(worldOffset, worldOffset + commonVelocity * 0.1, radius: target.radius)
    let firstEntry = (featureZ - 0.00002 + 20) / 400
    for reversed in [false, true] {
      let result = HullSweepSafety.firstNativeContact(
        source: reversed ? b : a, hull: reversed ? target : source,
        target: reversed ? a : b, targetHull: reversed ? source : target)
      guard case .contact(let contact) = result else {
        Issue.record("Thin native entry was not certified: \(String(describing: result))")
        continue
      }
      #expect(contact.lowerTime <= firstEntry && contact.upperTime >= firstEntry)
      #expect(contact.upperTime < 0.025)
      #expect(contact.upperTime - contact.lowerTime <= 0.1 / 4096)
      #expect(reversed ? contact.normal.z < -0.99 : contact.normal.z > 0.99)
      #expect(
        abs(contact.point.z - worldOffset.z - commonVelocity.z * contact.upperTime - featureZ)
          < 0.00002)
    }
    let missStart = worldOffset + .init(3, 0, -20)
    let miss = contactMotion(
      missStart, missStart + (.init(0, 0, 400) + commonVelocity) * 0.1, radius: source.radius)
    let clear = HullSweepSafety.firstNativeContact(
      source: miss, hull: source, target: b, targetHull: target)
    guard case .clear = clear else {
      Issue.record("Disjoint thin feature did not remain clear: \(String(describing: clear))")
      return
    }
  }
}

extension AsteroidDebrisContactTests {
  @Test(arguments: [0, 2], [Vector3(0, 0, 0), .init(13, -7, -30)])
  func actualNativeOctahedronTipsHaveASeparateVertexCertificate(axis: Int, commonVelocity: Vector3)
    throws
  {
    let native = Mesh.hull(.cargo)
    #expect(
      native.vertices == Mesh.hull(.asteroid).vertices && native.faces == Mesh.hull(.asteroid).faces
    )
    let scaled = Mesh(
      vertices: native.vertices.map { $0 * 1.173 }, faces: native.faces, preserveWinding: true)
    let source = try PreparedHull(mesh: scaled)
    let target = try PreparedHull(mesh: native)
    let direction = axis == 0 ? Vector3(1, 0, 0) : .init(0, 0, 1)
    let offset = Vector3(100000, -200000, 300000)
    let from = offset + direction * 500
    let other = offset + direction * 1500
    let a = contactMotion(
      from, from + (direction * 16000 + commonVelocity) * 0.1, radius: source.radius)
    let b = contactMotion(other, other + commonVelocity * 0.1, radius: target.radius)
    let leading = try #require(scaled.vertices.map { $0.dot(direction) }.max())
    let trailing = try #require(native.vertices.map { $0.dot(direction) }.min())
    let firstEntry =
      (1000 + trailing - leading) / (a.initialVelocity - b.initialVelocity).dot(direction)
    for reversed in [false, true] {
      let result = HullSweepSafety.firstNativeContact(
        source: reversed ? b : a, hull: reversed ? target : source,
        target: reversed ? a : b, targetHull: reversed ? source : target)
      guard case .contact(let contact) = result else {
        Issue.record("Real native tip meeting was not certified: \(String(describing: result))")
        continue
      }
      #expect(contact.lowerTime <= firstEntry && contact.upperTime >= firstEntry)
      #expect(contact.upperTime - contact.lowerTime <= 0.1 / 4096)
      #expect(
        reversed ? contact.normal.dot(direction) < -0.99 : contact.normal.dot(direction) > 0.99)
      if reversed { continue }
      let response = try #require(
        AsteroidImpactPolicy.impulse(
          sourceMass: 25000, targetMass: 1000, sourceVelocity: a.initialVelocity,
          targetVelocity: b.initialVelocity, normal: contact.normal))
      let duration = 0.1 - contact.lowerTime
      let aStart = a.start.position + a.initialVelocity * contact.lowerTime
      let bStart = b.start.position + b.initialVelocity * contact.lowerTime
      let remainderA = HullSceneMotion(
        start: .init(position: aStart), end: .init(position: aStart + response.source * duration),
        initialVelocity: response.source, acceleration: .init(0, 0, 0),
        worldAngularVelocity: .init(0, 0, 0), duration: duration, playerRadius: source.radius)
      let remainderB = HullSceneMotion(
        start: .init(position: bStart), end: .init(position: bStart + response.target * duration),
        initialVelocity: response.target, acceleration: .init(0, 0, 0),
        worldAngularVelocity: .init(0, 0, 0), duration: duration, playerRadius: target.radius)
      let separation = HullSweepSafety.firstNativeContact(
        source: remainderA, hull: source, target: remainderB, targetHull: target)
      guard case .clear = separation else {
        Issue.record(
          "Actual post-impulse native hulls were not proved clear: \(String(describing: separation))"
        )
        continue
      }
    }
    // A nearby transverse offset cannot borrow the exact vertex certificate.
    let transverse = axis == 0 ? Vector3(0, 0, 0.000001) : .init(0.000001, 0, 0)
    let shifted = contactMotion(
      other + transverse, other + transverse + commonVelocity * 0.1, radius: target.radius)
    let offAxis = HullSweepSafety.firstNativeContact(
      source: a, hull: source, target: shifted, targetHull: target)
    switch offAxis {
    case .contact(let contact): #expect(abs(contact.normal.dot(direction)) < 0.99)
    case .refused: break  // An uncertain non-axial feature still refuses movement.
    case .clear: Issue.record("Intersecting off-axis native hulls were incorrectly declared clear")
    }
  }
}

extension AsteroidDebrisContactTests {
  @Test func translatedCoplanarNearMissHasAContinuousCertificateAtTheExistingLeaf() throws {
    let source = try PreparedHull(mesh: contactBox(0.5, 0.5, 0.5))
    let target = try PreparedHull(mesh: contactBox(1, 1, 1))
    let motion = contactMotion(.init(-3, 1.5001, 0), .init(3, 1.5001, 0), radius: source.radius)
    let stationary = contactMotion(.init(0, 0, 0), .init(0, 0, 0), radius: target.radius)
    // The scalar travel envelope exceeds the true 0.0001 face gap even at
    // this leaf. Only a certificate over every triangle pair can admit it.
    let result = HullSweepSafety.firstNativeContact(
      source: motion, hull: source,
      target: stationary, targetHull: target,
      budget: .init(
        distanceQueries: 256, triangleTests: 500_000,
        nodeVisits: 500_000, subdivisionDepth: 1))
    guard case .clear = result else {
      Issue.record("Translated separated coplanar faces were not continuously certified")
      return
    }
  }

  @Test(arguments: ["pose", "geometry", "pair", "reuse"])
  func sealedFrontierRequiresTheExactPairPoseAndOneUse(mismatch: String) throws {
    let source = try PreparedHull(mesh: contactBox(0.5, 0.5, 0.5))
    let target = try PreparedHull(mesh: contactBox(0.01, 2, 2))
    let motion = contactMotion(.init(-20, 0.3, 0.2), .init(20, 0.3, 0.2), radius: source.radius)
    let stationary = contactMotion(.init(0, 0, 0), .init(0, 0, 0), radius: target.radius)
    guard
      case .contact(let contact) = HullSweepSafety.firstNativeContact(
        source: motion,
        hull: source, target: stationary, targetHull: target)
    else {
      Issue.record("The original real contact must mint its clear frontier")
      return
    }
    let frontier = try #require(
      HullSweepSafety.nativeFrontierPoses(
        contact,
        sourceHull: source, targetHull: target))
    let retreat = contactMotion(
      frontier.source.position,
      frontier.source.position - Vector3(1, 0, 0), radius: source.radius)
    let still = contactMotion(
      frontier.target.position, frontier.target.position, radius: target.radius)
    let wrong: NativeHullContactResult
    switch mismatch {
    case "pose":
      let shifted = contactMotion(
        frontier.source.position + Vector3(0, 0.001, 0),
        frontier.source.position - Vector3(1, -0.001, 0), radius: source.radius)
      wrong = HullSweepSafety.continueNativeContact(
        contact, source: shifted, hull: source,
        target: still, targetHull: target)
    case "geometry":
      let replacement = try PreparedHull(mesh: contactBox(0.5, 0.5, 0.5))
      wrong = HullSweepSafety.continueNativeContact(
        contact, source: retreat, hull: replacement,
        target: still, targetHull: target)
    case "pair":
      wrong = HullSweepSafety.continueNativeContact(
        contact, source: retreat, hull: target,
        target: still, targetHull: source)
    default:
      let accepted = HullSweepSafety.continueNativeContact(
        contact, source: retreat, hull: source,
        target: still, targetHull: target)
      guard case .clear = accepted else {
        Issue.record("The exact frontier did not authorize its separating continuation")
        return
      }
      wrong = HullSweepSafety.continueNativeContact(
        contact, source: retreat, hull: source,
        target: still, targetHull: target)
    }
    guard case .refused(.invalidMotion) = wrong else {
      Issue.record("A mismatched or spent frontier granted authority")
      return
    }
    if mismatch != "reuse" {
      let valid = HullSweepSafety.continueNativeContact(
        contact, source: retreat, hull: source,
        target: still, targetHull: target)
      guard case .clear = valid else {
        Issue.record("Rejected mismatches consumed the valid geometric frontier")
        return
      }
    }
    #expect(
      HullSweepSafety.nativeFrontierPoses(contact, sourceHull: source, targetHull: target) == nil)
  }

  @Test(arguments: [false, true])
  func freshNativeStartsRetainClosedContainmentAndAmbiguousOpenRefusal(open: Bool) throws {
    let source = try PreparedHull(mesh: contactBox(0.1, 0.1, 0.1))
    let mesh = contactBox(2, 2, 2)
    let target = try PreparedHull(
      mesh: .init(
        vertices: mesh.vertices,
        faces: open ? Array(mesh.faces.dropLast()) : mesh.faces))
    let small = contactMotion(.init(0, 0, 0), .init(0.01, 0, 0), radius: source.radius)
    let large = contactMotion(.init(0, 0, 0), .init(0, 0, 0), radius: target.radius)
    let result = HullSweepSafety.firstNativeContact(
      source: small, hull: source,
      target: large, targetHull: target)
    guard case .refused(let failure) = result else {
      Issue.record("A fresh contained or ambiguous open start was admitted")
      return
    }
    #expect(failure == (open ? .unproven : .insideHull))
  }
}

extension AsteroidDebrisContactTests {
  @Test func aContinuedContactInsideTheFirstLeafAdvancesItsCertifiedFrontier() throws {
    let source = try PreparedHull(mesh: contactBox(0.5, 0.5, 0.5))
    let target = try PreparedHull(mesh: contactBox(0.01, 2, 2))
    let incoming = contactMotion(.init(-20, 0.3, 0.2), .init(20, 0.3, 0.2), radius: source.radius)
    let stationary = contactMotion(.init(0, 0, 0), .init(0, 0, 0), radius: target.radius)
    guard
      case .contact(let first) = HullSweepSafety.firstNativeContact(
        source: incoming, hull: source, target: stationary, targetHull: target)
    else {
      Issue.record("Expected the original native contact")
      return
    }
    let frontier = try #require(
      HullSweepSafety.nativeFrontierPoses(
        first, sourceHull: source, targetHull: target))
    let continued = contactMotion(
      frontier.source.position,
      frontier.source.position + .init(40, 0, 0), radius: source.radius)
    let still = contactMotion(
      frontier.target.position, frontier.target.position, radius: target.radius)
    guard
      case .contact(let next) = HullSweepSafety.continueNativeContact(
        first, source: continued, hull: source, target: still, targetHull: target)
    else {
      Issue.record("Expected a certified contact on the continued path")
      return
    }
    #expect(next.lowerTime > 0 && next.upperTime >= next.lowerTime)
    let advanced = try #require(
      HullSweepSafety.nativeFrontierPoses(
        next, sourceHull: source, targetHull: target))
    #expect(advanced.source.position.x > frontier.source.position.x)
  }
}

extension AsteroidDebrisContactTests {
  @Test func aMaterialCornerResponseSeparatesAllCertifiedFacesWithoutAddingEnergy() throws {
    let normals = [
      Vector3(-0.5893675749470058, 0.552532101512818, -0.5893675749470058), .init(1, 0, 0),
    ]
    let sourceMass = 25_000.0
    let targetMass = 100_000.0
    let incoming = Vector3(0, 0, -6000)
    let first = try #require(
      AsteroidImpactPolicy.impulse(
        sourceMass: sourceMass,
        targetMass: targetMass, sourceVelocity: incoming, targetVelocity: .init(0, 0, 0),
        normal: normals[0]))
    let response = try #require(
      AsteroidImpactPolicy.impulse(
        sourceMass: sourceMass,
        targetMass: targetMass, sourceVelocity: first.source, targetVelocity: first.target,
        normals: normals))
    let relative = response.source - response.target
    #expect(normals.allSatisfy { relative.dot($0) <= 1e-8 })
    #expect(
      (response.source * sourceMass + response.target * targetMass - incoming * sourceMass).length
        < 1e-6)
    let before =
      sourceMass * first.source.dot(first.source) + targetMass * first.target.dot(first.target)
    let after =
      sourceMass * response.source.dot(response.source) + targetMass
      * response.target.dot(response.target)
    #expect(after <= before && response.damage > 0)
    let cross = normals[0].cross(normals[1])
    let tangent = cross * (1 / cross.length)
    #expect(abs(relative.dot(tangent) - (first.source - first.target).dot(tangent)) < 1e-8)
  }

  @Test func aThreeFaceResponseRetainsAuthoredRestitutionAndMomentum() throws {
    let normals = [Vector3(1, 0, 0), .init(0, 1, 0), .init(0, 0, 1)]
    let response = try #require(
      AsteroidImpactPolicy.impulse(
        sourceMass: 1000,
        targetMass: 4000, sourceVelocity: .init(20, 30, 40), targetVelocity: .init(0, 0, 0),
        normals: normals))
    #expect(
      ((response.source - response.target) - Vector3(20, 30, 40) * -AsteroidImpactPolicy.restitution)
        .length < 1e-10)
    #expect(
      (response.source * 1000 + response.target * 4000 - Vector3(20, 30, 40) * 1000).length < 1e-8)
    #expect(
      AsteroidImpactPolicy.impulse(
        sourceMass: 1000, targetMass: 4000,
        sourceVelocity: .init(20, 30, 40), targetVelocity: .init(0, 0, 0), normals: [.init(0, 0, 0)]
      ) == nil)
  }
}

extension AsteroidDebrisContactTests {
  @Test func crossedThinBarsHaveAnEdgeContactEvenWhenNoVertexEntersAFace() throws {
    let source = try PreparedHull(mesh: contactBox(2, 0.2, 0.01))
    let target = try PreparedHull(mesh: contactBox(0.2, 2, 0.01))
    let moving = contactMotion(.init(0, 0, -4), .init(0, 0, 4), radius: source.radius)
    let stationary = contactMotion(.init(0, 0, 0.31), .init(0, 0, 0.31), radius: target.radius)
    let result = HullSweepSafety.firstNativeContact(
      source: moving, hull: source,
      target: stationary, targetHull: target,
      budget: .init(
        distanceQueries: 256, triangleTests: 500_000, nodeVisits: 500_000, subdivisionDepth: 0))
    guard case .contact(let contact) = result else {
      Issue.record("A true edge intersection was lost between separated samples")
      return
    }
    let expected = (4 + 0.31 - 0.02) / 80
    #expect(contact.lowerTime <= expected && abs(contact.upperTime - expected) < 1e-10)
    #expect(abs(contact.normal.z - 1) < 1e-10)
    #expect(abs(contact.point.x) < 0.21 && abs(contact.point.y) < 0.21)
  }
}

extension AsteroidDebrisContactTests {
  @Test(arguments: [Vector3(0, 0, 0), .init(100000, -200000, 300000)])
  func diagonalTranslationPreservesOneTimeVariableWhenProvingThinClearance(offset: Vector3) throws {
    let box = contactBox(0.5, 0.5, 0.5)
    let diagonal = sqrt(0.5)
    let hull = try PreparedHull(
      mesh: .init(
        vertices: box.vertices.map {
          .init(($0.x - $0.y) * diagonal, ($0.x + $0.y) * diagonal, $0.z)
        }, faces: box.faces, preserveWinding: true))
    let normal = Vector3(diagonal, diagonal, 0)
    let tangent = Vector3(-diagonal, diagonal, 0)
    // The actual normal gap stays positive during the entire diagonal translation.
    // Enclosing X/Y time independently loses their cancellation and cannot prove it.
    let gap = 0.00001
    let from = offset + normal * (1 + gap) - tangent * 1000
    let to = offset + normal * (1 + gap) + tangent * 1000
    let moving = contactMotion(from, to, radius: hull.radius)
    let stationary = contactMotion(offset, offset, radius: hull.radius)
    for reversed in [false, true] {
      let result = HullSweepSafety.firstNativeContact(
        source: reversed ? stationary : moving, hull: hull,
        target: reversed ? moving : stationary, targetHull: hull)
      guard case .clear = result else {
        Issue.record(
          "The positive diagonal native gap was not certified: \(String(describing: result))")
        continue
      }
    }
  }
}
