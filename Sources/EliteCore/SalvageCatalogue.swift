import Foundation

public enum SalvageHullRole: String, Codable, Sendable {
  case capitalWarship, carrier, alienCapital, deepSpaceCruiser, bulkFreighter
  case largeLiner, largeExplorer, largeCombatShip, largeTransport, largeEncounterShip,
    abandonedInfrastructure
}

public enum SalvageSectionKind: String, Codable, Sendable, CaseIterable {
  case hull, cargo, computer, drive, weapons, shields, missiles, hardpoints, escapePods
}

public enum SalvageEligibility: String, Codable, Sendable {
  case allowed, unsupportedHull, claimed, occupied, activeStation, missionProtected
}

public struct SalvageSectionProfile: Equatable, Codable, Sendable {
  public let index: UInt16
  public let kind: SalvageSectionKind
  public let localPosition: Vector3
  public let normal: Vector3
  public let radius: Double
  public let workSeconds: Double
  public let structural: Bool
  public let technologyDefinitionIDs: [String]
  /// Index into the actual catalogue mesh, not a surrogate box or native Hull mesh.
  public let sourceFaceIndex: Int
}

public struct SalvageProfile: Sendable {
  public let catalogueShipID: String
  public let name: String
  public let role: SalvageHullRole
  public let basis: String
  /// Project native-unit scale; source geometry does not establish metres or mass.
  public let physicalScale: Double
  public let bounds: SalvageBounds
  public let minimum: Vector3
  public let maximum: Vector3
  public let sections: [SalvageSectionProfile]
  public let mesh: Mesh

  public func surfaces(wreck: WreckIdentity) -> [SalvageWorkSurface] {
    sections.map {
      .init(
        section: .init(wreck: wreck, section: $0.index), position: $0.localPosition,
        normal: $0.normal, radius: $0.radius)
    }
  }
}

