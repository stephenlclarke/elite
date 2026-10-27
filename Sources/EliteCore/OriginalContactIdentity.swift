import Foundation

/// Approved current display names. This overlay grants no mission or contact authority.
enum OriginalContactIdentity: String, CaseIterable, Sendable {
  case huntCaptainFirstGalaxy = "hunt-captain-galaxy-1"
  case huntCaptainSecondGalaxy = "hunt-captain-galaxy-2"
  case plansCaptain = "plans-captain"
  case plansAgent = "plans-agent"

  var name: String {
    switch self {
    case .huntCaptainFirstGalaxy: "Elara Venn"
    case .huntCaptainSecondGalaxy: "Orin Sorel"
    case .plansCaptain: "Tamsin Holt"
    case .plansAgent: "Mara Vale"
    }
  }
  var role: String { self == .plansAgent ? "Agent" : "Captain" }
  var displayName: String { role + " " + name }
  static func huntCaptain(galaxy: Int) -> Self {
    galaxy == 0 ? .huntCaptainFirstGalaxy : .huntCaptainSecondGalaxy
  }
}
