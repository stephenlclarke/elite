import Foundation
import Testing

@testable import EliteCore

private func ringAnchors(system: SystemIdentity = .init(galaxy: 0, system: 7)) -> SystemAnchors {
  var flight = FlightSimulationState()
  flight.enter(system, arriving: false)
  return flight.anchors!
}

private func ringIncident(_ id: UInt64) -> CombatIncident {
  let system = SystemIdentity(galaxy: 0, system: 7)
  let origin = AttackOrigin(
    emissionID: id, owner: .init(system: system, visit: 1, entity: 0),
    emittedAt: Double(id), ownerLegalAtEmission: .init())
  return .init(
    id: id, physicalTime: Double(id), origin: origin, victim: nil, kind: .laser, outcome: .hit,
    position: .init(0, 0, 0), victimLegalBeforeAttack: nil, firstAggressor: nil,
    victimRole: nil, victimIsStation: false, laser: .mining, mount: .front)
}

struct AsteroidRingTests {
  @Test func actualStarCentredRingContainsAllSizesAndRemainsSparseAndSafe() throws {
    let anchors = ringAnchors()
    let fields = MiningFields.generate(anchors: anchors, seed: 1)
    let radius = try #require(AsteroidBeltDefinition.radius(anchors: anchors))
    #expect(fields.count == 3 && fields.allSatisfy { $0.rocks.count == 4 })
    #expect(fields == MiningFields.generate(anchors: anchors, seed: 1))
    let rocks = fields.flatMap(\.rocks)
    #expect(
      Set(rocks.compactMap { AsteroidBeltDefinition.chunk(for: $0.identity)?.units })
        == Set(AsteroidBeltDefinition.chunkUnits))
    let radial = (anchors.planet.position - anchors.sun.position).unit
    for field in fields {
      #expect(abs((field.position - anchors.sun.position).length - radius) < 1e-7)
      #expect(field.rocks.allSatisfy { ($0.position - field.position).length < 350 })
    }
    for rock in rocks {
      let chunk = try #require(AsteroidBeltDefinition.chunk(for: rock.identity))
      #expect(
        abs((rock.position - anchors.sun.position).length - radius)
          <= AsteroidBeltDefinition.radialHalfWidth + 1e-7)
      #expect(rock.radius == chunk.radius && rock.energy == chunk.energy)
      #expect(
        (rock.position - anchors.planet.position).length >= 3 * anchors.planet.radius + rock.radius)
      #expect((rock.position - anchors.sun.position).length >= 4 * anchors.sun.radius + rock.radius)
      #expect((rock.position - anchors.station.position).length >= 1200 + rock.radius)
      for other in rocks where other.identity != rock.identity {
        #expect((other.position - rock.position).length > other.radius + rock.radius)
      }
    }
    // Every sector lies in one orbital plane that contains the actual planet-star radial.
    let normal = (fields[0].position - anchors.sun.position).cross(radial).unit
    for rock in rocks { #expect(abs((rock.position - anchors.sun.position).dot(normal)) < 1e-7) }
    let source = rocks[0].position
    var basis = Basis3()
    basis.rotate(pitch: 0.7, roll: -0.4, yaw: 1.2)
    let camera = ShipPose(position: .init(400, 300, -200), orientation: basis)
    #expect((camera.systemPoint(camera.shipPoint(source)) - source).length < 1e-7)
  }

  @Test func allGalaxiesUseTheSamePresenceAuthorityAsTheirActualGeneratedFields() {
    var present = 0
    var absent = 0
    for galaxy in 0..<8 {
      for star in Universe.systemsIncludingPlugh(number: galaxy) {
        let system = SystemIdentity(galaxy: galaxy, system: star.id)
        let seed = AsteroidBeltDefinition.seed(for: star)
        let flag = AsteroidBeltDefinition.isPresent(system: star, galaxy: galaxy)
        let fields = MiningFields.generate(anchors: ringAnchors(system: system), seed: seed)
        #expect(flag == !fields.isEmpty)
        #expect(flag == AsteroidBeltDefinition.isPresent(identity: system, seed: seed))
        if flag { present += 1 } else { absent += 1 }
      }
    }
    #expect(present > 0 && absent > 0)
  }

  @Test func impossibleRingRefusesInsteadOfCreatingPlanetShellAndLegacyRemainsExplicit() {
    let original = ringAnchors()
    let impossible = SystemAnchors(
      system: original.system, station: original.station, arrival: original.arrival,
      planet: .init(position: .init(0, 0, 0), radius: 10000),
      sun: .init(position: .init(10, 0, 0), radius: 10000))
    #expect(MiningFields.generate(anchors: impossible, seed: 1).isEmpty)
    let legacy = MiningFields.legacyFields(anchors: original, seed: 1)
    let combined = MiningFields.generate(anchors: original, seed: 1, includingLegacy: true)
    #expect(combined.filter { $0.rocks.allSatisfy { $0.identity.field < 4 } } == legacy)
    #expect(Set(combined.flatMap(\.rocks).map(\.identity)).count == combined.flatMap(\.rocks).count)
  }

  @Test func fiftyUnitsAreConservedAcrossPartialDamageSaveCollectionAndRevisit() throws {
    let rocks = MiningFields.generate(anchors: ringAnchors(), seed: 1).flatMap(\.rocks)
    let rock = try #require(
      rocks.first { AsteroidBeltDefinition.chunk(for: $0.identity)?.units == 50 })
    let chunk = try #require(AsteroidBeltDefinition.chunk(for: rock.identity))
    var ledger = MiningLedger(seed: 42)
    let untouched = ledger
    let falseEnergy = MiningRock(
      identity: rock.identity, position: rock.position, radius: rock.radius, energy: 1)
    #expect(ledger.hit(rock: falseEnergy, incident: ringIncident(1), damage: 10) == .ignored)
    #expect(ledger == untouched)
    #expect(
      ledger.hit(rock: rock, incident: ringIncident(1), damage: 10) == .damaged(rock.energy - 10))
    ledger = try JSONDecoder().decode(MiningLedger.self, from: JSONEncoder().encode(ledger))
    guard
      case .extracted(let lots) = ledger.hit(
        rock: rock, incident: ringIncident(2), damage: rock.energy)
    else {
      Issue.record("Missing complete fifty-unit extraction")
      return
    }
    #expect(lots.count == 50 && Set(lots.map(\.identity)).count == 50)
    #expect(
      lots.allSatisfy { $0.amount.quantity == 1 && $0.amount.commodity == chunk.content.commodity })
    ledger = try JSONDecoder().decode(MiningLedger.self, from: JSONEncoder().encode(ledger))
    var cargo = Array(repeating: 0, count: Commodity.all.count)
    for lot in lots {
      #expect(
        ledger.collect(
          payload: lot.identity, into: &cargo, freeTonnes: 100,
          hasScoops: true, approachAllowed: true, protection: .init()) == .collected(lot.amount))
    }
    #expect(cargo[chunk.content.commodity.rawValue] == 50 && ledger.pendingPayloads.isEmpty)
    #expect(
      ledger.collect(
        payload: lots[0].identity, into: &cargo, freeTonnes: 100,
        hasScoops: true, approachAllowed: true, protection: .init()) == .refused(.unavailable))
    ledger.depart(system: rock.identity.system)
    ledger.resetPhysicalBindings(system: rock.identity.system)
    #expect(ledger.isDepleted(rock.identity))
    #expect(ledger.hit(rock: rock, incident: ringIncident(3), damage: rock.energy) == .ignored)
    #expect(ledger.valid)
  }

  @Test func fullPendingOutputRefusesWholeExtractionWithoutDamageOrDepletion() throws {
    var ledger = MiningLedger()
    var event: UInt64 = 1
    // Six distinct fifty-unit sources pressure the existing 256-payload bound.
    for index in 0..<6 {
      let identity = RockIdentity(system: .init(galaxy: 0, system: 7 + index), field: 6, rock: 2)
      let chunk = try #require(AsteroidBeltDefinition.chunk(for: identity))
      try #require(chunk.units == 50)
      let rock = MiningRock(
        identity: identity, position: .init(100, 200, 300), radius: chunk.radius,
        energy: chunk.energy)
      let before = ledger
      let result = ledger.hit(rock: rock, incident: ringIncident(event), damage: rock.energy)
      if index < 5 {
        guard case .extracted(let lots) = result else {
          Issue.record("Unexpected refusal")
          return
        }
        #expect(lots.count == 50)
      } else {
        #expect(result == .capacityRefused && ledger == before && !ledger.isDepleted(identity))
      }
      event += 1
    }
    #expect(ledger.pendingPayloads.count == 250 && ledger.valid)
  }

  @Test func legacyLedgerKeepsOriginalYieldAndIdsAlongsideSeparateNewRingMask() throws {
    let oldRock = MiningFields.legacyFields(anchors: ringAnchors(), seed: 1)[0].rocks[0]
    var old = MiningLedger(seed: 42)
    _ = old.hit(rock: oldRock, incident: ringIncident(1), damage: oldRock.energy)
    let originalPayloads = old.pendingPayloads
    let encoded = try JSONEncoder().encode(old)
    var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    object.removeValue(forKey: "generation")
    object.removeValue(forKey: "ringTerminal")
    var restored = try JSONDecoder().decode(
      MiningLedger.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(restored.retainsLegacyFields && !restored.usesRingSaveVersion)
    #expect(restored.pendingPayloads == originalPayloads && restored.isDepleted(oldRock.identity))
    let newRock = MiningFields.generate(anchors: ringAnchors(), seed: 1)[0].rocks[0]
    _ = restored.hit(rock: newRock, incident: ringIncident(2), damage: newRock.energy)
    #expect(restored.isDepleted(oldRock.identity) && restored.isDepleted(newRock.identity))
    #expect(
      restored.pendingPayloads.filter { originalPayloads.map(\.identity).contains($0.identity) }
        == originalPayloads)
    #expect(restored.retainsLegacyFields && restored.usesRingSaveVersion && restored.valid)
    restored = try JSONDecoder().decode(MiningLedger.self, from: JSONEncoder().encode(restored))
    #expect(restored.isDepleted(oldRock.identity) && restored.isDepleted(newRock.identity))
  }

  @Test func savedRingMasksAndFragmentsRejectMalformedEvidenceBeforePayloadChildren() throws {
    let ledger = MiningLedger()
    let data = try JSONEncoder().encode(ledger)
    let original = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let system = SystemIdentity(galaxy: 0, system: 7)
    let systemObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(system))
    var badMask = original
    badMask["ringTerminal"] = [systemObject, UInt64(1) << 48]
    #expect(throws: SaveError.invalidCommander) {
      _ = try JSONDecoder().decode(
        MiningLedger.self, from: JSONSerialization.data(withJSONObject: badMask))
    }
    let rock = RockIdentity(system: system, field: 6, rock: 2)
    let identity = PayloadIdentity.ore(rock, fragment: 50)
    var badFragment = original
    badFragment["pending"] = [
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(identity)), NSNull(),
    ]
    do {
      _ = try JSONDecoder().decode(
        MiningLedger.self, from: JSONSerialization.data(withJSONObject: badFragment))
      Issue.record("Accepted out-of-manifest fragment")
    } catch DecodingError.dataCorrupted(let context) {
      #expect(context.debugDescription.contains("mining key"))
    }
    var unknown = original
    unknown["generation"] = 2
    #expect(throws: SaveError.invalidCommander) {
      _ = try JSONDecoder().decode(
        MiningLedger.self, from: JSONSerialization.data(withJSONObject: unknown))
    }
  }

  @Test func compositionMaterialsPreserveActualGeometryAndNativeCargoUnits() throws {
    let base = Mesh.hull(.asteroid)
    for (index, content) in AsteroidContent.allCases.enumerated() {
      #expect(content.commodity.unit == (index < 2 ? "t" : "kg"))
    }
    for rock in MiningFields.generate(anchors: ringAnchors(), seed: 1).flatMap(\.rocks) {
      let chunk = try #require(AsteroidBeltDefinition.chunk(for: rock.identity))
      let material = MiningRockAppearance.materials(for: rock, mesh: base)
      #expect(material.vertices == base.vertices && material.faces == base.faces)
      #expect(material.materials.first?.colour == chunk.content.colour)
      #expect(material.faceMaterials == Array(repeating: 0, count: base.faces.count))
      #expect(MiningRockAppearance.ink(for: rock) == chunk.content.ink)
    }
  }

  @Test func remoteGalaxyDetailsAndChartLegendReportTheSameRingPresence() {
    var game = Game(executive: false)
    game.screen = .chart
    game.viewGalaxy(3)
    game.selectChartSystem(7)
    let rows = Display.systemRows(game)
    #expect(rows.contains { $0.0 == "Asteroid belt: sparse star-centred ring" })
    let frame = Display.map(game, width: 768, height: 768)
    #expect(frame.labels.contains { $0.text.contains("<> belt") })
    #expect(rows.contains { $0.0.contains("Mineable cues: orange") })
    #expect(
      AsteroidBeltDefinition.isPresent(system: game.inspectedSystem, galaxy: game.inspectedGalaxy))
  }
}