/// Explicit project classifications, reviewed against catalogue roles and source/refit records.
/// These profiles describe abandoned variants, never permission to cut an active counterpart.
public enum SalvageCatalogue {
  private struct Entry: Sendable {
    let id: String
    let role: SalvageHullRole
    let basis: String
  }
  private static let entries: [Entry] = [
    .init(
      id: "SH005", role: .bulkFreighter,
      basis: "Anaconda: source bulk-cargo profiles; abandoned trader variant."),
    .init(
      id: "SH006", role: .bulkFreighter,
      basis:
        "Anaconda Mk II: project Anaconda-family wreck designation; estimated refit is not historical capital-size evidence."
    ),
    .init(
      id: "SH012", role: .largeLiner,
      basis: "Beluga Liner: named liner and project large-liner geometry."),
    .init(id: "SH013", role: .bulkFreighter, basis: "Boa: source 125-tonne bulk trader."),
    .init(
      id: "SH014", role: .bulkFreighter,
      basis: "Boa Mk II: 175-tonne project cargo refit and sourced Boa-family model."),
    .init(
      id: "SH019", role: .largeExplorer,
      basis: "Caspian Explorer: named exploration hull and project large-explorer geometry."),
    .init(
      id: "SH028", role: .abandonedInfrastructure,
      basis: "Coriolis: separately abandoned site variant only; active main station excluded."),
    .init(
      id: "SH034", role: .abandonedInfrastructure,
      basis: "Dodo: separately abandoned site variant only; active main station excluded."),
    .init(
      id: "SH043", role: .capitalWarship,
      basis: "Farragut-class Battle Cruiser: explicit Capital ship catalogue class."),
    .init(
      id: "SH045", role: .largeCombatShip,
      basis: "Federal Corvette: named corvette and project large combat hull."),
    .init(
      id: "SH062", role: .largeTransport,
      basis: "Imperial Clipper: project large transport/liner wreck designation."),
    .init(
      id: "SH064", role: .largeCombatShip,
      basis: "Imperial Cutter: project large armed transport; abandonment still required."),
    .init(
      id: "SH066", role: .largeExplorer,
      basis:
        "Imperial Explorer: project large exploration refit; source NPC cargo is not used as physical scale."
    ),
    .init(
      id: "SH067", role: .bulkFreighter,
      basis: "Imperial Trader: sourced trader model and 125-tonne source cargo."),
    .init(
      id: "SH077", role: .bulkFreighter,
      basis: "Lion: project 750-tonne bulk-trader refit, explicitly estimated."),
    .init(
      id: "SH078", role: .deepSpaceCruiser,
      basis: "Long Range Cruiser: named cruiser and project 3000-tonne refit."),
    .init(
      id: "SH079", role: .carrier,
      basis: "Lynx Bulk Carrier: named carrier and project large carrier geometry."),
    .init(
      id: "SH080", role: .largeLiner,
      basis:
        "Lynx Highliner: project highliner-family designation; generic refit does not establish physical capacity."
    ),
    .init(
      id: "SH081", role: .capitalWarship,
      basis: "Majestic-class Interdictor: explicit Capital ship catalogue class."),
    .init(
      id: "SH093", role: .largeLiner, basis: "Orca: project passenger-liner wreck designation."),
    .init(
      id: "SH096", role: .bulkFreighter,
      basis: "Panther Clipper: sourced model with source 1000-tonne cargo profile."),
    .init(
      id: "SH097", role: .bulkFreighter,
      basis: "Panther Clipper Mk II: project large freighter geometry and 192-tonne refit."),
    .init(
      id: "SH098", role: .bulkFreighter,
      basis: "Puma Clipper: sourced model with source 500-tonne cargo profile."),
    .init(
      id: "SH099", role: .bulkFreighter,
      basis: "Python: source 100-tonne bulk trader; project salvage classification."),
    .init(
      id: "SH102", role: .abandonedInfrastructure,
      basis: "Rock hermit: abandoned installation only, never an occupied station."),
    .init(
      id: "SH123", role: .alienCapital,
      basis:
        "Thargoid Titan: explicit named alien capital-scale project hull; not other Thargoid craft."
    ),
    .init(
      id: "SH127", role: .bulkFreighter,
      basis: "Tiger Trader: sourced model with source 400-tonne cargo profile."),
    .init(
      id: "SH129", role: .largeCombatShip,
      basis: "Type-10 Defender: project large armed freighter and 220-tonne refit."),
    .init(
      id: "SH132", role: .bulkFreighter,
      basis: "Type-7 Transporter: project large freighter and 128-tonne refit."),
    .init(
      id: "SH133", role: .bulkFreighter,
      basis: "Type-8 Transporter: project large freighter and 176-tonne refit."),
    .init(
      id: "SH134", role: .bulkFreighter,
      basis: "Type-9 Heavy: named heavy transport and 348-tonne project refit."),
    .init(
      id: "SH141", role: .abandonedInfrastructure,
      basis:
        "Wheel station: abandoned site variant only; bounds derive from vertices despite absent dimensions metadata."
    ),
    .init(
      id: "SH155", role: .largeEncounterShip,
      basis:
        "Ionics Funnelweb: explicitly reviewed large encounter hull using its sourced assembly, not its generic player refit."
    ),
    .init(
      id: "SH156", role: .abandonedInfrastructure,
      basis: "CR150 weapons platform: explicit Combat platform; abandoned variant only."),
    .init(
      id: "SH161", role: .carrier,
      basis:
        "Military Fiasco Leviathan: explicit Carrier/station catalogue class, using its complete sourced hull."
    ),
    .init(
      id: "SH164", role: .abandonedInfrastructure,
      basis:
        "Deposed medical drug factory: explicit Station/factory encounter object; abandoned variant only."
    ),
    .init(
      id: "SH171", role: .deepSpaceCruiser,
      basis: "Liberator DSV2: explicit Deep-space cruiser class and authored full-size model."),
  ]

  public static let all: [SalvageProfile] = entries.compactMap(makeProfile)

  public static func profile(catalogueShipID: String) -> SalvageProfile? {
    all.first { $0.catalogueShipID == catalogueShipID }
  }

  public static func eligibility(
    catalogueShipID: String, ownership: SalvageOwnership,
    activeStation: Bool = false, missionProtected: Bool = false
  ) -> SalvageEligibility {
    if missionProtected || ownership == .missionProtected { return .missionProtected }
    if activeStation { return .activeStation }
    guard profile(catalogueShipID: catalogueShipID) != nil else { return .unsupportedHull }
    switch ownership {
    case .abandoned: return .allowed
    case .claimed: return .claimed
    case .occupied: return .occupied
    case .missionProtected: return .missionProtected
    }
  }

