import Foundation
import Testing

@testable import L337Core

private let workSelectionSystem = SystemIdentity(galaxy: 0, system: 7)

private func workCandidate(
  _ entity: UInt64 = 1, category: SalvageTargetCategory = .rock,
  ownership: SalvageOwnership = .abandoned, claimant: ActorIdentity? = nil,
  payload: PayloadIdentity? = nil, radius: Double = 1000, scoop: Bool = false,
  front: Bool = false, distance: Double = 100, live: Bool = true,
  system: SystemIdentity = workSelectionSystem, visit: UInt64 = 3
) -> WorkTargetCandidate {
  .init(
    identity: .init(system: system, visit: visit, entity: entity),
    kind: .recoverable(
      .init(
        category: category, ownership: ownership, claimant: claimant, wreck: nil,
        section: nil, lot: nil, bounds: .init(center: .init(0, 0, 0), radius: radius),
        workSurfaces: []), payload: payload),
    isLive: live, frontVisible: front, distance: distance, singleScoopCompatible: scoop)
}

private func workCaps(
  _ core: TargetingTier? = .basic, mining: Bool = false, salvage: Bool = false,
  scoops: Bool = false
) -> WorkTargetCapabilities {
  .init(core: core, miningModule: mining, salvageModule: salvage, fuelScoops: scoops)
}

private func workDecision(
  _ candidate: WorkTargetCandidate, _ capabilities: WorkTargetCapabilities
) -> WorkTargetDecision {
  WorkTargetSelection.evaluate(
    candidate, system: workSelectionSystem, visit: 3, capabilities: capabilities)
}

struct WorkTargetSelectionTests {
  @Test func everyCoreRequiresIndependentSpecialtyAddonsIncludingOffscreenBasic() {
    for core in TargetingTier.allCases {
      for front in [false, true] {
        let ship = WorkTargetCandidate(
          identity: .init(system: workSelectionSystem, visit: 3, entity: 50), kind: .ship,
          isLive: true, frontVisible: front, distance: 1, singleScoopCompatible: false)
        #expect(
          workDecision(ship, workCaps(core))
            == (core >= .advanced || front
              ? .eligible(.ship) : .refused(.frontVisibilityRequired)))
      }
      let station = WorkTargetCandidate(
        identity: .init(system: workSelectionSystem, visit: 3, entity: 51), kind: .activeStation,
        isLive: true, frontVisible: false, distance: 1, singleScoopCompatible: false)
      #expect(
        workDecision(station, workCaps(core))
          == (core >= .docking
            ? .eligible(.docking) : .refused(.dockingCoreRequired)))
      for (mining, salvage) in [(false, false), (true, false), (false, true), (true, true)] {
        let caps = workCaps(core, mining: mining, salvage: salvage)
        #expect(
          workDecision(workCandidate(), caps)
            == (mining
              ? .eligible(.hold(.mining))
              : (core >= .advanced
                ? .eligible(.tracking(.mining))
                : .refused(.frontVisibilityRequired))))
        for category in [SalvageTargetCategory.wreck, .section] {
          #expect(
            workDecision(workCandidate(category: category), caps)
              == (salvage
                ? .eligible(.hold(.salvage))
                : (core >= .advanced
                  ? .eligible(.tracking(.salvage))
                  : .refused(.frontVisibilityRequired))))
        }
      }
    }
    #expect(
      workDecision(workCandidate(), workCaps(nil, mining: true, salvage: true))
        == .refused(.missingCore))
  }

  @Test func largeHoldsNeverNeedScoopsOrSmallBoundsButLooseItemsNeedTheirOwnSpecialty() {
    for radius in [0.1, 1000.0, 100_000] {
      #expect(
        workDecision(workCandidate(radius: radius), workCaps(mining: true))
          == .eligible(.hold(.mining)))
      for category in [SalvageTargetCategory.wreck, .section] {
        #expect(
          workDecision(workCandidate(category: category, radius: radius), workCaps(salvage: true))
            == .eligible(.hold(.salvage)))
      }
    }
    let ore = PayloadIdentity.ore(
      .init(system: workSelectionSystem, field: 0, rock: 1), fragment: 0)
    let looseOre = workCandidate(category: .cargo, payload: ore, scoop: true)
    #expect(
      workDecision(looseOre, workCaps(mining: true, scoops: true)) == .eligible(.autoScoop(.mining))
    )
    #expect(
      workDecision(looseOre, workCaps(salvage: true, scoops: true))
        == .refused(.missingModule(.mining)))
    for category in [SalvageTargetCategory.cargo, .technology, .module, .disabledDrone, .emptyPod] {
      let loose = workCandidate(category: category, scoop: true)
      #expect(
        workDecision(loose, workCaps(salvage: true, scoops: true))
          == .eligible(.autoScoop(.salvage)))
      #expect(
        workDecision(loose, workCaps(mining: true, scoops: true))
          == .refused(.missingModule(.salvage)))
      #expect(workDecision(loose, workCaps(salvage: true)) == .refused(.missingFuelScoops))
      #expect(
        workDecision(workCandidate(category: category), workCaps(salvage: true, scoops: true))
          == .refused(.notScoopCompatible))
    }
  }

  @Test func custodyAndLiveContextRefusalsCannotBecomeSelectable() {
    let caps = workCaps(.military, mining: true, salvage: true, scoops: true)
    for ownership in [SalvageOwnership.claimed, .occupied, .missionProtected] {
      #expect(
        workDecision(workCandidate(category: .cargo, ownership: ownership), caps)
          == .refused(.protectedTarget))
    }
    let mission = PayloadIdentity.mission(
      instance: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, payload: "protected")
    #expect(
      workDecision(workCandidate(category: .cargo, payload: mission, scoop: true), caps)
        == .refused(.protectedTarget))
    let claimant = ActorIdentity(system: workSelectionSystem, visit: 3, entity: 99)
    #expect(
      workDecision(workCandidate(category: .cargo, claimant: claimant), caps)
        == .refused(.protectedTarget))
    #expect(
      workDecision(workCandidate(category: .occupiedPod, scoop: true), caps)
        == .refused(.occupiedPod))
    #expect(workDecision(workCandidate(live: false), caps) == .refused(.notLive))
    #expect(
      workDecision(workCandidate(system: .init(galaxy: 0, system: 8)), caps)
        == .refused(.wrongContext))
    #expect(workDecision(workCandidate(visit: 2), caps) == .refused(.wrongContext))
    for distance in [Double.nan, .infinity, -.infinity, -1] {
      #expect(workDecision(workCandidate(distance: distance), caps) == .refused(.invalidDistance))
    }
  }

  @Test func filtersOrderStationsLastThenVisibilityDistanceAndIdentityWithStableDeduplication() {
    let caps = workCaps(.military, mining: true, salvage: true, scoops: true)
    func ordinary(_ entity: UInt64, station: Bool = false) -> WorkTargetCandidate {
      .init(
        identity: .init(system: workSelectionSystem, visit: 3, entity: entity),
        kind: station ? .activeStation : .ship, isLive: true, frontVisible: true,
        distance: 1, singleScoopCompatible: false)
    }
    let ship = ordinary(10)
    let station = ordinary(11, station: true)
    let mining = workCandidate(2, front: true, distance: 20)
    let salvage = workCandidate(3, category: .wreck, front: true, distance: 20)
    let offscreen = workCandidate(4, distance: 0)
    let ore = PayloadIdentity.ore(
      .init(system: workSelectionSystem, field: 0, rock: 1), fragment: 0)
    let looseOre = workCandidate(5, category: .cargo, payload: ore, scoop: true, distance: 10)
    let looseSalvage = workCandidate(6, category: .module, scoop: true, distance: 15)
    let conflicting = workCandidate(9)
    let inputs = [
      station, offscreen, salvage, mining, ship, looseOre, looseSalvage, mining, conflicting,
      workCandidate(9, distance: 101),
    ]
    let original = inputs
    for permutation in [inputs, Array(inputs.reversed()), Array(inputs.dropFirst()) + [inputs[0]]] {
      for (filter, expected) in [
        (WorkTargetFilter.all, [UInt64(10), 2, 3, 4, 5, 6, 11]),
        (.ships, [10, 11]), (.mining, [2, 4, 5]), (.salvage, [3, 6]),
      ] {
        let choices = WorkTargetSelection.ordered(
          permutation, filter: filter, system: workSelectionSystem, visit: 3, capabilities: caps)
        #expect(choices.map { $0.candidate.identity.entity } == expected)
      }
    }
    #expect(inputs == original)
    #expect(workDecision(offscreen, caps) == .eligible(.hold(.mining)))
  }
}

