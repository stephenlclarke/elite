import Foundation
import Testing

@testable import L337Core

private enum NativePeopleStorageTestError: Error { case expected }

struct NativePeopleStorageTests {
  @Test func populatedNativePeopleCopiesDetachNestedMutationsAndNilTransitions() async throws {
    let fixture = try NativeEvacuationFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    try await fixture.confirm(runtime, .request)
    let retained = await runtime.snapshot()
    let original = retained.commander
    let originalPeople = try #require(original.savedNativePeopleCustody)
    try #require(original.valid)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let bytes = try encoder.encode(original)

    // These isolated value mutations test aliasing, not valid gameplay or authored consent.
    var commanderCopy = original
    commanderCopy.savedNativePeopleCustody?.revision += 1
    commanderCopy.savedNativePeopleCustody?.orbitalEvacuation?.people[0].travelRequests.append(
      .init(revision: 2, destination: .init(galaxy: 0, system: 185), intent: .withdrawn))
    var gameCopy = retained
    gameCopy.commander.savedNativePeopleCustody?.orbitalEvacuation?.offers.removeAll()
    var ownedPeople = original.savedNativePeopleCustody
    ownedPeople?.orbitalEvacuation?.replies.removeAll()
    #expect(commanderCopy.savedNativePeopleCustody != originalPeople)
    #expect(gameCopy.commander.savedNativePeopleCustody != originalPeople)
    #expect(ownedPeople != originalPeople)
    #expect(original.savedNativePeopleCustody == originalPeople)
    #expect(retained.commander.savedNativePeopleCustody == originalPeople)
    #expect(try encoder.encode(original) == bytes)
    #expect(try encoder.encode(retained.commander) == bytes)
    #expect(await runtime.snapshot().commander == original)

    let replacement = try #require(commanderCopy.savedNativePeopleCustody)
    gameCopy.commander.savedNativePeopleCustody = replacement
    #expect(gameCopy.commander.savedNativePeopleCustody == replacement)
    commanderCopy.savedNativePeopleCustody = nil
    #expect(commanderCopy.savedNativePeopleCustody == nil)
    #expect(gameCopy.commander.savedNativePeopleCustody == replacement)
    #expect(original.savedNativePeopleCustody == originalPeople)
    #expect(try encoder.encode(retained.commander) == bytes)
  }

  @Test func nativePeopleCodecRetainsFlatPayloadAndNormalizesAbsentInoutResults() async throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    var absent = Commander()
    let originalAbsent = absent
    absent.savedNativePeopleCustody?.revision += 1
    let absentFields = try #require(
      JSONSerialization.jsonObject(with: encoder.encode(absent)) as? [String: Any])
    #expect(absent == originalAbsent && absentFields["savedNativePeopleCustody"] == nil)

    let fixture = try NativeEvacuationFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    try await fixture.confirm(runtime, .request)
    let original = await runtime.snapshot().commander
    let people = try #require(original.savedNativePeopleCustody)
    let fields = try #require(
      JSONSerialization.jsonObject(with: encoder.encode(original)) as? [String: Any])
    let savedPayload = try #require(fields["savedNativePeopleCustody"] as? NSDictionary)
    let plainPayload = try #require(
      JSONSerialization.jsonObject(with: encoder.encode(people)) as? NSDictionary)
    #expect(savedPayload == plainPayload)
    #expect(fields["savedNativePeopleCustodyStorage"] == nil)

    // This is the original flat value shape, not a storage-array envelope.
    var originalShape = fields
    originalShape["savedNativePeopleCustody"] = plainPayload
    let decoded = try JSONDecoder().decode(
      Commander.self, from: JSONSerialization.data(withJSONObject: originalShape))
    #expect(decoded == original && decoded.savedNativePeopleCustody == people)

    var expectedAbsent = original
    expectedAbsent.savedNativePeopleCustody = nil
    var removed = original
    func removeThenThrow(_ value: inout NativePeopleCustodyState?) throws {
      value = nil
      throw NativePeopleStorageTestError.expected
    }
    #expect(throws: NativePeopleStorageTestError.self) {
      try removeThenThrow(&removed.savedNativePeopleCustody)
    }
    let removedFields = try #require(
      JSONSerialization.jsonObject(with: encoder.encode(removed)) as? [String: Any])
    #expect(removed == expectedAbsent && removedFields["savedNativePeopleCustody"] == nil)
    #expect(original.savedNativePeopleCustody == people)

    // Optional Codable previously accepted explicit null and normalized it to an absent key.
    originalShape["savedNativePeopleCustody"] = NSNull()
    let decodedNull = try JSONDecoder().decode(
      Commander.self, from: JSONSerialization.data(withJSONObject: originalShape))
    let normalized = try #require(
      JSONSerialization.jsonObject(with: encoder.encode(decodedNull)) as? [String: Any])
    #expect(decodedNull == expectedAbsent && normalized["savedNativePeopleCustody"] == nil)
  }

  @Test func retainedNativePeopleSnapshotsSurviveRefusedPublicationAndSuccessfulRetry()
    async throws
  {
    let fixture = try NativeEvacuationFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime()
    try await fixture.confirm(runtime, .request)
    let page = try await NativePeopleTestFixture.review(runtime, row: .evacuation(.request))
    await runtime.scriptPageKey("right", expected: page)
    let retained = await runtime.snapshot()
    let before = retained.commander
    let people = try #require(before.savedNativePeopleCustody)
    let source = try #require(people.orbitalEvacuation)
    let offerCount = source.offers.count
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let bytes = try encoder.encode(before)
    let priorFiles = try ScriptFinanceTestFixture.files(fixture.save.deletingLastPathComponent())
    let blocked = try fixture.files.blockWrites("native-people-cow-request")
    await runtime.scriptPageKey("return", expected: page)
    let refused = await runtime.snapshot()
    #expect(refused.commander == before && refused.commander.savedNativePeopleCustody == people)
    #expect(try encoder.encode(retained.commander) == bytes)
    #expect(try encoder.encode(refused.commander) == bytes)

    try fixture.files.restoreWrites(blocked, files: priorFiles)
    try await fixture.confirm(runtime, .request)
    let committed = await runtime.snapshot()
    let renewed = try #require(committed.commander.savedNativePeopleCustody?.orbitalEvacuation)
    #expect(renewed.offers.count == offerCount + 1 && renewed.references == source.references)
    #expect(committed.commander.valid && committed.commander.credits == before.credits)
    #expect(retained.commander.savedNativePeopleCustody == people)
    #expect(try encoder.encode(retained.commander) == bytes)
    #expect(try encoder.encode(before) == bytes)
  }
}
