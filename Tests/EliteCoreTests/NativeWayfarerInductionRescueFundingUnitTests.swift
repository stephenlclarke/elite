import Foundation
import Testing

@testable import EliteCore

/// Financial/route/graph fixtures only. No native flight, dock, supply transfer or receiving is executed.
final class RescueFinanceFixture {
  let f: CrewLogProducerFixture
  let parent: NativeWayfarerInductionState
  let funding: NativeRescueFuelFunding
  let state: NativeInductionCrewLogState
  let legacyCommander: Commander?
  init(legacy: Bool = false) throws {
    let f: CrewLogProducerFixture
    let parent: NativeWayfarerInductionState
    var state: NativeInductionCrewLogState
    if legacy {
      let pickup = try CrewLogPickupFixture()
      f = pickup.f
      parent = try pickup.parent()
      state = pickup.state()
      legacyCommander = try pickup.commander()
    } else {
      f = try CrewLogProducerFixture()
      parent = f.parent
      state = .init(authorization: f.authorization)
      legacyCommander = nil
    }
    self.f = f
    self.parent = parent
    let dock = NativeWayfarerInductionUnitTests().dock(
      owner: f.source.manifest.owner,
      system: 211, visit: 31, sequence: 31)
    funding =
      legacy
      ? .init(
        authorization: f.authorization, sequence: 102, physicalTime: 20_002,
        flightSeconds: 10_001, legacyRebriefDock: dock)
      : .init(authorization: f.authorization)
    state.rescueFuel = try .init(funding: funding)
    state.rescueReserve = .init(authorization: f.authorization)
    self.state = state
  }
  func request(
    sequence: UInt64 = 1, system: Int = 211, vessel: UUID? = nil,
    before: Double = 0, hop: Double = 9, stock: Int = 1000,
    revision: UInt64 = 0
  ) -> NativeArkFuelRequest {
    let location = SystemIdentity(galaxy: 0, system: system)
    let dock = NativeWayfarerInductionUnitTests().dock(
      owner: f.source.manifest.owner,
      system: system, visit: 31 + sequence, sequence: 31 + sequence)
    let contact = NativeArkFuelContact(
      mission: f.parent.permission.mission,
      ark: vessel ?? f.source.manifest.launch, station: dock.station, stationActor: dock.actor,
      arkActor: .init(system: location, visit: dock.actor.visit, entity: 3),
      sequence: sequence, physicalTime: 20_002 + Double(sequence))
    return .init(
      offer: .init(
        contact: contact, supplierRevision: revision,
        availableTenthsLY: stock, pricePerTenth: Equipment.base[0].price), before: before,
      nextHopLY: hop)
  }
  func commander() throws -> Commander {
    var commander: Commander
    var parent: ScriptInstance
    var child: ScriptInstance
    if let previous = legacyCommander {
      commander = previous
      parent = try #require(commander.scriptState.instances[self.parent.permission.mission])
      child = try #require(commander.scriptState.instances[f.authorization.job])
    } else {
      commander = Commander()
      commander.savedEquipmentInventory = try .init(
        owner: f.source.manifest.owner, activeHull: f.parent.permission.carrier)
      parent = .init(
        id: f.parent.permission.mission, definition: NativeWayfarerInduction.stateID,
        version: NativeWayfarerInduction.version, digest: NativeWayfarerInduction.digest)
      parent.savedWayfarerInduction = self.parent
      parent.acknowledge(f.authorization.sequence)
      child = f.child()
      commander.nativeStations = try .init(owner: f.source.manifest.owner)
    }
    while commander.flightSimulation.visit < 31 {
      commander.flightSimulation.enter(NativeInductionCrewLogSource.location, arriving: true)
    }
    commander.flightSimulation.physicalTime = 20_010
    commander.scriptState.flightSeconds = 10_010
    commander.scriptState.nextEvent = funding.sequence
    commander.nativeStations?.mainStations = [
      NativeWayfarerInductionUnitTests().dock(
        owner: f.source.manifest.owner, system: 211, visit: 31, sequence: 31
      ).station
    ]
    commander.nativeStations?.nextMainDockSequence = 32
    parent.acknowledge(funding.sequence)
    child.acknowledge(funding.sequence)
    child.savedNativeCrewLog = state
    commander.scriptState.instances[parent.id] = parent
    commander.scriptState.instances[child.id] = child
    return commander
  }
}

