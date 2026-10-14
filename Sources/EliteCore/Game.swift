import Foundation

public enum Screen: String, Codable, Sendable, CaseIterable {
  case demo, title, front, rear, left, right, chart, shortChart, system, market, status, inventory,
    equipment, buy, sell, secret, help, mission, handoff, gallery, navigation, showroom, rumour,
    gameOver, contracts
  public var isFlight: Bool { [.front, .rear, .left, .right].contains(self) }
}

public struct Commander: Sendable, Equatable, Codable {
  private var savedContracts: ScriptContractState?
  public var contracts: ScriptContractState {
    get { savedContracts ?? ScriptContractState() }
    set { savedContracts = newValue == ScriptContractState() ? nil : newValue }
  }
  public var ownedEquipment: OwnedEquipmentInventory?
  private var savedAccommodation: ShipAccommodation?
  public var accommodation: ShipAccommodation {
    get { savedAccommodation ?? ShipAccommodation() }
    set { savedAccommodation = newValue }
  }
  private var savedScriptState: ScriptEngineState?
  public var scriptState: ScriptEngineState {
    get { savedScriptState ?? ScriptEngineState() }
    set { savedScriptState = newValue == ScriptEngineState() ? nil : newValue }
  }
  private var savedMissionProgress: [String: MissionProgress]?
  public var missionProgress: [String: MissionProgress] {
    get { savedMissionProgress ?? [:] }
    set { savedMissionProgress = newValue }
  }
  public var missionPayloadTonnes: Int {
    missionProgress.values.reduce(0) { $0 + $1.payloads.values.reduce(0, +) }
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
  public var name = "JAMESON"
  public var credits = 1000
  public var fuel = 70
  public var galaxy = 0
  public var system = 7
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
    get { mountedLasers ?? LaserMounts(front: legacyLaser) }
    set { mountedLasers = newValue }
  }
  private var finiteXYZzyCash: Bool?
  public var xyzzyCashGranted: Bool {
    get { finiteXYZzyCash ?? false }
    set { finiteXYZzyCash = newValue }
  }
  public var fuelStorageUnits: Int {
    get { storageUnitCount ?? 0 }
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
    get { displayStyle ?? .whiteWireframe }
    set { displayStyle = newValue }
  }
  mutating func migrateLegacyXYZzyMounts() {
    if mountedLasers == nil && xyzzyActive {
      mountedLasers = LaserMounts(front: .naval, left: .naval, right: .naval, rear: .naval)
      equipment.insert(Equipment.navalLaser)
    }
  }
  public init() {}
  public var availableCredits: Int { unlimitedCash ? Int.max : credits }
  public var capacity: Int {
    let standard = standardCargoCapacity
    return unlimitedCargo ? Int.max / 17 : standard
  }
  public var cargoTonnes: Int {
    zip(cargo, Commodity.all).reduce(
      missionPayloadTonnes + scriptState.payloadTonnes + accommodation.fittedBerths.count * 5
    ) { $0 + ($1.1.unit == "t" ? $1.0 : 0) }
  }
  public var rank: String {
    let thresholds = [8, 16, 32, 64, 128, 512, 2560, Self.eliteThreshold]
    return [
      "Harmless", "Mostly Harmless", "Poor", "Average", "Above Average", "Competent", "Dangerous",
      "Deadly", "ELITE",
    ][thresholds.filter { kills >= $0 }.count]
  }
  public var valid: Bool {
    ShipCatalogue.ship(shipID)?.game != nil && cargo.count == 17
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
      && cargoTonnes <= capacity
      && (navigationPlan?.valid ?? true) && blackjack.valid
      && scriptState.valid && accommodationValid && ownedEquipmentValid && issuedEquipmentValid
      && contractsValid
      && missionProgress.count <= 128 && missionProgress.values.allSatisfy(\.valid)
      && (!blackjack.carriesFirearm || cargo[10] >= 1)
      && equipment.isSubset(of: Equipment.validNames) && !name.isEmpty && name.count <= 16
  }
}