extension WorkTargetSelectionTests {
  @Test func capitalHoldAndManualTrackingDoNotGrantExtractionPermission() {
    for core in TargetingTier.allCases {
      for front in [false, true] {
        let candidate = WorkTargetCandidate(
          identity: .init(system: workSelectionSystem, visit: 3, entity: 50), kind: .capitalShip,
          isLive: true, frontVisible: front, distance: 5000, singleScoopCompatible: false)
        #expect(
          workDecision(candidate, workCaps(core, salvage: true)) == .eligible(.hold(.salvage)))
        #expect(
          workDecision(candidate, workCaps(core))
            == (core >= .advanced || front
              ? .eligible(.tracking(.salvage))
              : .refused(.frontVisibilityRequired)))
        let choices = WorkTargetSelection.ordered(
          [candidate], filter: .ships,
          system: workSelectionSystem, visit: 3, capabilities: workCaps(core, salvage: true))
        #expect(choices.count == 1 && choices.first?.mode == .hold(.salvage))
      }
    }
    let caps = workCaps(.military, mining: true, salvage: true)
    let claimant = ActorIdentity(system: workSelectionSystem, visit: 3, entity: 99)
    for category in [SalvageTargetCategory.rock, .wreck, .section] {
      let mode: WorkTargetMode = category == .rock ? .hold(.mining) : .hold(.salvage)
      for ownership in [SalvageOwnership.claimed, .occupied, .missionProtected] {
        #expect(
          workDecision(
            workCandidate(
              category: category, ownership: ownership,
              claimant: claimant), caps) == .eligible(mode))
      }
    }
  }

  @Test func missingModulesKeepManualSpecialtyTargetsInTheirFilterWithoutApproach() {
    let rock = workCandidate(front: true)
    let wreck = workCandidate(2, category: .wreck, front: true)
    for (filter, expected) in [
      (WorkTargetFilter.mining, WorkTargetMode.tracking(.mining)),
      (.salvage, .tracking(.salvage)),
    ] {
      let choices = WorkTargetSelection.ordered(
        [rock, wreck], filter: filter,
        system: workSelectionSystem, visit: 3, capabilities: workCaps())
      #expect(choices.count == 1 && choices.first?.mode == expected)
    }
  }
}
