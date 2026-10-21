import Foundation
import Testing

@testable import EliteCore

struct NativeMeasuredExtractionFixture {
  let flight: OriginalSealedDispatchFixture
  let pack: ScriptPack
  var files: ScriptFreightFixture { flight.files }
  var save: URL { files.save }
  init() throws {
    flight = try OriginalSealedDispatchFixture()
    pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledMeasuredExtractionDirectory)
  }

  func runtime(freeTonnes: Int = 12, excessHardware: Bool = false) async throws -> GameRuntime {
    var game = try ScriptProcurementFixture.freshG03FlightGame()
    // Initial owned fit is a fixture; source bodies, all mining, docking and custody remain native.
    game.commander.shipID = "SH023"
    // Match the selected hull tank before any native equipment transaction validates it.
    game.commander.fuel = game.commander.fuelCapacity
    let requiredHardware: Set<String> = [
      TargetingTier.docking.equipmentName, NavigationTier.military.equipmentName,
      "Fuel Scoops", "Escape Pod", "Large Cargo Bay", LaserKind.mining.equipmentName,
      "Targeting: Mining Module", "Targeting: Salvage Module", "Salvage Cutter",
    ]
    game.commander.equipment = excessHardware ? Equipment.maximumHardware : requiredHardware
    game.commander.laserMounts = .init(front: .naval, left: .naval, right: .naval, rear: .naval)
    game.commander.xyzzyActive = true
    game.commander.autoTarget = true
    try game.commander.initializeEquipment(
      owner: UUID(), hull: UUID(), legacy: false, xyzzyGrant: true
    ) { UUID() }
    // Initialization retains add-on modules as held equipment. Fit the actual items;
    // the mining work-tool, core and scoops still come from the supported native fit.
    try game.commander.grantEquipment(
      "Targeting: Mining Module", at: .targetingMining, provenance: .xyzzy)
    try game.commander.grantEquipment(
      "Targeting: Salvage Module", at: .targetingSalvage, provenance: .xyzzy)
    game.commander.fuel = game.commander.fuelCapacity
    game.energy = game.commander.performance.energy
    game.frontShield = game.commander.shieldCapacity
    game.rearShield = game.commander.rearShieldCapacity
    game.commander.cargo[0] = game.commander.standardCargoCapacity - freeTonnes
    if !excessHardware { try #require(game.commander.passengerFit?.allowed == true) }
    game.scriptPacks = [pack]
    let runtime = GameRuntime(game: game, saveURL: save)
    try await runtime.save(to: save)
    await runtime.key("0")
    try await flight.dock(runtime)
    try #require(await runtime.snapshot().hasMeasuredExtractionFit)
    return runtime
  }

  func review(_ runtime: GameRuntime, _ action: NativeMeasuredExtractionAction) async throws
    -> ScriptPagePresentation
  {
    await runtime.key("contracts-open")
    let game = await runtime.snapshot()
    let index = try #require(game.contractBoard.rows.firstIndex { $0.measuredExtraction == action })
    for _ in 0..<abs(index - game.contractBoard.selection) {
      await runtime.key(index < game.contractBoard.selection ? "up" : "down")
    }
    let page = await runtime.snapshot().scriptPagePresentation
    await runtime.scriptPageKey("return", expected: page)
    try #require(await runtime.snapshot().contractBoard.action == .back)
    return await runtime.snapshot().scriptPagePresentation
  }
  func confirm(_ runtime: GameRuntime, _ action: NativeMeasuredExtractionAction) async throws {
    let page = try await review(runtime, action)
    let quote = try #require(await runtime.snapshot().contractBoard.measuredExtractionQuote)
    try #require(quote.allowed, "\(quote.issues)")
    await runtime.scriptPageKey("right", expected: page)
    await runtime.scriptPageKey("return", expected: page)
  }
  func state(_ runtime: GameRuntime) async throws -> NativeMeasuredExtractionState {
    try #require(await runtime.snapshot().measuredExtractionState)
  }
  func accept(_ runtime: GameRuntime) async throws {
    await runtime.beginScriptRefusalObservation()
    let page = try await review(runtime, .accept)
    let before = await runtime.snapshot()
    let reviewed = try #require(before.contractBoard.measuredExtractionQuote)
    try #require(reviewed.allowed, "\(reviewed.issues)")
    await runtime.scriptPageKey("right", expected: page)
    await runtime.scriptPageKey("return", expected: page)
    let accepted = await runtime.snapshot()
    let refusal = await runtime.scriptRefusalObservationDetail()
    let dock = accepted.commander.nativeStations?.currentMainDock
    let quote = accepted.contractBoard.measuredExtractionQuote
    let context =
      "dock=\(dock?.station.key ?? "none")/\(dock?.sequence ?? 0); dockCurrent=\(accepted.nativeMainStationDockEvidenceIsCurrent); quote=\(quote?.action.rawValue ?? "none")/\(String(describing: quote?.allowed)); issues=\(quote?.issues.joined(separator: ";") ?? "none")"
    var reconstruction = "not needed"
    if accepted.measuredExtractionState == nil {
      // Diagnostic only: this genuine reviewed candidate is never installed or saved.
      // It is not the discarded publication candidate and cannot prove their equality.
      var candidate = before
      do {
        try candidate.confirmMeasuredExtraction(reviewed)
        let commander = candidate.commander
        var facts: [String] = [
          "RECONSTRUCTED diagnostic candidate; actual publication candidate unavailable"
        ]
        facts.append(
          "actual rollback matches preconfirm commander=\(accepted.commander == before.commander)")
        facts.append(
          "epoch unchanged=\(candidate.nativeStationRuntimeEpoch == before.nativeStationRuntimeEpoch)"
        )
        facts.append(
          "physicalTime=\(commander.flightSimulation.physicalTime)/preconfirm=\(before.commander.flightSimulation.physicalTime)"
        )
        facts.append("commander=\(commander.valid)")
        facts.append("measuredClaims=\(NativeMeasuredExtractionSave.validateClaims(commander))")
        facts.append("recordClaims=\(WayfarerRecordRecoverySave.validateClaims(commander))")
        facts.append("identifiedClaims=\(NativeIdentifiedSalvageSave.validateClaims(commander))")
        facts.append("equipment=\(commander.equipmentStateValid)")
        facts.append("scriptState=\(commander.scriptState.valid)")
        facts.append(
          "contracts=\(commander.contractsValid); boardStorage=\(commander.contracts.valid)")
        facts.append(
          "issuedEquipment=\(commander.issuedEquipmentValid); legacyIssues=\(commander.legacyIssueStateValid)"
        )
        facts.append("station=\(commander.nativeStationStateValid)")
        facts.append("emp=\(commander.empCustodyStateValid)")
        facts.append("electrical=\(commander.electricalStateValid)")
        facts.append("alien=\(commander.alienStorageStateValid)")
        facts.append("salvageSources=\(commander.nativeSalvageOriginalSourcesValid)")
        facts.append("freight=\(commander.freightCargoValid)")
        facts.append("navigationTrade=\(commander.navigationTradeStateValid)")
        facts.append("markets=\(commander.originalMarkets.valid)")
        facts.append("finance=\(commander.financeStateValid)")
        facts.append("wormholes=\(commander.nativeWormholeHistoryValid)")
        facts.append("people=\(commander.nativePeopleStateValid)")
        facts.append("accommodation=\(commander.accommodationValid)")
        facts.append(
          "cargo=\(String(describing: commander.checkedCargoTonnes))/capacity=\(commander.capacity)"
        )
        facts.append("fuel=\(commander.fuel)/capacity=\(commander.fuelCapacity)")
        facts.append("missiles=\(commander.missiles)/capacity=\(commander.missileCapacity)")
        facts.append(
          "flight=\(commander.flightSimulation.valid); mining=\(commander.miningLedger.valid); debris=\(commander.cargoDebrisLedger.valid); npcs=\(commander.npcPersistence.valid)"
        )
        facts.append(
          "navigation=\(commander.navigationPlan?.valid ?? true); blackjack=\(commander.blackjack.valid)"
        )
        facts.append(
          "equipmentNames=\(commander.equipment.isSubset(of: Equipment.validNames)); nameCount=\(commander.name.count)"
        )
        facts.append(
          "scriptNextEvent=\(commander.scriptState.nextEvent); calendar=\(commander.scriptState.calendarSeconds)"
        )
        if let source = commander.scriptState.savedMeasuredExtractionSource {
          facts.append(
            "sourceIdentity=\(source.id == NativeMeasuredExtraction.identity(source.owner)); sourceOwner=\(source.owner.world == commander.equipmentOwnerID); historicalDock=\(NativeMeasuredExtractionSave.historicalDock(source.registration, commander: commander))"
          )
          let bytes = try JSONEncoder().encode(source)
          facts.append("reconstructed source=\(String(decoding: bytes, as: UTF8.self))")
        }
        if let state = candidate.measuredExtractionState {
          facts.append(
            "permissionReach=\(state.permission.reach.valid); permissionRoute=\(NativeMeasuredExtraction.route(state.permission.reach))"
          )
          let bytes = try JSONEncoder().encode(state)
          facts.append("reconstructed state=\(String(decoding: bytes, as: UTF8.self))")
          if let mission = commander.scriptState.instances[state.permission.mission] {
            facts.append("contractValid=\(mission.contract?.valid ?? false)")
            let bytes = try JSONEncoder().encode(mission)
            facts.append("reconstructed mission=\(String(decoding: bytes, as: UTF8.self))")
            if let key = mission.contract?.boardKey, let board = commander.contracts.boards[key] {
              let bytes = try JSONEncoder().encode(board)
              facts.append("reconstructed board=\(String(decoding: bytes, as: UTF8.self))")
            }
          }
        }
        reconstruction = facts.joined(separator: "; ")
      } catch {
        reconstruction =
          "RECONSTRUCTED diagnostic candidate threw \(error); never installed or saved"
      }
    }
    try #require(
      accepted.measuredExtractionState != nil,
      "Native acceptance: \(accepted.message); action=\(accepted.contractBoard.action); detail=\(accepted.contractBoard.detail); \(context); refusal=\(refusal ?? "none"); \(reconstruction)"
    )
  }

  func aim(_ runtime: GameRuntime) async throws {
    await runtime.key("escape")
    await runtime.key("0")
    await runtime.nativeCommand { game in
      guard let rock = game.measuredExtractionRock else { return }
      var pose = game.commander.flightSimulation.pose
      pose.position = rock.position - pose.orientation.apply(.init(0, 0, 1000))
      NativeStationTestFixture.reframe(&game, to: pose)
      game.speed = 0
      game.pitch = 0
      game.yaw = 0
      game.roll = 0
    }
    _ = await runtime.advance(delta: 0.01)
    let natural = await runtime.snapshot()
    try #require(natural.bodies.contains { $0.physical?.rock == NativeMeasuredExtraction.root })
    for _ in 0..<4 {
      if await runtime.snapshot().workTargetFilter == .mining { break }
      await runtime.key("f")
    }
    for _ in 0..<100 {
      await runtime.key("tab")
      if await runtime.snapshot().informationTargetBody?.physical?.rock
        == NativeMeasuredExtraction.root
      {
        break
      }
    }
    try #require(
      await runtime.snapshot().informationTargetBody?.physical?.rock
        == NativeMeasuredExtraction.root)
    await runtime.key("w")
    try #require(await runtime.snapshot().selectedFlightTool == .miningLaser)
  }
  func extract(_ runtime: GameRuntime) async throws {
    try await aim(runtime)
    var controls = Controls()
    controls.fire = true
    await runtime.setControls(controls)
    for _ in 0..<1000 {
      _ = await runtime.advance(delta: 0.05)
      if await runtime.snapshot().commander.miningLedger.isDepleted(NativeMeasuredExtraction.root) {
        break
      }
    }
    await runtime.setControls(Controls())
    let game = await runtime.snapshot()
    try #require(game.measuredExtractionState?.extraction != nil)
    try #require(game.commander.miningLedger.isDepleted(NativeMeasuredExtraction.root))
    try #require(game.dischargeAudio.events.contains { $0.tool == .miningLaser })
  }

  func framePayload(
    _ runtime: GameRuntime, payload: PayloadIdentity, offset: Vector3 = .init(0, -45, 55)
  ) async throws {
    await runtime.nativeCommand { game in
      guard let body = game.bodies.first(where: { $0.physical?.payload == payload }) else { return }
      var pose = game.commander.flightSimulation.pose
      pose.position = pose.systemPoint(body.position) - pose.orientation.apply(offset)
      NativeStationTestFixture.reframe(&game, to: pose)
      game.speed = 0
      game.pitch = 0
      game.yaw = 0
      game.roll = 0
    }
    try #require(await runtime.snapshot().bodies.contains { $0.physical?.payload == payload })
  }
  func collect(_ runtime: GameRuntime, count: Int = 12) async throws {
    for _ in 0..<100 {
      let game = await runtime.snapshot()
      if game.measuredExtractionState?.captures.count ?? 0 >= count { break }
      if let body = game.bodies.first(where: { body in
        guard let payload = body.physical?.payload else { return false }
        return game.measuredPayloadIsAllocated(payload)
      }), let payload = body.physical?.payload {
        try await framePayload(runtime, payload: payload)
      }
      _ = await runtime.advance(delta: 0.01)
    }
    try #require(try await state(runtime).captures.count >= count)
  }
  func renas(_ runtime: GameRuntime) async throws {
    try await flight.dock(runtime)
    await runtime.procurementRefuel()
    try await flight.travel(runtime, path: [7, 185])
  }
}

