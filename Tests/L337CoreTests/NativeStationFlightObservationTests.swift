import Testing

@testable import L337Core

struct NativeStationFlightObservationTests {
  @Test func observationsUseTheActuallyBoundSourceMeshAndDoNotMutateTheGame() throws {
    let game = try NativeStationTestFixture.launched()
    let before = game.commander
    let bodies = game.bodies
    let message = game.message
    let observations = game.nativeStationFlightObservations(
      from: game.commander.flightSimulation.pose, delta: 0.02)
    #expect(observations.count == 2)
    for observation in observations {
      let body = try #require(bodies.first { $0.id == observation.bodyID })
      let identity = try #require(body.nativeStationIdentity)
      let source = try #require(NativeStationSource.binding(for: identity))
      let saved = try #require(game.commander.nativeStations?.pose(for: identity))
      #expect(observation.definition == identity.definition)
      #expect(
        observation.sourceKey == identity.key && observation.sourceVersion == identity.version)
      #expect(observation.world == identity.world && observation.actor == body.physical?.identity)
      #expect(observation.meshVertices == source.geometry.mesh.vertices.count)
      #expect(observation.meshFaces == source.geometry.mesh.faces.count)
      #expect(observation.meshMinimum == source.geometry.bounds.minimum)
      #expect(observation.meshMaximum == source.geometry.bounds.maximum)
      #expect(observation.canonicalPose.position == saved.position)
      #expect(observation.renderedPose == game.modelPose(of: body))
      #expect(observation.rigidPoseConsistent && observation.sweepClear == true)
    }
    #expect(game.commander == before && game.bodies == bodies && game.message == message)
    #expect(
      game.nativeStationFlightObservations(from: nil, delta: nil).allSatisfy {
        $0.sweepClear == nil
      })
    #expect(
      game.nativeStationFlightObservations(from: game.commander.flightSimulation.pose, delta: .nan)
        .allSatisfy { $0.sweepClear == nil })
  }

  @Test func stalePhysicalStationBindingDoesNotBecomeDiagnosticSourceAuthority() throws {
    var game = try NativeStationTestFixture.launched()
    let index = try #require(game.bodies.firstIndex { $0.nativeStationIdentity != nil })
    let id = game.bodies[index].id
    game.bodies[index].physical = nil
    let observations = game.nativeStationFlightObservations(from: nil, delta: nil)
    #expect(!observations.contains { $0.bodyID == id })
    #expect(Game(executive: false).nativeStationFlightObservations(from: nil, delta: nil).isEmpty)
  }
}
