import Foundation

enum ScriptProviderBounded {
  static func array<T: Decodable, K: CodingKey>(
    _ values: KeyedDecodingContainer<K>,
    key: K, type: T.Type, maximum: Int
  ) throws -> [T] {
    var entries = try values.nestedUnkeyedContainer(forKey: key)
    guard (entries.count ?? 0) <= maximum else {
      throw DecodingError.dataCorruptedError(
        in: entries, debugDescription: "Provider collection limit exceeded.")
    }
    var result: [T] = []
    while !entries.isAtEnd {
      guard result.count < maximum else {
        throw DecodingError.dataCorruptedError(
          in: entries, debugDescription: "Provider collection limit exceeded.")
      }
      result.append(try entries.decode(type))
    }
    return result
  }
}

struct ScriptProviderContractDefinition: Equatable, Codable, Sendable {
  let provider: String
  let origin: SystemIdentity
  let destination: SystemIdentity
  let payload: String
  let observation: ProviderMissionObservationTerms
  let fullReward: Int
  let urgentReward: Int
  let recoveryReward: Int
  let crewReward: Int
  static let requiredOperations: Set<String> = [
    "contact", "route", "core", "people", "law", "relay", "station", "actions",
  ]
  var valid: Bool {
    PackValidation.localID(provider) && PackValidation.localID(payload)
      && [origin, destination].allSatisfy {
        (0..<8).contains($0.galaxy) && (0...256).contains($0.system)
      }
      && origin != destination && observation.valid
      && [fullReward, urgentReward, recoveryReward, crewReward].allSatisfy {
        (0...1_000_000).contains($0)
      }
      && fullReward > 0 && urgentReward > 0 && recoveryReward > 0
  }
  func reward(_ branch: ProviderDispatchBranch) -> Int {
    switch branch {
    case .full: fullReward
    case .urgent: urgentReward
    case .recovery: recoveryReward
    }
  }
}

enum ProviderDispatchBranch: String, Codable, Sendable { case full, urgent, recovery }
enum ProviderContractStage: String, Codable, Sendable {
  case rendezvous, calibration, crisis, ready, returnRelay, betrayed, cargoLossPending, completed,
    cancelled, failedCargo
  var terminal: Bool { [.completed, .cancelled, .failedCargo].contains(self) }
}
enum ProviderCrewClaimDisposition: String, Codable, Sendable { case pending, paid, voided }
enum ProviderContractReceipt: String, Codable, Sendable {
  case accepted, manifest, ready, core, care, crewPaid, crewVoided, betrayed, terminal
}

struct ProviderCrewClaim: Equatable, Codable, Sendable {
  let operation: UUID
  let person: NativePersonReference
  let dock: NativeMainStationDockReceipt
  let order: UInt64
  var disposition: ProviderCrewClaimDisposition
}

public enum ProviderMissionAction: String, Codable, Sendable {
  case requestManifest, reviewUrgent, confirmUrgent, back, continueCalibration
  case recoverCore, deliver, returnRelay
}
struct ProviderMissionPendingReview: Equatable, Codable, Sendable {
  let action: ProviderMissionAction
  let token: UUID
  let runtimeEpoch: UUID
}

struct ScriptProviderContractState: Equatable, Codable, Sendable {
  let instance: UUID
  let terms: ScriptProviderContractDefinition
  let owner: UUID
  let provider: NativeProviderIdentity
  let subject: UUID
  let expectedManifest: NativeProviderManifest
  let origin: NativeMainStationIdentity
  let destination: NativeMainStationIdentity
  let item: UUID
  let acceptedOrder: UInt64
  var stage: ProviderContractStage = .rendezvous
  var branch: ProviderDispatchBranch?
  var custody: ProviderRelayCustody = .aboard
  var manifest: NativeProviderManifest?
  var progress = ProviderMissionProgress()
  var pending: ProviderMissionPendingReview?
  var core: NativeProviderCoreClaim?
  var crew: ProviderCrewClaim?
  var betrayal: NativeProviderBetrayal?
  var basePaid = 0
  var crewPaid = 0
  var terminalOrder: UInt64?
  var cargoLossOrder: UInt64?
  var lastRelayOrder: UInt64?
  var terminalDock: NativeMainStationDockReceipt?
  var receipts: Set<ProviderContractReceipt> = [.accepted]

