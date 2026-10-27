import Testing

@testable import EliteCore

@Suite struct SalvageCatalogueTests {
  @Test func reviewedCapitalCarrierAndLargeHullProfilesUseActualCatalogueRecords() throws {
    let expected: [String: String] = [
      "SH043": "Eagle Cruiser", "SH081": "Jaguar",
      "SH161": "Military Fiasco Leviathan", "SH155": "Ionics Funnelweb",
      "SH123": "Thargoid Titan", "SH171": "Liberator DSV2",
      "SH078": "Oryx Voyager", "SH079": "Carabao Carrier", "SH080": "Carabao Highliner",
    ]
    #expect(SalvageCatalogue.all.count == 37)
    #expect(Set(SalvageCatalogue.all.map(\.catalogueShipID)).count == SalvageCatalogue.all.count)
    for (id, name) in expected {
      let profile = try #require(SalvageCatalogue.profile(catalogueShipID: id))
      #expect(profile.name == name && !profile.basis.isEmpty)
    }
    for ship in ShipCatalogue.all
    where ship.shipClass == "Capital ship" || ship.shipClass == "Carrier/station" {
      #expect(SalvageCatalogue.profile(catalogueShipID: ship.id) != nil)
    }
    #expect(try #require(ShipCatalogue.all.first { $0.id == "SH043" }).game != nil)
    #expect(try #require(ShipCatalogue.all.first { $0.id == "SH161" }).game == nil)
  }

  @Test func sourceRolesUseExplicitInstallationsAndReviewedHullRoles() throws {
    let expected: [String: SalvageSourceRole] = [
      "SH161": .militaryCapital, "SH043": .militaryCapital, "SH081": .militaryCapital,
      "SH156": .weaponsPlatform, "SH164": .drugFactory, "SH102": .rockHermit,
      "SH123": .thargoid, "SH079": .commercialCarrier, "SH005": .commercialTrader,
      "SH012": .commercialTrader, "SH062": .commercialTrader, "SH028": .station,
      "SH155": .generalShip, "SH171": .generalShip, "SH078": .generalShip,
      "SH019": .generalShip, "SH045": .generalShip,
    ]
    for (id, role) in expected {
      #expect(
        try #require(SalvageCatalogue.profile(catalogueShipID: id)).sourceRoles.contains(role))
    }
    for profile in SalvageCatalogue.all {
      #expect(SalvageLootProfiles.profile(roles: profile.sourceRoles) != nil)
    }
  }

  @Test func nonflyableObjectsAndOccupiedOrProtectedCounterpartsNeverBecomeFreeSalvage() {
    for id in ["SH162", "SH163", "SH040", "SH125", "SH023", "SH999"] {
      #expect(SalvageCatalogue.profile(catalogueShipID: id) == nil)
      #expect(
        SalvageCatalogue.eligibility(catalogueShipID: id, ownership: .abandoned) == .unsupportedHull
      )
    }
    for profile in SalvageCatalogue.all {
      let id = profile.catalogueShipID
      #expect(SalvageCatalogue.eligibility(catalogueShipID: id, ownership: .abandoned) == .allowed)
      #expect(SalvageCatalogue.eligibility(catalogueShipID: id, ownership: .occupied) == .occupied)
      #expect(SalvageCatalogue.eligibility(catalogueShipID: id, ownership: .claimed) == .claimed)
      #expect(
        SalvageCatalogue.eligibility(catalogueShipID: id, ownership: .missionProtected)
          == .missionProtected)
      #expect(
        SalvageCatalogue.eligibility(
          catalogueShipID: id, ownership: .abandoned, activeStation: true) == .activeStation)
      #expect(
        SalvageCatalogue.eligibility(
          catalogueShipID: id, ownership: .abandoned, missionProtected: true) == .missionProtected)
    }
    for id in ["SH028", "SH034", "SH102", "SH141", "SH156", "SH164"] {
      #expect(SalvageCatalogue.profile(catalogueShipID: id)?.role == .abandonedInfrastructure)
    }
  }

  @Test func actualMeshBoundsMaterialsAndFaceWorkGeometryRemainUnnormalized() throws {
    for profile in SalvageCatalogue.all {
      let ship = try #require(ShipCatalogue.all.first { $0.id == profile.catalogueShipID })
      let mesh = ship.design.rawMesh
      #expect(profile.physicalScale == 1)
      #expect(profile.mesh.vertices == mesh.vertices && profile.mesh.faces == mesh.faces)
      #expect(
        profile.mesh.materials == mesh.materials && profile.mesh.faceMaterials == mesh.faceMaterials
      )
      #expect(profile.bounds.radius > 0 && profile.bounds.radius.isFinite)
      for vertex in mesh.vertices {
        #expect((vertex - profile.bounds.center).length <= profile.bounds.radius + 1e-8)
        #expect(vertex.x >= profile.minimum.x && vertex.x <= profile.maximum.x)
        #expect(vertex.y >= profile.minimum.y && vertex.y <= profile.maximum.y)
        #expect(vertex.z >= profile.minimum.z && vertex.z <= profile.maximum.z)
      }
      #expect(Set(profile.sections.map(\.index)).count == profile.sections.count)
      #expect(Set(profile.sections.map(\.sourceFaceIndex)).count == profile.sections.count)
      for section in profile.sections {
        #expect((10...30).contains(section.workSeconds) && section.radius > 0)
        #expect(abs(section.normal.length - 1) < 1e-8)
        let indices = mesh.faces[section.sourceFaceIndex]
        let vertices = indices.map { mesh.vertices[$0] }
        let center = vertices.reduce(Vector3(0, 0, 0), +) * (1 / Double(vertices.count))
        #expect((center - section.localPosition).length < 1e-8)
        let normal = (vertices[1] - vertices[0]).cross(vertices[2] - vertices[0]).unit
        #expect((normal - section.normal).length < 1e-8)
        #expect(vertices.allSatisfy { ($0 - center).length <= section.radius + 1e-8 })
        #expect(section.structural == (section.kind == .hull || section.kind == .cargo))
      }
    }
    let leviathan = try #require(SalvageCatalogue.profile(catalogueShipID: "SH161"))
    #expect(leviathan.maximum.z - leviathan.minimum.z > 1500)
    let wheel = try #require(SalvageCatalogue.profile(catalogueShipID: "SH141"))
    #expect(wheel.bounds.radius > 0)
  }

  @Test func workSurfaceIDsArePersistentAndTechnologyMetadataResolvesEveryCategory() throws {
    let wreck = WreckIdentity(system: .init(galaxy: 0, system: 7), site: 1, lineage: 123)
    var categories: Set<String> = []
    for profile in SalvageCatalogue.all {
      let surfaces = profile.surfaces(wreck: wreck)
      #expect(surfaces.count == profile.sections.count)
      #expect(surfaces == profile.surfaces(wreck: wreck))
      for (section, surface) in zip(profile.sections, surfaces) {
        #expect(surface.section.wreck == wreck && surface.section.section == section.index)
        #expect(surface.position == section.localPosition && surface.normal == section.normal)
        for id in section.technologyDefinitionIDs {
          _ = try #require(SalvageDefinitions.definition(id: id))
          categories.insert(id)
        }
      }
    }
    #expect(
      categories == [
        "computer-core", "drive-technology", "laser-technology", "shield-technology",
        "missile-standard", "missile-guided", "missile-heavy", "missile-ecm-resistant",
        "laser-hardpoint", "missile-pylon", "spare-escape-pod", "alien-artefact",
      ])
  }
}
