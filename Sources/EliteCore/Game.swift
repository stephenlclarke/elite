import Foundation

/// Synchronous dock preparation owns its rollback values off the active call stack.
private final class DockPersistenceSnapshot {
  private let commander: Commander
  private let work: NativeSalvageHotWork?
  private let wreckMotion: [WreckIdentity: NativeSalvageWreckObservation]
  private let lotMotion: [SalvageLotIdentity: NativeSalvageMotion]

  @inline(never)
  init(_ game: borrowing Game) {
    commander = game.commander
    work = game.nativeSalvageWork
    wreckMotion = game.nativeSalvageWreckMotion
    lotMotion = game.nativeSalvageMotion
  }

  @inline(never)
  func restore(to game: inout Game) {
    game.commander = commander
    game.nativeSalvageWork = work
    game.nativeSalvageWreckMotion = wreckMotion
    game.nativeSalvageMotion = lotMotion
  }
}

public enum Screen: String, Codable, Sendable, CaseIterable {
  case demo, title, front, rear, left, right, chart, shortChart, system, market, status, inventory,
    equipment, buy, sell, secret, help, mission, handoff, gallery, navigation, showroom, rumour,
    gameOver, contracts, library
  public var isFlight: Bool { [.front, .rear, .left, .right].contains(self) }
}

/// A Commander-owned value: one COW payload, encoded exactly as the original script-state value.
private struct CommanderScriptStateStorage: Sendable, Equatable, Codable {
  private var values: [ScriptEngineState]

  init(_ value: consuming ScriptEngineState) {
    values = [consume value]
  }

  var value: ScriptEngineState {
    _read { yield values[0] }
    _modify { yield &values[0] }
  }

  func withReadOnlyValue<Result>(
    _ read: (borrowing ScriptEngineState) throws -> Result
  ) rethrows -> Result {
    try values.withUnsafeBufferPointer { storage in
      try read(storage.baseAddress!.pointee)
    }
  }

  init(from decoder: Decoder) throws {
    values = [try ScriptEngineState(from: decoder)]
  }

  func encode(to encoder: Encoder) throws {
    try withReadOnlyValue { try $0.encode(to: encoder) }
  }
}

/// Native custody retains value semantics without growing every inline Commander copy.
private struct CommanderNativePeopleCustodyStorage: Sendable, Equatable, Codable {
  private var values: [NativePeopleCustodyState?]

  init(_ value: consuming NativePeopleCustodyState?) {
    values = [consume value]
  }

  var value: NativePeopleCustodyState? {
    _read { yield values[0] }
    _modify { yield &values[0] }
  }

  func withReadOnlyValue<Result>(
    _ read: (borrowing NativePeopleCustodyState?) throws -> Result
  ) rethrows -> Result {
    try values.withUnsafeBufferPointer { storage in
      try read(storage.baseAddress!.pointee)
    }
  }

  init(from decoder: Decoder) throws {
    values = [try NativePeopleCustodyState(from: decoder)]
  }

  func encode(to encoder: Encoder) throws {
    try withReadOnlyValue { try $0.encode(to: encoder) }
  }
}

public struct Commander: Sendable, Equatable, Codable {
  private var savedContracts: ScriptContractState?
  public var contracts: ScriptContractState {
    get { savedContracts ?? ScriptContractState() }
    set { savedContracts = newValue == ScriptContractState() ? nil : newValue }
  }
  var legacyOwnedEquipment: LegacyOwnedEquipmentInventory?
  private var savedAccommodation: ShipAccommodation?
  public var accommodation: ShipAccommodation {
    get { savedAccommodation ?? ShipAccommodation() }
    set { savedAccommodation = newValue }
  }
  private var savedScriptState: CommanderScriptStateStorage?
  public var scriptState: ScriptEngineState {
    _read {
      if let stored = savedScriptState {
        yield stored.value
      } else {
        let empty = ScriptEngineState()
        yield empty
      }
    }
    set { savedScriptState = newValue == ScriptEngineState() ? nil : .init(newValue) }
    _modify {
      if case .none = savedScriptState { savedScriptState = .init(ScriptEngineState()) }
      defer {
        if savedScriptState?.withReadOnlyValue({ $0.nextEvent }) == 0,
          savedScriptState?.withReadOnlyValue({ $0 == ScriptEngineState() }) == true
        {
          savedScriptState = nil
        }
      }
      yield &savedScriptState!.value
    }
  }

  func withReadOnlyScriptState<Result>(
    _ read: (borrowing ScriptEngineState) throws -> Result
  ) rethrows -> Result {
    if let stored = savedScriptState { return try stored.withReadOnlyValue(read) }
    return try Self.withDefaultScriptState(read)
  }

  @inline(never)
  private static func withDefaultScriptState<Result>(
    _ read: (borrowing ScriptEngineState) throws -> Result
  ) rethrows -> Result {
    let empty = ScriptEngineState()
    return try read(empty)
  }
  // Read only child storage here: no Commander value crosses the pointer boundary.
  fileprivate static func nativeStationReadScriptState<Result>(
    at commander: UnsafePointer<Commander>,
    _ read: (borrowing ScriptEngineState) -> Result
  ) -> Result {
    if let stored = commander.pointee.savedScriptState { return stored.withReadOnlyValue(read) }
    return Self.withDefaultScriptState(read)
  }

  fileprivate static func nativeStationReadFlight(
    at commander: UnsafePointer<Commander>
  ) -> FlightSimulationState {
    if let flight = commander.pointee.savedFlightSimulation { return flight }
    return FlightSimulationState()
  }

  @inline(never)
  static func nativeStationStateIsValid(_ commander: borrowing Commander) -> Bool {
    withUnsafePointer(to: commander) { pointer in
      Self.nativeStationStateIsValid(at: pointer)
    }
  }

  // Capture only this read-only pointer, never the borrowed Commander, in the policy readers.
  fileprivate static func nativeStationStateIsValid(at commander: UnsafePointer<Commander>) -> Bool
  {
    NativeStationStateValidation.check(
      readWorld: { commander.pointee.nativeStations },
      readResources: {
        Self.nativeStationReadScriptState(at: commander) { $0.stationResources }
      },
      readSystem: {
        SystemIdentity(galaxy: commander.pointee.galaxy, system: commander.pointee.system)
      },
      readOwner: { commander.pointee.savedEquipmentInventory?.owner },
      readPhysicalTime: { Self.nativeStationReadFlight(at: commander).physicalTime },
      readStationPosition: {
        Self.nativeStationReadFlight(at: commander).anchors?.station.position
      },
      readCalendar: {
        Self.nativeStationReadScriptState(at: commander) { $0.calendarLedger }
      })
  }

  var savedEquipmentInventory: OwnedEquipmentInventory?
  var savedEquipmentPurchaseHistory: EquipmentPurchaseHistory?
  var savedEMPState: EMPState?
  var savedPlayerElectrical: ElectricalReserve?
  var savedEMPCharge: EMPChargeState?
  var savedCrimboState: NativeCrimboRegistry?
  private var savedNativePeopleCustodyStorage: CommanderNativePeopleCustodyStorage?
  var savedNativePeopleCustody: NativePeopleCustodyState? {
    _read {
      if let stored = savedNativePeopleCustodyStorage {
        yield stored.value
      } else {
        let absent: NativePeopleCustodyState? = nil
        yield absent
      }
    }
    set {
      if let newValue {
        savedNativePeopleCustodyStorage = .init(newValue)
      } else {
        savedNativePeopleCustodyStorage = nil
      }
    }
    _modify {
      if case .none = savedNativePeopleCustodyStorage {
        savedNativePeopleCustodyStorage = .init(nil)
      }
      defer {
        // A nil inout result must retain the original absent-key encoding and equality.
        if savedNativePeopleCustodyStorage?.withReadOnlyValue({
          if case .none = $0 { return true }
          return false
        }) == true {
          savedNativePeopleCustodyStorage = nil
        }
      }
      yield &savedNativePeopleCustodyStorage!.value
    }
  }
  var savedSalvageLedger: SalvageLedger?
  var savedAlienStorageReference: AlienStorageReference?
  var alienStorageState: AlienCommanderStorage? = nil
  var savedEquipmentVersion: Int?
  var nativeStations: NativeStationWorld?
  private var savedFlightSimulation: FlightSimulationState?
  public var flightSimulation: FlightSimulationState {
    _read {
      if case .some = savedFlightSimulation {
        yield savedFlightSimulation!
      } else {
        let empty = FlightSimulationState()
        yield empty
      }
    }
    set { savedFlightSimulation = newValue }
  }
  private var savedCrimeLedger: CrimeLedger?
  public var crimeLedger: CrimeLedger {
    get { savedCrimeLedger ?? CrimeLedger() }
    set { savedCrimeLedger = newValue }
  }
  private var savedStationSecurity: StationSecurity?
  public var stationSecurity: StationSecurity {
    get { savedStationSecurity ?? StationSecurity() }
    set { savedStationSecurity = newValue }
  }
  public var encounterDirector: EncounterDirector?
  private var savedWantedCareers: WantedCareerLedger?
  public var wantedCareers: WantedCareerLedger {
    get { savedWantedCareers ?? WantedCareerLedger() }
    set { savedWantedCareers = newValue }
  }
  /// Optional chaining preserves the absent state when no careers have been recorded.
  mutating func resetWantedCareerBindings(system: SystemIdentity) {
    savedWantedCareers?.resetPhysicalBindings(system: system)
  }
  private var savedNPCPersistence: NPCPersistenceLedger?
  public var npcPersistence: NPCPersistenceLedger {
    get { savedNPCPersistence ?? NPCPersistenceLedger() }
    set { savedNPCPersistence = newValue }
  }
  private var savedCargoDebrisLedger: CargoDebrisLedger?
  public var cargoDebrisLedger: CargoDebrisLedger {
    get { savedCargoDebrisLedger ?? CargoDebrisLedger() }
    set { savedCargoDebrisLedger = newValue }
  }
  private var savedMiningLedger: MiningLedger?
  var usesRingMiningSaveVersion: Bool { savedMiningLedger?.usesRingSaveVersion == true }
  var usesEconomyMiningSaveVersion: Bool {
    savedMiningLedger?.usesEconomyWeightedPresence == true
  }
  func miningLedgerForMigration(legacyMissing: Bool) -> MiningLedger {
    savedMiningLedger ?? (legacyMissing ? .legacyUnworked() : MiningLedger())
  }
  public var miningLedger: MiningLedger {
    get { savedMiningLedger ?? MiningLedger() }
    set { savedMiningLedger = newValue }
  }
  private var savedMissionProgress: [String: MissionProgress]?
  public var missionProgress: [String: MissionProgress] {
    get { savedMissionProgress ?? [:] }
    set { savedMissionProgress = newValue }
  }
  public var missionPayloadTonnes: Int {
    checkedMissionPayloadTonnes ?? Int.max
  }
  private var wantedAmnesty: Bool?
  public var xyzzyWantedAmnesty: Bool {
    get { wantedAmnesty ?? false }
    set { wantedAmnesty = newValue }
  }
  private var ownedShipID: String?
  public var shipID: String {
    get { ownedShipID ?? "SH023" }
    set { ownedShipID = newValue }
  }
  public var originalMarkets = OriginalLiveMarkets()
  public var name = NewCommanderDefaults.name
  public var credits = NewCommanderDefaults.credits
  public var fuel = NewCommanderDefaults.fuel
  public var galaxy = NewCommanderDefaults.galaxy
  public var system = NewCommanderDefaults.system
  public var cargo = Array(repeating: 0, count: 17)
  public var equipment: Set<String> = ["Pulse Laser"]
  public var missiles = 3
  public var kills = 0
  public var legal = 0
  public var unlimitedMissiles = false
  public var unlimitedCargo = false
  public var unlimitedCash = false
  public var unlimitedFuel = false
  public var unlimitedJumps = false
  public var autoTrade = false
  public var speech = false
  public var executive = false
  // Optional storage preserves compatibility with commanders saved before each feature existed.
  private var discoveredSecretPorts: Int?
  public var plughDiscoveryMask: Int {
    get { discoveredSecretPorts ?? 0 }
    set { discoveredSecretPorts = newValue }
  }
  private var blackjackMission: BlackjackMission?
  public var blackjack: BlackjackMission {
    get { blackjackMission ?? BlackjackMission() }
    set { blackjackMission = newValue }
  }
  private var displayStyle: ShipDisplayStyle?
  private var navalMission: NavalMissionStage?
  private var xyzzyEnabled: Bool?
  private var automaticProfitScan: Bool?
  public var profitScanEnabled: Bool {
    get { automaticProfitScan ?? false }
    set { automaticProfitScan = newValue }
  }
  private var automaticECM: Bool?
  private var automaticTargeting: Bool?
  private var returnFireEnabled: Bool?
  private var capitalReward: Bool?
  private var navigationRoute: NavigationPlan?
  private var storageUnitCount: Int?
  private var mountedLasers: LaserMounts?
  public var laserMounts: LaserMounts {
    get {
      guard equipmentInventory != nil else {
        return mountedLasers ?? LaserMounts(front: legacyLaser)
      }
      var mounts = LaserMounts()
      for mount in LaserMount.allCases {
        mounts[mount] = fittedEquipment(at: .laser(mount)).flatMap { LaserKind.from($0.node.key) }
      }
      return mounts
    }
    set { mountedLasers = newValue }
  }
  private var finiteXYZzyCash: Bool?
  public var xyzzyCashGranted: Bool {
    get { finiteXYZzyCash ?? false }
    set { finiteXYZzyCash = newValue }
  }
  public var fuelStorageUnits: Int {
    get {
      guard let inventory = equipmentInventory else { return storageUnitCount ?? 0 }
      return inventory.items.filter {
        if case .some(.fuelStorage) = $0.location?.slot { return true }
        return false
      }.count
    }
    set { storageUnitCount = newValue }
  }
  public var navigationPlan: NavigationPlan? {
    get { navigationRoute }
    set { navigationRoute = newValue }
  }
  public var capitalRewardClaimed: Bool {
    get { capitalReward ?? false }
    set { capitalReward = newValue }
  }
  public var retaliationEnabled: Bool {
    get { returnFireEnabled ?? true }
    set { returnFireEnabled = newValue }
  }
  public var xyzzyActive: Bool {
    get { xyzzyEnabled ?? false }
    set { xyzzyEnabled = newValue }
  }
  public var autoECM: Bool {
    get { automaticECM ?? false }
    set { automaticECM = newValue }
  }
  public var autoTarget: Bool {
    get { automaticTargeting ?? false }
    set { automaticTargeting = newValue }
  }
  public var missionStage: NavalMissionStage {
    get { navalMission ?? .notStarted }
    set { navalMission = newValue }
  }
  public var shipDisplayStyle: ShipDisplayStyle {
    get { displayStyle ?? .shadedPanels }
    set { displayStyle = newValue }
  }
  mutating func migrateLegacyXYZzyMounts() {
    if mountedLasers == nil && xyzzyActive {
      mountedLasers = LaserMounts(front: .naval, left: .naval, right: .naval, rear: .naval)
      equipment.insert(Equipment.navalLaser)
    }
  }
  private enum CodingKeys: String, CodingKey {
    case savedContracts
    case legacyOwnedEquipment = "ownedEquipment"
    case savedAccommodation
    case savedScriptState
    case savedEquipmentInventory
    case savedEquipmentPurchaseHistory
    case savedEMPState
    case savedPlayerElectrical
    case savedEMPCharge
    case savedNativePeopleCustodyStorage = "savedNativePeopleCustody"
    case savedCrimboState
    case savedSalvageLedger
    case savedAlienStorageReference
    case savedEquipmentVersion
    case nativeStations
    case savedFlightSimulation
    case savedCrimeLedger
    case savedStationSecurity
    case encounterDirector
    case savedNPCPersistence
    case savedWantedCareers
    case savedCargoDebrisLedger
    case savedMiningLedger
    case savedMissionProgress
    case wantedAmnesty
    case ownedShipID
    case originalMarkets
    case name
    case credits
    case fuel
    case galaxy
    case system
    case cargo
    case equipment
    case missiles
    case kills
    case legal
    case unlimitedMissiles
    case unlimitedCargo
    case unlimitedCash
    case unlimitedFuel
    case unlimitedJumps
    case autoTrade
    case speech
    case executive
    case discoveredSecretPorts
    case blackjackMission
    case displayStyle
    case navalMission
    case xyzzyEnabled
    case automaticProfitScan
    case automaticECM
    case automaticTargeting
    case returnFireEnabled
    case capitalReward
    case navigationRoute
    case storageUnitCount
    case mountedLasers
    case finiteXYZzyCash
  }