  static func itemID(instance: UUID, payload: String) -> UUID {
    ScriptIdentity.uuid("provider-item-v1:" + instance.uuidString + ":" + payload)
  }
  var eligible: Bool { betrayal == nil && !stage.terminal }
  var owedCrewReward: Int { eligible && crew?.disposition == .pending ? terms.crewReward : 0 }
  var valid: Bool {
    guard terms.valid, provider.valid, provider.definition == terms.provider,
      origin.valid, destination.valid, origin.system == terms.origin,
      destination.system == terms.destination,
      origin.world == owner, destination.world == owner,
      provider.system == terms.origin, expectedManifest.valid,
      expectedManifest.provider == provider, expectedManifest.subject == subject,
      item == Self.itemID(instance: instance, payload: terms.payload),
      acceptedOrder > 0 && acceptedOrder < UInt64(Int64.max),
      progress.valid(terms: terms.observation),
      manifest == nil || manifest == expectedManifest, receipts.contains(.accepted),
      (manifest != nil) == receipts.contains(.manifest),
      (branch != nil) == receipts.contains(.ready),
      (core != nil) == receipts.contains(.core), (crew != nil) == receipts.contains(.care),
      (betrayal != nil) == receipts.contains(.betrayed),
      [0, terms.fullReward, terms.urgentReward, terms.recoveryReward].contains(basePaid),
      crewPaid == 0 || crewPaid == terms.crewReward, custody != .unavailable
    else { return false }
    if let pending {
      guard pending.action == .confirmUrgent, eligible, branch == nil, manifest != nil else {
        return false
      }
    }
    guard (custody == .lost) == (cargoLossOrder != nil),
      cargoLossOrder.map({ $0 > acceptedOrder && $0 < UInt64(Int64.max) }) ?? true,
      lastRelayOrder.map({ $0 > acceptedOrder && $0 < UInt64(Int64.max) }) ?? true
    else { return false }
    if let branch {
      guard manifest != nil else { return false }
      if branch == .full {
        guard progress.checkpointBits == terms.observation.completedBits,
          progress.escortSeconds >= terms.observation.escortSeconds
        else { return false }
      }
      if branch == .recovery, core == nil && crew == nil { return false }
    }
    if let core {
      guard core.provider == provider, core.subject == subject, core.manifest == expectedManifest,
        core.owner == owner, core.order > acceptedOrder, core.order < UInt64(Int64.max)
      else { return false }
    }
    if let crew {
      guard crew.dock.valid, crew.dock.station == origin, crew.dock.commanderOwner == owner,
        crew.order > acceptedOrder, crew.order < UInt64(Int64.max),
        (crew.disposition == .paid) == receipts.contains(.crewPaid),
        (crew.disposition == .voided) == receipts.contains(.crewVoided),
        crew.disposition == .paid ? crewPaid == terms.crewReward : crewPaid == 0
      else { return false }
    } else if crewPaid != 0 || receipts.contains(.crewPaid) || receipts.contains(.crewVoided) {
      return false
    }
    if let betrayal {
      guard betrayal.valid, betrayal.provider == provider, betrayal.order > acceptedOrder,
        crew?.disposition != .pending, basePaid == 0,
        stage == .betrayed || stage == .cancelled || stage == .failedCargo
          || stage == .cargoLossPending
      else { return false }
    }
    guard stage.terminal == receipts.contains(.terminal), stage.terminal == (terminalOrder != nil),
      terminalOrder.map({ order in
        order > acceptedOrder && order < UInt64(Int64.max)
          && [core?.order, crew?.order, betrayal?.order, cargoLossOrder, lastRelayOrder]
            .compactMap({ $0 }).allSatisfy({ $0 <= order })
      }) ?? true
    else { return false }
    switch stage {
    case .completed:
      guard let branch, basePaid == terms.reward(branch), custody == .delivered,
        terminalDock?.station == destination, terminalDock?.commanderOwner == owner,
        terminalDock?.valid == true, crew?.disposition != .pending
      else { return false }
    case .cancelled:
      guard basePaid == 0, custody == .returned, terminalDock?.station == origin,
        terminalDock?.commanderOwner == owner, terminalDock?.valid == true,
        crew?.disposition != .pending
      else { return false }
    case .cargoLossPending:
      guard basePaid == 0, custody == .lost, terminalDock == nil else { return false }
    case .failedCargo:
      guard basePaid == 0, custody == .lost, crew?.disposition != .pending else { return false }
    default:
      guard basePaid == 0, ![.delivered, .returned, .lost].contains(custody) else { return false }
    }
    return true
  }
  func valid(instance state: ScriptInstance) -> Bool {
    guard instance == state.id, valid,
      state.payloads[terms.payload, default: 0] == (custody == .aboard ? 1 : 0)
    else { return false }
    switch stage {
    case .completed: return state.outcome == .complete
    case .cancelled: return state.outcome == (betrayal == nil ? .abandoned : .failed)
    case .failedCargo: return state.outcome == .failed
    default: return state.outcome == .active
    }
  }
}

