import Foundation
import Testing

@testable import EliteCore

/// Choice/terms/receipt fixtures; no actual station journey, signatures or reservations are executed.
private final class InductionCharterFixture {
  let work: InductionUtilityWorkFixture
  let parent: NativeWayfarerInductionState
  let utility: NativeInductionUtilityReception
  let dock: NativeMainStationDockReceipt
  init() throws {
    work = try .init()
    utility = try work.receipt(work.state())
    parent = try work.f.parent.receivingUtilityRoute(utility)
    dock = NativeWayfarerInductionUnitTests().dock(
      owner: parent.permission.owner, system: 7,
      visit: utility.dock.actor.visit + 1, sequence: 103)
  }
  func choice(
    _ policy: NativeInductionCharterPolicy,
    terms: NativeInductionCharterTerms? = nil, dock: NativeMainStationDockReceipt? = nil
  ) throws
    -> NativeInductionCharterChoice
  {
    let dock = dock ?? self.dock
    let terms =
      terms
      ?? .original(
        epoch: NativeInductionCharterChoice.epoch(
          owner: parent.permission.owner, parent: parent.permission.mission,
          utility: utility.operation))
    let operation = try NativeInductionCharterChoice.identity(
      utility: utility.operation,
      policy: policy, terms: terms, dock: dock, carrier: utility.carrier, revision: 1,
      time: 1_000_120, flightSeconds: 900_120, sequence: 125)
    return .init(
      operation: operation, sequence: 125, owner: parent.permission.owner,
      parent: parent.permission.mission, utility: utility.operation, policy: policy, terms: terms,
      dock: dock, carrier: utility.carrier, inventoryRevision: 1,
      physicalTime: 1_000_120, flightSeconds: 900_120)
  }
}