  // Preserve complete stored-value equality while retiring each field's temporaries in turn.
  @inline(never)
  public static func == (_ lhs: Self, _ rhs: Self) -> Bool {
    guard equalSavedContracts(lhs, rhs) else { return false }
    guard equalLegacyOwnedEquipment(lhs, rhs) else { return false }
    guard equalSavedAccommodation(lhs, rhs) else { return false }
    guard equalSavedScriptState(lhs, rhs) else { return false }
    guard equalSavedEquipmentInventory(lhs, rhs) else { return false }
    guard equalSavedEquipmentPurchaseHistory(lhs, rhs) else { return false }
    guard equalSavedEMPState(lhs, rhs) else { return false }
    guard equalSavedPlayerElectrical(lhs, rhs) else { return false }
    guard equalSavedEMPCharge(lhs, rhs) else { return false }
    guard equalSavedCrimboState(lhs, rhs) else { return false }
    guard equalSavedNativePeopleCustodyStorage(lhs, rhs) else { return false }
    guard equalSavedSalvageLedger(lhs, rhs) else { return false }
    guard equalSavedAlienStorageReference(lhs, rhs) else { return false }
    guard equalAlienStorageState(lhs, rhs) else { return false }
    guard equalSavedEquipmentVersion(lhs, rhs) else { return false }
    guard equalNativeStations(lhs, rhs) else { return false }
    guard equalSavedFlightSimulation(lhs, rhs) else { return false }
    guard equalSavedCrimeLedger(lhs, rhs) else { return false }
    guard equalSavedStationSecurity(lhs, rhs) else { return false }
    guard equalEncounterDirector(lhs, rhs) else { return false }
    guard equalSavedWantedCareers(lhs, rhs) else { return false }
    guard equalSavedNPCPersistence(lhs, rhs) else { return false }
    guard equalSavedCargoDebrisLedger(lhs, rhs) else { return false }
    guard equalSavedMiningLedger(lhs, rhs) else { return false }
    guard equalSavedMissionProgress(lhs, rhs) else { return false }
    guard equalWantedAmnesty(lhs, rhs) else { return false }
    guard equalOwnedShipID(lhs, rhs) else { return false }
    guard equalOriginalMarkets(lhs, rhs) else { return false }
    guard equalName(lhs, rhs) else { return false }
    guard equalCredits(lhs, rhs) else { return false }
    guard equalFuel(lhs, rhs) else { return false }
    guard equalGalaxy(lhs, rhs) else { return false }
    guard equalSystem(lhs, rhs) else { return false }
    guard equalCargo(lhs, rhs) else { return false }
    guard equalEquipment(lhs, rhs) else { return false }
    guard equalMissiles(lhs, rhs) else { return false }
    guard equalKills(lhs, rhs) else { return false }
    guard equalLegal(lhs, rhs) else { return false }
    guard equalUnlimitedMissiles(lhs, rhs) else { return false }
    guard equalUnlimitedCargo(lhs, rhs) else { return false }
    guard equalUnlimitedCash(lhs, rhs) else { return false }
    guard equalUnlimitedFuel(lhs, rhs) else { return false }
    guard equalUnlimitedJumps(lhs, rhs) else { return false }
    guard equalAutoTrade(lhs, rhs) else { return false }
    guard equalSpeech(lhs, rhs) else { return false }
    guard equalExecutive(lhs, rhs) else { return false }
    guard equalDiscoveredSecretPorts(lhs, rhs) else { return false }
    guard equalBlackjackMission(lhs, rhs) else { return false }
    guard equalDisplayStyle(lhs, rhs) else { return false }
    guard equalNavalMission(lhs, rhs) else { return false }
    guard equalXyzzyEnabled(lhs, rhs) else { return false }
    guard equalAutomaticProfitScan(lhs, rhs) else { return false }
    guard equalAutomaticECM(lhs, rhs) else { return false }
    guard equalAutomaticTargeting(lhs, rhs) else { return false }
    guard equalReturnFireEnabled(lhs, rhs) else { return false }
    guard equalCapitalReward(lhs, rhs) else { return false }
    guard equalNavigationRoute(lhs, rhs) else { return false }
    guard equalStorageUnitCount(lhs, rhs) else { return false }
    guard equalMountedLasers(lhs, rhs) else { return false }
    guard equalFiniteXYZzyCash(lhs, rhs) else { return false }
    return true
  }

  @inline(never)
  private static func equalSavedContracts(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.savedContracts == rhs.savedContracts
  }

  @inline(never)
  private static func equalLegacyOwnedEquipment(_ lhs: borrowing Self, _ rhs: borrowing Self)
    -> Bool
  {
    lhs.legacyOwnedEquipment == rhs.legacyOwnedEquipment
  }