struct NativeWayfarerInductionRescueFundingUnitTests {
  @Test func originalRescueFundingAndUncrewedReserveAreFiniteDistinctAndDoNotCreatePeople() throws {
    let f = try RescueFinanceFixture()
    let reserve = try #require(f.state.rescueReserve)
    let bank = try #require(f.state.rescueFuel)
    #expect(
      f.funding.valid(authorization: f.f.authorization) && f.state.shapeValid(parent: f.parent))
    #expect(bank.remainingCredits == 10_000 && bank.purchases.isEmpty)
    #expect(reserve.valid(authorization: f.f.authorization) && reserve.crew.isEmpty)
    #expect(reserve.fuelCredits == 10_000 && reserve.fuelFunding != f.funding.issue)
    #expect(
      reserve.hull != f.f.source.manifest.launch && !f.f.source.manifest.crew.contains(reserve.hull)
    )
    #expect(f.state.admission == nil && f.state.livingCrew.isEmpty && f.state.capture == nil)
    #expect(f.parent.payloads.isEmpty && f.parent.milestones == [0, 1, 2, 3, 4, 5, 6])
    let repeated = NativeRescueFuelFunding(authorization: f.f.authorization)
    #expect(
      repeated == f.funding
        && NativeRescueLaunchReserve(authorization: f.f.authorization) == reserve)
    let foreign = try RescueFinanceFixture()
    #expect(!f.funding.valid(authorization: foreign.f.authorization))
    #expect(!reserve.valid(authorization: foreign.f.authorization))
  }

  @Test func reachableOriginalCatalogueRouteKeepsBurroDriveTankAndActualMeasuredHops() throws {
    let f = try RescueFinanceFixture()
    let route = try NativeRescueRoutePlan(source: f.f.source, escortReachLY: 7)
    #expect(route.matches(source: f.f.source) && route.launch == f.f.source.manifest.launch)
    #expect(route.worldKeys.first == "G01-S211" && route.worldKeys.last == "G01-S000")
    #expect(route.driveReachLY == 9 && route.tankCapacityLY == 13 && route.routingReachLY == 7)
    #expect(route.distancesLY.allSatisfy { $0 > 0 && $0 <= 7 })
    for index in route.distancesLY.indices {
      #expect(
        route.distancesLY[index]
          == (try Universe.originalWorlds.distanceLY(
            from: route.worldKeys[index], to: route.worldKeys[index + 1])))
    }
    for reach in [0, -1, Double.nan] {
      #expect(throws: (any Error).self) {
        try NativeRescueRoutePlan(source: f.f.source, escortReachLY: reach)
      }
    }
    let restored = try JSONDecoder().decode(
      NativeRescueRoutePlan.self, from: JSONEncoder().encode(route))
    #expect(restored == route && restored.matches(source: f.f.source))
  }

  @Test func rescueAndArkPurchasesShareOneExistingStationAllocationWithoutSharingEscrows() throws {
    let f = try RescueFinanceFixture()
    let original = try #require(f.state.rescueFuel)
    let request = f.request()
    let quote = try original.quote(request)
    #expect(quote.cost == 180 && quote.fuelAfter == 9)
    let purchased = try original.purchasing(quote, current: request)
    let receipt = try #require(purchased.purchases.last)
    let stock = try NativeArkStationFuel(contact: request.offer.contact)
    let afterRescue = try stock.dispensing(receipt)
    #expect(purchased.remainingCredits == 9820 && afterRescue.remainingTenthsLY == 910)
    let key = try #require(f.parent.seedKey)
    let ark = try NativeInductionArkSource(
      loan: key, permission: f.parent.permission, service: #require(f.parent.cassetteService))
    let arkBank = try NativeArkFuelEscrow(source: ark)
    let arkRequest = f.request(sequence: 2, vessel: ark.actor, stock: 910, revision: 1)
    let arkQuote = try arkBank.quote(arkRequest)
    let arkAfter = try arkBank.purchasing(arkQuote, current: arkRequest)
    let sharedAfter = try afterRescue.dispensing(#require(arkAfter.purchases.last))
    #expect(sharedAfter.issue == stock.issue && sharedAfter.openingTenthsLY == 1000)
    #expect(sharedAfter.remainingTenthsLY == 820 && sharedAfter.revision == 2)
    #expect(sharedAfter.purchases[0].operation != sharedAfter.purchases[1].operation)
    #expect(original.remainingCredits == 10_000 && arkBank.remainingCredits == 10_000)
    #expect(throws: NativeArkFuelRefusal.foreignDock) { try original.quote(arkRequest) }
    #expect(throws: NativeArkFuelRefusal.staleQuote) {
      try purchased.purchasing(quote, current: request)
    }
  }

  @Test func onlyNeededFuelUsesActualUnitsAndRefusesForeignStockAndDriveOrTankViolations() throws {
    let f = try RescueFinanceFixture()
    let bank = try #require(f.state.rescueFuel)
    let request = f.request(before: 8.25)
    let quote = try bank.quote(request)
    #expect(quote.cost == 16 && abs(quote.fuelAfter - 9.05) < 1e-9)
    #expect(throws: NativeArkFuelRefusal.noFuelNeeded) { try bank.quote(f.request(before: 9)) }
    #expect(throws: NativeArkFuelRefusal.unavailableStock) { try bank.quote(f.request(stock: 89)) }
    for request in [
      f.request(before: 13.1), f.request(hop: 9.01), f.request(before: .nan),
      f.request(hop: .infinity),
    ] {
      #expect(throws: NativeArkFuelRefusal.invalidInput) { try bank.quote(request) }
    }
    #expect(throws: NativeArkFuelRefusal.foreignDock) { try bank.quote(f.request(vessel: UUID())) }
    #expect(bank.remainingCredits == 10_000 && bank.purchases.isEmpty)
  }

  @Test func finiteRescueBudgetCanRunOutAndColdDecodeCannotReplenishOrHideRefusal() throws {
    let f = try RescueFinanceFixture()
    var bank = try #require(f.state.rescueFuel)
    // Distinct actual station identities in a pure financial fixture; no reset of one supply is claimed.
    for index in 1...55 {
      let request = f.request(sequence: UInt64(index), system: index)
      bank = try bank.purchasing(bank.quote(request), current: request)
    }
    #expect(bank.remainingCredits == 100 && bank.purchases.count == 55)
    let request = f.request(sequence: 56, system: 56)
    #expect(throws: NativeArkFuelRefusal.insufficientEscrow) { try bank.quote(request) }
    let refused = try bank.recordingRefusal(request)
    #expect(refused.refusal?.reason == .insufficientEscrow && refused.remainingCredits == 100)
    let restored = try NativeRescueFuelEscrow.decodeClosed(JSONEncoder().encode(refused))
    #expect(restored == refused && restored.refusal == refused.refusal)
    var altered = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(restored)) as? [String: Any])
    altered["remainingCredits"] = 10_000
    #expect(throws: (any Error).self) {
      try NativeRescueFuelEscrow.decodeClosed(JSONSerialization.data(withJSONObject: altered))
    }
  }

  @Test func fundingClaimsNeedOwningAcknowledgementsAndRealLegacyRebriefHistoryWithoutSourceReset()
    throws
  {
    for legacy in [false, true] {
      let f = try RescueFinanceFixture(legacy: legacy)
      #expect(f.state.shapeValid(parent: f.parent))
      let original = try f.commander()
      #expect(NativeInductionCrewLogSave.validateClaims(original))
      #expect(
        original.scriptState.instances[f.parent.permission.mission]?.savedWayfarerInduction
          == f.parent)
      if legacy {
        #expect(f.state.capture == f.parent.crewLog && f.state.livingCrew.count == 2)
        var missingHistory = original
        missingHistory.nativeStations?.nextMainDockSequence = 1
        #expect(!NativeInductionCrewLogSave.validateClaims(missingHistory))
        var missingCapture = f.state
        missingCapture.capture = nil
        #expect(!missingCapture.shapeValid(parent: f.parent))
      } else {
        #expect(f.state.livingCrew.isEmpty && f.funding.legacyRebriefDock == nil)
      }
      let raw = try JSONEncoder().encode(f.state)
      let restored = try JSONDecoder().decode(NativeInductionCrewLogState.self, from: raw)
      #expect(restored == f.state && restored.rescueFuel?.remainingCredits == 10_000)
      var spentWithoutProvider = f.state
      let account = try #require(f.state.rescueFuel)
      spentWithoutProvider.rescueFuel = try account.purchasing(
        account.quote(f.request()), current: f.request())
      #expect(!spentWithoutProvider.shapeValid(parent: f.parent))
    }
  }

  @Test func closedFundingSchemaRejectsEarlierInventedBalancesAndUnknownNestedReserveClaims() throws
  {
    let f = try RescueFinanceFixture()
    let leaf = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(f.state)) as? [String: Any])
    func bytes(_ leaf: [String: Any]) throws -> Data {
      try JSONSerialization.data(withJSONObject: [
        "instances": [
          f.f.authorization.job.uuidString: [
            "definition": NativeInductionCrewLogPack.stateID,
            "digest": NativeInductionCrewLogPack.digest,
            "savedNativeCrewLog": leaf,
          ]
        ]
      ])
    }
    for schema in [89, 90] {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(
        bytes(leaf), part: .missions, schema: schema)
    }
    for schema in [83, 84, 85, 86, 87, 88, Int.max] {
      #expect(throws: (any Error).self) {
        try NativeInductionCrewLogSave.validateFields(bytes(leaf), part: .missions, schema: schema)
      }
    }
    var old = leaf
    old["rescueFuel"] = nil
    old["rescueReserve"] = nil
    for schema in [83, 84, 85, 86, 87, 88, 89, 90] {
      try NativeInductionCrewLogSave.validateFields(bytes(old), part: .missions, schema: schema)
    }
    var forged = leaf
    var bank = try #require(forged["rescueFuel"] as? [String: Any])
    bank["remainingCredits"] = 20_000
    forged["rescueFuel"] = bank
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(bytes(forged), part: .missions, schema: 89)
    }
    var reserve = try #require(leaf["rescueReserve"] as? [String: Any])
    reserve["replacementCrew"] = [UUID().uuidString]
    forged = leaf
    forged["rescueReserve"] = reserve
    #expect(throws: (any Error).self) {
      try NativeInductionCrewLogSave.validateFields(bytes(forged), part: .missions, schema: 89)
    }
    #expect(NativeInductionArkSave.isAlien(88) && NativeInductionArkSave.isAlien(90))
  }
}
