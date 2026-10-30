import Foundation
import Testing

@testable import L337Core

private func starPose(_ position: Vector3, angle: Double) -> ShipPose {
  var pose = ShipPose(position: position)
  let axis = Vector3(0.2, 0.3, 0.4).unit
  func rotate(_ vector: Vector3) -> Vector3 {
    vector * cos(angle) + axis.cross(vector) * sin(angle)
      + axis * (axis.dot(vector) * (1 - cos(angle)))
  }
  pose.orientation.x = rotate(.init(1, 0, 0))
  pose.orientation.y = rotate(.init(0, 1, 0))
  pose.orientation.z = rotate(.init(0, 0, 1))
  return pose
}

private func starMapped(_ star: Vector3, from start: ShipPose, to end: ShipPose) -> Vector3 {
  let world =
    start.position + start.orientation.x * star.x
    + start.orientation.y * star.y + start.orientation.z * star.z
  let relative = world - end.position
  return .init(
    relative.dot(end.orientation.x), relative.dot(end.orientation.y),
    relative.dot(end.orientation.z))
}

private func starForceRecycle(_ field: inout Starfield) -> Bool {
  field.advance(from: .init(), to: .init(position: .init(100_000, 0, 0)))
}

struct StarfieldPoseMotionTests {
  @Test func arbitraryPoseMappingUsesNativeTranslationAndIndependentBasisProjection() {
    var field = Starfield()
    let before = field.positions
    let start = starPose(.init(100, 200, 300), angle: 0.3)
    let end = starPose(.init(107, 198, 303), angle: -0.2)
    let mapped = before.map { starMapped($0, from: start, to: end) }
    #expect(mapped.allSatisfy { $0.length > 300 && $0.length < 9000 })
    let accepted = field.advance(from: start, to: end)
    #expect(accepted && field.positions.count == 768)
    for (actual, expected) in zip(field.positions, mapped) {
      #expect((actual - expected).length < 1e-9)
    }
    var translation = Starfield()
    let original = translation.positions
    let moved = translation.advance(from: .init(), to: .init(position: .init(0, 0, 1)))
    #expect(moved)
    for (actual, initial) in zip(translation.positions, original) {
      #expect((actual - initial - Vector3(0, 0, -1)).length < 1e-9)
    }
  }

  @Test func exactRestAtNonzeroOriginPreservesPositionsAndFutureRandomStream() {
    var field = Starfield()
    let before = field
    let pose = starPose(.init(1000, -2000, 3000), angle: 0.7)
    let accepted = field.advance(from: pose, to: pose)
    #expect(accepted && field == before)
    var control = before
    let a = starForceRecycle(&field)
    let b = starForceRecycle(&control)
    #expect(a && b && field == control)
  }

  @Test func splitWholeAndClosedLoopAgreeWithoutRecyclingAndPreserveRandomStream() {
    let start = starPose(.init(0, 0, 0), angle: 0)
    let middle = starPose(.init(2, 3, 4), angle: 0.1)
    let end = starPose(.init(5, 6, 7), angle: 0.2)
    var whole = Starfield()
    var split = whole
    let original = whole
    let intermediate = split.positions.map { starMapped($0, from: start, to: middle) }
    let final = intermediate.map { starMapped($0, from: middle, to: end) }
    #expect((intermediate + final).allSatisfy { $0.length > 300 && $0.length < 9000 })
    let a = whole.advance(from: start, to: end)
    let b = split.advance(from: start, to: middle)
    let c = split.advance(from: middle, to: end)
    #expect(a && b && c)
    #expect(zip(whole.positions, split.positions).allSatisfy { ($0 - $1).length < 1e-8 })
    let loop = split.advance(from: end, to: start)
    #expect(loop)
    #expect(zip(split.positions, original.positions).allSatisfy { ($0 - $1).length < 1e-8 })
    var control = original
    let forcedSplit = starForceRecycle(&split)
    let forcedWhole = starForceRecycle(&whole)
    let forcedControl = starForceRecycle(&control)
    #expect(forcedSplit && forcedWhole && forcedControl && split == whole && whole == control)
  }

  @Test func invalidPosesAndDerivedOverflowRejectAtomicallyIncludingFutureRandomState() {
    var reflected = ShipPose()
    reflected.orientation.x = .init(-1, 0, 0)
    var scaled = ShipPose()
    scaled.orientation.y = .init(0, 2, 0)
    var skewed = ShipPose()
    skewed.orientation.x = .init(1, 1, 0)
    var nonfinite = ShipPose()
    nonfinite.orientation.z.x = .nan
    let bad = [
      reflected, scaled, skewed, nonfinite,
      ShipPose(position: .init(.nan, 0, 0)),
      ShipPose(position: .init(.infinity, 0, 0)),
      ShipPose(position: .init(-.infinity, 0, 0)),
      ShipPose(position: .init(.greatestFiniteMagnitude, 0, 0)),
    ]
    for pose in bad {
      for invalidStart in [false, true] {
        var field = Starfield()
        var control = field
        let accepted = field.advance(
          from: invalidStart ? pose : .init(), to: invalidStart ? .init() : pose)
        #expect(!accepted && field == control)
        let a = starForceRecycle(&field)
        let b = starForceRecycle(&control)
        #expect(a && b && field == control)
      }
      var rest = Starfield()
      let before = rest
      let accepted = rest.advance(from: pose, to: pose)
      #expect(!accepted && rest == before)
    }
    // Each origin has finite length, but their difference overflows the derived length.
    var field = Starfield()
    let before = field
    let accepted = field.advance(
      from: .init(position: .init(1e154, 0, 0)),
      to: .init(position: .init(-1e154, 0, 0)))
    #expect(!accepted && field == before)
  }

  @Test func deterministicRecyclingKeepsCountAndRadiusAndLegacyApiBehavior() {
    var a = Starfield()
    var b = Starfield()
    let acceptedA = starForceRecycle(&a)
    let acceptedB = starForceRecycle(&b)
    #expect(acceptedA && acceptedB && a == b && a.positions.count == 768)
    #expect(a.positions.allSatisfy { abs($0.length - 7000) < 1e-8 })
    var legacy = Starfield()
    let original = legacy.positions
    legacy.advance(delta: 0.05, speed: 8, pitch: 1, roll: -1)
    for (actual, before) in zip(legacy.positions, original) {
      let expected = before.rotated(pitch: 0.05, roll: -0.05) - Vector3(0, 0, 7.2)
      #expect((actual - expected).length < 1e-8)
    }
  }
}
