import Foundation

/// Main-actor preferences only; validated game loading remains in GameRuntime.
@MainActor
final class CommanderSaveSession {
  private let preferences: UserDefaults?
  let defaultURL: URL
  var activeURL: URL
  private let key = "lastCommanderSavePath"
  init(
    preferences: UserDefaults? = .standard,
    defaultURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
      ".xyzzy/l337/commander.json")
  ) {
    self.preferences = preferences
    self.defaultURL = defaultURL
    activeURL = preferences?.string(forKey: key).map { URL(fileURLWithPath: $0) } ?? defaultURL
  }
  var startupURL: URL? {
    if preferences?.string(forKey: key) != nil { return activeURL }
    return FileManager.default.fileExists(atPath: defaultURL.path) ? defaultURL : nil
  }
  func newCommanderDestination(afterFailedRestore: Bool) -> URL {
    if !afterFailedRestore, startupURL == nil { return defaultURL }
    return defaultURL.deletingLastPathComponent()
      .appendingPathComponent("new-commander-" + UUID().uuidString, isDirectory: true)
      .appendingPathComponent("commander.json")
  }
  func didSave(to url: URL) {
    activeURL = url
    preferences?.set(url.path, forKey: key)
  }
}
