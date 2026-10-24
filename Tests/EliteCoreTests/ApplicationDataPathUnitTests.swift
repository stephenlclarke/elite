import Foundation
import Testing

@testable import EliteCore
@testable import EliteMac

struct ApplicationDataPathUnitTests {
  @MainActor @Test func freshCommanderAndPackLibrariesShareTheL337Root() {
    let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".xyzzy/l337")
    let saves = CommanderSaveSession(preferences: nil)
    #expect(saves.defaultURL.path == root.appendingPathComponent("commander.json").path)
    #expect(saves.activeURL == saves.defaultURL)
    #expect(
      MissionPackLibrary.userDirectory.path == root.appendingPathComponent("mission-packs").path)
    #expect(
      ScriptPackLibrary.userDirectory.path == root.appendingPathComponent("script-packs").path)
    #expect(MissionPackLibrary.userDirectory != ScriptPackLibrary.userDirectory)
  }

  @MainActor @Test func explicitSaveDestinationAndRecoveryKeepTheirExistingPathPolicy() {
    let saves = CommanderSaveSession(preferences: nil)
    let originalDefault = saves.defaultURL
    let custom = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("chosen-commander.json")
    saves.didSave(to: custom)
    #expect(saves.activeURL == custom && saves.defaultURL == originalDefault)
    let fresh = saves.newCommanderDestination(afterFailedRestore: true)
    #expect(fresh.lastPathComponent == "commander.json")
    #expect(fresh.deletingLastPathComponent().lastPathComponent.hasPrefix("new-commander-"))
    #expect(
      fresh.deletingLastPathComponent().deletingLastPathComponent().path
        == originalDefault.deletingLastPathComponent().path)
    #expect(fresh != originalDefault && fresh != custom)
    #expect(saves.activeURL == custom)
  }
}