struct NativeMeasuredExtractionJourneyTests {
  @Test func actualNaturalMiningTwelveOriginalScoopsProcessingAndSeparateReceiverPaysOnce()
    async throws
  {
    let f = try NativeMeasuredExtractionFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    let before = await runtime.snapshot().commander
    try await f.accept(runtime)
    let allocated = await runtime.snapshot()
    #expect(allocated.commander.cargoTonnes == before.cargoTonnes + 12)
    #expect(allocated.commander.cargo == before.cargo)
    #expect(OriginalServiceReservationPolicy.activeCount(allocated.commander.scriptState) == 1)
    try await f.extract(runtime)
    let extracted = await runtime.snapshot()
    let witness = try #require(extracted.measuredExtractionState?.extraction)
    #expect(
      witness.emitted.count == 20 && witness.emitted.reduce(0) { $0 + $1.amount.quantity } == 20)
    #expect(extracted.commander.miningLedger.breakups[NativeMeasuredExtraction.root] == nil)
    #expect(extracted.commander.cargo == before.cargo)
    try await f.collect(runtime)
    let aboard = await runtime.snapshot()
    #expect(
      aboard.commander.cargo == before.cargo
        && aboard.commander.cargoTonnes == allocated.commander.cargoTonnes)
    #expect(
      aboard.commander.miningLedger.pendingPayloads.filter { item in
        if case .ore(let root, _) = item.identity { return root == NativeMeasuredExtraction.root }
        return false
      }.count == 8)
    try await f.renas(runtime)
    let raw = await runtime.snapshot()
    #expect(!raw.measuredExtractionReview(.receive).allowed)
    let cash = raw.commander.credits
    try await f.confirm(runtime, .process)
    let graded = await runtime.snapshot()
    let state = try #require(graded.measuredExtractionState)
    let processing = try #require(state.processing)
    #expect(
      processing.products.count == 12 && processing.products.reduce(0) { $0 + $1.massKg } == 12000)
    #expect(Set(processing.products.map(\.input)) == Set(processing.inputs))
    #expect(
      graded.commander.credits == cash && graded.commander.cargoTonnes == raw.commander.cargoTonnes)
    #expect(!graded.measuredExtractionReview(.process).allowed)
    #expect(graded.commander.scriptState.savedClueJournal == nil)
    try await f.confirm(runtime, .receive)
    let received = await runtime.snapshot()
    #expect(received.commander.credits == cash + 8900)
    #expect(received.commander.cargoTonnes == raw.commander.cargoTonnes - 12)
    #expect(
      received.commander.scriptState.instances[state.permission.mission]?.outcome == .complete)
    #expect(
      received.commander.scriptState.instances[state.permission.mission]?.milestones == [
        0, 1, 2, 3, 4,
      ])
    #expect(
      NativeMeasuredExtractionSave.validateClaims(received.commander, requireRecordedLoss: true))
    await runtime.key("return")
    #expect(await runtime.snapshot().commander.credits == cash + 8900)
  }

  @Test func twelveFreeTonnesAndRequiredToolsStillRefuseAnOverBudgetEquipmentFit() async throws {
    let f = try NativeMeasuredExtractionFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime(excessHardware: true)
    let page = try await f.review(runtime, .accept)
    let before = await runtime.snapshot()
    try #require(before.hasMeasuredExtractionFit)
    try #require(before.commander.checkedCargoTonnes == before.commander.standardCargoCapacity - 12)
    let fit = try #require(before.commander.passengerFit)
    try #require(!fit.allowed && fit.freeEquipmentUnits < 0)
    let quote = try #require(before.contractBoard.measuredExtractionQuote)
    #expect(!quote.allowed)
    #expect(fit.issues.allSatisfy { quote.issues.contains($0) })
    await runtime.scriptPageKey("right", expected: page)
    await runtime.scriptPageKey("return", expected: page)
    let refused = await runtime.snapshot()
    #expect(refused.commander == before.commander)
    #expect(refused.measuredExtractionState == nil)
    #expect(refused.commander.scriptState.savedMeasuredExtractionSource == nil)
  }

  @Test func officeBackAndInsufficientHoldCannotAllocateFiniteSource() async throws {
    let f = try NativeMeasuredExtractionFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime(freeTonnes: 11)
    let before = await runtime.snapshot().commander
    let page = try await f.review(runtime, .accept)
    #expect(await runtime.snapshot().contractBoard.measuredExtractionQuote?.allowed == false)
    await runtime.scriptPageKey("return", expected: page)
    #expect(await runtime.snapshot().commander == before)
    #expect(await runtime.snapshot().measuredExtractionState == nil)
  }

  @Test func departureExpiresUncollectedOriginalsAndPartialSurvivorsRequireUnpaidSourceReturn()
    async throws
  {
    let f = try NativeMeasuredExtractionFixture()
    defer { f.files.clean() }
    let runtime = try await f.runtime()
    try await f.accept(runtime)
    try await f.extract(runtime)
    try await f.collect(runtime, count: 1)
    let aboard = await runtime.snapshot()
    let held = try #require(aboard.commander.scriptState.savedMeasuredExtractionSource).originals
      .filter {
        if case .raw = $0.custody { return true }
        return false
      }.count
    try #require(held > 0 && held < 12)
    try await f.renas(runtime)
    let failed = await runtime.snapshot()
    let state = try #require(failed.measuredExtractionState)
    #expect(failed.commander.scriptState.instances[state.permission.mission]?.outcome == .failed)
    #expect(failed.commander.cargoTonnes == aboard.commander.cargoTonnes - (12 - held))
    #expect(
      !failed.measuredExtractionReview(.cancel).allowed
        && !failed.measuredExtractionReview(.process).allowed)
    await runtime.procurementRefuel()
    try await f.flight.travel(runtime, path: [185, 7])
    let cash = await runtime.snapshot().commander.credits
    try await f.confirm(runtime, .cancel)
    let returned = await runtime.snapshot()
    #expect(returned.commander.credits == cash)
    #expect(returned.commander.cargoTonnes == failed.commander.cargoTonnes - held)
    #expect(returned.commander.scriptState.savedClueJournal == nil)
    #expect(
      NativeMeasuredExtractionSave.validateClaims(returned.commander, requireRecordedLoss: true))
  }
}