  @inline(never)
  private static func equalSavedAccommodation(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool
  {
    lhs.savedAccommodation == rhs.savedAccommodation
  }

  @inline(never)
  private static func equalSavedScriptState(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.savedScriptState == rhs.savedScriptState
  }

  @inline(never)
  private static func equalSavedEquipmentInventory(_ lhs: borrowing Self, _ rhs: borrowing Self)
    -> Bool
  {
    lhs.savedEquipmentInventory == rhs.savedEquipmentInventory
  }

  @inline(never)
  private static func equalSavedEquipmentPurchaseHistory(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    lhs.savedEquipmentPurchaseHistory == rhs.savedEquipmentPurchaseHistory
  }

  @inline(never)
  private static func equalSavedEMPState(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.savedEMPState == rhs.savedEMPState
  }

  @inline(never)
  private static func equalSavedPlayerElectrical(_ lhs: borrowing Self, _ rhs: borrowing Self)
    -> Bool
  {
    lhs.savedPlayerElectrical == rhs.savedPlayerElectrical
  }

  @inline(never)
  private static func equalSavedEMPCharge(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.savedEMPCharge == rhs.savedEMPCharge
  }

  @inline(never)
  private static func equalSavedCrimboState(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.savedCrimboState == rhs.savedCrimboState
  }

  @inline(never)
  private static func equalSavedNativePeopleCustodyStorage(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    lhs.savedNativePeopleCustodyStorage == rhs.savedNativePeopleCustodyStorage
  }

  @inline(never)
  private static func equalSavedSalvageLedger(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool
  {
    lhs.savedSalvageLedger == rhs.savedSalvageLedger
  }

  @inline(never)
  private static func equalSavedAlienStorageReference(_ lhs: borrowing Self, _ rhs: borrowing Self)
    -> Bool
  {
    lhs.savedAlienStorageReference == rhs.savedAlienStorageReference
  }

  @inline(never)
  private static func equalAlienStorageState(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.alienStorageState == rhs.alienStorageState
  }

  @inline(never)
  private static func equalSavedEquipmentVersion(_ lhs: borrowing Self, _ rhs: borrowing Self)
    -> Bool
  {
    lhs.savedEquipmentVersion == rhs.savedEquipmentVersion
  }

  @inline(never)
  private static func equalNativeStations(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.nativeStations == rhs.nativeStations
  }

  @inline(never)
  private static func equalSavedFlightSimulation(_ lhs: borrowing Self, _ rhs: borrowing Self)
    -> Bool
  {
    lhs.savedFlightSimulation == rhs.savedFlightSimulation
  }

  @inline(never)
  private static func equalSavedCrimeLedger(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.savedCrimeLedger == rhs.savedCrimeLedger
  }

  @inline(never)
  private static func equalSavedStationSecurity(_ lhs: borrowing Self, _ rhs: borrowing Self)
    -> Bool
  {
    lhs.savedStationSecurity == rhs.savedStationSecurity
  }

  @inline(never)
  private static func equalEncounterDirector(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.encounterDirector == rhs.encounterDirector
  }

  @inline(never)
  private static func equalSavedWantedCareers(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool
  {
    lhs.savedWantedCareers == rhs.savedWantedCareers
  }

  @inline(never)
  private static func equalSavedNPCPersistence(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool
  {
    lhs.savedNPCPersistence == rhs.savedNPCPersistence
  }

  @inline(never)
  private static func equalSavedCargoDebrisLedger(_ lhs: borrowing Self, _ rhs: borrowing Self)
    -> Bool
  {
    lhs.savedCargoDebrisLedger == rhs.savedCargoDebrisLedger
  }

  @inline(never)
  private static func equalSavedMiningLedger(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.savedMiningLedger == rhs.savedMiningLedger
  }

  @inline(never)
  private static func equalSavedMissionProgress(_ lhs: borrowing Self, _ rhs: borrowing Self)
    -> Bool
  {
    lhs.savedMissionProgress == rhs.savedMissionProgress
  }

  @inline(never)
  private static func equalWantedAmnesty(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.wantedAmnesty == rhs.wantedAmnesty
  }

  @inline(never)
  private static func equalOwnedShipID(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.ownedShipID == rhs.ownedShipID
  }

  @inline(never)
  private static func equalOriginalMarkets(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.originalMarkets == rhs.originalMarkets
  }

  @inline(never)
  private static func equalName(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.name == rhs.name
  }

  @inline(never)
  private static func equalCredits(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.credits == rhs.credits
  }

  @inline(never)
  private static func equalFuel(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.fuel == rhs.fuel
  }

  @inline(never)
  private static func equalGalaxy(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.galaxy == rhs.galaxy
  }

  @inline(never)
  private static func equalSystem(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.system == rhs.system
  }

  @inline(never)
  private static func equalCargo(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.cargo == rhs.cargo
  }

  @inline(never)
  private static func equalEquipment(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.equipment == rhs.equipment
  }

  @inline(never)
  private static func equalMissiles(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.missiles == rhs.missiles
  }

  @inline(never)
  private static func equalKills(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.kills == rhs.kills
  }

  @inline(never)
  private static func equalLegal(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.legal == rhs.legal
  }

  @inline(never)
  private static func equalUnlimitedMissiles(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.unlimitedMissiles == rhs.unlimitedMissiles
  }

  @inline(never)
  private static func equalUnlimitedCargo(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.unlimitedCargo == rhs.unlimitedCargo
  }

  @inline(never)
  private static func equalUnlimitedCash(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.unlimitedCash == rhs.unlimitedCash
  }

  @inline(never)
  private static func equalUnlimitedFuel(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.unlimitedFuel == rhs.unlimitedFuel
  }

  @inline(never)
  private static func equalUnlimitedJumps(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.unlimitedJumps == rhs.unlimitedJumps
  }

  @inline(never)
  private static func equalAutoTrade(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.autoTrade == rhs.autoTrade
  }

  @inline(never)
  private static func equalSpeech(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.speech == rhs.speech
  }

  @inline(never)
  private static func equalExecutive(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.executive == rhs.executive
  }

  @inline(never)
  private static func equalDiscoveredSecretPorts(_ lhs: borrowing Self, _ rhs: borrowing Self)
    -> Bool
  {
    lhs.discoveredSecretPorts == rhs.discoveredSecretPorts
  }

  @inline(never)
  private static func equalBlackjackMission(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.blackjackMission == rhs.blackjackMission
  }

  @inline(never)
  private static func equalDisplayStyle(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.displayStyle == rhs.displayStyle
  }

  @inline(never)
  private static func equalNavalMission(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.navalMission == rhs.navalMission
  }

  @inline(never)
  private static func equalXyzzyEnabled(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.xyzzyEnabled == rhs.xyzzyEnabled
  }

  @inline(never)
  private static func equalAutomaticProfitScan(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool
  {
    lhs.automaticProfitScan == rhs.automaticProfitScan
  }

  @inline(never)
  private static func equalAutomaticECM(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.automaticECM == rhs.automaticECM
  }

  @inline(never)
  private static func equalAutomaticTargeting(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool
  {
    lhs.automaticTargeting == rhs.automaticTargeting
  }

  @inline(never)
  private static func equalReturnFireEnabled(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.returnFireEnabled == rhs.returnFireEnabled
  }

  @inline(never)
  private static func equalCapitalReward(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.capitalReward == rhs.capitalReward
  }

  @inline(never)
  private static func equalNavigationRoute(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.navigationRoute == rhs.navigationRoute
  }

  @inline(never)
  private static func equalStorageUnitCount(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.storageUnitCount == rhs.storageUnitCount
  }

  @inline(never)
  private static func equalMountedLasers(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.mountedLasers == rhs.mountedLasers
  }

  @inline(never)
  private static func equalFiniteXYZzyCash(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    lhs.finiteXYZzyCash == rhs.finiteXYZzyCash
  }

  public init() {
    ownedShipID = NewCommanderDefaults.shipID
  }
  public var availableCredits: Int { unlimitedCash ? Int.max : credits }
  public var capacity: Int {
    let standard = standardCargoCapacity
    return unlimitedCargo ? Int.max / 17 : standard
  }
  public var cargoTonnes: Int {
    checkedCargoTonnes ?? Int.max
  }
  public var rank: String {
    let thresholds = [8, 16, 32, 64, 128, 512, 2560, Self.eliteThreshold]
    return [
      "Harmless", "Mostly Harmless", "Poor", "Average", "Above Average", "Competent", "Dangerous",
      "Deadly", "ELITE",
    ][thresholds.filter { kills >= $0 }.count]
  }
  public var valid: Bool {
    guard ShipCatalogue.ship(shipID)?.game != nil else { return false }
    guard equipmentStateValid else { return false }
    return validAfterEquipment()
  }

  @inline(never)
  private func validAfterEquipment() -> Bool {
    guard NativeInductionCrewLogSave.validateClaims(self),
      NativeInductionArkSave.validateClaims(self),
      NativeWayfarerInductionSave.validateClaims(self),
      NativeFirstCommoditySaleSave.validateClaims(self),
      NativeGlassMeridianSave.validateClaims(self),
      NativeFleetDiscoverySave.validateClaims(self),
      NativeFlightReceptionSave.validateClaims(self),
      WayfarerFieldReliefSave.validateClaims(self)
    else { return false }
    guard NativeMeasuredExtractionSave.validateClaims(self) else { return false }
    guard WayfarerRecordRecoverySave.validateClaims(self) else { return false }
    guard NativeIdentifiedSalvageSave.validateClaims(self) else { return false }
    return nativeStationStateValid && nativeUtilityStateValid
      && empCustodyStateValid && electricalStateValid && alienStorageStateValid
      && nativeSalvageOriginalSourcesValid && freightCargoValid && navigationTradeStateValid
      && originalMarkets.valid
      && cargo.count == 17
      && cargo.allSatisfy { $0 >= 0 && $0 <= Int.max / 17 } && credits >= 0
      && credits <= 4_294_967_295
      && (0...256).contains(system) && (0..<8).contains(galaxy)
      && (0...255).contains(plughDiscoveryMask)
      && (system != Plugh.systemID || hasDiscoveredPlugh(in: galaxy))
      && (!(navigationPlan?.path.contains(Plugh.systemID) ?? false)
        || hasDiscoveredPlugh(in: galaxy))
      && (0...FuelStorage.maximumCount).contains(fuelStorageUnits)
      && (0...fuelCapacity).contains(fuel)
      && (0...missileCapacity).contains(missiles) && (0...65535).contains(kills) && legal >= 0
      && missionProgress.count <= 128 && missionProgress.values.allSatisfy(\.valid)
      && scriptState.valid && financeStateValid && nativeWormholeHistoryValid
      && nativePeopleStateValid && accommodationValid
      && contractsValid
      && (legacyOwnedEquipment != nil ? legacyIssueStateValid : issuedEquipmentValid)
      && (checkedCargoTonnes.map { $0 <= capacity } ?? false)
      && (navigationPlan?.valid ?? true) && blackjack.valid
      && (savedFlightSimulation?.valid ?? true)
      && (savedCargoDebrisLedger?.valid ?? true)
      && (savedMiningLedger?.valid ?? true)
      && (savedWantedCareers?.valid(in: flightSimulation) ?? true)
      && (savedNPCPersistence?.valid ?? true)
      && (!blackjack.carriesFirearm || cargo[10] >= 1)
      && equipment.isSubset(of: Equipment.validNames) && !name.isEmpty && name.count <= 16
  }
}

public struct Equipment: Sendable {
  /// Equipment definitions store zero-based requirements; original worlds expose one-based TL.
  public var requiredTechnologyLevel: Int { technology + 1 }
  public static let legacyDockingComputer = "Docking Computers"
  public static let navalEnergyUnit = "Naval Energy Unit"
  public static let eliteEnergyUnit = "Elite Energy Unit"
  public static let navalLaser = "Naval Laser"
  public static let empPirateBlaster = "EMP Pirate Blaster"
  public static var validNames: Set<String> {
    Set(all.map(\.name)).subtracting(
      [FuelStorage.equipmentName] + PassengerCabinGrade.allCases.map(\.equipmentName)
    )
    .union(Set(HyperspaceDriveTier.allCases.map(\.label)))
    .union([
      navalEnergyUnit, navalLaser, ShieldBooster.capital.equipmentName, legacyDockingComputer,
      "Targeting: Mining Module", "Targeting: Salvage Module", "Salvage Cutter",
      "Elite Shield Module",
    ])
  }
  public static var maximumHardware: Set<String> {
    validNames.subtracting(
      [
        legacyDockingComputer, "Extra Energy Unit", navalEnergyUnit, "Pulse Laser", "Beam Laser",
        HyperspaceDriveTier.basic.label, HyperspaceDriveTier.intermediate.label,
        "Military Laser", AlienMissileDefinition.name,
      ]
        + TargetingTier.allCases.map(\.equipmentName) + NavigationTier.allCases.map(\.equipmentName)
        + ShieldBooster.allCases.map(\.equipmentName)
    )
    .union([
      TargetingTier.military.equipmentName, NavigationTier.military.equipmentName,
      "Elite Shield Module",
    ])
  }
  public let name: String
  public let price: Int
  public let technology: Int
  public static let base: [Equipment] =
    [
      .init(name: "Fuel", price: 2, technology: 0),
      .init(name: "Missile", price: 300, technology: 0),
      .init(
        name: AlienMissileDefinition.name, price: AlienMissileDefinition.repeatPriceTenths,
        technology: 0),
      .init(name: "Large Cargo Bay", price: 4000, technology: 0),
      .init(name: "E.C.M. System", price: 6000, technology: 2),
      .init(name: "Pulse Laser", price: 4000, technology: 3),
      .init(name: "Beam Laser", price: 10000, technology: 4),
      .init(name: "Fuel Scoops", price: 5250, technology: 5),
      .init(name: "Escape Pod", price: 10000, technology: 6),
      .init(name: "Energy Bomb", price: 9000, technology: 7),
      .init(name: "Extra Energy Unit", price: 15000, technology: 8),
      .init(name: "Galactic Hyperdrive", price: 50000, technology: 10),
      .init(name: "Mining Laser", price: 8000, technology: 10),
      .init(name: "Military Laser", price: 60000, technology: 10),
    ]
  public static let all =
    base
    + TargetingTier.allCases.map {
      .init(name: $0.equipmentName, price: $0.price, technology: $0.technology)
    }
    + NavigationTier.allCases.map {
      .init(name: $0.equipmentName, price: $0.price, technology: $0.technology)
    } + [
      // Initial project balancing in tenths of a credit; these are new independent devices.
      .init(name: "Targeting: Mining Module", price: 20000, technology: 5),
      .init(name: "Targeting: Salvage Module", price: 40000, technology: 7),
      .init(name: empPirateBlaster, price: 30000, technology: 8),
      .init(name: "Salvage Cutter", price: 25000, technology: 6),
      .init(name: FuelStorage.equipmentName, price: FuelStorage.price, technology: 0),
      .init(name: navalLaser, price: 0, technology: 0),
      .init(name: navalEnergyUnit, price: 45000, technology: 11),
      .init(name: eliteEnergyUnit, price: 135000, technology: 13),
    ]
    + ShieldBooster.allCases.compactMap(\.shopItem) + [
      .init(name: ShieldBooster.capital.equipmentName, price: 0, technology: 0),
      .init(name: HyperspaceDriveTier.intermediate.label, price: 50000, technology: 9),
      .init(name: HyperspaceDriveTier.advanced.label, price: 150000, technology: 12),
    ]
    + PassengerCabinGrade.allCases.map {
      .init(name: $0.equipmentName, price: $0.price, technology: 0)
    }
}

public struct Controls: Sendable {
  public var pitch: Double = 0
  public var roll: Double = 0
  public var yaw: Double = 0
  public var throttle: Double = 0
  public var fire = false
  public var spinContacts = 0
  public var spinRecognition = 0.0
  public var spinSlower = false
  public var spinFaster = false
  public init() {}
}

public struct Game: Sendable {
  // Exactly one value lives in checked copy-on-write storage. Game copies retain independent
  // nested commander mutations without reserving the whole commander in every Game temporary.
  private var commanderStorage = [Commander()]
  public var commander: Commander {
    _read { yield commanderStorage[0] }
    _modify { yield &commanderStorage[0] }
  }
  var commanderGalaxy: Int {
    commanderStorage.withUnsafeBufferPointer { storage in
      storage.baseAddress!.pointee.galaxy
    }
  }
  // Adoption needs only these scalars; passing the whole pointee to a generic read callback
  // can require an owned Commander temporary before the callback projects either field.
  @inline(never)
  mutating func nativePhysicalAdoptionSystemIdentity() -> SystemIdentity {
    commanderStorage.withUnsafeBufferPointer { storage in
      let commander = storage.baseAddress!
      return .init(galaxy: commander.pointee.galaxy, system: commander.pointee.system)
    }
  }
  // Keep the original full policy and lazy read order without passing a whole Commander value
  // through the generic read callback. Only owned system/anchor values leave this buffer scope.
  @inline(never)
  mutating func nativeStationPopulationHeader() throws -> (
    system: SystemIdentity, anchors: SystemAnchors
  ) {
    try commanderStorage.withUnsafeBufferPointer { storage in
      let commander = storage.baseAddress!
      let system = SystemIdentity(
        galaxy: commander.pointee.galaxy, system: commander.pointee.system)
      guard
        Commander.nativeStationStateIsValid(at: commander),
        let anchors = Commander.nativeStationReadFlight(at: commander).anchors,
        anchors.system
          == SystemIdentity(
            galaxy: commander.pointee.galaxy, system: commander.pointee.system)
      else { throw NativeStationRuntimeError.invalidState }
      return (system, anchors)
    }
  }
  /// Synchronous read-only access; the storage borrow and pointer never escape this call.
  func withReadOnlyCommander<Result>(
    _ read: (borrowing Commander) throws -> Result
  ) rethrows -> Result {
    try commanderStorage.withUnsafeBufferPointer { storage in
      try read(storage.baseAddress!.pointee)
    }
  }
  /// Native station reads borrow current storage without an owned Game receiver temporary.
  /// The synchronous buffer borrow and pointer cannot escape this call.
  @inline(never)
  mutating func withNativeStationReadOnlyCommander<Result>(
    _ read: (borrowing Commander) throws -> Result
  ) rethrows -> Result {
    try commanderStorage.withUnsafeBufferPointer { storage in
      try read(storage.baseAddress!.pointee)
    }
  }

  func withReadOnlyScriptState<Result>(
    _ read: (borrowing ScriptEngineState) throws -> Result
  ) rethrows -> Result {
    try withReadOnlyCommander { try $0.withReadOnlyScriptState(read) }
  }

  var missionActorAdmissionSystemIdentity: SystemIdentity {
    withReadOnlyCommander { .init(galaxy: $0.galaxy, system: $0.system) }
  }

  /// Snapshot installed instances through the same synchronous Commander borrow as native policy.
  var retainedMissionActorInstances: [UUID: ScriptInstance] {
    withReadOnlyScriptState { $0.instances }
  }

  func retainedMissionActorAdmissionSourceValues() -> (
    instances: [UUID: ScriptInstance], geometry: [String: ShipDesign], galaxy: Int, system: Int
  ) {
    withReadOnlyCommander { commander in
      let state = commander.withReadOnlyScriptState { ($0.instances, $0.geometry) }
      return (state.0, state.1, commander.galaxy, commander.system)
    }
  }

  func retainedMissionActorAdmissionWorldJob(_ id: UUID) -> ScriptWorldJob? {
    withReadOnlyScriptState { $0.worldJobs[id] }
  }

  @inline(never)
  var contractStation: ContractStationIdentity {
    let galaxyField: KeyPath<Commander, Int> = \.galaxy
    let systemField: KeyPath<Commander, Int> = \.system
    guard let galaxyOffset = MemoryLayout<Commander>.offset(of: galaxyField),
      let systemOffset = MemoryLayout<Commander>.offset(of: systemField)
    else { preconditionFailure("Contract stations require addressable stored coordinates.") }
    let galaxyEnd = galaxyOffset.addingReportingOverflow(MemoryLayout<Int>.size)
    let systemEnd = systemOffset.addingReportingOverflow(MemoryLayout<Int>.size)
    precondition(
      galaxyOffset >= 0 && !galaxyEnd.overflow
        && galaxyEnd.partialValue <= MemoryLayout<Commander>.size)
    precondition(
      systemOffset >= 0 && !systemEnd.overflow
        && systemEnd.partialValue <= MemoryLayout<Commander>.size)
    return commanderStorage.withUnsafeBufferPointer { buffer in
      precondition(buffer.count == 1)
      let base = UnsafeRawPointer(buffer.baseAddress!)
      let galaxyAddress = base.advanced(by: galaxyOffset)
      let systemAddress = base.advanced(by: systemOffset)
      precondition(Int(bitPattern: galaxyAddress) % MemoryLayout<Int>.alignment == 0)
      precondition(Int(bitPattern: systemAddress) % MemoryLayout<Int>.alignment == 0)
      // Both addresses refer to initialized Int subobjects in this same live Commander.
      let galaxy = galaxyAddress.assumingMemoryBound(to: Int.self).pointee
      let system = systemAddress.assumingMemoryBound(to: Int.self).pointee
      return .init(galaxy: galaxy, system: system, stationClass: "main-orbital")
    }
  }

  @inline(never)
  var retainedNativeMainStationDockReceipt: NativeMainStationDockReceipt? {
    let field: KeyPath<Commander, NativeStationWorld?> = \.nativeStations
    guard let offset = MemoryLayout<Commander>.offset(of: field) else {
      preconditionFailure("Dock receipts require addressable stored station state.")
    }
    let end = offset.addingReportingOverflow(MemoryLayout<NativeStationWorld?>.size)
    precondition(
      offset >= 0 && !end.overflow && end.partialValue <= MemoryLayout<Commander>.size)
    return commanderStorage.withUnsafeBufferPointer { buffer in
      precondition(buffer.count == 1)
      let address = UnsafeRawPointer(buffer.baseAddress!).advanced(by: offset)
      precondition(Int(bitPattern: address) % MemoryLayout<NativeStationWorld?>.alignment == 0)
      // This initialized optional station subobject belongs to the same live Commander.
      return address.assumingMemoryBound(to: NativeStationWorld?.self).pointee?.currentMainDock
    }
  }

  var retainedMissionProjectiles: [UUID: ScriptProjectileRecord] {
    withReadOnlyScriptState { $0.projectiles }
  }

  func retainedMissionProjectileRestorationCandidates() throws -> [UUID] {
    try withReadOnlyCommander { commander in
      let galaxy = commander.galaxy
      let system = commander.system
      return try commander.withReadOnlyScriptState { state in
        try Self.retainedMissionProjectileRestorationCandidates(
          from: state, galaxy: galaxy, system: system)
      }
    }
  }

  private static func retainedMissionProjectileRestorationCandidates(
    from state: borrowing ScriptEngineState, galaxy: Int, system: Int
  ) throws -> [UUID] {
    var eligible: [UUID] = []
    for (id, record) in state.projectiles {
      guard record.galaxy == galaxy, record.system == system else { continue }
      guard id == record.body.scriptShot?.identity, record.valid,
        state.projectileArchiveValid(record)
      else { throw NativeMissionProjectileAdmissionError.invalidRecord }
      eligible.append(id)
    }
    return eligible
  }
  public var systems = Universe.systemsIncludingPlugh()
  public var screen: Screen = .title
  public var paused = false
  public var isMissionTrial = false
  public var contractBoard = ContractBoardUI()
  var scriptPledgeAdmission: ScriptPledgeAdmission?
  var scriptCourierAdmission: ScriptCourierAdmission?
  public var trialTitle: String?
  var trialDigest: String?
  var trialSeed: UInt64?
  public var docked = true
  public var dockedAtMainStation = true
  var scriptReferenceFrame: ScriptReferenceFrame?
  var scriptDispatching = false
  var scriptEventsDeferred = false
  var scriptDurabilityAvailable = false
  // Runtime-only destination ownership and acknowledgment; never encoded in Commander saves.
  var pendingNewSaveDestination: URL?
  var newCommanderSaveReceipt: CommanderFileReceipt?
  var nativeStationRuntimeEpoch = UUID() {
    didSet {
      nativeOrbitalOutlookRuntime = .init()
      nativeOriginalSurveyRuntime = nil
      nativeGlassMeridianRuntime = nil
      nativeFlightReceptionPending = nil
      nativeMeasuredExtractionPending = nil
      nativeRecordRecoveryPending = nil
      nativeCrewLogPickupPending = nil
      nativeC01SurveyorPending = nil
      nativeRecordRecoveryIdentificationPending = nil
      nativeIdentifiedSalvagePending = nil
    }
  }
  var nativeOrbitalOutlookRuntime = NativeOrbitalOutlookRuntime()
  var nativeOriginalSurveyRuntime: NativeOriginalSurveyRuntime?
  var nativeGlassMeridianRuntime: NativeGlassMeridianRuntime?
  var nativeFlightReceptionPending: NativeFlightReceptionPending?
  var nativeMeasuredExtractionPending: NativeMeasuredExtractionPending?
  var nativeRecordRecoveryPending: WayfarerRecordRecoveryPending?
  var nativeCrewLogPickupPending: NativeCrewLogPickupPending?
  var nativeC01SurveyorPending: NativeC01SurveyorPending?
  var nativeRecordRecoveryIdentificationPending: WayfarerRecordRecoveryIdentificationPending?
  var nativeIdentifiedSalvagePending: NativeIdentifiedSalvagePending?
  var nativeCrimboMotionSample: NativeCrimboMotionSample?
  var nativeCrimboAttainedMotion: NativeCrimboAttainedMotion?
  // Enabled only by G1 after supported native save/world/durability validation. Never saved.
  var nativeCrimboLifecycleAvailable = false
  var nativeSalvageMotion: [SalvageLotIdentity: NativeSalvageMotion] = [:]
  var nativeSalvageWreckMotion: [WreckIdentity: NativeSalvageWreckObservation] = [:]
  var nativeSalvageWork: NativeSalvageHotWork?
  var pendingNativeSalvageCollections: [NativeSalvageCollectionObservation] = []
  var pendingNativeStationDock: NativeStationEntryProof?
  var inductionArkDockPublicationPending = false
  var inductionRescueDockPublicationPending = false
  var inductionUtilityWorkRuntime = NativeInductionUtilityWorkRuntime()
  var nativeStationDockEvidence: NativeStationDockEvidence?
  var nativeMainStationDockEvidence: NativeMainStationDockEvidence?
  public var scriptPacks: [ScriptPack] = []
  public var scriptAvailablePackDigest: String?
  public var scriptOffer: UUID?
  public var scriptPresentedDialogue: ScriptDialogue?
  public var scriptConfirmSelected = true
  public var scriptChoiceSelection = 0
  public var missionPacks = MissionPackLibrary.bundled
  public var packOffer: PackOffer?
  public var packOfferElapsed = 0.0
  public var packDialogScroll = 0
  public var blackjackOffer: BlackjackOffer?
  public var showroom = ShowroomState()
  public var galacticBrowse = GalaxyBrowseState()
  public var systemInspection: SystemInspection?
  public var rumourReturn: Screen = .status
  var wantedSelection: ActorIdentity?
  var wantedPlayerSelected = false
  var wantedDetail = false
  var wantedRumourDetail = false
  var wantedScroll = 0
  var wantedReadContext: WantedReadContext?
  public var blackjackReturn: Screen = .status
  var screenHistory: [Screen] = []
  var flightReturn: Screen = .front
  public var selectedSystem = 7
  public var selection = 0
  public var informationScroll = 0
  public var chartInformationScroll = 0
  /// Mutable station stock is commander-owned and survives departure, save and reload.
  public var market: [MarketItem] {
    get { commander.originalMarkets.items(galaxy: commander.galaxy, system: currentSystem) }
    set { commander.originalMarkets.set(newValue, galaxy: commander.galaxy, system: currentSystem) }
  }
  public var bodies: [SpaceBody] = []
  public var miningFields: [MiningField] = []
  public var salvageSites: [SalvageSite] = []
  var gameplayRevision: UInt64 = 0
  /// Actual contact disqualifies this physical frame from attained-motion credit.
  var stationImpactRevision: UInt64?
  // A laser capability is consumed synchronously in the same actor turn that emitted it.
  // Bounded and ephemeral: capabilities are never restored from a commander save.
  var consumedMissionLaserEmission: UInt64 = 0
  var salvageAdmissionGeometry: [String: PreparedSalvageAdmissionHull] = [:]
  public var starfield = Starfield()
  public var speed = 0.0
  public var pitch = 0.0
  public var roll = 0.0
  public var yaw = 0.0
  public var spin = SpinControl()
  public var autoPilot = AutoTargetControl()
  var stationAutoDefence: StationAutoDefenceState?
  public var workTargetFilter: WorkTargetFilter = .ships
  var workGuidance: FlightWorkGuidance?
  var workBraking: FlightWorkBraking?
  var workRecoveryRock: RockIdentity?
  var workRecoveryAdmissionDeadline: Double?
  var approvedWorkMotion: HullSceneMotion?
  var lastAppliedWorkMotion: HullSceneMotion?
  var plannedLegacyWorkMotion: [Int: HullSweepObstacle] = [:]
  var workScenePlanned = false
  var workFireSuspended = false
  var flightTrigger = FlightTriggerState()
  var selectedToolActivity: FlightToolActivity?
  /// Immutable presentation for the delivered runtime snapshot, prepared off the paint path.
  public internal(set) var flightWeaponDisplay = FlightWeaponDisplay(
    weapon: "UNAVAILABLE", status: "SNAPSHOT REQUIRED")
  var manualResidualFlight = false
  public var viewportWidth = 768.0
  public var viewportHeight = 768.0
  public var targetPanelExpanded: Bool?
  public var targetPanelScroll = 0
  public var weaponsTargetID: Int?
  public var secretScroll = 0
  public var energy = 256.0
  public var frontShield = 255.0
  public var rearShield = 255.0
  public var laserHeat = 0.0
  public var laserFlash = 0.0
  public var dischargeAudio = DischargeAudioState()
  var gameplayCombatTrace: GameplayCombatTrace?
  public var altitude = 1.0
  public var celestials: [CelestialBody] = []
  public var solarScoopState: SolarScoopState = .inactive
  var solarFuelRemainder = 0.0
  public var cabinTemperature = 0.0
  public var equipmentMount: LaserMount = .front
  public var equipmentWorkTool = false
  public var selectedFlightTool: FlightWorkTool = .combatLaser
  public internal(set) var inventoryContextEpoch = InventoryContextEpoch()
  public var inventoryActionSelection = 0
  public var inventoryUpgradeChoice = 0
  public var dockingComputer = false
  public var missileArmed = false
  public var message = ""
  public var messageTime = 0.0
  public var jumpCountdown: Double? = nil
  public var time = 0.0
  var scriptStartupTime: Double?
  public var secretBuffer = ""
  public var secretReturn: Screen = .status
  public var helpReturn: Screen = .title
  public var helpPage = 0
  public var gallery = MissionGalleryState()
  public var library = ScriptLibraryState()
  public var mapColour: MapColourMode = .economy
  public var mapZoom: MapZoom = .jump
  public var mapSearch = PlanetSearchState()
  public var navigationOptions: [RouteAlternative] = []
  public var navigationSelection = 0
  public var navigationScroll = 0
  public var navigationReturn: Screen = .chart
  public var missionNotice: MissionNotice?
  public var missionPage = 0
  public var missionClue: String?
  public var missionElapsed = 0.0
  var fireCooldown = 0.0
  var missionLoopCounter: UInt8 = 0
  var missionSpawnDelay = 0
  // Legacy callers share ECMControl's physical-time clock; there is no second countdown.
  var ecmFrames: Int {
    get { ecmControl.legacyFrames }
    set { ecmControl.setLegacyFrames(newValue) }
  }
  var enemyECMSource: Int?
  var activeECMActivation: ECMActivationIdentity?
  public var ecmControl = ECMControl()
  public var retaliation = RetaliationControl()
  var missileCooldown = 0.0
  var nextBodyID = 10
  private var legacySimulationSpawnClock: Double?
  private var randomState: UInt64 = 0x45_4c49_5445
  public init(executive: Bool = true) {
    energy = commander.performance.energy
    frontShield = commander.shieldCapacity
    rearShield = commander.rearShieldCapacity
    if executive {
      commander.executive = true
      screen = .demo
    }
  }
  public var currentSystem: StarSystem { systems[commander.system] }
  public var targetSystem: StarSystem { systems[selectedSystem] }

  public mutating func notify(_ text: String, voiced: Bool = true) {
    if voiced { ecmControl.emit(.gameplay(text)) }
    message = text
    messageTime = 4
  }
  public mutating func load(_ value: Commander) -> Bool {
    var candidate = self
    candidate.stationAutoDefence = nil
    candidate.gameplayCombatTrace = nil
    guard candidate.loadCommander(value) else { return false }
    self = candidate
    return true
  }
  private mutating func loadCommander(_ value: Commander) -> Bool {
    guard value.valid, !value.usesAlienStorageSaveVersion,
      !value.usesEMPSaveVersion, !value.usesModularDriveSaveVersion,
      !value.usesEconomyMiningSaveVersion,
      !value.usesFreightNativeSaveVersion, !value.usesProviderContractSaveVersion,
      value.scriptState.savedFleetDiscovery == nil,
      value.scriptState.firstNativeCommoditySale == nil,
      !NativeInductionCrewLogSave.hasClaims(value),
      !NativeInductionArkSave.hasClaims(value),
      !NativeWayfarerInductionSave.hasClaims(value),
      value.scriptState.financeLedger == nil, value.scriptState.savedClueJournal == nil,
      !value.scriptState.instances.values.contains(where: { $0.savedNavigationTrade != nil })
    else {
      return false
    }
    // The loaded commander owns a different native allocation timeline. Invalidate old
    // capabilities and allow that timeline's first genuine emission to be consumed once.
    gameplayRevision &+= 1
    consumedMissionLaserEmission = 0
    legacySimulationSpawnClock = nil
    nativeSalvageMotion.removeAll(keepingCapacity: true)
    nativeSalvageWreckMotion.removeAll(keepingCapacity: true)
    nativeSalvageWork = nil
    pendingNativeSalvageCollections.removeAll(keepingCapacity: true)
    bodies = []
    scriptReferenceFrame = nil
    scriptStartupTime = nil
    commander = value
    invalidateNativeStationAuthority()
    if commander.npcPersistence.count > 0 {
      commander.npcPersistence.resetPhysicalBindings(
        system: .init(galaxy: value.galaxy, system: value.system))
    }
    commander.resetWantedCareerBindings(system: .init(galaxy: value.galaxy, system: value.system))
    clearCelestialFlight()
    blackjackOffer = nil
    packOffer = nil
    scriptOffer = nil
    scriptPresentedDialogue = nil
    scriptAvailablePackDigest = nil
    scriptChoiceSelection = 0
    migrateMissionProgress()
    gallery = MissionGalleryState()
    library = ScriptLibraryState()
    showroom = ShowroomState()
    galacticBrowse = GalaxyBrowseState()
    systemInspection = nil
    dockedAtMainStation = commander.nativeStations?.ledger.currentDock == nil
    enforceBlackjackWanted()
    commander.migrateXYZzyPolicy()
    commander.migrateLegacyXYZzyMounts()
    mapSearch = PlanetSearchState()
    do { try commander.prepareEquipment() } catch { return false }
    commander.mirrorFittedEquipment()
    energy = commander.performance.energy
    frontShield = commander.shieldCapacity
    rearShield = commander.rearShieldCapacity
    targetPanelExpanded = nil
    targetPanelScroll = 0
    systems = Universe.systemsIncludingPlugh(number: value.galaxy)
    do { try migrateMiningPresence(legacyMissing: true) } catch { return false }
    selectedSystem = value.system
    docked = true
    bodies = []
    missionNotice = nil
    missionPage = 0
    missionClue = nil
    missionElapsed = 0
    missionLoopCounter = 0
    missionSpawnDelay = 0
    ecmFrames = 0
    ecmControl = ECMControl()
    dischargeAudio = DischargeAudioState()
    retaliation.clear()
    weaponsTargetID = nil
    missileCooldown = 0
    paused = false
    spin.stop(immediate: true)
    cancelAutoTarget()
    autoPilot = AutoTargetControl()
    clearManualResidualFlight()
    screen = .status
    screenHistory.removeAll()
    speed = 0
    reconcileEliteReward()
    navigationDocked()
    inventoryContextEpoch = .init()
    inventoryActionSelection = 0
    inventoryUpgradeChoice = 0
    equipmentMount = .front
    equipmentWorkTool = false
    return true
  }
  public mutating func key(_ raw: String) {
    let key = raw.lowercased()
    if prepareFlightControlKey(key) { return }
    guard flushNativeSalvageWork() else {
      notify("SALVAGE STATE UNAVAILABLE")
      return
    }
    let priorScreen = screen
    let priorPause = paused
    defer { if screen != priorScreen || paused != priorPause { interruptFlightTool() } }
    if handleInductionUtilityWorkKey(key) { return }
    if interfaceKey(key) { return }
    keyAfterInterface(key)
  }
  private mutating func keyAfterInterface(_ key: String) {
    if !docked && screen.isFlight {
      if sharedFlightKey(key) { return }
      switch key {
      case "pageup", "pagedown":
        pageTargetDetails(key == "pageup" ? -1 : 1)
        return
      case "i":
        targetPanelExpanded = !(targetPanelExpanded ?? (viewportWidth >= 1100))
        return
      case "v":
        if autoTargetBody?.hull == .station || workGuidance != nil || workBraking != nil {
          cancelAutoTarget()
        }
        spin.toggleMode()
        return
      case "b":
        if autoTargetBody?.hull == .station || workGuidance != nil || workBraking != nil {
          cancelAutoTarget()
        }
        spin.stop()
        return
      case "]", "spin:cw":
        if autoTargetBody?.hull == .station || workGuidance != nil || workBraking != nil {
          cancelAutoTarget()
        }
        spin.begin(.clockwise)
        return
      case "[", "spin:ccw":
        if autoTargetBody?.hull == .station || workGuidance != nil || workBraking != nil {
          cancelAutoTarget()
        }
        spin.begin(.anticlockwise)
        return
      default: break
      }
    }
    if screen == .demo { return }
    if screen == .title || screen == .gameOver {
      if key == " " || key == "return" {
        if screen == .title, let restoredTime = scriptStartupTime {
          time = restoredTime
          scriptStartupTime = nil
        }
        if screen == .gameOver {
          do { try restartBornBerthedCommander() } catch {
            notify("NEW COMMANDER STATE UNAVAILABLE - RESTART REFUSED", voiced: false)
            return
          }
        }
        screen = .status
      }
      return
    }
    if key.count == 1, let number = Int(key), (0...9).contains(number) {
      functionKey(number)
      return
    }
    switch key {
    case "up":
      if screen == .equipment {
        moveEquipmentSelection(-1)
      } else if [.buy, .sell, .market].contains(screen) {
        selection = MarketDisplayOrder.moved(selection: selection, direction: -1)
      } else {
        selection = max(0, selection - 1)
      }
    case "down":
      if screen == .equipment {
        moveEquipmentSelection(1)
      } else if [.buy, .sell, .market].contains(screen) {
        selection = MarketDisplayOrder.moved(selection: selection, direction: 1)
      } else {
        selection = min(Commodity.all.count - 1, selection + 1)
      }
    case "left", "right":
      if screen == .equipment || screen == .inventory {
        cycleEquipmentFitting(key == "right" ? 1 : -1)
        if screen == .inventory {
          inventoryUpgradeChoice &+= key == "right" ? 1 : -1
        }
      } else if screen == .chart || screen == .shortChart {
        selectChartNeighbour(key == "left" ? -1 : 1)
      } else if screen == .buy || screen == .sell {
        trade(buy: key == "right")
      }
    case "tab":
      if screen == .inventory { inventoryActionSelection &+= 1 }
    case "return":
      if screen == .buy || screen == .sell { trade(buy: screen == .buy) }
      if screen == .equipment { purchase() }
    case "z": if screen == .shortChart { mapZoom = mapZoom.next }
    case "o":
      if screen == .chart {
        returnChartToCurrentLocation()
      } else if screen == .shortChart {
        manuallySelectSystem(commander.system)
      }
    case "d":
      if screen == .chart || screen == .shortChart {
        notify(
          mapIsCurrentGalaxy
            ? String(
              format: "DISTANCE %.1f LIGHT YEARS", currentSystem.distance(to: mapTargetSystem))
            : "DISTANCE UNAVAILABLE ACROSS GALAXIES")
      }
    case "b": if docked { offerBlackjackHandoff() }
    case "h": beginHyperspace()
    case "g": galacticJump()
    case "j": inSystemJump()
    case "t": missileArmed = !docked && (commander.missiles > 0 || commander.unlimitedMissiles)
    case "u":
      missileArmed = false
      retaliation.clear()
      weaponsTargetID = nil
    case "m": fireMissile()
    case "e": ecm()
    case "p": cancelAutoTarget()
    case "energy-bomb": energyBomb()
    case "escape-pod": escapePod()
    default: break
    }
  }
  mutating func secretKey(_ key: String) {
    if ["up", "down", "pageup", "pagedown"].contains(key) {
      secretScroll = secretWindow.moved(key == "up" || key == "pageup" ? -1 : 1)
      return
    }
    switch key {
    case "0":
      commander.shipDisplayStyle = commander.shipDisplayStyle.next
      notify(commander.shipDisplayStyle.label)
    case "1":
      if commander.targetingTier.map({ $0 >= .docking }) != true {
        do {
          try commander.grantEquipment(
            TargetingTier.docking.equipmentName, at: .targetingCore, provenance: .xyzzy)
        } catch {
          notify("DOCKING COMPUTER REFIT REFUSED")
          return
        }
      }
      notify("DOCKING TARGETING COMPUTER FITTED")
    case "2":
      fitMaximumHardware()
    case "c": restoreXYZzyCobra()
    case "3":
      commander.unlimitedMissiles.toggle()
      notify("MISSILE SUPPLY UPDATED")
    case "4":
      commander.unlimitedFuel.toggle()
      if commander.unlimitedFuel { commander.fuel = commander.fuelCapacity }
      notify("FUEL SUPPLY UPDATED")
    case "5":
      notify(
        String(format: "JUMP LIMIT %.1f LY - FUEL AND NAV COMPUTER", commander.maximumJumpDistance))
    case "6":
      commander.autoTrade.toggle()
      if commander.autoTrade { autoTrade() }
      notify("AUTO TRADE UPDATED")
    case "7":
      commander.speech.toggle()
      notify("SPEECH UPDATED")
    case "8":
      if commander.unlimitedCargo
        && commander.cargoTonnes > commander.standardCargoCapacity
      {
        notify("SELL EXCESS CARGO FIRST")
      } else {
        commander.unlimitedCargo.toggle()
        notify("CARGO CAPACITY UPDATED")
      }
    case "9":
      notify(String(format: "CASH %.1f CR", Double(commander.credits) / 10))
    case "b":
      commander.retaliationEnabled.toggle()
      if !commander.retaliationEnabled { retaliation.clear() }
      notify("MILITARY RETURN FIRE UPDATED")
    case "f":
      do {
        try commander.grantEquipment("Fuel Scoops", at: .utility(.fuelScoops), provenance: .xyzzy)
      } catch {
        notify("FUEL SCOOP REFIT REFUSED")
        return
      }
      notify("FUEL SCOOPS FITTED")
    case "e":
      commander.autoECM.toggle()
      notify("AUTOMATIC ECM UPDATED")
    case "l":
      commander.legal = 0
      commander.xyzzyWantedAmnesty = commander.blackjack.stage.wanted
      notify("LEGAL STATUS RESET TO CLEAN")
    case "a":
      commander.autoTarget.toggle()
      if !commander.autoTarget { cancelAutoTarget() }
      notify("AUTO TARGET UPDATED")
    case "escape", "return": screen = secretReturn
    default: break
    }
  }
  mutating func enableXYZzy() {
    var candidate = self
    candidate.commander.xyzzyActive = true
    candidate.commander.profitScanEnabled = true
    candidate.commander.shipDisplayStyle = .shadedPanels
    candidate.commander.retaliationEnabled = true
    candidate.commander.unlimitedMissiles = true
    candidate.commander.unlimitedFuel = true
    candidate.commander.unlimitedJumps = false
    candidate.commander.unlimitedCargo = true
    candidate.commander.startXYZzyCash()
    candidate.commander.autoTrade = true
    candidate.commander.speech = true
    candidate.commander.autoECM = true
    candidate.commander.autoTarget = true
    do { try candidate.refitXYZzyCobra() } catch {
      notify("MAXIMUM REFIT REFUSED")
      return
    }
    if candidate.docked { candidate.autoTrade() }
    self = candidate
  }
  mutating func restoreXYZzyCobra() {
    var candidate = self
    do { try candidate.refitXYZzyCobra() } catch {
      notify("MAXIMUM REFIT REFUSED")
      return
    }
    self = candidate
  }
  private mutating func refitXYZzyCobra() throws {
    try commander.prepareEquipment()
    if commander.shipID != "SH023" {
      // Hull exchange preserves every portable item and refuses incompatible fittings.
      // The explicit maximum-hardware grant fills only vacant compatible pylons.
      commander.fuel = 0
      commander.unlimitedCargo = true
      try commander.transferEquipment(to: "SH023", hullID: UUID())
    }
    try commander.grantMaximumHardware()
    refillMaximumHardware()
    if commander.cargoTonnes > commander.standardCargoCapacity { commander.unlimitedCargo = true }
    speed = min(speed, commander.performance.speed)
    showroom.selection = commander.shipID
    showroom.baseline = commander.shipID
    showroom.baselineUsesCurrent = true
    clearShowroomSearch()
    notify("COBRA MK III RESTORED - MAXIMUM HARDWARE")
  }
  mutating func fitMaximumHardware() {
    var candidate = self
    do { try candidate.commander.grantMaximumHardware() } catch {
      notify("MAXIMUM REFIT REFUSED")
      return
    }
    candidate.refillMaximumHardware()
    self = candidate
    notify("MAXIMUM HARDWARE FITTED")
  }
  private mutating func refillMaximumHardware() {
    commander.fuel = commander.fuelCapacity
    energy = commander.performance.energy
    frontShield = commander.shieldCapacity
    rearShield = commander.rearShieldCapacity
  }
  mutating func functionKey(_ number: Int) {
    if number == 6 && docked {
      openShowroom()
      return
    }
    if number == 0 && docked {
      launch()
      return
    }
    selectNumberedDestination(number)
  }
  private mutating func selectNumberedDestination(_ number: Int) {
    guard let destination = Self.numberedScreen(number, docked: docked) else { return }
    if destination == .system {
      systemInspection =
        screen == .chart ? .init(galaxy: viewedGalaxy, system: viewedSystemID) : nil
      let variation = commander.missionStage.rawValue & 1 == 1 ? randomByte() % 5 : 0
      missionClue =
        inspectedGalaxy == commander.galaxy
        ? MissionRules.clue(
          stage: commander.missionStage, galaxy: inspectedGalaxy,
          system: inspectedSystem.id, variation: variation) : nil
    }
    if docked && [.buy, .sell].contains(screen) && [.buy, .sell].contains(destination) {
      screen = destination
    } else {
      navigatePrimary(to: destination)
    }
  }
  public mutating func selectNeighbour(direction: Int) {
    let known = knownSystems
    let current = known.firstIndex { $0.id == selectedSystem } ?? 0
    manuallySelectSystem(known[(current + direction + known.count) % known.count].id)
  }
  public mutating func selectSystem(x: Double, y: Double) {
    let selected =
      knownSystems.min { left, right in
        let ld = pow(Double(left.x - x), 2) + pow(Double(left.y - y), 2)
        let rd = pow(Double(right.x - x), 2) + pow(Double(right.y - y), 2)
        return ld < rd
      }?.id ?? selectedSystem
    manuallySelectSystem(selected)
  }
  public mutating func trade(buy: Bool) {
    var candidate = self
    do {
      try candidate.performMarketTrade(buy: buy, before: self)
      self = candidate
    } catch {
      notify(String(error.localizedDescription.prefix(512)))
    }
  }
  private mutating func performMarketTrade(buy: Bool, before: borrowing Game) throws {
    guard stationAllowsMarketServices, market.indices.contains(selection) else {
      if docked { notify("MARKET UNAVAILABLE AT THIS STATION") }
      return
    }
    let index = selection
    let item = market[index]
    let practice = try navigationTradeMarketAdmission(buying: buy, index: index)
    if buy {
      guard item.quantity > 0, commander.availableCredits >= item.price,
        commander.cargo[index] < Int.max / 17,
        Commodity.all[index].unit != "t" || commander.cargoTonnes < commander.tradeCargoCapacity
          || (practice != nil && commander.cargoTonnes == commander.tradeCargoCapacity)
      else {
        notify("CANNOT BUY")
        return
      }
      if !commander.unlimitedCash { commander.credits -= item.price }
      commander.cargo[index] += 1
      market[index].quantity -= 1
    } else {
      if index == 3, commander.sellableCargo(3) == 0, commander.nativeCaptiveCount > 0 {
        _ = reviewNativeCaptiveSale()
        return
      }
      guard commander.sellableCargo(index) > 0 || practice != nil,
        market[index].quantity < Int.max / 17
      else {
        notify(
          index == 10 && commander.markedFirearms > 0 ? "MISSION FIREARM RESERVED" : "NO CARGO")
        return
      }
      commander.credits = min(4_294_967_295, commander.credits + item.bidPrice)
      commander.cargo[index] -= 1
      market[index].quantity += 1
    }
    if let practice {
      try recordNavigationTradeMarket(instance: practice, buying: buy, before: before, index: index)
    }
    if !buy {
      recordFirstNativeCommoditySale(
        index: index,
        before: .init(
          stock: item.quantity, cargo: before.commander.cargo[index],
          credits: before.commander.credits),
        unitPrice: item.bidPrice)
    }
  }
  public mutating func purchase() {
    guard docked, Equipment.all.indices.contains(selection) else { return }
    _ = purchaseImmediately()
  }
  /// Sells the hold, then buys the most profitable exports for a destination.
  /// Government changes route risk, while commodity prices follow Elite's economy rules.
  public mutating func autoTrade() {
    guard !commander.hasActiveNavigationTrade else {
      notify("TRADE PRACTICE - USE SINGLE-TONNE MARKET CONTROLS")
      return
    }
    guard stationAllowsMarketServices else {
      if docked { notify("AUTO TRADE UNAVAILABLE AT THIS STATION") }
      return
    }
    let oldSelection = selection
    for index in commander.cargo.indices where commander.sellableCargo(index) > 0 {
      let beforeSale = NativeSaleBalance(
        stock: market[index].quantity, cargo: commander.cargo[index], credits: commander.credits)
      let saleQuantity = min(commander.sellableCargo(index), Int.max / 17 - market[index].quantity)
      let (revenue, overflow) = saleQuantity.multipliedReportingOverflow(
        by: market[index].bidPrice)
      commander.credits =
        overflow
        ? 4_294_967_295 : min(4_294_967_295, commander.credits + min(revenue, 4_294_967_295))
      market[index].quantity += saleQuantity
      commander.cargo[index] -= saleQuantity
      recordFirstNativeCommoditySale(
        index: index, before: beforeSale, unitPrice: market[index].bidPrice)
    }
    let refuelCost = refillCost
    if commander.unlimitedFuel {
      commander.fuel = commander.fuelCapacity
    } else if commander.availableCredits >= refuelCost {
      if !commander.unlimitedCash { commander.credits -= refuelCost }
      commander.fuel = commander.fuelCapacity
    } else {
      notify("INSUFFICIENT FUNDS FOR FULL FUEL")
      return
    }
    let routeDestination = commander.navigationPlan?.nextSystem
    if routeDestination == nil && selectedSystem == commander.system {
      let candidates = knownSystems.filter {
        $0.id != commander.system
          && currentSystem.distance(to: $0) <= commander.maximumJumpDistance
      }
      selectedSystem = candidates.max { routeScore($0) < routeScore($1) }?.id ?? commander.system
    }
    guard (routeDestination ?? selectedSystem) != commander.system else {
      notify("NO TRADE ROUTE")
      return
    }
    let destination = routeDestination.map { systems[$0] } ?? targetSystem
    let exports = profitableExports(to: destination)
    for item in exports {
      selection = item.index
      let unit = Commodity.all[item.index].unit
      let room = unit == "t" ? commander.tradeCargoCapacity - commander.cargoTonnes : 63
      let affordable =
        market[item.index].price > 0 ? commander.availableCredits / market[item.index].price : 63
      let count = max(0, min(room, min(affordable, market[item.index].quantity)))
      if !commander.unlimitedCash { commander.credits -= count * market[item.index].price }
      commander.cargo[item.index] += count
      market[item.index].quantity -= count
    }
    selection = oldSelection
    notify("AUTO TRADE TO " + destination.name)
  }
  public func profitableExports(to destination: StarSystem) -> [(index: Int, profit: Int)] {
    Commodity.all.indices.compactMap { index in
      let lowestSale = MarketItem.minimumPrices(at: destination)[index]
      let profit = lowestSale - market[index].price
      return profit > 0 && market[index].quantity > 0 ? (index, profit) : nil
    }.sorted { $0.profit == $1.profit ? $0.index < $1.index : $0.profit > $1.profit }
  }
  private func routeScore(_ destination: StarSystem) -> Double {
    let exports = profitableExports(to: destination)
    let gross = exports.reduce(0.0) {
      $0 + Double($1.profit) * Double(min(commander.tradeCargoCapacity, market[$1.index].quantity))
    }
    let risk = destination.hostileFraction
    return gross / (1 + risk + currentSystem.distance(to: destination) * 0.05)
  }
  public mutating func launch() {
    guard
      commander.nativeStations?.ledger.currentDock == nil
        || nativeStationDockEvidenceIsCurrent
    else {
      notify("RRS DOCKING CUSTODY UNAVAILABLE - LAUNCH REFUSED")
      return
    }
    var candidate = self
    do {
      try candidate.activateNativeStationWorld()
      try candidate.persistNativeStationConditions()
    } catch {
      notify("RRS STATION STATE UNAVAILABLE - LAUNCH REFUSED")
      return
    }
    if candidate.requiresScriptDurability, !candidate.recordCalendarLaunch(wasDocked: docked) {
      notify("CALENDAR LIMIT - LAUNCH NOT COMMITTED")
      return
    }
    do {
      try candidate.preflightActiveMissionProjectiles()
      candidate.persistScriptActors(unloading: true)
      try candidate.performNativeLaunch()
    } catch is NativeStationRuntimeError {
      notify("RRS EXIT UNAVAILABLE - LAUNCH REFUSED")
      return
    } catch {
      paused = true
      notify("MISSION FLIGHT RESTORE REFUSED - PAUSED", voiced: false)
      return
    }
    guard candidate.commander.valid else {
      notify("LAUNCH REFUSED")
      return
    }
    self = candidate
  }
  private mutating func performNativeLaunch() throws {
    let stationReceipt = commander.nativeStations?.ledger.currentDock
    persistBlackjackTargets()
    retaliation.clear()
    weaponsTargetID = nil
    missileCooldown = 0
    spin.stop(immediate: true)
    cancelAutoTarget()
    clearManualResidualFlight()
    docked = false
    screen = .front
    screenHistory.removeAll()
    flightReturn = .front
    speed = 8
    dockingComputer = false
    bodies = [
      SpaceBody(id: 0, hull: .station, position: .init(0, 0, -500)),
      SpaceBody(id: 2, hull: .asteroid, position: .init(-280, 100, 2200)),
    ]
    var freshLaunchTrafficID: Int?
    if commander.npcPersistence.count == 0,
      commander.savedEMPState?.records.values.contains(where: {
        $0.source.system == systemIdentity && $0.originalSpawn == nil && $0.originalBodyID == 1
      }) != true
    {
      bodies.insert(.init(id: 1, hull: .cobra, position: .init(90, 20, 1400)), at: 1)
      freshLaunchTrafficID = 1
    }
    commander.legal |= commander.cargo[3] + 2 * commander.cargo[6] + commander.cargo[10]
    resetCelestialFlight()
    guard beginGameplayVisit(arriving: false, freshLaunchTrafficID: freshLaunchTrafficID) else {
      throw SaveError.invalidCommander
    }
    notifyNativeLaunch()
    preloadNavigation()
    restoreBlackjackEncounter()
    applyScriptStationResources()
    try registerOriginalNativeMainStation()
    if stationReceipt == nil { try offsetMovingMainStationDeparture() }
    try restoreScriptActors()
    if let stationReceipt { try launchFromNativeStation(stationReceipt) }
    commander.nativeStations?.currentMainDock = nil
  }

  /// Retire the system-name snapshot before entering retained-actor restoration.
  @inline(never)
  private mutating func notifyNativeLaunch() {
    notify("LAUNCHING FROM " + currentSystem.name)
  }

  public mutating func dock(atMainStation: Bool = true) {
    stationAutoDefence = nil
    do { try persistNativeStationConditions() } catch {
      notify("DOCKING DEFERRED: RRS STATE UNAVAILABLE")
      return
    }
    resolveDestroyed()
    if atMainStation,
      commander.scriptState.stationResources[contractStation.key]?.destroyed == true
    {
      notify("MAIN STATION DESTROYED - DOCKING UNAVAILABLE")
      return
    }
    guard !hasUnsettledWreckDeaths else {
      notify("DOCKING DEFERRED: WRECK SETTLEMENT PENDING")
      return
    }
    guard !hasUnsettledCargoDeaths else {
      notify("DOCKING DEFERRED: CARGO SETTLEMENT PENDING")
      return
    }
    do { try prepareMeasuredDock() } catch {
      notify("DOCKING DEFERRED: EXTRACTION CUSTODY UNAVAILABLE")
      return
    }
    guard prepareDockPersistence() else { return }
    persistScriptActors(unloading: true)
    persistBlackjackTargets()
    if commander.npcPersistence.count > 0 {
      commander.npcPersistence.resetPhysicalBindings(system: systemIdentity)
    }
    commander.resetWantedCareerBindings(system: systemIdentity)
    commander.nativeStations?.currentMainDock = nil
    commander.nativeStations?.ledger.depart()
    dockedAtMainStation = atMainStation
    retaliation.clear()
    weaponsTargetID = nil
    missileCooldown = 0
    spin.stop(immediate: true)
    cancelAutoTarget()
    clearManualResidualFlight()
    docked = true
    commander.savedEMPCharge = nil
    commander.savedPlayerElectrical = nil
    screen = .status
    screenHistory.removeAll()
    speed = 0
    dockingComputer = false
    bodies = []
    energy = commander.performance.energy
    frontShield = commander.shieldCapacity
    rearShield = commander.rearShieldCapacity
    laserHeat = 0
    jumpCountdown = nil
    if requiresScriptDurability { cancelCalendarJourney() }
    missileArmed = false
    clearCelestialFlight()
    notify("DOCKED")
    navigationDocked()
    if commander.autoTrade { autoTrade() }
    progressNavalMissions()
    reconcileEliteReward()
    if screen != .mission { _ = dispatchMission(.dock) }
    offerBlackjackHandoff()
  }
  /// Scene snapshots commit together; settled physical deaths precede this boundary.
  @inline(never)
  private mutating func prepareDockPersistence() -> Bool {
    let snapshot = DockPersistenceSnapshot(self)
    var committed = false
    defer {
      if !committed { snapshot.restore(to: &self) }
    }
    guard persistNPCStates().isEmpty else {
      notify("DOCKING DEFERRED: NPC STATE UNAVAILABLE")
      return false
    }
    persistCargoPoses()
    persistOrePoses()
    guard persistSalvagePoses() else {
      notify("DOCKING DEFERRED: SALVAGE STATE UNAVAILABLE")
      return false
    }
    guard flushNativeSalvageMotion(parkingSystem: systemIdentity) else {
      notify("SALVAGE STATE UNAVAILABLE")
      return false
    }
    committed = true
    return true
  }
  public mutating func beginHyperspace() {
    if screen == .chart && !mapIsCurrentGalaxy {
      _ = prepareChartTravel()
      return
    }
    guard !docked, !playerEMPDisabled, jumpCountdown == nil else { return }
    guard prepareChartTravel(), selectedSystem != commander.system,
      knownSystems.contains(where: { $0.id == selectedSystem })
    else {
      return
    }
    let distance = currentSystem.distance(to: targetSystem)
    guard
      distance <= commander.maximumJumpDistance
    else {
      notify("FUEL TOO LOW")
      return
    }
    guard let drive = commander.hyperspaceDrivePolicy,
      commander.fittedComponent(at: .drive) != nil
    else {
      notify("FIT A HYPERSPACE DRIVE")
      return
    }
    guard !hyperspaceMassLocked else {
      notify("MASS LOCKED")
      return
    }
    var candidate = self
    if requiresScriptDurability {
      let debit = commander.jumpFuelCost(distance: distance)
      guard candidate.admitCalendarJourney(destination: targetSystem, nativeFuelDebit: debit),
        candidate.commander.valid
      else {
        notify("CALENDAR LIMIT - JUMP NOT ADMITTED")
        return
      }
    }
    switch drive.activation {
    case .timed(let seconds): candidate.jumpCountdown = seconds
    case .immediate:
      // The fitted recovered alien device uses the same fuel and arrival transaction.
      candidate.arrive()
      guard candidate.commander.system == selectedSystem, candidate.commander.valid else { return }
    }
    candidate.notify("HYPERSPACE")
    self = candidate
  }
  public var massLocked: Bool {
    bodies.contains { $0.hull != .cargo && $0.position.length < 600 }
      || celestials.contains { $0.position.length < $0.radius * 4 }
  }
  public mutating func arrive() {
    var candidate = self
    do {
      try candidate.preflightActiveMissionProjectiles()
      guard try candidate.performNativeArrival() else {
        jumpCountdown = candidate.jumpCountdown
        notify(candidate.message)
        return
      }
      guard candidate.commander.valid else { throw SaveError.invalidCommander }
    } catch {
      paused = true
      notify("MISSION FLIGHT RESTORE REFUSED - PAUSED", voiced: false)
      return
    }
    self = candidate
  }
  mutating func arriveThroughNativeWormhole(_ passage: NativeCommanderWormholePassage) throws
    -> Bool
  {
    guard passage.matches(self) else { throw NativeWormholeRefusal.stale }
    try preflightActiveMissionProjectiles()
    return try performNativeArrival(wormhole: passage)
  }
  private mutating func performNativeArrival(wormhole: NativeCommanderWormholePassage? = nil) throws
    -> Bool
  {
    try activateNativeStationWorld()
    try persistNativeStationConditions()
    resolveDestroyed()
    guard !hasUnsettledWreckDeaths else {
      jumpCountdown = nil
      notify("JUMP DEFERRED: WRECK SETTLEMENT PENDING")
      return false
    }
    guard persistSalvagePoses() else {
      jumpCountdown = nil
      notify("JUMP DEFERRED: SALVAGE STATE UNAVAILABLE")
      return false
    }
    persistOrePoses()
    let journey: ScriptCalendarJourney?
    if let wormhole {
      guard let admitted = completeWormholeCalendarJourney(wormhole) else { return false }
      journey = admitted
    } else {
      journey = requiresScriptDurability ? completeCalendarJourney() : nil
    }
    let destination = journey?.destination ?? selectedSystem
    guard flushNativeSalvageMotion(parkingSystem: systemIdentity) else { return false }
    persistScriptActors(unloading: true)
    if destination != commander.system { try departOrdinarySimulation() }
    persistBlackjackTargets()
    retaliation.clear()
    weaponsTargetID = nil
    missileCooldown = 0
    spin.stop(immediate: true)
    let arrivalSpeed = min(commander.performance.speed, flightWorldVelocity.length / 18)
    cancelAutoTarget()
    clearManualResidualFlight()
    speed = arrivalSpeed
    let fuelBeforeArrival = commander.fuel
    let cost =
      journey?.nativeFuelDebit
      ?? commander.jumpFuelCost(distance: currentSystem.distance(to: targetSystem))
    if !commander.unlimitedFuel {
      commander.fuel = max(0, commander.fuel - cost)
    }
    commander.system = destination
    if wormhole != nil { selectedSystem = destination }
    if let plan = commander.navigationPlan, plan.nextSystem != commander.system {
      commander.navigationPlan = nil
      notify("ROUTE CANCELLED - OFF ROUTE")
    }
    jumpCountdown = nil
    screen = .front
    screenHistory.removeAll()
    flightReturn = .front
    dockingComputer = false
    bodies = [
      SpaceBody(id: 0, hull: .station, position: .init(0, 0, 16000)),
      SpaceBody(
        id: 1, hull: .sidewinder, position: .init(80, 0, 2600),
        hostile: currentSystem.government < 4),
    ]
    resetCelestialFlight()
    guard beginGameplayVisit(arriving: true, freshLaunchTrafficID: 1) else {
      throw SaveError.invalidCommander
    }
    if let wormhole, let journey, let player = commander.flightSimulation.player {
      // The adapter must have registered this actual native exit, never a guessed GPS pose.
      guard commander.flightSimulation.pose == wormhole.opening.route.exit else {
        throw NativeWormholeRefusal.worldUnavailable
      }
      let fuelAfter = commander.fuel
      commander.scriptState.wormholeTransit?.commanderPassages[wormhole.opening.id] = .init(
        opening: wormhole.opening.id, source: wormhole.player, arrival: player,
        calendarOperation: journey.operation, seconds: journey.seconds,
        fuelBefore: wormhole.fuelBefore, fuelAfter: fuelAfter, fuelDebit: wormhole.fuelDebit)
    }
    altitude = 1
    notify(currentSystem.name)
    restoreBlackjackEncounter()
    applyScriptStationResources()
    try registerOriginalNativeMainStation()
    try restoreScriptActors()
    try recordNavigationTradeJourney(journey, fuelBefore: fuelBeforeArrival)
    return true
  }
  public mutating func galacticJump() {
    guard !docked, !playerEMPDisabled, commander.equipment.contains("Galactic Hyperdrive") else {
      return
    }
    var candidate = self
    do {
      guard try candidate.performGalacticJump(), candidate.commander.valid else {
        notify(candidate.message)
        return
      }
      self = candidate
    } catch { notify("GALACTIC JUMP REFUSED") }
  }
  private mutating func performGalacticJump() throws -> Bool {
    resolveDestroyed()
    guard !hasUnsettledWreckDeaths else {
      notify("JUMP DEFERRED: WRECK SETTLEMENT PENDING")
      return false
    }
    guard persistSalvagePoses() else {
      notify("JUMP DEFERRED: SALVAGE STATE UNAVAILABLE")
      return false
    }
    guard try consumeNativeEquipment("Galactic Hyperdrive") else { return false }
    guard flushNativeSalvageMotion(parkingSystem: systemIdentity) else { return false }
    persistScriptActors(unloading: true)
    mapSearch = PlanetSearchState()
    commander.navigationPlan = nil
    persistBlackjackTargets()
    try departOrdinarySimulation()
    bodies = []
    commander.galaxy = (commander.galaxy + 1) & 7
    if commander.system == Plugh.systemID { commander.system = Plugh.rumourStation }
    galacticBrowse = GalaxyBrowseState()
    systemInspection = nil
    systems = Universe.systemsIncludingPlugh(number: commander.galaxy)
    selectedSystem = commander.system
    try preflightActiveMissionProjectiles()
    guard try performNativeArrival() else { return false }
    commander.fuel = commander.fuelCapacity
    return true
  }
  public mutating func inSystemJump() {
    guard !docked, !playerEMPDisabled, !massLocked else {
      notify("MASS LOCKED")
      return
    }
    let before = commander.flightSimulation.pose
    for index in bodies.indices { bodies[index].position.z -= 3000 }
    for index in celestials.indices { celestials[index].position.z -= 3000 }
    commander.flightSimulation.pose.advanceView(
      pitch: 0, roll: 0, yaw: 0, translation: .init(0, 0, 3000))
    advanceNativeMissionFrame(from: before, to: commander.flightSimulation.pose, delta: 0)
  }
  @discardableResult public mutating func fireMissile(retaliating: Bool = false) -> Bool {
    guard !docked, !playerEMPDisabled, missileArmed, missileCooldown == 0,
      commander.missiles > 0 || commander.unlimitedMissiles,
      let target = bodies.firstIndex(where: { body in
        (body.hull != .station || nativeStationBodyIsCurrent(body))
          && body.energy > 0 && body.position.z > 0
          && (weaponsTargetID == nil || body.id == weaponsTargetID)
      })
    else { return false }
    guard launchGameplayMissile(targetBodyID: bodies[target].id) else { return false }
    missileCooldown = 1
    notify("MISSILE AWAY", voiced: !retaliating)
    missileArmed = false
    return true
  }
  public mutating func ecm() {
    guard !docked, !playerEMPDisabled, commander.equipment.contains("E.C.M. System"),
      energy > ECMControl.activationEnergyCost,
      ecmFrames == 0
    else {
      return
    }
    ensurePhysicalActors()
    guard let player = commander.flightSimulation.player, activateOrdnanceECM(emitter: player)
    else { return }
    _ = ecmControl.detect(bodies)
    detectRetaliationSources()
    ecmControl.activate(destroyed: 0)
    for missile in bodies
    where missile.hull == .missile && missile.energy > 0 && missile.physical?.ordnance == nil
      && missile.scriptShot == nil
    {
      ecmControl.recordDestruction()
      confirmRetaliation(missile)
    }
    bodies.removeAll {
      $0.hull == .missile && $0.physical?.ordnance == nil && $0.scriptShot == nil
    }
    ecmFrames = 32
    enemyECMSource = nil
    energy -= ECMControl.activationEnergyCost
    advanceGameplayOrdnance(allowEnemyECM: false)
    notify("E.C.M.", voiced: false)
  }
  public mutating func energyBomb() {
    guard !docked else { return }
    var candidate = self
    do {
      guard try candidate.consumeNativeEquipment("Energy Bomb"),
        candidate.applyAttributedEnergyBomb(), candidate.commander.valid
      else { return }
      candidate.notify("ENERGY BOMB")
      self = candidate
    } catch { notify("ENERGY BOMB REFUSED") }
  }
  public mutating func escapePod() {
    guard !docked, commander.equipment.contains("Escape Pod") else { return }
    guard !commander.accommodation.fittedBerths.contains(where: { $0.use.used }) else {
      notify("PASSENGERS CANNOT FIT THIS ESCAPE POD")
      return
    }
    var candidate = self
    let measuredPod = candidate.measuredEscapePod()
    let recorderPod = candidate.recordRecoveryEscapePod()
    let originalPod = candidate.identifiedSalvageEscapePod()
    let surveyorPod = candidate.commander.fittedEquipment(at: .utility(.escapePod)).flatMap {
      fitted in
      try? candidate.commander.purchaseSnapshot().items.first(where: { $0.id == fitted.id })
    }
    do {
      guard try candidate.consumeNativeEquipment("Escape Pod") else { return }
    } catch {
      notify("ESCAPE POD REFUSED")
      return
    }
    guard candidate.loseCourierPackagesOnEscape() else {
      notify("COURIER LOSS COULD NOT BE RECORDED - ESCAPE NOT COMMITTED")
      return
    }
    guard candidate.loseFreightOnEscape() else {
      notify("FREIGHT LOSS COULD NOT BE RECORDED - ESCAPE NOT COMMITTED")
      return
    }
    do {
      try candidate.closeUncollectedInductionClinicOnExit(.escapePod)
      try candidate.loseHeldInductionClinicOnExit(.escapePod)
      try candidate.loseInductionWorkshopOnExit(.escapePod)
      try candidate.closeUncollectedInductionSeedOnExit(.escapePod)
      try candidate.loseHeldInductionSeedOnExit(.escapePod)
      try candidate.loseC01SurveyorOnEscape(surveyorPod)
    } catch {
      notify("CLINIC RESERVATION LOSS NOT SAVED - ESCAPE NOT COMMITTED")
      return
    }
    guard candidate.loseWayfarerColdChainOnEscape() else {
      notify("SAMPLE LOSS COULD NOT BE RECORDED - ESCAPE NOT COMMITTED")
      return
    }
    do { _ = try candidate.loseWayfarerInductionCrate(.escapePod) } catch {
      notify("INDUCTION CRATE LOSS NOT SAVED - ESCAPE NOT COMMITTED")
      return
    }
    do { try candidate.loseNativeUtilityOnEscape() } catch {
      notify("UTILITY MATERIAL LOSS NOT SAVED - ESCAPE NOT COMMITTED")
      return
    }
    guard candidate.loseWayfarerRepairLoopOnEscape() else {
      notify("REPAIR UNIT LOSS COULD NOT BE RECORDED - ESCAPE NOT COMMITTED")
      return
    }
    do { try candidate.loseMeasuredOnEscape(pod: measuredPod) } catch {
      notify("EXTRACTION LOSS NOT SAVED - ESCAPE NOT COMMITTED")
      return
    }
    do { try candidate.loseRecordRecoveryOnEscape(pod: recorderPod) } catch {
      notify("SENN RECORDER LOSS NOT SAVED - ESCAPE NOT COMMITTED")
      return
    }
    do { try candidate.loseIdentifiedSalvageOnEscape(pod: originalPod) } catch {
      notify("PELL PROPERTY LOSS NOT SAVED - ESCAPE NOT COMMITTED")
      return
    }
    let leftPeople = !(candidate.commander.nativePeople?.held.isEmpty ?? true)
    do {
      try candidate.abandonNativePeopleOnEscape()
    } catch {
      notify("PEOPLE ABANDONMENT COULD NOT BE RECORDED - ESCAPE NOT COMMITTED")
      return
    }
    // The existing successful escape transaction replaces the abandoned craft;
    // a pending charge and its disabled electrical reserve cannot follow it.
    candidate.commander.savedEMPCharge = nil
    candidate.commander.savedPlayerElectrical = nil
    candidate.loseNavigationTradeOnEscape()
    candidate.commander.cargo = Array(repeating: 0, count: 17)
    candidate.commander.cargo[10] = candidate.commander.markedFirearms
    candidate.commander.legal = 0
    candidate.commander.fuel = candidate.commander.fuelCapacity
    do {
      if candidate.activeFlightReception != nil { try candidate.finishFlightReception(.failed) }
    } catch {
      notify("PRACTICE LOSS NOT RECORDED - ESCAPE NOT COMMITTED")
      return
    }
    candidate.dock()
    guard candidate.docked, candidate.commander.valid else {
      notify(candidate.message)
      return
    }
    self = candidate
    if leftPeople { notify("ESCAPED - PEOPLE LEFT WITH ABANDONED SHIP") }
  }
  mutating func randomByte() -> Int {
    randomState = randomState &* 6_364_136_223_846_793_005 &+ 1
    return Int((randomState >> 32) & 255)
  }
  public mutating func tick(delta: Double, controls: Controls = Controls()) {
    tick(delta: delta, controls: controls, nativeSalvagePublish: nil)
  }

  mutating func tick(delta: Double, controls: Controls, nativeSalvagePublish: ScriptPublisher?) {
    guard admitFlightWorkAdvance(controls: controls) else { return }
    pendingNativeSalvageCollections.removeAll(keepingCapacity: true)
    guard delta.isFinite, delta > 0 else { return }
    let dt = min(delta, 0.1)
    if screen == .showroom {
      showroom.advance(delta: dt)
      return
    }
    if screen == .handoff {
      if !paused { packOfferElapsed += dt }
      return
    }
    if paused || screen == .help || screen == .gallery || screen == .library
      || screen == .navigation
      || screen == .handoff || screen == .rumour
    {
      return
    }
    time += dt
    if screen == .mission {
      missionElapsed += dt
      return
    }
    if screen == .demo && time >= 12 {
      screen = .title
      time = 0
    }
    if commander.unlimitedFuel { commander.fuel = commander.fuelCapacity }
    messageTime = max(0, messageTime - dt)
    laserFlash = max(0, laserFlash - dt)
    guard !docked, ![Screen.gameOver, .secret, .help, .title, .demo].contains(screen) else {
      return
    }
    approvedWorkMotion = nil
    lastAppliedWorkMotion = nil
    plannedLegacyWorkMotion.removeAll(keepingCapacity: true)
    workScenePlanned = false
    let fireRequested = controls.fire
    let wasElectricalDisabled = playerEMPDisabled
    commander.flightSimulation.advancePhysicalTime(dt)
    advancePlayerElectrical()
    if wasElectricalDisabled != playerEMPDisabled { interruptFlightTool() }
    let fireAdmitted = admitFlightFire(held: fireRequested)
    let controls = playerEMPDisabled ? Controls() : controls
    gameplayRevision &+= 1
    ensurePhysicalActors()
    let craft = commander.performance
    if !manualResidualFlight && workGuidance == nil && workBraking == nil {
      speed = min(craft.speed, max(0, speed + controls.throttle * dt * craft.acceleration))
    }
    pitch = controls.pitch * craft.pitch
    yaw = controls.yaw * craft.yaw
    let previousSpinRate = spin.actualRate
    if !playerEMPDisabled { spin.advance(delta: dt, controls: controls) }
    roll =
      spin.mode || spin.actualRate != 0 || previousSpinRate != 0
      ? (previousSpinRate + spin.actualRate) * .pi / 360 : controls.roll * craft.roll
    if !playerEMPDisabled { applyAutoTarget(delta: dt, controls: controls) }
    applyManualResidualThrottle(delta: dt, throttle: controls.throttle)
    laserHeat = max(0, laserHeat - dt * 12)
    fireCooldown = max(0, fireCooldown - dt)
    missileCooldown = max(0, missileCooldown - dt)
    energy = min(craft.energy, energy + dt * craft.recharge * commander.energyRechargeMultiplier)
    frontShield = min(commander.shieldCapacity, frontShield + dt * commander.frontShieldRecharge)
    rearShield = min(commander.rearShieldCapacity, rearShield + dt * commander.rearShieldRecharge)
    if fireAdmitted && screen.isFlight {
      fireSelectedFlightTool(delta: dt, nativeSalvagePublish: nativeSalvagePublish)
    } else {
      fireStationAutoLaser()
    }
    if let remaining = jumpCountdown {
      jumpCountdown = remaining - dt
      if remaining <= dt { arrive() }
    }
    advanceGameplayEncounters(delta: dt)
    planWorkScene(delta: dt)
    advanceWorkGuidance(delta: dt)
    let workCameraStart = commander.flightSimulation.pose
    let usedWorkCamera = workGuidance != nil || workBraking != nil
    moveBodies(dt: dt)
    if paused { return }
    if docked {
      stationAutoDefence = nil
      reconcileEliteReward()
      return
    }
    advanceSolarFlight(delta: dt)
    guard screen != .gameOver else { return }
    scoopCargo()
    if !workScenePlanned && missionLoopCounter & 7 == 0 { navalTactics() }
    detectIncomingMissiles()
    advanceNavalMissiles(delta: dt)
    ecmControl.advance(delta: dt)
    if ecmFrames == 0 {
      enemyECMSource = nil
      activeECMActivation = nil
    }
    advanceRetaliation()
    if usedWorkCamera {
      starfield.advance(from: workCameraStart, to: commander.flightSimulation.pose)
    } else {
      starfield.advance(
        delta: dt, speed: speed, pitch: pitch, roll: roll, yaw: yaw, translation: autoPilot.velocity
      )
    }
    let beforeEMPEvent = dischargeAudio.events.last?.id
    advanceEMPCharge(
      triggerHeld: fireAdmitted && !workFireSuspended && selectedFlightTool == .empPirateBlaster)
    if selectedFlightTool == .empPirateBlaster,
      dischargeAudio.events.last?.id != beforeEMPEvent,
      dischargeAudio.events.last?.tool == .empPirateBlaster
    {
      selectedToolActivity = .init(
        tool: .empPirateBlaster, physicalTime: commander.flightSimulation.physicalTime)
    }
    resolveDestroyed()
    persistBlackjackTargets()
    if let id = weaponsTargetID, !bodies.contains(where: { $0.id == id && $0.energy > 0 }) {
      weaponsTargetID = nil
      notify("WEAPON LOCK LOST")
    }
    reconcileEliteReward()
    missionLoopCounter &-= 1
    if missionLoopCounter == 0 { spawnNavalEncounter() }
    if energy <= 0 {
      spin.stop(immediate: true)
      screen = .gameOver
      notify("GAME OVER")
    } else if energy < commander.performance.energy / 4 && messageTime <= 0 {
      notify("ENERGY LOW,SIR")
    }
    if screen != .gameOver { advanceMissionClock(dt) }
  }
  public func viewPosition(_ p: Vector3) -> Vector3 {
    Self.viewPosition(p, screen: screen)
  }
  static func viewPosition(_ p: Vector3, screen: Screen) -> Vector3 {
    switch screen {
    case .rear: return .init(-p.x, p.y, -p.z)
    case .left: return .init(p.z, p.y, -p.x)
    case .right: return .init(-p.z, p.y, p.x)
    default: return p
    }
  }
  private mutating func moveBodies(dt: Double) {
    let asteroidContactFrame = beginAsteroidContactStep(delta: dt)
    let before = commander.flightSimulation.pose
    if !moveWorkFrame(delta: dt) {
      autoPilot.rotateVelocity(pitch: pitch * dt, roll: roll * dt, yaw: yaw * dt)
      commander.flightSimulation.pose.advanceView(
        pitch: pitch * dt, roll: roll * dt, yaw: yaw * dt,
        translation: autoPilot.velocity * dt + Vector3(0, 0, speed * dt * 18))
      rotateScriptNPCVelocities(from: before, to: commander.flightSimulation.pose)
      moveCelestials(delta: dt)
      for index in bodies.indices {
        bodies[index].position = bodies[index].position.rotated(
          pitch: pitch * dt, roll: roll * dt, yaw: yaw * dt)
        bodies[index].orientation.rotate(pitch: pitch * dt, roll: roll * dt, yaw: yaw * dt)
        bodies[index].position = bodies[index].position - autoPilot.velocity * dt
        bodies[index].position.z -= speed * dt * 18
        advanceBodyModelRotation(at: index, delta: dt)
        advanceCanonicalModelSpin(at: index, delta: dt)
        if let physical = bodies[index].physical, physical.spawnIdentity != nil,
          physical.ordnance == nil, bodies[index].scriptShot == nil,
          bodies[index].scriptNPC == nil || c01SurveyorActor(bodies[index]) != nil
        {
          bodies[index].position =
            bodies[index].position
            + commander.flightSimulation.pose.shipVector(physical.velocity) * dt
        }
        if bodies[index].hostile && bodies[index].energy > 0,
          bodies[index].physical?.spawnIdentity == nil, !workScenePlanned,
          bodies[index].missionInstanceID == nil
        {
          enemyAction(index: index, dt: dt)
        }
      }
    }
    guard completeAsteroidContactStep(asteroidContactFrame, delta: dt).admitted else { return }
    advanceNativeStationRecharge(delta: dt)
    detectNativeStationEntry(from: before, delta: dt)
    if pendingNativeStationDock != nil {
      advanceNativeMissionFrame(from: before, to: commander.flightSimulation.pose, delta: dt)
      return
    }
    collideWithNativeStationStructures(from: before, delta: dt)
    if let station = bodies.first(where: { $0.id == 0 && $0.hull == .station }),
      station.containsPlayer
    {
      if station.canEnter(roll: roll, speed: nativeStationRelativeEntrySpeed(station)),
        nativeMainStationHullCourseIsClear(
          station, from: before, to: commander.flightSimulation.pose, delta: dt)
      {
        dockAtOriginalNativeMainStation(station, from: before, delta: dt)
        return
      }
      stopAtStationImpact(at: before)
      applyDamage(dt * 100, front: true)
      if message != "DOCKING COLLISION" || messageTime <= 0 { notify("DOCKING COLLISION") }
    }
    // Motion observers receive only the endpoint retained by physical collision handling.
    advanceNativeMissionFrame(from: before, to: commander.flightSimulation.pose, delta: dt)
    advanceScriptNPCFlight(delta: dt)
    synchronizeScriptNPCPhysicalVelocities()
    advanceScriptNPCWeapons(delta: dt)
    advanceScriptNPCShots(delta: dt)
    persistBlackjackTargets()
    persistCargoPoses()
    persistOrePoses()
    guard persistSalvagePoses(cold: false) else {
      if message != "SALVAGE STATE UNAVAILABLE" || messageTime <= 0 {
        notify("SALVAGE STATE UNAVAILABLE")
      }
      return
    }
    persistScriptActors()
    let retainedNPCs = persistNPCStates()
    guard persistEMPState() else { return }
    let departing = bodies.filter {
      $0.energy > 0 && $0.leavesLocalBubble && $0.id != 0 && !retainedNPCs.contains($0.id)
    }
    // Ordinary traffic/projectile culls must not replay native lifetime history.
    let nativePending = commander.alienStorageState?.current.salvage.pending
    let nativeDeparting = Set(
      departing.compactMap { body -> ActorIdentity? in
        guard let physical = body.physical, let payload = physical.payload,
          case .salvage(let identity) = payload,
          nativePending?[identity]?.binding == physical.identity
        else { return nil }
        return physical.identity
      })
    let nativeWreckDeparting = Set(
      departing.compactMap { body -> ActorIdentity? in
        guard let physical = body.physical, physical.payload == nil,
          let wreck = physical.salvage?.wreck,
          commander.alienStorageState?.current.salvage.native.wrecks[wreck]?.binding
            == physical.identity
        else { return nil }
        return physical.identity
      })
    if !nativeWreckDeparting.isEmpty {
      guard flushNativeSalvageWrecks(parking: nativeWreckDeparting) else {
        notify("SALVAGE STATE UNAVAILABLE")
        return
      }
    }
    if !nativeDeparting.isEmpty {
      guard flushNativeSalvageMotion(parking: nativeDeparting) else {
        notify("SALVAGE STATE UNAVAILABLE")
        return
      }
    }
    for body in departing {
      if var ordnance = body.physical?.ordnance {
        endOrdnance(bodyID: body.id, state: &ordnance, reason: .culled)
      }
      if let actor = body.physical?.identity {
        commander.miningLedger.cull(actor: actor)
        commander.cargoDebrisLedger.cull(actor: actor)
        commander.salvageLedger.cull(actor: actor)
        commander.npcPersistence.cull(actor: actor)
      }
      clearRemovedTarget(body)
      missionTargetRemoved(body)
      blackjackTargetDestroyed(body)
      recordScriptActorRemoval(body, destroyed: false)
    }
    bodies.removeAll {
      $0.energy > 0 && $0.leavesLocalBubble && $0.id != 0 && !retainedNPCs.contains($0.id)
    }
  }
  mutating func enemyAction(index: Int, dt: Double) {
    guard !isEMPDisabled(bodies[index]), bodies[index].physical?.empCrewPod == nil else { return }
    let priorPosition = commander.flightSimulation.pose.systemPoint(bodies[index].position)
    if bodies[index].blackjackRole != nil {
      advanceBlackjackNPC(index: index, delta: dt)
      return
    }
    // The legacy hostile projection alone cannot authorize pursuit of the current player.
    let flight = commander.flightSimulation
    guard let player = flight.player, player.system == systemIdentity,
      let physical = bodies[index].physical,
      physical.identity.system == player.system, physical.identity.visit == player.visit,
      physical.identity.entity >= 2, physical.identity.entity < flight.nextActor,
      physical.npc?.intention == .engage(player)
    else { return }
    if let maximumSpeed = bodies[index].hull.navalSpeed {
      let distance = bodies[index].position.length
      if distance > 0 {
        bodies[index].position =
          bodies[index].position * max(0, 1 - maximumSpeed * 18 * dt / distance)
      }
    } else {
      bodies[index].position.x *= 1 - dt * 0.25
      bodies[index].position.y *= 1 - dt * 0.25
      if bodies[index].position.z > 300 { bodies[index].position.z -= dt * 60 }
    }
    if dt > 0 {
      let worldVelocity =
        (commander.flightSimulation.pose.systemPoint(bodies[index].position) - priorPosition)
        * (1 / dt)
      bodies[index].physical?.velocity = worldVelocity
    }
    if bodies[index].position.length < 1500 {
      let damage = dt * (bodies[index].hull.navalLaserDamage ?? 6) * 2
      emitLegacyNPCBeam(bodyID: bodies[index].id, damage: damage, energyMultiplier: 2)
    }
  }
  mutating func resolveDestroyed() {
    do { try persistNativeStationConditions() } catch {
      notify("RRS LIFECYCLE UNAVAILABLE - SETTLEMENT DEFERRED", voiced: false)
      return
    }
    let initial = bodies.filter { $0.energy <= 0 }
    if !initial.isEmpty { ensurePhysicalActors() }
    for body in initial { settleLegacyCombatDeath(body) }
    var deferred = registerDestroyedCargo()
    deferred.formUnion(registerDestroyedWrecks())
    deferred.formUnion(registerDestroyedNativeSalvage())
    guard registerEMPHullDeaths() else {
      notify("EMP CUSTODY SETTLEMENT DEFERRED")
      return
    }
    let destroyed = bodies.filter { $0.energy <= 0 && !deferred.contains($0.id) }
    for body in destroyed {
      observeMeasuredOreDeath(body)
      if let payload = body.physical?.payload {
        _ = commander.miningLedger.destroy(payload: payload)
        _ = commander.cargoDebrisLedger.destroy(
          payload: payload, protection: gameplayContext()?.protection)
        if case .salvage(let lot) = payload, let context = gameplayContext(),
          commander.alienStorageState?.current.salvage.sections.contains(lot.section) != true
        {
          _ = commander.salvageLedger.destroy(lot: lot, protection: context.protection)
        }
      }
      if let actor = body.physical?.identity {
        guard retireRecoveredEMPActor(actor, reason: .destroyed) else { continue }
        _ = commander.npcPersistence.terminal(actor: actor, reason: .destroyed)
      }
      missionTargetRemoved(body)
      clearRemovedTarget(body)
      blackjackTargetDestroyed(body)
      recordScriptActorRemoval(body, destroyed: true)
    }
    bodies.removeAll { $0.energy <= 0 && !deferred.contains($0.id) }
    if !bodies.contains(where: { $0.hull == .thargoid }) {
      for index in bodies.indices where bodies[index].hull == .thargon {
        bodies[index].hostile = false
        bodies[index].ecmEnabled = false
      }
    }
  }

}

public enum SaveError: Error { case invalidCommander }

/// Owns all mutable simulation state. Rendering consumes value snapshots only.
public actor GameRuntime {
  var game: Game
  var controls = Controls()
  var galleryNamespace: URL?
  var galleryParent: GalleryParentState?
  var scriptSaveURL: URL?
  var nativePeopleFailureGate: NativePeopleFailureGate?
  var scriptRefusalDiagnostic: ScriptRefusalDiagnostic?
  public init(game: Game = Game(), saveURL: URL? = nil) {
    var prepared = game
    prepared.invalidateNativeStationAuthority()
    prepared.stationAutoDefence = nil
    prepared.gameplayCombatTrace = nil
    prepared.flightTrigger = .init()
    prepared.selectedToolActivity = nil
    prepared.inventoryContextEpoch = .init()
    if (try? prepared.commander.prepareEquipment()) != nil {
      prepared.commander.mirrorFittedEquipment()
      self.game = prepared
    } else {
      self.game = prepared
    }
    if self.game.requiresScriptDurability {
      let missingCalendar = self.game.commander.scriptState.calendarLedger == nil
      self.game.ensureScriptCalendar(
        origin: game.jumpCountdown == nil ? .newCommander : .inactiveLegacyMigration)
      if missingCalendar, game.jumpCountdown != nil {
        self.game.commander.scriptState.calendarLedger?.legacyUntrackedJourney = true
      }
    }
    if game.isMissionTrial {
      let namespace = Self.newGalleryNamespace()
      galleryNamespace = namespace
      scriptSaveURL = namespace.appendingPathComponent("commander.json")
      self.game.scriptDurabilityAvailable = true
    } else {
      self.game.scriptDurabilityAvailable = saveURL != nil
      scriptSaveURL = saveURL
    }
  }
  init(trialGame: Game) throws {
    let namespace = Self.newGalleryNamespace()
    let target = namespace.appendingPathComponent("commander.json")
    var candidate = trialGame
    candidate.invalidateNativeStationAuthority()
    try candidate.commander.prepareEquipment()
    candidate.inventoryContextEpoch = .init()
    candidate.ensureScriptCalendar(origin: .newCommander)
    candidate.scriptDurabilityAvailable = true
    candidate.isMissionTrial = true
    try Self.writeCommander(&candidate, to: target)
    game = candidate
    galleryNamespace = namespace
    scriptSaveURL = target
  }
  func invalidateInventoryContext() { game.inventoryContextEpoch = .init() }
  public func inventoryCommand(_ command: InventoryCommand) -> Bool {
    equipmentTransaction(.inventory(command)).applied
  }
  public func snapshot() -> Game {
    game.prepareFlightWeaponDisplay()
    return game
  }
  public func key(_ key: String) {
    if galleryAction(key) { return }
    keyAfterGallery(key)
  }
  private func keyAfterGallery(_ key: String) {
    // Safety input survives a refused candidate command because it precedes its rollback snapshot.
    let stopsTool = game.flightKeyStopsTool(key)
    if game.prepareFlightControlKey(key) {
      controls.fire = false
      return
    }
    if stopsTool { controls.fire = false }
    game.resolveCourierTerminals(publish: scriptPublisher())
    game.resolveFreightTerminals(
      publish: scriptPublisher(diagnosticBoundary: .resolver), diagnostics: scriptRefusalDiagnostic)
    let before = game
    let held = controls
    applyKey(key)
    game.resolveCourierTerminals()
    game.resolveFreightTerminals(diagnostics: scriptRefusalDiagnostic)
    game.scriptDurabilityAvailable = scriptSaveURL != nil
    if before.screen == .gameOver, [" ", "return"].contains(key) {
      game.scriptPacks = before.scriptPacks
      game.missionPacks = before.missionPacks
      game.pendingNewSaveDestination = before.pendingNewSaveDestination
      game.newCommanderSaveReceipt = before.newCommanderSaveReceipt
    }
    do { try commitScriptCommand(from: before) } catch {
      game = before
      controls = held
      game.notify("MISSION SAVE FAILED - ACTION NOT COMMITTED")
    }
  }
  private func applyKey(_ key: String) {
    let prior = keyTransitionState()
    if handleScriptContactKey(key) {
      controls = Controls()
      return
    }
    if !handleEquipmentKey(key) { applyPlainGameKey(key) }
    finishKeyTransition(
      key, old: prior.screen, wasPaused: prior.paused, wasDocked: prior.docked,
      oldLocation: (prior.galaxy, prior.system))
  }
  // Read buffers finish before command phases can enter deeper native transactions.
  private func keyTransitionState() -> (
    screen: Screen, paused: Bool, docked: Bool, galaxy: Int, system: Int
  ) {
    let old = game.screen
    let wasPaused = game.paused
    let wasDocked = game.docked
    let oldLocation = (game.commander.galaxy, game.commander.system)
    return (old, wasPaused, wasDocked, oldLocation.0, oldLocation.1)
  }
  private func handleScriptContactKey(_ key: String) -> Bool {
    if key == "contacts-open" || (key == "b" && !game.acceptsTextInput), game.docked, !game.paused,
      ![
        Screen.help, .gallery, .library, .handoff, .mission, .showroom, .title, .demo, .gameOver,
        .secret, .navigation, .rumour,
      ].contains(game.screen)
    {
      game.emitScriptEvent("contact.requested")
      if game.showScriptDialogue() || game.offerAvailableScriptMission() {
        return true
      }
    }
    return false
  }
  private func handleEquipmentKey(_ key: String) -> Bool {
    if game.passengerBerthSelected, ["s", "r"].contains(key.lowercased()) {
      guard scriptSaveURL != nil else {
        game.notify("CABIN FITTING REQUIRES A SAVE LOCATION")
        return true
      }
      if let intent = game.equipmentPurchaseContext?.passengerBerthFitting(
        fitted: key.lowercased() == "r")
      {
        _ = game.performEquipmentMutation(.passengerBerth(intent))
      }
      return true
    }
    guard key.lowercased() == "return", let context = game.equipmentPurchaseContext else {
      return false
    }
    if game.passengerBerthSelected {
      guard scriptSaveURL != nil else {
        game.notify("CABIN PURCHASE REQUIRES A SAVE LOCATION")
        return true
      }
    }
    _ = game.performEquipmentMutation(.purchase(context))
    // A refused attempt still consumes Return; the original route never fell through.
    return true
  }
  private func applyPlainGameKey(_ key: String) {
    game.key(key)
  }
  private func finishKeyTransition(
    _ key: String, old: Screen, wasPaused: Bool, wasDocked: Bool, oldLocation: (Int, Int)
  ) {
    if old != game.screen || wasPaused != game.paused { invalidateInventoryContext() }
    if old == .handoff, game.screen == .contracts { game.refreshContractRows() }
    game.observeScriptLocation(wasDocked: wasDocked, galaxy: oldLocation.0, system: oldLocation.1)
    if key.lowercased() == "tab", game.screen.isFlight, game.autoPilot.targetID != nil {
      controls.pitch = 0
      controls.yaw = 0
      controls.roll = 0
      if game.dockingComputer { controls = Controls() }
    }
    if old != game.screen || key == "pause"
      || [.gallery, .library, .handoff, .showroom].contains(game.screen)
    {
      controls = Controls()
    }
  }
  public func blackjackHandoffClick(x: Double, y: Double) {
    nativeCommand { $0.blackjackHandoffClick(x: x, y: y) }
  }
  public func secretClick(x: Double, y: Double) { nativeCommand { $0.secretClick(x: x, y: y) } }
  public func showroomClick(x: Double, y: Double) { nativeCommand { $0.showroomClick(x: x, y: y) } }
  public func marketClick(x: Double, y: Double) { nativeCommand { $0.marketClick(x: x, y: y) } }
  public func equipmentClick(y: Double, x: Double? = nil) {
    nativeCommand { $0.equipmentClick(y: y, x: x) }
  }
  public func mapClick(x: Double, y: Double) { game.mapClick(x: x, y: y) }
  public func galleryClick(x: Double, y: Double) { campaignGalleryClick(x: x, y: y) }
  public func setControls(_ value: Controls, expectedEpoch: UUID? = nil) {
    controls = expectedEpoch == nil || expectedEpoch == game.ecmControl.epoch ? value : Controls()
    game.observeFlightFire(held: controls.fire)
  }
  public func setViewport(width: Double, height: Double) {
    game.viewportWidth = width
    game.viewportHeight = height
  }
  public func selectSystem(x: Double, y: Double) { game.selectSystem(x: x, y: y) }
  public func advance(delta: Double) -> Game {
    guard game.admitFlightWorkAdvance(controls: controls) else { return snapshot() }
    game.pendingNativeSalvageCollections.removeAll(keepingCapacity: true)
    game.nativeCrimboAttainedMotion = nil
    game.nativeCrimboMotionSample = nil
    let utilityWorkStart = game.inductionUtilityEndpoint()
    guard let context = prepareAdvance(delta: delta) else {
      game.advanceInductionUtilityWork(from: nil, publish: scriptPublisher())
      return snapshot()
    }
    let glassMeridianStart = game.glassMeridianSample()
    let flightReceptionStart = game.flightReceptionSample()
    let outlookStart = game.orbitalOutlookSample()
    let surveyStart = game.originalSurveySample()
    let recordStart = game.recordRecoveryIdentificationSample()
    let committedRecordIdentification = game.recordRecoveryState?.identification?.operation
    let salvageStart = game.commander.flightSimulation.physicalTime
    let salvagePlayer = game.commander.flightSimulation.player
    game.tick(
      delta: delta, controls: controls,
      nativeSalvagePublish: scriptPublisher(requireNativeSalvage: true))
    commitNativeSalvageCollections()
    commitMeasuredExtraction()
    commitRecordRecoveryLoss()
    commitIdentifiedSalvageLoss()
    commitIdentifiedSalvageCapture(startTime: salvageStart, startPlayer: salvagePlayer)
    commitRecordRecoveryCapture(
      startTime: salvageStart, startPlayer: salvagePlayer,
      committedIdentification: committedRecordIdentification)
    commitInductionCrewLogCapture(startTime: salvageStart, startPlayer: salvagePlayer)
    commitRecordRecoveryIdentification(start: recordStart)
    let stationEntryAttempted = game.pendingNativeStationDock != nil
    commitPendingNativeStationEntry()
    if game.docked { game.stationAutoDefence = nil }
    commitGlassMeridianScan(start: glassMeridianStart)
    commitGlassMeridianBeacons()
    commitC01Surveyor(startTime: salvageStart, startPlayer: salvagePlayer)
    commitFlightReception(start: flightReceptionStart)
    commitOrbitalOutlookScan(start: outlookStart)
    commitOriginalSurveyScan(start: surveyStart)
    finishAdvance(delta: delta, context: context, stationEntryAttempted: stationEntryAttempted)
    game.advanceInductionUtilityWork(from: utilityWorkStart, publish: scriptPublisher())
    return snapshot()
  }
  private typealias AdvanceContext = (
    wasDocked: Bool, wasLive: Bool, location: (Int, Int), localActive: Bool, flightActive: Bool,
    calendarActive: Bool, clockAdvanced: Bool, startPhysicalTime: Double,
    startPlayer: ActorIdentity?, transitSample: NativeWormholeMotionSample?,
    startTransitSeconds: Double
  )
  // Release preflight/read buffers before entering the deeper physical simulation.
  private func prepareAdvance(delta: Double) -> AdvanceContext? {
    let wasDocked = game.docked
    let wasLive = game.screen != .gameOver
    let startPhysicalTime = game.commander.flightSimulation.physicalTime
    let startPlayer = game.commander.flightSimulation.player
    let location = (game.commander.galaxy, game.commander.system)
    let localActive =
      !game.paused
      && ![Screen.demo, .title, .gameOver, .gallery, .library, .help, .navigation].contains(
        game.screen)
    let flightActive =
      localActive && !game.docked
      && ![Screen.mission, .handoff, .rumour, .showroom, .secret].contains(game.screen)
    if localActive && !game.docked {
      do { try game.preflightActiveMissionProjectiles() } catch {
        controls = Controls()
        game.paused = true
        game.notify("MISSION FLIGHT RESTORE REFUSED - PAUSED", voiced: false)
        return nil
      }
    }
    // Projectile restoration must admit the frame before automatic ammunition can publish.
    // Publish before advancing clocks or exposing the candidate projectile to physics.
    advanceStationAutoMissile(delta: delta)
    // Physical facts commit first. A failed script save must never undo a real hit/death.
    let calendarActive = game.calendarActive
    game.scriptEventsDeferred = true
    let clockAdvanced =
      game.requiresScriptDurability
      && game.advanceScriptClockValues(
        delta: delta, flight: flightActive, local: localActive, calendar: calendarActive,
        missionCalendar: game.missionCalendarActive)
    return (
      wasDocked, wasLive, location, localActive, flightActive, calendarActive, clockAdvanced,
      startPhysicalTime, startPlayer,
      flightActive
        && (game.hasNativeWormholeMotionObservers || game.hasInductionArkMotionObserver
          || game.hasInductionRescueMotionObserver)
        ? NativeWormholeMotionSample(game) : nil,
      game.commander.scriptState.transitSeconds
    )
  }
  // Reserve later event/restoration buffers only after the physical tick and native entry.
  private func finishAdvance(delta: Double, context: AdvanceContext, stationEntryAttempted: Bool) {
    let (
      wasDocked, wasLive, location, localActive, flightActive, calendarActive, clockAdvanced,
      startPhysicalTime, startPlayer, transitSample, startTransitSeconds
    ) =
      context
    if wasLive && game.screen == .gameOver {
      if game.energy.isFinite && game.energy < 0 { game.energy = 0 }
      game.markCourierFatalLoss()
      game.markFreightFatalLoss()
      commitNativePeopleLoss()
    }
    // Acts only on the measured fatal state; retries its durable proposal after writer refusal.
    commitWayfarerInductionCrateLoss()
    commitWayfarerColdChainFatalLoss()
    commitInductionClinicUncollectedLoss()
    commitInductionClinicHeldFatalLoss()
    commitInductionWorkshopLoss()
    commitInductionSeedUncollectedLoss()
    commitInductionSeedHeldFatalLoss()
    commitWayfarerRepairLoopFatalLoss()
    commitNativeUtilityFatalLoss()
    commitFieldReliefTargetLoss()
    commitMeasuredExtraction()
    commitRecordRecoveryLoss()
    commitIdentifiedSalvageLoss()
    commitC01Surveyor(startTime: startPhysicalTime, startPlayer: startPlayer)
    game.observeSelectedFleetDiscovery()
    game.observeNativeCrimboAttainedMotion(
      delta: delta, flightWasActive: wasLive && !wasDocked && localActive && flightActive,
      startTime: startPhysicalTime, startPlayer: startPlayer,
      stationEntryAttempted: stationEntryAttempted)
    if wasLive && localActive && flightActive && !stationEntryAttempted {
      commitNativePeopleCapture(
        startTime: startPhysicalTime, startPlayer: startPlayer, delta: delta)
    }
    game.resolveCourierTerminals(publish: scriptPublisher())
    game.resolveFreightTerminals(
      publish: scriptPublisher(diagnosticBoundary: .resolver), diagnostics: scriptRefusalDiagnostic)
    game.observeScriptLocation(wasDocked: wasDocked, galaxy: location.0, system: location.1)
    game.scriptEventsDeferred = false
    if localActive && !game.docked {
      game.persistScriptActors()
      do { try game.restoreScriptActors() } catch {
        // Earlier physical effects stay committed. The restore operation's own
        // all-record preflight prevents partial actor/projectile publication.
        controls = Controls()
        game.paused = true
        game.notify("MISSION FLIGHT RESTORE REFUSED - PAUSED", voiced: false)
        return
      }
    }
    if localActive {
      game.advanceNativeWormholeFrame(from: transitSample, publish: scriptPublisher())
      game.drainScriptEvents(publish: scriptPublisher())
    }
    if clockAdvanced {
      game.fireDueScriptTimers(
        flight: flightActive, local: localActive, calendar: calendarActive,
        transit: game.commander.scriptState.transitSeconds > startTransitSeconds,
        publish: scriptPublisher())
    }
    if localActive {
      game.advanceInductionArk(from: transitSample, publish: scriptPublisher())
      game.advanceInductionCrewLog(publish: scriptPublisher())
      game.advanceInductionUtilitySource(publish: scriptPublisher())
      game.advanceInductionRescueFlight(from: transitSample, publish: scriptPublisher())
    }
    game.advanceScriptWorldJobs(delta: delta, publish: scriptPublisher())
  }
  public func save(to url: URL) throws {
    try requireGalleryFileAccess(url)
    var candidate = game
    candidate.resolveCourierTerminals()
    candidate.resolveFreightTerminals()
    try Self.writeCommander(&candidate, to: url)
    game = candidate
    scriptSaveURL = url
    game.stationAutoDefence?.missilePublicationRefused = false
    game.stationAutoDefence?.saveBinding = url
    nativePeopleFailureGate = nil
    game.scriptDurabilityAvailable = true
  }

  /// Immutable per-publication ownership, never serialized or reused as validation authority.
  final class NativeSavePreparation: Sendable {
    private let gameValue: Game
    private let commanderValue: Commander
    var game: Game { _read { yield gameValue } }
    var commander: Commander { _read { yield commanderValue } }
    init(game: consuming Game, commander: consuming Commander) {
      gameValue = consume game
      commanderValue = consume commander
    }
  }

  /// Shared native persistence barrier before either ordinary JSON or Script chunks.
  /// The returned live Game keeps bindings; only the disk Commander clears them.
  static func prepareNativeSaveState(
    _ value: Game, diagnostics: ScriptRefusalDiagnostic? = nil,
    diagnosticBoundary: ScriptRefusalBoundary = .publication
  ) throws -> NativeSavePreparation {
    var candidate = value
    var stage = ScriptRefusalStage.nativePeople
    do {
      try candidate.recordFlightReceptionFailureIfNeeded()
      _ = try candidate.applyGlassMeridianPending()
      _ = try candidate.applyFlightReceptionPending()
      try candidate.recordNativePeopleLossIfNeeded()
      candidate.stageMeasuredHullLoss()
      try candidate.applyMeasuredPending()
      _ = try candidate.recordRecoveryLossIfNeeded()
      _ = try candidate.recordIdentifiedSalvageLossIfNeeded()
      try candidate.retryRecordRecoveryIdentification()
      try candidate.retryRecordRecoveryCapture()
      try candidate.retryInductionCrewLogCapture()
      try candidate.retryIdentifiedSalvageCapture()
      stage = .nativeDock
      try validateNativeDockEvidenceForSave(&candidate)
      stage = .nativeStations
      try candidate.persistNativeStationConditions()
      try candidate.failFieldReliefAtDestroyedTarget()
      stage = .equipment
      try candidate.commander.prepareEquipment()
      candidate.commander.mirrorFittedEquipment()
      stage = .nativeDestruction
      candidate.resolveDestroyed()
      try candidate.recordFlightReceptionFailureIfNeeded()
      candidate.stageMeasuredHullLoss()
      try candidate.applyMeasuredPending()
      _ = try candidate.recordRecoveryLossIfNeeded()
      _ = try candidate.recordIdentifiedSalvageLossIfNeeded()
      return try finishNativeSaveState(
        &candidate, diagnostics: diagnostics, diagnosticBoundary: diagnosticBoundary)
    } catch {
      diagnostics?.record(diagnosticBoundary, .init(stage: stage, error: error, game: candidate))
      throw error
    }
  }

  private static func validateNativeDockEvidenceForSave(_ candidate: inout Game) throws {
    guard
      candidate.commander.nativeStations?.ledger.currentDock == nil
        || candidate.nativeStationDockEvidenceIsCurrent,
      candidate.commander.nativeStations?.currentMainDock == nil
        || candidate.nativeMainStationDockEvidenceIsCurrent
    else { throw SaveError.invalidCommander }
  }

  /// Disk commanders omit only current scene bindings; live load candidates restore them.
  private static func clearNativeSaveBindings(
    _ commander: inout Commander, system: SystemIdentity
  ) {
    if commander.npcPersistence.count > 0 {
      commander.npcPersistence.resetPhysicalBindings(system: system)
    }
    commander.resetWantedCareerBindings(system: system)
  }

  /// Keep the comparison copy out of the live load frame. All semantic facts still compare.
  @inline(never)
  private static func nativeCommanderNeedsRepublishing(
    _ candidate: borrowing Game, persisted: borrowing Commander
  ) -> Bool {
    var projected = candidate.commander
    clearNativeSaveBindings(&projected, system: candidate.systemIdentity)
    return projected != persisted
  }

  private static func finishNativeSaveState(
    _ candidate: inout Game, diagnostics: ScriptRefusalDiagnostic? = nil,
    diagnosticBoundary: ScriptRefusalBoundary = .publication
  ) throws -> NativeSavePreparation {
    candidate.persistCargoPoses()
    candidate.persistOrePoses()
    guard candidate.persistSalvagePoses() else {
      diagnostics?.record(
        diagnosticBoundary,
        .init(stage: .salvagePoses, error: SaveError.invalidCommander, game: candidate))
      throw SaveError.invalidCommander
    }
    candidate.persistBlackjackTargets()
    let refusedNPCs = candidate.persistNPCStates()
    guard refusedNPCs.isEmpty, !candidate.hasUnsettledWreckDeaths, candidate.commander.valid,
      !candidate.bodies.contains(where: {
        $0.energy <= 0 && $0.hull.isTargetShip && $0.physical?.npc != nil
          && $0.physical?.npc?.role != .mission
      })
    else {
      if let diagnostics, !diagnostics.contains(diagnosticBoundary) {
        // Bits 1/2/4/8: no NPC refusals, no unsettled wreck, commander valid, no dead ordinary NPC.
        let npcCheck: UInt16 = refusedNPCs.isEmpty ? 1 : 0
        let wreckCheck: UInt16 = !candidate.hasUnsettledWreckDeaths ? 2 : 0
        let commanderCheck: UInt16 = candidate.commander.valid ? 4 : 0
        let ordinaryNPCCheck: UInt16 =
          !candidate.bodies.contains(where: {
            $0.energy <= 0 && $0.hull.isTargetShip && $0.physical?.npc != nil
              && $0.physical?.npc?.role != .mission
          }) ? 8 : 0
        let checks: UInt16 = npcCheck | wreckCheck | commanderCheck | ordinaryNPCCheck
        diagnostics.record(
          diagnosticBoundary,
          .init(
            stage: .nativeSaveValidation, error: SaveError.invalidCommander, game: candidate,
            checks: checks, count: refusedNPCs.count))
      }
      throw SaveError.invalidCommander
    }
    var persistedCommander = candidate.commander
    clearNativeSaveBindings(&persistedCommander, system: candidate.systemIdentity)
    return NativeSavePreparation(game: copy candidate, commander: consume persistedCommander)
  }

  public func restoreStartup(from url: URL) throws {
    try load(from: url, persistMigrations: false)
    if game.requiresScriptDurability {
      game.scriptStartupTime = game.time
    }
    game.screen = .title
    game.time = 0
  }
  public func load(from url: URL, persistMigrations: Bool = true) throws {
    try loadNativeCommander(from: url, persistMigrations: persistMigrations, navigationBinding: nil)
  }
  func loadNativeCommander(
    from url: URL, persistMigrations: Bool, navigationBinding: ScriptNavigationTradeBinding?
  ) throws {
    try requireGalleryFileAccess(url)
    let data = try CommanderSaveInput.read(from: url)
    try ScriptSaveJSONPreflight.validate(data)
    if let pointer = try? JSONDecoder().decode(ScriptSavePointer.self, from: data) {
      if pointer.schemaVersion >= 6 {
        guard (pointer.scope == "gallery") == (galleryNamespace != nil) else {
          throw MissionPackError(
            "Trial saves open only in Gallery trials; commander saves open in the live game.")
        }
      }
      let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: url)
      try Self.requireGalleryPathAccess(generation, namespace: galleryNamespace)
      let (commander, world) = try ScriptSaveStore.read(
        data, from: url, navigationBinding: navigationBinding)
      // v2 is already migrated/validated; ordinary docking/load callbacks must not replay here.
      var candidate = Game(executive: false)
      candidate.commander = commander
      try candidate.commander.prepareEquipment()
      candidate.isMissionTrial = galleryNamespace != nil
      candidate.trialTitle = game.trialTitle
      candidate.trialDigest = game.trialDigest
      candidate.trialSeed = game.trialSeed
      candidate.missionPacks = game.missionPacks
      candidate.scriptPacks = game.scriptPacks
      candidate.scriptDurabilityAvailable = true
      candidate.viewportWidth = game.viewportWidth
      candidate.viewportHeight = game.viewportHeight
      candidate.systems = Universe.systemsIncludingPlugh(number: commander.galaxy)
      if candidate.requiresScriptDurability {
        migrateScriptCalendar(&candidate, untrackedJump: world.jumpCountdown != nil)
      }
      candidate.restoreScriptWorld(world)
      try candidate.migrateMiningPresence(legacyMissing: pointer.schemaVersion < 26)
      candidate.rebuildMiningFields()
      candidate.rebuildSalvageSites()
      try candidate.restoreSavedNPCSceneBindings()
      try candidate.rebindNativeStationsAfterLoad()
      try candidate.validateInstalledCourierContent()
      candidate.resolveCourierTerminals()
      candidate.resolveFreightTerminals()
      candidate.suspendUnavailableScriptContent(navigationBinding: navigationBinding)
      guard candidate.commander.valid else { throw SaveError.invalidCommander }
      if persistMigrations && Self.nativeCommanderNeedsRepublishing(candidate, persisted: commander)
      {
        try Self.writeCommander(&candidate, to: url, navigationBinding: navigationBinding)
      }
      game = candidate
      controls = Controls()
      scriptSaveURL = url
      game.scriptDurabilityAvailable = true
      return
    }
    guard galleryNamespace == nil else {
      throw MissionPackError("Legacy commander files cannot replace a Gallery trial.")
    }
    try ScriptSaveJSONPreflight.rejectCourierFields(data, location: .rawCommander)
    try ScriptSaveJSONPreflight.validateFreightFields(data, part: .commander)
    try AlienStorageVersionedSave.rejectFields(data)
    try EMPVersionedSave.rejectFields(data, part: .commander)
    try NativePeopleVersionedSave.rejectFields(data)
    try RingMiningVersionedSave.rejectFields(data)
    try ElectricalVersionedSave.rejectFields(data)
    try HyperspaceDriveVersionedSave.rejectFields(data)
    try ScriptFinanceVersionedSave.rejectFields(data, part: .commander)
    var commander = try ScriptValueStorage.decoder(typed: false).decode(Commander.self, from: data)
    // Native pledge evidence belongs to versioned missions chunks.
    guard commander.scriptState.pledgeLedger == nil,
      commander.scriptState.instances.values.allSatisfy({ $0.pledgeReceiptID == nil })
    else { throw SaveError.invalidCommander }
    let original = commander
    commander.migrateLegacyPassengerMarker()
    var candidate = game
    guard candidate.load(commander) else { throw SaveError.invalidCommander }
    candidate.pendingNewSaveDestination = nil
    candidate.newCommanderSaveReceipt = nil
    try candidate.rebindNativeStationsAfterLoad()
    if candidate.requiresScriptDurability { migrateScriptCalendar(&candidate) }
    candidate.suspendUnavailableScriptContent(navigationBinding: navigationBinding)
    guard candidate.commander.valid else { throw SaveError.invalidCommander }
    if persistMigrations && candidate.commander != original {
      try Self.writeCommander(&candidate, to: url, navigationBinding: navigationBinding)
    }
    game = candidate
    controls = Controls()
    scriptSaveURL = url
    game.scriptDurabilityAvailable = true
  }
}

extension Game {
  var scriptSimulationSave: ScriptSimulationSave {
    ScriptSimulationSave(
      randomState: randomState, fireCooldown: fireCooldown, spawnClock: legacySimulationSpawnClock,
      missionLoopCounter: missionLoopCounter, missionSpawnDelay: missionSpawnDelay,
      ecmFrames: ecmFrames, ecmRemainingDuration: ecmControl.remainingDuration,
      enemyECMSource: enemyECMSource, missileCooldown: missileCooldown,
      cabinTemperature: cabinTemperature, altitude: altitude, solar: ScriptSolarSave(game: self))
  }
  mutating func restoreScriptSimulation(_ state: ScriptSimulationSave?) {
    guard let state, state.valid else { return }
    randomState = state.randomState
    fireCooldown = state.fireCooldown
    legacySimulationSpawnClock = state.spawnClock
    missionLoopCounter = state.missionLoopCounter
    missionSpawnDelay = state.missionSpawnDelay
    let duration =
      state.ecmRemainingDuration
      ?? Double(state.ecmFrames) / ECMControl.referenceFramesPerSecond
    _ = ecmControl.restoreRemainingDuration(duration)
    activeECMActivation = nil
    enemyECMSource = state.enemyECMSource
    missileCooldown = state.missileCooldown
    cabinTemperature = state.cabinTemperature
    altitude = state.altitude
    if let solar = state.solar {
      solar.restore(into: &self)
    } else {
      celestials = []
      solarFuelRemainder = 0
      solarScoopState = .inactive
    }
  }
  mutating func seedScriptTrial(_ seed: UInt64) { randomState = seed }
}

extension Game {
  fileprivate func preflightActiveMissionProjectiles() throws {
    try validateRetainedMissionActorRestoration()
    guard !commander.scriptState.projectiles.isEmpty else { return }
    let identities: [UUID] = commander.scriptState.projectiles.compactMap { id, record in
      record.galaxy == commander.galaxy && record.system == commander.system ? id : nil
    }
    try validateRetainedMissionProjectileAdmissions(identities)
  }
}
