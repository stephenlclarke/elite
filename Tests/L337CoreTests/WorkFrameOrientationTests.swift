import Foundation
import Testing

@testable import L337Core

// Existing run 542 generation 7A55D2C3... at time zero, not a player save.
private func workInitial542Camera() -> Basis3 {
  var basis = Basis3()
  basis.x = .init(0.04821488252927895, 0.42781634398676166, -0.9025788059335809)
  basis.y = .init(-0.9988193287243612, 0.026023821424974766, -0.041020839643497946)
  basis.z = .init(0.005939164024033952, 0.9034909720280784, 0.42856596901113575)
  return basis
}

@Test func workFramesPreserveCanonicalSpinWithoutAmplifyingCameraRoundoff() throws {
  var game = Game(executive: false)
  game.commander.system = 5
  game.launch()
  game.commander.flightSimulation.pose = .init(
    position: .init(4243.357534473111, 11238.39880282264, -15188.277543250319),
    orientation: workInitial542Camera())
  let allocatedActor = game.commander.flightSimulation.allocateActor()
  let actor = try #require(allocatedActor)
  let omega = Vector3(0.016728431069136646, -0.009690030774505315, 0.005124733900826819)
  var body = SpaceBody(id: 10, hull: .cobra, position: .init(0, 0, 500))
  body.rotationRate = 0
  body.physical = .init(
    identity: actor, population: .wreck, angularVelocity: omega, canonicalSpin: true)
  game.bodies = [body]
  game.celestials = []
  game.workBraking = .init(velocity: .init(1, 0, 0), angularVelocity: omega)
  var reference = game.modelPose(of: body).orientation
  for _ in 0..<1000 {
    let start = game.commander.flightSimulation.pose
    let end = ShipPose(
      position: start.position + Vector3(0.02, 0, 0),
      orientation: RelativeWorkController.rotated(start.orientation, omega: omega, delta: 0.02))
    let motion = HullSceneMotion(
      start: start, end: end, initialVelocity: .init(1, 0, 0), acceleration: .init(0, 0, 0),
      worldAngularVelocity: omega, duration: 0.02, playerRadius: 69, requiredClearance: 138)
    // This component test exercises frame consumption, not work/cutter admission.
    #expect(HullSweepSafety.validateSceneMotion(motion).safe)
    game.approvedWorkMotion = motion
    game.commander.flightSimulation.advancePhysicalTime(0.02)
    let moved = game.moveWorkFrame(delta: 0.02)
    #expect(moved)
    reference = RelativeWorkController.rotated(reference, omega: omega, delta: 0.02)
  }
  let model = game.modelPose(of: game.bodies[0])
  #expect((model.orientation.x - reference.x).length < 1e-12)
  #expect((model.orientation.y - reference.y).length < 1e-12)
  #expect((model.orientation.z - reference.z).length < 1e-12)

  // The unchanged native observer rebase uses this same parent-axis permutation.
  // Its 1e-8 world-position invariant must hold without normalizing the represented basis.
  var observer = ShipPose(position: model.position)
  observer.orientation.x = model.orientation.x
  observer.orientation.y = model.orientation.z * -1
  observer.orientation.z = model.orientation.y
  let distant = Vector3(-279.9999999894753, 100.00000005736547, 2699.9999999872744)
  let restored = observer.systemPoint(observer.shipPoint(distant))
  #expect((restored - distant).length < 1e-8)
}

@Test func workFrameReexpressionPreservesRetainedBasisWithoutNormalization() {
  // Actual run 542 pre-observer parent basis at physical time 19.30. Its Gram
  // residual is 9.651612842276336e-12, although the old camera's is only 5.33e-15.
  var frame = Basis3()
  frame.x = .init(0.14352623567632475, 0.6994087480438039, -0.700162568852928)
  frame.y = .init(-0.9731935945704423, -0.02872290733140284, -0.22818681400509047)
  frame.z = .init(-0.17970655848825684, 0.7141445216105633, 0.6765376228232334)
  var world = Basis3()
  world.rotate(pitch: 0.4, roll: -0.2, yaw: 0.8)
  let before = frame
  let local = world.workFrameRelative(to: frame)
  let restored = local.transformed(by: frame)
  #expect(frame == before)
  #expect((restored.x - world.x).length < 1e-14)
  #expect((restored.y - world.y).length < 1e-14)
  #expect((restored.z - world.z).length < 1e-14)
  let former = world.relative(to: frame).transformed(by: frame)
  #expect(
    max((former.x - world.x).length, (former.y - world.y).length, (former.z - world.z).length)
      > 1e-12)
}
