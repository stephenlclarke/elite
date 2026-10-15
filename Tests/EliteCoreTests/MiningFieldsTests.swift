import Testing

@testable import EliteCore

@Test func miningFieldsAreStableSafeAndIndependentOfVisits() {
  let anchors = ecologyContext().anchors
  for seed in UInt64(0)..<100 {
    let fields = MiningFields.generate(anchors: anchors, seed: seed)
    #expect((2...4).contains(fields.count))
    #expect(fields == MiningFields.generate(anchors: anchors, seed: seed))
    for field in fields {
      #expect((5...12).contains(field.rocks.count))
      for rock in field.rocks {
        #expect(
          (rock.position - anchors.planet.position).length >= 3 * anchors.planet.radius
            + rock.radius)
        #expect(
          (rock.position - anchors.sun.position).length >= 4 * anchors.sun.radius + rock.radius)
        #expect((rock.position - anchors.station.position).length >= 1200 + rock.radius)
        #expect((100...200).contains(rock.energy))
        let pose = ShipPose(position: .init(400, -200, 100), orientation: .init())
        #expect((pose.systemPoint(pose.shipPoint(rock.position)) - rock.position).length < 0.000001)
      }
    }
  }
}

@Test func miningFieldsUseSafeDeterministicShellForShortBand() {
  let base = ecologyContext().anchors
  let anchors = SystemAnchors(
    system: base.system, station: base.station, arrival: base.arrival,
    planet: .init(position: .init(0, 0, 0), radius: 10000),
    sun: .init(position: .init(10, 0, 0), radius: 10000))
  let fields = MiningFields.generate(anchors: anchors, seed: 1)
  #expect((2...4).contains(fields.count))
  for rock in fields.flatMap(\.rocks) {
    #expect(
      (rock.position - anchors.planet.position).length >= 3 * anchors.planet.radius + rock.radius)
    #expect((rock.position - anchors.sun.position).length >= 4 * anchors.sun.radius + rock.radius)
  }
}