extension ScriptProviderContractState {
  private enum CodingKeys: String, CodingKey {
    case instance, terms, owner, provider, subject, expectedManifest, origin, destination, item,
      acceptedOrder
    case stage, branch, custody, manifest, progress, pending, core, crew, betrayal, basePaid,
      crewPaid
    case terminalOrder, cargoLossOrder, lastRelayOrder, terminalDock, receipts
  }
  init(from decoder: any Decoder) throws {
    let v = try decoder.container(keyedBy: CodingKeys.self)
    let entries = try ScriptProviderBounded.array(
      v, key: .receipts, type: ProviderContractReceipt.self, maximum: 9)
    guard Set(entries).count == entries.count else { throw SaveError.invalidCommander }
    self.init(
      instance: try v.decode(UUID.self, forKey: .instance),
      terms: try v.decode(ScriptProviderContractDefinition.self, forKey: .terms),
      owner: try v.decode(UUID.self, forKey: .owner),
      provider: try v.decode(NativeProviderIdentity.self, forKey: .provider),
      subject: try v.decode(UUID.self, forKey: .subject),
      expectedManifest: try v.decode(NativeProviderManifest.self, forKey: .expectedManifest),
      origin: try v.decode(NativeMainStationIdentity.self, forKey: .origin),
      destination: try v.decode(NativeMainStationIdentity.self, forKey: .destination),
      item: try v.decode(UUID.self, forKey: .item),
      acceptedOrder: try v.decode(UInt64.self, forKey: .acceptedOrder),
      stage: try v.decode(ProviderContractStage.self, forKey: .stage),
      branch: try v.decodeIfPresent(ProviderDispatchBranch.self, forKey: .branch),
      custody: try v.decode(ProviderRelayCustody.self, forKey: .custody),
      manifest: try v.decodeIfPresent(NativeProviderManifest.self, forKey: .manifest),
      progress: try v.decode(ProviderMissionProgress.self, forKey: .progress),
      pending: try v.decodeIfPresent(ProviderMissionPendingReview.self, forKey: .pending),
      core: try v.decodeIfPresent(NativeProviderCoreClaim.self, forKey: .core),
      crew: try v.decodeIfPresent(ProviderCrewClaim.self, forKey: .crew),
      betrayal: try v.decodeIfPresent(NativeProviderBetrayal.self, forKey: .betrayal),
      basePaid: try v.decode(Int.self, forKey: .basePaid),
      crewPaid: try v.decode(Int.self, forKey: .crewPaid),
      terminalOrder: try v.decodeIfPresent(UInt64.self, forKey: .terminalOrder),
      cargoLossOrder: try v.decodeIfPresent(UInt64.self, forKey: .cargoLossOrder),
      lastRelayOrder: try v.decodeIfPresent(UInt64.self, forKey: .lastRelayOrder),
      terminalDock: try v.decodeIfPresent(NativeMainStationDockReceipt.self, forKey: .terminalDock),
      receipts: Set(entries))
    guard valid else { throw SaveError.invalidCommander }
  }
}
