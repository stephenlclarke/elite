import Foundation
import Testing

@testable import EliteCore

struct NativeWayfarerInductionUnitTests {
  func dock(owner: UUID, system: Int, visit: UInt64, sequence: UInt64)
    -> NativeMainStationDockReceipt
  {
    let location = SystemIdentity(galaxy: 0, system: system)
    let station = NativeMainStationIdentity(
      world: owner, system: location,
      resource: Game.worldResourceIdentity("main-station-v1:main-orbital:0:\(system)"))
    return .init(
      station: station, actor: .init(system: location, visit: visit, entity: 1),
      commanderOwner: owner, sequence: sequence, calendarSeconds: Double(sequence))
  }
  func fixture() throws -> (NativeWayfarerInductionState, ScriptEngineState) {
    let owner = UUID()
    let carrier = UUID()
    let source = dock(owner: owner, system: 7, visit: 1, sequence: 1)
    let price = try #require(
      OriginalLiveMarkets.initialQuote(galaxy: 0, system: 7, commodity: 13)
    ).bidPrice
    let sale = NativeFirstCommoditySale(
      operation: UUID(), owner: owner, commodity: 13, dock: source, physicalTime: 0,
      calendarOperation: 0, unitPrice: price, quantity: 1,
      before: .init(stock: 20, cargo: 1, credits: 100),
      after: .init(stock: 21, cargo: 0, credits: 100 + price))
    var engine = ScriptEngineState()
    engine.firstNativeCommoditySale = sale
    let mission = NativeWayfarerInduction.mission(owner: owner)
    let permission = NativeInductionPermission(
      mission: mission,
      operation: try NativeWayfarerInduction.commissionOperation(
        mission: mission, owner: owner, dock: source, carrier: carrier, revision: 1),
      owner: owner, dock: source, trade: .sale(sale.operation),
      carrier: carrier, inventoryRevision: 1, physicalTime: 1, flightSeconds: 10)
    return (.init(permission: permission), engine)
  }
  func crate(
    _ state: NativeWayfarerInductionState, source: NativeMainStationDockReceipt? = nil,
    unit: UUID? = nil, allowance: Double = 1800, deadline: Double? = nil
  ) throws -> NativeInductionClinicCrate {
    let p = state.permission
    let source = source ?? dock(owner: p.owner, system: 185, visit: 2, sequence: 2)
    let unit = unit ?? NativeWayfarerInduction.clinicUnit(owner: p.owner)
    return .init(
      unit: unit, coolingUnit: ScriptIdentity.uuid("induction-sealed-cooling-v1:\(unit)"),
      operation: try NativeWayfarerInduction.pickupOperation(
        permission: p.operation, dock: source, carrier: p.carrier, revision: 1, flightSeconds: 60),
      dock: source, carrier: p.carrier, inventoryRevision: 1, physicalTime: 31,
      issuedFlightSeconds: 60, allowance: allowance, deadline: deadline ?? 60 + allowance)
  }
  func loss(_ state: NativeWayfarerInductionState, escape: Bool = false, energy: Double = 0)
    -> NativeInductionCrateLoss
  {
    let context = ScriptEventContext(
      galaxy: 0, system: 185, docked: false, mainStation: false, revision: 2,
      frameSeconds: 0, localSeconds: 100, flightSeconds: 100, calendarSeconds: 100,
      transitSeconds: 0, playerPosition: .init(0, 0, 1000))
    return .init(
      carrier: state.permission.carrier, physicalTime: 100,
      facts: .init(
        cause: escape ? .escapePod : .shipDestroyed, sequence: 10, context: context,
        energy: energy, visit: 2))
  }

  @Test func inductionRequiresAnOwnedRecordedSaleOrActualCompletedDeliveryAndNeverAGenericFlag()
    throws
  {
    let (state, engine) = try fixture()
    let owner = state.permission.owner
    #expect(state.valid && state.payloads.isEmpty)
    #expect(NativeInductionTradeEvidence.first(in: engine, owner: owner) == state.permission.trade)
    #expect(state.permission.trade.valid(in: engine, owner: owner))
    #expect(!state.permission.trade.valid(in: engine, owner: UUID()))
    #expect(NativeInductionTradeEvidence.first(in: ScriptEngineState(), owner: owner) == nil)
    #expect(
      !NativeInductionTradeEvidence.delivery(UUID(), String(repeating: "0", count: 64))
        .valid(in: engine, owner: owner))
    #expect(!NativeInductionTradeEvidence.delivery(UUID(), "not-a-receipt").validShape)
    let otherMission = NativeWayfarerInduction.mission(owner: UUID())
    #expect(otherMission != state.permission.mission)
  }

  @Test func clinicPickupNeedsFreeHoldAndTheExactLaterRenasSourceAndCannotReissueTheOriginal()
    throws
  {
    let (state, _) = try fixture()
    let original = try crate(state)
    #expect(original.valid(permission: state.permission))
    #expect(throws: (any Error).self) { try state.collecting(original, freeTonnes: 0) }
    #expect(state.payloads.isEmpty && state.crate == nil)
    let held = try state.collecting(original, freeTonnes: 1)
    #expect(held.valid && held.payloads == [NativeWayfarerInduction.payload: 1])
    #expect(throws: (any Error).self) { try held.collecting(original, freeTonnes: 100) }
    for invalid in [
      try crate(state, source: state.permission.dock),
      try crate(state, source: dock(owner: UUID(), system: 185, visit: 2, sequence: 2)),
      try crate(state, unit: UUID()), try crate(state, allowance: 2700),
      try crate(state, deadline: 1861),
    ] {
      #expect(!invalid.valid(permission: state.permission))
      #expect(throws: (any Error).self) { try state.collecting(invalid, freeTonnes: 1) }
    }
    #expect(state.crate == nil)
  }

  @Test func fixedArmedFlightDeadlineSurvivesPauseAndLoadingWithoutBorrowingTheServiceAllowance()
    throws
  {
    let (state, _) = try fixture()
    let original = try crate(state)
    #expect(try original.remaining(at: 60) == 1800)
    #expect(try original.remaining(at: 60) == 1800)
    #expect(try original.remaining(at: 1859.5) == 0.5)
    #expect(try original.remaining(at: 1860) == 0)
    #expect(try original.remaining(at: 5000) == 0)
    let restored = try JSONDecoder().decode(
      NativeInductionClinicCrate.self, from: JSONEncoder().encode(original))
    #expect(restored == original && restored.deadline == 1860 && restored.allowance == 1800)
    #expect(try restored.remaining(at: 500) == 1360)
    for clock in [59.0, Double.nan, .infinity] {
      #expect(throws: (any Error).self) { try restored.remaining(at: clock) }
    }
    let malformed = try crate(state, deadline: .nan)
    #expect(throws: (any Error).self) { try malformed.remaining(at: 60) }
  }

  @Test func actualCarrierLossReleasesTheReservationWhileRetainingConsumedStockAndRejectingReplay()
    throws
  {
    let (state, _) = try fixture()
    let original = try crate(state)
    let held = try state.collecting(original, freeTonnes: 1)
    let lost = try held.losing(loss(held))
    #expect(lost.valid && lost.payloads.isEmpty && lost.crate == original)
    #expect(lost.permission == state.permission && lost.loss?.facts.energy == 0)
    #expect(throws: (any Error).self) { try lost.collecting(original, freeTonnes: 100) }
    #expect(throws: (any Error).self) { try lost.losing(loss(held)) }
    #expect(throws: (any Error).self) { try held.losing(loss(held, escape: true, energy: 0)) }
    let escaped = try held.losing(loss(held, escape: true, energy: 100))
    #expect(escaped.valid && escaped.payloads.isEmpty && escaped.crate?.unit == original.unit)
    #expect(held.payloads == [NativeWayfarerInduction.payload: 1])
  }

  @Test(arguments: [false, true])
  func strictInductionSchemaRejectsOldUnknownAndRewrittenDeadlinesAndPreservesLowerFeatures(
    alien: Bool
  ) throws {
    let (state, _) = try fixture()
    let held = try state.collecting(crate(state), freeTonnes: 1)
    var leaf = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(held)) as? [String: Any])
    func bytes(_ value: [String: Any]) throws -> Data {
      try JSONSerialization.data(withJSONObject: [
        "instances": [
          "opening": [
            "definition": NativeWayfarerInduction.stateID, "digest": NativeWayfarerInduction.digest,
            "savedWayfarerInduction": value,
          ]
        ]
      ])
    }
    let schema = alien ? 68 : 67
    try ScriptSaveJSONPreflight.validateRepairLoopFields(
      try bytes(leaf), part: .missions, schema: schema)
    #expect(throws: (any Error).self) {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(
        try bytes(leaf), part: .missions, schema: schema - 2)
    }
    leaf["accredited"] = true
    #expect(throws: (any Error).self) {
      try NativeWayfarerInductionSave.validateFields(
        try bytes(leaf), part: .missions, schema: schema)
    }
    leaf.removeValue(forKey: "accredited")
    var altered = try #require(leaf["crate"] as? [String: Any])
    altered["deadline"] = 3660
    leaf["crate"] = altered
    #expect(throws: (any Error).self) {
      try NativeWayfarerInductionSave.validateFields(
        try bytes(leaf), part: .missions, schema: schema)
    }
    let commerce = NativeWayfarerInductionSave.lowerSchema(schema)
    #expect(commerce == (alien ? 66 : 65))
    #expect(NativeFirstCommoditySaleSave.lowerSchema(commerce) == (alien ? 64 : 63))
  }

  @Test func bundledInductionSupportsOnlyCommissionAndClinicPickupWithItsOwnPublishedAllowance()
    throws
  {
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledWayfarerInductionDirectory)
    #expect(pack.digest == NativeWayfarerInduction.digest && pack.missingCapabilities.isEmpty)
    #expect(pack.manifest.mission.milestones.count == 14)
    #expect(NativeWayfarerInduction.commissionTarget == "senn-network-commission")
    #expect(NativeWayfarerInduction.clinicTarget == "renas-clinic-coldcrate")
    #expect(NativeWayfarerInduction.clinicItem == "clinic-cold-crate")
    #expect(NativeWayfarerInduction.receiver == SystemIdentity(galaxy: 0, system: 164))
    #expect(pack.manifest.wayfarerInduction?.flightAllowance == 1800)
    #expect(pack.manifest.handlers.map(\.event) == ["mission.accepted"])
    #expect(
      pack.manifest.trial == nil && pack.manifest.board == nil && pack.manifest.coldChain == nil)
    #expect(pack.manifest.mission.briefing.contains("1800"))
    #expect(pack.manifest.mission.briefing.contains("Navidor"))
    var invalid = pack.manifest
    invalid.wayfarerInduction = .init(profile: "native-senn-clinic-v1", flightAllowance: 2700)
    #expect(throws: (any Error).self) { try ScriptPackLibrary.validateWayfarerInduction(invalid) }
    invalid = pack.manifest
    invalid.glassMeridian = .init(profile: "native-clock-pair-v1")
    #expect(throws: (any Error).self) { try ScriptPackLibrary.validateWayfarerInduction(invalid) }
  }
}
