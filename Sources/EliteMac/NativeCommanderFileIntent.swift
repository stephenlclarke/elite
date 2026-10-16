import EliteCore
import Foundation

/// Active-path actions resolve at their position in the native input stream.
/// Panel actions retain the explicitly selected URL even if preferences later change.
enum NativeCommanderFileIntent: Sendable, Equatable {
  case saveActive
  case saveAs(URL)
  case reloadActive
  case open(URL)

  var usesActivePath: Bool {
    switch self {
    case .saveActive, .reloadActive: true
    case .saveAs, .open: false
    }
  }

  func operation(activeURL: URL) -> CommanderFileOperation {
    switch self {
    case .saveActive: .save(activeURL)
    case .saveAs(let url): .save(url)
    case .reloadActive: .load(activeURL, persistMigrations: true)
    case .open(let url): .load(url, persistMigrations: false)
    }
  }
}
