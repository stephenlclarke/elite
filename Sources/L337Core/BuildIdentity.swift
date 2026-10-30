import Foundation

public struct BuildIdentity: Sendable {
  public static let repository = "GITHUB.COM/STEPHENLCLARKE/L337"
  public static let current = BuildIdentity(info: Bundle.main.infoDictionary ?? [:])
  public let version: String
  public let revision: String?

  public init(info: [String: Any]) {
    version = info["CFBundleShortVersionString"] as? String ?? "DEVELOPMENT"
    let candidate = info["L337SourceRevision"] as? String ?? ""
    revision = candidate.count == 40 && candidate.allSatisfy { $0.isHexDigit } ? candidate : nil
  }

  var versionLine: String { "VERSION " + version }
  var revisionLine: String { revision ?? "COMMIT UNAVAILABLE" }
  var legacyRevisionLines: [String] {
    guard let revision else { return [revisionLine] }
    return [String(revision.prefix(20)), String(revision.suffix(20))]
  }
}