  private struct Face {
    let index: Int
    let center: Vector3
    let normal: Vector3
    let radius: Double
  }

  private static func makeProfile(_ entry: Entry) -> SalvageProfile? {
    guard let ship = ShipCatalogue.all.first(where: { $0.id == entry.id }) else { return nil }
    // previewMesh is showroom-normalised; native wreck geometry must use authoritative raw vertices.
    let mesh = ship.design.rawMesh
    guard !mesh.vertices.isEmpty else { return nil }
    let minimum = Vector3(
      mesh.vertices.map(\.x).min()!, mesh.vertices.map(\.y).min()!, mesh.vertices.map(\.z).min()!)
    let maximum = Vector3(
      mesh.vertices.map(\.x).max()!, mesh.vertices.map(\.y).max()!, mesh.vertices.map(\.z).max()!)
    let center = (minimum + maximum) * 0.5
    let radius = mesh.vertices.map { ($0 - center).length }.max()!
    let faces = mesh.faces.enumerated().compactMap { index, indices -> Face? in
      guard indices.count >= 3, indices.allSatisfy({ mesh.vertices.indices.contains($0) }) else {
        return nil
      }
      let vertices = indices.map { mesh.vertices[$0] }
      let cross = (vertices[1] - vertices[0]).cross(vertices[2] - vertices[0])
      guard cross.length > 1e-8 else { return nil }
      let midpoint = vertices.reduce(Vector3(0, 0, 0), +) * (1 / Double(vertices.count))
      return .init(
        index: index, center: midpoint, normal: cross * (1 / cross.length),
        radius: vertices.map { ($0 - midpoint).length }.max()!)
    }
    let directions: [Vector3] = [
      .init(0, 1, 0), .init(0, -1, 0), .init(0, 0, 1),
      .init(0, 0, -1), .init(1, 0, 0), .init(-1, 0, 0), .init(1, 1, 0), .init(-1, 1, 0),
      .init(0, 1, 1),
    ]
    var used: Set<Int> = []
    var sections: [SalvageSectionProfile] = []
    for (index, kind) in SalvageSectionKind.allCases.enumerated() {
      let direction = directions[index].unit
      let available = faces.filter { !used.contains($0.index) }
      let facing = available.filter { $0.normal.dot(direction) > 0.2 }
      guard
        let face = (facing.isEmpty ? available : facing).max(by: {
          let a = ($0.center - center).dot(direction)
          let b = ($1.center - center).dot(direction)
          return a == b ? $0.index > $1.index : a < b
        })
      else { continue }
      used.insert(face.index)
      sections.append(
        .init(
          index: UInt16(index), kind: kind, localPosition: face.center,
          normal: face.normal, radius: face.radius, workSeconds: workSeconds(kind),
          structural: kind == .hull || kind == .cargo,
          technologyDefinitionIDs: technology(kind, alien: entry.role == .alienCapital),
          sourceFaceIndex: face.index))
    }
    guard radius.isFinite, radius > 0, !sections.isEmpty else { return nil }
    return .init(
      catalogueShipID: ship.id, name: ship.name, role: entry.role, basis: entry.basis,
      physicalScale: 1, bounds: .init(center: center, radius: radius), minimum: minimum,
      maximum: maximum, sections: sections, mesh: mesh)
  }

  private static func workSeconds(_ kind: SalvageSectionKind) -> Double {
    switch kind {
    case .hull: 12
    case .cargo: 16
    case .computer, .shields, .hardpoints: 24
    case .drive: 30
    case .weapons: 26
    case .missiles: 18
    case .escapePods: 16
    }
  }

  private static func technology(_ kind: SalvageSectionKind, alien: Bool) -> [String] {
    if alien { return kind == .hull ? [] : ["alien-artefact"] }
    switch kind {
    case .hull, .cargo: return []
    case .computer: return ["computer-core"]
    case .drive: return ["drive-technology"]
    case .weapons: return ["laser-technology"]
    case .shields: return ["shield-technology"]
    case .missiles:
      return ["missile-standard", "missile-guided", "missile-heavy", "missile-ecm-resistant"]
    case .hardpoints: return ["laser-hardpoint", "missile-pylon"]
    case .escapePods: return ["spare-escape-pod"]
    }
  }
}