struct NativeWayfarerInductionCharterUnitTests {
  @Test func eitherCharterCommitsOnlyStageElevenAndPreservesAllOriginalPropertyAndReceivingHistory()
    throws
  {
    let f = try InductionCharterFixture()
    for policy in NativeInductionCharterPolicy.allCases {
      let choice = try f.choice(policy)
      let next = try f.parent.choosingCharter(choice)
      #expect(next.valid && next.charterChoice == choice)
      #expect(next.milestones == f.parent.milestones.union([10]))
      #expect(next.payloads == f.parent.payloads && next.utilityReception == f.utility)
      #expect(
        next.rescueReception == f.parent.rescueReception
          && next.seedReception == f.parent.seedReception)
      let restored = try JSONDecoder().decode(
        NativeWayfarerInductionState.self,
        from: JSONEncoder().encode(next))
      #expect(restored == next && restored.charterChoice?.terms == choice.terms)
    }
  }

  @Test func fixedOperatorTermsRejectAlteredCapacityMinimumUnitsAndForeignEpoch() throws {
    let f = try InductionCharterFixture()
    let choice = try f.choice(.pooledWindows)
    #expect(choice.terms.unitsPerOperator == 6 && choice.terms.protectedMinimum == 2)
    for terms in [
      NativeInductionCharterTerms(
        unitsPerOperator: 7, protectedMinimum: 2, unit: choice.terms.unit, epoch: choice.terms.epoch
      ),
      .init(
        unitsPerOperator: 6, protectedMinimum: 0, unit: choice.terms.unit, epoch: choice.terms.epoch
      ),
      .init(
        unitsPerOperator: 6, protectedMinimum: 2, unit: "cargo-tonnes", epoch: choice.terms.epoch),
      .original(epoch: UUID()),
    ] {
      let altered = try f.choice(.pooledWindows, terms: terms)
      #expect(!altered.valid(permission: f.parent.permission, utility: f.utility))
      #expect(throws: (any Error).self) { try f.parent.choosingCharter(altered) }
    }
  }

  @Test func choiceRequiresOwningLaterAvenorDockAndCannotReplaceAnExistingPolicy() throws {
    let f = try InductionCharterFixture()
    let good = try f.choice(.protectedReservations)
    #expect(throws: (any Error).self) { try f.work.f.parent.choosingCharter(good) }
    for dock in [
      f.utility.dock,
      NativeWayfarerInductionUnitTests().dock(
        owner: UUID(), system: 7,
        visit: f.dock.actor.visit, sequence: 103),
      NativeWayfarerInductionUnitTests().dock(
        owner: f.parent.permission.owner, system: 190,
        visit: f.dock.actor.visit, sequence: 103),
    ] {
      let bad = try f.choice(.protectedReservations, dock: dock)
      #expect(!bad.valid(permission: f.parent.permission, utility: f.utility))
    }
    let chosen = try f.parent.choosingCharter(good)
    let other = try f.choice(.pooledWindows)
    #expect(throws: (any Error).self) { try chosen.choosingCharter(other) }
    #expect(chosen.charterChoice == good && chosen.milestones.max() == 10)
  }

  @Test func owningChoiceClaimsNeedAcknowledgementActualStationAndCurrentClockBounds() throws {
    let f = try InductionCharterFixture()
    let choice = try f.choice(.pooledWindows)
    var commander = try f.work.f.commander()
    while commander.flightSimulation.visit < f.dock.actor.visit {
      commander.flightSimulation.enter(NativeWayfarerInduction.source, arriving: true)
    }
    commander.flightSimulation.physicalTime = 1_000_130
    commander.scriptState.flightSeconds = 900_130
    commander.scriptState.nextEvent = 125
    commander.nativeStations?.mainStations.append(f.dock.station)
    commander.nativeStations?.nextMainDockSequence = 104
    var mission = try #require(commander.scriptState.instances[f.parent.permission.mission])
    mission.acknowledge(125)
    #expect(NativeInductionCharterSave.claimsValid(choice, mission: mission, commander: commander))
    mission.acknowledgedThrough = 124
    #expect(!NativeInductionCharterSave.claimsValid(choice, mission: mission, commander: commander))
    mission.acknowledge(125)
    commander.scriptState.flightSeconds = choice.flightSeconds - 1
    #expect(!NativeInductionCharterSave.claimsValid(choice, mission: mission, commander: commander))
    commander.scriptState.flightSeconds = 900_130
    commander.nativeStations?.mainStations.removeAll { $0 == f.dock.station }
    #expect(!NativeInductionCharterSave.claimsValid(choice, mission: mission, commander: commander))
  }

  @Test func boardOffersBothPoliciesAndShowsSelectedCapacityConsequencesBeforeConfirm() throws {
    let f = try InductionCharterFixture()
    var game = Game()
    game.commander = try f.work.f.commander()
    game.commander.system = 7
    game.screen = .contracts
    game.docked = true
    game.commander.scriptState.instances[f.parent.permission.mission]?.savedWayfarerInduction =
      f.parent
    game.scriptPacks = [
      try ScriptPackLibrary.read(ScriptPackLibrary.bundledWayfarerInductionDirectory)
    ]
    let rows = game.wayfarerInductionRows
    #expect(rows.map(\.wayfarerInduction) == [.pooledCharter, .protectedCharter])
    let before = game.commander
    for (index, policy) in NativeInductionCharterPolicy.allCases.enumerated() {
      game.contractBoard.rows = rows
      game.contractBoard.selection = index
      let action = try #require(rows[index].wayfarerInduction)
      game.contractBoard.wayfarerInductionQuote = game.wayfarerInductionReview(action)
      let detail = game.wayfarerInductionDetail()
      #expect(detail.first?.contains(policy.title.uppercased()) == true)
      #expect(
        detail.contains { $0.contains("six indivisible") && $0.contains("protected minimum two") })
      #expect(detail.contains { $0.contains("separate from ship cargo") })
      #expect(!game.contractBoard.wayfarerInductionQuote!.allowed)
    }
    #expect(game.commander == before && f.parent.charterChoice == nil)
    #expect(NativeWayfarerInduction.laterStages.contains("12-14"))
  }

  @Test func closedChoiceSchemaKeepsEarlierUtilityAndRejectsEarlyEmbeddedAndUnknownCharterTerms()
    throws
  {
    let f = try InductionCharterFixture()
    let choice = try f.choice(.pooledWindows)
    let chosen = try f.parent.choosingCharter(choice)
    var leaf = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(chosen)) as? [String: Any])
    func data(embedded: Bool = false) throws -> Data {
      let instances = [
        "instances": [
          f.parent.permission.mission.uuidString: [
            "definition": NativeWayfarerInduction.stateID, "digest": NativeWayfarerInduction.digest,
            "savedWayfarerInduction": leaf,
          ]
        ]
      ]
      return try JSONSerialization.data(
        withJSONObject: embedded ? ["savedScriptState": instances] : instances)
    }
    for schema in [101, 102] {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(data(), part: .missions, schema: schema)
    }
    for schema in [95, 96, 97, 98, 99, 100] {
      #expect(throws: (any Error).self) {
        try ScriptSaveJSONPreflight.validateRepairLoopFields(
          data(), part: .missions, schema: schema)
      }
    }
    #expect(throws: (any Error).self) {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(
        data(embedded: true), part: .commander, schema: 101)
    }
    var rawChoice = try #require(leaf["charterChoice"] as? [String: Any])
    rawChoice["signatures"] = ["clinic", "workshop", "seed"]
    leaf["charterChoice"] = rawChoice
    #expect(throws: (any Error).self) {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(data(), part: .missions, schema: 101)
    }
    #expect(NativeInductionArkSave.isAlien(100) && NativeInductionArkSave.isAlien(102))
  }
}