public struct Equipment: Sendable {
  public static let legacyDockingComputer = "Docking Computers"
  public static let navalEnergyUnit = "Naval Energy Unit"
  public static let navalLaser = "Naval Laser"
  public static var validNames: Set<String> {
    Set(all.map(\.name)).subtracting([FuelStorage.equipmentName, PassengerCabin.equipmentName])
      .union([
        navalEnergyUnit, navalLaser, ShieldBooster.capital.equipmentName, legacyDockingComputer,
      ])
  }
  public static var maximumHardware: Set<String> {
    validNames.subtracting(
      [legacyDockingComputer, "Extra Energy Unit", "Pulse Laser", "Beam Laser", "Military Laser"]
        + TargetingTier.allCases.map(\.equipmentName) + NavigationTier.allCases.map(\.equipmentName)
        + ShieldBooster.allCases.map(\.equipmentName)
    )
    .union([
      TargetingTier.military.equipmentName, NavigationTier.military.equipmentName,
      ShieldBooster.capital.equipmentName,
    ])
  }
  public let name: String
  public let price: Int
  public let technology: Int
  public static let base: [Equipment] =
    [
      .init(name: "Fuel", price: 2, technology: 0),
      .init(name: "Missile", price: 300, technology: 0),
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
      .init(name: PassengerCabin.equipmentName, price: PassengerCabin.price, technology: 0),
    ]
  public static let all =
    base
    + TargetingTier.allCases.map {
      .init(name: $0.equipmentName, price: $0.price, technology: $0.technology)
    }
    + NavigationTier.allCases.map {
      .init(name: $0.equipmentName, price: $0.price, technology: $0.technology)
    } + [
      .init(name: FuelStorage.equipmentName, price: FuelStorage.price, technology: 0),
      .init(name: navalLaser, price: 0, technology: 0),
      .init(name: navalEnergyUnit, price: 0, technology: 0),
    ]
    + ShieldBooster.allCases.compactMap(\.shopItem) + [
      .init(name: ShieldBooster.capital.equipmentName, price: 0, technology: 0)
    ]
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
  public var commander = Commander()
  public var systems = Universe.systemsIncludingPlugh()
  public var screen: Screen = .title
  public var paused = false
  public var isMissionTrial = false
  public var contractBoard = ContractBoardUI()
  public var trialTitle: String?
  var trialDigest: String?
  var trialSeed: UInt64?
  public var docked = true
  public var dockedAtMainStation = true
  var scriptReferenceFrame: ScriptReferenceFrame?
  var scriptDispatching = false
  var scriptEventsDeferred = false
  var scriptDurabilityAvailable = false
  public var scriptPacks: [ScriptPack] = []
  public var scriptAvailablePackDigest: String?
  public var scriptOffer: UUID?
  public var scriptConfirmSelected = true
  public var missionPacks = MissionPackLibrary.bundled
  public var packOffer: PackOffer?
  public var packOfferElapsed = 0.0
  public var packDialogScroll = 0
  public var blackjackOffer: BlackjackOffer?
  public var showroom = ShowroomState()
  public var galacticBrowse = GalaxyBrowseState()
  public var systemInspection: SystemInspection?
  public var rumourReturn: Screen = .status
  public var blackjackReturn: Screen = .status
  var screenHistory: [Screen] = []
  var flightReturn: Screen = .front
  public var selectedSystem = 7
  public var selection = 0
  public var informationScroll = 0
  public var chartInformationScroll = 0
  public var market = MarketItem.generate(economy: 5, fluctuation: 0)
  public var bodies: [SpaceBody] = []
  public var starfield = Starfield()
  public var speed = 0.0
  public var pitch = 0.0
  public var roll = 0.0
  public var yaw = 0.0
  public var spin = SpinControl()
  public var autoPilot = AutoTargetControl()
  public var viewportWidth = 768.0
  public var viewportHeight = 768.0
  public var targetPanelExpanded: Bool?
  public var weaponsTargetID: Int?
  public var secretScroll = 0
  public var energy = 256.0
  public var frontShield = 255.0
  public var rearShield = 255.0
  public var laserHeat = 0.0
  public var laserFlash = 0.0
  public var altitude = 1.0
  public var celestials: [CelestialBody] = []
  public var solarScoopState: SolarScoopState = .inactive
  var solarFuelRemainder = 0.0
  public var cabinTemperature = 0.0
  public var equipmentMount: LaserMount = .front
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
  private var fireCooldown = 0.0
  private var spawnClock = 0.0
  var missionLoopCounter: UInt8 = 0
  var missionSpawnDelay = 0
  var ecmFrames = 0
  var enemyECMSource: Int?
  public var ecmControl = ECMControl()
  public var retaliation = RetaliationControl()
  var missileCooldown = 0.0
  var nextBodyID = 10
  private var randomState: UInt64 = 0x45_4c49_5445
  public init(executive: Bool = true) {
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
    guard value.valid else { return false }
    // A new commander must never receive destruction rewards from the previous local scene.
    bodies = []
    scriptReferenceFrame = nil
    scriptStartupTime = nil
    commander = value
    clearCelestialFlight()
    blackjackOffer = nil
    packOffer = nil
    scriptOffer = nil
    scriptAvailablePackDigest = nil
    migrateMissionProgress()
    gallery = MissionGalleryState()
    showroom = ShowroomState()
    galacticBrowse = GalaxyBrowseState()
    systemInspection = nil
    dockedAtMainStation = true
    enforceBlackjackWanted()
    commander.migrateXYZzyPolicy()
    commander.migrateLegacyXYZzyMounts()
    mapSearch = PlanetSearchState()
    if let tier = commander.targetingTier { commander.installTargetingComputer(tier) }
    if let tier = commander.navigationTier { commander.installNavigationComputer(tier) }
    if let booster = commander.shieldBooster { commander.installShieldBooster(booster) }
    energy = commander.performance.energy
    frontShield = commander.shieldCapacity
    rearShield = commander.shieldCapacity
    targetPanelExpanded = nil
    systems = Universe.systemsIncludingPlugh(number: value.galaxy)
    selectedSystem = value.system
    market = MarketItem.at(currentSystem, fluctuation: 0)
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
    retaliation.clear()
    weaponsTargetID = nil
    missileCooldown = 0
    paused = false
    spin.stop(immediate: true)
    cancelAutoTarget()
    screen = .status
    screenHistory.removeAll()
    speed = 0
    reconcileEliteReward()
    navigationDocked()
    return true
  }
  public mutating func key(_ raw: String) {
    defer { commander.synchronizeEquipmentInventory() }
    let key = raw.lowercased()
    if interfaceKey(key) { return }
    if ownedEquipmentKey(key) { return }
    if !docked && screen.isFlight {
      switch key {
      case "r", "tab":
        cycleAutoTarget()
        return
      case "i":
        targetPanelExpanded = !(targetPanelExpanded ?? (viewportWidth >= 1100))
        return
      case "q":
        cancelAutoTarget()
        return
      case "v":
        if autoTargetBody?.hull == .station { cancelAutoTarget() }
        spin.toggleMode()
        return
      case "b":
        if autoTargetBody?.hull == .station { cancelAutoTarget() }
        spin.stop()
        return
      case "]", "spin:cw":
        if autoTargetBody?.hull == .station { cancelAutoTarget() }
        spin.begin(.clockwise)
        return
      case "[", "spin:ccw":
        if autoTargetBody?.hull == .station { cancelAutoTarget() }
        spin.begin(.anticlockwise)
        return
      default: break
      }
    }
    if screen == .demo { return }
    if screen == .title || screen == .gameOver {
      if key == " " || key == "return" {
        if screen == .gameOver { self = Game(executive: commander.executive) }
        screen = .status
        if let saved = scriptStartupTime {
          time = saved
          scriptStartupTime = nil
        }
      }
      return
    }
    if key.count == 1, let number = Int(key), (0...9).contains(number) {
      functionKey(number)
      return
    }
    if screen == .equipment, Equipment.all.indices.contains(selection),
      Equipment.all[selection].name == PassengerCabin.equipmentName, ["s", "r"].contains(key)
    {
      let berth =
        key == "s"
        ? commander.accommodation.fittedBerths.first(where: { !$0.use.used })
        : commander.accommodation.storedBerths.first
      guard let berth else {
        notify("NO EMPTY CABIN AVAILABLE")
        return
      }
      do {
        try setPassengerBerthFitted(berth.id, fitted: key == "r")
        notify(key == "r" ? "OWNED CABIN REFITTED" : "EMPTY CABIN STORED")
      } catch { notify(error.localizedDescription.uppercased()) }
      return
    }
    switch key {
    case "up":
      if screen == .equipment {
        moveEquipmentSelection(-1)
      } else {
        selection = max(0, selection - 1)
      }
    case "down":
      if screen == .equipment {
        moveEquipmentSelection(1)
      } else {
        selection = min(Commodity.all.count - 1, selection + 1)
      }
    case "left", "right":
      if screen == .equipment {
        equipmentMount = key == "right" ? equipmentMount.next : equipmentMount.previous
      } else if screen == .chart || screen == .shortChart {
        selectChartNeighbour(key == "left" ? -1 : 1)
      } else if screen == .buy || screen == .sell {
        trade(buy: key == "right")
      }
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
      commander.installTargetingComputer(.docking)
      notify("DOCKING TARGETING COMPUTER FITTED")
    case "2":
      fitMaximumHardware()
      notify("MAXIMUM HARDWARE FITTED")
    case "c": restoreXYZzyCobra()
    case "3":
      commander.unlimitedMissiles.toggle()
      commander.missiles = commander.missileCapacity
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
      commander.equipment.insert("Fuel Scoops")
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
    commander.xyzzyActive = true
    commander.profitScanEnabled = true
    commander.shipDisplayStyle = .shadedPanels
    commander.retaliationEnabled = true
    commander.unlimitedMissiles = true
    commander.unlimitedFuel = true
    commander.unlimitedJumps = false
    commander.unlimitedCargo = true
    commander.startXYZzyCash()
    commander.autoTrade = true
    commander.speech = true
    commander.autoECM = true
    commander.autoTarget = true
    restoreXYZzyCobra()
    if docked { autoTrade() }
  }
  mutating func restoreXYZzyCobra() {
    commander.shipID = "SH023"
    fitMaximumHardware()
    // A secret refit preserves cargo even when a larger former hold was full.
    if commander.cargoTonnes > commander.standardCargoCapacity { commander.unlimitedCargo = true }
    speed = min(speed, commander.performance.speed)
    showroom.selection = commander.shipID
    showroom.baseline = commander.shipID
    showroom.baselineUsesCurrent = true
    clearShowroomSearch()
    notify("COBRA MK III RESTORED - MAXIMUM HARDWARE")
  }
  mutating func fitMaximumHardware() {
    commander.storeOwnedModules(
      commander.equipment.subtracting(Equipment.maximumHardware), keeping: "")
    commander.equipment = Equipment.maximumHardware
    for mount in LaserMount.allCases where commander.performance.supports(mount) {
      commander.installLaser(.naval, on: mount)
    }
    if commander.performance.cargoExpansion == 0 { commander.equipment.remove("Large Cargo Bay") }
    commander.fuelStorageUnits = FuelStorage.maximumCount
    commander.fuel = commander.fuelCapacity
    commander.missiles = commander.missileCapacity
    energy = commander.performance.energy
    frontShield = commander.shieldCapacity
    rearShield = commander.shieldCapacity
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
    navigatePrimary(to: destination)
  }
  public mutating func selectNeighbour(direction: Int) {
    let known = knownSystems
    let current = known.firstIndex { $0.id == selectedSystem } ?? 0
    manuallySelectSystem(known[(current + direction + known.count) % known.count].id)
  }
  public mutating func selectSystem(x: Int, y: Int) {
    let selected =
      knownSystems.min { left, right in
        let ld = pow(Double(left.x - x), 2) + pow(Double(left.y - y), 2)
        let rd = pow(Double(right.x - x), 2) + pow(Double(right.y - y), 2)
        return ld < rd
      }?.id ?? selectedSystem
    manuallySelectSystem(selected)
  }
  public mutating func trade(buy: Bool) {
    guard docked, market.indices.contains(selection) else { return }
    let index = selection
    let item = market[index]
    if buy {
      guard item.quantity > 0, commander.availableCredits >= item.price,
        Commodity.all[index].unit != "t" || commander.cargoTonnes < commander.tradeCargoCapacity
      else {
        notify("CANNOT BUY")
        return
      }
      if !commander.unlimitedCash { commander.credits -= item.price }
      commander.cargo[index] += 1
      market[index].quantity -= 1
    } else {
      guard commander.sellableCargo(index) > 0 else {
        notify(
          index == 10 && commander.markedFirearms > 0 ? "MISSION FIREARM RESERVED" : "NO CARGO")
        return
      }
      commander.credits = min(4_294_967_295, commander.credits + item.price)
      commander.cargo[index] -= 1
      market[index].quantity += 1
    }
  }
  public mutating func purchase() {
    guard docked, Equipment.all.indices.contains(selection) else { return }
    let before = commander
    let oldShields = (frontShield, rearShield)
    defer {
      commander.synchronizeEquipmentInventory()
      if (!commander.accommodation.fitted.isEmpty || commander.ownedEquipment != nil)
        && !commander.valid
      {
        commander = before
        frontShield = oldShields.0
        rearShield = oldShields.1
        notify("EQUIPMENT CANNOT FIT WITH THE CURRENT CABINS AND CARGO")
      }
    }
    let catalogueItem = Equipment.all[selection]
    let item = Equipment(
      name: catalogueItem.name, price: shopPrice(catalogueItem),
      technology: catalogueItem.technology)
    if item.name == PassengerCabin.equipmentName {
      do { try confirmPassengerBerth(passengerBerthQuote) } catch {
        notify(error.localizedDescription.uppercased())
      }
      return
    }
    if item.name == FuelStorage.equipmentName {
      guard commander.fuelStorageUnits < FuelStorage.maximumCount else {
        notify("FUEL STORAGE FULL")
        return
      }
      let price = item.price
      guard commander.availableCredits >= price else {
        notify("NOT ENOUGH CASH")
        return
      }
      if !commander.unlimitedCash { commander.credits -= price }
      commander.fuelStorageUnits += 1
      notify("FUEL STORAGE UNIT FITTED - REFUEL SEPARATELY")
      return
    }
    if Equipment.isReward(item.name) && !atPlugh {
      notify(Equipment.rewardLabel(item.name).uppercased() + " - NOT FOR SALE")
      return
    }
    if item.name == "Extra Energy Unit" && commander.equipment.contains(Equipment.navalEnergyUnit) {
      notify("NAVAL ENERGY UNIT FITTED")
      return
    }
    if let tier = TargetingTier.from(item.name), let fitted = commander.targetingTier,
      fitted >= tier
    {
      notify("TARGETING COMPUTER ALREADY FITTED")
      return
    }
    if let tier = NavigationTier.from(item.name), let fitted = commander.navigationTier,
      fitted >= tier
    {
      notify("NAVIGATIONAL COMPUTER ALREADY FITTED")
      return
    }
    if let booster = ShieldBooster.from(item.name), let fitted = commander.shieldBooster,
      fitted >= booster
    {
      notify(
        booster.multiplier < fitted.multiplier
          ? "WOULD REDUCE SHIELD CAPACITY" : "SHIELD BOOSTER ALREADY FITTED")
      return
    }
    if let kind = LaserKind.from(item.name) {
      purchaseLaser(kind, item: item)
      return
    }
    if item.name == "Large Cargo Bay" && commander.performance.cargoExpansion == 0 {
      notify("THIS HULL CANNOT FIT A CARGO EXPANSION")
      return
    }
    let cost =
      item.price
    guard equipmentAvailable(item), commander.availableCredits >= cost else {
      notify("NOT AVAILABLE")
      return
    }
    if item.name == "Fuel" {
      commander.fuel = commander.fuelCapacity
    } else if item.name == "Missile" {
      guard commander.missiles < commander.missileCapacity else {
        notify("MISSILE RACK FULL")
        return
      }
      commander.missiles += 1
    } else {
      guard !commander.equipment.contains(item.name) else {
        notify("ALREADY FITTED")
        return
      }
      if let tier = TargetingTier.from(item.name) {
        commander.installTargetingComputer(tier)
      } else if let tier = NavigationTier.from(item.name) {
        commander.installNavigationComputer(tier)
      } else if let booster = ShieldBooster.from(item.name) {
        let oldCapacity = commander.shieldCapacity
        commander.installShieldBooster(booster)
        frontShield = frontShield / oldCapacity * commander.shieldCapacity
        rearShield = rearShield / oldCapacity * commander.shieldCapacity
      } else {
        if item.name == Equipment.navalEnergyUnit {
          commander.storeOwnedModules(["Extra Energy Unit"], keeping: Equipment.navalEnergyUnit)
          commander.equipment.remove("Extra Energy Unit")
        }
        commander.equipment.insert(item.name)
      }
    }
    if !commander.unlimitedCash { commander.credits -= cost }
    notify("EQUIPMENT FITTED")
  }
  /// Sells the hold, then buys the most profitable exports for a destination.
  /// Government changes route risk, while commodity prices follow Elite's economy rules.
  public mutating func autoTrade() {
    guard docked else { return }
    let oldSelection = selection
    for index in commander.cargo.indices where commander.sellableCargo(index) > 0 {
      let saleQuantity = commander.sellableCargo(index)
      let (revenue, overflow) = saleQuantity.multipliedReportingOverflow(
        by: market[index].price)
      commander.credits =
        overflow
        ? 4_294_967_295 : min(4_294_967_295, commander.credits + min(revenue, 4_294_967_295))
      market[index].quantity += saleQuantity
      commander.cargo[index] -= saleQuantity
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
    let gross = exports.reduce(0) {
      $0 + $1.profit * min(commander.tradeCargoCapacity, market[$1.index].quantity)
    }
    let risk = Double(7 - destination.government) * 0.15
    return Double(gross) / (1 + risk + currentSystem.distance(to: destination) * 0.05)
  }
  public mutating func launch() {
    persistScriptActors(unloading: true)
    persistBlackjackTargets()
    retaliation.clear()
    weaponsTargetID = nil
    missileCooldown = 0
    spin.stop(immediate: true)
    cancelAutoTarget()
    docked = false
    screen = .front
    screenHistory.removeAll()
    flightReturn = .front
    speed = 8
    dockingComputer = false
    bodies = [
      SpaceBody(id: 0, hull: .station, position: .init(0, 0, -500)),
      SpaceBody(id: 1, hull: .cobra, position: .init(90, 20, 1400)),
      SpaceBody(id: 2, hull: .asteroid, position: .init(-280, 100, 2200)),
    ]
    commander.legal |= commander.cargo[3] + 2 * commander.cargo[6] + commander.cargo[10]
    resetCelestialFlight()
    notify("LAUNCHING FROM " + currentSystem.name)
    preloadNavigation()
    restoreBlackjackEncounter()
    restoreScriptActors()
  }
  public mutating func dock(atMainStation: Bool = true) {
    resolveDestroyed()
    persistScriptActors(unloading: true)
    persistBlackjackTargets()
    dockedAtMainStation = atMainStation
    retaliation.clear()
    weaponsTargetID = nil
    missileCooldown = 0
    spin.stop(immediate: true)
    cancelAutoTarget()
    docked = true
    screen = .status
    screenHistory.removeAll()
    speed = 0
    dockingComputer = false
    bodies = []
    energy = commander.performance.energy
    frontShield = commander.shieldCapacity
    rearShield = commander.shieldCapacity
    laserHeat = 0
    jumpCountdown = nil
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
  public mutating func beginHyperspace() {
    if screen == .chart && !mapIsCurrentGalaxy {
      _ = prepareChartTravel()
      return
    }
    guard !docked, jumpCountdown == nil else { return }
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
    guard !massLocked else {
      notify("MASS LOCKED")
      return
    }
    jumpCountdown = commander.performance.spool
    notify("HYPERSPACE")
  }
  public var massLocked: Bool {
    bodies.contains { $0.hull != .cargo && $0.position.length < 600 }
      || celestials.contains { $0.position.length < $0.radius * 4 }
  }
  public mutating func arrive() {
    resolveDestroyed()
    persistScriptActors(unloading: true)
    persistBlackjackTargets()
    retaliation.clear()
    weaponsTargetID = nil
    missileCooldown = 0
    spin.stop(immediate: true)
    cancelAutoTarget()
    let cost = Int((currentSystem.distance(to: targetSystem) * 10).rounded())
    if !commander.unlimitedFuel {
      commander.fuel = max(0, commander.fuel - cost)
    }
    commander.system = selectedSystem
    if let plan = commander.navigationPlan, plan.nextSystem != commander.system {
      commander.navigationPlan = nil
      notify("ROUTE CANCELLED - OFF ROUTE")
    }
    market = MarketItem.at(currentSystem, fluctuation: randomByte())
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
    altitude = 1
    notify(currentSystem.name)
    restoreBlackjackEncounter()
    restoreScriptActors()
  }
  public mutating func galacticJump() {
    let spent = ownedFittedGear(named: "Galactic Hyperdrive")
    guard !docked, commander.equipment.remove("Galactic Hyperdrive") != nil else { return }
    commander.synchronizeEquipmentInventory()
    recordOwnedGearConsumption(spent)
    resolveDestroyed()
    mapSearch = PlanetSearchState()
    commander.navigationPlan = nil
    persistScriptActors(unloading: true)
    persistBlackjackTargets()
    commander.galaxy = (commander.galaxy + 1) & 7
    if commander.system == Plugh.systemID { commander.system = Plugh.rumourStation }
    galacticBrowse = GalaxyBrowseState()
    systemInspection = nil
    systems = Universe.systemsIncludingPlugh(number: commander.galaxy)
    selectedSystem = commander.system
    arrive()
    commander.fuel = commander.fuelCapacity
  }
  public mutating func inSystemJump() {
    guard !docked, !massLocked else {
      notify("MASS LOCKED")
      return
    }
    for index in bodies.indices { bodies[index].position.z -= 3000 }
    if !bodies.contains(where: { $0.id == 0 && $0.hull == .station }),
      var frame = scriptReferenceFrame, frame.galaxy == commander.galaxy,
      frame.system == commander.system
    {
      frame.station.position.z -= 3000
      scriptReferenceFrame = frame
    }
    for index in celestials.indices { celestials[index].position.z -= 3000 }
  }
  @discardableResult public mutating func fireMissile(retaliating: Bool = false) -> Bool {
    guard !docked, missileArmed, missileCooldown == 0,
      commander.missiles > 0 || commander.unlimitedMissiles,
      let target = bodies.firstIndex(where: { body in
        body.hull != .station && body.energy > 0 && body.position.z > 0
          && (weaponsTargetID == nil || body.id == weaponsTargetID)
      })
    else { return false }
    let spent = commander.ownedEquipment?.fitted.first {
      $0.fittedSlot == .pylon(commander.missiles - 1)
    }
    if !commander.unlimitedMissiles { commander.missiles -= 1 }
    commander.synchronizeEquipmentInventory()
    missileCooldown = 1
    if bodies[target].ecmEnabled {
      var missile = SpaceBody(id: nextBodyID, hull: .missile, position: .init(0, 0, 24))
      missile.playerMissileTarget = bodies[target].id
      bodies.append(missile)
      nextBodyID += 1
    } else {
      bodies[target].energy = 0
      bodies[target].destroyedByPlayer = true
    }
    notify("MISSILE AWAY", voiced: !retaliating)
    missileArmed = false
    if !commander.unlimitedMissiles { recordOwnedGearConsumption(spent) }
    return true
  }
  public mutating func ecm() {
    guard !docked, commander.equipment.contains("E.C.M. System"), energy > 10, ecmFrames == 0 else {
      return
    }
    _ = ecmControl.detect(bodies)
    detectRetaliationSources()
    ecmControl.activate(destroyed: bodies.filter { $0.hull == .missile && $0.energy > 0 }.count)
    for missile in bodies where missile.hull == .missile && missile.energy > 0 {
      confirmRetaliation(missile)
    }
    bodies.removeAll { $0.hull == .missile }
    ecmFrames = 32
    enemyECMSource = nil
    energy -= 10
    notify("E.C.M.", voiced: false)
  }
  public mutating func energyBomb() {
    let spent = ownedFittedGear(named: "Energy Bomb")
    guard !docked, commander.equipment.remove("Energy Bomb") != nil else { return }
    commander.synchronizeEquipmentInventory()
    for index in bodies.indices where !bodies[index].hull.bombImmune {
      bodies[index].energy = 0
      bodies[index].destroyedByPlayer = true
    }
    notify("ENERGY BOMB")
    recordOwnedGearConsumption(spent)
  }
  public mutating func escapePod() {
    let spent = ownedFittedGear(named: "Escape Pod")
    guard !commander.accommodation.fittedBerths.contains(where: { $0.use.used }) else {
      notify("PASSENGERS CANNOT FIT THIS ESCAPE POD")
      return
    }
    guard !docked, commander.equipment.remove("Escape Pod") != nil else { return }
    commander.synchronizeEquipmentInventory()
    commander.cargo = Array(repeating: 0, count: 17)
    commander.cargo[10] = commander.markedFirearms
    commander.legal = 0
    commander.fuel = commander.fuelCapacity
    recordOwnedGearConsumption(spent)
    dock()
  }
  mutating func randomByte() -> Int {
    randomState = randomState &* 6_364_136_223_846_793_005 &+ 1
    return Int((randomState >> 32) & 255)
  }
  public mutating func tick(delta: Double, controls: Controls = Controls()) {
    defer { commander.synchronizeEquipmentInventory() }
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
    if paused || screen == .help || screen == .gallery || screen == .navigation
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
    guard !docked, screen != .gameOver, screen != .secret, screen != .help,
      screen != .title, screen != .demo
    else { return }
    let craft = commander.performance
    speed = min(craft.speed, max(0, speed + controls.throttle * dt * craft.acceleration))
    pitch = controls.pitch * craft.pitch
    yaw = controls.yaw * craft.yaw
    let previousSpinRate = spin.actualRate
    spin.advance(delta: dt, controls: controls)
    roll =
      spin.mode || spin.actualRate != 0 || previousSpinRate != 0
      ? (previousSpinRate + spin.actualRate) * .pi / 360 : controls.roll * craft.roll
    applyAutoTarget(delta: dt, controls: controls)
    laserHeat = max(0, laserHeat - dt * 12)
    fireCooldown = max(0, fireCooldown - dt)
    missileCooldown = max(0, missileCooldown - dt)
    energy = min(craft.energy, energy + dt * craft.recharge * commander.energyRechargeMultiplier)
    frontShield = min(commander.shieldCapacity, frontShield + dt * craft.shieldRecharge)
    rearShield = min(commander.shieldCapacity, rearShield + dt * craft.shieldRecharge)
    if controls.fire && screen.isFlight { fireLaser() }
    if let remaining = jumpCountdown {
      jumpCountdown = remaining - dt
      if remaining <= dt { arrive() }
    }
    moveBodies(dt: dt)
    if docked {
      reconcileEliteReward()
      return
    }
    advanceSolarFlight(delta: dt)
    guard screen != .gameOver else { return }
    scoopCargo()
    if missionLoopCounter & 7 == 0 { navalTactics() }
    detectIncomingMissiles()
    advanceNavalMissiles(delta: dt)
    ecmControl.advance()
    ecmFrames = max(0, ecmFrames - 1)
    if ecmFrames == 0 { enemyECMSource = nil }
    advanceRetaliation()
    starfield.advance(
      delta: dt, speed: speed, pitch: pitch, roll: roll, yaw: yaw, translation: autoPilot.velocity)
    resolveDestroyed()
    persistBlackjackTargets()
    if let id = weaponsTargetID, !bodies.contains(where: { $0.id == id && $0.energy > 0 }) {
      weaponsTargetID = nil
      notify("WEAPON LOCK LOST")
    }
    reconcileEliteReward()
    missionLoopCounter &-= 1
    if missionLoopCounter == 0 { spawnNavalEncounter() }
    spawnClock += dt
    if spawnClock > 18 && bodies.count < (commander.executive ? 18 : 10) {
      spawnClock = 0
      spawn()
    }
    if energy <= 0 {
      spin.stop(immediate: true)
      screen = .gameOver
      notify("GAME OVER")
    } else if energy < commander.performance.energy / 4 && messageTime <= 0 {
      notify("ENERGY LOW,SIR")
    }
    if screen != .gameOver { advanceMissionClock(dt) }
  }
  private mutating func fireLaser() {
    guard fireCooldown <= 0, laserHeat < 240, energy > 1 else { return }
    guard let mount = LaserMount.from(screen), let laser = commander.laser(on: mount) else {
      return
    }
    fireCooldown = laser.firingInterval
    laserHeat += 10
    energy -= 1
    laserFlash = 0.08
    if let index = bodies.firstIndex(where: {
      let p = viewPosition($0.position)
      return $0.hull != .station && p.z > 0 && abs(p.x / p.z) < 0.06 && abs(p.y / p.z) < 0.06
    }) {
      bodies[index].energy -= commander.laserDamage(against: bodies[index].hull, mount: mount)
      bodies[index].hostile = true
      if bodies[index].energy <= 0 { bodies[index].destroyedByPlayer = true }
    }
  }
  public func viewPosition(_ p: Vector3) -> Vector3 {
    switch screen {
    case .rear: return .init(-p.x, p.y, -p.z)
    case .left: return .init(p.z, p.y, -p.x)
    case .right: return .init(-p.z, p.y, p.x)
    default: return p
    }
  }
  private mutating func moveBodies(dt: Double) {
    autoPilot.rotateVelocity(pitch: pitch * dt, roll: roll * dt, yaw: yaw * dt)
    advanceScriptReferenceFrame(delta: dt)
    moveCelestials(delta: dt)
    for index in bodies.indices {
      bodies[index].position = bodies[index].position.rotated(
        pitch: pitch * dt, roll: roll * dt, yaw: yaw * dt)
      bodies[index].orientation.rotate(pitch: pitch * dt, roll: roll * dt, yaw: yaw * dt)
      bodies[index].position = bodies[index].position - autoPilot.velocity * dt
      bodies[index].position.z -= speed * dt * 18
      bodies[index].rotation += dt * bodies[index].rotationRate
      if bodies[index].hostile && bodies[index].energy > 0 { enemyAction(index: index, dt: dt) }
    }
    if let station = bodies.first(where: { $0.hull == .station }), station.containsPlayer {
      if station.canEnter(roll: roll, speed: max(speed * 18, autoPilot.velocity.length)) {
        dock(atMainStation: station.id == 0)
        return
      }
      applyDamage(dt * 100, front: true)
      if message != "DOCKING COLLISION" || messageTime <= 0 { notify("DOCKING COLLISION") }
    }
    persistBlackjackTargets()
    persistScriptActors()
    let departing = bodies.filter { $0.leavesLocalBubble }
    for body in departing {
      recordScriptActorRemoval(body, destroyed: body.energy <= 0)
      clearRemovedTarget(body)
      missionTargetRemoved(body)
      blackjackTargetDestroyed(body)
    }
    bodies.removeAll { $0.leavesLocalBubble }
    drainScriptEvents()
  }
  private mutating func enemyAction(index: Int, dt: Double) {
    if bodies[index].blackjackRole != nil {
      advanceBlackjackNPC(index: index, delta: dt)
      return
    }
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
    if bodies[index].position.length < 1500 {
      let damage = dt * (bodies[index].hull.navalLaserDamage ?? 6) * 2
      applyDamage(damage, front: bodies[index].position.z >= 0, energyMultiplier: 2)
    }
  }
  mutating func resolveDestroyed() {
    persistScriptActors()
    let destroyed = bodies.filter { $0.energy <= 0 }
    for body in destroyed
    where body.destroyedByPlayer == true && body.hull != .cargo && body.hull != .asteroid
      && body.playerMissileTarget == nil
      && !body.enemyMissile
    {
      let previousRank = commander.rank
      commander.kills = (commander.kills + 1) & 0xffff
      if commander.rank != previousRank { notify("RIGHT ON, COMMANDER") }
      commander.credits =
        (commander.credits
          + (body.blackjackRole.map { $0.bountyCredits * 10 } ?? body.hull.navalBounty
            ?? (body.hostile ? 50 : 0)))
        & 0xffff_ffff
      if !body.hostile { commander.legal += 8 }
    }
    for body in destroyed {
      recordScriptActorRemoval(body, destroyed: true)
      missionTargetRemoved(body)
      clearRemovedTarget(body)
      blackjackTargetDestroyed(body)
    }
    bodies.removeAll { $0.energy <= 0 }
    drainScriptEvents()
    if !bodies.contains(where: { $0.hull == .thargoid }) {
      for index in bodies.indices where bodies[index].hull == .thargon {
        bodies[index].hostile = false
        bodies[index].ecmEnabled = false
      }
    }
  }
  private mutating func spawn() {
    let hostile = randomByte() & 7 > currentSystem.government
    let peacefulKind: Hull = nextBodyID % 4 == 0 ? .cargo : .cobra
    let kind: Hull = hostile ? .sidewinder : peacefulKind
    bodies.append(
      SpaceBody(
        id: nextBodyID, hull: kind,
        position: .init(Double(randomByte() - 128) * 4, Double(randomByte() - 128) * 2, 5000),
        hostile: hostile))
    nextBodyID += 1
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
  public init(game: Game = Game(), saveURL: URL? = nil) {
    self.game = game
    if game.isMissionTrial {
      let namespace = Self.newGalleryNamespace()
      galleryNamespace = namespace
      scriptSaveURL = namespace.appendingPathComponent("commander.json")
      self.game.scriptDurabilityAvailable = true
    } else {
      self.game.scriptDurabilityAvailable = saveURL != nil
      galleryNamespace = nil
      scriptSaveURL = saveURL
    }
  }
  init(trialGame: Game) throws {
    let namespace = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent("elite-mission-gallery-" + UUID().uuidString, isDirectory: true)
    let target = namespace.appendingPathComponent("commander.json")
    var candidate = trialGame
    candidate.scriptDurabilityAvailable = true
    candidate.isMissionTrial = true
    try Self.writeCommander(&candidate, to: target)
    game = candidate
    galleryNamespace = namespace
    scriptSaveURL = target
  }
  public func snapshot() -> Game { game }
  public func key(_ key: String) {
    if galleryAction(key) { return }
    let before = game
    let held = controls
    applyKey(key)
    game.scriptDurabilityAvailable = scriptSaveURL != nil
    if before.screen == .gameOver, [" ", "return"].contains(key) {
      game.scriptPacks = before.scriptPacks
      game.missionPacks = before.missionPacks
    }
    do { try commitScriptCommand(from: before) } catch {
      game = before
      controls = held
      game.notify("MISSION SAVE FAILED - ACTION NOT COMMITTED")
    }
  }
  private func applyKey(_ key: String) {
    let old = game.screen
    let wasDocked = game.docked
    let oldLocation = (game.commander.galaxy, game.commander.system)
    if key == "contacts-open" || (key == "b" && !game.acceptsTextInput), game.docked, !game.paused,
      ![
        Screen.help, .gallery, .handoff, .mission, .showroom, .title, .demo, .gameOver,
        .secret, .navigation, .rumour,
      ].contains(game.screen)
    {
      game.emitScriptEvent("contact.requested")
      if game.showScriptDialogue() || game.offerAvailableScriptMission() {
        controls = Controls()
        return
      }
    }
    game.key(key)
    if old == .handoff, game.screen == .contracts { game.refreshContractRows() }
    game.observeScriptLocation(wasDocked: wasDocked, galaxy: oldLocation.0, system: oldLocation.1)
    if ["r", "tab"].contains(key.lowercased()), game.screen.isFlight, game.autoPilot.targetID != nil
    {
      controls.pitch = 0
      controls.yaw = 0
      controls.roll = 0
      if game.dockingComputer { controls = Controls() }
    }
    if old != game.screen || key == "pause"
      || [.gallery, .handoff, .showroom].contains(game.screen)
    {
      controls = Controls()
    }
  }
  public func blackjackHandoffClick(x: Double, y: Double) {
    nativeCommand { $0.blackjackHandoffClick(x: x, y: y) }
  }
  public func secretClick(x: Double, y: Double) { nativeCommand { $0.secretClick(x: x, y: y) } }
  public func showroomClick(x: Double, y: Double) { nativeCommand { $0.showroomClick(x: x, y: y) } }
  public func equipmentClick(y: Double, x: Double? = nil) {
    nativeCommand { $0.equipmentClick(y: y, x: x) }
  }
  public func mapClick(x: Double, y: Double) { game.mapClick(x: x, y: y) }
  public func galleryClick(x: Double, y: Double) { game.galleryClick(x: x, y: y) }
  public func setControls(_ value: Controls, expectedEpoch: UUID? = nil) {
    controls = expectedEpoch == nil || expectedEpoch == game.ecmControl.epoch ? value : Controls()
  }
  public func setViewport(width: Double, height: Double) {
    game.viewportWidth = width
    game.viewportHeight = height
  }
  public func selectSystem(x: Int, y: Int) { game.selectSystem(x: x, y: y) }
  public func advance(delta: Double) -> Game {
    let wasDocked = game.docked
    let location = (game.commander.galaxy, game.commander.system)
    let localActive =
      !game.paused
      && ![Screen.demo, .title, .gameOver, .gallery, .help, .navigation].contains(game.screen)
    let flightActive =
      localActive && !game.docked
      && ![Screen.mission, .handoff, .rumour, .showroom, .secret].contains(game.screen)
    // Physical facts commit first. A failed script save must never undo a real hit/death.
    game.scriptEventsDeferred = true
    game.tick(delta: delta, controls: controls)
    game.observeScriptLocation(wasDocked: wasDocked, galaxy: location.0, system: location.1)
    game.scriptEventsDeferred = false
    if localActive && !game.docked {
      game.persistScriptActors()
      game.restoreScriptActors()
    }
    if localActive { game.drainScriptEvents(publish: scriptPublisher()) }
    game.advanceScriptClocks(
      delta: delta, flight: flightActive, local: localActive, publish: scriptPublisher())
    return game
  }
  public func save(to url: URL) throws {
    try requireGalleryFileAccess(url)
    var candidate = game
    try Self.writeCommander(&candidate, to: url)
    game = candidate
    scriptSaveURL = url
    game.scriptDurabilityAvailable = true
  }
  public func restoreStartup(from url: URL) throws {
    try load(from: url, persistMigrations: false)
    if !game.commander.scriptState.instances.isEmpty
      || !game.commander.accommodation.ownedBerths.isEmpty
    {
      game.scriptStartupTime = game.time
    }
    game.screen = .title
    game.time = 0
  }
  public func load(from url: URL, persistMigrations: Bool = true) throws {
    try requireGalleryFileAccess(url)
    let data = try Data(contentsOf: url)
    guard data.count <= 4_194_304 else { throw SaveError.invalidCommander }
    if let pointer = try? JSONDecoder().decode(ScriptSavePointer.self, from: data) {
      if pointer.schemaVersion >= 6 {
        guard (pointer.scope == "gallery") == (galleryNamespace != nil) else {
          throw MissionPackError(
            "Trial saves open only in Gallery trials; commander saves open in the live game.")
        }
      }
      let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: url)
      try Self.requireGalleryPathAccess(generation, namespace: galleryNamespace)
      let (commander, world) = try ScriptSaveStore.read(data, from: url)
      // v2 is already migrated/validated; ordinary docking/load callbacks must not replay here.
      var candidate = Game(executive: false)
      candidate.commander = commander
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
      candidate.restoreScriptWorld(world)
      candidate.suspendUnavailableScriptContent()
      game = candidate
      controls = Controls()
      scriptSaveURL = url
      game.scriptDurabilityAvailable = true
      return
    }
    guard galleryNamespace == nil else {
      throw MissionPackError("Legacy commander files cannot replace a Gallery trial.")
    }
    var commander = try JSONDecoder().decode(Commander.self, from: data)
    let original = commander
    commander.migrateLegacyPassengerMarker()
    var candidate = game
    guard candidate.load(commander) else { throw SaveError.invalidCommander }
    if persistMigrations && candidate.commander != original {
      try Self.writeCommander(&candidate, to: url)
    }
    game = candidate
    controls = Controls()
    scriptSaveURL = url
    game.scriptDurabilityAvailable = true
  }
}
public enum TradePlanner {
  /// Conservative selling prices account for every possible market fluctuation.
  public static let minimumPrices: [[Int]] = (0..<8).map { economy in
    var prices = Array(repeating: Int.max, count: Commodity.all.count)
    for fluctuation in 0..<256 {
      let market = MarketItem.generate(economy: economy, fluctuation: fluctuation)
      for index in prices.indices { prices[index] = min(prices[index], market[index].price) }
    }
    return prices
  }
}

extension Game {
  var scriptSimulationSave: ScriptSimulationSave {
    ScriptSimulationSave(
      randomState: randomState, fireCooldown: fireCooldown, spawnClock: spawnClock,
      missionLoopCounter: missionLoopCounter, missionSpawnDelay: missionSpawnDelay,
      ecmFrames: ecmFrames,
      enemyECMSource: enemyECMSource, missileCooldown: missileCooldown,
      cabinTemperature: cabinTemperature, altitude: altitude, solar: ScriptSolarSave(game: self))
  }
  mutating func restoreScriptSimulation(_ state: ScriptSimulationSave?) {
    guard let state else { return }
    randomState = state.randomState
    fireCooldown = state.fireCooldown
    spawnClock = state.spawnClock
    missionLoopCounter = state.missionLoopCounter
    missionSpawnDelay = state.missionSpawnDelay
    ecmFrames = state.ecmFrames
    enemyECMSource = state.enemyECMSource
    missileCooldown = state.missileCooldown
    cabinTemperature = state.cabinTemperature
    altitude = state.altitude
    if let solar = state.solar {
      solar.restore(into: &self)
    } else {
      // Earlier physical formats predate local solar simulation; do not invent a saved scene.
      celestials = []
      solarFuelRemainder = 0
      solarScoopState = .inactive
    }
  }
}

extension Game {
  mutating func seedScriptTrial(_ seed: UInt64) { randomState = seed }
}
